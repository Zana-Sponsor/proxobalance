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

function publishingStore({failStorage=false}={}) {
 const rows=new Map(),audits=[];let tick=0;
 const state={rows,audits,failStorage,fetch:async(url,options={})=>{
  const u=new URL(url),method=options.method||'GET';
  if(u.pathname==='/auth/v1/user')return Response.json({id:owner});
  if(u.pathname.includes('/storage/'))return new Response(state.failStorage?'corrupted':template);
  if(u.pathname==='/rest/v1/proxolink_templates')return Response.json([metadata]);
  if(u.pathname==='/rest/v1/proxolink_publish_attempts'){audits.push(JSON.parse(options.body));return new Response(null,{status:204});}
  if(u.pathname==='/rest/v1/proxolink_cards') {
   if(method==='POST') {
    const data=JSON.parse(options.body);if(rows.has(data.id))return new Response('',{status:409});
    const row={...data,updated_at:new Date(1791060000000+tick++).toISOString()};rows.set(row.id,row);return Response.json([row]);
   }
   const key=u.searchParams.get('id')?.slice(3),user=u.searchParams.get('user_id')?.slice(3);
   const found=[...rows.values()].filter(r=>(!key||r.id===key)&&(!user||r.user_id===user));
   if(method==='PATCH') {
    const expected=u.searchParams.get('updated_at')?.slice(3),changed=[];
    for(const row of found)if(!expected||Date.parse(expected)===Date.parse(row.updated_at)){
     Object.assign(row,JSON.parse(options.body),{updated_at:new Date(1791060000000+tick++).toISOString()});changed.push(row);
    }
    return options.headers?.Prefer==='return=minimal'?new Response(null,{status:204}):Response.json(changed);
   }
   return Response.json(found);
  }
  throw Error('Unexpected path '+u.pathname);
 }};return state;
}
const createPayload={client_request_id:id,name:'Proxo',bio:'Hello',tt:'proxo_iq',template_key:'classic',template_version:1,color_theme:'purple',card_language:'ku',platforms:{wa:'9647501234567'}};
test('duplicate create reuses one stable UUID and rejects a changed payload',async()=>{
 const store=publishingStore();global.fetch=store.fetch;
 const first=await invoke({op:'cards'},{method:'POST',body:createPayload});assert.equal(first.statusCode,201);
 const again=await invoke({op:'cards'},{method:'POST',body:createPayload});assert.equal(again.statusCode,200);assert.equal(JSON.parse(again.body).reused,true);
 const conflict=await invoke({op:'cards'},{method:'POST',body:{...createPayload,name:'Different'}});assert.equal(conflict.statusCode,409);
 assert.equal(store.rows.size,1);assert.equal(store.rows.get(id).publish_status,'ready');assert.equal(store.rows.get(id).status,'active');
 assert.deepEqual(store.audits.map(r=>r.result),['started','success']);assert.doesNotMatch(first.body,/creation_request_hash|html_content|avatar_b64/);
});
test('a failed publication remains recoverable and retry publishes the same UUID',async()=>{
 const store=publishingStore({failStorage:true});global.fetch=store.fetch;
 const failed=await invoke({op:'cards'},{method:'POST',body:createPayload});assert.equal(failed.statusCode,422);
 assert.equal(JSON.parse(failed.body).card.id,id);assert.equal(store.rows.get(id).publish_status,'failed');assert.equal(store.rows.get(id).status,'inactive');
 store.failStorage=false;
 const retry=await invoke({op:'card-action'},{method:'POST',body:{card_id:id,action:'retry'}});assert.equal(retry.statusCode,200);
 assert.equal(store.rows.size,1);assert.equal(store.rows.get(id).publish_status,'ready');assert.equal(store.rows.get(id).status,'active');
 assert.deepEqual(store.audits.map(r=>[r.operation,r.result]),[['create','started'],['create','failed'],['retry','started'],['retry','success']]);
});
test('owner-only APIs reject another owner and require a bearer session',async()=>{
 global.fetch=mockFetch({currentCard:{...card,user_id:adB}});
 assert.equal((await invoke({op:'preview-token'},{method:'POST',body:{card_id:id}})).statusCode,404);
 assert.equal((await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:card.updated_at,name:'Changed'}})).statusCode,403);
 assert.equal((await invoke({op:'cards'},{auth:false})).statusCode,401);
});
test('large and malformed JSON never writes a card',async()=>{
 const store=publishingStore();global.fetch=store.fetch;
 assert.equal((await invoke({op:'cards'},{method:'POST',body:{...createPayload,bio:'x'.repeat(70000)}})).statusCode,413);
 assert.equal((await invoke({op:'cards'},{method:'POST',body:'{invalid-json'})).statusCode,422);
 assert.equal(store.rows.size,0);
});
test('signed preview tokens expire and cannot be used as a different token kind',async()=>{
 const {templateTokenData,validPreviewToken}=await import('../api/_lib/proxolink-preview.js');
 const start=Date.now,token=makePreviewToken(card),demo=makeTemplateToken(owner,'classic',1);
 assert.equal(validPreviewToken(demo,card),false);assert.equal(templateTokenData(token),null);
 try{Date.now=()=>start()+301000;assert.equal(validPreviewToken(token,card),false);assert.equal(templateTokenData(demo),null);}finally{Date.now=start;}
});
test('the renderer preserves original TikTok badge spacing and tracks the banner badge',()=>{
 const source='<h1>{{NAME}}</h1><p>{{BIO}}</p><div class="tt-wrap">{{TT_BADGE}}</div>{{BUTTONS}}';
 const html=renderTemplate(source,{...card,template_key:'card'});
 assert.equal((html.match(/class="tt-wrap"/g)||[]).length,2);
 const banner=renderTemplate('<h1>{{NAME}}</h1><p>{{BIO}}</p>{{TT_INLINE}}{{BUTTONS}}',{...card,template_key:'banner'},{adToken:tokenA});
 assert.match(banner,new RegExp('href="/a/'+tokenA+'/action/tt"'));assert.match(banner,/text-decoration:none/);
});
test('WhatsApp tracking derives a universal app/web fallback from the validated card phone',async()=>{
 const{actionUrl}=await import('../api/_lib/proxolink-track.js');assert.equal(actionUrl(card,'wa'),'https://wa.me/9647501234567');
 assert.throws(()=>actionUrl({...card,platforms:{wa:'https://evil.example'}},'wa'));
});

