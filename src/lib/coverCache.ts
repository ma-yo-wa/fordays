/** One screen of the two-column Someday / Memories board. */
export const FIRST_BOARD_COVERS = 6;

/** Warm stills, GIFs, and gallery photos for the first screen. */
export function prefetchCovers(urls: Array<string | null | undefined>): void {
  if (typeof window === 'undefined') return;
  for (const url of urls) {
    if (!url || url.startsWith('emoji:')) continue;
    if (url.startsWith('data:image') || /^https?:/i.test(url)) {
      const img = new Image();
      img.decoding = 'async';
      img.src = url;
    }
  }
}

function lastDay(a: { date_time: string | null; ends_at?: string | null }): string {
  return (a.ends_at ?? a.date_time ?? '').slice(0, 10);
}

function isPastPlan(
  a: { date_time: string | null; ends_at?: string | null },
  today = new Date().toISOString().slice(0, 10),
): boolean {
  if (!a.date_time) return false;
  return lastDay(a) < today;
}

export function prefetchSomedayCovers(
  items: Array<{ created_at: string; image_url?: string | null }>,
): void {
  prefetchCovers(
    items
      .slice()
      .sort((a, b) => +new Date(b.created_at) - +new Date(a.created_at))
      .slice(0, FIRST_BOARD_COVERS)
      .map((a) => a.image_url),
  );
}

export function prefetchMemoriesCovers(
  items: Array<{ date_time: string | null; ends_at?: string | null; image_url?: string | null }>,
): void {
  prefetchCovers(
    items
      .filter((a) => isPastPlan(a))
      .slice()
      .sort((a, b) => lastDay(b).localeCompare(lastDay(a)))
      .slice(0, FIRST_BOARD_COVERS)
      .map((a) => a.image_url),
  );
}

export function prefetchBoardCovers(
  items: Array<{
    created_at: string;
    date_time: string | null;
    ends_at?: string | null;
    image_url?: string | null;
  }>,
): void {
  prefetchSomedayCovers(items.filter((a) => !a.date_time));
  prefetchMemoriesCovers(items);
}
