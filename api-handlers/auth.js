// ═════════════════════════════════════════════════════════════════
// /api/auth — sign-up with an Iraqi mobile number, sign-in with e-mail or number.
//
//   signup_start  {phone, name, password}            → WhatsApp code (proxo_otp)
//   signup_finish {phone, name, password, code, remember}  → session
//   login_start   {identifier, password, device_token}     → session (remembered device)
//                                                           or a code (WhatsApp / e-mail)
//   login_finish  {identifier, password, code, remember}   → session
//   reset_start   {phone}                             → WhatsApp code
//   reset_verify  {phone, code}                       → one-time grant
//   reset_finish  {phone, grant, password, remember}  → session (signed in right away)
//   verify_password {password}  (signed in)           → ok  (used before deleting an account)
//
// The rules live in the database (supabase/migrations/20261115000000_phone_auth.sql):
// Iraqi numbers only, hashed 5-minute codes, send limits, and a 24-hour block after
// 3 wrong passwords or codes. Number accounts keep their password hash in
// ex_auth_passwords; their Supabase Auth password is random and never used, so the
// only way to a session is through this file.
// ═════════════════════════════════════════════════════════════════
import { randomBytes } from 'node:crypto';
import { json, readJson, rpc, serviceFetch, withSecurity, config } from './_lib/security.js';

const SUPABASE_URL = config.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const WEVLIX_URL = 'https://api.wevlix.com/v1/messages/template';
const OTP_TEMPLATE_ID = process.env.WEVLIX_OTP_TEMPLATE_ID || 'fcb360b0-6bee-499c-990b-8fc181dccfbd'; // proxo_otp
const EMAIL_OTP_WEBHOOK = process.env.N8N_OTP_WEBHOOK || 'https://email.proxopages.com/webhook/otp_exchange';
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ── helpers ──────────────────────────────────────────────────────
export function normalizeIraqiPhone(value) {
  let d = String(value ?? '')
    .replace(/[٠-٩]/g, ch => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, ch => String(ch.charCodeAt(0) - 0x06F0))
    .replace(/\D/g, '');
  if (d.startsWith('00964')) d = d.slice(5);
  else if (d.startsWith('964')) d = d.slice(3);
  else if (d.startsWith('0')) d = d.slice(1);
  return /^7[3-9]\d{8}$/.test(d) ? `+964${d}` : null;
}
export const phoneEmail = phone => `p${phone.slice(1)}@phone.proxobalance.app`;
export const localPhone = phone => `0${phone.slice(4)}`;              // +9647501234567 → 07501234567
const maskPhone = phone => `${localPhone(phone).slice(0, 4)}•••${phone.slice(-4)}`;
const maskEmail = email => email.replace(/^(.)[^@]*(@.*)$/, (_, a, b) => `${a}•••${b}`);

function fail(status, code, message, extra = {}) {
  return Object.assign(new Error(message), { status, code, extra });
}
function cleanName(value) {
  const name = String(value ?? '').replace(/\s+/g, ' ').trim();
  if (name.length < 3 || name.length > 80) throw fail(400, 'NAME_INVALID', 'ناوی تەواوت بنووسە (لانیکەم ٣ پیت)');
  return name;
}
function cleanPassword(value) {
  const password = String(value ?? '');
  if (password.length < 8) throw fail(400, 'PASSWORD_SHORT', 'وشەی نهێنی دەبێت لانیکەم ٨ پیت بێت');
  if (password.length > 72) throw fail(400, 'PASSWORD_LONG', 'وشەی نهێنی زۆر درێژە');
  return password;
}
function requirePhone(value) {
  const phone = normalizeIraqiPhone(value);
  if (!phone) throw fail(400, 'PHONE_INVALID', 'تەنها ژمارەی مۆبایلی عێراقی قبوڵ دەکرێت (07XX XXX XXXX)');
  return phone;
}
function cleanCode(value) {
  const code = String(value ?? '')
    .replace(/[٠-٩]/g, ch => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, ch => String(ch.charCodeAt(0) - 0x06F0)).replace(/\D/g, '');
  if (code.length !== 6) throw fail(400, 'CODE_INVALID', 'کۆدە ٦ ژمارەییەکە بنووسە');
  return code;
}
// e-mail or number → { kind, key, authEmail, display }
function identify(value) {
  const raw = String(value ?? '').trim();
  if (raw.includes('@')) {
    const email = raw.toLowerCase();
    if (!EMAIL_RE.test(email) || email.endsWith('@phone.proxobalance.app')) throw fail(400, 'EMAIL_INVALID', 'فۆرماتی ئیمەیڵ هەڵەیە');
    return { kind: 'email', key: `email:${email}`, authEmail: email, display: maskEmail(email) };
  }
  const phone = requirePhone(raw);
  return { kind: 'phone', phone, key: `phone:${phone}`, authEmail: phoneEmail(phone), display: maskPhone(phone) };
}
function lockedError(until) {
  return fail(423, 'LOCKED', 'بەهۆی ٣ هەوڵی هەڵە، ئەم هەژمارە بۆ ٢٤ کاتژمێر بلۆک کراوە', { locked_until: until });
}
async function assertNotLocked(key) {
  const until = await rpc('ex_auth_lock_until', { p_key: key });
  if (until) throw lockedError(until);
}
async function registerFailure(key, message) {
  const result = await rpc('ex_auth_fail', { p_key: key });
  if (result?.locked_until) throw lockedError(result.locked_until);
  throw fail(401, 'WRONG', message, { attempts_left: result?.attempts_left ?? null });
}

