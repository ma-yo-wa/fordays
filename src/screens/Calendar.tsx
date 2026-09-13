import { motion } from 'motion/react';
import CoverArt from '../components/CoverArt';
import { useApp, partnerName, isMatched, canCompose } from '../lib/store';
import { isPlan, planDraftFromExternal, type ExternalEvent } from '../lib/types';
import { artFor } from '../lib/art';
import { faceColor, faceIndexFor } from '../lib/tint';
import {
  MONTHS,
  dtDate,
  dtTime,
  monthGrid,
  parseISO,
  prettyLower,
  relativeDay,
  spanDays,
  todayISO,
} from '../lib/date';
import { Copy, formatCopy } from '../lib/copy';
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

export default function Calendar() {
  const activities = useApp((st) => st.activities);
  const external = useApp((st) => st.external);
  const config = useApp((st) => st.config);
  const picked = useApp((st) => st.picked);
  const cursor = useApp((st) => st.cursor);
  const setPicked = useApp((st) => st.setPicked);
  const openDetail = useApp((st) => st.openDetail);
  const openExternal = useApp((st) => st.openExternal);
  const openComposer = useApp((st) => st.openComposer);
  const space = useApp((st) => st.space);

  const cursorDate = parseISO(cursor);
  const today = todayISO();
  const matched = isMatched(space);
  const other = matched ? space?.partnerName ?? null : null;

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
     booking shows up across all four. */
  const extByDate = new Map<string, ExternalEvent[]>();
  for (const e of external) {
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

  const pickedDate = parseISO(picked);
  const dayHeading =
    picked === today
      ? 'Today'
      : `${MONTHS[pickedDate.getMonth()]} ${pickedDate.getDate()}`;

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

          let trackStyle: React.CSSProperties | undefined;
          if (isSpanning) {
            const roundLeft = startsHere ? '15px' : isRowStart ? '6px' : '0';
            const roundRight = endsHere ? '15px' : isRowEnd ? '6px' : '0';
            const leftInset = startsHere ? 'calc(50% - 15px)' : isRowStart ? '2px' : '0';
            const rightInset = endsHere ? 'calc(50% - 15px)' : isRowEnd ? '2px' : '0';

            trackStyle = {
              left: leftInset,
              right: rightInset,
              borderRadius: `${roundLeft} ${roundRight} ${roundRight} ${roundLeft}`,
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
              </span>
            </button>
          );
        })}
      </div>

      <div className={s.agenda}>
        <div className={s.dayLabel}>{dayHeading}</div>

        {!dayPlans.length ? (
          <div className={s.blank}>
            <p>
              {space?.frozen
                ? Copy.plans.emptyFrozen
                : dayExternal.length > 0
                  ? Copy.plans.emptyTogether
                  : other
                    ? picked === today
                      ? formatCopy(Copy.plans.emptyTodayPartner, { partner: other })
                      : formatCopy(Copy.plans.emptyDayPartner, { partner: other })
                    : picked === today
                      ? Copy.plans.emptyToday
                      : Copy.plans.emptyDay}
            </p>
          </div>
        ) : (
          <div className={s.plansList}>
            {dayPlans.map((a, i) => {
              const when = relativeDay(dtDate(a.date_time) ?? picked);
              const time = dtTime(a.date_time);
              const timing = time ? `${when} · ${prettyLower(time)}` : `${when} · All day`;
              return (
                <motion.button
                  key={a.id}
                  type="button"
                  className={s.entry}
                  onClick={() => openDetail(a.id)}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.05, duration: 0.4 }}
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
                </motion.button>
              );
            })}
          </div>
        )}

        {dayExternal.length > 0 && (
          <div className={s.availabilitySection}>
            <div className={s.availabilityHeader}>
              <span className={s.availabilityTitle}>{Copy.availability.title}</span>
              <span className={s.availabilitySub}>{Copy.availability.googleCalendar}</span>
            </div>
            <div className={s.availabilityList}>
              {dayExternal.map((e) => {
                const owner = ownerIndex(e.ownerId);
                const ownerName = config.names[owner] ?? 'Them';
                return (
                  <div
                    key={e.id}
                    className={s.availabilityRow}
                    onClick={() => openExternal(e.id)}
                    role="button"
                    tabIndex={0}
                    onKeyDown={(ev) => {
                      if (ev.key === 'Enter' || ev.key === ' ') openExternal(e.id);
                    }}
                  >
                    <span className={s.availabilityGlyph} aria-hidden>
                      {artFor(e.title)}
                    </span>
                    <div className={s.availabilityText}>
                      <span className={s.availabilityName}>{e.title || Copy.availability.busy}</span>
                      <span className={s.availabilityTime}>
                        {pillWhen(e, picked)} · {ownerName}
                      </span>
                    </div>
                    {e.title && canCompose(space) && (
                      <button
                        type="button"
                        className={s.makePlanAction}
                        onClick={(ev) => {
                          ev.stopPropagation();
                          openComposer('plan', planDraftFromExternal(e));
                        }}
                      >
                        {Copy.availability.makePlanShort}
                      </button>
                    )}
                    <span
                      className={s.availabilityWho}
                      style={{ background: faceColor(owner) }}
                    >
                      {(ownerName[0] ?? '?').toUpperCase()}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
