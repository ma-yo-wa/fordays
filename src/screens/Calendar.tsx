import { useEffect, useMemo } from 'react';
import CoverArt from '../components/CoverArt';
import { useApp, partnerName, isMatched } from '../lib/store';
import { isPlan, type ExternalEvent } from '../lib/types';
import { artFor } from '../lib/art';
import { faceColor, faceIndexFor } from '../lib/tint';
import {
  MONTHS,
  dtDate,
  dtTime,
  formatUpNext,
  monthGrid,
  parseISO,
  prettyLower,
  relativeDay,
  spanDays,
  todayISO,
} from '../lib/date';
import { Copy, formatCopy } from '../lib/copy';
import type { CalendarSource } from '../lib/calendars';
import s from './Calendar.module.css';

const DOW = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

/* What a multi-day event means depends on which day you're standing on:
   it begins today, it ends today, or it simply covers today. */
function pillWhen(e: ExternalEvent, day: string): string {
  if (e.allDay) return 'All day';
  const startsToday = dtDate(e.startsAt) === day;
  const endsToday = dtDate(e.endsAt) === day;
  if (startsToday && endsToday) return prettyLower(dtTime(e.startsAt) as string);
  if (startsToday) return `From ${prettyLower(dtTime(e.startsAt) as string)}`;
  if (endsToday) return `Until ${prettyLower(dtTime(e.endsAt) as string)}`;
  return 'All day';
}

function sourceTag(source?: CalendarSource): string {
  if (source === 'apple') return Copy.availability.apple;
  if (source === 'outlook') return Copy.availability.outlook;
  return Copy.availability.google;
}

