import { useState } from 'react';
import Sheet from './Sheet';
import CoverArt from './CoverArt';
import ActionSheet from './ActionSheet';
import { useApp } from '../lib/store';
import { faceColor } from '../lib/tint';
import { formatRange } from '../lib/date';
import { Copy, formatCopy } from '../lib/copy';
import type { SpaceInfo } from '../lib/auth';
import s from './ExternalDetail.module.css';

function resolveOwner(
  ownerId: string,
  me: 0 | 1,
  myId: string | undefined,
): 0 | 1 {
  if (ownerId === '0' || ownerId === '1') return ownerId === '1' ? 1 : 0;
  if (myId && ownerId === myId) return me;
  return (1 - me) as 0 | 1;
}

function PeopleIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" strokeLinecap="round" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" strokeLinecap="round" />
    </svg>
  );
}

export default function ExternalDetail() {
  const externalId = useApp((st) => st.externalId);
  const external = useApp((st) => st.external);
  const config = useApp((st) => st.config);
  const openExternal = useApp((st) => st.openExternal);
  const create = useApp((st) => st.create);
  const spaces = useApp((st) => st.spaces);
  const toast = useApp((st) => st.toast);
  const space = useApp((st) => st.space);

  const [doWithOpen, setDoWithOpen] = useState(false);
  const [movingBusy, setMovingBusy] = useState(false);

  const event = external.find((e) => e.id === externalId) ?? null;
  const owner = event
    ? resolveOwner(event.ownerId, space?.me ?? config.me, space?.myId)
    : config.me;
  const isMine = owner === (space?.me ?? config.me);
  const ownerName = isMine
    ? 'You'
    : (space?.partnerName ?? config.names[owner] ?? 'Them');
  const possessive = isMine ? 'your' : `${ownerName}’s`;
  const initial = (
    (isMine ? space?.myName : space?.partnerName) ??
    config.names[owner] ??
    '?'
  )
    .trim()
    .charAt(0)
    .toUpperCase() || '?';

  const activeOrbs = spaces.filter((s) => !s.frozen);
  const activeSharedOrbs = activeOrbs.filter((s) => s.id !== space?.id);

  function targetOrbName(target: SpaceInfo): string {
    return target.partnerName || target.name || 'Orb';
  }

  async function handleDoWith(targetSpace: SpaceInfo) {
    if (!event) return;
    setMovingBusy(true);
    try {
      await create({
        title: event.title ?? 'Plan',
        location: event.location,
        date_time: event.startsAt,
        ends_at: event.endsAt || null,
        space_id: targetSpace.id,
      });
      const targetName = targetOrbName(targetSpace);
      toast(formatCopy(Copy.orbs.movedToPlans, { orb: targetName }));
      openExternal(null);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t add plan');
    } finally {
      setMovingBusy(false);
    }
  }

  return (
    <>
      <Sheet open={!!event} onClose={() => openExternal(null)}>
        {event && (
          <div className={s.body}>
            <div className={s.head}>
              <CoverArt
                washId={event.id}
                washTitle={event.title}
                size="thumb"
                className={s.headWash}
              />
              <div className={s.headMeta}>
                <h3 className={s.title}>{event.title ?? 'Busy'}</h3>
                <div className={s.range}>
                  {formatRange(event.startsAt, event.endsAt, event.allDay)}
                </div>
                {event.location && (
                  <a
                    href={`https://maps.apple.com/?q=${encodeURIComponent(event.location)}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className={s.locationLink}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <span className={s.locationPin} aria-hidden>📍</span>
                    <span>{event.location}</span>
                    <span className={s.locationArrow} aria-hidden>↗</span>
                  </a>
                )}
              </div>
            </div>

            <div className={s.rows}>
              <div className={s.row}>
                <span
                  className={s.avatar}
                  style={{ background: faceColor(owner) }}
                  aria-hidden
                >
                  {initial}
                </span>
                <span>{ownerName}</span>
                <span className={s.sourcePill}>
                  {event.calendar || (event.source ? event.source.toUpperCase() : 'CALENDAR')}
                </span>
              </div>
            </div>

            {activeSharedOrbs.length > 0 && (
              <div className={s.actions}>
                {activeSharedOrbs.length === 1 && activeSharedOrbs[0] ? (
                  <button
                    type="button"
                    className={s.action}
                    onClick={() => void handleDoWith(activeSharedOrbs[0]!)}
                    disabled={movingBusy}
                  >
                    <PeopleIcon />
                    {formatCopy(Copy.orbs.doWith, {
                      name: targetOrbName(activeSharedOrbs[0]),
                    })}
                  </button>
                ) : (
                  <button
                    type="button"
                    className={s.action}
                    onClick={() => setDoWithOpen(true)}
                    disabled={movingBusy}
                  >
                    <PeopleIcon />
                    {Copy.orbs.doWithEllipsis}
                  </button>
                )}
              </div>
            )}

            <p className={s.foot}>
              {formatCopy(Copy.availability.importedFoot, { owner: possessive })}
            </p>
          </div>
        )}
      </Sheet>

      <ActionSheet
        open={doWithOpen}
        title={Copy.orbs.doWithEllipsis}
        actions={activeSharedOrbs.map((target) => ({
          label: targetOrbName(target),
          onClick: () => void handleDoWith(target),
        }))}
        onCancel={() => setDoWithOpen(false)}
      />
    </>
  );
}
