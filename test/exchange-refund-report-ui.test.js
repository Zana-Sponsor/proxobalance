import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('../assets/js/exchange-refund-report.js',import.meta.url),'utf8');
const balanceSource=readFileSync(new URL('../assets/js/exchange-balance-admin.js',import.meta.url),'utf8');
const helpers=balanceSource.slice(balanceSource.indexOf('function balanceRecordedIqd('),balanceSource.indexOf('function balanceRecordedMoney('));
const adminId='11111111-1111-4111-8111-111111111111';
const userId='22222222-2222-4222-8222-222222222222';
const orderId='33333333-3333-4333-8333-333333333333';
const snapshot='2026-10-17T12:00:00.000Z';
const clone=value=>JSON.parse(JSON.stringify(value));
const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const order={id:orderId,user_id:userId,order_code:'P123456789AB',amount:50000,total:49000,from_method:'FastPay',to_method:'QiCard'};
function shortfall(index=1,extra={}){
  const id='44444444-4444-4444-8444-'+String(index).padStart(12,'0');
  return {id,order_id:orderId,order_code:order.order_code,user_id:userId,admin_id:adminId,amount_iqd:150,
    expected_iqd:49000,refunded_before_iqd:(index-1)*150,refunded_after_iqd:index*150,
    balance_before_iqd:1000+(index-1)*150,balance_after_iqd:1000+index*150,
    journal_id:'journal-'+index,request_key:id,verification_reference:'shortfall:'+id,
    reason:'Actual verified shortfall for this refund case',created_at:new Date(Date.parse('2026-10-17T10:00:00Z')+index*1000).toISOString(),...extra};
}
function fullRefund(extra={}){
  return {id:'55555555-5555-4555-8555-555555555555',order_id:orderId,user_id:userId,amount_iqd:50000,
    refund_kind:'admin_rejection',confirmed_payout_failed:false,verified_by:adminId,journal_id:'journal-full',
    failure_reason:'The administrator rejected the pending order',bank_verification_reference:'BANK-LEGACY-001',
    created_at:'2026-10-17T09:00:00.000Z',...extra};
}
function pageData(page=0,{refunds=[],shortfalls=[],more=false,...extra}={}){
  return {refunds,shortfalls,orders:{[orderId]:order},profiles:{[userId]:{full_name:'Customer One'},[adminId]:{full_name:'Auditor One'}},
    page,next_page:more?page+1:null,has_more:more,snapshot,...extra};
}
function harness(pages=[pageData()]){
  const elements=new Map(),calls=[],pdfs=[];let allowed=true,request=null;
  const el=id=>{
    if(!elements.has(id))elements.set(id,{value:'',disabled:false,textContent:'',attrs:{},handlers:{},
      setAttribute(name,value){this.attrs[name]=value;},addEventListener(name,fn){this.handlers[name]=fn;}});
    return elements.get(id);
  };
  const context=vm.createContext({document:{getElementById:el},adminUser:{id:adminId},staffCan:()=>allowed,
    esc:escapeHtml,Date,console,window:{html2canvas(){},jspdf:{jsPDF(){}}},showToast(){},
    pageConfig:{balance:{load(){}}},adminApiRequest:async(action,payload)=>{
      assert.equal(action,'balance_refund_report');calls.push(clone(payload));
      return request?request(payload):clone(pages[payload.page]);
    }});
  vm.runInContext(helpers,context);vm.runInContext(source,context);
  context.balanceCreateRefundPdf=async(report,rows,range,owner)=>{pdfs.push(clone({report,rows,range,owner}));return 2;};
  return {context,el,calls,pdfs,deny(){allowed=false;},setRequest(fn){request=fn;}};
}

