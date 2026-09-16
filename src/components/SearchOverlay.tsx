import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { useApp } from '../lib/store';
import { isMemory, type Activity } from '../lib/types';
import { Copy, formatCopy } from '../lib/copy';
import { dtDate, dtTime, formatSearchDate, pretty } from '../lib/date';
import { Pill } from '../ui';
import { durationFade, easeIos, ySearch } from '../ui/motion';
import s from './SearchOverlay.module.css';

function SearchIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" strokeLinecap="round" />
    </svg>
  );
}

function BackIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" aria-hidden>
      <path d="M15 19l-7-7 7-7" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function formatItemTime(a: Activity): string {
  if (!a.date_time) return '';
  const sTime = dtTime(a.date_time);
  const eTime = a.ends_at ? dtTime(a.ends_at) : null;
  if (!sTime) return 'All day';
  if (eTime && eTime !== sTime) {
    return `${pretty(sTime)} – ${pretty(eTime)}`;
  }
  return pretty(sTime);
}

interface DayGroup {
  dayKey: string;
  dayLabel: string;
  items: Activity[];
}

function groupByDay(list: Activity[]): DayGroup[] {
  const map = new Map<string, Activity[]>();
  for (const item of list) {
    const day = (item.date_time ? dtDate(item.date_time) : null) ?? 'unknown';
    if (!map.has(day)) map.set(day, []);
    map.get(day)!.push(item);
  }
  return Array.from(map.entries()).map(([dayKey, items]) => ({
    dayKey,
    dayLabel: dayKey !== 'unknown' ? formatSearchDate(dayKey) : '',
    items,
  }));
}

