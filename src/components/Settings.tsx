import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import ActionSheet from './ActionSheet';
import Switch from './Switch';
import GcalPicker from './GcalPicker';
import OrbKindForm from './OrbKindForm';
import OrbFaces, { orbFaceChips } from './OrbFaces';
import { useApp, spaceOrbName, spacePeopleLabel } from '../lib/store';
import {
  currentEmail,
  isDefaultSpaceName,
  isHomeOrb,
  soloNotebookTitle,
  updateDisplayName,
  type SpaceInfo,
} from '../lib/auth';
import {
  clearGoogleToken,
  connectGoogle,
  googleToken,
  listGoogleCalendars,
} from '../lib/gcal';
import {
  clearOutlookTokens,
  connectOutlook,
  consumeOutlookRedirect,
  listOutlookCalendars,
  msClientId,
  ensureOutlookToken,
} from '../lib/outlook';
import {
  chooseCalendars,
  chosenCalendars,
  lastSynced,
  updatedAgo,
  type ImportedCalendar,
} from '../lib/calendars';
import { forgetSource } from '../lib/myCalendar';
import {
  disablePush,
  enablePush,
  pushState,
  registerPush,
  syncPush,
  type PushState,
} from '../lib/push';
import { Copy, formatCopy } from '../lib/copy';
import { faceColor } from '../lib/tint';
import { Button, Avatar, Card, Input, FormGroup, FormRow, Pill, PickRow } from '../ui';
import { durationSheetSlide, durationFade, easeIos, easeSheet, xPage } from '../ui/motion';
import {
  ALL_DAY_ALERTS,
  DEFAULT_PREFS,
  SUMMARY_TIMES,
  TIMED_ALERTS,
  loadOrbMuted,
  loadPrefs,
  savePrefs,
  setOrbMuted,
  type NotificationPrefs,
} from '../lib/alerts';
import f from './Form.module.css';
import ui from './Settings.module.css';
import auth from './Auth.module.css';

function pushCopy(state: PushState): string {
  switch (state) {
    case 'unsupported':
      return 'This browser can’t show notifications';
    case 'ios-install':
      return 'Open Fordays from the Home Screen icon to turn notifications on';
    case 'denied':
      return 'Blocked. Turn them on in iPhone Settings → Fordays → Notifications';
    case 'granted-idle':
      return 'Allowed. Turn the switch on to finish';
    case 'on':
      return 'On. You’ll hear when someone adds to Someday, makes a plan, changes the day, or joins';
    default:
      return 'Hear when someone adds to Someday, makes a plan, changes the day, or joins';
  }
}

function firstLetter(name: string): string {
  return (name.trim()[0] ?? '?').toUpperCase();
}

type SettingsConfirm = {
  heading: string;
  note: string;
  action: string;
  cancel: string;
  run: () => Promise<void>;
};

/* Settings is a stack of pages, like iOS Settings: each has its own title
   and the back button names the page underneath. */
type WebSource = 'google' | 'outlook';

type Page =
  | { k: 'main' }
  | { k: 'account' }
  | { k: 'orb'; id: string }
  | { k: 'newOrb'; withPeople: boolean }
  | { k: 'pastOrbs' }
  | { k: 'calendars' }
  | { k: 'calPicker' }
  | { k: 'notifications' };

type SearchHit = {
  id: string;
  label: string;
  where: string;
  words: string;
  go: () => void;
};

function Chevron() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path d="M15 5 8 12l7 7" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" strokeLinecap="round" />
    </svg>
  );
}

function CalendarIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </svg>
  );
}

function BellIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

function HistoryIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="10" />
      <polyline points="12 6 12 12 16 14" />
    </svg>
  );
}

function SignOutIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" y1="12" x2="9" y2="12" />
    </svg>
  );
}

/** Who's in an Orb, you first: "Just you", "You and Tess", "You, Tess and Kofi". */
function peopleNote(orb: SpaceInfo): string {
  const others = (orb.members ?? []).filter((m) => m.id !== orb.myId).map((m) => m.name);
  if (!others.length) return orb.partnerName ? `You and ${orb.partnerName}` : 'Just you';
  const all = ['You', ...others];
  return `${all.slice(0, -1).join(', ')} and ${all[all.length - 1]}`;
}

/** A solo Orb that is someone's home base: it can't be left or shared. */
function isPersonal(orb: SpaceInfo, activeOrbs: SpaceInfo[]): boolean {
  return isHomeOrb({ ...orb, frozen: false }, activeOrbs);
}

