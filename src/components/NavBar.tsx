import { useApp, isMatched, spaceOrbName } from '../lib/store';
import { faceColor } from '../lib/tint';
import { MONTHS, iso, parseISO, todayISO } from '../lib/date';
import { Copy } from '../lib/copy';
import s from './NavBar.module.css';

function Chevron({ dir }: { dir: 'left' | 'right' }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" aria-hidden>
      <path
        d={dir === 'left' ? 'M15 5 8 12l7 7' : 'M9 5l7 7-7 7'}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function ChevronDown() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden>
      <path d="m6 9 6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" strokeLinecap="round" />
    </svg>
  );
}

export default function NavBar() {
  const screen = useApp((st) => st.screen);
  const config = useApp((st) => st.config);
  const live = useApp((st) => st.live);
  const backendName = useApp((st) => st.backendName);
  const cursor = useApp((st) => st.cursor);
  const setCursor = useApp((st) => st.setCursor);
  const setPicked = useApp((st) => st.setPicked);
  const setSettingsOpen = useApp((st) => st.setSettingsOpen);
  const setSearchOpen = useApp((st) => st.setSearchOpen);
  const space = useApp((st) => st.space);

  const cursorDate = parseISO(cursor);
  const isCalendar = screen === 'calendar';
  const matched = isMatched(space);
  const me = space?.me ?? config.me;
  const faceChips = space?.members?.length
    ? (() => {
        const mine = space.members.find((m) => m.id === space.myId);
        const others = space.members.filter((m) => m.id !== space.myId);
        const ordered = mine ? [mine, ...others] : space.members;
        return ordered.map((m) => ({
          key: m.id,
          letter: (m.name[0] ?? '?').toUpperCase(),
          them: m.id !== space.myId,
        }));
      })()
    : [
        {
          key: 'me',
          letter: (space?.myName ?? config.names[me] ?? '?')[0]!.toUpperCase(),
          them: false,
        },
        ...(matched
          ? [
              {
                key: 'them',
                letter: (space?.partnerName ?? '?')[0]!.toUpperCase(),
                them: true,
              },
            ]
          : []),
      ];
  const visibleFaces = faceChips.slice(0, 2);
  const moreCount = Math.max(0, faceChips.length - 2);
  const titleName = space ? spaceOrbName(space) : '';
  const customOrbName = titleName || null;

  const monthLabel = `${MONTHS[cursorDate.getMonth()]}${
    cursorDate.getFullYear() === new Date().getFullYear()
      ? ''
      : ` ${cursorDate.getFullYear()}`
  }`;
  const title = isCalendar
    ? monthLabel
    : screen === 'memories'
      ? Copy.tabs.memories
      : Copy.tabs.ideas;

  const now = new Date();
  const offCurrentMonth =
    cursorDate.getMonth() !== now.getMonth() ||
    cursorDate.getFullYear() !== now.getFullYear();

  const shiftMonth = (delta: number) =>
    setCursor(iso(new Date(cursorDate.getFullYear(), cursorDate.getMonth() + delta, 1)));

  const goToday = () => {
    setPicked(todayISO());
    setCursor(iso(new Date(now.getFullYear(), now.getMonth(), 1)));
  };

  return (
    <header className={s.nav}>
      <div className={s.bar}>
        <div className={s.leading}>
          <button
            type="button"
            className={`${s.who} ${customOrbName ? s.whoNamed : s.whoAvatars}`}
            onClick={() => setSettingsOpen(true)}
            aria-label={customOrbName ? `Open settings for ${customOrbName}` : 'Open Orb settings'}
            title={customOrbName ?? 'Orb settings'}
          >
            {customOrbName ? (
              <span className={s.whoTitle}>{customOrbName}</span>
            ) : (
              <span className={s.faceStack}>
                {visibleFaces.map((f) => (
                  <span
                    key={f.key}
                    className={`${s.face} ${f.them ? s.dim : ''}`}
                    style={{ background: faceColor(f.them ? 1 : 0) }}
                  >
                    {f.letter}
                  </span>
                ))}
                {moreCount > 0 && (
                  <span className={`${s.face} ${s.more}`} aria-label={`${moreCount} more people`}>
                    +{moreCount}
                  </span>
                )}
                {!live && backendName === 'supabase' && (
                  <span className={s.bulb} aria-hidden />
                )}
              </span>
            )}
            <span className={s.whoChevron} aria-hidden>
              <ChevronDown />
            </span>
          </button>
        </div>

        <div className={s.compactTitle}>
          {title}
        </div>

        <div className={s.trailing}>
          {isCalendar && (
            <>
              {offCurrentMonth && (
                <button type="button" className={s.todayPill} onClick={goToday}>
                  Today
                </button>
              )}
              <button
                type="button"
                className={s.action}
                onClick={() => shiftMonth(-1)}
                aria-label="Previous month"
              >
                <Chevron dir="left" />
              </button>
              <button
                type="button"
                className={s.action}
                onClick={() => shiftMonth(1)}
                aria-label="Next month"
              >
                <Chevron dir="right" />
              </button>
            </>
          )}
          <button
            type="button"
            className={s.action}
            onClick={() => setSearchOpen(true)}
            aria-label="Search"
            title="Search"
          >
            <SearchIcon />
          </button>
        </div>
      </div>
    </header>
  );
}
