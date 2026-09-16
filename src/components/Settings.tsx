import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import ActionSheet from './ActionSheet';
import Switch from './Switch';
import GcalPicker from './GcalPicker';
import { useApp, spaceOrbName, spacePeopleLabel } from '../lib/store';
import { isDefaultSpaceName, updateDisplayName, type SpaceInfo } from '../lib/auth';
import {
  clearGoogleToken,
  connectGoogle,
  fetchGoogleEvents,
  googleToken,
  listGoogleCalendars,
  saveGoogleCalendar,
  savedGoogleCalendar,
  type GoogleCalendar,
} from '../lib/gcal';
import {
  clearOutlookTokens,
  connectOutlook,
  consumeOutlookRedirect,
  fetchOutlookEvents,
  listOutlookCalendars,
  msClientId,
  saveOutlookCalendar,
  savedOutlookCalendar,
  ensureOutlookToken,
  type OutlookCalendar,
} from '../lib/outlook';
import type { ImportedCalendar } from '../lib/calendars';
import {
  disablePush,
  enablePush,
  pushState,
  registerPush,
  syncPush,
  type PushState,
} from '../lib/push';
import { Copy, formatCopy } from '../lib/copy';
import { Button, Avatar, Card, Input, ActionRow, FormGroup, FormRow, Pill } from '../ui';
import f from './Form.module.css';
import ui from './Settings.module.css';
import auth from './Auth.module.css';
import OrbKindForm from './OrbKindForm';

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
      return `On — when ${who} adds to Someday, suggests a time, locks in a date, or updates notes`;
    default:
      return `Hear when ${who} adds to Someday, suggests a time, locks in a date, or updates notes`;
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

