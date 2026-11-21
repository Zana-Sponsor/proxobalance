import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// v85: the /transactions card. The card is as it was; inside it every state has the same parts:
// the two wallets' logos · route and date · what arrives and what was sent · status pill and one line.
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const app=read('assets/js/app.js'), css=read('assets/css/transaction-summary.css');
const skeletons=read('assets/js/skeletons.js');

function context(){
  const c=vm.createContext({formatNum:v=>Number(v).toLocaleString('en-US'),
    escHtml:v=>String(v).replace(/[&<>"]/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch])),
    methodLabel:k=>({FastPay:'FastPay',FIB:'FIB',Korek:'Korek',AccountBalance:'باڵانسی هەژمار'}[k]||k),
    methodIconHTML:(k,size)=>k==='Gone'?'':'<span class="method-icon '+size+'" data-w="'+k+'"></span>',
    kycFmtDate:v=>v,ICON:{arrowLeftLong:''}});
  vm.runInContext(read('assets/js/exchange-payout-rounding.js'),c);
  vm.runInContext(app.slice(app.indexOf('function orderCodeOf('),app.indexOf('// ── transaction details')),c);
  return c;
}
const settlement='44444444-4444-4444-8444-444444444444';
const base={id:'o1',order_code:'PQ7K2M4R9T1X',from_method:'FastPay',to_method:'FIB',amount:60000,total:59100,fee:900,created_at:'2026-11-21T12:00:00Z'};
const states={
  pending:{...base,status:'چاوەڕوانە'},
  review:{...base,status:'لەژێر پێداچوونەوەدایە'},
  correction:{...base,status:'پێویستی بە ڕاستکردنەوەیە'},
  corrected:{...base,status:'ڕاستکراوەتەوە'},
  approved:{...base,status:'پەسەندکرا',payout_settlement_id:settlement,payout_iqd:59000,payout_rounding_iqd:100,shortfall_refunded_iqd:100},
  approvedEven:{...base,status:'پەسەندکرا',total:59000},
  rejected:{...base,status:'ڕەتکرا',admin_note:'وێنەی  پسووڵەکە\nڕوون نییە'},
  rejectedQuiet:{...base,status:'ڕەتکرا'},
  cancelled:{...base,from_method:'Korek',status:'هەڵوەشێنرایەوە'},
  refunded:{...base,status:'ڕەتکرا',balance_refunded_at:'2026-11-21T13:00:00Z'}
};

test('every state has the same parts: logos, route and date, two amounts, a footer with a status pill and one line', () => {
  const c=context();
  for(const [name,o] of Object.entries(states)){
    const card=c.orderCardHTML(o);
    for(const part of ['tx-item-pair','tx-item-main','tx-item-route','tx-item-when','tx-item-end','tx-item-amount','tx-item-sub','tx-item-foot','tx-item-status','tx-item-note'])
      assert.equal((card.match(new RegExp('class="'+part+'[" ]','g'))||[]).length,1,name+': '+part);
    // the from and to logos, in that order
    assert.match(card, /<span class="tx-item-pair" aria-hidden="true"><span class="method-icon sz-sm" data-w="(FastPay|Korek)"><\/span><span class="method-icon sz-sm" data-w="(FIB|AccountBalance)"><\/span><\/span>/, name);
    // no heavy block for one state, and no status circle
    assert.doesNotMatch(card, /tx-item-hint|tx-item-ico/, name);
    assert.match(card, /role="button"/); assert.match(card, /onkeydown=/);
  }
});

test('the amounts: what arrives, and under it what was sent (or, refunded, that it went back to the balance)', () => {
  const c=context();
  const pending=c.orderCardHTML(states.pending);
  // dinars are «د.ع» and read right to left (v90), so «د.ع» is to the left of the number
  assert.match(pending, /<strong class="tx-item-amount" dir="rtl">59,000 د\.ع<\/strong>/);
  assert.match(pending, /<span class="tx-item-sub">نێردراو <bdi dir="rtl">60,000 د\.ع<\/bdi><\/span>/);
  const dollars=c.orderCardHTML({...states.pending,from_method:'USDT',to_method:'FIB',amount:50});
  assert.match(dollars, /<span class="tx-item-sub">نێردراو <bdi dir="ltr">50 \$<\/bdi><\/span>/);
  const refunded=c.orderCardHTML(states.refunded);
  assert.match(refunded, /<strong class="tx-item-amount" dir="rtl">60,000 د\.ع<\/strong>/);
  assert.match(refunded, /<span class="tx-item-sub">گەڕاوە بۆ باڵانس<\/span>/);
  assert.match(refunded, /باڵانسی هەژمار/);
});

test('each state\'s pill and line', () => {
  const c=context();
  const card=o=>c.orderCardHTML(o);
  const pill=html=>html.match(/<span class="tx-item-status"><i aria-hidden="true"><\/i>([^<]+)<\/span>/)[1];
  const note=html=>html.match(/<span class="tx-item-note[^"]*"[^>]*>([\s\S]*?)<\/span><\/span><\/article>/)[1];
  // waiting: grey pill; the part that comes back after approval
  assert.match(card(states.pending), /^<article class="tx-item is-wait"/);
  assert.equal(pill(card(states.pending)),'چاوەڕوانی');
  assert.match(card(states.pending), /<span class="tx-item-note">بڕی گەڕێندراو <bdi dir="rtl">100 د\.ع<\/bdi><\/span>/);
  assert.equal(pill(card(states.review)),'پێداچوونەوە');
  assert.equal(pill(card(states.corrected)),'ڕاستکراوەتەوە');
  // to correct: the line asks for it
  assert.match(card(states.correction), /^<article class="tx-item is-warn"/);
  assert.match(card(states.correction), /<span class="tx-item-note is-warn">زانیارییەکان ڕاست بکەرەوە<svg/);
  // approved: what came back to the balance; nothing came back: the code
  assert.match(card(states.approved), /<span class="tx-item-note is-ok">بڕی گەڕێندراو <bdi dir="rtl">100 د\.ع<\/bdi><\/span>/);
  assert.match(card(states.approvedEven), /<span class="tx-item-note is-code" dir="ltr">PQ7K2M4R9T1X<\/span>/);
  // refused: the reason on one line; without one, the code
  assert.match(card(states.rejected), /<span class="tx-item-note is-bad">هۆکار: وێنەی پسووڵەکە ڕوون نییە<\/span>/);
  assert.match(note(card(states.rejectedQuiet)), /^PQ7K2M4R9T1X$/);
  // cancelled from a wallet: what comes back
  assert.match(card(states.cancelled), /^<article class="tx-item is-info"/);
  assert.match(card(states.cancelled), /<span class="tx-item-note is-info">بڕی گەڕێندراو <bdi dir="rtl">60,000 د\.ع<\/bdi><\/span>/);
  // the same words in every state, never «… بۆ باڵانست»
  for(const o of Object.values(states)) assert.doesNotMatch(card(o), /بۆ باڵانست/);
  assert.match(card(states.approved), /aria-label="FastPay بۆ FIB، 59,000 د\.ع، پەسەندکرا، بڕی گەڕێندراو 100 د\.ع"/);
  // refunded: blue pill, the code
  assert.equal(pill(card(states.refunded)),'گەڕێندرایەوە');
  assert.match(card(states.refunded), /is-code" dir="ltr">PQ7K2M4R9T1X</);
  // read aloud: the line is part of the card's name
  assert.match(card(states.correction), /aria-label="FastPay بۆ FIB، 59,000 د\.ع، پێویستی بە ڕاستکردنەوەیە، زانیارییەکان ڕاست بکەرەوە"/);
  // a wallet the app no longer lists: its first letter
  assert.match(c.orderCardHTML({...states.pending,from_method:'Gone'}), /<span class="method-icon sz-sm tx-mark-letter">G<\/span>/);
});

test('styles: the card is as it was; inside, the logos, the footer with its hairline, and the pill', () => {
  // the card itself: edge, corners, surface and padding unchanged
  assert.match(css, /padding: 14px 16px;\n  border: 1px solid var\(--tf-line\); border-radius: 16px; background: var\(--tf-surface\);/);
  assert.match(css, /grid-template-columns: 44px minmax\(0, 1fr\) auto; grid-template-areas: "ico main end" "foot foot foot";/);
  assert.match(css, /html body \.tx-item-pair \.method-icon:last-child \{ right: 0; bottom: 0; z-index: 1; \}/);
  assert.match(css, /html body \.tx-item-foot \{\n  grid-area: foot;[^}]*margin-top: 12px; padding-top: 12px; border-top: 1px solid var\(--tf-line\);/);
  assert.match(css, /html body \.tx-item-status \{\n  flex: 0 0 auto; display: inline-flex;[^}]*height: 24px; padding: 0 10px; border-radius: 999px;/);
  for(const tone of ['ok','bad','warn','info'])
    assert.match(css, new RegExp('html body \\.tx-item\\.is-'+tone+' +\\.tx-item-status \\{ background: var\\(--tf-'+tone+'-soft\\); +color: var\\(--tf-'+tone+'\\); \\}'));
  assert.doesNotMatch(css, /\.tx-item-hint|\.tx-item-ico/);
});

test('while loading, the card already has its new shape', () => {
  const fn=skeletons.slice(skeletons.indexOf('function txItems(n){'),skeletons.indexOf('// ── dashboard'));
  for(const part of ['tx-item-pair','tx-item-main','tx-item-end','tx-item-sub','tx-item-foot','tx-item-status is-skel-pill','tx-item-note'])
    assert(fn.includes('class="'+part+'"'),part);
  assert.doesNotMatch(fn, /tx-item-ico/);
});
