import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const html=read('index.html');
const css=read('assets/css/proxo-design-system.css');
const shellCss=read('assets/css/proxo-ui-v2.css');

test('Customer design contract is loaded after every legacy stylesheet',()=>{
  const sheets=[...html.matchAll(/<link[^>]+rel="stylesheet"[^>]+href="([^"]+)"/g)].map(m=>m[1]);
  assert.equal(sheets.at(-1),'/assets/css/proxo-design-system.css?v=1');
  assert(!read('exchange-admin.html').includes('proxo-design-system.css'));
});

test('Shared contract defines the approved Proxo palette and local font family',()=>{
  for(const token of ['--proxo-accent: #0265ff','--proxo-canvas: #fafafa','--proxo-ink: #0f172a','--proxo-muted: #64748b','--proxo-line: #e3e7f0','--proxo-font: Rabar, Arial, sans-serif'])assert(css.includes(token));
  assert(read('assets/css/app-ui-polish.css').includes('/assets/fonts/Rabar_021.ttf'));
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
  assert(workflow.includes('app.js?v=66'));
  assert(workflow.includes('proxo-design-system.css?v=1'));
  assert(html.includes('/assets/js/app.js?v=66'));
  assert(html.includes('/assets/css/proxo-ui-v2.css?v=9'));
  assert(html.includes('/assets/js/proxo-ui-v2.js?v=3'));
  assert(html.includes('/assets/js/proxo-toast.js?v=1'));
  assert(html.indexOf('proxo-toast.js?v=1') < html.indexOf('app.js?v=66'));
  assert(shellCss.includes('.pxt-stack'));
  assert(shellCss.includes('.pxn-pill'));
  assert(shellCss.includes('.field-error.show'));
  assert(shellCss.includes('.notif-reason'));
  assert(read('assets/js/app.js').includes("escHtml(String(msg==null?'':msg))"));
  assert(html.includes('id="feedbackSheet"'));
  assert(html.includes('id="usernameSheet"'));
  assert(html.includes('id="pfUsernameEdit"'));
  assert(read('assets/js/app.js').includes('ex_change_username'));
  assert(html.includes('id="savedRecipientsShortcut"'));
  assert(shellCss.includes('.xc-step-head .xc-saved-recipients-btn'));
  assert(html.includes('proxo-dark.css?v=4'));
});
