import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';

const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const source=read('assets/js/exchange-payout-rounding.js')+'\n'+read('assets/js/receipt-download.js');
const userId='11111111-1111-4111-8111-111111111111';
const order={id:'22222222-2222-4222-8222-222222222222',user_id:userId,order_code:'P123456789AB',
  status:'پەسەندکرا',from_method:'FastPay',to_method:'FIB',amount:11000,total:10500,
  payout_settlement_id:'33333333-3333-4333-8333-333333333333',payout_iqd:10000,payout_rounding_iqd:500,
  shortfall_refunded_iqd:650,created_at:'2026-10-17T10:00:00Z'};
const escape=value=>String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]);
class Node{
  constructor(tag='div'){this.tag=tag;this.children=[];this.style={};this.textContent='';this.removed=false;}
  append(...nodes){this.children.push(...nodes);}setAttribute(){}remove(){this.removed=true;}
  get outerHTML(){return '<'+this.tag+'>'+escape(this.textContent)+this.children.map(n=>n.outerHTML).join('')+'</'+this.tag+'>';}
}
function harness({fresh=order,readOrder,blocked=false}={}){
  const writes=[],events=[],toasts=[],filters=[],listeners={};
  const popup={closed:false,document:{open(){},write(html){writes.push(html);},close(){}},close(){this.closed=true;}};
  const document={createElement:tag=>new Node(tag),head:new Node('head'),body:new Node('body')};
  const chain={select(value){assert.equal(value,'*');return this;},eq(key,value){filters.push([key,value]);return this;},
    async maybeSingle(){events.push('read');return readOrder?readOrder():{data:fresh,error:null};}};
  const c=vm.createContext({document,curUser:{id:userId},_orders:[{...order,shortfall_refunded_iqd:500}],
    sb:{from(table){assert.equal(table,'ex_orders');return chain;}},
    methodLabel:String,txWhen:String,orderCodeOf:o=>o.order_code,
    window:{open(){events.push('open');return blocked?null:popup;},print(){events.push('print');},
      addEventListener(type,fn){listeners[type]=fn;}},showToast:(message,type)=>toasts.push({message,type}),console:{error(){}}});
  vm.runInContext(source,c);
  return {c,document,writes,events,toasts,filters,popup,listeners};
}
function rows(node){return node.className==='pb-rrow'?[[node.children[0].textContent,node.children[1].textContent]]:node.children.flatMap(rows);}
function receiptData(value){const {c}=harness();return new Map(rows(c.pbBuildReceipt(value)));}

test('customer receipt separates automatic and later manual returns without changing original pricing or payout target',()=>{
  const r=receiptData(order);
  assert.equal(r.get('بڕی سەرەکی داواکاری'),'11,000 د.ع');
  assert.equal(r.get('بڕی سەرەکی دوای لێبڕین'),'10,500 د.ع');
  assert.equal(r.get('بڕی ناردنی دیاریکراو بۆ وەرگر'),'10,000 د.ع');
  assert.equal(r.get('گەڕاندنەوەی خۆکار بۆ باڵانسی هەژمار'),'500 د.ع');
  assert.equal(r.get('بڕی کەم نێردراو کە ئادمین گەڕاندوویەتییەوە'),'150 د.ع');
  assert.equal(r.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'650 د.ع');
  assert.equal(r.get('بڕی نێردراوی هەژمارکراو بۆ وەرگر'),'9,850 د.ع');
  assert.equal(r.get('بڕی لێبڕین'),'500 د.ع');
});

test('manual legacy refunds are shown without inventing a rounding settlement',()=>{
  const legacy={...order,payout_settlement_id:null,payout_iqd:null,payout_rounding_iqd:null,shortfall_refunded_iqd:150};
  const r=receiptData(legacy);
  assert.equal(r.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'150 د.ع');
  assert.equal(r.get('بڕی نێردراوی هەژمارکراو بۆ وەرگر'),'10,350 د.ع');
  assert.equal(r.has('گەڕاندنەوەی خۆکار بۆ باڵانسی هەژمار'),false);
  assert.equal(r.has('بڕی ناردنی دیاریکراو بۆ وەرگر'),false);
  const unchanged=receiptData({...legacy,shortfall_refunded_iqd:0});
  assert.equal(unchanged.get('بڕی وەرگیراو'),'10,500 د.ع');
  assert.equal(unchanged.has('کۆی گەڕاوە بۆ باڵانسی هەژمار'),false);
});

