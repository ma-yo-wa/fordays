import { useEffect, useRef, useState } from 'react';
import NavBar from './components/NavBar';
import TabBar from './components/TabBar';
import AddSheet from './components/AddSheet';
import Composer from './components/Composer';
import Detail from './components/Detail';
import Settings from './components/Settings';
import ExternalDetail from './components/ExternalDetail';
import SearchOverlay from './components/SearchOverlay';
import InviteAccept from './components/InviteAccept';
import InviteShare from './components/InviteShare';
import Auth from './components/Auth';
import OrbSetup from './components/OrbSetup';
import Toasts from './components/Toasts';
import UpdateBanner from './components/UpdateBanner';
import BucketList from './screens/BucketList';
import Calendar from './screens/Calendar';
import Memories from './screens/Memories';
import {
  clearInviteFromUrl,
  currentSession,
  peekInvite,
  spaceNeedsFirstSetup,
  watchPasswordRecovery,
  type InvitePeek,
} from './lib/auth';
import { completeOutlookOAuthReturn, consumeOutlookRedirect } from './lib/outlook';
import { isDesktopBrowser } from './lib/device';
import { useApp } from './lib/store';
import DesktopGate from './components/DesktopGate';
import s from './App.module.css';

export default function App() {
  if (completeOutlookOAuthReturn()) {
    return <div />;
  }

  if (isDesktopBrowser()) {
    return <DesktopGate />;
  }

  return <AppShell />;
}

