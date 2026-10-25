import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');

function live(){
 const timers=new Map(),events={},channels=[],removed=[];let next=0,poll;
 const c=vm.createContext({console,
  document:{visibilityState:'visible',addEventListener:(name,fn)=>{events[name]=fn;}},
  window:{addEventListener:(name,fn)=>{events[name]=fn;},setInterval:fn=>{poll=fn;}},
  setTimeout:fn=>{timers.set(++next,fn);return next;},clearTimeout:id=>timers.delete(id)});
 vm.runInContext(read('assets/js/exchange-live.js')+'\nglobalThis.live=ProxoLive;',c);
 const client={channel(name){
  const ch={name,handlers:[],on(kind,filter,fn){ch.handlers.push({kind,filter,fn});return ch;},
   subscribe(fn){ch.status=fn;return ch;}};
  channels.push(ch);return ch;
 },removeChannel:ch=>{removed.push(ch);return Promise.resolve();}};
 return {c,client,channels,removed,events,poll:()=>poll(),async flush(){
  const jobs=[...timers.values()];timers.clear();await Promise.all(jobs.map(fn=>fn()));
 }};
}
test('live changes are owner filtered and bursts share one bounded refresh job',async()=>{
 const p=live();let reads=0;
 p.c.live.start(p.client,'customer','owner-a',[{key:'recipients',table:'ex_customer_feature_changes',
  filter:'user_id=eq.owner-a',read:async()=>{reads++;}}]);
 const ch=p.channels[0];
 assert.deepEqual(ch.handlers.map(h=>h.filter.event),['INSERT','UPDATE']);
 assert.ok(ch.handlers.every(h=>h.filter.filter==='user_id=eq.owner-a'));
 ch.handlers[0].fn();ch.handlers[1].fn();ch.handlers[0].fn();
 await p.flush();assert.equal(reads,1);
});
test('a change during an in-flight read triggers one follow-up without concurrent reads',async()=>{
 const p=live();let reads=0,resolve;
 p.c.live.start(p.client,'customer','owner-a',[{key:'recipients',table:'ex_customer_feature_changes',
  read:async()=>{reads++;if(reads===1)await new Promise(r=>{resolve=r;});}}]);
 p.channels[0].handlers[0].fn();const pending=p.flush();
 await Promise.resolve();p.channels[0].handlers[0].fn();p.channels[0].handlers[1].fn();
 assert.equal(reads,1);resolve();await pending;assert.equal(reads,2);
});
test('logout/account switch removes the old subscription and ignores stale channel callbacks',async()=>{
 const p=live();let a=0,b=0;
 const binding=read=>[{key:'private',table:'ex_customer_feature_changes',read}];
 p.c.live.start(p.client,'customer','owner-a',binding(async()=>{a++;}));
 const old=p.channels[0];old.handlers[0].fn();
 p.c.live.start(p.client,'customer','owner-b',binding(async()=>{b++;}));
 old.handlers[0].fn();old.status('SUBSCRIBED');
 p.channels[1].handlers[0].fn();await p.flush();
 assert.equal(a,0);assert.equal(b,1);assert.equal(p.removed.length,1);
 p.c.live.stop();p.channels[1].handlers[0].fn();await p.flush();assert.equal(b,1);
});
test('reconnect and visible-page resume catch missed changes; polling is only a disconnected fallback',async()=>{
 const p=live();let reads=0;
 p.c.live.start(p.client,'customer','owner-a',[{key:'private',table:'ex_customer_feature_changes',read:async()=>{reads++;}}]);
 p.channels[0].status('SUBSCRIBED');await p.flush();assert.equal(reads,1);
 p.poll();await p.flush();assert.equal(reads,1);
 p.events.online();await p.flush();assert.equal(reads,2);
 p.c.document.visibilityState='hidden';p.events.focus();await p.flush();assert.equal(reads,2);
 p.c.document.visibilityState='visible';p.channels[0].status('CHANNEL_ERROR');
 p.poll();await p.flush();assert.equal(reads,3);
});

