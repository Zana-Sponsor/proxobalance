// Run on a disposable KVM-backed Android runner. Ordinary verification-account
// credentials stay in the CI environment; the app receives only short-lived
// preview capabilities through its private runtime file, never dart-define.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { STYLES, WIDTHS, validateRuntime, safeRequest, verifyReadOnlySecurity,
  validateNativeResults } from './proxolink-verification-security.mjs';
import {validateViewport, compareNativePixels, createPreviewReferenceBrowser} from './proxolink-pixel-comparison.mjs';

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
let referenceBrowser=null;
let currentPreviews={};
let stage='runtime_configuration';
let lastJsonResponseStatus=null;
const safeErrorCodes=new Set([
  'approved_preview_workflow_required','runtime_setting_required','publishable_key_required',
  'approved_origin_required','protection_header_scope','read_only_verification_required',
  'device_command_failed','verification_endpoint_unavailable','verification_sign_in_failed',
  'application_auth_boundary_failed','invalid_capability_boundary_failed',
  'internal_table_access_failed','verification_user_required','ordinary_account_rls_required',
  'private_template_access_failed','catalog_metadata_boundary_failed','eight_templates_required',
  'invalid_preview_capability','rendered_preview_security_failed','preview_source_boundary_failed',
  'native_evidence_incomplete','native_screenshot_failed','native_verification_timeout',
  'native_viewport_invalid','native_crop_outside_screen','reference_viewport_mismatch',
  'reference_capability_required','reference_preview_unavailable','reference_assets_or_viewport_failed',
]);
const safePreflightChecks=new Set([
  'bypass_without_app_auth','forged_app_auth','invalid_preview_capability',
  'invalid_ad_token','invalid_avatar_card','ordinary_account_other_cards_rls',
  ...['anonymous_','authenticated_'].flatMap(prefix=>['proxolink_templates',
    'pa_ad_contact_links','pa_contact_events','proxolink_publish_attempts'].map(table=>prefix+table)),
  ...styles.map(style=>'private_template_'+style),
]);
const safeTransportCodes=new Set(['ENOTFOUND','EAI_AGAIN','ETIMEDOUT','ECONNRESET',
  'ECONNREFUSED','CERT_HAS_EXPIRED','UNABLE_TO_VERIFY_LEAF_SIGNATURE']);
