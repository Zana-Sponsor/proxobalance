import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const helper=read('assets/js/exchange-payout-rounding.js');
const app=read('assets/js/app.js');
const admin=read('assets/js/admin.js');
const approved='پەسەندکرا',pending='چاوەڕوانە';
const orderId='11111111-1111-4111-8111-111111111111';
const actorId='22222222-2222-4222-8222-222222222222';
const customerId='33333333-3333-4333-8333-333333333333';
const settlementId='44444444-4444-4444-8444-444444444444';
const base={id:orderId,user_id:customerId,order_code:'P1ROUNDED',from_method:'FastPay',to_method:'FIB',
  amount:11000,total:10500,fee:500,phone:'07501234567',receipt_url:'https://example.test/incoming.jpg',
  payout_receipt_url:null,admin_note:'Original note',status:pending,shortfall_refunded_iqd:0,
  updated_at:'2026-10-17T21:00:00.000Z',profile:{full_name:'Fixture Customer'}};
const helperContext=vm.createContext({});vm.runInContext(helper,helperContext);
const rounding=helperContext.ProxoPayoutRounding;
const savedOrder=(order=base)=>({...order,status:approved,payout_iqd:Math.floor(order.total/1000)*1000,
  payout_rounding_iqd:order.total%1000,payout_settlement_id:settlementId,shortfall_refunded_iqd:order.total%1000});

test('whole-thousand plans conserve the original net, including zero and wallet-only settlement',()=>{
  for(const [total,payout,credit] of [[10500,10000,500],[1600,1000,600],[1000,1000,0],[1999,1000,999],
    [999,0,999],[1,0,1],[0,0,0],[1000000000,1000000000,0]]){
    const p=rounding.plan(total,'FIB');
    assert.equal(p.valid,true);assert.equal(p.payout_iqd,payout);assert.equal(p.remainder_iqd,credit);
    assert.equal(p.expected_iqd,payout+credit);assert.equal(p.requires_payout,payout>0);
    assert.equal(Object.isFrozen(p),true);
  }
});
test('missing, fractional and corrupt net values never become a zero payout',()=>{
  for(const value of [null,undefined,'',false,true,' ',NaN,Infinity,-1,1000000001,10500.5,'10,500','10500x']){
    const p=rounding.plan(value,'FIB');
    assert.equal(p.applies,true);assert.equal(p.valid,false);
    assert.equal(p.expected_iqd,null);assert.equal(p.payout_iqd,null);assert.equal(p.remainder_iqd,null);
  }
  assert.equal(rounding.plan('10500.00','FIB').payout_iqd,10000);
});
test('recipient currency governs policy and dynamically configured IQD wallets remain supported',()=>{
  for(const key of ['FIB','FastPay','QiCard','Korek','Asiacell','AddedWallet'])assert.equal(rounding.plan(1600,key).valid,true);
  for(const key of ['USDT','AccountBalance','',null,undefined,17,' FIB','FIB ','FIB\n']){
    const p=rounding.plan(1600,key);assert.equal(p.applies,false);assert.equal(p.payout_iqd,null);
  }
  assert.equal(rounding.forOrder({...base,from_method:'USDT'}).payout_iqd,10000);
});
test('pending previews and saved settlements are distinct; legacy completed records are never rounded',()=>{
  const preview=rounding.forOrder(base);assert.equal(preview.planned,true);assert.equal(preview.settled,false);
  assert.equal(preview.display_amount,10000);
  const settled=rounding.forOrder(savedOrder());assert.equal(settled.settled,true);assert.equal(settled.planned,false);
  const legacy=rounding.forOrder({...base,status:approved});
  assert.equal(legacy.legacy,true);assert.equal(legacy.display_amount,10500);assert.equal(legacy.payout_iqd,null);
  const rejected=rounding.forOrder({...base,status:'ڕەتکرا'});
  assert.equal(rejected.planned,false);assert.equal(rejected.remainder_iqd,null);
  const manual=rounding.forOrder({...savedOrder(),shortfall_refunded_iqd:650});
  assert.equal(manual.payout_iqd,10000);assert.equal(manual.remainder_iqd,500);
});
test('incomplete or inconsistent settlement snapshots cannot invent an external amount',()=>{
  for(const patch of [{payout_settlement_id:null},{payout_iqd:null},{payout_rounding_iqd:null},
    {payout_iqd:10500},{payout_rounding_iqd:650},{total:9999},{status:pending},{balance_refunded_at:'2026-10-17'}]){
    const p=rounding.forOrder({...savedOrder(),...patch});
    assert.equal(p.valid,false);assert.equal(p.display_amount,null);assert.equal(p.payout_iqd,null);
  }
});
test('later proof attachment is available only for positive automatic-only settlements without a receipt',()=>{
  assert.equal(rounding.canAttachReceipt(savedOrder()),true);
  for(const patch of [{payout_receipt_url:'https://example.test/paid.jpg'},{shortfall_refunded_iqd:650},
    {shortfall_refunded_iqd:null},{status:pending}])assert.equal(rounding.canAttachReceipt({...savedOrder(),...patch}),false);
  assert.equal(rounding.canAttachReceipt(savedOrder({...base,total:600})),false);
  assert.equal(rounding.canAttachReceipt({...base,status:approved,shortfall_refunded_iqd:150}),false);
});

