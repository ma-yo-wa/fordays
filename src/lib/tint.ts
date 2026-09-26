import { hueForTitle } from './art';

/* The orb's hues, deepened until they can carry white text but kept
   saturated — a flat dark fill of the same hue goes muddy, and six muddy
   rectangles is what a board of these looked like. Each card is a short
   gradient instead, light at the top corner where nothing sits and dark
   at the bottom where the title does, so the type has contrast without
   a heavy scrim over the whole card.

   Title families (dinner, hike, soccer…) pick a hue from art.ts. No
   match falls back to the id, so a given card still keeps a colour. */
const PALETTE: Array<[string, string]> = [
  ['#E0416F', '#7A1F3D'],
  ['#DE5A3E', '#7E2A28'],
  ['#D0842F', '#6E3F22'],
  ['#A8901F', '#55491F'],
  ['#6C9330', '#35491F'],
  ['#34925A', '#1B4A2E'],
];

function bucket(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (Math.imul(h, 31) + id.charCodeAt(i)) | 0;
  // Ids that share a prefix land together without a final avalanche.
  h ^= h >>> 16;
  h = Math.imul(h, 0x45d9f3b);
  h ^= h >>> 16;
  return Math.abs(h) % PALETTE.length;
}

const gradient = (i: number): string => {
  const [from, to] = PALETTE[i] as [string, string];
  return `linear-gradient(155deg, ${from} 0%, ${to} 82%)`;
};

function hueFor(id: string, title?: string | null): number {
  return hueForTitle(title) ?? bucket(id);
}

export function tintFor(id: string, title?: string | null): string {
  return gradient(hueFor(id, title));
}

/* The hash is uniform, but uniform isn't the same as good-looking: on a
   board of four, random assignment lands three cards on the same hue
   often enough to look broken. So the colour is still derived from the
   title family or the id — a card keeps its own — and then nudged along
   the palette only when it would collide with the card to its left or
   the one above it in the two-column grid. */
export function tintsFor(
  ids: string[],
  titles: Array<string | null | undefined> = [],
): string[] {
  const chosen: number[] = [];
  for (let i = 0; i < ids.length; i++) {
    let idx = hueFor(ids[i] as string, titles[i]);
    for (
      let step = 0;
      step < PALETTE.length && (idx === chosen[i - 1] || idx === chosen[i - 2]);
      step++
    ) {
      idx = (idx + 1) % PALETTE.length;
    }
    chosen.push(idx);
  }
  return chosen.map(gradient);
}

/** One face color for everyone. Initials tell people apart. */
export function faceColor(): string {
  return 'var(--face-fill)';
}

/** Map a profile id (or local demo "0"/"1") onto seat color 0 | 1. */
export function faceIndexFor(
  userId: string,
  ctx: { me: 0 | 1; myId?: string },
): 0 | 1 {
  if (userId === '0' || userId === '1') return userId === '1' ? 1 : 0;
  if (ctx.myId && userId === ctx.myId) return ctx.me;
  return (1 - ctx.me) as 0 | 1;
}
