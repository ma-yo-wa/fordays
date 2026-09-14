import type { Config } from './config';
import { loadConfig, saveConfig } from './config';

export interface SpaceMember {
  id: string;
  name: string;
  role: 'admin' | 'member';
}

export interface SpaceInfo {
  id: string;
  name: string;
  inviteCode: string;
  frozen: boolean;
  forkedFrom: string | null;
  partner1Id: string;
  partner2Id: string | null;
  myId: string;
  myName: string;
  myRole: 'admin' | 'member';
  partnerName: string | null;
  members: SpaceMember[];
  /** 0 = you (sage), 1 = them (rose) — faces, not orbs. */
  me: 0 | 1;
}

export function isDefaultSpaceName(name: string): boolean {
  const raw = name.trim();
  return !raw || /^(fordays|someday)$/i.test(raw);
}

/** First notebook still has the trigger’s default name — ask Just you / With people. */
export function spaceNeedsFirstSetup(
  space: SpaceInfo | null,
  pendingInvite = false,
): boolean {
  if (!space || space.frozen || pendingInvite) return false;
  const others = (space.members ?? []).filter((m) => m.id !== space.myId);
  if (others.length > 0 || space.partner2Id) return false;
  return isDefaultSpaceName(space.name);
}

export interface InvitePeek {
  spaceId: string;
  spaceName: string;
  inviterName: string;
  isOpen: boolean;
}

type Client = Awaited<ReturnType<typeof makeClient>>;

let client: Client | null = null;
let clientKey = '';

async function makeClient(url: string, key: string) {
  const { createClient } = await import('@supabase/supabase-js');
  return createClient(url, key, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      // Needed for password-recovery links (hash/query tokens).
      detectSessionInUrl: true,
    },
  });
}

export function authConfigured(c: Config = loadConfig()): boolean {
  return Boolean(c.supabaseUrl && c.supabaseKey);
}

/** Shown when the client build has no project URL/key. */
export const MISSING_BACKEND =
  'This copy of Fordays can’t reach the server. Close the tab and open the link again — if it keeps happening, ask whoever shared it to redeploy.';

/** Turn Auth/API noise into something a person can act on. */
export function friendlyAuthError(err: unknown): string {
  if (!(err instanceof Error)) return 'Couldn’t sign in';
  const msg = err.message.trim();
  if (/isn.?t configured|is not configured/i.test(msg)) return MISSING_BACKEND;
  if (/invalid login credentials/i.test(msg)) return 'Wrong email or password';
  if (/email not confirmed/i.test(msg)) {
    return 'Confirm your email first, then try again';
  }
  if (/failed to fetch|networkerror|load failed|network request failed/i.test(msg)) {
    return 'Couldn’t reach the server — check your connection and try again';
  }
  if (/too many requests|rate limit/i.test(msg)) {
    return 'Too many tries — wait a minute and try again';
  }
  return msg || 'Couldn’t sign in';
}

export async function getClient(c: Config = loadConfig()): Promise<Client | null> {
  if (!authConfigured(c)) return null;
  const nextKey = `${c.supabaseUrl}\0${c.supabaseKey}`;
  if (!client || clientKey !== nextKey) {
    client = await makeClient(c.supabaseUrl, c.supabaseKey);
    clientKey = nextKey;
  }
  return client;
}

export async function currentSession() {
  const sb = await getClient();
  if (!sb) return null;
  const { data } = await sb.auth.getSession();
  return data.session;
}

export async function signInWithPassword(
  email: string,
  password: string,
): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const { error } = await sb.auth.signInWithPassword({
    email: email.trim().toLowerCase(),
    password,
  });
  if (error) throw new Error(friendlyAuthError(error));
}

/** Sends a recovery email. Redirect URL must be allow-listed in Supabase Auth. */
export async function requestPasswordReset(email: string): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const clean = email.trim().toLowerCase();
  if (!clean || !clean.includes('@')) {
    throw new Error('That doesn’t look like an email');
  }
  const redirectTo = `${appOrigin()}/`;
  const { error } = await sb.auth.resetPasswordForEmail(clean, { redirectTo });
  if (error) throw new Error(friendlyAuthError(error));
}

export async function updatePassword(password: string): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  if (password.length < 6) {
    throw new Error('Password needs at least 6 characters');
  }
  const { error } = await sb.auth.updateUser({ password });
  if (error) throw new Error(friendlyAuthError(error));
}

/** Fires when the open session came from a recovery link. */
export async function watchPasswordRecovery(
  onRecovery: () => void,
): Promise<() => void> {
  const sb = await getClient();
  if (!sb) return () => {};
  const { data } = sb.auth.onAuthStateChange((event) => {
    if (event === 'PASSWORD_RECOVERY') onRecovery();
  });
  return () => {
    data.subscription.unsubscribe();
  };
}

