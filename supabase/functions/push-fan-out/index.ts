/* =====================================================================
   Fordays — push-fan-out
   Supabase Edge Function (Deno).

   Zero dependencies. VAPID signing (RFC 8292) and payload encryption
   (RFC 8291 / aes128gcm per RFC 8188) are done directly against Web
   Crypto — no notification SDK, no vendor sitting between our database
   and the user's push service. iOS goes straight to APNs with a token
   signed by our own .p8 key, same idea.

   Invoked by private.enqueue_push_event (migration 020) with:
     { recipient_id, space_id, activity_id?, kind, facts }
   facts = { actor, title?, note?, at?, all_day?, orb?, orb_name? }

   The words are written here, per device, so a time reads in that
   device's time zone. Older callers that still send { title, body }
   are passed through as they are.

   kind is one of: idea | scheduled | rescheduled | notes | joined |
                   suggested | suggestion_accepted

   Secrets required (supabase secrets set ...):
     VAPID_PUBLIC_KEY    base64url, uncompressed P-256 point (65 bytes)
     VAPID_PRIVATE_KEY   base64url, raw d scalar (32 bytes)
     VAPID_SUBJECT       mailto:you@example.com  (or an https:// URL)
     APNS_KEY_ID         10 characters, from the Apple Developer key
     APNS_TEAM_ID        10 characters
     APNS_BUNDLE_ID      app.fordays.ios
     APNS_PRIVATE_KEY    the .p8 file's contents (PEM)
     SUPABASE_URL                (injected automatically)
     SUPABASE_SERVICE_ROLE_KEY   (injected automatically)
   ===================================================================== */

const VAPID_PUBLIC  = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY")!;
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") ?? "mailto:hello@example.com";
const SB_URL        = Deno.env.get("SUPABASE_URL")!;
const SB_KEY        = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID   = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID  = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_TOPIC    = Deno.env.get("APNS_BUNDLE_ID") ?? "app.fordays.ios";
const APNS_PEM      = Deno.env.get("APNS_PRIVATE_KEY") ?? "";

/* The trigger's bearer has to satisfy two checks with one value: the
   platform gateway, which only accepts a JWT, and the caller check below.
   On projects issuing sb_secret_… keys those two can't be the same string,
   so the trigger's key is configured separately. */
const CALLER_KEYS = new Set(
  [SB_KEY, Deno.env.get("PUSH_HOOK_KEY")].filter(Boolean) as string[],
);

/* ------------------------------------------------------------------ */
/* base64url helpers                                                   */
/* ------------------------------------------------------------------ */
function b64uToBytes(s: string): Uint8Array {
  const pad = s.length % 4 ? "=".repeat(4 - (s.length % 4)) : "";
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function bytesToB64u(b: Uint8Array): string {
  let s = "";
  for (const byte of b) s += String.fromCharCode(byte);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function concat(...parts: Uint8Array[]): Uint8Array {
  const len = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(len);
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}
const utf8 = (s: string) => new TextEncoder().encode(s);

/* ------------------------------------------------------------------ */
/* VAPID — an ES256 JWT proving we own the key the client subscribed to */
/* ------------------------------------------------------------------ */
async function importVapidKey(): Promise<CryptoKey> {
  // Web Crypto wants a JWK. The private key is the raw d scalar; x and y
  // come out of the uncompressed public point (0x04 || x[32] || y[32]).
  const pub = b64uToBytes(VAPID_PUBLIC);
  if (pub.length !== 65 || pub[0] !== 0x04) {
    throw new Error("VAPID_PUBLIC_KEY must be a 65-byte uncompressed P-256 point");
  }
  const jwk: JsonWebKey = {
    kty: "EC",
    crv: "P-256",
    x: bytesToB64u(pub.slice(1, 33)),
    y: bytesToB64u(pub.slice(33, 65)),
    d: VAPID_PRIVATE,
    ext: true,
  };
  return crypto.subtle.importKey(
    "jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
}

async function vapidHeader(endpoint: string): Promise<string> {
  const aud = new URL(endpoint).origin;
  const header  = { typ: "JWT", alg: "ES256" };
  const payload = {
    aud,
    exp: Math.floor(Date.now() / 1000) + 12 * 60 * 60, // spec caps this at 24h
    sub: VAPID_SUBJECT,
  };
  const signingInput =
    bytesToB64u(utf8(JSON.stringify(header))) + "." +
    bytesToB64u(utf8(JSON.stringify(payload)));

  const key = await importVapidKey();
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" }, key, utf8(signingInput),
    ),
  );
  // Web Crypto already returns the raw r||s form that JWS wants.
  const jwt = `${signingInput}.${bytesToB64u(sig)}`;
  return `vapid t=${jwt}, k=${VAPID_PUBLIC}`;
}

/* ------------------------------------------------------------------ */
/* RFC 8291 payload encryption (aes128gcm)                             */
/* ------------------------------------------------------------------ */
async function hkdf(
  salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, length: number,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "HKDF", hash: "SHA-256", salt, info }, key, length * 8,
  );
  return new Uint8Array(bits);
}

