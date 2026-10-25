import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PROXO_PLAYWRIGHT_MODULE||'playwright');
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
function html(path){return read(path).replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'').replace(/<link\b[^>]*>/gi,t=>{const m=t.match(/href="\/?(assets\/css\/[^"?]+)/);return m?'<style>'+read(m[1])+'</style>':'';});}
const browser=await chromium.launch({headless:true,executablePath:process.env.PROXO_BROWSER_EXECUTABLE,args:['--no-sandbox']});
try{
 for(const width of [390,1280]){
  const page=await browser.newPage({viewport:{width,height:900}});await page.route('**/*',r=>r.abort());
  await page.setContent(html('index.html'));await page.evaluate(()=>document.getElementById('authWrap').style.display='flex');
  assert.equal(await page.locator('#authStepEmail').isVisible(),true);
  assert.equal(await page.locator('.auth-proof').isVisible(),false);
  for(const id of ['authStepEmail','authStepName','authStepPass','otpStep']){
   await page.evaluate(id=>{['authStepEmail','authStepName','authStepPass','otpStep'].forEach(x=>document.getElementById(x).style.display=x===id?'block':'none');},id);
   const bounds=await page.locator('.auth-card').boundingBox();assert.ok(bounds.x>=0&&bounds.x+bounds.width<=width+1,'Auth fits viewport');
   assert.equal(await page.locator('#'+id).isVisible(),true);
  }
  await page.evaluate(()=>{document.getElementById('otpStep').style.display='none';document.getElementById('authStepEmail').style.display='block';});
  if(width===390&&process.env.PROXO_AUTH_SCREENSHOT)await page.screenshot({path:process.env.PROXO_AUTH_SCREENSHOT,animations:'disabled'});
  await page.setContent(html('exchange-admin.html'));
  await page.evaluate(()=>{document.getElementById('authWrap').style.display='none';document.getElementById('moWallet').classList.add('on');window.allWallets=[];window.allRates=[{from_method:'FastPay',to_method:'FIB',is_active:true}];window.METHOD_META={};});
  await page.addScriptTag({content:read('assets/js/exchange-admin-workspace.js')});
  await page.evaluate(()=>switchWalletSection('info'));
  assert.equal(await page.locator('[data-wallet-section="info"]').isVisible(),true);
  assert.equal(await page.locator('[data-wallet-section="routes"]').isVisible(),false);
  await page.locator('[data-wallet-tab="routes"]').click();
  assert.equal(await page.locator('[data-wallet-section="routes"]').isVisible(),true);
  assert.equal(await page.locator('[data-wallet-section="info"]').isVisible(),false);
  await page.evaluate(()=>{document.getElementById('adminRateSearch').value='fib';});assert.equal(await page.evaluate(()=>filteredAdminRates().length),1);
  await page.evaluate(()=>{document.getElementById('adminRateSearch').value='korek';});assert.equal(await page.evaluate(()=>filteredAdminRates().length),0);
  await page.evaluate(()=>{
   document.getElementById('moWallet').classList.remove('on');
   window.adminUser={id:'super'};window.isSuperAdmin=()=>window.superMode;
   window.superMode=true;window.allAccounts=[];window.esc=v=>String(v);window.adminDbMessage=e=>e.message;
   window.openMo=id=>document.getElementById(id).classList.add('on');window.closeMo=id=>document.getElementById(id).classList.remove('on');
   window.toggleBan=(id,banned)=>window.staffOperation=['ban',id,banned];
   window.toggleAdmin=(id,current)=>window.staffOperation=['demote',id,current];
   window.openSetPasswordModal=(id,email)=>window.staffOperation=['password',id,email];
   window.sb={from:()=>({select(){return this;},eq(){return this;},order(){return this;},
    async range(start){return {data:start===0?[{id:'staff',role:'admin',is_admin:true,is_banned:false,full_name:'ئادمینی تاقیکردنەوە',email:'staff@example.invalid',staff_permissions:['view']}]:[],error:null};}})};
  });
  await page.addScriptTag({content:read('assets/js/exchange-staff.js')});
  await page.evaluate(()=>openStaffDirectory());
  assert.equal(await page.locator('#staffDirectoryList button').count(),4);
  const bounds=await page.locator('#moStaffDirectory .modal').boundingBox();
  assert.ok(bounds.x>=0&&bounds.x+bounds.width<=width+1,'Staff controls fit viewport');
  if(width===390&&process.env.PROXO_STAFF_SCREENSHOT)await page.locator('#moStaffDirectory .modal').screenshot({path:process.env.PROXO_STAFF_SCREENSHOT});
  await page.getByRole('button',{name:'بۆیکۆتکردن',exact:true}).click();
  assert.deepEqual(await page.evaluate(()=>staffOperation),['ban','staff',false]);
  await page.evaluate(()=>openStaffDirectory());
  await page.getByRole('button',{name:'لابردنی ئادمین',exact:true}).click();
  assert.deepEqual(await page.evaluate(()=>staffOperation),['demote','staff',true]);
  await page.evaluate(()=>openStaffDirectory());
  await page.getByRole('button',{name:'وشەی نهێنی',exact:true}).click();
  assert.deepEqual(await page.evaluate(()=>staffOperation),['password','staff','staff@example.invalid']);
  await page.evaluate(()=>{window.superMode=false;window.staffOperation=null;staffDirectoryAction('staff','demote');});
  assert.equal(await page.evaluate(()=>staffOperation),null);
  await page.close();console.log('PASS: '+width+'px app authentication, wallet tabs, route search and super-admin staff controls');
 }
}finally{await browser.close();}
