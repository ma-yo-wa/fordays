import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import Switch from './Switch';
import GcalPicker from './GcalPicker';
import { useApp, spacePeopleLabel } from '../lib/store';
import { updateDisplayName } from '../lib/auth';
import {
  clearGoogleToken,
  connectGoogle,
  fetchGoogleEvents,
  googleClientId,
  googleToken,
  listGoogleCalendars,
  saveGoogleCalendar,
  savedGoogleCalendar,
  type GoogleCalendar,
} from '../lib/gcal';
import {
  disablePush,
  enablePush,
  pushState,
  registerPush,
  syncPush,
  type PushState,
} from '../lib/push';
import f from './Form.module.css';

function pushCopy(state: PushState, partnerName: string | null | undefined): string {
  const who = partnerName?.trim() || 'your person';
  switch (state) {
    case 'unsupported':
      return "This browser can't do web push";
    case 'ios-install':
      return 'Open Fordays from the Home Screen icon to turn notifications on';
    case 'denied':
      return 'Blocked — iPhone Settings → Fordays → Notifications';
    case 'granted-idle':
      return 'Allowed — turn the switch on to finish subscribing';
    case 'on':
      return `On — when ${who} adds an idea, suggests a time, locks in a date, or updates notes`;
    default:
      return `Hear when ${who} adds an idea, suggests a time, locks in a date, or updates notes`;
  }
}

