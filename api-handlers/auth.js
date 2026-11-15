// ═════════════════════════════════════════════════════════════════
// /api/auth — sign-up with an Iraqi mobile number, sign-in with e-mail or number.
//
//   signup_start  {phone, name, password}            → WhatsApp code (proxo_otp)
//   signup_finish {phone, name, password, code, remember}  → session
//   login_start   {identifier, password, device_token}     → session (remembered device)
//                                                           or a code (WhatsApp / e-mail)
//   login_finish  {identifier, password, code, remember}   → session
//   reset_start   {identifier}                        → code (WhatsApp / e-mail)
//   reset_verify  {identifier, code}                  → one-time grant
//   reset_finish  {identifier, grant, password, remember} → session (signed in right away)
//   verify_password {password}  (signed in)           → ok  (used before deleting an account)
//   phone_change_start  {phone, password}  (signed in) → WhatsApp code to the NEW number
//   phone_change_finish {phone, code}      (signed in) → number saved and verified
//   password_change     {current, password} (signed in) → new password, other devices
//                                                         signed out, this one stays in
//   email_change_start  {email, password}  (signed in) → code to the NEW Gmail address (n8n)
//   email_change_finish {email, code}      (signed in) → address saved and verified
//
// Every account can keep a verified number AND a verified Gmail address and sign in
// with either one (ex_auth_resolve), so a lost SIM never locks anyone out.
//
// Number rules (supabase/migrations/20261115010000_account_name_phone_rules.sql):
// once every 30 days, and a verified number belongs to one account only.
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
const GMAIL_RE = /^[a-z0-9._%+-]+@gmail\.com$/;              // sign-in by e-mail: Gmail only

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
  if (name.length < 3 || name.length > 80) throw fail(400, 'NAME_INVALID', 'ناوی تەواوت بنووسە (لانیکەم 3 پیت)');
  return name;
}
function cleanPassword(value) {
  const password = String(value ?? '');
  if (password.length < 8) throw fail(400, 'PASSWORD_SHORT', 'وشەی نهێنی دەبێت لانیکەم 8 پیت بێت');
  if (password.length > 72) throw fail(400, 'PASSWORD_LONG', 'وشەی نهێنی زۆر درێژە');
  return password;
}
function requirePhone(value) {
  const phone = normalizeIraqiPhone(value);
  if (!phone) throw fail(400, 'PHONE_INVALID', 'ژمارەی مۆبایلەکە دروست نییە');
  return phone;
}
function cleanCode(value) {
  const code = String(value ?? '')
    .replace(/[٠-٩]/g, ch => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, ch => String(ch.charCodeAt(0) - 0x06F0)).replace(/\D/g, '');
  if (code.length !== 6) throw fail(400, 'CODE_INVALID', 'کۆدە 6 ژمارەییەکە بنووسە');
  return code;
}
// e-mail or number → { kind, key, authEmail, display }
function identify(value) {
  const raw = String(value ?? '').trim();
  if (raw.includes('@')) {
    const email = raw.toLowerCase();
    if (!EMAIL_RE.test(email)) throw fail(400, 'EMAIL_INVALID', 'فۆرماتی ئیمەیڵ هەڵەیە');
    if (!GMAIL_RE.test(email)) throw fail(400, 'EMAIL_NOT_GMAIL', 'ئیمەیڵەکە دروست نییە');
    return { kind: 'email', email, key: `email:${email}`, authEmail: email, display: maskEmail(email) };
  }
  const phone = requirePhone(raw);
  return { kind: 'phone', phone, key: `phone:${phone}`, authEmail: phoneEmail(phone), display: maskPhone(phone) };
}
function lockedError(until) {
  return fail(423, 'LOCKED', 'بەهۆی 3 هەوڵی هەڵە، ئەم هەژمارە بۆ 24 کاتژمێر بلۆک کراوە', { locked_until: until });
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
    if (error.message === 'TOO_MANY_CODES') throw fail(429, 'TOO_MANY_CODES', 'کۆدی زۆر داواکراوە. تکایە 10 خولەکی تر هەوڵ بدەرەوە');
    throw error;
  }
  // the previous code is still valid: nothing new is sent until it expires
  if (issued?.active) return { channel: 'whatsapp', target: maskPhone(phone), expires_at: issued.expires_at || null, already_sent: true };
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
  return { channel: 'whatsapp', target: maskPhone(phone), expires_at: issued.expires_at || null };
}
// When the live e-mail code for this address expires (null: none, or the database rule is not there yet).
async function emailCodeExpiry(email, purpose) {
  try { return (await rpc('ex_auth_email_code_expiry', { p_email: email, p_purpose: purpose })) || null; } catch { return null; }
}
async function sendEmailCode(email, purpose) {
  const live = await emailCodeExpiry(email, purpose);
  if (live) return { channel: 'email', target: maskEmail(email), expires_at: live, already_sent: true };
  const response = await fetch(EMAIL_OTP_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'request_otp', email, purpose }),
    signal: AbortSignal.timeout(15000)
  }).catch(() => null);
  const result = response ? await response.json().catch(() => ({})) : null;
  if (!response?.ok || result?.success === false) {
    // n8n saves the code before sending; the database refuses a second live code (CODE_STILL_VALID)
    if (/CODE_STILL_VALID/.test(String(result?.message || ''))) {
      return { channel: 'email', target: maskEmail(email), expires_at: await emailCodeExpiry(email, purpose), already_sent: true };
    }
    throw fail(502, 'EMAIL_FAILED', 'هەڵەی ناردنی کۆد');
  }
  return { channel: 'email', target: maskEmail(email), expires_at: (await emailCodeExpiry(email, purpose)) || new Date(Date.now() + 600e3).toISOString() };
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

