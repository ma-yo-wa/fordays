import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import ActionSheet from './ActionSheet';
import CoverPicker from './CoverPicker';
import CoverArt from './CoverArt';
import WhenFields from './WhenFields';
import { LocationInput } from './LocationInput';
import { Button, Card, Input, Avatar, ActionRow } from '../ui';
import { useApp, partnerName, isMatched } from '../lib/store';
import { Copy, formatCopy } from '../lib/copy';
import { isPlan, isMemory } from '../lib/types';
import type { SpaceInfo } from '../lib/auth';
import { isHomeSoloName } from '../lib/auth';
import { faceIndexFor } from '../lib/tint';
import {
  composeWhen,
  describePlan,
  dtDate,
  dtTime,
  iso,
  localizeAuditDetails,
  parseISO,
  timeAgo,
  todayISO,
} from '../lib/date';
import Linkify from './Linkify';
import PlanAlerts from './PlanAlerts';
import s from './Detail.module.css';
import f from './Form.module.css';

function CalendarIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <rect x="3" y="5" width="18" height="16" rx="4" />
      <path d="M3 10h18M8 3v3M16 3v3" strokeLinecap="round" />
    </svg>
  );
}

function SuggestIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path
        d="M5 6.5A2.5 2.5 0 0 1 7.5 4h9A2.5 2.5 0 0 1 19 6.5v7a2.5 2.5 0 0 1-2.5 2.5H12l-4 3v-3H7.5A2.5 2.5 0 0 1 5 13.5v-7Z"
        strokeLinejoin="round"
      />
      <path d="M9 9h6M9 12h3.5" strokeLinecap="round" />
    </svg>
  );
}

function BucketIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path
        d="M4.6 5h14.8l-2 12.3A3 3 0 0 1 14.4 20H9.6a3 3 0 0 1-3-2.7L4.6 5Z"
        strokeLinejoin="round"
      />
      <path d="m8.6 10.6 2.4 2.4 4.4-4.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" strokeLinecap="round" />
      <path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12" strokeLinejoin="round" />
    </svg>
  );
}

function RepeatIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path d="M17 2l4 4-4 4" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M3 11v-1a4 4 0 0 1 4-4h14" strokeLinecap="round" />
      <path d="M7 22l-4-4 4-4" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M21 13v1a4 4 0 0 1-4 4H3" strokeLinecap="round" />
    </svg>
  );
}

function PeopleIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" strokeLinecap="round" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" strokeLinecap="round" />
    </svg>
  );
}

type Mode = 'view' | 'edit' | 'when' | 'suggest';

const HISTORY_CAP = 5;

/* The place on its own: name, then the rest of the address. Opens Maps. */
function PlaceBlock({ place }: { place: string }) {
  const comma = place.indexOf(',');
  const name = (comma < 0 ? place : place.slice(0, comma)).trim();
  const rest = comma < 0 ? '' : place.slice(comma + 1).trim();
  return (
    <a
      href={`https://maps.apple.com/?q=${encodeURIComponent(place)}`}
      target="_blank"
      rel="noopener noreferrer"
      className={s.place}
      onClick={(e) => e.stopPropagation()}
    >
      <span className={s.placeText}>
        <span className={s.placeName}>{name}</span>
        {rest && <span className={s.placeRest}>{rest}</span>}
      </span>
      <span className={s.placeArrow} aria-hidden>
        ↗
      </span>
    </a>
  );
}

/* All-day plans are stored at noon UTC, so the server logs "at 12:00 PM".
   That isn't a time anyone chose; keep only the date. */
function dropNoonUTC(details: string): string {
  return details.replace(/\b([A-Z][a-z]{2}) 0?(\d{1,2}), (\d{4}) at 12:00 PM\b/g, '$1 $2, $3');
}

function sameWhen(
  a: string | null,
  b: string | null,
  aEnd: string | null,
  bEnd: string | null,
): boolean {
  return a === b && (aEnd ?? null) === (bEnd ?? null);
}

