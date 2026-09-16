import { motion } from 'motion/react';
import { springSwitch } from '../ui/motion';
import f from './Form.module.css';

interface Props {
  on: boolean;
  onChange: (next: boolean) => void;
  label: string;
  disabled?: boolean;
}

export default function Switch({ on, onChange, label, disabled }: Props) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      disabled={disabled}
      className={`${f.switch} ${on ? f.switchOn : ''}`}
      onClick={() => {
        if (disabled) return;
        onChange(!on);
      }}
      style={{
        justifyContent: on ? 'flex-end' : 'flex-start',
        opacity: disabled ? 'var(--op-45)' : 'var(--op-100)',
      }}
    >
      {/* layout animation slides the knob rather than tweening a transform,
          so it tracks the track's real geometry at any size. */}
      <motion.span
        layout
        className={f.switchKnob}
        transition={springSwitch}
      />
    </button>
  );
}
