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
  minDate?: string;
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
    slots.push({ time: currentValue, label: pretty(currentValue) });
    slots.sort((a, b) => parseMinutes(a.time) - parseMinutes(b.time));
  }
  return slots;
}

function generateEndSlots(currentValue: string, baseFrom: string, sameDay: boolean): TimeSlot[] {
  const startMins = parseMinutes(baseFrom || defaultAppleStartTime());
  const slots: TimeSlot[] = [];

  for (let step = 1; step <= 24; step++) {
    const dur = step * 30;
    // Same day: past midnight would read as a backwards window.
    if (sameDay && startMins + dur >= 1440) break;
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
      label: pretty(currentValue),
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

/**
 * Forgiving human parser for custom typed times:
 * - "01", "1" -> 1:00
 * - "02", "2" -> 2:00
 * - "1:15", "01:15" -> 1:15
 * - "130" -> 1:30
 * - "14" or "14:00" -> 2:00 PM
 * - "9am", "9:30pm"
 */
function parseUserTypedTime(raw: string, currentValue: string): string | null {
  const trimmed = raw.trim().toLowerCase();
  if (!trimmed) return null;

  const currentH24 = currentValue ? parseInt(currentValue.split(':')[0] || '12', 10) : 12;
  const currentIsPM = currentH24 >= 12;

  let pm: boolean | null = null;
  let cleaned = trimmed;
  if (trimmed.includes('am')) {
    pm = false;
    cleaned = trimmed.replace('am', '').trim();
  } else if (trimmed.includes('pm')) {
    pm = true;
    cleaned = trimmed.replace('pm', '').trim();
  }

  let h = 0;
  let m = 0;

  if (cleaned.includes(':')) {
    const [hPart, mPart] = cleaned.split(':');
    h = parseInt(hPart || '0', 10);
    m = parseInt(mPart || '0', 10);
  } else if (/^\d{3,4}$/.test(cleaned)) {
    if (cleaned.length === 3) {
      h = parseInt(cleaned.slice(0, 1), 10);
      m = parseInt(cleaned.slice(1), 10);
    } else {
      h = parseInt(cleaned.slice(0, 2), 10);
      m = parseInt(cleaned.slice(2), 10);
    }
  } else if (/^\d{1,2}$/.test(cleaned)) {
    h = parseInt(cleaned, 10);
    m = 0;
  } else {
    return null;
  }

  if (isNaN(h) || isNaN(m) || m < 0 || m > 59) return null;

  if (h >= 12 && h < 24) {
    if (pm === null) pm = true;
    h = h % 12 === 0 ? 12 : h % 12;
  } else if (h === 0) {
    if (pm === null) pm = false;
    h = 12;
  } else if (h > 24) {
    return null;
  }

  if (pm === null) {
    pm = currentIsPM;
  }

  let h24 = h % 12;
  if (pm) h24 += 12;

  return `${pad(h24)}:${pad(m)}`;
}

/**
 * Apple Web style floating time popover.
 * - Floats directly beneath the time pill with soft shadow.
 * - Clean list of 30-minute intervals with relative durations for end times.
 * - Optional "Reset time" at the top to clear.
 * - Quiet custom time input at the bottom.
 * - Dismisses on outside click.
 */
function TimeDropdownList({
  value,
  baseFrom,
  isUntil = false,
  sameDay = false,
  onChange,
  onReset,
  onClose,
}: {
  value: string;
  baseFrom?: string;
  isUntil?: boolean;
  sameDay?: boolean;
  onChange: (time: string) => void;
  onReset?: () => void;
  onClose: () => void;
}) {
  const popoverRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<HTMLButtonElement>(null);

  const baseTime = value || (baseFrom ? defaultAppleEndTime(baseFrom) : defaultAppleStartTime());
  const [h24Str, mStr] = baseTime.split(':');
  const initH24 = parseInt(h24Str || '12', 10);
  const initM = parseInt(mStr || '0', 10);
  const [isPM, setIsPM] = useState(initH24 >= 12);
  const h12 = initH24 % 12 === 0 ? 12 : initH24 % 12;
  const [minuteText, setMinuteText] = useState(pad(initM));

  const slots = isUntil
    ? generateEndSlots(value, baseFrom || '', sameDay)
    : generateStartSlots(value);

  useEffect(() => {
    if (selectedRef.current) {
      selectedRef.current.scrollIntoView({ block: 'center', behavior: 'instant' });
    }
  }, []);

  useEffect(() => {
    function handlePointerDown(e: PointerEvent) {
      if (popoverRef.current && !popoverRef.current.contains(e.target as Node)) {
        onClose();
      }
    }
    document.addEventListener('pointerdown', handlePointerDown);
    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
    };
  }, [onClose]);

  function handleDone() {
    if (minuteText.includes(':')) {
      const parsed = parseUserTypedTime(minuteText, value);
      if (parsed) {
        onChange(parsed);
        onClose();
        return;
      }
    }
    let mNum = parseInt(minuteText || '0', 10);
    if (isNaN(mNum)) mNum = 0;
    mNum = Math.max(0, Math.min(59, mNum));
    let finalH24 = h12 % 12;
    if (isPM) finalH24 += 12;
    onChange(`${pad(finalH24)}:${pad(mNum)}`);
    onClose();
  }

  function toggleAmPm(e: React.MouseEvent) {
    e.stopPropagation();
    setIsPM((prev) => !prev);
  }

  return (
    <div className={f.timeDropdown} ref={popoverRef}>
      {onReset && (
        <div className={f.timeDropdownTopRow}>
          <button
            type="button"
            className={f.timeDropdownClearBtn}
            onClick={() => {
              onReset();
              onClose();
            }}
          >
            Clear
          </button>
        </div>
      )}

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

      <form
        className={f.timeDropdownFooterRow}
        onSubmit={(e) => {
          e.preventDefault();
          handleDone();
        }}
      >
        <div className={f.timeDropdownMinuteGroup}>
          <span className={f.timeDropdownHourDisplay}>{h12} :</span>
          <input
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            maxLength={2}
            className={f.timeDropdownMinuteInput}
            value={minuteText}
            onFocus={(e) => e.target.select()}
            onChange={(e) => {
              const cleaned = e.target.value.replace(/\D/g, '');
              setMinuteText(cleaned);
            }}
            aria-label="Minute"
          />
          <button
            type="button"
            className={f.timeDropdownAmPmToggle}
            onClick={toggleAmPm}
            title="Toggle AM/PM"
          >
            {isPM ? 'PM' : 'AM'}
          </button>
        </div>

        <button type="submit" className={f.timeDropdownDoneBtn}>
          Done
        </button>
      </form>
    </div>
  );
}

function InlineMonthCalendar({
  selectedDate,
  minDate,
  onSelect,
}: {
  selectedDate: string;
  minDate?: string;
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
          const isDisabled = Boolean(minDate && cell.date && cell.date < minDate);
          const classNames = [
            f.calDay,
            isToday ? f.calToday : '',
            isPicked ? f.calPicked : '',
            isDisabled ? f.calDisabled : '',
          ]
            .filter(Boolean)
            .join(' ');

          return (
            <button
              key={i}
              type="button"
              className={classNames}
              disabled={isDisabled}
              onClick={() => {
                if (!isDisabled && cell.date) onSelect(cell.date);
              }}
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
 * WhenFields: Apple Calendar Web style unified When card.
 *
 * - Starts row: Date capsule + Time capsule side-by-side as twin clean pills.
 * - Tap date capsule to expand inline month grid (exact match to Plans page).
 * - Tap time capsule to open Apple-style floating popover with relative durations.
 * - Popover has zero header chrome, a quiet "Reset time" top item, and a quiet custom minute bar at the bottom.
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
  minDate,
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
      <span className={f.label} style={{ marginTop: 'var(--space-3-5)' }}>
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
              <div className={f.appleTimeContainer}>
                <button
                  type="button"
                  className={`${f.applePill} ${activeTimePicker === 'from' ? f.applePillActive : ''}`}
                  onClick={() => {
                    setActiveTimePicker((cur) => (cur === 'from' ? null : 'from'));
                    setPickerOpen(false);
                  }}
                  aria-label="Pick start time"
                >
                  {pretty(from)} {activeTimePicker === 'from' ? '⌃' : '⌵'}
                </button>

                {activeTimePicker === 'from' && (
                  <TimeDropdownList
                    value={from || defaultAppleStartTime()}
                    onChange={onFrom}
                    onReset={() => {
                      onFrom('');
                      onUntil('');
                      setActiveTimePicker(null);
                    }}
                    onClose={() => setActiveTimePicker(null)}
                  />
                )}
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
            minDate={minDate}
            onSelect={(next) => {
              onDate(next);
              if (end && end <= next) onEnd(null);
              setPickerOpen(false);
            }}
          />
        )}

        {/* Multi-day Ends Row */}
        {multiDay && (
          <div
            className={f.appleWhenRow}
            style={{ borderTop: 'var(--hairline-w) solid var(--separator)' }}
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
                  <div className={f.appleTimeContainer}>
                    <button
                      type="button"
                      className={`${f.applePill} ${activeTimePicker === 'until' ? f.applePillActive : ''}`}
                      onClick={() => {
                        setActiveTimePicker((cur) => (cur === 'until' ? null : 'until'));
                        setPickerOpen(false);
                      }}
                      aria-label="Pick end time"
                    >
                      {pretty(until)} {activeTimePicker === 'until' ? '⌃' : '⌵'}
                    </button>

                    {activeTimePicker === 'until' && (
                      <TimeDropdownList
                        value={until || (from ? defaultAppleEndTime(from) : defaultAppleStartTime())}
                        baseFrom={from}
                        isUntil
                        onChange={onUntil}
                        onReset={() => {
                          onUntil('');
                          setActiveTimePicker(null);
                        }}
                        onClose={() => setActiveTimePicker(null)}
                      />
                    )}
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

        {/* Single-day Until Row (if set) */}
        {!multiDay && from && until && (
          <div
            className={f.appleWhenRow}
            style={{ borderTop: 'var(--hairline-w) solid var(--separator)' }}
          >
            <span className={f.appleWhenLabel}>Until</span>
            <div className={f.applePillGroup}>
              <div className={f.appleTimeContainer}>
                <button
                  type="button"
                  className={`${f.applePill} ${activeTimePicker === 'until' ? f.applePillActive : ''}`}
                  onClick={() => {
                    setActiveTimePicker((cur) => (cur === 'until' ? null : 'until'));
                    setPickerOpen(false);
                  }}
                  aria-label="Pick until time"
                >
                  {pretty(until)} {activeTimePicker === 'until' ? '⌃' : '⌵'}
                </button>

                {activeTimePicker === 'until' && (
                  <TimeDropdownList
                    value={until || (from ? defaultAppleEndTime(from) : defaultAppleStartTime())}
                    baseFrom={from}
                    isUntil
                    sameDay
                    onChange={onUntil}
                    onReset={() => {
                      onUntil('');
                      setActiveTimePicker(null);
                    }}
                    onClose={() => setActiveTimePicker(null)}
                  />
                )}
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
