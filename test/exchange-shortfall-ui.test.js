import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('../assets/js/exchange-balance-admin.js',import.meta.url),'utf8');
const adminHtml=readFileSync(new URL('../exchange-admin.html',import.meta.url),'utf8');
const customerSource=readFileSync(new URL('../assets/js/exchange-balance.js',import.meta.url),'utf8');
const userId='22222222-2222-4222-8222-222222222222';
const adminId='11111111-1111-4111-8111-111111111111';
const orderId='33333333-3333-4333-8333-333333333333';
const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const copy=value=>JSON.parse(JSON.stringify(value));
function element(){
  let html='',text='';
  return {value:'',checked:false,disabled:false,hidden:false,handlers:{},attrs:{},
    get innerHTML(){return html;},set innerHTML(value){html=String(value);text=html.replace(/<[^>]*>/g,'');},
    get textContent(){return text;},set textContent(value){text=String(value);html=escapeHtml(text);},
    addEventListener(name,handler){this.handlers[name]=handler;},
    setAttribute(name,value){this.attrs[name]=value;},
    scrollIntoView(){},focus(){this.focused=true;}
  };
}
function panel({storage=new Map(),owner=adminId,uuidStart=0}={}){
  const elements=new Map(),calls=[],confirmations=[],toasts=[];
  const el=id=>{if(!elements.has(id))elements.set(id,element());return elements.get(id);};
  let keyCount=uuidStart,allowed=true,creditImpl=null,lookupImpl=null;
  let lookup={order:{id:orderId,user_id:userId,order_code:'P123456789AB',amount:50000,total:49000,
      from_method:'FastPay',to_method:'QiCard',status:'پەسەندکرا',balance_refunded_at:null,
      receipt_url:'https://example.invalid/sender-receipt.jpg',payout_receipt_url:'https://example.invalid/payout.jpg',
      shortfall_refunded_iqd:0,created_at:'2026-10-17T10:00:00Z'},
    profile:{full_name:'Customer One'},profiles:{[adminId]:{full_name:'Auditor One'}},
    balance:{user_id:userId,available_iqd:1000,held_iqd:0},refund:null,shortfalls:[],
    shortfall_summary:{eligible:true,expected_iqd:49000,refunded_iqd:0,remaining_iqd:49000,code:null}};
  const dashboard=()=>({balances:[lookup.balance],refunds:lookup.refund?[lookup.refund]:[],
    shortfalls:lookup.shortfalls,payouts:[],alerts:[],config:{},reconciliation:{},
    profiles:{[userId]:lookup.profile,[adminId]:{full_name:'Auditor One'}}});
  const postCredit=payload=>{
    const existing=lookup.shortfalls.find(row=>row.request_key===payload.request_key);
    if(existing)return copy(existing);
    const before=Number(lookup.balance.available_iqd),refunded=Number(lookup.shortfall_summary.refunded_iqd);
    const row={id:'44444444-4444-4444-8444-444444444444',user_id:userId,admin_id:adminId,
      order_id:payload.order_id,order_code:lookup.order.order_code,journal_id:'55555555-5555-4555-8555-555555555555',
      request_key:payload.request_key,amount_iqd:payload.amount_iqd,expected_iqd:lookup.order.total,
      refunded_before_iqd:refunded,refunded_after_iqd:refunded+payload.amount_iqd,
      balance_before_iqd:before,balance_after_iqd:before+payload.amount_iqd,
      reason:payload.reason,verification_reference:payload.verification_reference??'shortfall:'+payload.request_key.toLowerCase(),created_at:'2026-10-17T11:00:00Z'};
    lookup.balance.available_iqd=row.balance_after_iqd;
    lookup.order.shortfall_refunded_iqd=row.refunded_after_iqd;
    Object.assign(lookup.shortfall_summary,{refunded_iqd:row.refunded_after_iqd,
      remaining_iqd:row.expected_iqd-row.refunded_after_iqd,eligible:row.refunded_after_iqd<row.expected_iqd});
    lookup.shortfalls.unshift(row);return copy(row);
  };
  const context=vm.createContext({
    document:{getElementById:id=>id==='balanceShortfallReference'?null:el(id)},esc:escapeHtml,Date,console,
    adminUser:{id:owner},sessionStorage:{getItem:key=>storage.get(key)??null,
      setItem:(key,value)=>storage.set(key,String(value)),removeItem:key=>storage.delete(key)},
    crypto:{randomUUID:()=>`00000000-0000-4000-8000-${String(++keyCount).padStart(12,'0')}`},
    allOrders:[copy(lookup.order)],staffCan:()=>allowed,
    showToast:(...args)=>toasts.push(args),confirm:value=>{confirmations.push(value);return true;},
    closeMo(){},goPage(){},
    adminApiRequest:async(action,payload={})=>{
      calls.push({action,payload:copy(payload)});
      if(action==='balance_lookup_order')return lookupImpl?lookupImpl(payload):copy(lookup);
      if(action==='balance_dashboard')return copy(dashboard());
      if(action==='balance_credit_shortfall')return creditImpl?creditImpl(payload):postCredit(payload);
      if(action==='balance_credit_refund'){
        lookup.refund={order_id:payload.order_id,user_id:userId,amount_iqd:lookup.order.amount};
        lookup.order.status='ڕەتکرا';return copy(lookup.refund);
      }
      throw Error('Unexpected test action: '+action);
    }
  });
  vm.runInContext(source,context);
  const fill=(amount='150')=>{
    el('balanceShortfallAmount').value=amount;
    el('balanceShortfallReason').value='Actual payout was short by the stated amount';
    el('balanceShortfallConfirmed').checked=true;
    el('balanceShortfallForm').handlers.input();
  };
  return {context,el,calls,confirmations,toasts,fill,postCredit,storage,
    credits:()=>calls.filter(c=>c.action==='balance_credit_shortfall'),
    get lookup(){return lookup;},setLookup(value){lookup=value;},
    setCredit(fn){creditImpl=fn;},setLookupImpl(fn){lookupImpl=fn;},deny(){allowed=false;},
    async select(search='P123456789AB'){el('balanceOrderSearch').value=search;await context.lookupBalanceOrder();}
  };
}

