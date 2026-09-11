export interface StillItem {
  id: string;
  title: string;
  preview: string;
  full: string;
  download: string;
  credit: string;
}

const ACCESS =
  (import.meta.env.VITE_UNSPLASH_ACCESS_KEY as string | undefined)?.trim() ?? '';

const LIMIT = 15;

export async function fetchStills(
  q = '',
  signal?: AbortSignal,
): Promise<StillItem[]> {
  if (!ACCESS) {
    throw Object.assign(new Error('cfg'), { kind: 'cfg' });
  }

  const u = q.trim()
    ? new URL('https://api.unsplash.com/search/photos')
    : new URL('https://api.unsplash.com/photos');
  if (q.trim()) u.searchParams.set('query', q.trim());
  u.searchParams.set('per_page', String(LIMIT));

  const res = await fetch(u, {
    headers: { Authorization: `Client-ID ${ACCESS}` },
    signal,
  });
  if (res.status === 429) throw Object.assign(new Error('rate'), { kind: 'rate' });
  if (res.status === 401 || res.status === 403) {
    throw Object.assign(new Error('cfg'), { kind: 'cfg' });
  }
  if (!res.ok) throw Object.assign(new Error('http'), { kind: 'http' });

  const body = (await res.json()) as
    | { results?: UnsplashPhoto[] }
    | UnsplashPhoto[];
  const rows = Array.isArray(body) ? body : (body.results ?? []);
  return rows.map(toStill).filter((p) => p.preview && p.full);
}

/** Unsplash asks that we ping this when a photo is chosen. */
export function trackStillDownload(download: string): void {
  if (!ACCESS || !download) return;
  void fetch(download, {
    headers: { Authorization: `Client-ID ${ACCESS}` },
  }).catch(() => {
    /* attribution ping — ignore failures */
  });
}

interface UnsplashPhoto {
  id: string;
  description?: string | null;
  alt_description?: string | null;
  urls?: { small?: string; regular?: string };
  links?: { download_location?: string };
  user?: { name?: string };
}

function toStill(p: UnsplashPhoto): StillItem {
  return {
    id: p.id,
    title: p.alt_description || p.description || '',
    preview: p.urls?.small ?? '',
    full: p.urls?.regular ?? p.urls?.small ?? '',
    download: p.links?.download_location ?? '',
    credit: p.user?.name ?? 'Unsplash',
  };
}
