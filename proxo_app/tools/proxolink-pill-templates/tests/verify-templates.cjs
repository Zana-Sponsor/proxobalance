const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const root = process.env.PROXO_KIT_ROOT || path.resolve(__dirname, '..');
const templates = fs.existsSync(path.join(root,'outputs')) ? path.join(root,'outputs') : root;
const evidence = path.join(root,'verification');
fs.mkdirSync(evidence,{recursive:true});
const sizes = [[320,568],[360,640],[375,667],[390,844],[412,915],[430,932],[768,1024],[1024,768],[568,320],[844,390]];
const themes = ['pill','pill-mint','pill-dark','pill-white'];
const results = {browser:'Chromium 154 headless, Linux',mode:'Actual rendered browser measurements; not Android/iOS native WebView',cases:[],checks:[]};
function luminance(rgb) {return rgb.map(c=>c/255).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4).reduce((s,c,i)=>s+c*[.2126,.7152,.0722][i],0);}
function contrast(a,b){const [x,y]=[luminance(a),luminance(b)].sort((a,b)=>a-b);return (y+.05)/(x+.05);}
(async()=>{
 const browser = await chromium.launch({headless:true,...(process.env.CHROMIUM_EXECUTABLE_PATH ? {executablePath:process.env.CHROMIUM_EXECUTABLE_PATH} : {}),args:['--no-sandbox']});
 const context=await browser.newContext({reducedMotion:'reduce'});
 const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 for(const theme of themes){
  await page.goto('file://'+path.join(templates,theme+'.html'));await page.evaluate(()=>document.fonts.ready);
  for(const [width,height]of sizes){
   await page.setViewportSize({width,height});
   const measured=await page.evaluate(()=>{
    const box=n=>{const r=n.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height}};
    return {overflow:document.documentElement.scrollWidth>innerWidth,font:document.fonts.check('16px ProxoBahij'),avatar:box(document.getElementById('avatar')),buttons:[...document.querySelectorAll('.pl-btn')].map(n=>({provider:n.dataset.provider,box:box(n),font:getComputedStyle(n.querySelector('.pl-lbl')).fontSize,icon:box(n.querySelector('svg')),bg:getComputedStyle(n).backgroundColor,fg:getComputedStyle(n).color,center:box(n.querySelector('.pl-lbl')).x+box(n.querySelector('.pl-lbl')).width/2})),stores:[...document.querySelectorAll('.store-link')].map(n=>({provider:n.dataset.provider,box:box(n),image:box(n.querySelector('img')),loaded:n.querySelector('img').naturalWidth>0})),lists:[...document.querySelectorAll('.list')].map(n=>({gap:getComputedStyle(n).gap,heights:[...n.children].map(b=>box(b).height)}))};
   });
   assert(!measured.overflow,`${theme} ${width}: overflow`);assert(measured.font,`${theme}: font unavailable`);assert.equal(measured.avatar.width,88);assert.equal(measured.avatar.height,88);assert.equal(measured.buttons.length,9);assert.equal(measured.stores.length,2);
   for(const b of measured.buttons){assert(Math.abs(b.box.height-56)<.1,`${b.provider} height ${b.box.height}`);assert.equal(b.font,'16px');assert(Math.abs(b.icon.width-22)<.1);assert(Math.abs(b.center-(b.box.x+b.box.width/2))<.1,`${b.provider}: not centered`);
    const rgb=s=>s.match(/[\d.]+/g).slice(0,3).map(Number);b.contrast=contrast(rgb(b.bg),rgb(b.fg));assert(b.contrast>=4.5,`${b.provider}: contrast ${b.contrast}`);assert(b.box.x>=0&&b.box.x+b.box.width<=width+.1);
   }
   for(const list of measured.lists)assert.equal(list.gap,'12px');
   for(const store of measured.stores){assert(Math.abs(store.box.height-64)<.1,`${store.provider} target height ${store.box.height}`);assert(store.loaded);}
   assert(Math.abs(measured.stores[0].image.height-40)<.1);assert(Math.abs(measured.stores[1].image.height*168/250-40)<.1);
   results.cases.push({theme,width,height,...measured});
  }
  await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(root,'verification',theme+'-rendered.png'),fullPage:true});
  await page.setViewportSize({width:320,height:568});
  await page.evaluate(()=>{document.documentElement.style.fontSize='200%';const c=ProxoLink.getConfig();c.name='ناوی درێژی فرۆشگا و خزمەتگوزارییەکانی کڕیار ABC 123';c.bio='ناسێنەری درێژ بۆ پشکنینی دەق و ڕێکخستنی پەڕە '.repeat(10);c.buttons[0].label='پەیوەندی و پرسیار دەربارەی بەرهەمەکان و خزمەتگوزارییەکان';ProxoLink.setConfig(c);});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  assert(await page.evaluate(()=>[...document.querySelectorAll('.pl-lbl')].every(n=>n.scrollWidth<=n.clientWidth+1)));
  results.checks.push({theme,check:'320px, 200% root text size, long mixed-language name/bio/button label',passed:true});
  await page.evaluate(()=>document.documentElement.style.fontSize='');
  await page.evaluate(()=>{const c=ProxoLink.getConfig();c.direction='ltr';c.lang='en';c.name='Proxo business';ProxoLink.setConfig(c)});
  assert(await page.evaluate(()=>document.documentElement.dir==='ltr'&&document.documentElement.scrollWidth<=innerWidth));
  results.checks.push({theme,check:'LTR language and no horizontal overflow',passed:true});
 }
 await page.goto('file://'+path.join(templates,'pill-white.html'));await page.evaluate(()=>document.fonts.ready);
 const urlTests=await page.evaluate(()=>{
  const good=[['whatsapp','https://wa.me/9647500000000'],['telegram','https://t.me/proxo_iq'],['viber','viber://chat?number=%2B9647500000000'],['korek','+9647500000000'],['asiacell','٠٧٧٠٠٠٠٠٠٠٠'],['talabat','https://www.talabat.com/iraq'],['lezzoo','https://www.lezzoo.com/'],['toters','https://www.totersapp.com/'],['wade','https://wadedelivery.com/en'],['app_store','https://apps.apple.com/us/app/wade-delivery-taxi/id1538884916'],['google_play','https://play.google.com/store/apps/details?id=app.trytiptop.customer']];
  const bad=[['whatsapp','javascript:alert(1)'],['lezzoo','https://lezzoo.com.evil.invalid/store'],['talabat','https://evil.invalid'],['telegram','https://t.me@evil.invalid/'],['viber','viber://chat?number=%2B9647500000000&evil=1'],['korek','tel:*123#'],['app_store','https://apps.apple.com'],['google_play','https://play.google.com/store'],['lezzoo','http://www.lezzoo.com/'],['unknown','https://example.com']];
  return {good:good.map(([id,url])=>({id,url,result:ProxoLink.validateUrl(id,url)})),bad:bad.map(([id,url])=>({id,url,result:ProxoLink.validateUrl(id,url)}))};
 });
 assert(urlTests.good.every(x=>x.result));assert(urlTests.bad.every(x=>!x.result));results.checks.push({check:'11 supported providers and 10 unsafe/malformed URL cases',passed:true});
 await page.evaluate(()=>{window.__PROXO_INTERCEPT_NAVIGATION__=true;window.captured=[];addEventListener('proxo:navigate',e=>{captured.push(e.detail);e.preventDefault()});const c=ProxoLink.getConfig();c.preview=false;c.buttons=[{type:'whatsapp',url:'https://wa.me/9647500000000',intents:true},{type:'lezzoo',url:'https://www.lezzoo.com/'},{type:'wade',url:'https://wadedelivery.com/en'},{type:'app_store',url:'https://apps.apple.com/us/app/wade-delivery-taxi/id1538884916'},{type:'google_play',url:'https://play.google.com/store/apps/details?id=app.trytiptop.customer'}];ProxoLink.setConfig(c);});
 await page.locator('[data-provider="whatsapp"]').click();assert(await page.locator('#intent-dialog').evaluate(n=>n.open));await page.locator('#cancel').click();assert(!await page.locator('#intent-dialog').evaluate(n=>n.open));assert.equal(await page.evaluate(()=>document.activeElement.dataset.provider),'whatsapp');
 await page.locator('[data-provider="whatsapp"]').click();await page.locator('.opt').first().click();assert.equal(await page.evaluate(()=>captured.length),1);assert((await page.evaluate(()=>captured[0].url)).includes('text='));
 for(const id of ['lezzoo','wade','app_store','google_play'])await page.locator(`[data-provider="${id}"]`).click();assert.equal(await page.evaluate(()=>captured.length),5);
 await page.evaluate(()=>{const c=ProxoLink.getConfig();c.buttons=[{type:'lezzoo',url:'javascript:alert(1)'},{type:'whatsapp',url:''},{type:'telegram',url:'https://t.me/proxo_iq',enabled:false}];ProxoLink.setConfig(c)});assert.equal(await page.locator('[data-provider]').count(),0);
 await page.evaluate(()=>{const c=ProxoLink.getConfig();c.name='<img src=x onerror=alert(1)>';c.preview=true;c.buttons=[{type:'lezzoo',url:'',label:'<script>alert(1)</script>'}];ProxoLink.setConfig(c)});assert.equal(await page.locator('#name img').count(),0);assert.equal(await page.locator('.pl-lbl script').count(),0);
 await page.locator('[data-provider="lezzoo"]').click();assert(await page.locator('#toast').isVisible());
 results.checks.push({check:'WhatsApp intent dialog/cancel/focus restoration/prefill; direct links; disabled/invalid filtering; text injection; inert preview',passed:true});
 await page.goto('file://'+path.join(templates,'proxo-template-editor.html'));await page.locator('#preview').waitFor();
 await page.waitForFunction(()=>document.getElementById('preview').srcdoc.includes('ProxoLink'));
 for(const [width,height]of [[320,568],[390,844],[1024,768]]){await page.setViewportSize({width,height});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
 await page.locator('#clear').click();assert.equal(await page.locator('.check input:checked').count(),0);await page.locator('#select-all').click();assert.equal(await page.locator('.check input:checked').count(),11);
 await page.locator('[data-theme="pill-dark"]').click();assert.equal(await page.locator('[data-theme="pill-dark"]').getAttribute('aria-pressed'),'true');
 await page.locator('#export-html').click();assert((await page.locator('#status').textContent()).length>0);
 results.checks.push({check:'Editor at 320/390/1024px; select/deselect all 11; theme selection; export rejects missing URLs',passed:true});
 await page.locator('#clear').click();
 const imported={template:'pill-white',preview:false,name:'$1 <img onerror=alert(1)> تاقیکردنەوە',bio:'Export test',direction:'rtl',lang:'ku',buttons:[{type:'whatsapp',url:'https://wa.me/9647500000000'},{type:'lezzoo',url:'https://www.lezzoo.com/'}]};
 await page.locator('#file').setInputFiles({name:'config.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(imported))});
 await page.waitForFunction(()=>document.querySelectorAll('.link-row').length===2);
 await page.locator('.moves button').nth(1).click();
 const jsonDownload=page.waitForEvent('download');await page.locator('#export-json').click();
 const jsonFile=await jsonDownload;const exported=JSON.parse(fs.readFileSync(await jsonFile.path(),'utf8'));
 assert.equal(exported.preview,false);assert.equal(exported.buttons[0].type,'lezzoo');assert.equal(exported.name,imported.name);
 const htmlDownload=page.waitForEvent('download');await page.locator('#export-html').click();
 const htmlFile=await htmlDownload;const exportedHtml=fs.readFileSync(await htmlFile.path(),'utf8');
 assert(!exportedHtml.includes('id="name">$1 <img'));assert(exportedHtml.includes('\\u003cimg'));
 const exportPage=await context.newPage();await exportPage.setContent(exportedHtml);await exportPage.evaluate(()=>document.fonts.ready);
 assert.equal(await exportPage.locator('#name').textContent(),imported.name);assert.equal(await exportPage.locator('#name img').count(),0);
 assert.equal(await exportPage.evaluate(()=>ProxoLink.getConfig().preview),false);assert.equal(await exportPage.locator('[data-provider]').count(),2);await exportPage.close();
 results.checks.push({check:'Editor imports config, reorders buttons, exports usable JSON and HTML, preserves dollar signs and escapes HTML in customer text',passed:true});
 assert.deepEqual(errors,[]);results.checks.push({check:'No browser JavaScript errors',passed:true});
 fs.writeFileSync(path.join(root,'verification/rendered-results.json'),JSON.stringify(results,null,2));
 await browser.close();console.log(JSON.stringify({renderedCases:results.cases.length,checks:results.checks.length,passed:true}));
})().catch(e=>{fs.writeFileSync(path.join(root,'verification/rendered-failure.txt'),e.stack);console.error(e);process.exit(1)});
