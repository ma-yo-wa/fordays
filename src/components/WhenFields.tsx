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

/**
 * Forgiving human parser for user-typed times into the field:
 * - "01", "1" -> 1:00
 * - "02", "2" -> 2:00
 * - "1:15", "01:15" -> 1:15
 * - "130" -> 1:30
 * - "14" or "14:00" -> 2:00 PM
 * - "9am" -> 9:00 AM
 */
function parseUserTypedTime(raw: string, currentIsPM: boolean): { time: string; isPM: boolean } | null {
  const trimmed = raw.trim().toLowerCase();
  if (!trimmed) return null;

  let pm = currentIsPM;
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
    pm = true;
    h = h % 12 === 0 ? 12 : h % 12;
  } else if (h === 0) {
    pm = false;
    h = 12;
  } else if (h > 24) {
    return null;
  }

  let h24 = h % 12;
  if (pm) h24 += 12;

  return {
    time: `${pad(h24)}:${pad(m)}`,
    isPM: pm,
  };
}

function TimeField({
  value,
  onChange,
  onClear,
  isActive,
  onOpen,
  ariaLabel,
}: {
  value: string;
  onChange: (val: string) => void;
  onClear: () => void;
  isActive: boolean;
  onOpen: () => void;
  ariaLabel: string;
}) {
  const [h24Str, mStr] = value.split(':');
  const h24 = parseInt(h24Str || '0', 10);
  const m = parseInt(mStr || '0', 10);
  const isPM = h24 >= 12;
  const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
  const formattedDisplay = `${pad(h12)}:${pad(m)}`;

  const [text, setText] = useState(formattedDisplay);

  useEffect(() => {
    setText(formattedDisplay);
  }, [formattedDisplay]);

  function commitText(raw: string) {
    const parsed = parseUserTypedTime(raw, isPM);
    if (parsed) {
      onChange(parsed.time);
      const [newH24Str, newMStr] = parsed.time.split(':');
      const newH24 = parseInt(newH24Str || '0', 10);
      const newH12 = newH24 % 12 === 0 ? 12 : newH24 % 12;
      setText(`${pad(newH12)}:${pad(parseInt(newMStr || '0', 10))}`);
    } else {
      setText(formattedDisplay);
    }
  }

  function toggleAmPm(e: React.MouseEvent) {
    e.stopPropagation();
    let newH24 = h12 % 12;
    if (!isPM) newH24 += 12;
    onChange(`${pad(newH24)}:${pad(m)}`);
  }

  return (
    <div className={`${f.appleTimeWrapper} ${isActive ? f.appleTimeWrapperActive : ''}`}>
      <input
        type="text"
        inputMode="numeric"
        className={f.appleTimeInput}
        value={text}
        aria-label={ariaLabel}
        onFocus={onOpen}
        onClick={onOpen}
        onChange={(e) => {
          setText(e.target.value);
          if (/^\d{2}:\d{2}$/.test(e.target.value)) {
            commitText(e.target.value);
          }
        }}
        onBlur={() => commitText(text)}
        onKeyDown={(e) => {
          if (e.key === 'Enter') {
            (e.target as HTMLInputElement).blur();
          }
        }}
      />
      <button
        type="button"
        className={f.appleAmPmBtn}
        onClick={toggleAmPm}
        title="Toggle AM/PM"
        aria-label="Toggle AM/PM"
      >
        {isPM ? 'PM' : 'AM'} <span className={f.ampmChevron}>↕</span>
      </button>
      <button
        type="button"
        className={f.appleTimeClear}
        onClick={(e) => {
          e.stopPropagation();
          onClear();
        }}
        aria-label="Clear time"
        title="Clear time"
      >
        ×
      </button>
    </div>
  );
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

  const slots = isUntil
    ? generateEndSlots(value, baseFrom || '')
    : generateStartSlots(value);

  useEffect(() => {
    if (selectedRef.current) {
      selectedRef.current.scrollIntoView({ block: 'center', behavior: 'instant' });
    }
  }, []);

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
 * - Starts row: Date capsule + Typeable Time field side-by-side.
 * - Tap date capsule to expand inline month grid (exact match to Plans page).
 * - Tap/focus time field to open clean scrollable half-hour dropdown with relative durations.
 * - Directly typeable time field ("01", "02", "1:15", etc.) + AM/PM toggle button.
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
              <TimeField
                value={from}
                onChange={onFrom}
                onClear={() => {
                  onFrom('');
                  onUntil('');
                  if (activeTimePicker === 'from') setActiveTimePicker(null);
                }}
                isActive={activeTimePicker === 'from'}
                onOpen={() => {
                  setActiveTimePicker('from');
                  setPickerOpen(false);
                }}
                ariaLabel="Start time"
              />
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
                  <TimeField
                    value={until}
                    onChange={onUntil}
                    onClear={() => {
                      onUntil('');
                      if (activeTimePicker === 'until') setActiveTimePicker(null);
                    }}
                    isActive={activeTimePicker === 'until'}
                    onOpen={() => {
                      setActiveTimePicker('until');
                      setPickerOpen(false);
                    }}
                    ariaLabel="End time"
                  />
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
              <TimeField
                value={until}
                onChange={onUntil}
                onClear={() => {
                  onUntil('');
                  if (activeTimePicker === 'until') setActiveTimePicker(null);
                }}
                isActive={activeTimePicker === 'until'}
                onOpen={() => {
                  setActiveTimePicker('until');
                  setPickerOpen(false);
                }}
                ariaLabel="Until time"
              />
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
