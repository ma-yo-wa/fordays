import type { ExternalEventInput } from './backend';
import type { ImportedCalendar } from './calendars';
import { loadConfig } from './config';

const TOKEN_KEY = 'fordays.outlookTokens';
const CAL_KEY = 'fordays.outlookCalendar';
const WANTED_KEY = 'fordays.outlookWanted';
const PKCE_KEY = 'fordays.outlook.pkce';
const SCOPE = 'offline_access Calendars.Read';
const MSG = 'fordays-outlook';

export type OutlookCalendar = ImportedCalendar;

interface TokenSet {
  access: string;
  refresh: string;
  expiresAt: number;
}

export function msClientId(): string {
  return loadConfig().msClientId.trim();
}

export function outlookRedirectUri(): string {
  return `${window.location.origin}/`;
}

export function outlookWanted(): boolean {
  try {
    return localStorage.getItem(WANTED_KEY) === '1' || Boolean(savedOutlookCalendar());
  } catch {
    return Boolean(savedOutlookCalendar());
  }
}

function markOutlookWanted(on: boolean): void {
  try {
    if (on) localStorage.setItem(WANTED_KEY, '1');
    else localStorage.removeItem(WANTED_KEY);
  } catch {
    /* */
  }
}

function readTokens(): TokenSet | null {
  try {
    const raw = localStorage.getItem(TOKEN_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<TokenSet>;
    if (!parsed.access) return null;
    return {
      access: parsed.access,
      refresh: parsed.refresh ?? '',
      expiresAt: Number(parsed.expiresAt) || 0,
    };
  } catch {
    return null;
  }
}

function writeTokens(tokens: TokenSet | null): void {
  try {
    if (!tokens) localStorage.removeItem(TOKEN_KEY);
    else localStorage.setItem(TOKEN_KEY, JSON.stringify(tokens));
  } catch {
    /* */
  }
}

export function clearOutlookTokens(): void {
  writeTokens(null);
  markOutlookWanted(false);
  try {
    sessionStorage.removeItem(PKCE_KEY);
  } catch {
    /* */
  }
}

export function savedOutlookCalendar(): OutlookCalendar | null {
  try {
    const raw = localStorage.getItem(CAL_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as OutlookCalendar;
    if (!parsed?.id || !parsed?.summary) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function saveOutlookCalendar(cal: OutlookCalendar | null): void {
  try {
    if (!cal) localStorage.removeItem(CAL_KEY);
    else localStorage.setItem(CAL_KEY, JSON.stringify(cal));
  } catch {
    /* */
  }
}

/** Finish a popup (or same-window) Microsoft redirect. Call before the app paints. */
export function completeOutlookOAuthReturn(): boolean {
  const params = new URLSearchParams(window.location.search);
  const state = params.get('state') ?? '';
  const code = params.get('code');
  if (!state.startsWith('outlook.') || !code) return false;

  if (window.opener && !window.opener.closed) {
    window.opener.postMessage({ type: MSG, code, state }, window.location.origin);
    window.close();
    return true;
  }

  try {
    sessionStorage.setItem(`${PKCE_KEY}.code`, JSON.stringify({ code, state }));
  } catch {
    /* */
  }
  window.history.replaceState(null, '', window.location.pathname);
  return false;
}

export async function consumeOutlookRedirect(): Promise<string | null> {
  let payload: { code: string; state: string } | null = null;
  try {
    const raw = sessionStorage.getItem(`${PKCE_KEY}.code`);
    if (raw) payload = JSON.parse(raw) as { code: string; state: string };
    sessionStorage.removeItem(`${PKCE_KEY}.code`);
  } catch {
    payload = null;
  }
  if (!payload?.code) return null;
  return exchangeOutlookCode(payload.code, payload.state);
}

export async function connectOutlook(): Promise<string> {
  const clientId = msClientId();
  if (!clientId) {
    throw new Error('Outlook isn’t available yet');
  }

  const { verifier, challenge } = await makePkce();
  const nonce = crypto.randomUUID();
  sessionStorage.setItem(PKCE_KEY, JSON.stringify({ verifier, nonce }));

  const params = new URLSearchParams({
    client_id: clientId,
    response_type: 'code',
    redirect_uri: outlookRedirectUri(),
    response_mode: 'query',
    scope: SCOPE,
    code_challenge: challenge,
    code_challenge_method: 'S256',
    state: `outlook.${nonce}`,
    prompt: 'select_account',
  });
  const authUrl = `https://login.microsoftonline.com/common/oauth2/v2.0/authorize?${params.toString()}`;

  const popup = window.open(authUrl, 'fordays-outlook', 'width=480,height=720,scrollbars=yes');
  if (!popup) {
    window.location.assign(authUrl);
    return new Promise(() => {
      /* page unloads */
    });
  }

  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = (err?: Error, token?: string) => {
      if (settled) return;
      settled = true;
      window.removeEventListener('message', onMsg);
      window.clearInterval(tick);
      window.clearTimeout(timeout);
      if (token) resolve(token);
      else reject(err ?? new Error('Outlook sign-in closed'));
    };

    const onMsg = (ev: MessageEvent) => {
      if (ev.origin !== window.location.origin) return;
      if (ev.data?.type !== MSG || !ev.data.code) return;
      void exchangeOutlookCode(String(ev.data.code), String(ev.data.state ?? ''))
        .then((token) => finish(undefined, token))
        .catch((err) => finish(err instanceof Error ? err : new Error('Outlook sign-in failed')));
    };

    window.addEventListener('message', onMsg);
    const tick = window.setInterval(() => {
      if (popup.closed) finish(new Error('Outlook sign-in closed'));
    }, 400);
    const timeout = window.setTimeout(() => {
      try {
        popup.close();
      } catch {
        /* */
      }
      finish(new Error('Outlook sign-in timed out'));
    }, 120_000);
  });
}

export async function ensureOutlookToken(): Promise<string | null> {
  const tokens = readTokens();
  if (tokens && tokens.expiresAt > Date.now() + 15_000) return tokens.access;
  if (tokens?.refresh) {
    try {
      return await refreshOutlook(tokens.refresh);
    } catch {
      return null;
    }
  }
  return tokens?.access ?? null;
}

export async function listOutlookCalendars(token: string): Promise<OutlookCalendar[]> {
  const res = await fetch('https://graph.microsoft.com/v1.0/me/calendars', {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 401 || res.status === 403) {
    clearOutlookTokens();
    throw new Error('Outlook access expired — connect again');
  }
  if (!res.ok) throw new Error("Couldn't list your Outlook calendars");

  const body = (await res.json()) as {
    value?: Array<{
      id?: string;
      name?: string;
      isDefaultCalendar?: boolean;
      canEdit?: boolean;
    }>;
  };

  const list = (body.value ?? [])
    .filter((c): c is { id: string; name?: string; isDefaultCalendar?: boolean; canEdit?: boolean } =>
      Boolean(c.id),
    )
    .map((c) => ({
      id: c.id,
      summary: c.name?.trim() || c.id,
      primary: Boolean(c.isDefaultCalendar),
      accessRole: c.canEdit ? 'owner' : 'reader',
    }));

  list.sort((a, b) => {
    if (a.primary !== b.primary) return a.primary ? -1 : 1;
    return a.summary.localeCompare(b.summary);
  });
  return list;
}

export async function fetchOutlookEvents(
  token: string,
  calendarId: string,
  calendarName?: string,
): Promise<ExternalEventInput[]> {
  const min = new Date();
  min.setMonth(min.getMonth() - 1);
  const max = new Date();
  max.setMonth(max.getMonth() + 3);

  type GraphEvent = {
    id?: string;
    subject?: string;
    isAllDay?: boolean;
    location?: { displayName?: string };
    start?: { dateTime?: string; date?: string };
    end?: { dateTime?: string; date?: string };
  };

  const items: GraphEvent[] = [];
  let url =
    `https://graph.microsoft.com/v1.0/me/calendars/${encodeURIComponent(calendarId)}/calendarView` +
    `?startDateTime=${encodeURIComponent(min.toISOString())}` +
    `&endDateTime=${encodeURIComponent(max.toISOString())}` +
    '&$select=id,subject,isAllDay,location,start,end' +
    '&$top=100';

  for (let page = 0; page < 8 && url; page++) {
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        Prefer: 'outlook.timezone="UTC"',
      },
    });
    if (res.status === 401 || res.status === 403) {
      clearOutlookTokens();
      throw new Error('Outlook access expired — connect again');
    }
    if (!res.ok) throw new Error("Couldn't read Outlook Calendar");
    const body = (await res.json()) as { value?: GraphEvent[]; '@odata.nextLink'?: string };
    items.push(...(body.value ?? []));
    url = body['@odata.nextLink'] ?? '';
  }

  const label = calendarName?.trim() || savedOutlookCalendar()?.summary || 'Outlook';

  return items
    .filter((ev) => ev.id && (ev.start?.dateTime || ev.start?.date))
    .map((ev) => {
      const allDay = Boolean(ev.isAllDay);
      const startRaw = ev.start?.date ?? ev.start?.dateTime ?? '';
      const endRaw = ev.end?.date ?? ev.end?.dateTime ?? startRaw;
      let endsAt = toLocal(endRaw, allDay);
      if (allDay && endsAt > toLocal(startRaw, true)) {
        const d = new Date(`${endsAt}T12:00:00`);
        d.setDate(d.getDate() - 1);
        const pad = (n: number) => String(n).padStart(2, '0');
        endsAt = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
      }
      const place = ev.location?.displayName?.replace(/\s+/g, ' ').trim() || null;
      return {
        sourceId: ev.id!,
        title: ev.subject?.trim() || 'Busy',
        location: place && place !== '' ? place : null,
        startsAt: toLocal(startRaw, allDay),
        endsAt,
        allDay,
        calendar: label,
        source: 'outlook' as const,
      };
    });
}

