// Real customer markup, styles, calculator and receipt renderer; no network/account writes.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PROXO_PLAYWRIGHT_MODULE||'playwright');
const root=new URL('../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const app=read('assets/js/app.js');
const realFunctions=app.slice(app.indexOf('function calc(){'),app.indexOf('function _validateOrderFields()'))+
  app.slice(app.indexOf('function orderCodeOf('),app.indexOf('// ── transaction details'))+
  app.slice(app.indexOf('function renderTxPage('),app.indexOf('function copyNum()'));
const html=read('index.html').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'')
  .replace(/<link\b[^>]*>/gi,tag=>{
    const ref=tag.match(/href="\/?(assets\/css\/[^"?]+)(?:\?[^" ]*)?"/);
    return ref?'<style>'+read(ref[1])+'</style>':'';
  }).replace('<head>','<head><base href="https://fixture.invalid/">');
const browser=await chromium.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage'],
  ...(process.env.PROXO_BROWSER_EXECUTABLE?{executablePath:process.env.PROXO_BROWSER_EXECUTABLE}:{})});
try{
  for(const width of [390,1280]){
    const page=await browser.newPage({viewport:{width,height:1000}});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.route('**/*',async route=>{
      const path=new URL(route.request().url()).pathname;
      if(/^\/assets\/fonts\/[\w/-]+\.(woff2?|ttf)$/.test(path)){
        try{await route.fulfill({body:readFileSync(new URL('.'+path,root))});return;}catch(_){}
      }
      await route.abort();
    });
    await page.setContent(html,{waitUntil:'domcontentloaded'});
    await page.evaluate(()=>{
      document.documentElement.dataset.theme='light';
      document.getElementById('authWrap').style.display='none';
      document.getElementById('mainApp').style.display='block';
      document.getElementById('pageHome').classList.add('active');
      document.getElementById('exchangeCard').classList.remove('kyc-locked');
      document.getElementById('from').innerHTML='<option value="FastPay">FastPay</option><option value="Korek">Korek</option>';
      document.getElementById('receiveVia').innerHTML='<option value="FIB">FIB Bank</option>';
      window.amount='60000';window.getAmtRaw=()=>window.amount;window.curUser={id:'fixture'};
      window.formatNum=v=>Number(v).toLocaleString('en-US');window.fmtPct=String;
      window.kycFmtDate=iso=>new Date(iso).toLocaleDateString('en-GB');
      window.RATES={'FastPay>FIB':{type:'fee_percent',value:2},'Korek>FIB':{type:'fee_percent',value:20}};
      window.MIN_AMOUNT=10000;window.METHOD_META={};window.getWalletInfo=()=>({locked:false});
      window.routeAllowed=()=>true;window.refreshFormHints=()=>{};window.updateSubmitState=()=>{};window.updateHeaderRate=()=>{};
      window.escHtml=v=>String(v).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
      window.methodLabel=k=>({FIB:'FIB Bank',AccountBalance:'باڵانسی هەژمار'}[k]||k);
      window.ICON={arrowLeftLong:'<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 12H4m6-6-6 6 6 6"/></svg>'};
      window._orders=[{id:'11111111-1111-4111-8111-111111111111',order_code:'P7K9M2Q4R6T8',status:'پەسەندکرا',from_method:'FastPay',to_method:'FIB',amount:60000,total:59100,created_at:new Date().toISOString()},
        {id:'22222222-2222-4222-8222-222222222222',order_code:'P8A3B5C7D9E2',status:'ڕەتکرا',from_method:'FastPay',to_method:'FIB',amount:40000,total:39200,balance_refunded_at:new Date().toISOString(),created_at:new Date().toISOString()}];
      window.txMatches=()=>true;window._txQuery='';window._txStatus='all';window._txTime='all';
      window.openTxDetail=id=>{window.openedOrder=id;};
    });
    await page.addScriptTag({content:read('assets/js/exchange-pricing.js')});
    await page.addScriptTag({content:realFunctions});
    await page.evaluate(()=>calc());
    // No discount anywhere: the full configured fee is charged and no discount UI exists.
    for(const id of ['#welcomeReward','#rewardBanner','#bdDiscountRow','#bdDiscount'])
      assert.equal(await page.locator(id).count(),0,id);
    assert.equal(await page.locator('#bdFee').textContent(),'1,200 IQD');
    assert.equal(await page.locator('#totalDisplay').innerText(),'58,800 IQD');
    assert.equal(await page.locator('#feeDisplay').isVisible(),false,'No duplicated fee row');
    if(process.env.PROXO_SCREENSHOT_DIR && width===390)
      await page.locator('#xcBreakdown').screenshot({path:process.env.PROXO_SCREENSHOT_DIR+'/exchange-price-mobile.png'});
    await page.evaluate(()=>{
      document.getElementById('pageHome').classList.remove('active');
      document.getElementById('pageTx').classList.add('active');renderTxPage();
    });
    assert.equal(await page.locator('#txSummary').count(),0);
    assert.equal(await page.locator('#txList .tx-money').count(),0);
    assert.equal(await page.locator('#txList .tx-card').count(),2);
    assert.equal(await page.locator('#txList .tx-card').nth(1).locator('.tx-amount').textContent(),'40,000 IQD');
    await page.locator('#txList .tx-card').first().focus();await page.keyboard.press('Enter');
    assert.equal(await page.evaluate(()=>openedOrder),_uuid());
    if(process.env.PROXO_SCREENSHOT_DIR && width===390)
      await page.locator('#pageTx').screenshot({path:process.env.PROXO_SCREENSHOT_DIR+'/exchange-transactions-mobile.png'});
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'No horizontal overflow');
    assert.deepEqual(errors,[]);
    await page.close();
  }
  console.log('PASS: 390/1280px fee (no discount) and completed/refund receipts, keyboard navigation, no overflow');
}finally{await browser.close();}
function _uuid(){return '11111111-1111-4111-8111-111111111111';}
