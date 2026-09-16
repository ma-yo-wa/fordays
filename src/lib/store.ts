import { create } from 'zustand';
import { isPlan, type Activity, type AuditLog, type ExternalEvent, type PlanDraft } from './types';
import type { Backend, ExternalEventInput, NewActivity, WhenSuggestion } from './backend';
import type { CalendarSource } from './calendars';
import { LocalBackend } from './backends/local';
import { loadConfig, saveConfig, isSupabaseConfigured, type Config } from './config';
import {
  authConfigured,
  currentSession,
  createSpace as createSpaceRemote,
  ensureSpace,
  joinInvite,
  leaveSpace as leaveSpaceRemote,
  restoreSpace as restoreSpaceRemote,
  deleteFrozenSpace as deleteFrozenSpaceRemote,
  loadSpaces,
  removeSpaceMember as removeSpaceMemberRemote,
  renameSpace as renameSpaceRemote,
  isDefaultSpaceName,
  clearFirstOrbSetupPending,
  pendingInvite,
  signOut,
  switchSpace as switchSpaceRemote,
  type SpaceInfo,
} from './auth';
import { dtDate, iso, parseISO, todayISO } from './date';
import { Copy, formatCopy } from './copy';
import { prefetchBoardCovers } from './coverCache';

export type Screen = 'bucket' | 'calendar' | 'memories';

/** The two things this app makes. A plan has a date; a bucket-list item
 *  is the same thing before anyone has committed to one. */
export type Kind = 'plan' | 'bucket';

interface Toast {
  id: number;
  text: string;
}

export type AuthPhase = 'loading' | 'local' | 'signedOut' | 'signedIn';

/** Two or more people in this orb. */
export function isMatched(space: SpaceInfo | null | undefined): boolean {
  if (!space) return false;
  if (space.members?.length) return space.members.length >= 2;
  return Boolean(space.partner2Id);
}

export function canCompose(space: SpaceInfo | null | undefined): boolean {
  return Boolean(space && !space.frozen);
}

/** The notebook’s name, or empty if they haven’t named it.
 *  Fordays / Someday leftovers are unnamed. Never invent Personal or Aline’s Crew. */
export function spaceOrbName(space: SpaceInfo): string {
  const raw = space.name?.trim() ?? '';
  if (raw && !isDefaultSpaceName(raw)) return raw;
  return '';
}

/** @deprecated use spaceOrbName — same value, kept for call sites. */
export function spacePeopleLabel(space: SpaceInfo): string {
  return spaceOrbName(space);
}

interface AppState {
  ready: boolean;
  authPhase: AuthPhase;
  backendName: 'local' | 'supabase';
  live: boolean;
  liveLabel: string;

  activities: Activity[];
  logs: AuditLog[];
  external: ExternalEvent[];

  config: Config;
  space: SpaceInfo | null;
  spaces: SpaceInfo[];

  screen: Screen;
  /** Selected day, YYYY-MM-DD. */
  picked: string;
  /** First of the visible month, YYYY-MM-DD. */
  cursor: string;
  /* How far the active screen's scroller has travelled. The nav bar owns
     none of the scrolling but has to react to all of it, the way a large
     title collapses in a real app. */
  navScroll: number;

  detailId: string | null;
  /* Kept apart from detailId because an imported event isn't an activity
     and never becomes one — different data, different sheet. */
  externalId: string | null;
  /* Which of the two things you're making, chosen before the form opens
     rather than inferred from whether a date got filled in. null = shut. */
  composerMode: Kind | null;
  composerDraft: PlanDraft | null;
  /* The little menu that asks which one. */
  addOpen: boolean;
  settingsOpen: boolean;
  inviteShareOpen: boolean;
  inviteCode: string | null;
  /** Reset-link session — force the new-password screen before the app. */
  passwordRecovery: boolean;
  toasts: Toast[];