export default function SearchOverlay() {
  const searchOpen = useApp((st) => st.searchOpen);
  const setSearchOpen = useApp((st) => st.setSearchOpen);
  const activities = useApp((st) => st.activities);
  const openDetail = useApp((st) => st.openDetail);

  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (searchOpen) {
      setQuery('');
      const timer = setTimeout(() => {
        inputRef.current?.focus();
      }, 50);
      return () => clearTimeout(timer);
    }
  }, [searchOpen]);

  useEffect(() => {
    if (!searchOpen) return;
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setSearchOpen(false);
      }
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [searchOpen, setSearchOpen]);

  const q = query.trim().toLowerCase();

  const { planGroups, somedayItems, memoryGroups, totalCount } = useMemo(() => {
    if (!q) {
      return { planGroups: [], somedayItems: [], memoryGroups: [], totalCount: 0 };
    }

    const matches = activities.filter((a) => {
      const matchTitle = a.title?.toLowerCase().includes(q);
      const matchLoc = a.location?.toLowerCase().includes(q);
      const matchDesc = a.description?.toLowerCase().includes(q);
      return matchTitle || matchLoc || matchDesc;
    });

    const plans = matches
      .filter((a) => Boolean(a.date_time) && !isMemory(a))
      .sort((a, b) => (a.date_time ?? '').localeCompare(b.date_time ?? ''));

    const someday = matches
      .filter((a) => !a.date_time)
      .sort((a, b) => (b.created_at ?? '').localeCompare(a.created_at ?? ''));

    const memories = matches
      .filter((a) => Boolean(a.date_time) && isMemory(a))
      .sort((a, b) => (b.date_time ?? '').localeCompare(a.date_time ?? ''));

    return {
      planGroups: groupByDay(plans),
      somedayItems: someday,
      memoryGroups: groupByDay(memories),
      totalCount: matches.length,
    };
  }, [activities, q]);

  const recentItems = useMemo(() => {
    if (q) return { plans: [], someday: [] };
    const upcomingPlans = activities
      .filter((a) => Boolean(a.date_time) && !isMemory(a))
      .sort((a, b) => (a.date_time ?? '').localeCompare(b.date_time ?? ''))
      .slice(0, 4);
    const recentSomeday = activities
      .filter((a) => !a.date_time)
      .sort((a, b) => (b.created_at ?? '').localeCompare(a.created_at ?? ''))
      .slice(0, 4);
    return { plans: upcomingPlans, someday: recentSomeday };
  }, [activities, q]);

  function handleSelect(id: string) {
    setSearchOpen(false);
    openDetail(id);
  }

  function handleClose() {
    setSearchOpen(false);
    setQuery('');
  }

  return (
    <AnimatePresence>
      {searchOpen && (
        <motion.div
          className={s.overlay}
          initial={{ opacity: 0, y: ySearch }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: ySearch }}
          transition={{ duration: durationFade, ease: easeIos }}
        >
          <div className={s.topBar}>
            <button
              type="button"
              className={s.backBtn}
              onClick={handleClose}
              aria-label={Copy.search.cancel}
              title={Copy.search.cancel}
            >
              <BackIcon />
            </button>
            <div className={s.searchBox}>
              <span className={s.searchIcon}>
                <SearchIcon />
              </span>
              <input
                ref={inputRef}
                className={s.input}
                type="search"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={Copy.search.placeholder}
                autoCorrect="off"
                autoCapitalize="none"
                spellCheck={false}
                enterKeyHint="search"
              />
              {query.length > 0 && (
                <button
                  type="button"
                  className={s.clearBtn}
                  onClick={() => {
                    setQuery('');
                    inputRef.current?.focus();
                  }}
                  aria-label={Copy.search.clear}
                >
                  ×
                </button>
              )}
            </div>
            <button type="button" className={s.cancelBtn} onClick={handleClose}>
              {Copy.search.cancel}
            </button>
          </div>

          <div className={s.content}>
            {!q && (
              <>
                {recentItems.plans.length === 0 && recentItems.someday.length === 0 ? (
                  <div className={s.emptyPrompt}>
                    <span className={s.emptyPromptIcon}>
                      <SearchIcon />
                    </span>
                    <p className={s.emptyPromptText}>{Copy.search.emptyPrompt}</p>
                  </div>
                ) : (
                  <div className={s.recentWrap}>
                    {recentItems.plans.length > 0 && (
                      <div className={s.section}>
                        <h3 className={s.sectionHeader}>Upcoming Plans</h3>
                        <div className={s.rowsList}>
                          {recentItems.plans.map((item) => (
                            <button
                              key={item.id}
                              type="button"
                              className={s.row}
                              onClick={() => handleSelect(item.id)}
                            >
                              <span className={s.accentBar} />
                              <div className={s.rowMain}>
                                <span className={s.rowTitle}>{item.title}</span>
                                {item.location && (
                                  <span className={s.rowLoc}>
                                    <span className={s.rowLocPin} aria-hidden>
                                      📍
                                    </span>
                                    <span>{item.location}</span>
                                  </span>
                                )}
                                {item.description && (
                                  <span className={s.rowNote}>{item.description}</span>
                                )}
                              </div>
                              <span className={s.rowTrailing}>{formatItemTime(item)}</span>
                            </button>
                          ))}
                        </div>
                      </div>
                    )}

                    {recentItems.someday.length > 0 && (
                      <div className={s.section}>
                        <h3 className={s.sectionHeader}>Recent in Someday</h3>
                        <div className={s.rowsList}>
                          {recentItems.someday.map((item) => (
                            <button
                              key={item.id}
                              type="button"
                              className={s.row}
                              onClick={() => handleSelect(item.id)}
                            >
                              <span className={`${s.accentBar} ${s.accentBarSomeday}`} />
                              <div className={s.rowMain}>
                                <span className={s.rowTitle}>{item.title}</span>
                                {item.location && (
                                  <span className={s.rowLoc}>
                                    <span className={s.rowLocPin} aria-hidden>
                                      📍
                                    </span>
                                    <span>{item.location}</span>
                                  </span>
                                )}
                                {item.description && (
                                  <span className={s.rowNote}>{item.description}</span>
                                )}
                              </div>
                              <Pill variant="neutral" size="sm">{Copy.search.someday}</Pill>
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </>
            )}

            {q && totalCount === 0 && (
              <div className={s.emptyPrompt}>
                <p className={s.emptyPromptText}>
                  {formatCopy(Copy.search.noResults, { query })}
                </p>
              </div>
            )}

            {planGroups.length > 0 && (
              <div className={s.section}>
                <h3 className={s.sectionHeader}>
                  {Copy.search.plans} ({planGroups.reduce((acc, g) => acc + g.items.length, 0)})
                </h3>
                {planGroups.map((group) => (
                  <div key={group.dayKey} className={s.dayGroup}>
                    {group.dayLabel && <div className={s.dayHeader}>{group.dayLabel}</div>}
                    <div className={s.rowsList}>
                      {group.items.map((item) => (
                        <button
                          key={item.id}
                          type="button"
                          className={s.row}
                          onClick={() => handleSelect(item.id)}
                        >
                          <span className={s.accentBar} />
                          <div className={s.rowMain}>
                            <span className={s.rowTitle}>{item.title}</span>
                            {item.location && (
                              <span className={s.rowLoc}>
                                <span className={s.rowLocPin} aria-hidden>
                                  📍
                                </span>
                                <span>{item.location}</span>
                              </span>
                            )}
                            {item.description && (
                              <span className={s.rowNote}>{item.description}</span>
                            )}
                          </div>
                          <span className={s.rowTrailing}>{formatItemTime(item)}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {somedayItems.length > 0 && (
              <div className={s.section}>
                <h3 className={s.sectionHeader}>
                  {Copy.search.someday} ({somedayItems.length})
                </h3>
                <div className={s.rowsList}>
                  {somedayItems.map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      className={s.row}
                      onClick={() => handleSelect(item.id)}
                    >
                      <span className={`${s.accentBar} ${s.accentBarSomeday}`} />
                      <div className={s.rowMain}>
                        <span className={s.rowTitle}>{item.title}</span>
                        {item.location && (
                          <span className={s.rowLoc}>
                            <span className={s.rowLocPin} aria-hidden>
                              📍
                            </span>
                            <span>{item.location}</span>
                          </span>
                        )}
                        {item.description && <span className={s.rowNote}>{item.description}</span>}
                      </div>
                      <Pill variant="neutral" size="sm">{Copy.search.someday}</Pill>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {memoryGroups.length > 0 && (
              <div className={s.section}>
                <h3 className={s.sectionHeader}>
                  {Copy.search.memories} ({memoryGroups.reduce((acc, g) => acc + g.items.length, 0)})
                </h3>
                {memoryGroups.map((group) => (
                  <div key={group.dayKey} className={s.dayGroup}>
                    {group.dayLabel && <div className={s.dayHeader}>{group.dayLabel}</div>}
                    <div className={s.rowsList}>
                      {group.items.map((item) => (
                        <button
                          key={item.id}
                          type="button"
                          className={s.row}
                          onClick={() => handleSelect(item.id)}
                        >
                          <span className={`${s.accentBar} ${s.accentBarMemory}`} />
                          <div className={s.rowMain}>
                            <span className={s.rowTitle}>{item.title}</span>
                            {item.location && (
                              <span className={s.rowLoc}>
                                <span className={s.rowLocPin} aria-hidden>
                                  📍
                                </span>
                                <span>{item.location}</span>
                              </span>
                            )}
                            {item.description && (
                              <span className={s.rowNote}>{item.description}</span>
                            )}
                          </div>
                          <span className={s.rowTrailing}>{formatItemTime(item)}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