test('approved order previews exact shortfall against recipient total and fresh wallet balance',async()=>{
  const p=panel();await p.select();p.fill('۱۵۰');
  assert.equal(p.el('balanceShortfallBtn').disabled,false);
  assert.equal(p.el('balanceCreditBtn').disabled,true);
  const html=p.el('balanceShortfallPreview').innerHTML;
  for(const value of ['49,000','1,000','1,150','48,850'])assert.ok(html.includes(value),value);
  assert.doesNotMatch(html,/50,000/);
  assert.match(p.el('balanceFoundOrder').innerHTML,/50,000/);
});

test('shortfall form has only amount, reason and confirmation while full refunds keep their reference',()=>{
  assert.doesNotMatch(adminHtml,/balanceShortfallReference|ژمارە یان بەڵگەی پشتڕاستکردنەوە/);
  assert.match(adminHtml,/id="balanceShortfallAmount"/);
  assert.match(adminHtml,/id="balanceShortfallReason"/);
  assert.match(adminHtml,/id="balanceShortfallConfirmed"/);
  assert.match(adminHtml,/id="balanceBankReference"/);
  assert.match(adminHtml,/exchange-balance-admin\.js\?v=8/);
});

test('150 IQD credits use their own action and preserve approved status and full-refund marker',async()=>{
  const p=panel();await p.select();p.fill();
  await p.context.creditOrderShortfall();
  const payload=p.credits()[0].payload;
  assert.equal(payload.amount_iqd,150);assert.equal(payload.expected_refunded_iqd,0);
  assert.equal(payload.order_id,orderId);assert.equal(payload.confirmed_shortfall,true);
  assert.match(payload.request_key,/^00000000-/);
  for(const forbidden of ['verification_reference','status','admin_id','user_id','balance_after_iqd','reward_id'])assert.equal(Object.hasOwn(payload,forbidden),false);
  assert.equal(p.lookup.order.status,'پەسەندکرا');assert.equal(p.lookup.order.balance_refunded_at,null);
  assert.equal(p.lookup.balance.available_iqd,1150);assert.equal(p.lookup.order.shortfall_refunded_iqd,150);
  assert.equal(p.el('balanceShortfallAmount').value,'');assert.equal(p.el('balanceShortfallConfirmed').checked,false);
  assert.match(p.el('balanceShortfallSuccess').innerHTML,/1,150/);
  const history=p.el('balanceShortfallList').innerHTML;
  for(const value of ['P123456789AB','Customer One','Auditor One','1,000','1,150','55555555'])assert.ok(history.includes(value),value);
  assert.doesNotMatch(history,/shortfall:|بەڵگەی پێشوو/);
  assert.doesNotMatch(p.el('balanceRefundList').innerHTML,/BANK-FIXTURE/);
  assert.equal(p.storage.size,0);
  p.fill('50');await p.context.creditOrderShortfall();
  assert.notEqual(p.credits()[1].payload.request_key,payload.request_key);
  assert.equal(p.lookup.balance.available_iqd,1200);
});

