// ─────────────────────────────────────────────────────────────
// /api/track  —  records a suspicious-behaviour event.
//
// The browser only says WHAT happened. The IP, the user-agent and the
// identity all come from the request itself, so a modified client cannot
// spoof another IP, another device, or another user's id.
//
// Request:  POST /api/track
//           Authorization: Bearer <access_token>   (optional)
//           { "event": "honeypot", "detail": "...", "meta": {...} }
// ─────────────────────────────────────────────────────────────
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY;

const db = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
});

// Risk weights are server-side on purpose: the client cannot inflate or
// deflate its own score, and unknown event names score nothing.
const RISK = {
  honeypot:        100,   // instant ban — no human fills a hidden field
  receipt_probe:    45,   // same receipt image reused across accounts
  number_spray:     35,   // many different recipient numbers, fast
  rapid_submit:     30,   // orders faster than a human can type
  otp_bruteforce:   40,
  devtools_tamper:  25,   // client-side integrity check failed
  order_submitted:   0,   // attribution only: links user ↔ IP ↔ device
  login_failed:      8,
  page_view:         0
};

function clientIp(req) {
  const h = req.headers;
  return (h['cf-connecting-ip']
       || h['x-real-ip']
       || (h['x-forwarded-for'] || '').split(',')[0]
       || '').trim();
}

// Small dependency-free UA parse — enough for "which browser/OS/device".
function parseUA(ua = '') {
  const s = String(ua);
  let browser = 'Unknown', os = 'Unknown', device = 'Desktop';
  let m;
  if ((m = s.match(/Edg\/([\d.]+)/)))            browser = 'Edge ' + m[1].split('.')[0];
  else if ((m = s.match(/OPR\/([\d.]+)/)))       browser = 'Opera ' + m[1].split('.')[0];
  else if ((m = s.match(/Chrome\/([\d.]+)/)))    browser = 'Chrome ' + m[1].split('.')[0];
  else if ((m = s.match(/Version\/([\d.]+).*Safari/))) browser = 'Safari ' + m[1].split('.')[0];
  else if ((m = s.match(/Firefox\/([\d.]+)/)))   browser = 'Firefox ' + m[1].split('.')[0];
  else if (/bot|crawler|spider|curl|wget|python-requests|axios|Go-http/i.test(s)) browser = 'Bot/Script';

  if (/Windows NT 10/.test(s))       os = 'Windows 10/11';
  else if (/Windows NT/.test(s))     os = 'Windows';
  else if (/Android ([\d.]+)/.test(s)) os = 'Android ' + s.match(/Android ([\d.]+)/)[1];
  else if (/iPhone OS ([\d_]+)/.test(s)) os = 'iOS ' + s.match(/iPhone OS ([\d_]+)/)[1].replace(/_/g, '.');
  else if (/Mac OS X/.test(s))       os = 'macOS';
  else if (/Linux/.test(s))          os = 'Linux';

  if (/iPad|Tablet/i.test(s))                     device = 'Tablet';
  else if (/Mobi|iPhone|Android.*Mobile/i.test(s)) device = 'Mobile';
  if (browser === 'Bot/Script')                   device = 'Script';

  return { browser, os, device };
}

async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string') { try { return JSON.parse(req.body); } catch { return {}; } }
  const chunks = [];
  for await (const c of req) chunks.push(c);
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return {}; }
}

export default async function handler(req, res) {
  // Always answer 204 — success, failure and "you are already banned" look
  // identical, so probing this endpoint reveals nothing.
  const quiet = () => { res.status(204); res.setHeader('Cache-Control','no-store'); return res.end(); };

  if (req.method !== 'POST') return quiet();
  if (!SUPABASE_URL || !SERVICE_KEY) return quiet();

  try {
    const body  = await readBody(req);
    const event = String(body.event || '').slice(0, 40);
    if (!Object.prototype.hasOwnProperty.call(RISK, event)) return quiet();

    const ua = String(req.headers['user-agent'] || '').slice(0, 500);
    const { browser, os, device } = parseUA(ua);

    // Identity comes from the token, never from the body.
    let userId = null;
    const auth = req.headers.authorization || '';
    if (auth.startsWith('Bearer ')) {
      const { data } = await db.auth.getUser(auth.slice(7).trim());
      userId = data?.user?.id || null;
    }

    await db.rpc('ex_record_event', {
      p_ip:         clientIp(req),
      p_user_id:    userId,
      p_user_agent: ua,
      p_browser:    browser,
      p_os:         os,
      p_device:     device,
      p_event_type: event,
      p_detail:     body.detail ? String(body.detail).slice(0, 300) : null,
      p_risk:       RISK[event],
      p_path:       String(body.path || req.headers.referer || '').slice(0, 200),
      p_method:     'POST',
      p_meta:       body.meta && typeof body.meta === 'object' ? body.meta : null
    });
  } catch (err) {
    console.error('[api/track]', err);
  }

  return quiet();
}