export default function Settings() {
  const open = useApp((st) => st.settingsOpen);
  const setOpen = useApp((st) => st.setSettingsOpen);
  const config = useApp((st) => st.config);
  const updateConfig = useApp((st) => st.updateConfig);
  const signOutUser = useApp((st) => st.signOutUser);
  const authPhase = useApp((st) => st.authPhase);
  const space = useApp((st) => st.space);
  const syncExternal = useApp((st) => st.syncExternal);
  const setInviteShareOpen = useApp((st) => st.setInviteShareOpen);
  const refreshSpace = useApp((st) => st.refreshSpace);
  const toast = useApp((st) => st.toast);
  const spaces = useApp((st) => st.spaces);
  const switchToSpace = useApp((st) => st.switchToSpace);
  const addSpace = useApp((st) => st.addSpace);
  const leaveCurrentSpace = useApp((st) => st.leaveCurrentSpace);
  const removeMemberFromSpace = useApp((st) => st.removeMemberFromSpace);

  const signedIn = authPhase === 'signedIn';
  const [myName, setMyName] = useState(space?.myName ?? config.names[config.me]);
  const [gcalOn, setGcalOn] = useState(Boolean(googleToken()));
  const [gcalName, setGcalName] = useState(savedGoogleCalendar()?.summary ?? null);
  const [gcalList, setGcalList] = useState<GoogleCalendar[] | null>(null);
  const [gcalBusy, setGcalBusy] = useState(false);
  const [bell, setBell] = useState<PushState>('default');
  const [bellBusy, setBellBusy] = useState(false);
  const [spaceBusy, setSpaceBusy] = useState(false);
  const [leaveAsk, setLeaveAsk] = useState(false);
  const [removeId, setRemoveId] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setMyName(space?.myName ?? config.names[config.me]);
    setLeaveAsk(false);
    setRemoveId(null);
    setGcalOn(Boolean(googleToken()));
    setGcalName(savedGoogleCalendar()?.summary ?? null);
    void registerPush().then(() => setBell(pushState()));
    void syncPush().then(() => setBell(pushState()));
  }, [open, space?.myName, config.names, config.me]);

  async function importGoogleCalendar(cal: GoogleCalendar) {
    const token = googleToken();
    if (!token) {
      toast('Connect Google again');
      setGcalOn(false);
      setGcalList(null);
      return;
    }
    setGcalBusy(true);
    try {
      saveGoogleCalendar(cal);
      setGcalName(cal.summary);
      setGcalList(null);
      const owner = space?.myId ?? String(config.me);
      const events = await fetchGoogleEvents(token, owner, cal.id);
      await syncExternal(events);
      setGcalOn(true);
      const withPlace = events.filter((e) => e.location).length;
      toast(
        events.length
          ? withPlace
            ? `${cal.summary} — ${events.length} events · ${withPlace} with a place`
            : `${cal.summary} — ${events.length} events (no places on those Google events)`
          : `${cal.summary} — nothing in the next few months`,
      );
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t load that calendar');
    } finally {
      setGcalBusy(false);
    }
  }

  async function pickGoogleCalendar(cal: GoogleCalendar) {
    await importGoogleCalendar(cal);
  }

  async function refreshGoogleOverlay() {
    const cal = savedGoogleCalendar();
    if (!cal) {
      toast('Choose a calendar first');
      return;
    }
    await importGoogleCalendar(cal);
  }

  function closeGcalPicker() {
    const had = savedGoogleCalendar();
    setGcalList(null);
    if (!had) {
      clearGoogleToken();
      setGcalOn(false);
      setGcalName(null);
    }
  }

  return (
    <>
    <Sheet open={open} onClose={() => setOpen(false)} heading="Settings">
      {signedIn && (
        <>
          <span className={f.label}>You</span>
          <div className={f.group}>
            <input
              className={f.input}
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
              placeholder="Mayowa"
            />
          </div>

          <span className={f.label}>Orbs</span>
          <div className={f.group}>
            {(spaces.length ? spaces : space ? [space] : []).map((sp) => (
              <button
                key={sp.id}
                type="button"
                className={f.listRow}
                disabled={spaceBusy || sp.id === space?.id}
                onClick={() => {
                  void (async () => {
                    setSpaceBusy(true);
                    try {
                      await switchToSpace(sp.id);
                    } catch (err) {
                      toast(err instanceof Error ? err.message : 'Couldn’t switch');
                    } finally {
                      setSpaceBusy(false);
                    }
                  })();
                }}
              >
                <span className={f.rowLabel}>{spacePeopleLabel(sp)}</span>
                <span className={f.hint}>{sp.id === space?.id ? '✓' : '›'}</span>
              </button>
            ))}
            <button
              type="button"
              className={f.listRow}
              disabled={spaceBusy}
              onClick={() => {
                void (async () => {
                  setSpaceBusy(true);
                  try {
                    await addSpace();
                    toast('New orb — just you, until you invite');
                  } catch (err) {
                    toast(err instanceof Error ? err.message : 'Couldn’t make an orb');
                  } finally {
                    setSpaceBusy(false);
                  }
                })();
              }}
            >
              <span className={f.rowLabel}>New orb</span>
              <span className={f.hint}>›</span>
            </button>
            {space && !space.frozen && (
              <button
                type="button"
                className={f.listRow}
                onClick={() => {
                  setOpen(false);
                  setInviteShareOpen(true);
                }}
              >
                <span className={f.rowLabel}>Invite to this orb</span>
                <span className={f.hint}>›</span>
              </button>
            )}
          </div>
          <p className={f.rowNote}>
            An orb is your planning group — solo, two, or a few
          </p>

          <span className={f.label}>This orb</span>
          {space?.frozen && (
            <p className={f.rowNote} style={{ marginTop: 0, marginBottom: 8 }}>
              This is a copy from when you left — you can look, not change
            </p>
          )}
          {(space?.members ?? []).map((m) => (
            <p key={m.id} className={f.withName}>
              {m.name}
              {m.id === space?.myId ? ' (you)' : ''}
            </p>
          ))}
          {space &&
            !space.frozen &&
            space.myRole === 'admin' &&
            (space.members?.length ?? 0) >= 3 &&
            space.members
              .filter((m) => m.id !== space.myId)
              .map((m) =>
                removeId === m.id ? (
                  <div key={`rm-${m.id}`}>
                    <p className={f.rowNote}>
                      Remove {m.name}? They get a copy of what’s already here.
                      This orb stays live for everyone else.
                    </p>
                    <div className={f.group}>
                      <button
                        type="button"
                        className={f.listRow}
                        disabled={spaceBusy}
                        onClick={() => setRemoveId(null)}
                      >
                        <span className={f.rowLabel}>Keep them</span>
                      </button>
                      <button
                        type="button"
                        className={f.listRow}
                        disabled={spaceBusy}
                        onClick={() => {
                          void (async () => {
                            setSpaceBusy(true);
                            try {
                              await removeMemberFromSpace(m.id);
                              setRemoveId(null);
                              toast(`${m.name} is out — they have a copy`);
                            } catch (err) {
                              toast(err instanceof Error ? err.message : 'Couldn’t remove');
                            } finally {
                              setSpaceBusy(false);
                            }
                          })();
                        }}
                      >
                        <span className={f.rowLabel}>Remove {m.name}</span>
                      </button>
                    </div>
                  </div>
                ) : (
                  <button
                    key={`ask-${m.id}`}
                    type="button"
                    className={f.textLink}
                    disabled={spaceBusy}
                    onClick={() => setRemoveId(m.id)}
                  >
                    Remove {m.name}
                  </button>
                ),
              )}
          {space && !space.frozen && (
            leaveAsk ? (
              <>
                <p className={f.rowNote}>
                  {(space.members?.length ?? 1) <= 1
                    ? 'You’re the last person — this deletes the orb.'
                    : 'They keep the live orb. You get a frozen copy of what’s already here.'}
                </p>
                <div className={f.group}>
                  <button
                    type="button"
                    className={f.listRow}
                    disabled={spaceBusy}
                    onClick={() => setLeaveAsk(false)}
                  >
                    <span className={f.rowLabel}>Stay</span>
                  </button>
                  <button
                    type="button"
                    className={f.listRow}
                    disabled={spaceBusy}
                    onClick={() => {
                      void (async () => {
                        setSpaceBusy(true);
                        try {
                          await leaveCurrentSpace();
                          setLeaveAsk(false);
                        } catch (err) {
                          toast(err instanceof Error ? err.message : 'Couldn’t leave');
                        } finally {
                          setSpaceBusy(false);
                        }
                      })();
                    }}
                  >
                    <span className={f.rowLabel}>Leave this orb</span>
                  </button>
                </div>
              </>
            ) : (
              <button
                type="button"
                className={f.textLink}
                disabled={spaceBusy}
                onClick={() => setLeaveAsk(true)}
              >
                Leave this orb
              </button>
            )
          )}
        </>
      )}

      <span className={f.label}>Calendars</span>
      <div className={f.group}>
        <div className={f.listRow}>
          <span className={f.rowLabel}>Google Calendar</span>
          <Switch
            on={gcalOn}
            disabled={gcalBusy}
            label="Connect Google Calendar"
            onChange={(on) => {
              void (async () => {
                if (!on) {
                  clearGoogleToken();
                  saveGoogleCalendar(null);
                  setGcalList(null);
                  setGcalName(null);
                  setGcalOn(false);
                  void syncExternal([])
                    .then(() => toast('Google Calendar disconnected'))
                    .catch((err) =>
                      toast(err instanceof Error ? err.message : 'Couldn’t clear overlay'),
                    );
                  return;
                }
                setGcalBusy(true);
                try {
                  const token = await connectGoogle();
                  const calendars = await listGoogleCalendars(token);
                  if (!calendars.length) {
                    setGcalOn(false);
                    toast('No calendars found on that Google account');
                    return;
                  }
                  setGcalOn(true);
                  setGcalList(calendars);
                } catch (err) {
                  setGcalOn(false);
                  toast(err instanceof Error ? err.message : 'Google connect failed');
                } finally {
                  setGcalBusy(false);
                }
              })();
            }}
          />
        </div>
        {gcalOn && (
          <button
            type="button"
            className={f.listRow}
            disabled={gcalBusy}
            onClick={() => {
              void (async () => {
                const token = googleToken();
                if (!token) {
                  toast('Connect Google again');
                  setGcalOn(false);
                  return;
                }
                setGcalBusy(true);
                try {
                  setGcalList(await listGoogleCalendars(token));
                } catch (err) {
                  toast(err instanceof Error ? err.message : 'Couldn’t list calendars');
                } finally {
                  setGcalBusy(false);
                }
              })();
            }}
          >
            <span className={f.rowLabel}>{gcalName ?? 'Choose calendar'}</span>
            <span className={f.hint}>{gcalName ? 'Change ›' : '›'}</span>
          </button>
        )}
        {gcalOn && gcalName && (
          <button
            type="button"
            className={f.listRow}
            disabled={gcalBusy}
            onClick={() => void refreshGoogleOverlay()}
          >
            <span className={f.rowLabel}>Refresh overlay</span>
            <span className={f.hint}>{gcalBusy ? '…' : '›'}</span>
          </button>
        )}
      </div>
      <p className={f.rowNote}>
        Overlay one calendar so your person can see what reshapes the week —
        trips, stays, appointments. Skip daily routines and private clutter;
        still not plans. Best from Safari/Chrome the first time you connect
      </p>

      <span className={f.label}>Notifications</span>
      <div className={f.group}>
        <div className={f.listRow}>
          <span className={f.rowLabel}>Push</span>
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
        </div>
      </div>
      <p className={f.rowNote}>
        {bellBusy ? 'Working…' : pushCopy(bell, space?.partnerName)}
      </p>

      {(!googleClientId() || !config.vapidPublicKey.trim()) && (
        <details className={f.advanced}>
          <summary className={f.advancedSum}>Advanced</summary>
          {!googleClientId() && (
            <>
              <span className={f.label}>Google client ID</span>
              <div className={f.group}>
                <input
                  className={f.input}
                  value={config.googleClientId}
                  onChange={(e) => updateConfig({ googleClientId: e.target.value })}
                  placeholder="xxxx.apps.googleusercontent.com"
                  autoCapitalize="none"
                  spellCheck={false}
                />
              </div>
              <p className={f.rowNote}>
                Usually set at deploy — only paste here if Calendar won’t connect
              </p>
            </>
          )}
          {!config.vapidPublicKey.trim() && (
            <>
              <span className={f.label}>VAPID public key</span>
              <div className={f.group}>
                <input
                  className={f.input}
                  value={config.vapidPublicKey}
                  onChange={(e) => updateConfig({ vapidPublicKey: e.target.value })}
                  placeholder="BNxxx…"
                  autoCapitalize="none"
                  spellCheck={false}
                />
              </div>
              <p className={f.rowNote}>
                Usually set at deploy — only paste here if push won’t subscribe
              </p>
            </>
          )}
        </details>
      )}

      {signedIn && (
        <div className={f.row}>
          <button
            type="button"
            className={`${f.btn} ${f.ghost}`}
            onClick={() => void signOutUser()}
          >
            Sign out
          </button>
        </div>
      )}
    </Sheet>

    {/* Outside Settings sheet — nested fixed sheets get clipped by the
        parent’s transform and never cover the screen. */}
    <GcalPicker
      open={!!gcalList?.length}
      calendars={gcalList ?? []}
      selectedId={savedGoogleCalendar()?.id ?? null}
      busy={gcalBusy}
      onClose={closeGcalPicker}
      onPick={(cal) => void pickGoogleCalendar(cal)}
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
