import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { Buffer } from 'node:buffer';
import vm from 'node:vm';
import { payoutPlan } from '../api/_lib/payout-rounding.js';

const adminId = '11111111-1111-4111-8111-111111111111';
const userId = '22222222-2222-4222-8222-222222222222';
const orderId = '33333333-3333-4333-8333-333333333333';
const requestKey = 'abcdabcd-abcd-4bcd-8bcd-abcdabcdabcd';
const settlementId = '55555555-5555-4555-8555-555555555555';
const refundId = '66666666-6666-4666-8666-666666666666';
const receiptId = '77777777-7777-4777-8777-777777777777';
const updatedAt = '2026-10-17T12:34:56.123456+00:00';
const receiptUrl = 'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/' + userId + '/payout.jpg';
const baseOrder = {
  id:orderId,user_id:userId,order_code:'P123456789AB',from_method:'FastPay',to_method:'FIB',
  amount:11000,total:10500,fee:500,status:'چاوەڕوانە',updated_at:updatedAt,
  receipt_url:'https://example.invalid/funding-receipt.jpg',balance_refunded_at:null,
  shortfall_refunded_iqd:0,payout_settlement_id:null
};
const approvalPayload = {
  order_id:orderId,request_key:requestKey,expected_updated_at:updatedAt,expected_total:10500,
  confirmed_payout_iqd:10000,confirmed_received:true,confirmed_paid:true
};

function savedSettlement(total = 10500, payout = 10000, remainder = 500, patch = {}) {
  return {
    order:{...baseOrder,total,status:'پەسەندکرا',payout_iqd:payout,payout_rounding_iqd:remainder,
      payout_settlement_id:settlementId,shortfall_refunded_iqd:remainder,...patch},
    settlement:{id:settlementId,order_id:orderId,user_id:userId,admin_id:adminId,
      request_key:requestKey,expected_iqd:total,payout_iqd:payout,rounding_iqd:remainder},
    refund:remainder === 0 ? null : {id:refundId,order_id:orderId,user_id:userId,
      amount_iqd:remainder,refund_source:'payout_rounding',payout_settlement_id:settlementId}
  };
}

function application(options = {}) {
  const calls = [];
  const profile = {id:adminId,is_admin:true,is_banned:false,role:'admin',staff_permissions:['approve_orders'],...options.profile};
  const order = {...baseOrder,...options.order};
  const db = {
    auth:{getUser:async token => {
      calls.push({auth:token});
      return options.authError ? {error:{message:'Expired'},data:null}
        : {error:null,data:{user:{id:adminId,user_metadata:{role:'super_admin'}}}};
    }},
    async rpc(name, args) {
      calls.push({rpc:name,args:JSON.parse(JSON.stringify(args))});
      if (options.rpc) return options.rpc(name, args, order);
      if (options.rpcError) return {data:null,error:options.rpcError};
      return {data:Object.hasOwn(options,'rpcData') ? options.rpcData : savedSettlement(),error:null};
    },
    from(table) {
      const query = {table,filters:[]};
      let patch;
      const q = {
        select(fields) {query.fields = fields; return q;},
        eq(field,value) {query.filters.push(['eq',field,value]); return q;},
        in(field,value) {query.filters.push(['in',field,Array.from(value)]); return q;},
        is(field,value) {query.filters.push(['is',field,value]); return q;},
        update(value) {patch = value; calls.push({write:table,patch:JSON.parse(JSON.stringify(value))}); return q;},
        insert(value) {calls.push({write:table,value:JSON.parse(JSON.stringify(value))}); return q;},
        async single() {
          calls.push({read:query});
          if (table === 'ex_profiles') return {data:profile,error:null};
          if (options.orderReadError) return {data:null,error:{message:'Read unavailable'}};
          return {data:options.orderMissing ? null : {...order,...patch},error:null};
        },
        then(yes,no) {return Promise.resolve({data:null,error:null}).then(yes,no);}
      };
      return q;
    }
  };
  const source = readFileSync(new URL('../api/admin.js',import.meta.url),'utf8')
    .replace("import { createClient } from '@supabase/supabase-js';",'const createClient=globalThis.createClient;')
    .replace("import { payoutPlan } from './_lib/payout-rounding.js';",'const payoutPlan=globalThis.payoutPlan;')
    .replace('export function assertStaffAction','function assertStaffAction')
    .replace('export default async function handler','async function handler');
  const context = vm.createContext({createClient:()=>db,payoutPlan,URL,Date,Buffer,
    console:{error(){}},process:{env:{SUPABASE_SERVICE_ROLE_KEY:'fixture-only-service-key'}}});
  vm.runInContext(source + '\nglobalThis.handler=handler;',context);
  return {calls,profile,order,async request(payload = approvalPayload, action = 'approve_order', authorized = true) {
    let status,body;
    const headers = {};
    const res = {
      status(value) {status = value; return res;},
      setHeader(name,value) {headers[name] = value; return res;},
      send(value) {body = JSON.parse(value); return res;}
    };
    await context.handler({method:'POST',headers:authorized ? {authorization:'Bearer fixture-token'} : {},
      body:{action,payload}},res);
    return {status,body,headers};
  }};
}