function orbFaceChips(space: SpaceInfo): { key: string; letter: string; them: boolean }[] {
  if (space.members?.length) {
    const mine = space.members.find((m) => m.id === space.myId);
    const others = space.members.filter((m) => m.id !== space.myId);
    const ordered = mine ? [mine, ...others] : space.members;
    return ordered.map((m) => ({
      key: m.id,
      letter: firstLetter(m.name),
      them: m.id !== space.myId,
    }));
  }
  return [
    { key: 'me', letter: firstLetter(space.myName || '?'), them: false },
    ...(space.partnerName
      ? [{ key: 'them', letter: firstLetter(space.partnerName), them: true }]
      : []),
  ];
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
  const setJoinOrbOpen = useApp((st) => st.setJoinOrbOpen);
  const refreshSpace = useApp((st) => st.refreshSpace);
  const toast = useApp((st) => st.toast);
  const spaces = useApp((st) => st.spaces);
  const switchToSpace = useApp((st) => st.switchToSpace);
  const addSpace = useApp((st) => st.addSpace);
  const renameCurrentSpace = useApp((st) => st.renameCurrentSpace);
  const leaveCurrentSpace = useApp((st) => st.leaveCurrentSpace);
  const deletePastOrb = useApp((st) => st.deletePastOrb);
  const removeMemberFromSpace = useApp((st) => st.removeMemberFromSpace);

  const signedIn = authPhase === 'signedIn';
  const [myName, setMyName] = useState(space?.myName ?? config.names[config.me]);
  const [orbDraft, setOrbDraft] = useState('');
  const [gcalOn, setGcalOn] = useState(Boolean(savedGoogleCalendar() || googleToken()));
  const [gcalName, setGcalName] = useState(savedGoogleCalendar()?.summary ?? null);
  const [outlookOn, setOutlookOn] = useState(Boolean(savedOutlookCalendar()));
  const [outlookName, setOutlookName] = useState(savedOutlookCalendar()?.summary ?? null);
  const [calPicker, setCalPicker] = useState<{
    source: 'google' | 'outlook';
    items: ImportedCalendar[];
  } | null>(null);
  const [calBusy, setCalBusy] = useState(false);
  const [bell, setBell] = useState<PushState>('default');
  const [bellBusy, setBellBusy] = useState(false);
  const [spaceBusy, setSpaceBusy] = useState(false);
  const [confirm, setConfirm] = useState<SettingsConfirm | null>(null);
  const [subview, setSubview] = useState<
    'main' | 'anotherOrb' | 'orbSetup' | 'pastOrbs' | 'calPicker'
  >('main');
  const [createWithPeople, setCreateWithPeople] = useState(false);
  const [orbSetupBackTo, setOrbSetupBackTo] = useState<'main' | 'anotherOrb'>('anotherOrb');

  const allOrbs = spaces.length ? spaces : space ? [space] : [];
  const activeOrbs = allOrbs.filter((s) => !s.frozen);
  const pastOrbs = allOrbs.filter((s) => s.frozen);
  const visibleOrbs = activeOrbs;
  const members = space?.members ?? [];
  const soloOrb = members.length <= 1;
  const soloOrbs = activeOrbs.filter((s) => (s.members ?? []).length <= 1);
  const isPersonalOrb =
    soloOrb &&
    Boolean(
      (space && space.name.trim().toLowerCase() === 'personal') ||
      soloOrbs.length <= 1,
    );
  const leaveLabel = soloOrb ? 'Delete this Orb' : 'Leave this Orb';
  const removableMembers =
    space && !space.frozen && space.myRole === 'admin' && members.length >= 3
      ? members.filter((m) => m.id !== space.myId)
      : [];

  useEffect(() => {
    if (!open) {
      setSubview('main');
      return;
    }
    setMyName(space?.myName ?? config.names[config.me]);
    setOrbDraft(space && !isDefaultSpaceName(space.name) ? space.name : '');
    setConfirm(null);
    setGcalOn(Boolean(savedGoogleCalendar() || googleToken()));
    setGcalName(savedGoogleCalendar()?.summary ?? null);
    setOutlookOn(Boolean(savedOutlookCalendar()));
    setOutlookName(savedOutlookCalendar()?.summary ?? null);
    void registerPush().then(() => setBell(pushState()));
    void syncPush().then(() => setBell(pushState()));
    void (async () => {
      const redirected = await consumeOutlookRedirect();
      const token = redirected || (await ensureOutlookToken());
      if (!token || savedOutlookCalendar()) return;
      setOutlookOn(true);
      try {
        const calendars = await listOutlookCalendars(token);
        if (calendars.length) {
          setCalPicker({ source: 'outlook', items: calendars });
          setSubview('calPicker');
        }
      } catch {
        /* wait for an explicit connect */
      }
    })();
  }, [open, space?.myName, config.names, config.me]);

  useEffect(() => {
    setConfirm(null);
    setOrbDraft(space && !isDefaultSpaceName(space.name) ? space.name : '');
  }, [space?.id, space?.name]);

  async function importGoogleCalendar(cal: GoogleCalendar) {
    const token = googleToken();
    if (!token) {
      toast('Connect Google again');
      setGcalOn(false);
      setCalPicker(null);
      return;
    }
    setCalBusy(true);
    try {
      saveGoogleCalendar(cal);
      setGcalName(cal.summary);
      setCalPicker(null);
      const events = await fetchGoogleEvents(token, cal.id, cal.summary);
      await syncExternal(events, 'google');
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
      setCalBusy(false);
    }
  }

  async function importOutlookCalendar(cal: OutlookCalendar) {
    const token = await ensureOutlookToken();
    if (!token) {
      toast('Connect Outlook again');
      setOutlookOn(false);
      setCalPicker(null);
      return;
    }
    setCalBusy(true);
    try {
      saveOutlookCalendar(cal);
      setOutlookName(cal.summary);
      setCalPicker(null);
      const events = await fetchOutlookEvents(token, cal.id, cal.summary);
      await syncExternal(events, 'outlook');
      setOutlookOn(true);
      toast(
        events.length
          ? `${cal.summary} — ${events.length} events`
          : `${cal.summary} — nothing in the next few months`,
      );
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t load that calendar');
    } finally {
      setCalBusy(false);
    }
  }

  async function pickImportedCalendar(cal: ImportedCalendar) {
    if (calPicker?.source === 'outlook') {
      await importOutlookCalendar(cal);
      return;
    }
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

  async function refreshOutlookOverlay() {
    const cal = savedOutlookCalendar();
    if (!cal) {
      toast('Choose a calendar first');
      return;
    }
    await importOutlookCalendar(cal);
  }

  function closeCalPicker() {
    const source = calPicker?.source;
    setCalPicker(null);
    setSubview('main');
    if (source === 'outlook') {
      if (!savedOutlookCalendar()) {
        clearOutlookTokens();
        setOutlookOn(false);
        setOutlookName(null);
      }
      return;
    }
    if (!savedGoogleCalendar()) {
      clearGoogleToken();
      setGcalOn(false);
      setGcalName(null);
    }
  }

  async function persistOrbName() {
    if (!space || space.frozen) return;
    const current = isDefaultSpaceName(space.name) ? '' : space.name.trim();
    const next = orbDraft.trim();
    if (!next) {
      setOrbDraft(current);
      return;
    }
    if (next === current) return;
    await renameCurrentSpace(next);
  }

  async function handleSwitchOrb(next: SpaceInfo) {
    if (spaceBusy || next.id === space?.id) return;
    setOpen(false);
    setSpaceBusy(true);
    try {
      await persistOrbName();
      await switchToSpace(next.id);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t switch');
    } finally {
      setSpaceBusy(false);
    }
  }

  async function handleCreateOrb(name: string, withPeople: boolean) {
    if (spaceBusy) return;
    setSpaceBusy(true);
    try {
      await addSpace(name, withPeople);
      setSubview('main');
      setOpen(false);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t make an Orb');
    } finally {
      setSpaceBusy(false);
    }
  }

  function openInviteSheet() {
    if (!space || space.frozen) return;
    if (isPersonalOrb) {
      toast(Copy.orbs.cannotInviteToPersonal);
      setCreateWithPeople(true);
      setOrbSetupBackTo('main');
      setSubview('orbSetup');
      return;
    }
    setOpen(false);
    setInviteShareOpen(true);
  }

  async function handleRemoveMember(memberId: string, memberName: string) {
    setSpaceBusy(true);
    try {
      await removeMemberFromSpace(memberId);
      setConfirm(null);
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
      setConfirm(null);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t leave');
    } finally {
      setSpaceBusy(false);
    }
  }

  async function handleDeletePastOrb(id: string) {
    if (spaceBusy) return;
    setSpaceBusy(true);
    try {
      await deletePastOrb(id);
      setConfirm(null);
      if (pastOrbs.length <= 1) {
        setSubview('main');
      }
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t delete Orb');
    } finally {
      setSpaceBusy(false);
    }
  }

  function askLeave() {
    if (isPersonalOrb) {
      toast(Copy.orbs.cannotDeletePersonal);
      return;
    }
    setConfirm({
      heading: soloOrb ? Copy.orbs.deleteSoloTitle : Copy.orbs.leaveSharedTitle,
      note: soloOrb ? Copy.orbs.deleteSoloBody : Copy.orbs.leaveSharedBody,
      action: leaveLabel,
      cancel: Copy.orbs.stay,
      run: () => handleLeaveOrb(),
    });
  }

  function askRemove(memberId: string, memberName: string) {
    setConfirm({
      heading: formatCopy(Copy.orbs.removeTitle, { name: memberName }),
      note: Copy.orbs.removeBody,
      action: `Remove ${memberName}`,
      cancel: Copy.orbs.keepThem,
      run: () => handleRemoveMember(memberId, memberName),
    });
  }

  function askPurge(id: string) {
    setConfirm({
      heading: Copy.orbs.deletePermanentTitle,
      note: Copy.orbs.deletePermanentBody,
      action: Copy.orbs.deletePermanent,
      cancel: Copy.orbs.keep,
      run: () => handleDeletePastOrb(id),
    });
  }

  const heading =
    subview === 'anotherOrb'
      ? Copy.orbs.anotherOrb
      : subview === 'orbSetup'
        ? Copy.orbs.setupTitle
        : subview === 'pastOrbs'
          ? Copy.orbs.pastOrbs
          : subview === 'calPicker'
            ? 'Import calendars'
            : 'Settings';

  return (
    <>
      <Sheet open={open} onClose={() => setOpen(false)} heading={heading}>
        {subview === 'main' && (
          <>
            {signedIn && (
              <>
            {space?.frozen && (
              <div className={ui.frozenBanner}>
                <p className={ui.frozenBannerText}>{Copy.orbs.viewingFrozenBanner}</p>
                {activeOrbs[0] && (
                  <button
                    type="button"
                    className={ui.frozenBannerBtn}
                    onClick={() => void handleSwitchOrb(activeOrbs[0]!)}
                  >
                    {Copy.orbs.switchBackToActive}
                  </button>
                )}
              </div>
            )}

            <section className={ui.section}>
              <span className={ui.label}>Your profile</span>
              <div className={ui.profileCard}>
                <Avatar
                  name={myName || space?.myName || 'Me'}
                  seat={0}
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
            </section>

            <section className={ui.section}>
              <span className={ui.label}>{Copy.orbs.yourOrbs}</span>
              <div className={ui.orbGrid}>
                <button
                  type="button"
                  className={ui.orbTile}
                  disabled={spaceBusy}
                  aria-label="Another Orb"
                  onClick={() => setSubview('anotherOrb')}
                >
                  <span className={ui.orbCircle}>
                    <span className={ui.orbAddMark} aria-hidden>
                      +
                    </span>
                  </span>
                </button>
                {visibleOrbs.map((orb) => {
                  const faces = orbFaceChips(orb);
                  const on = orb.id === space?.id;
                  return (
                    <button
                      key={orb.id}
                      type="button"
                      className={`${ui.orbTile} ${on ? ui.orbTileOn : ''}`}
                      disabled={spaceBusy}
                      title={spaceOrbName(orb) || undefined}
                      onClick={() => void handleSwitchOrb(orb)}
                    >
                      <span className={ui.orbCircle}>
                        <span className={ui.orbFaceStack}>
                          {faces.slice(0, 3).map((f, idx) => (
                            <span
                              key={f.key}
                              className={`${ui.orbMiniFace} ${f.them ? ui.orbMiniFaceThem : ui.orbMiniFaceMe}`}
                              style={{ zIndex: 4 - idx }}
                              aria-hidden
                            >
                              {f.letter}
                            </span>
                          ))}
                          {faces.length > 3 && (
                            <span className={`${ui.orbMiniFace} ${ui.orbMiniMore}`}>
                              +{faces.length - 3}
                            </span>
                          )}
                        </span>
                      </span>
                      <span className={ui.orbTileName}>{spaceOrbName(orb) || '\u00a0'}</span>
                    </button>
                  );
                })}
              </div>
              {pastOrbs.length > 0 && (
                <div style={{ marginTop: 'var(--space-3)' }}>
                  <FormGroup>
                    <FormRow
                      label={Copy.orbs.pastOrbs}
                      note={Copy.orbs.pastOrbsSub}
                      onClick={() => setSubview('pastOrbs')}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-1-5)' }}>
                        <Pill variant="neutral" size="sm">{pastOrbs.length}</Pill>
                        <span style={{ color: 'var(--ink-faint)', fontSize: 'var(--fs-footnote)' }} aria-hidden>›</span>
                      </div>
                    </FormRow>
                  </FormGroup>
                </div>
              )}
            </section>

            {space && (
              <section className={ui.section}>
                <span className={ui.thisOrbHead}>
                  <span className={ui.label}>{Copy.orbs.thisOrb}</span>
                  {spaceOrbName(space) ? (
                    <span className={ui.thisOrbName}>{spaceOrbName(space)}</span>
                  ) : null}
                </span>
                <Input
                  value={orbDraft}
                  disabled={space.frozen || spaceBusy}
                  onChange={(e) => setOrbDraft(e.target.value)}
                  onBlur={() => {
                    void (async () => {
                      try {
                        await persistOrbName();
                      } catch (err) {
                        toast(err instanceof Error ? err.message : 'Couldn’t rename this Orb');
                        setOrbDraft(isDefaultSpaceName(space.name) ? '' : space.name);
                      }
                    })();
                  }}
                  placeholder={
                    soloOrb ? Copy.orbs.personalPlaceholder : Copy.orbs.crewPlaceholder
                  }
                  autoComplete="off"
                  autoCapitalize="words"
                />

                <span className={`${ui.label} ${ui.subLabel}`}>{Copy.orbs.people}</span>
                <div className={ui.peopleCard}>
                  <div className={ui.peopleRail}>
                    {!space.frozen && !isPersonalOrb && (
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

                    {members.map((member) => {
                      const mine = member.id === space.myId;
                      const removable = removableMembers.some((m) => m.id === member.id);
                      return (
                        <div key={member.id} className={ui.person}>
                          <div className={ui.personWrap}>
                            <span
                              className={`${ui.personFace} ${mine ? ui.personFaceMe : ui.personFaceThem}`}
                              aria-hidden
                            >
                              {firstLetter(member.name)}
                            </span>
                            {removable && (
                              <button
                                type="button"
                                className={ui.removeBadge}
                                title={`Remove ${member.name}`}
                                aria-label={`Remove ${member.name}`}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  askRemove(member.id, member.name);
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

                  {isPersonalOrb && (
                    <div className={ui.personalNoteRow}>
                      <p className={ui.personalNoteText}>{Copy.orbs.personalPrivateNote}</p>
                      <button
                        type="button"
                        className={ui.startSharedBtn}
                        onClick={() => {
                          setCreateWithPeople(true);
                          setOrbSetupBackTo('main');
                          setSubview('orbSetup');
                        }}
                      >
                        + {Copy.orbs.startSharedOrb}
                      </button>
                    </div>
                  )}
                </div>
                <p className={ui.help}>{Copy.orbs.descriptor}</p>
                {space.frozen && (
                  <p className={ui.frozen}>{Copy.orbs.frozenNotice}</p>
                )}

                {removableMembers.map((member) => (
                  <button
                    key={`ask-${member.id}`}
                    type="button"
                    className={ui.textLink}
                    disabled={spaceBusy}
                    onClick={() => askRemove(member.id, member.name)}
                  >
                    Remove {member.name}
                  </button>
                ))}

                {!space.frozen && !isPersonalOrb ? (
                  <button
                    type="button"
                    className={ui.textLink}
                    disabled={spaceBusy}
                    onClick={() => askLeave()}
                  >
                    {leaveLabel}
                  </button>
                ) : space.frozen ? (
                  <button
                    type="button"
                    className={`${ui.textLink} ${ui.pastOrbBtnDanger}`}
                    disabled={spaceBusy}
                    onClick={() => askPurge(space.id)}
                  >
                    {Copy.orbs.deletePermanent}
                  </button>
                ) : null}
              </section>
            )}
          </>
        )}

        <FormGroup
          header="External calendars"
          footer={Copy.availability.settingsNoteWeb}
        >
          <FormRow label={Copy.availability.googleCalendar}>
            <Switch
              on={gcalOn}
              disabled={calBusy}
              label="Connect Google Calendar"
              onChange={(on) => {
                void (async () => {
                  if (!on) {
                    clearGoogleToken();
                    saveGoogleCalendar(null);
                    setCalPicker(null);
                    setGcalName(null);
                    setGcalOn(false);
                    void syncExternal([], 'google')
                      .then(() => toast('Google Calendar disconnected'))
                      .catch((err) =>
                        toast(err instanceof Error ? err.message : 'Couldn’t clear overlay'),
                      );
                    return;
                  }
                  setCalBusy(true);
                  try {
                    const token = await connectGoogle();
                    const calendars = await listGoogleCalendars(token);
                    if (!calendars.length) {
                      setGcalOn(false);
                      toast('No calendars found on that Google account');
                      return;
                    }
                    setGcalOn(true);
                    setCalPicker({ source: 'google', items: calendars });
                    setSubview('calPicker');
                  } catch (err) {
                    setGcalOn(false);
                    toast(err instanceof Error ? err.message : 'Google connect failed');
                  } finally {
                    setCalBusy(false);
                  }
                })();
              }}
            />
          </FormRow>
          {gcalOn && (
            <FormRow
              label={gcalName ?? 'Choose calendar'}
              onClick={calBusy ? undefined : () => {
                void (async () => {
                  const token = googleToken();
                  if (!token) {
                    toast('Connect Google again');
                    setGcalOn(false);
                    return;
                  }
                  setCalBusy(true);
                  try {
                    setCalPicker({
                      source: 'google',
                      items: await listGoogleCalendars(token),
                    });
                    setSubview('calPicker');
                  } catch (err) {
                    toast(err instanceof Error ? err.message : 'Couldn’t list calendars');
                  } finally {
                    setCalBusy(false);
                  }
                })();
              }}
            >
              <span className={f.hint}>{gcalName ? 'Change ›' : '›'}</span>
            </FormRow>
          )}
          {gcalOn && gcalName && (
            <FormRow
              label="Refresh overlay"
              onClick={calBusy ? undefined : () => void refreshGoogleOverlay()}
            >
              <span className={f.hint}>{calBusy ? '…' : '›'}</span>
            </FormRow>
          )}
          <FormRow label={Copy.availability.outlookCalendar}>
            <Switch
              on={outlookOn}
              disabled={calBusy}
              label="Connect Outlook Calendar"
              onChange={(on) => {
                void (async () => {
                  if (!on) {
                    clearOutlookTokens();
                    saveOutlookCalendar(null);
                    setCalPicker(null);
                    setOutlookName(null);
                    setOutlookOn(false);
                    void syncExternal([], 'outlook')
                      .then(() => toast('Outlook Calendar disconnected'))
                      .catch((err) =>
                        toast(err instanceof Error ? err.message : 'Couldn’t clear overlay'),
                      );
                    return;
                  }
                  if (!msClientId()) {
                    toast('Outlook isn’t available yet');
                    return;
                  }
                  setCalBusy(true);
                  try {
                    const token = await connectOutlook();
                    const calendars = await listOutlookCalendars(token);
                    if (!calendars.length) {
                      setOutlookOn(false);
                      toast('No calendars found on that Outlook account');
                      return;
                    }
                    setOutlookOn(true);
                    setCalPicker({ source: 'outlook', items: calendars });
                    setSubview('calPicker');
                  } catch (err) {
                    setOutlookOn(false);
                    toast(err instanceof Error ? err.message : 'Outlook connect failed');
                  } finally {
                    setCalBusy(false);
                  }
                })();
              }}
            />
          </FormRow>
          {outlookOn && (
            <FormRow
              label={outlookName ?? 'Choose calendar'}
              onClick={calBusy ? undefined : () => {
                void (async () => {
                  const token = await ensureOutlookToken();
                  if (!token) {
                    toast('Connect Outlook again');
                    setOutlookOn(false);
                    return;
                  }
                  setCalBusy(true);
                  try {
                    setCalPicker({
                      source: 'outlook',
                      items: await listOutlookCalendars(token),
                    });
                    setSubview('calPicker');
                  } catch (err) {
                    toast(err instanceof Error ? err.message : 'Couldn’t list calendars');
                  } finally {
                    setCalBusy(false);
                  }
                })();
              }}
            >
              <span className={f.hint}>{outlookName ? 'Change ›' : '›'}</span>
            </FormRow>
          )}
          {outlookOn && outlookName && (
            <FormRow
              label="Refresh overlay"
              onClick={calBusy ? undefined : () => void refreshOutlookOverlay()}
            >
              <span className={f.hint}>{calBusy ? '…' : '›'}</span>
            </FormRow>
          )}
        </FormGroup>

        <div style={{ marginTop: 'var(--space-4)' }}>
          <FormGroup
            header="Notifications"
            footer={bellBusy ? 'Working…' : pushCopy(bell, space?.partnerName)}
          >
            <FormRow label="Push">
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
        </div>

        {signedIn && (
          <div className={f.row}>
            <Button
              variant="destructive"
              onClick={() => void signOutUser()}
            >
              Sign out
            </Button>
          </div>
        )}
      </>
    )}

    {subview === 'anotherOrb' && (
      <div>
        <button
          type="button"
          className={ui.navBack}
          onClick={() => setSubview('main')}
        >
          ← Settings
        </button>
        <div style={{ marginTop: 'var(--space-2)' }}>
          <ActionRow
            icon="+"
            label={Copy.orbs.startNew}
            note={Copy.orbs.startNewNote}
            onClick={() => {
              setCreateWithPeople(false);
              setOrbSetupBackTo('anotherOrb');
              setSubview('orbSetup');
            }}
          />
          <ActionRow
            icon="→"
            label={Copy.orbs.joinWithCode}
            note={Copy.orbs.joinWithCodeNote}
            onClick={() => {
              setSubview('main');
              setOpen(false);
              setJoinOrbOpen(true);
            }}
          />
        </div>
      </div>
    )}

    {subview === 'orbSetup' && (
      <div>
        <button
          type="button"
          className={ui.navBack}
          onClick={() => setSubview(orbSetupBackTo)}
        >
          ← {orbSetupBackTo === 'main' ? 'Settings' : 'Another Orb'}
        </button>
        <p className={auth.lead}>{Copy.orbs.setupLead}</p>
        <OrbKindForm
          key={createWithPeople ? 'with-people' : 'just-you'}
          knobId="orb-create-kind-knob"
          initialWithPeople={createWithPeople}
          onSubmit={handleCreateOrb}
        />
      </div>
    )}

    {subview === 'pastOrbs' && (
      <div>
        <button
          type="button"
          className={ui.navBack}
          onClick={() => setSubview('main')}
        >
          ← Settings
        </button>
        <div className={ui.pastOrbList} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)', marginTop: 'var(--space-3)' }}>
          {pastOrbs.map((pOrb) => {
            const pFaces = orbFaceChips(pOrb);
            const isCurrent = pOrb.id === space?.id;
            return (
              <Card key={pOrb.id} variant="sunk" padding="md">
                <div className={ui.pastOrbTop}>
                  <div className={ui.pastOrbInfo}>
                    <span className={ui.pastOrbName}>{spacePeopleLabel(pOrb) || '\u00a0'}</span>
                  </div>
                  <div className={ui.orbFaceStack}>
                    {pFaces.slice(0, 3).map((fc, idx) => (
                      <span
                        key={fc.key}
                        className={`${ui.orbMiniFace} ${fc.them ? ui.orbMiniFaceThem : ui.orbMiniFaceMe}`}
                        style={{ zIndex: 4 - idx }}
                        aria-hidden
                      >
                        {fc.letter}
                      </span>
                    ))}
                  </div>
                </div>

                <div className={ui.pastOrbActions} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 'var(--space-3)' }}>
                  {isCurrent ? (
                    <Button variant="primary" size="sm" disabled>
                      Currently viewing
                    </Button>
                  ) : (
                    <Button
                      variant="secondary"
                      size="sm"
                      disabled={spaceBusy}
                      onClick={() => {
                        setSubview('main');
                        void handleSwitchOrb(pOrb);
                      }}
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
      </div>
    )}

    {subview === 'calPicker' && (
      <div>
        <button
          type="button"
          className={ui.navBack}
          onClick={closeCalPicker}
        >
          ← External calendars
        </button>
        {calPicker && (
          <GcalPicker
            calendars={calPicker.items}
            selectedId={
              calPicker.source === 'outlook'
                ? (savedOutlookCalendar()?.id ?? null)
                : (savedGoogleCalendar()?.id ?? null)
            }
            busy={calBusy}
            onClose={closeCalPicker}
            onPick={async (cal) => {
              await pickImportedCalendar(cal);
              setSubview('main');
            }}
          />
        )}
      </div>
    )}
  </Sheet>

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