test('avatar publication fully decodes bytes and rejects truncation or a false MIME',async()=>{
 const sharp=(await import('sharp')).default;
 const png=await sharp({create:{width:2,height:2,channels:3,background:'#046cfa'}}).png().toBuffer();
 const {verifyPublicAvatar}=await import('../api/_lib/proxolink.js');
 global.fetch=async()=>new Response(png,{headers:{'Content-Type':'image/png'}});
 assert.equal(await verifyPublicAvatar(owner+'/'+id+'/avatar.png'),true);
 global.fetch=async()=>new Response(png.subarray(0,20),{headers:{'Content-Type':'image/png'}});
 await assert.rejects(verifyPublicAvatar(owner+'/'+id+'/avatar.png'),e=>e.code==='invalid_avatar');
 global.fetch=async()=>new Response(png,{headers:{'Content-Type':'image/jpeg'}});
 await assert.rejects(verifyPublicAvatar(owner+'/'+id+'/avatar.jpg'),e=>e.code==='invalid_avatar');
});
test('the verified JWT owner overrides forged JSON ownership',async()=>{
 const store=publishingStore();global.fetch=store.fetch;
 const result=await invoke({op:'cards'},{method:'POST',body:{...createPayload,user_id:adB,owner_user_id:adB}});
 assert.equal(result.statusCode,201);assert.equal(store.rows.get(id).user_id,owner);
});
test('a rejected bearer cannot reach protected data operations',async()=>{
 let protectedReads=0;
 global.fetch=async url=>{if(new URL(url).pathname==='/auth/v1/user')return new Response('',{status:401});protectedReads++;throw Error('Protected data access');};
 assert.equal((await invoke({op:'cards'})).statusCode,401);assert.equal(protectedReads,0);
});

test('client IP comes from the socket locally and Vercel-reserved headers only on Vercel',async()=>{
 const{realClientIp}=await import('../api/_lib/security.js');
 const old=process.env.VERCEL;const request={headers:{'x-forwarded-for':'8.8.8.8','x-vercel-forwarded-for':'9.9.9.9'},socket:{remoteAddress:'127.0.0.1'}};
 try {
  delete process.env.VERCEL;
  assert.equal(realClientIp(request,{proxyMode:'direct'}),'127.0.0.1');
  assert.equal(realClientIp(request,{proxyMode:'vercel'}),'127.0.0.1');
  process.env.VERCEL='1';
  assert.equal(realClientIp(request,{proxyMode:'vercel'}),'9.9.9.9');
 }finally{if(old===undefined)delete process.env.VERCEL;else process.env.VERCEL=old;}
});
