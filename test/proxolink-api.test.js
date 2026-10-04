import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
process.env.PROXO_SUPABASE_URL='https://proxo-test.supabase.co';
process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY='server-test-key';
process.env.PROXO_PREVIEW_SIGNING_SECRET='test-preview-key-at-least-32-characters';
const {default:handler}=await import('../api/proxolink.js');
const {makePreviewToken,makeTemplateToken}=await import('../api/_lib/proxolink-preview.js');
const {renderTemplate,normalizedPlatforms}=await import('../api/_lib/proxolink.js');
const owner='11111111-1111-4111-8111-111111111111';
const id='22222222-2222-4222-8222-222222222222';
const adA='33333333-3333-4333-8333-333333333333',adB='44444444-4444-4444-8444-444444444444';
const linkA='55555555-5555-4555-8555-555555555555',linkB='66666666-6666-4666-8666-666666666666';
const tokenA='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',tokenB='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const card={id,user_id:owner,name:'Proxo',bio:'Hello',tt:'proxo_iq',template_key:'classic',template_version:1,
 color_theme:'purple',platforms:{wa:'9647501234567',vb:'9647501234567',tg:'proxo_iq'},status:'active',publish_status:'ready',updated_at:'2026-10-03T00:00:00Z'};
const template='<!DOCTYPE html><html dir="rtl" lang="ku"><head></head><body><h1>{{NAME}}</h1><p>{{BIO}}</p>{{BUTTONS}}{{TT_BADGE}}<script>{{HANDLERS}}</script></body></html>';
const metadata={template_key:'classic',version:1,display_name_ckb:'کلاسیک',storage_path:'classic/v1/template.html',
 checksum_sha256:createHash('sha256').update(template).digest('hex'),requires_avatar:false,is_active:true};
