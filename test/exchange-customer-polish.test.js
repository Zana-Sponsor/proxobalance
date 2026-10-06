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
  vm.runInContext(app.slice(app.indexOf('function completedTxTotals('),app.indexOf('function renderTxPage(')),c);
  return c;
}
test('completed totals keep currencies separate and exclude rejected, pending and refunded orders',()=>{
  const c=context();
  const totals=c.completedTxTotals([fixture,
    {...fixture,from_method:'USDT',amount:100,total:145000},
    {...fixture,to_method:'USDT',amount:150000,total:100},
    {...fixture,status:'ڕەتکرا',balance_refunded_at:'2026-10-06T10:00:00Z'},
    {...fixture,status:'ڕەتکرا'}, {...fixture,status:'چاوەڕوانە'}]);
  assert.deepEqual(JSON.parse(JSON.stringify(totals)),{count:3,sentIqd:210000,sentUsdt:100,recvIqd:204100,recvUsdt:100});
});
test('receipt cards show the persisted public ID and actual refund principal',()=>{
  const c=context();
  const complete=c.orderCardHTML(fixture);
  assert.match(complete,/P7K9M2Q4R6T8/);assert.match(complete,/59,100 IQD/);
  assert.match(complete,/ناردنت/);assert.match(complete,/وەرگرتنت/);
  const refund=c.orderCardHTML({...fixture,status:'ڕەتکرا',balance_refunded_at:'2026-10-06T10:00:00Z'});
  assert.match(refund,/باڵانسی هەژمار/);assert.match(refund,/گەڕاوە بۆ باڵانس/);
  assert.doesNotMatch(refund,/59,100 IQD/);assert.match(refund,/60,000 IQD/);
  assert.match(refund,/role="button"/);assert.match(refund,/onkeydown=/);
});
