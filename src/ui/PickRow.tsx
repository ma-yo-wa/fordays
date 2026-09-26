import React from 'react';
import { FormRow } from './FormGroup';
import s from './FormGroup.module.css';

export interface PickRowProps<T extends string | number> {
  label: React.ReactNode;
  icon?: React.ReactNode;
  value: T;
  options: { value: T; label: string }[];
  onChange: (next: T) => void;
  disabled?: boolean;
}

/** A form row that opens the system picker (the wheel on iPhone), the
 *  way Calendar's Alert row does. The select sits invisibly over the
 *  whole row so the tap target is the row. */
export function PickRow<T extends string | number>({
  label,
  icon,
  value,
  options,
  onChange,
  disabled,
}: PickRowProps<T>) {
  const current = options.find((o) => o.value === value)?.label ?? '';
  return (
    <FormRow label={label} icon={icon} className={s.pickRow}>
      <span className={s.pickValue}>{current}</span>
      <select
        className={s.pickSelect}
        value={String(value)}
        disabled={disabled}
        aria-label={typeof label === 'string' ? label : undefined}
        onChange={(e) => {
          const hit = options.find((o) => String(o.value) === e.target.value);
          if (hit) onChange(hit.value);
        }}
      >
        {options.map((o) => (
          <option key={String(o.value)} value={String(o.value)}>
            {o.label}
          </option>
        ))}
      </select>
    </FormRow>
  );
}
