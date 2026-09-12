import { create } from 'zustand';
import type { Activity, AuditLog, ExternalEvent } from './types';
import type { Backend, ExternalEventInput, NewActivity, WhenSuggestion } from './backend';
import { LocalBackend } from './backends/local';
import { loadConfig, saveConfig, isSupabaseConfigured, type Config } from './config';
import {
  authConfigured,
  currentSession,
  createSpace as createSpaceRemote,
  ensureSpace,
  leaveSpace as leaveSpaceRemote,
  loadSpaces,
  removeSpaceMember as removeSpaceMemberRemote,
  pendingInvite,
  signOut,
  switchSpace as switchSpaceRemote,
  type SpaceInfo,
} from './auth';
import { iso, todayISO } from './date';

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

/** Who this orb is with — or that it’s a leftover copy. */
export function spacePeopleLabel(space: SpaceInfo): string {
  if (space.frozen) return 'Copy from when you left';
  const others = (space.members ?? []).filter((m) => m.id !== space.myId);
  if (!others.length) return 'Just you';
  if (others.length === 1) return others[0]!.name;
  if (others.length === 2) return `${others[0]!.name} and ${others[1]!.name}`;
  return others.map((m) => m.name).join(', ');
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
  addSpace: (name?: string) => Promise<void>;
  leaveCurrentSpace: () => Promise<void>;
  removeMemberFromSpace: (userId: string) => Promise<void>;
  signOutUser: () => Promise<void>;
  setPasswordRecovery: (v: boolean) => void;
  connect: (next: Partial<Config>) => Promise<void>;
  disconnect: () => Promise<void>;

  create: (input: NewActivity) => Promise<void>;
  patch: (id: string, changes: Partial<Activity>) => Promise<void>;
  remove: (id: string) => Promise<void>;
  suggestWhen: (id: string, input: WhenSuggestion) => Promise<void>;
  acceptSuggestion: (id: string) => Promise<void>;
  dismissSuggestion: (id: string) => Promise<void>;

  setScreen: (s: Screen) => void;
  setPicked: (d: string) => void;
  setCursor: (d: string) => void;
  setNavScroll: (y: number) => void;
  openDetail: (id: string | null) => void;
  openExternal: (id: string | null) => void;
  setAddOpen: (v: boolean) => void;
  openComposer: (mode: Kind) => void;
  closeComposer: () => void;
  setSettingsOpen: (v: boolean) => void;
  setInviteShareOpen: (v: boolean) => void;
  setInviteCode: (code: string | null) => void;
  updateConfig: (patch: Partial<Config>) => void;
  setExternal: (events: ExternalEvent[]) => void;
  syncExternal: (events: ExternalEventInput[]) => Promise<void>;
  toast: (text: string) => void;
}

let backend: Backend | null = null;
let toastSeq = 0;

const firstOfMonth = (d: Date) => iso(new Date(d.getFullYear(), d.getMonth(), 1));

export const useApp = create<AppState>()((set, get) => {
  const handlers = {
    onActivities: (list: Activity[]) => set({ activities: list }),
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

  return {
    ready: false,
    authPhase: 'loading',
    backendName: 'local',
    live: false,
    liveLabel: 'On this device',

    activities: [],
    logs: [],
    external: [],

    config: loadConfig(),
    space: null,
    spaces: [],

    screen: 'calendar',
    picked: todayISO(),
    cursor: firstOfMonth(new Date()),
    navScroll: 0,
    detailId: null,
    externalId: null,
    composerMode: null,
    addOpen: false,
    settingsOpen: false,
    inviteShareOpen: false,
    inviteCode: pendingInvite(),
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
          const space = await ensureSpace();
          const spaces = await loadSpaces().catch(() => (space ? [space] : []));
          set({ space, spaces, config: loadConfig(), authPhase: 'signedIn' });
          if (space) {
            await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
            void import('./push').then((m) => m.syncPush());
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
      }
    },

    async switchToSpace(id) {
      const space = await switchSpaceRemote(id);
      const spaces = await loadSpaces().catch(() => (space ? [space] : []));
      set({ space, spaces, config: loadConfig(), detailId: null });
      if (space?.frozen) get().toast('This is a copy from when you left');
      if (space) {
        await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
      }
    },

    async addSpace(name) {
      const space = await createSpaceRemote(name);
      const spaces = await loadSpaces().catch(() => (space ? [space] : []));
      set({ space, spaces, config: loadConfig() });
      if (space) {
        await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
      }
    },

    async leaveCurrentSpace() {
      const current = get().space;
      if (!current) return;
      await leaveSpaceRemote(current.id);
      const spaces = await loadSpaces();
      const space = spaces.find((s) => s.id === loadConfig().spaceId) ?? spaces[0] ?? null;
      if (space) {
        const config = { ...loadConfig(), spaceId: space.id };
        saveConfig(config);
        set({ space, spaces, config, detailId: null });
        await start(await supabaseBackend(config));
      } else {
        const space = await ensureSpace();
        const next = await loadSpaces().catch(() => (space ? [space] : []));
        set({ space, spaces: next, config: loadConfig(), detailId: null });
        if (space) {
          await start(await supabaseBackend({ ...loadConfig(), spaceId: space.id }));
        }
      }
      if (get().space?.frozen) get().toast('This is a copy from when you left');
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
    openExternal: (externalId) => set({ externalId }),
    setAddOpen: (addOpen) => {
      if (addOpen && !canCompose(get().space)) {
        get().toast('This is a copy from when you left');
        return;
      }
      set({ addOpen });
    },
    openComposer: (composerMode) => {
      if (!canCompose(get().space)) {
        get().toast('This is a copy from when you left');
        return;
      }
      set({ composerMode, addOpen: false });
    },
    closeComposer: () => set({ composerMode: null }),
    setSettingsOpen: (settingsOpen) => set({ settingsOpen }),
    setInviteShareOpen: (inviteShareOpen) => set({ inviteShareOpen }),
    setInviteCode: (inviteCode) => set({ inviteCode }),

    updateConfig: (patch) => {
      const config = { ...get().config, ...patch };
      set({ config });
      saveConfig(config);
    },

    setExternal: (external) => set({ external }),

    async syncExternal(events) {
      if (!backend) throw new Error('Not connected');
      if (backend.name !== 'supabase') {
        throw new Error(
          'Calendar sharing needs a signed-in cloud Orb — sign out and sign back in, then import again',
        );
      }
      await backend.replaceExternal(events);
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