export async function signUpWithPassword(
  email: string,
  password: string,
  displayName: string,
): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const name = displayName.trim();
  if (!name) throw new Error('Add a name — it shows on your avatar');

  const { data, error } = await sb.auth.signUp({
    email: email.trim().toLowerCase(),
    password,
    options: {
      // handle_new_user reads this into profiles.display_name (avatar letter).
      data: { display_name: name },
    },
  });
  if (error) throw new Error(friendlyAuthError(error));
  // With “Confirm email” on, Supabase creates the user but returns no session
  // until they click a link — which breaks the in-app / PWA flow.
  if (!data.session) {
    throw new Error(
      'Account created, but email confirmation is still on in Supabase. Turn off Authentication → Providers → Email → Confirm email, then sign in.',
    );
  }

  // Belt-and-suspenders if the trigger used a stale default.
  // App reads public.profiles — Auth “Display name” in the dashboard is separate.
  if (data.user) {
    const { error: profErr } = await sb
      .from('profiles')
      .update({ display_name: name })
      .eq('id', data.user.id);
    if (profErr) throwSb(profErr);
  }
}

export async function signOut(): Promise<void> {
  const sb = await getClient();
  if (!sb) return;
  await sb.auth.signOut();
}

type SpaceRow = {
  id: string;
  name: string;
  invite_code: string;
  partner_1_id: string;
  partner_2_id: string | null;
  frozen?: boolean;
  forked_from?: string | null;
};

/** If signup ran before auto-create, make a solo space now. */
export async function ensureSpace(): Promise<SpaceInfo | null> {
  const list = await loadSpaces();
  if (list.length) {
    const saved = loadConfig().spaceId;
    return list.find((s) => s.id === saved) ?? list[0] ?? null;
  }

  const sb = await getClient();
  if (!sb) return null;
  const { data: sess } = await sb.auth.getSession();
  if (!sess.session?.user?.id) return null;

  const { error } = await sb.rpc('create_space', { p_name: 'Fordays' });
  if (error) {
    const { error: insErr } = await sb.from('spaces').insert({
      partner_1_id: sess.session.user.id,
      name: 'Fordays',
    });
    if (insErr) throw insErr;
  }
  const next = await loadSpaces();
  return next[0] ?? null;
}

export async function loadSpaces(): Promise<SpaceInfo[]> {
  const sb = await getClient();
  if (!sb) return [];
  const { data: sess } = await sb.auth.getSession();
  const uid = sess.session?.user?.id;
  if (!uid) return [];

  const { data: memberships, error: memErr } = await sb
    .from('space_members')
    .select('space_id, role')
    .eq('user_id', uid);
  if (memErr) {
    // Migration not applied yet — fall back to the pair columns.
    const one = await loadSpaceLegacy(uid);
    return one ? [one] : [];
  }

  const ids = (memberships ?? []).map((m) => m.space_id);
  if (!ids.length) return [];

  const { data: spaces, error } = await sb
    .from('spaces')
    .select('id, name, invite_code, partner_1_id, partner_2_id, frozen, forked_from')
    .in('id', ids);
  if (error) throw error;

  const { data: allMembers } = await sb
    .from('space_members')
    .select('space_id, user_id, role')
    .in('space_id', ids);

  const userIds = [...new Set((allMembers ?? []).map((m) => m.user_id))];
  const { data: profiles } = await sb
    .from('profiles')
    .select('id, display_name')
    .in('id', userIds.length ? userIds : [uid]);

  const metaName = metaDisplayName(sess.session?.user?.user_metadata);
  const rowName = profiles?.find((p) => p.id === uid)?.display_name?.trim() ?? '';
  if (metaName && (isPlaceholderName(rowName) || !rowName)) {
    await sb.from('profiles').update({ display_name: metaName }).eq('id', uid);
  }

  const nameOf = (id: string) => {
    const fromProfile = profiles?.find((p) => p.id === id)?.display_name?.trim();
    if (fromProfile && !isPlaceholderName(fromProfile)) return fromProfile;
    if (id === uid && metaName) return metaName;
    return fromProfile || (id === uid ? 'Me' : 'Them');
  };

  const list = (spaces ?? []).map((space) =>
    hydrateSpace(space, uid, nameOf(uid), nameOf, allMembers ?? [], memberships ?? []),
  );

  const current = list.find((s) => s.id === loadConfig().spaceId) ?? list[0];
  if (current) persistSpaceConfig(current);
  return list.sort((a, b) => Number(a.frozen) - Number(b.frozen) || a.name.localeCompare(b.name));
}

export async function loadSpace(): Promise<SpaceInfo | null> {
  const list = await loadSpaces();
  const saved = loadConfig().spaceId;
  return list.find((s) => s.id === saved) ?? list[0] ?? null;
}

