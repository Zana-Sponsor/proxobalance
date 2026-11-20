import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// v52: fee by amount set from one simple card, and admin pause switches.
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');

process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-test-key';
process.env.SECURITY_FINGERPRINT_SALT = 'test-fingerprint-salt';
process.env.TRUSTED_PROXY = 'direct';

let paused = [];          // rows ex_site_controls returns
let reads = 0;
const reply = (status, body) => new Response(body === undefined ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
globalThis.fetch = async (url) => {
  const u = String(url);
  if (u.includes('/rest/v1/ex_site_controls')) { reads++; return reply(200, paused); }
  if (u.endsWith('/auth/v1/user')) return reply(200, { id: '44444444-4444-4444-8444-444444444444', email: 'c@gmail.com' });
  if (u.includes('/rpc/')) return reply(200, [{ banned: false }]);
  return reply(200, []);
};
const security = await import('../api-handlers/_lib/security.js');
const { default: supportCases } = await import('../api-handlers/support-cases.js');
const { default: auth } = await import('../api-handlers/auth.js');

async function call(handler, url, body) {
  const res = { statusCode: 0, headers: {}, setHeader(k, v) { this.headers[k] = v; }, end(text) { this.body = text ? JSON.parse(text) : null; } };
  await handler({ method: 'POST', url, headers: { authorization: 'Bearer t', 'user-agent': 'test' }, body, socket: { remoteAddress: '1.2.3.4' } }, res);
  return { status: res.statusCode, ...res.body };
}

test('a paused section answers 423 with the Kurdish title and the admin message; the whole site stops everything', async () => {
  security.resetSectionPauseCache();
  paused = [{ key: 'support', paused: true, message: 'تا بەیانی' }];
  const r = await call(supportCases, '/api/support-cases', { category: 'general', description: 'x'.repeat(30) });
  assert.equal(r.status, 423);
  assert.equal(r.code, 'SECTION_PAUSED');
  assert.equal(r.section, 'support');
  assert.equal(r.error, 'پشتگیری بۆ ماوەیەک ڕاگیراوە. تا بەیانی');

  security.resetSectionPauseCache();
  paused = [{ key: 'site', paused: true, message: null }];
  assert.deepEqual(await security.sectionPaused(['exchange']), { section: 'site', message: null });
  assert.deepEqual(security.pausedBody({ section: 'site', message: null }).error, 'ماڵپەڕەکە بۆ ماوەیەک ڕاگیراوە');
});

test('sign-up, sign-in and account changes each follow their own switch', async () => {
  security.resetSectionPauseCache();
  paused = [{ key: 'signup', paused: true, message: null }];
  const signup = await call(auth, '/api/auth', { action: 'signup_start', phone: '07501234567' });
  assert.equal(signup.status, 423);
  assert.equal(signup.section, 'signup');
  const login = await call(auth, '/api/auth', { action: 'login_start', phone: '07501234567', password: 'x' });
  assert.notEqual(login.status, 423);

  security.resetSectionPauseCache();
  paused = [{ key: 'password', paused: true, message: null }];
  assert.equal((await call(auth, '/api/auth', { action: 'password_change', current: 'a', password: 'b' })).section, 'password');
  assert.notEqual((await call(auth, '/api/auth', { action: 'email_change_start', email: 'x@gmail.com' })).status, 423);
  security.resetSectionPauseCache();
  paused = [{ key: 'delete', paused: true, message: null }];
  assert.equal((await call(auth, '/api/auth', { action: 'verify_password', password: 'a' })).section, 'delete');
});

test('switches are read at most every 10 seconds, and an unreadable table keeps the site open', async () => {
  security.resetSectionPauseCache();
  paused = [];
  reads = 0;
  await security.sectionPaused(['exchange']);
  await security.sectionPaused(['support']);
  assert.equal(reads, 1);
  security.resetSectionPauseCache();
  paused = { message: 'relation "public.ex_site_controls" does not exist' };
  assert.equal(await security.sectionPaused(['exchange']), null);
  // rows that are not real switches are ignored
  security.resetSectionPauseCache();
  paused = [{ key: 'exchange', paused: false }, { key: 'nope', paused: true }, { id: 1 }];
  assert.equal(await security.sectionPaused(['exchange']), null);
});

test('server: every customer action that a switch covers checks it', () => {
  const orders = read('api-handlers/orders.js');
  assert.match(orders, /const paused = await sectionPaused\(balanceSource \? \['exchange', 'balance'\] : \['exchange'\]\);\n  if \(paused\) return json\(res, 423, pausedBody\(paused\)\);/);
  assert.match(read('api-handlers/balance.js'), /if\(action!=='request_payout'\)return json\(res,422,\{error:'Unknown balance action'\}\);\n  const paused=await sectionPaused\(\['balance'\]\);/);
  const authSrc = read('api-handlers/auth.js');
  for (const [action, key] of [['signup_start', 'signup'], ['signup_finish', 'signup'], ['login_start', 'login'], ['reset_finish', 'login'], ['phone_change_start', 'phone'], ['email_change_finish', 'email'], ['password_change', 'password']])
    assert.match(authSrc, new RegExp(`${action}: '${key}'`), action);
  assert.match(read('api-handlers/error-log.js'), /code === 'SECTION_PAUSED'\) return json\(res, 202, \{ ok: true, ignored: true \}\)/);
  const admin = read('api-handlers/admin.js');
  assert.match(admin, /'site_controls','site_control_set','site_schedule_save','site_schedule_delete',[^\]]*\]\.includes\(action\)&&profile\.role!=='super_admin'/);
  assert.match(admin, /db\.rpc\('ex_admin_site_control_set', \{ p_key: key, p_paused: paused, p_message: text, p_admin: ctx\.user\.id \}\)/);
});