function elements(){
  const rows=new Map();
  return id=>{if(!rows.has(id))rows.set(id,{value:'',textContent:'',innerText:'',innerHTML:'',outerHTML:'',files:[],hidden:false,
    disabled:false,style:{},dataset:{},attributes:{},classList:{add(){},remove(){}},
    setAttribute(key,value){this.attributes[key]=value;}});return rows.get(id);};
}
const number=value=>Number(value).toLocaleString('en-US');
const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function quoteContext(){
  const element=elements();element('from').value='FastPay';element('receiveVia').value='FIB';
  const c=vm.createContext({document:{getElementById:element},amount:'60000',curUser:{id:customerId},
    MY_REWARDS:[{kind:'free_transactions',discount_percent:100,max_amount_iqd:50000,
      id:'reward',active:true,max_uses:2,used_count:0,created_at:'2026-01-01T00:00:00Z'}],
    RATES:{'FastPay>FIB':{type:'fee_percent',value:2}},MIN_AMOUNT:10000,formatNum:number,fmtPct:String,
    refreshFormHints(){},updateSubmitState(){element('submitBtn').disabled=false;},updateHeaderRate(){},
    routeAllowed:()=>true,METHOD_META:{},getWalletInfo:()=>({locked:false})});
  vm.runInContext(read('assets/js/exchange-reward-pricing.js')+'\n'+helper,c);
  vm.runInContext('function getAmtRaw(){return amount;}',c);
  vm.runInContext(app.slice(app.indexOf('function availableFeeReward('),app.indexOf('// Smallest amount'))+'\n'+
    app.slice(app.indexOf('function calc(){'),app.indexOf('function _validateOrderFields()')),c);
  return {c,element};
}
test('customer quote preserves reward and fee math while separately displaying payout and automatic credit',()=>{
  const {c,element}=quoteContext();c.calc();
  assert.equal(element('totalDisplay').innerText,'59,800 IQD');
  assert.equal(element('payoutDisplay').textContent,'59,000 IQD');
  assert.equal(element('roundingDisplay').textContent,'800 IQD');
  assert.equal(element('bdFee').textContent,'200 IQD');
  assert.match(element('rewardBanner').textContent,/50,000/);
  assert.match(element('payoutRoundingNote').textContent,/دوای پەسەندکردن/);
  c.amount='11000';c.MY_REWARDS=[];c.RATES['FastPay>FIB']={type:'fee_fixed',value:9400};c.calc();
  assert.equal(element('payoutDisplay').textContent,'1,000 IQD');assert.equal(element('roundingDisplay').textContent,'600 IQD');
  c.RATES['FastPay>FIB'].value=10400;c.calc();
  assert.equal(element('payoutDisplay').textContent,'0 IQD');assert.equal(element('roundingDisplay').textContent,'600 IQD');
  assert.match(element('payoutRoundingNote').textContent,/هیچ بڕێک بۆ وەرگر نانێردرێت/);
});
test('fractional IQD principal is rejected while the USDT source display preserves decimals',()=>{
  const {c,element}=quoteContext();c.amount='60000.5';c.calc();
  assert.match(element('totalDisplay').innerText,/دیناری تەواو/);assert.equal(element('bdPayoutRow').hidden,true);
  element('from').value='USDT';c.RATES['USDT>FIB']={type:'multiplier',value:1500};c.amount='1.1';c.calc();
  assert.equal(element('bdSent').textContent,'1.1 $');
});
test('customer order cards show saved payout and posted credit without rounding legacy records',()=>{
  const c=vm.createContext({formatNum:number,escHtml:escape,methodLabel:String,kycFmtDate:String,ICON:{arrowLeftLong:''}});
  vm.runInContext(helper+'\n'+app.slice(app.indexOf('function orderCodeOf('),app.indexOf('// ── transaction details')),c);
  const card=c.orderCardHTML(savedOrder());
  assert.match(card,/10,000 IQD/);assert.match(card,/500 IQD/);assert.match(card,/گەڕاوەتەوە بۆ باڵانست/);
  const pendingCard=c.orderCardHTML(base);assert.match(pendingCard,/دوای پەسەندکردن بۆ باڵانست/);
  assert.doesNotMatch(pendingCard,/گەڕاوەتەوە بۆ باڵانست/);
  const legacy=c.orderCardHTML({...base,status:approved});assert.match(legacy,/10,500 IQD/);
  assert.doesNotMatch(legacy,/tx-rounding-credit/);
  const manual=c.orderCardHTML({...savedOrder(),shortfall_refunded_iqd:650});assert.match(manual,/10,000 IQD/);
});
test('customer receipt preserves pricing, saved target and automatic refund; fractional USDT is not truncated',()=>{
  class Node{
    constructor(){this.children=[];this.style={};this.textContent='';}
    append(...items){this.children.push(...items);}setAttribute(){}
  }
  const c=vm.createContext({document:{createElement:()=>new Node()},methodLabel:String,txWhen:String,orderCodeOf:o=>o.order_code});
  vm.runInContext(helper+'\n'+read('assets/js/receipt-download.js'),c);
  const rows=node=>node.className==='pb-rrow'?[[node.children[0].textContent,node.children[1].textContent]]:node.children.flatMap(rows);
  const data=new Map(rows(c.pbBuildReceipt({...savedOrder(),shortfall_refunded_iqd:650})));
  assert.equal(data.get('بڕی سەرەکی دوای لێبڕین'),'10,500 د.ع');
  assert.equal(data.get('بڕی ناردنی دیاریکراو بۆ وەرگر'),'10,000 د.ع');
  assert.equal(data.get('گەڕاندنەوەی خۆکار بۆ باڵانسی هەژمار'),'500 د.ع');
  assert.equal(data.get('بڕی لێبڕین'),'500 د.ع');
  const usdt=new Map(rows(c.pbBuildReceipt(savedOrder({...base,from_method:'USDT',amount:1.1,total:1600}))));
  assert.equal(usdt.get('بڕی نێردراو'),'1.1 $');
  assert.equal(usdt.get('بڕی ناردنی دیاریکراو بۆ وەرگر'),'1,000 د.ع');
  const legacy=new Map(rows(c.pbBuildReceipt({...base,status:approved})));
  assert.equal(legacy.get('بڕی وەرگیراو'),'10,500 د.ع');
  assert.equal(legacy.has('گەڕاندنەوەی خۆکار بۆ باڵانسی هەژمار'),false);
});

