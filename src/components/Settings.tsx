import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import Switch from './Switch';
import GcalPicker from './GcalPicker';
import { useApp, spacePeopleLabel } from '../lib/store';
import { updateDisplayName, type SpaceInfo } from '../lib/auth';
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
import ui from './Settings.module.css';

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

function firstLetter(name: string): string {
  return (name.trim()[0] ?? '?').toUpperCase();
}

function orbSizeLabel(space: SpaceInfo): string {
  const n = space.members?.length || (space.partner2Id ? 2 : 1);
  if (n <= 1) return 'Solo Orb';
  return `${n} people`;
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

  const visibleOrbs = spaces.length ? spaces : space ? [space] : [];
  const members = space?.members ?? [];
  const removableMembers =
    space && !space.frozen && space.myRole === 'admin' && members.length >= 3
      ? members.filter((m) => m.id !== space.myId)
      : [];

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

  useEffect(() => {
    setLeaveAsk(false);
    setRemoveId(null);
  }, [space?.id]);

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

  async function handleSwitchOrb(next: SpaceInfo) {
    if (spaceBusy || next.id === space?.id) return;
    setSpaceBusy(true);
    try {
      await switchToSpace(next.id);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t switch');
    } finally {
      setSpaceBusy(false);
    }
  }

  async function handleCreateOrb() {
    if (spaceBusy) return;
    setSpaceBusy(true);
    try {
      await addSpace();
      toast('New Orb — just you, until you invite');
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t make an Orb');
    } finally {
      setSpaceBusy(false);
    }
  }

  function openInviteSheet() {
    if (!space || space.frozen) return;
    setOpen(false);
    setInviteShareOpen(true);
  }

  async function handleRemoveMember(memberId: string, memberName: string) {
    setSpaceBusy(true);
    try {
      await removeMemberFromSpace(memberId);
      setRemoveId(null);
      toast(`${memberName} is out — they have a copy`);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t remove');
    } finally {
      setSpaceBusy(false);
    }
  }

  async function handleLeaveOrb() {
    setSpaceBusy(true);
    try {
      await leaveCurrentSpace();
      setLeaveAsk(false);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t leave');
    } finally {
      setSpaceBusy(false);
    }
  }

  return (
    <>
      <Sheet open={open} onClose={() => setOpen(false)} heading="Settings">
        {signedIn && (
          <>
            <section className={ui.section}>
              <span className={ui.label}>Your profile</span>
              <div className={ui.profileCard}>
                <span className={`${ui.face} ${ui.faceMe}`} aria-hidden>
                  {firstLetter(myName || space?.myName || 'Me')}
                </span>
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
                  placeholder="Mayowa"
                />
              </div>
            </section>

            <section className={ui.section}>
              <span className={ui.label}>Your Orbs</span>
              <div className={ui.orbRail}>
                {visibleOrbs.map((orb) => (
                  <button
                    key={orb.id}
                    type="button"
                    className={`${ui.orbCard} ${orb.id === space?.id ? ui.orbCardOn : ''}`}
                    disabled={spaceBusy || orb.id === space?.id}
                    onClick={() => void handleSwitchOrb(orb)}
                  >
                    <span className={ui.orbTitle}>{spacePeopleLabel(orb)}</span>
                    <span className={ui.orbMeta}>{orbSizeLabel(orb)}</span>
                    <span className={ui.orbState}>
                      {orb.id === space?.id ? 'Active ✓' : 'Open ›'}
                    </span>
                  </button>
                ))}
                <button
                  type="button"
                  className={`${ui.orbCard} ${ui.orbCreate}`}
                  disabled={spaceBusy}
                  onClick={() => void handleCreateOrb()}
                >
                  <span className={ui.orbPlus} aria-hidden>
                    +
                  </span>
                  <span className={ui.orbTitle}>Create Orb</span>
                  <span className={ui.orbMeta}>Start solo, or invite</span>
                </button>
              </div>
            </section>

            {space && (
              <section className={ui.section}>
                <span className={ui.label}>People in this Orb</span>
                <div className={ui.peopleCard}>
                  <div className={ui.peopleRail}>
                    {members.map((member) => {
                      const mine = member.id === space.myId;
                      return (
                        <div key={member.id} className={ui.person}>
                          <span
                            className={`${ui.personFace} ${mine ? ui.personFaceMe : ui.personFaceThem}`}
                            aria-hidden
                          >
                            {firstLetter(member.name)}
                          </span>
                          <span className={ui.personName}>{member.name}</span>
                          <span className={ui.personTag}>{mine ? 'You' : ''}</span>
                        </div>
                      );
                    })}

                    {!space.frozen && (
                      <button
                        type="button"
                        className={`${ui.person} ${ui.personButton}`}
                        onClick={openInviteSheet}
                      >
                        <span className={`${ui.personFace} ${ui.personFaceAdd}`} aria-hidden>
                          +
                        </span>
                        <span className={ui.personName}>Invite</span>
                        <span className={ui.personTag}>More</span>
                      </button>
                    )}
                  </div>
                </div>
                <p className={ui.help}>An Orb is your planning group — solo, two, or a few</p>
                {space.frozen && (
                  <p className={ui.frozen}>This is a copy from when you left — you can look, not change</p>
                )}
              </section>
            )}

            {space && (
              <section className={ui.section}>
                <span className={ui.label}>Orb actions</span>

                {removableMembers.map((member) =>
                  removeId === member.id ? (
                    <div key={`confirm-${member.id}`} className={ui.removePrompt}>
                      <p className={f.rowNote}>
                        Remove {member.name}? They get a copy of what was already here. This Orb
                        stays live for everyone else.
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
                          onClick={() => void handleRemoveMember(member.id, member.name)}
                        >
                          <span className={f.rowLabel}>Remove {member.name}</span>
                        </button>
                      </div>
                    </div>
                  ) : (
                    <button
                      key={`ask-${member.id}`}
                      type="button"
                      className={ui.textLink}
                      disabled={spaceBusy}
                      onClick={() => setRemoveId(member.id)}
                    >
                      Remove {member.name}
                    </button>
                  ),
                )}

                {!space.frozen &&
                  (leaveAsk ? (
                    <>
                      <p className={f.rowNote}>
                        {members.length <= 1
                          ? 'You’re the last person — this deletes the Orb.'
                          : 'They keep the live Orb. You get a frozen copy of what’s already here.'}
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
                          onClick={() => void handleLeaveOrb()}
                        >
                          <span className={f.rowLabel}>Leave this Orb</span>
                        </button>
                      </div>
                    </>
                  ) : (
                    <button
                      type="button"
                      className={ui.textLink}
                      disabled={spaceBusy}
                      onClick={() => setLeaveAsk(true)}
                    >
                      Leave this Orb
                    </button>
                  ))}
              </section>
            )}
          </>
        )}

        <span className={f.label}>External calendars</span>
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
          Overlay one calendar so your person can see what reshapes the week — trips, stays,
          appointments. Skip daily routines and private clutter; still not plans. Best from
          Safari/Chrome the first time you connect
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
        <p className={f.rowNote}>{bellBusy ? 'Working…' : pushCopy(bell, space?.partnerName)}</p>

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
