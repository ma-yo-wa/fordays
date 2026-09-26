import { chosenCalendars, type CalendarSource, type ImportedCalendar } from './calendars';
import type { ExternalEventInput } from './backend';
import { ensureGoogleToken, fetchGoogleEvents } from './gcal';
import { ensureOutlookToken, fetchOutlookEvents } from './outlook';
import { syncCalendars } from './myCalendar';

let lastPull = 0;
let inFlight: Promise<boolean> | null = null;

/** Fetch one ticked calendar from its source, with a fresh token. */
export async function fetchCalendar(
  source: CalendarSource,
  cal: ImportedCalendar,
): Promise<ExternalEventInput[]> {
  if (source === 'google') {
    const token = await ensureGoogleToken();
    if (!token) throw new Error('Connect Google again');
    return fetchGoogleEvents(token, cal.id, cal.summary);
  }
  if (source === 'outlook') {
    const token = await ensureOutlookToken();
    if (!token) throw new Error('Connect Outlook again');
    return fetchOutlookEvents(token, cal.id, cal.summary);
  }
  return [];
}

/** Sync every ticked calendar of one source. Returns how many events came in. */
export function syncSource(source: CalendarSource): Promise<number> {
  return syncCalendars(source, chosenCalendars(source), (cal) => fetchCalendar(source, cal));
}

/** Quiet refresh on open and on coming back. True when anything synced. */
export async function pullImportedCalendars(): Promise<boolean> {
  if (Date.now() - lastPull < 25_000) return false;
  if (inFlight) return inFlight;
  lastPull = Date.now();
  inFlight = (async () => {
    const sources = (['google', 'outlook'] as const).filter(
      (s) => chosenCalendars(s).length > 0,
    );
    const done = await Promise.allSettled(sources.map((s) => syncSource(s)));
    return done.some((d) => d.status === 'fulfilled');
  })().finally(() => {
    inFlight = null;
  });
  return inFlight;
}