test('pending refunds stay future and wallet-only settlements accurately show zero external payout',()=>{
  const pending=receiptData({...order,status:'چاوەڕوانە',payout_settlement_id:null,payout_iqd:null,payout_rounding_iqd:null,shortfall_refunded_iqd:0});
  assert.equal(pending.get('گەڕاندنەوە بۆ باڵانس دوای پەسەندکردن'),'500 د.ع');
  assert.equal(pending.has('کۆی گەڕاوە بۆ باڵانسی هەژمار'),false);
  assert.match(pending.get('دۆخی گەڕاندنەوە'),/هێشتا.*تۆمار نەکراوە/);
  const walletOnly=receiptData({...order,total:600,payout_iqd:0,payout_rounding_iqd:600,shortfall_refunded_iqd:600});
  assert.equal(walletOnly.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'600 د.ع');
  assert.equal(walletOnly.get('بڕی نێردراوی هەژمارکراو بۆ وەرگر'),'0 د.ع');
  const zero=receiptData({...order,total:0,payout_iqd:0,payout_rounding_iqd:0,shortfall_refunded_iqd:0});
  assert.equal(zero.has('کۆی گەڕاوە بۆ باڵانسی هەژمار'),false);
});

test('missing or inconsistent cumulative values do not become zero or a fabricated manual refund',()=>{
  for(const value of [null,undefined,'',false,-1,0,400,10501,'invalid']){
    const r=receiptData({...order,shortfall_refunded_iqd:value});
    assert.equal(r.get('گەڕاندنەوەی خۆکار بۆ باڵانسی هەژمار'),'500 د.ع');
    assert.equal(r.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'— د.ع');
    assert.equal(r.get('بڕی کەم نێردراو کە ئادمین گەڕاندوویەتییەوە'),'— د.ع');
    assert.equal(r.get('بڕی نێردراوی هەژمارکراو بۆ وەرگر'),'— د.ع');
  }
  const malformed=receiptData({...order,payout_iqd:9999});
  assert.equal(malformed.has('گەڕاندنەوەی خۆکار بۆ باڵانسی هەژمار'),false);
  assert.equal(malformed.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'— د.ع');
});

test('full refund returns the trusted original principal and keeps unknown legacy payout unknown',()=>{
  const full={...order,status:'ڕەتکرا',amount:10000,total:9750,payout_settlement_id:null,payout_iqd:null,
    payout_rounding_iqd:null,shortfall_refunded_iqd:0,balance_refunded_at:'2026-10-17T11:00:00Z',
    balance_refund_case_id:'44444444-4444-4444-8444-444444444444'};
  const r=receiptData(full);
  assert.equal(r.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'10,000 د.ع');
  assert.equal(r.get('بڕی سەرەکی دوای لێبڕین'),'9,750 د.ع');
  assert.equal(r.get('بڕی لێبڕین'),'250 د.ع');
  assert.equal(r.get('بڕی نێردراو بۆ وەرگر'),'تۆمار نەکراوە');
  const incomplete=receiptData({...full,balance_refund_case_id:null});
  assert.equal(incomplete.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'— د.ع');
});

test('PDF click opens synchronously, refreshes this owner and order, and prints the latest cumulative return once',async()=>{
  let resolveRead;const pending=new Promise(resolve=>{resolveRead=resolve;});
  const h=harness({readOrder:()=>pending});
  const run=h.c.downloadTransactionReceipt(order.id);
  await h.c.downloadTransactionReceipt(order.id);
  assert.deepEqual(h.events,['open','read']);
  assert.deepEqual(h.filters,[['id',order.id],['user_id',userId]]);
  resolveRead({data:order,error:null});await run;
  assert.equal(h.writes.length,2);
  assert.match(h.writes[1],/650 د.ع/);assert.match(h.writes[1],/9,850 د.ع/);
  assert.equal(h.popup.closed,false);
});

test('read errors and an owner change close the new window without printing cached financial values',async()=>{
  for(const result of [{data:null,error:{message:'offline'}},{data:{...order,user_id:'another-user'},error:null}]){
    const h=harness({readOrder:()=>result});await h.c.downloadTransactionReceipt(order.id);
    assert.equal(h.popup.closed,true);assert.equal(h.writes.length,1);
    assert.equal(h.toasts.at(-1).type,'error');
  }
  let resolveRead;const h=harness({readOrder:()=>new Promise(resolve=>{resolveRead=resolve;})});
  const run=h.c.downloadTransactionReceipt(order.id);h.c.curUser={id:'another-user'};
  resolveRead({data:order,error:null});await run;
  assert.equal(h.popup.closed,true);assert.equal(h.writes.length,1);
});

test('blocked popups preserve the same fresh receipt through the existing in-page print fallback',async()=>{
  const h=harness({blocked:true});await h.c.downloadTransactionReceipt(order.id);
  assert.deepEqual(h.events,['open','read','print']);
  const r=new Map(rows(h.document.body.children[0]));
  assert.equal(r.get('کۆی گەڕاوە بۆ باڵانسی هەژمار'),'650 د.ع');
  h.listeners.afterprint();
  assert.equal(h.document.body.children[0].removed,true);
});
