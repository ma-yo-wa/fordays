/** One screen of the two-column Someday board. */
export const FIRST_SOMEDAY_COVERS = 6;

/** Warm the cover cache for the first screen of Someday cards. */
export function prefetchCovers(urls: Array<string | null | undefined>): void {
  if (typeof window === 'undefined') return;
  for (const url of urls) {
    if (!url || !/^https?:/i.test(url)) continue;
    const img = new Image();
    img.decoding = 'async';
    img.src = url;
  }
}

export function prefetchSomedayCovers(
  items: Array<{ created_at: string; image_url?: string | null }>,
): void {
  prefetchCovers(
    items
      .slice()
      .sort((a, b) => +new Date(b.created_at) - +new Date(a.created_at))
      .slice(0, FIRST_SOMEDAY_COVERS)
      .map((a) => a.image_url),
  );
}
