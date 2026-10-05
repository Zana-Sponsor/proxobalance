// Local Chromium evidence only; never native/remote/staging certification.
// Supply immutable private sources + an offline cache of the original web
// dependencies. Only final fictional pages are served on the loopback interface.
import http from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import sharp from 'sharp';
import {renderTemplate,publicPage} from '../api/_lib/proxolink.js';
import {TEMPLATE_ORDER} from './proxolink-refinements.mjs';
const [mode,v1Arg,v2Arg,cacheArg,outArg]=process.argv.slice(2);
if(!['--serve','--run'].includes(mode)||![v1Arg,v2Arg,cacheArg,outArg].every(Boolean))
  throw Error('Usage: node scripts/verify-proxolink-visual.mjs --serve|--run /private/v1 /private/v2 /original-dependency-cache /evidence');
const roots={1:path.resolve(v1Arg),2:path.resolve(v2Arg)},cache=path.resolve(cacheArg),output=path.resolve(outArg);
const base='http://127.0.0.1:4177';
const id='00000000-0000-4000-8000-000000000001';
const owner='00000000-0000-4000-8000-000000000002';
const bios={short:'پەیوەندیمان پێوە بکەن.',medium:'لەڕێگەی دووگمەکانەوە پەیوەندیمان پێوە بکەن بۆ زانیاری زیاتر دەربارەی بەرهەم و خزمەتگوزارییەکانمان.',long:'فرۆشگای Proxo 2026 — پەیوەندیمان پێوە بکەن بۆ زانیاری زیاتر دەربارەی بەرهەم و خزمەتگوزارییەکانمان. '.repeat(12),unbroken:'Proxo'.repeat(200)};
if(mode==='--serve') {
 const manifests={};
 for(const version of [1,2])manifests[version]=JSON.parse(await readFile(path.join(roots[version],'manifest.json'),'utf8'));
 const server=http.createServer(async(req,res)=>{
  try {
   const url=new URL(req.url,base),match=/^\/visual\/(dark|light|classic|pill|card|neon|zoom|banner)\/v([12])$/.exec(url.pathname);
   if(match) {
    const [,key,version]=match,meta=manifests[version].find(e=>e.template_key===key);
    const raw=await readFile(path.join(roots[version],meta.storage_path),'utf8');
    assert.equal(createHash('sha256').update(raw).digest('hex'),meta.checksum_sha256);
    const source=raw.replace(/!function\s*\(w,\s*d,\s*t\)\s*\{[\s\S]*?\}\(window,\s*document,\s*['"]ttq['"]\);/g,'');
    const card={id,user_id:owner,name:'فرۆشگای Proxo 2026',bio:bios[url.searchParams.get('bio')]||bios.medium,tt:'proxo_iq',template_key:key,template_version:Number(version),color_theme:'purple',card_language:'ku',platforms:{wa:'9647501234567',vb:'9647501234567',ig:'proxo_iq',ph:'9647501234567',as:'9647501234567'},demo:!url.searchParams.has('public'),avatar_path:owner+'/'+id+'/avatar.png'};
    return publicPage(res,renderTemplate(source,card,{publicAvatarUrl:'/assets/proxolink-demo-avatar.png'}));
   }
   const local={'/assets/fonts/Rabar_021.woff2':'assets/fonts/Rabar_021.woff2','/assets/proxolink-demo-avatar.png':'assets/proxolink-demo-avatar.png'};
   if(local[url.pathname]) {
    res.setHeader('Content-Type',url.pathname.endsWith('woff2')?'font/woff2':'image/png');
    return res.end(await readFile(path.resolve(local[url.pathname])));
   }
   res.statusCode=404;res.end();
  }catch{res.statusCode=500;res.end('Local visual fixture unavailable');}
 });
 server.listen(4177,'127.0.0.1',()=>console.log('Local fictional template pages: '+base+'/visual/dark/v2'));
} else {
 const require=createRequire(import.meta.url);
 const {chromium}=require(process.env.PROXO_VISUAL_PLAYWRIGHT_MODULE||'playwright');
 const browser=await chromium.launch({executablePath:process.env.PROXO_VISUAL_CHROMIUM,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({deviceScaleFactor:1});
 const files={
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css':['all.min.css','text/css'],
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/webfonts/fa-brands-400.woff2':['fa-brands-400.woff2','font/woff2'],
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/webfonts/fa-solid-900.woff2':['fa-solid-900.woff2','font/woff2'],
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/webfonts/fa-regular-400.woff2':['fa-regular-400.woff2','font/woff2'],
  'https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp':['footer.webp','image/webp']
 };
 await context.route('**/*',async route=>{
  const url=route.request().url();
  if(url.startsWith(base+'/'))return route.continue();
  if(files[url])return route.fulfill({body:await readFile(path.join(cache,files[url][0])),contentType:files[url][1]});
  return route.abort();
 });
 await mkdir(output,{recursive:true});
 const cases=[];const page=await context.newPage();let errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 const wait=async()=>{await page.evaluate(()=>document.fonts.ready);await page.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));};
 const dimensions=()=>page.evaluate(()=>{
  const rect=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {x:r.x,y:r.y,width:r.width,height:r.height,color:s.color,background:s.backgroundImage,radius:s.borderRadius,font:s.fontFamily};};
  return {header:rect(document.querySelector('.gradient-bg,.top-banner,.hdr')),avatar:document.querySelector('.avatar,.av,.hdr-av')?rect(document.querySelector('.avatar,.av,.hdr-av')):null,button:rect(document.querySelector('#wa')),bodyColor:getComputedStyle(document.body).backgroundColor};
 });
 try {
  for(const key of TEMPLATE_ORDER)for(const width of [320,375,393,430,768]) {
   await page.setViewportSize({width,height:1000});errors=[];
   await page.goto(base+'/visual/'+key+'/v1');await wait();const before=await dimensions();
   await page.screenshot({path:path.join(output,key+'-'+width+'-v1.png'),animations:'disabled'});
   await page.goto(base+'/visual/'+key+'/v2');await wait();const after=await dimensions();
   const state=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,fonts:[...document.fonts].filter(f=>f.status==='loaded').map(f=>f.family),bioWeight:getComputedStyle(document.querySelector('.desc,.ubio,.hdr-bio')).fontWeight,buttonWeight:getComputedStyle(document.querySelector('#wa span,.pl-lbl')).fontWeight,links:[...document.querySelectorAll('a[href]')].every(a=>a.getAttribute('href')==='#'),telegram:!!document.querySelector('#tg,.fa-telegram'),animations:document.getAnimations().length}));
   assert.equal(state.overflow,false,key+' overflow');assert.equal(state.bioWeight,'400');assert.equal(state.buttonWeight,'400');assert.equal(state.links,true);assert.equal(state.telegram,false);
   assert.ok(state.fonts.some(f=>/Rabar|^R$/.test(f)));assert.ok(state.fonts.some(f=>/Awesome/.test(f)));
   assert.equal(before.bodyColor,after.bodyColor);assert.equal(before.header.background,after.header.background);
   assert.equal(before.button.radius,after.button.radius);assert.equal(before.button.background,after.button.background);
   if(before.avatar){assert.equal(before.avatar.width,after.avatar.width);assert.equal(before.avatar.height,after.avatar.height);}
   const animationBefore=await page.evaluate(()=>document.getAnimations().map(a=>a.currentTime));
   await page.waitForTimeout(100);
   const advanced=await page.evaluate(times=>document.getAnimations().some((a,i)=>a.currentTime>times[i]),animationBefore);
   assert.ok(advanced,key+' original animations');
   await page.locator('#wa').click();assert.ok(await page.locator('.modal-overlay.active').isVisible());
   await page.locator('.btn-cancel,.modal-cancel').click();assert.equal(await page.locator('.modal-overlay.active').count(),0);
   await page.locator('#wa').click();await page.locator('#main-confirm-btn,#mod-ok').click();assert.equal(await page.locator('.modal-overlay.active').count(),0);
   assert.equal(page.url(),base+'/visual/'+key+'/v2');
   // Original modal JS suspends decorative effects after a contact action.
   // Compare two fresh renders at the same interaction/animation state.
   await page.mouse.move(0,0);await page.goto(base+'/visual/'+key+'/v2');await wait();
   const demo=await page.screenshot({path:path.join(output,key+'-'+width+'-v2.png'),animations:'disabled'});
   await page.goto(base+'/visual/'+key+'/v2?public=1');await wait();
   const real=await page.screenshot({path:path.join(output,key+'-'+width+'-public.png'),animations:'disabled'});
   const demoRaw=await sharp(demo).raw().toBuffer(),realRaw=await sharp(real).raw().toBuffer();
   assert.equal(Buffer.compare(demoRaw,realRaw),0,key+' selector/public pixel mismatch');
   for(const bio of ['short','long','unbroken']) {
    await page.goto(base+'/visual/'+key+'/v2?bio='+bio);await wait();
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,key+' '+bio+' overflow');
    assert.equal(await page.locator('.desc,.ubio,.hdr-bio').textContent(),bios[bio]);
   }
   await page.emulateMedia({reducedMotion:'reduce'});await page.goto(base+'/visual/'+key+'/v2');await wait();
   assert.equal(await page.evaluate(()=>document.getAnimations().length),0);await page.emulateMedia({reducedMotion:'no-preference'});
   assert.deepEqual(errors,[]);
   cases.push({template:key,width,passed:true,font_loaded:true,icons_loaded:true,images_decoded:true,animations_advance:true,modal_cycle:true,demo_links_inert:true,selector_public_pixels_equal:true,long_bios_preserved:true,reduced_motion:true,identity_colors_shapes_preserved:true});
   console.log('VERIFIED local Chromium: '+key+' '+width);
  }
 }finally{await browser.close();}
 await writeFile(path.join(output,'results.json'),JSON.stringify({environment:'Local Chromium, fictional data, cached original dependencies; not native or protected Vercel',cases},null,2)+'\n');
 console.log('Verified '+cases.length+' local browser cases.');
}
