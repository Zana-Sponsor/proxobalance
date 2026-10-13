import test from 'node:test';
import assert from 'node:assert/strict';
import {PREVIEW_ORIGIN,SUPABASE_ORIGIN,STYLES,WIDTHS,NATIVE_CASE_IDS,validateRuntime,
  safeRequest,verifyReadOnlySecurity,validateNativeResults,createNativeVerificationSession} from '../scripts/proxolink-verification-security.mjs';
const environment={GITHUB_REPOSITORY:'Zana-Sponsor/proxobalance',
 GITHUB_REF:'refs/heads/feat/proxolink-private-renderer-migration',
 GITHUB_WORKFLOW_REF:'Zana-Sponsor/proxobalance/.github/workflows/proxolink-native-build.yml@refs/heads/feat/proxolink-private-renderer-migration',
 PROXO_NATIVE_BASE_URL:PREVIEW_ORIGIN,PROXO_NATIVE_SUPABASE_URL:SUPABASE_ORIGIN,
 PROXO_NATIVE_ANON_KEY:'sb_publishable_test',PROXO_NATIVE_TEST_EMAIL:'test@example.invalid',
 PROXO_NATIVE_TEST_PASSWORD:'test-only',PROXO_NATIVE_VERCEL_BYPASS:'test-only'};
