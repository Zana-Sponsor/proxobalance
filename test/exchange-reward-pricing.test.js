import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const pricing = readFileSync(new URL('../assets/js/exchange-reward-pricing.js', import.meta.url), 'utf8');
const context = vm.createContext({});
vm.runInContext(pricing, context);
const quote = context.ProxoRewardPricing.quote;
const free = {kind:'free_transactions',discount_percent:100,max_amount_iqd:50000};
const cases = [
  ['60k transfer, 50k free cap',60000,'fee_percent',2,free,59800,200,1000],
  ['at the cap',50000,'fee_percent',2,free,50000,0,1000],
  ['below the cap',49999,'fee_percent',2,free,49999,0,1000],
  ['one dinar over the cap',50001,'fee_percent',2,free,50000,1,1000],
  ['decimal 2.2 percent',60000,'fee_percent',2.2,free,59780,220,1100],
  ['carrier multiplier',60000,'multiplier',0.86,free,58600,1400,7000],
  ['50 percent discount on covered principal',60000,'fee_percent',2,{...free,kind:'fee_discount',discount_percent:50},59300,700,500],
  ['legacy unlimited coverage',60000,'fee_percent',2,{...free,max_amount_iqd:null},60000,0,1200],
  ['fixed fee still applies to excess',60000,'fee_fixed',1000,free,59000,1000,0],
  ['fixed fee waived within cap',50000,'fee_fixed',1000,free,50000,0,1000],
  ['fractional fixed fee rounds payout once',60000,'fee_fixed',123.5,free,59876,124,0],
  ['fractional IQD input keeps the same decimal math',60000.5,'fee_percent',2,free,59800,200.5,1000],
  ['no reward keeps the configured fee',60000,'fee_percent',2,null,58800,1200,0]
];
for(const [name,amount,type,value,reward,total,fee,discount] of cases){
  test(name,()=>{
    const result=quote(amount,{type,value},reward);
    assert.equal(result.total,total);
    assert.equal(result.fee,fee);
    assert.equal(result.discount_iqd,discount);
    assert.equal(result.total+result.fee,amount);
  });
}

test('the real customer calculation shows 50k covered, 10k excess and a 200 IQD fee',()=>{
  const app=readFileSync(new URL('../assets/js/app.js',import.meta.url),'utf8');
  const elements=new Map();
  const element=id=>{
    if(!elements.has(id))elements.set(id,{value:'',innerText:'',textContent:'',hidden:false,classList:{add(){},remove(){}}});
    return elements.get(id);
  };
  element('from').value='FastPay';element('receiveVia').value='FIB';
  const c=vm.createContext({
    document:{getElementById:element},amount:'60000',curUser:{id:'fixture'},
    MY_REWARDS:[{...free,active:true,max_uses:2,used_count:0,created_at:'2026-01-01T00:00:00Z',id:'reward'}],
    RATES:{'FastPay>FIB':{type:'fee_percent',value:2}},MIN_AMOUNT:10000,
    formatNum:v=>Number(v).toLocaleString('en-US'),fmtPct:String,
    refreshFormHints(){},updateSubmitState(){},refreshTrigger(){},updateHeaderRate(){},
    routeAllowed:()=>true,METHOD_META:{},getWalletInfo:()=>({locked:false})
  });
  vm.runInContext(pricing,c);
  vm.runInContext('function getAmtRaw(){return amount;}',c);
  const a=app.indexOf('function availableFeeReward('),b=app.indexOf('// Smallest amount',a);
  const start=app.indexOf('function calc(){'),end=app.indexOf('function _validateOrderFields()',start);
  assert.ok(a>=0&&b>a&&start>=0&&end>start);
  vm.runInContext(app.slice(a,b)+'\n'+app.slice(start,end),c);
  c.calc();
  assert.equal(element('bdFee').textContent,'200 IQD');
  assert.equal(element('totalDisplay').innerText,'59,800 IQD');
  assert.match(element('rewardBanner').textContent,/50,000/);
  assert.match(element('rewardBanner').textContent,/10,000/);
  assert.equal(element('rewardBanner').hidden,false);
  c.amount='49999';c.calc();
  assert.equal(element('bdFee').textContent,'0 IQD');
  assert.doesNotMatch(element('rewardBanner').textContent,/بڕی زیادە/);
  c.MY_REWARDS[0].used_count=2;c.amount='60000';c.calc();
  assert.equal(element('rewardBanner').hidden,true);
  assert.equal(element('bdFee').textContent,'1,200 IQD');
});
