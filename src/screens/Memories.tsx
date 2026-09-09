import { motion } from 'motion/react';
import CoverArt from '../components/CoverArt';
import { useApp, isMatched } from '../lib/store';
import { isMemory } from '../lib/types';
import { dtDate, MON3, parseISO, todayISO } from '../lib/date';
import { tintsFor } from '../lib/tint';
import s from './BucketList.module.css';

function memoryWhen(dateTime: string): string {
  const d = parseISO(dateTime);
  const mon = MON3[d.getMonth()] ?? '';
  return `${mon} ${d.getDate()}, ${d.getFullYear()}`;
}

export default function Memories() {
  const activities = useApp((st) => st.activities);
  const openDetail = useApp((st) => st.openDetail);
  const matched = useApp((st) => isMatched(st.space));
  const today = todayISO();

  const items = activities
    .filter((a) => isMemory(a, today))
    .slice()
    .sort((a, b) => {
      const ae = (a.ends_at ?? a.date_time)!.slice(0, 10);
      const be = (b.ends_at ?? b.date_time)!.slice(0, 10);
      return be.localeCompare(ae);
    });

  const tints = tintsFor(items.map((a) => a.id));

  if (!items.length) {
    return (
      <div className={s.board}>
        <div className={s.blank}>
          <p>
            {matched
              ? 'Plans you’ve lived together will land here'
              : 'Invite your person — memories gather as you keep plans'}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className={s.board}>
      {items.map((a, i) => {
        const when = dtDate(a.date_time);
        return (
          <motion.button
            key={a.id}
            type="button"
            className={s.card}
            style={{ background: tints[i] }}
            onClick={() => openDetail(a.id)}
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{
              delay: Math.min(i, 7) * 0.055,
              duration: 0.5,
              ease: [0.2, 0.8, 0.2, 1],
            }}
          >
            {a.image_url && <CoverArt url={a.image_url} size="card" className={s.art} />}
            <div className={s.veil} />

            <div className={s.body}>
              <h3 className={s.title}>{a.title}</h3>
              <div className={s.foot}>{when ? memoryWhen(when) : ''}</div>
            </div>
          </motion.button>
        );
      })}
    </div>
  );
}