export default function Settings() {
  const open = useApp((st) => st.settingsOpen);
  const setOpen = useApp((st) => st.setSettingsOpen);
  const startOrbId = useApp((st) => st.settingsOrbId);
  const screen = useApp((st) => st.screen);
  const config = useApp((st) => st.config);
  const updateConfig = useApp((st) => st.updateConfig);
  const signOutUser = useApp((st) => st.signOutUser);
  const authPhase = useApp((st) => st.authPhase);
  const space = useApp((st) => st.space);
  const syncCalendarSource = useApp((st) => st.syncCalendarSource);
  const reloadMine = useApp((st) => st.reloadMine);
  const myEvents = useApp((st) => st.external);
  const setInviteShareOpen = useApp((st) => st.setInviteShareOpen);
  const setJoinOrbOpen = useApp((st) => st.setJoinOrbOpen);
  const refreshSpace = useApp((st) => st.refreshSpace);
  const toast = useApp((st) => st.toast);
  const spaces = useApp((st) => st.spaces);
  const switchToSpace = useApp((st) => st.switchToSpace);
  const addSpace = useApp((st) => st.addSpace);
  const renameSpace = useApp((st) => st.renameSpace);
  const leaveSpace = useApp((st) => st.leaveSpace);
  const deletePastOrb = useApp((st) => st.deletePastOrb);
  const removeMember = useApp((st) => st.removeMember);

  const signedIn = authPhase === 'signedIn';
  const [stack, setStack] = useState<Page[]>([{ k: 'main' }]);
  const page = stack[stack.length - 1]!;
  const push = (p: Page) => setStack((st) => [...st, p]);
  const pop = () => setStack((st) => (st.length > 1 ? st.slice(0, -1) : st));
  const scrollRef = useRef<HTMLDivElement>(null);

  const [query, setQuery] = useState('');
  const [email, setEmail] = useState<string | null>(null);
  const [myName, setMyName] = useState(space?.myName ?? config.names[config.me]);
  const [orbDraft, setOrbDraft] = useState('');
  const [gcalOn, setGcalOn] = useState(Boolean(chosenCalendars('google').length || googleToken()));
  const [outlookOn, setOutlookOn] = useState(chosenCalendars('outlook').length > 0);
  const [chosen, setChosen] = useState<Record<WebSource, ImportedCalendar[]>>(() => ({
    google: chosenCalendars('google'),
    outlook: chosenCalendars('outlook'),
  }));
  const [calPicker, setCalPicker] = useState<{
    source: WebSource;
    items: ImportedCalendar[];
  } | null>(null);
  const [calBusy, setCalBusy] = useState(false);
  const [bell, setBell] = useState<PushState>('default');
  const [bellBusy, setBellBusy] = useState(false);
  const [spaceBusy, setSpaceBusy] = useState(false);
  const [confirm, setConfirm] = useState<SettingsConfirm | null>(null);
  const [prefs, setPrefs] = useState<NotificationPrefs>(DEFAULT_PREFS);
  const [muted, setMuted] = useState(false);

  const allOrbs = spaces.length ? spaces : space ? [space] : [];
  const activeOrbs = allOrbs.filter((s) => !s.frozen);
  const pastOrbs = allOrbs.filter((s) => s.frozen);
  const pageOrb = page.k === 'orb' ? (allOrbs.find((o) => o.id === page.id) ?? null) : null;

  // Each new page starts at the top, like a pushed screen.
  useEffect(() => {
    scrollRef.current?.scrollTo({ top: 0 });
  }, [stack.length]);

  useEffect(() => {
    if (page.k === 'notifications') void loadPrefs().then(setPrefs);
  }, [page.k]);

  useEffect(() => {
    if (!pageOrb) return;
    setOrbDraft(isDefaultSpaceName(pageOrb.name) ? '' : pageOrb.name);
    void loadOrbMuted(pageOrb.id).then(setMuted);
    // Only when a different Orb's page comes up, not on every refresh.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pageOrb?.id]);

  // Save as they change, like iOS Settings; put it back if it didn't take.
  const changePrefs = (patch: Partial<NotificationPrefs>) => {
    const before = prefs;
    const next = { ...prefs, ...patch };
    setPrefs(next);
    void savePrefs(next).catch(() => {
      setPrefs(before);
      toast('Couldn’t save that. Check your connection and try again.');
    });
  };

  useEffect(() => {
    if (!open) return;
    // From the switcher, an Orb's page stands alone: back goes straight home.
    setStack(startOrbId ? [{ k: 'orb', id: startOrbId }] : [{ k: 'main' }]);
    setQuery('');
    setMyName(space?.myName ?? config.names[config.me]);
    setConfirm(null);
    void currentEmail().then(setEmail);
    setGcalOn(Boolean(chosenCalendars('google').length || googleToken()));
    setOutlookOn(chosenCalendars('outlook').length > 0);
    setChosen({ google: chosenCalendars('google'), outlook: chosenCalendars('outlook') });
    void registerPush().then(() => setBell(pushState()));
    void syncPush().then(() => setBell(pushState()));
    void (async () => {
      const redirected = await consumeOutlookRedirect();
      const token = redirected || (await ensureOutlookToken());
      if (!token || chosenCalendars('outlook').length) return;
      setOutlookOn(true);
      try {
        const calendars = await listOutlookCalendars(token);
        if (calendars.length) {
          setCalPicker({ source: 'outlook', items: calendars });
          setStack([{ k: 'main' }, { k: 'calendars' }, { k: 'calPicker' }]);
        }
      } catch {
        /* wait for an explicit connect */
      }
    })();
    // Fresh each time Settings opens.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // A sheet that leaves the page scrollable behind it feels like a web page.
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  const setOn = (source: WebSource, on: boolean) =>
    source === 'google' ? setGcalOn(on) : setOutlookOn(on);

  const sourceName = (source: WebSource) =>
    source === 'google' ? Copy.availability.googleCalendar : Copy.availability.outlookCalendar;

  async function listCalendars(source: WebSource): Promise<ImportedCalendar[] | null> {
    const token = source === 'google' ? googleToken() : await ensureOutlookToken();
    if (!token) {
      toast(source === 'google' ? 'Connect Google again' : 'Connect Outlook again');
      setOn(source, false);
      return null;
    }
    return source === 'google' ? listGoogleCalendars(token) : listOutlookCalendars(token);
  }

  async function openPicker(source: WebSource) {
    setCalBusy(true);
    try {
      const items = await listCalendars(source);
      if (!items) return;
      setCalPicker({ source, items });
      push({ k: 'calPicker' });
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t list calendars');
    } finally {
      setCalBusy(false);
    }
  }

  /* Tick boxes saved: sync the ticked ones, forget the rest. */
  async function saveChoice(source: WebSource, list: ImportedCalendar[]) {
    if (!list.length) {
      await disconnect(source);
      return;
    }
    chooseCalendars(source, list);
    setChosen((c) => ({ ...c, [source]: list }));
    setOn(source, true);
    setCalBusy(true);
    try {
      const n = await syncCalendarSource(source);
      toast(n ? `${n} events from ${sourceName(source)}` : 'Nothing in the next few months');
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t load that calendar');
    } finally {
      setCalBusy(false);
    }
  }

  async function refreshSource(source: WebSource) {
    setCalBusy(true);
    try {
      await syncCalendarSource(source);
      toast('Up to date');
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t refresh');
    } finally {
      setCalBusy(false);
    }
  }

  /* Off: the token goes, and every event from that source with it. */
  async function disconnect(source: WebSource) {
    if (source === 'google') clearGoogleToken();
    else clearOutlookTokens();
    setChosen((c) => ({ ...c, [source]: [] }));
    setOn(source, false);
    setCalPicker(null);
    try {
      await forgetSource(source);
      await reloadMine();
      toast(`${sourceName(source)} disconnected`);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t clear those events');
    }
  }

  async function connect(source: WebSource) {
    if (source === 'outlook' && !msClientId()) {
      toast('Outlook isn’t available yet');
      return;
    }
    setCalBusy(true);
    try {
      const token = source === 'google' ? await connectGoogle() : await connectOutlook();
      const items =
        source === 'google' ? await listGoogleCalendars(token) : await listOutlookCalendars(token);
      if (!items.length) {
        setOn(source, false);
        toast(`No calendars found on that ${source === 'google' ? 'Google' : 'Outlook'} account`);
        return;
      }
      setOn(source, true);
      setCalPicker({ source, items });
      push({ k: 'calPicker' });
    } catch (err) {
      setOn(source, false);
      toast(err instanceof Error ? err.message : `${source === 'google' ? 'Google' : 'Outlook'} connect failed`);
    } finally {
      setCalBusy(false);
    }
  }

  function closeCalPicker() {
    const source = calPicker?.source;
    setCalPicker(null);
    pop();
    // Backed out of a first connect: nothing was ticked, so let go of the account.
    if (source && !chosenCalendars(source).length) {
      if (source === 'google') clearGoogleToken();
      else clearOutlookTokens();
      setOn(source, false);
    }
  }


  async function persistOrbName(orb: SpaceInfo) {
    if (orb.frozen) return;
    const current = isDefaultSpaceName(orb.name) ? '' : orb.name.trim();
    const next = orbDraft.trim();
    if (!next) {
      setOrbDraft(current);
      return;
    }
    if (next === current) return;
    try {
      await renameSpace(orb.id, next);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t rename this Orb');
      setOrbDraft(current);
    }
  }

  async function openOrb(orb: SpaceInfo) {
    setOpen(false);
    if (orb.id === space?.id) return;
    try {
      await switchToSpace(orb.id);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t switch');
    }
  }

  /* Inviting shares that Orb's code and can add a first idea to it, so it
     happens from inside the Orb: switch there first when it isn't open. */
  async function inviteTo(orb: SpaceInfo) {
    if (orb.frozen) return;
    if (isPersonal(orb, activeOrbs)) {
      toast(Copy.orbs.cannotInviteToPersonal);
      push({ k: 'newOrb', withPeople: true });
      return;
    }
    setOpen(false);
    if (orb.id !== space?.id) {
      try {
        await switchToSpace(orb.id);
      } catch (err) {
        toast(err instanceof Error ? err.message : 'Couldn’t switch');
        return;
      }
    }
    setInviteShareOpen(true);
  }

  async function handleCreateOrb(name: string, withPeople: boolean) {
    if (spaceBusy) return;
    setSpaceBusy(true);
    try {
      await addSpace(name, withPeople);
      setOpen(false);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t make an Orb');
    } finally {
      setSpaceBusy(false);
    }
  }

  function askLeave(orb: SpaceInfo) {
    if (isPersonal(orb, activeOrbs)) {
      toast(Copy.orbs.cannotDeletePersonal);
      return;
    }
    const solo = (orb.members ?? []).length <= 1;
    setConfirm({
      heading: solo ? Copy.orbs.deleteSoloTitle : Copy.orbs.leaveSharedTitle,
      note: solo ? Copy.orbs.deleteSoloBody : Copy.orbs.leaveSharedBody,
      action: solo ? Copy.orbs.deleteSoloAction : Copy.orbs.leaveAction,
      cancel: Copy.orbs.stay,
      run: async () => {
        setSpaceBusy(true);
        try {
          await leaveSpace(orb.id);
          setConfirm(null);
          if (stack.length > 1) pop();
          else setOpen(false);
        } catch (err) {
          toast(err instanceof Error ? err.message : 'Couldn’t leave');
        } finally {
          setSpaceBusy(false);
        }
      },
    });
  }

  function askRemove(orb: SpaceInfo, memberId: string, memberName: string) {
    setConfirm({
      heading: formatCopy(Copy.orbs.removeTitle, { name: memberName }),
      note: Copy.orbs.removeBody,
      action: `Remove ${memberName}`,
      cancel: Copy.orbs.keepThem,
      run: async () => {
        setSpaceBusy(true);
        try {
          await removeMember(orb.id, memberId);
          setConfirm(null);
          toast(`${memberName} is out — they have a copy`);
        } catch (err) {
          toast(err instanceof Error ? err.message : 'Couldn’t remove');
        } finally {
          setSpaceBusy(false);
        }
      },
    });
  }

  function askPurge(id: string) {
    setConfirm({
      heading: Copy.orbs.deletePermanentTitle,
      note: Copy.orbs.deletePermanentBody,
      action: Copy.orbs.deletePermanent,
      cancel: Copy.orbs.keep,
      run: async () => {
        if (spaceBusy) return;
        setSpaceBusy(true);
        try {
          await deletePastOrb(id);
          setConfirm(null);
          if (stack.length <= 1) setOpen(false);
          else if (page.k === 'orb' || pastOrbs.length <= 1) pop();
        } catch (err) {
          toast(err instanceof Error ? err.message : 'Couldn’t delete Orb');
        } finally {
          setSpaceBusy(false);
        }
      },
    });
  }

  function askSignOut() {
    setConfirm({
      heading: 'Sign out of Fordays?',
      note: 'Your Orbs stay as they are. Sign back in any time.',
      action: 'Sign out',
      cancel: 'Cancel',
      run: async () => {
        setConfirm(null);
        setOpen(false);
        await signOutUser();
      },
    });
  }

  function titleOf(p: Page): string {
    switch (p.k) {
      case 'main':
        return 'Settings';
      case 'account':
        return 'Account';
      case 'orb': {
        const orb = allOrbs.find((o) => o.id === p.id);
        return (orb && spaceOrbName(orb)) || Copy.orbs.thisOrb;
      }
      case 'newOrb':
        return Copy.orbs.startNew;
      case 'pastOrbs':
        return Copy.orbs.pastOrbs;
      case 'calendars':
        return 'Calendars';
      case 'calPicker':
        return 'Choose a calendar';
      case 'notifications':
        return 'Notifications';
    }
  }

  const tabLabel =
    screen === 'calendar' ? Copy.tabs.plans : screen === 'memories' ? Copy.tabs.memories : Copy.tabs.ideas;
  const backLabel = stack.length > 1 ? titleOf(stack[stack.length - 2]!) : tabLabel;
  const onBack = () => {
    if (page.k === 'calPicker') closeCalPicker();
    else if (stack.length > 1) pop();
    else setOpen(false);
  };

  /* Every row you might look for, with the words people use for it. */
  const hits = useMemo<SearchHit[]>(() => {
    const list: SearchHit[] = [
      {
        id: 'account',
        label: 'Account',
        where: 'Your name and email',
        words: 'account profile name email you me photo',
        go: () => push({ k: 'account' }),
      },
      {
        id: 'calendars',
        label: 'Calendars',
        where: 'Google and Outlook',
        words: 'calendars calendar google outlook import external busy events',
        go: () => push({ k: 'calendars' }),
      },
      {
        id: 'notifications',
        label: 'Notifications',
        where: 'Push, alerts, morning summary, quiet overnight',
        words: 'notifications push alerts alert reminders remind summary morning quiet night sound',
        go: () => push({ k: 'notifications' }),
      },
      {
        id: 'new',
        label: Copy.orbs.startNew,
        where: 'Orbs',
        words: 'new orb create start make',
        go: () => push({ k: 'newOrb', withPeople: false }),
      },
      {
        id: 'join',
        label: Copy.orbs.joinWithCode,
        where: 'Orbs',
        words: 'join code invite link',
        go: () => {
          setOpen(false);
          setJoinOrbOpen(true);
        },
      },
      {
        id: 'signout',
        label: 'Sign out',
        where: 'Settings',
        words: 'sign out log out logout signout leave account',
        go: askSignOut,
      },
    ];
    if (pastOrbs.length) {
      list.push({
        id: 'past',
        label: Copy.orbs.pastOrbs,
        where: 'Orbs',
        words: 'past orbs archive history left old frozen deleted',
        go: () => push({ k: 'pastOrbs' }),
      });
    }
    for (const orb of activeOrbs) {
      const name = spaceOrbName(orb) || Copy.orbs.thisOrb;
      const shared = (orb.members ?? []).length > 1;
      const toOrb = () => push({ k: 'orb', id: orb.id });
      list.push({
        id: `orb-${orb.id}`,
        label: name,
        where: `Orbs · ${peopleNote(orb)}`,
        words: `${name} orb rename name people members`,
        go: toOrb,
      });
      if (shared) {
        list.push(
          { id: `invite-${orb.id}`, label: `Invite to ${name}`, where: name, words: 'invite add people share link', go: toOrb },
          { id: `mute-${orb.id}`, label: `Mute ${name}`, where: name, words: 'mute silence quiet notifications', go: toOrb },
          { id: `leave-${orb.id}`, label: `Leave ${name}`, where: name, words: 'leave exit quit remove', go: toOrb },
        );
      }
    }
    return list;
    // push and the confirm helpers are stable enough for a list rebuilt per render
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeOrbs.length, pastOrbs.length, spaces, space?.id]);

  const q = query.trim().toLowerCase();
  const found = q
    ? hits.filter((h) => `${h.label} ${h.where} ${h.words}`.toLowerCase().includes(q))
    : [];

  function renderMain() {
    return (
      <>
        <label className={ui.searchBox}>
          <span className={ui.searchIcon}>
            <SearchIcon />
          </span>
          <input
            className={ui.searchInput}
            type="search"
            placeholder="Search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            enterKeyHint="search"
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
          />
        </label>

        {q ? (
          found.length ? (
            <FormGroup className={ui.section}>
              {found.map((h) => (
                <FormRow
                  key={h.id}
                  label={h.label}
                  note={h.where}
                  onClick={() => {
                    setQuery('');
                    h.go();
                  }}
                >
                  <span className={f.hint}>›</span>
                </FormRow>
              ))}
            </FormGroup>
          ) : (
            <p className={ui.noResults}>No settings match “{query.trim()}”</p>
          )
        ) : (
          <>
            {space?.frozen && (
              <div className={`${ui.frozenBanner} ${ui.section}`}>
                <p className={ui.frozenBannerText}>{Copy.orbs.viewingFrozenBanner}</p>
                {activeOrbs[0] && (
                  <button
                    type="button"
                    className={ui.frozenBannerBtn}
                    onClick={() => void openOrb(activeOrbs[0]!)}
                  >
                    {Copy.orbs.switchBackToActive}
                  </button>
                )}
              </div>
            )}

            <FormGroup className={ui.section}>
              <FormRow
                label={space?.myName || config.names[config.me] || 'You'}
                note={email ?? 'Your name and email'}
                icon={
                  <Avatar
                    name={space?.myName || config.names[config.me] || 'Me'}
                    personId={space?.myId}
                    size="md"
                  />
                }
                className={ui.youRow}
                onClick={() => push({ k: 'account' })}
              >
                <span className={f.hint}>›</span>
              </FormRow>
            </FormGroup>

            <FormGroup header={Copy.orbs.yourOrbs} className={ui.section}>
              {activeOrbs.map((orb) => (
                <FormRow
                  key={orb.id}
                  label={spaceOrbName(orb) || Copy.orbs.thisOrb}
                  note={peopleNote(orb)}
                  icon={
                    <span className={ui.orbRowIcon}>
                      <OrbFaces faces={orbFaceChips(orb)} small />
                    </span>
                  }
                  className={ui.orbRow}
                  onClick={() => push({ k: 'orb', id: orb.id })}
                >
                  <span className={f.hint}>{orb.id === space?.id ? 'Current ›' : '›'}</span>
                </FormRow>
              ))}
              {pastOrbs.length > 0 && (
                <FormRow
                  label={Copy.orbs.pastOrbs}
                  note={Copy.orbs.pastOrbsSub}
                  icon={<HistoryIcon />}
                  onClick={() => push({ k: 'pastOrbs' })}
                >
                  <div className={ui.rowTrail}>
                    <Pill variant="neutral" size="sm">{pastOrbs.length}</Pill>
                    <span className={f.hint}>›</span>
                  </div>
                </FormRow>
              )}
            </FormGroup>

            <FormGroup className={ui.section}>
              <FormRow label="Calendars" icon={<CalendarIcon />} onClick={() => push({ k: 'calendars' })}>
                <span className={f.hint}>›</span>
              </FormRow>
              <FormRow label="Notifications" icon={<BellIcon />} onClick={() => push({ k: 'notifications' })}>
                <span className={f.hint}>›</span>
              </FormRow>
            </FormGroup>

            {signedIn && (
              <FormGroup className={ui.section}>
                <FormRow label="Sign out" icon={<SignOutIcon />} destructive onClick={askSignOut} />
              </FormGroup>
            )}
          </>
        )}
      </>
    );
  }

  function renderOrb(orb: SpaceInfo) {
    const members = orb.members ?? [];
    const solo = members.length <= 1;
    const personal = isPersonal(orb, activeOrbs);
    const current = orb.id === space?.id;
    const removable =
      !orb.frozen && orb.myRole === 'admin' && members.length >= 3
        ? members.filter((m) => m.id !== orb.myId)
        : [];
    return (
      <>
        {!current && !orb.frozen && (
          <Button variant="secondary" fullWidth className={ui.section} onClick={() => void openOrb(orb)}>
            Open this Orb
          </Button>
        )}

        <section className={ui.section}>
          <span className={ui.label}>{Copy.orbs.orbName}</span>
          <Input
            value={orbDraft}
            disabled={orb.frozen || spaceBusy}
            onChange={(e) => setOrbDraft(e.target.value)}
            onBlur={() => void persistOrbName(orb)}
            placeholder={
              solo
                ? soloNotebookTitle(orb.myName) || Copy.orbs.personalPlaceholder
                : Copy.orbs.crewPlaceholder
            }
            autoComplete="off"
            autoCapitalize="words"
          />

          <span className={`${ui.label} ${ui.subLabel}`}>{Copy.orbs.people}</span>
          <div className={ui.peopleCard}>
            <div className={ui.peopleRail}>
              {!orb.frozen && !personal && (
                <button
                  type="button"
                  className={`${ui.person} ${ui.personButton}`}
                  onClick={() => void inviteTo(orb)}
                >
                  <span className={`${ui.personFace} ${ui.personFaceAdd}`} aria-hidden>
                    +
                  </span>
                  <span className={ui.personName}>Invite</span>
                  <span className={ui.personTag}>More</span>
                </button>
              )}

              {members.map((member) => {
                const mine = member.id === orb.myId;
                const canRemove = removable.some((m) => m.id === member.id);
                return (
                  <div key={member.id} className={ui.person}>
                    <div className={ui.personWrap}>
                      <span
                        className={ui.personFace}
                        style={{ background: faceColor(member.id) }}
                        aria-hidden
                      >
                        {firstLetter(member.name)}
                      </span>
                      {canRemove && (
                        <button
                          type="button"
                          className={ui.removeBadge}
                          title={`Remove ${member.name}`}
                          aria-label={`Remove ${member.name}`}
                          onClick={(e) => {
                            e.stopPropagation();
                            askRemove(orb, member.id, member.name);
                          }}
                        >
                          –
                        </button>
                      )}
                    </div>
                    <span className={ui.personName}>{member.name}</span>
                    <span className={ui.personTag}>{mine ? 'You' : ''}</span>
                  </div>
                );
              })}
            </div>

            {personal && (
              <div className={ui.personalNoteRow}>
                <p className={ui.personalNoteText}>{Copy.orbs.personalPrivateNote}</p>
                <button
                  type="button"
                  className={ui.startSharedBtn}
                  onClick={() => push({ k: 'newOrb', withPeople: true })}
                >
                  + {Copy.orbs.startSharedOrb}
                </button>
              </div>
            )}
          </div>
          <p className={ui.help}>{Copy.orbs.descriptor}</p>
          {orb.frozen && <p className={ui.frozen}>{Copy.orbs.frozenNotice}</p>}

          {!orb.frozen && !solo && (
            <FormGroup footer="Alerts you set on plans still ring." style={{ marginTop: 'var(--space-4)' }}>
              <FormRow label="Mute this Orb" icon={<BellIcon />}>
                <Switch
                  on={muted}
                  label="Mute this Orb"
                  onChange={(on) => {
                    setMuted(on);
                    void setOrbMuted(orb.id, on).catch(() => {
                      setMuted(!on);
                      toast('Couldn’t save that. Check your connection and try again.');
                    });
                  }}
                />
              </FormRow>
            </FormGroup>
          )}

          {removable.map((member) => (
            <button
              key={`ask-${member.id}`}
              type="button"
              className={ui.textLink}
              disabled={spaceBusy}
              onClick={() => askRemove(orb, member.id, member.name)}
            >
              Remove {member.name}
            </button>
          ))}

          {!orb.frozen && !personal ? (
            <button
              type="button"
              className={ui.textLink}
              disabled={spaceBusy}
              onClick={() => askLeave(orb)}
            >
              {solo ? Copy.orbs.deleteSoloAction : Copy.orbs.leaveAction}
            </button>
          ) : orb.frozen ? (
            <button
              type="button"
              className={`${ui.textLink} ${ui.pastOrbBtnDanger}`}
              disabled={spaceBusy}
              onClick={() => askPurge(orb.id)}
            >
              {Copy.orbs.deletePermanent}
            </button>
          ) : null}
        </section>
      </>
    );
  }

  function renderAccount() {
    return (
      <FormGroup className={ui.section} footer="Your name shows on your face in every Orb.">
        <div className={ui.profileRow}>
          <Avatar
            name={myName || space?.myName || 'Me'}
            personId={space?.myId}
            size="md"
          />
          <input
            className={ui.profileInput}
            value={myName}
            onChange={(e) => setMyName(e.target.value)}
            onBlur={() => {
              void (async () => {
                const clean = myName.trim();
                if (!clean || clean === space?.myName) return;
                try {
                  await updateDisplayName(clean);
                  updateConfig({ names: loadNames(config.me, clean, config.names) });
                  await refreshSpace();
                } catch (err) {
                  toast(err instanceof Error ? err.message : 'Couldn’t save name');
                }
              })();
            }}
            placeholder="Aline"
          />
        </div>
        {email && (
          <FormRow label="Email">
            <span className={f.hint}>{email}</span>
          </FormRow>
        )}
      </FormGroup>
    );
  }

  function renderNewOrb(withPeople: boolean) {
    return (
      <div className={ui.section}>
        <p className={auth.lead}>{Copy.orbs.setupLead}</p>
        <OrbKindForm
          key={withPeople ? 'with-people' : 'just-you'}
          knobId="orb-create-kind-knob"
          initialWithPeople={withPeople}
          onSubmit={handleCreateOrb}
        />
      </div>
    );
  }

  function renderPastOrbs() {
    return (
      <div className={`${ui.pastOrbList} ${ui.section}`}>
        {pastOrbs.map((pOrb) => {
          const pFaces = orbFaceChips(pOrb);
          const isCurrent = pOrb.id === space?.id;
          return (
            <Card key={pOrb.id} variant="sunk" padding="md">
              <div className={ui.pastOrbTop}>
                <div className={ui.pastOrbInfo}>
                  <span className={ui.pastOrbName}>{spacePeopleLabel(pOrb) || ' '}</span>
                </div>
                <div className={ui.orbFaceStack}>
                  {pFaces.slice(0, 3).map((fc, idx) => (
                    <span
                      key={fc.key}
                      className={ui.orbMiniFace}
                      style={{ zIndex: 4 - idx, background: faceColor(fc.key) }}
                      aria-hidden
                    >
                      {fc.letter}
                    </span>
                  ))}
                </div>
              </div>

              <div className={ui.pastOrbActions}>
                {isCurrent ? (
                  <Button variant="primary" size="sm" disabled>
                    Currently viewing
                  </Button>
                ) : (
                  <Button
                    variant="secondary"
                    size="sm"
                    disabled={spaceBusy}
                    onClick={() => void openOrb(pOrb)}
                  >
                    View
                  </Button>
                )}

                <Button
                  variant="ghost"
                  size="sm"
                  disabled={spaceBusy}
                  onClick={() => askPurge(pOrb.id)}
                >
                  <span style={{ color: 'var(--rose-ink)' }}>{Copy.orbs.deletePermanent}</span>
                </Button>
              </div>
            </Card>
          );
        })}
      </div>
    );
  }

  function renderCalendars() {
    const home = activeOrbs.find((o) => isHomeOrb(o, activeOrbs));
    const sources: WebSource[] = ['google', 'outlook'];
    return (
      <div className={ui.section}>
        <p className={ui.calLead}>
          {formatCopy(Copy.availability.yoursOnly, { orb: home ? spaceOrbName(home) : 'your own Orb' })}
        </p>
        {sources.map((source) => {
          const on = source === 'google' ? gcalOn : outlookOn;
          const list = chosen[source];
          const synced = lastSynced(source);
          const count = myEvents.filter((e) => e.source === source).length;
          return (
            <FormGroup
              key={source}
              footer={
                on && list.length
                  ? `${count === 1 ? '1 event' : `${count} events`}${synced ? ` · ${updatedAgo(synced.at)}` : ''}`
                  : undefined
              }
              style={source === 'outlook' ? { marginTop: 'var(--space-5)' } : undefined}
            >
              <FormRow label={sourceName(source)} icon={<CalendarIcon />}>
                <Switch
                  on={on}
                  disabled={calBusy}
                  label={`Connect ${sourceName(source)}`}
                  onChange={(next) => void (next ? connect(source) : disconnect(source))}
                />
              </FormRow>
              {on && (
                <FormRow
                  label={list.length ? list.map((c) => c.summary).join(', ') : 'Choose calendars'}
                  onClick={calBusy ? undefined : () => void openPicker(source)}
                >
                  <span className={f.hint}>{list.length ? 'Change ›' : '›'}</span>
                </FormRow>
              )}
              {on && list.length > 0 && (
                <FormRow
                  label="Refresh"
                  onClick={calBusy ? undefined : () => void refreshSource(source)}
                >
                  <span className={f.hint}>{calBusy ? '…' : '›'}</span>
                </FormRow>
              )}
            </FormGroup>
          );
        })}
        <p className={ui.calNote}>{Copy.availability.settingsNoteWeb}</p>
      </div>
    );
  }

  function renderNotifications() {
    return (
      <div className={ui.section}>
          <FormGroup
            footer={bellBusy ? 'Working…' : pushCopy(bell)}
          >
            <FormRow label="Push notifications" icon={<BellIcon />}>
              <Switch
                on={bell === 'on'}
                disabled={bellBusy || bell === 'ios-install' || bell === 'unsupported'}
                label="Notifications"
                onChange={(on) => {
                  if (bellBusy) return;
                  void (async () => {
                    setBellBusy(true);
                    try {
                      const msg = on ? await enablePush() : await disablePush();
                      await registerPush();
                      setBell(pushState());
                      toast(msg);
                    } finally {
                      setBellBusy(false);
                    }
                  })();
                }}
              />
            </FormRow>
          </FormGroup>

          <FormGroup
            header="Alerts"
            footer="Yours only. Change them on any plan."
            style={{ marginTop: 'var(--space-5)' }}
          >
            <PickRow
              label="Plans"
              value={prefs.alertTimed[0] ?? -1}
              options={[{ value: -1, label: 'None' }, ...TIMED_ALERTS]}
              onChange={(v) => changePrefs({ alertTimed: v < 0 ? [] : [v] })}
            />
            <PickRow
              label="All-day plans"
              value={prefs.alertAllDay[0] ?? -1}
              options={[{ value: -1, label: 'None' }, ...ALL_DAY_ALERTS]}
              onChange={(v) => changePrefs({ alertAllDay: v < 0 ? [] : [v] })}
            />
          </FormGroup>

          <FormGroup
            header="Morning summary"
            footer="Today’s plans, on days you have some"
            style={{ marginTop: 'var(--space-5)' }}
          >
            <FormRow label="Morning summary">
              <Switch
                on={prefs.summaryMinute != null}
                label="Morning summary"
                onChange={(on) => changePrefs({ summaryMinute: on ? 480 : null })}
              />
            </FormRow>
            {prefs.summaryMinute != null && (
              <PickRow
                label="Time"
                value={prefs.summaryMinute}
                options={SUMMARY_TIMES}
                onChange={(v) => changePrefs({ summaryMinute: v })}
              />
            )}
          </FormGroup>

          <FormGroup
            footer="From 10 pm to 8 am, news from others waits until morning. Alerts you set still ring."
            style={{ marginTop: 'var(--space-5)' }}
          >
            <FormRow label="Quiet overnight">
              <Switch
                on={prefs.quietHours}
                label="Quiet overnight"
                onChange={(on) => changePrefs({ quietHours: on })}
              />
            </FormRow>
          </FormGroup>

      </div>
    );
  }

  function renderCalPicker() {
    if (!calPicker) return null;
    const source = calPicker.source;
    return (
      <div className={ui.section}>
        <GcalPicker
          calendars={calPicker.items}
          selectedIds={chosen[source].map((c) => c.id)}
          counts={lastSynced(source)?.counts}
          busy={calBusy}
          onClose={closeCalPicker}
          onSave={(list) => {
            setCalPicker(null);
            pop();
            void saveChoice(source, list);
          }}
        />
      </div>
    );
  }

  function renderPage() {
    switch (page.k) {
      case 'main':
        return renderMain();
      case 'account':
        return renderAccount();
      case 'orb':
        return pageOrb ? renderOrb(pageOrb) : null;
      case 'newOrb':
        return renderNewOrb(page.withPeople);
      case 'pastOrbs':
        return renderPastOrbs();
      case 'calendars':
        return renderCalendars();
      case 'calPicker':
        return renderCalPicker();
      case 'notifications':
        return renderNotifications();
    }
  }

  return (
    <>
      <AnimatePresence>
        {open && (
          <motion.div
            className={ui.screen}
            role="dialog"
            aria-modal="true"
            aria-label="Settings"
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ duration: durationSheetSlide, ease: easeSheet }}
          >
            <header className={ui.screenBar}>
              <button type="button" className={ui.screenBack} onClick={onBack}>
                <Chevron />
                <span>{backLabel}</span>
              </button>
            </header>

            <div className={ui.screenScroll} ref={scrollRef}>
              <AnimatePresence mode="wait" initial={false}>
                <motion.div
                  key={`${stack.length}-${page.k}-${page.k === 'orb' ? page.id : ''}`}
                  initial={{ opacity: 0, x: xPage }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -xPage }}
                  transition={{ duration: durationFade, ease: easeIos }}
                >
                  <h1 className={ui.screenTitle}>{titleOf(page)}</h1>
                  {renderPage()}
                </motion.div>
              </AnimatePresence>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <ActionSheet
        open={Boolean(confirm)}
        title={confirm?.heading}
        message={confirm?.note}
        actions={
          confirm
            ? [
                {
                  label: confirm.action,
                  danger: true,
                  disabled: spaceBusy,
                  onClick: async () => {
                    await confirm.run();
                  },
                },
              ]
            : []
        }
        cancelLabel={confirm?.cancel ?? 'Cancel'}
        onCancel={() => setConfirm(null)}
      />
    </>
  );
}

function loadNames(
  me: 0 | 1,
  myName: string,
  current: [string, string],
): [string, string] {
  return me === 0 ? [myName, current[1]] : [current[0], myName];
}
