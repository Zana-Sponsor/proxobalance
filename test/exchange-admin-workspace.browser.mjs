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
  if(width===390)await page.screenshot({path:'/workspace/scratch/068a40bbfdcc/auth-app-preview.png',animations:'disabled'});
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
  await page.close();console.log('PASS: '+width+'px app authentication, isolated wallet tabs and route search');
 }
}finally{await browser.close();}