test('database: switches are private, the status is public, and only the customer\'s own direct actions are stopped', () => {
  const sql = read('supabase/migrations/20261115154830_site_pause_switches.sql');
  assert.match(sql, /check \(key in \('site', 'exchange', 'balance', 'support', 'verify', 'signup', 'login', 'account'\)\)/);
  assert.match(sql, /revoke all on public\.ex_site_controls, public\.ex_site_control_log from anon, authenticated;/);
  assert.match(sql, /grant execute on function public\.ex_site_status\(\) to anon, authenticated, service_role;/);
  assert.match(sql, /revoke all on function public\.ex_admin_site_control_set\(text, boolean, text, uuid\) from public, anon, authenticated;/);
  assert.match(sql, /if v_uid is null then return new; end if;/);
  assert.match(sql, /if v_owner is distinct from v_uid then return new; end if;/);
  assert.match(sql, /before insert on public\.ex_identity_verifications\s+for each row execute function public\.ex_site_pause_guard\('verify'\);/);
  assert.match(sql, /before insert on public\.ex_account_deletions\s+for each row execute function public\.ex_site_pause_guard\('account'\);/);
  assert.match(sql, /before update of full_name, username on public\.ex_profiles\s+for each row execute function public\.ex_site_pause_guard\('account'\);/);
  assert.doesNotMatch(sql, /ex_rates|rate_value|ex_orders/);
});

test('customer app: notices follow the switches, and a 423 shows at once', () => {
  const js = read('assets/js/site-pause.js');
  const index = read('index.html');
  assert.match(index, /<script src="\/assets\/js\/activity-tracker\.js\?v=1"><\/script>\n<script src="\/assets\/js\/site-pause\.js\?v=\d+"><\/script>/);
  assert.match(index, /<link rel="stylesheet" href="\/assets\/css\/site-pause\.css\?v=\d+">/);
  assert.match(js, /\/rest\/v1\/rpc\/ex_site_status/);
  assert.match(js, /res\.status === 423 && url\.indexOf\('\/api\/'\) !== -1/);
  assert.match(js, /support: \{ key: 'support', form: true \}/);
  assert.match(js, /\{ id: 'authStepName', key: 'signup', buttons: \['signupSubmitBtn'\] \}/);
  assert.match(js, /if \(on && !btn\.disabled\) \{ btn\.disabled = true; btn\.dataset\.svcLocked = '1'; \}/);
});

