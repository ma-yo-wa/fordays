/** Where an imported overlay row came from. Orb plans are not this. */
export type CalendarSource = 'google' | 'apple' | 'outlook';

export interface ImportedCalendar {
  id: string;
  summary: string;
  primary: boolean;
  /** owner | writer | reader — used to group “Mine” vs “Other”. */
  accessRole: 'owner' | 'writer' | 'reader' | string;
}

export function isCalendarSource(v: unknown): v is CalendarSource {
  return v === 'google' || v === 'apple' || v === 'outlook';
}

/* Which calendars you ticked, per source, on this device. The first
   version kept one calendar under an older key; it becomes a list of one. */
const LEGACY_ONE: Record<CalendarSource, string[]> = {
  google: ['fordays.gcalCalendar', 'someday.gcalCalendar'],
  outlook: ['fordays.outlookCalendar'],
  apple: [],
};

const listKey = (source: CalendarSource) => `fordays.calendars.${source}`;
const syncedKey = (source: CalendarSource) => `fordays.calendarsSynced.${source}`;

export function chosenCalendars(source: CalendarSource): ImportedCalendar[] {
  try {
    const raw = localStorage.getItem(listKey(source));
    if (raw) {
      const list = JSON.parse(raw) as ImportedCalendar[];
      return Array.isArray(list) ? list.filter((c) => c?.id && c?.summary) : [];
    }
    for (const key of LEGACY_ONE[source]) {
      const old = localStorage.getItem(key);
      if (!old) continue;
      const one = JSON.parse(old) as ImportedCalendar;
      if (!one?.id || !one?.summary) continue;
      chooseCalendars(source, [one]);
      return [one];
    }
  } catch {
    /* private mode or a bad value: nothing ticked */
  }
  return [];
}

export function chooseCalendars(source: CalendarSource, list: ImportedCalendar[]): void {
  try {
    if (list.length) localStorage.setItem(listKey(source), JSON.stringify(list));
    else {
      localStorage.removeItem(listKey(source));
      localStorage.removeItem(syncedKey(source));
    }
    for (const key of LEGACY_ONE[source]) localStorage.removeItem(key);
  } catch {
    /* */
  }
}

/** When a source last synced, and how many events each calendar brought. */
export interface CalendarSynced {
  at: number;
  counts: Record<string, number>;
}

export function lastSynced(source: CalendarSource): CalendarSynced | null {
  try {
    const raw = localStorage.getItem(syncedKey(source));
    return raw ? (JSON.parse(raw) as CalendarSynced) : null;
  } catch {
    return null;
  }
}

export function markSynced(source: CalendarSource, counts: Record<string, number>): void {
  try {
    localStorage.setItem(syncedKey(source), JSON.stringify({ at: Date.now(), counts }));
  } catch {
    /* */
  }
}

/** "Updated just now" / "Updated 5 min ago" / "Updated 3 h ago" / "Updated Sep 24". */
export function updatedAgo(at: number, now = Date.now()): string {
  const mins = Math.floor((now - at) / 60_000);
  if (mins < 1) return 'Updated just now';
  if (mins < 60) return `Updated ${mins} min ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `Updated ${hours} h ago`;
  const d = new Date(at);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `Updated ${months[d.getMonth()]} ${d.getDate()}`;
}