// Number or e-mail → the account. Any account can be reached by its verified number
// and by its verified address. ownPassword: number accounts keep the password hash in
// ex_auth_passwords, e-mail accounts in Supabase Auth.
async function resolveAccount(who) {
  const acct = await rpc('ex_auth_resolve', { p_identifier: who.kind === 'phone' ? who.phone : who.email });
  if (!acct?.user_id) return null;
  return { userId: acct.user_id, authEmail: String(acct.auth_email || '').toLowerCase(), ownPassword: !!acct.own_password };
}
// Password check. Returns the account (+ a session for e-mail accounts) or registers a failure.
async function checkPassword(who, password) {
  const acct = await resolveAccount(who);
  if (acct?.ownPassword) {
    if (await rpc('ex_auth_password_ok', { p_user: acct.userId, p_password: password })) return acct;
  } else if (acct) {
    const session = await passwordSession(acct.authEmail, password);
    if (session) return { ...acct, session };
  }
  return registerFailure(who.key, who.kind === 'phone' ? 'ژمارە یان وشەی نهێنی هەڵەیە' : 'ئیمەیڵ یان وشەی نهێنی هەڵەیە');
}
async function setAccountPassword(acct, password) {
  if (acct.ownPassword) return rpc('ex_auth_password_set', { p_user: acct.userId, p_password: password });
  const r = await gotrue(`/admin/users/${acct.userId}`, { method: 'PUT', body: { password } });
  if (!r.ok) throw fail(502, 'PASSWORD_CHANGE_FAILED', 'وشەی نهێنی نەگۆڕدرا، دووبارە هەوڵ بدەرەوە');
}
async function finishSignIn(req, who, acct, remember, existingSession = null) {
  const session = existingSession || await issuedSession(acct.authEmail);
  if (!session) throw fail(401, 'WRONG', 'ئیمەیڵ یان وشەی نهێنی هەڵەیە');
  await rpc('ex_auth_clear', { p_key: who.key });
  const body = { ok: true, session: sessionBody(session) };
  if (remember) body.device_token = await rpc('ex_auth_device_add', { p_user: acct.userId || session.user?.id, p_label: deviceLabel(req) });
  return body;
}

