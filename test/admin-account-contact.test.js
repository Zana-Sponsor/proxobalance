import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import { payoutPlan } from '../api-handlers/_lib/payout-rounding.js';

// /api/admin: change a customer's e-mail / number, and set a password for either kind of account.
const adminId='11111111-1111-4111-8111-111111111111';
const numberUser='22222222-2222-4222-8222-222222222222';
const emailUser='33333333-3333-4333-8333-333333333333';
const authEmails={[numberUser]:'p9647501234567@phone.proxobalance.app',[emailUser]:'old@gmail.com'};

function application({role='super_admin',staff=null,check={ok:true,old_email:null,old_phone:'07501234567'},ownPassword=false}={}){
  const calls=[];
  const db={
    auth:{
      getUser:async()=>({data:{user:{id:adminId}},error:null}),
      admin:{
        getUserById:async(id)=>({data:{user:{id,email:authEmails[id]}},error:null}),
        updateUserById:async(id,attrs)=>{calls.push({auth:id,attrs});return {data:{user:{id}},error:null};}
      }
    },
    rpc:async(name,args)=>{
      calls.push({rpc:name,args});
      if(name==='ex_account_contact_check')return {data:check,error:null};
      if(name==='ex_account_contact_admin_set')return {data:{ok:true,email:args.p_email,phone:args.p_phone},error:null};
      return {data:null,error:null};
    },
    from(table){
      const q={select(){return q;},eq(){return q;},
        insert(row){calls.push({table,row});return q;},
        async single(){return {data:{id:adminId,is_admin:true,is_banned:false,role,staff_permissions:staff},error:null};},
        async maybeSingle(){return {data:table==='ex_auth_passwords'&&ownPassword?{user_id:numberUser}:null,error:null};},
        then(resolve,reject){return Promise.resolve({data:null,error:null}).then(resolve,reject);}
      };return q;
    }
  };
  const source=readFileSync(new URL('../api-handlers/admin.js',import.meta.url),'utf8')
    .replace("import { createClient } from '@supabase/supabase-js';",'const createClient=globalThis.createClient;')
    .replace("import { payoutPlan } from './_lib/payout-rounding.js';",'const payoutPlan=globalThis.payoutPlan;')
    .replace('export default async function handler','async function handler')
    .replace('export function assertStaffAction','function assertStaffAction');
  const c=vm.createContext({createClient:()=>db,payoutPlan,process:{env:{SUPABASE_SERVICE_ROLE_KEY:'test-only-placeholder'}},console,URL,Date,Buffer});
  vm.runInContext(source+'\nglobalThis.handler=handler;',c);
  return {calls,async request(action,payload){
    let data,status;
    const res={status(s){status=s;return res;},setHeader(){return res;},send(s){data=JSON.parse(s);return res;}};
    await c.handler({method:'POST',headers:{authorization:'Bearer test-only-token'},body:{action,payload}},res);
    return {status,data};
  }};
}

test('admin changes a number account: its sign-in follows the new number, the change is audited',async()=>{
  const app=application();
  const r=await app.request('account_contact_update',{user_id:numberUser,phone:'+964 770 111 2233',email:'New@Gmail.com'});
  assert.equal(r.status,200,JSON.stringify(r.data));
  const set=app.calls.find(c=>c.rpc==='ex_account_contact_admin_set');
  assert.deepEqual({...set.args},{p_user:numberUser,p_email:'new@gmail.com',p_phone:'07701112233'});
  const moved=app.calls.find(c=>c.auth);
  assert.equal(moved.attrs.email,'p9647701112233@phone.proxobalance.app'); assert.equal(moved.attrs.email_confirm,true);
  const audit=app.calls.find(c=>c.table==='ex_admin_audit_log');
  assert.equal(audit.row.action,'account_contact_update');
  assert.deepEqual(JSON.parse(audit.row.detail).phone,{from:'07501234567',to:'07701112233'});
});

test('admin changes an e-mail account: the address moves its sign-in; a number alone does not touch it',async()=>{
  const a=application({check:{ok:true,old_email:'old@gmail.com',old_phone:null}});
  assert.equal((await a.request('account_contact_update',{user_id:emailUser,email:'fresh@gmail.com'})).status,200);
  assert.equal(a.calls.find(c=>c.auth).attrs.email,'fresh@gmail.com');
  const b=application({check:{ok:true,old_email:'old@gmail.com',old_phone:null}});
  assert.equal((await b.request('account_contact_update',{user_id:emailUser,phone:'07801234567'})).status,200);
  assert.equal(b.calls.some(c=>c.auth),false);
});

test('a taken number or address is refused before anything changes',async()=>{
  const app=application({check:{ok:false,reason:'phone_taken'}});
  const r=await app.request('account_contact_update',{user_id:numberUser,phone:'07701112233'});
  assert.equal(r.status,409); assert.equal(r.data.code,'phone_taken');
  assert.equal(app.calls.some(c=>c.auth||c.rpc==='ex_account_contact_admin_set'),false);
});

test('only super admins change contacts and set passwords, for either kind of account',async()=>{
  assert.equal((await application({role:'admin',staff:['view','refunds']}).request('account_contact_update',{user_id:numberUser,phone:'07701112233'})).status,403);
  assert.equal((await application({role:'admin',staff:null}).request('account_contact_update',{user_id:numberUser,phone:'07701112233'})).status,403);
  assert.equal((await application({role:'admin',staff:null}).request('account_set_password',{user_id:numberUser,password:'newpassword1'})).status,403);
  const num=application({ownPassword:true});
  assert.equal((await num.request('account_set_password',{user_id:numberUser,password:'newpassword1'})).status,200);
  assert.ok(num.calls.find(c=>c.rpc==='ex_auth_password_set'));                 // number account: its own hash
  assert.equal(num.calls.some(c=>c.auth),false);
  assert.ok(num.calls.find(c=>c.rpc==='ex_auth_sign_out_everywhere'));
  const mail=application();
  assert.equal((await mail.request('account_set_password',{user_id:emailUser,password:'newpassword1'})).status,200);
  assert.equal(mail.calls.find(c=>c.auth).attrs.password,'newpassword1');       // e-mail account: Supabase Auth
});
