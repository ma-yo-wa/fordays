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

function TimeInput({
  value,
  onChange,
}: {
  value: string;
  onChange: (v: string) => void;
}) {
  const [tick, setTick] = useState(0);

  function set(next: string) {
    onChange(next);
    if (!next) setTick((n) => n + 1);
  }

  return (
    <div className={f.group}>
      <div className={f.inputRow}>
        <input
          key={tick}
          className={f.input}
          type="time"
          value={value}
          onChange={(e) => set(e.target.value)}
          onInput={(e) => set((e.target as HTMLInputElement).value)}
        />
        {value ? (
          <button type="button" className={f.fieldClear} onClick={() => set('')}>
            Clear
          </button>
        ) : null}
      </div>
    </div>
  );
}

/** Day is chosen elsewhere. Default: From + Until. Multi-day stays hidden. */
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
      <span className={f.label}>
        From <span className={f.hint}>— optional</span>
      </span>
      <TimeInput value={from} onChange={onFrom} />

      <span className={f.label}>
        Until{' '}
        <span className={f.hint}>
          {multiDay ? '— on the last day, optional' : '— optional'}
        </span>
      </span>
      <TimeInput value={until} onChange={onUntil} />

      {!multiDay ? (
        <button type="button" className={f.textLink} onClick={openMultiDay}>
          Runs more than one day?
        </button>
      ) : (
        <>
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
          <button type="button" className={f.textLink} onClick={closeMultiDay}>
            Just one day
          </button>
        </>
      )}
    </>
  );
}
