/** Phone / installed PWA may use the app. Desktop browsers get the gate. */
export function isDesktopBrowser(): boolean {
  const nav = window.navigator as Navigator & { standalone?: boolean };
  if (nav.standalone === true) return false;
  if (
    window.matchMedia('(display-mode: standalone), (display-mode: fullscreen)')
      .matches
  ) {
    return false;
  }

  const ua = navigator.userAgent || '';
  if (/iPhone|iPod|iPad|Android|Mobile/i.test(ua)) return false;

  // Mouse + hover ≈ laptop/desktop browser.
  return window.matchMedia('(hover: hover) and (pointer: fine)').matches;
}