test('shortfall history keeps escaped legacy references without labelling generated identifiers as proof',async()=>{
  const p=panel();await p.select();p.fill();await p.context.creditOrderShortfall();
  const row=copy(p.lookup.shortfalls[0]);
  const generated=p.context.balanceShortfallTable([row]);
  assert.doesNotMatch(generated,/shortfall:|بەڵگەی پێشوو/);
  row.verification_reference='BANK-LEGACY-<script>bad</script>';
  const legacy=p.context.balanceShortfallTable([row]);
  assert.match(legacy,/بەڵگەی پێشوو: BANK-LEGACY-&lt;script&gt;bad&lt;\/script&gt;/);
  assert.doesNotMatch(legacy,/<script>/);
});

test('invalid fractional, exponential, negative and excessive amounts never reach the API',async()=>{
  const p=panel();await p.select();
  for(const amount of ['', '0','-150','150.5','1e3','1,50','Infinity','49001','1000000001']){
    p.fill(amount);await p.context.creditOrderShortfall();assert.equal(p.credits().length,0,amount);
    assert.notEqual(p.el('balanceShortfallError').textContent,'');
  }
  assert.equal(p.context.balanceWholeIqd('١٬٢٥٠'),1250);
  assert.equal(p.context.balanceWholeIqd('150'),150);
});

test('a reason and explicit undelivered confirmation are required without a manual reference',async()=>{
  const p=panel();await p.select();
  for(const [id,value] of [['balanceShortfallReason','short'],['balanceShortfallConfirmed',false]]){
    p.fill();if(typeof value==='boolean')p.el(id).checked=value;else p.el(id).value=value;
    await p.context.creditOrderShortfall();assert.equal(p.credits().length,0,id);
  }
});

test('double clicks cannot create concurrent credits or change the selected order in flight',async()=>{
  const p=panel();await p.select();p.fill();let complete;
  p.setCredit(payload=>new Promise(resolve=>{complete=()=>resolve(p.postCredit(payload));}));
  const first=p.context.creditOrderShortfall();
  assert.equal(p.el('balanceShortfallFields').disabled,true);
  assert.equal(p.el('balanceOrderSearch').disabled,true);
  await p.context.creditOrderShortfall();await p.context.openOrderShortfall('different-order');
  assert.equal(p.credits().length,1);
  complete();await first;assert.equal(p.lookup.balance.available_iqd,1150);
});

test('network retry keeps request UUID and frozen cumulative baseline after lookup refresh',async()=>{
  const p=panel();await p.select();p.fill();let attempt=0;
  p.setCredit(payload=>{if(++attempt===1)throw Error('Network connection was interrupted');return p.postCredit(payload);});
  await p.context.creditOrderShortfall();const first=p.credits()[0].payload;
  p.lookup.balance.available_iqd=2000;
  await p.select();await p.context.creditOrderShortfall();
  const retry=p.credits()[1].payload;
  assert.equal(retry.request_key,first.request_key);assert.equal(retry.expected_refunded_iqd,0);
  assert.match(p.el('balanceShortfallSuccess').innerHTML,/2,000[\s\S]*2,150/);
});