function wallet(){
 const src=read('assets/js/admin.js'),els=new Map(),calls=[],toasts=[];let response,error;
 const el=id=>{if(!els.has(id))els.set(id,{value:'',checked:false,disabled:false,innerHTML:'Save',textContent:''});return els.get(id);};
 const values={walletId:'fixture-wallet',walletName:'FastPay',walletKey:'FastPay',walletFeeType:'percent',walletBadge:'popular'};
 for(const [id,value]of Object.entries(values))el(id).value=value;el('walletCanSend').checked=true;
 const c=vm.createContext({document:{getElementById:el},allWallets:[{id:'fixture-wallet',key:'FastPay'}],
  allPairs:[{from_method:'FastPay',to_method:'FIB',rate_type:'fee_percent',rate_value:2,is_active:true}],
  _pairDraft:{out:{FIB:{on:true,type:'fee_percent',value:'3'}},in:{}},_walletOldKey:'FastPay',
  sb:{rpc:async(name,args)=>{calls.push({name,args});if(error)throw error;return response||{data:{id:'fixture-wallet',...args.p_wallet},error:null};}},
  adminDbMessage:e=>e.message,handleDbWriteError:async()=>{},showToast:(msg,type)=>toasts.push({msg,type}),
  renderWalletsGrid(){},closeMo:id=>calls.push({closed:id}),loadWalletsAdmin:async()=>{}});
 vm.runInContext(src.slice(src.indexOf('async function saveWallet(){'),src.indexOf('// ═══ PER-PAIR ROUTES & FEES'))+
  src.slice(src.indexOf('function walletPairRows('),src.indexOf('// ── Original admin module 5')),c);
 return {c,el,calls,toasts,respond:r=>{response=r;},fail:e=>{error=e;}};
}
test('wallet and route edits use one atomic RPC and update the UI from its committed row',async()=>{
 const p=wallet();await p.c.saveWallet();
 assert.equal(p.calls[0].name,'ex_staff_save_wallet');
 assert.equal(p.calls[0].args.p_routes.length,1);
 assert.equal(p.c.allWallets[0].badge,'popular');
 assert.ok(p.toasts.some(t=>t.type==='gr'));assert.ok(p.calls.some(c=>c.closed==='moWallet'));
 assert.equal(p.el('walletSaveBtn').disabled,false);
});
test('failed/empty wallet results keep the editor open and restore the save button without false success',async()=>{
 for(const setup of [p=>p.respond({data:null,error:{message:'Denied'}}),
  p=>p.respond({data:null,error:null}),p=>p.fail(new Error('Offline'))]){
  const p=wallet();setup(p);await p.c.saveWallet();
  assert.equal(p.toasts.some(t=>t.type==='gr'),false);assert.equal(p.calls.some(c=>c.closed),false);
  assert.ok(p.el('walletSaveError').textContent);assert.equal(p.el('walletSaveBtn').disabled,false);
 }
});
test('invalid route values stop before any wallet write',async()=>{
 const p=wallet();p.c._pairDraft.out.FIB.value='';await p.c.saveWallet();
 assert.equal(p.calls.length,0);assert.ok(p.el('walletSaveError').textContent);
});
test('a label-only wallet edit does not rewrite unchanged fees',async()=>{
 const p=wallet();p.c._pairDraft.out.FIB.value='2';await p.c.saveWallet();
 assert.equal(p.calls[0].args.p_routes.length,0);
});
test('a temporary permission read failure does not report revoked admin access during live refresh',async()=>{
 const src=read('assets/js/admin.js');
 const c=vm.createContext({sb:{from(){const q={select(){return q;},eq(){return q;},
  maybeSingle:async()=>({data:null,error:{message:'Temporary network failure'}})};return q;}},
  staffCan:()=>true});
 vm.runInContext(src.slice(src.indexOf('async function verifyAdmin('),src.indexOf('async function doLogin(')),c);
 await assert.rejects(c.verifyAdmin('fixture','fixture@example.invalid',{strict:true}),e=>e.message==='Temporary network failure');
 assert.equal(await c.verifyAdmin('fixture','fixture@example.invalid'),false);
});
