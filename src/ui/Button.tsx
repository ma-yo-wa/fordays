import React, { forwardRef } from 'react';
import s from './Button.module.css';

export type ButtonVariant = 'primary' | 'secondary' | 'destructive' | 'ghost';
export type ButtonSize = 'md' | 'sm';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  fullWidth?: boolean;
  loading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    variant = 'primary',
    size = 'md',
    fullWidth = false,
    loading = false,
    disabled = false,
    className = '',
    children,
    ...rest
  },
  ref,
) {
  const classes = [
    s.btn,
    s[variant],
    size === 'sm' ? s.sizeSm : s.sizeMd,
    fullWidth ? s.fullWidth : '',
    loading ? s.loading : '',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button
      ref={ref}
      className={classes}
      disabled={disabled || loading}
      {...rest}
    >
      {/* The label keeps its space while loading, so the button never
          shrinks to the spinner's width. */}
      <span className={s.label}>{children}</span>
      {loading && <span className={s.spinner} aria-hidden="true" />}
    </button>
  );
});
