import { useState } from 'react';
import { addDays, parseISO } from '../lib/date';
import f from './Form.module.css';

type Props = {
  date: string;
  from: string;
  until: string;
  end: string | null;
  multiDay: boolean;
  onFrom: (v: string) => void;
  onUntil: (v: string) => void;
  onEnd: (v: string | null) => void;
  onMultiDay: (open: boolean) => void;
};

function TimeField({
  value,
  onChange,
}: {
  value: string;
  onChange: (v: string) => void;
}) {
  const [tick, setTick] = useState(0);

  function clear(e: React.MouseEvent) {
    e.preventDefault();
    e.stopPropagation();
    onChange('');
    setTick((n) => n + 1);
  }

  return (
    <div className={f.timeBox}>
      <input
        key={tick}
        className={f.timeInput}
        type="time"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onInput={(e) => onChange((e.target as HTMLInputElement).value)}
      />
      {value ? (
        <button
          type="button"
          className={f.timeClear}
          onClick={clear}
          aria-label="Clear time"
          title="Clear time"
        >
          ×
        </button>
      ) : null}
    </div>
  );
}

/**
 * WhenFields: Multi-day end date sits right next to the date flow,
 * followed by a compact side-by-side time row (From & Until) with in-app clear buttons.
 */
export default function WhenFields({
  date,
  from,
  until,
  end,
  multiDay,
  onFrom,
  onUntil,
  onEnd,
  onMultiDay,
}: Props) {
  function openMultiDay() {
    onMultiDay(true);
    if (!end || end <= date) {
      onEnd(addDays(1, parseISO(date)));
    }
  }

  function closeMultiDay() {
    onMultiDay(false);
    onEnd(null);
  }

  return (
    <>
      {multiDay && (
        <div style={{ marginTop: 14 }}>
          <span className={f.label}>
            Ends on <span className={f.hint}>— last day</span>
          </span>
          <div className={f.group}>
            <input
              className={f.input}
              type="date"
              value={end ?? ''}
              min={date}
              onChange={(e) => onEnd(e.target.value || null)}
            />
          </div>
          <button
            type="button"
            className={f.textLink}
            onClick={closeMultiDay}
            style={{ marginTop: 6, marginBottom: 12 }}
          >
            Just one day
          </button>
        </div>
      )}

      <span className={f.label} style={{ marginTop: multiDay ? 0 : 14 }}>
        Time <span className={f.hint}>— optional</span>
      </span>
      <div className={f.timeRow}>
        <div className={f.timeCol}>
          <span className={f.timeColLabel}>{multiDay ? 'Starts at' : 'From'}</span>
          <TimeField value={from} onChange={onFrom} />
        </div>
        <div className={f.timeCol}>
          <span className={f.timeColLabel}>{multiDay ? 'Ends at' : 'Until'}</span>
          <TimeField value={until} onChange={onUntil} />
        </div>
      </div>

      {!multiDay && (
        <button
          type="button"
          className={f.textLink}
          onClick={openMultiDay}
          style={{ marginTop: 14 }}
        >
          Runs more than one day?
        </button>
      )}
    </>
  );
}