test('IQD approvals pass only verified actor and the frozen confirmation into one atomic RPC',async()=>{
  const app = application();
  const result = await app.request({...approvalPayload,request_key:requestKey.toUpperCase(),
    admin_id:userId,p_admin_id:userId,user_id:adminId,amount_iqd:999999,refund_iqd:999999,
    payout_iqd:999999,available_iqd:999999,admin_note:'  Paid the displayed amount  ',payout_receipt_url:receiptUrl});
  assert.equal(result.status,200);
  assert.equal(result.headers['Cache-Control'],'no-store');
  assert.deepEqual(app.calls.find(c=>c.rpc),{
    rpc:'ex_admin_approve_order_settlement',args:{p_order_id:orderId,p_admin_id:adminId,
      p_request_key:requestKey,p_expected_updated_at:updatedAt,p_expected_total:10500,
      p_confirmed_payout_iqd:10000,p_confirmed_received:true,p_confirmed_paid:true,
      p_payout_receipt_url:receiptUrl,p_admin_note:'Paid the displayed amount'}
  });
  assert.equal(result.body.data.total,10500);
  assert.equal(result.body.data.payout_iqd,10000);
  assert.equal(result.body.data.payout_rounding_iqd,500);
  assert.equal(result.body.data.refund.amount_iqd,500);
  assert.equal(result.body.data.refund.refund_source,'payout_rounding');
  assert.equal(app.calls.filter(c=>c.write).length,0,'no status, ledger or optional audit write follows the atomic RPC');
});

for (const [total,payout,remainder] of [[10500,10000,500],[1600,1000,600],[1000,1000,0],[999,0,999],[1,0,1],[0,0,0],[1000000000,1000000000,0]]) {
  test(`settles displayed ${total} IQD as payout ${payout} and refund ${remainder}`,async()=>{
    const app = application({order:{total},rpcData:savedSettlement(total,payout,remainder)});
    const result = await app.request({...approvalPayload,expected_total:total,confirmed_payout_iqd:payout,confirmed_paid:payout>0});
    assert.equal(result.status,200);
    assert.equal(result.body.data.payout_iqd,payout);
    assert.equal(result.body.data.payout_rounding_iqd,remainder);
    assert.equal(app.calls.find(c=>c.rpc).args.p_confirmed_paid,payout>0);
    assert.equal(result.body.data.refund?.amount_iqd || 0,remainder);
    assert.equal(app.calls.filter(c=>c.write).length,0);
  });
}

test('zero outbound rejects a paid claim or payout proof and positive outbound requires paid confirmation',async()=>{
  for (const [total,payout,patch] of [[500,0,{confirmed_paid:true}],[0,0,{payout_receipt_url:receiptUrl}],
    [10500,10000,{confirmed_paid:false}],[10500,10000,{confirmed_received:false}],
    [10500,10000,{confirmed_received:'true'}],[10500,10000,{confirmed_paid:1}]]) {
    const app = application({order:{total}});
    const result = await app.request({...approvalPayload,expected_total:total,confirmed_payout_iqd:payout,
      confirmed_paid:payout>0,...patch});
    assert.equal(result.status,400);
    assert.equal(app.calls.filter(c=>c.rpc || c.write).length,0);
  }
});