test('PDF export fetches every page beyond the dashboard cap with one unchanged date range and snapshot',async()=>{
  const records=Array.from({length:203},(_,i)=>shortfall(i+1));
  const p=harness([
    pageData(0,{refunds:[fullRefund()],shortfalls:records.slice(0,100),more:true}),
    pageData(1,{shortfalls:records.slice(100,200),more:true,profiles:{[adminId]:{full_name:'Auditor from final profile page'}}}),
    pageData(2,{shortfalls:records.slice(200)})
  ]);
  p.el('balanceRefundReportFrom').value='2026-10-01';p.el('balanceRefundReportTo').value='2026-10-17';
  await p.context.exportBalanceRefundPdf();
  assert.equal(p.calls.length,3);assert.equal(p.pdfs.length,1);assert.equal(p.pdfs[0].rows.length,204);
  assert.deepEqual(p.calls[0],{date_from:'2026-10-01',date_to:'2026-10-17',page:0});
  for(let i=1;i<3;i++)assert.deepEqual(p.calls[i],{date_from:'2026-10-01',date_to:'2026-10-17',page:i,snapshot});
  assert.equal(p.pdfs[0].rows[0].id,records[202].id);
  assert.match(p.el('balanceRefundReportStatus').textContent,/204/);
  assert.equal(p.el('balanceRefundReportBtn').disabled,false);
});

test('normalized partial cases use immutable cumulative snapshots while credit totals count each case once',()=>{
  const p=harness(),data=pageData(0,{shortfalls:[shortfall(1),shortfall(2)]});
  data.orders[orderId]={...order,total:99999,shortfall_refunded_iqd:9999};
  const rows=clone(p.context.balanceRefundReportRecords(data));
  assert.deepEqual(rows.map(({expected,sent,unpaid,credited})=>({expected,sent,unpaid,credited})),[
    {expected:49000,sent:48700,unpaid:300,credited:150},{expected:49000,sent:48850,unpaid:150,credited:150}
  ]);
  assert.equal(rows.reduce((sum,row)=>sum+row.credited,0),300);
  assert.equal(rows[0].admin,'Auditor One');assert.equal(rows[0].customer,'Customer One');
});

test('full admin rejections keep sent and unpaid unknown; verified failed payouts use joined order expected amount',()=>{
  const p=harness();
  for(const patch of [{},{refund_kind:null},{refund_kind:'failed_payout',confirmed_payout_failed:false}]){
    const [row]=p.context.balanceRefundReportRecords(pageData(0,{refunds:[fullRefund(patch)]}));
    assert.equal(row.sent,null);assert.equal(row.unpaid,null);assert.equal(row.expected,49000);assert.equal(row.credited,50000);
  }
  const data=pageData(0,{refunds:[fullRefund({refund_kind:'failed_payout',confirmed_payout_failed:true})]});
  const [confirmed]=p.context.balanceRefundReportRecords(data);
  assert.equal(confirmed.sent,0);assert.equal(confirmed.unpaid,49000);assert.equal(confirmed.credited,50000);
  assert.equal(confirmed.adminId,adminId);
  for(const badOrder of [{},{...order,user_id:'wrong-user'},{...order,from_method:'USDT'}]){
    const report={...data,orders:{[orderId]:badOrder}},[row]=p.context.balanceRefundReportRecords(report);
    assert.equal(row.expected,null);assert.equal(row.sent,null);assert.equal(row.unpaid,null);
  }
});

test('missing financial snapshots never become fake zero amounts and large legitimate wallet balances remain exact',()=>{
  const p=harness();
  for(const value of [null,undefined,'',false,-1,150.5]){
    const [row]=p.context.balanceRefundReportRecords(pageData(0,{shortfalls:[shortfall(1,{balance_before_iqd:value,balance_after_iqd:value})]}));
    assert.equal(row.balanceBefore,null);assert.equal(row.balanceAfter,null);
  }
  const [large]=p.context.balanceRefundReportRecords(pageData(0,{shortfalls:[shortfall(1,{balance_before_iqd:'2000000000',balance_after_iqd:'2000000150'})]}));
  assert.equal(large.balanceBefore,2000000000);assert.equal(large.balanceAfter,2000000150);
  assert.throws(()=>p.context.balanceRefundReportRecords(pageData(0,{shortfalls:[shortfall(1,{created_at:null})]})));
  assert.throws(()=>p.context.balanceRefundReportRecords(pageData(0,{shortfalls:[shortfall(1,{amount_iqd:null})]})));
});