test('pending payload is saved before POST and recovered exactly after a page reload',async()=>{
  const p=panel();await p.select();p.fill('١٥٠');
  p.setCredit(payload=>{
    const [[key,raw]]=p.storage;
    assert.equal(key,'proxo:shortfall:pending:v1:'+adminId+':'+orderId);
    assert.deepEqual(JSON.parse(raw),{version:1,admin_id:adminId,payload:copy(payload)});
    throw Error('Connection interrupted before a response');
  });
  await p.context.creditOrderShortfall();const original=p.credits()[0].payload;
  const reloaded=panel({storage:p.storage,uuidStart:100});
  reloaded.setLookup(copy(p.lookup));reloaded.lookup.balance.available_iqd=2000;
  await reloaded.select();
  assert.equal(reloaded.el('balanceShortfallAmount').value,'150');
  assert.equal(reloaded.el('balanceShortfallReason').value,original.reason);
  assert.equal(reloaded.el('balanceShortfallAmount').readOnly,true);
  assert.equal(reloaded.el('balanceShortfallReason').readOnly,true);
  assert.equal(reloaded.el('balanceShortfallConfirmed').checked,false);
  await reloaded.context.creditOrderShortfall();assert.equal(reloaded.credits().length,0);
  reloaded.el('balanceShortfallConfirmed').checked=true;await reloaded.context.creditOrderShortfall();
  assert.deepEqual(reloaded.credits()[0].payload,original);
  assert.equal(reloaded.lookup.balance.available_iqd,2150);
  assert.equal(reloaded.storage.size,0);
});

test('returning to an order restores its unresolved request while another administrator sees no draft',async()=>{
  const p=panel();await p.select();p.fill();
  p.setCredit(()=>{throw Error('No response');});await p.context.creditOrderShortfall();
  const firstOrder=copy(p.lookup),original=p.credits()[0].payload;
  const otherOrder=copy(firstOrder);otherOrder.order.id='66666666-6666-4666-8666-666666666666';
  otherOrder.order.order_code='OTHER';
  p.el('balanceOrderSearch').handlers.input();p.setLookup(otherOrder);await p.select('OTHER');
  assert.equal(p.el('balanceShortfallAmount').value,'');
  assert.equal(p.el('balanceShortfallAmount').readOnly,false);assert.equal(p.storage.size,1);
  const otherAdmin=panel({storage:p.storage,owner:'77777777-7777-4777-8777-777777777777'});
  otherAdmin.setLookup(copy(firstOrder));await otherAdmin.select();
  assert.equal(otherAdmin.el('balanceShortfallReason').value,'');
  assert.equal(otherAdmin.el('balanceShortfallAmount').readOnly,false);assert.equal(otherAdmin.storage.size,1);
  p.el('balanceOrderSearch').handlers.input();p.setLookup(firstOrder);await p.select();
  assert.equal(p.el('balanceShortfallAmount').value,'150');
  assert.equal(p.el('balanceShortfallConfirmed').checked,false);
  p.el('balanceShortfallConfirmed').checked=true;await p.context.creditOrderShortfall();
  assert.deepEqual(p.credits()[1].payload,original);assert.equal(p.storage.size,1);
});

test('ambiguous errors including stale text and edited pending values never create a fresh request',async()=>{
  for(const error of [
    Error('A stale network connection lost the response'),
    Object.assign(Error('Upstream stale response'),{status:500,code:'shortfall_failed'}),
    Object.assign(Error('No credit result was returned'),{status:500,code:'shortfall_result_missing'}),
    Object.assign(Error('SHORTFALL_REQUEST_KEY_CONFLICT'),{status:400,code:'22023'})
  ]){
    const p=panel();await p.select();p.fill();p.setCredit(()=>{throw error;});
    await p.context.creditOrderShortfall();const original=p.credits()[0].payload;
    assert.equal(p.storage.size,1,error.message);
    assert.equal(p.el('balanceShortfallAmount').readOnly,true,error.message);
    p.fill('200');p.el('balanceShortfallReason').value='Changed reason must not silently create a new request';
    p.el('balanceShortfallForm').handlers.input();
    assert.equal(p.el('balanceShortfallBtn').disabled,true,error.message);
    await p.context.creditOrderShortfall();assert.equal(p.credits().length,1,error.message);
    await p.select();assert.equal(p.el('balanceShortfallAmount').value,'150');
    assert.equal(p.el('balanceShortfallReason').value,original.reason);
    await p.context.creditOrderShortfall();assert.deepEqual(p.credits()[1].payload,original,error.message);
    assert.equal(p.storage.size,1,error.message);
  }
});