export default function Detail() {
  const detailId = useApp((st) => st.detailId);
  const activities = useApp((st) => st.activities);
  const logs = useApp((st) => st.logs);
  const config = useApp((st) => st.config);
  const openDetail = useApp((st) => st.openDetail);
  const patch = useApp((st) => st.patch);
  const remove = useApp((st) => st.remove);
  const suggestWhen = useApp((st) => st.suggestWhen);
  const acceptSuggestion = useApp((st) => st.acceptSuggestion);
  const dismissSuggestion = useApp((st) => st.dismissSuggestion);
  const toast = useApp((st) => st.toast);
  const setPicked = useApp((st) => st.setPicked);
  const setCursor = useApp((st) => st.setCursor);
  const space = useApp((st) => st.space);
  const spaces = useApp((st) => st.spaces);
  const openComposer = useApp((st) => st.openComposer);
  const moveToSpace = useApp((st) => st.moveToSpace);

  const item = activities.find((a) => a.id === detailId) ?? null;
  const faceCtx = { me: space?.me ?? config.me, myId: space?.myId };
  const myId = space?.myId ?? String(config.me);

  const allOrbs = spaces.length ? spaces : space ? [space] : [];
  const activeOrbs = allOrbs.filter((s) => !s.frozen);
  const soloOrbs = activeOrbs.filter((s) => (s.members ?? []).length <= 1);
  const isPersonalOrb = Boolean(
    space &&
      (space.members ?? []).length <= 1 &&
      (isHomeSoloName(space.name, space.myName) || soloOrbs.length <= 1),
  );
  const activeSharedOrbs = activeOrbs.filter((s) => s.id !== space?.id);

  const [mode, setMode] = useState<Mode>('view');
  const [title, setTitle] = useState('');
  const [location, setLocation] = useState('');
  const [notes, setNotes] = useState('');
  const [cover, setCover] = useState<string | null>(null);
  const [date, setDate] = useState(todayISO());
  const [from, setFrom] = useState('');
  const [until, setUntil] = useState('');
  const [end, setEnd] = useState<string | null>(null);
  const [multiDay, setMultiDay] = useState(false);
  const [suggestNote, setSuggestNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [doAgainOpen, setDoAgainOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [doWithOpen, setDoWithOpen] = useState(false);
  const [historyAll, setHistoryAll] = useState(false);

  async function handleDoWith(targetSpace: SpaceInfo) {
    if (!item) return;
    setBusy(true);
    try {
      await moveToSpace(item.id, targetSpace.id);
      const targetName = targetSpace.partnerName || targetSpace.name || 'Orb';
      toast(
        item.date_time
          ? formatCopy(Copy.orbs.movedToPlans, { orb: targetName })
          : formatCopy(Copy.orbs.movedToSomeday, { orb: targetName }),
      );
      close();
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t move item');
    } finally {
      setBusy(false);
    }
  }

  // Reset every time a different card opens, so nothing leaks between them.
  useEffect(() => {
    if (!item) return;
    setMode('view');
    setTitle(item.title);
    setLocation(item.location ?? '');
    setNotes(item.description ?? '');
    setCover(item.image_url);
    setDate(dtDate(item.date_time) ?? todayISO());
    setFrom(dtTime(item.date_time) ?? '');
    setUntil(dtTime(item.ends_at) ?? '');
    const multi =
      Boolean(item.ends_at) && dtDate(item.ends_at) !== dtDate(item.date_time);
    setEnd(multi ? dtDate(item.ends_at) : null);
    setMultiDay(multi);
    setSuggestNote('');
    setBusy(false);
  }, [detailId, item]);

  if (!item) return <Sheet open={false} onClose={() => openDetail(null)} children={null} />;

  const planned = isPlan(item);
  const memory = isMemory(item);
  const matched = isMatched(space);
  const frozen = Boolean(space?.frozen);
  const pending = Boolean(item.suggested_date_time && item.suggested_by);
  const suggestOthers = (space?.members ?? []).filter((m) => m.id !== space?.myId);
  const minePending = pending && item.suggested_by === myId;
  const history = logs
    .filter((l) => l.activity_id === item.id)
    .slice()
    .sort((a, b) => +new Date(b.timestamp) - +new Date(a.timestamp));

  const close = () => openDetail(null);

  function openSuggest() {
    const row = item!;
    const start = row.suggested_date_time ?? row.date_time;
    const finish = row.suggested_ends_at ?? row.ends_at;
    setDate(dtDate(start) ?? todayISO());
    setFrom(dtTime(start) ?? '');
    setUntil(dtTime(finish) ?? '');
    const multi = Boolean(finish) && dtDate(finish) !== dtDate(start);
    setEnd(multi ? dtDate(finish) : null);
    setMultiDay(multi);
    setSuggestNote('');
    setMode('suggest');
  }

  async function saveEdits() {
    const clean = title.trim();
    if (!clean) {
      toast('It needs a name');
      return;
    }
    await patch(item!.id, {
      title: clean,
      description: notes.trim() || null,
      location: location.trim() || null,
      image_url: cover,
    });
    setMode('view');
  }

  async function saveWhen() {
    const { date_time, ends_at } = composeWhen({
      date,
      from,
      until,
      endDate: multiDay ? end : null,
    });
    const from_someday = planned ? undefined : true;
    await patch(item!.id, { date_time, ends_at, from_someday });
    setPicked(date);
    const d = parseISO(date);
    setCursor(iso(new Date(d.getFullYear(), d.getMonth(), 1)));
    setMode('view');
    toast(planned ? 'Updated' : 'Made it a plan');
  }

  async function saveSuggest() {
    const row = item!;
    const { date_time, ends_at } = composeWhen({
      date,
      from,
      until,
      endDate: multiDay ? end : null,
    });
    if (sameWhen(date_time, row.date_time, ends_at, row.ends_at)) {
      toast('That’s already the date — change it, or leave a reason in a note');
      return;
    }
    if (
      row.suggested_date_time &&
      sameWhen(date_time, row.suggested_date_time, ends_at, row.suggested_ends_at)
    ) {
      toast('That’s already the suggestion');
      return;
    }
    setBusy(true);
    try {
      await suggestWhen(row.id, {
        date_time,
        ends_at,
        note: suggestNote.trim() || null,
      });
      setMode('view');
      toast('Suggested');
    } catch {
      /* toast already shown */
    } finally {
      setBusy(false);
    }
  }

  async function onAccept() {
    const row = item!;
    setBusy(true);
    try {
      const day = dtDate(row.suggested_date_time);
      await acceptSuggestion(row.id);
      if (day) {
        setPicked(day);
        const d = parseISO(day);
        setCursor(iso(new Date(d.getFullYear(), d.getMonth(), 1)));
      }
      toast('Locked in');
    } catch {
      /* toast already shown */
    } finally {
      setBusy(false);
    }
  }

  async function onDismiss() {
    const row = item!;
    const mine = row.suggested_by === myId;
    setBusy(true);
    try {
      await dismissSuggestion(row.id);
      toast(mine ? 'Cancelled' : 'Dismissed');
    } catch {
      /* toast already shown */
    } finally {
      setBusy(false);
    }
  }

  async function toBucket() {
    await patch(item!.id, { date_time: null, ends_at: null, from_someday: true });
    toast(Copy.ideas.backIn);
    close();
  }

  const suggestedLabel =
    item.suggested_date_time &&
    describePlan(item.suggested_date_time, item.suggested_ends_at);

  return (
    <>
    <Sheet open={!!detailId} onClose={close}>
      <div className={s.bar}>
        {mode === 'view' && !frozen ? (
          <button type="button" className={s.barButton} onClick={() => setMode('edit')}>
            Edit
          </button>
        ) : (
          <span />
        )}
        <button type="button" className={s.barButton} onClick={close}>
          Done
        </button>
      </div>

      {item.image_url && mode === 'view' && (
        <CoverArt url={item.image_url} size="hero" className={s.cover} />
      )}

      <div className={s.head}>
        <h3 className={s.title}>{item.title}</h3>
        <div className={s.when}>
          {planned ? describePlan(item.date_time as string, item.ends_at) : Copy.ideas.inList}
        </div>
      </div>

      {mode === 'view' && item.location && <PlaceBlock place={item.location} />}

      {mode === 'view' && item.description && (
        <p className={`${s.notes} selectable`}><Linkify text={item.description} /></p>
      )}

      {mode === 'view' && pending && item.suggested_date_time && (
        <Card variant="sageWash" padding="sm" className={s.suggestCard}>
          <div className={s.suggestWho}>
            <Avatar
              name={partnerName(config, item.suggested_by!)}
              personId={item.suggested_by}
              seat={faceIndexFor(item.suggested_by!, faceCtx)}
              size="sm"
            />
            <span>
              {minePending
                ? 'You suggested'
                : `${partnerName(config, item.suggested_by!)} suggests`}{' '}
              <strong>{suggestedLabel}</strong>
            </span>
          </div>
          {item.suggested_note && (
            <p className={s.suggestNote}><Linkify text={item.suggested_note} /></p>
          )}
          {!frozen && (
          <div className={s.suggestActions}>
            {minePending ? (
              <Button
                variant="secondary"
                size="sm"
                disabled={busy}
                onClick={() => void onDismiss()}
              >
                Cancel
              </Button>
            ) : (
              <>
                <Button
                  variant="primary"
                  size="sm"
                  disabled={busy}
                  onClick={() => void onAccept()}
                >
                  Accept
                </Button>
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={busy}
                  onClick={() => void onDismiss()}
                >
                  Dismiss
                </Button>
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={busy}
                  onClick={openSuggest}
                >
                  Suggest something else
                </Button>
              </>
            )}
          </div>
          )}
        </Card>
      )}

      {mode === 'edit' && (
        <>
          <div style={{ marginTop: 'var(--space-3-5)' }}>
            <Input
              label="Name"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Name"
            />
          </div>
          <span className={f.label}>
            Location <span className={f.hint}>— optional</span>
          </span>
          <LocationInput
            value={location}
            onChange={setLocation}
            placeholder="Where is this?"
          />
          <div style={{ marginTop: 'var(--space-3-5)' }}>
            <Input
              label="Notes"
              hint="— optional"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Anything worth remembering"
              multiline
              rows={3}
            />
          </div>
          <span className={f.label}>Cover</span>
          <CoverPicker value={cover} onChange={setCover} titleHint={() => title} />
          <div className={f.row}>
            <Button
              variant="secondary"
              onClick={() => setMode('view')}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              onClick={() => void saveEdits()}
            >
              Save
            </Button>
          </div>
        </>
      )}

      {(mode === 'when' || mode === 'suggest') && (
        <>
          <WhenFields
            date={date}
            from={from}
            until={until}
            end={end}
            multiDay={multiDay}
            onDate={setDate}
            onFrom={setFrom}
            onUntil={setUntil}
            onEnd={setEnd}
            onMultiDay={setMultiDay}
          />

          {mode === 'suggest' && (
            <div style={{ marginTop: 'var(--space-3-5)' }}>
              <Input
                label="Why"
                hint="— optional, but helpful"
                value={suggestNote}
                onChange={(e) => setSuggestNote(e.target.value)}
                placeholder="I’m free that afternoon…"
                multiline
                rows={2}
              />
            </div>
          )}

          <div className={f.row}>
            <Button
              variant="secondary"
              onClick={() => setMode('view')}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              disabled={busy}
              onClick={() => void (mode === 'suggest' ? saveSuggest() : saveWhen())}
            >
              {mode === 'suggest' ? 'Suggest' : planned ? 'Save' : 'Make it a plan'}
            </Button>
          </div>
        </>
      )}

      {mode === 'view' && matched && (
        <p className={s.addedBy}>
          Added by {partnerName(config, item.created_by)}
          {timeAgo(item.created_at) ? ` · ${timeAgo(item.created_at)}` : ''}
        </p>
      )}

      {mode === 'view' && frozen && (
        <p className={f.rowNote} style={{ marginTop: 'var(--space-3-5)' }}>
          This is a copy from when you left — you can look, not change
        </p>
      )}

      {mode === 'view' && !frozen && (
        <div className={s.actions}>
          {memory && (
            <ActionRow
              icon={<RepeatIcon />}
              label={Copy.memories.doAgain}
              onClick={() => setDoAgainOpen(true)}
            />
          )}

          {!memory && isPersonalOrb && activeSharedOrbs.length > 0 && activeSharedOrbs[0] && (
            activeSharedOrbs.length === 1 ? (
              <ActionRow
                icon={<PeopleIcon />}
                label={formatCopy(Copy.orbs.doWith, {
                  name: activeSharedOrbs[0]!.partnerName || activeSharedOrbs[0]!.name,
                })}
                onClick={() => void handleDoWith(activeSharedOrbs[0]!)}
              />
            ) : (
              <ActionRow
                icon={<PeopleIcon />}
                label={Copy.orbs.doWithEllipsis}
                onClick={() => setDoWithOpen(true)}
              />
            )
          )}

          <ActionRow
            icon={<CalendarIcon />}
            label={planned ? 'Change the day' : 'Make it a plan'}
            onClick={() => setMode('when')}
          />

          {planned && !memory && item.date_time && (
            <PlanAlerts activityId={item.id} allDay={Boolean(item.all_day)} />
          )}

          {matched && !memory && (
            <ActionRow
              icon={<SuggestIcon />}
              label={suggestOthers.length === 1 ? `Suggest a date to ${suggestOthers[0]!.name}` : 'Suggest a date'}
              onClick={openSuggest}
            />
          )}

          {planned && !memory && (
            <ActionRow
              icon={<BucketIcon />}
              label={Copy.ideas.backTo}
              onClick={() => void toBucket()}
            />
          )}

        </div>
      )}

      {mode === 'view' && !frozen && (
        <div className={`${s.actions} ${s.danger}`}>
          <ActionRow
            icon={<TrashIcon />}
            label="Delete"
            destructive
            onClick={() => setDeleteOpen(true)}
          />
        </div>
      )}

      {/* Always visible, newest first, capped so the drawer stays about the plan. */}
      {mode === 'view' && history.length > 0 && (
        <>
          <span className={s.historyHead}>History</span>
          {(historyAll ? history : history.slice(0, HISTORY_CAP)).map((l) => (
            <div key={l.id} className={s.entry}>
              <Avatar
                name={partnerName(config, l.user_id)}
                personId={l.user_id}
                seat={faceIndexFor(l.user_id, faceCtx)}
                size="sm"
              />
              <span className={s.what}>
                {partnerName(config, l.user_id)}{' '}
                {localizeAuditDetails(item.all_day ? dropNoonUTC(l.details) : l.details)}{' '}
                <span className={s.ago}>· {timeAgo(l.timestamp)}</span>
              </span>
            </div>
          ))}
          {!historyAll && history.length > HISTORY_CAP && (
            <button type="button" className={s.historyMore} onClick={() => setHistoryAll(true)}>
              Show {history.length - HISTORY_CAP} more
            </button>
          )}
        </>
      )}
    </Sheet>

    <ActionSheet
      open={doAgainOpen}
      title={formatCopy(Copy.memories.doAgainPrompt, { title: item.title })}
      actions={[
        {
          label: Copy.memories.makePlan,
          onClick: () => {
            setDoAgainOpen(false);
            const draft = {
              title: item.title,
              notes: item.description ?? '',
              location: item.location ?? '',
              cover: item.image_url ?? null,
              fromSomeday: true,
            };
            close();
            openComposer('plan', draft);
          },
        },
        {
          label: Copy.memories.addToSomeday,
          onClick: () => {
            setDoAgainOpen(false);
            const draft = {
              title: item.title,
              notes: item.description ?? '',
              location: item.location ?? '',
              cover: item.image_url ?? null,
              fromSomeday: true,
            };
            close();
            openComposer('bucket', draft);
          },
        },
      ]}
      cancelLabel="Cancel"
      onCancel={() => setDoAgainOpen(false)}
    />

    <ActionSheet
      open={doWithOpen}
      title={Copy.orbs.doWithEllipsis}
      actions={activeSharedOrbs.map((targetSpace) => ({
        label: targetSpace.partnerName
          ? `${targetSpace.partnerName} (${targetSpace.name})`
          : targetSpace.name,
        onClick: () => {
          setDoWithOpen(false);
          void handleDoWith(targetSpace);
        },
      }))}
      cancelLabel="Cancel"
      onCancel={() => setDoWithOpen(false)}
    />

    {/* A confirm is an Action Sheet, never Keep / Delete expanded in the page. */}
    <ActionSheet
      open={deleteOpen}
      title={`Delete “${item.title}”?`}
      message="This removes it for everyone in this Orb."
      actions={[
        {
          label: 'Delete',
          danger: true,
          onClick: () => {
            setDeleteOpen(false);
            close();
            void remove(item.id).then((ok) => {
              if (ok) toast('Deleted');
            });
          },
        },
      ]}
      cancelLabel="Keep it"
      onCancel={() => setDeleteOpen(false)}
    />
    </>
  );
}
