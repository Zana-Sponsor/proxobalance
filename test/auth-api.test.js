import assert from 'node:assert/strict';
import test from 'node:test';

// /api/auth against a fake Supabase (REST + Auth) and a fake Wevlix.
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-test-key';
process.env.WEVLIX_API_KEY = 'wevlix-test-key';
const { default: handler, normalizeIraqiPhone, phoneEmail } = await import('../api-handlers/auth.js');

function backend() {
  const db = { users: new Map(), passwords: new Map(), codes: [], locks: new Map(), devices: new Map(), sent: [], emailCodes: [], sessions: 0 };
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
      const code = String(100000 + db.codes.length);
      db.codes.push({ id: `c${db.codes.length}`, phone: p_phone, purpose: p_purpose, code, used: false });
      return { id: `c${db.codes.length - 1}`, code };
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
    ex_verify_otp: ({ p_email, p_code }) => {
      if (lock(`email:${p_email}`)) return false;
      const c = db.emailCodes.filter(x => x.email === p_email && !x.used).at(-1);
      if (!c || c.code !== p_code) { failKey(`email:${p_email}`); return false; }
      c.used = true; return true;
    }
  };
  const session = user => { db.sessions += 1; return { access_token: 'at' + db.sessions, refresh_token: 'rt' + db.sessions, expires_in: 3600, user: { id: user.id, email: user.email } }; };
  const reply = (status, body) => new Response(status === 204 || body === undefined ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

  globalThis.fetch = async (url, options = {}) => {
    const u = String(url); const body = options.body ? JSON.parse(options.body) : {};
    if (u.includes('/rest/v1/rpc/')) {
      const name = u.split('/rpc/')[1];
      const out = rpcs[name]?.(body);
      if (out && out.__error) return reply(400, { message: out.__error, details: null });
      return reply(200, out ?? null);
    }
    if (u.includes('/rest/v1/ex_profiles')) { db.profilePatch = body; return reply(204); }
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
  assert.deepEqual(db.profilePatch, { full_name: 'Zana Ahmed', phone: '07501234567', email: null });
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

test('e-mail accounts: password + e-mail code, same 24-hour block', async () => {
  const { db, call } = backend();
  db.users.set('e1', { id: 'e1', email: 'old@example.com', password: 'emailpass1' });
  const start = await call({ action: 'login_start', identifier: 'Old@Example.com', password: 'emailpass1' });
  assert.equal(start.channel, 'email'); assert.equal(start.target, 'o•••@example.com');
  const done = await call({ action: 'login_finish', identifier: 'old@example.com', password: 'emailpass1', code: '777777' });
  assert.ok(done.session.access_token);
  for (let i = 0; i < 2; i += 1) assert.equal((await call({ action: 'login_start', identifier: 'old@example.com', password: 'nope' })).status, 401);
  assert.equal((await call({ action: 'login_start', identifier: 'old@example.com', password: 'nope' })).status, 423);
});
