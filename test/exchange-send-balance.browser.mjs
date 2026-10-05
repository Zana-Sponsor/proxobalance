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
    assert.equal(await page.locator('#savedRecipientsShortcut').isVisible(),true,'Saved recipients remain discoverable in the Send heading');
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
    // New wallet badges are remembered only after intersecting the visible picker.
    // Recipient CRUD uses synthetic, owner-scoped in-memory rows in this browser.
    await page.evaluate(()=>{
      window.fixtureRecipients=[];window.fixtureBadgeViews=[];window.fixtureWrites=[];window.fixtureRpc=[];
      window.WALLET_DATA={FastPay:{id:'wallet-fast',badge:'new',badge_version:'campaign-1'},
        AccountBalance:{id:'wallet-balance',badge:'popular',badge_version:'campaign-1'}};
      for(let i=0;i<15;i++){
        const key='Extra'+i;FROM_OPTIONS.push(key);METHOD_META[key]={label:key};
        WALLET_DATA[key]={id:key,badge:i===14?'new':'none',badge_version:'campaign-1'};
      }
      window.showToast=()=>{};window.validatePhoneLive=()=>{};window.confirm=()=>true;
      window.sb={rpc:async(name)=>{fixtureRpc.push(name);return {data:0,error:null};},
        from(table){
          let operation='read',row,filters={};
          const q={select(){return q;},eq(key,value){filters[key]=value;return q;},order(){return q;},
            insert(value){operation='insert';row=value;return q;},
            update(value){operation='update';row=value;return q;},delete(){operation='delete';return q;},
            single(){return q.then(result=>({...result,data:result.data?.[0]||null}));},
            then(resolve,reject){
              const target=table==='ex_wallet_badge_views'?fixtureBadgeViews:fixtureRecipients;
              const matches=v=>Object.entries(filters).every(([key,value])=>v[key]===value),before=target.filter(matches);
              if(operation==='insert')target.push({id:'recipient-'+target.length,...row});
              if(operation==='update')target.filter(matches).forEach(v=>Object.assign(v,row));
              if(operation==='delete'){for(let i=target.length-1;i>=0;i--)if(matches(target[i]))target.splice(i,1);}
              if(operation!=='read')fixtureWrites.push({table,operation,row,filters});
              return Promise.resolve({data:operation==='delete'?before:operation==='insert'?[target.at(-1)]:target.filter(matches),error:null}).then(resolve,reject);
            }
          };return q;
        }};
    });
    await page.addScriptTag({content:read('assets/js/exchange-customer-features.js')});
    await page.evaluate(()=>loadCustomerConveniences());
    await page.evaluate(()=>openPicker('from'));
    assert.equal(await page.locator('[data-new-wallet="FastPay"]').textContent(),'نوێ');
    await page.waitForFunction(()=>fixtureBadgeViews.some(v=>v.wallet_id==='wallet-fast'));
    assert.equal(await page.evaluate(()=>fixtureBadgeViews.some(v=>v.wallet_id==='Extra14')),false,'Unseen wallet stays new');
    await page.evaluate(()=>closePicker());await page.evaluate(()=>openPicker('from'));
    assert.equal(await page.locator('[data-new-wallet="FastPay"]').count(),0);
    assert.equal(await page.locator('.badge-popular').textContent(),'باو');
    assert.equal(await page.locator('[data-new-wallet="Extra14"]').count(),1);
    await page.locator('[data-new-wallet="Extra14"]').scrollIntoViewIfNeeded();
    await page.waitForFunction(()=>fixtureBadgeViews.some(v=>v.wallet_id==='Extra14'));
    await page.evaluate(()=>closePicker());
    await page.locator('#savedRecipientsShortcut').click();
    await page.locator('#recipientLabel').fill('Fixture Recipient');
    await page.locator('#recipientPhone').fill('07700000001');
    await page.locator('#recipientSave').click();
    await page.waitForFunction(()=>document.getElementById('savedRecipientList').textContent.includes('Fixture Recipient'));
    assert.equal(await page.locator('.recipient-select strong').textContent(),'Fixture Recipient');
    await page.locator('.recipient-select').click();
    assert.equal(await page.locator('#userPhone').inputValue(),'07700000001');
    assert.equal(await page.locator('#receiveVia').inputValue(),'FastPay');
    await page.evaluate(()=>openSavedRecipients());
    await page.locator('.recipient-actions button').first().click();
    await page.locator('#recipientLabel').fill('Updated Recipient');
    await page.locator('#recipientSave').click();
    await page.waitForFunction(()=>document.getElementById('savedRecipientList').textContent.includes('Updated Recipient'));
    if(width===390)await page.screenshot({path:'/workspace/scratch/068a40bbfdcc/customer-features-mobile.png'});
    await page.locator('.recipient-actions button').last().click();
    await page.waitForFunction(()=>fixtureRecipients.length===0);
    await page.evaluate(()=>refreshRewardAlerts());
    assert.ok(await page.evaluate(()=>fixtureRpc.includes('ex_refresh_reward_alerts')));
    await page.evaluate(()=>{curUser={id:'other-browser-fixture'};return loadCustomerConveniences();});
    assert.equal(await page.locator('.saved-recipient').count(),0,'Different owner sees no former recipients');
    assert.ok(await page.evaluate(()=>walletBadgeHTML('FastPay').includes('نوێ')),'Badge is new for another account');
    // Two actual browser tabs share a synthetic database. Real feature/UI
    // modules receive simulated owner-only database change signals.
    const peer=await browser.newPage({viewport:{width,height:900}});
    await peer.route('**/*',route=>route.abort());
    await peer.setContent(offlineHtml('index.html'),{waitUntil:'domcontentloaded'});
    let sharedRecipients=[];
    for(const livePage of [page,peer]){
      await livePage.exposeFunction('fixtureReadOwn',owner=>sharedRecipients.filter(r=>r.user_id===owner));
      await livePage.evaluate(()=>{
        window.curUser={id:'two-tabs-owner'};window._route='home';window._changesLoaded=false;window.liveHandlers=[];
        window.RECEIVE_OPTIONS=['FIB'];window.METHOD_META={FIB:{label:'FIB Bank'}};
        window.WALLET_DATA={};window.getWalletInfo=()=>({locked:false});window.routeAllowed=()=>true;
        window.escHtml=v=>String(v||'');window.showToast=()=>{};
        window.loadWallets=async()=>{};window.loadRates=async()=>{};window.loadMyRewards=async()=>{};window.loadMyBalance=async()=>{};
        window.refreshTrigger=()=>{};window.updateWallet=()=>{};window.updatePlaceholder=()=>{};
        window.calc=()=>{};window.openPicker=()=>{};
        window.openSheet=el=>{el.style.display='flex';el.classList.add('open');};
        window.closeSheet=el=>{el.style.display='none';el.classList.remove('open');};
        document.getElementById('authWrap').style.display='none';document.getElementById('mainApp').style.display='block';
        document.getElementById('receiveVia').innerHTML='<option value="FIB">FIB</option>';
        window.sb={
          from(table){let owner;const q={select(){return q;},eq(k,v){owner=v;return q;},order(){return q;},
            then(resolve,reject){return (table==='ex_saved_recipients'?fixtureReadOwn(owner):Promise.resolve([]))
              .then(data=>({data,error:null})).then(resolve,reject);}};return q;},
          channel(){const c={on(kind,filter,fn){liveHandlers.push({filter,fn});return c;},
            subscribe(fn){fn('SUBSCRIBED');return c;}};return c;},
          removeChannel:async()=>{}
        };
      });
      await livePage.addScriptTag({content:read('assets/js/exchange-live.js')});
      if(livePage===peer)await livePage.addScriptTag({content:read('assets/js/exchange-customer-features.js')});
      await livePage.evaluate(()=>{resetCustomerConveniences();openSavedRecipients();startCustomerLive();});
    }
    sharedRecipients=[{id:'remote-recipient',user_id:'two-tabs-owner',label:'Remote recipient',wallet_key:'FIB',phone:'07700000008'}];
    const signal=()=>Promise.all([page,peer].map(p=>p.evaluate(()=>{
      liveHandlers.find(h=>h.filter.table==='ex_customer_feature_changes'&&h.filter.event==='UPDATE').fn();
    })));
    await signal();
    for(const livePage of [page,peer])await livePage.waitForFunction(()=>document.getElementById('savedRecipientList').textContent.includes('Remote recipient'));
    sharedRecipients=[];await signal();
    for(const livePage of [page,peer])await livePage.waitForFunction(()=>!document.getElementById('savedRecipientList').textContent.includes('Remote recipient'));
    await peer.close();
    console.log('PASS: '+width+'px two-tab recipient insert/delete synchronization with owner-only signals');
    console.log('PASS: '+width+'px observed badge persistence, unseen badge, recipient create/select/edit/delete, owner switch and alerts');
    console.log('PASS: '+width+'px real HTML/CSS, KYC-locked and unlocked Send, zero/positive balances');
    await page.close();
    const adminPage=await browser.newPage({viewport:{width,height:900}});
    await adminPage.route('**/*',route=>route.abort());
    await adminPage.setContent(offlineHtml('exchange-admin.html'),{waitUntil:'domcontentloaded'});
    await adminPage.evaluate(()=>{
      window.adminUser={id:'super-fixture'};window.fixtureSuper=false;window.fixturePermissionCalls=[];window.allAccounts=[];
      window.isSuperAdmin=()=>fixtureSuper;window.esc=v=>String(v||'');window.adminDbMessage=e=>e.message;
      window.showToast=()=>{};window.loadAccounts=()=>{};
      window.openMo=id=>document.getElementById(id).classList.add('on');
      window.closeMo=id=>document.getElementById(id).classList.remove('on');
      window.sb={from(){const q={select(){return q;},eq(){return q;},maybeSingle:async()=>({
        data:{id:'staff-fixture',full_name:'Fixture Staff',is_admin:true,role:'admin',staff_permissions:['view']},error:null})};return q;},
        rpc:async(name,args)=>{fixturePermissionCalls.push({name,args});return {data:{user_id:args.p_user_id,permissions:args.p_permissions},error:null};}};
      document.getElementById('authWrap').style.display='none';document.getElementById('main').classList.add('show');document.getElementById('pgAccounts').classList.add('on');
    });
    await adminPage.addScriptTag({content:read('assets/js/exchange-staff.js')});
    await adminPage.evaluate(()=>{adminStaffPermissions=['view'];applyStaffUI();});
    assert.equal(await adminPage.locator('.sb-item[onclick="goPage(\'wallets\')"]').isVisible(),false);
    assert.equal(await adminPage.evaluate(()=>staffPageAllowed('statistics')),true);
    assert.equal(await adminPage.evaluate(()=>staffCan('refunds')),false);
    assert.equal(await adminPage.locator('#staffDirectoryButton').isVisible(),false,'Scoped staff cannot manage permissions');
    await adminPage.evaluate(()=>{fixtureSuper=true;applyStaffUI();return openStaffDirectory();});
    assert.equal(await adminPage.locator('#staffDirectoryButton').isVisible(),true);
    assert.match(await adminPage.locator('#staffDirectoryList').textContent(),/هێشتا کارمەندی ئادمین نییە/,'A super admin can discover the feature before staff exist');
    await adminPage.evaluate(()=>{closeMo('moStaffDirectory');document.getElementById('pgAccounts').classList.add('on');allAccounts=[{id:'staff-fixture',full_name:'Fixture Staff',role:'admin',is_admin:true}];return openStaffDirectory();});
    await adminPage.locator('#staffDirectoryList button').click();
    assert.equal(await adminPage.locator('#moStaffDirectory').isVisible(),false);
    await adminPage.locator('[data-staff-permission="manage_fees"]').check();
    if(width===390)await adminPage.screenshot({path:'/workspace/scratch/068a40bbfdcc/staff-permissions-mobile.png'});
    await adminPage.locator('#staffPermissionSave').click();
    assert.deepEqual(await adminPage.evaluate(()=>fixturePermissionCalls[0].args.p_permissions),['view','manage_fees']);
    assert.equal(await adminPage.evaluate(()=>staffCan('refunds')),true,'Super admin retains access');
    console.log('PASS: '+width+'px staff page restrictions and super-admin permission editor');
    await adminPage.close();
  }
}finally{await browser.close();}
