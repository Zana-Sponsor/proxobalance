import {createServer} from 'node:http';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
import {PAGE_TYPES,PREPARED_DESIGNS,PROVIDER_REGISTRY,validatePage} from '../api/_lib/proxolink-pages.js';
import {preparedMetadata,preparedSource,nativeBaselineSource,renderPrepared} from '../api/_lib/proxolink-prepared.js';
import {publicPage} from '../api/_lib/proxolink.js';
import {pagePayload,OWNER} from '../test/fixtures/proxolink-v6-service.mjs';
const output='verification/v6-responsive';mkdirSync(output,{recursive:true});
const html=new Map();
for(const key of PREPARED_DESIGNS)for(const type of PAGE_TYPES)for(const language of ['ku','en'])for(const long of [false,true]){
 const name=long?(language==='ku'?'پڕۆکسۆ Proxo 2026 ':'Proxo 2026 ').padEnd(160,'X'):'Proxo';
 const bio=long?(language==='ku'?'بایۆ زانیاری Proxo 2026 ':'Bio Proxo 2026 ').repeat(150).slice(0,2000):'Proxo 2026';
 const config=validatePage(pagePayload(type,Object.keys(PROVIDER_REGISTRY).filter(k=>PROVIDER_REGISTRY[k].page_type===type),
  {name,bio,template_key:key,card_language:language}),OWNER);
 for(const baseline of [false,true]){
  const source=baseline?await nativeBaselineSource(key):await preparedSource(await preparedMetadata(key));
  html.set(`/${key}/${type}/${language}/${long}/${baseline}`,renderPrepared(source,config,{preview:true}));
 }
}
const server=createServer((req,res)=>html.has(req.url)?publicPage(res,html.get(req.url)):(res.writeHead(404),res.end()));
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const executablePath=process.env.PROXO_CHROMIUM_PATH;
const browser=await chromium.launch({...(executablePath?{executablePath}:{}),args:['--no-sandbox','--disable-dev-shm-usage']});
const results=[],base='http://127.0.0.1:'+server.address().port;
try{
 for(const width of [320,375,393,430,768])for(const key of PREPARED_DESIGNS)for(const type of PAGE_TYPES)for(const language of ['ku','en'])for(const long of [false,true]){
  const page=await browser.newPage({viewport:{width,height:1100},deviceScaleFactor:1}),errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.goto(base+`/${key}/${type}/${language}/${long}/false`);await page.evaluate(()=>document.fonts.ready);
  await page.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
  const state=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,dir:document.documentElement.dir,
   providers:[...document.querySelectorAll('[data-provider]')].map(b=>b.dataset.provider),font:getComputedStyle(document.body).fontFamily,
   avatar:{width:document.getElementById('avatar').getBoundingClientRect().width,height:document.getElementById('avatar').getBoundingClientRect().height},
   targets:[...document.querySelectorAll('[data-provider],.legal a,.footer-brand')].map(b=>({width:b.getBoundingClientRect().width,height:b.getBoundingClientRect().height})),
   footerLogo:!!document.querySelector('.footer-logo'),preview:window.ProxoLink.getConfig().preview}));
  assert.ok(state.scroll<=width+1,`${key}/${type}/${language}/${width} overflow`);assert.equal(state.dir,language==='en'?'ltr':'rtl');
  assert.ok(state.font.includes('Bahij'));assert.ok(state.targets.every(b=>b.height>=44));assert.equal(state.avatar.width,88);assert.equal(state.avatar.height,88);
  assert.ok(state.providers.every(k=>PROVIDER_REGISTRY[k].page_type===type));assert.equal(state.preview,true);assert.equal(state.footerLogo,true);assert.equal(errors.length,0);
  const requests=[];page.on('request',r=>{if(r.url().startsWith('https:'))requests.push(r.url());});
  await page.evaluate(()=>document.querySelectorAll('[data-provider]').forEach(b=>b.click()));
  await page.waitForTimeout(100);assert.equal(requests.length,0);assert.equal(await page.evaluate(()=>document.getElementById('intent-dialog').open),false);
  // Enlarged text retains the real responsive CSS and does not replace the template.
  await page.evaluate(()=>document.documentElement.style.fontSize='160%');
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'enlarged text overflow');
  await page.evaluate(()=>{document.documentElement.style.fontSize='';window.ProxoLink.setConfig(window.ProxoLink.getConfig());document.getAnimations().forEach(a=>{a.pause();a.currentTime=0;});document.getElementById('toast').hidden=true;});
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  const candidate=await page.screenshot();
  await page.goto(base+`/${key}/${type}/${language}/${long}/true`);await page.evaluate(()=>document.fonts.ready);
  await page.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
  await page.evaluate(()=>{document.getAnimations().forEach(a=>{a.pause();a.currentTime=0;});});
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  const baseline=await page.screenshot();if(!candidate.equals(baseline)){writeFileSync(output+'/failed-candidate.png',candidate);writeFileSync(output+'/failed-baseline.png',baseline);}assert.ok(candidate.equals(baseline),'prepared design pixel difference '+[key,type,language,width,long].join('/'));
  if(width===393&&!long){writeFileSync(`${output}/${key}-${type}-${language}.png`,candidate);}
  results.push({design:key,type,language,width,long_text:long,text_scale:1.6,overflow:false,targets_min_44:true,preview_inert:true,prepared_baseline_exact:true});
  await page.close();
 }
 writeFileSync(output+'/results.json',JSON.stringify({status:'VERIFIED',engine:'Chromium '+browser.version(),cases:results},null,2));
 console.log('VERIFIED: '+results.length+' actual renderer/browser cases, five widths, all page types/designs, RTL/LTR, long text, 1.6 text scale, inert previews, and exact prepared-design baseline pixels.');
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