function approvalContext({order={...base},storage=new Map(),api,upload}={}){
  const element=elements(),posts=[],toasts=[];let generated=0,uploads=0;
  const c=vm.createContext({document:{getElementById:element},allOrders:[order],adminUser:{id:actorId},
    STATUS_APPROVED:approved,REVIEWABLE_ORDER_STATUSES:new Set([pending,'ڕاستکراوەتەوە']),
    crypto:{randomUUID:()=>`55555555-5555-4555-8555-${String(++generated).padStart(12,'0')}`},
    sessionStorage:{getItem:key=>storage.get(key)??null,setItem:(key,value)=>storage.set(key,value),removeItem:key=>storage.delete(key)},
    formatNum:number,esc:escape,fmtCode:String,orderCodeOf:o=>o.order_code||o.id,
    methodPill:key=>'<span>'+escape(key)+'</span>',openMo(){},closeMo(){},refreshOrdersEverywhere(){},showOrderDetail(){},
    showToast:(...args)=>toasts.push(args),
    adminApiRequest:async(action,payload)=>{posts.push({action,payload:JSON.parse(JSON.stringify(payload))});
      return api?api(action,payload):savedOrder(order);}});
  vm.runInContext(helper,c);
  vm.runInContext(admin.slice(admin.indexOf('let _apFile=null'),admin.indexOf('function showRejectReason(')),c);
  c.uploadReceiptFile=async()=>{uploads++;return upload?upload():'https://example.test/payout.jpg';};
  return {c,element,posts,toasts,storage,get uploads(){return uploads;},get generated(){return generated;}};
}
test('approval sends the reviewed baseline even if realtime replaces the visible order before submit',async()=>{
  const h=approvalContext();h.c.approveOrder(orderId);
  assert.match(h.element('apReview').innerHTML,/07501234567/);assert.match(h.element('apReview').innerHTML,/10,000/);
  h.c.allOrders[0]={...base,phone:'07709999999',total:20500,admin_note:'Changed',updated_at:'2026-10-17T22:00:00Z'};
  await h.c.confirmApproveOrder();
  assert.equal(h.posts.length,1);const p=h.posts[0].payload;
  assert.equal(p.expected_total,10500);assert.equal(p.confirmed_payout_iqd,10000);
  assert.equal(p.expected_updated_at,base.updated_at);assert.equal(p.admin_note,'Original note');
  assert.equal(p.confirmed_received,true);assert.equal(p.confirmed_paid,true);assert.equal(h.storage.size,0);
});
test('wallet-only and zero-net approval confirm funding without claiming an external payment',async()=>{
  for(const total of [600,0]){
    const h=approvalContext({order:{...base,total}});h.c.approveOrder(orderId);
    assert.equal(h.element('apReceiptWrap').hidden,true);assert.match(h.element('apConfirmBtn').textContent,/بێ ناردنی دەرەکی/);
    await h.c.confirmApproveOrder();
    assert.equal(h.posts[0].payload.confirmed_payout_iqd,0);assert.equal(h.posts[0].payload.confirmed_paid,false);
    assert.equal(h.posts[0].payload.confirmed_received,true);assert.equal(h.posts[0].payload.payout_receipt_url,null);
  }
});
test('approval guards duplicate clicks while its single request is in flight',async()=>{
  let release;const wait=new Promise(resolve=>{release=resolve;});
  const h=approvalContext({api:async()=>{await wait;return savedOrder();}});h.c.approveOrder(orderId);
  const first=h.c.confirmApproveOrder();await h.c.confirmApproveOrder();
  assert.equal(h.posts.length,1);assert.equal(h.element('apConfirmBtn').disabled,true);
  release();await first;assert.equal(h.storage.size,0);
});
test('an unknown approval outcome survives reload with the exact request, baseline and uploaded receipt',async()=>{
  const storage=new Map();let original;
  const h=approvalContext({storage,api:async(_action,payload)=>{original=JSON.parse(JSON.stringify(payload));throw Error('Network response lost');}});
  h.c.approveOrder(orderId);vm.runInContext('_apFile={name:"proof.png",size:1};',h.c);
  await h.c.confirmApproveOrder();assert.equal(h.storage.size,1);assert.equal(h.uploads,1);
  const reloaded=approvalContext({storage,order:{...base,phone:'07709999999',updated_at:'2026-10-17T22:00:00Z'},api:async()=>savedOrder()});
  reloaded.c.approveOrder(orderId);
  assert.match(reloaded.element('apReview').innerHTML,/07501234567/);
  assert.doesNotMatch(reloaded.element('apReview').innerHTML,/07709999999/);
  assert.equal(reloaded.element('apReceiptFile').disabled,true);
  await reloaded.c.confirmApproveOrder();
  assert.deepEqual(reloaded.posts[0].payload,original);assert.equal(reloaded.uploads,0);assert.equal(storage.size,0);
});
test('only definitive mapped stale errors clear pending approval; arbitrary stale text preserves it',async()=>{
  for(const error of [Object.assign(Error('upstream stale timeout'),{status:500}),Error('network stale response')]){
    const h=approvalContext({api:async()=>{throw error;}});h.c.approveOrder(orderId);await h.c.confirmApproveOrder();
    assert.equal(h.storage.size,1);assert.equal(h.element('apConfirmBtn').disabled,false);
  }
  for(const code of ['approval_stale','already_decided']){
    const h=approvalContext({api:async()=>{throw Object.assign(Error('Order changed'),{status:409,code});}});
    h.c.approveOrder(orderId);await h.c.confirmApproveOrder();
    assert.equal(h.storage.size,0);assert.equal(h.element('apConfirmBtn').disabled,true);
  }
});
test('validation failures after an unknown earlier attempt do not discard its identity',async()=>{
  let calls=0;const h=approvalContext({api:async()=>{calls++;throw calls===1?Error('No response'):
    Object.assign(Error('New API validation'),{status:400,code:'approval_refresh_required'});}});
  h.c.approveOrder(orderId);await h.c.confirmApproveOrder();await h.c.confirmApproveOrder();
  assert.equal(h.storage.size,1);assert.deepEqual(h.posts[0].payload,h.posts[1].payload);
});
test('storage failure and invalid baselines stop approval before the financial request',async()=>{
  const h=approvalContext();h.c.approveOrder(orderId);
  h.c.sessionStorage.setItem=()=>{throw Error('Quota full');};await h.c.confirmApproveOrder();
  assert.equal(h.posts.length,0);assert.match(h.element('apError').textContent,/هیچ پەسەندکردنێک نەنێردرا/);
  for(const patch of [{updated_at:null},{total:null},{total:10500.5},{to_method:' FIB'},{total:600,payout_receipt_url:'https://example.test/proof.jpg'}]){
    const invalid=approvalContext({order:{...base,...patch}});invalid.c.approveOrder(orderId);await invalid.c.confirmApproveOrder();
    assert.equal(invalid.posts.length,0);assert.equal(invalid.element('apConfirmBtn').disabled,true);
  }
});
test('pending storage is scoped to the authenticated admin and order',async()=>{
  const h=approvalContext({api:async()=>{throw Error('Unknown outcome');}});h.c.approveOrder(orderId);await h.c.confirmApproveOrder();
  const key=[...h.storage.keys()][0];assert.equal(key,`proxo:approval:pending:v1:${actorId}:${orderId}`);
  h.c.adminUser={id:'66666666-6666-4666-8666-666666666666'};await h.c.confirmApproveOrder();
  assert.equal(h.posts.length,1);assert.equal(h.storage.size,1);
});
test('switching admin during receipt upload cannot post or persist approval under the new actor',async()=>{
  let release;const wait=new Promise(resolve=>{release=resolve;});
  const h=approvalContext({upload:async()=>{await wait;return 'https://example.test/paid.jpg';}});
  h.c.approveOrder(orderId);vm.runInContext('_apFile={name:"proof.png",size:1};',h.c);
  const posting=h.c.confirmApproveOrder();
  h.c.adminUser={id:'66666666-6666-4666-8666-666666666666'};
  release();await posting;
  assert.equal(h.posts.length,0);assert.equal(h.storage.size,0);assert.equal(h.element('apConfirmBtn').disabled,true);
});
