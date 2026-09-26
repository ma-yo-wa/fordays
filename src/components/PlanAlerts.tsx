import { useEffect, useState } from 'react';
import {
  alertOptions,
  loadPlanAlerts,
  loadPrefs,
  savePlanAlerts,
} from '../lib/alerts';
import { useApp } from '../lib/store';
import s from '../ui/ActionRow.module.css';

function BellIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

const NONE = -1;

/** One row that opens the system picker, styled like the other actions. */
function PickAction({
  label,
  value,
  allDay,
  onChange,
  icon,
}: {
  label: string;
  value: number;
  allDay: boolean;
  onChange: (v: number) => void;
  icon: boolean;
}) {
  const options = [{ value: NONE, label: 'None' }, ...alertOptions(allDay)];
  const current = options.find((o) => o.value === value)?.label ?? 'None';
  return (
    <div className={`${s.actionRow} ${s.pick}`}>
      <span className={s.icon}>{icon ? <BellIcon /> : null}</span>
      <div className={s.textStack}>
        <span className={s.label}>{label}</span>
        <span className={s.note}>{current}</span>
      </div>
      <select
        className={s.pickSelect}
        value={String(value)}
        aria-label={label}
        onChange={(e) => onChange(Number(e.target.value))}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </div>
  );
}

/** Alert and Second alert, as in Calendar. Yours only: nobody else in the
 *  Orb sees or shares them. Until you choose, your defaults apply. */
export default function PlanAlerts({ activityId, allDay }: { activityId: string; allDay: boolean }) {
  const toast = useApp((st) => st.toast);
  const [alerts, setAlerts] = useState<number[] | null>(null);

  useEffect(() => {
    let live = true;
    setAlerts(null);
    void Promise.all([loadPlanAlerts(activityId, allDay), loadPrefs()]).then(([mine, prefs]) => {
      if (!live) return;
      setAlerts(mine ?? (allDay ? prefs.alertAllDay : prefs.alertTimed));
    });
    return () => {
      live = false;
    };
  }, [activityId, allDay]);

  if (!alerts) return null;

  const save = (next: number[]) => {
    const before = alerts;
    setAlerts(next);
    void savePlanAlerts(activityId, allDay, next).catch(() => {
      setAlerts(before);
      toast('Couldn’t save that. Check your connection and try again.');
    });
  };

  const first = alerts[0] ?? NONE;
  const second = alerts[1] ?? NONE;

  return (
    <>
      <PickAction
        label="Alert"
        value={first}
        allDay={allDay}
        icon
        onChange={(v) => save(v === NONE ? [] : second === NONE ? [v] : [v, second])}
      />
      {first !== NONE && (
        <PickAction
          label="Second alert"
          value={second}
          allDay={allDay}
          icon={false}
          onChange={(v) => save(v === NONE ? [first] : [first, v])}
        />
      )}
    </>
  );
}
