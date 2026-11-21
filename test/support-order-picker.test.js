import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// v84: a support case's transaction is chosen from the account's own, never typed,
// and the admin sees that transaction in the case and opens it from there.
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const html=read('index.html'), app=read('assets/js/app.js'), admin=read('assets/js/admin.js');
const adminApi=read('api-handlers/admin.js'), css=read('assets/css/support-case.css');

test('the form has no code to type: a picker, the chosen code in a hidden field, and a sheet of transactions', () => {
  assert.doesNotMatch(html, /<input type="text"[^>]*id="supportOrderCode"/);
  assert.doesNotMatch(html, /PXXXXXXXXXXX/);
  assert.match(html, /<span class="field-label sc-label" id="supportOrderLabel">مامەڵەی پەیوەندیدار <small>ئارەزوومەندانە<\/small><\/span>\n\s*<button type="button" class="sc-order-clear" id="supportOrderClear" onclick="setSupportOrder\(null\)" aria-label="لابردنی مامەڵەکە" hidden>لابردن<\/button>\n\s*<\/div>\n\s*<input type="hidden" id="supportOrderCode" value="">/);
  assert.match(html, /<button type="button" class="sc-order-pick is-empty" id="supportOrderPick" onclick="openSupportOrderPicker\(\)" aria-haspopup="dialog"/);
  const sheet=html.slice(html.indexOf('<div id="supportOrderSheet"'),html.indexOf('ORDER CONFIRM SHEET'));
  assert.match(sheet, /role="dialog" aria-modal="true" aria-labelledby="supportOrderSheetTitle"/);
  assert.match(sheet, /<h3 id="supportOrderSheetTitle">مامەڵەیەک هەڵبژێرە<\/h3>/);
  assert.match(sheet, /<div class="sheet-body" id="supportOrderSheetBody" role="listbox"/);
  // Escape closes it, like the other sheets
  assert.match(app, /const supportOrderS=document\.getElementById\('supportOrderSheet'\); if\(supportOrderS && supportOrderS\.classList\.contains\('open'\)\)\{ closeSupportOrderPicker\(\); return; \}/);
});

