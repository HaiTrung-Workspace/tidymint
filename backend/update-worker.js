// tidymint-update: returns the total number of Tidymint downloads: GitHub (all releases, live)
// plus downloads counted by other sites that host their own copy (plain-text variable
// EXTRA_DOWNLOADS, JSON like {"uptodown": 12}, updated by hand from each site's own stats).
// No logging, no cookies, no visitor data stored. Result cached ~10 minutes per data center.
//
// /version: the latest version number for the app's daily update check (copied from tidymint.app/version.txt).
// Each request adds one point to the Analytics Engine dataset bound as CHECKS: app name, app version and Darwin
// version, read from the User-Agent every macOS app request already carries ("Tidymint/0.3.8 CFNetwork/... Darwin/27.2.0").
// No IP address, no identifier, no other header is stored. Workers Logs and Logpush stay off for this Worker.
const REPO = "HaiTrung-Workspace/tidymint";
const TTL = 600;

function headers(origin) {
  const allowed = ["https://tidymint.app", "https://www.tidymint.app"];
  return {
    "Content-Type": "text/plain; charset=utf-8",
    "Cache-Control": "public, max-age=300",
    "Access-Control-Allow-Origin": allowed.includes(origin) ? origin : "https://tidymint.app",
    "Vary": "Origin",
  };
}

async function countDownloads(env) {
  const h = { "User-Agent": "tidymint-update", "Accept": "application/vnd.github+json" };
  if (env.GITHUB_TOKEN) h["Authorization"] = "Bearer " + env.GITHUB_TOKEN;
  let total = 0;
  for (let page = 1; page <= 5; page++) {
    const r = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100&page=${page}`, { headers: h });
    if (!r.ok) throw new Error("github " + r.status);
    const list = await r.json();
    for (const rel of list) for (const a of rel.assets || []) total += a.download_count || 0;
    if (list.length < 100) break;
  }
  return total;
}

function extraDownloads(env) {
  try {
    const o = JSON.parse(env.EXTRA_DOWNLOADS || "{}");
    return Object.values(o).reduce((sum, v) => sum + (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0), 0);
  } catch (e) {
    return 0;
  }
}

// "Tidymint/0.3.8 CFNetwork/3896.200.61 Darwin/27.2.0" -> ["Tidymint", "0.3.8", "27.2.0"]; anything else -> null.
function parseUA(ua) {
  const m = /^([A-Za-z0-9 %]{1,40})\/(\d+(?:\.\d+){0,3}) .*Darwin\/(\d+(?:\.\d+){0,2})/.exec(ua || "");
  return m ? [m[1], m[2], m[3]] : null;
}

async function latestVersion(ctx) {
  const cache = caches.default;
  const key = new Request("https://update.tidymint.app/version");
  const hit = await cache.match(key);
  if (hit) return await hit.text();
  const r = await fetch("https://tidymint.app/version.txt", { cf: { cacheTtl: TTL } });
  const v = (await r.text()).trim();
  if (!r.ok || !/^v?\d+(\.\d+){1,3}$/.test(v)) throw new Error("version " + r.status);
  ctx.waitUntil(cache.put(key, new Response(v, { headers: { "Cache-Control": "public, max-age=" + TTL } })));
  return v;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin") || "";
    if (url.pathname === "/version") {
      const p = parseUA(request.headers.get("User-Agent"));
      if (p && env.CHECKS) {
        try { env.CHECKS.writeDataPoint({ blobs: p, doubles: [1], indexes: [p[1]] }); } catch (e) {}
      }
      try {
        return new Response(await latestVersion(ctx), { headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });
      } catch (e) {
        return new Response("unavailable", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } });
      }
    }
    if (url.pathname !== "/downloads") return new Response("Not found", { status: 404 });
    const cache = caches.default;
    const key = new Request("https://update.tidymint.app/downloads");
    const hit = await cache.match(key);
    if (hit) return new Response(await hit.text(), { headers: headers(origin) });
    try {
      const body = String((await countDownloads(env)) + extraDownloads(env));
      ctx.waitUntil(cache.put(key, new Response(body, { headers: { "Cache-Control": "public, max-age=" + TTL } })));
      return new Response(body, { headers: headers(origin) });
    } catch (e) {
      return new Response(String(e && e.message || "error"), { status: 503, headers: headers(origin) });
    }
  },
};
