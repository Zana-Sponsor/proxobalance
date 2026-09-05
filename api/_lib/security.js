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
  return normalizeIp(req.socket?.remoteAddress) || normalizeIp(req.connection?.remoteAddress);
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

export async function isSecurityAdmin(userId) {
  if (!userId) return false;
  const rows = await serviceFetch(`/rest/v1/security_admins?user_id=eq.${encodeURIComponent(userId)}&select=user_id&limit=1`);
  return Array.isArray(rows) && rows.length === 1;
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
    const gate = await rpc('security_check_request', {
      p_ip: context.ip,
      p_user_id: null,
      p_user_agent: context.userAgent,
      p_fingerprint_hash: context.fingerprint,
      p_path: context.path
    });
    if (gate?.banned) return stealth404(res);
    req.securityContext = context;
    return next();
  } catch (error) {
    return json(res, Number(error.status) || 503, { error: 'Server error' });
  }
}

export function withSecurity(handler, { auth = 'optional', methods = ['GET', 'POST'] } = {}) {
  return async function secured(req, res) {
    try {
      if (!methods.includes(req.method)) {
        res.setHeader('Allow', methods.join(', '));
        return json(res, 405, { error: 'Method Not Allowed' });
      }

      const context = requestContext(req);
      const gate = await rpc('security_check_request', {
        p_ip: context.ip,
        p_user_id: null,
        p_user_agent: context.userAgent,
        p_fingerprint_hash: context.fingerprint,
        p_path: context.path
      });
      if (gate?.banned) return stealth404(res);

      const user = auth === 'none' ? null : await bearerUser(req);
      if ((auth === 'required' || auth === 'admin') && !user) return json(res, 401, { error: 'Unauthorized' });
      if (auth === 'admin' && !(await isSecurityAdmin(user.id))) return json(res, 404, { error: 'Not Found' });

      return await handler(req, res, { context, user });
    } catch (error) {
      const status = Number(error.status) || 500;
      if (status === 403) return stealth404(res);
      return json(res, status, { error: status >= 500 ? 'Server error' : error.message });
    }
  };
}

export const config = { SUPABASE_URL };
