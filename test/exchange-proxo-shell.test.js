import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const app=readFileSync(new URL('../assets/js/app.js',import.meta.url),'utf8');
const balance=readFileSync(new URL('../assets/js/exchange-balance.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const reminderCode=app.slice(app.indexOf('function pendingHomeFeedbackOrder(){'),app.indexOf('function renderHomePreview(){'));
const navCode=app.slice(app.indexOf('function navigate(route, push){'),app.indexOf("window.addEventListener('popstate'",app.indexOf('function navigate(route, push){')));
const approved={id:'order-1',order_code:'P123456789AB',status:'پەسەندکرا',feedback:null};
function reminderContext(rows=[{...approved}]){
  const element={hidden:true,innerHTML:''},timers=[],opened=[],routes=[];
  const context=vm.createContext({
    _orders:rows,curUser:{id:'user-1'},_route:'home',_txSheetId:null,FEEDBACK_REWARD:{percent:50},
    _homeFeedbackPromptShownThisSession:false,_homeFeedbackPromptQueued:false,_feedbackSheetId:null,
    document:{getElementById:()=>element},
    escHtml:s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),
    orderCodeOf:order=>order.order_code,
    setTimeout:fn=>timers.push(fn),
    navigate:route=>routes.push(route),openTxDetail:id=>opened.push(id),openFeedbackSheet:id=>opened.push(id),markFeedbackRead(){},localStorage:{setItem(){},getItem(){return null}}
  });
  vm.runInContext(reminderCode,context);
  return {context,element,timers,opened,routes};
}

test('Proxo shell uses official PNG branding and keeps wallet controls under Profile',()=>{
  assert.match(html,/<title>Proxo —/);
  assert.match(html,/"@type": "WebSite",\s*"name": "Proxo"/);
  assert.match(html,/proxo-app\/proxo-wordmark\.png/);
  const home=html.slice(html.indexOf('id="pageHome"'),html.indexOf('id="pageTx"'));
  const profile=html.slice(html.indexOf('id="pageProfile"'));
  assert(!home.includes('id="balanceSendSection"'));
  assert(profile.includes('id="balanceSendSection"'));
  for(const id of ['balanceAvailable','balanceHeld','profileBalanceAvailable','profileBalanceHeld']){
    assert.equal((html.match(new RegExp('id="'+id+'"','g'))||[]).length,1);
  }
});

test('Home only reminds about approved unrated orders',()=>{
  const {context}=reminderContext([{...approved,status:'چاوەڕوانە'},{...approved,feedback:{rating:5}},{...approved,id:'pending-rating'}]);
  assert.equal(context.pendingHomeFeedbackOrder().id,'pending-rating');
});

test('Home reward reminder renders its 50% reward copy safely',()=>{
  const {context,element}=reminderContext([{...approved,order_code:'<script>unsafe</script>'}]);
  context.renderHomeFeedbackPrompt();
  assert.equal(element.hidden,false);
  assert(!element.innerHTML.includes('<script>'));
  assert(element.innerHTML.includes('50%'));
  assert(!element.innerHTML.includes('<script>'));
});

test('Home feedback sheet prompt queues once per session',()=>{
  const {context,timers,opened}=reminderContext();
  context.maybePromptHomeFeedback();context.maybePromptHomeFeedback();
  assert.equal(timers.length,1);
  timers[0]();
  assert.deepEqual(opened,['order-1']);
  context.maybePromptHomeFeedback();
  assert.equal(timers.length,1);
});

test('Leaving Home before the delay prevents a stale rating popup',()=>{
  const {context,timers,opened}=reminderContext();
  context.maybePromptHomeFeedback();context._route='profile';timers[0]();
  assert.equal(opened.length,0);
  assert.equal(context._homeFeedbackPromptQueued,false);
});

test('Home rating action opens the matching feedback sheet and successful rating hides the reminder',()=>{
  const {context,routes,opened,element}=reminderContext();
  context.openHomePendingFeedback();
  assert.deepEqual(routes,[]);assert.deepEqual(opened,['order-1']);
  context._orders[0].feedback={rating:5};context.renderHomeFeedbackPrompt();
  assert.equal(element.hidden,true);assert.equal(element.innerHTML,'');
});

test('Same-tab navigation does not create duplicate browser history entries',()=>{
  const pushed=[],selected=[];
  const context=vm.createContext({
    ROUTES:{home:'pageHome',profile:'pageProfile',transactions:'pageTx'},_route:'profile',curUser:null,
    ROUTE_TITLES:{profile:'پڕۆفایل — Proxo'},location:{pathname:'/profile',hash:''},
    document:{getElementById:()=>({classList:{toggle(){}}}),querySelectorAll:()=>[{dataset:{route:'profile'},classList:{toggle:(name,on)=>selected.push(on)}}],addEventListener(){}},
    history:{pushState:(state,title,url)=>pushed.push(url)},urlFor:r=>r==='home'?'/':'/'+r,
    closeNotifPanel(){},window:{scrollTo(){}},renderTxPage(){},renderHomeFeedbackPrompt(){},maybePromptHomeFeedback(){},fillProfileForm(){},loadKycStatus(){}
  });
  vm.runInContext(navCode,context);
  context.navigate('profile');assert.equal(pushed.length,0);assert.equal(selected[0],true);
  context.navigate('transactions');assert.deepEqual(pushed,['/transactions']);
});

function balanceContext(){
  const nodes=new Map();
  const get=id=>{if(!nodes.has(id))nodes.set(id,{textContent:'',hidden:false,disabled:false,value:'',reset(){},appendChild(){},addEventListener(){}});return nodes.get(id);};
  const context=vm.createContext({
    curUser:{id:'user-1'},getOrderSession:async()=>({access_token:'fixture-only'}),
    fetch:async()=>({ok:true,json:async()=>({ok:true,balance:{available_iqd:25000,held_iqd:5000},wallets:[],journal:[],payouts:[],payouts_enabled:false})}),
    document:{getElementById:get,createElement:()=>({}),addEventListener(){},visibilityState:'visible'},
    window:{addEventListener(){},setInterval(){}},setInterval(){},kycExchangeBlocked:()=>false,
    escHtml:s=>String(s)
  });
  vm.runInContext(balance,context);
  return {context,get};
}
test('Profile balances are populated from the same authenticated balance API',async()=>{
  const {context,get}=balanceContext();await context.loadMyBalance();
  for(const id of ['balanceAvailable','profileBalanceAvailable'])assert.equal(get(id).textContent,'25,000 د.ع');
  for(const id of ['balanceHeld','profileBalanceHeld'])assert.equal(get(id).textContent,'5,000 د.ع');
});

test('Reset clears both legacy wallet values and visible Profile values',async()=>{
  const {context,get}=balanceContext();await context.loadMyBalance();context.resetMyBalance();
  for(const id of ['balanceAvailable','profileBalanceAvailable','balanceHeld','profileBalanceHeld'])assert.equal(get(id).textContent,'—');
});
