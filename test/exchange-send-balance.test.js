import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('../assets/js/exchange-balance.js',import.meta.url),'utf8');
function customer(){
  const els=new Map(),events={},calls=[];
  const el=id=>{
    if(!els.has(id))els.set(id,{hidden:true,disabled:false,textContent:'',innerHTML:'',value:'',
      addEventListener(){},appendChild(){},reset(){},focus(){this.focused=true;},scrollIntoView(){this.scrolled=true;}});
    return els.get(id);
  };
  let payload={ok:true,balance:{available_iqd:40000,held_iqd:10000},
    payouts_enabled:false,wallets:[],journal:[],payouts:[],max_single_payout_iqd:1000000};
  let status=200,blocked=false,pending=null;
  const c=vm.createContext({curUser:{id:'fixture-user'},_route:'home',
    getOrderSession:async()=>({access_token:'fixture-only-token'}),
    fetch:async(url,options)=>{
      calls.push({url,options});
      if(pending)return pending;
      return {ok:status===200,status,json:async()=>payload};
    },
    document:{getElementById:el,createElement:()=>({}),readyState:'loading',visibilityState:'visible',
      addEventListener:(name,fn)=>{events[name]=fn;}},
    window:{addEventListener:(name,fn)=>{events[name]=fn;},setInterval(){}},
    escHtml:s=>String(s),kycExchangeBlocked:()=>blocked
  });
  vm.runInContext(source,c);
  return {c,el,calls,events,setBalance(available){payload.balance.available_iqd=available;},
    enable(){payload.payouts_enabled=true;},block(){blocked=true;},error(){status=503;payload={error:'fixture offline'};},
    defer(){pending=new Promise(resolve=>{this.resolve=resolve;});}};
}
test('Send shows available and held funds even when payout requests are disabled',async()=>{
  const p=customer();await p.c.loadMyBalance();
  assert.equal(p.el('balanceSendSection').hidden,false);
  assert.equal(p.el('balanceAvailable').textContent,'40,000 د.ع');
  assert.equal(p.el('balanceHeld').textContent,'10,000 د.ع');
  assert.equal(p.el('balancePayoutToggle').disabled,true);
  assert.equal(p.calls[0].options.method,'GET');
  assert.equal(p.calls[0].options.headers.Authorization,'Bearer fixture-only-token');
  p.setBalance(0);await p.c.loadMyBalance();
  assert.equal(p.el('balanceAvailable').textContent,'0 د.ع');
  assert.equal(p.el('balanceSendSection').hidden,false);
});
test('identity verification does not hide balance and keeps the payout form blocked',async()=>{
  const p=customer();p.enable();p.block();await p.c.loadMyBalance();
  assert.equal(p.el('balanceSendSection').hidden,false);
  assert.equal(p.el('balanceAvailable').textContent,'40,000 د.ع');
  assert.equal(p.el('balancePayoutToggle').disabled,true);
  p.c.toggleBalancePayout();
  assert.equal(p.el('balancePayoutForm').hidden,true);
});
test('a failed read is visible without displaying a false zero balance',async()=>{
  const p=customer();p.error();await p.c.loadMyBalance();
  assert.equal(p.el('balanceSendSection').hidden,false);
  assert.equal(p.el('balanceAvailable').textContent,'—');
  assert.equal(p.el('balancePayoutToggle').disabled,true);
  assert.match(p.el('balanceStatusMessage').textContent,/fixture offline/);
});
test('late balance responses cannot expose the signed-out customer balance',async()=>{
  const p=customer();p.defer();const request=p.c.loadMyBalance();
  await Promise.resolve();await Promise.resolve();
  p.c.curUser=null;p.c.resetMyBalance();
  p.resolve({ok:true,status:200,json:async()=>({ok:true,balance:{available_iqd:90000,held_iqd:0}})});
  await request;
  assert.equal(p.el('balanceSendSection').hidden,true);
  assert.equal(p.el('balanceAvailable').textContent,'—');
});
test('returning to an active Send page refreshes the latest refund balance',async()=>{
  const p=customer();await p.c.loadMyBalance();p.setBalance(80000);
  await p.events.focus();
  assert.equal(p.el('balanceAvailable').textContent,'80,000 د.ع');
  const before=p.calls.length;p.c._route='profile';await p.events.focus();
  assert.equal(p.calls.length,before);
});
test('choosing account balance opens its funded payout form when enabled',async()=>{
  const p=customer();p.enable();await p.c.openAccountBalanceSend();
  assert.equal(p.el('balanceSendSection').scrolled,true);
  assert.equal(p.el('balancePayoutForm').hidden,false);
  assert.equal(p.el('balanceDestWallet').focused,true);
  assert.equal(p.calls.length,1);
  assert.equal(p.calls[0].options.method,'GET');
});
test('choosing balance explains disabled, insufficient and KYC-blocked payouts',async()=>{
  for(const state of ['disabled','insufficient','kyc','error']){
    const p=customer();
    if(state==='insufficient'){p.enable();p.setBalance(0);}
    if(state==='kyc'){p.enable();p.block();}
    if(state==='error')p.error();
    await p.c.openAccountBalanceSend();
    assert.equal(p.el('balancePayoutForm').hidden,true,state);
    assert.equal(p.el('balanceStatusMessage').focused,true,state);
    assert.equal(p.calls.every(c=>c.options.method==='GET'),true);
  }
});
