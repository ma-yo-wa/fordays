import { getClient } from './auth';

/* Reminders, the way Google and Apple Calendar do them (migration 021).
   Alerts are yours, not the plan's: everyone in the Orb has their own.
   A plan with none of your own uses your defaults. */

/** Minutes before a timed plan. Apple Calendar's list, in its order. */
export const TIMED_ALERTS: { value: number; label: string }[] = [
  { value: 0, label: 'At time of plan' },
  { value: 5, label: '5 minutes before' },
  { value: 10, label: '10 minutes before' },
  { value: 15, label: '15 minutes before' },
  { value: 30, label: '30 minutes before' },
  { value: 60, label: '1 hour before' },
  { value: 120, label: '2 hours before' },
  { value: 1440, label: '1 day before' },
  { value: 2880, label: '2 days before' },
  { value: 10080, label: '1 week before' },
];

/** Days before an all-day plan, at 9 am. Apple's list. */
export const ALL_DAY_ALERTS: { value: number; label: string }[] = [
  { value: 0, label: 'On the day (9 am)' },
  { value: 1, label: '1 day before (9 am)' },
  { value: 2, label: '2 days before (9 am)' },
  { value: 7, label: '1 week before' },
];

export function alertOptions(allDay: boolean) {
  return allDay ? ALL_DAY_ALERTS : TIMED_ALERTS;
}

export function alertLabel(value: number | null | undefined, allDay: boolean): string {
  if (value == null) return 'None';
  return alertOptions(allDay).find((o) => o.value === value)?.label ?? 'None';
}

/** Morning summary times, every half hour from 5 am to 11 am. */
export const SUMMARY_TIMES: { value: number; label: string }[] = Array.from(
  { length: 13 },
  (_, i) => {
    const minute = 300 + i * 30;
    const h = Math.floor(minute / 60);
    const m = minute % 60;
    return { value: minute, label: `${h}:${String(m).padStart(2, '0')} am` };
  },
);

export interface NotificationPrefs {
  alertTimed: number[];
  alertAllDay: number[];
  summaryMinute: number | null;
  quietHours: boolean;
}

export const DEFAULT_PREFS: NotificationPrefs = {
  alertTimed: [30],
  alertAllDay: [0],
  summaryMinute: 480,
  quietHours: true,
};

async function uid(): Promise<string | null> {
  const sb = await getClient();
  if (!sb) return null;
  const { data } = await sb.auth.getSession();
  return data.session?.user?.id ?? null;
}

export async function loadPrefs(): Promise<NotificationPrefs> {
  const sb = await getClient();
  const me = await uid();
  if (!sb || !me) return DEFAULT_PREFS;
  const { data } = await sb
    .from('notification_prefs')
    .select('alert_timed, alert_all_day, summary_minute, quiet_hours')
    .eq('user_id', me)
    .maybeSingle();
  if (!data) return DEFAULT_PREFS;
  return {
    alertTimed: data.alert_timed ?? DEFAULT_PREFS.alertTimed,
    alertAllDay: data.alert_all_day ?? DEFAULT_PREFS.alertAllDay,
    summaryMinute: data.summary_minute,
    quietHours: data.quiet_hours ?? true,
  };
}

export async function savePrefs(next: NotificationPrefs): Promise<void> {
  const sb = await getClient();
  const me = await uid();
  if (!sb || !me) return;
  const { error } = await sb.from('notification_prefs').upsert(
    {
      user_id: me,
      alert_timed: next.alertTimed,
      alert_all_day: next.alertAllDay,
      summary_minute: next.summaryMinute,
      quiet_hours: next.quietHours,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );
  if (error) throw error;
}

/** Your alerts on one plan, or null when it follows your defaults. */
export async function loadPlanAlerts(activityId: string, allDay: boolean): Promise<number[] | null> {
  const sb = await getClient();
  const me = await uid();
  if (!sb || !me) return null;
  const { data } = await sb
    .from('activity_alerts')
    .select('alerts, all_day')
    .eq('user_id', me)
    .eq('activity_id', activityId)
    .maybeSingle();
  // Set for the other kind of plan: the defaults apply again.
  if (!data || data.all_day !== allDay) return null;
  return data.alerts ?? [];
}

export async function savePlanAlerts(
  activityId: string,
  allDay: boolean,
  alerts: number[],
): Promise<void> {
  const sb = await getClient();
  const me = await uid();
  if (!sb || !me) return;
  const { error } = await sb.from('activity_alerts').upsert(
    {
      user_id: me,
      activity_id: activityId,
      all_day: allDay,
      alerts,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,activity_id' },
  );
  if (error) throw error;
}

export async function loadOrbMuted(spaceId: string): Promise<boolean> {
  const sb = await getClient();
  const me = await uid();
  if (!sb || !me) return false;
  const { data } = await sb
    .from('space_members')
    .select('muted')
    .eq('space_id', spaceId)
    .eq('user_id', me)
    .maybeSingle();
  return Boolean(data?.muted);
}

export async function setOrbMuted(spaceId: string, muted: boolean): Promise<void> {
  const sb = await getClient();
  if (!sb) return;
  const { error } = await sb.rpc('set_orb_muted', { target_space: spaceId, mute: muted });
  if (error) throw error;
}
