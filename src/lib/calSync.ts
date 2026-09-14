import type { CalendarSource } from './calendars';
import type { ExternalEventInput } from './backend';
import {
  ensureGoogleToken,
  fetchGoogleEvents,
  savedGoogleCalendar,
} from './gcal';
import {
  ensureOutlookToken,
  fetchOutlookEvents,
  savedOutlookCalendar,
} from './outlook';

let lastPull = 0;
let inFlight: Promise<void> | null = null;

type SyncFn = (events: ExternalEventInput[], source: CalendarSource) => Promise<void>;

/** Quiet refresh of connected overlays. Skips if we pulled recently. */
export async function pullImportedCalendars(sync: SyncFn): Promise<void> {
  if (Date.now() - lastPull < 25_000) return;
  if (inFlight) return inFlight;
  lastPull = Date.now();
  inFlight = (async () => {
    await Promise.allSettled([pullGoogle(sync), pullOutlook(sync)]);
  })().finally(() => {
    inFlight = null;
  });
  return inFlight;
}

async function pullGoogle(sync: SyncFn): Promise<void> {
  const cal = savedGoogleCalendar();
  if (!cal) return;
  const token = await ensureGoogleToken();
  if (!token) return;
  const events = await fetchGoogleEvents(token, cal.id, cal.summary);
  await sync(events, 'google');
}

async function pullOutlook(sync: SyncFn): Promise<void> {
  const cal = savedOutlookCalendar();
  if (!cal) return;
  const token = await ensureOutlookToken();
  if (!token) return;
  const events = await fetchOutlookEvents(token, cal.id, cal.summary);
  await sync(events, 'outlook');
}
