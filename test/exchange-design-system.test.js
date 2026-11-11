import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const html=read('index.html');
const css=read('assets/css/proxo-design-system.css');
const shellCss=read('assets/css/proxo-ui-v2.css');

test('Customer design contract is loaded after every legacy stylesheet',()=>{
  const sheets=[...html.matchAll(/<link[^>]+rel="stylesheet"[^>]+href="([^"]+)"/g)].map(m=>m[1]);
  assert.equal(sheets.at(-1),'/assets/css/proxo-design-system.css?v=3');
  assert(!read('exchange-admin.html').includes('proxo-design-system.css'));
});

test('Shared contract defines the approved Proxo palette and local font family',()=>{
  for(const token of ['--proxo-accent: #0265ff','--proxo-canvas: #fafafa','--proxo-ink: #0f172a','--proxo-muted: #64748b','--proxo-line: #e3e7f0','--proxo-font: Rabar, Arial, sans-serif'])assert(css.includes(token));
  assert(read('assets/css/app-ui-polish.css').includes('/assets/fonts/Rabar_021.ttf'));
});

test('Profile balance and splash mark use restrained, consistent proportions',()=>{
  assert(css.includes('clamp(24px, 7vw, 30px)'));
  assert(css.includes('.pfx-balance .bx-head {\n  justify-content: center !important;'));
  assert(css.includes('.pfx-balance .bx-amount { justify-content: center !important;'));
  assert(html.includes('width:min(42vw,180px)'));
  assert(html.includes('animation:spIn 1.15s'));
  assert(html.includes('transform:scale(.55)'));
  assert(html.includes('transform:scale(1.08)'));
  assert(read('assets/js/app.js').includes('1400-(performance.now()-appSplashStartedAt)'));
  assert(html.includes('transform:scale(1.04)'));
  assert(!html.includes('transform:scale(6)'));
});

