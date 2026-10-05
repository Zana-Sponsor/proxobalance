import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const adminId='11111111-1111-4111-8111-111111111111';
const userId='22222222-2222-4222-8222-222222222222';
function application(isAdmin=true,options={}){
  const calls=[];
  const db={
    auth:{getUser:async()=>({data:{user:{id:adminId}},error:null})},
    rpc:async(name,args)=>{calls.push({rpc:name,args});return {data:{id:'refund',refund_kind:'admin_rejection'},error:null};},
    from(table){
      let inserted=null;
      const q={select(){return q;},eq(){return q;},
        in(column,ids){calls.push({table,column,ids});return q;},
        insert(row){inserted=row;calls.push({table,row});return q;},
        async single(){return {data:table==='ex_profiles'?{id:adminId,is_admin:isAdmin,is_banned:false}:{id:'reward',...inserted},error:null};},
        async maybeSingle(){return {data:{id:userId,is_banned:false},error:null};},
        then(resolve,reject){return Promise.resolve(table==='ex_customer_balances'
          ? {data:options.balances||[],error:options.balanceError||null}
          : {data:inserted,error:null}).then(resolve,reject);}
      };return q;
    }
  };
  const source=readFileSync(new URL('../api/admin.js',import.meta.url),'utf8')
    .replace("import { createClient } from '@supabase/supabase-js';",'const createClient=globalThis.createClient;')
    .replace('export default async function handler','async function handler');
  const c=vm.createContext({createClient:()=>db,process:{env:{SUPABASE_SERVICE_ROLE_KEY:'test-only-placeholder'}},console,URL,Date});
  vm.runInContext(source+'\nglobalThis.handler=handler;',c);
  return {calls,async request(action,payload,authorized=true){
    let data,status;
    const res={status(s){status=s;return res;},setHeader(){return res;},send(s){data=JSON.parse(s);return res;}};
    await c.handler({method:'POST',headers:authorized?{authorization:'Bearer test-only-token'}:{},body:{action,payload}},res);
    return {status,data};
  }};
}

test('admin refund is explicit and does not need a failed-payout assertion',async()=>{
  const app=application();
  const result=await app.request('balance_credit_refund',{order_id:userId,
    verification_reference:'receipt-proof',reason:'Admin cancelled this order',confirmed_received:true,
    confirmed_failed:false,p_admin_id:userId,amount_iqd:99999999});
  assert.equal(result.status,200);
  const call=app.calls.find(c=>c.rpc);
  assert.equal(call.rpc,'ex_admin_reject_and_refund');
  assert.equal(call.args.p_admin_id,adminId);
  assert.equal(call.args.p_confirmed_received,true);
  assert.equal(Object.hasOwn(call.args,'p_confirmed_failed'),false);
  assert.equal(Object.hasOwn(call.args,'amount_iqd'),false);
});
test('ordinary customers cannot issue refunds or grant rewards',async()=>{
  const app=application(false);
  for(const action of ['balance_credit_refund','grant_reward','account_balances']){
    assert.equal((await app.request(action,{})).status,403);
  }
  assert.equal(app.calls.length,0);
});
test('per-user balances include actual available/held amounts and zero for an uninitialized account',async()=>{
  const app=application(true,{balances:[{user_id:userId,available_iqd:40000,held_iqd:10000,updated_at:'2026-10-05T00:00:00Z'}]});
  const result=await app.request('account_balances',{user_ids:[userId.toUpperCase(),adminId,userId]});
  assert.equal(result.status,200);
  assert.deepEqual(result.data.data,[
    {user_id:userId,available_iqd:40000,held_iqd:10000,updated_at:'2026-10-05T00:00:00Z'},
    {user_id:adminId,available_iqd:0,held_iqd:0,updated_at:null}
  ]);
  assert.deepEqual(Array.from(app.calls[0].ids),[userId,adminId]);
  assert.equal(app.calls[0].column,'user_id');
});
test('balance lookup requires authentication and rejects invalid or oversized ID lists',async()=>{
  const app=application();
  assert.equal((await app.request('account_balances',{user_ids:[userId]},false)).status,401);
  for(const ids of [undefined,'all',['invalid'],Array(201).fill(userId)]){
    assert.equal((await app.request('account_balances',{user_ids:ids})).status,400);
  }
  assert.equal(app.calls.length,0);
});
test('a balance read error is reported instead of returning a false zero balance',async()=>{
  const app=application(true,{balanceError:{message:'fixture read failure'}});
  const result=await app.request('account_balances',{user_ids:[userId]});
  assert.equal(result.status,500);
  assert.equal(result.data.code,'db_error');
  assert.equal(Object.hasOwn(result.data,'data'),false);
});
test('anonymous clients cannot issue refunds',async()=>{
  const app=application();
  assert.equal((await app.request('balance_credit_refund',{},false)).status,401);
  assert.equal(app.calls.length,0);
});
test('admin grants a 50k principal cap and the customer notification includes it',async()=>{
  const app=application();
  const result=await app.request('grant_reward',{user_id:userId,kind:'free_transactions',max_uses:2,max_amount_iqd:50000});
  assert.equal(result.status,200);
  const grant=app.calls.find(c=>c.table==='ex_user_rewards');
  assert.equal(grant.row.max_amount_iqd,50000);
  assert.equal(grant.row.discount_percent,100);
  assert.equal(grant.row.created_by,adminId);
  assert.match(app.calls.find(c=>c.table==='ex_notifications').row.message,/50,000/);
});
for(const cap of [0,-1,50000.5,1000000001,'bad']){
  test('rejects invalid reward amount cap '+cap,async()=>{
    const app=application();
    const result=await app.request('grant_reward',{user_id:userId,kind:'free_transactions',max_uses:2,max_amount_iqd:cap});
    assert.equal(result.status,400);
    assert.equal(result.data.code,'bad_amount_cap');
    assert.equal(app.calls.length,0);
  });
}
