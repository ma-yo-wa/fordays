import { motion } from 'motion/react';
import { useApp, isMatched, type Screen } from '../lib/store';
import s from './TabBar.module.css';

/* Outlined when idle, solid when selected. Without labels the icon is
   doing all the work, so the selected state has to be unmistakable —
   hence a fill and a pill behind it, not just a colour change. */
function CalendarIcon({ on }: { on: boolean }) {
  return on ? (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M7 2a1 1 0 0 1 1 1v1h8V3a1 1 0 1 1 2 0v1.1A4 4 0 0 1 21 8v1H3V8a4 4 0 0 1 3-3.9V3a1 1 0 0 1 1-1Z" />
      <path d="M3 11h18v6a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4v-6Z" fillOpacity="0.55" />
    </svg>
  ) : (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <rect x="3" y="5" width="18" height="16" rx="4" />
      <path d="M3 10h18M8 3v3M16 3v3" strokeLinecap="round" />
    </svg>
  );
}

function BucketIcon({ on }: { on: boolean }) {
  return on ? (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M3.6 5.5A1 1 0 0 1 4.6 4h14.8a1 1 0 0 1 1 1.2l-2 12.3A3 3 0 0 1 15.4 20H8.6a3 3 0 0 1-3-2.5l-2-12ZM9 9.4a1 1 0 1 0-1.4 1.4l2.6 2.6a1 1 0 0 0 1.5 0l4.6-4.7A1 1 0 0 0 15 7.3l-3.9 3.9L9 9.4Z" />
    </svg>
  ) : (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path
        d="M4.6 5h14.8l-2 12.3A3 3 0 0 1 14.4 20H9.6a3 3 0 0 1-3-2.7L4.6 5Z"
        strokeLinejoin="round"
      />
      <path d="m8.6 10.6 2.4 2.4 4.4-4.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function MemoriesIcon({ on }: { on: boolean }) {
  return on ? (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12 2.4c.4 0 .8.2 1 .6l1.6 3.4 3.7.5c.9.1 1.3 1.2.6 1.8l-2.7 2.6.6 3.7c.2.9-.8 1.6-1.6 1.2L12 14.8l-3.2 1.7c-.8.4-1.8-.3-1.6-1.2l.6-3.7-2.7-2.6c-.7-.6-.3-1.7.6-1.8l3.7-.5L11 3c.2-.4.6-.6 1-.6Z" />
    </svg>
  ) : (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path
        d="m12 3.2 1.5 3.2.4.8.9.1 3.5.5-2.5 2.5-.6.6.1.9.6 3.5-3.1-1.6-.8-.4-.8.4-3.1 1.6.6-3.5.1-.9-.6-.6-2.5-2.5 3.5-.5.9-.1.4-.8L12 3.2Z"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export default function TabBar() {
  const screen = useApp((st) => st.screen);
  const setScreen = useApp((st) => st.setScreen);
  const setAddOpen = useApp((st) => st.setAddOpen);
  const matched = useApp((st) => isMatched(st.space));

  const tab = (id: Screen, label: string, icon: (on: boolean) => React.ReactNode) => {
    const on = screen === id;
    return (
      <button
        type="button"
        className={`${s.tab} ${on ? s.on : ''}`}
        onClick={() => setScreen(id)}
        aria-current={on ? 'page' : undefined}
        aria-label={label}
      >
        {on && (
          <motion.span
            layoutId="tab-pill"
            className={s.pill}
            transition={{ type: 'spring', stiffness: 480, damping: 38 }}
          />
        )}
        <span className={s.icon}>{icon(on)}</span>
      </button>
    );
  };

  return (
    <nav className={s.dock}>
      <div className={s.inner}>
        {tab('bucket', 'Bucket List', (on) => <BucketIcon on={on} />)}
        {tab('calendar', 'Plans', (on) => <CalendarIcon on={on} />)}
        {tab('memories', 'Memories', (on) => <MemoriesIcon on={on} />)}
      </div>

      {matched && (
        <motion.button
          type="button"
          className={s.make}
          onClick={() => setAddOpen(true)}
          whileTap={{ scale: 0.9 }}
          transition={{ type: 'spring', stiffness: 600, damping: 30 }}
          aria-label="Add something"
        >
          <span className={s.plus} aria-hidden />
        </motion.button>
      )}
    </nav>
  );
}