// ── Supabase Auth (GoTrue) ───────────────────────────────────────
async function gotrue(path, { method = 'POST', body, token } = {}) {
  const response = await fetch(`${SUPABASE_URL}/auth/v1${path}`, {
    method,
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${token || SERVICE_KEY}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(15000)
  });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { ok: response.ok, status: response.status, data };
}
// E-mail accounts: Supabase checks the password and returns a session.
async function passwordSession(email, password) {
  const r = await gotrue('/token?grant_type=password', { body: { email, password } });
  return r.ok && r.data?.access_token ? r.data : null;
}
// Number accounts: a session without a password (the password was checked here).
async function issuedSession(email) {
  const link = await gotrue('/admin/generate_link', { body: { type: 'magiclink', email } });
  const hashed = link.data?.properties?.hashed_token || link.data?.hashed_token;
  if (!link.ok || !hashed) throw fail(502, 'SESSION_FAILED', 'نەتوانرا بچیتە ژوورەوە، دووبارە هەوڵ بدەرەوە');
  for (const type of ['magiclink', 'email']) {
    const r = await gotrue('/verify', { body: { type, token_hash: hashed } });
    if (r.ok && r.data?.access_token) return r.data;
  }
  throw fail(502, 'SESSION_FAILED', 'نەتوانرا بچیتە ژوورەوە، دووبارە هەوڵ بدەرەوە');
}
async function dropSession(session) {
  if (session?.access_token) await gotrue('/logout?scope=local', { token: session.access_token }).catch(() => null);
}
function sessionBody(session) {
  return {
    access_token: session.access_token, refresh_token: session.refresh_token,
    expires_in: session.expires_in, expires_at: session.expires_at, user: session.user
  };
}

// ── sending codes ────────────────────────────────────────────────
async function sendWhatsAppCode(phone, purpose, ip) {
  if (!process.env.WEVLIX_API_KEY) throw fail(503, 'WHATSAPP_NOT_CONFIGURED', 'ناردنی کۆدی واتساپ هێشتا ڕێکنەخراوە');
  let issued;
  try {
    issued = await rpc('ex_auth_code_issue', { p_phone: phone, p_purpose: purpose, p_ip: ip || null });
  } catch (error) {
    if (error.message === 'LOCKED') throw lockedError(error.details?.details || null);
    if (error.message === 'TOO_MANY_CODES') throw fail(429, 'TOO_MANY_CODES', 'کۆدی زۆر داواکراوە. تکایە ١٠ خولەکی تر هەوڵ بدەرەوە');
    throw error;
  }
  const response = await fetch(WEVLIX_URL, {
    method: 'POST',
    headers: { 'x-api-key': process.env.WEVLIX_API_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      to: phone,
      templateId: OTP_TEMPLATE_ID,
      clientMessageId: `otp_${issued.id}`,
      components: [
        { type: 'body', parameters: [{ type: 'text', text: issued.code }] },
        { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: issued.code }] }
      ]
    }),
    signal: AbortSignal.timeout(15000)
  }).catch(() => null);
  const result = response ? await response.json().catch(() => null) : null;
  if (!response?.ok || result?.success === false) {
    throw fail(502, 'WHATSAPP_FAILED', 'نەتوانرا کۆد بنێردرێت بۆ واتساپ. دڵنیابە کە ژمارەکە واتساپی هەیە');
  }
  return { channel: 'whatsapp', target: maskPhone(phone) };
}
async function sendEmailCode(email, purpose) {
  const response = await fetch(EMAIL_OTP_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'request_otp', email, purpose }),
    signal: AbortSignal.timeout(15000)
  }).catch(() => null);
  const result = response ? await response.json().catch(() => ({})) : null;
  if (!response?.ok || result?.success === false) throw fail(502, 'EMAIL_FAILED', result?.message || 'هەڵەی ناردنی کۆد');
  return { channel: 'email', target: maskEmail(email) };
}