function response() {return {statusCode:0,headers:{},setHeader(k,v){this.headers[k.toLowerCase()]=v;},end(v=''){this.body=v;}};}
function mockFetch({currentCard=card,events=[],writes=[],links=true,failTemplate=false}={}) {
 return async(url,options={})=>{
  const u=new URL(url);
  if(u.pathname==='/auth/v1/user')return Response.json({id:owner});
  if(u.pathname.includes('/storage/'))return new Response(failTemplate?'bad':template);
  if(u.pathname==='/rest/v1/pa_contact_events') {events.push(JSON.parse(options.body));return new Response(null,{status:204});}
  if(u.pathname==='/rest/v1/proxolink_cards') {
   if(options.method==='PATCH'){writes.push(JSON.parse(options.body));return Response.json([{...currentCard,...JSON.parse(options.body)}]);}
   return Response.json([currentCard]);
  }
  if(u.pathname==='/rest/v1/proxolink_templates')return Response.json([metadata]);
  if(u.pathname==='/rest/v1/pa_ad_contact_links') {
   const tok=u.searchParams.get('public_token')?.slice(3);
   if(!links||![tokenA,tokenB].includes(tok))return Response.json([]);
   return Response.json([{id:tok===tokenA?linkA:linkB,ad_id:tok===tokenA?adA:adB,card_id:id,owner_user_id:owner}]);
  }
  if(u.pathname==='/rest/v1/pa_ads')return Response.json([{id:u.searchParams.get('id')?.slice(3),user_id:owner,asset_id:id,status:'active'}]);
  throw Error('Unexpected mock path '+u.pathname);
 };
}
async function invoke(query,{body={},method='GET',auth=true,cookie=''}={}) {
 const res=response();await handler({method,query,body,url:'/a/test',headers:{
  ...(auth?{authorization:'Bearer user-token'}:{}),cookie,'user-agent':'Mozilla/5.0 Android Chrome/100'},socket:{remoteAddress:'127.0.0.1'}},res);return res;
}
const originalFetch=global.fetch;
test.afterEach(()=>{global.fetch=originalFetch;});
test('catalog returns live signed previews without raw storage metadata',async()=>{
 global.fetch=mockFetch();const res=await invoke({op:'templates'});
 assert.equal(res.statusCode,200);const body=JSON.parse(res.body);
 assert.match(body.templates[0].preview_path,/^\/contact-preview\?token=/);
 assert.doesNotMatch(res.body,/storage_path|checksum_sha256|template.html/);
});
test('template preview renders the selected real template and records no events',async()=>{
 const events=[];global.fetch=mockFetch({events});
 const res=await invoke({op:'template-preview',token:makeTemplateToken(owner,'classic',1)},{auth:false});
 assert.equal(res.statusCode,200);assert.match(res.body,/<h1>Proxo<\/h1>/);assert.equal(events.length,0);
 const invalid=await invoke({op:'template-preview',token:'tampered'},{auth:false});assert.equal(invalid.statusCode,404);
});
test('inactive public card is hidden; owner signed preview remains available without analytics',async()=>{
 const inactive={...card,status:'inactive'},events=[];global.fetch=mockFetch({currentCard:inactive,events});
 assert.equal((await invoke({op:'contact',id},{auth:false})).statusCode,404);
 const preview=await invoke({op:'contact',id,preview_token:makePreviewToken(inactive)},{auth:false});
 assert.equal(preview.statusCode,200);assert.equal(events.length,0);
 const changed=await invoke({op:'contact',id,preview_token:makePreviewToken({...inactive,id:adA})},{auth:false});
 assert.equal(changed.statusCode,404);
});
test('organic visits produce no advertisement event',async()=>{
 const events=[];global.fetch=mockFetch({events});assert.equal((await invoke({op:'contact',id},{auth:false})).statusCode,200);assert.equal(events.length,0);
});
test('same-card ads in two tabs preserve exact token identity despite shared/fake session and client IP',async()=>{
 const events=[];global.fetch=mockFetch({events});
 const cookie='proxo_contact_session=77777777-7777-4777-8777-777777777777';
 for(const token of [tokenA,tokenB]) {
  assert.equal((await invoke({op:'ad',token},{auth:false,cookie})).statusCode,200);
  assert.equal((await invoke({op:'ad',token,action:'wa',ip:'8.8.8.8',ad_id:adA},{auth:false,cookie})).statusCode,302);
 }
 assert.deepEqual(events.map(e=>e.ad_contact_link_id),[linkA,linkA,linkB,linkB]);
 assert.ok(events.every(e=>e.session_id==='77777777-7777-4777-8777-777777777777'&&e.ip_address===null));
 assert.ok(events.every(e=>!('ad_id'in e)&&!('card_id'in e)));
});
test('invalid token and arbitrary destination create no events and no redirects',async()=>{
 const events=[];global.fetch=mockFetch({events});
 assert.equal((await invoke({op:'ad',token:'invalid'},{auth:false})).statusCode,404);
 const r=await invoke({op:'ad',token:tokenA,action:'https://evil.example'},{auth:false});
 assert.equal(r.statusCode,404);assert.equal(r.headers.location,undefined);assert.equal(events.length,0);
});
test('invalid edit renders first and leaves existing published fields intact',async()=>{
 const writes=[];global.fetch=mockFetch({writes});
 const res=await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:card.updated_at,platforms:{wa:'javascript:1234567890'}}});
 assert.equal(res.statusCode,422);assert.equal(writes.length,0);
});
test('optimistic edit rejects stale state before writing',async()=>{
 const writes=[];global.fetch=mockFetch({writes});
 const res=await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:'2000-01-01T00:00:00Z',name:'Updated'}});
 assert.equal(res.statusCode,409);assert.equal(writes.length,0);
});
test('server rejects non-string platform values and escapes mixed direction data',()=>{
 assert.throws(()=>normalizedPlatforms({wa:{number:'9647501234567'}}));
 const html=renderTemplate(template,{...card,name:'فرۆشگا Proxo 2026 <script>'});
 assert.match(html,/<bdi dir="ltr">/);assert.doesNotMatch(html,/<h1>[^<]*<script>/);
});
test('TikTok tracked badges carry the same exact ad token',()=>{
 const html=renderTemplate(template,card,{adToken:tokenA});
 assert.match(html,new RegExp('/a/'+tokenA+'/action/tt'));assert.doesNotMatch(html,/href="https:\/\/www.tiktok.com/);
});

test('server renderer preserves mixed direction text and trusted contact attributes',()=>{
 const html=renderTemplate(template,{...card,name:'Zana',bio:'کۆد ABC-123، بڕ -12,345.67 IQD <script>',platforms:{wa:'9647501234567'}});
 assert.match(html,/<bdi dir="ltr">ABC-123<\/bdi>/);
 assert.match(html,/<bdi dir="ltr">-12,345.67 IQD<\/bdi>/);
 assert.match(html,/&lt;<bdi dir="ltr">script<\/bdi>&gt;/);
 assert.match(html,/9647501234567/);
 assert.doesNotMatch(html,/href="<bdi/);
});