// ── the signed-in account (profile screens) ──────────────────────
const PHONE_DOMAIN = '@phone.proxobalance.app';
function accountOf(user) {
  if (!user?.id) throw fail(401, 'UNAUTHORIZED', 'تکایە دووبارە بچۆ ژوورەوە');
  const email = String(user.email || '').toLowerCase();
  if (email.endsWith(PHONE_DOMAIN)) {
    const phone = `+${email.slice(1, email.indexOf('@'))}`;
    return { id: user.id, kind: 'phone', phone, key: `phone:${phone}`, authEmail: email };
  }
  return { id: user.id, kind: 'email', key: `email:${email}`, authEmail: email };
}
// The current password; 3 wrong → the same 24-hour block as at sign-in.
async function confirmAccountPassword(account, password) {
  if (!password) throw fail(400, 'PASSWORD_REQUIRED', 'وشەی نهێنیی ئێستات بنووسە');
  await assertNotLocked(account.key);
  let ok = false;
  if (account.kind === 'phone') ok = await rpc('ex_auth_password_ok', { p_user: account.id, p_password: password });
  else { const s = await passwordSession(account.authEmail, password); ok = !!s; await dropSession(s); }
  if (!ok) return registerFailure(account.key, 'وشەی نهێنیی ئێستا هەڵەیە');
  await rpc('ex_auth_clear', { p_key: account.key });
}
const PHONE_REASONS = {
  same: () => fail(409, 'PHONE_SAME', 'ئەمە هەمان ژمارەی ئێستای هەژمارەکەتە'),
  cooldown: s => fail(409, 'PHONE_COOLDOWN', 'ژمارەی مۆبایل هەر 30 ڕۆژ جارێک دەگۆڕدرێت', { available_at: s?.available_at || null }),
  taken: () => fail(409, 'PHONE_TAKEN', 'ئەم ژمارەیە بە هەژمارێکی ترەوە بەستراوە. هەر ژمارەیەک تەنها بۆ یەک هەژمارە'),
  no_account: () => fail(403, 'ACCOUNT_UNAVAILABLE', 'ئەم هەژمارە ناتوانێت ئەم کردارە ئەنجام بدات'),
  invalid: () => fail(400, 'PHONE_INVALID', 'ژمارەی مۆبایلەکە دروست نییە')
};
const phoneReason = (reason, extra) => (PHONE_REASONS[reason] || PHONE_REASONS.invalid)(extra);
async function assertPhoneChangeAllowed(userId, phone) {
  const status = await rpc('ex_account_phone_status', { p_user: userId, p_phone: localPhone(phone) });
  if (!status?.ok) throw phoneReason(status?.reason, status);
}
const phoneTaken = phone => rpc('ex_account_phone_taken', { p_phone: localPhone(phone) });

// The n8n e-mail workflow already proves new addresses with its "signup" code.
const EMAIL_VERIFY_PURPOSE = 'signup';
function requireGmail(value) {
  const email = String(value ?? '').trim().toLowerCase();
  if (!EMAIL_RE.test(email)) throw fail(400, 'EMAIL_INVALID', 'فۆرماتی ئیمەیڵ هەڵەیە');
  if (!GMAIL_RE.test(email)) throw fail(400, 'EMAIL_NOT_GMAIL', 'ئیمەیڵەکە دروست نییە');
  return email;
}
const EMAIL_REASONS = {
  same: () => fail(409, 'EMAIL_SAME', 'ئەمە هەمان ئیمەیڵی ئێستای هەژمارەکەتە'),
  taken: () => fail(409, 'EMAIL_TAKEN', 'ئەم ئیمەیڵە بە هەژمارێکی ترەوە بەستراوە. هەر ئیمەیڵێک تەنها بۆ یەک هەژمارە'),
  no_account: () => fail(403, 'ACCOUNT_UNAVAILABLE', 'ئەم هەژمارە ناتوانێت ئەم کردارە ئەنجام بدات'),
  invalid: () => fail(400, 'EMAIL_NOT_GMAIL', 'ئیمەیڵەکە دروست نییە')
};
const emailReason = reason => (EMAIL_REASONS[reason] || EMAIL_REASONS.invalid)();
async function assertEmailChangeAllowed(userId, email) {
  const status = await rpc('ex_account_email_status', { p_user: userId, p_email: email });
  if (!status?.ok) throw emailReason(status?.reason);
}

