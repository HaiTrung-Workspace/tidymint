// tidymint-update: the small service behind update.tidymint.app.
//
// /downloads: total number of Tidymint downloads: GitHub (all releases, live) plus downloads counted by other
// sites that host their own copy (plain-text variable EXTRA_DOWNLOADS, JSON like {"uptodown": 12}). Cached ~10 minutes.
//
// /version: the latest version number for the app's daily update check (copied from tidymint.app/version.txt).
// Each request adds one point to the Analytics Engine dataset bound as CHECKS: app name, app version and Darwin
// version from the User-Agent, and the country Cloudflare reports for the connection. When the person has turned on
// "Share usage statistics" the app adds a few short fields (see checkFields) and a random install number.
// From the release that opens sales the IP address of a check and of a usage report is kept with its point (Chú,
// 22/11/2026), three months like every point here (blob12). Before that none was stored: the public pages that say
// "your IP address is not stored" must change BEFORE this version of the Worker is deployed.
// Workers Logs and Logpush stay off for this Worker.
//
// /update?from=<version>: the Download button in the app. Counts the click and sends the browser to the latest release.
// /usage (POST): one small summary a day from apps that share usage statistics: how many times each tool was used.
// /checks: public totals of the update checks for the last 24 hours and 7 days, by app version and macOS version.
// /stats/<name>: the daily report's tables (see STATS). Needs ?key= when the secret STATS_KEY is set.
// scheduled(): once an hour, notes the download count GitHub shows for each file of the newest releases.
// Reads go through the Analytics Engine SQL API with a read-only token kept as the secret ANALYTICS_TOKEN.
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

const SQL_ACCOUNT = "0049e7c1c829d724310a7fee8f129381";

async function sqlCounts(env, days) {
  const q = `SELECT blob2 AS version, blob3 AS darwin, SUM(_sample_interval) AS n FROM tidymint_checks ` +
            `WHERE timestamp > NOW() - INTERVAL '${days}' DAY AND blob1 = 'Tidymint' GROUP BY version, darwin ORDER BY n DESC LIMIT 200`;
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${SQL_ACCOUNT}/analytics_engine/sql`, {
    method: "POST", headers: { "Authorization": "Bearer " + env.ANALYTICS_TOKEN }, body: q,
  });
  if (!r.ok) throw new Error("sql " + r.status + " " + (await r.text()).replace(/[^\x20-\x7e]/g, " ").slice(0, 200));
  const data = (await r.json()).data || [];
  const out = { total: 0, by_version: {}, by_darwin: {} };
  for (const row of data) {
    const n = Number(row.n) || 0;
    out.total += n;
    out.by_version[row.version] = (out.by_version[row.version] || 0) + n;
    out.by_darwin[row.darwin] = (out.by_darwin[row.darwin] || 0) + n;
  }
  return out;
}

async function checks(env, ctx) {
  const cache = caches.default;
  const key = new Request("https://update.tidymint.app/checks");
  const hit = await cache.match(key);
  if (hit) return await hit.text();
  if (!env.ANALYTICS_TOKEN) throw new Error("no token");
  const body = JSON.stringify({ generated: new Date().toISOString(), last_24h: await sqlCounts(env, 1), last_7d: await sqlCounts(env, 7) });
  ctx.waitUntil(cache.put(key, new Response(body, { headers: { "Cache-Control": "public, max-age=" + TTL } })));
  return body;
}

async function sql(env, q) {
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${SQL_ACCOUNT}/analytics_engine/sql`, {
    method: "POST", headers: { "Authorization": "Bearer " + env.ANALYTICS_TOKEN }, body: q,
  });
  if (!r.ok) throw new Error("sql " + r.status + " " + (await r.text()).replace(/[^\x20-\x7e]/g, " ").slice(0, 200));
  return (await r.json()).data || [];
}

