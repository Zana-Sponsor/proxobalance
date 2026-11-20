import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// v57: wallets only from ex_wallets; no OTP page; a ban with a reason; new panel lists;
// a panel page starts clean every time it is opened.
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const sql = read('supabase/migrations/20261120112638_wallet_rules_otp_removal_ban_reason.sql');
const save = read('supabase/migrations/20261120113125_wallet_rules_in_panel_save.sql');
const WALLET_NAMES = /QiCard|Qi Card|Korek|Asiacell|FastPay|ZainCash|Zain Cash|FIB Bank|'FIB'|"FIB"/;

test('database: the two wallet rules are columns of ex_wallets, not names in functions', () => {
  assert.match(sql, /add column if not exists recipient_format text not null default 'phone',\n  add column if not exists sender_phone_required boolean not null default false;/);
  assert.match(sql, /check \(recipient_format in \('phone', 'card'\)\)/);
  assert.match(sql, /then p_value ~ '\^\[0-9\]\{6,32\}\$'\n    else p_value ~ '\^07\[0-9\]\{9\}\$'/);
  assert.match(sql, /'new', \$q\$if exists \(select 1 from public\.ex_wallets w where w\.key = new\.from_method and w\.sender_phone_required\) then\$q\$/);
  assert.match(sql, /'new', \$q\$not public\.ex_wallet_recipient_ok\(new\.wallet_key, new\.phone\)\$q\$/);
  assert.match(sql, /if position\(p ->> 'old' in v_def\) = 0 then raise exception 'wallet rule not found in %', v_fn; end if;/);
  // the panel saves both rules; an edit that leaves them out keeps the old values
  assert.match(save, /recipient_format/);
  assert.match(save, /sender_phone_required/);
  for (const m of [sql, save]) assert.doesNotMatch(m, /ex_rates|rate_value|fee_brackets/);
});

test('database: the OTP functions are gone and the browser cannot check codes', () => {
  for (const fn of ['ex_admin_list_otp', 'ex_admin_update_otp', 'ex_admin_create_otp', 'ex_admin_expire_otp', 'ex_admin_delete_otp'])
    assert.match(sql, new RegExp(`drop function if exists public\\.${fn}\\(`));
  assert.match(sql, /revoke all on function public\.ex_verify_otp\(text, text, text\) from public, anon, authenticated;\ngrant execute on function public\.ex_verify_otp\(text, text, text\) to service_role;/);
  assert.match(sql, /check \(ban_reason is null or char_length\(ban_reason\) <= 300\)/);
});

test('code: no wallet is named in the site, the panel or the order server', () => {
  // every script the site and the panel load, and the server handlers
  const loaded = ['index.html', 'exchange-admin.html'].flatMap(page =>
    [...read(page).matchAll(/<script src="\/?(assets\/js\/[^"?]+\.js)/g)].map(m => m[1]));
  const handlers = readdirSync(new URL('../api-handlers', import.meta.url)).filter(f => /\.m?js$/.test(f)).map(f => 'api-handlers/' + f);
  assert.ok(loaded.includes('assets/js/app.js') && loaded.includes('assets/js/admin.js'));
  for (const file of new Set([...loaded, ...handlers])) assert.doesNotMatch(read(file), WALLET_NAMES, file);
  const app = read('assets/js/app.js');
  assert.doesNotMatch(app, /WALLET_VISUALS|FALLBACK_RATES|CARRIER_SENDER_METHODS|LOGO_B64/);
  assert.match(app, /function needsSenderPhone\(method\)\{ return !!\(WALLET_DATA\[method\] && WALLET_DATA\[method\]\.sender_phone_required\); \}/);
  assert.match(app, /function recipientIsCard\(method\)\{ return !!\(WALLET_DATA\[method\] && WALLET_DATA\[method\]\.recipient_format==='card'\); \}/);
  assert.match(app, /\/\/ An empty table means no wallets — never fall back to a built-in list\./);
  assert.doesNotMatch(read('api-handlers/public.js'), /QiCard|FastPay|fallback feed/i);
});