async function checkPhoneCode(phone, purpose, code) {
  const result = await rpc('ex_auth_code_check', { p_phone: phone, p_purpose: purpose, p_code: code });
  if (result?.ok) return result;
  if (result?.reason === 'locked') throw lockedError(result.locked_until);
  if (result?.reason === 'expired') throw fail(410, 'CODE_EXPIRED', 'کاتی کۆدەکە تەواو بووە. کۆدی نوێ داوا بکە');
  throw fail(401, 'WRONG', 'کۆدەکە هەڵەیە', { attempts_left: result?.attempts_left ?? null });
}
async function checkEmailCode(email, purpose, code) {
  const ok = await rpc('ex_verify_otp', { p_email: email, p_code: code, p_purpose: purpose });
  if (ok === true) return;
  const until = await rpc('ex_auth_lock_until', { p_key: `email:${email}` });
  if (until) throw lockedError(until);
  throw fail(401, 'WRONG', 'کۆدەکە هەڵەیە یان کاتی تەواو بووە');
}

const userIdFor = email => rpc('ex_auth_user_by_email', { p_email: email });
const deviceLabel = req => String(req.headers?.['user-agent'] || '').slice(0, 200) || null;

// Password check for either kind. Returns { userId, session? } or registers a failure.
async function checkPassword(who, password) {
  if (who.kind === 'phone') {
    const userId = await userIdFor(who.authEmail);
    if (userId && await rpc('ex_auth_password_ok', { p_user: userId, p_password: password })) return { userId };
    return registerFailure(who.key, 'ژمارە یان وشەی نهێنی هەڵەیە');
  }
  const session = await passwordSession(who.authEmail, password);
  if (session) return { userId: session.user?.id, session };
  return registerFailure(who.key, 'ئیمەیڵ یان وشەی نهێنی هەڵەیە');
}
async function finishSignIn(req, who, userId, remember, existingSession = null, password = null) {
  let session = existingSession;
  if (!session) session = who.kind === 'phone' ? await issuedSession(who.authEmail) : await passwordSession(who.authEmail, password);
  if (!session) throw fail(401, 'WRONG', 'ئیمەیڵ یان وشەی نهێنی هەڵەیە');
  await rpc('ex_auth_clear', { p_key: who.key });
  const body = { ok: true, session: sessionBody(session) };
  if (remember) body.device_token = await rpc('ex_auth_device_add', { p_user: userId || session.user?.id, p_label: deviceLabel(req) });
  return body;
}