async function encryptPayload(
  plaintext: string, uaPublicB64: string, authSecretB64: string,
): Promise<Uint8Array> {
  const uaPublic   = b64uToBytes(uaPublicB64);    // 65 bytes
  const authSecret = b64uToBytes(authSecretB64);  // 16 bytes

  // Ephemeral application-server keypair, fresh for every message.
  const asKeys = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"],
  ) as CryptoKeyPair;
  const asPublic = new Uint8Array(await crypto.subtle.exportKey("raw", asKeys.publicKey));

  const uaKey = await crypto.subtle.importKey(
    "raw", uaPublic, { name: "ECDH", namedCurve: "P-256" }, false, [],
  );
  const ecdhSecret = new Uint8Array(
    await crypto.subtle.deriveBits({ name: "ECDH", public: uaKey }, asKeys.privateKey, 256),
  );

  // PRK = HKDF(salt=auth_secret, ikm=ecdh, info="WebPush: info\0"|ua_pub|as_pub)
  const prkInfo = concat(utf8("WebPush: info\0"), uaPublic, asPublic);
  const prk = await hkdf(authSecret, ecdhSecret, prkInfo, 32);

  const salt  = crypto.getRandomValues(new Uint8Array(16));
  const cek   = await hkdf(salt, prk, utf8("Content-Encoding: aes128gcm\0"), 16);
  const nonce = await hkdf(salt, prk, utf8("Content-Encoding: nonce\0"), 12);

  // Single record: plaintext followed by the 0x02 last-record delimiter.
  const padded = concat(utf8(plaintext), new Uint8Array([0x02]));
  const aesKey = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce, tagLength: 128 }, aesKey, padded),
  );

  // aes128gcm header: salt(16) | rs(4, big-endian) | idlen(1) | keyid(65)
  const rs = new Uint8Array(4);
  new DataView(rs.buffer).setUint32(0, 4096, false);
  return concat(salt, rs, new Uint8Array([asPublic.length]), asPublic, ct);
}

/* ------------------------------------------------------------------ */
/* Words                                                               */
/* ------------------------------------------------------------------ */
type Facts = {
  actor?: string;
  title?: string | null;
  note?: string | null;
  at?: string | null;
  all_day?: boolean;
  orb?: string | null;       // set only when they're in more than one shared Orb
  orb_name?: string | null;  // "joined" always names the Orb if it has a name
};

type Words = { title: string; body: string };

const WEEKDAY = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTH = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** Calendar parts of an instant as seen in a time zone. */
function partsIn(d: Date, tz: string): { y: number; m: number; day: number; wd: number; h: number; min: number } {
  const f = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, year: "numeric", month: "numeric", day: "numeric",
    weekday: "short", hour: "numeric", minute: "numeric", hourCycle: "h23",
  });
  const p: Record<string, string> = {};
  for (const x of f.formatToParts(d)) p[x.type] = x.value;
  return {
    y: +p.year, m: +p.month, day: +p.day,
    wd: WEEKDAY.indexOf(p.weekday), h: +p.hour % 24, min: +p.minute,
  };
}

/** "today at 6:30 pm", "tomorrow", "Sat, Oct 3 at 6:30 pm". Lowercase
 *  times, as everywhere else in the app. All-day plans are stored at
 *  noon UTC, so their date is read in UTC; timed plans in the device's
 *  own zone. No zone known yet → the day only, never a UTC clock time. */
