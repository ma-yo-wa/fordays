import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import CoverPicker from './CoverPicker';
import WhenFields from './WhenFields';
import { LocationInput } from './LocationInput';
import { partnerName, useApp } from '../lib/store';
import { composeWhen, describePlan, iso, parseISO, prettyLower, shortDate } from '../lib/date';
import { Copy } from '../lib/copy';
import f from './Form.module.css';

/* Still one form and still one nullable column underneath, but which of
   the two you're making was decided before this opened. In bucket mode
   there is no date control at all — the simplest way to stop someone
   wondering what happens if they leave it blank. */
export default function Composer() {
  const mode = useApp((st) => st.composerMode);
  const draft = useApp((st) => st.composerDraft);
  const close = useApp((st) => st.closeComposer);
  const create = useApp((st) => st.create);
  const toast = useApp((st) => st.toast);
  const picked = useApp((st) => st.picked);
  const setPicked = useApp((st) => st.setPicked);
  const setScreen = useApp((st) => st.setScreen);
  const setCursor = useApp((st) => st.setCursor);
  const external = useApp((st) => st.external);
  const space = useApp((st) => st.space);
  const config = useApp((st) => st.config);

  const isPlan = mode === 'plan';

  const [title, setTitle] = useState('');
  const [location, setLocation] = useState('');
  const [notes, setNotes] = useState('');
  const [cover, setCover] = useState<string | null>(null);
  const [date, setDate] = useState<string>(picked);
  const [from, setFrom] = useState('');
  const [until, setUntil] = useState('');
  const [end, setEnd] = useState<string | null>(null);
  const [multiDay, setMultiDay] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!mode) return;
    setTitle(draft?.title ?? '');
    setLocation(draft?.location ?? '');
    setNotes(draft?.notes ?? '');
    setCover(null);
    // A plan opens on the draft date if provided, or the day you were already looking at.
    setDate(draft?.date ?? picked);
    setFrom(draft?.from ?? '');
    setUntil(draft?.until ?? '');
    setEnd(draft?.endDate ?? null);
    setMultiDay(draft?.multiDay ?? Boolean(draft?.endDate));
    setSaving(false);
  }, [mode, picked, draft]);

  const dayContext = external.filter((e) => {
    const isMine = e.ownerId === (space?.myId ?? String(space?.me ?? config.me));
    if (!isMine && !e.sharedWithSpace) return false;

    const eStartDay = e.startsAt.slice(0, 10);
    const eEndDay = e.endsAt ? e.endsAt.slice(0, 10) : eStartDay;

    if (multiDay && end) {
      return date <= eEndDay && end >= eStartDay;
    }

    if (date < eStartDay || date > eEndDay) return false;
    if (e.allDay) return true;
    if (!from) return true;

    if (eStartDay < date && eEndDay > date) return true;

    const eStartTime = eStartDay < date
      ? '00:00'
      : (e.startsAt.length > 10 ? e.startsAt.slice(11, 16) : '00:00');
    const eEndTime = eEndDay > date
      ? '23:59'
      : (e.endsAt?.length > 10 ? e.endsAt.slice(11, 16) : (eStartTime || '23:59'));

    const pStartTime = from;
    const pEndTime = until || '23:59';

    const safeEnd = eEndTime <= eStartTime
      ? (eStartTime >= '23:00' ? '23:59' : `${String(Number(eStartTime.slice(0, 2)) + 1).padStart(2, '0')}:${eStartTime.slice(3, 5)}`)
      : eEndTime;

    return eStartTime < pEndTime && safeEnd > pStartTime;
  });

  const whisper = (() => {
    if (!isPlan || !dayContext.length) return null;

    const formatEvent = (ev: (typeof dayContext)[0]) => {
      const isMine = ev.ownerId === (space?.myId ?? String(space?.me ?? config.me));
      const who = isMine ? 'You' : partnerName(config, ev.ownerId);
      const eventTitle = ev.title?.trim() || Copy.availability.busy;

      let timeStr = 'All day';
      if (!ev.allDay) {
        const tStart = ev.startsAt.length > 10 ? prettyLower(ev.startsAt.slice(11, 16)) : '';
        const tEnd = ev.endsAt?.length > 10 ? prettyLower(ev.endsAt.slice(11, 16)) : '';
        if (tStart && tEnd && tEnd !== tStart) {
          timeStr = `${tStart} – ${tEnd}`;
        } else if (tStart) {
          timeStr = `from ${tStart}`;
        }
      } else {
        const sDate = ev.startsAt.slice(0, 10);
        const eDate = ev.endsAt ? ev.endsAt.slice(0, 10) : sDate;
        if (sDate !== eDate && eDate > sDate) {
          timeStr = `${shortDate(sDate)} – ${shortDate(eDate)}`;
        }
      }

      return `${who} · ${eventTitle} (${timeStr})`;
    };

    const first = dayContext[0];
    const second = dayContext[1];
    if (dayContext.length === 1 && first) {
      return formatEvent(first);
    }
    if (dayContext.length === 2 && first && second) {
      return `${formatEvent(first)} · ${formatEvent(second)}`;
    }
    return from
      ? `${dayContext.length} overlapping events at this time`
      : `${dayContext.length} shared events on this day`;
  })();

  async function save() {
    const clean = title.trim();
    if (!clean) {
      toast('Give it a name');
      return;
    }
    setSaving(true);
    const when = isPlan
      ? composeWhen({ date, from, until, endDate: multiDay ? end : null })
      : null;
    try {
      await create({
        title: clean,
        description: notes.trim() || null,
        location: location.trim() || null,
        image_url: cover,
        date_time: when?.date_time ?? null,
        ends_at: when?.ends_at ?? null,
      });
      close();
      if (isPlan) {
        setPicked(date);
        const d = parseISO(date);
        setCursor(iso(new Date(d.getFullYear(), d.getMonth(), 1)));
        setScreen('calendar');
      } else {
        setScreen('bucket');
      }
      toast(isPlan ? 'Made it a plan' : Copy.ideas.added);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Could not save');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Sheet
      open={mode !== null}
      onClose={close}
      heading={isPlan ? Copy.composer.newPlan : Copy.composer.newIdea}
    >
      {isPlan && (
        <span className={f.label} style={{ marginTop: 14 }}>
          Plan
        </span>
      )}
      <div className={f.group} style={isPlan ? undefined : { marginTop: 14 }}>
        <input
          className={f.input}
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder={isPlan ? 'Dinner at Alma' : 'Kayak the Grand River'}
          autoComplete="off"
          enterKeyHint="done"
          onKeyDown={(e) => {
            if (e.key === 'Enter') void save();
          }}
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

      <span className={f.label}>
        Notes <span className={f.hint}>— optional</span>
      </span>
      <div className={f.group}>
        <textarea
          className={f.input}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Anything worth remembering"
          rows={3}
        />
      </div>

      {isPlan && (
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

          <p className={f.rowNote} style={{ marginTop: 12 }}>
            {describePlan(
              composeWhen({
                date,
                from,
                until,
                endDate: multiDay ? end : null,
              }).date_time,
              composeWhen({
                date,
                from,
                until,
                endDate: multiDay ? end : null,
              }).ends_at,
            )}
          </p>

          {whisper && (
            <div className={f.whisper}>
              <span className={f.whisperGlyph} aria-hidden>💬</span>
              <span className={f.whisperText}>{whisper}</span>
            </div>
          )}
        </>
      )}

      <span className={f.label}>
        Cover <span className={f.hint}>— optional</span>
      </span>
      <CoverPicker value={cover} onChange={setCover} titleHint={() => title} />

      <div className={f.row}>
        <button type="button" className={`${f.btn} ${f.ghost}`} onClick={close}>
          Cancel
        </button>
        <button
          type="button"
          className={`${f.btn} ${f.accent}`}
          onClick={() => void save()}
          disabled={saving}
        >
          {isPlan ? Copy.composer.addPlan : Copy.composer.addIdea}
        </button>
      </div>
    </Sheet>
  );
}