  boot: () => Promise<void>;
  refreshSpace: () => Promise<void>;
  switchToSpace: (id: string) => Promise<void>;
  addSpace: (name?: string, withPeople?: boolean) => Promise<void>;
  completeFirstOrb: (name: string, withPeople: boolean) => Promise<void>;
  renameCurrentSpace: (name: string) => Promise<void>;
  leaveCurrentSpace: () => Promise<void>;
  leaveSpace: (spaceId: string) => Promise<void>;
  restorePastOrb: (spaceId: string) => Promise<void>;
  deletePastOrb: (spaceId: string) => Promise<void>;
  removeMemberFromSpace: (userId: string) => Promise<void>;
  signOutUser: () => Promise<void>;
  setPasswordRecovery: (v: boolean) => void;
  connect: (next: Partial<Config>) => Promise<void>;
  disconnect: () => Promise<void>;

  create: (input: NewActivity) => Promise<void>;
  patch: (id: string, changes: Partial<Activity>) => Promise<void>;
  moveToSpace: (id: string, targetSpaceId: string) => Promise<void>;
  remove: (id: string) => Promise<void>;
  suggestWhen: (id: string, input: WhenSuggestion) => Promise<void>;
  acceptSuggestion: (id: string) => Promise<void>;
  dismissSuggestion: (id: string) => Promise<void>;

  setScreen: (s: Screen) => void;
  setPicked: (d: string) => void;
  setCursor: (d: string) => void;
  setNavScroll: (y: number) => void;
  openDetail: (id: string | null) => void;
  navigateToActivity: (activityId: string, spaceId?: string | null) => Promise<void>;
  openExternal: (id: string | null) => void;
  setAddOpen: (v: boolean) => void;
  openComposer: (mode: Kind, draft?: PlanDraft | null) => void;
  closeComposer: () => void;
  searchOpen: boolean;
  setSearchOpen: (v: boolean) => void;
  setSettingsOpen: (v: boolean) => void;
  setInviteShareOpen: (v: boolean) => void;
  setInviteCode: (code: string | null) => void;
  joinOrbOpen: boolean;
  setJoinOrbOpen: (v: boolean) => void;
  joinOrb: (code: string) => Promise<SpaceInfo>;
  updateConfig: (patch: Partial<Config>) => void;
  setExternal: (events: ExternalEvent[]) => void;
  syncExternal: (events: ExternalEventInput[], source: CalendarSource) => Promise<void>;
  pullImportedCalendars: () => Promise<void>;
  toggleExternalShare: (id: string, shared: boolean) => Promise<void>;
  toast: (text: string) => void;
}

let backend: Backend | null = null;
let toastSeq = 0;
let snapTimer = 0;

const SNAP_LAST = 'fordays:snap:last';
const firstOfMonth = (d: Date) => iso(new Date(d.getFullYear(), d.getMonth(), 1));

type NotebookSnap = {
  space: SpaceInfo;
  spaces: SpaceInfo[];
  activities: Activity[];
};

function snapKey(spaceId: string): string {
  return `fordays:snap:v1:${spaceId}`;
}

function slimActivities(list: Activity[]): Activity[] {
  return list.map((a) =>
    a.image_url?.startsWith('data:') ? { ...a, image_url: null } : a,
  );
}

function readSnap(spaceId?: string | null): NotebookSnap | null {
  try {
    const id = spaceId ?? localStorage.getItem(SNAP_LAST);
    if (!id) return null;
    const raw = localStorage.getItem(snapKey(id));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as NotebookSnap;
    if (!parsed?.space?.id || !Array.isArray(parsed.activities)) return null;
    return parsed;
  } catch {
    return null;
  }
}

function writeSnap(space: SpaceInfo, spaces: SpaceInfo[], activities: Activity[]): void {
  try {
    const snap: NotebookSnap = {
      space,
      spaces: spaces.length ? spaces : [space],
      activities: slimActivities(activities),
    };
    localStorage.setItem(snapKey(space.id), JSON.stringify(snap));
    localStorage.setItem(SNAP_LAST, space.id);
  } catch {
    /* quota / private mode */
  }
}

