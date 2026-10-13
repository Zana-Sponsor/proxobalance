import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash,randomUUID} from 'node:crypto';
import {Readable} from 'node:stream';
import {validateStagingConfiguration,stagingTransport,verifyStagingLifecycle} from '../scripts/proxolink-staging-verification.mjs';
import {verifyStagingTools,verifyStagingToolsTransitions} from '../scripts/proxolink-staging-tools.mjs';

const environment={PROXO_STAGING_PROJECT_REF:'abcdefghijklmnopqrst',
  PROXO_STAGING_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',
  PROXO_STAGING_BASE_URL:'https://proxolink-staging-fixtures.vercel.app',
  PROXO_STAGING_ANON_KEY:'sb_publishable_fixture',PROXO_STAGING_TEST_EMAIL:'fictional@example.invalid',
  PROXO_STAGING_TEST_PASSWORD:'test-only',PROXO_STAGING_VERCEL_BYPASS:'test-only',
  PROXO_STAGING_OTHER_EMAIL:'other@example.invalid',PROXO_STAGING_OTHER_PASSWORD:'test-only-other'};
const config=validateStagingConfiguration(environment);

test('staging runner refuses production/preview projects, credential-bearing URLs and service keys',()=>{
  for(const change of [{PROXO_STAGING_PROJECT_REF:'cojchkwssmasiejcgvbk'},
    {PROXO_STAGING_BASE_URL:'https://www.proxobalance.app'},
    {PROXO_STAGING_BASE_URL:'https://proxobalance-git-feat-proxolink-private-re-00a2aa-proxoapp-1758.vercel.app'},
    {PROXO_STAGING_BASE_URL:'https://secret@proxolink-staging.vercel.app'},
    {PROXO_STAGING_SUPABASE_URL:'https://cojchkwssmasiejcgvbk.supabase.co'},
    {PROXO_STAGING_ANON_KEY:'sb_secret_fixture'}])
    assert.throws(()=>validateStagingConfiguration({...environment,...change}));
});

test('staging HTTP scope never forwards bypass to Supabase or follows credential redirects',async()=>{
  const calls=[];
  const request=stagingTransport(config,async(url,options)=>{calls.push({url,options});return Response.json({});});
  await request('/api/contact-templates');
  await request('/auth/v1/token?grant_type=password',{supabase:true,method:'POST'});
  assert.equal(calls[0].options.headers['x-vercel-protection-bypass'],'test-only');
  assert.equal(calls[1].options.headers['x-vercel-protection-bypass'],undefined);
  assert.ok(calls.every(c=>c.options.redirect==='error'));
  for(const [path,options] of [['https://www.proxobalance.app/api/contact-cards',{}],
    ['/api/contact-templates?x-vercel-protection-bypass=value',{}],
    ['/rest/v1/proxolink_cards',{supabase:true,method:'PATCH'}],
    ['/api/contact-cards',{method:'DELETE'}]])await assert.rejects(request(path,options));
  assert.equal(calls.length,2);
  const id='11111111-1111-4111-8111-111111111111';
  await request('/rest/v1/proxolink_cards?id=eq.'+id,{supabase:true,method:'PATCH',body:'{"moderation_status":"approved"}'});
  for(const body of ['{"moderation_status":"approved","user_id":"forged"}','{"name":"write"}','{"moderation_status":"pending"}'])
    await assert.rejects(request('/rest/v1/proxolink_cards?id=eq.'+id,{supabase:true,method:'PATCH',body}));
  await assert.rejects(request('/rest/v1/proxolink_cards',{supabase:true,method:'PATCH',body:'{"moderation_status":"approved"}'}));
});

