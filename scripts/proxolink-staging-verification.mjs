// Real HTTP lifecycle checks for an independently configured isolated project.
// No production fallback, service credential, template edit or customer cleanup.
import {randomUUID,createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {STYLES,SUPABASE_ORIGIN,PREVIEW_ORIGIN} from './proxolink-verification-security.mjs';

export function validateStagingConfiguration(env) {
  const ref=env.PROXO_STAGING_PROJECT_REF;
  if(!/^[a-z]{20}$/.test(ref||'')||ref==='cojchkwssmasiejcgvbk')throw Error('isolated_staging_project_required');
  const supabase='https://'+ref+'.supabase.co';
  if(env.PROXO_STAGING_SUPABASE_URL!==supabase||supabase===SUPABASE_ORIGIN)
    throw Error('isolated_staging_project_required');
  let base;
  try{base=new URL(env.PROXO_STAGING_BASE_URL);}catch{throw Error('isolated_staging_origin_required');}
  if(base.protocol!=='https:'||base.username||base.password||base.pathname!=='/'||base.search||base.hash
    ||!/^proxolink-staging(?:-[a-z0-9-]+)?\.vercel\.app$/.test(base.hostname)
    ||base.origin===PREVIEW_ORIGIN)throw Error('isolated_staging_origin_required');
  for(const name of ['PROXO_STAGING_ANON_KEY','PROXO_STAGING_TEST_EMAIL','PROXO_STAGING_TEST_PASSWORD'])
    if(typeof env[name]!=='string'||!env[name])throw Error('staging_setting_required');
  const key=env.PROXO_STAGING_ANON_KEY;
  let role;
  try{role=JSON.parse(Buffer.from(key.split('.')[1],'base64url')).role;}catch{}
  if(!key.startsWith('sb_publishable_')&&role!=='anon')throw Error('publishable_key_required');
  return {base:base.origin,supabase,key,email:env.PROXO_STAGING_TEST_EMAIL,
    password:env.PROXO_STAGING_TEST_PASSWORD,bypass:env.PROXO_STAGING_VERCEL_BYPASS||''};
}

export function stagingTransport(config,fetcher=fetch) {
  return async (path,{supabase=false,method='GET',authorization,body,contentType}={})=>{
    const origin=supabase?config.supabase:config.base;
    const url=new URL(path,origin);
    if(url.origin!==origin||url.username||url.password||url.searchParams.has('x-vercel-protection-bypass'))
      throw Error('staging_request_scope');
    const allowed=supabase
      ?url.pathname==='/auth/v1/token'||url.pathname==='/rest/v1/proxolink_cards'
        ||/^\/storage\/v1\/object\/proxolink-assets\/[0-9a-f-]{36}\/[0-9a-f-]{36}\/avatar(?:-edited)?\.png$/.test(url.pathname)
      :['/api/contact-templates','/api/contact-cards','/api/contact-card-action','/api/contact-preview-token'].includes(url.pathname)
        ||/^\/contact\/[0-9a-f-]{36}(?:\/avatar)?$/.test(url.pathname);
    if(!allowed||!['GET','POST','PATCH'].includes(method))throw Error('staging_request_scope');
    if(supabase && ((url.pathname==='/auth/v1/token'&&method!=='POST')
      ||(url.pathname==='/rest/v1/proxolink_cards'&&method!=='GET')
      ||(url.pathname.startsWith('/storage/')&&method!=='POST')))
      throw Error('staging_request_scope');
    const headers={};
    if(supabase)headers.apikey=config.key;
    else if(config.bypass)headers['x-vercel-protection-bypass']=config.bypass;
    if(authorization)headers.Authorization=authorization;
    if(contentType)headers['Content-Type']=contentType;
    return fetcher(url.href,{method,headers,body,redirect:'error',signal:AbortSignal.timeout(30000)});
  };
}

export async function verifyStagingLifecycle(config,avatar,fetcher=fetch,{uuid=randomUUID}={}) {
  const request=stagingTransport(config,fetcher);
  const json=async(path,options={})=>{
    const response=await request(path,options);
    const body=await response.json();
    return {status:response.status,body};
  };
  const signed=await json('/auth/v1/token?grant_type=password',{supabase:true,method:'POST',
    contentType:'application/json',body:JSON.stringify({email:config.email,password:config.password})});
  assert.equal(signed.status,200,'staging_sign_in_failed');
  const session=signed.body;
  assert.ok(session.access_token&&/^[0-9a-f-]{36}$/.test(session.user?.id||''),'staging_user_required');
  const authorization='Bearer '+session.access_token;
  const api=(path,options={})=>json(path,{authorization,...options});
  const body=data=>({method:'POST',contentType:'application/json',body:JSON.stringify(data)});
  const noAuth=await json('/api/contact-templates');
  assert.equal(noAuth.status,401,'independent_application_auth_required');
  const catalog=await api('/api/contact-templates');
  assert.equal(catalog.status,200,'staging_catalog_required');
  assert.doesNotMatch(JSON.stringify(catalog.body),/storage_path|checksum_sha256|html_content|template\.html/);
  const fixtures=[];
  const replacementAvatar=await sharp(avatar).modulate({brightness:0.9}).png().toBuffer();
  const inspect=async id=>{
    const list=await api('/api/contact-cards');assert.equal(list.status,200);
    const card=list.body.cards.find(row=>row.id===id);assert.ok(card,'saved_fixture_required');return card;
  };
  const page=async(id,expected)=>{
    const response=await request('/contact/'+id);
    assert.equal(response.status,expected,'public_renderer_status');
    if(expected===200){assert.match(response.headers.get('content-type')||'',/^text\/html/);
      const html=await response.text();assert.doesNotMatch(html,/\{\{[A-Z_]+\}\}|proxolink-templates\/|fa-telegram|api\.telegram\.org/);}
  };
  for(const style of STYLES) {
    const meta=catalog.body.templates.find(item=>item.template_key===style&&item.version===2);
    assert.ok(meta,'reviewed_staging_v2_required');
    const id=uuid(),path=session.user.id+'/'+id+'/avatar.png';
    const payload={client_request_id:id,name:'Proxo staging '+style,bio:'Isolated verification fixture',
      tt:'proxo_staging_fixture',template_key:style,template_version:2,color_theme:'purple',card_language:'ku',
      avatar_path:path,platforms:{wa:'12025550123',vb:'12025550123',ig:'proxo_staging_fixture',ph:'12025550123'}};
    // A new fixture references a not-yet-uploaded avatar. This causes a genuine
    // publication failure without changing templates or other users' rows.
    const failed=await api('/api/contact-cards',body(payload));
    assert.equal(failed.status,422);assert.equal(failed.body.error,'publish_failed');
    assert.equal(failed.body.card?.id,id);assert.equal(failed.body.card?.publish_status,'failed');
    await page(id,404);
    const duplicate=await api('/api/contact-cards',body(payload));
    assert.equal(duplicate.status,200);assert.equal(duplicate.body.reused,true);assert.equal(duplicate.body.card.id,id);
    const upload=await request('/storage/v1/object/proxolink-assets/'+path,{supabase:true,
      authorization,method:'POST',contentType:'image/png',body:avatar});
    assert.ok(upload.ok,'staging_avatar_upload_failed');
    const retried=await api('/api/contact-card-action',body({card_id:id,action:'retry'}));
    assert.equal(retried.status,200);assert.equal(retried.body.card.id,id);
    assert.equal(retried.body.card.publish_status,'ready');assert.equal(retried.body.card.status,'active');
    const publicPath='/contact/'+id;assert.equal(retried.body.card.public_path,publicPath);
    await page(id,200);
    const publicAvatar=await request(publicPath+'/avatar');assert.equal(publicAvatar.status,200);
    assert.equal(createHash('sha256').update(Buffer.from(await publicAvatar.arrayBuffer())).digest('hex'),
      createHash('sha256').update(avatar).digest('hex'),'public_avatar_bytes');
    const before=await inspect(id);
    const replacementPath=session.user.id+'/'+id+'/avatar-edited.png';
    const replacement=await request('/storage/v1/object/proxolink-assets/'+replacementPath,{supabase:true,
      authorization,method:'POST',contentType:'image/png',body:replacementAvatar});
    assert.ok(replacement.ok,'staging_avatar_replacement_failed');
    const nextStyle=STYLES[(STYLES.indexOf(style)+1)%STYLES.length];
    const updated=await api('/api/contact-cards?id='+id,{...body({name:'Edited Proxo '+style,
      bio:'Updated fixture',template_key:nextStyle,template_version:2,color_theme:'blue',card_language:'en',
      platforms:{wa:'12025550124',vb:'12025550124',ig:'proxo_staging_edited',ph:'12025550124'},
      avatar_path:replacementPath,expected_updated_at:before.updated_at}),method:'PATCH'});
    assert.equal(updated.status,200);assert.equal(updated.body.card.id,id);assert.equal(updated.body.card.public_path,publicPath);
    const edited=await inspect(id);
    assert.equal(edited.template_key,nextStyle);assert.equal(edited.color_theme,'blue');assert.equal(edited.card_language,'en');
    assert.equal(edited.platforms.wa,'12025550124');assert.equal(edited.avatar_path,replacementPath);
    const editedAvatar=await request(publicPath+'/avatar');assert.equal(editedAvatar.status,200);
    assert.equal(createHash('sha256').update(Buffer.from(await editedAvatar.arrayBuffer())).digest('hex'),
      createHash('sha256').update(replacementAvatar).digest('hex'),'replacement_avatar_bytes');
    const invalid=await api('/api/contact-cards?id='+id,{...body({name:'',expected_updated_at:(await inspect(id)).updated_at}),method:'PATCH'});
    assert.equal(invalid.status,422);assert.equal((await inspect(id)).name,'Edited Proxo '+style);await page(id,200);
    const off=await api('/api/contact-card-action',body({card_id:id,action:'deactivate'}));assert.equal(off.status,200);
    assert.equal(off.body.card.status,'inactive');assert.equal(off.body.card.public_path,null);await page(id,404);
    const preview=await api('/api/contact-preview-token',body({card_id:id}));assert.equal(preview.status,200);
    const previewPath=preview.body.preview_path;
    assert.ok(typeof previewPath==='string'&&previewPath.startsWith(publicPath+'?preview_token='),'owner_preview_required');
    const ownerPage=await request(previewPath);assert.equal(ownerPage.status,200);
    const on=await api('/api/contact-card-action',body({card_id:id,action:'activate'}));assert.equal(on.status,200);
    assert.equal(on.body.card.id,id);assert.equal(on.body.card.public_path,publicPath);await page(id,200);
    fixtures.push({style,version:2,fixture_id:id,failed_publish_recovered:true,duplicate_reused:true,
      stable_edit_link:true,invalid_edit_preserved:true,public_avatar_bytes:true,inactive_hidden:true,
      template_theme_language_contacts_edited:true,avatar_replaced:true,
      owner_inactive_preview:true,reactivated_same_link:true});
  }
  const list=await api('/api/contact-cards');
  for(const fixture of fixtures)assert.equal(list.body.cards.filter(card=>card.id===fixture.fixture_id).length,1);
  return {environment:'Isolated staging; real HTTP APIs; ordinary account; fictional retained fixtures',
    application_auth_required:true,cases:fixtures,
    coverage_exclusions:['native rendering','OS copy/share','external app launches','exact-ad live analytics','iOS']};
}
