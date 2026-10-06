import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
process.env.PROXO_SUPABASE_URL='https://proxo-test.supabase.co';
process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY='server-test-key';
process.env.PROXO_PREVIEW_SIGNING_SECRET='test-preview-key-at-least-32-characters';
const {default:handler}=await import('../api/proxolink.js');
const {makePreviewToken,makeTemplateToken,templateTokenData,validPreviewToken}=await import('../api/_lib/proxolink-preview.js');
const {renderTemplate,normalizedPlatforms,privateTemplate,verifyPublicAvatar}=await import('../api/_lib/proxolink.js');
const {destination,TEMPLATE_KEYS,PROVIDERS}=await import('../api/_lib/proxolink-catalog.js');
const owner='11111111-1111-4111-8111-111111111111';
const id='22222222-2222-4222-8222-222222222222';
const other='33333333-3333-4333-8333-333333333333';
const token='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const card={id,user_id:owner,name:'Proxo',bio:'Hello',tt:'proxo_iq',template_key:'pill-white',template_version:2,page_type:'contact',color_theme:'purple',card_language:'ku',platforms:{wa:'07501234567',tg:'proxo_iq'},status:'active',publish_status:'ready',updated_at:'2026-10-06T00:00:00Z'};
const templates=TEMPLATE_KEYS.map(key=>{
 const source=readFileSync(new URL('../api/_lib/proxolink-templates/'+key+'.html',import.meta.url),'utf8');
 return {template_key:key,version:2,display_name_ckb:key,display_name_en:key,storage_path:key+'/v2/template.html',checksum_sha256:createHash('sha256').update(source).digest('hex'),requires_avatar:false,is_active:true,is_catalog_visible:true};
});
const source=readFileSync(new URL('../api/_lib/proxolink-templates/pill-white.html',import.meta.url),'utf8');
function response(){return {statusCode:0,headers:{},setHeader(k,v){this.headers[k.toLowerCase()]=v;},end(v=''){this.body=v;}};}
function store({rows=[card],authUser=owner,failChecksum=false,adDependency=false}={}){
 const state={rows:new Map(rows.map(x=>[x.id,structuredClone(x)])),events:[],audits:[],writes:[],failChecksum,authUser,tick:0};
 state.fetch=async (url,options={})=>{
  const u=new URL(url),method=options.method||'GET';
  if(u.pathname==='/auth/v1/user')return state.authUser?Response.json({id:state.authUser}):new Response(null,{status:401});
  if(u.pathname==='/rest/v1/proxolink_templates')return Response.json(templates.filter(t=>!u.searchParams.get('template_key')||t.template_key===u.searchParams.get('template_key').slice(3)).map(t=>state.failChecksum?{...t,checksum_sha256:'0'.repeat(64)}:t));
  if(u.pathname==='/rest/v1/proxolink_publish_attempts'){state.audits.push(JSON.parse(options.body));return new Response(null,{status:201});}
  if(u.pathname==='/rest/v1/pa_contact_events'){state.events.push(JSON.parse(options.body));return new Response(null,{status:201});}
  if(u.pathname==='/rest/v1/pa_ad_contact_links')return Response.json(u.searchParams.get('public_token')==='eq.'+token?[{id:other,ad_id:other,card_id:id,owner_user_id:owner}]:[]);
  if(u.pathname==='/rest/v1/pa_ads')return Response.json(u.searchParams.has('or')?(adDependency?[{id:other}]:[]):[{id:other,user_id:owner,asset_id:id,status:'active'}]);
  if(u.pathname==='/rest/v1/proxolink_cards'){
   const data=options.body?JSON.parse(options.body):null;
   if(method==='POST'){
    if(state.rows.has(data.id))return new Response(null,{status:409});
    const row={...data,updated_at:new Date(1791244800000+state.tick++).toISOString()};state.rows.set(data.id,row);state.writes.push(data);return Response.json([row]);
   }
   const key=u.searchParams.get('id')?.slice(3),uid=u.searchParams.get('user_id')?.slice(3);
   const found=[...state.rows.values()].filter(r=>(!key||r.id===key)&&(!uid||r.user_id===uid));
   if(method==='PATCH'){
    const expected=u.searchParams.get('updated_at')?.slice(3),changed=[];
    for(const row of found)if(!expected||Date.parse(expected)===Date.parse(row.updated_at)){
     Object.assign(row,data,{updated_at:new Date(1791244800000+state.tick++).toISOString()});changed.push(row);state.writes.push(data);
    }
    return options.headers?.Prefer==='return=minimal'?new Response(null,{status:204}):Response.json(changed);
   }
   if(method==='DELETE'){for(const row of found)state.rows.delete(row.id);return new Response(null,{status:204});}
   return Response.json(found);
  }
  throw Error('Unexpected backend path '+u.pathname);
 };return state;
}
async function invoke(query,{body={},method='GET',auth=true}={}){
 const res=response();await handler({method,query,body,url:'/contact/test',headers:{...(auth?{authorization:'Bearer user-token'}:{}),'user-agent':'Mozilla/5.0 Android Chrome/100'},socket:{remoteAddress:'127.0.0.1'}},res);return res;
}
function config(html){return JSON.parse(html.match(/<script type="application\/json" id="proxo-config">([\s\S]*?)<\/script>/)[1]);}
const payload={client_request_id:id,name:'Proxo',bio:'Hello',template_key:'pill-white',template_version:2,page_type:'contact',color_theme:'purple',card_language:'ku',platforms:{wa:'07501234567',tg:'proxo_iq'}};
const oldFetch=global.fetch;test.afterEach(()=>{global.fetch=oldFetch;});
test('only four reviewed v2 themes appear in the signed catalog',async()=>{
 global.fetch=store().fetch;const r=await invoke({op:'templates'});assert.equal(r.statusCode,200);
 const body=JSON.parse(r.body);assert.deepEqual(body.templates.map(t=>t.template_key),TEMPLATE_KEYS);assert.ok(body.templates.every(t=>t.version===2));assert.doesNotMatch(r.body,/storage_path|checksum_sha256|html_content/);
 for(const key of ['dark','light','classic','card','neon','zoom','banner'])assert.equal((await invoke({op:'templates',template_key:key,version:'1'})).statusCode,422);
});
test('each signed demo selects its language and page purpose and never records analytics',async()=>{
 const s=store();global.fetch=s.fetch;
 for(const key of TEMPLATE_KEYS)for(const pageType of ['contact','food','download']){
  const signed=makeTemplateToken(owner,key,2,{language:'en',pageType});
  const r=await invoke({op:'template-preview',token:signed,page_type:'contact',language:'ar'},{auth:false});assert.equal(r.statusCode,200);
  const c=config(r.body);assert.equal(c.template,key);assert.equal(c.lang,'en');assert.equal(c.preview,true);
  assert.ok(c.buttons.every(b=>Object.values(PROVIDERS).find(p=>p.type===b.type).group===pageType));assert.ok(c.buttons.length>=2);
 }
 assert.equal(s.events.length,0);
});
test('expired or altered tokens and cross-kind capabilities are rejected',()=>{
 const demo=makeTemplateToken(owner,'pill-white',2),preview=makePreviewToken(card),now=Date.now;
 assert.equal(validPreviewToken(demo,card),false);assert.equal(templateTokenData(preview),null);assert.equal(templateTokenData(demo+'bad'),null);
 try{Date.now=()=>now()+301000;assert.equal(templateTokenData(demo),null);assert.equal(validPreviewToken(preview,card),false);}finally{Date.now=now;}
});
test('public cards and protected owner previews respect active and ready state',async()=>{
 const inactive={...card,status:'inactive'},s=store({rows:[inactive]});global.fetch=s.fetch;
 assert.equal((await invoke({op:'contact',id},{auth:false})).statusCode,404);
 assert.equal((await invoke({op:'contact',id,preview_token:makePreviewToken(inactive)},{auth:false})).statusCode,200);
 assert.equal(s.events.length,0);
 s.rows.get(id).publish_status='failed';assert.equal((await invoke({op:'contact',id,preview_token:makePreviewToken(inactive)},{auth:false})).statusCode,404);
});
test('every supported provider redirects to its validated stored destination with correct ad attribution',async()=>{
 const values={wa:'٠٧٥٠١٢٣٤٥٦٧',tg:'proxo_iq',vb:'07501234567',ph:'07501234567',as:'07701234567',ig:'proxo_iq',talabat:'https://www.talabat.com/iraq/restaurant/123',lezzoo:'https://lezzoo.com/restaurant/123',wade:'https://wadedelivery.com/restaurant/123',toters:'https://www.totersapp.com/restaurant/123',app_store:'https://apps.apple.com/iq/app/proxo/id123456789',google_play:'https://play.google.com/store/apps/details?id=com.proxo.app'};
 const s=store({rows:[{...card,platforms:values}]});global.fetch=s.fetch;
 for(const [provider,value]of Object.entries(values)){
  const r=await invoke({op:'ad',token,action:provider,url:'https://evil.example'},{auth:false});assert.equal(r.statusCode,302,provider);assert.equal(r.headers.location,destination(provider,value));
 }
 assert.equal(s.events.length,Object.keys(values).length);assert.ok(s.events.every(e=>e.ad_contact_link_id===other));
});
test('invalid attribution, unsafe schemes and impersonating hosts cannot redirect or record clicks',async()=>{
 const s=store();global.fetch=s.fetch;
 for(const query of [{op:'ad',token:'bad',action:'wa'},{op:'ad',token,action:'javascript:alert(1)'},{op:'ad',token,action:'talabat'}])assert.equal((await invoke(query,{auth:false})).statusCode,404);
 for(const [provider,value]of [['talabat','https://talabat.com.evil.example/'],['tg','javascript:alert(1)'],['google_play','https://play.google.com/store/apps/details'],['wa','https://evil.example'],['vb','viber://chat?number=12345678&command=delete'],['app_store','https://apps.apple.com/']])assert.equal(destination(provider,value),null);
 assert.equal(s.events.length,0);
});
test('create publishes each of three page purposes with one stable idempotency key',async()=>{
 for(const [pageType,platforms]of [['contact',{wa:'07501234567',tg:'proxo_iq'}],['food',{talabat:'https://talabat.com/iq/restaurant/123',wade:'https://wadedelivery.com/restaurant/123'}],['download',{app_store:'https://apps.apple.com/app/id123456789',google_play:'https://play.google.com/store/apps/details?id=com.proxo.app'}]]){
  const s=store({rows:[]});global.fetch=s.fetch;const data={...payload,page_type:pageType,platforms,user_id:other};
  assert.equal((await invoke({op:'cards'},{method:'POST',body:data})).statusCode,201);
  assert.equal(s.rows.get(id).user_id,owner);assert.equal(s.rows.get(id).publish_status,'ready');assert.equal(s.rows.get(id).status,'active');assert.equal(s.rows.get(id).page_type,pageType);
  const duplicate=await invoke({op:'cards'},{method:'POST',body:data});assert.equal(duplicate.statusCode,200);assert.equal(JSON.parse(duplicate.body).reused,true);
  assert.equal((await invoke({op:'cards'},{method:'POST',body:{...data,name:'Changed'}})).statusCode,409);assert.equal(s.rows.size,1);
 }
});
test('create refuses a provider from the wrong page purpose',async()=>{
 const s=store({rows:[]});global.fetch=s.fetch;assert.equal((await invoke({op:'cards'},{method:'POST',body:{...payload,page_type:'food'}})).statusCode,422);assert.equal(s.rows.size,0);
});
test('optimistic edits and invalid destinations do not overwrite a published card',async()=>{
 const s=store();global.fetch=s.fetch;
 assert.equal((await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:'2000-01-01T00:00:00Z',name:'Changed'}})).statusCode,409);
 assert.equal((await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:card.updated_at,platforms:{wa:'javascript:1234567890'}}})).statusCode,422);assert.equal(s.writes.length,0);
 const r=await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:card.updated_at,name:'Updated'}});assert.equal(r.statusCode,200);assert.equal(s.rows.get(id).platforms.tg,'proxo_iq');
});
test('publication failure is recoverable on the same card without replacing it',async()=>{
 const s=store({rows:[],failChecksum:true});global.fetch=s.fetch;
 assert.equal((await invoke({op:'cards'},{method:'POST',body:payload})).statusCode,422);assert.equal(s.rows.get(id).publish_status,'failed');
 s.failChecksum=false;assert.equal((await invoke({op:'card-action'},{method:'POST',body:{card_id:id,action:'retry'}})).statusCode,200);assert.equal(s.rows.get(id).publish_status,'ready');assert.equal(s.rows.size,1);
});
test('a modified template cannot replace an already published page on edit',async()=>{
 const s=store({failChecksum:true});global.fetch=s.fetch;assert.equal((await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:card.updated_at,name:'Changed'}})).statusCode,422);assert.equal(s.writes.length,0);assert.equal(s.rows.get(id).name,'Proxo');
 await assert.rejects(privateTemplate({...templates[0],storage_path:'../template.html'}));
});
test('owner-only APIs reject missing sessions and other users',async()=>{
 const s=store({authUser:other});global.fetch=s.fetch;
 assert.equal((await invoke({op:'cards',id},{method:'PATCH',body:{expected_updated_at:card.updated_at,name:'Forged'}})).statusCode,403);
 assert.equal((await invoke({op:'preview-token'},{method:'POST',body:{card_id:id}})).statusCode,404);
 assert.equal((await invoke({op:'cards'},{auth:false})).statusCode,401);assert.equal(s.writes.length,0);
});
test('ads prevent deletion or deactivation of their linked customer card',async()=>{
 const s=store({adDependency:true});global.fetch=s.fetch;
 for(const action of ['delete','deactivate'])assert.equal((await invoke({op:'card-action'},{method:'POST',body:{card_id:id,action}})).statusCode,409);assert.equal(s.rows.size,1);
});
test('oversized and malformed JSON cannot enter publication',async()=>{
 const s=store({rows:[]});global.fetch=s.fetch;
 assert.equal((await invoke({op:'cards'},{method:'POST',body:{...payload,bio:'x'.repeat(70000)}})).statusCode,413);
 assert.equal((await invoke({op:'cards'},{method:'POST',body:'{invalid-json'})).statusCode,422);assert.equal(s.rows.size,0);
});
test('profile text is escaped JSON and never becomes HTML or a script',()=>{
 const dangerous='</script><script>alert(1)</script><img src=x onerror=alert(1)>';
 const html=renderTemplate(source,{...card,name:dangerous,bio:dangerous});assert.equal(config(html).name,dangerous);assert.equal(config(html).bio,dangerous);assert.ok(!html.includes(dangerous));assert.ok(!html.includes('<img src=x onerror=alert(1)>'));assert.throws(()=>normalizedPlatforms({wa:{number:'12345678'}}));
});
test('legacy avatar data renders as verified raster bytes without exposing private storage',async()=>{
 const sharp=(await import('sharp')).default;const png=await sharp({create:{width:2,height:2,channels:3,background:'#25d366'}}).png().toBuffer();
 const s=store({rows:[{...card,avatar_b64:png.toString('base64')}]});global.fetch=s.fetch;const r=await invoke({op:'avatar',id},{auth:false});assert.equal(r.statusCode,200);assert.equal(r.headers['content-type'],'image/webp');
 s.rows.get(id).avatar_b64=Buffer.from('<svg onload="alert(1)"/>').toString('base64');assert.equal((await invoke({op:'avatar',id},{auth:false})).statusCode,404);
 const html=renderTemplate(source,card,{publicAvatarUrl:'/contact/'+id+'/avatar'});assert.equal(config(html).avatarUrl,'/contact/'+id+'/avatar');assert.ok(!config(html).avatarUrl.includes(owner));
});
test('private avatar MIME and full decode are verified before publishing',async()=>{
 const sharp=(await import('sharp')).default;const png=await sharp({create:{width:2,height:2,channels:3,background:'#25d366'}}).png().toBuffer();
 global.fetch=async()=>new Response(png,{headers:{'Content-Type':'image/png'}});assert.equal(await verifyPublicAvatar(owner+'/'+id+'/avatar.png'),true);
 global.fetch=async()=>new Response(png.subarray(0,20),{headers:{'Content-Type':'image/png'}});await assert.rejects(verifyPublicAvatar(owner+'/'+id+'/avatar.png'));
});
test('the old eight reusable client styles and HTML generator are absent',()=>{
 for(const path of ['proxo_app/assets/styles','proxo_app/lib/templates/card_templates.dart','proxo_app/lib/services/html_generator.dart','proxo_app/lib/services/telegram_delivery_service.dart'])assert.equal(existsSync(path),false,path);
});

test('existing empty customer pages stay renderable without inventing links',()=>{
 const c=config(renderTemplate(source,{...card,platforms:{},tt:''}));assert.deepEqual(c.buttons,[]);assert.equal(c.name,card.name);
});