test('old clients, invalid money and imprecise or malformed version inputs cannot approve IQD orders',async()=>{
  for (const patch of [{request_key:undefined},{request_key:'bad'},{expected_updated_at:undefined},
    {expected_updated_at:'2026-02-30T12:00:00Z'},{expected_updated_at:'2026-10-17T12:00:00'},
    {expected_updated_at:'2026-10-17T24:00:00Z'},{expected_total:undefined},{expected_total:null},
    {expected_total:10500.5},{expected_total:true},{expected_total:'1e4'},{expected_total:-1},
    {expected_total:1000000001},{confirmed_payout_iqd:undefined},{confirmed_payout_iqd:10500},
    {confirmed_payout_iqd:10000.5},{confirmed_payout_iqd:Infinity},{confirmed_payout_iqd:true}]) {
    const app = application();
    const result = await app.request({...approvalPayload,...patch});
    assert.equal(result.status,400,JSON.stringify(patch));
    assert.equal(app.calls.filter(c=>c.rpc || c.write).length,0);
  }
});

test('approval permissions are fresh and independent of manual refunds permission',async()=>{
  for (const profile of [{is_admin:false},{is_banned:true},{staff_permissions:['view']},{staff_permissions:['refunds']}]) {
    const app = application({profile});
    assert.equal((await app.request()).status,403);
    assert.equal(app.calls.filter(c=>c.rpc || c.write).length,0);
  }
  const app = application();
  assert.equal((await app.request()).status,200,'approve_orders alone can execute deterministic rounding');
  app.profile.staff_permissions = ['view'];
  assert.equal((await app.request()).status,403,'revoked permission applies to retries too');
  assert.equal(app.calls.filter(c=>c.rpc).length,1);
  assert.equal((await application().request(approvalPayload,'approve_order',false)).status,401);
  assert.equal((await application({authError:true}).request()).status,401);
});

test('an approved-order exact replay reaches the RPC with the identical request key and microsecond version',async()=>{
  const app = application({rpc:async (_name,_args,order)=>{
    Object.assign(order,savedSettlement().order);
    return {data:savedSettlement(),error:null};
  }});
  const first = await app.request();
  const second = await app.request({...approvalPayload,request_key:requestKey.toUpperCase()});
  assert.equal(first.status,200);
  assert.equal(second.status,200);
  const calls = app.calls.filter(c=>c.rpc);
  assert.deepEqual(calls[0].args,calls[1].args);
  assert.equal(calls[1].args.p_expected_updated_at,updatedAt);
  assert.equal(app.order.status,'پەسەندکرا');
  assert.equal(app.calls.filter(c=>c.write).length,0);
});

for (const [message,sqlCode,status,code] of [
  ['ORDER_SETTLEMENT_STALE','22023',409,'approval_stale'],
  ['ORDER_ALREADY_DECIDED','22023',409,'already_decided'],
  ['SETTLEMENT_REQUEST_KEY_CONFLICT','22023',409,'approval_request_conflict'],
  ['STAFF_PERMISSION_REQUIRED','42501',403,'staff_permission_required'],
  ['PAYOUT_AMOUNT_MISMATCH','22023',400,'payout_amount_mismatch'],
  ['RECEIVED_FUNDS_PROOF_REQUIRED','22023',400,'received_funds_proof_required'],
  ['BALANCE_DEBIT_PROOF_REQUIRED','22023',400,'balance_debit_proof_required'],
  ['ORDER_NOT_ELIGIBLE_FOR_SETTLEMENT','22023',400,'invalid_payout_amount'],
  ['RECEIPT_HAS_MULTIPLE_ORDERS','23505',409,'receipt_multiple_orders'],
  ['Function missing','PGRST202',503,'settlement_unavailable'],
  ['private diagnostic must not escape','XX000',500,'settlement_result_unknown']
]) {
  test('approval maps ' + message + ' without a fallback financial write',async()=>{
    const app = application({rpcError:{code:sqlCode,message}});
    const result = await app.request();
    assert.equal(result.status,status);
    assert.equal(result.body.code,code);
    assert.equal(app.calls.filter(c=>c.write).length,0);
    assert.equal(Object.hasOwn(result.body,'data'),false);
    assert.equal(result.body.error.includes('private diagnostic'),false);
  });
}

test('invalid RPC results stay uncertain while object and exactly one row encodings succeed',async()=>{
  for (const data of [savedSettlement(),[savedSettlement()]]) {
    assert.equal((await application({rpcData:data}).request()).status,200);
  }
  for (const data of [null,[],[savedSettlement(),savedSettlement()],[null],{},
    {order:savedSettlement().order,settlement:[]},
    {...savedSettlement(),order:{...savedSettlement().order,id:userId}}]) {
    const result = await application({rpcData:data}).request();
    assert.equal(result.status,500);
    assert.equal(result.body.code,'settlement_result_unknown');
  }
  const app = application({rpc:async()=>{throw Error('network unavailable');}});
  assert.equal((await app.request()).body.code,'settlement_result_unknown');
});

