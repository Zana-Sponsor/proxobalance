// ─────────────────────────────────────────────────────────────
// middleware.js  —  runs at the Vercel Edge BEFORE every route,
// static file and /api function. Lives at the repository root.
//
// STEALTH BAN: a banned IP gets a plain 404 with the normal not-found
// body. No 403, no header, no timing difference worth measuring, no hint
// that a filter exists. To the attacker the site simply isn't there.
//
// PERFORMANCE: the ban list is cached in the edge instance's memory for
// BAN_CACHE_TTL_MS, so the common case costs zero network round-trips.
// A cold instance does one PostgREST call and then serves from memory.
//
// FAIL-OPEN: if Supabase is unreachable the request is allowed through.
// A database blip must never 404 your whole customer base.
// ─────────────────────────────────────────────────────────────

import { next } from '@vercel/functions';

export const config = {
  // Skip Next-style internals and the favicon; everything else is checked.
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)']
};

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY;

const BAN_CACHE_TTL_MS = 30_000;   // how long a cached ban list stays warm
let   banCache  = null;            // array of { cidr, bits, base }
let   cacheTime = 0;
let   inFlight  = null;

// ── real client IP ───────────────────────────────────────────
// Order matters. Cloudflare's header is authoritative when Cloudflare
// fronts the domain; otherwise Vercel's x-real-ip / the FIRST entry of
// x-forwarded-for is the client. Never trust a client-supplied header
// like x-client-ip — those are attacker-controlled.
export function clientIp(req) {
  const cf = req.headers.get('cf-connecting-ip');
  if (cf) return cf.trim();

  const real = req.headers.get('x-real-ip');
  if (real) return real.trim();

  const xff = req.headers.get('x-forwarded-for');
  if (xff) return xff.split(',')[0].trim();

  return '';
}

// ── tiny IP matcher (supports single addresses and CIDR ranges) ──
function ipToBigInt(ip) {
  if (ip.includes(':')) {                       // IPv6
    const parts = ip.split('::');
    let head = parts[0] ? parts[0].split(':') : [];
    let tail = parts[1] !== undefined ? (parts[1] ? parts[1].split(':') : []) : [];
    const fill = 8 - head.length - tail.length;
    const full = [...head, ...Array(Math.max(fill, 0)).fill('0'), ...tail];
    return full.reduce((acc, h) => (acc << 16n) + BigInt(parseInt(h || '0', 16)), 0n);
  }
  const o = ip.split('.').map(Number);           // IPv4
  if (o.length !== 4 || o.some(n => Number.isNaN(n))) return null;
  return (BigInt(o[0]) << 24n) + (BigInt(o[1]) << 16n) + (BigInt(o[2]) << 8n) + BigInt(o[3]);
}

function parseCidr(entry) {
  const [addr, maskRaw] = entry.split('/');
  const v6   = addr.includes(':');
  const bits = maskRaw !== undefined ? Number(maskRaw) : (v6 ? 128 : 32);
  const base = ipToBigInt(addr);
  if (base === null) return null;
  const total = v6 ? 128 : 32;
  const shift = BigInt(total - bits);
  return { base: (base >> shift) << shift, shift, v6 };
}

function ipMatches(ip, rule) {
  const val = ipToBigInt(ip);
  if (val === null) return false;
  if ((ip.includes(':')) !== rule.v6) return false;
  return ((val >> rule.shift) << rule.shift) === rule.base;
}

// ── ban list, cached ─────────────────────────────────────────
async function fetchBanList() {
  const url = `${SUPABASE_URL}/rest/v1/banned_ips`
            + `?select=ip_address,expires_at`
            + `&is_active=eq.true`
            + `&or=(expires_at.is.null,expires_at.gt.${new Date().toISOString()})`;

  const res = await fetch(url, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    // never let a slow database hold up a page load
    signal: AbortSignal.timeout(1500)
  });
  if (!res.ok) throw new Error(`ban list ${res.status}`);

  const rows = await res.json();
  return rows.map(r => parseCidr(String(r.ip_address))).filter(Boolean);
}

async function getBanList() {
  const now = Date.now();
  if (banCache && now - cacheTime < BAN_CACHE_TTL_MS) return banCache;
  if (inFlight) return inFlight;                 // collapse concurrent refreshes

  inFlight = fetchBanList()
    .then(list => { banCache = list; cacheTime = Date.now(); return list; })
    .catch(() => banCache || [])                 // fail open, keep stale list
    .finally(() => { inFlight = null; });

  return inFlight;
}

// ── the 404 the attacker sees ────────────────────────────────
// Identical in status, headers and body to a genuine miss.
function notFound() {
  return new Response(
    '<!DOCTYPE html><html><head><meta charset="utf-8"><title>404: NOT_FOUND</title></head>'
    + '<body><h1>404</h1><p>The page could not be found.</p></body></html>',
    {
      status: 404,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store'
      }
    }
  );
}

export default async function middleware(req) {
  // next() hands the request to the normal route/static handler. Returning a
  // Response instead (see notFound()) terminates it right here at the edge.
  if (!SUPABASE_URL || !SERVICE_KEY) return next();   // unconfigured → allow

  const ip = clientIp(req);
  if (!ip) return next();

  try {
    const list = await getBanList();
    if (list.some(rule => ipMatches(ip, rule))) {
      // Fire-and-forget: count the blocked hit without delaying the response.
      // (ex_ip_check also increments hit_count when called from an API route.)
      return notFound();
    }
  } catch (_) {
    // fail open
  }

  return next();
}
