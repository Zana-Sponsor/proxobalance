// Offline browser regression using the real customer HTML, CSS and balance module.
// Run with Playwright installed and PROXO_BROWSER_EXECUTABLE if Chromium is external.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PROXO_PLAYWRIGHT_MODULE||'playwright');
const root=new URL('../',import.meta.url);
const read=path=>readFileSync(new URL(path,root),'utf8');
const balanceCss=read('assets/css/exchange-balance.css');
const oldBalanceCss=balanceCss.replace(/#exchangeCard\.kyc-locked > #balanceSendSection:not\(\[hidden\]\),\s*\[data-theme="light"\] #pageHome #exchangeCard\.kyc-locked > #balanceSendSection:not\(\[hidden\]\)\{display:block!important\}/,'');
assert.notEqual(oldBalanceCss,balanceCss);
function offlineHtml(path,before=false){
  return read(path).replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'')
    .replace(/<link\b[^>]*>/gi,tag=>{
      const ref=tag.match(/href="\/?(assets\/css\/[^"?]+)(?:\?[^" ]*)?"/);
      if(!ref)return '';
      return '<style>'+(before&&ref[1]==='assets/css/exchange-balance.css'?oldBalanceCss:read(ref[1]))+'</style>';
    });
}
const browser=await chromium.launch({headless:true,
  ...(process.env.PROXO_BROWSER_EXECUTABLE?{executablePath:process.env.PROXO_BROWSER_EXECUTABLE}:{}),
  args:['--no-sandbox','--disable-dev-shm-usage']});
try{
  for(const width of [390,1280]){
    const page=await browser.newPage({viewport:{width,height:900}});
    await page.route('**/*',route=>route.abort());
    await page.setContent(offlineHtml('index.html',true),{waitUntil:'domcontentloaded'});
    await page.evaluate(()=>{
      document.documentElement.setAttribute('data-theme','light');
      document.getElementById('authWrap').style.display='none';
      document.getElementById('mainApp').style.display='block';
      document.getElementById('pageHome').classList.add('active');
      document.body.classList.add('has-nav');
      document.getElementById('exchangeCard').classList.add('kyc-locked');
      document.getElementById('exchangeKycGate').hidden=false;
    });
    assert.equal(await page.locator('#balanceSendSection').isVisible(),false,'Reproduce old KYC-hidden balance');
    await page.addStyleTag({content:balanceCss});
    await page.evaluate(()=>{
      window.curUser={id:'browser-fixture'};window._route='home';
      window.getOrderSession=async()=>({access_token:'fixture-token'});
      window.kycExchangeBlocked=()=>document.getElementById('exchangeCard').classList.contains('kyc-locked');
      window.escHtml=text=>String(text||'');
      window.fixtureAmount=40000;
      window.fixtureEnabled=false;
      window.fetch=async()=>({ok:true,status:200,json:async()=>({ok:true,
        balance:{available_iqd:window.fixtureAmount,held_iqd:10000},
        payouts_enabled:window.fixtureEnabled,max_single_payout_iqd:1000000,
        wallets:[{key:'FastPay',name:'FastPay'}],journal:[],payouts:[]})});
    });
    await page.addScriptTag({content:read('assets/js/exchange-balance.js')});
    await page.evaluate(()=>loadMyBalance());
    assert.equal(await page.locator('#balanceSendSection').isVisible(),true);
    assert.equal(await page.locator('#balanceAvailable').textContent(),'40,000 د.ع');
    assert.equal(await page.locator('#balanceHeld').textContent(),'10,000 د.ع');
    assert.equal(await page.locator('#grpSend').isVisible(),false,'KYC still locks the exchange form');
    assert.equal(await page.locator('#balancePayoutToggle').isDisabled(),true);
    await page.evaluate(()=>{window.fixtureAmount=0;return loadMyBalance();});
    assert.equal(await page.locator('#balanceAvailable').textContent(),'0 د.ع');
    assert.equal(await page.locator('#balanceSendSection').isVisible(),true);
    await page.evaluate(()=>{
      document.getElementById('exchangeCard').classList.remove('kyc-locked');
      document.getElementById('exchangeKycGate').hidden=true;
    });
    assert.equal(await page.locator('#grpSend').isVisible(),true);
    assert.equal(await page.locator('#balanceSendSection').isVisible(),true);
    // Exercise the actual source picker shown in the customer's screenshot.
    await page.evaluate(()=>{
      window.FROM_OPTIONS=['FastPay','AccountBalance'];window.RECEIVE_OPTIONS=['FastPay'];
      window.METHOD_META={FastPay:{label:'FastPay'},AccountBalance:{label:'باڵانسی هەژمار',color:'#2563eb',icon:'<svg viewBox="0 0 24 24"><path d="M2 5h20v14H2z"/></svg>'}};window.ICON={banknote:''};
      window.needsSenderPhone=()=>false;window._balanceOrderKey=null;window.clearFieldError=()=>{};window.calc=()=>{};
      window.updatePlaceholder=()=>{};window.kycExchangeBlocked=()=>false;
      window.getWalletInfo=()=>({locked:false});window.routeAllowed=()=>true;

      document.getElementById('from').innerHTML='<option value="FastPay">FastPay</option><option value="AccountBalance">باڵانسی هەژمار</option>';
      document.getElementById('receiveVia').innerHTML='<option value="FastPay">FastPay</option>';
    });
    const app=read('assets/js/app.js');
    const actualIcon=app.match(/AccountBalance: \{ color:'#2563eb', icon:'([^']*)' \}/)[1];
    await page.evaluate(icon=>{window.METHOD_META.AccountBalance.icon=icon;},actualIcon);
    await page.addScriptTag({content:app.slice(app.indexOf('function methodIconHTML'),app.indexOf('const TOAST_ICON'))+app.slice(app.indexOf('function updateWallet(){'),app.indexOf('function updatePlaceholder(){'))});
    await page.locator('#fromTrigger').click();
    assert.equal(await page.locator('#accountBalanceSourceOption').isVisible(),true);
    assert.match(await page.locator('#accountBalanceSourceOption').textContent(),/باڵانسی هەژمار/);
    await page.locator('#accountBalanceSourceOption').click();
    assert.equal(await page.locator('#from').inputValue(),'AccountBalance','Balance must be a selected source');
    assert.equal(await page.locator('#fromTriggerLabel').textContent(),'باڵانسی هەژمار');
    assert.equal(await page.locator('#fromTriggerIcon svg').count(),1,'Balance has an actual wallet icon');
    assert.equal(await page.locator('#grpProof').isVisible(),false,'Internal funds require no external receipt');
    await page.waitForFunction(()=>document.getElementById('pickerSheet').style.display==='none');
    await page.evaluate(()=>openPicker('receive'));
    assert.equal(await page.locator('#accountBalanceSourceOption').count(),0,'Balance is a send source only');
    await page.evaluate(()=>closePicker());
    console.log('PASS: '+width+'px real HTML/CSS, KYC-locked and unlocked Send, zero/positive balances');
    await page.close();
  }
}finally{await browser.close();}
