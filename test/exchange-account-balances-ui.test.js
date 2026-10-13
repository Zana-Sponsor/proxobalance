import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const userId='22222222-2222-4222-8222-222222222222';
const zeroId='33333333-3333-4333-8333-333333333333';
const source=readFileSync(new URL('../assets/js/admin.js',import.meta.url),'utf8');
const start=source.indexOf('let _accountBalances =');
const end=source.indexOf('function toggleBan(',start);
assert.ok(start>=0&&end>start);
function panel(){
  const elements=new Map();
  const el=id=>{
    if(!elements.has(id))elements.set(id,{value:'',innerHTML:'',textContent:''});
    return elements.get(id);
  };
  const calls=[];
  let amount=40000,fail=false;
  const context=vm.createContext({
    document:{getElementById:el},allAccounts:[
      {id:userId,full_name:'Customer One',email:'one@example.invalid'},
      {id:zeroId,full_name:'Customer Two',email:'two@example.invalid'}
    ],_curPage:'accounts',accFilter:'all',STATUS_APPROVED:'approved',STATUS_PENDING:'pending',STATUS_REJECTED:'rejected',
    formatNum:v=>Number(v).toLocaleString('en-US'),esc:s=>String(s??''),
    fmtDate:()=>'',fmtTime:()=>'',fmtAgo:()=>'',fmtDateTime:s=>s,
    accIpCell:()=>'',roleButtonHTML:()=>'',openMo(){},kycBadgeHTML:()=>'',
    securityRequest:async()=>({ips:[]}),
    sb:{from(){const q={select(){return q;},eq(){return q;},order:async()=>({data:[]})};return q;},rpc:async()=>({data:[]})},
    adminApiRequest:async(action,{user_ids})=>{
      assert.equal(action,'account_balances');calls.push(Array.from(user_ids));
      if(fail)throw Error('fixture read failed');
      return user_ids.map(user_id=>({user_id,available_iqd:user_id===userId?amount:0,
        held_iqd:user_id===userId?10000:0,updated_at:user_id===userId?'2026-10-05T00:00:00Z':null}));
    }
  });
  vm.runInContext(source.slice(start,end),context);
  return {context,el,calls,setAmount(value){amount=value;},fail(){fail=true;}};
}
test('desktop and mobile user lists show each account balance, including zero and held funds',async()=>{
  const p=panel(),c=p.context;
  await c.loadAccountBalances([userId,zeroId]);
  for(const render of [c.renderAccTable,c.renderAccCards]){
    const html=render(c.allAccounts);
    assert.match(html,/Customer One[\s\S]*40,000 دینار[\s\S]*10,000 دینار[\s\S]*Customer Two[\s\S]*0 دینار/);
    assert.match(html,/باڵانسی بەردەست/);
  }
});
test('opening account details reads a fresh balance and updates the account list',async()=>{
  const p=panel(),c=p.context;
  await c.loadAccountBalances([userId,zeroId]);p.setAmount(55000);
  await c.openAccountInfo(userId);
  assert.match(p.el('aiBody').innerHTML,/باڵانسی هەژمار[\s\S]*55,000 دینار[\s\S]*10,000 دینار/);
  assert.match(p.el('accountsTableWrap').innerHTML,/55,000 دینار/);
  assert.deepEqual(p.calls.at(-1),[userId]);
});
test('all accounts beyond the balance dashboard limit are fetched in bounded batches',async()=>{
  const p=panel();
  const ids=Array.from({length:401},(_,i)=>i.toString(16).padStart(8,'0')+'-4444-4444-8444-444444444444');
  await p.context.loadAccountBalances(ids);
  assert.deepEqual(p.calls.map(ids=>ids.length),[200,200,1]);
  assert.match(p.context.accountBalanceCell(ids[400]),/0 دینار/);
});
test('a late response from another account cannot overwrite the currently opened balance',async()=>{
  const p=panel(),c=p.context,pending=new Map();
  c.adminApiRequest=async(action,{user_ids})=>new Promise(resolve=>pending.set(user_ids[0],resolve));
  const first=c.openAccountInfo(userId),second=c.openAccountInfo(zeroId);
  pending.get(zeroId)([{user_id:zeroId,available_iqd:0,held_iqd:0,updated_at:null}]);
  await second;
  pending.get(userId)([{user_id:userId,available_iqd:40000,held_iqd:0,updated_at:null}]);
  await first;
  assert.equal(p.el('aiTitle').textContent,'Customer Two');
  assert.match(p.el('aiBody').innerHTML,/Customer Two/);
  assert.doesNotMatch(p.el('aiBody').innerHTML,/Customer One|40,000 دینار/);
});
test('failed balance refresh preserves known values and shows an error in account details',async()=>{
  const p=panel(),c=p.context;
  await c.loadAccountBalances([userId]);p.fail();
  await assert.rejects(c.loadAccountBalances([userId]),/fixture read failed/);
  assert.match(c.accountBalanceCell(userId),/40,000 دینار/);
  await c.openAccountInfo(userId);
  assert.match(p.el('aiBody').innerHTML,/نەتوانرا باڵانس بخوێندرێتەوە/);
  assert.doesNotMatch(p.el('aiBody').innerHTML,/باڵانسی بەردەست[\s\S]*0 دینار/);
});