test('unavailable or unreadable session storage blocks sending and preserves any pending record',async()=>{
  const blocked=panel();await blocked.select();blocked.fill();
  const originalSet=blocked.context.sessionStorage.setItem;
  blocked.context.sessionStorage.setItem=()=>{throw Error('Storage is blocked');};
  await blocked.context.creditOrderShortfall();assert.equal(blocked.credits().length,0);
  assert.equal(blocked.storage.size,0);assert.equal(blocked.el('balanceShortfallBtn').disabled,true);
  blocked.context.sessionStorage.setItem=originalSet;await blocked.select();
  assert.equal(blocked.el('balanceShortfallAmount').readOnly,false);
  await blocked.context.creditOrderShortfall();assert.equal(blocked.credits().length,1);
  const unreadable=panel();
  const key='proxo:shortfall:pending:v1:'+adminId+':'+orderId;
  unreadable.storage.set(key,'{invalid json');await unreadable.select();unreadable.fill();
  assert.equal(unreadable.el('balanceShortfallBtn').disabled,true);
  await unreadable.context.creditOrderShortfall();assert.equal(unreadable.credits().length,0);
  assert.equal(unreadable.storage.get(key),'{invalid json');
  const inaccessible=panel();
  inaccessible.context.sessionStorage.getItem=()=>{throw Error('Storage is blocked');};
  await inaccessible.select();inaccessible.fill();await inaccessible.context.creditOrderShortfall();
  assert.equal(inaccessible.credits().length,0);
});

test('a definite pre-RPC validation rejection permits correction with new confirmation',async()=>{
  const p=panel();await p.select();p.fill();let attempt=0;
  p.setCredit(payload=>{
    if(++attempt===1)throw Object.assign(Error('Explain the shortfall'),{status:400,code:'invalid_reason'});
    return p.postCredit(payload);
  });
  await p.context.creditOrderShortfall();const original=p.credits()[0].payload;
  assert.equal(p.storage.size,0);assert.equal(p.el('balanceShortfallReason').readOnly,false);
  assert.equal(p.el('balanceShortfallConfirmed').checked,false);
  p.fill();p.el('balanceShortfallReason').value='Corrected description of the actual undelivered shortfall';
  await p.context.creditOrderShortfall();assert.notEqual(p.credits()[1].payload.request_key,original.request_key);
  assert.equal(p.lookup.balance.available_iqd,1150);
});

test('a validation rejection on retry cannot discard an earlier ambiguous attempt',async()=>{
  const p=panel();await p.select();p.fill();let attempt=0;
  p.setCredit(()=>{
    if(++attempt===1)throw Error('The server response was lost');
    throw Object.assign(Error('A different deployment requires evidence'),{status:400,code:'invalid_evidence'});
  });
  await p.context.creditOrderShortfall();const original=p.credits()[0].payload;
  await p.context.creditOrderShortfall();
  assert.deepEqual(p.credits()[1].payload,original);assert.equal(p.storage.size,1);
  assert.equal(p.el('balanceShortfallAmount').readOnly,true);
  p.fill('200');await p.context.creditOrderShortfall();assert.equal(p.credits().length,2);
});

test('retry retains its original baseline when another credit has changed the order',async()=>{
  const p=panel();await p.select();p.fill();let attempt=0;
  p.setCredit(()=>{
    if(++attempt===1)throw Error('Response unavailable');
    throw Object.assign(Error('SHORTFALL_STATE_CHANGED'),{status:409,code:'shortfall_stale'});
  });
  await p.context.creditOrderShortfall();const first=p.credits()[0].payload;
  p.lookup.shortfall_summary.refunded_iqd=100;p.lookup.shortfall_summary.remaining_iqd=48900;
  await p.select();await p.context.creditOrderShortfall();
  assert.equal(p.credits()[1].payload.request_key,first.request_key);
  assert.equal(p.credits()[1].payload.expected_refunded_iqd,0);
  assert.equal(p.el('balanceShortfallBtn').disabled,true);
  assert.equal(p.lookup.balance.available_iqd,1000);
});

