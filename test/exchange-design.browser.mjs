// Offline mocked-data design audit; requires a local SPA static server.
// Run: PROXO_PLAYWRIGHT_MODULE=/path/to/playwright PROXO_BROWSER_EXECUTABLE=/usr/bin/chromium node test/exchange-design.browser.mjs
import {createRequire} from 'node:module';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PROXO_PLAYWRIGHT_MODULE||'playwright');
import fs from 'node:fs';
import assert from 'node:assert/strict';
const label=process.argv[2]||'verified';
const out=join(process.env.PROXO_AUDIT_OUTPUT||join(tmpdir(),'proxo-design-audit'),label);
const origin=new URL(process.env.PROXO_TEST_ORIGIN||'http://127.0.0.1:8765');
assert(['localhost','127.0.0.1','[::1]'].includes(origin.hostname),'This mock audit may only run against localhost');
fs.mkdirSync(out,{recursive:true});
const browser=await chromium.launch({...(process.env.PROXO_BROWSER_EXECUTABLE?{executablePath:process.env.PROXO_BROWSER_EXECUTABLE}:{}),headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();
const errors=[],writeRequests=[];page.on('pageerror',e=>errors.push(e.message));
await page.route('**/*',async route=>{
 const u=new URL(route.request().url());
 // Analytics are unrelated to this UI audit; do not record synthetic page views.
 if(u.pathname==='/assets/js/track.js')return route.fulfill({contentType:'application/javascript',body:''});
 if(!['GET','HEAD'].includes(route.request().method())){writeRequests.push(u.pathname);return route.fulfill({status:405,body:'Writes blocked by test harness'});}
 if(u.origin!==origin.origin)return route.fulfill({status:200,contentType:route.request().resourceType()==='script'?'application/javascript':'text/plain',body:''});
 if(u.pathname==='/api/balance')return route.fulfill({json:{ok:true,balance:{available_iqd:25000,held_iqd:5000},wallets:[],journal:[],payouts:[],payouts_enabled:false}});
 if(u.pathname.startsWith('/api/'))return route.fulfill({json:{ok:true,allowed:true,stats:{},cases:[]}});
 return route.continue();
});
await page.addInitScript(()=>{
 window.firebase={initializeApp(){},database:()=>({ref:()=>({on(){},off(){},once:async()=>({val:()=>null})})})};
 window.supabase={createClient:()=>({auth:{onAuthStateChange(){},getSession:async()=>({data:{session:null}})},from(){const q=new Proxy({}, {get:(o,k)=>k==='then'?resolve=>Promise.resolve({data:[],error:null}).then(resolve):()=>q});return q;}})};
});
await page.goto(new URL('/login',origin).href,{waitUntil:'networkidle'});await page.waitForTimeout(1400);
await page.evaluate(()=>{
 curUser={id:'fixture-user',email:'fixture@example.invalid'};curProfile={full_name:'کاربەر',username:'customer',phone:'07500000000',is_admin:false};activeSession={access_token:'fixture-token',user:curUser};
 getOrderSession=async()=>activeSession;loadKycStatus=async()=>{};kycExchangeBlocked=()=>false;
 document.getElementById('authWrap').style.display='none';document.getElementById('mainApp').style.display='block';document.body.classList.add('has-nav');applyProfileToUI();
 WALLET_DATA={FastPay:{name:'FastPay',number:'07500000000',allow_from:true,allow_receive:true,sort_order:0},FIB:{name:'FIB',number:'07500000001',allow_from:true,allow_receive:true,sort_order:1},AccountBalance:{name:'باڵانسی هەژمار',allow_from:true,allow_receive:false,sort_order:2}};
 WALLETS_STATE='ready';rebuildWalletOptions();document.getElementById('from').value='FastPay';document.getElementById('receiveVia').value='FIB';refreshTrigger('from');refreshTrigger('receiveVia');updateWallet();
 _homeFeedbackPromptShownThisSession=true;
 renderHistory(['پەسەندکرا','ڕەتکرایەوە','چاوەڕوانە'].map((status,i)=>({id:'order-'+i,order_code:'P123456789A'+i,user_id:'fixture-user',status,from_method:'FastPay',to_method:'FIB',amount:100000,total:98000,fee:2000,created_at:'2026-11-05T10:00:00Z',feedback:null})));
});
async function measure(name,width,scope){
 await page.setViewportSize({width,height:844});await page.waitForTimeout(320);
 if(name==='rating-controls')await page.evaluate(()=>{const sheet=document.getElementById('txSheet');sheet.scrollTop=sheet.scrollHeight;});
 const result=await page.evaluate(scope=>{
  const root=document.querySelector(scope)||document.body;
  const visible=el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&!!el.getClientRects().length};
  const controls=[...root.querySelectorAll('button,input,select,textarea,a.btn,[role="button"]')].filter(visible).map(el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el);return {disabled:el.disabled===true,selector:el.id?'#'+el.id:el.tagName.toLowerCase()+'.'+String(el.className).trim().replace(/\s+/g,'.'),text:(el.textContent||el.getAttribute('aria-label')||'').trim().slice(0,60),w:Math.round(r.width),h:Math.round(r.height),font:s.fontSize,color:s.color,bg:s.backgroundColor,radius:s.borderRadius,shadow:s.boxShadow,border:s.borderColor}});
  const headings=[...root.querySelectorAll('h1,h2,h3,.section-title,.pf-card-title')].filter(visible).map(el=>{const s=getComputedStyle(el);return {text:el.textContent.trim().slice(0,60),font:s.fontSize,color:s.color,weight:s.fontWeight}});
  const icons=[...root.querySelectorAll('.icn,.pb-svg-icon,.bn-icon,button>svg')].filter(visible).map(el=>{const r=el.getBoundingClientRect();return {cls:typeof el.className==='string'?el.className:el.className.baseVal,w:Math.round(r.width),h:Math.round(r.height)}});
  return {scrollWidth:document.documentElement.scrollWidth,viewport:innerWidth,controls,headings,icons};
 },scope);
 if(width===390)await page.screenshot({path:out+'/'+name+'.png',fullPage:false});
 return {name,width,...result};
}
const results=[];
for(const route of ['home','transactions','profile','rules','changes','verify','support']){
 await page.evaluate(r=>navigate(r,false),route);
 if(route==='changes')await page.evaluate(()=>{renderRatesNow([{from_method:'FastPay',to_method:'FIB',rate_type:'fee_percent',rate_value:2}]);renderChangeLog([{id:'change-1',field:'rate_value',from_method:'FastPay',to_method:'FIB',old_value:3,new_value:2,created_at:'2026-11-05T10:00:00Z'}]);});
 if(route==='support')await page.evaluate(()=>{_supportCases=[{id:'case-1',case_number:'CASE-001',status:'open',category:'order',description:'پشکنینی شێوازی کارتی پشتگیری بە داتای ساختە.',order_code:'P123456789AB',created_at:'2026-11-05T10:00:00Z',admin_note:'وەڵامی تاقیکردنەوە'}];renderSupportCases();});
 if(route==='verify')await page.evaluate(()=>{_kyc={status:'required',data:{can_submit:true,request:{reason:'بۆ پاراستنی هەژمار ناسنامەکەت پشتڕاست بکەرەوە.'}}};renderVerifyPage();kycSelectDoc('national_id',true);});
 for(const width of [320,390,768,1280])results.push(await measure(route,width,'#mainApp'));
 console.log('Measured',route);
}
for(const state of ['pending','approved','rejected','error']){
 await page.evaluate(status=>{navigate('verify',false);_kyc={status,data:{can_submit:status==='rejected',verification:{id:'fixture-kyc',document_type:'national_id',submitted_at:'2026-11-05T10:00:00Z',reviewed_at:'2026-11-05T10:00:00Z',rejection_reason:'وێنەیەکی ڕوونتر بنێرە.'}}};renderVerifyPage();},state);
 for(const width of [320,390])results.push(await measure('verify-'+state,width,'#pageVerify'));
}
await page.evaluate(()=>navigate('home',false));
for(const id of ['recipientSheet','pickerSheet','confirmSheet']){
 await page.evaluate(id=>{if(id==='pickerSheet')openPicker('from');else openSheet(document.getElementById(id));},id);
 for(const width of [320,390,768])results.push(await measure(id,width,'#'+id));
 await page.evaluate(id=>closeSheet(document.getElementById(id)),id);await page.waitForTimeout(250);
}
for(const tone of ['success','error','warning']){
 await page.evaluate(tone=>showResultModal({tone,title:'ئەنجامی تاقیکردنەوە',message:'ئەمە تەنها پشکنینی دیزاینە؛ هیچ مامەڵەیەک نەنێردراوە.'}),tone);
 for(const width of [320,390])results.push(await measure('result-'+tone,width,'#resultModal'));
 await page.evaluate(()=>closeResultModal());
}
await page.evaluate(()=>{document.getElementById('orderCorrectionModal').style.display='flex';});
for(const width of [320,390])results.push(await measure('correction-dialog',width,'#orderCorrectionModal'));
await page.evaluate(()=>{document.getElementById('orderCorrectionModal').style.display='none';});
await page.evaluate(()=>{openNotifPanel();});
results.push(await measure('notifications',390,'#notifPanel'));await page.evaluate(()=>closeNotifPanel());
await page.evaluate(()=>{navigate('support',false);document.getElementById('supportImagePicker').classList.add('selected');});
results.push(await measure('support-selected-image',390,'#pageSupport'));await page.evaluate(()=>document.getElementById('supportImagePicker').classList.remove('selected'));
await page.evaluate(()=>{navigate('transactions',false);openTxDetail('order-0');});
for(const width of [320,390])results.push(await measure('rating',width,'#txSheet'));
await page.evaluate(()=>{const b=document.getElementById('txSheetBody');b.scrollTop=b.scrollHeight;});
for(const width of [320,390])results.push(await measure('rating-controls',width,'#txSheet'));
await page.evaluate(()=>closeTxDetail());await page.waitForTimeout(350);
await page.evaluate(()=>{curUser=null;document.getElementById('mainApp').style.display='none';document.getElementById('authWrap').style.display='flex';document.body.classList.remove('has-nav');});
for(const route of ['login','signup','login/otp','signup/otp','forgetpassword','forgetpassword/otp','newpassword']){
 await page.evaluate(r=>{_otpPendingData={email:'fixture@example.invalid',flow:r.startsWith('signup')?'signup':'login'};_fpEmail='fixture@example.invalid';_fpVerified=true;setAuthRoute(r,false,true);},route);
 for(const width of [320,390,768])results.push(await measure('auth-'+route.replaceAll('/','-'),width,'#authWrap'));
 console.log('Measured',route);
}
const failures=[];
for(const r of results){
 if(r.scrollWidth>r.viewport)failures.push('Overflow '+r.name+' '+r.width);
 if(['transactions','profile','rules','changes','support','verify'].includes(r.name)||r.name.startsWith('auth-')){
  if(r.headings[0]?.font!=='18px')failures.push('Title scale '+r.name+' '+r.width+': '+r.headings[0]?.font);
 }
 for(const c of r.controls){
  const primary=/^#(?:authBtn|signupSubmitBtn|otpVerifyBtn|fpVerifyBtn|fpSaveBtn|forgotSendBtn|pfSaveBtn|supportSubmitBtn|kycSubmitBtn|submitBtn|orderFeedbackSubmit|confirmSendBtn|resultPrimaryBtn|recipientSave|balancePayoutToggle|balancePayoutSubmit)$/.test(c.selector);
  if(primary && !c.disabled){
   if(c.bg!=='rgb(2, 101, 255)'||c.color!=='rgb(255, 255, 255)')failures.push('Primary color '+r.name+' '+c.selector+' '+c.bg);
   if(c.h<48||c.h>72)failures.push('Primary size '+r.name+' '+c.selector+' '+c.h);
   if(c.font!=='14px')failures.push('Primary font '+r.name+' '+c.selector+' '+c.font);
  }
 }
}
if(errors.length)failures.push(...errors);
if(writeRequests.length)failures.push('Unexpected writes: '+writeRequests.join(','));
fs.writeFileSync(out+'/measurements.json',JSON.stringify({results,errors,failures},null,2));
console.log('Design assertions:',failures.length?'FAILED':'PASS',JSON.stringify(failures));
assert.equal(failures.length,0);
console.log('Total measured screens',results.length,'errors',JSON.stringify(errors));
await browser.close();
