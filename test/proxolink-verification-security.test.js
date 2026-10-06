import test from 'node:test';
import assert from 'node:assert/strict';
import {PREVIEW_ORIGIN,SUPABASE_ORIGIN,STYLES,WIDTHS,NATIVE_CASE_IDS,validateRuntime,
  safeRequest,verifyReadOnlySecurity,validateNativeResults} from '../scripts/proxolink-verification-security.mjs';
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
test('native evidence requires 240 captured cases plus exact same-device Android WebView pixel comparisons',()=>{
 const entries=NATIVE_CASE_IDS.map(id=>[id,{passed:true,width:Number(id.split('-').at(-1)),
  font_loaded:true,font_applied:true,images_loaded:true,icons_loaded:true,animation_count:1,animation_checked:true,provider_types:true,
  preview_inert:true,public_actions_checked:true,navigation_blocked:true,private_token:'not-for-artifacts'}]);
 const data=Object.fromEntries(entries),captured=new Set(entries.map(([id])=>id));
 const pixels=Object.fromEntries(entries.map(([id,value])=>[id,{width:value.width,changed_pixels:0,exact_pixels_equal:true}]));
 assert.equal(entries.length,240);
 assert.doesNotMatch(JSON.stringify(validateNativeResults(data,captured,pixels)),/private_token|not-for-artifacts/);
 assert.throws(()=>validateNativeResults(data,captured));
 pixels[NATIVE_CASE_IDS[0]].changed_pixels=1;assert.throws(()=>validateNativeResults(data,captured,pixels));
 pixels[NATIVE_CASE_IDS[0]].changed_pixels=0;
 captured.delete(NATIVE_CASE_IDS[0]);assert.throws(()=>validateNativeResults(data,captured,pixels));
});
