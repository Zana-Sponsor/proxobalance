import { json, readJson, rpc, withSecurity } from './_lib/security.js';

const ALLOWED = new Set([
  'honeypot', 'receipt_probe', 'account_scanning', 'failed_login',
  'page_view', 'number_spray', 'rapid_submit', 'otp_bruteforce', 'devtools_tamper'
]);

const text = (value, max) => String(value || '').replace(/[\r\n\t]+/g, ' ').trim().slice(0, max);

function safeMeta(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const out = {};
  for (const [key, item] of Object.entries(value).slice(0, 20)) {
    if (!/^[a-z0-9_]{1,40}$/i.test(key)) continue;
    if (['password', 'token', 'authorization', 'card_number', 'phone'].includes(key.toLowerCase())) continue;
    out[key] = typeof item === 'string' ? text(item, 200) : (typeof item === 'number' || typeof item === 'boolean' ? item : null);
  }
  return out;
}

export default withSecurity(async (req, res, { context, user }) => {
  const body = await readJson(req, 24 * 1024);
  const event = text(body.event, 60);

  // Orders are recorded atomically by /api/orders; this avoids double counting.
  if (event === 'order_submitted') return json(res, 202, { ok: true });
  if (!ALLOWED.has(event)) return json(res, 422, { error: 'Unsupported event' });

  const result = await rpc('security_log_event', {
    p_action_type: event,
    p_ip: context.ip,
    p_user_id: user?.id || null,
    p_username: text(user?.user_metadata?.full_name, 200) || null,
    p_user_email: text(user?.email, 320) || null,
    p_user_agent: context.userAgent,
    p_browser: context.browser,
    p_os: context.os,
    p_device: context.device,
    p_fingerprint_hash: context.fingerprint,
    p_detail: text(body.detail, 1000) || null,
    p_request_path: text(body.path || context.path, 500),
    p_payload_summary: safeMeta(body.meta)
  });
  return json(res, 202, { ok: true, alert_created: Boolean(result?.alert_id) });
}, { auth: 'optional', methods: ['POST'] });
