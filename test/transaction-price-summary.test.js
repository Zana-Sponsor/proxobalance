import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// v87: the transaction's screen shows «پوختەی نرخ», the exchange's price summary, with the
// order's own figures; it replaces «وردەکاری بڕ» and «دابەشکردنی بڕ».
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const app=read('assets/js/app.js'), css=read('assets/css/transaction-summary.css'), html=read('index.html');

function context(){
  const c=vm.createContext({formatNum:v=>Number(v).toLocaleString('en-US'),
    escHtml:v=>String(v).replace(/[&<>"]/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch])),
    methodLabel:k=>k,kycFmtDate:v=>v,ICON:{arrowLeftLong:''}});
  vm.runInContext(read('assets/js/exchange-payout-rounding.js'),c);
  vm.runInContext(app.slice(app.indexOf('function orderCodeOf('),app.indexOf('// ── transaction details')),c);
  return c;
}
const settlement='44444444-4444-4444-8444-444444444444';
const base={id:'o1',order_code:'PQ7K2M4R9T1X',from_method:'FastPay',to_method:'FIB',amount:60000,total:59100,fee:900,created_at:'2026-11-21T12:00:00Z'};
const rowsOf=out=>[...out.matchAll(/<div class="tf-price-row"><span class="tf-price-k">([^<]+)(?:<button[^>]*>[\s\S]*?<\/button>)?<\/span><span class="tf-price-v" dir="(?:rtl|ltr)">([^<]+)<\/span><\/div>/g)].map(m=>m[1]+' '+m[2]);

test('each state: sent, fee, what goes back to the balance, a soft line, and what the recipient gets', () => {
  const c=context();
  const price=o=>c.tfPriceHTML(o);
  // pending: the planned split
  assert.deepEqual(rowsOf(price({...base,status:'چاوەڕوانە'})),
    ['بڕی پارەی ناردراو 60,000 د.ع','کرێی خزمەتگوزاری 900 د.ع','بڕی گەڕێندراو 100 د.ع','کۆی گشتی نرخ 59,000 د.ع']);
  // approved and settled: what was paid
  assert.deepEqual(rowsOf(price({...base,status:'پەسەندکرا',payout_settlement_id:settlement,payout_iqd:59000,payout_rounding_iqd:100,shortfall_refunded_iqd:100})),
    ['بڕی پارەی ناردراو 60,000 د.ع','کرێی خزمەتگوزاری 900 د.ع','بڕی گەڕێندراو 100 د.ع','کۆی گشتی نرخ 59,000 د.ع']);
  // a whole-thousand total: nothing goes back, no such line
  assert.deepEqual(rowsOf(price({...base,status:'چاوەڕوانە',total:59000})),
    ['بڕی پارەی ناردراو 60,000 د.ع','کرێی خزمەتگوزاری 1,000 د.ع','کۆی گشتی نرخ 59,000 د.ع']);
  // refused: the price as asked for, nothing goes back
  assert.deepEqual(rowsOf(price({...base,status:'ڕەتکرا'})),
    ['بڕی پارەی ناردراو 60,000 د.ع','کرێی خزمەتگوزاری 900 د.ع','کۆی گشتی نرخ 59,100 د.ع']);
  // cancelled or refunded: everything back to the balance, no fee, nothing arrives
  assert.deepEqual(rowsOf(price({...base,from_method:'Korek',status:'هەڵوەشێنرایەوە'})),
    ['بڕی پارەی ناردراو 60,000 د.ع','بڕی گەڕێندراو 60,000 د.ع','کۆی گشتی نرخ 0 د.ع']);
  assert.deepEqual(rowsOf(price({...base,status:'ڕەتکرا',balance_refunded_at:'2026-11-21T13:00:00Z'})),
    ['بڕی پارەی ناردراو 60,000 د.ع','بڕی گەڕێندراو 60,000 د.ع','کۆی گشتی نرخ 0 د.ع']);
});

test('the «!» is on «بڕی گەڕێندراو» only when it is the part under a whole thousand', () => {
  const c=context();
  assert.match(c.tfPriceHTML({...base,status:'چاوەڕوانە'}),
    /<span class="tf-price-k">بڕی گەڕێندراو<button type="button" class="tf-price-info" onclick="openSummaryInfo\(\)" aria-haspopup="dialog" aria-label="بۆچی بڕێک دەگەڕێندرێتەوە؟">/);
  assert.doesNotMatch(c.tfPriceHTML({...base,from_method:'Korek',status:'هەڵوەشێنرایەوە'}), /tf-price-info/);
  // one title, the rows, then the total under the soft line; no other text
  const out=c.tfPriceHTML({...base,status:'چاوەڕوانە'});
  assert.match(out, /^<section class="tf-sec tf-price"><h3 class="tf-sec-title">پوختەی نرخ<\/h3><div class="tf-price-rows">/);
  assert.match(out, /<\/div><div class="tf-price-total"><div class="tf-price-row"><span class="tf-price-k">کۆی گشتی نرخ<\/span><span class="tf-price-v" dir="rtl">59,000 د\.ع<\/span><\/div><\/div><\/section>$/);
  // the sheet it opens is titled with the line's name
  assert.match(html, /<h2 id="summaryInfoTitle">بڕی گەڕێندراو<\/h2>/);
});

test('styles: the exchange\'s figures — 36 a line, 13 grey and 14 ink; a 1px line; the total 48 high, 14/600 and 18/700 blue', () => {
  assert.match(css, /html body \.tf-flow \.tf-price-row \{ display: flex; align-items: center; justify-content: space-between; gap: 12px; min-height: 36px; padding: 0 2px; \}/);
  assert.match(css, /html body \.tf-flow \.tf-price-k \{[^}]*color: var\(--tf-muted\); font-size: 13px; font-weight: 400;/);
  assert.match(css, /html body \.tf-flow \.tf-price-v \{\n  color: var\(--tf-ink\); font-size: 14px; font-weight: 500;/);
  assert.match(css, /html body \.tf-flow \.tf-price-total \{ margin-top: 8px; padding-top: 4px; border-top: 1px solid var\(--tf-line\); \}/);
  assert.match(css, /html body \.tf-flow \.tf-price-total \.tf-price-row \{ min-height: 48px; \}/);
  assert.match(css, /html body \.tf-flow \.tf-price-total \.tf-price-k \{ color: var\(--tf-ink\); font-size: 14px; font-weight: 600; \}/);
  assert.match(css, /html body \.tf-flow \.tf-price-total \.tf-price-v \{ color: var\(--tf-accent\); font-size: 18px; font-weight: 700;/);
  assert.match(css, /html body \.tf-flow \.tf-price-info::after \{ content: ""; position: absolute; inset: -14px; \}/);
});