// What the daily report reads. Every table is a count per day (UTC) over the last 90 days (the dataset keeps 3 months).
// Data point layout, by blob1:
//   "Tidymint" (a check): blob2 version, blob3 Darwin, blob4 country, blob5 first check (1/0), blob6 days since
//     install (d0, d1, d7, d30, d90), blob7 window or background (w/b), blob8 language, blob9 tools switched on (Mintangle, Mintdrop, Mintbar, open at login, menu bar icon, then from the release that opens sales Mintclip and Downloads kept tidy), blob10 install number, blob11 kind of copy (0 free, 1 trial, 2 tools bought, 3 bundle bought), blob12 IP address
//   "click": blob2 version the Download button was pressed in, blob4 country
//   "usage": blob2 version, blob3 Darwin, blob4 country, blob10 install number, double1.. in the order of USAGE_KEYS
//   "gh": blob2 release tag, blob3 file name, double1 the download count GitHub showed
const DAY = "toStartOfInterval(timestamp, INTERVAL '1' DAY)";
const D90 = "timestamp > NOW() - INTERVAL '90' DAY";
const USAGE_KEYS = ["opens", "cleans", "cleaned_mb", "uninstalls", "angle", "drop", "bar", "days", "clip", "sort"];   // new keys go at the end
const STATS = {
  "checks-daily": `SELECT ${DAY} AS day, blob2 AS version, blob3 AS darwin, SUM(_sample_interval) AS n FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' GROUP BY day, version, darwin ORDER BY day`,
  "checks-country": `SELECT ${DAY} AS day, blob4 AS country, SUM(_sample_interval) AS n FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' GROUP BY day, country ORDER BY day`,
  "checks-hour": `SELECT toHour(timestamp) AS hour_utc, SUM(_sample_interval) AS n FROM tidymint_checks WHERE timestamp > NOW() - INTERVAL '30' DAY AND blob1 = 'Tidymint' GROUP BY hour_utc ORDER BY hour_utc`,
  "cohort": `SELECT ${DAY} AS day, blob2 AS version, blob5 AS first, blob6 AS age, blob7 AS source, blob8 AS lang, SUM(_sample_interval) AS n FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' AND blob6 != '' GROUP BY day, version, first, age, source, lang ORDER BY day`,
  "tools": `SELECT ${DAY} AS day, blob9 AS tools, SUM(_sample_interval) AS n FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' AND blob9 != '' GROUP BY day, tools ORDER BY day`,
  "machines-day": `SELECT ${DAY} AS day, count(DISTINCT blob10) AS machines FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' AND blob10 != '' GROUP BY day ORDER BY day`,
  "machines-week": `SELECT toStartOfWeek(timestamp) AS week, count(DISTINCT blob10) AS machines FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' AND blob10 != '' GROUP BY week ORDER BY week`,
  "machines-month": `SELECT toStartOfMonth(timestamp) AS month, count(DISTINCT blob10) AS machines FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' AND blob10 != '' GROUP BY month ORDER BY month`,
  // Copies in use by kind (from the release that opens sales): blob11 "0" free, "1" in the trial, "2" one or more tools
  // bought, "3" the bundle bought; "" a release before it. One copy is one install number, so this counts Macs, not checks.
  "plans-week": `SELECT toStartOfWeek(timestamp) AS week, blob11 AS plan, count(DISTINCT blob10) AS machines FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' AND blob10 != '' GROUP BY week, plan ORDER BY week`,
  // The same count by day and version, for the morning report (23/11/2026): how many copies of each release are
  // free, in the trial or paid. A copy shows the kind it had at its check of that day.
  "plans-day": `SELECT ${DAY} AS day, blob2 AS version, blob11 AS plan, count(DISTINCT blob10) AS machines FROM tidymint_checks WHERE ${D90} AND blob1 = 'Tidymint' AND blob10 != '' GROUP BY day, version, plan ORDER BY day`,
  // The licence Worker's own dataset (tidymint_license; layout in backend/license/license-worker.js, count()). Totals
  // only: no key id, no machine hash and no address leaves in these tables.
  //   trials-day: trial requests by outcome ("started": a Mac began its trial that day; "had": it asked again).
  //   keys-day: key requests by action and outcome ("confirm"/"added": a Mac was added to a key).
  //   keys-added-day: Macs added to a key, by product and whole days since that Mac's trial began ("none": never tried).
  "trials-day": `SELECT ${DAY} AS day, blob2 AS action, blob3 AS outcome, SUM(_sample_interval) AS n, count(DISTINCT blob6) AS machines FROM tidymint_license WHERE ${D90} AND blob1 = 'license' AND (blob2 = 'trial/start' OR blob2 = 'trial/status') GROUP BY day, action, outcome ORDER BY day`,
  "keys-day": `SELECT ${DAY} AS day, blob2 AS action, blob3 AS outcome, SUM(_sample_interval) AS n, count(DISTINCT blob5) AS keys, count(DISTINCT blob6) AS machines FROM tidymint_license WHERE ${D90} AND blob1 = 'license' AND blob2 != 'trial/start' AND blob2 != 'trial/status' GROUP BY day, action, outcome ORDER BY day`,
  "keys-added-day": `SELECT ${DAY} AS day, blob3 AS product, blob4 AS days_since_trial, SUM(_sample_interval) AS n FROM tidymint_license WHERE ${D90} AND blob1 = 'funnel' AND blob2 = 'trial_to_key' GROUP BY day, product, days_since_trial ORDER BY day`,
  "clicks": `SELECT ${DAY} AS day, blob2 AS version, SUM(_sample_interval) AS n FROM tidymint_checks WHERE ${D90} AND blob1 = 'click' GROUP BY day, version ORDER BY day`,
  "usage": `SELECT ${DAY} AS day, blob2 AS version, SUM(_sample_interval) AS reports, ` +
           USAGE_KEYS.map((k, i) => `SUM(double${i + 1}) AS ${k}`).join(", ") +
           ` FROM tidymint_checks WHERE ${D90} AND blob1 = 'usage' GROUP BY day, version ORDER BY day`,
  "gh": `SELECT toStartOfInterval(timestamp, INTERVAL '1' HOUR) AS hour, blob2 AS tag, blob3 AS file, max(double1) AS downloads FROM tidymint_checks WHERE timestamp > NOW() - INTERVAL '30' DAY AND blob1 = 'gh' GROUP BY hour, tag, file ORDER BY hour`,
};

