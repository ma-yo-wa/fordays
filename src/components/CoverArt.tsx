import { emojiFromCover, isEmojiCover } from '../lib/cover';
import { tintFor } from '../lib/tint';
import s from './CoverArt.module.css';

interface Props {
  url?: string | null;
  /** Orb wash when there is no picture — same language as the bucket board. */
  washId?: string;
  washTitle?: string | null;
  className?: string;
  /** Larger emoji for detail / picker preview. */
  size?: 'card' | 'hero' | 'thumb';
}

export default function CoverArt({
  url,
  washId,
  washTitle,
  className,
  size = 'card',
}: Props) {
  if (!url) {
    if (!washId) return null;
    return (
      <div
        className={`${s.wash} ${s[size]} ${className ?? ''}`}
        style={{ background: tintFor(washId, washTitle) }}
        aria-hidden
      />
    );
  }

  if (isEmojiCover(url)) {
    return (
      <div className={`${s.emoji} ${s[size]} ${className ?? ''}`} aria-hidden>
        <span>{emojiFromCover(url)}</span>
      </div>
    );
  }

  /* A real <img> rather than a background, so the browser can skip
     everything below the fold. A long bucket list is otherwise a few
     hundred simultaneous decodes. The detail sheet's hero is already on
     screen by the time it renders, so it doesn't wait. */
  return (
    <div className={`${s.photo} ${s[size]} ${className ?? ''}`} aria-hidden>
      <img
        src={url}
        alt=""
        loading={size === 'hero' ? 'eager' : 'lazy'}
        decoding="async"
      />
    </div>
  );
}
