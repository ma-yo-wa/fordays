import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import CoverPicker from './CoverPicker';
import WhenFields from './WhenFields';
import { LocationInput } from './LocationInput';
import { useApp } from '../lib/store';
import { composeWhen, describePlan, iso, parseISO, todayISO } from '../lib/date';
import { Copy } from '../lib/copy';
import { Button, Input } from '../ui';
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
  const [sessionKey, setSessionKey] = useState(0);

  useEffect(() => {
    if (!mode) return;
    setSessionKey((k) => k + 1);
    setTitle(draft?.title ?? '');
    setLocation(draft?.location ?? '');
    setNotes(draft?.notes ?? '');
    setCover(draft?.cover ?? null);
    const today = todayISO();
    // A plan opens on the draft date if provided, or the day you were already looking at (never in the past).
    const initialDate =
      draft?.date && draft.date >= today
        ? draft.date
        : picked >= today
          ? picked
          : today;
    setDate(initialDate);
    setFrom(draft?.from ?? '');
    setUntil(draft?.until ?? '');
    setEnd(draft?.endDate ?? null);
    setMultiDay(draft?.multiDay ?? Boolean(draft?.endDate));
    setSaving(false);
  }, [mode, picked, draft]);

  async function save() {
    const clean = title.trim();
    if (!clean) {
      toast('Give it a name');
      return;
    }
    if (isPlan && date < todayISO()) {
      toast("Plans can't be set in the past");
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
      <div style={{ marginTop: 'var(--space-3-5)' }}>
        <Input
          label={isPlan ? 'Plan' : undefined}
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

      {isPlan && (
        <>
          <WhenFields
            date={date}
            from={from}
            until={until}
            end={end}
            multiDay={multiDay}
            minDate={todayISO()}
            onDate={setDate}
            onFrom={setFrom}
            onUntil={setUntil}
            onEnd={setEnd}
            onMultiDay={setMultiDay}
          />

          <p className={f.rowNote} style={{ marginTop: 'var(--space-3)' }}>
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
        </>
      )}

      {cover === null && (
        <button
          type="button"
          className={f.coverAddBtn}
          onClick={() => setCover('')}
        >
          + Add cover <span className={f.hint}>— photo or GIF</span>
        </button>
      )}

      {cover !== null && (
        <>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', margin: 'var(--space-4) 0 var(--space-2)' }}>
            <span className={f.label} style={{ margin: 0 }}>
              Cover
            </span>
            {cover === '' && (
              <button
                type="button"
                onClick={() => setCover(null)}
                className={f.hint}
                style={{
                  background: 'none', border: 'none', padding: 0, cursor: 'pointer', color: 'var(--ink-soft)'
                }}
              >
                Cancel
              </button>
            )}
          </div>
          <CoverPicker key={sessionKey} value={cover} onChange={setCover} titleHint={() => title} />
        </>
      )}

      <div className={f.row} style={{ marginTop: cover !== null ? 'var(--space-2)' : 'var(--space-5)' }}>
        <Button variant="secondary" onClick={close}>
          Cancel
        </Button>
        <Button
          variant="primary"
          onClick={() => void save()}
          loading={saving}
          disabled={saving}
        >
          {isPlan ? Copy.composer.addPlan : Copy.composer.addIdea}
        </Button>
      </div>
    </Sheet>
  );
}
