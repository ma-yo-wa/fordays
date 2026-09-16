import { useEffect, useRef, useState } from 'react';
import { motion } from 'motion/react';
import { fetchGifs, type GifItem } from '../lib/giphy';
import { fetchStills, trackStillDownload, type StillItem } from '../lib/unsplash';
import { fileToCoverDataUrl, isEmojiCover } from '../lib/cover';
import CoverArt from './CoverArt';
import f from './Form.module.css';
import s from './CoverPicker.module.css';

type Tab = 'gifs' | 'stills' | 'photos';
type SearchTab = 'gifs' | 'stills';

interface Props {
  value: string | null;
  onChange: (url: string | null) => void;
  titleHint: () => string;
}

export default function CoverPicker({ value, onChange, titleHint }: Props) {
  const [tab, setTab] = useState<Tab>('gifs');
  const [q, setQ] = useState('');
  const [gifs, setGifs] = useState<GifItem[]>([]);
  const [stills, setStills] = useState<StillItem[]>([]);
  const [msg, setMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const timer = useRef<number | null>(null);
  const ctrl = useRef<AbortController | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  async function load(source: SearchTab, query: string) {
    ctrl.current?.abort();
    const mine = new AbortController();
    ctrl.current = mine;
    setLoading(true);
    setMsg(null);
    try {
      if (source === 'gifs') {
        const next = await fetchGifs(query ? 'search' : 'trending', query, mine.signal);
        if (mine.signal.aborted) return;
        setGifs(next);
        if (!next.length) {
          setMsg(query ? `Nothing for “${query}”. Try another word.` : 'No GIFs came back.');
        }
      } else {
        const next = await fetchStills(query, mine.signal);
        if (mine.signal.aborted) return;
        setStills(next);
        if (!next.length) {
          setMsg(query ? `Nothing for “${query}”. Try another word.` : 'No stills came back.');
        }
      }
    } catch (err) {
      if ((err as Error).name === 'AbortError') return;
      const kind = (err as { kind?: string }).kind;
      if (source === 'gifs') setGifs([]);
      else setStills([]);
      setMsg(
        source === 'gifs'
          ? {
              rate: "Giphy's rate limit is hit. Give it a minute.",
              cfg: 'GIFs aren’t available right now.',
              http: 'Giphy returned an error.',
            }[kind ?? ''] ?? "Couldn't reach Giphy."
          : {
              rate: "Unsplash's rate limit is hit. Give it a minute.",
              cfg: 'Stills aren’t available right now.',
              http: 'Unsplash returned an error.',
            }[kind ?? ''] ?? "Couldn't reach Unsplash.",
      );
    } finally {
      if (!mine.signal.aborted) setLoading(false);
    }
  }

  function openSearchTab(id: SearchTab) {
    setTab(id);
    const query = q.trim();
    void load(id, query);
  }

  useEffect(() => {
    setQ('');
    void load('gifs', '');
    return () => ctrl.current?.abort();
  }, []);

  const hits = tab === 'gifs' ? gifs : tab === 'stills' ? stills : [];

  return (
    <div className={s.wrap}>
      {value && (
        <div className={s.preview}>
          <CoverArt url={value} size="hero" className={s.previewArt} />
          <div className={s.tools}>
            <button
              type="button"
              className={`${s.tool} ${s.danger}`}
              onClick={() => {
                onChange(null);
                setGifs([]);
                setStills([]);
                setMsg(null);
              }}
            >
              Remove
            </button>
          </div>
        </div>
      )}

      <div className={f.segmented} role="tablist" aria-label="Cover type">
        {(
          [
            ['gifs', 'GIFs'],
            ['stills', 'Stills'],
            ['photos', 'Photos'],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            role="tab"
            aria-selected={tab === id}
            className={`${f.segment} ${tab === id ? f.segmentOn : ''}`}
            onClick={() => {
              if (id === 'photos') {
                setTab(id);
                setMsg(null);
              } else {
                openSearchTab(id);
              }
            }}
          >
            {tab === id && (
              <motion.span
                layoutId="cover-tab-knob"
                className={f.segmentKnob}
                transition={{ type: 'spring', stiffness: 520, damping: 38 }}
              />
            )}
            <span className={f.segmentLabel}>{label}</span>
          </button>
        ))}
      </div>

      {(tab === 'gifs' || tab === 'stills') && (
        <div className={`${s.search} ${loading ? s.loading : ''}`}>
          <span className={s.mag} aria-hidden>
            ⌕
          </span>
          <input
            className={s.searchInput}
            value={q}
            placeholder={tab === 'gifs' ? 'Search Giphy…' : 'Search Unsplash…'}
            onChange={(e) => {
              const next = e.target.value;
              setQ(next);
              if (timer.current) window.clearTimeout(timer.current);
              timer.current = window.setTimeout(() => {
                void load(tab, next.trim());
              }, 300);
            }}
            onFocus={() => {
              if (tab !== 'gifs' && tab !== 'stills') return;
              if (q.trim() || hits.length) return;
              const t = titleHint().trim();
              if (t) {
                setQ(t);
                void load(tab, t);
              } else {
                void load(tab, '');
              }
            }}
          />
          {q ? (
            <button
              type="button"
              className={s.clear}
              aria-label="Clear search"
              onClick={() => {
                setQ('');
                if (tab === 'gifs' || tab === 'stills') void load(tab, '');
              }}
            >
              ×
            </button>
          ) : null}
        </div>
      )}

      {tab === 'gifs' && gifs.length > 0 && (
        <div className={s.gifGrid}>
          {gifs.map((g, i) => (
            <button
              key={g.id}
              type="button"
              className={`${s.gifCell} ${value === g.full ? s.iconOn : ''}`}
              style={{ ['--i' as string]: i }}
              onClick={() => {
                onChange(g.full);
                setMsg(null);
              }}
            >
              <img src={g.preview} alt={g.title.slice(0, 60)} loading="lazy" />
            </button>
          ))}
        </div>
      )}

      {tab === 'stills' && stills.length > 0 && (
        <>
          <div className={s.gifGrid}>
            {stills.map((p, i) => (
              <button
                key={p.id}
                type="button"
                className={`${s.gifCell} ${value === p.full ? s.iconOn : ''}`}
                style={{ ['--i' as string]: i }}
                onClick={() => {
                  trackStillDownload(p.download);
                  onChange(p.full);
                  setMsg(null);
                }}
              >
                <img src={p.preview} alt={p.title.slice(0, 60)} loading="lazy" />
              </button>
            ))}
          </div>
          <p className={s.photoNote}>
            <a
              href="https://unsplash.com/?utm_source=fordays&utm_medium=referral"
              target="_blank"
              rel="noreferrer"
            >
              Photos via Unsplash
            </a>
          </p>
        </>
      )}

      {tab === 'photos' && (
        <div className={s.photos}>
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            className={s.file}
            onChange={(e) => {
              const file = e.target.files?.[0];
              e.target.value = '';
              if (!file) return;
              void (async () => {
                try {
                  const url = await fileToCoverDataUrl(file);
                  onChange(url);
                  setMsg(null);
                } catch (err) {
                  setMsg(err instanceof Error ? err.message : 'Couldn’t use that photo');
                }
              })();
            }}
          />
          <button
            type="button"
            className={s.photoBtn}
            onClick={() => fileRef.current?.click()}
          >
            Choose from library
          </button>
          <p className={s.photoNote}>
            Picks a photo from this phone. It’s saved with this.
          </p>
          {value && !isEmojiCover(value) && value.startsWith('data:') ? (
            <CoverArt url={value} size="thumb" className={s.photoThumb} />
          ) : null}
        </div>
      )}

      {msg && (
        <div className={s.msg}>
          <span>{msg}</span>
          {tab === 'gifs' || tab === 'stills' ? (
            <button type="button" onClick={() => void load(tab, q.trim())}>
              Retry
            </button>
          ) : null}
        </div>
      )}
    </div>
  );
}
