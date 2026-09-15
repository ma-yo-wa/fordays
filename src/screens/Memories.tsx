import CoverArt from '../components/CoverArt';
import { useApp, isMatched } from '../lib/store';
import type { Activity } from '../lib/types';
import { isMemory } from '../lib/types';
import { MON3, todayISO } from '../lib/date';
import { tintsFor } from '../lib/tint';
import s from './Memories.module.css';

function monthKey(a: Activity): string {
  return (a.ends_at ?? a.date_time)!.slice(0, 7);
}

function monthLabel(key: string): string {
  const [y, m] = key.split('-').map(Number);
  const mon = MON3[(m ?? 1) - 1] ?? '';
  return `${mon} ${y}`;
}

function groupByMonth(items: Activity[]): { key: string; label: string; items: Activity[] }[] {
  const map = new Map<string, Activity[]>();
  for (const a of items) {
    const key = monthKey(a);
    const list = map.get(key);
    if (list) list.push(a);
    else map.set(key, [a]);
  }
  return [...map.entries()]
    .sort(([a], [b]) => b.localeCompare(a))
    .map(([key, group]) => ({ key, label: monthLabel(key), items: group }));
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

  const sections = groupByMonth(items);
  const tints = tintsFor(
    items.map((a) => a.id),
    items.map((a) => a.title),
  );
  const tintById = new Map(items.map((a, i) => [a.id, tints[i]!]));

  if (!items.length) {
    return (
      <div className={s.wrap}>
        <div className={s.blank}>
          <p>
            {matched
              ? 'Plans you’ve lived together will land here'
              : 'Plans you’ve lived will land here'}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className={s.wrap}>
      {sections.map((section) => (
        <section key={section.key}>
          <h2 className={s.month}>{section.label}</h2>
          <div className={s.board}>
            {section.items.map((a) => (
              <button
                key={a.id}
                type="button"
                className={s.card}
                style={{ background: tintById.get(a.id) }}
                onClick={() => openDetail(a.id)}
              >
                {a.image_url && (
                  <CoverArt url={a.image_url} size="card" className={s.art} />
                )}
                <div className={s.veil} />
                <div className={s.body}>
                  <h3 className={s.title}>{a.title}</h3>
                </div>
              </button>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