test('staging orchestrator exercises all twelve independent page/design lifecycles through the actual API handlers using controlled provider fixtures',async()=>{
  process.env.PROXO_SUPABASE_URL=config.supabase;
  process.env.PROXO_V6_WRITE_MODE='isolated';
  process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY='server-fixture-only';
  process.env.PROXO_PREVIEW_SIGNING_SECRET='fixture-secret-at-least-32-characters';
  const {default:handler}=await import('../api/proxolink.js');
  const owner='11111111-1111-4111-8111-111111111111',other='99999999-9999-4999-8999-999999999999';
  const cards=new Map(),images=new Map();let serial=0,dependencyId=null;
  const source='<!DOCTYPE html><html><head></head><body>{{NAME}}{{BIO}}{{AVATAR}}{{BUTTONS}}<script>{{HANDLERS}}</script></body></html>';
  const fetcher=async(url,options={})=>{
    const u=new URL(url),method=options.method||'GET';
    if(u.origin===config.supabase) {
      if(u.pathname==='/auth/v1/token')return JSON.parse(options.body).email===config.otherEmail
        ?Response.json({access_token:'other-fixture-session',user:{id:other}}):Response.json({access_token:'ordinary-fixture-session',user:{id:owner}});
      if(u.pathname==='/auth/v1/user')return Response.json({id:options.headers.Authorization==='Bearer other-fixture-session'?other:owner});
      if(u.pathname==='/rest/v1/proxolink_templates') {
        const style=u.searchParams.get('template_key')?.slice(3);
        return Response.json((style?[style]:['dark','light','classic','pill','card','neon','zoom','banner']).map(key=>({
          template_key:key,version:2,storage_path:key+'/v2/template.html',requires_avatar:true,
          checksum_sha256:createHash('sha256').update(source).digest('hex'),is_active:true,is_catalog_visible:true})));
      }
      if(u.pathname.startsWith('/storage/v1/object/proxolink-templates/'))return new Response(source);
      if(u.pathname.startsWith('/storage/v1/object/proxolink-assets/')) {
        if(method==='POST'){
          if(options.headers.Authorization==='Bearer other-fixture-session'&&!u.pathname.includes('/'+other+'/'))return Response.json({error:'fixture_owner_denied'},{status:403});
          images.set(u.pathname,options.body);return Response.json({},{status:201});}
        return images.has(u.pathname)?new Response(images.get(u.pathname),{headers:{'Content-Type':'image/png'}}):new Response(null,{status:404});
      }
      if(u.pathname==='/rest/v1/proxolink_cards') {
        const id=u.searchParams.get('id')?.slice(3);
        if(method==='POST') {
          const data=JSON.parse(options.body);const id=data.id||randomUUID();cards.set(id,{...data,id,moderation_status:'pending',card_number:cards.size+1,updated_at:'2026-10-05T00:00:00.001Z'});
          return Response.json([cards.get(id)],{status:201});
        }
        const values=[...cards.values()].filter(card=>(!id||card.id===id)
          &&(!u.searchParams.get('user_id')||card.user_id===u.searchParams.get('user_id').slice(3))
          &&(options.headers.Authorization!=='Bearer other-fixture-session'||card.user_id===other)
          &&(!u.searchParams.get('client_request_id')||card.client_request_id===u.searchParams.get('client_request_id').slice(3))
          &&(!u.searchParams.get('updated_at')||card.updated_at===u.searchParams.get('updated_at').slice(3)));
        if(method==='PATCH'){
          const patch=JSON.parse(options.body);
          if(patch.moderation_status&&['Bearer ordinary-fixture-session','Bearer other-fixture-session'].includes(options.headers.Authorization))
            return Response.json({code:'42501'},{status:403});
          for(const card of values)Object.assign(card,patch,{updated_at:new Date(1791158400000+(++serial)).toISOString()});
        }
        if(method==='DELETE')for(const card of values)cards.delete(card.id);
        return Response.json(values);
      }
      if(u.pathname==='/rest/v1/proxolink_publish_attempts')return new Response(null,{status:201});
      if(u.pathname==='/rest/v1/pa_ads')return Response.json(dependencyId&&u.searchParams.get('or')?.includes(dependencyId)?[{id:randomUUID()}]:[]);
      throw Error('Unexpected provider fixture request');
    }
    assert.equal(u.origin,config.base);
    const pageType=u.pathname.split('/')[1];
    const operation=/^\/(contact|order|download)\//.test(u.pathname)?(u.pathname.endsWith('/avatar')?(pageType==='contact'?'avatar':pageType+'-avatar'):pageType):
      {'/api/contact-templates':'templates','/api/page-providers':'providers','/api/contact-cards':'cards','/api/contact-card-action':'card-action','/api/contact-preview-token':'preview-token',
        '/api/page-preview-token':'form-preview-token','/page-preview':'form-preview'}[u.pathname];
    const query={...Object.fromEntries(u.searchParams),op:operation};
    if(/^\/(contact|order|download)\//.test(u.pathname)){query.id=u.pathname.split('/')[2];query.page_type=u.pathname.split('/')[1];}
    const req=Readable.from(options.body?[Buffer.from(options.body)]:[]);
    Object.assign(req,{query,method,headers:{...Object.fromEntries(Object.entries(options.headers||{}).map(([k,v])=>[k.toLowerCase(),v])),host:'proxolink-staging-fixtures.vercel.app'},socket:{remoteAddress:'127.0.0.1'},url:u.pathname+u.search});
    const res={statusCode:200,headers:{},setHeader(name,value){this.headers[name]=value;},end(data=''){this.body=data;}};
    await handler(req,res);
    return new Response(res.body,{status:res.statusCode,headers:res.headers});
  };
  const original=global.fetch;global.fetch=fetcher;
  try {
    const sharp=(await import('sharp')).default;
    const image=await sharp({create:{width:10,height:10,channels:3,background:'#046cfa'}}).png().toBuffer();
    const result=await verifyStagingLifecycle(config,image,fetcher);
    assert.equal(result.cases.length,12);assert.equal(cards.size,12);
    assert.ok(result.cases.every(entry=>entry.failed_publish_recovered&&entry.stable_edit_link&&entry.owner_inactive_preview));
    assert.doesNotMatch(JSON.stringify(result),/ordinary-fixture-session|server-fixture-only|test-only|preview_token/);
    const tools=await verifyStagingTools(config,image,fetcher);
    assert.equal(tools.status,'Pending');assert.equal(tools.cases.length,12);assert.equal(tools.cases.filter(p=>p.actual_delete).length,9);
    assert.equal(tools.hosted_browser_or_native_ui_verified,false);assert.equal(tools.trusted_transitions_verified,false);
    await assert.rejects(verifyStagingToolsTransitions(config,tools,fetcher)); // Cannot certify absent trusted changes.
    for(const fixture of tools.retained_fixtures)if(fixture.expected_action==='ad_dependency')dependencyId=fixture.fixture_id;
      else cards.get(fixture.fixture_id).moderation_status=fixture.expected_action;
    const transitions=await verifyStagingToolsTransitions(config,tools,fetcher);
    assert.equal(transitions.cases.length,3);assert.equal(transitions.setup_mutations_performed,false);
    assert.equal(transitions.hosted_browser_or_native_ui_verified,false);
    assert.doesNotMatch(JSON.stringify({tools,transitions}),/ordinary-fixture-session|server-fixture-only|test-only|preview_token/);
  }finally{global.fetch=original;}
});
