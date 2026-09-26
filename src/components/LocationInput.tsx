import { useState, useEffect, useRef } from 'react';
import { PinIcon } from '../ui';
import f from './Form.module.css';

interface Suggestion {
  title: string;
  subtitle: string;
  full: string;
}

interface Props {
  value: string;
  onChange: (val: string) => void;
  placeholder?: string;
  onEnter?: () => void;
}

export function LocationInput({
  value,
  onChange,
  placeholder = 'Where is this?',
  onEnter,
}: Props) {
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const containerRef = useRef<HTMLDivElement>(null);
  const blurTimerRef = useRef<number | null>(null);

  useEffect(() => {
    const trimmed = value.trim();
    if (trimmed.length < 2) {
      setSuggestions([]);
      setIsOpen(false);
      return;
    }

    const controller = new AbortController();
    const timer = setTimeout(async () => {
      try {
        const res = await fetch(
          `https://photon.komoot.io/api/?q=${encodeURIComponent(trimmed)}&limit=5`,
          { signal: controller.signal },
        );
        if (!res.ok) return;
        const data = await res.json();
        if (!Array.isArray(data.features)) return;

        const parsed: Suggestion[] = data.features.map(
          (feat: {
            properties?: {
              name?: string;
              housenumber?: string;
              street?: string;
              locality?: string;
              district?: string;
              city?: string;
              state?: string;
              country?: string;
            };
          }) => {
            const p = feat.properties || {};
            const street = [p.housenumber, p.street].filter(Boolean).join(' ');
            const title = p.name || street || p.city || p.country || 'Location';

            const subParts: string[] = [];
            if (p.name && street && street !== p.name) subParts.push(street);
            const place = p.locality || p.district || p.city;
            if (place && place !== title) subParts.push(place);
            if (p.state && p.state !== place) subParts.push(p.state);
            if (p.country && p.country !== title && p.country !== p.state) {
              subParts.push(p.country);
            }
            const subtitle = subParts.join(', ');

            const full = [title, subtitle].filter(Boolean).join(', ');
            return { title, subtitle, full };
          },
        );

        setSuggestions(parsed);
        setIsOpen(parsed.length > 0);
        setActiveIndex(-1);
      } catch {
        // Silently catch aborts and offline errors
      }
    }, 250);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [value]);

  function handleSelect(sug: Suggestion) {
    onChange(sug.full);
    setSuggestions([]);
    setIsOpen(false);
    setActiveIndex(-1);
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (isOpen && suggestions.length > 0) {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setActiveIndex((prev) => (prev < suggestions.length - 1 ? prev + 1 : 0));
        return;
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        setActiveIndex((prev) => (prev > 0 ? prev - 1 : suggestions.length - 1));
        return;
      }
      if (e.key === 'Enter') {
        e.preventDefault();
        if (activeIndex >= 0 && suggestions[activeIndex]) {
          handleSelect(suggestions[activeIndex]);
        } else {
          setIsOpen(false);
          onEnter?.();
        }
        return;
      }
      if (e.key === 'Escape') {
        e.preventDefault();
        setIsOpen(false);
        return;
      }
    } else if (e.key === 'Enter') {
      onEnter?.();
    }
  }

  function handleFocus() {
    if (blurTimerRef.current) clearTimeout(blurTimerRef.current);
    if (suggestions.length > 0) setIsOpen(true);
  }

  function handleBlur() {
    blurTimerRef.current = window.setTimeout(() => {
      setIsOpen(false);
    }, 200);
  }

  return (
    <div className={f.locationWrap} ref={containerRef}>
      <div className={f.group}>
        <div className={f.locationRow}>
          <span className={f.locationPinIcon} aria-hidden>
            <PinIcon />
          </span>
          <input
            className={`${f.input} ${f.locationInputWithPin}`}
            value={value}
            onChange={(e) => onChange(e.target.value)}
            onFocus={handleFocus}
            onBlur={handleBlur}
            onKeyDown={handleKeyDown}
            placeholder={placeholder}
            autoComplete="off"
            enterKeyHint="done"
          />
          {value.trim().length > 0 && (
            <button
              type="button"
              className={f.fieldClear}
              onClick={() => {
                onChange('');
                setSuggestions([]);
                setIsOpen(false);
              }}
              aria-label="Clear location"
            >
              ×
            </button>
          )}
        </div>
      </div>

      {isOpen && suggestions.length > 0 && (
        <div className={f.locationDropdown}>
          {suggestions.map((sug, i) => (
            <button
              key={`${sug.full}-${i}`}
              type="button"
              className={`${f.locationItem} ${i === activeIndex ? f.locationItemActive : ''}`}
              onMouseDown={(e) => {
                e.preventDefault(); // prevents blur before click
                handleSelect(sug);
              }}
            >
              <span className={f.locationItemTitle}>{sug.title}</span>
              {sug.subtitle && (
                <span className={f.locationItemSubtitle}>{sug.subtitle}</span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
