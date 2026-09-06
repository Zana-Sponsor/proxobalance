import { createHmac } from 'node:crypto';
import { isIP } from 'node:net';

const SUPABASE_URL = (process.env.SUPABASE_URL || 'https://pycxuugoblkslvwebxuu.supabase.co').replace(/\/$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const FINGERPRINT_SALT = process.env.SECURITY_FINGERPRINT_SALT || SERVICE_KEY.slice(-32);

function header(req, name) {
  const value = req.headers?.[name.toLowerCase()];
  return Array.isArray(value) ? value[0] : (value || '');
}

function normalizeIp(raw) {
  let value = String(raw || '').trim();
  if (!value) return null;
  if (value.startsWith('[')) value = value.slice(1, value.indexOf(']'));
  if (value.startsWith('::ffff:')) value = value.slice(7);
  if (/^\d+\.\d+\.\d+\.\d+:\d+$/.test(value)) value = value.split(':')[0];
  return isIP(value) ? value : null;
}

function forwardedCandidate(value, fromRight = 0) {
  const list = String(value || '').split(',').map(normalizeIp).filter(Boolean);
  return list[Math.max(0, list.length - 1 - fromRight)] || null;
}

export function realClientIp(req) {
  const mode = (process.env.TRUSTED_PROXY || (process.env.VERCEL ? 'vercel' : 'direct')).toLowerCase();

  if (mode === 'cloudflare' && header(req, 'cf-ray')) {
    const ip = normalizeIp(header(req, 'cf-connecting-ip'));
    if (ip) return ip;
  }
  if (mode === 'vercel' && process.env.VERCEL) {
    const ip = forwardedCandidate(header(req, 'x-vercel-forwarded-for')) || normalizeIp(header(req, 'x-real-ip'));
    if (ip) return ip;
  }
  if (mode === 'trusted-xff') {
    const trustedHops = Math.max(0, Math.min(10, Number(process.env.TRUSTED_PROXY_HOPS || 1)));
    const ip = forwardedCandidate(header(req, 'x-forwarded-for'), trustedHops);
    if (ip) return ip;
  }
  // Vercel always sets x-forwarded-for; fall back to it so an IP is never lost.
  return normalizeIp(req.socket?.remoteAddress)
      || normalizeIp(req.connection?.remoteAddress)
      || forwardedCandidate(header(req, 'x-forwarded-for'))
      || null;
}

function browserInfo(ua) {
  const text = String(ua || '');
  const browser = /Edg\/([\d.]+)/.test(text) ? `Edge ${RegExp.$1}`
    : /OPR\/([\d.]+)/.test(text) ? `Opera ${RegExp.$1}`
    : /CriOS\/([\d.]+)/.test(text) ? `Chrome iOS ${RegExp.$1}`
    : /Chrome\/([\d.]+)/.test(text) ? `Chrome ${RegExp.$1}`
    : /FxiOS\/([\d.]+)/.test(text) ? `Firefox iOS ${RegExp.$1}`
    : /Firefox\/([\d.]+)/.test(text) ? `Firefox ${RegExp.$1}`
    : /Version\/([\d.]+).*Safari/.test(text) ? `Safari ${RegExp.$1}`
    : 'Unknown';
  const os = /Android ([^;\)]+)/.test(text) ? `Android ${RegExp.$1}`
    : /iPhone OS ([\d_]+)/.test(text) ? `iOS ${RegExp.$1.replaceAll('_', '.')}`
    : /iPad; CPU OS ([\d_]+)/.test(text) ? `iPadOS ${RegExp.$1.replaceAll('_', '.')}`
    : /Windows NT 10/.test(text) ? 'Windows 10/11'
    : /Mac OS X ([\d_]+)/.test(text) ? `macOS ${RegExp.$1.replaceAll('_', '.')}`
    : /Linux/.test(text) ? 'Linux' : 'Unknown';
  const device = /iPad/.test(text) ? 'Tablet'
    : /Mobile|iPhone|Android/.test(text) ? 'Mobile'
    : 'Desktop';
  return { browser, os, device };
}