function AppShell() {
  const ready = useApp((st) => st.ready);
  const authPhase = useApp((st) => st.authPhase);
  const screen = useApp((st) => st.screen);
  const space = useApp((st) => st.space);
  const inviteCode = useApp((st) => st.inviteCode);
  const inviteShareOpen = useApp((st) => st.inviteShareOpen);
  const passwordRecovery = useApp((st) => st.passwordRecovery);
  const boot = useApp((st) => st.boot);
  const refreshSpace = useApp((st) => st.refreshSpace);
  const setNavScroll = useApp((st) => st.setNavScroll);
  const setInviteShareOpen = useApp((st) => st.setInviteShareOpen);
  const setInviteCode = useApp((st) => st.setInviteCode);
  const joinOrbOpen = useApp((st) => st.joinOrbOpen);
  const setJoinOrbOpen = useApp((st) => st.setJoinOrbOpen);
  const setPasswordRecovery = useApp((st) => st.setPasswordRecovery);
  const main = useRef<HTMLElement>(null);
  const scrollY = useRef(0);
  const scrollRaf = useRef(0);
  const [invitePeek, setInvitePeek] = useState<InvitePeek | null>(null);
  // After Auth unmounts, iOS often delivers the Sign-in tap to whatever is
  // now under the finger (usually the avatar → Settings). Eat that click.
  const [blockChrome, setBlockChrome] = useState(false);

  useEffect(() => {
    void boot();
  }, [boot]);

  useEffect(() => {
    void consumeOutlookRedirect().then((token) => {
      if (!token) return;
      useApp.getState().setSettingsOpen(true);
      useApp.getState().toast('Outlook connected — pick a calendar');
    });
  }, []);

  useEffect(() => {
    const onVis = () => {
      if (document.visibilityState === 'visible') {
        void useApp.getState().pullImportedCalendars();
      }
    };
    document.addEventListener('visibilitychange', onVis);
    return () => document.removeEventListener('visibilitychange', onVis);
  }, []);

  useEffect(() => {
    const href = window.location.href;
    if (/type=recovery/i.test(href)) setPasswordRecovery(true);

    let off: () => void = () => {};
    void watchPasswordRecovery(() => setPasswordRecovery(true)).then((unsub) => {
      off = unsub;
    });
    return () => off();
  }, [setPasswordRecovery]);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('compose') === '1') {
      // Opens the add chooser — solo can create; frozen spaces stay shut.
      useApp.getState().setAddOpen(true);
      window.history.replaceState(null, '', window.location.pathname);
    }
  }, []);

  useEffect(() => {
    if (!('serviceWorker' in navigator)) return;
    const handler = (event: MessageEvent) => {
      const data = event.data as {
        type?: string;
        activityId?: string | null;
        spaceId?: string | null;
        oldEndpoint?: string | null;
        subscription?: PushSubscriptionJSON;
      } | null;
      if (data?.type === 'notification-click' && data.activityId) {
        void useApp.getState().navigateToActivity(data.activityId, data.spaceId);
      }
      if (data?.type === 'subscription-change' && data.subscription) {
        void import('./lib/push').then((m) =>
          m.adoptRotatedSubscription(data.oldEndpoint ?? null, data.subscription!),
        );
      }
    };
    navigator.serviceWorker.addEventListener('message', handler);
    return () => {
      navigator.serviceWorker.removeEventListener('message', handler);
    };
  }, []);

  useEffect(() => {
    if (authPhase !== 'signedIn') return;
    const params = new URLSearchParams(window.location.search);
    const actId = params.get('a');
    const spId = params.get('s');
    if (actId) {
      void useApp.getState().navigateToActivity(actId, spId);
      params.delete('a');
      params.delete('s');
      const q = params.toString();
      window.history.replaceState(null, '', window.location.pathname + (q ? `?${q}` : ''));
    }
  }, [authPhase]);

  useEffect(() => {
    if (!inviteCode) {
      setInvitePeek(null);
      return;
    }
    void peekInvite(inviteCode)
      .then((p) => setInvitePeek(p ?? null))
      .catch(() => setInvitePeek(null));
  }, [inviteCode]);

  useEffect(() => {
    if (authPhase !== 'signedIn' || !inviteCode) return;
    void (async () => {
      // A cold start says "signed in" from the snapshot before the session is
      // checked. Join only with a real session; otherwise keep the invite so
      // sign-in shows who invited you and joins afterwards.
      if (!(await currentSession().catch(() => null))) return;
      try {
        await useApp.getState().joinOrb(inviteCode);
      } catch (err) {
        // Arrives while the page is still settling; stay up long enough to read.
        useApp.getState().toast(err instanceof Error ? err.message : 'Couldn’t join that Orb', 6000);
      } finally {
        setInviteCode(null);
        clearInviteFromUrl();
      }
    })();
  }, [authPhase, inviteCode, setInviteCode]);

  useEffect(() => {
    main.current?.scrollTo({ top: 0 });
  }, [screen]);

  if (authPhase === 'loading') {
    return <div className={s.app} />;
  }

  if (passwordRecovery || authPhase === 'signedOut') {
    return (
      <div className={s.app}>
        <Auth
          inviterHint={passwordRecovery ? null : invitePeek?.inviterName ?? null}
          inviteSpaceName={passwordRecovery ? null : invitePeek?.spaceName ?? null}
          startInRecovery={passwordRecovery}
          onSignedIn={async () => {
            setPasswordRecovery(false);
            setBlockChrome(true);
            useApp.getState().setSettingsOpen(false);
            try {
              if (inviteCode) {
                // Clear first so the signed-in auto-join doesn't run it again.
                const code = inviteCode;
                setInviteCode(null);
                clearInviteFromUrl();
                try {
                  await useApp.getState().joinOrb(code);
                } catch (err) {
                  useApp.getState().toast(err instanceof Error ? err.message : 'Couldn’t join that Orb', 6000);
                  await refreshSpace();
                }
              } else {
                await refreshSpace();
              }
            } finally {
              window.setTimeout(() => setBlockChrome(false), 600);
            }
          }}
        />
        <UpdateBanner />
        <Toasts />
      </div>
    );
  }

  if (
    spaceNeedsFirstSetup(space, Boolean(inviteCode) || joinOrbOpen)
  ) {
    return (
      <div className={s.app}>
        <OrbSetup />
        <UpdateBanner />
        <Toasts />
      </div>
    );
  }

  return (
    <div
      className={s.app}
      style={blockChrome ? { pointerEvents: 'none' } : undefined}
    >
      <NavBar />

      <main
        ref={main}
        className={s.main}
        onScroll={(e) => {
          scrollY.current = e.currentTarget.scrollTop;
          if (scrollRaf.current) return;
          scrollRaf.current = window.requestAnimationFrame(() => {
            scrollRaf.current = 0;
            setNavScroll(scrollY.current);
          });
        }}
      >
        <div className={s.screen}>
          {ready &&
            (screen === 'bucket' ? (
              <BucketList />
            ) : screen === 'memories' ? (
              <Memories />
            ) : (
              <Calendar />
            ))}
        </div>
      </main>

      <TabBar />
      <AddSheet />
      <Composer />
      <Detail />
      <Settings />
      <ExternalDetail />
      <SearchOverlay />
      <InviteShare
        open={inviteShareOpen}
        code={space?.inviteCode ?? ''}
        onClose={() => setInviteShareOpen(false)}
      />
      <InviteAccept
        code=""
        open={authPhase === 'signedIn' && joinOrbOpen}
        onJoined={() => {
          setJoinOrbOpen(false);
          void refreshSpace();
        }}
        onDismiss={() => {
          setJoinOrbOpen(false);
        }}
      />
      <UpdateBanner />
      <Toasts />
    </div>
  );
}