const j = (x) => JSON.parse(JSON.stringify(x));   // objects from the vm realm
// ── fee by amount ───────────────────────────────────────────────────
function feeTiers(extra = {}) {
  const els = {};
  const el = (id) => els[id] || (els[id] = { id, value: '', innerHTML: '', textContent: '', hidden: false, checked: false });
  const adminSrc = read('assets/js/admin.js');
  const pick = (name) => { const m = adminSrc.match(new RegExp(`function ${name}\\([^]*?\\n\\}`)); return m[0]; };
  const ctx = {
    window: {}, console,
    document: { getElementById: el, querySelector: () => null, querySelectorAll: () => [], addEventListener() {} },
    allRates: [], allWallets: [], METHOD_META: {},
    walletLabelFor: (k) => k, showToast() {}, confirm2() {}, updateAdminRatePreview() {},
    ...extra
  };
  vm.createContext(ctx);
  vm.runInContext(['fmtPct', 'fmtPairValue', 'pairBracketsOfRow', 'pairTierAllowed', 'pairBracketsFromRows'].map(pick).join('\n'), ctx);
  ctx.window = ctx;
  vm.runInContext(read('assets/js/exchange-fee-tiers.js'), ctx);
  return { ctx, el };
}

test('the route editor saves the steps, keeps unchanged ones untouched and removes them when switched off', () => {
  const { ctx, el } = feeTiers();
  const set = (from, to, type, value) => { el('rateFrom').value = from; el('rateTo').value = to; el('rateType').value = type; el('rateValue').value = value; };
  // an old two-step route opens as two rows and saving without a change writes nothing about steps
  const old = { from_method: 'QiCard', to_method: 'FastPay', rate_type: 'fee_percent', rate_value: 2, fee_tier_enabled: true, fee_tier_limit_iqd: 500000, fee_tier_low_percent: 2, fee_tier_high_percent: 1, fee_brackets: null };
  set('QiCard', 'FastPay', 'fee_percent', '2');
  ctx.ftModalOpen(old);
  assert.deepEqual(j(ctx.ftModalPatch(old)), {});
  assert.deepEqual(j(ctx.ftModalBrackets()), [{ up_to: 500000, percent: 2 }, { up_to: null, percent: 1 }]);
  // a fixed fee cannot take steps: they are switched off instead of failing the save
  set('QiCard', 'FastPay', 'fee_fixed', '500');
  assert.deepEqual(j(ctx.ftModalPatch(old)), { fee_brackets: null, fee_tier_enabled: false });
  // USDT never takes steps
  set('FIB', 'USDT', 'fee_percent', '2');
  ctx.ftModalOpen(null);
  assert.deepEqual(j(ctx.ftModalPatch(null)), {});
});

test('the card validates the rows before anything is written', () => {
  let confirmed = null;
  const { ctx } = feeTiers({ confirm2: (t, msg) => { confirmed = msg; } });
  ctx.allRates.push({ id: 'r1', from_method: 'FIB', to_method: 'FastPay', rate_type: 'fee_percent', rate_value: 2, is_active: true });
  ctx.saveFeeTiers();
  assert.equal(confirmed, null);                     // empty rows: nothing is asked or sent
  assert.equal(ctx.feeStepsText([{ up_to: 100000, percent: 1 }, { up_to: null, percent: 0.5 }]),
    'تا ⁦100,000⁩: ⁦1%⁩ · زیاتر: ⁦0.5%⁩');
});

test('panel: the rates page leads with the steps card and lists routes by wallet', () => {
  const html = read('exchange-admin.html');
  assert.match(html, /<section class="ft-card" id="feeTierCard" aria-labelledby="ftTitle">\s*<h3 id="ftTitle">لێبڕین بەپێی بڕ<\/h3>/);
  assert.match(html, /<div class="ft-modal" id="rateTierWrap" hidden><\/div>/);
  assert.match(html, /<script src="assets\/js\/exchange-fee-tiers\.js\?v=1"><\/script><script src="assets\/js\/exchange-site-pause-admin\.js\?v=\d+"><\/script>/);
  assert.match(html, /onclick="goPage\('pause'\)"/);
  const adminJs = read('assets/js/admin.js');
  assert.match(adminJs, /if\(typeof ftModalPatch==='function'\) Object\.assign\(row,ftModalPatch\(prevRate\)\);/);
  assert.match(read('assets/js/exchange-fee-tiers.js'), /sb\.from\('ex_rates'\)\.update\(patch\)\.in\('id', ids\)\.select\('\*'\)/);
  assert.doesNotMatch(read('assets/js/exchange-fee-tiers.js'), /rate_value\s*:/);
  // v57: the OTP page is gone from the panel
  assert.match(read('assets/js/exchange-staff.js'), /\['activity','security','errors','audit','pause'\]\.includes\(page\)\)return isSuperAdmin\(\);/);
  assert.doesNotMatch(read('assets/js/exchange-staff.js'), /'otp'/);
});