// ── actions ──────────────────────────────────────────────────────
const actions = {
  async signup_start(body, { context }) {
    const phone = requirePhone(body.phone);
    cleanName(body.name); cleanPassword(body.password);
    await assertNotLocked(`phone:${phone}`);
    if (await userIdFor(phoneEmail(phone))) throw fail(409, 'PHONE_TAKEN', 'ئەم ژمارەیە پێشتر تۆمارکراوە. تکایە بچۆ ژوورەوە');
    if (await phoneTaken(phone)) throw fail(409, 'PHONE_TAKEN', 'ئەم ژمارەیە بە هەژمارێکی ترەوە بەستراوە');
    return { ok: true, otp_required: true, ...(await sendWhatsAppCode(phone, 'signup', context?.ip)) };
  },

  async signup_finish(body, { req }) {
    const phone = requirePhone(body.phone);
    const name = cleanName(body.name);
    const password = cleanPassword(body.password);
    await checkPhoneCode(phone, 'signup', cleanCode(body.code));
    const email = phoneEmail(phone);
    if (await userIdFor(email)) throw fail(409, 'PHONE_TAKEN', 'ئەم ژمارەیە پێشتر تۆمارکراوە. تکایە بچۆ ژوورەوە');
    if (await phoneTaken(phone)) throw fail(409, 'PHONE_TAKEN', 'ئەم ژمارەیە بە هەژمارێکی ترەوە بەستراوە');
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
      // the code proved the number: WhatsApp may use it, and no other account can take it
      body: JSON.stringify({ full_name: name, phone: localPhone(phone), email: null, phone_verified_at: new Date().toISOString() })
    });
    const who = { kind: 'phone', phone, key: `phone:${phone}`, authEmail: email };
    return finishSignIn(req, who, { userId, authEmail: email, ownPassword: true }, body.remember === true);
  },

  async login_start(body, { req, context }) {
    const who = identify(body.identifier);
    const password = String(body.password ?? '');
    if (!password) throw fail(400, 'PASSWORD_REQUIRED', 'وشەی نهێنی بنووسە');
    await assertNotLocked(who.key);
    const acct = await checkPassword(who, password);
    const deviceToken = typeof body.device_token === 'string' ? body.device_token : '';
    if (deviceToken && await rpc('ex_auth_device_ok', { p_user: acct.userId, p_token: deviceToken })) {
      return finishSignIn(req, who, acct, false, acct.session);           // remembered device: no code
    }
    await dropSession(acct.session);
    // the code goes to what they typed: WhatsApp for a number, e-mail for an address
    const sent = who.kind === 'phone' ? await sendWhatsAppCode(who.phone, 'login', context?.ip) : await sendEmailCode(who.email, 'login');
    return { ok: true, otp_required: true, ...sent };
  },

  async login_finish(body, { req }) {
    const who = identify(body.identifier);
    const password = String(body.password ?? '');
    await assertNotLocked(who.key);
    const code = cleanCode(body.code);
    if (who.kind === 'phone') await checkPhoneCode(who.phone, 'login', code);
    else await checkEmailCode(who.email, 'login', code);
    const acct = await checkPassword(who, password);
    return finishSignIn(req, who, acct, body.remember === true, acct.session);
  },

  // Forgot password, by number (WhatsApp code) or by e-mail (n8n code), for every account.
  async reset_start(body, { context }) {
    const who = identify(body.identifier ?? body.phone);
    await assertNotLocked(who.key);
    if (!(await resolveAccount(who))) {
      throw who.kind === 'phone'
        ? fail(404, 'PHONE_UNKNOWN', 'هیچ هەژمارێک بەم ژمارەیە نییە')
        : fail(404, 'EMAIL_UNKNOWN', 'هیچ هەژمارێک بەم ئیمەیڵە نییە');
    }
    const sent = who.kind === 'phone' ? await sendWhatsAppCode(who.phone, 'reset', context?.ip) : await sendEmailCode(who.email, 'reset_password');
    return { ok: true, otp_required: true, ...sent };
  },

  async reset_verify(body) {
    const who = identify(body.identifier ?? body.phone);
    const code = cleanCode(body.code);
    if (who.kind === 'phone') return { ok: true, grant: (await checkPhoneCode(who.phone, 'reset', code)).grant };
    await checkEmailCode(who.email, 'reset_password', code);
    return { ok: true, grant: await rpc('ex_auth_email_grant_issue', { p_email: who.email }) };
  },

  async reset_finish(body, { req }) {
    const who = identify(body.identifier ?? body.phone);
    const password = cleanPassword(body.password);
    await assertNotLocked(who.key);
    const grant = String(body.grant ?? '');
    const granted = who.kind === 'phone'
      ? await rpc('ex_auth_reset_grant_use', { p_phone: who.phone, p_grant: grant })
      : await rpc('ex_auth_email_grant_use', { p_email: who.email, p_grant: grant });
    if (!granted) throw fail(410, 'GRANT_EXPIRED', 'کاتەکەی تەواو بوو. تکایە دووبارە کۆد داوا بکە');
    const acct = await resolveAccount(who);
    if (!acct) throw fail(404, 'ACCOUNT_UNKNOWN', 'هیچ هەژمارێک نەدۆزرایەوە');
    await setAccountPassword(acct, password);
    await rpc('ex_auth_sign_out_everywhere', { p_user: acct.userId });
    return finishSignIn(req, who, acct, body.remember === true);         // signed in with the new password
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
  },

  // ── profile: mobile number (code to the NEW number) ─────────────
  async phone_change_start(body, { user, context }) {
    const account = accountOf(user);
    const phone = requirePhone(body.phone);
    await assertPhoneChangeAllowed(account.id, phone);
    await confirmAccountPassword(account, String(body.password ?? ''));
    return { ok: true, otp_required: true, ...(await sendWhatsAppCode(phone, 'change_phone', context?.ip)) };
  },

  async phone_change_finish(body, { user }) {
    const account = accountOf(user);
    const phone = requirePhone(body.phone);
    await assertPhoneChangeAllowed(account.id, phone);
    await checkPhoneCode(phone, 'change_phone', cleanCode(body.code));
    // A number account signs in with its number, so its sign-in moves to the new one.
    if (account.kind === 'phone') {
      const moved = await gotrue(`/admin/users/${account.id}`, { method: 'PUT', body: { email: phoneEmail(phone), email_confirm: true } });
      if (!moved.ok) throw fail(502, 'PHONE_CHANGE_FAILED', 'ژمارەکە نەگۆڕدرا، دووبارە هەوڵ بدەرەوە');
    }
    let saved;
    try {
      saved = await rpc('ex_account_phone_set', { p_user: account.id, p_phone: localPhone(phone) });
    } catch (error) {
      if (account.kind === 'phone') {
        await gotrue(`/admin/users/${account.id}`, { method: 'PUT', body: { email: account.authEmail, email_confirm: true } }).catch(() => null);
      }
      const reason = /^PHONE_[A-Z_]+$/.test(String(error.message || '')) ? error.message.slice(6).toLowerCase() : '';
      if (reason) throw phoneReason(reason, { available_at: error.details?.details || null });
      throw error;
    }
    return {
      ok: true, phone: localPhone(phone),
      changed_at: saved?.changed_at || null, available_at: saved?.available_at || null,
      sign_in_changed: account.kind === 'phone'
    };
  },

  // ── profile: e-mail (code to the NEW address, sent by n8n) ──────
  async email_change_start(body, { user }) {
    const account = accountOf(user);
    const email = requireGmail(body.email);
    await assertEmailChangeAllowed(account.id, email);
    await confirmAccountPassword(account, String(body.password ?? ''));
    return { ok: true, otp_required: true, ...(await sendEmailCode(email, EMAIL_VERIFY_PURPOSE)) };
  },

  async email_change_finish(body, { user }) {
    const account = accountOf(user);
    const email = requireGmail(body.email);
    await assertEmailChangeAllowed(account.id, email);
    await checkEmailCode(email, EMAIL_VERIFY_PURPOSE, cleanCode(body.code));
    // An e-mail account signs in with its address, so its sign-in moves to the new one.
    if (account.kind === 'email') {
      const moved = await gotrue(`/admin/users/${account.id}`, { method: 'PUT', body: { email, email_confirm: true } });
      if (!moved.ok) throw fail(502, 'EMAIL_CHANGE_FAILED', 'ئیمەیڵەکە نەگۆڕدرا، دووبارە هەوڵ بدەرەوە');
    }
    try {
      await rpc('ex_account_email_set', { p_user: account.id, p_email: email });
    } catch (error) {
      if (account.kind === 'email') {
        await gotrue(`/admin/users/${account.id}`, { method: 'PUT', body: { email: account.authEmail, email_confirm: true } }).catch(() => null);
      }
      const m = /^EMAIL_([A-Z_]+)$/.exec(String(error.message || ''));
      if (m) throw emailReason(m[1].toLowerCase());
      throw error;
    }
    return { ok: true, email, sign_in_changed: account.kind === 'email' };
  },

  // ── profile: password (this device stays signed in) ─────────────
  async password_change(body, { user }) {
    const account = accountOf(user);
    const current = String(body.current ?? '');
    const password = cleanPassword(body.password);
    if (current && current === password) throw fail(400, 'PASSWORD_SAME', 'وشەی نهێنیی نوێ دەبێت جیاواز بێت لە وشەی نهێنیی ئێستا');
    await confirmAccountPassword(account, current);
    if (account.kind === 'phone') {
      await rpc('ex_auth_password_set', { p_user: account.id, p_password: password });
    } else {
      const r = await gotrue(`/admin/users/${account.id}`, { method: 'PUT', body: { password } });
      if (!r.ok) throw fail(502, 'PASSWORD_CHANGE_FAILED', 'وشەی نهێنی نەگۆڕدرا، دووبارە هەوڵ بدەرەوە');
    }
    await rpc('ex_auth_sign_out_everywhere', { p_user: account.id });   // every other device signs in again
    const session = account.kind === 'phone'
      ? await issuedSession(account.authEmail)
      : await passwordSession(account.authEmail, password);
    return { ok: true, session: session ? sessionBody(session) : null };
  }
};

export default withSecurity(async (req, res, ctx) => {
  const body = await readJson(req, 8 * 1024);
  const action = Object.hasOwn(actions, body?.action) ? actions[body.action] : null;
  if (!action) return json(res, 400, { error: 'Unknown action', code: 'UNKNOWN_ACTION' });
  try {
    return json(res, 200, await action(body, { ...ctx, req }));
  } catch (error) {
    if (error.code && error.status && error.status < 500 || ['WHATSAPP_FAILED', 'WHATSAPP_NOT_CONFIGURED', 'EMAIL_FAILED', 'SESSION_FAILED', 'SIGNUP_FAILED', 'PHONE_CHANGE_FAILED', 'PASSWORD_CHANGE_FAILED', 'EMAIL_CHANGE_FAILED'].includes(error.code)) {
      return json(res, error.status, { error: error.message, code: error.code, ...(error.extra || {}) });
    }
    throw error;
  }
}, { auth: 'optional', methods: ['POST'], event: 'auth_api' });