export default function Calendar() {
  const activities = useApp((st) => st.activities);
  const external = useApp((st) => st.external);
  const config = useApp((st) => st.config);
  const picked = useApp((st) => st.picked);
  const cursor = useApp((st) => st.cursor);
  const setPicked = useApp((st) => st.setPicked);
  const openDetail = useApp((st) => st.openDetail);
  const openExternal = useApp((st) => st.openExternal);
  const space = useApp((st) => st.space);
  const pullImportedCalendars = useApp((st) => st.pullImportedCalendars);

  useEffect(() => {
    void pullImportedCalendars();
  }, [pullImportedCalendars]);

  const cursorDate = parseISO(cursor);
  const today = todayISO();
  const matched = isMatched(space);
  const others = (space?.members ?? []).filter((m) => m.id !== space?.myId);
  const other =
    others.length === 1 && others[0]?.name && others[0].name !== space?.myName
      ? others[0].name
      : matched && others.length === 0 && space?.partnerName && space.partnerName !== space.myName
        ? space.partnerName
        : null;

  const faceCtx = { me: space?.me ?? config.me, myId: space?.myId };
  const ownerIndex = (ownerId: string): 0 | 1 => faceIndexFor(ownerId, faceCtx);

  /* Plans land on every day they cover, so a trip reads as one run of
     days rather than a mark on the day you leave. */
  const plansByDate = new Map<string, typeof activities>();
  for (const a of activities) {
    if (!isPlan(a)) continue;
    const from = dtDate(a.date_time);
    if (!from) continue;
    const to = dtDate(a.ends_at) ?? from;
    for (const day of spanDays(from, to)) {
      plansByDate.set(day, [...(plansByDate.get(day) ?? []), a]);
    }
  }

  /* Imported events land on every day they touch, so a four-night hotel
     booking shows up across all four. Non-owners only see events if shared. */
  const extByDate = new Map<string, ExternalEvent[]>();
  for (const e of external) {
    const isMine = e.ownerId === (space?.myId ?? String(space?.me ?? config.me));
    if (!isMine && !e.sharedWithSpace) continue;
    for (const day of spanDays(e.startsAt, e.endsAt)) {
      extByDate.set(day, [...(extByDate.get(day) ?? []), e]);
    }
  }

  /* Ordered by when a plan actually began, not by clock time alone: a
     trip that started yesterday and is still running belongs above the
     things that start on this day. All-day sorts last within its day. */
  const startKey = (dateTime: string | null) =>
    `${dtDate(dateTime) ?? '9999-99-99'} ${dtTime(dateTime) ?? '99'}`;

  const dayPlans = (plansByDate.get(picked) ?? [])
    .slice()
    .sort((a, b) => startKey(a.date_time).localeCompare(startKey(b.date_time)));
  const dayExternal = (extByDate.get(picked) ?? [])
    .slice()
    .sort((a, b) => a.startsAt.localeCompare(b.startsAt));

  const dayItems = [
    ...dayPlans.map((plan) => ({
      kind: 'plan' as const,
      plan,
      sort: startKey(plan.date_time),
    })),
    ...dayExternal.map((event) => ({
      kind: 'external' as const,
      event,
      sort: event.allDay
        ? `${picked} 99`
        : event.startsAt.includes('T')
          ? event.startsAt.replace('T', ' ')
          : `${event.startsAt} 99`,
    })),
  ].sort((a, b) => a.sort.localeCompare(b.sort));

  const pickedDate = parseISO(picked);
  const dayHeading =
    picked === today
      ? 'Today'
      : `${MONTHS[pickedDate.getMonth()]} ${pickedDate.getDate()}`;

  // When Today is selected and has nothing planned, find the next upcoming plan date
  const upNext = useMemo(() => {
    if (picked !== today) return null;
    if (dayPlans.length > 0 || dayExternal.length > 0) return null;
    const futurePlans = activities
      .filter((a) => isPlan(a) && (dtDate(a.date_time) ?? '') > today)
      .sort((a, b) => (a.date_time ?? '').localeCompare(b.date_time ?? ''));
    if (!futurePlans.length || !futurePlans[0]?.date_time) return null;
    const targetDate = dtDate(futurePlans[0].date_time)!;
    const targetPlans = futurePlans.filter(
      (a) => (dtDate(a.date_time) ?? '') === targetDate,
    );
    const formatted = formatUpNext(targetDate, today);
    return {
      date: targetDate,
      countdown: formatted.countdown,
      dateFormatted: formatted.dateFormatted,
      plans: targetPlans,
    };
  }, [activities, picked, today, dayPlans.length, dayExternal.length]);

  return (
    <div className={s.wrap}>
      <div className={s.dow}>
        {DOW.map((d, i) => (
          <span key={i}>{d}</span>
        ))}
      </div>

      <div className={s.grid}>
        {monthGrid(cursorDate).map((cell, i) => {
          if (cell.outside || !cell.date) {
            return (
              <div key={i} className={`${s.day} ${s.outside}`}>
                <span className={s.num}>{cell.label}</span>
              </div>
            );
          }
          const date = cell.date;
          const mine = plansByDate.get(date) ?? [];
          const imported = extByDate.get(date) ?? [];

          const isRowStart = i % 7 === 0;
          const isRowEnd = i % 7 === 6;

          // Multi-day shared plans draw the soft sage ribbon. External events do not.
          const spanningPlans = mine.filter((p) => {
            const from = dtDate(p.date_time);
            const to = dtDate(p.ends_at) ?? from;
            return from && to && spanDays(from, to).length > 1;
          });
          const startsHere = spanningPlans.some((p) => dtDate(p.date_time) === date);
          const endsHere = spanningPlans.some((p) => (dtDate(p.ends_at) ?? dtDate(p.date_time)) === date);
          const isSpanning = spanningPlans.length > 0;
          const isContinuationToNext = isRowEnd && !endsHere;
          const isContinuationFromPrev = isRowStart && !startsHere;

          let trackStyle: React.CSSProperties | undefined;
          if (isSpanning) {
            const roundLeft = startsHere ? '15px' : '0';
            const roundRight = endsHere ? '15px' : '0';
            const leftInset = startsHere ? 'calc(50% - 15px)' : '0';
            const rightInset = endsHere ? 'calc(50% - 15px)' : '0';

            let clipPath: string | undefined;
            if (isContinuationToNext && isContinuationFromPrev) {
              clipPath = 'polygon(5px 0%, calc(100% - 5px) 0%, 100% 50%, calc(100% - 5px) 100%, 5px 100%, 0% 50%)';
            } else if (isContinuationToNext) {
              clipPath = 'polygon(0% 0%, calc(100% - 5px) 0%, 100% 50%, calc(100% - 5px) 100%, 0% 100%)';
            } else if (isContinuationFromPrev) {
              clipPath = 'polygon(5px 0%, 100% 0%, 100% 100%, 5px 100%, 0% 50%)';
            }

            trackStyle = {
              left: leftInset,
              right: rightInset,
              borderRadius: `${roundLeft} ${roundRight} ${roundRight} ${roundLeft}`,
              clipPath,
            };
          }

          // Discrete marks on the month grid are strictly Fordays plans
          const singlePlans = mine.filter((p) => {
            const from = dtDate(p.date_time);
            const to = dtDate(p.ends_at) ?? from;
            return !from || !to || spanDays(from, to).length <= 1;
          });

          const classes: string[] = [];
          if (s.day) classes.push(s.day);
          if (date === picked && s.picked) classes.push(s.picked);
          if (date === today && s.isToday) classes.push(s.isToday);

          return (
            <button
              key={i}
              type="button"
              className={classes.join(' ')}
              onClick={() => setPicked(date)}
            >
              {trackStyle && <span className={s.track} style={trackStyle} />}
              <span className={s.num}>{cell.label}</span>
              <span className={s.marks}>
                {singlePlans.slice(0, 3).map((p) => (
                  <i key={p.id} />
                ))}
                {imported.slice(0, Math.max(0, 3 - Math.min(singlePlans.length, 3))).map((e) => (
                  <i key={e.id} className={s.ext} />
                ))}
              </span>
            </button>
          );
        })}
      </div>

      <div className={s.agenda}>
        <div className={s.dayLabel}>{dayHeading}</div>

        {!dayPlans.length && !dayExternal.length ? (
          <>
            <div className={upNext ? s.blankCompact : s.blank}>
              <p>
                {space?.frozen
                  ? Copy.plans.emptyFrozen
                  : other
                    ? picked === today
                      ? formatCopy(Copy.plans.emptyTodayPartner, { partner: other })
                      : formatCopy(Copy.plans.emptyDayPartner, { partner: other })
                    : picked === today
                      ? Copy.plans.emptyToday
                      : Copy.plans.emptyDay}
              </p>
            </div>

            {upNext && (
              <div className={s.upNextSection}>
                <div className={s.upNextHeading}>{Copy.plans.upNext}</div>
                <div className={s.upNextSubhead}>
                  <span className={s.upNextCountdown}>{upNext.countdown}</span>
                  <span className={s.upNextDot}>·</span>
                  <span className={s.upNextDate}>{upNext.dateFormatted}</span>
                </div>
                <div className={s.plansList}>
                  {upNext.plans.map((a) => {
                    const time = dtTime(a.date_time);
                    const timing = time ? prettyLower(time) : 'All day';
                    return (
                      <button
                        key={a.id}
                        type="button"
                        className={s.entry}
                        onClick={() => openDetail(a.id)}
                      >
                        <CoverArt
                          url={a.image_url}
                          washId={a.id}
                          washTitle={a.title}
                          size="thumb"
                          className={s.thumb}
                        />
                        <span>
                          <span className={s.title}>{a.title}</span>
                          <div className={s.range}>{timing}</div>
                          {a.location && (
                            <div className={s.loc}>
                              <span>📍</span> {a.location}
                            </div>
                          )}
                          {a.description && <div className={s.note}>{a.description}</div>}
                          <div className={s.meta}>
                            <span
                              className={s.avatar}
                              style={{
                                background: faceColor(faceIndexFor(a.created_by, faceCtx)),
                              }}
                            >
                              {(partnerName(config, a.created_by)[0] ?? '?').toUpperCase()}
                            </span>
                            {partnerName(config, a.created_by)}
                          </div>
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </>
        ) : (
          <div className={s.plansList}>
            {dayItems.map((item) => {
              if (item.kind === 'plan') {
                const a = item.plan;
                const when = relativeDay(dtDate(a.date_time) ?? picked);
                const time = dtTime(a.date_time);
                const timing = time ? `${when} · ${prettyLower(time)}` : `${when} · All day`;
                return (
                  <button
                    key={a.id}
                    type="button"
                    className={s.entry}
                    onClick={() => openDetail(a.id)}
                  >
                    <CoverArt
                      url={a.image_url}
                      washId={a.id}
                      washTitle={a.title}
                      size="thumb"
                      className={s.thumb}
                    />
                    <span>
                      <span className={s.title}>{a.title}</span>
                      <div className={s.range}>{timing}</div>
                      {a.description && <div className={s.note}>{a.description}</div>}
                      <div className={s.meta}>
                        <span
                          className={s.avatar}
                          style={{
                            background: faceColor(faceIndexFor(a.created_by, faceCtx)),
                          }}
                        >
                          {(partnerName(config, a.created_by)[0] ?? '?').toUpperCase()}
                        </span>
                        {partnerName(config, a.created_by)}
                      </div>
                    </span>
                  </button>
                );
              }

              const e = item.event;
              const owner = ownerIndex(e.ownerId);
              const myId = space?.myId ?? String(space?.me ?? config.me);
              const isMine = e.ownerId === myId || e.ownerId === String(space?.me ?? config.me);
              const ownerName = isMine
                ? (space?.myName ?? config.names[owner] ?? 'You')
                : (config.names[owner] ?? 'Them');
              const when = relativeDay(dtDate(e.startsAt) ?? picked);
              const timing = `${when} · ${pillWhen(e, picked)}`;
              return (
                <button
                  key={e.id}
                  type="button"
                  className={`${s.entry} ${s.entryCal}`}
                  onClick={() => openExternal(e.id)}
                >
                  <span className={s.calThumb} aria-hidden>
                    {artFor(e.title)}
                  </span>
                  <span>
                    <span className={s.title}>{e.title || Copy.availability.busy}</span>
                    <div className={s.range}>{timing}</div>
                    <div className={s.meta}>
                      <span className={s.avatar} style={{ background: faceColor(owner) }}>
                        {(ownerName[0] ?? '?').toUpperCase()}
                      </span>
                      {ownerName}
                      <span className={s.sourceTag}>{sourceTag(e.source)}</span>
                      {isMine && !e.sharedWithSpace && (
                        <span className={s.privateTag}>{Copy.availability.onlyYou}</span>
                      )}
                    </div>
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
