import React from 'react';
import s from './Pill.module.css';

export type PillVariant = 'neutral' | 'rose' | 'sage' | 'solid' | 'rule';
export type PillSize = 'sm' | 'md';

export interface PillProps extends React.HTMLAttributes<HTMLSpanElement | HTMLButtonElement> {
  variant?: PillVariant;
  size?: PillSize;
  onClick?: (e: React.MouseEvent<any>) => void;
  icon?: React.ReactNode;
}

export const Pill: React.FC<PillProps> = ({
  variant = 'neutral',
  size = 'md',
  onClick,
  icon,
  className = '',
  children,
  ...rest
}) => {
  const isClickable = Boolean(onClick);
  const sizeClass = size === 'sm' ? s.sizeSm : s.sizeMd;
  const classes = [
    s.pill,
    s[variant],
    sizeClass,
    isClickable ? s.clickable : '',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  if (isClickable) {
    return (
      <button
        type="button"
        className={classes}
        onClick={onClick}
        {...(rest as React.ButtonHTMLAttributes<HTMLButtonElement>)}
      >
        {icon}
        {children}
      </button>
    );
  }

  return (
    <span className={classes} {...rest}>
      {icon}
      {children}
    </span>
  );
};
