import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// v53: a switch for every section, image banners, light account and order lists.
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const sql = read('supabase/migrations/20261115230344_section_switches_and_banners.sql');
const adminApi = read('api-handlers/admin.js');
const KEYS = ['site', 'home', 'exchange', 'transactions', 'correction', 'rating', 'balance', 'balance_history',
  'support', 'verify', 'whatsapp', 'changes', 'rules', 'profile', 'signup', 'login',
  'name', 'phone', 'email', 'password', 'delete'];

test('database: one switch per section; the old account switch carries over to name, number, e-mail, password and delete', () => {
  for (const k of KEYS) assert.match(sql, new RegExp(`'${k}'`), k);
  assert.match(sql, /from unnest\(array\['name', 'phone', 'email', 'password', 'delete'\]\) as k\s+left join public\.ex_site_controls a on a\.key = 'account'/);
  assert.match(sql, /delete from public\.ex_site_controls where key = 'account';/);
  assert.match(sql, /before update of full_name, username on public\.ex_profiles\s+for each row execute function public\.ex_site_pause_guard\('name'\);/);
  assert.match(sql, /before insert on public\.ex_account_deletions\s+for each row execute function public\.ex_site_pause_guard\('delete'\);/);
  assert.match(sql, /before insert on public\.ex_order_feedback\s+for each row execute function public\.ex_site_pause_guard\('rating'\);/);
  assert.match(sql, /before insert or update of enabled on public\.ex_whatsapp_settings\s+for each row execute function public\.ex_site_pause_guard\('whatsapp'\);/);
  // a phone change that only rewrites the number is never stopped by the WhatsApp switch
  assert.match(sql, /if new\.enabled is not distinct from old\.enabled then return new; end if;/);
  assert.doesNotMatch(sql, /ex_rates|rate_value|ex_orders\b/);
});

