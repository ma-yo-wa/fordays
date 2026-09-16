import React from 'react';
import s from './ActionRow.module.css';

export interface ActionRowProps {
  label: string;
  note?: string;
  icon?: React.ReactNode;
  destructive?: boolean;
  onClick: () => void;
  className?: string;
}

export const ActionRow: React.FC<ActionRowProps> = ({
  label,
  note,
  icon,
  destructive = false,
  onClick,
  className = '',
}) => {
  return (
    <button
      type="button"
      className={`${s.actionRow} ${destructive ? s.destructive : ''} ${className}`.trim()}
      onClick={onClick}
    >
      {icon && <span className={s.icon}>{icon}</span>}
      <div className={s.textStack}>
        <span className={s.label}>{label}</span>
        {note && <span className={s.note}>{note}</span>}
      </div>
    </button>
  );
};
