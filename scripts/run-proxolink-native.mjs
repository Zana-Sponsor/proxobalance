// Run on a disposable KVM-backed Android runner. Ordinary verification-account
// credentials stay in the CI environment; the app receives only short-lived
// preview capabilities through its private runtime file, never dart-define.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import sharp from 'sharp';
import { STYLES, WIDTHS, PAGE_TYPES, LANGUAGES, NATIVE_CASE_IDS, validateRuntime, safeRequest, verifyReadOnlySecurity,
  validateNativeResults, createNativeVerificationSession } from './proxolink-verification-security.mjs';
import {validateViewport, compareNativePixels, captureNativeFrames, createPreviewReferenceBrowser} from './proxolink-pixel-comparison.mjs';

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
  'private_template_access_failed','catalog_metadata_boundary_failed','four_templates_required',
  'invalid_preview_capability','rendered_preview_security_failed','preview_source_boundary_failed',
  'native_evidence_incomplete','native_screenshot_failed','native_verification_timeout',
  'native_capture_unstable','native_pixel_parity_failed',
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
const safeNativeChecks=new Set(['rendered_page_checks','animation_motion',
  'contact_confirmation','contact_cancel','contact_confirm','inert_tiktok',
  'preview_url','navigation_boundary','fresh_frame','pixel_density','preview_actions','public_actions','whatsapp_hint',
  'screenshot_ack','capture_visibility','fresh_native_view','native_paint_barrier','public_navigation','unclassified_native_check']);
const safeDiagnosticBooleans=new Set(['valid','public_url_unchanged','legacy_viber_url_parser',
  ...['whatsapp','viber','instagram','telegram','korek','asiacell','talabat','toters','lezzoo','wade','google_play','app_store'].map(p=>p+'_destination_match')]);
