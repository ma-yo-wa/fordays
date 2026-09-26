import { useEffect, useState } from 'react';
import { BucketIcon, CalendarIcon } from './TabBar';
import s from './DesktopGate.module.css';

/**
 * Editorial marketing landing page shown exclusively on desktop browsers.
 * The Fordays planner runs exclusively on phone / installed mobile PWA.
 */
export default function DesktopGate() {
  const [targetUrl, setTargetUrl] = useState('https://fordays.app');
  const [hasInvite, setHasInvite] = useState(false);

  useEffect(() => {
    document.documentElement.classList.add('marketing');
    if (typeof window !== 'undefined') {
      const href = window.location.href;
      setTargetUrl(href);
      setHasInvite(href.includes('invite='));
    }
    return () => {
      document.documentElement.classList.remove('marketing');
    };
  }, []);

  const qrSrc = `https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${encodeURIComponent(
    targetUrl,
  )}&bgcolor=FFFDFB&color=1C1B1A&margin=8`;

  return (
    <div className={s.page}>
      <div className={s.orbBackground} aria-hidden />

      <header className={s.nav}>
        <span className={s.brand}>Fordays</span>
        <span className={s.navTag}>iPhone & Android</span>
      </header>

      <main className={s.hero}>
        <div className={s.heroContent}>
          {hasInvite ? (
            <div className={s.inviteBanner}>
              <span>You’ve been invited to plan together</span>
            </div>
          ) : (
            <div className={s.pillBadge}>Designed exclusively for mobile</div>
          )}

          <h1 className={s.headline}>Plans for days.</h1>
          <p className={s.tagline}>Plans, Bucket lists and Memories</p>
          <p className={s.subheadline}>
            A quiet shared notebook for your plans, dreams, and memories. Not a
            busy calendar with corporate meetings — just an intimate space to
            plan with the people who matter most.
          </p>

          <div className={s.qrCard}>
            <div className={s.qrImage}>
              <img src={qrSrc} alt="Scan QR code with your iPhone to open Fordays" />
            </div>
            <div className={s.qrText}>
              <h3>Open on your phone</h3>
              <p>
                Point your iPhone camera at the code to open Fordays instantly in
                Mobile Safari. Tap <strong>Share → Add to Home Screen</strong> to install.
              </p>
            </div>
          </div>
        </div>

        <div className={s.mockupWrap} aria-hidden>
          <div className={s.mockup}>
            <div className={s.mockupIsland} />
            <div className={s.mockupHeader}>
              <div className={s.mockupPill}>
                <div className={s.mockupFaces}>
                  <span className={s.mockupFace}>J</span>
                  <span className={s.mockupFace}>S</span>
                </div>
                <span style={{ fontSize: 'var(--fs-tiny)', color: 'var(--ink-faint)' }}>⌵</span>
              </div>
              <span className={s.mockupTitle}>September</span>
              <span className={s.mockupControls}>Today</span>
            </div>
            <div className={s.mockupBody}>
              <span className={s.mockupDayHeader}>Today</span>
              <div className={s.mockupRow}>
                <span className={s.mockupTime}>11:00 am</span>
                <span className={s.mockupRowText}>
                  <strong>Farmers market</strong>
                  <span>St. Jacobs</span>
                </span>
              </div>
              <div className={s.mockupRow}>
                <span className={s.mockupTime}>7:30 pm</span>
                <span className={s.mockupRowText}>
                  <strong>Dinner at Alma</strong>
                </span>
              </div>
              <div className={s.mockupRow}>
                <span className={s.mockupTime}>All day</span>
                <span className={s.mockupRowText}>
                  <strong>Kayak the Grand River</strong>
                  <span>Cambridge</span>
                </span>
              </div>
            </div>
          </div>
        </div>
      </main>

      <section className={s.features}>
        <div className={s.featureCard}>
          <div className={s.featureIcon}>
            <span className={s.mockupFaces}>
              <span className={s.mockupFace}>J</span>
              <span className={s.mockupFace}>S</span>
            </span>
          </div>
          <h3>Just you, or your people</h3>
          <p>
            Keep your own, or share with a partner or a few friends. No feeds,
            no algorithms, no social noise.
          </p>
        </div>

        <div className={s.featureCard}>
          <div className={s.featureIcon}>
            <CalendarIcon on={false} />
          </div>
          <h3>Simpler than a calendar</h3>
          <p>
            No complex timezones, video links, or rigid recurring forms. Just a
            day, a time if you want one, and a place.
          </p>
        </div>

        <div className={s.featureCard}>
          <div className={s.featureIcon}>
            <BucketIcon on={false} />
          </div>
          <h3>Bucket lists, plans and memories</h3>
          <p>
            Keep what you want to do one day. When you’re ready, give it a day.
            Afterwards it becomes a memory, photos and all.
          </p>
        </div>
      </section>

      <footer className={s.footer}>
        <p>© 2026 Fordays · fordays.app</p>
      </footer>
    </div>
  );
}
