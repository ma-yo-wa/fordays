import { useEffect, useRef, useState } from 'react';
import {
  MONTHS,
  addDays,
  defaultAppleEndTime,
  defaultAppleStartTime,
  mediumDate,
  monthGrid,
  pad,
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

function Chevron({ dir }: { dir: 'left' | 'right' }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" aria-hidden>
      <path
        d={dir === 'left' ? 'M15 5 8 12l7 7' : 'M9 5l7 7-7 7'}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

interface TimeSlot {
  time: string;
  label: string;
  duration?: string;
}

function parseMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

function formatMinutes(totalMins: number): string {
  const normalized = ((totalMins % 1440) + 1440) % 1440;
  const h = Math.floor(normalized / 60);
  const m = normalized % 60;
  return `${pad(h)}:${pad(m)}`;
}

function formatDuration(diffMins: number): string {
  if (diffMins <= 0) return '';
  if (diffMins === 30) return '30 minutes';
  if (diffMins === 60) return '1 hour';
  if (diffMins % 60 === 0) return `${diffMins / 60} hours`;
  return `${(diffMins / 60).toFixed(1)} hours`;
}

function generateStartSlots(currentValue: string): TimeSlot[] {
  const slots: TimeSlot[] = [];
  for (let m = 0; m < 1440; m += 30) {
    const t = formatMinutes(m);
    slots.push({ time: t, label: pretty(t) });
  }
  if (currentValue && !slots.some((s) => s.time === currentValue)) {
    slots.push({ time: currentValue, label: `${pretty(currentValue)} (custom)` });
    slots.sort((a, b) => parseMinutes(a.time) - parseMinutes(b.time));
  }
  return slots;
}

function generateEndSlots(currentValue: string, baseFrom: string): TimeSlot[] {
  const startMins = parseMinutes(baseFrom || defaultAppleStartTime());
  const slots: TimeSlot[] = [];

  // Generate 24 clean half-hour steps (up to 12 hours duration)
  for (let step = 1; step <= 24; step++) {
    const dur = step * 30;
    const endT = formatMinutes(startMins + dur);
    slots.push({
      time: endT,
      label: pretty(endT),
      duration: formatDuration(dur),
    });
  }

  if (currentValue && !slots.some((s) => s.time === currentValue)) {
    const curMins = parseMinutes(currentValue);
    const diff = curMins >= startMins ? curMins - startMins : curMins + 1440 - startMins;
    slots.push({
      time: currentValue,
      label: `${pretty(currentValue)} (custom)`,
      duration: formatDuration(diff),
    });
    slots.sort((a, b) => {
      const diffA = (parseMinutes(a.time) - startMins + 1440) % 1440 || 1440;
      const diffB = (parseMinutes(b.time) - startMins + 1440) % 1440 || 1440;
      return diffA - diffB;
    });
  }

  return slots;
}

function TimeDropdownList({
  title,
  value,
  baseFrom,
  isUntil = false,
  onChange,
  onClose,
}: {
  title: string;
  value: string;
  baseFrom?: string;
  isUntil?: boolean;
  onChange: (time: string) => void;
  onClose: () => void;
}) {
  const listRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<HTMLButtonElement>(null);
  const [showCustom, setShowCustom] = useState(false);
  const [customH, setCustomH] = useState(() => {
    if (!value) return 12;
    const h = parseInt(value.split(':')[0] || '12', 10);
    return h % 12 === 0 ? 12 : h % 12;
  });
  const [customM, setCustomM] = useState(() => {
    if (!value) return 0;
    return parseInt(value.split(':')[1] || '0', 10);
  });
  const [customPM, setCustomPM] = useState(() => {
    if (!value) return false;
    const h = parseInt(value.split(':')[0] || '12', 10);
    return h >= 12;
  });

  const slots = isUntil
    ? generateEndSlots(value, baseFrom || '')
    : generateStartSlots(value);

  // Auto-scroll to selected slot on mount
  useEffect(() => {
    if (selectedRef.current) {
      selectedRef.current.scrollIntoView({ block: 'center', behavior: 'instant' });
    }
  }, []);

  function applyCustom() {
    let h24 = customH % 12;
    if (customPM) h24 += 12;
    onChange(`${pad(h24)}:${pad(customM)}`);
    onClose();
  }

  return (
    <div className={f.timeDropdown}>
      <div className={f.timeDropdownHeader}>
        <span className={f.timeDropdownTitle}>{title}</span>
        <button type="button" className={f.calNavBtn} onClick={onClose} aria-label="Close">
          ×
        </button>
      </div>

      <div className={f.timeDropdownList} ref={listRef}>
        {slots.map((slot) => {
          const isSelected = slot.time === value;
          return (
            <button
              key={slot.time}
              ref={isSelected ? selectedRef : null}
              type="button"
              className={`${f.timeDropdownItem} ${isSelected ? f.timeDropdownItemActive : ''}`}
              onClick={() => {
                onChange(slot.time);
                onClose();
              }}
            >
              <span className={f.timeDropdownTime}>{slot.label}</span>
              {slot.duration && (
                <span className={f.timeDropdownDuration}>{slot.duration}</span>
              )}
            </button>
          );
        })}
      </div>

      {showCustom ? (
        <div className={f.timeDropdownCustomBox}>
          <div className={f.timeDigitBox}>
            <input
              type="number"
              min="1"
              max="12"
              className={f.timeDigitInput}
              value={customH}
              onChange={(e) => setCustomH(Math.max(1, Math.min(12, parseInt(e.target.value, 10) || 1)))}
              aria-label="Hour"
            />
            <span className={f.timeColon}>:</span>
            <input
              type="number"
              min="0"
              max="59"
              className={f.timeDigitInput}
              value={pad(customM)}
              onChange={(e) => setCustomM(Math.max(0, Math.min(59, parseInt(e.target.value, 10) || 0)))}
              aria-label="Minute"
            />
          </div>
          <div className={f.timeAmPmToggle}>
            <button
              type="button"
              className={`${f.timeAmPmBtn} ${!customPM ? f.timeAmPmActive : ''}`}
              onClick={() => setCustomPM(false)}
            >
              AM
            </button>
            <button
              type="button"
              className={`${f.timeAmPmBtn} ${customPM ? f.timeAmPmActive : ''}`}
              onClick={() => setCustomPM(true)}
            >
              PM
            </button>
          </div>
          <button type="button" className={f.timeDoneBtn} onClick={applyCustom}>
            Set
          </button>
        </div>
      ) : (
        <button
          type="button"
          className={f.timeDropdownCustomToggle}
          onClick={() => setShowCustom(true)}
        >
          Type specific minute...
        </button>
      )}
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
  const currentYear = new Date().getFullYear();
  const monthTitle =
    cursorMonth.getFullYear() === currentYear
      ? MONTHS[cursorMonth.getMonth()]
      : `${MONTHS[cursorMonth.getMonth()]} ${cursorMonth.getFullYear()}`;

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
            <Chevron dir="left" />
          </button>
          <button
            type="button"
            className={f.calNavBtn}
            onClick={() => shiftMonth(1)}
            aria-label="Next month"
          >
            <Chevron dir="right" />
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
 * WhenFields: Apple Calendar / Notion style unified When card.
 *
 * - Starts row: Date capsule + Time capsule side-by-side.
 * - Tap date capsule to expand inline month grid (exact match to Plans page).
 * - Tap time capsule to open clean scrollable half-hour dropdown with relative durations.
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

        {/* Start Time Clean List */}
        {activeTimePicker === 'from' && (
          <TimeDropdownList
            title={multiDay ? 'Starts' : 'When'}
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

        {/* Multi-day End Time Clean List */}
        {multiDay && activeTimePicker === 'until' && (
          <TimeDropdownList
            title="Ends"
            value={until || (from ? defaultAppleEndTime(from) : defaultAppleStartTime())}
            baseFrom={from}
            isUntil
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

        {/* Single-day Until Time Clean List */}
        {!multiDay && activeTimePicker === 'until' && (
          <TimeDropdownList
            title="Until"
            value={until || (from ? defaultAppleEndTime(from) : defaultAppleStartTime())}
            baseFrom={from}
            isUntil
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