async function stat(env, ctx, name) {
  const cache = caches.default;
  const key = new Request("https://update.tidymint.app/stats/" + name);
  const hit = await cache.match(key);
  if (hit) return await hit.text();
  if (!env.ANALYTICS_TOKEN) throw new Error("no token");
  const body = JSON.stringify({ generated: new Date().toISOString(), name, rows: await sql(env, STATS[name] + " LIMIT 10000") });
  ctx.waitUntil(cache.put(key, new Response(body, { headers: { "Cache-Control": "public, max-age=1800" } })));
  return body;
}

// The few extra fields of a check from an app that shares usage statistics. Each has one fixed shape; anything else is dropped.
function checkFields(q) {
  const pick = (k, re) => { const v = q.get(k) || ""; return re.test(v) ? v : ""; };
  return [pick("f", /^[01]$/), pick("a", /^d(0|1|7|30|90)$/), pick("s", /^[wb]$/), pick("l", /^[a-z]{2}$/),
          pick("t", /^[01]{1,12}$/), pick("i", /^[0-9a-f]{32}$/), pick("p", /^[0-3]$/)];
}

async function usage(request, env) {
  const p = parseUA(request.headers.get("User-Agent"));
  if (!p || !env.CHECKS) return;
  const text = await request.text();
  if (text.length > 2000) return;
  const j = JSON.parse(text);
  const id = /^[0-9a-f]{32}$/.test(String(j.i || "")) ? String(j.i) : "";
  const nums = USAGE_KEYS.map(k => { const n = Number(j.d && j.d[k]); return Number.isFinite(n) ? Math.min(Math.max(0, Math.floor(n)), 1e7) : 0; });
  env.CHECKS.writeDataPoint({ blobs: ["usage", p[1], p[2], country(request), "", "", "", "", "", id, "", ipOf(request)], doubles: nums, indexes: [id || p[1]] });
}

