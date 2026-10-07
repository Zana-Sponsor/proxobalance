// Run from the repository root with PROXO_CHROMIUM_PATH if needed.
// Capture the existing authenticated server demo renderer with isolated,
// fictional service fixtures. No production credentials, writes or templates
// are embedded in the output: only twelve PNGs and a build-time provenance file.
import {createServer} from 'node:http';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
import sharp from 'sharp';
import {localService,invoke} from '../../test/fixtures/proxolink-v6-service.mjs';
import {PAGE_TYPES,PREPARED_DESIGNS} from '../../api/_lib/proxolink-pages.js';
process.env.PROXO_SUPABASE_URL='https://v6-isolated.supabase.co';
process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY='isolated-thumbnail-fixture';
process.env.PROXO_PREVIEW_SIGNING_SECRET='isolated-thumbnail-signing-secret-at-least-32';
const {default:handler}=await import('../../api/proxolink.js');
const originalFetch=global.fetch,fixture=localService(),documents=new Map();
global.fetch=fixture.fetcher;
try {
 for(const type of PAGE_TYPES)for(const key of PREPARED_DESIGNS){
  const selected=await invoke(handler,'templates',{query:{template_key:key,version:'6',page_type:type,language:'ku'}});
  assert.equal(selected.status,200);
  const token=new URL(selected.json().templates[0].preview_path,'https://isolated.test').searchParams.get('token');
  const page=await invoke(handler,'template-preview',{query:{token},auth:null});
  assert.equal(page.status,200);documents.set('/'+type+'-'+key,page);
 }
 assert.equal(fixture.writes.length,0);assert.equal(fixture.events.length,0);
}finally{global.fetch=originalFetch;}
const server=createServer((req,res)=>{
 const item=documents.get(req.url);if(!item){res.writeHead(404);res.end();return;}
 res.writeHead(200,{'Content-Type':'text/html; charset=utf-8',...item.headers});res.end(item.body);
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base='http://127.0.0.1:'+server.address().port;
const browser=await chromium.launch({...(process.env.PROXO_CHROMIUM_PATH?{executablePath:process.env.PROXO_CHROMIUM_PATH}:{}),args:['--no-sandbox']});
const files=[];mkdirSync('proxo_app/assets/proxolink_thumbnails',{recursive:true});
try {
 for(const type of PAGE_TYPES)for(const key of PREPARED_DESIGNS){
  const page=await browser.newPage({viewport:{width:393,height:1040},deviceScaleFactor:1});
  const outbound=[];await page.route('**/*',route=>{
   if(route.request().url().startsWith(base+'/'))return route.continue();
   outbound.push(true);return route.abort();
  });
  await page.goto(base+'/'+type+'-'+key);await page.evaluate(()=>document.fonts.ready);
  await page.waitForFunction(()=>window.ProxoLink&&Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0));
  const inert=await page.evaluate(()=>{
   let opened=0;window.open=()=>opened++;
   document.querySelectorAll('[data-provider]').forEach(b=>b.click());
   return window.ProxoLink.getConfig().preview===true&&opened===0&&!document.getElementById('intent-dialog').open;
  });assert.equal(inert,true);assert.equal(page.url(),base+'/'+type+'-'+key);assert.equal(outbound.length,0);
  await page.evaluate(()=>{
   document.getElementById('toast').hidden=true;
   document.getAnimations().forEach(a=>a.finish());
   document.querySelectorAll('.wa-message-card').forEach(e=>e.hidden=true);
  });
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  const png=await sharp(await page.screenshot()).resize(240,635).png().toBuffer();
  const file=`${type}-${key}.png`;writeFileSync('proxo_app/assets/proxolink_thumbnails/'+file,png);
  files.push({file,page_type:type,template_key:key,bytes:png.length,sha256:createHash('sha256').update(png).digest('hex'),preview_inert:inert,outbound_requests:outbound.length});
  await page.close();
 }
 writeFileSync('proxo_app/tool/proxolink-thumbnail-manifest.json',JSON.stringify({renderer:'Existing authenticated V6 server template-preview handler, fictional isolated fixtures',viewport:{width:393,height:1040},thumbnail:{width:240,height:635},files},null,2)+'\n');
 console.log('VERIFIED: 12 real server-rendered inert PNG thumbnails; zero fixture writes/events or outbound requests.');
}finally{await browser.close();await new Promise(r=>server.close(r));}