test('Auth remains full-bleed and password recovery gets the same email icon',()=>{
  assert.match(html,/<div class="field input-wrap">\s*<span class="input-ico">[\s\S]*?id="forgotEmail"/);
  assert.match(css,/body #authWrap :is\(\.input,\.ainp,\.otp-digit\) \{ height: 48px !important/);
  assert(!css.includes('.auth-card {'));
});

test('Root sheets and transaction feedback are included, not just .page',()=>{
  for(const id of ['#recipientSheet','#pickerSheet','#confirmSheet','#resultModal','#orderCorrectionModal'])assert(css.includes(id));
  assert(css.includes('#mainApp .tx-sheet .order-feedback'));
  assert(css.includes('body #recipientSheet #recipientSave'));
  assert(css.includes('body #confirmSheet #confirmSendBtn'));
});

test('Semantic state edges and selected states survive card/field normalization',()=>{
  for(const selector of ['.tx-card.needs-action','.kyc-card[data-state]','.kyc-banner','.support-image-picker.selected','.feedback-star.selected','.input[aria-invalid="true"]'])assert(css.includes(selector));
  assert.match(css,/\.kyc-banner \{ background: var\(--kyc-bg\) !important; border: 1px solid var\(--kyc-bd\) !important/);
});

test('Design layer leaves hidden/route mechanics untouched and provides accessible targets',()=>{
  assert(!/\[hidden\]\s*\{[^}]*display:\s*(?:block|flex|grid)/s.test(css));
  assert(!css.includes('pointer-events: none'));
  assert(css.includes('min-height: 44px'));
  assert(css.includes('min-height: 48px !important'));
  assert(css.includes('prefers-reduced-motion: reduce'));
  assert(css.includes('.btn.btn-ghost'));
});

test('Production smoke waits for the changed customer version and verifies its design contract',()=>{
  const workflow=read('.github/workflows/exchange-production-smoke.yml');
  assert(workflow.includes('app.js?v=70'));
  assert(workflow.includes('admin.js?v=31'));
  assert(workflow.includes('exchange-admin-workspace.js?v=3'));
  assert(workflow.includes('exchange-insights.js?v=7'));
  assert(workflow.includes('exchange-reward-pricing.js?v=4'));
  assert(workflow.includes("grep -q 'ProxoRewardPricing.effectiveRate' app-v70.js"));
  assert(!workflow.includes('effectiveCustomerRate'));
  assert(workflow.includes('proxo-design-system.css?v=3'));
  assert(workflow.includes("grep -q 'width:min(42vw,180px)' current-index.html"));
  assert(workflow.includes("grep -q 'animation:spIn 1.15s' current-index.html"));
  assert(workflow.includes("grep -q 'clamp(24px, 7vw, 30px)' proxo-design-system.css"));
  assert(html.includes('/assets/js/app.js?v=70'));
  assert(html.includes('exchange-reward-pricing.js?v=4'));
  assert(html.includes('proxo-ui-v2.css?v=12'));
  assert(html.includes('proxo-dark.css?v=6'));
  assert(html.includes('exchange-balance.css?v=6'));
  assert(html.includes('/assets/css/proxo-ui-v2.css?v=12'));
  assert(html.includes('/assets/js/proxo-ui-v2.js?v=4'));
  assert(html.includes('/assets/js/proxo-toast.js?v=1'));
  assert(html.indexOf('proxo-toast.js?v=1') < html.indexOf('app.js?v=70'));
  assert(shellCss.includes('.pxt-stack'));
  assert(shellCss.includes('.pxn-pill'));
  assert(shellCss.includes('.field-error.show'));
  assert(shellCss.includes('.notif-reason'));
  assert(read('assets/js/app.js').includes('escHtml(notifClean(s))'));
  assert(read('assets/js/app.js').includes('function notifRich(s)'));
  assert(html.includes('id="feedbackSheet"'));
  assert(html.includes('id="usernameSheet"'));
  assert(html.includes('id="pfUsernameEdit"'));
  assert(read('assets/js/app.js').includes('ex_change_username'));
  assert(read('assets/js/app.js').includes('مامەڵەکەت چۆن بوو؟'));
  assert(html.includes('id="savedRecipientsShortcut"'));
  assert(shellCss.includes('.xc-step-head .xc-saved-recipients-btn'));
  assert(shellCss.includes('#usernameSheet .sheet-body'));
  assert(html.includes('proxo-dark.css?v=6'));
  assert(html.includes('exchange-balance.css?v=6'));
  assert(html.includes('id="savedRecipientsShortcut"'));
  assert(html.includes('بەبێ بەڵگەی ناردن داواکارییەکە ڕەت دەکرێتەوە.'));
  assert(html.includes('id="pageBalance" data-route="balance"'));
  assert(html.includes("navigate('balance')"));
  assert(html.includes('id="bxAmount"'));
  assert(shellCss.includes('.xc-step-head .xc-saved-recipients-btn'));
  assert(shellCss.includes('.bh-item'));
  assert(shellCss.includes('.px-ptr-pill'));
  const app=read('assets/js/app.js');
  assert(app.includes("sb.rpc('ex_my_balance_activity'"));
  assert(app.includes('escHtml(sub)'));
  const balanceAdmin=read('exchange-admin-balance.html');
  for(const marker of ['id="gate"','id="app"','/assets/js/exchange-admin-balance.js?v=1'])assert(balanceAdmin.includes(marker));
  assert(!/<script>\s*[\s\S]*?<\/script>/.test(balanceAdmin));
  const balanceAdminJs=read('assets/js/exchange-admin-balance.js');
  for(const marker of ['ex_admin_find_accounts','ex_admin_adjust_balance','ex_admin_balance_history','pending.key'])assert(balanceAdminJs.includes(marker));
  assert(read('exchange-admin.html').includes('href="exchange-admin-balance.html"'));
  const build=read('scripts/prepare-vercel.mjs');
  assert(build.includes("join(output, 'exchange-admin-balance.html')"));
});

test('Tiered fees are opt-in per directed wallet route and preserve existing commissions',()=>{
  const admin=read('exchange-admin.html');
  const adminJs=read('assets/js/admin.js');
  assert(read('exchange-admin.html').includes('admin.js?v=31'));
  assert(read('exchange-admin.html').includes('admin.css?v=10'));
  assert(read('assets/css/admin.css').includes('.pair-tier'));
  assert(read('assets/js/exchange-admin-workspace.js').includes('pairTierOf'));
  const api=read('api/orders.js');
  const migration=read('SUPABASE_EXCHANGE_ROUTE_FEE_TIERS.sql');
  for(const id of ['pairTierBulkLimit','pairTierBulkLow','pairTierBulkHigh'])assert(admin.includes(`id="${id}"`));
  assert(adminJs.includes('pairTierAllowed'));
  assert(adminJs.includes('fee_tier_enabled:tierOn'));
  assert(adminJs.includes('fee_tier_low_percent:low'));
  assert(adminJs.includes('fee_tier_high_percent:high'));
  assert(api.includes('effectiveRateValue(rate, amount)'));
  assert(api.includes('calculateTotal(amount, rate)'));
  assert(read('assets/js/exchange-reward-pricing.js').includes('function effectiveRate(rate,amount)'));
  assert(migration.includes('fee_tier_enabled boolean NOT NULL DEFAULT false'));
  assert(!/UPDATE\s+public\.ex_rates\s+SET\s+(?:rate_type|rate_value)\s*=/i.test(migration));
});

test('production smoke wait loop has a defined root and v10 release markers',()=>{
  const workflow=read('.github/workflows/exchange-production-smoke.yml');
  assert(workflow.includes("root='https://www.proxobalance.app'"));
  assert(workflow.includes("grep -q 'fee_tier_enabled' current-app.js"));
  assert(workflow.includes("exchange-balance-manual.js?v=1"));
});
test('manual balance administration is server-authorized and uses the versioned same-origin client',()=>{
  const admin=read('exchange-admin.html');
  const api=read('api/admin.js');
  const client=read('assets/js/exchange-balance-manual.js');
  assert(admin.includes('id=\"bmPanel\"'));
  assert(admin.includes('exchange-balance-manual.js?v=1'));
  assert(admin.includes('exchange-balance.css?v=7'));
  for(const action of ['balance_manual_find','balance_manual_overview','balance_manual_adjust'])assert(api.includes(action));
  assert(api.includes('ex_admin_adjust_balance'));
  assert(client.includes('confirmed:true'));
  assert(client.includes('request_key:pending.key'));
});
