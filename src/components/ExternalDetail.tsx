import { useState } from 'react';
import Sheet from './Sheet';
import CoverArt from './CoverArt';
import ActionSheet from './ActionSheet';
import { useApp } from '../lib/store';
import { Avatar, Pill, ActionRow } from '../ui';
import { describePlan, dtDate } from '../lib/date';
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
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
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

  const event = external.find((e) => e.id === externalId) ?? null;
  const owner = event
    ? resolveOwner(event.ownerId, space?.me ?? config.me, space?.myId)
    : config.me;
  const isMine = owner === (space?.me ?? config.me);
  const ownerName = isMine
    ? 'You'
    : (space?.partnerName ?? config.names[owner] ?? 'Them');
  const possessive = isMine ? 'your' : `${ownerName}’s`;

  const activeOrbs = spaces.filter((s) => !s.frozen);
  const activeSharedOrbs = activeOrbs.filter((s) => s.id !== space?.id);

  function targetOrbName(target: SpaceInfo): string {
    return target.partnerName || target.name || 'Orb';
  }

  /* Same label as plan Detail's Do with list. */
  function targetOrbLabel(target: SpaceInfo): string {
    return target.partnerName ? `${target.partnerName} (${target.name})` : target.name;
  }

  /* An imported event is a plan: its when reads like plan Detail's. */
  function describeEvent(e: { startsAt: string; endsAt: string; allDay: boolean }): string {
    if (!e.allDay) return describePlan(e.startsAt, e.endsAt || null);
    const start = dtDate(e.startsAt) as string;
    const end = dtDate(e.endsAt);
    return describePlan(start, end && end !== start ? end : null);
  }

  async function handleDoWith(targetSpace: SpaceInfo) {
    if (!event) return;
    try {
      await create({
        title: event.title || 'Plan',
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
                <h3 className={s.title}>{event.title || Copy.availability.busy}</h3>
                <div className={s.range}>{describeEvent(event)}</div>
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
                <Avatar
                  name={ownerName}
                  seat={owner}
                  size="sm"
                />
                <span>{ownerName}</span>
                <Pill variant="neutral" size="sm">
                  {event.calendar || (event.source ? event.source.toUpperCase() : 'CALENDAR')}
                </Pill>
              </div>
            </div>

            {activeSharedOrbs.length > 0 && (
              <div className={s.actions}>
                {activeSharedOrbs.length === 1 && activeSharedOrbs[0] ? (
                  <ActionRow
                    icon={<PeopleIcon />}
                    label={formatCopy(Copy.orbs.doWith, {
                      name: targetOrbName(activeSharedOrbs[0]),
                    })}
                    onClick={() => void handleDoWith(activeSharedOrbs[0]!)}
                  />
                ) : (
                  <ActionRow
                    icon={<PeopleIcon />}
                    label={Copy.orbs.doWithEllipsis}
                    onClick={() => setDoWithOpen(true)}
                  />
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
          label: targetOrbLabel(target),
          onClick: () => void handleDoWith(target),
        }))}
        onCancel={() => setDoWithOpen(false)}
      />
    </>
  );
}