function pickerContext(orders){
  const nodes=new Map();
  const node=id=>{
    if(!nodes.has(id)){
      const classes=new Set();
      nodes.set(id,{id,value:'',innerHTML:'',className:'',hidden:false,attributes:{},
        classList:{toggle:(c,on)=>{ on?classes.add(c):classes.delete(c); },contains:c=>classes.has(c)},
        setAttribute(k,v){ this.attributes[k]=v; },removeAttribute(k){ delete this.attributes[k]; },
        getAttribute(k){ return this.attributes[k]; },focus(){} });
    }
    return nodes.get(id);
  };
  node('supportCategory').value='general';
  const opened=[], closed=[];
  const c=vm.createContext({
    document:{getElementById:node,querySelector:()=>null},window:{},requestAnimationFrame:f=>f(),
    curUser:{id:'u'},_orders:orders,_ordersLoaded:true,
    orderCodeOf:o=>o.order_code,tfToneOf:o=>o.status==='ڕەتکرا'?'bad':'ok',TF_ICONS:{ok:'<svg/>',bad:'<svg/>'},
    ProxoPayoutRounding:{forOrder:o=>({display_amount:o.total})},
    txAmount:(v,m)=>Number(v).toLocaleString('en-US')+(m==='USDT'?' $':' د.ع'),amtDir:t=>/\$\s*$/.test(String(t).trim())?'ltr':'rtl',
    txRouteInner:(a,b)=>a+'→'+b,txWhenHTML:()=>'<bdi>21 - 11 - 2026</bdi>',txWhen:()=>'21 - 11 - 2026',
    txShortLabelOf:o=>o.status,txLabelOf:o=>o.status,methodLabel:k=>k,
    escHtml:v=>String(v).replace(/[&<>"]/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch])),
    scIcon:()=>'<svg/>',setSupportCategory:v=>{ node('supportCategory').value=v; },
    openSheet:s=>opened.push(s.id),closeSheet:s=>closed.push(s.id),loadHistory:async()=>{},
    tfSplitOf:()=>({recipient:0,returned:0,pending:true})
  });
  // the chooser shows the list's own card (txCardInner)
  vm.runInContext(app.slice(app.indexOf('// One transaction in a list (v85).'),app.indexOf('// ── transaction details')),c);
  vm.runInContext(app.slice(app.indexOf('// ── «مامەڵەی پەیوەندیدار»'),app.indexOf('async function submitSupportCase(){')),c);
  return {c,node,opened,closed};
}
const orders=[
  {id:'1',order_code:'PAAAAAAAAAA1',from_method:'FastPay',to_method:'FIB',total:59100,amount:60000,status:'پەسەندکرا',created_at:'2026-11-21T10:00:00Z'},
  {id:'2',order_code:'PBBBBBBBBBB2',from_method:'Korek',to_method:'FIB',total:8000,amount:10000,status:'ڕەتکرا',created_at:'2026-11-20T10:00:00Z'}
];

test('the sheet lists the account\'s transactions with their code; one tap chooses and closes it', async () => {
  const {c,node,opened,closed}=pickerContext(orders);
  await c.openSupportOrderPicker();
  assert.deepEqual([...opened],['supportOrderSheet']);
  const body=node('supportOrderSheetBody').innerHTML;
  assert.equal((body.match(/class="tx-item sc-order-row/g)||[]).length,2);
  // the list's card: logos, route and date, amounts, status and the code in its footer
  assert.match(body, /<span class="tx-item-pair" aria-hidden="true">/);
  assert.match(body, /<span class="tx-item-note is-code" dir="ltr">PAAAAAAAAAA1<\/span>/);
  assert.match(body, /role="option" aria-selected="false"/);
  c.pickSupportOrder('PBBBBBBBBBB2');
  assert.equal(node('supportOrderCode').value,'PBBBBBBBBBB2');
  assert.deepEqual([...closed],['supportOrderSheet']);
  // the field shows the chosen transaction and «لابردن»; a general case becomes an order case
  assert.match(node('supportOrderPick').className, /^sc-order-pick tx-item is-bad$/);
  assert.match(node('supportOrderPick').innerHTML, /PBBBBBBBBBB2/);
  assert.equal(node('supportOrderClear').hidden,false);
  assert.equal(node('supportOrderField').classList.contains('has-order'),true);
  assert.equal(node('supportCategory').value,'order');
  // opened again, the chosen one is marked
  await c.openSupportOrderPicker();
  assert.match(node('supportOrderSheetBody').innerHTML, /is-picked" role="option" aria-selected="true"[^>]*data-code="PBBBBBBBBBB2"/);
  // «لابردن» empties it again
  c.setSupportOrder(null);
  assert.equal(node('supportOrderCode').value,'');
  assert.equal(node('supportOrderPick').className,'sc-order-pick is-empty');
  assert.equal(node('supportOrderClear').hidden,true);
});

test('only a code of the account\'s own transactions can be chosen; no transactions says so', async () => {
  const {c,node}=pickerContext(orders);
  c.setSupportOrder('PZZZZZZZZZZ9');
  assert.equal(node('supportOrderCode').value,'');
  const empty=pickerContext([]);
  await empty.c.openSupportOrderPicker();
  assert.match(empty.node('supportOrderSheetBody').innerHTML, /هێشتا هیچ مامەڵەیەکت نییە/);
});

test('the form is emptied after sending and on sign-out; a refused code is said plainly', () => {
  const submit=app.slice(app.indexOf('async function submitSupportCase(){'),app.indexOf('async function loadSupportCases(){'));
  assert.match(submit, /setSupportOrder\(null\);\n    document\.getElementById\('supportCategory'\)\.value='order';/);
  assert.match(submit, /err\.reason=payload\.code\|\|'';/);
  assert.match(submit, /e\?\.reason==='ORDER_NOT_FOUND'\?'ئەو مامەڵەیە لە هەژمارەکەتدا نەدۆزرایەوە؛ مامەڵەیەکی تر هەڵبژێرە'/);
  assert.match(app, /\['supportOrderCode','supportDescription'\]\.forEach\(id=>\{ const el=document\.getElementById\(id\); if\(el\) el\.value=''; \}\);\n  try\{ setSupportOrder\(null\); \}catch\(_\)\{\}/);
  // a realtime change keeps the chosen row current
  assert.match(app, /updateNavBadge\(\);\n  try\{ refreshSupportOrderPick\(\); \}catch\(_\)\{\}\n\}/);
});

test('the admin\'s case list carries the transaction, only when it is the customer\'s own', () => {
  const fn=adminApi.slice(adminApi.indexOf('async list_support_cases('),adminApi.indexOf('async update_support_case('));
  assert.match(fn, /await db\.from\('ex_orders'\)\.select\('\*'\)\.in\('order_code', orderCodes\)/);
  assert.match(fn, /const order = found && found\.user_id === row\.user_id \? found : null;/);
  assert.match(fn, /const orderState = !row\.order_code \? null : order \? 'linked' : found \? 'other_customer' : 'missing';/);
});

function adminContext(){
  const c=vm.createContext({
    METHOD_META:{FastPay:{label:'FastPay',color:'#0aa'},FIB:{label:'FIB',color:'#60f'}},
    STATUS_CANCELLED:'هەڵوەشێنرایەوە',STATUS_APPROVED:'پەسەندکرا',STATUS_REJECTED:'ڕەتکرا',STATUS_NEEDS_CORRECTION:'x',STATUS_CORRECTED:'y',STATUS_REVIEW:'z',
    formatNum:v=>Number(v).toLocaleString('en-US'),fmtDateTime:()=>'21/11/2026 — 14:05',
    _supportCasesAdmin:[],allOrders:[],shown:[],loadProfilesFor:async ids=>({[ids[0]]:{id:ids[0],full_name:'Full Profile',username:'zana'}})
  });
  const pick=(a,b)=>admin.slice(admin.indexOf(a),admin.indexOf(b));
  vm.runInContext(pick('function walletMark(key){','if(typeof document')+pick('function statusBadgeClass(s){','function isAuthDbError(')
    +pick('// the transaction a case is about','async function saveSupportCaseAdmin(id){')
    +'function showOrderDetail(id){ shown.push(id); }',c);
  return c;
}

test('the admin sees the case\'s transaction and opens it in the order window', async () => {
  const c=adminContext();
  const order={id:'o-1',user_id:'u-1',order_code:'PAAAAAAAAAA1',from_method:'FastPay',to_method:'FIB',amount:60000,total:59100,status:'پەسەندکرا',created_at:'2026-11-21T10:00:00Z'};
  const row={id:'case-1',user_id:'u-1',order_code:'PAAAAAAAAAA1',order,order_state:'linked',profile:{id:'u-1',full_name:'Case Profile'}};
  const out=c.supportCaseOrderHTML(row);
  assert.match(out, /<button type="button" class="support-admin-order" onclick="showSupportCaseOrder\('case-1'\)"/);
  assert.match(out, /<b dir="ltr">60,000 IQD<\/b><span dir="ltr">PAAAAAAAAAA1<\/span><span>21\/11\/2026 — 14:05<\/span>/);
  assert.match(out, /<span class="badge approved">پەسەندکرا<\/span>/);
  assert.match(out, /بینینی مامەڵە<i class="fas fa-arrow-left"/);
  c._supportCasesAdmin.push(row);
  await c.showSupportCaseOrder('case-1');
  assert.deepEqual([...c.shown],['o-1']);
  assert.equal(c.allOrders[0].profile.username,'zana');
  // no code: nothing; a code that is not found or is another customer's: said plainly, nothing to open
  assert.equal(c.supportCaseOrderHTML({id:'c2',order_code:null}),'');
  assert.match(c.supportCaseOrderHTML({id:'c3',order_code:'PZZZZZZZZZZ9',order:null,order_state:'missing'}), /is-missing[\s\S]*ئەم مامەڵەیە نەدۆزرایەوە/);
  assert.match(c.supportCaseOrderHTML({id:'c4',order_code:'PZZZZZZZZZZ9',order:null,order_state:'other_customer'}), /ئەم مامەڵەیە هی کڕیارێکی ترە/);
  assert.doesNotMatch(admin, /<small>ئایدی مامەڵە<\/small>/);
});

test('styles: the empty field like the others, «لابردن» on the label row, and the sheet\'s frame', () => {
  assert.match(css, /#pageSupport \.sc-order-pick\.is-empty \{\n  display: flex !important; align-items: center !important; gap: 10px !important; height: 48px !important;/);
  assert.match(css, /#pageSupport \.sc-order-head \{ display: flex !important; align-items: center !important; justify-content: space-between !important;/);
  assert.match(css, /#pageSupport \.sc-order-clear \{\n  display: inline-flex !important;[^}]*color: var\(--sc-accent\) !important;/);
  assert.doesNotMatch(css, /padding-inline-end: 56px/);
  assert.match(css, /html body #supportOrderSheet \.sc-order-row\.is-picked \{ border-color: var\(--so-accent\);/);
  assert.match(css, /html\[data-theme="dark"\] body #supportOrderSheet \{\n  --so-sheet: #131c2e;/);
  assert.match(read('assets/css/admin.css'), /\.support-admin-order\{display:block;width:100%;/);
});
