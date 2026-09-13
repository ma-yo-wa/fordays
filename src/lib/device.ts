/**
 * Phone / installed PWA may use the app.
 * All desktop and tablet browsers get the marketing landing page.
 */
export function isDesktopBrowser(): boolean {
  if (typeof window === 'undefined') return true;

  // Explicit dev escape-hatch for testing in desktop browser devtools:
  // e.g. https://fordays.app/?preview=mobile or ?app=1
  const params = new URLSearchParams(window.location.search);
  if (params.get('preview') === 'mobile' || params.get('app') === '1') {
    return false;
  }

  const nav = window.navigator as Navigator & { standalone?: boolean };
  // Standalone installed PWA on iOS
  if (nav.standalone === true) return false;

  const ua = navigator.userAgent || '';

  // iPad or desktop Mac/Windows/Linux:
  const isIPad =
    /iPad/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (isIPad) return true;

  // Real phones: iPhone, iPod, Android phone with Mobile in UA, Windows Phone
  const isPhone =
    /iPhone|iPod/i.test(ua) ||
    (/Android/i.test(ua) && /Mobile/i.test(ua)) ||
    /webOS|BlackBerry|IEMobile|Opera Mini/i.test(ua);

  if (isPhone) return false;

  // Everything else (macOS Safari/Chrome, Windows, Linux, CrOS) -> desktop browser marketing page
  return true;
}