export const useApp = create<AppState>()((set, get) => {
  const scheduleSnap = () => {
    const { space, spaces, activities } = get();
    if (!space) return;
    window.clearTimeout(snapTimer);
    snapTimer = window.setTimeout(() => writeSnap(space, spaces, activities), 200);
  };

  const handlers = {
    onActivities: (list: Activity[]) => {
      set({ activities: list });
      scheduleSnap();
      prefetchBoardCovers(list);
    },
    onLogs: (list: AuditLog[]) => set({ logs: list }),
    onExternal: (list: ExternalEvent[]) => set({ external: list }),
    onLive: (live: boolean, liveLabel: string) => set({ live, liveLabel }),
  };

  async function start(next: Backend): Promise<void> {
    backend?.dispose();
    backend = next;
    await next.init(handlers);
    set({ backendName: next.name, ready: true });
  }

  /* The Supabase client is over half the bundle and is dead weight until
     someone actually connects a project, so it loads on demand. */
  async function supabaseBackend(config: Config): Promise<Backend> {
    const { SupabaseBackend } = await import('./backends/supabase');
    return new SupabaseBackend(config);
  }

  const snap = readSnap();
  if (snap) {
    prefetchBoardCovers(snap.activities);
  }

  return {
    ready: Boolean(snap),
    authPhase: snap ? 'signedIn' : 'loading',
    backendName: 'local',
    live: false,
    liveLabel: 'On this device',

    activities: snap ? snap.activities : [],
    logs: [],
    external: [],

    config: loadConfig(),
    space: snap ? snap.space : null,
    spaces: snap ? (snap.spaces.length ? snap.spaces : [snap.space]) : [],

    screen: 'calendar',
    picked: todayISO(),
    cursor: firstOfMonth(new Date()),
    navScroll: 0,
    detailId: null,
    externalId: null,
    composerMode: null,
    composerDraft: null,
    addOpen: false,
    searchOpen: false,
    settingsOpen: false,
    inviteShareOpen: false,
    inviteCode: pendingInvite(),
    joinOrbOpen: false,
    passwordRecovery: false,
    toasts: [],

    setPasswordRecovery: (passwordRecovery) => set({ passwordRecovery }),

    async boot() {
      const config = get().config;

      // Auth path: project credentials present, space comes from the session.
      // Never fall through to the offline demo — that leaked Me/You calendars
      // to strangers when Supabase hiccuped.
      if (authConfigured(config)) {
        try {
          const session = await currentSession();
          if (!session) {
            set({ authPhase: 'signedOut', ready: true, space: null });
            return;
          }
          const backendMod = import('./backends/supabase');
          const snap = readSnap();
          if (snap) {
            set({
              space: snap.space,
              spaces: snap.spaces.length ? snap.spaces : [snap.space],
              activities: snap.activities,
              authPhase: 'signedIn',
              ready: true,
              config: loadConfig(),
            });
            prefetchBoardCovers(snap.activities);
          }
          const space = await ensureSpace();
          const [spaces, { SupabaseBackend }] = await Promise.all([
            loadSpaces().catch(() => (space ? [space] : [])),
            backendMod,
          ]);
          set({ space, spaces, config: loadConfig(), authPhase: 'signedIn' });
          if (space) {
            await start(new SupabaseBackend({ ...loadConfig(), spaceId: space.id }));
            void import('./push').then((m) => m.syncPush());
            void get().pullImportedCalendars();
          } else {
            set({ ready: true });
          }
          return;
        } catch (err) {
          get().toast(err instanceof Error ? err.message : 'Could not sign in');
          set({ authPhase: 'signedOut', ready: true, space: null });
          return;
        }
      }

      // Manual connect path (demo / older setup with a pasted space id).
      if (isSupabaseConfigured(config)) {
        try {
          set({ authPhase: 'local' });
          await start(await supabaseBackend(config));
          return;
        } catch (err) {
          get().toast(err instanceof Error ? err.message : 'Could not connect');
        }
      }

      // Production never ships the offline Me/You sandbox — that looked like
      // a real space, then Sign out left people on a login that can’t work.
      if (import.meta.env.PROD) {
        set({ authPhase: 'signedOut', ready: true, space: null });
        return;
      }

      // Offline sandbox for local builds without Supabase env.
      const localSpace = {
        id: 'local',
        name: 'Fordays',
        inviteCode: '',
        frozen: false,
        forkedFrom: null,
        partner1Id: '0',
        partner2Id: '1',
        myId: String(config.me),
        myName: config.names[config.me] || 'Me',
        myRole: 'admin' as const,
        partnerName: config.names[1 - config.me] || 'You',
        members: [
          { id: '0', name: config.names[0] || 'Me', role: 'admin' as const },
          { id: '1', name: config.names[1] || 'You', role: 'member' as const },
        ],
        me: config.me,
      };
      set({ authPhase: 'local', space: localSpace, spaces: [localSpace] });
      await start(new LocalBackend());
    },

    async refreshSpace() {
      const space = await ensureSpace();
      const spaces = await loadSpaces().catch(() => (space ? [space] : []));
      set({ space, spaces, config: loadConfig(), authPhase: 'signedIn' });
      if (space) {
        await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
        void get().pullImportedCalendars();
      }
    },

    async switchToSpace(id) {
      const snap = readSnap(id);
      if (snap) {
        set({
          space: snap.space,
          spaces: snap.spaces.length ? snap.spaces : [snap.space],
          activities: snap.activities,
          external: [],
          detailId: null,
          searchOpen: false,
        });
        prefetchBoardCovers(snap.activities);
      } else {
        set({ activities: [], external: [], logs: [], detailId: null, searchOpen: false });
      }
      const space = await switchSpaceRemote(id);
      const spaces = await loadSpaces().catch(() => (space ? [space] : []));
      set({ space, spaces, config: loadConfig(), detailId: null, searchOpen: false });
      if (space?.frozen) get().toast('This is a copy from when you left');
      if (space) {
        await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
        if (!space.frozen) void get().pullImportedCalendars();
      }
    },

    async addSpace(name, withPeople) {
      const clean = (name ?? '').trim();
      if (!clean) return;
      const space = await createSpaceRemote(clean);
      const spaces = await loadSpaces().catch(() => (space ? [space] : []));
      set({ space, spaces, config: loadConfig() });
      if (space) {
        await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
        void get().pullImportedCalendars();
      }
      if (withPeople) get().setInviteShareOpen(true);
    },

    async completeFirstOrb(name, withPeople) {
      const current = get().space;
      if (!current) return;
      const clean = name.trim();
      if (!clean) return;
      if (withPeople) {
        await renameSpaceRemote(current.id, 'Personal');
        const space = await createSpaceRemote(clean);
        clearFirstOrbSetupPending();
        const spaces = await loadSpaces().catch(() => (space ? [space] : []));
        set({ space, spaces, config: loadConfig() });
        if (space) {
          await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
          void get().pullImportedCalendars();
        }
        get().setInviteShareOpen(true);
      } else {
        await renameSpaceRemote(current.id, clean);
        clearFirstOrbSetupPending();
        await get().refreshSpace();
      }
    },

    async renameCurrentSpace(name) {
      const current = get().space;
      if (!current || current.frozen) return;
      const clean = name.trim();
      if (!clean) return;
      await renameSpaceRemote(current.id, clean);
      await get().refreshSpace();
    },

    async leaveCurrentSpace() {
      const current = get().space;
      if (!current) return;
      await get().leaveSpace(current.id);
    },

    async leaveSpace(spaceId) {
      const listed = get().spaces;
      const current = get().space;
      const before = listed.length ? listed : current ? [current] : [];
      const live = before.filter((s) => !s.frozen);
      const leaving = before.find((s) => s.id === spaceId);
      const others = (leaving?.members ?? []).filter((m) => m.id !== leaving?.myId);
      const solo = others.length === 0 && !leaving?.partner2Id;
      if (solo && live.length <= 1) {
        get().toast('Keep at least one Orb');
        return;
      }
      const soloOrbs = live.filter(
        (s) => (s.members ?? []).filter((m) => m.id !== s.myId).length === 0 && !s.partner2Id,
      );
      const isPersonal =
        solo &&
        (leaving?.name.trim().toLowerCase() === 'personal' || soloOrbs.length <= 1);
      if (isPersonal) {
        get().toast(Copy.orbs.cannotDeletePersonal);
        return;
      }
      await leaveSpaceRemote(spaceId);
      const spaces = await loadSpaces();
      const active = spaces.filter((s) => !s.frozen);
      let target = get().space;
      if (!target || target.id === spaceId || target.frozen) {
        target = active[0] ?? null;
      }
      if (!target) {
        target = await ensureSpace();
      }
      const allSpaces = await loadSpaces().catch(() => (target ? [target] : []));
      if (target) {
        const config = { ...loadConfig(), spaceId: target.id };
        saveConfig(config);
        set({ space: target, spaces: allSpaces, config, detailId: null });
        await start(await supabaseBackend(config));
      }
      get().toast('Saved to Past Orbs');
    },

    async restorePastOrb(spaceId) {
      await restoreSpaceRemote(spaceId);
      const spaces = await loadSpaces();
      const restored = spaces.find((s) => s.id === spaceId);
      if (restored) {
        const config = { ...loadConfig(), spaceId: restored.id };
        saveConfig(config);
        set({ space: restored, spaces, config, detailId: null });
        await start(await supabaseBackend(config));
      } else {
        set({ spaces });
      }
      get().toast('Orb restored to active');
    },

    async deletePastOrb(spaceId) {
      await deleteFrozenSpaceRemote(spaceId);
      const spaces = await loadSpaces();
      const current = get().space;
      if (current?.id === spaceId) {
        const active = spaces.filter((s) => !s.frozen);
        let target = active[0] ?? null;
        if (!target) {
          target = await ensureSpace();
        }
        const allSpaces = await loadSpaces().catch(() => (target ? [target] : []));
        if (target) {
          const config = { ...loadConfig(), spaceId: target.id };
          saveConfig(config);
          set({ space: target, spaces: allSpaces, config, detailId: null });
          await start(await supabaseBackend(config));
        }
      } else {
        set({ spaces });
      }
      get().toast('Orb permanently deleted');
    },

    async removeMemberFromSpace(userId) {
      const current = get().space;
      if (!current) return;
      await removeSpaceMemberRemote(current.id, userId);
      await get().refreshSpace();
    },

    async signOutUser() {
      await signOut();
      set({ space: null, spaces: [], authPhase: 'signedOut', activities: [], logs: [] });
      backend?.dispose();
      backend = null;
      set({ ready: true, backendName: 'local', live: false, liveLabel: 'Signed out' });
    },

    async connect(next) {
      const config = { ...get().config, ...next };
      set({ config });
      saveConfig(config);
      if (!isSupabaseConfigured(config) && !authConfigured(config)) {
        get().toast('Needs a URL and a key');
        return;
      }
      // With URL+key only, go through the auth gate.
      if (authConfigured(config) && !config.spaceId) {
        set({ authPhase: 'signedOut', ready: true });
        get().toast('Now sign in with your email');
        return;
      }
      try {
        await start(await supabaseBackend(config));
        set({ authPhase: 'local' });
        get().toast('Connected — syncing live');
      } catch (err) {
        get().toast(err instanceof Error ? err.message : 'Could not connect');
        set({ authPhase: 'signedOut', ready: true, space: null });
      }
    },

    async disconnect() {
      // Keep project URL/key (build-time defaults); only drop the space binding.
      const config = { ...get().config, spaceId: '' };
      set({ config, space: null });
      saveConfig(config);
      set({ authPhase: 'signedOut' });
      backend?.dispose();
      backend = null;
      set({ ready: true, backendName: 'local', live: false, liveLabel: 'Signed out' });
      get().toast('Signed out');
    },

    async create(input) {
      if (!backend) throw new Error('Not connected — try signing out and back in');
      if (!canCompose(get().space)) {
        throw new Error('This is a copy from when you left — it can’t take new plans');
      }
      await backend.create(input);
    },

    async patch(id, changes) {
      if (!backend) throw new Error('Not connected — try signing out and back in');
      if (!canCompose(get().space)) {
        get().toast('This is a copy from when you left');
        return;
      }
      try {
        await backend.patch(id, changes);
      } catch (err) {
        get().toast(err instanceof Error ? err.message : 'Could not save');
      }
    },

    async moveToSpace(id, targetSpaceId) {
      if (!backend) throw new Error('Not connected — try signing out and back in');
      if (!canCompose(get().space)) {
        get().toast('This is a copy from when you left');
        return;
      }
      await backend.moveToSpace(id, targetSpaceId);
    },

    async remove(id) {
      if (!backend) throw new Error('Not connected — try signing out and back in');
      if (!canCompose(get().space)) {
        get().toast('This is a copy from when you left');
        return;
      }
      try {
        await backend.remove(id);
      } catch (err) {
        get().toast(err instanceof Error ? err.message : 'Could not delete');
      }
    },

    async suggestWhen(id, input) {
      if (!backend) throw new Error('Not connected — try signing out and back in');
      if (!isMatched(get().space) || !canCompose(get().space)) {
        throw new Error('Suggest a date when someone else is in this Orb');
      }
      try {
        await backend.suggestWhen(id, input);
      } catch (err) {
        get().toast(err instanceof Error ? err.message : 'Could not suggest');
        throw err;
      }
    },

    async acceptSuggestion(id) {
      if (!backend) throw new Error('Not connected — try signing out and back in');
      if (!canCompose(get().space)) {
        throw new Error('This is a copy from when you left');
      }
      try {
        await backend.acceptSuggestion(id);
      } catch (err) {
        get().toast(err instanceof Error ? err.message : 'Could not accept');
        throw err;
      }
    },

    async dismissSuggestion(id) {
      if (!backend) throw new Error('Not connected — try signing out and back in');
      if (!canCompose(get().space)) {
        throw new Error('This is a copy from when you left');
      }
      try {
        await backend.dismissSuggestion(id);
      } catch (err) {
        get().toast(err instanceof Error ? err.message : 'Could not clear suggestion');
        throw err;
      }
    },

    // A new screen arrives at the top, so the title starts expanded.
    setScreen: (screen) => set({ screen, navScroll: 0 }),
    setPicked: (picked) => set({ picked }),
    setCursor: (cursor) => set({ cursor }),
    setNavScroll: (navScroll) => {
      // Fires on every scroll frame, so don't wake subscribers unless the
      // value they render from actually moved.
      if (Math.abs(get().navScroll - navScroll) > 0.5) set({ navScroll });
    },
    openDetail: (detailId) => set({ detailId }),
    navigateToActivity: async (activityId, spaceId) => {
      if (!activityId) return;

      const currentSpace = get().space;
      if (spaceId && currentSpace && currentSpace.id !== spaceId) {
        try {
          await get().switchToSpace(spaceId);
        } catch {
          /* fallback to current space */
        }
      }

      let act = get().activities.find((a) => a.id === activityId);
      if (!act) {
        for (let i = 0; i < 5; i++) {
          await new Promise((r) => setTimeout(r, 200));
          act = get().activities.find((a) => a.id === activityId);
          if (act) break;
        }
      }

      if (!act) {
        get().toast('That plan is no longer here');
        return;
      }

      if (isPlan(act) && act.date_time) {
        const planDate = dtDate(act.date_time);
        if (planDate) {
          set({
            screen: 'calendar',
            picked: planDate,
            cursor: firstOfMonth(parseISO(planDate)),
          });
        } else {
          set({ screen: 'calendar' });
        }
      } else {
        set({ screen: 'bucket' });
      }

      get().openDetail(act.id);
    },
    openExternal: (externalId) => set({ externalId }),
    setAddOpen: (addOpen) => {
      if (addOpen && !canCompose(get().space)) {
        get().toast('This is a copy from when you left');
        return;
      }
      set({ addOpen });
    },
    openComposer: (composerMode, draft = null) => {
      if (!canCompose(get().space)) {
        get().toast('This is a copy from when you left');
        return;
      }
      set({ composerMode, composerDraft: draft, addOpen: false });
    },
    closeComposer: () => set({ composerMode: null, composerDraft: null }),
    setSearchOpen: (searchOpen) => set({ searchOpen }),
    setSettingsOpen: (settingsOpen) => set({ settingsOpen }),
    setInviteShareOpen: (inviteShareOpen) => set({ inviteShareOpen }),
    setInviteCode: (inviteCode) => set({ inviteCode }),
    setJoinOrbOpen: (joinOrbOpen) => set({ joinOrbOpen }),

    async joinOrb(rawCode: string) {
      const spaceId = await joinInvite(rawCode);
      clearFirstOrbSetupPending();
      const allSpaces = await loadSpaces().catch(() => []);
      const genericSolo = allSpaces.find(
        (s) =>
          (s.members ?? []).filter((m) => m.id !== s.myId).length === 0 &&
          !s.partner2Id &&
          isDefaultSpaceName(s.name),
      );
      if (genericSolo) {
        await renameSpaceRemote(genericSolo.id, 'Personal');
      }
      await get().switchToSpace(spaceId);
      const space = get().space;
      const name = space ? spaceOrbName(space) : '';
      get().toast(formatCopy(Copy.invite.joinedSuccess, { orb: name || 'this Orb' }));
      return space!;
    },

    updateConfig: (patch) => {
      const config = { ...get().config, ...patch };
      set({ config });
      saveConfig(config);
    },

    setExternal: (external) => set({ external }),

    async syncExternal(events, source) {
      if (!backend) throw new Error('Not connected');
      if (backend.name !== 'supabase') {
        throw new Error(
          'Calendar sharing needs a signed-in cloud Orb — sign out and sign back in, then import again',
        );
      }
      await backend.replaceExternal(events, source);
    },

    async pullImportedCalendars() {
      if (!backend || backend.name !== 'supabase') return;
      if (get().space?.frozen) return;
      const { pullImportedCalendars } = await import('./calSync');
      await pullImportedCalendars((events, source) => get().syncExternal(events, source)).catch(
        () => {
          /* overlay already in the database from last import */
        },
      );
    },

    async toggleExternalShare(id, shared) {
      if (!backend) throw new Error('Not connected');
      await backend.toggleExternalShare(id, shared);
      set({
        external: get().external.map((e) =>
          e.id === id ? { ...e, sharedWithSpace: shared } : e,
        ),
      });
    },

    toast: (text) => {
      const id = ++toastSeq;
      set({ toasts: [...get().toasts, { id, text }] });
      setTimeout(() => {
        set({ toasts: get().toasts.filter((t) => t.id !== id) });
      }, 2600);
    },
  };
});

/** Name of whichever partner created a row, for history lines. */
export function partnerName(config: Config, createdBy: string): string {
  // Local demo uses "0" / "1"; signed-in mode uses profile UUIDs.
  if (createdBy === '0' || createdBy === '1') {
    const idx = createdBy === '1' ? 1 : 0;
    return config.names[idx] || (idx === 0 ? 'Me' : 'You');
  }
  const space = useApp.getState().space;
  if (space) {
    if (createdBy === space.myId) return space.myName;
    const named = space.members?.find((m) => m.id === createdBy)?.name;
    if (named) return named;
    if (createdBy === space.partner1Id || createdBy === space.partner2Id) {
      return space.partnerName ?? config.names[1 - space.me] ?? 'Them';
    }
  }
  return 'Someone';
}
