import React, { forwardRef } from 'react';
import s from './Card.module.css';

export type CardVariant = 'warm' | 'paper' | 'sunk' | 'roseWash' | 'sageWash';
export type CardPadding = 'none' | 'sm' | 'md' | 'lg';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: CardVariant;
  padding?: CardPadding;
}

export const Card = forwardRef<HTMLDivElement, CardProps>(function Card(
  {
    variant = 'warm',
    padding = 'md',
    className = '',
    children,
    ...rest
  },
  ref,
) {
  const padClass =
    padding === 'none'
      ? s.padNone
      : padding === 'sm'
        ? s.padSm
        : padding === 'lg'
          ? s.padLg
          : s.padMd;

  const classes = [s.card, s[variant], padClass, className]
    .filter(Boolean)
    .join(' ');

  return (
    <div ref={ref} className={classes} {...rest}>
      {children}
    </div>
  );
});