function when(iso: string | null | undefined, allDay: boolean, tz: string | null): string {
  if (!iso) return "";
  const at = new Date(iso);
  if (isNaN(at.getTime())) return "";
  const zone = allDay || !tz ? "UTC" : tz;
  const a = partsIn(at, zone);
  const today = partsIn(new Date(), tz ?? "UTC");

  const dayNo = (x: { y: number; m: number; day: number }) => Date.UTC(x.y, x.m - 1, x.day) / 86400000;
  const diff = dayNo(a) - dayNo(today);
  const day = diff === 0 ? "today"
    : diff === 1 ? "tomorrow"
    : `${WEEKDAY[a.wd]}, ${MONTH[a.m - 1]} ${a.day}`;

  if (allDay || !tz) return day;
  const h12 = a.h % 12 === 0 ? 12 : a.h % 12;
  const mm = String(a.min).padStart(2, "0");
  return `${day} at ${h12}:${mm} ${a.h >= 12 ? "pm" : "am"}`;
}

function clip(s: string, n: number): string {
  const t = s.replace(/\s+/g, " ").trim();
  return t.length > n ? t.slice(0, n - 1).trimEnd() + "…" : t;
}

/** Plan name first so the banner says what it's about; the Orb's name
 *  follows only for people juggling more than one shared Orb. */
function words(kind: string, f: Facts, tz: string | null): Words {
  const who = f.actor || "Someone";
  const plan = clip(f.title || "A plan", 60);
  const titled = f.orb ? `${plan} · ${f.orb}` : plan;
  const note = f.note ? clip(f.note, 120) : "";
  const at = when(f.at, Boolean(f.all_day), tz);
  const withNote = (line: string) => (note ? `${line}\n${note}` : line);

  switch (kind) {
    case "idea":
      return { title: titled, body: withNote(`${who} added this to Someday`) };
    case "scheduled":
      return { title: titled, body: at ? `${who} made this a plan for ${at}` : `${who} made this a plan` };
    case "rescheduled":
      return { title: titled, body: at ? `${who} moved this to ${at}` : `${who} changed the day` };
    case "suggested":
      return { title: titled, body: withNote(at ? `${who} suggested ${at}` : `${who} suggested a new day`) };
    case "suggestion_accepted":
      return { title: titled, body: at ? `${who} said yes to ${at}` : `${who} said yes to your day` };
    case "notes":
      return { title: titled, body: withNote(`${who} updated the note`) };
    case "joined":
      return {
        title: f.orb_name ? `${who} joined ${f.orb_name}` : `${who} joined your Orb`,
        body: "You can plan together now",
      };
    default:
      return { title: titled, body: "" };
  }
}

/* ------------------------------------------------------------------ */
/* One web device                                                      */
/* ------------------------------------------------------------------ */
type Sub = {
  endpoint: string;
  platform: "web" | "ios";
  p256dh: string | null;
  auth: string | null;
  apns_env: string | null;
  time_zone: string | null;
};

type Message = Words & {
  tag: string;
  kind: string;
  activityId: string | null;
  spaceId: string;
  url: string;
};

async function sendWeb(sub: Sub, msg: Message): Promise<"ok" | "gone" | "failed"> {
  if (!sub.p256dh || !sub.auth) return "gone";
  const body = await encryptPayload(JSON.stringify(msg), sub.p256dh, sub.auth);
  const auth = await vapidHeader(sub.endpoint);

  const res = await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      "Authorization": auth,
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      "TTL": "86400",
      "Urgency": "normal",
    },
    body,
  });

  if (res.status === 404 || res.status === 410) return "gone"; // unsubscribed / expired
  if (!res.ok) {
    console.error("push failed", res.status, await res.text().catch(() => ""));
    return "failed";
  }
  return "ok";
}

/* ------------------------------------------------------------------ */
/* One iOS device — APNs over HTTP/2 with a provider token             */
/* ------------------------------------------------------------------ */
let apnsKey: CryptoKey | null = null;
let apnsJwt: { token: string; at: number } | null = null;

async function apnsToken(): Promise<string> {
  // Apple wants the same token reused for 20–60 minutes; minting one per
  // request gets TooManyProviderTokenUpdates.
  const now = Math.floor(Date.now() / 1000);
  if (apnsJwt && now - apnsJwt.at < 40 * 60) return apnsJwt.token;

  if (!apnsKey) {
    const b64 = APNS_PEM
      .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
      .replace(/\s+/g, "");
    const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    apnsKey = await crypto.subtle.importKey(
      "pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
    );
  }

  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const claims = { iss: APNS_TEAM_ID, iat: now };
  const input =
    bytesToB64u(utf8(JSON.stringify(header))) + "." +
    bytesToB64u(utf8(JSON.stringify(claims)));
  const sig = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, apnsKey, utf8(input)),
  );
  apnsJwt = { token: `${input}.${bytesToB64u(sig)}`, at: now };
  return apnsJwt.token;
}

