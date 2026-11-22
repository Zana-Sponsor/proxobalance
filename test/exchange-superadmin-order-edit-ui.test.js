import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('../assets/js/exchange-order-manual.js',import.meta.url),'utf8');
const baseOrder={id:'ord-1',amount:100000,total:97000,from_method:'AccountBalance',to_method:'USDT',status:'چاوەڕوانە',updated_at:'2026-01-01T00:00:00Z',admin_note:'old'};
function setup({superAdmin=true,order={...baseOrder},response={balance_delta:5000,balance_after_iqd:25000}}={}){
  const els={};const toasts=[];let payload;
  const context=vm.createContext({
    allOrders:[order],allWallets:[],isSuperAdmin:()=>superAdmin,
    document:{getElementById:id=>els[id]||null,createElement:()=>({className:'',id:'',innerHTML:'',appendChild(){}}),body:{appendChild(){}},querySelectorAll:()=>[],querySelector:()=>null},
    openMo(){},closeMo(){},fmtCode:x=>x,orderCodeOf:o=>o.id,showToast:(...x)=>toasts.push(x),
    adminApiRequest:async(a,p)=>{payload={action:a,...p};return response;},renderOrders(){},refreshOrdersEverywhere(){},
    crypto:{randomUUID:()=> 'uuid-fresh'},console
  });
  context.window=context;
  context.esc=x=>String(x??'');
  context.ProxoOrderManual=undefined;
  vm.runInContext(source,context);
  els.omErr={style:{},textContent:''};
  els.omReason={value:'correction reason'};
  for(const [key,value] of Object.entries(order))els['omf_'+key]={value:String(value??''),addEventListener(){}};
  els.omf_admin_note={value:order.admin_note||''};
  return {api:context.ProxoOrderManual,els,toasts,get payload(){return payload;},context};
}

test('order edit action and open/save are gated to strict super-admin',()=>{
  const h=setup({superAdmin:false});
  assert.doesNotMatch(h.api.buttonsHTML(baseOrder),/ProxoOrderManual\.open\('edit'/);
  h.api.open('edit','ord-1');
  h.api.saveEdit('ord-1');
  assert.equal(h.payload,undefined);
  assert.ok(h.toasts.some(t=>String(t[0]).includes('سوپەر')));
});

test('AccountBalance eligible amount can change while other financial fields stay locked; protected states lock all financial fields',()=>{
  const h=setup();
  const L=h.api._locks(baseOrder).locked;
  assert.equal(L.includes('amount'),false);
  const staff=setup({superAdmin:false});assert.ok(staff.api._locks(baseOrder).locked.includes('amount'));
  for(const f of ['total','from_method','to_method'])assert.ok(L.includes(f));
  for(const protectedOrder of [
    {...baseOrder,payout_settlement_id:'settlement'},
    {...baseOrder,balance_refunded_at:'2025-01-01'},
    {...baseOrder,shortfall_refunded_iqd:1}
  ])assert.ok(h.api._locks(protectedOrder).locked.includes('amount'));
  assert.ok(h.api._locks({...baseOrder,from_method:'USDT'}).locked.includes('amount'));
});

test('amount preview uses old minus new and displays old/new values and delta',()=>{
  const h=setup();
  assert.equal(h.api._amountDelta(baseOrder,95000),5000);
  assert.equal(h.api._amountDelta(baseOrder,105000),-5000);
  h.els.omAmountPreview={textContent:''};h.els.omf_amount={value:'95000'};
  h.api._previewAmount('ord-1');
  assert.match(h.els.omAmountPreview.textContent,/100,000/);
  assert.match(h.els.omAmountPreview.textContent,/95,000/);
  assert.match(h.els.omAmountPreview.textContent,/5,000/);
});

test('save sends request key and revision and reports returned adjustment and resulting balance',async()=>{
  const h=setup();h.els.omf_amount.value='95000';
  h.api.saveEdit('ord-1');
  await new Promise(resolve=>setTimeout(resolve,0));
  assert.equal(h.payload.action,'order_update');
  assert.deepEqual(JSON.parse(JSON.stringify(h.payload.fields)),{amount:95000});
  assert.equal(h.payload.expected_updated_at,baseOrder.updated_at);
  assert.equal(h.payload.request_key,'uuid-fresh');
  const message=h.toasts.find(t=>String(t[0]).includes('دەستکاری'))?.[0]||'';
  assert.match(message,/5,000/);
  assert.match(message,/25,000/);
});