test('PDF cards escape data, keep the complete reason and omit redundant generated verification IDs',()=>{
  const p=harness(),reason=('Long note\n with <script>unsafe</script> evidence. ').repeat(44).slice(0,2000);
  const data=pageData(0,{shortfalls:[shortfall(1,{reason})]});
  data.profiles[userId].full_name='<img src=x onerror=alert(1)>';
  const [row]=p.context.balanceRefundReportRecords(data),card=p.context.balanceRefundReportCard(row,1);
  assert.equal(row.reason,reason.replace(/\s+/g,' ').trim());
  assert.match(card,/&lt;script&gt;unsafe&lt;\/script&gt;/);assert.match(card,/&lt;img src=x onerror=alert\(1\)&gt;/);
  assert.doesNotMatch(card,/<script>|<img /);assert.equal(row.reference,'');
  assert.doesNotMatch(card,/بەڵگەی تۆمارکراو/);
  assert.match(card,/48,850/);assert.match(card,/نێردراو هەژمارکراوە/);
  row.reference='BANK-OLD-<script>proof</script>';
  assert.match(p.context.balanceRefundReportCard(row,1),/BANK-OLD-&lt;script&gt;proof&lt;\/script&gt;/);
});

test('empty date ranges show an empty state and do not create a PDF',async()=>{
  const p=harness();await p.context.exportBalanceRefundPdf();
  assert.equal(p.calls.length,1);assert.equal(p.pdfs.length,0);
  assert.match(p.el('balanceRefundReportStatus').textContent,/هیچ گەڕاندنەوەیەک/);
  assert.equal(p.el('balanceRefundReportBtn').disabled,false);
});

test('permissions, valid date ranges and loaded PDF libraries are required before fetching data',async()=>{
  const denied=harness();denied.deny();await denied.context.exportBalanceRefundPdf();assert.equal(denied.calls.length,0);
  for(const [from,to] of [['2026-10-20','2026-10-01'],['2026-02-30',''],['invalid','']]){
    const p=harness();p.el('balanceRefundReportFrom').value=from;p.el('balanceRefundReportTo').value=to;
    await p.context.exportBalanceRefundPdf();assert.equal(p.calls.length,0);assert.notEqual(p.el('balanceRefundReportError').textContent,'');
  }
  const missing=harness();missing.context.window.html2canvas=null;
  await missing.context.exportBalanceRefundPdf();assert.equal(missing.calls.length,0);
});

test('a failed page, duplicate case, changed snapshot or looping page aborts the whole PDF',async()=>{
  const first=pageData(0,{shortfalls:[shortfall(1)],more:true});
  for(const second of [
    Error('Database unavailable'),
    pageData(1,{shortfalls:[shortfall(1)]}),
    pageData(1,{shortfalls:[shortfall(2)],snapshot:'2026-10-17T12:01:00.000Z'}),
    pageData(1,{shortfalls:[shortfall(2)],more:true,next_page:1}),
    pageData(1,{more:true}),
    pageData(1,{shortfalls:[shortfall(2)],snapshot:'2026-10-17'})
  ]){
    const p=harness();p.setRequest(({page})=>{
      if(page===0)return clone(first);if(second instanceof Error)throw second;return clone(second);
    });
    await p.context.exportBalanceRefundPdf();assert.equal(p.pdfs.length,0);assert.equal(p.calls.length,2);
    assert.notEqual(p.el('balanceRefundReportError').textContent,'');assert.equal(p.el('balanceRefundReportBtn').disabled,false);
  }
});

test('double clicks stay disabled during fetching and an identity change cancels export',async()=>{
  const p=harness();let resolve;
  p.setRequest(()=>new Promise(done=>{resolve=done;}));
  const first=p.context.exportBalanceRefundPdf();
  assert.equal(p.el('balanceRefundReportBtn').disabled,true);assert.equal(p.el('balanceRefundReportFrom').disabled,true);
  await p.context.exportBalanceRefundPdf();assert.equal(p.calls.length,1);
  p.context.adminUser.id='another-admin';resolve(pageData(0,{shortfalls:[shortfall(1)]}));await first;
  assert.equal(p.pdfs.length,0);assert.notEqual(p.el('balanceRefundReportError').textContent,'');
  assert.equal(p.el('balanceRefundReportFrom').disabled,false);
});

test('oversized exports request a narrower date range and never silently truncate',async()=>{
  const p=harness([pageData(0,{shortfalls:Array.from({length:2001},(_,i)=>shortfall(i+1))})]);
  await p.context.exportBalanceRefundPdf();assert.equal(p.pdfs.length,0);
  assert.match(p.el('balanceRefundReportError').textContent,/2,000/);assert.match(p.el('balanceRefundReportError').textContent,/ماوەیەکی کورتتر/);
});