async function jsonRequest(url,{headers={},...options}={}) {
  const response=await safeRequest(url,{...options,headers});
  lastJsonResponseStatus=response.status;
  if(!response.ok)throw Error('verification_endpoint_unavailable');
  return response.json();
}
async function configure() {
  if(!authorization) {
    stage='verification_sign_in';
    const session=await jsonRequest(supabase+'/auth/v1/token?grant_type=password',{
      method:'POST',headers:{apikey:key,'Content-Type':'application/json'},
      body:JSON.stringify({email,password})
    });
    if(!session.access_token)throw Error('verification_sign_in_failed');
    authorization='Bearer '+session.access_token;
    userId=session.user?.id;
  }
  // HTTP checks authenticate each request directly and reject redirects. The
  // optional cookie header deliberately redirects and is only for WebView.
  const protection=bypass?{'x-vercel-protection-bypass':bypass}:{};
  if(!securityVerified) {
    stage='read_only_security';
    const checks=await verifyReadOnlySecurity({authorization,key,userId,protection});
    writeFileSync(output+'/security.json',JSON.stringify(checks,null,2));
    securityVerified=true;
    console.log('Read-only application-auth, RLS and private-template boundaries passed.');
  }
  stage='template_catalog';
  const catalog=await jsonRequest(base+'/api/contact-templates',{headers:{...protection,Authorization:authorization}});
  if(/storage_path|checksum_sha256|template\.html|html_content/.test(JSON.stringify(catalog)))
    throw Error('catalog_metadata_boundary_failed');
  const previews={};
  stage='template_capabilities';
  for(const style of styles) {
    const item=catalog.templates?.find(t=>t.template_key===style&&t.version===1);
    if(!item||typeof item.preview_path!=='string')throw Error('eight_templates_required');
    const url=new URL(item.preview_path,base);
    if(url.origin!==base||url.pathname!=='/contact-preview'||!url.searchParams.has('token'))
      throw Error('invalid_preview_capability');
    previews[style]=url.href;
  }
  if(!capturedPreviewHeaders) {
    stage='rendered_preview_headers';
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
  stage='write_private_configuration';
  appWrite('proxolink-verification.json',JSON.stringify({origin:base,previews,
    headers:{...protection,'x-vercel-set-bypass-cookie':'true'}}));
  currentPreviews=previews;
}
let capturedPreviewHeaders=false;

async function main() {
  validateRuntime(process.env);
  mkdirSync(output,{recursive:true});
  stage='native_install';
  adb(['install','-r','proxo_app/build/app/outputs/flutter-apk/app-debug.apk']);
  stage='prepare_device';
  adb(['shell','wm','size','1200x1900']);
  adb(['shell','wm','density','160']);
  adb(['shell','run-as',packageId,'mkdir','-p','files']);
  await configure();
  stage='reference_browser';
  referenceBrowser=await createPreviewReferenceBrowser({protection:{'x-vercel-protection-bypass':bypass}});
  stage='native_case_collection';
  adb(['shell','am','start','-n',packageId+'/.MainActivity']);
  let configuredAt=Date.now();
  const captured=new Set();
  const pixels={};
  const deadline=Date.now()+15*60*1000;
  while(Date.now()<deadline) {
    if(Date.now()-configuredAt>60000) {await configure();configuredAt=Date.now();stage='native_case_collection';}
    const result=appRead('proxolink-verification-results.json');
    if(result) {
      const data=JSON.parse(result);
      const safe=validateNativeResults(data,captured,pixels);
      writeFileSync(output+'/results.json',JSON.stringify(safe,null,2));
      console.log('8/8 real native WebView previews and exact browser pixel comparisons passed at all five widths (40/40 cases).');
      return;
    }
    const current=appRead('proxolink-verification-case.json');
    if(current) {
      const {style,width,viewport}=JSON.parse(current),id=style+'-'+width;
      if(styles.includes(style)&&WIDTHS.includes(width)&&!captured.has(id)) {
        const png=adb(['exec-out','screencap','-p']);
        if(!png?.length)throw Error('native_screenshot_failed');
        writeFileSync(output+'/'+id+'.png',png);
        const crop=validateViewport(viewport,width);
        const reference=await referenceBrowser.screenshot(currentPreviews[style],crop);
        const comparison=await compareNativePixels(png,reference,crop);
        writeFileSync(output+'/'+id+'-webview.png',comparison.native);
        writeFileSync(output+'/'+id+'-browser.png',reference);
        writeFileSync(output+'/'+id+'-diff.png',comparison.diff);
        pixels[id]=comparison.metrics;
        writeFileSync(output+'/pixels.json',JSON.stringify({environment:'Android 35 WebView versus Chromium '+referenceBrowser.version,
          animation_state:'fresh page; scroll zero; CSS animations paused at zero',cases:pixels},null,2));
        // Keep evidence for every requested case, including pixel differences.
        // The final validateNativeResults gate still rejects any changed pixel.
        if(!comparison.metrics.exact_pixels_equal)
          console.log('Native pixel difference recorded for '+id+'.');
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
catch(error) {
  // Never print fetch errors, URLs, runtime files, bearer values or credentials.
  const code=safeErrorCodes.has(error?.message)?error.message:'unclassified_failure';
  const check=safePreflightChecks.has(error?.verificationCheck)?error.verificationCheck:null;
  const transport=error?.cause?.message==='unexpected redirect'?'redirect_blocked':
    ['TimeoutError','AbortError'].includes(error?.name)?'request_timeout':
    safeTransportCodes.has(error?.cause?.code)?error.cause.code:'unclassified_transport';
  mkdirSync(output,{recursive:true});
  writeFileSync(output+'/failure.json',JSON.stringify({status:'FAILED',stage,code,
    preflight_check:check,transport_code:transport,
    last_json_response_status:lastJsonResponseStatus,credential_values_included:false},null,2));
  console.error('Native verification did not complete: '+stage+' / '+code+
    (check?' / '+check+' / '+transport:'')+'.');
  process.exitCode=1;
} finally {
  if(referenceBrowser)await referenceBrowser.close();
  adb(['shell','am','force-stop',packageId],null,true);
  for(const name of ['proxolink-verification.json','proxolink-verification-ack'])
    adb(['shell','run-as',packageId,'rm','-f','files/'+name],null,true);
  adb(['shell','wm','size','reset'],null,true);
  adb(['shell','wm','density','reset'],null,true);
}