test('runtime verification refuses production, other repositories/branches and service keys',()=>{
 validateRuntime(environment);
 for(const [key,value] of [['PROXO_NATIVE_BASE_URL','https://www.proxobalance.app'],
  ['GITHUB_REF','refs/heads/main'],['GITHUB_REPOSITORY','other/repo'],
  ['PROXO_NATIVE_ANON_KEY','sb_secret_test'],['PROXO_NATIVE_VERCEL_BYPASS','']])
   assert.throws(()=>validateRuntime({...environment,[key]:value}));
 const jwt='header.'+Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url')+'.test';
 assert.throws(()=>validateRuntime({...environment,PROXO_NATIVE_ANON_KEY:jwt}));
});
test('requests never send protection headers to Supabase, follow redirects or mutate card data',async()=>{
 const seen=[];const fetcher=async(url,options)=>{seen.push({url,options});return new Response(null,{status:401});};
 await safeRequest(PREVIEW_ORIGIN+'/api/contact-templates',{headers:{'x-vercel-protection-bypass':'test-only'}},fetcher);
 assert.equal(seen[0].options.redirect,'error');
 for(const [url,options] of [[SUPABASE_ORIGIN+'/rest/v1/proxolink_cards',{headers:{'x-vercel-protection-bypass':'test-only'}}],
  [PREVIEW_ORIGIN+'/api/contact-cards',{method:'POST'}],
  [PREVIEW_ORIGIN+'/api/contact-cards',{method:'DELETE'}],
  ['https://www.proxobalance.app/api/contact-templates',{}],
  [PREVIEW_ORIGIN+'/?x-vercel-protection-bypass=test-only',{}]])
  await assert.rejects(safeRequest(url,options,fetcher));
 assert.equal(seen.length,1);
});
test('live checks require app authentication independently of the Vercel bypass and retain only booleans',async()=>{
 const requests=[];
 const fetcher=async(url,options)=>{
  requests.push({url,headers:options.headers});const u=new URL(url);
  if(u.pathname==='/api/contact-templates')return new Response(null,{status:401});
  if(u.pathname==='/rest/v1/proxolink_cards')return Response.json([]);
  if(u.pathname.startsWith('/rest/'))return new Response(null,{status:403});
  if(u.pathname.startsWith('/storage/'))return new Response(null,{status:400});
  return new Response(null,{status:404});
 };
 const result=await verifyReadOnlySecurity({authorization:'Bearer test-only',key:'sb_publishable_test',
  userId:'11111111-1111-4111-8111-111111111111',protection:{'x-vercel-protection-bypass':'test-only'}},fetcher);
 assert.ok(Object.values(result).every(v=>v===true));
 assert.equal(requests.filter(r=>r.headers?.['x-vercel-protection-bypass']).length,5);
 await assert.rejects(verifyReadOnlySecurity({authorization:'Bearer test-only',key:'test',
  userId:'11111111-1111-4111-8111-111111111111',protection:{}},async()=>new Response(null,{status:200})));
});
test('native capability refresh keeps app authentication valid beyond a one-hour run',async()=>{
 let time=1000000,calls=0;const issued=new Map(),userId='11111111-1111-4111-8111-111111111111';
 const session=createNativeVerificationSession(async()=>{
  const token='test-only-'+(++calls);issued.set('Bearer '+token,time+3600000);
  return {access_token:token,expires_in:3600,expires_at:(time+3600000)/1000,user:{id:userId},refresh_token:'never-retained'};
 },()=>time);
 for(let minute=0;minute<=90;minute+=3){
  time=1000000+minute*60000;const active=await session();
  assert.ok(issued.get(active.authorization)>time+300000,'configuration must not use a token nearing expiry');
  assert.equal(active.userId,userId);
  assert.deepEqual(Object.keys(active).sort(),['authorization','userId']);
 }
 assert.equal(calls,2,'renew before the original token expires, without signing in at every capability refresh');
});
test('native session renewal honors an earlier absolute expiry and rejects an account change',async()=>{
 let time=1000000,calls=0;const userId='11111111-1111-4111-8111-111111111111';
 const session=createNativeVerificationSession(async()=>({access_token:'test-only-'+(++calls),expires_in:3600,
  expires_at:(1000000+600000)/1000,user:{id:calls===1?userId:'22222222-2222-4222-8222-222222222222'}}),()=>time);
 await session();time+=299000;await session();assert.equal(calls,1);
 time+=1000;await assert.rejects(session(),/verification_user_required/);
});
test('native session renewal fails closed on missing, expired or invalid sign-in metadata',async()=>{
 const user={id:'11111111-1111-4111-8111-111111111111'};
 for(const result of [{access_token:'test-only',user},
  {access_token:'test-only',user,expires_in:0},
  {access_token:'test-only',user,expires_in:3600,expires_at:500},
  {access_token:'test-only',user:{id:'invalid'},expires_in:3600},
  {access_token:'test-only',user:{id:'gggggggg-gggg-gggg-gggg-gggggggggggg'},expires_in:3600}])
   await assert.rejects(createNativeVerificationSession(async()=>result,()=>1000000)(),/verification_sign_in_failed/);
 let time=1000000,calls=0;
 const session=createNativeVerificationSession(async()=>{
  if(calls++)throw Error('verification_endpoint_unavailable');
  return {access_token:'test-only',user,expires_in:3600};
 },()=>time);
 await session();time+=3600000;
 await assert.rejects(session(),/verification_endpoint_unavailable/);
});
test('native evidence requires 240 captured cases plus exact same-device Android WebView pixel comparisons',()=>{
 const entries=NATIVE_CASE_IDS.map(id=>[id,{passed:true,width:Number(id.split('-').at(-1)),
  font_loaded:true,font_applied:true,images_loaded:true,icons_loaded:true,animation_count:1,animation_checked:true,provider_types:true,
  preview_inert:true,public_actions_checked:true,navigation_blocked:true,fresh_native_views:true,native_paint_barriers:true,private_token:'not-for-artifacts'}]);
 const data=Object.fromEntries(entries),captured=new Set(entries.map(([id])=>id));
 const pixels=Object.fromEntries(entries.map(([id,value])=>[id,{width:value.width,changed_pixels:0,exact_pixels_equal:true,capture_stable:true,capture_samples:3}]));
 assert.equal(entries.length,240);
 assert.doesNotMatch(JSON.stringify(validateNativeResults(data,captured,pixels)),/private_token|not-for-artifacts/);
 assert.throws(()=>validateNativeResults(data,captured));
 pixels[NATIVE_CASE_IDS[0]].changed_pixels=1;assert.throws(()=>validateNativeResults(data,captured,pixels),/native_pixel_parity_failed/);
 pixels[NATIVE_CASE_IDS[0]].changed_pixels=0;
 data[NATIVE_CASE_IDS[0]].fresh_native_views=false;assert.throws(()=>validateNativeResults(data,captured,pixels));
 delete data[NATIVE_CASE_IDS[0]].fresh_native_views;assert.throws(()=>validateNativeResults(data,captured,pixels));
 data[NATIVE_CASE_IDS[0]].fresh_native_views=true;
 data[NATIVE_CASE_IDS[0]].native_paint_barriers=false;assert.throws(()=>validateNativeResults(data,captured,pixels),/native_evidence_incomplete/);
 data[NATIVE_CASE_IDS[0]].native_paint_barriers=true;
 pixels[NATIVE_CASE_IDS[0]].capture_stable=false;assert.throws(()=>validateNativeResults(data,captured,pixels),/native_capture_unstable/);
 pixels[NATIVE_CASE_IDS[0]].capture_stable=true;
 pixels[NATIVE_CASE_IDS[0]].capture_samples=1;assert.throws(()=>validateNativeResults(data,captured,pixels),/native_capture_unstable/);
 pixels[NATIVE_CASE_IDS[0]].capture_samples=3;
 captured.delete(NATIVE_CASE_IDS[0]);assert.throws(()=>validateNativeResults(data,captured,pixels));
});
