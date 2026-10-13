// Actual API handlers -> PostgreSQL 17 in a disposable CI service. No production fallback.
import {execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {pagePayload,OWNER,OTHER,invoke,configFromHtml} from '../test/fixtures/proxolink-v6-service.mjs';
const target=new URL(process.env.PROXO_V6_DATABASE_URL||'invalid:');
if(target.protocol!=='postgresql:'||target.hostname!=='127.0.0.1'||target.port!=='5432'||target.pathname!=='/proxo_v6_test')throw Error('isolated_database_required');
const env={...process.env,PGHOST:target.hostname,PGPORT:target.port,PGDATABASE:'proxo_v6_test',PGUSER:decodeURIComponent(target.username),PGPASSWORD:decodeURIComponent(target.password)};
const sql=query=>execFileSync('psql',['-X','-q','-t','-A','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate','-c',query],{env,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
const quoted=value=>"'"+String(value).replaceAll("'","''")+"'";
const identifier=name=>{if(!/^[a-z][a-z0-9_]*$/.test(name))throw Error('invalid_column');return '"'+name+'"';};
const jsonQuery=query=>JSON.parse(sql(`SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (${query}) t`));
process.env.PROXO_SUPABASE_URL='https://v6-isolated-db.supabase.co';
process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY='isolated-test-service';
process.env.PROXO_V6_WRITE_MODE='isolated';
process.env.PROXO_PREVIEW_SIGNING_SECRET='isolated-db-signing-test-at-least-32-characters';
const {default:handler}=await import('../api/proxolink.js');
let events=0;
global.fetch=async(raw,options={})=>{
 const url=new URL(raw),method=options.method||'GET';
 if(url.origin!=='https://v6-isolated-db.supabase.co')throw Error('request_outside_isolated_fixture');
 if(url.pathname==='/auth/v1/user')return Response.json({id:options.headers.Authorization==='Bearer other-token'?OTHER:OWNER});
 if(url.pathname==='/rest/v1/pa_contact_events'){events++;throw Error('outbound_tracking_forbidden');}
 if(!url.pathname.startsWith('/rest/v1/'))return new Response(null,{status:404});
 const table=url.pathname.split('/').at(-1);
 if(!['proxolink_cards','proxolink_publish_attempts','pa_ads'].includes(table))throw Error('unapproved_table');
 const columns=url.searchParams.get('select')?.split(',').map(identifier).join(',')||'*';
 const conditions=[];
 for(const [key,value]of url.searchParams)if(!['select','order','limit'].includes(key)){
  if(value==='is.null')conditions.push(identifier(key)+' IS NULL');
  else if(value.startsWith('eq.'))conditions.push(identifier(key)+'='+quoted(value.slice(3)));
  else if(key==='or'){
   const ids=[...value.matchAll(/(?:asset_id|card_id)\.eq\.([0-9a-f-]{36})/g)].map(m=>m[1]);
   conditions.push('('+ids.map(id=>'asset_id='+quoted(id)+' OR card_id='+quoted(id)).join(' OR ')+')');
  }else if(key==='status'&&value.startsWith('not.in.'))conditions.push("status NOT IN ('completed','rejected','cancelled','canceled','failed')");
  else throw Error('unapproved_query');
 }
 const where=conditions.length?' WHERE '+conditions.join(' AND '):'';
 try{
  if(method==='GET')return Response.json(jsonQuery('SELECT '+columns+' FROM public.'+identifier(table)+where));
  const body=JSON.parse(options.body),entries=Object.entries(body||{}),literal=v=>v===null?'NULL':quoted(typeof v==='object'?JSON.stringify(v):v);
  const query=method==='POST'?'INSERT INTO public.'+identifier(table)+'('+entries.map(([k])=>identifier(k)).join(',')+') VALUES ('+entries.map(([,v])=>literal(v)).join(',')+')':
    method==='DELETE'?'DELETE FROM public.'+identifier(table)+where:
    'UPDATE public.'+identifier(table)+' SET '+entries.map(([k,v])=>identifier(k)+'='+literal(v)).join(',')+where;
  if(options.headers.Prefer==='return=minimal'){sql(query);return new Response(null,{status:method==='POST'?201:204});}
  return Response.json(JSON.parse(sql('WITH changed AS ('+query+' RETURNING '+columns+") SELECT coalesce(jsonb_agg(changed),'[]'::jsonb) FROM changed")),{status:method==='POST'?201:200});
 }catch(error){const code=/ERROR:\s+([A-Z0-9]{5})/.exec(String(error.stderr||''))?.[1];return Response.json({code:code||'fixture_database_failure'},{status:400});}
};
const call=(op,options)=>invoke(handler,op,options),ids=[];
for(const [type,providers]of [['contact',['whatsapp','viber','instagram','telegram','korek','asiacell']],['order',['talabat']],['order',['toters']],['order',['talabat','toters']],['download',['google_play']],['download',['app_store']],['download',['google_play','app_store']]]){
 const payload=pagePayload(type,providers),result=await call('cards',{method:'POST',body:payload});assert.equal(result.status,201,result.body);
 const id=result.json().card.id;ids.push(id);assert.notEqual(id,OWNER);assert.notEqual(id,payload.client_request_id);assert.equal(result.json().card.public_path,`/${type}/${id}`);
 const stored=jsonQuery('SELECT * FROM public.proxolink_cards WHERE id='+quoted(id))[0];assert.equal(stored.user_id,OWNER);assert.equal(stored.page_kind,type);
 assert.equal((await call('cards',{method:'POST',body:payload})).json().card.id,id);
 const rendered=await call(type,{query:{id},auth:null});assert.equal(rendered.status,200);assert.deepEqual(configFromHtml(rendered.body).buttons.map(b=>b.type),providers);
 for(const route of ['contact','order','download'])if(route!==type)assert.equal((await call(route,{query:{id},auth:null})).status,404);
 assert.equal((await call('cards',{method:'PATCH',auth:'other-token',query:{id},body:{name:'takeover',expected_updated_at:stored.updated_at}})).status,403);
 const edit=await call('cards',{method:'PATCH',query:{id},body:{name:'Updated '+type,expected_updated_at:stored.updated_at}});assert.equal(edit.status,200,edit.body);assert.equal(edit.json().card.public_path,`/${type}/${id}`);
 assert.equal((await call('card-action',{method:'POST',body:{card_id:id,action:'deactivate'}})).status,200);
 assert.equal((await call(type,{query:{id},auth:null})).status,404);
 const preview=await call('preview-token',{method:'POST',body:{card_id:id}});assert.equal(preview.status,200);
 const token=new URL(preview.json().preview_path,'https://isolated.test').searchParams.get('preview_token');
 assert.equal(configFromHtml((await call(type,{query:{id,preview_token:token},auth:null})).body).preview,true);
 assert.equal((await call('card-action',{method:'POST',body:{card_id:id,action:'activate'}})).status,200);
 assert.equal((await call('card-action',{method:'POST',body:{card_id:id,action:'delete'}})).status,200);
 assert.equal(jsonQuery('SELECT id FROM public.proxolink_cards WHERE id='+quoted(id)).length,0);
}
assert.equal(new Set(ids).size,7);assert.equal(events,0);
assert.equal(sql("SELECT count(*) FROM public.pa_ads a JOIN public.v6_ad_snapshot s USING(id) WHERE to_jsonb(a)<>s.data"),'0');
console.log('VERIFIED: 7 PostgreSQL-backed API lifecycles; generated UUIDs, ownership, edit stability, typed routes, preview, activate/deactivate, dependency-safe deletion, zero outbound events; legacy advertisements preserved.');
