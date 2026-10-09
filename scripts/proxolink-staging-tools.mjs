// Additive hosted acceptance for the CURRENT Tools/Create contract. Uses two
// ordinary accounts, no service key, no trusted transition endpoint/backdoor.
// Explicitly incomplete until trusted fixtures AND browser/device UI pass.
import assert from 'node:assert/strict';
import {randomUUID,createHash} from 'node:crypto';
import {stagingTransport} from './proxolink-staging-verification.mjs';
import {STYLES,PAGE_TYPES} from './proxolink-verification-security.mjs';
const fixtureName='Proxo Tools isolated fixture';
export async function verifyStagingTools(config,avatar,fetcher=fetch,{uuid=randomUUID}={}){
 const request=stagingTransport(config,fetcher);
 const json=async(path,options={})=>{const r=await request(path,options);return {status:r.status,body:await r.json()};};
 const post=data=>({method:'POST',contentType:'application/json',body:JSON.stringify(data)});
 const sign=async(email,password)=>{
  const r=await json('/auth/v1/token?grant_type=password',{supabase:true,...post({email,password})});
  assert.equal(r.status,200,'tools_staging_sign_in');assert.ok(r.body.access_token&&r.body.user?.id,'tools_staging_ordinary_session');
  return {authorization:'Bearer '+r.body.access_token,id:r.body.user.id};
 };
 const owner=await sign(config.email,config.password),other=await sign(config.otherEmail,config.otherPassword);
 assert.notEqual(owner.id,other.id,'tools_staging_distinct_accounts');
 const api=(path,options={},account=owner)=>json(path,{authorization:account.authorization,...options});
 assert.equal((await json('/api/contact-cards')).status,401,'tools_staging_anonymous_api');
 const catalog=await api('/api/page-providers');assert.equal(catalog.status,200);
 const providers=catalog.body.providers;
 for(const [label,key] of [['تەلەبات','talabat'],['وادێ','wade'],['تۆتەرز','toters'],['لەزوو','lezzoo']])
  assert.ok(providers.some(p=>p.provider_key===key&&p.label===label&&p.page_type==='order'),'tools_staging_restaurant_contract');
 const destinations={contact:[['telegram','https://t.me/proxo_staging_fixture']],order:[
  ['talabat','https://iraq.talabat.com/iraq/restaurant/proxo-staging'],['wade','https://wadedelivery.com/proxo-staging'],
  ['toters','https://totersapp.com/proxo-staging'],['lezzoo','https://lezzoo.com/proxo-staging']],
  download:[['google_play','https://play.google.com/store/apps/details?id=com.proxo.staging']]};
 const payload=(type,style,requestId,path)=>({client_request_id:requestId,page_kind:type,name:fixtureName+' '+type+' '+style,
  template_key:style,template_version:6,avatar_path:path,settings:{providers:destinations[type].map(([provider_key,destination_url],sort_order)=>
   ({provider_key,destination_url,enabled:true,sort_order}))}});
 const cases=[],retained=[];
 for(const type of PAGE_TYPES)for(const style of STYLES){
  const requestId=uuid(),path=owner.id+'/'+requestId+'/avatar.png',data=payload(type,style,requestId,path);
  const upload=await request('/storage/v1/object/proxolink-assets/'+path,{supabase:true,authorization:owner.authorization,
   method:'POST',contentType:'image/png',body:avatar});assert.ok(upload.ok,'tools_staging_owner_upload');
  const created=await api('/api/contact-cards',post(data));assert.equal(created.status,201,'tools_staging_create');
  const id=created.body.card?.id;assert.ok(id&&id!==owner.id&&id!==requestId,'tools_staging_generated_page_uuid');
  assert.equal(created.body.card.moderation_status,'pending','tools_staging_stored_pending');
  const duplicate=await api('/api/contact-cards',post(data));assert.equal(duplicate.status,200);assert.equal(duplicate.body.card.id,id);assert.equal(duplicate.body.reused,true);
  for(const moderation_status of ['approved','rejected']){
   const forged=await api('/api/contact-cards',post({...data,client_request_id:uuid(),moderation_status}));assert.equal(forged.status,422);
   const direct=await json('/rest/v1/proxolink_cards?id=eq.'+id,{supabase:true,authorization:owner.authorization,
    method:'PATCH',contentType:'application/json',body:JSON.stringify({moderation_status})});
   assert.ok([400,401,403].includes(direct.status),'tools_staging_direct_moderation_denied');
  }
  const refresh=await api('/api/contact-cards');assert.equal(refresh.status,200);
  assert.equal(refresh.body.cards.filter(p=>p.id===id).length,1);assert.equal(refresh.body.cards.find(p=>p.id===id).moderation_status,'pending');
  const externalPath='/'+type+'/'+id,publicPage=await request(externalPath);assert.equal(publicPage.status,200,'tools_staging_real_created_public_page');
  const html=await publicPage.text();assert.ok(html.includes(fixtureName),'tools_staging_public_fixture_content');
  assert.doesNotMatch(html,/\{\{[A-Z_]+\}\}|proxolink-templates\/|api\.telegram\.org|service_role/);
  const image=await request(externalPath+'/avatar');assert.equal(image.status,200);
  assert.equal(createHash('sha256').update(Buffer.from(await image.arrayBuffer())).digest('hex'),createHash('sha256').update(avatar).digest('hex'));
  assert.equal((await api('/api/contact-cards?id='+id,{},other)).status,404,'tools_staging_other_account_api');
  const denied=await json('/rest/v1/proxolink_cards?id=eq.'+id+'&select=id',{supabase:true,authorization:other.authorization});
  assert.equal(denied.status,200);assert.deepEqual(denied.body,[],'tools_staging_other_account_rls');
  const otherList=await api('/api/contact-cards',{},other);assert.equal(otherList.status,200);assert.ok(!otherList.body.cards.some(p=>p.id===id));
  const wrongUpload=await request('/storage/v1/object/proxolink-assets/'+owner.id+'/'+uuid()+'/avatar.png',{supabase:true,
   authorization:other.authorization,method:'POST',contentType:'image/png',body:avatar});assert.ok([400,401,403].includes(wrongUpload.status));
  const otherDelete=await api('/api/contact-card-action',post({card_id:id,action:'delete'}),other);assert.equal(otherDelete.status,404);
  const switched=await api('/api/contact-cards?id='+id);assert.equal(switched.status,200);assert.equal(switched.body.card.id,id);
  if(retained.length<3)retained.push({fixture_id:id,type,style,expected_action:['approved','rejected','ad_dependency'][retained.length],
   public_path:externalPath});
  else {
   const deleted=await api('/api/contact-card-action',post({card_id:id,action:'delete',expected_updated_at:switched.body.card.updated_at}));
   assert.equal(deleted.status,200,'tools_staging_actual_delete');assert.equal(deleted.body.deleted,id);
   assert.equal((await api('/api/contact-cards?id='+id)).status,404);assert.equal((await request(externalPath)).status,404);
  }
  cases.push({type,style,fixture_id:id,authenticated_create:true,stored_pending:true,ordinary_moderation_denied:true,
   authenticated_upload:true,duplicate_reused:true,refresh_authoritative:true,real_created_public_content:true,public_avatar_bytes:true,
   ownership_rls:true,foreign_upload_denied:true,foreign_delete_denied:true,account_auth_switch:true,actual_delete:retained.every(p=>p.fixture_id!==id)});
 }
 // A positive row for account B proves two actual ordinary-owner collections.
 const otherCreated=await api('/api/contact-cards',post(payload('contact','pill',uuid(),undefined)),other);
 assert.equal(otherCreated.status,201);assert.equal(otherCreated.body.card.moderation_status,'pending');
 assert.equal((await api('/api/contact-cards?id='+otherCreated.body.card.id)).status,404);
 return {status:'Pending',environment:'Isolated real HTTP Tools API; two ordinary accounts; fictional content',cases,retained_fixtures:retained,
  current_contract_verified:true,hosted_browser_or_native_ui_verified:false,trusted_transitions_verified:false,ad_dependency_verified:false,
  pending:['trusted pending to approved/rejected fixtures and persisted refresh','actual advertisement FK dependency fixture and delete denial',
   'authenticated app create/upload/refresh/delete and account switching UI','three real external-browser cycles using one retained created page']};
}
export async function verifyStagingToolsTransitions(config,manifest,fetcher=fetch){
 // Only fixture IDs produced by the ordinary authenticated phase above. This
 // phase observes trusted setup; it NEVER applies a migration/transition/ad.
 assert.equal(manifest?.environment,'Isolated real HTTP Tools API; two ordinary accounts; fictional content');
 assert.equal(manifest.retained_fixtures?.length,3);
 const request=stagingTransport(config,fetcher),signed=await request('/auth/v1/token?grant_type=password',{supabase:true,method:'POST',contentType:'application/json',
  body:JSON.stringify({email:config.email,password:config.password})});assert.equal(signed.status,200);
 const session=await signed.json(),authorization='Bearer '+session.access_token,out=[];
 for(const fixture of manifest.retained_fixtures){
  assert.ok(/^[0-9a-f-]{36}$/.test(fixture.fixture_id));assert.ok(['approved','rejected','ad_dependency'].includes(fixture.expected_action));
  const response=await request('/api/contact-cards?id='+fixture.fixture_id,{authorization});assert.equal(response.status,200);
  const card=(await response.json()).card;assert.ok(card.name.startsWith(fixtureName),'tools_staging_retained_fixture_scope');
  if(fixture.expected_action==='ad_dependency'){
   const rejected=await request('/api/contact-card-action',{authorization,method:'POST',contentType:'application/json',body:JSON.stringify({card_id:card.id,action:'delete'})});
   assert.equal(rejected.status,409);assert.equal((await rejected.json()).error,'ad_dependency');
   assert.equal((await request('/api/contact-cards?id='+card.id,{authorization})).status,200);
  }else assert.equal(card.moderation_status,fixture.expected_action);
  out.push({fixture_id:fixture.fixture_id,expected_action:fixture.expected_action,persisted_refresh_verified:true});
 }
 return {trusted_transitions_verified:true,ad_dependency_verified:true,cases:out,setup_mutations_performed:false,
  hosted_browser_or_native_ui_verified:false};
}