async function sendIos(sub: Sub, msg: Message): Promise<"ok" | "gone" | "failed"> {
  if (!APNS_PEM || !APNS_KEY_ID || !APNS_TEAM_ID) {
    console.error("APNs secrets missing");
    return "failed";
  }
  const token = sub.endpoint.replace(/^apns:/, "");
  const host = sub.apns_env === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

  const payload = {
    aps: {
      alert: { title: msg.title, body: msg.body },
      sound: "default",
      "thread-id": msg.spaceId,
    },
    kind: msg.kind,
    activityId: msg.activityId,
    spaceId: msg.spaceId,
    url: msg.url,
  };

  const res = await fetch(`${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${await apnsToken()}`,
      "apns-topic": APNS_TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(Math.floor(Date.now() / 1000) + 86400),
      // Same collapse as the web tag: a second update about one plan
      // replaces the first banner.
      "apns-collapse-id": msg.tag.slice(0, 64),
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (res.ok) return "ok";
  const text = await res.text().catch(() => "");
  let reason = "";
  try { reason = JSON.parse(text).reason ?? ""; } catch { /* */ }
  if (res.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered") {
    return "gone";
  }
  console.error("apns failed", res.status, reason || text);
  return "failed";
}

/* ------------------------------------------------------------------ */
/* PostgREST helpers (service role — bypasses RLS by design)           */
/* ------------------------------------------------------------------ */
const sbHeaders = {
  "apikey": SB_KEY,
  "Authorization": `Bearer ${SB_KEY}`,
  "Content-Type": "application/json",
};

/** Every device the person has. A device hears from all their Orbs. */
async function loadSubs(userId: string): Promise<Sub[]> {
  const url = `${SB_URL}/rest/v1/push_subscriptions` +
    `?select=endpoint,platform,p256dh,auth,apns_env,time_zone&user_id=eq.${userId}`;
  const r = await fetch(url, { headers: sbHeaders });
  if (!r.ok) { console.error("loadSubs", await r.text()); return []; }
  return await r.json();
}

async function pruneSub(endpoint: string): Promise<void> {
  await fetch(`${SB_URL}/rest/v1/rpc/prune_subscription`, {
    method: "POST",
    headers: sbHeaders,
    body: JSON.stringify({ dead_endpoint: endpoint }),
  });
}

/* ------------------------------------------------------------------ */
/* Entrypoint                                                          */
/* ------------------------------------------------------------------ */
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Only the database trigger may invoke this — the anon key is public.
  const bearer = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!CALLER_KEYS.has(bearer)) {
    return new Response("Forbidden", { status: 403 });
  }

  let job: {
    recipient_id: string;
    space_id: string;
    activity_id?: string | null;
    kind: string;
    facts?: Facts;
    title?: string;
    body?: string;
  };
  try {
    job = await req.json();
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  if (!job.recipient_id || !job.space_id || (!job.facts && !job.title)) {
    return new Response("Missing fields", { status: 400 });
  }

  const subs = await loadSubs(job.recipient_id);
  if (!subs.length) {
    return Response.json({ sent: 0, reason: "no registered devices" });
  }

  const activityId = job.activity_id ?? null;
  const spaceId = job.space_id;
  const base = {
    // Collapse repeats: one activity, or one "joined" per space.
    tag: activityId ? `activity-${activityId}` : `space-${job.kind}-${spaceId}`,
    kind: job.kind,
    activityId,
    spaceId,
    url: activityId
      ? `/?a=${encodeURIComponent(activityId)}&s=${encodeURIComponent(spaceId)}`
      : `/?s=${encodeURIComponent(spaceId)}`,
  };

  const results = await Promise.all(subs.map(async (s) => {
    try {
      const w = job.facts
        ? words(job.kind, job.facts, s.time_zone)
        : { title: job.title ?? "Fordays", body: job.body ?? "" };
      const msg: Message = { ...base, ...w };
      const outcome = s.platform === "ios" ? await sendIos(s, msg) : await sendWeb(s, msg);
      if (outcome === "gone") await pruneSub(s.endpoint);
      return outcome;
    } catch (err) {
      console.error("send error", err);
      return "failed" as const;
    }
  }));

  return Response.json({
    sent:   results.filter((r) => r === "ok").length,
    pruned: results.filter((r) => r === "gone").length,
    failed: results.filter((r) => r === "failed").length,
  });
});