export async function createSpace(name = 'Fordays'): Promise<SpaceInfo | null> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const { data, error } = await sb.rpc('create_space', { p_name: name });
  if (error) throwSb(error);
  const row = (Array.isArray(data) ? data[0] : data) as { id?: string } | null;
  if (row?.id) {
    const config = loadConfig();
    saveConfig({ ...config, spaceId: row.id });
  }
  return loadSpace();
}

export async function renameSpace(id: string, name: string): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const clean = name.trim();
  if (!clean) throw new Error('Add a name for this Orb');
  const { error } = await sb.from('spaces').update({ name: clean }).eq('id', id);
  if (error) throwSb(error);
}

export async function switchSpace(id: string): Promise<SpaceInfo | null> {
  const config = loadConfig();
  saveConfig({ ...config, spaceId: id });
  return loadSpace();
}

export async function removeSpaceMember(spaceId: string, userId: string): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const { error } = await sb.rpc('remove_space_member', { sid: spaceId, uid: userId });
  if (error) throwSb(error);
}

export async function leaveSpace(id: string): Promise<string | null> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const { data, error } = await sb.rpc('leave_space', { sid: id });
  if (error) throwSb(error);
  return typeof data === 'string' ? data : null;
}

export async function restoreSpace(id: string): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const { error } = await sb.rpc('restore_space', { sid: id });
  if (error) throwSb(error);
}

export async function deleteFrozenSpace(id: string): Promise<void> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const { error } = await sb.rpc('delete_frozen_space', { sid: id });
  if (error) throwSb(error);
}

function persistSpaceConfig(space: SpaceInfo): void {
  const config = loadConfig();
  saveConfig({
    ...config,
    spaceId: space.id,
    me: space.me,
    names:
      space.me === 0
        ? [space.myName, space.partnerName ?? 'You']
        : [space.partnerName ?? 'You', space.myName],
  });
}

function hydrateSpace(
  space: SpaceRow,
  uid: string,
  myName: string,
  nameOf: (id: string) => string,
  allMembers: Array<{ space_id: string; user_id: string; role: string }>,
  myMemberships: Array<{ space_id: string; role: string }>,
): SpaceInfo {
  const mine = allMembers.filter((m) => m.space_id === space.id);
  const members: SpaceMember[] = mine.map((m) => ({
    id: m.user_id,
    name: nameOf(m.user_id),
    role: m.role === 'admin' ? 'admin' : 'member',
  }));
  const others = members.filter((m) => m.id !== uid);
  const myRole =
    myMemberships.find((m) => m.space_id === space.id)?.role === 'admin' ? 'admin' : 'member';
  const partnerName = others.length === 1 ? others[0]!.name : others.length ? others.map((m) => m.name).join(', ') : null;

  return {
    id: space.id,
    name: space.name,
    inviteCode: space.invite_code,
    frozen: Boolean(space.frozen),
    forkedFrom: space.forked_from ?? null,
    partner1Id: space.partner_1_id,
    partner2Id: space.partner_2_id,
    myId: uid,
    myName,
    myRole,
    partnerName,
    members,
    me: 0,
  };
}

async function loadSpaceLegacy(uid: string): Promise<SpaceInfo | null> {
  const sb = await getClient();
  if (!sb) return null;
  const { data: space, error } = await sb
    .from('spaces')
    .select('id, name, invite_code, partner_1_id, partner_2_id')
    .or(`partner_1_id.eq.${uid},partner_2_id.eq.${uid}`)
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!space) return null;
  const partnerId = space.partner_1_id === uid ? space.partner_2_id : space.partner_1_id;
  const ids = [space.partner_1_id, partnerId].filter(Boolean) as string[];
  const { data: profiles } = await sb.from('profiles').select('id, display_name').in('id', ids);
  const nameOf = (id: string | null) =>
    profiles?.find((p) => p.id === id)?.display_name?.trim() || (id === uid ? 'Me' : 'Them');
  const info: SpaceInfo = {
    id: space.id,
    name: space.name,
    inviteCode: space.invite_code,
    frozen: false,
    forkedFrom: null,
    partner1Id: space.partner_1_id,
    partner2Id: space.partner_2_id,
    myId: uid,
    myName: nameOf(uid),
    myRole: space.partner_1_id === uid ? 'admin' : 'member',
    partnerName: partnerId ? nameOf(partnerId) : null,
    members: [
      { id: space.partner_1_id, name: nameOf(space.partner_1_id), role: 'admin' },
      ...(space.partner_2_id
        ? [{ id: space.partner_2_id, name: nameOf(space.partner_2_id), role: 'member' as const }]
        : []),
    ],
    me: 0,
  };
  persistSpaceConfig(info);
  return info;
}

