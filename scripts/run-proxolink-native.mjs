// Run on a disposable KVM-backed Android runner. Ordinary verification-account
// credentials stay in the CI environment; the app receives only short-lived
// preview capabilities through its private runtime file, never dart-define.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { STYLES, WIDTHS, validateRuntime, safeRequest, verifyReadOnlySecurity,
  validateNativeResults } from './proxolink-verification-security.mjs';

const styles=STYLES;
const packageId='com.proxo.proxoapp';
const output=resolve('proxo_app/build/native-verification');
const base=process.env.PROXO_NATIVE_BASE_URL;
const supabase=process.env.PROXO_NATIVE_SUPABASE_URL;
const key=process.env.PROXO_NATIVE_ANON_KEY;
const email=process.env.PROXO_NATIVE_TEST_EMAIL;
const password=process.env.PROXO_NATIVE_TEST_PASSWORD;
const bypass=process.env.PROXO_NATIVE_VERCEL_BYPASS;

function adb(args,input=null,optional=false) {
  const result=spawnSync('adb',args,{input,timeout:30000,maxBuffer:4*1024*1024});
  if(result.status!==0&&!optional)throw Error('device_command_failed');
  return result.status===0?result.stdout:null;
}
const appRead=name=>adb(['shell','run-as',packageId,'cat','files/'+name],null,true)?.toString().trim();
const appWrite=(name,value)=>adb(['shell','run-as',packageId,'tee','files/'+name],value);
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let authorization=null;
let userId=null;
let securityVerified=false;
async function jsonRequest(url,{headers={},...options}={}) {
  const response=await safeRequest(url,{...options,headers});
  if(!response.ok)throw Error('verification_endpoint_unavailable');
  return response.json();
}
async function configure() {
  if(!authorization) {
    const session=await jsonRequest(supabase+'/auth/v1/token?grant_type=password',{
      method:'POST',headers:{apikey:key,'Content-Type':'application/json'},
      body:JSON.stringify({email,password})
    });
    if(!session.access_token)throw Error('verification_sign_in_failed');
    authorization='Bearer '+session.access_token;
    userId=session.user?.id;
  }
  const protection=bypass?{'x-vercel-protection-bypass':bypass,'x-vercel-set-bypass-cookie':'true'}:{};
  if(!securityVerified) {
    const checks=await verifyReadOnlySecurity({authorization,key,userId,protection});
    writeFileSync(output+'/security.json',JSON.stringify(checks,null,2));
    securityVerified=true;
    console.log('Read-only application-auth, RLS and private-template boundaries passed.');
  }
  const catalog=await jsonRequest(base+'/api/contact-templates',{headers:{...protection,Authorization:authorization}});
  if(/storage_path|checksum_sha256|template\.html|html_content/.test(JSON.stringify(catalog)))
    throw Error('catalog_metadata_boundary_failed');
  const previews={};
  for(const style of styles) {
    const item=catalog.templates?.find(t=>t.template_key===style&&t.version===1);
    if(!item||typeof item.preview_path!=='string')throw Error('eight_templates_required');
    const url=new URL(item.preview_path,base);
    if(url.origin!==base||url.pathname!=='/contact-preview'||!url.searchParams.has('token'))
      throw Error('invalid_preview_capability');
    previews[style]=url.href;
  }
  if(!capturedPreviewHeaders) {
    for(const style of styles) {
      const response=await safeRequest(previews[style],{headers:protection});
      const csp=response.headers.get('content-security-policy')||'';
      if(response.status!==200||!response.headers.get('content-type')?.startsWith('text/html')
        ||response.headers.get('cache-control')!=='no-store'
        ||response.headers.get('x-content-type-options')!=='nosniff'
        ||response.headers.get('referrer-policy')!=='no-referrer'
        ||!csp.includes("default-src 'none'")||!csp.includes("object-src 'none'")
        ||!csp.includes("frame-ancestors 'none'")||csp.includes("'unsafe-eval'"))
        throw Error('rendered_preview_security_failed');
      const html=await response.text();
      if(/\{\{[A-Z_]+\}\}|storage_path|proxolink-templates\//.test(html)
        ||/ttq\.load\(/.test(html))throw Error('preview_source_boundary_failed');
    }
    capturedPreviewHeaders=true;
    console.log('8/8 live rendered-preview response security checks passed.');
  }
  // tee's stdout is captured and discarded. It is never printed or uploaded.
  appWrite('proxolink-verification.json',JSON.stringify({origin:base,previews,headers:protection}));
}
let capturedPreviewHeaders=false;

async function main() {
  validateRuntime(process.env);
  mkdirSync(output,{recursive:true});
  adb(['install','-r','proxo_app/build/app/outputs/flutter-apk/app-debug.apk']);
  adb(['shell','wm','size','1200x1900']);
  adb(['shell','wm','density','160']);
  adb(['shell','run-as',packageId,'mkdir','-p','files']);
  await configure();
  adb(['shell','am','start','-n',packageId+'/.MainActivity']);
  let configuredAt=Date.now();
  const captured=new Set();
  const deadline=Date.now()+15*60*1000;
  while(Date.now()<deadline) {
    if(Date.now()-configuredAt>60000) {await configure();configuredAt=Date.now();}
    const result=appRead('proxolink-verification-results.json');
    if(result) {
      const data=JSON.parse(result);
      const safe=validateNativeResults(data,captured);
      writeFileSync(output+'/results.json',JSON.stringify(safe,null,2));
      console.log('8/8 real native WebView previews passed at all four widths (32/32 cases).');
      return;
    }
    const current=appRead('proxolink-verification-case.json');
    if(current) {
      const {style,width}=JSON.parse(current),id=style+'-'+width;
      if(styles.includes(style)&&WIDTHS.includes(width)&&!captured.has(id)) {
        const png=adb(['exec-out','screencap','-p']);
        if(!png?.length)throw Error('native_screenshot_failed');
        writeFileSync(output+'/'+id+'.png',png);
        captured.add(id);
        appWrite('proxolink-verification-ack',id);
        console.log('Native evidence captured for '+id+'.');
      }
    }
    await pause(1000);
  }
  throw Error('native_verification_timeout');
}
try {await main();}
catch {
  // Never print fetch errors, URLs, runtime files, bearer values or credentials.
  console.error('Native verification did not complete. Review configuration and safe evidence artifacts.');
  process.exitCode=1;
} finally {
  adb(['shell','am','force-stop',packageId],null,true);
  for(const name of ['proxolink-verification.json','proxolink-verification-ack'])
    adb(['shell','run-as',packageId,'rm','-f','files/'+name],null,true);
  adb(['shell','wm','size','reset'],null,true);
  adb(['shell','wm','density','reset'],null,true);
}
