import s from './DesktopGate.module.css';

/** Desktop browsers never get the planner — phone (or installed PWA) only. */
export default function DesktopGate() {
  return (
    <div className={s.page}>
      <div className={s.orb} aria-hidden />
      <main className={s.main}>
        <p className={s.brand}>Fordays</p>
        <h1 className={s.tag}>Plans for days.</h1>
        <p className={s.lead}>
          Fordays lives on your phone — open this link on your iPhone, or get
          the app when it’s on the App Store.
        </p>
        <p className={s.hint}>This page won’t run the planner on a computer.</p>
      </main>
    </div>
  );
}