async function exchangeOutlookCode(code: string, state: string): Promise<string> {
  const raw = sessionStorage.getItem(PKCE_KEY);
  const pkce = raw ? (JSON.parse(raw) as { verifier?: string; nonce?: string }) : null;
  const nonce = state.startsWith('outlook.') ? state.slice('outlook.'.length) : '';
  if (!pkce?.verifier || !pkce.nonce || pkce.nonce !== nonce) {
    throw new Error('Outlook sign-in expired — try again');
  }
  sessionStorage.removeItem(PKCE_KEY);
  const clientId = msClientId();
  const body = new URLSearchParams({
    client_id: clientId,
    grant_type: 'authorization_code',
    code,
    redirect_uri: outlookRedirectUri(),
    code_verifier: pkce.verifier,
    scope: SCOPE,
  });
  return persistTokenResponse(await postToken(body));
}

async function refreshOutlook(refresh: string): Promise<string> {
  const clientId = msClientId();
  if (!clientId) throw new Error('Outlook isn’t available yet');
  const body = new URLSearchParams({
    client_id: clientId,
    grant_type: 'refresh_token',
    refresh_token: refresh,
    scope: SCOPE,
  });
  return persistTokenResponse(await postToken(body));
}

async function postToken(body: URLSearchParams): Promise<{
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  error?: string;
  error_description?: string;
}> {
  const res = await fetch('https://login.microsoftonline.com/common/oauth2/v2.0/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const json = (await res.json()) as {
    access_token?: string;
    refresh_token?: string;
    expires_in?: number;
    error?: string;
    error_description?: string;
  };
  if (!res.ok || !json.access_token) {
    throw new Error(json.error_description || json.error || 'Outlook sign-in failed');
  }
  return json;
}

function persistTokenResponse(json: {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
}): string {
  const prev = readTokens();
  const access = json.access_token ?? '';
  const expiresIn = Number(json.expires_in) || 3600;
  writeTokens({
    access,
    refresh: json.refresh_token || prev?.refresh || '',
    expiresAt: Date.now() + Math.max(60, expiresIn - 60) * 1000,
  });
  markOutlookWanted(true);
  return access;
}

async function makePkce(): Promise<{ verifier: string; challenge: string }> {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const verifier = btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  const challenge = btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  return { verifier, challenge };
}

function toLocal(iso: string, allDay: boolean): string {
  if (allDay) return iso.slice(0, 10);
  const d = new Date(iso.endsWith('Z') || iso.includes('+') || iso.includes('T') ? iso : `${iso}Z`);
  if (Number.isNaN(d.getTime())) return iso.slice(0, 16);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