function safeCaseResults(data){
 return Object.fromEntries(NATIVE_CASE_IDS.filter(id=>data[id]).map(id=>[id,
  Object.fromEntries(Object.entries(data[id]).filter(([name,value])=>
   name==='failed_check'?safeNativeChecks.has(value):
   ['width','animation_count','expected_count','observed_count'].includes(name)?Number.isInteger(value):
   (['passed','font_loaded','font_applied','images_loaded','icons_loaded','animation_checked','provider_types','preview_inert','public_actions_checked','navigation_blocked','fresh_native_views','native_paint_barriers'].includes(name)||safeDiagnosticBooleans.has(name))&&typeof value==='boolean'))]));
}
async function jsonRequest(url,{headers={},...options}={}) {
  const response=await safeRequest(url,{...options,headers});
  lastJsonResponseStatus=response.status;
  if(!response.ok)throw Error('verification_endpoint_unavailable');
  return response.json();
}
const nativeSession=createNativeVerificationSession(async()=>{
  stage='verification_sign_in';
  return jsonRequest(supabase+'/auth/v1/token?grant_type=password',{
    method:'POST',headers:{apikey:key,'Content-Type':'application/json'},
    body:JSON.stringify({email,password})
  });
});
async function configure() {
  ({authorization,userId}=await nativeSession());
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
  const selections=[];
  stage='template_capabilities';
  for(const style of styles) {
    const item=catalog.templates?.find(t=>t.template_key===style&&t.version===6);
    if(!item||typeof item.preview_path!=='string')throw Error('four_templates_required');
    for(const type of PAGE_TYPES)for(const language of LANGUAGES)for(const baseline of [false,true])
      selections.push({style,type,language,baseline});
  }
  // These are independent authenticated reads. Bound concurrency to four;
  // repeated sequential acquisition was consuming the collection deadline.
  for(let offset=0;offset<selections.length;offset+=4){
    await Promise.all(selections.slice(offset,offset+4).map(async({style,type,language,baseline})=>{
      const selected=await jsonRequest(base+'/api/contact-templates?template_key='+style+'&version=6&page_type='+type+'&language='+language+'&baseline='+baseline,
        {headers:{...protection,Authorization:authorization}});
      const url=new URL(selected.templates[0].preview_path,base);
      if(url.origin!==base||url.pathname!=='/contact-preview'||!url.searchParams.has('token'))throw Error('invalid_preview_capability');
      previews[style+'-'+type+'-'+language+(baseline?'-baseline':'')]=url.href;
    }));
  }
  if(!capturedPreviewHeaders) {
    stage='rendered_preview_headers';
    for(const style of styles) {
      const response=await safeRequest(previews[style+'-contact-ku'],{headers:protection});
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
    console.log('4/4 live rendered-preview response security checks passed.');
  }
  // tee's stdout is captured and discarded. It is never printed or uploaded.
  stage='write_private_configuration';
  appWrite('proxolink-verification.next.json',JSON.stringify({origin:base,previews,
    headers:{...protection,'x-vercel-set-bypass-cookie':'true'}}));
  adb(['shell','run-as',packageId,'mv','files/proxolink-verification.next.json','files/proxolink-verification.json']);
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
  // Exact parity uses the same Android emulator/WebView version for both roles.
  const captures=new Map();
  stage='native_case_collection';
  adb(['shell','am','start','-n',packageId+'/.ProxoLinkNativeProbeActivity']);
  let configuredAt=Date.now();
  const captured=new Set();
  const pixels={};
  const repeatability={};
  const reportedFailures=new Set();
  const deadline=Date.now()+90*60*1000;
  while(Date.now()<deadline) {
    // Five-minute capabilities are refreshed after three minutes, leaving
    // headroom for the bounded acquisition and the current WebView case.
    if(Date.now()-configuredAt>180000) {await configure();configuredAt=Date.now();stage='native_case_collection';}
    const progress=appRead('proxolink-verification-progress.json');
    if(progress){
      const observed=safeCaseResults(JSON.parse(progress));
      writeFileSync(output+'/case-results.json',JSON.stringify(observed,null,2));
      for(const [id,item] of Object.entries(observed))if(item.passed===false&&!reportedFailures.has(id)){
        reportedFailures.add(id);
        console.log('Native case failed for '+id+': '+JSON.stringify(item));
      }
    }
    const result=appRead('proxolink-verification-results.json');
    if(result) {
      const data=JSON.parse(result);
      // Retain safe executed-case details even when the strict final gate
      // rejects a failed page or pixel difference. Never upload the raw map.
      const observed=safeCaseResults(data);
      writeFileSync(output+'/case-results.json',JSON.stringify(observed,null,2));
      const safe=validateNativeResults(data,captured,pixels);
      writeFileSync(output+'/results.json',JSON.stringify(safe,null,2));
      console.log('All 240 live native cases and exact same-device Android WebView baseline/candidate comparisons passed.');
      return;
    }
    const current=appRead('proxolink-verification-case.json');
    if(current) {
      const {id,capture_id,style,type,language,width,variant,viewport}=JSON.parse(current);
      if(NATIVE_CASE_IDS.includes(id)&&capture_id===id+'-'+variant&&['candidate','baseline'].includes(variant)&&!captures.has(capture_id)) {
        const crop=validateViewport(viewport,width);
        const frame=await captureNativeFrames(()=>adb(['exec-out','screencap','-p']),crop);
        writeFileSync(output+'/'+capture_id+'.png',frame.png);
        frame.repeated.forEach((sample,index)=>writeFileSync(output+'/'+capture_id+'-repeat-'+(index+2)+'-webview.png',sample.native));
        repeatability[capture_id]=frame.repeatability;
        writeFileSync(output+'/capture-repeatability.json',JSON.stringify(repeatability,null,2));
        if(!frame.repeatability.exact_pixels_equal)console.log('Native capture instability recorded for '+capture_id+'.');
        captures.set(capture_id,{png:frame.png,crop,repeatability:frame.repeatability});
        if(captures.has(id+'-candidate')&&captures.has(id+'-baseline')) {
          const candidate=captures.get(id+'-candidate'),baseline=captures.get(id+'-baseline');
          if(JSON.stringify(candidate.crop)!==JSON.stringify(baseline.crop))throw Error('reference_viewport_mismatch');
          const reference=await sharp(baseline.png).extract({left:baseline.crop.left,top:baseline.crop.top,width:baseline.crop.width,height:baseline.crop.height}).removeAlpha().png().toBuffer();
          const comparison=await compareNativePixels(candidate.png,reference,candidate.crop);
          writeFileSync(output+'/'+id+'-webview.png',comparison.native);
          writeFileSync(output+'/'+id+'-baseline-webview.png',reference);
          writeFileSync(output+'/'+id+'-diff.png',comparison.diff);
          pixels[id]={...comparison.metrics,capture_samples:3,
            capture_stable:candidate.repeatability.exact_pixels_equal&&baseline.repeatability.exact_pixels_equal};captured.add(id);
          writeFileSync(output+'/pixels.json',JSON.stringify({environment:'Same Android 35 emulator / WebView / DPR 1 baseline versus candidate',
            animation_state:'Behavior view retired; fresh production WebViews with identical load/reload/settle history; finite entrances completed; infinite animations paused at zero; hint/toast hidden; Android visual-state callback and native draw acknowledged; three fixed captures per role must be identical; first frames compared; original CSS/assets unchanged',cases:pixels},null,2));
          if(!comparison.metrics.exact_pixels_equal)console.log('Native pixel difference recorded for '+id+'.');
        }
        appWrite('proxolink-verification-ack',capture_id);
        console.log('Native evidence captured for '+capture_id+'.');
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