// The address a request came from. Cloudflare's header reference (read 22/11/2026) gives CF-Connecting-IP as the
// client address and CF-Connecting-IPv6 as the real IPv6 one under Pseudo IPv4; it does not say outright that a Worker
// receives them, so this is empty when neither is there. TO CHECK on the deployed Worker.
function ipOf(request) {
  const ip = String(request.headers.get("CF-Connecting-IPv6") || request.headers.get("CF-Connecting-IP") || "").slice(0, 45);
  return /^[0-9a-fA-F:.]{3,45}$/.test(ip) ? ip : "";
}

function country(request) { const c = request.cf && request.cf.country; return /^[A-Z0-9]{2}$/.test(String(c || "")) ? String(c) : ""; }

// Hourly: the download count of each file of the six newest releases, plus the total of all of them.
// Each point has its own index: with one shared index only some of the points of a run could be read back (19/11/2026).
async function snapshot(env) {
  if (!env.CHECKS) return;
  const h = { "User-Agent": "tidymint-update", "Accept": "application/vnd.github+json" };
  if (env.GITHUB_TOKEN) h["Authorization"] = "Bearer " + env.GITHUB_TOKEN;
  const r = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100`, { headers: h });
  if (!r.ok) throw new Error("github " + r.status);
  const list = await r.json();
  let total = 0;
  list.forEach((rel, i) => {
    for (const a of rel.assets || []) {
      total += a.download_count || 0;
      if (i < 6) env.CHECKS.writeDataPoint({ blobs: ["gh", String(rel.tag_name).slice(0, 40), String(a.name).slice(0, 80)], doubles: [a.download_count || 0], indexes: [("gh/" + rel.tag_name + "/" + a.name).slice(0, 90)] });
    }
  });
  env.CHECKS.writeDataPoint({ blobs: ["gh", "all", "all"], doubles: [total], indexes: ["gh/all"] });
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
        const x = checkFields(url.searchParams);
        try { env.CHECKS.writeDataPoint({ blobs: [p[0], p[1], p[2], country(request), ...x, ipOf(request)], doubles: [1], indexes: [x[5] || p[1]] }); } catch (e) {}
      }
      try {
        return new Response(await latestVersion(ctx), { headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });
      } catch (e) {
        return new Response("unavailable", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } });
      }
    }
    if (url.pathname === "/update") {
      const from = url.searchParams.get("from") || "";
      if (env.CHECKS && /^\d+(\.\d+){1,3}$/.test(from)) {
        try { env.CHECKS.writeDataPoint({ blobs: ["click", from, "", country(request)], doubles: [1], indexes: ["click"] }); } catch (e) {}
      }
      return new Response(null, { status: 302, headers: { "Location": `https://github.com/${REPO}/releases/latest`, "Cache-Control": "no-store" } });
    }
    if (url.pathname === "/usage" && request.method === "POST") {
      try { await usage(request, env); } catch (e) {}
      return new Response("ok", { headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });
    }
    if (url.pathname.startsWith("/stats/")) {
      const name = url.pathname.slice(7);
      const jh = { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" };
      if (!STATS[name]) return new Response("Not found", { status: 404 });
      if (env.STATS_KEY && url.searchParams.get("key") !== env.STATS_KEY) return new Response("Not found", { status: 404 });
      try { return new Response(await stat(env, ctx, name), { headers: jh }); }
      catch (e) { return new Response(JSON.stringify({ error: String(e && e.message || "error") }), { status: 503, headers: jh }); }
    }
    if (url.pathname === "/checks") {
      const jh = { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "public, max-age=300" };
      try { return new Response(await checks(env, ctx), { headers: jh }); }
      catch (e) { return new Response(JSON.stringify({ error: String(e && e.message || "error") }), { status: 503, headers: jh }); }
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
  async scheduled(event, env, ctx) {
    ctx.waitUntil(snapshot(env).catch(() => {}));
  },
};
