import type { ExternalEventInput } from './backend';
import { getClient } from './auth';
import { iso } from './date';
import {
  chooseCalendars,
  markSynced,
  type CalendarSource,
  type ImportedCalendar,
} from './calendars';
import type { ExternalEvent } from './types';
import type { BusyItem } from './clash';

/* Your own Google / Apple / Outlook events. They belong to you, not an
   Orb: one copy in my_events that only you can read, shown in your home
   Orb and nowhere else. */

const pad = (n: number) => String(n).padStart(2, '0');

/** timestamptz -> "YYYY-MM-DDTHH:MM" in this device's time zone. */
function localStamp(v: string): string {
  const d = new Date(v);
  return `${iso(d)}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** "YYYY-MM-DDTHH:MM" (local) -> ISO instant. */
function instant(v: string): string {
  const [datePart, timePart] = v.split('T');
  const [y, m, d] = (datePart ?? '').split('-').map(Number);
  const [hh, mm] = (timePart ?? '00:00').split(':').map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1, hh ?? 0, mm ?? 0).toISOString();
}

/** The same event from Google and Apple, or a plan made from it, matches on this. */
function matchKey(title: string | null, startsAt: string): string {
  return `${(title ?? '').trim().toLowerCase()}|${startsAt}`;
}

interface MyEventRow {
  id: string;
  owner_id: string;
  source: CalendarSource;
  calendar_id: string;
  calendar_name: string;
  title: string | null;
  location: string | null;
  starts_at: string | null;
  ends_at: string | null;
  start_date: string | null;
  end_date: string | null;
}

/** Your events, once each, leaving out any you already made a plan from;
 *  and your home Orb's plans, for the clash line in other Orbs. */
export async function loadMyEvents(
  homeOrbId: string | null,
): Promise<{ events: ExternalEvent[]; homePlans: BusyItem[] }> {
  const client = await getClient();
  if (!client) return { events: [], homePlans: [] };

  const since = new Date();
  since.setMonth(since.getMonth() - 2);
  const [events, plans] = await Promise.all([
    client.from('my_events').select('*').order('starts_at', { ascending: true }),
    client
      .from('activities')
      .select('space_id, title, date_time, ends_at, all_day')
      .not('date_time', 'is', null)
      .gte('date_time', since.toISOString()),
  ]);
  if (events.error) {
    // Before migration 023 there's nothing to show; don't break the day.
    if (/my_events|schema cache/i.test(events.error.message)) return { events: [], homePlans: [] };
    throw events.error;
  }

  type PlanRow = { space_id: string; title: string; date_time: string; ends_at: string | null; all_day: boolean };
  const planRows = (plans.data ?? []) as PlanRow[];
  // All-day plans sit at noon UTC; their day is the UTC date.
  const planStamp = (v: string, allDay: boolean) =>
    allDay ? new Date(v).toISOString().slice(0, 10) : localStamp(v);
  const planned = new Set(planRows.map((p) => matchKey(p.title, planStamp(p.date_time, p.all_day))));
  const homePlans: BusyItem[] = planRows
    .filter((p) => p.space_id === homeOrbId)
    .map((p) => ({
      title: p.title,
      startsAt: planStamp(p.date_time, p.all_day),
      endsAt: planStamp(p.ends_at ?? p.date_time, p.all_day),
      allDay: p.all_day,
    }));

  const seen = new Set<string>();
  const out: ExternalEvent[] = [];
  for (const r of (events.data ?? []) as MyEventRow[]) {
    const allDay = r.start_date != null;
    const startsAt = allDay ? r.start_date! : localStamp(r.starts_at!);
    const endsAt = allDay ? (r.end_date ?? r.start_date!) : localStamp(r.ends_at ?? r.starts_at!);
    const key = matchKey(r.title, startsAt);
    if (seen.has(key) || planned.has(key)) continue;
    seen.add(key);
    out.push({
      id: r.id,
      ownerId: r.owner_id,
      title: r.title,
      location: r.location,
      startsAt,
      endsAt,
      allDay,
      calendar: r.calendar_name,
      calendarId: r.calendar_id,
      source: r.source,
    });
  }
  out.sort((a, b) => a.startsAt.localeCompare(b.startsAt));
  return { events: out, homePlans };
}

/**
 * Fetch each ticked calendar and replace it whole, so an event deleted or
 * declined at the source is gone here too; then forget calendars that
 * aren't ticked any more. One calendar failing leaves the others synced.
 */
export async function syncCalendars(
  source: CalendarSource,
  calendars: ImportedCalendar[],
  fetchOne: (cal: ImportedCalendar) => Promise<ExternalEventInput[]>,
): Promise<number> {
  const client = await getClient();
  if (!client) throw new Error('Sign in first');

  const counts: Record<string, number> = {};
  let total = 0;
  let firstError: unknown = null;
  for (const cal of calendars) {
    try {
      const events = await fetchOne(cal);
      const { error } = await client.rpc('replace_my_calendar', {
        p_source: source,
        p_calendar_id: cal.id,
        p_calendar_name: cal.summary,
        p_events: events.map((e) =>
          e.allDay
            ? {
                source_id: e.sourceId,
                title: e.title,
                location: e.location,
                start_date: e.startsAt.slice(0, 10),
                end_date: (e.endsAt || e.startsAt).slice(0, 10),
              }
            : {
                source_id: e.sourceId,
                title: e.title,
                location: e.location,
                starts_at: instant(e.startsAt),
                ends_at: instant(e.endsAt || e.startsAt),
              },
        ),
      });
      if (error) throw error;
      counts[cal.id] = events.length;
      total += events.length;
    } catch (err) {
      firstError ??= err;
    }
  }

  const { error } = await client.rpc('forget_my_calendars', {
    p_source: source,
    p_keep: calendars.map((c) => c.id),
  });
  if (error) firstError ??= error;

  if (firstError && Object.keys(counts).length === 0 && calendars.length) {
    throw firstError instanceof Error
      ? firstError
      : new Error((firstError as { message?: string }).message ?? 'Couldn’t sync that calendar');
  }
  markSynced(source, counts);
  return total;
}

/** Disconnect: nothing ticked, and every event from that source gone. */
export async function forgetSource(source: CalendarSource): Promise<void> {
  chooseCalendars(source, []);
  const client = await getClient();
  if (!client) return;
  const { error } = await client.rpc('forget_my_calendars', { p_source: source, p_keep: [] });
  if (error) throw error;
}
