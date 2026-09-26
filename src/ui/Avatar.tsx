import React from 'react';
import s from './Avatar.module.css';
import { faceColor } from '../lib/tint';

export type AvatarSize = 'xs' | 'sm' | 'md' | 'lg';

export interface AvatarProps extends React.HTMLAttributes<HTMLDivElement> {
  name?: string;
  /** Picks the face colour; falls back to the name. */
  personId?: string | null;
  seat?: 0 | 1;
  color?: string;
  imageUrl?: string | null;
  size?: AvatarSize;
  ring?: boolean;
}

export const Avatar: React.FC<AvatarProps> = ({
  name,
  personId,
  seat: _seat = 0,
  color,
  imageUrl,
  size = 'md',
  ring = false,
  className = '',
  style,
  ...rest
}) => {
  const initial = name?.trim() ? name.trim()[0]?.toUpperCase() : '';
  const bgColor = color || faceColor(personId || name);

  const sizeClass =
    size === 'sm' ? s.sizeSm : size === 'lg' ? s.sizeLg : s.sizeMd;

  const classes = [s.avatar, sizeClass, ring ? s.ring : '', className]
    .filter(Boolean)
    .join(' ');

  return (
    <div
      className={classes}
      style={{ background: imageUrl ? 'transparent' : bgColor, ...style }}
      aria-label={name || 'Avatar'}
      {...rest}
    >
      {imageUrl ? (
        <img src={imageUrl} alt={name || 'Avatar'} className={s.img} />
      ) : (
        <span>{initial}</span>
      )}
    </div>
  );
};
