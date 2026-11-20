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

test('panel details: the order, account and identity windows use the lists\' card language', () => {
  const js = read('assets/js/admin.js'), css = read('assets/css/admin-details.css'), html = read('exchange-admin.html');
  assert.match(html, /admin-lists\.css\?v=1">\n<link rel="stylesheet" href="assets\/css\/admin-details\.css\?v=1">/);
  assert.match(js, /function dxGroup\(title, rows, cls\)\{/);
  assert.match(js, /document\.getElementById\('odTitle'\)\.textContent = 'وردەکاری مامەڵە';/);
  assert.match(js, /dxGroup\('بڕ',money\)\+dxGroup\('نێرەر',sender\)\+dxGroup\('وەرگر',receiver\)\+dxGroup\('مامەڵە',facts\)/);
  assert.match(js, /<div class="dx-decide"><button type="button" class="act-btn gr" onclick="approveOrder\('\$\{oid\}'\);closeMo\('moOrderDetail'\)">پەسەندکردن<\/button>/);
  assert.match(js, /<div class="dx-head" id="aiHead"><span class="lv-av" id="aiAv"><\/span>/);
  assert.match(js, /document\.getElementById\('kycRvTitle'\)\.textContent=pending\?'پشکنینی بەڵگەنامە':'بەڵگەنامەی ناسنامە';/);
  assert.match(js, /<div class="dx-decide kyc-rv-actions">/);
  // the same values as admin-lists.css
  assert.match(css, /--dx-ink: #202c3c; --dx-muted: #66768c; --dx-line: #e8edf3;/);
  assert.match(css, /\.act-btn\.gr \{ background: var\(--dx-ok-bg\) !important;/);
  assert.match(css, /html body #pgKyc \.kyc-admin-card \{\n  --kc-edge: #0b6bcb;/);
});

test('profile head: the photo, the name with the identity mark after it, the number; one font in every window', () => {
  const html = read('index.html'), css = read('assets/css/profile-head.css');
  const hero = html.slice(html.indexOf('<div class="pfx-hero">'), html.indexOf('<section class="pfx-card pfx-balance"'));
  assert.doesNotMatch(hero, /pfx-cover|pfx-avatar-wrap|pfKycBadge|pfx-meta/);
  assert.match(hero, /<div class="pfx-name-row">\n\s*<div class="pfx-name" id="pfNameLbl">/);
  assert.match(hero, /<span class="pfx-verified" id="pfVerifiedDot" hidden/);
  assert.match(hero, /<div class="pfx-email" id="pfEmailLbl" dir="ltr">/);
  assert.match(html, /\/assets\/css\/banners\.css\?v=2">\n<link rel="stylesheet" href="\/assets\/css\/profile-head\.css\?v=1">/);
  assert.match(css, /html:has\(#mainApp\) \{ font-family: Rabar, Arial, sans-serif; \}/);
  assert.match(css, /\.pfx-hero \.pfx-verified \{\n  position: static !important;/);
  assert.match(css, /\.pfx-menu > \.pfx-item \{ border-radius: 0 !important; \}/);
  assert.match(css, /html\[data-theme="dark"\] body #usernameSheet \{\n  --un-ink: #e8edf6;/);
});

test('exchange screen: one card per step on the identity screen\'s values, and its bar while sending', () => {
  const html = read('index.html'), css = read('assets/css/exchange-form.css'), app = read('assets/js/app.js');
  // the top is the inner screens' toolbar: back, the title alone, no line under it
  assert.match(html, /<section class="page" id="pageHome" data-route="exchange">\n\s*<div class="pfx-bar"><button type="button" class="pfx-bar-btn" onclick="navigate\('home'\)" aria-label="گەڕانەوە بۆ سەرەکی">/);
  assert.match(html, /<h2>ئاڵوگۆڕی نوێ<\/h2><span aria-hidden="true"><\/span><\/div>/);
  assert.doesNotMatch(html, /class="page-head support-page-head ex-head"/);
  // the bar sits under the button, the same markup as #kycProgress
  assert.match(html, /<div class="kv-progress xc-progress" id="orderProgress" hidden aria-live="polite">\n\s*<div class="kv-progress-track"><span id="orderProgressFill"><\/span><\/div>\n\s*<small id="orderProgressText">/);
  assert.match(html, /\/assets\/css\/profile-head\.css\?v=1">\n<link rel="stylesheet" href="\/assets\/css\/exchange-form\.css\?v=5">/);
  // the site header steps aside on phones, as on every inner screen; wide screens keep it
  assert.match(css, /html body #mainApp:has\(#pageHome\.active\) #siteHeader\.pxh \{ display: none !important; \}\n@media \(min-width: 1024px\) \{\n  html body #mainApp:has\(#pageHome\.active\) #siteHeader\.pxh \{ display: block !important; \}/);
  // and the same values as kyc-screen.css's .kv-progress
  assert.match(css, /\.xc-progress \.kv-progress-track \{ height: 6px; overflow: hidden; border-radius: 999px; background: var\(--xf-line\); \}/);
  assert.match(css, /\.xc-progress \.kv-progress-track span \{ display: block; width: 0; height: 100%; border-radius: inherit; background: var\(--xf-accent\); transition: width \.3s ease; \}/);
  assert.match(app, /function orderSetProgress\(pct, text\)\{/);
  for (const step of ["orderSetProgress(6,'پشکنینی هەژمار...')", "orderSetProgress(32,'بارکردنی پسووڵە...')", "orderSetProgress(78,'ناردنی داواکاری...')", "orderSetProgress(100,'تەواو بوو')"])
    assert(app.includes(step), step);
  assert.match(app, /setTimeout\(\(\)=>\{ if\(btn\.dataset\.submitting!=='1'\) orderSetProgress\(null\); \}, 900\);/);
  // what the app hides stays hidden under the new cards
  assert.match(css, /:is\(\.xc-step, #xcBreakdown, \.xc-sum-row, \.xc-badge, \.field\)\[hidden\]:not\(#_shown\) \{ display: none !important; \}/);
  assert.match(css, /#exchangeCard\.kyc-locked > :not\(\.xc-head\):not\(#exchangeKycGate\):not\(#balanceSendSection\) \{ display: none !important; \}/);
  // the number hint no longer names a country
  assert.doesNotMatch(app, /ژمارەی عێراقی/);
});

test('sign-in, sign-up and the code screen: the identity screen\'s bar under the button while it works', () => {
  const html = read('index.html'), css = read('assets/css/auth-progress.css'), app = read('assets/js/app.js');
  for (const [btn, id] of [['id="authBtn" onclick="submitLogin()"', 'authProgress'], ['id="signupSubmitBtn" onclick="submitSignup()"', 'signupProgress'], ['id="otpVerifyBtn" onclick="verifyOtp()"', 'otpProgress']]) {
    const at = html.indexOf(btn);
    assert(at > 0, btn);
    const after = html.slice(at, at + 700);
    assert.match(after, new RegExp(`</button>\\n\\s*<div class="kv-progress au-progress" id="${id}" hidden aria-live="polite">\\n\\s*<div class="kv-progress-track"><span></span></div>\\n\\s*<small>`), id);
  }
  assert.match(html, /\/assets\/css\/exchange-form\.css\?v=5">\n<link rel="stylesheet" href="\/assets\/css\/auth-progress\.css\?v=1">/);
  // kyc-screen.css's .kv-progress, value for value, on the sign-in screen's tokens
  assert.match(css, /\.au-progress \.kv-progress-track \{ height: 6px; overflow: hidden; border-radius: 999px; background: var\(--au-line\); \}/);
  assert.match(css, /\.au-progress \.kv-progress-track span \{ display: block; width: 0; height: 100%; border-radius: inherit; background: var\(--au-accent\); transition: width \.3s ease; \}/);
  assert.match(css, /\.au-progress\[hidden\] \{ display: none !important; \}/);
  assert.match(app, /function authSetProgress\(id,pct,text\)\{/);
  for (const step of ["authSetProgress('authProgress',35,'پشتڕاستکردنەوەی هەژمار...')", "authSetProgress('signupProgress',40,'ناردنی کۆدی دڵنیایی...')", "authSetProgress('otpProgress',60,'چوونەژوورەوە...')", "authSetProgress('otpProgress',85,'ئامادەکردنی هەژمار...')"])
    assert(app.includes(step), step);
  // the bar never outlives the attempt: each one ends by hiding it
  for (const id of ['authProgress', 'signupProgress', 'otpProgress'])
    assert(app.includes(`authSetProgress('${id}',null);`), id);
});

test('home: «داواکاری نوێ بکە!» types over the new-order card once the app opens, and is gone after 5 seconds', () => {
  const html = read('index.html'), css = read('assets/css/dashboard.css'), app = read('assets/js/app.js');
  // inside the card, so a tap on it opens the exchange; hidden from screen readers (the card already says it)
  const card = html.slice(html.indexOf('id="dbNewOrder"'), html.indexOf('</button>', html.indexOf('id="dbNewOrder"')));
  assert.match(card, /<span class="db-new-tip" id="dbNewTip" aria-hidden="true" hidden>/);
  assert.match(card, /<span class="db-new-tip-txt"><span>داواکاری نوێ بکە!<\/span><\/span>/);
  assert.match(html, /\/assets\/css\/dashboard\.css\?v=10"/);
  // types, says, goes: 5 s from the moment it appears
  assert.match(app, /if\(!calm\) later\(\(\)=>\{ tip\.dataset\.state='say'; \},1100\);\n\s*later\(\(\)=>\{ tip\.dataset\.state='out'; \},4700\);\n\s*later\(dbNewTipStop,5000\);/);
  // once per opening of the app, only on home, never over a sheet or while the exchange is paused
  assert.match(app, /if\(route==='home'\)\{[\s\S]*?dbNewTip\(\);\n\s*\} else dbNewTipStop\(\);/);
  assert.match(app, /document\.querySelector\('\.sheet-overlay\.open, #notifPanel\.open'\)/);
  assert.match(app, /getElementById\('pageHome'\)\?\.classList\.contains\('svc-paused'\)/);
  // on the card's top edge (20px above, 8px on it), so it never reaches the name 36px above the card
  assert.match(css, /position: absolute; z-index: 3; right: 10px; bottom: calc\(100% - 8px\);/);
  assert.match(css, /\.db-new-tip-b \{\n  position: relative; display: flex; align-items: center; height: 28px;/);
  assert.match(css, /@keyframes dbTipFloat \{ 0%, 100% \{ transform: translateY\(0\); \} 50% \{ transform: translateY\(-2px\); \} \}/);
  // the tail sits over the + and the motion respects reduced motion
  assert.match(css, /\.db-new-tip-b::after \{\n  content: ""; position: absolute; right: 19px;/);
  assert.match(css, /@media \(prefers-reduced-motion: reduce\) \{\n  html body #mainApp#mainApp #pageDash \.db-new-tip\[data-state\] \{ animation: none; \}/);
});

test('exchange: «بۆچی بڕێک دەخرێتە سەر باڵانسەکەت؟» — the amount, then plain sentences shared with the summary, in the exchange sheets\' frame', () => {
  const html = read('index.html'), css = read('assets/css/exchange-form.css'), app = read('assets/js/app.js');
  const sheet = html.slice(html.indexOf('<div id="roundingInfoSheet"'), html.indexOf('<!-- ══', html.indexOf('<div id="roundingInfoSheet"')));
  assert.match(sheet, /<b class="ri-amount" id="roundingInfoAmount" dir="ltr" hidden><\/b>/);
  // sentences, not icons: no icon in the sheet's body, the text comes from one function
  assert.match(sheet, /<h3 id="roundingInfoTitle">بۆچی بڕێک دەخرێتە سەر باڵانسەکەت؟<\/h3>/);
  assert.match(sheet, /<div class="ri-text" id="roundingInfoText"><\/div>/);
  assert.doesNotMatch(sheet.slice(sheet.indexOf('<div class="sheet-body">')), /<svg|ri-ico|ri-points/);
  assert.doesNotMatch(sheet, /xc-info-body/);
  const explain = app.slice(app.indexOf('function roundingExplainHTML(n){'), app.indexOf('function fillRoundingExplain('));
  for (const words of ['بۆ وەرگر تەنها بڕی تەواو بە هەزار دەنێرین', 'ئەم بڕە نافەوتێت', 'لە مێژووی باڵانسدا دەیبینیت', 'FIB و Qi&nbsp;Card'])
    assert(explain.includes(words), words);
  // the figures of this request: what the split says
  assert.match(app, /fillRoundingExplain\('roundingInfoAmount','roundingInfoText',n\);/);
  // under the split: one sentence and «بۆچی؟» in words, not an (i)
  assert.match(html, /<button type="button" class="xc-why" id="payoutWhyBtn" onclick="openRoundingInfo\(\)" aria-haspopup="dialog">بۆچی؟<\/button>/);
  assert.match(html, /<span class="lbl">وەرگر وەریدەگرێت<\/span>\n\s*<span class="v" id="payoutDisplay" dir="ltr">/);
  assert.match(html, /<span class="lbl">دەخرێتە سەر باڵانسەکەت<\/span>\n\s*<span class="v" id="roundingDisplay" dir="ltr">/);
  assert.doesNotMatch(html, /class="xc-info-btn"/);
  assert.match(css, /#xcBreakdown \.xc-sum-result \{\n  display: grid !important; grid-template-columns: repeat\(2, minmax\(0, 1fr\)\); gap: 8px;/);
  // the frame of the exchange's other sheets: title 18/500 in ink, a 44px close, the blue button in light and dark
  assert.match(css, /#roundingInfoSheet#roundingInfoSheet \.sheet-head h3 \{\n  color: var\(--ri-ink\) !important; font-size: 18px !important; font-weight: 500 !important;/);
  assert.match(css, /#roundingInfoSheet#roundingInfoSheet \.sheet-close \{\n  width: 44px !important; height: 44px !important;/);
  assert.match(css, /--ri-close: #f6f7f9; --ri-close-ink: #64748b; --ri-close-line: transparent; --ri-btn: #0265ff;/);
  // a bottom sheet on every screen: on wide screens too it rises from the bottom edge
  assert.match(css, /@media \(min-width: 640px\) \{\n  html body :is\(#pickerSheet, #recipientSheet, #confirmSheet\):not\(#_x\) > \.sheet \{ border-radius: 16px !important; \}/);
  assert.match(css, /html body #roundingInfoSheet#roundingInfoSheet \{ align-items: flex-end !important; \}/);
  assert.match(css, /html body #roundingInfoSheet#roundingInfoSheet\.open > \.sheet \{ transform: translateY\(0\); \}/);
});

test('transaction details: one card per block in the exchange\'s values, the route with its wallets in the top card', () => {
  const html = read('index.html'), css = read('assets/css/transaction-summary.css'), xf = read('assets/css/exchange-form.css'), app = read('assets/js/app.js');
  assert.match(html, /\/assets\/css\/transaction-summary\.css\?v=9"/);
  // the site header steps aside on phones, as on every inner screen
  assert.match(css, /body #mainApp:has\(#pageSummary\.active\) #siteHeader\.pxh \{ display: none !important; \}/);
  // cards: radius 20, border, the exchange's shadow; titles without the marker
  assert.match(css, /#pageSummary \.tf-flow > :is\(\.tf-hero, \.tf-sec, \.tf-note\) \{\n  margin: 0 !important; padding: 16px; border: 1px solid var\(--sx-line\) !important; border-radius: 20px;/);
  assert.match(css, /#pageSummary \.tf-flow \.tf-sec-title::before \{ display: none; \}/);
  assert.match(css, /--sx-card: #131c2e; --sx-line: #25324a; --sx-rule: #1b2740;/);
  // the route moved into the top card, with the wallets' icons
  assert.match(app, /hero\.route=tfRouteIconsHTML\(o\.from_method,refundedSheet\?'AccountBalance':o\.to_method\);/);
  assert.match(app, /\+ \(opts\.route\?'<div class="tf-hero-route" dir="ltr">'\+opts\.route\+'<\/div>':''\)/);
  assert.doesNotMatch(app.slice(app.indexOf('function txDetailHTML'), app.indexOf('function closeTxDetail')), /tfRow\('ڕێگای گواستنەوە'/);
  // the summary's sheet is the exchange's: the same title, amount box and sentences
  const info = html.slice(html.indexOf('<div id="summaryInfoBackdrop"'), html.indexOf('</div>\n\n\n<script', html.indexOf('<div id="summaryInfoBackdrop"')));
  assert.match(info, /<b class="ri-amount" id="summaryInfoAmount" dir="ltr" hidden><\/b>/);
  assert.match(info, /<h2 id="summaryInfoTitle">بۆچی بڕێک دەخرێتە سەر باڵانسەکەت؟<\/h2>/);
  assert.match(info, /<div class="ri-text" id="summaryInfoText"><\/div>/);
  assert.doesNotMatch(info.slice(info.indexOf('<div class="ts-info-body">')), /<svg|ri-ico/);
  assert.match(app, /fillRoundingExplain\('summaryInfoAmount','summaryInfoText',n\);/);
  assert.match(app, /<button class="tf-info" type="button" onclick="openSummaryInfo\(\)" aria-haspopup="dialog">بۆچی؟<\/button>/);
  assert.match(info, /<button class="ts-info-ok" type="button" onclick="closeSummaryInfo\(\)">باشە، تێگەیشتم<\/button>/);
  assert.match(xf, /html body :is\(#roundingInfoSheet, #summaryInfoBackdrop\) \.ri-hero \{/);
});
