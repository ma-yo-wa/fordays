import { useEffect, useMemo } from 'react';
import CoverArt from '../components/CoverArt';
import { useApp, partnerName, isMatched } from '../lib/store';
import { isBucketItem } from '../lib/types';
import { tintsFor } from '../lib/tint';
import { prefetchCovers } from '../lib/coverCache';
import { Copy } from '../lib/copy';
import s from './BucketList.module.css';

export default function BucketList() {
  const activities = useApp((st) => st.activities);
  const config = useApp((st) => st.config);
  const openDetail = useApp((st) => st.openDetail);
  const matched = useApp((st) => isMatched(st.space));
  const frozen = useApp((st) => Boolean(st.space?.frozen));

  const items = useMemo(
    () =>
      activities
        .filter(isBucketItem)
        .slice()
        .sort((a, b) => +new Date(b.created_at) - +new Date(a.created_at)),
    [activities],
  );

  const tints = tintsFor(
    items.map((a) => a.id),
    items.map((a) => a.title),
  );

  useEffect(() => {
    prefetchCovers(items.map((a) => a.image_url));
  }, [items]);

  if (!items.length) {
    return (
      <div className={s.board}>
        <div className={s.blank}>
          <p>
            {frozen
              ? Copy.ideas.emptyFrozen
              : matched
                ? Copy.ideas.emptyShared
                : Copy.ideas.emptySolo}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className={s.board}>
      {items.map((a, i) => (
        <button
          key={a.id}
          type="button"
          className={s.card}
          style={{ background: tints[i] }}
          onClick={() => openDetail(a.id)}
        >
          {a.image_url && (
            <CoverArt url={a.image_url} size="card" className={s.art} eager={i < 8} />
          )}
          <div className={s.veil} />

          <div className={s.body}>
            <h3 className={s.title}>{a.title}</h3>
            <div className={s.foot}>{partnerName(config, a.created_by)}</div>
          </div>
        </button>
      ))}
    </div>
  );
}