test('USDT-funded IQD payout settles, fractional IQD principal does not, and USDT destination remains legacy',async()=>{
  const incoming = application({order:{from_method:'USDT',amount:10.5}});
  assert.equal((await incoming.request()).status,200);
  assert.equal(incoming.calls.find(c=>c.rpc).rpc,'ex_admin_approve_order_settlement');
  for (const amount of [11000.5,0,-1]) {
    const app = application({order:{amount}});
    assert.equal((await app.request()).status,400);
    assert.equal(app.calls.filter(c=>c.rpc || c.write).length,0);
  }
  const outgoing = application({order:{to_method:'USDT',total:7.5}});
  const result = await outgoing.request({order_id:orderId});
  assert.equal(result.status,200);
  assert.equal(result.body.data.total,7.5);
  assert.equal(outgoing.calls.filter(c=>c.rpc).length,0);
  assert.equal(outgoing.calls.find(c=>c.write==='ex_orders').patch.status,'پەسەندکرا');
  for (const to_method of [null,'','AccountBalance']) {
    const invalid = application({order:{to_method}});
    assert.equal((await invalid.request()).status,400);
    assert.equal(invalid.calls.filter(c=>c.rpc || c.write).length,0);
  }
});

test('a frozen IQD approval cannot approve an order whose destination changed to USDT',async()=>{
  const app = application({order:{to_method:'USDT',total:7.5}});
  for (const payload of [approvalPayload,{order_id:orderId,request_key:requestKey},
    {order_id:orderId,expected_total:10500},{order_id:orderId,confirmed_payout_iqd:10000}]) {
    const result = await app.request(payload);
    assert.equal(result.status,409);
    assert.equal(result.body.code,'approval_stale');
  }
  assert.equal(app.calls.filter(c=>c.rpc || c.write).length,0);
});

test('first settled payout proof is an atomic replayable attachment without a second audit',async()=>{
  const saved = savedSettlement().order;
  const attached = {...saved,payout_receipt_url:receiptUrl};
  const app = application({order:attached,rpcData:{order:attached,
    receipt:{id:receiptId,order_id:orderId,admin_id:adminId,payout_receipt_url:receiptUrl}}});
  for (let attempt=0;attempt<2;attempt++) {
    const result = await app.request({order_id:orderId,payout_receipt_url:receiptUrl,admin_id:userId},'save_payout_receipt');
    assert.equal(result.status,200);
    assert.equal(result.body.data.payout_receipt_url,receiptUrl);
  }
  const calls = app.calls.filter(c=>c.rpc);
  assert.equal(calls.length,2);
  assert.deepEqual(calls[0],{rpc:'ex_admin_attach_settlement_receipt',args:{
    p_order_id:orderId,p_admin_id:adminId,p_payout_receipt_url:receiptUrl}});
  assert.deepEqual(calls[0].args,calls[1].args);
  assert.equal(app.calls.filter(c=>c.write).length,0);
});

test('settled proof replacement/manual-refund locks and invalid URLs cannot fall back to direct updates',async()=>{
  for (const message of ['SETTLEMENT_RECEIPT_LOCKED','SETTLEMENT_RECEIPT_CONFLICT']) {
    const app = application({order:savedSettlement().order,rpcError:{code:'22023',message}});
    assert.equal((await app.request({order_id:orderId,payout_receipt_url:receiptUrl},'save_payout_receipt')).status,409);
    assert.equal(app.calls.filter(c=>c.write).length,0);
  }
  for (const url of ['https://example.invalid/payout.jpg',receiptUrl.replace(userId,adminId),
    receiptUrl+'?token=bad',receiptUrl+'#bad',receiptUrl.replace('payout.jpg','../other.jpg'),
    receiptUrl.replace('payout.jpg','%2e%2e/other.jpg')]) {
    const app = application({order:savedSettlement().order});
    assert.equal((await app.request({order_id:orderId,payout_receipt_url:url},'save_payout_receipt')).status,400);
    assert.equal(app.calls.filter(c=>c.rpc || c.write).length,0);
  }
});

