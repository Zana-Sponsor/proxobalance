// Run on a disposable KVM-backed Android runner. Ordinary verification-account
// credentials stay in the CI environment; the app receives only short-lived
// preview capabilities through its private runtime file, never dart-define.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const styles=['dark','light','classic','pill','card','neon','zoom','banner'];
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
async function jsonRequest(url,{headers={},...options}={}) {
  const response=await fetch(url,{...options,headers,redirect:'error',signal:AbortSignal.timeout(30000)});
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
  }
  const protection=bypass?{'x-vercel-protection-bypass':bypass,'x-vercel-set-bypass-cookie':'true'}:{};
  const catalog=await jsonRequest(base+'/api/contact-templates',{headers:{...protection,Authorization:authorization}});
  const previews={};
  for(const style of styles) {
    const item=catalog.templates?.find(t=>t.template_key===style&&t.version===1);
    if(!item||typeof item.preview_path!=='string')throw Error('eight_templates_required');
    const url=new URL(item.preview_path,base);
    if(url.origin!==base||url.pathname!=='/contact-preview'||!url.searchParams.has('token'))
      throw Error('invalid_preview_capability');
    previews[style]=url.href;
  }
  // tee's stdout is captured and discarded. It is never printed or uploaded.
  appWrite('proxolink-verification.json',JSON.stringify({origin:base,previews,headers:protection}));
}

async function main() {
  if(![base,supabase,key,email,password].every(v=>typeof v==='string'&&v.length))
    throw Error('native_verification_configuration_required');
  if(new URL(base).origin!==base||new URL(base).protocol!=='https:'
    ||new URL(supabase).origin!==supabase||new URL(supabase).protocol!=='https:')
    throw Error('https_origins_required');
  mkdirSync(output,{recursive:true});
  adb(['install','-r','proxo_app/build/app/outputs/flutter-apk/app-debug.apk']);
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
      writeFileSync(output+'/results.json',JSON.stringify(data,null,2));
      if(!styles.every(style=>data[style]?.passed===true))throw Error('native_webview_case_failed');
      console.log('8/8 real native WebView previews passed.');
      return;
    }
    const current=appRead('proxolink-verification-case.json');
    if(current) {
      const {style}=JSON.parse(current);
      if(styles.includes(style)&&!captured.has(style)) {
        const png=adb(['exec-out','screencap','-p']);
        if(!png?.length)throw Error('native_screenshot_failed');
        writeFileSync(output+'/'+style+'.png',png);
        captured.add(style);
        appWrite('proxolink-verification-ack',style);
        console.log('Native evidence captured for '+style+'.');
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
}
