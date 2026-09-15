import { useState } from 'react';
import {
  MONTHS,
  addDays,
  defaultAppleEndTime,
  defaultAppleStartTime,
  mediumDate,
  monthGrid,
  parseISO,
  pretty,
  todayISO,
} from '../lib/date';
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

const DOW = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const MINUTES_5 = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
const HOURS_12 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

function parseHHMM(time: string): { h12: number; m: number; isPM: boolean } {
  if (!time) {
    const def = defaultAppleStartTime();
    const [defH, defM] = def.split(':').map(Number);
    return {
      h12: (defH ?? 11) % 12 === 0 ? 12 : (defH ?? 11) % 12,
      m: defM ?? 0,
      isPM: (defH ?? 11) >= 12,
    };
  }
  const [hRaw, mRaw] = time.split(':').map(Number);
  const h = hRaw ?? 0;
  const m = mRaw ?? 0;
  const isPM = h >= 12;
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return { h12, m, isPM };
}

function formatHHMM(h12: number, m: number, isPM: boolean): string {
  let h24 = h12 % 12;
  if (isPM) h24 += 12;
  return `${String(h24).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function TimeDrawer({
  title,
  value,
  onChange,
  onClose,
}: {
  title: string;
  value: string;
  onChange: (v: string) => void;
  onClose: () => void;
}) {
  const { h12, m, isPM } = parseHHMM(value);

  function setHour(newH12: number) {
    const clamped = Math.max(1, Math.min(12, newH12));
    onChange(formatHHMM(clamped, m, isPM));
  }

  function setMinute(newM: number) {
    const clamped = Math.max(0, Math.min(59, newM));
    onChange(formatHHMM(h12, clamped, isPM));
  }

  function setPM(pm: boolean) {
    onChange(formatHHMM(h12, m, pm));
  }

  return (
    <div className={f.appleTimeDrawer}>
      <div className={f.timeDrawerHeader}>
        <span className={f.timeDrawerTitle}>{title}</span>
        <button type="button" className={f.timeDoneBtn} onClick={onClose}>
          Done
        </button>
      </div>

      {/* Tap-to-type Direct Row */}
      <div className={f.timeDirectRow}>
        <div className={f.timeDigitBox}>
          <input
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            className={f.timeDigitInput}
            value={h12}
            onChange={(e) => {
              const val = parseInt(e.target.value, 10);
              if (!isNaN(val)) setHour(val);
            }}
            aria-label="Hour"
          />
          <span className={f.timeColon}>:</span>
          <input
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            className={f.timeDigitInput}
            value={String(m).padStart(2, '0')}
            onChange={(e) => {
              const val = parseInt(e.target.value, 10);
              if (!isNaN(val)) setMinute(val);
            }}
            aria-label="Minute"
          />
        </div>

        <div className={f.timeAmPmToggle}>
          <button
            type="button"
            className={`${f.timeAmPmBtn} ${!isPM ? f.timeAmPmActive : ''}`}
            onClick={() => setPM(false)}
          >
            AM
          </button>
          <button
            type="button"
            className={`${f.timeAmPmBtn} ${isPM ? f.timeAmPmActive : ''}`}
            onClick={() => setPM(true)}
          >
            PM
          </button>
        </div>
      </div>

      {/* 5-minute ticks */}
      <span className={f.timeSectionLabel}>Minutes</span>
      <div className={f.timeChipsGrid}>
        {MINUTES_5.map((minVal) => {
          const active = m === minVal;
          const label = `:${String(minVal).padStart(2, '0')}`;
          return (
            <button
              key={minVal}
              type="button"
              className={`${f.timeChip} ${active ? f.timeChipActive : ''}`}
              onClick={() => setMinute(minVal)}
            >
              {label}
            </button>
          );
        })}
      </div>

      {/* Quick Hours */}
      <span className={f.timeSectionLabel}>Hours</span>
      <div className={f.timeHoursGrid}>
        {HOURS_12.map((hVal) => {
          const active = h12 === hVal;
          return (
            <button
              key={hVal}
              type="button"
              className={`${f.timeHourChip} ${active ? f.timeHourChipActive : ''}`}
              onClick={() => setHour(hVal)}
            >
              {hVal}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function InlineMonthCalendar({
  selectedDate,
  onSelect,
}: {
  selectedDate: string;
  onSelect: (date: string) => void;
}) {
  const [cursorMonth, setCursorMonth] = useState<Date>(() => parseISO(selectedDate));
  const today = todayISO();

  function shiftMonth(delta: number) {
    setCursorMonth(
      new Date(cursorMonth.getFullYear(), cursorMonth.getMonth() + delta, 1),
    );
  }

  const cells = monthGrid(cursorMonth);
  const monthTitle = `${MONTHS[cursorMonth.getMonth()]} ${cursorMonth.getFullYear()}`;

  return (
    <div className={f.appleCalendarBox}>
      <div className={f.calHeader}>
        <span className={f.calMonthTitle}>{monthTitle}</span>
        <div className={f.calNavGroup}>
          <button
            type="button"
            className={f.calNavBtn}
            onClick={() => shiftMonth(-1)}
            aria-label="Previous month"
          >
            ‹
          </button>
          <button
            type="button"
            className={f.calNavBtn}
            onClick={() => shiftMonth(1)}
            aria-label="Next month"
          >
            ›
          </button>
        </div>
      </div>

      <div className={f.calDow}>
        {DOW.map((d, i) => (
          <span key={i}>{d}</span>
        ))}
      </div>

      <div className={f.calGrid}>
        {cells.map((cell, i) => {
          if (cell.outside || !cell.date) {
            return (
              <div key={i} className={`${f.calDay} ${f.calOutside}`}>
                <span className={f.calNum}>{cell.label}</span>
              </div>
            );
          }
          const isToday = cell.date === today;
          const isPicked = cell.date === selectedDate;
          const classNames = [
            f.calDay,
            isToday ? f.calToday : '',
            isPicked ? f.calPicked : '',
          ]
            .filter(Boolean)
            .join(' ');

          return (
            <button
              key={i}
              type="button"
              className={classNames}
              onClick={() => onSelect(cell.date as string)}
            >
              <span className={f.calNum}>{cell.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

/**
 * WhenFields: Apple Calendar style unified When card.
 *
 * - Starts row: Date capsule + Time capsule side-by-side.
 * - Tap date capsule to expand inline month grid (exact match to Plans page).
 * - Segmented 5-minute time popover with tap-to-type direct numeric input.
 * - Apple Next Half-Hour Rule on default start time.
 * - Apple 1-Hour Duration Rule on default end time.
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
  const [activeTimePicker, setActiveTimePicker] = useState<'from' | 'until' | null>(null);

  function openMultiDay() {
    onMultiDay(true);
    if (!end || end <= date) {
      onEnd(addDays(1, parseISO(date)));
    }
  }

  function closeMultiDay() {
    onMultiDay(false);
    onEnd(null);
    if (activeTimePicker === 'until') setActiveTimePicker(null);
  }

  function addDefaultTime() {
    const def = defaultAppleStartTime();
    onFrom(def);
  }

  function addDefaultEndTime() {
    if (!from) {
      addDefaultTime();
      return;
    }
    onUntil(defaultAppleEndTime(from));
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
              onClick={() => {
                setPickerOpen((v) => !v);
                setActiveTimePicker(null);
              }}
              aria-label="Pick date"
            >
              {mediumDate(date)} {pickerOpen ? '⌃' : '⌵'}
            </button>

            {from ? (
              <div className={f.appleTimeWrapper}>
                <button
                  type="button"
                  className={`${f.appleTimePill} ${activeTimePicker === 'from' ? f.applePillActive : ''}`}
                  onClick={() => {
                    setActiveTimePicker((cur) => (cur === 'from' ? null : 'from'));
                    setPickerOpen(false);
                  }}
                  aria-label="Pick start time"
                >
                  {pretty(from)}
                </button>
                <button
                  type="button"
                  className={f.appleTimeClear}
                  onClick={() => {
                    onFrom('');
                    onUntil('');
                    if (activeTimePicker === 'from') setActiveTimePicker(null);
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
                onClick={() => {
                  addDefaultTime();
                  setActiveTimePicker('from');
                  setPickerOpen(false);
                }}
              >
                + Add time
              </button>
            )}
          </div>
        </div>

        {/* Inline Month Calendar (Matches Plans page) */}
        {pickerOpen && (
          <InlineMonthCalendar
            selectedDate={date}
            onSelect={(next) => {
              onDate(next);
              if (end && end <= next) onEnd(null);
              setPickerOpen(false);
            }}
          />
        )}

        {/* Start Time Drawer */}
        {activeTimePicker === 'from' && (
          <TimeDrawer
            title={multiDay ? 'Starts time' : 'Time'}
            value={from || defaultAppleStartTime()}
            onChange={onFrom}
            onClose={() => setActiveTimePicker(null)}
          />
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
                    <button
                      type="button"
                      className={`${f.appleTimePill} ${activeTimePicker === 'until' ? f.applePillActive : ''}`}
                      onClick={() => {
                        setActiveTimePicker((cur) => (cur === 'until' ? null : 'until'));
                        setPickerOpen(false);
                      }}
                      aria-label="Pick end time"
                    >
                      {pretty(until)}
                    </button>
                    <button
                      type="button"
                      className={f.appleTimeClear}
                      onClick={() => {
                        onUntil('');
                        if (activeTimePicker === 'until') setActiveTimePicker(null);
                      }}
                      aria-label="Clear end time"
                    >
                      ×
                    </button>
                  </div>
                ) : (
                  <button
                    type="button"
                    className={f.applePill}
                    onClick={() => {
                      addDefaultEndTime();
                      setActiveTimePicker('until');
                      setPickerOpen(false);
                    }}
                  >
                    + End time
                  </button>
                )
              )}
            </div>
          </div>
        )}

        {/* Multi-day End Time Drawer */}
        {multiDay && activeTimePicker === 'until' && (
          <TimeDrawer
            title="Ends time"
            value={until || (from ? defaultAppleEndTime(from) : defaultAppleStartTime())}
            onChange={onUntil}
            onClose={() => setActiveTimePicker(null)}
          />
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
                <button
                  type="button"
                  className={`${f.appleTimePill} ${activeTimePicker === 'until' ? f.applePillActive : ''}`}
                  onClick={() => {
                    setActiveTimePicker((cur) => (cur === 'until' ? null : 'until'));
                    setPickerOpen(false);
                  }}
                  aria-label="Pick end time"
                >
                  {pretty(until)}
                </button>
                <button
                  type="button"
                  className={f.appleTimeClear}
                  onClick={() => {
                    onUntil('');
                    if (activeTimePicker === 'until') setActiveTimePicker(null);
                  }}
                  aria-label="Clear end time"
                >
                  ×
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Single-day Until Time Drawer */}
        {!multiDay && activeTimePicker === 'until' && (
          <TimeDrawer
            title="Until"
            value={until || (from ? defaultAppleEndTime(from) : defaultAppleStartTime())}
            onChange={onUntil}
            onClose={() => setActiveTimePicker(null)}
          />
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
                onClick={() => {
                  addDefaultEndTime();
                  setActiveTimePicker('until');
                  setPickerOpen(false);
                }}
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
