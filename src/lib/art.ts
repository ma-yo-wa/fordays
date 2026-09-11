/* Title → kind, offline. First match wins. Glyphs still mark imported
   GCal rows. Families pick the orb wash when there’s no picture. */

export type ArtFamily =
  | 'food'
  | 'home'
  | 'trip'
  | 'culture'
  | 'outdoors'
  | 'sport';

/** Index into the orb palette in tint.ts (rose → sage). */
export const FAMILY_HUE: Record<ArtFamily, number> = {
  food: 0,
  home: 1,
  trip: 2,
  culture: 3,
  outdoors: 4,
  sport: 5,
};

const ART: Array<[RegExp, string, ArtFamily | null]> = [
  [/flight|fly|airline|airport|boarding|depart|arriv/i, '✈️', 'trip'],
  [/hotel|reservation|booking|check-?in|airbnb|room|suite/i, '🏨', 'trip'],
  [/train|rail|via |amtrak/i, '🚆', 'trip'],
  [/drive|road ?trip/i, '🛣', 'trip'],
  [/trip|travel|vacation|holiday|getaway|abroad/i, '✈️', 'trip'],
  [/beach|sunset|ocean|island|swim|mallorca|ibiza|hawaii/i, '🌅', 'trip'],
  [/hike|hiking|trail|mountain|camp|banff|cabin/i, '🏔', 'outdoors'],
  [/kayak|canoe|paddle|river|boat|cruise|harbou?r/i, '🛶', 'outdoors'],
  [/garden|plant|flower|picnic|park/i, '🌿', 'outdoors'],
  [/gym|workout|run|yoga|training|climb|soccer|football|match|pitch|tennis|basketball/i, '🏃', 'sport'],
  [/bike|cycl|ride/i, '🚲', 'sport'],
  [/dinner|restaurant|ramen|sushi|food|brunch|lunch|eat|waffle|pizza|taco/i, '🍜', 'food'],
  [/coffee|cafe|espresso/i, '☕', 'food'],
  [/cook|bake|kitchen|recipe/i, '🍳', 'food'],
  [/movie|film|cinema|screening/i, '🎞', 'culture'],
  [/concert|music|gig|festival|album/i, '🎶', 'culture'],
  [/museum|gallery|exhibit/i, '🖼', 'culture'],
  [/read|book|library/i, '📖', 'culture'],
  [/game|arcade|board/i, '🎲', 'culture'],
  [/birthday|anniversary|celebrat|wedding/i, '🎂', 'home'],
  [/dance|salsa|club/i, '💃', 'home'],
  [/spa|massage|rest|lazy|sleep/i, '🛁', 'home'],
  [/doctor|dentist|appointment|clinic|therapy/i, '🩺', null],
  [/call|sync|standup|stand-up|1:1|meeting|review|interview/i, '💬', null],
  [/deadline|due|launch|ship/i, '🚩', null],
];

export function familyFor(title: string | null | undefined): ArtFamily | null {
  if (!title) return null;
  for (const [re, , family] of ART) {
    if (family && re.test(title)) return family;
  }
  return null;
}

export function hueForTitle(title: string | null | undefined): number | null {
  const family = familyFor(title);
  return family ? FAMILY_HUE[family] : null;
}

export function artFor(title: string | null | undefined): string {
  if (!title) return '🗓';
  for (const [re, glyph] of ART) if (re.test(title)) return glyph;
  return '✦';
}
