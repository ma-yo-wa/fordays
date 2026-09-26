import { formatRange, spanDays } from './date';
import { Copy, formatCopy } from './copy';

/** Something already in your day: one of your calendar events, or a plan
 *  in your home Orb. Local form, like ExternalEvent. */
export interface BusyItem {
  title: string | null;
  startsAt: string;
  endsAt: string;
  allDay: boolean;
}

/** An hour on, same day; a start at 11 pm runs to midnight. */
const addHour = (stamp: string): string => {
  const [d, t] = stamp.split('T');
  const h = Number((t ?? '00:00').slice(0, 2)) + 1;
  return h > 23 ? `${d}T23:59` : `${d}T${String(h).padStart(2, '0')}${(t ?? '00:00').slice(2, 5)}`;
};

/**
 * The private line under a plan's date: "You have Gym, 8:00 am – 9:00 am".
 * A day with no time matches anything on that day; a time matches what
 * overlaps it. Yours only, and it never stops a save.
 */
export function clashLine(
  when: { date: string; from?: string; until?: string; endDate?: string | null },
  items: BusyItem[],
): string | null {
  const lastDay = when.endDate && when.endDate > when.date ? when.endDate : when.date;
  const days = new Set(spanDays(when.date, lastDay));

  let hits: BusyItem[];
  if (!when.from) {
    hits = items.filter((e) =>
      spanDays(e.startsAt.slice(0, 10), (e.endsAt || e.startsAt).slice(0, 10)).some((d) => days.has(d)),
    );
  } else {
    const start = `${when.date}T${when.from}`;
    const end = when.until
      ? `${lastDay}T${when.until}`
      : lastDay !== when.date
        ? `${lastDay}T23:59`
        : addHour(start);
    hits = items.filter((e) => {
      if (e.allDay) return false;
      const eEnd = e.endsAt && e.endsAt > e.startsAt ? e.endsAt : addHour(e.startsAt);
      return e.startsAt < end && eEnd > start;
    });
  }
  if (!hits.length) return null;

  hits.sort((a, b) => Number(a.allDay) - Number(b.allDay) || a.startsAt.localeCompare(b.startsAt));
  const first = hits[0]!;
  const range = formatRange(first.startsAt, first.endsAt || first.startsAt, first.allDay);
  const line = formatCopy(Copy.availability.clash, {
    title: first.title?.trim() || Copy.availability.busy,
    when: range === 'All day' ? 'all day' : range,
  });
  return hits.length > 1 ? `${line} and ${hits.length - 1} more` : line;
}