export function requestContext(req) {
  const userAgent = String(header(req, 'user-agent') || 'Unknown').slice(0, 1200);
  const hints = [
    userAgent,
    header(req, 'accept-language'),
    header(req, 'sec-ch-ua'),
    header(req, 'sec-ch-ua-platform'),
    header(req, 'sec-ch-ua-mobile')
  ].join('\n');
  const fingerprint = FINGERPRINT_SALT
    ? createHmac('sha256', FINGERPRINT_SALT).update(hints).digest('hex')
    : null;
  return {
    ip: realClientIp(req),
    userAgent,
    fingerprint,
    path: String(req.url || '/').slice(0, 500),
    method: String(req.method || 'GET'),
    ...browserInfo(userAgent)
  };
}

function requireServerSecrets() {
  if (!SERVICE_KEY) throw Object.assign(new Error('Server security configuration is incomplete'), { status: 503 });
}

async function parseResponse(response) {
  const text = await response.text();
  const data = text ? (() => { try { return JSON.parse(text); } catch { return text; } })() : null;
  if (!response.ok) {
    const message = data?.message || data?.msg || data?.error_description || `Supabase request failed (${response.status})`;
    throw Object.assign(new Error(message), { status: response.status, details: data });
  }
  return data;
}

export async function serviceFetch(path, options = {}) {
  requireServerSecrets();
  const headers = {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
    'Content-Type': 'application/json',
    ...options.headers
  };
  return parseResponse(await fetch(`${SUPABASE_URL}${path}`, { ...options, headers }));
}

export function rpc(name, payload) {
  return serviceFetch(`/rest/v1/rpc/${encodeURIComponent(name)}`, {
    method: 'POST',
    body: JSON.stringify(payload || {})
  });
}

