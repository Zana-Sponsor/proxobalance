import assert from 'node:assert/strict';
import test from 'node:test';

// /api/auth against a fake Supabase (REST + Auth) and a fake Wevlix.
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-test-key';
process.env.WEVLIX_API_KEY = 'wevlix-test-key';
const { default: handler, normalizeIraqiPhone, phoneEmail } = await import('../api-handlers/auth.js');

function backend() {
  const db = { users: new Map(), passwords: new Map(), codes: [], locks: new Map(), devices: new Map(), sent: [], emailCodes: [], sessions: 0, tokens: new Map(), profiles: new Map() };
  const DAY = 864e5;
  const taken = (phone, except) => [...db.profiles.entries()].some(([id, p]) => id !== except && p.phone === phone && p.verified)
    || [...db.users.values()].some(u => u.id !== except && u.email === `p964${phone.slice(1)}@phone.proxobalance.app`);
  const phoneStatus = (id, phone) => {
    const p = db.profiles.get(id) || {};
    if (!/^07[3-9]\d{8}$/.test(phone || '')) return { ok: false, reason: 'invalid' };
    if (p.phone === phone && p.verified) return { ok: false, reason: 'same' };
    if (p.changedAt && p.changedAt + 30 * DAY > Date.now()) return { ok: false, reason: 'cooldown', available_at: new Date(p.changedAt + 30 * DAY).toISOString() };
    if (taken(phone, id)) return { ok: false, reason: 'taken' };
    return { ok: true };
  };
  const lock = key => { const l = db.locks.get(key); return l?.until && l.until > Date.now() ? new Date(l.until).toISOString() : null; };
  const failKey = key => {
    const l = db.locks.get(key) || { failures: 0, until: 0 };
    l.failures += 1;
    if (l.failures >= 3) { l.until = Date.now() + 24 * 3600e3; l.failures = 0; }
    db.locks.set(key, l);
    return { locked_until: lock(key), attempts_left: lock(key) ? 0 : 3 - l.failures };
  };
  const rpcs = {
    ex_ip_check: () => [{ banned: false }],
    ex_record_event: () => null,
    ex_auth_lock_until: ({ p_key }) => lock(p_key),
    ex_auth_fail: ({ p_key }) => failKey(p_key),
    ex_auth_clear: ({ p_key }) => { if (!lock(p_key)) db.locks.delete(p_key); return null; },
    ex_auth_user_by_email: ({ p_email }) => [...db.users.values()].find(u => u.email === p_email)?.id || null,
    ex_auth_code_issue: ({ p_phone, p_purpose }) => {
      if (lock(`phone:${p_phone}`)) return { __error: 'LOCKED' };
      // one live code: while it is valid, no new code
      const live = db.codes.filter(x => x.phone === p_phone && x.purpose === p_purpose && !x.used && x.expiresAt > Date.now()).at(-1);
      if (live) return { id: null, code: null, active: true, expires_at: new Date(live.expiresAt).toISOString() };
      const code = String(100000 + db.codes.length);
      const expiresAt = Date.now() + 300e3;
      db.codes.push({ id: `c${db.codes.length}`, phone: p_phone, purpose: p_purpose, code, used: false, expiresAt });
      return { id: `c${db.codes.length - 1}`, code, active: false, expires_at: new Date(expiresAt).toISOString() };
    },
    ex_auth_code_check: ({ p_phone, p_purpose, p_code }) => {
      if (lock(`phone:${p_phone}`)) return { ok: false, reason: 'locked', locked_until: lock(`phone:${p_phone}`) };
      const c = db.codes.filter(x => x.phone === p_phone && x.purpose === p_purpose && !x.used).at(-1);
      if (!c) return { ok: false, reason: 'expired' };
      if (c.code !== p_code) { const f = failKey(`phone:${p_phone}`); return f.locked_until ? { ok: false, reason: 'locked', locked_until: f.locked_until } : { ok: false, reason: 'wrong', attempts_left: f.attempts_left }; }
      c.used = true;
      if (p_purpose === 'reset') { c.grant = 'grant-' + c.id; return { ok: true, grant: c.grant }; }
      return { ok: true, grant: null };
    },
    ex_auth_reset_grant_use: ({ p_phone, p_grant }) => { const c = db.codes.find(x => x.phone === p_phone && x.grant && x.grant === p_grant); if (!c) return false; c.grant = null; return true; },
    ex_auth_password_set: ({ p_user, p_password }) => { db.passwords.set(p_user, p_password); return null; },
    ex_auth_password_ok: ({ p_user, p_password }) => db.passwords.get(p_user) === p_password,
    ex_auth_device_add: ({ p_user }) => { const t = 'd'.repeat(40) + db.devices.size; db.devices.set(t, p_user); return t; },
    ex_auth_device_ok: ({ p_user, p_token }) => db.devices.get(p_token) === p_user,
    ex_auth_sign_out_everywhere: ({ p_user }) => { for (const [t, u] of db.devices) if (u === p_user) db.devices.delete(t); return null; },
    ex_account_phone_taken: ({ p_phone }) => taken(p_phone, null),
    ex_account_phone_status: ({ p_user, p_phone }) => phoneStatus(p_user, p_phone),
    ex_account_phone_set: ({ p_user, p_phone }) => {
      const s = phoneStatus(p_user, p_phone);
      if (!s.ok) return { __error: 'PHONE_' + s.reason.toUpperCase() };
      db.profiles.set(p_user, { ...(db.profiles.get(p_user) || {}), phone: p_phone, verified: true, changedAt: Date.now() });
      return { ok: true, phone: p_phone, changed_at: new Date().toISOString(), available_at: new Date(Date.now() + 30 * DAY).toISOString() };
    },
    ex_auth_email_code_expiry: () => db.liveEmail || null,
    ex_auth_resolve: ({ p_identifier }) => {
      const id = String(p_identifier).toLowerCase(); let user = null;
      const byProfile = test => { const hit = [...db.profiles.entries()].find(([, p]) => test(p)); return hit ? db.users.get(hit[0]) : null; };
      if (id.startsWith('+964')) {
        user = byProfile(p => p.phone === '0' + id.slice(4) && p.verified) || [...db.users.values()].find(u => u.email === `p${id.slice(1)}@phone.proxobalance.app`);
      } else {
        user = [...db.users.values()].find(u => u.email === id && !u.email.endsWith('@phone.proxobalance.app')) || byProfile(p => p.email === id && p.emailVerified);
      }
      return user ? { user_id: user.id, auth_email: user.email, own_password: db.passwords.has(user.id) } : null;
    },
    ex_account_email_status: ({ p_user, p_email }) => {
      if (!/^[a-z0-9._%+-]+@gmail\.com$/.test(p_email)) return { ok: false, reason: 'invalid' };
      const p = db.profiles.get(p_user) || {};
      if (p.email === p_email && p.emailVerified) return { ok: false, reason: 'same' };
      const taken = [...db.profiles.entries()].some(([id, x]) => id !== p_user && x.email === p_email && x.emailVerified)
        || [...db.users.values()].some(u => u.id !== p_user && u.email === p_email);
      return taken ? { ok: false, reason: 'taken' } : { ok: true };
    },
    ex_account_email_set: ({ p_user, p_email }) => { db.profiles.set(p_user, { ...(db.profiles.get(p_user) || {}), email: p_email, emailVerified: true }); return { ok: true, email: p_email }; },
    ex_auth_email_grant_issue: ({ p_email }) => { const g = 'eg-' + p_email + '-' + db.codes.length; db.emailGrants = db.emailGrants || new Map(); db.emailGrants.set(g, p_email); return g; },
    ex_auth_email_grant_use: ({ p_email, p_grant }) => { const ok = db.emailGrants?.get(p_grant) === p_email; if (ok) db.emailGrants.delete(p_grant); return ok; },
    ex_verify_otp: ({ p_email, p_code }) => {
      if (lock(`email:${p_email}`)) return false;
      const c = db.emailCodes.filter(x => x.email === p_email && !x.used).at(-1);
      if (!c || c.code !== p_code) { failKey(`email:${p_email}`); return false; }
      c.used = true; return true;
    }
  };
  const session = user => { db.sessions += 1; db.tokens.set('at' + db.sessions, user.id); return { access_token: 'at' + db.sessions, refresh_token: 'rt' + db.sessions, expires_in: 3600, user: { id: user.id, email: user.email } }; };
  const reply = (status, body) => new Response(status === 204 || body === undefined ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

  globalThis.fetch = async (url, options = {}) => {
    const u = String(url); const body = options.body ? JSON.parse(options.body) : {};
    if (u.includes('/rest/v1/rpc/')) {
      const name = u.split('/rpc/')[1];
      const out = rpcs[name]?.(body);
      if (out && out.__error) return reply(400, { message: out.__error, details: null });
      return reply(200, out ?? null);
    }
    if (u.includes('/rest/v1/ex_profiles')) {
      db.profilePatch = body;
      const id = u.split('id=eq.')[1];
      if (id && body.phone) db.profiles.set(id, { ...(db.profiles.get(id) || {}), phone: body.phone, verified: !!body.phone_verified_at, changedAt: null });
      return reply(204);
    }
    if (u.endsWith('/auth/v1/user')) {
      const id = db.tokens.get(String(options.headers?.Authorization || '').replace('Bearer ', ''));
      const user = id && db.users.get(id);
      return user ? reply(200, { id: user.id, email: user.email }) : reply(401, { msg: 'invalid token' });
    }
    if (/\/auth\/v1\/admin\/users\/[^/]+$/.test(u) && options.method === 'PUT') {
      const user = db.users.get(u.split('/').pop());
      if (body.email) user.email = body.email;
      if (body.password) user.password = body.password;
      return reply(200, { id: user.id, email: user.email });
    }
    if (u.startsWith('https://api.wevlix.com/')) { db.sent.push(body); return reply(200, { success: true, data: { messageId: 'm1' } }); }
    if (u.includes('webhook/otp_exchange')) { db.emailCodes.push({ email: body.email, code: '777777' }); return reply(200, { success: true }); }
    if (u.includes('/auth/v1/admin/users')) {
      const id = 'u' + (db.users.size + 1); db.users.set(id, { id, email: body.email, password: body.password, meta: body.user_metadata });
      return reply(200, { id, email: body.email });
    }
    if (u.includes('/auth/v1/admin/generate_link')) { const user = [...db.users.values()].find(x => x.email === body.email); return reply(200, { properties: { hashed_token: 'h:' + user.id } }); }
    if (u.includes('/auth/v1/verify')) { const user = db.users.get(body.token_hash.slice(2)); return reply(200, session(user)); }
    if (u.includes('/auth/v1/token?grant_type=password')) {
      const user = [...db.users.values()].find(x => x.email === body.email && x.password === body.password);
      return user ? reply(200, session(user)) : reply(400, { error: 'invalid_grant' });
    }
    if (u.includes('/auth/v1/logout')) return reply(204);
    if (u.includes('rpc/ex_record_app_error') || u.includes('ex_error_logs')) { db.lastError = body; return reply(200, null); }
    throw new Error('unexpected fetch ' + u);
  };
  async function call(payload, headers = {}) {
    const res = { statusCode: 0, headers: {}, setHeader(k, v) { this.headers[k] = v; }, end(text) { this.body = text ? JSON.parse(text) : null; } };
    await handler({ method: 'POST', url: '/api/auth', headers: { 'user-agent': 'test', ...headers }, body: payload, socket: { remoteAddress: '1.2.3.4' } }, res);
    return { status: res.statusCode, ...res.body };
  }
  return { db, call };
}

test('only Iraqi mobile numbers are accepted', () => {
  assert.equal(normalizeIraqiPhone('0750 123 4567'), '+9647501234567');
  assert.equal(normalizeIraqiPhone('٠٧٧٠١٢٣٤٥٦٧'), '+9647701234567');
  assert.equal(normalizeIraqiPhone('+964 780 111 2233'), '+9647801112233');
  assert.equal(normalizeIraqiPhone('009647901112233'), '+9647901112233');
  for (const bad of ['07201234567', '+15551234567', '0750123', '07501234567 8', 'abc']) assert.equal(normalizeIraqiPhone(bad), null, bad);
  assert.equal(phoneEmail('+9647501234567'), 'p9647501234567@phone.proxobalance.app');
});

test('sign-up with a number: WhatsApp code (proxo_otp), then a session; no e-mail asked', async () => {
  const { db, call } = backend();
  const bad = await call({ action: 'signup_start', phone: '+15551234567', name: 'Zana Ahmed', password: 'longpassword' });
  assert.equal(bad.status, 400); assert.equal(bad.code, 'PHONE_INVALID');
  const start = await call({ action: 'signup_start', phone: '0750 123 4567', name: 'Zana Ahmed', password: 'longpassword' });
  assert.equal(start.status, 200); assert.equal(start.channel, 'whatsapp'); assert.equal(start.target, '0750•••4567');
  assert.equal(db.sent[0].templateId, 'fcb360b0-6bee-499c-990b-8fc181dccfbd');
  assert.equal(db.sent[0].to, '+9647501234567');
  const code = db.sent[0].components[0].parameters[0].text;
  assert.equal(db.sent[0].components[1].parameters[0].text, code);   // copy-code button
  const done = await call({ action: 'signup_finish', phone: '07501234567', name: 'Zana Ahmed', password: 'longpassword', code, remember: true });
  assert.equal(done.status, 200, JSON.stringify(db.lastError || done)); assert.ok(done.session.access_token); assert.ok(done.device_token);
  const user = [...db.users.values()][0];
  assert.equal(user.email, 'p9647501234567@phone.proxobalance.app');
  assert.notEqual(user.password, 'longpassword');                     // Auth never holds the real password
  assert.equal(db.passwords.get(user.id), 'longpassword');
  const { phone_verified_at, ...patch } = db.profilePatch;
  assert.deepEqual(patch, { full_name: 'Zana Ahmed', phone: '07501234567', email: null });
  assert.ok(phone_verified_at);                                         // the code proved the number
  const again = await call({ action: 'signup_start', phone: '07501234567', name: 'Zana Ahmed', password: 'longpassword' });
  assert.equal(again.status, 409);
});

test('number login: password + code; a remembered device skips the code', async () => {
  const { db, call } = backend();
  const s = await call({ action: 'signup_start', phone: '07701112233', name: 'Rekar Ali', password: 'longpassword' });
  assert.equal(s.status, 200);
  await call({ action: 'signup_finish', phone: '07701112233', name: 'Rekar Ali', password: 'longpassword', code: db.sent.at(-1).components[0].parameters[0].text });
  const start = await call({ action: 'login_start', identifier: '0770 111 2233', password: 'longpassword' });
  assert.equal(start.otp_required, true); assert.equal(start.session, undefined);
  const done = await call({ action: 'login_finish', identifier: '07701112233', password: 'longpassword', code: db.sent.at(-1).components[0].parameters[0].text, remember: true });
  assert.ok(done.session.access_token); assert.ok(done.device_token);
  const fast = await call({ action: 'login_start', identifier: '07701112233', password: 'longpassword', device_token: done.device_token });
  assert.ok(fast.session.access_token); assert.equal(fast.otp_required, undefined);
  const wrongDevice = await call({ action: 'login_start', identifier: '07701112233', password: 'longpassword', device_token: 'x'.repeat(40) });
  assert.equal(wrongDevice.otp_required, true);
});

test('3 wrong passwords block the number for 24 hours (even with the right password)', async () => {
  const { db, call } = backend();
  await call({ action: 'signup_start', phone: '07801112233', name: 'Sara Omar', password: 'longpassword' });
  await call({ action: 'signup_finish', phone: '07801112233', name: 'Sara Omar', password: 'longpassword', code: db.sent.at(-1).components[0].parameters[0].text });
  const a = await call({ action: 'login_start', identifier: '07801112233', password: 'wrong-1' });
  assert.equal(a.status, 401); assert.equal(a.attempts_left, 2);
  await call({ action: 'login_start', identifier: '07801112233', password: 'wrong-2' });
  const c = await call({ action: 'login_start', identifier: '07801112233', password: 'wrong-3' });
  assert.equal(c.status, 423); assert.ok(c.locked_until);
  const right = await call({ action: 'login_start', identifier: '07801112233', password: 'longpassword' });
  assert.equal(right.status, 423);
});

test('3 wrong codes block the number for 24 hours', async () => {
  const { db, call } = backend();
  await call({ action: 'signup_start', phone: '07901112233', name: 'Aras Kamal', password: 'longpassword' });
  for (const code of ['000001', '000002']) assert.equal((await call({ action: 'signup_finish', phone: '07901112233', name: 'Aras Kamal', password: 'longpassword', code })).status, 401);
  const third = await call({ action: 'signup_finish', phone: '07901112233', name: 'Aras Kamal', password: 'longpassword', code: '000003' });
  assert.equal(third.status, 423);
  assert.equal(db.users.size, 0);
});

test('forgot password by number: code → new password → signed in at once', async () => {
  const { db, call } = backend();
  await call({ action: 'signup_start', phone: '07501112233', name: 'Lana Jalal', password: 'oldpassword1' });
  await call({ action: 'signup_finish', phone: '07501112233', name: 'Lana Jalal', password: 'oldpassword1', code: db.sent.at(-1).components[0].parameters[0].text, remember: true });
  assert.equal(db.devices.size, 1);
  assert.equal((await call({ action: 'reset_start', phone: '07509999999' })).status, 404);
  await call({ action: 'reset_start', phone: '07501112233' });
  const v = await call({ action: 'reset_verify', phone: '07501112233', code: db.sent.at(-1).components[0].parameters[0].text });
  assert.ok(v.grant);
  const done = await call({ action: 'reset_finish', phone: '07501112233', grant: v.grant, password: 'newpassword1' });
  assert.ok(done.session.access_token);
  assert.equal(db.devices.size, 0);                                      // every remembered device forgotten
  assert.equal((await call({ action: 'reset_finish', phone: '07501112233', grant: v.grant, password: 'again12345' })).status, 410);
  const user = [...db.users.values()][0];
  assert.equal(db.passwords.get(user.id), 'newpassword1');
});

test('e-mail accounts (Gmail only): password + e-mail code, same 24-hour block', async () => {
  const { db, call } = backend();
  db.users.set('e1', { id: 'e1', email: 'old@gmail.com', password: 'emailpass1' });
  const notGmail = await call({ action: 'login_start', identifier: 'someone@yahoo.com', password: 'emailpass1' });
  assert.equal(notGmail.status, 400); assert.equal(notGmail.code, 'EMAIL_NOT_GMAIL');
  const start = await call({ action: 'login_start', identifier: 'Old@Gmail.com', password: 'emailpass1' });
  assert.equal(start.channel, 'email'); assert.equal(start.target, 'o•••@gmail.com');
  const done = await call({ action: 'login_finish', identifier: 'old@gmail.com', password: 'emailpass1', code: '777777' });
  assert.ok(done.session.access_token);
  for (let i = 0; i < 2; i += 1) assert.equal((await call({ action: 'login_start', identifier: 'old@gmail.com', password: 'nope' })).status, 401);
  assert.equal((await call({ action: 'login_start', identifier: 'old@gmail.com', password: 'nope' })).status, 423);
});

async function signedUpNumber(db, call, phone, password = 'longpassword') {
  await call({ action: 'signup_start', phone, name: 'Test Person', password });
  const done = await call({ action: 'signup_finish', phone, name: 'Test Person', password, code: db.sent.at(-1).components[0].parameters[0].text });
  return { token: done.session.access_token, id: done.session.user.id };
}

test('change number: password, then a WhatsApp code to the NEW number; once every 30 days', async () => {
  const { db, call } = backend();
  const { token, id } = await signedUpNumber(db, call, '07501234567');
  const auth = { authorization: `Bearer ${token}` };
  assert.equal((await call({ action: 'phone_change_start', phone: '07701234567', password: 'longpassword' })).status, 401);   // signed in only
  const wrong = await call({ action: 'phone_change_start', phone: '07701234567', password: 'nope' }, auth);
  assert.equal(wrong.status, 401); assert.equal(wrong.attempts_left, 2);
  const same = await call({ action: 'phone_change_start', phone: '07501234567', password: 'longpassword' }, auth);
  assert.equal(same.code, 'PHONE_SAME');
  const foreign = await call({ action: 'phone_change_start', phone: '+15551234567', password: 'longpassword' }, auth);
  assert.equal(foreign.code, 'PHONE_INVALID');
  const sentBefore = db.sent.length;
  const start = await call({ action: 'phone_change_start', phone: '0770 123 4567', password: 'longpassword' }, auth);
  assert.equal(start.status, 200, JSON.stringify(start)); assert.equal(start.channel, 'whatsapp');
  assert.equal(db.sent.length, sentBefore + 1); assert.equal(db.sent.at(-1).to, '+9647701234567');   // the new number
  assert.equal((await call({ action: 'phone_change_finish', phone: '07701234567', code: '000000' }, auth)).status, 401);
  const done = await call({ action: 'phone_change_finish', phone: '07701234567', code: db.sent.at(-1).components[0].parameters[0].text }, auth);
  assert.equal(done.status, 200, JSON.stringify(done)); assert.equal(done.phone, '07701234567'); assert.equal(done.sign_in_changed, true);
  assert.equal(db.users.get(id).email, 'p9647701234567@phone.proxobalance.app');                   // signs in with the new number
  assert.deepEqual({ phone: db.profiles.get(id).phone, verified: db.profiles.get(id).verified }, { phone: '07701234567', verified: true });
  const login = await call({ action: 'login_start', identifier: '07701234567', password: 'longpassword' });
  assert.equal(login.otp_required, true);
  const again = await call({ action: 'phone_change_start', phone: '07801234567', password: 'longpassword' }, auth);
  assert.equal(again.status, 409); assert.equal(again.code, 'PHONE_COOLDOWN'); assert.ok(again.available_at);
});

test('one number, one account: a verified number cannot be taken or signed up again', async () => {
  const { db, call } = backend();
  await signedUpNumber(db, call, '07501112299');
  db.users.set('e9', { id: 'e9', email: 'mail@gmail.com', password: 'emailpass1' });
  db.profiles.set('e9', { phone: '07801112299', verified: true, changedAt: null });                  // e-mail account with a verified number
  const { token } = await signedUpNumber(db, call, '07701112299');
  const sent = db.sent.length;
  const takeIt = await call({ action: 'phone_change_start', phone: '07501112299', password: 'longpassword' }, { authorization: `Bearer ${token}` });
  assert.equal(takeIt.code, 'PHONE_TAKEN'); assert.equal(db.sent.length, sent);                         // no code is sent
  const signup = await call({ action: 'signup_start', phone: '07801112299', name: 'Other Person', password: 'longpassword' });
  assert.equal(signup.status, 409); assert.equal(signup.code, 'PHONE_TAKEN');
});

test('change password: current password checked, other devices signed out, this one gets a new session', async () => {
  const { db, call } = backend();
  db.users.set('e1', { id: 'e1', email: 'me@gmail.com', password: 'emailpass1' });
  db.devices.set('t'.repeat(40), 'e1');
  const session = await call({ action: 'login_finish', identifier: 'me@gmail.com', password: 'emailpass1', code: (await call({ action: 'login_start', identifier: 'me@gmail.com', password: 'emailpass1' }), '777777') });
  const auth = { authorization: `Bearer ${session.session.access_token}` };
  assert.equal((await call({ action: 'password_change', current: 'emailpass1', password: 'short' }, auth)).code, 'PASSWORD_SHORT');
  assert.equal((await call({ action: 'password_change', current: 'emailpass1', password: 'emailpass1' }, auth)).code, 'PASSWORD_SAME');
  const wrong = await call({ action: 'password_change', current: 'nope', password: 'brandnew123' }, auth);
  assert.equal(wrong.status, 401); assert.equal(wrong.attempts_left, 2);
  const done = await call({ action: 'password_change', current: 'emailpass1', password: 'brandnew123' }, auth);
  assert.equal(done.status, 200, JSON.stringify(done)); assert.ok(done.session.access_token);
  assert.equal(db.users.get('e1').password, 'brandnew123'); assert.equal(db.devices.size, 0);

  const num = await signedUpNumber(db, call, '07501234500', 'firstpass1');
  const n = await call({ action: 'password_change', current: 'firstpass1', password: 'secondpass2' }, { authorization: `Bearer ${num.token}` });
  assert.equal(n.status, 200); assert.equal(db.passwords.get(num.id), 'secondpass2'); assert.ok(n.session.access_token);
});

test('a number account adds a Gmail address (code to the new address) and can then sign in with either', async () => {
  const { db, call } = backend();
  const { token, id } = await signedUpNumber(db, call, '07501230001');
  const auth = { authorization: `Bearer ${token}` };
  assert.equal((await call({ action: 'email_change_start', email: 'me@yahoo.com', password: 'longpassword' }, auth)).code, 'EMAIL_NOT_GMAIL');
  assert.equal((await call({ action: 'email_change_start', email: 'me@gmail.com', password: 'wrong' }, auth)).status, 401);
  const start = await call({ action: 'email_change_start', email: 'Me@Gmail.com', password: 'longpassword' }, auth);
  assert.equal(start.status, 200, JSON.stringify(start)); assert.equal(start.channel, 'email');
  assert.equal(db.emailCodes.at(-1).email, 'me@gmail.com');
  const done = await call({ action: 'email_change_finish', email: 'me@gmail.com', code: '777777' }, auth);
  assert.equal(done.status, 200, JSON.stringify(done)); assert.equal(done.sign_in_changed, false);
  assert.equal(db.users.get(id).email, 'p9647501230001@phone.proxobalance.app');             // number sign-in untouched
  // sign in with the e-mail: same password, code by e-mail, same account
  const s1 = await call({ action: 'login_start', identifier: 'me@gmail.com', password: 'longpassword' });
  assert.equal(s1.channel, 'email', JSON.stringify(s1));
  const s2 = await call({ action: 'login_finish', identifier: 'me@gmail.com', password: 'longpassword', code: '777777' });
  assert.equal(s2.session.user.id, id);
  // forgot password by e-mail works for this number account too
  await call({ action: 'reset_start', identifier: 'me@gmail.com' });
  const v = await call({ action: 'reset_verify', identifier: 'me@gmail.com', code: '777777' });
  assert.ok(v.grant, JSON.stringify(v));
  const r = await call({ action: 'reset_finish', identifier: 'me@gmail.com', grant: v.grant, password: 'brandnew99' });
  assert.equal(r.status, 200, JSON.stringify(r)); assert.equal(r.session.user.id, id); assert.equal(db.passwords.get(id), 'brandnew99');
  assert.equal((await call({ action: 'reset_finish', identifier: 'me@gmail.com', grant: v.grant, password: 'again12345' })).status, 410);
});

test('an e-mail account with a verified number signs in with the number; its address change moves the sign-in', async () => {
  const { db, call } = backend();
  db.users.set('e5', { id: 'e5', email: 'old5@gmail.com', password: 'emailpass5' });
  db.profiles.set('e5', { email: 'old5@gmail.com', emailVerified: true, phone: '07701230005', verified: true });
  const s1 = await call({ action: 'login_start', identifier: '07701230005', password: 'emailpass5' });
  assert.equal(s1.channel, 'whatsapp', JSON.stringify(s1));
  const s2 = await call({ action: 'login_finish', identifier: '07701230005', password: 'emailpass5', code: db.sent.at(-1).components[0].parameters[0].text });
  assert.equal(s2.session.user.id, 'e5');
  const auth = { authorization: `Bearer ${s2.session.access_token}` };
  assert.equal((await call({ action: 'email_change_start', email: 'old5@gmail.com', password: 'emailpass5' }, auth)).code, 'EMAIL_SAME');
  await call({ action: 'email_change_start', email: 'new5@gmail.com', password: 'emailpass5' }, auth);
  const done = await call({ action: 'email_change_finish', email: 'new5@gmail.com', code: '777777' }, auth);
  assert.equal(done.sign_in_changed, true); assert.equal(db.users.get('e5').email, 'new5@gmail.com');
  assert.equal((await call({ action: 'login_start', identifier: 'old5@gmail.com', password: 'emailpass5' })).status, 401);
});

test('a new code only after the previous one expired (WhatsApp and e-mail)', async () => {
  const { db, call } = backend();
  const first = await call({ action: 'signup_start', phone: '07501239999', name: 'Test Person', password: 'longpassword' });
  assert.equal(first.status, 200); assert.ok(first.expires_at); assert.equal(first.already_sent, undefined);
  const sent = db.sent.length;
  const again = await call({ action: 'signup_start', phone: '07501239999', name: 'Test Person', password: 'longpassword' });
  assert.equal(again.status, 200); assert.equal(again.already_sent, true); assert.equal(again.expires_at, first.expires_at);
  assert.equal(db.sent.length, sent);                                     // nothing new on WhatsApp
  db.codes.at(-1).expiresAt = Date.now() - 1;                             // the code expires
  const fresh = await call({ action: 'signup_start', phone: '07501239999', name: 'Test Person', password: 'longpassword' });
  assert.equal(fresh.already_sent, undefined); assert.equal(db.sent.length, sent + 1);
  // e-mail: the live code's expiry comes from the database, n8n is not called again
  db.users.set('e7', { id: 'e7', email: 'seven@gmail.com', password: 'emailpass7' });
  db.liveEmail = new Date(Date.now() + 400e3).toISOString();
  const calls = db.emailCodes.length;
  const login = await call({ action: 'login_start', identifier: 'seven@gmail.com', password: 'emailpass7' });
  assert.equal(login.already_sent, true); assert.equal(login.expires_at, db.liveEmail); assert.equal(db.emailCodes.length, calls);
});
