import { loadConfig } from './config';
import { getClient } from './auth';

export type PushState =
  | 'unsupported'
  | 'ios-install'
  | 'default'
  | 'denied'
  | 'granted-idle'
  | 'on';

let reg: ServiceWorkerRegistration | null = null;
let sub: PushSubscription | null = null;

function urlB64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(base64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

export function pushSupported(): boolean {
  return (
    typeof window !== 'undefined' &&
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    'Notification' in window
  );
}

export function iosNeedsInstall(): boolean {
  const iOS = /iP(hone|ad|od)/.test(navigator.userAgent || '');
  const displayStandalone =
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(display-mode: standalone)').matches;
  const standalone =
    (window.navigator as Navigator & { standalone?: boolean }).standalone === true ||
    displayStandalone;
  return iOS && !standalone;
}

export async function registerPush(): Promise<ServiceWorkerRegistration | null> {
  if (!pushSupported()) return null;
  try {
    reg = await navigator.serviceWorker.ready;
    sub = await reg.pushManager.getSubscription();
    return reg;
  } catch {
    return null;
  }
}

export function pushState(): PushState {
  // iOS Safari (tab) advertises some APIs but push only works from the
  // Home Screen app — check that before “supported”.
  if (iosNeedsInstall()) return 'ios-install';
  if (!pushSupported()) return 'unsupported';
  if (Notification.permission === 'denied') return 'denied';
  if (Notification.permission === 'granted') return sub ? 'on' : 'granted-idle';
  return 'default';
}

/* A device belongs to whoever is signed in, and hears from every Orb
   they're in. The RPC moves the row over if this browser was last
   signed in as someone else, which RLS alone can't do. */
async function persist(j: PushSubscriptionJSON): Promise<void> {
  const sb = await getClient();
  if (!sb) return;
  const { data: sess } = await sb.auth.getSession();
  if (!sess.session?.user?.id || !j.endpoint) return;
  await sb.rpc('register_push_device', {
    device_endpoint: j.endpoint,
    device_platform: 'web',
    device_p256dh: j.keys?.p256dh ?? null,
    device_auth: j.keys?.auth ?? null,
    device_tz: Intl.DateTimeFormat().resolvedOptions().timeZone ?? null,
    device_agent: navigator.userAgent,
  });
}

async function forget(endpoint: string): Promise<void> {
  const sb = await getClient();
  if (!sb) return;
  await sb.from('push_subscriptions').delete().eq('endpoint', endpoint);
}

/** The worker got a fresh endpoint from the push service (they rotate
 *  without asking). Swap it in, or this device quietly goes deaf. */
export async function adoptRotatedSubscription(
  oldEndpoint: string | null,
  fresh: PushSubscriptionJSON,
): Promise<void> {
  try {
    if (oldEndpoint && oldEndpoint !== fresh.endpoint) await forget(oldEndpoint);
    await persist(fresh);
  } catch {
    /* */
  }
}

/** Signing out stops this browser hearing about that account's Orbs. The
 *  browser keeps its subscription; the next sign-in claims it. */
export async function forgetThisDevice(): Promise<void> {
  try {
    if (!pushSupported()) return;
    if (!reg) await registerPush();
    const current = sub ?? (reg ? await reg.pushManager.getSubscription() : null);
    if (current) await forget(current.endpoint);
  } catch {
    /* */
  }
}

export async function enablePush(): Promise<string> {
  if (iosNeedsInstall()) {
    return 'Add Fordays to your Home Screen, open it from there, then try again.';
  }
  if (!pushSupported()) return "This browser can't do web push";

  let perm = Notification.permission;
  if (perm === 'default') {
    perm = await Notification.requestPermission();
  }
  if (perm === 'denied') {
    return 'Blocked — iPhone Settings → Fordays → Notifications → Allow';
  }
  if (perm !== 'granted') {
    return 'Tap Allow on the notifications prompt, then try the switch again.';
  }

  if (!reg) await registerPush();
  if (!reg) return 'Service worker unavailable — close and reopen the app';

  const key = loadConfig().vapidPublicKey.trim();
  if (!key) {
    return 'Notifications allowed, but VITE_VAPID_PUBLIC_KEY isn’t set yet.';
  }

  try {
    sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlB64ToUint8Array(key) as BufferSource,
    });
    await persist(sub.toJSON());
    return 'Notifications on';
  } catch (err) {
    const detail = err instanceof Error ? err.message : '';
    return detail
      ? `Couldn’t subscribe — ${detail}`
      : 'Couldn’t subscribe — check the VAPID key';
  }
}

export async function disablePush(): Promise<string> {
  try {
    if (!reg) await registerPush();
    if (!sub && reg) sub = await reg.pushManager.getSubscription();
    if (sub) {
      const endpoint = sub.endpoint;
      await sub.unsubscribe();
      await forget(endpoint);
      sub = null;
    }
  } catch {
    /* */
  }
  return 'Notifications off';
}

export async function syncPush(): Promise<void> {
  if (iosNeedsInstall()) return;
  if (!pushSupported() || Notification.permission !== 'granted') return;
  if (!reg) await registerPush();
  if (!reg) return;
  const key = loadConfig().vapidPublicKey.trim();
  if (!key) return;
  try {
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlB64ToUint8Array(key) as BufferSource,
      });
    }
    await persist(sub.toJSON());
  } catch {
    /* */
  }
}