test('lookup recognizes a committed timed-out request without sending another credit',async()=>{
  const p=panel();await p.select();p.fill();
  p.setCredit(payload=>{p.postCredit(payload);throw Error('Response lost after commit');});
  await p.context.creditOrderShortfall();assert.equal(p.credits().length,1);
  await p.select();assert.equal(p.credits().length,1);
  assert.match(p.el('balanceShortfallSuccess').innerHTML,/150[\s\S]*1,150/);
  assert.equal(p.el('balanceShortfallAmount').value,'');
  assert.equal(p.el('balanceShortfallConfirmed').checked,false);
});

test('reload recognizes a committed lost-response request in history without another POST',async()=>{
  const p=panel();await p.select();p.fill();
  p.setCredit(payload=>{p.postCredit(payload);throw Error('Response lost after commit');});
  await p.context.creditOrderShortfall();assert.equal(p.storage.size,1);
  const reloaded=panel({storage:p.storage,uuidStart:100});reloaded.setLookup(copy(p.lookup));
  await reloaded.select();assert.equal(reloaded.credits().length,0);assert.equal(reloaded.storage.size,0);
  assert.equal(reloaded.lookup.balance.available_iqd,1150);
  assert.match(reloaded.el('balanceShortfallSuccess').innerHTML,/150[\s\S]*1,150/);
  assert.equal(reloaded.el('balanceShortfallAmount').value,'');
  assert.equal(reloaded.el('balanceShortfallConfirmed').checked,false);
});

test('stale state requires a fresh lookup and new explicit confirmation before another request',async()=>{
  const p=panel();await p.select();p.fill();let attempt=0;
  p.setCredit(payload=>{
    if(++attempt===1)throw Object.assign(Error('SHORTFALL_STATE_CHANGED'),{status:409,code:'shortfall_stale'});
    return p.postCredit(payload);
  });
  await p.context.creditOrderShortfall();const first=p.credits()[0].payload;
  assert.equal(p.storage.size,0);
  assert.equal(p.el('balanceShortfallBtn').disabled,true);assert.equal(p.el('balanceShortfallConfirmed').checked,false);
  await p.context.creditOrderShortfall();assert.equal(p.credits().length,1);
  p.lookup.shortfall_summary.refunded_iqd=150;p.lookup.shortfall_summary.remaining_iqd=48850;
  await p.select();await p.context.creditOrderShortfall();assert.equal(p.credits().length,1);
  p.el('balanceShortfallConfirmed').checked=true;await p.context.creditOrderShortfall();
  assert.equal(p.credits()[1].payload.expected_refunded_iqd,150);
  assert.notEqual(p.credits()[1].payload.request_key,first.request_key);
});

test('late lookup for an old search cannot overwrite the selected customer or enable a stale credit',async()=>{
  const p=panel(),pending=new Map();
  p.setLookupImpl(payload=>new Promise(resolve=>pending.set(payload.search,resolve)));
  const first=p.select('FIRST');
  p.el('balanceOrderSearch').handlers.input();
  const second=p.select('SECOND');
  const newOrder=copy(p.lookup);newOrder.order.id='66666666-6666-4666-8666-666666666666';
  newOrder.order.order_code='SECOND';newOrder.profile.full_name='Second Customer';
  pending.get('SECOND')(newOrder);await second;
  pending.get('FIRST')(copy(p.lookup));await first;
  assert.match(p.el('balanceFoundOrder').innerHTML,/Second Customer/);
  assert.doesNotMatch(p.el('balanceFoundOrder').innerHTML,/Customer One/);
});

test('lookup failures and staff without refund permission leave credit controls disabled',async()=>{
  const failed=panel();failed.setLookupImpl(()=>{throw Error('Database unavailable');});await failed.select();
  assert.equal(failed.el('balanceShortfallBtn').disabled,true);
  assert.equal(failed.el('balanceShortfallPreview').innerHTML,'');
  const denied=panel();denied.deny();await denied.select();denied.fill();
  assert.equal(denied.el('balanceShortfallBtn').disabled,true);await denied.context.creditOrderShortfall();
  assert.equal(denied.credits().length,0);
});

