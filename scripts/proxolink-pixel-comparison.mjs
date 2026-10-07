// Compare the actual Android WebView surface, excluding Flutter/system chrome.
// A nonzero pixel difference is evidence of a difference, never a parity pass.
import sharp from 'sharp';
import {PREVIEW_ORIGIN, safeRequest} from './proxolink-verification-security.mjs';

export function validateViewport(value, cssWidth) {
  const keys=['left','top','width','height','css_height'];
  if(!value || keys.some(key=>!Number.isInteger(value[key]) || value[key]<0)
    ||value.width!==cssWidth ||value.css_height!==value.height
    ||value.height<100 ||value.height>1800 ||value.left>1200 ||value.top>1900)
    throw Error('native_viewport_invalid');
  return Object.fromEntries(keys.map(key=>[key,value[key]]));
}

export async function compareNativePixels(screenshot, reference, viewport) {
  const metadata=await sharp(screenshot).metadata();
  if(viewport.left+viewport.width>metadata.width
    ||viewport.top+viewport.height>metadata.height)
    throw Error('native_crop_outside_screen');
  const crop={left:viewport.left,top:viewport.top,width:viewport.width,height:viewport.height};
  const native=await sharp(screenshot).extract(crop).removeAlpha().png().toBuffer();
  const a=await sharp(native).raw().toBuffer({resolveWithObject:true});
  const b=await sharp(reference).removeAlpha().raw().toBuffer({resolveWithObject:true});
  if(a.info.width!==b.info.width||a.info.height!==b.info.height||a.info.channels!==3||b.info.channels!==3)
    throw Error('reference_viewport_mismatch');
  let changed=0,totalError=0,maxError=0;
  const diff=Buffer.alloc(a.data.length);
  for(let i=0;i<a.data.length;i+=3) {
    let delta=0;
    for(let c=0;c<3;c++) {
      const error=Math.abs(a.data[i+c]-b.data[i+c]);
      delta+=error;totalError+=error;maxError=Math.max(maxError,error);
    }
    if(delta){changed++;diff[i]=255;diff[i+1]=0;diff[i+2]=80;}
    else {const grey=Math.round((a.data[i]+a.data[i+1]+a.data[i+2])/3)*.3;diff.fill(grey,i,i+3);}
  }
  const total=a.info.width*a.info.height;
  return {native,diff:await sharp(diff,{raw:{width:a.info.width,height:a.info.height,channels:3}}).png().toBuffer(),
    metrics:{width:a.info.width,height:a.info.height,changed_pixels:changed,total_pixels:total,
      changed_fraction:changed/total,mean_channel_error:totalError/(total*3),
      max_channel_error:maxError,exact_pixels_equal:changed===0}};
}

// Three predetermined captures of each role independently. Always compare the
// first frame; never search for a frame that matches the other role, average
// pixels, mask differences or retry a failing parity comparison.
export async function captureNativeFrames(readScreenshot, viewport, wait = ms =>
  new Promise(resolve => setTimeout(resolve, ms))) {
  const screenshots=[];
  for(let sample=0;sample<3;sample++) {
    if(sample)await wait(250);
    const png=await readScreenshot();
    if(!png?.length)throw Error('native_screenshot_failed');
    screenshots.push(png);
  }
  const crop={left:viewport.left,top:viewport.top,width:viewport.width,height:viewport.height};
  const reference=await sharp(screenshots[0]).extract(crop).removeAlpha().png().toBuffer();
  const repeated=[];
  for(const screenshot of screenshots.slice(1))repeated.push(await compareNativePixels(screenshot,reference,viewport));
  return {png:screenshots[0],repeated,
    repeatability:{samples:3,exact_pixels_equal:repeated.every(frame=>frame.metrics.exact_pixels_equal),
      changed_pixels:repeated.map(frame=>frame.metrics.changed_pixels)}};
}

// Both engines start at scroll zero with CSS animations held at time zero.
// Motion is tested separately before this deterministic screenshot is taken.
export const FREEZE_FRAME_SCRIPT=`window.scrollTo(0,0);document.getAnimations().forEach(a=>{a.pause();a.currentTime=0;});`;

export async function createPreviewReferenceBrowser({protection}) {
  const {chromium}=await import('playwright');
  const browser=await chromium.launch({args:['--no-sandbox','--disable-dev-shm-usage']});
  const context=await browser.newContext({deviceScaleFactor:1,colorScheme:'light'});
  let previewUrl=null;
  const assets=new Map();
  const external=new Set(['cdnjs.cloudflare.com','fonts.googleapis.com','fonts.gstatic.com','image2url.com']);
  await context.route('**/*',async route=>{
    try {
      const request=route.request(),url=new URL(request.url());
      if(request.method()!=='GET')return route.abort();
      let response;
      if(url.origin===PREVIEW_ORIGIN) {
        if(url.href!==previewUrl && !['/assets/fonts/Rabar_021.woff2','/assets/proxolink-demo-avatar.png'].includes(url.pathname))
          return route.abort();
        response=await safeRequest(url.href,{headers:protection});
      } else {
        if(url.protocol!=='https:'||url.username||url.password||!external.has(url.hostname))return route.abort();
        // Never forward bearer, bypass or cookie values to dependency hosts.
        if(!assets.has(url.href)) {
          const fetched=await fetch(url.href,{redirect:'error',signal:AbortSignal.timeout(30000)});
          if(!fetched.ok)throw Error('reference_dependency_unavailable');
          assets.set(url.href,{body:Buffer.from(await fetched.arrayBuffer()),
            contentType:fetched.headers.get('content-type')||'application/octet-stream'});
        }
        return route.fulfill(assets.get(url.href));
      }
      const headers=Object.fromEntries(response.headers);
      // Do not persist protection cookies, compressed-length or token-bearing
      // response headers in browser traces or artifacts (tracing is disabled).
      for(const name of ['set-cookie','content-encoding','content-length'])delete headers[name];
      await route.fulfill({status:response.status,headers,body:Buffer.from(await response.arrayBuffer())});
    }catch{await route.abort();}
  });
  const page=await context.newPage();
  return {
    version:browser.version(),
    async screenshot(url,viewport) {
      const parsed=new URL(url);
      if(parsed.origin!==PREVIEW_ORIGIN||parsed.pathname!=='/contact-preview'
        ||!parsed.searchParams.has('token'))throw Error('reference_capability_required');
      previewUrl=parsed.href;
      await page.setViewportSize({width:viewport.width,height:viewport.css_height});
      const response=await page.goto(previewUrl,{waitUntil:'load',timeout:45000});
      if(response?.status()!==200)throw Error('reference_preview_unavailable');
      await page.evaluate(()=>document.fonts.ready);
      await page.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
      const valid=await page.evaluate(()=>({width:innerWidth,height:innerHeight,
        font:[...document.fonts].some(f=>/Rabar|^R$/.test(f.family.replaceAll("'",''))&&f.status==='loaded'),
        icons:[...document.fonts].some(f=>/Awesome/.test(f.family)&&f.status==='loaded')}));
      if(valid.width!==viewport.width||valid.height!==viewport.css_height||!valid.font||!valid.icons)
        throw Error('reference_assets_or_viewport_failed');
      await page.evaluate(FREEZE_FRAME_SCRIPT);
      await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
      return page.screenshot({type:'png'});
    },
    async close(){await browser.close();}
  };
}
