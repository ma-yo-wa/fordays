import React from 'react';
import s from './ActionRow.module.css';

export interface ActionRowProps {
  label: string;
  icon?: React.ReactNode;
  destructive?: boolean;
  onClick: () => void;
  className?: string;
}

export const ActionRow: React.FC<ActionRowProps> = ({
  label,
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
      <span className={s.label}>{label}</span>
    </button>
  );
};
