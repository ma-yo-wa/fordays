import type { SpaceInfo } from '../lib/auth';
import { faceColor } from '../lib/tint';
import ui from './Settings.module.css';

export type OrbFaceChip = { key: string; letter: string; them: boolean };

function firstLetter(name: string): string {
  return (name.trim()[0] ?? '?').toUpperCase();
}

/** You first, then everyone else, as one letter each. */
export function orbFaceChips(space: SpaceInfo): OrbFaceChip[] {
  if (space.members?.length) {
    const mine = space.members.find((m) => m.id === space.myId);
    const others = space.members.filter((m) => m.id !== space.myId);
    const ordered = mine ? [mine, ...others] : space.members;
    return ordered.map((m) => ({
      key: m.id,
      letter: firstLetter(m.name),
      them: m.id !== space.myId,
    }));
  }
  return [
    { key: 'me', letter: firstLetter(space.myName || '?'), them: false },
    ...(space.partnerName
      ? [{ key: 'them', letter: firstLetter(space.partnerName), them: true }]
      : []),
  ];
}

/* Where each face sits in an Orb tile, in steps of (face − overlap) / 2
   from the centre: one centred, two side by side, three as two over one,
   four as a square. Past four, the last spot says +N. Same as iOS. */
const ORB_SPOTS: Record<number, Array<[number, number]>> = {
  1: [[0, 0]],
  2: [[-1, 0], [1, 0]],
  3: [[-1, -1], [1, -1], [0, 1]],
  4: [[-1, -1], [1, -1], [-1, 1], [1, 1]],
};

export default function OrbFaces({
  faces,
  small = false,
}: {
  faces: { key: string; letter: string }[];
  /** The row-sized cluster used in Settings lists. */
  small?: boolean;
}) {
  const spots = ORB_SPOTS[Math.min(Math.max(faces.length, 1), 4)] ?? [];
  const more = faces.length > 4 ? faces.length - 3 : 0;
  const shown = more ? faces.slice(0, 3) : faces.slice(0, 4);
  const place = ([x, y]: [number, number]) =>
    `translate(calc(-50% + ${x} * var(--orb-face-step)), calc(-50% + ${y} * var(--orb-face-step)))`;
  return (
    <span className={`${ui.orbFaceCluster} ${small ? ui.orbFaceClusterSm : ''}`} aria-hidden>
      {shown.map((f, idx) => (
        <span
          key={f.key}
          className={ui.orbMiniFace}
          style={{ zIndex: 4 - idx, background: faceColor(f.key), transform: place(spots[idx]!) }}
        >
          {f.letter}
        </span>
      ))}
      {more > 0 && (
        <span className={`${ui.orbMiniFace} ${ui.orbMiniMore}`} style={{ transform: place(spots[3]!) }}>
          +{more}
        </span>
      )}
    </span>
  );
}
