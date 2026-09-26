import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';
import type {
  Backend,
  BackendHandlers,
  NewActivity,
} from '../backend';
import type { Activity, AuditLog, WhenSuggestion } from '../types';
import { iso } from '../date';
import type { Config } from '../config';
import { getClient } from '../auth';

const pad = (n: number) => String(n).padStart(2, '0');

/** App form ("2026-08-03" or "2026-08-03T19:30") -> timestamptz.
 *  All-day dates anchor at noon UTC so they stay on the exact same calendar day
 *  across all global timezones (-11h to +12h). */
function toTimestamptz(v: string): string {
  const [datePart, timePart] = v.split('T');
  if (!timePart) {
    return `${datePart}T12:00:00.000Z`;
  }
  const [y, m, d] = (datePart ?? '').split('-').map(Number);
  const [hh, mm] = timePart.split(':').map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1, hh ?? 0, mm ?? 0).toISOString();
}

/** timestamptz -> app form, rendered in the reader's own timezone.
 *  All-day plans never have a clock time. */
function fromTimestamptz(v: string | null, allDay: boolean): string | null {
  if (!v) return null;
  const d = new Date(v);
  const date = iso(d);
  if (allDay) return date;
  return `${date}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

interface ActivityRow {
  id: string;
  space_id: string;
  title: string;
  description: string | null;
  location?: string | null;
  image_url: string | null;
  created_by: string;
  date_time: string | null;
  ends_at?: string | null;
  all_day: boolean;
  from_someday?: boolean | null;
  suggested_date_time?: string | null;
  suggested_ends_at?: string | null;
  suggested_all_day?: boolean | null;
  suggested_by?: string | null;
  suggested_at?: string | null;
  suggested_note?: string | null;
  created_at: string;
  updated_at: string | null;
}

const CLEAR_SUGGESTION = {
  suggested_date_time: null,
  suggested_ends_at: null,
  suggested_all_day: false,
  suggested_by: null,
  suggested_at: null,
  suggested_note: null,
} as const;

/* Writes are not optimistic: the row must land in Postgres first. We still
   refresh the list ourselves after each write so the UI doesn't depend on
   Realtime being subscribed (Realtime remains for the other phone). */
export class SupabaseBackend implements Backend {
  readonly name = 'supabase' as const;

  private client!: SupabaseClient;
  private channel: RealtimeChannel | null = null;
  private handlers!: BackendHandlers;
  private spaceId: string;
  private uid = '';
  private cachedActivities: Activity[] = [];

  constructor(private config: Config) {
    this.spaceId = config.spaceId;
  }

  async init(handlers: BackendHandlers): Promise<void> {
    this.handlers = handlers;

    if (!this.spaceId) {
      throw new Error('No Orb yet — sign out and sign back in.');
    }

    const client = await getClient(this.config);
    if (!client) {
      throw new Error(
        'This copy of Fordays can’t reach the server. Close the tab and open the link again.',
      );
    }
    this.client = client;

    const { data: sessionData } = await this.client.auth.getSession();
    const user = sessionData.session?.user;
    if (!user) {
      throw new Error('Sign in first — this Orb needs an authenticated user.');
    }
    this.uid = user.id;

    await this.refreshActivities();
    void this.refreshLogs();

    // A start that overlaps an earlier one (a quick Orb switch back, or
    // React running effects twice in dev) finds this Orb's channel already
    // subscribed, and adding listeners to it throws. Start clean.
    const topic = `space:${this.spaceId}`;
    for (const ch of this.client.getChannels()) {
      if (ch.topic === `realtime:${topic}`) await this.client.removeChannel(ch);
    }

    this.channel = this.client
      .channel(topic)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'activities',
          filter: `space_id=eq.${this.spaceId}`,
        },
        () => void this.refreshActivities(),
      )
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'audit_logs',
          filter: `space_id=eq.${this.spaceId}`,
        },
        () => void this.refreshLogs(),
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          handlers.onLive(true, 'Live');
          return;
        }
        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          handlers.onLive(false, 'Reconnecting…');
          return;
        }
        handlers.onLive(false, 'Connecting…');
      });
  }

  dispose(): void {
    if (this.channel) void this.client.removeChannel(this.channel);
    this.channel = null;
  }

  async create(input: NewActivity): Promise<void> {
    // Re-check auth right before write — a stale client can "succeed" with
    // zero rows under RLS when the JWT isn't actually attached.
    const { data: userData, error: userErr } = await this.client.auth.getUser();
    if (userErr || !userData.user) {
      throw new Error('Session expired — sign out and sign back in.');
    }
    this.uid = userData.user.id;

    const targetSpaceId = input.space_id || this.spaceId;
    if (!targetSpaceId) {
      throw new Error('No Orb yet — sign out and sign back in.');
    }

    // 1. Optimistic insert: show in local state immediately at 0ms (if target is current space)
    const tempId = `opt-${crypto.randomUUID()}`;
    const fromSomeday = Boolean(input.from_someday ?? !input.date_time);

    if (targetSpaceId === this.spaceId) {
      const optimistic: Activity = {
        id: tempId,
        space_id: this.spaceId,
        title: input.title,
        description: input.description || null,
        location: input.location?.trim() || null,
        image_url: input.image_url || null,
        created_by: this.uid,
        created_at: new Date().toISOString(),
        date_time: input.date_time ?? null,
        ends_at: input.ends_at ?? null,
        all_day: !input.date_time || input.date_time.length <= 10,
        from_someday: fromSomeday,
        suggested_date_time: null,
        suggested_ends_at: null,
        suggested_all_day: false,
        suggested_by: null,
        suggested_at: null,
        suggested_note: null,
      };
      this.cachedActivities = [optimistic, ...this.cachedActivities.filter((a) => a.id !== tempId)];
      this.handlers.onActivities(this.cachedActivities);
    }

    const row: Record<string, unknown> = {
      space_id: targetSpaceId,
      title: input.title,
      description: input.description || null,
      image_url: input.image_url || null,
      created_by: this.uid,
      date_time: input.date_time ? toTimestamptz(input.date_time) : null,
      all_day: !input.date_time || input.date_time.length <= 10,
      from_someday: fromSomeday,
    };
    if (input.location?.trim()) row.location = input.location.trim();
    // Only send ends_at when set — older DBs without the column still work,
    // and null spans don't need the field.
    if (input.ends_at) row.ends_at = toTimestamptz(input.ends_at);

    try {
      let { data, error } = await this.client
        .from('activities')
        .insert(row)
        .select('*')
        .single();

      if (error && 'location' in row && /location/i.test(error.message || '')) {
        delete row.location;
        const retry = await this.client
          .from('activities')
          .insert(row)
          .select('*')
          .single();
        data = retry.data;
        error = retry.error;
      }

      if (error) {
        const detail = [error.message, error.details, error.hint]
          .filter(Boolean)
          .join(' — ');
        throw new Error(detail || 'Could not save');
      }
      if (!data) {
        throw new Error(
          'Save was blocked (no row returned). In Supabase, confirm schema.sql + migrations ran and you’re a member of the Orb.',
        );
      }

      // Replace optimistic row with server row
      const real = mapActivity(data as ActivityRow);
      this.cachedActivities = [
        real,
        ...this.cachedActivities.filter((a) => a.id !== tempId && a.id !== real.id),
      ];
      this.handlers.onActivities(this.cachedActivities);
      void this.refreshLogs();
    } catch (err) {
      // Revert optimistic insert on failure
      this.cachedActivities = this.cachedActivities.filter((a) => a.id !== tempId);
      this.handlers.onActivities(this.cachedActivities);
      throw err;
    }
  }

  async patch(id: string, changes: Partial<Activity>): Promise<void> {
    const backup = [...this.cachedActivities];
    const idx = this.cachedActivities.findIndex((a) => a.id === id);
    if (idx !== -1) {
      const existing = this.cachedActivities[idx]!;
      const fromSomeday =
        'from_someday' in changes
          ? changes.from_someday
          : ('date_time' in changes && changes.date_time && !existing.date_time)
            ? true
            : existing.from_someday;
      const updated: Activity = {
        ...existing,
        ...changes,
        id: existing.id,
        title: changes.title ?? existing.title,
        created_by: existing.created_by,
        created_at: existing.created_at,
        description: 'description' in changes ? (changes.description ?? null) : existing.description,
        location: 'location' in changes ? (changes.location ?? null) : existing.location,
        image_url: 'image_url' in changes ? (changes.image_url ?? null) : existing.image_url,
        date_time: 'date_time' in changes ? (changes.date_time ?? null) : existing.date_time,
        all_day:
          'date_time' in changes
            ? !changes.date_time || (changes.date_time?.length ?? 0) <= 10
            : existing.all_day,
        from_someday: fromSomeday,
        ends_at:
          'date_time' in changes && !changes.date_time
            ? null
            : 'ends_at' in changes
              ? (changes.ends_at ?? null)
              : existing.ends_at,
      };
      this.cachedActivities = [
        ...this.cachedActivities.slice(0, idx),
        updated,
        ...this.cachedActivities.slice(idx + 1),
      ];
      this.handlers.onActivities(this.cachedActivities);
    }

    const patch: Record<string, unknown> = {};
    if ('title' in changes) patch.title = changes.title;
    if ('description' in changes) patch.description = changes.description;
    if ('location' in changes) {
      const loc = changes.location?.trim();
      patch.location = loc || null;
    }
    if ('image_url' in changes) patch.image_url = changes.image_url;
    if ('date_time' in changes) {
      patch.date_time = changes.date_time ? toTimestamptz(changes.date_time) : null;
      patch.all_day = !changes.date_time || changes.date_time.length <= 10;
      // Unscheduling drops the end date too; a bucket-list item has no span.
      if (!changes.date_time) {
        patch.ends_at = null;
        patch.from_someday = true;
      }
      // A direct date change supersedes any pending suggestion.
      Object.assign(patch, CLEAR_SUGGESTION);
    }
    if ('ends_at' in changes) {
      patch.ends_at = changes.ends_at ? toTimestamptz(changes.ends_at) : null;
    }
    if ('from_someday' in changes) {
      patch.from_someday = changes.from_someday;
    }
    try {
      let { error } = await this.client.from('activities').update(patch).eq('id', id);
      if (error && 'location' in patch && /location/i.test(error.message || '')) {
        delete patch.location;
        const retry = await this.client.from('activities').update(patch).eq('id', id);
        error = retry.error;
      }
      if (error) throw error;
      void this.refreshLogs();
    } catch (err) {
      this.cachedActivities = backup;
      this.handlers.onActivities(this.cachedActivities);
      throw err;
    }
  }

  async moveToSpace(id: string, targetSpaceId: string): Promise<void> {
    const backup = [...this.cachedActivities];
    this.cachedActivities = this.cachedActivities.filter((a) => a.id !== id);
    this.handlers.onActivities(this.cachedActivities);
    try {
      const { error } = await this.client
        .from('activities')
        .update({ space_id: targetSpaceId })
        .eq('id', id);
      if (error) throw error;
      void this.refreshLogs();
    } catch (err) {
      this.cachedActivities = backup;
      this.handlers.onActivities(this.cachedActivities);
      throw err;
    }
  }

  async suggestWhen(id: string, input: WhenSuggestion): Promise<void> {
    const { data: userData, error: userErr } = await this.client.auth.getUser();
    if (userErr || !userData.user) {
      throw new Error('Session expired — sign out and sign back in.');
    }
    this.uid = userData.user.id;
    const allDay = !input.date_time || input.date_time.length <= 10;
    const { error } = await this.client
      .from('activities')
      .update({
        suggested_date_time: toTimestamptz(input.date_time),
        suggested_ends_at: input.ends_at ? toTimestamptz(input.ends_at) : null,
        suggested_all_day: allDay,
        suggested_by: this.uid,
        suggested_at: new Date().toISOString(),
        suggested_note: input.note?.trim() || null,
      })
      .eq('id', id);
    if (error) throw error;
    await this.refresh();
  }

  async acceptSuggestion(id: string): Promise<void> {
    const { data, error: readErr } = await this.client
      .from('activities')
      .select('suggested_date_time, suggested_ends_at, suggested_all_day')
      .eq('id', id)
      .single();
    if (readErr) throw readErr;
    if (!data?.suggested_date_time) {
      throw new Error('That suggestion is gone — ask them to send it again');
    }
    const { error } = await this.client
      .from('activities')
      .update({
        date_time: data.suggested_date_time,
        ends_at: data.suggested_ends_at,
        all_day: Boolean(data.suggested_all_day),
        ...CLEAR_SUGGESTION,
      })
      .eq('id', id);
    if (error) throw error;
    await this.refresh();
  }

  async dismissSuggestion(id: string): Promise<void> {
    const { error } = await this.client
      .from('activities')
      .update(CLEAR_SUGGESTION)
      .eq('id', id);
    if (error) throw error;
    await this.refresh();
  }

  async remove(id: string): Promise<void> {
    const backup = [...this.cachedActivities];
    this.cachedActivities = this.cachedActivities.filter((a) => a.id !== id);
    this.handlers.onActivities(this.cachedActivities);
    try {
      const { error } = await this.client.from('activities').delete().eq('id', id);
      if (error) throw error;
      void this.refreshLogs();
    } catch (err) {
      this.cachedActivities = backup;
      this.handlers.onActivities(this.cachedActivities);
      throw err;
    }
  }

  /* ---------------- internals ---------------- */

  private async refresh(): Promise<void> {
    await this.refreshActivities();
    void this.refreshLogs();
  }

  private async fetchActivities(): Promise<Activity[]> {
    const { data, error } = await this.client
      .from('activities')
      .select('*')
      .eq('space_id', this.spaceId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    const list = ((data ?? []) as ActivityRow[]).map(mapActivity);
    this.cachedActivities = list;
    return list;
  }

  private async refreshActivities(): Promise<void> {
    this.handlers.onActivities(await this.fetchActivities());
  }

  private async refreshLogs(): Promise<void> {
    const { data, error } = await this.client
      .from('audit_logs')
      .select('*')
      .eq('space_id', this.spaceId)
      .order('timestamp', { ascending: false })
      .limit(200);
    if (error || !data) return;
    this.handlers.onLogs(data as AuditLog[]);
  }

  /** Exposed so settings can show who you're actually signed in as. */
  get userId(): string {
    return this.uid;
  }

  get configRef(): Config {
    return this.config;
  }
}

function mapActivity(r: ActivityRow): Activity {
  const suggestedAllDay = Boolean(r.suggested_all_day);
  return {
    id: r.id,
    space_id: r.space_id,
    title: r.title,
    description: r.description,
    location: r.location ?? null,
    image_url: r.image_url,
    created_by: r.created_by,
    date_time: fromTimestamptz(r.date_time, r.all_day),
    ends_at: fromTimestamptz(r.ends_at ?? null, r.all_day),
    all_day: r.all_day,
    from_someday: r.from_someday ?? (!r.date_time ? true : false),
    suggested_date_time: fromTimestamptz(r.suggested_date_time ?? null, suggestedAllDay),
    suggested_ends_at: fromTimestamptz(r.suggested_ends_at ?? null, suggestedAllDay),
    suggested_all_day: suggestedAllDay,
    suggested_by: r.suggested_by ?? null,
    suggested_at: r.suggested_at ?? null,
    suggested_note: r.suggested_note ?? null,
    created_at: r.created_at,
    updated_at: r.updated_at ?? undefined,
  };
}