test('backend payout previews match the browser helper on boundaries and dynamic wallet names',()=>{
  const context = vm.createContext({});
  vm.runInContext(readFileSync(new URL('../assets/js/exchange-payout-rounding.js',import.meta.url),'utf8'),context);
  for (const to of ['FIB','NewConfiguredWallet','USDT','AccountBalance',null,'',' ',' FIB','FIB\n','FIB\u0000']) {
    for (const amount of [10500,1600,1000,999,0,-1,1000000000,1000000001,10500.5,
      null,undefined,true,NaN,'10500.000','10000','1e4',' 10000','']) {
      assert.deepEqual(payoutPlan(amount,to),JSON.parse(JSON.stringify(context.ProxoPayoutRounding.plan(amount,to))));
    }
  }
});

function notificationApplication(order) {
  const sent = [],reads = [];
  const source = readFileSync(new URL('../api/notify-order.js',import.meta.url),'utf8')
    .replace("import { json, readJson, serviceFetch, withSecurity } from './_lib/security.js';",
      'const {json,readJson,serviceFetch,withSecurity}=globalThis.security;')
    .replace("import { payoutPlan } from './_lib/payout-rounding.js';",'const payoutPlan=globalThis.payoutPlan;')
    .replace('export default withSecurity(','globalThis.handler=withSecurity(');
  const context = vm.createContext({payoutPlan,process:{env:{TELEGRAM_BOT_TOKEN:'fixture-token',TELEGRAM_CHAT_ID:'fixture-chat'}},
    security:{json:(res,status,body)=>Object.assign(res,{status,body}),readJson:async req=>req.body,
      withSecurity:handler=>(req,res)=>handler(req,res,{user:{id:userId}}),
      serviceFetch:async path=>{reads.push(path);return order ? [order] : [];}
    },
    fetch:async (url,options)=>{sent.push({url,body:JSON.parse(options.body)});return {ok:true,json:async()=>({ok:true})};}
  });
  vm.runInContext(source,context);
  return {sent,reads,async request(){const res={};await context.handler({body:{order_id:orderId}},res);return res;}};
}

test('operational notification clearly labels pending 1000-unit payout and future refund',async()=>{
  const app = notificationApplication({...baseOrder,receipt_url:null});
  assert.equal((await app.request()).status,200);
  assert.match(app.sent[0].body.text,/Net after fees \(before account refund\): 10,500 IQD/);
  assert.match(app.sent[0].body.text,/Planned recipient payout: 10,000 IQD/);
  assert.match(app.sent[0].body.text,/Planned account refund on approval: 500 IQD/);
  assert.match(app.reads[0],new RegExp('user_id=eq.'+userId));
  assert.equal(app.sent[0].body.text.includes('Confirmed recipient payout'),false);
});

test('notifications respect USDT destination, incoming USDT, historical approvals, and ownership failure',async()=>{
  const cases = [
    [{...baseOrder,to_method:'USDT',total:7.5},/Net after fees \(before account refund\): 7.5 USDT/,false],
    [{...baseOrder,from_method:'USDT',amount:10.5},/Amount: 10.5 USDT/,true],
    [{...baseOrder,status:'پەسەندکرا'},/Net after fees \(before account refund\): 10,500 IQD/,false],
    [{...baseOrder,total:500},/Planned recipient payout: 0 IQD/,true]
  ];
  for (const [order,label,planned] of cases) {
    const app = notificationApplication({...order,receipt_url:null});
    await app.request();
    assert.match(app.sent[0].body.text,label);
    assert.equal(app.sent[0].body.text.includes('Planned account refund'),planned);
  }
  const missing = notificationApplication(null);
  assert.equal((await missing.request()).status,404);
  assert.equal(missing.sent.length,0);
});

test('null or inconsistent settled amounts never become a confirmed zero-payout notification',async()=>{
  for (const patch of [{payout_iqd:null,payout_rounding_iqd:500},{payout_iqd:0,payout_rounding_iqd:null},
    {payout_iqd:0,payout_rounding_iqd:500,payout_settlement_id:'invalid'}]) {
    const app = notificationApplication({...savedSettlement(500,0,500).order,...patch,receipt_url:null});
    await app.request();
    assert.equal(app.sent[0].body.text.includes('Confirmed recipient payout'),false);
    assert.equal(app.sent[0].body.text.includes('Automatic account refund'),false);
  }
});