test('pending orders retain the existing full rejection/refund action',async()=>{
  const p=panel();p.lookup.order.status='چاوەڕوانە';p.lookup.order.payout_receipt_url=null;
  p.lookup.shortfall_summary.eligible=false;await p.select();
  assert.equal(p.el('balanceShortfallBtn').disabled,true);assert.equal(p.el('balanceCreditBtn').disabled,false);
  p.el('balanceBankReference').value='BANK-PROOF-01';p.el('balanceRefundReason').value='Manual full rejection of this pending order';
  p.el('balanceFundsVerified').checked=true;await p.context.creditVerifiedRefund();
  assert.equal(p.calls.filter(c=>c.action==='balance_credit_refund').length,1);assert.equal(p.credits().length,0);
  assert.equal(p.lookup.order.status,'ڕەتکرا');
});

test('a settlement mismatch prevents the dashboard from claiming that accounting reconciles',async()=>{
  const p=panel(),request=p.context.adminApiRequest;
  p.context.adminApiRequest=async(action,payload)=>{
    const data=await request(action,payload);
    if(action==='balance_dashboard')data.reconciliation={rounding_settlement_mismatches:1};
    return data;
  };
  await p.context.loadBalanceAdmin();
  assert.match(p.el('balanceAdminStats').innerHTML,/ئاگاداری: 1 نایەکسانی/);
  assert.doesNotMatch(p.el('balanceAdminStats').innerHTML,/حسابداری و تۆماری جوڵەکان یەکدەگرنەوە/);
});

test('customer history joins repeated shortfalls by journal ID and escapes audit text',()=>{
  const out=element();
  const start=customerSource.indexOf('function renderBalanceHistory(){');
  const end=customerSource.indexOf("document.getElementById('balancePayoutForm')",start);
  assert.ok(start>=0&&end>start);
  const context=vm.createContext({document:{getElementById:()=>out},escHtml:escapeHtml,
    balanceTime:value=>value,balanceIqd:value=>Number(value).toLocaleString('en-US')+' د.ع',
    _myBalanceData:{journal:[
      {id:'journal-second',kind:'shortfall_refund',order_id:orderId,created_at:'2026-10-17T12:00:00Z',
        ex_balance_entries:[{account:'customer_available',delta_iqd:150,balance_after_iqd:1300}]},
      {id:'journal-first',kind:'shortfall_refund',order_id:orderId,created_at:'2026-10-17T11:00:00Z',
        ex_balance_entries:[{account:'customer_available',delta_iqd:150,balance_after_iqd:1150}]}],
      shortfalls:[{journal_id:'journal-first',order_code:'P123',reason:'First refund'},
        {journal_id:'journal-second',order_code:'P123',reason:'Second <script>unsafe</script> refund'}],payouts:[]}
  });
  vm.runInContext(customerSource.slice(start,end),context);context.renderBalanceHistory();
  assert.match(out.innerHTML,/گەڕاندنەوەی بڕی کەم نێردراو/);
  assert.match(out.innerHTML,/Second &lt;script&gt;unsafe&lt;\/script&gt; refund[\s\S]*1,150[\s\S]*1,300[\s\S]*First refund[\s\S]*1,000/);
  assert.doesNotMatch(out.innerHTML,/<script>/);
});

test('customer balance history distinguishes automatic rounding credits from manual shortfalls',()=>{
  const out=element();
  const start=customerSource.indexOf('function renderBalanceHistory(){');
  const end=customerSource.indexOf("document.getElementById('balancePayoutForm')",start);
  const context=vm.createContext({document:{getElementById:()=>out},escHtml:escapeHtml,
    balanceTime:value=>value,balanceIqd:value=>Number(value).toLocaleString('en-US')+' د.ع',
    _myBalanceData:{journal:[{id:'automatic-journal',kind:'shortfall_refund',order_id:orderId,
      created_at:'2026-10-17T12:00:00Z',ex_balance_entries:[
        {account:'customer_available',delta_iqd:500,balance_after_iqd:1500}]}],
      shortfalls:[{journal_id:'automatic-journal',order_code:'P123',refund_source:'payout_rounding',
        reason:'پاشماوەی ناردن بۆ باڵانس گەڕێندرایەوە.'}],payouts:[]}
  });
  vm.runInContext(customerSource.slice(start,end),context);context.renderBalanceHistory();
  assert.match(out.innerHTML,/گەڕاندنەوەی ئۆتۆماتیکی/);
  assert.match(out.innerHTML,/500/);assert.match(out.innerHTML,/1,500/);
  assert.doesNotMatch(out.innerHTML,/گەڕاندنەوەی بڕی کەم نێردراو/);
});
