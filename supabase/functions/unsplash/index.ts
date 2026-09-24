/* =====================================================================
   Fordays — unsplash
   Supabase Edge Function (Deno).

   The Unsplash twin of `giphy`: a thin proxy so the access key lives in
   `supabase secrets` and never ships inside an app. The iOS cover
   picker calls this; the PWA can too.

   Routes (the action is a query param, so one function covers all):
     GET /functions/v1/unsplash?action=list&limit=15
     GET /functions/v1/unsplash?action=search&q=kayak&limit=15
     GET /functions/v1/unsplash?action=track&url=<links.download_location>

   `track` is the download ping Unsplash's API guidelines ask for when
   someone actually picks a photo.

   Secret required:
     supabase secrets set UNSPLASH_ACCESS_KEY="..."
   ===================================================================== */

const ACCESS    = Deno.env.get("UNSPLASH_ACCESS_KEY") ?? "";
const MAX_LIMIT = 25;

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json", ...extra },
  });
}

/* Same shape the PWA's `StillItem` uses, trimmed to what the picker
   renders. */
function slim(items: any[]) {
  return (items ?? []).map((p) => ({
    id: p.id,
    title: p.alt_description || p.description || "",
    preview: p.urls?.small ?? "",
    full: p.urls?.regular ?? p.urls?.small ?? "",
    download: p.links?.download_location ?? "",
    credit: p.user?.name ?? "Unsplash",
  })).filter((p) => p.preview && p.full);
}

const auth = () => ({ Authorization: `Client-ID ${ACCESS}`, "Accept-Version": "v1" });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "GET")     return json({ error: "Method not allowed" }, 405);

  if (!ACCESS) {
    return json({ error: "not_configured", message: "UNSPLASH_ACCESS_KEY is not set" }, 501);
  }

  const url    = new URL(req.url);
  const action = url.searchParams.get("action") ?? "list";

  if (action === "track") {
    // Only ever forward to Unsplash's own download endpoint.
    const target = url.searchParams.get("url") ?? "";
    let ping: URL;
    try {
      ping = new URL(target);
    } catch {
      return json({ error: "bad_url" }, 400);
    }
    if (ping.protocol !== "https:" || ping.hostname !== "api.unsplash.com") {
      return json({ error: "bad_url" }, 400);
    }
    try {
      await fetch(ping, { headers: auth(), signal: AbortSignal.timeout(6000) });
    } catch (err) {
      console.error("unsplash track failed", err);
    }
    return json({ ok: true });
  }

  const q     = (url.searchParams.get("q") ?? "").trim();
  const limit = Math.min(Number(url.searchParams.get("limit") ?? 15) || 15, MAX_LIMIT);

  // An empty search is a list request wearing the wrong hat.
  const wantsSearch = action === "search" && q.length > 0;

  const upstream = new URL(
    wantsSearch
      ? "https://api.unsplash.com/search/photos"
      : "https://api.unsplash.com/photos",
  );
  upstream.searchParams.set("per_page", String(limit));
  if (wantsSearch) upstream.searchParams.set("query", q);

  try {
    const res = await fetch(upstream, { headers: auth(), signal: AbortSignal.timeout(6000) });

    // Unsplash answers an exhausted hourly quota with 403 + Remaining: 0.
    if (res.status === 429 || (res.status === 403 && res.headers.get("X-Ratelimit-Remaining") === "0")) {
      return json({ error: "rate_limited", message: "Unsplash rate limit reached" }, 429, {
        "Retry-After": "60",
      });
    }
    if (res.status === 401) {
      return json({ error: "not_configured", message: "Unsplash rejected the key" }, 501);
    }
    if (!res.ok) {
      console.error("unsplash upstream", res.status, await res.text().catch(() => ""));
      return json({ error: "upstream", status: res.status }, 502);
    }

    const body = await res.json();
    const rows = Array.isArray(body) ? body : (body.results ?? []);
    return json(
      { source: wantsSearch ? "search" : "list", items: slim(rows) },
      200,
      { "Cache-Control": wantsSearch ? "public, max-age=300" : "public, max-age=900" },
    );
  } catch (err) {
    const timedOut = err instanceof DOMException && err.name === "TimeoutError";
    console.error("unsplash fetch failed", err);
    return json(
      { error: timedOut ? "timeout" : "network", message: "Couldn't reach Unsplash" },
      504,
    );
  }
});