test('order server: the recipient rule comes from the wallet row', () => {
  const src = read('api-handlers/orders.js');
  assert.match(src, /const WALLET_FIELDS = 'key,is_locked,allow_from,allow_receive,recipient_format,sender_phone_required';/);
  const start = src.indexOf('function validRecipient(');
  const ctx = vm.createContext({});
  vm.runInContext(src.slice(start, src.indexOf('\n}\n', start) + 3) + '\nthis.validRecipient = validRecipient;', ctx);
  const { validRecipient } = ctx;
  assert.equal(validRecipient({ recipient_format: 'card' }, '1234567890123456'), true);
  assert.equal(validRecipient({ recipient_format: 'card' }, '07501234567'), true);
  assert.equal(validRecipient({ recipient_format: 'card' }, '12345'), false);
  assert.equal(validRecipient({ recipient_format: 'card' }, '1234 5678'), false);
  assert.equal(validRecipient({ recipient_format: 'phone' }, '07501234567'), true);
  assert.equal(validRecipient({ recipient_format: 'phone' }, '1234567890123456'), false);
  assert.equal(validRecipient(undefined, '07501234567'), true);
  assert.equal(validRecipient(undefined, '1234567890'), false);
});

test('website and panel: no OTP code anywhere', () => {
  const app = read('assets/js/app.js'), admin = read('assets/js/admin.js'), html = read('exchange-admin.html');
  assert.doesNotMatch(app, /N8N_WEBHOOK|requestOtp|verifyOtpCode|startBanCountdown/);
  assert.doesNotMatch(admin, /ex_admin_(list|update|create|expire|delete)_otp|pageConfig\.otp|otp:\s*\{/);
  assert.doesNotMatch(html, /id="pgOtp"|goPage\('otp'\)|OTP EDIT MODAL|OTP CREATE MODAL/);
  assert.doesNotMatch(read('assets/js/exchange-staff.js'), /'otp'/);
});

test('ban: the reason is saved, shown to the customer, and the screen follows a live change', () => {
  const api = read('api-handlers/admin.js');
  assert.match(api, /async set_ban\(\{ user_id, banned, reason \}, ctx\) \{/);
  assert.match(api, /const why = banned \? \(String\(reason \?\? ''\)\.replace\(\/\\s\+\/g, ' '\)\.trim\(\)\.slice\(0, 300\) \|\| null\) : null;/);
  assert.match(api, /\.update\(\{ is_banned: !!banned, ban_reason: why, banned_at: banned \? new Date\(\)\.toISOString\(\) : null \}\)/);
  const admin = read('assets/js/admin.js');
  assert.match(admin, /await adminApiRequest\('set_ban',\{user_id:id,banned:next,reason\}\);/);
  const app = read('assets/js/app.js');
  assert.match(app, /el\.id='pxBanned'; el\.className='svc-site is-ban';/);
  assert.match(app, /'<h1 id="pxBannedTitle">هەژمارەکەت باندکراوە<\/h1>'/);
  assert.match(app, /\(reason\?'<div><dt>هۆکار<\/dt><dd>'\+escHtml\(reason\)\+'<\/dd><\/div>':''\)/);
  assert.match(app, /select\('is_banned,ban_reason,banned_at'\)\.eq\('id',curUser\.id\)/);
  assert.match(read('assets/js/exchange-customer-features.js'), /\{key:'profile',table:'ex_profiles',filter:'id=eq\.'\+owner,events:\['UPDATE'\],read:\(\)=>typeof checkBanState==='function'\?checkBanState\(\):null\}/);
  const css = read('assets/css/site-pause.css');
  assert.match(css, /\.svc-site\.is-ban/);
});

test('panel lists: one row per record, columns from the room the list has', () => {
  const admin = read('assets/js/admin.js'), html = read('exchange-admin.html'), css = read('assets/css/admin-lists.css');
  assert.match(html, /<link rel="stylesheet" href="assets\/css\/admin-lists\.css\?v=\d+">/);
  assert.match(html, /<input class="lv-search" id="orderSearch"[^>]*oninput="filterOrders\(null,true\)"/);
  assert.match(html, /<input class="lv-search" id="accSearch"[^>]*oninput="filterAccounts\(null,true\)"/);
  assert.match(admin, /return '<div class="lv-list lv-orders">'\+list\.map\(orderRowHTML\)\.join\(''\)\+'<\/div>';/);
  assert.match(admin, /return '<div class="lv-list lv-accounts">'\+list\.map\(accRowHTML\)\.join\(''\)\+'<\/div>';/);
  assert.match(admin, /<div class="lv-end"><div class="lv-c lv-state">/);
  assert.match(css, /\.lv-list \{ container-type: inline-size; \}/);
  assert.match(css, /@container \(min-width: 880px\) \{\n  \.lv-orders \.lv-row \{/);
  assert.match(css, /@container \(min-width: 1060px\) \{\n  \.lv-accounts \.lv-row \{/);
  // the panel theme paints buttons with !important: the ban buttons and the menu use an id
  assert.match(css, /#moBan \.modal-btn\.ban-go-no \{/);
  assert.match(css, /#accountsTableWrap \.lv-menu \.act-btn, #accountsTableWrap \.lv-menu button \{/);
});

test('panel: leaving a page resets it; opening it loads fresh data', () => {
  const admin = read('assets/js/admin.js');
  assert.match(admin, /if\(_curPage&&_curPage!==p\) resetPage\(_curPage\);/);
  assert.match(admin, /if\(p==='orders'\)\{ orderFilter='all'; _ordShown=LIST_STEP; allOrders=\[\];/);
  assert.match(admin, /if\(p==='accounts'\)\{ accFilter='all'; _accShown=LIST_STEP; allAccounts=\[\];/);
  assert.match(admin, /pg\.querySelectorAll\('input\.tbl-search, input\.lv-search'\)/);
  assert.match(admin, /pg\.querySelectorAll\('details\.lv-more\[open\]'\)\.forEach\(d=>d\.removeAttribute\('open'\)\);/);
  // the default chips are noted once the panel opens
  assert.match(admin, /notePageDefaults\(\);\n  loadWalletMeta\(\);\n  goPage\('dashboard'\);/);
});

test('panel pause page: the whole-site card says the state, the message and what is off', () => {
  const js = read('assets/js/exchange-site-pause-admin.js');
  assert.match(js, /if \(site\) \{ site\.innerHTML = siteHTML\(\); site\.classList\.toggle\('is-off', !!row\('site'\)\.paused\); \}/);
  assert.match(js, /'<span class="ps-mark" aria-hidden="true"><i><\/i><i><\/i><\/span>'/);
  assert.match(js, /onchange="toggleSitePause\(\\'site\\', this\)"/);
  assert.match(read('exchange-admin.html'), /exchange-site-pause-admin\.js\?v=4/);
});

test('paused section: one card in light and dark, filling the screen, with "check again" and the way home', () => {
  const js = read('assets/js/site-pause.js'), css = read('assets/css/site-pause.css');
  assert.match(js, /'<span class="svc-note-mark" aria-hidden="true"><i><\/i><i><\/i><\/span>'/);
  assert.match(js, /'<button type="button" class="svc-note-btn is-soft" data-act="check">دووبارە پشکنین<\/button>'/);
  assert.match(js, /load\(\)\.then\(function \(\) \{ setTimeout\(function \(\) \{ btn\.disabled = false;/);
  assert.match(js, /if \(typeof window\.navigate === 'function'\) window\.navigate\('home'\);/);
  assert.match(js, /box\.querySelector\('b'\)\.textContent = TITLES\[key\] \|\| TITLES\.site;/);
  // the card takes the room of the screen's content, between the header and the bottom bar
  assert.match(css, /html body #mainApp \.page\.svc-paused > \.svc-note \{\n  display: flex; flex-direction: column; align-items: center; justify-content: center;\n  min-height: calc\(100dvh - 184px\);/);
  assert.match(css, /\.page\.svc-paused:has\(> \.page-head\) > \.svc-note \{ min-height: calc\(100dvh - 237px\); \}/);
  assert.match(css, /\.svc-note\[data-svc="home"\] \[data-act="home"\] \{ display: none; \}/);
  // light and dark: the same card; the dark values are the app's own
  assert.match(css, /html\[data-theme="dark"\] body \.svc-note, html\[data-theme="dark"\] \.svc-site \{\n  --sv-page: #0b1220; --sv-card: #131c2e; --sv-line: #25324a; --sv-ink: #e8edf6; --sv-text: #a3b1c7;\n  --sv-tone: #3b8cff; --sv-tone-soft: #10223d;\n  --sv-btn: #1c6cff; --sv-btn-press: #1559d6;/);
  assert.match(css, /\.svc-site-mark \{\n  width: 76px; height: 76px; margin: 0 0 24px; border-radius: 24px;/);
  assert.doesNotMatch(css, /#3c2b07|#674c16|--sv-tone-ring/);
  const index = read('index.html');
  assert.match(index, /\/assets\/css\/site-pause\.css\?v=5/);
  assert.match(index, /\/assets\/js\/site-pause\.js\?v=5/);
});

test('dark mode: one palette in every stylesheet; filled buttons one blue; light mode rules untouched', () => {
  const dark = read('assets/css/app-dark.css');
  for (const v of ['--dk-canvas: #0b1220', '--dk-card: #131c2e', '--dk-line: #25324a', '--dk-ink: #e8edf6', '--dk-muted: #a3b1c7', '--dk-fill: #1c6cff', '--dk-bad: #f87171'])
    assert.ok(dark.includes(v), v);
  assert.match(dark, /:is\(\.btn\.btn-primary, \.db-new, \.home-feedback-action, \.sc-picker-go, \.acx-btn, #orderFeedbackSubmit, \.pfx-balance \.bx-btn:not\(\.bx-secondary\)\),\n/);
  assert.match(dark, /\{\n  background: #1c6cff !important; border-color: #1c6cff !important; color: #fff !important;\n\}/);
  assert.match(dark, /#siteHeader \.pxh-link\.on \{ background: #163056 !important; color: #8ab8ff !important; \}/);
  assert.match(dark, /:is\(\.xc-badge, \.quick-amount-btn, \.chip-count, \.pfx-handle, \.pfx-chip\) \{\n  background: #1b2740 !important;/);
  // every colour written in a dark-only rule belongs to the palette (white, alpha and wallet colours aside)
  const PALETTE = new Set(['#0b1220', '#0e1725', '#131c2e', '#1b2740', '#25324a', '#2b3a55', '#3a4a66', '#7d8ba3', '#a3b1c7', '#c4cee0', '#e8edf6',
    '#10223d', '#163056', '#264a73', '#1c6cff', '#1559d6', '#3b8cff', '#8ab8ff', '#5b9dff', '#10301f', '#1f5135', '#22a35a', '#4ade80',
    '#2e2511', '#5a4521', '#d9a03f', '#f7b955', '#3a1816', '#231619', '#6b2a27', '#e5484d', '#c4383c', '#f87171', '#ffffff', '#fff']);
  const sheets = [...read('index.html').matchAll(/href="\/?(assets\/css\/[^"?]+)/g)].map(m => m[1]);
  const off = [];
  for (const f of sheets) {
    const src = read(f).replace(/\/\*[\s\S]*?\*\//g, '');
    for (const m of src.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
      const sel = m[1].replace(/:is\(:not\(\[data-theme=["']?dark["']?\]\),\[data-theme=["']?dark["']?\]\)|:not\(\[data-theme=["']?dark["']?\]\)/g, '');
      const parts = sel.split(',').map(x => x.trim()).filter(Boolean);
      if (!parts.length || !parts.every(x => /\[data-theme=["']?dark["']?\]/.test(x))) continue;
      for (const d of m[2].matchAll(/([\w-]+)\s*:([^;]*)/g)) {
        if (/^--.*(tg|telegram|wa|whatsapp|brand|star|wallet)/i.test(d[1]) || d[1] === '--secondary') continue;   // brand colours; the indigo of the old gradients
        for (const c of d[2].matchAll(/#[0-9a-fA-F]{3,8}\b/g)) if (!PALETTE.has(c[0].toLowerCase())) off.push(f + ' ' + d[1] + ' ' + c[0]);
      }
    }
  }
  assert.deepEqual(off.filter(x => !/(#9333ea|#0891b2|#65a30d|#f59e0b|#ef4444|#16a34a|#22c55e|#f5a524|#ef5350|#f04438)$/i.test(x)), []);
});

test('profile: username and creation date are rows of the account list; verified is a blue rosette, every state the same shape', () => {
  const html = read('index.html'), app = read('assets/js/app.js'), ui = read('assets/css/proxo-ui-v2.css'), dark = read('assets/css/proxo-dark.css');
  const hero = html.slice(html.indexOf('<div class="pfx-hero">'), html.indexOf('<section class="pfx-card pfx-balance"'));
  assert.doesNotMatch(hero, /un-row|pfUsername|pfJoined/);
  const menu = html.slice(html.indexOf('<div class="pfx-menu acx-menu" id="pfAccountMenu"'), html.indexOf('<div class="pfx-menu wa-menu">'));
  assert.match(menu, /<div class="pfx-item un-item" id="pfUsernameRow">/);
  assert.match(menu, /<button type="button" class="pfx-item-txt" id="pfUsernameEdit" onclick="usernameRowTap\(\)"><b>ناوی بەکارهێنەر<\/b><small id="pfMenuUsername">—<\/small><\/button>/);
  assert.match(menu, /<button type="button" class="pfx-item-copy" id="pfUsernameCopy" onclick="copyUsername\(this\)"/);
  assert.match(menu, /<div class="pfx-item pfx-item-static" id="pfJoinedRow">/);
  assert.match(menu, /<b>بەرواری دروستکردن<\/b><small><span id="pfJoined" dir="ltr">—<\/span><\/small>/);
  assert.ok(menu.indexOf('pfMenuName') < menu.indexOf('pfUsernameRow') && menu.indexOf('pfUsernameRow') < menu.indexOf('pfMenuPhone'));
  assert.match(app, /if\(!isNaN\(d\)\) joined\.textContent=d\.getFullYear\(\)\+'\/'\+String\(d\.getMonth\(\)\+1\)\.padStart\(2,'0'\)\+'\/'\+String\(d\.getDate\(\)\)\.padStart\(2,'0'\);/);
  assert.match(app, /function usernameRowTap\(\)\{\n  if\(usernameEditable\(\)\) return openUsernameSheet\(\);/);
  assert.match(app, /tag\.className='acx-edit-tag'; tag\.textContent='گۆڕین';/);
  assert.match(app, /const KYC_SHIELD_PATH='M12 0\.9 12\.9 1\.3 /);
  assert.match(ui, /body :is\(\.kyc-ico, \.pfx-verified\)\[data-tone="ok"\]    \{ --kt: #0265ff;/);
  assert.match(ui, /body :is\(\.kyc-ico, \.pfx-verified\)\[data-tone="wait"\]  \{ --kt: #64748b;/);
  assert.match(ui, /body :is\(\.kyc-badge, \.kyc-card, \.kyc-banner\)\[data-state\] \{ --kyc-c: var\(--kt\); \}/);
  assert.match(ui, /body #mainApp \.pxn-state\[data-state="ok"\] \{ background: #0265ff; \}/);
  assert.match(dark, /\[data-tone="ok"\] \{\n  --kt: #3b8cff !important;/);
});
