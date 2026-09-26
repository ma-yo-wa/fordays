import { useEffect, useMemo, useState } from 'react';
import type { ImportedCalendar } from '../lib/calendars';
import { Copy } from '../lib/copy';
import f from './Form.module.css';
import s from './GcalPicker.module.css';

interface Props {
  calendars: ImportedCalendar[];
  /** Ticked already; none means a first connect, which ticks the main one. */
  selectedIds: string[];
  /** Events each calendar brought last time, when known. */
  counts?: Record<string, number>;
  busy?: boolean;
  onClose: () => void;
  onSave: (cals: ImportedCalendar[]) => void;
}

function Tick() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden>
      <path d="M6.5 12.5l3.5 3.5 7.5-8" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function CalIcon() {
  return (
    <svg className={s.icon} viewBox="0 0 24 24" fill="none" aria-hidden>
      <rect x="3.5" y="5" width="17" height="15.5" rx="3" stroke="currentColor" strokeWidth="1.7" />
      <path d="M3.5 10h17M8 3.5v3.5M16 3.5v3.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

export default function GcalPicker({
  calendars,
  selectedIds,
  counts,
  busy,
  onClose,
  onSave,
}: Props) {
  const [ticked, setTicked] = useState<Set<string>>(new Set(selectedIds));

  useEffect(() => {
    if (selectedIds.length) {
      setTicked(new Set(selectedIds));
      return;
    }
    const main =
      calendars.find((c) => c.primary) ??
      calendars.find((c) => c.accessRole === 'owner') ??
      calendars[0];
    setTicked(new Set(main ? [main.id] : []));
  }, [selectedIds, calendars]);

  const toggle = (id: string) =>
    setTicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const sections = useMemo(() => {
    const mine = calendars.filter((c) => c.accessRole === 'owner' || c.primary);
    const other = calendars.filter((c) => !(c.accessRole === 'owner' || c.primary));
    const out: { label: string; items: ImportedCalendar[] }[] = [];
    if (mine.length) out.push({ label: 'My calendars', items: mine });
    if (other.length) out.push({ label: 'Other', items: other });
    return out;
  }, [calendars]);

  const chosen = calendars.filter((c) => ticked.has(c.id));

  return (
    <div>
      <p className={s.lead}>{Copy.availability.pickerLead}</p>

      {sections.map((sec) => (
        <div key={sec.label} className={s.section}>
          <span className={s.sectionLabel}>{sec.label}</span>
          <div className={s.list}>
            {sec.items.map((cal) => {
              const on = ticked.has(cal.id);
              const n = counts?.[cal.id];
              return (
                <button
                  key={cal.id}
                  type="button"
                  role="checkbox"
                  className={s.row}
                  disabled={busy}
                  onClick={() => toggle(cal.id)}
                  aria-checked={on}
                >
                  <CalIcon />
                  <span className={s.name}>
                    {cal.summary}
                    {cal.primary ? ' · Primary' : ''}
                  </span>
                  {n != null && <span className={s.count}>{n}</span>}
                  <span className={`${s.check} ${on ? s.checkOn : ''}`} aria-hidden>
                    {on && <Tick />}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      ))}

      <div className={s.actions}>
        <button type="button" className={`${f.btn} ${f.ghost}`} onClick={onClose} disabled={busy}>
          Cancel
        </button>
        <button
          type="button"
          className={`${f.btn} ${f.accent}`}
          disabled={busy || (!chosen.length && !selectedIds.length)}
          onClick={() => onSave(chosen)}
        >
          {busy ? 'Importing…' : selectedIds.length ? 'Save' : 'Import'}
        </button>
      </div>
    </div>
  );
}
