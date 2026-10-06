import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const app=readFileSync(new URL('../assets/js/app.js',import.meta.url),'utf8');
const fixture={id:'11111111-1111-4111-8111-111111111111',order_code:'P7K9M2Q4R6T8',
  status:'پەسەندکرا',from_method:'FastPay',to_method:'FIB',amount:60000,total:59100,created_at:'2026-10-06T09:00:00Z'};
function context(){
  const c=vm.createContext({formatNum:v=>Number(v).toLocaleString('en-US'),
    escHtml:v=>String(v).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;'),
    methodLabel:k=>({FastPay:'FastPay',FIB:'FIB Bank',AccountBalance:'باڵانسی هەژمار'}[k]||k),
    kycFmtDate:v=>v,ICON:{arrowLeftLong:'<svg></svg>'}});
  vm.runInContext(app.slice(app.indexOf('function orderCodeOf('),app.indexOf('// ── transaction details')),c);
  return c;
}
test('removing the completed summary preserves status filters and every history record',()=>{
  const c=context();
  const elements=new Map(),lookups=[];
  c.document={getElementById(id){lookups.push(id);if(!elements.has(id))elements.set(id,{textContent:''});return elements.get(id);}};
  let rendered=0;c.renderTxList=()=>rendered++;
  c._orders=[fixture,
    {...fixture,status:'ڕەتکرا',balance_refunded_at:'2026-10-06T10:00:00Z'},
    {...fixture,status:'ڕەتکرا'}, {...fixture,status:'چاوەڕوانە'}];
  vm.runInContext(app.slice(app.indexOf('function renderTxPage('),app.indexOf('function renderTxList(')),c);
  c.renderTxPage();
  assert.equal(c._orders.length,4);assert.equal(rendered,1);
  assert.equal(elements.get('fcAll').textContent,'4');assert.equal(elements.get('fcOk').textContent,'2');
  assert.equal(elements.get('fcWait').textContent,'1');assert.equal(elements.get('fcNo').textContent,'1');
  assert.equal(lookups.some(id=>id==='txSummary'||id.startsWith('txTotal')),false);
  assert.doesNotMatch(readFileSync(new URL('../index.html',import.meta.url),'utf8'),/id="txSummary"/);
});
test('receipt cards show the persisted public ID and actual refund principal',()=>{
  const c=context();
  const complete=c.orderCardHTML(fixture);
  assert.match(complete,/P7K9M2Q4R6T8/);assert.match(complete,/59,100 IQD/);
  assert.match(complete,/وەرگرتنت/);assert.doesNotMatch(complete,/tx-money|tx-amount-sent/);
  const refund=c.orderCardHTML({...fixture,status:'ڕەتکرا',balance_refunded_at:'2026-10-06T10:00:00Z'});
  assert.match(refund,/باڵانسی هەژمار/);assert.match(refund,/گەڕاوە بۆ باڵانس/);
  assert.doesNotMatch(refund,/59,100 IQD/);assert.match(refund,/60,000 IQD/);
  assert.match(refund,/role="button"/);assert.match(refund,/onkeydown=/);
});