test('database: banners are private tables; the app reads one short answer; a screen banner is seen once per account', () => {
  assert.match(sql, /image_path\s+text not null check \(image_path ~ '\^\(slides\|popups\)\/\[0-9a-f-\]\{36\}\\\.webp\$'\)/);
  assert.match(sql, /action_url\s+text check \(action_url is null or \(action_url ~ '\^https:\/\/\[\^\\s\]\+\$'/);
  assert.match(sql, /\(kind = 'slide' and cardinality\(places\) = 0\) or\s+\(kind = 'popup' and cardinality\(places\) between 1 and 20\)/);
  assert.match(sql, /revoke all on public\.ex_banners, public\.ex_banner_seen from anon, authenticated;/);
  assert.match(sql, /revoke all on function public\.ex_my_banners\(\) from public, anon;\ngrant execute on function public\.ex_my_banners\(\) to authenticated, service_role;/);
  assert.match(sql, /not exists \(select 1 from public\.ex_banner_seen s where s\.user_id = auth\.uid\(\) and s\.banner_id = b\.id\)/);
  assert.match(sql, /values \('banners', 'banners', true, 409600, array\['image\/webp'\]\)/);
});

// bannerRow from the admin API, run on its own
function bannerRow() {
  const start = adminApi.indexOf('// ── banners ─────');
  const end = adminApi.indexOf('\n}\n', adminApi.indexOf('function bannerRow(')) + 2;
  const ctx = vm.createContext({ URL });
  vm.runInContext(adminApi.slice(start, end) + '\nthis.bannerRow = bannerRow;', ctx);
  return ctx.bannerRow;
}
const j = x => JSON.parse(JSON.stringify(x));

test('admin API: a banner is checked before it is saved', () => {
  const row = bannerRow();
  const slide = j(row({ kind: 'slide', image_path: 'slides/11111111-1111-4111-8111-111111111111.webp', action_type: 'section', action_section: 'exchange' }));
  assert.deepEqual(slide, { kind: 'slide', image_path: 'slides/11111111-1111-4111-8111-111111111111.webp', image_w: 1200, image_h: 500,
    action_type: 'section', action_section: 'exchange', action_url: null, places: [], is_active: true });
  const popup = j(row({ kind: 'popup', image_path: 'popups/22222222-2222-4222-8222-222222222222.webp', action_type: 'url', action_url: 'https://proxobalance.app/x', places: ['home', 'profile', 'home', 'nope'] }));
  assert.deepEqual([popup.image_w, popup.image_h, popup.places, popup.action_url], [720, 900, ['home', 'profile'], 'https://proxobalance.app/x']);
  const bad = [
    { kind: 'slide', image_path: 'popups/22222222-2222-4222-8222-222222222222.webp' },
    { kind: 'slide', image_path: '../x.webp' },
    { kind: 'slide', image_path: 'slides/11111111-1111-4111-8111-111111111111.webp', action_type: 'url', action_url: 'javascript:alert(1)' },
    { kind: 'slide', image_path: 'slides/11111111-1111-4111-8111-111111111111.webp', action_type: 'url', action_url: 'http://x.com' },
    { kind: 'slide', image_path: 'slides/11111111-1111-4111-8111-111111111111.webp', action_type: 'section', action_section: 'delete-account' },
    { kind: 'popup', image_path: 'popups/22222222-2222-4222-8222-222222222222.webp', places: [] },
    { kind: 'other', image_path: 'slides/11111111-1111-4111-8111-111111111111.webp' }
  ];
  for (const p of bad) assert.throws(() => row(p), x => x.status === 400, JSON.stringify(p));
  // full admins only (limited staff have no banner permission); the picture goes up through a one-time address
  assert.doesNotMatch(adminApi, /banner_save:'|banners_list:'/);
  assert.match(adminApi, /db\.storage\.from\('banners'\)\.createSignedUploadUrl\(path\)/);
  assert.match(adminApi, /if \(previous && previous\.image_path !== saved\.image_path\) await db\.storage\.from\('banners'\)\.remove\(\[previous\.image_path\]\)/);
  assert.match(adminApi, /const SITE_KEYS = \['site', 'home', 'exchange', 'transactions', 'correction', 'rating', 'balance', 'balance_history',/);
});

test('server: name, number, e-mail, password and delete each have their own switch; corrections have theirs', () => {
  const auth = read('api-handlers/auth.js');
  assert.match(auth, /phone_change_start: 'phone', phone_change_finish: 'phone',/);
  assert.match(auth, /email_change_start: 'email', email_change_finish: 'email', password_change: 'password'/);
  assert.match(auth, /verify_password: 'delete',/);
  assert.doesNotMatch(auth, /'account'/);
  assert.match(read('api-handlers/orders.js'), /if \(req\.method === 'PATCH'\) \{\n    const pausedFix = await sectionPaused\(\['correction'\]\);/);
  const titles = read('api-handlers/_lib/security.js');
  for (const k of KEYS) assert.match(titles, new RegExp(`\\n  ${k}: '`), k);
});

test('customer app: no Firebase, one banner place on the dashboard, every screen follows its switch', () => {
  const index = read('index.html'), app = read('assets/js/app.js'), pause = read('assets/js/site-pause.js'), banners = read('assets/js/banners.js');
  assert.doesNotMatch(index, /firebasejs|id="newsBanner"/);
  assert.doesNotMatch(app, /firebase\.|listenToNews/);
  assert.match(index, /<div class="dbb" id="dbBanners" hidden><\/div>/);
  assert.match(index, /<script src="\/assets\/js\/site-pause\.js\?v=5"><\/script>\n<script src="\/assets\/js\/banners\.js\?v=\d+"><\/script>/);
  assert.match(app, /if\(typeof pxBannersStart==='function'\) pxBannersStart\(\);/);
  for (const [route, key] of [['home', 'home'], ['transactions', 'transactions'], ['summary', 'transactions'], ['balance', 'balance_history'], ['profile', 'profile'], ['changes', 'changes'], ['rules', 'rules'],
    ['account-name', 'name'], ['change-phone', 'phone'], ['change-email', 'email'], ['change-password', 'password'], ['delete-account', 'delete']])
    assert.match(pause, new RegExp(`'?${route}'?: \\{ key: '${key}'`), route);
  assert.match(pause, /rating: \['openFeedbackSheet', 'submitOrderFeedback', 'submitSummaryFeedback'\]/);
  assert.match(pause, /whatsapp: \['toggleWhatsappNotify', 'openWhatsappSheet', 'submitWhatsappSheet'\]/);
  // banners: one call, kept on the device, a seen screen banner never returns, pictures load late
  assert.match(banners, /sb\.rpc\('ex_my_banners'\)/);
  assert.match(banners, /sb\.rpc\('ex_banner_seen_mark', \{ p_banner: b\.id \}\)/);
  assert.match(banners, /store\(CACHE_KEY, \{ uid: owner, at: fetchedAt, data: res\.data \}\)/);
  assert.match(banners, /' data-src="' \+ imgUrl\(b\.img\) \+ '"'/);
  assert.match(banners, /track\.style\.transform = 'translateX\(' \+ \(idx \* 100\) \+ '%\)';/);
  assert.match(read('assets/css/banners.css'), /aspect-ratio: 12 \/ 5;/);
});

test('panel: banners page instead of the old text banner; pictures become small WebP; lists draw 50 at a time', () => {
  const html = read('exchange-admin.html'), js = read('assets/js/exchange-banners-admin.js'), admin = read('assets/js/admin.js');
  assert.doesNotMatch(html, /firebasejs|id="pgAnnouncement"/);
  assert.doesNotMatch(admin, /firebase|fbdb|saveAnnouncement/);
  assert.match(html, /<div class="pg" id="pgBanners">/);
  assert.match(html, /onclick="goPage\('banners'\)"/);
  assert.match(js, /const SIZE = \{ slide: \[1200, 500\], popup: \[720, 900\] \};/);
  assert.match(js, /canvas\.toBlob\(res, 'image\/webp', q\)/);
  assert.match(js, /if \(blob\.size <= MAX_BYTES\) break;/);
  assert.match(js, /uploadToSignedUrl\(up\.path, up\.token, d\.blob, \{ contentType: 'image\/webp', cacheControl: '31536000' \}\)/);
  const pauseAdmin = read('assets/js/exchange-site-pause-admin.js');
  for (const k of KEYS.filter(k => k !== 'site')) assert.match(pauseAdmin, new RegExp(`\\['${k}', '`), k);
  assert.match(admin, /const LIST_STEP=50;/);
  assert.match(admin, /const page=list\.slice\(0,_accShown\);/);
  assert.match(admin, /const page=list\.slice\(0,_ordShown\);/);
  assert.match(admin, /answers=await Promise\.all\(parts\.map\(ids=>adminApiRequest\('account_balances',\{user_ids:ids\}\)\)\)/);
  assert.match(html, /oninput="filterAccounts\(null,true\)"/);
});

test('v54: a change in the panel reaches open apps at once, without sending any content', () => {
  const live = read('supabase/migrations/20261115233351_live_banners_and_switches.sql');
  assert.match(live, /key\s+text primary key check \(key in \('banners', 'site_controls'\)\),\n  version\s+bigint not null default 0,/);
  assert.match(live, /revoke all on public\.ex_live_versions from anon, authenticated;\ngrant select on public\.ex_live_versions to authenticated;/);
  assert.match(live, /after insert or update or delete on public\.ex_banners\s+for each statement execute function public\.ex_live_bump\('banners'\);/);
  assert.match(live, /after insert or update or delete on public\.ex_site_controls\s+for each statement execute function public\.ex_live_bump\('site_controls'\);/);
  assert.match(live, /alter publication supabase_realtime add table public\.ex_live_versions;/);
  const banners = read('assets/js/banners.js');
  assert.match(banners, /\.on\('postgres_changes', \{ event: 'UPDATE', schema: 'public', table: 'ex_live_versions' \}/);
  assert.match(banners, /if \(key === 'banners'\) soon\(\);\n\s+else if \(key === 'site_controls' && window\.pxSitePause\) window\.pxSitePause\.load\(\);/);
  assert.match(banners, /fetchFresh\(\);\n    listen\(\);/);
});