// ── actions ──────────────────────────────────────────────────────
const actions = {
  async signup_start(body, { context }) {
    const phone = requirePhone(body.phone);
    cleanName(body.name); cleanPassword(body.password);
    await assertNotLocked(`phone:${phone}`);
    if (await userIdFor(phoneEmail(phone))) throw fail(409, 'PHONE_TAKEN', 'ئەم ژمارەیە پێشتر تۆمارکراوە. تکایە بچۆ ژوورەوە');
    return { ok: true, otp_required: true, ...(await sendWhatsAppCode(phone, 'signup', context?.ip)) };
  },

  async signup_finish(body, { req }) {
    const phone = requirePhone(body.phone);
    const name = cleanName(body.name);
    const password = cleanPassword(body.password);
    await checkPhoneCode(phone, 'signup', cleanCode(body.code));
    const email = phoneEmail(phone);
    if (await userIdFor(email)) throw fail(409, 'PHONE_TAKEN', 'ئەم ژمارەیە پێشتر تۆمارکراوە. تکایە بچۆ ژوورەوە');
    const created = await gotrue('/admin/users', {
      body: {
        email, password: randomBytes(32).toString('base64url'), email_confirm: true,
        user_metadata: { full_name: name, phone: localPhone(phone), signup_method: 'phone', source: 'exchange' }
      }
    });
    const userId = created.data?.id || created.data?.user?.id;
    if (!created.ok || !userId) throw fail(502, 'SIGNUP_FAILED', 'هەژمار دروست نەکرا، دووبارە هەوڵ بدەرەوە');
    await rpc('ex_auth_password_set', { p_user: userId, p_password: password });
    await serviceFetch(`/rest/v1/ex_profiles?id=eq.${userId}`, {
      method: 'PATCH', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ full_name: name, phone: localPhone(phone), email: null })
    });
    const who = { kind: 'phone', phone, key: `phone:${phone}`, authEmail: email };
    return finishSignIn(req, who, userId, body.remember === true);
  },

  async login_start(body, { req, context }) {
    const who = identify(body.identifier);
    const password = String(body.password ?? '');
    if (!password) throw fail(400, 'PASSWORD_REQUIRED', 'وشەی نهێنی بنووسە');
    await assertNotLocked(who.key);
    const { userId, session } = await checkPassword(who, password);
    const deviceToken = typeof body.device_token === 'string' ? body.device_token : '';
    if (deviceToken && await rpc('ex_auth_device_ok', { p_user: userId, p_token: deviceToken })) {
      return finishSignIn(req, who, userId, false, session, password);   // remembered device: no code
    }
    await dropSession(session);
    const sent = who.kind === 'phone' ? await sendWhatsAppCode(who.phone, 'login', context?.ip) : await sendEmailCode(who.authEmail, 'login');
    return { ok: true, otp_required: true, ...sent };
  },

  async login_finish(body, { req }) {
    const who = identify(body.identifier);
    const password = String(body.password ?? '');
    await assertNotLocked(who.key);
    const code = cleanCode(body.code);
    if (who.kind === 'phone') await checkPhoneCode(who.phone, 'login', code);
    else await checkEmailCode(who.authEmail, 'login', code);
    const { userId, session } = await checkPassword(who, password);
    return finishSignIn(req, who, userId, body.remember === true, session, password);
  },

  async reset_start(body, { context }) {
    const phone = requirePhone(body.phone);
    await assertNotLocked(`phone:${phone}`);
    if (!(await userIdFor(phoneEmail(phone)))) throw fail(404, 'PHONE_UNKNOWN', 'هیچ هەژمارێک بەم ژمارەیە نییە');
    return { ok: true, otp_required: true, ...(await sendWhatsAppCode(phone, 'reset', context?.ip)) };
  },

  async reset_verify(body) {
    const phone = requirePhone(body.phone);
    const result = await checkPhoneCode(phone, 'reset', cleanCode(body.code));
    return { ok: true, grant: result.grant };
  },

  async reset_finish(body, { req }) {
    const phone = requirePhone(body.phone);
    const password = cleanPassword(body.password);
    await assertNotLocked(`phone:${phone}`);
    if (!(await rpc('ex_auth_reset_grant_use', { p_phone: phone, p_grant: String(body.grant ?? '') }))) {
      throw fail(410, 'GRANT_EXPIRED', 'کاتەکەی تەواو بوو. تکایە دووبارە کۆد داوا بکە');
    }
    const email = phoneEmail(phone);
    const userId = await userIdFor(email);
    if (!userId) throw fail(404, 'PHONE_UNKNOWN', 'هیچ هەژمارێک بەم ژمارەیە نییە');
    await rpc('ex_auth_password_set', { p_user: userId, p_password: password });
    await rpc('ex_auth_sign_out_everywhere', { p_user: userId });
    const who = { kind: 'phone', phone, key: `phone:${phone}`, authEmail: email };
    return finishSignIn(req, who, userId, body.remember === true);     // signed in with the new password
  },

  async verify_password(body, { user }) {
    if (!user) throw fail(401, 'UNAUTHORIZED', 'Unauthorized');
    const email = String(user.email || '').toLowerCase();
    const password = String(body.password ?? '');
    let ok = false;
    if (email.endsWith('@phone.proxobalance.app')) ok = await rpc('ex_auth_password_ok', { p_user: user.id, p_password: password });
    else { const s = await passwordSession(email, password); ok = !!s; await dropSession(s); }
    if (!ok) throw fail(401, 'WRONG', 'وشەی نهێنی هەڵەیە');
    return { ok: true };
  }
};

export default withSecurity(async (req, res, ctx) => {
  const body = await readJson(req, 8 * 1024);
  const action = Object.hasOwn(actions, body?.action) ? actions[body.action] : null;
  if (!action) return json(res, 400, { error: 'Unknown action', code: 'UNKNOWN_ACTION' });
  try {
    return json(res, 200, await action(body, { ...ctx, req }));
  } catch (error) {
    if (error.code && error.status && error.status < 500 || ['WHATSAPP_FAILED', 'WHATSAPP_NOT_CONFIGURED', 'EMAIL_FAILED', 'SESSION_FAILED', 'SIGNUP_FAILED'].includes(error.code)) {
      return json(res, error.status, { error: error.message, code: error.code, ...(error.extra || {}) });
    }
    throw error;
  }
}, { auth: 'optional', methods: ['POST'], event: 'auth_api' });
