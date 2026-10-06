import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {localService,pagePayload,OWNER,OTHER,invoke,configFromHtml} from './fixtures/proxolink-v6-service.mjs';
import {PAGE_TYPES,PREPARED_DESIGNS,PROVIDER_REGISTRY,providerDestination} from '../api/_lib/proxolink-pages.js';
process.env.PROXO_SUPABASE_URL='https://v6-isolated.supabase.co';
process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY='isolated-fixture-key';
process.env.PROXO_PREVIEW_SIGNING_SECRET='isolated-preview-signing-secret-at-least-32';
process.env.PROXO_V6_WRITE_MODE='isolated';
const {default:handler}=await import('../api/proxolink.js');
const {makePreviewToken,makeFormToken,formTokenData}=await import('../api/_lib/proxolink-preview.js');
const original=global.fetch;
let fixture;
test.beforeEach(()=>{fixture=localService();global.fetch=fixture.fetcher;process.env.PROXO_V6_WRITE_MODE='isolated';});
test.afterEach(()=>{global.fetch=original;});
const call=(op,options)=>invoke(handler,op,options);
for(const [kind,sets] of Object.entries({contact:[['whatsapp','viber','instagram','telegram','korek','asiacell']],order:[['talabat'],['toters'],['talabat','toters']],download:[['google_play'],['app_store'],['google_play','app_store']]})){
 for(const providers of sets)test(`${kind} ${providers.join('+')}: create/database UUID/edit/stable typed URL/public/owner preview`,async()=>{
   const body=pagePayload(kind,providers),created=await call('cards',{method:'POST',body});
   assert.equal(created.status,201,created.body);
   const result=created.json().card,id=result.id;
   assert.notEqual(id,OWNER);assert.notEqual(id,body.client_request_id);
   assert.equal(result.public_path,`/${kind}/${id}`);
   assert.equal(fixture.writes[0].body.id,undefined);
   const same=await call('cards',{method:'POST',body});assert.equal(same.status,200);assert.equal(same.json().card.id,id);assert.equal(fixture.rows.length,1);
   const conflict=await call('cards',{method:'POST',body:{...body,name:'different'}});assert.equal(conflict.status,409);
   const read=await call(kind,{query:{id},auth:null});assert.equal(read.status,200);
   const config=configFromHtml(read.body);assert.equal(config.name,body.name);assert.equal(config.preview,false);
   assert.deepEqual(config.buttons.map(p=>p.type),providers);assert.doesNotMatch(read.body,new RegExp(OWNER));
   assert.equal(fixture.events.length,0);
   for(const route of PAGE_TYPES)if(route!==kind)assert.equal((await call(route,{query:{id},auth:null})).status,404);
   assert.equal((await call(kind,{query:{id:OWNER},auth:null})).status,404);
   const current=fixture.rows[0],updated=current.updated_at;
   assert.equal((await call('cards',{method:'PATCH',query:{id},auth:'other-token',body:{name:'takeover',expected_updated_at:updated}})).status,403);
   const edited=await call('cards',{method:'PATCH',query:{id},body:{name:'Edited '+kind,expected_updated_at:updated}});
   assert.equal(edited.status,200,edited.body);assert.equal(edited.json().card.id,id);assert.equal(edited.json().card.public_path,`/${kind}/${id}`);
   assert.equal(configFromHtml((await call(kind,{query:{id},auth:null})).body).name,'Edited '+kind);
   assert.equal((await call('cards',{method:'PATCH',query:{id},body:{page_kind:kind==='contact'?'order':'contact',expected_updated_at:current.updated_at}})).status,422);
   const preview=await call('preview-token',{method:'POST',body:{card_id:id}});assert.equal(preview.status,200);
   const uri=new URL(preview.json().preview_path,'https://isolated.test');assert.equal(uri.pathname,`/${kind}/${id}`);
   const signed=await call(kind,{query:{id,preview_token:uri.searchParams.get('preview_token')},auth:null});
   assert.equal(signed.status,200);assert.equal(configFromHtml(signed.body).preview,true);
   const deactivate=await call('card-action',{method:'POST',body:{card_id:id,action:'deactivate'}});assert.equal(deactivate.status,200);
   assert.equal((await call(kind,{query:{id},auth:null})).status,404);
   assert.equal((await call(kind,{query:{id,preview_token:uri.searchParams.get('preview_token')},auth:null})).status,200);
   assert.equal((await call('card-action',{method:'POST',body:{card_id:id,action:'activate'}})).status,200);
   assert.equal((await call('card-action',{method:'POST',body:{card_id:id,action:'delete'}})).status,200);
   assert.equal(fixture.rows.length,1);assert.ok(fixture.rows[0].archived_at);
   assert.equal((await call(kind,{query:{id},auth:null})).status,404);
   assert.equal((await call('cards')).json().cards.length,0);
   assert.equal(fixture.events.length,0);
 });
}
test('one owner has multiple independent pages of each kind and request keys are owner-scoped',async()=>{
 const ids=[];for(const kind of PAGE_TYPES)for(let i=0;i<2;i++){
   const key={contact:'telegram',order:'talabat',download:'app_store'}[kind];
   const created=await call('cards',{method:'POST',body:pagePayload(kind,[key])});assert.equal(created.status,201);ids.push(created.json().card.id);
 }assert.equal(new Set(ids).size,6);assert.equal((await call('cards')).json().cards.length,6);
});
test('auth/provider/type/owner spoofing/disabled-only settings fail before mutation',async()=>{
 const valid=pagePayload('contact',['telegram']);
 for(const op of ['cards','templates','providers','preview-token','form-preview-token'])assert.equal((await call(op,{auth:null,method:op.includes('token')?'POST':'GET'})).status,401);
 const invalid=[{...valid,user_id:OTHER},{...valid,id:randomUUID()},{...valid,owner_id:OTHER},{...valid,html_content:'<script>evil()</script>'},
   {...valid,client_request_id:OWNER},{...valid,page_kind:'food'},{...valid,template_key:'dark'},
   pagePayload('contact',['talabat']),pagePayload('order',['google_play']),pagePayload('download',['telegram']),
   {...valid,settings:{providers:valid.settings.providers.map(p=>({...p,enabled:false}))}},
   {...valid,settings:{providers:[...valid.settings.providers,...valid.settings.providers]}},
   {...valid,avatar_path:OTHER+'/'+valid.client_request_id+'/avatar.png'}];
 for(const body of invalid){const r=await call('cards',{method:'POST',body});assert.equal(r.status,422,r.body);}
 assert.equal(fixture.rows.length,0);
 process.env.PROXO_V6_WRITE_MODE='disabled';assert.equal((await call('cards',{method:'POST',body:valid})).status,503);assert.equal(fixture.rows.length,0);
});
test('malformed provider/store URLs rejected and canonical destinations revalidate',()=>{
 for(const [key,p]of Object.entries(PROVIDER_REGISTRY)){
   for(const value of ['javascript:alert(1)','file:///etc/passwd','data:text/html,evil','https://evil.example/path',
     `https://${p.hosts[0]||'talabat.com'}.evil.example/path`,'https://user:pass@talabat.com/path','https://talabat.com:444/path','https://talabat.com/\\evil','<a href="evil">'])
     assert.throws(()=>providerDestination(key,value),undefined,key+' '+value);
 }
 for(const raw of ['https://play.google.com/store/apps/details','https://play.google.com/store/apps/details?id=javascript:evil',
   'https://play.google.com/store/apps/details?id=com.app.valid&redirect=https://evil.example','https://play.google.com/store/search?id=com.app.valid'])
   assert.throws(()=>providerDestination('google_play',raw));
 for(const raw of ['https://apps.apple.com/app/not-an-id','https://apps.apple.com/app/id1/evil','https://apps.apple.com/app/id1#evil'])assert.throws(()=>providerDestination('app_store',raw));
 for(const kind of PAGE_TYPES)for(const p of pagePayload(kind,Object.keys(PROVIDER_REGISTRY).filter(k=>PROVIDER_REGISTRY[k].page_type===kind)).settings.providers){
   const url=providerDestination(p.provider_key,p.destination_url);assert.equal(providerDestination(p.provider_key,url),url);
 }
});
test('all four prepared designs support all three typed signed demos, no secrets/private metadata',async()=>{
 const catalog=(await call('templates')).json();assert.deepEqual(catalog.templates.map(t=>t.template_key),PREPARED_DESIGNS);
 assert.doesNotMatch(JSON.stringify(catalog),/storage_path|checksum_sha256|template.html|SERVICE_ROLE/);
 for(const kind of PAGE_TYPES)for(const key of PREPARED_DESIGNS){
   const token=(await call('templates',{query:{template_key:key,version:'6',page_type:kind,language:'en'}})).json().templates[0].preview_path.split('token=')[1];
   const page=await call('template-preview',{query:{token:decodeURIComponent(token),page_type:'wrong'},auth:null});assert.equal(page.status,200);
   const config=configFromHtml(page.body);assert.equal(config.template,key);assert.equal(config.preview,true);
   assert.ok(config.buttons.every(b=>PROVIDER_REGISTRY[b.type].page_type===kind));assert.equal(config.direction,'ltr');
   assert.equal((await call('template-preview',{query:{token:token+'x'},auth:null})).status,404);
 }assert.equal(fixture.events.length,0);
});
test('unsaved live form preview is encrypted/type-bound/inert, preserves draft values without writes',async()=>{
 for(const kind of PAGE_TYPES){
   const body=pagePayload(kind,[{contact:'telegram',order:'talabat',download:'app_store'}[kind]],{name:'</script><script>globalThis.injected=true</script>',bio:'بایۆ Long '+ 'X'.repeat(1900)});
   const generated=await call('form-preview-token',{method:'POST',body});assert.equal(generated.status,200,generated.body);
   const token=new URL(generated.json().preview_path,'https://local.test').searchParams.get('token');
   assert.equal(formTokenData(token).card.name,body.name);assert.ok(!Buffer.from(token,'base64url').toString().includes(OWNER));
   const rendered=await call('form-preview',{query:{token},auth:null});assert.equal(rendered.status,200);
   assert.equal(configFromHtml(rendered.body).name,body.name);assert.equal(configFromHtml(rendered.body).preview,true);
   assert.doesNotMatch(rendered.body,/<script>globalThis.injected|html_content|proxolink-templates\//);
   assert.equal((await call('form-preview',{query:{token:token.slice(0,-2)+'aa'},auth:null})).status,404);
 }
 assert.equal(fixture.writes.length,0);assert.equal(fixture.events.length,0);
});
test('preview capability expiration, tampering and route-type binding reject safely',async()=>{
 const card={id:randomUUID(),user_id:OWNER,page_kind:'contact'};
 const token=makePreviewToken(card),{validPreviewToken}=await import('../api/_lib/proxolink-preview.js');
 assert.equal(validPreviewToken(token,card),true);assert.equal(validPreviewToken(token,{...card,page_kind:'order'}),false);
 const time=Date.now;try{Date.now=()=>time()+301000;assert.equal(validPreviewToken(token,card),false);}finally{Date.now=time;}
 const form=makeFormToken({...card,page_kind:'download'});assert.ok(formTokenData(form));
 try{Date.now=()=>time()+301000;assert.equal(formTokenData(form),null);}finally{Date.now=time;}
});
test('typed advertisement links use the stable page URL without tokens, RPCs or events and verify ownership',async()=>{
 for(const kind of PAGE_TYPES){
  const result=await call('cards',{method:'POST',body:pagePayload(kind,[{contact:'telegram',order:'talabat',download:'app_store'}[kind]])});
  assert.equal(result.status,201);
  const id=result.json().card.id,ad_id=randomUUID();fixture.ads.push({id:ad_id,user_id:OWNER,card_id:id,status:'active'});
  const link=await call('ad-links',{method:'POST',body:{ad_id}});assert.equal(link.status,200,link.body);
  assert.equal(link.json().tracked,false);assert.equal(link.json().public_path,`/${kind}/${id}`);
  assert.equal(link.json().tracked_path,`/${kind}/${id}`);assert.doesNotMatch(link.body,/\/a\/|public_token/);
  assert.equal((await call('ad-links',{method:'POST',body:{ad_id},auth:'other-token'})).status,422);
  assert.equal((await call('card-action',{method:'POST',body:{card_id:id,action:'delete'}})).status,409);
 }
 assert.equal(fixture.events.length,0);
 // The fixture has no token-issuing RPC handler; any such call fails this test.
});
test('typed avatar routes cannot be changed by a page_type query or attribution token',async()=>{
 const sharp=(await import('sharp')).default;
 const image=await sharp({create:{width:20,height:20,channels:3,background:'#128c7e'}}).png().toBuffer();
 const delegate=fixture.fetcher;
 global.fetch=async(raw,options)=>new URL(raw).pathname.startsWith('/storage/')
   ?new Response(image,{headers:{'Content-Type':'image/png'}}):delegate(raw,options);
 for(const kind of PAGE_TYPES){
  const body=pagePayload(kind,[{contact:'telegram',order:'talabat',download:'app_store'}[kind]]);
  body.avatar_path=OWNER+'/'+body.client_request_id+'/avatar.png';
  const created=await call('cards',{method:'POST',body});assert.equal(created.status,201,created.body);
  const id=created.json().card.id;
  for(const route of PAGE_TYPES){
   const result=await call(route==='contact'?'avatar':route+'-avatar',{query:{id,page_type:kind,token:'fake-attribution-token'},auth:null});
   assert.equal(result.status,kind===route?200:404,kind+' on '+route);
  }
 }
 assert.equal(fixture.events.length,0);
});
test('V6 cannot create through the legacy UUID protocol or rewrite legacy customers outside isolated staging',async()=>{
 const id=randomUUID(),legacy={id,user_id:OWNER,name:'Existing customer',bio:'',platforms:{wa:'9647501234567'},
  template_key:'classic',template_version:1,status:'active',publish_status:'ready',updated_at:new Date().toISOString()};
 fixture.rows.push(legacy);
 assert.equal((await call('cards',{method:'POST',body:{client_request_id:randomUUID(),name:'V6',template_key:'pill-white',template_version:6,platforms:{tg:'proxo_iq'}}})).status,422);
 process.env.PROXO_V6_WRITE_MODE='disabled';
 const edit=await call('cards',{method:'PATCH',query:{id},body:{template_key:'pill-white',template_version:6,expected_updated_at:legacy.updated_at}});
 assert.equal(edit.status,503);assert.equal(edit.json().error,'isolated_staging_required');
 assert.equal(legacy.template_key,'classic');assert.equal(fixture.writes.length,0);
});