export async function bearerUser(req) {
  const auth = header(req, 'authorization');
  const match = auth.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  requireServerSecrets();
  try {
    return await parseResponse(await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${match[1]}` }
    }));
  } catch {
    return null;
  }
}

// Admin rights live in ex_profiles.is_admin — the same source the panel and the
// database's own is_ex_admin() use. A banned account is never an admin.
export async function isSecurityAdmin(userId) {
  if (!userId) return false;
  try {
    const rows = await serviceFetch(
      `/rest/v1/ex_profiles?id=eq.${encodeURIComponent(userId)}&select=is_admin,is_banned&limit=1`
    );
    const row = Array.isArray(rows) ? rows[0] : null;
    return !!row && row.is_admin === true && row.is_banned !== true;
  } catch {
    return false;
  }
}

// ── BAN GATE ────────────────────────────────────────────────────────────────
// ex_ip_check() matches an exact IP or any CIDR range, bumps the ban's hit
// counter, and returns a single row. RETURNS TABLE arrives as an array.
export async function ipGate(context) {
  const rows = await rpc('ex_ip_check', { p_ip: context.ip });
  const row = Array.isArray(rows) ? rows[0] : rows;
  return {
    banned: row?.banned === true,
    banId: row?.ban_id || null,
    reason: row?.reason || null,
    expiresAt: row?.expires_at || null
  };
}

// ── EVENT LOG ───────────────────────────────────────────────────────────────
// ex_record_event() writes to suspicious_events and auto-bans an IP once its
// risk in the window crosses the threshold.
//
// risk MUST stay 0 for routine traffic. The database default is 10 and the
// auto-ban threshold is 100 per hour, so logging ordinary requests at the
// default would ban a normal user after ten page loads.
export async function recordEvent(context, options = {}) {
  const {
    type,
    detail = null,
    risk = 0,
    userId = null,
    meta = null,
    method = null,
    windowMins = 60,
    threshold = 100
  } = options;
  if (!type) return null;
  try {
    return await rpc('ex_record_event', {
      p_ip: context.ip,
      p_user_id: userId,
      p_user_agent: context.userAgent,
      p_browser: context.browser,
      p_os: context.os,
      p_device: context.device,
      p_event_type: type,
      p_detail: detail,
      p_risk: Math.max(0, Number(risk) || 0),
      p_path: context.path,
      p_method: method || context.method || null,
      p_meta: { ...(meta || {}), fp: context.fingerprint || null },
      p_window_mins: windowMins,
      p_threshold: threshold
    });
  } catch {
    // Telemetry must never take a request down with it.
    return null;
  }
}

// Per-instance throttle so routine traffic does not flood suspicious_events.
// Risky events (risk > 0) are never throttled.
const RECENT = new Map();
const THROTTLE_MS = 5 * 60 * 1000;
function throttled(key) {
  const now = Date.now();
  if (RECENT.size > 500) {
    for (const [k, t] of RECENT) if (now - t > THROTTLE_MS) RECENT.delete(k);
  }
  const last = RECENT.get(key);
  if (last && now - last < THROTTLE_MS) return true;
  RECENT.set(key, now);
  return false;
}

export async function readJson(req, maxBytes = 64 * 1024) {
  const declared = Number(header(req, 'content-length') || 0);
  if (declared > maxBytes) throw Object.assign(new Error('Payload too large'), { status: 413 });
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw Object.assign(new Error('Payload too large'), { status: 413 });
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8');
  return raw ? JSON.parse(raw) : {};
}

export function json(res, status, body) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(body));
}

export function stealth404(res) {
  res.statusCode = 404;
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store, private');
  res.end('Not Found');
}

// Express/Node adapter: mount this before static files and before every route
// (`app.use(stealthBanMiddleware)`) when the whole site is served by Node.
export async function stealthBanMiddleware(req, res, next) {
  try {
    const context = requestContext(req);
    const gate = await ipGate(context);
    if (gate.banned) {
      if (!throttled(`blocked|${context.ip || '-'}`)) {
        await recordEvent(context, { type: 'blocked_request', detail: gate.reason, risk: 0 });
      }
      return stealth404(res);
    }
    req.securityContext = context;
    return next();
  } catch (error) {
    return json(res, Number(error.status) || 503, { error: 'Server error' });
  }
}

/**
 * Wraps an API route with: ban gate → auth → activity logging.
 *
 * The user is resolved BEFORE the event is written, so every recorded IP is
 * tied to the account that was signed in — that is what feeds the admin
 * panel's "IP و ئامێر" column and the per-account IP history.
 *
 * options:
 *   auth     'none' | 'optional' | 'required' | 'admin'
 *   methods  allowed HTTP methods
 *   event    event_type to log for this route (default 'api_access')
 *   risk     risk score for this route; keep 0 unless the route is sensitive
 */
export function withSecurity(handler, {
  auth = 'optional',
  methods = ['GET', 'POST'],
  event = null,
  risk = 0,
  autoLog = true
} = {}) {
  return async function secured(req, res) {
    try {
      if (!methods.includes(req.method)) {
        res.setHeader('Allow', methods.join(', '));
        return json(res, 405, { error: 'Method Not Allowed' });
      }

      const context = requestContext(req);

      const gate = await ipGate(context);
      if (gate.banned) {
        if (!throttled(`blocked|${context.ip || '-'}`)) {
          await recordEvent(context, { type: 'blocked_request', detail: gate.reason, risk: 0 });
        }
        return stealth404(res);
      }

      const user = auth === 'none' ? null : await bearerUser(req);
      if ((auth === 'required' || auth === 'admin') && !user) {
        await recordEvent(context, { type: 'unauthorized_request', detail: context.path, risk: 5 });
        return json(res, 401, { error: 'Unauthorized' });
      }
      if (auth === 'admin' && !(await isSecurityAdmin(user.id))) {
        // A non-admin probing an admin route is worth flagging, and gets the
        // same blank 404 a banned visitor sees.
        await recordEvent(context, {
          type: 'account_scanning',
          detail: `هەوڵی دەستگەیشتن بە ڕێڕەوی ئادمین: ${context.path}`,
          risk: 30,
          userId: user.id
        });
        return stealth404(res);
      }

      const type = event || 'api_access';
      const key = `${context.ip || '-'}|${user?.id || '-'}|${type}`;
      if (autoLog && (risk > 0 || !throttled(key))) {
        await recordEvent(context, {
          type,
          detail: context.path,
          risk,
          userId: user?.id || null
        });
      }

      // Handlers can log their own findings:
      //   await log({ type:'receipt_probe', detail:'...', risk:40 })
      const log = (options) => recordEvent(context, { userId: user?.id || null, ...options });

      return await handler(req, res, { context, user, log, recordEvent: log });
    } catch (error) {
      const status = Number(error.status) || 500;
      if (status === 403) return stealth404(res);
      return json(res, status, { error: status >= 500 ? 'Server error' : error.message });
    }
  };
}

export const config = { SUPABASE_URL };