export async function updateDisplayName(name: string): Promise<void> {
  const sb = await getClient();
  if (!sb) return;
  const { data: sess } = await sb.auth.getSession();
  const uid = sess.session?.user?.id;
  if (!uid) return;
  const clean = name.trim();
  if (!clean) return;

  const { error: profErr } = await sb
    .from('profiles')
    .update({ display_name: clean })
    .eq('id', uid);
  if (profErr) throwSb(profErr);

  // Keep Auth dashboard “Display name” in sync with the app.
  const { error: authErr } = await sb.auth.updateUser({
    data: { display_name: clean },
  });
  if (authErr) throw authErr;

  const config = loadConfig();
  const names: [string, string] = [...config.names];
  names[config.me] = clean;
  saveConfig({ ...config, names });
}

function metaDisplayName(meta: Record<string, unknown> | undefined): string | null {
  if (!meta) return null;
  for (const key of ['display_name', 'full_name', 'name'] as const) {
    const v = meta[key];
    if (typeof v === 'string' && v.trim() && !isPlaceholderName(v)) return v.trim();
  }
  return null;
}

function isPlaceholderName(name: string): boolean {
  const n = name.trim().toLowerCase();
  return !n || n === 'me' || n === 'you';
}

/** supabase-js still returns plain { message, … } objects, not Error. */
function throwSb(error: { message?: string; hint?: string; code?: string }): never {
  const msg = error.message?.trim() || 'Something went wrong';
  const hint = error.hint?.trim();
  // Missing RPC = invites migration never ran on this project.
  if (/peek_invite|join_space/i.test(msg) && /could not find the function/i.test(msg)) {
    throw new Error(
      'Invite isn’t set up on the server yet. In Supabase SQL, run migrations/001_spans_and_invites.sql.',
    );
  }
  if (
    /create_space|leave_space|remove_space_member|space_members/i.test(msg) &&
    /could not find|does not exist|schema cache/i.test(msg)
  ) {
    throw new Error(
      'Orbs aren’t set up on the server yet. In Supabase SQL, run migrations/010_space_members.sql.',
    );
  }
  throw new Error(hint && hint !== msg ? `${msg} (${hint})` : msg);
}

export function extractInviteCode(input: string): string {
  if (!input) return '';
  const trimmed = input.trim();
  const queryMatch = trimmed.match(/[?&]invite=([a-zA-Z0-9]+)/i);
  if (queryMatch && queryMatch[1]) {
    return queryMatch[1].toLowerCase();
  }
  const pathMatch = trimmed.match(/\/invite\/([a-zA-Z0-9]+)/i);
  if (pathMatch && pathMatch[1]) {
    return pathMatch[1].toLowerCase();
  }
  return trimmed.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
}

export async function peekInvite(code: string): Promise<InvitePeek | null> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const cleaned = extractInviteCode(code);
  if (!cleaned) throw new Error('That invite link is missing a code');
  const { data, error } = await sb.rpc('peek_invite', { code: cleaned });
  if (error) throwSb(error);
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) return null;
  return {
    spaceId: row.space_id,
    spaceName: row.space_name,
    inviterName: row.inviter_name,
    isOpen: row.is_open,
  };
}

export async function joinInvite(code: string, bringItems = false): Promise<string> {
  const sb = await getClient();
  if (!sb) throw new Error(MISSING_BACKEND);
  const cleaned = extractInviteCode(code);
  if (!cleaned) throw new Error('That invite link is missing a code');
  const fn = bringItems ? 'join_space_bringing_items' : 'join_space';
  const { data, error } = await sb.rpc(fn, { code: cleaned });
  if (error) throwSb(error);
  const row = (Array.isArray(data) ? data[0] : data) as { id?: string } | null;
  if (!row?.id) throw new Error('Could not join space');
  const config = loadConfig();
  saveConfig({ ...config, spaceId: row.id });
  return row.id;
}

/** Canonical production origin — invite links should never ship as localhost. */
const PROD_ORIGIN = 'https://fordays.app';

export function appOrigin(): string {
  const { protocol, hostname, origin } = window.location;
  if (hostname === 'localhost' || hostname === '127.0.0.1') return PROD_ORIGIN;
  if (protocol === 'https:' || protocol === 'http:') return origin.replace(/\/$/, '');
  return PROD_ORIGIN;
}

export function inviteUrl(code: string): string {
  return `${appOrigin()}/?invite=${encodeURIComponent(code)}`;
}

export function pendingInvite(): string | null {
  const params = new URLSearchParams(window.location.search);
  return params.get('invite');
}

export function clearInviteFromUrl(): void {
  const url = new URL(window.location.href);
  if (!url.searchParams.has('invite')) return;
  url.searchParams.delete('invite');
  window.history.replaceState(null, '', url.pathname + url.search + url.hash);
}
