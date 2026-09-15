import { useState } from 'react';
import { DayPicker } from 'react-day-picker';
import 'react-day-picker/style.css';
import { addDays, iso, mediumDate, parseISO } from '../lib/date';
import f from './Form.module.css';

type Props = {
  date: string;
  from: string;
  until: string;
  end: string | null;
  multiDay: boolean;
  onDate: (v: string) => void;
  onFrom: (v: string) => void;
  onUntil: (v: string) => void;
  onEnd: (v: string | null) => void;
  onMultiDay: (open: boolean) => void;
};

/**
 * WhenFields: Apple Calendar style unified When card.
 *
 * - Starts row: Date capsule + Time capsule side-by-side.
 * - Tap date capsule to expand inline Apple-style month grid.
 * - 5-minute interval stepping with step="300".
 * - Ends row: revealed conditionally for Until or Multi-day.
 * - Soft blanks are valid: never force Until or Ends on.
 */
export default function WhenFields({
  date,
  from,
  until,
  end,
  multiDay,
  onDate,
  onFrom,
  onUntil,
  onEnd,
  onMultiDay,
}: Props) {
  const [pickerOpen, setPickerOpen] = useState(false);

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

  function addDefaultTime() {
    const now = new Date();
    const rem = now.getMinutes() % 5;
    const rounded = new Date(now.getTime() + (5 - rem) * 60 * 1000);
    const h = String(rounded.getHours()).padStart(2, '0');
    const m = String(rounded.getMinutes()).padStart(2, '0');
    onFrom(`${h}:${m}`);
  }

  function addDefaultEndTime() {
    if (!from) {
      addDefaultTime();
      return;
    }
    const [h, m] = from.split(':').map(Number);
    const endH = Math.min((h ?? 0) + 2, 23);
    onUntil(`${String(endH).padStart(2, '0')}:${String(m ?? 0).padStart(2, '0')}`);
  }

  return (
    <>
      <span className={f.label} style={{ marginTop: 14 }}>
        When
      </span>

      <div className={f.appleWhenCard}>
        {/* Starts / When Row */}
        <div className={f.appleWhenRow}>
          <span className={f.appleWhenLabel}>{multiDay ? 'Starts' : 'When'}</span>
          <div className={f.applePillGroup}>
            <button
              type="button"
              className={`${f.applePill} ${pickerOpen ? f.applePillActive : ''}`}
              onClick={() => setPickerOpen((v) => !v)}
              aria-label="Pick date"
            >
              {mediumDate(date)} {pickerOpen ? '⌃' : '⌵'}
            </button>

            {from ? (
              <div className={f.appleTimeWrapper}>
                <input
                  type="time"
                  step="300"
                  className={f.appleTimeInput}
                  value={from}
                  onChange={(e) => onFrom(e.target.value)}
                  onInput={(e) => onFrom((e.target as HTMLInputElement).value)}
                />
                <button
                  type="button"
                  className={f.appleTimeClear}
                  onClick={() => {
                    onFrom('');
                    onUntil('');
                  }}
                  aria-label="Clear time"
                  title="Clear time"
                >
                  ×
                </button>
              </div>
            ) : (
              <button
                type="button"
                className={f.applePill}
                onClick={addDefaultTime}
              >
                + Add time
              </button>
            )}
          </div>
        </div>

        {/* Inline Apple Calendar Grid */}
        {pickerOpen && (
          <div className={f.appleCalendarBox}>
            <DayPicker
              className={f.picker}
              mode="single"
              required
              selected={parseISO(date)}
              defaultMonth={parseISO(date)}
              onSelect={(d) => {
                if (!d) return;
                const next = iso(d);
                onDate(next);
                if (end && end <= next) onEnd(null);
                setPickerOpen(false);
              }}
            />
          </div>
        )}

        {/* Multi-day Ends Row */}
        {multiDay && (
          <div
            className={f.appleWhenRow}
            style={{ borderTop: '1px solid rgba(0, 0, 0, 0.06)' }}
          >
            <span className={f.appleWhenLabel}>Ends</span>
            <div className={f.applePillGroup}>
              <input
                type="date"
                className={f.appleDateInput}
                min={date}
                value={end ?? ''}
                onChange={(e) => onEnd(e.target.value || null)}
              />
              {from && (
                until ? (
                  <div className={f.appleTimeWrapper}>
                    <input
                      type="time"
                      step="300"
                      className={f.appleTimeInput}
                      value={until}
                      onChange={(e) => onUntil(e.target.value)}
                      onInput={(e) => onUntil((e.target as HTMLInputElement).value)}
                    />
                    <button
                      type="button"
                      className={f.appleTimeClear}
                      onClick={() => onUntil('')}
                      aria-label="Clear end time"
                    >
                      ×
                    </button>
                  </div>
                ) : (
                  <button
                    type="button"
                    className={f.applePill}
                    onClick={addDefaultEndTime}
                  >
                    + End time
                  </button>
                )
              )}
            </div>
          </div>
        )}

        {/* Single-day Until Row (if set) */}
        {!multiDay && from && until && (
          <div
            className={f.appleWhenRow}
            style={{ borderTop: '1px solid rgba(0, 0, 0, 0.06)' }}
          >
            <span className={f.appleWhenLabel}>Until</span>
            <div className={f.applePillGroup}>
              <div className={f.appleTimeWrapper}>
                <input
                  type="time"
                  step="300"
                  className={f.appleTimeInput}
                  value={until}
                  onChange={(e) => onUntil(e.target.value)}
                  onInput={(e) => onUntil((e.target as HTMLInputElement).value)}
                />
                <button
                  type="button"
                  className={f.appleTimeClear}
                  onClick={() => onUntil('')}
                  aria-label="Clear end time"
                >
                  ×
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Sub-row links */}
      <div className={f.appleSubRow}>
        {!multiDay ? (
          <>
            {from && !until ? (
              <button
                type="button"
                className={f.textLink}
                onClick={addDefaultEndTime}
              >
                + Add end time
              </button>
            ) : (
              <span />
            )}
            <button
              type="button"
              className={f.textLink}
              onClick={openMultiDay}
            >
              Runs more than one day?
            </button>
          </>
        ) : (
          <button
            type="button"
            className={f.textLink}
            onClick={closeMultiDay}
          >
            Just one day
          </button>
        )}
      </div>
    </>
  );
}
