/** Warm the cover cache (service worker + browser) for Someday cards. */
export function prefetchCovers(urls: Array<string | null | undefined>): void {
  if (typeof window === 'undefined') return;
  for (const url of urls) {
    if (!url || !/^https?:/i.test(url)) continue;
    const img = new Image();
    img.decoding = 'async';
    img.src = url;
  }
}
