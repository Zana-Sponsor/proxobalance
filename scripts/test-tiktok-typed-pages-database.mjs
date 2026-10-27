/** Disposable PostgreSQL tests; no production database or provider requests.
 * PGLITE_MODULE=/absolute/node_modules/@electric-sql/pglite/dist/index.js node scripts/test-tiktok-typed-pages-database.mjs
 */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {pagePayload} from '../test/fixtures/proxolink-v6-service.mjs';
import {normalizeSettings} from '../api/_lib/proxolink-pages.js';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const db=new PGlite();let checks=0,number=0;
const read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
const check=(value,message)=>{assert.ok(value,message);checks++;};
const scalar=async(sql,args=[])=> (await db.query(sql,args)).rows[0]?.v;
const user='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222';
const session='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const uuid=()=>crypto.randomUUID();
async function role(name,fn){
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user,session_id:session,role:name})]);
  await db.exec(`set role ${name}`);try{return await fn();}finally{await db.exec('reset role');}
}
const base={title:'Typed page fixture',goal:'messages',category:'other',message_destination:'external_contact',
  age_groups:['all'],gender:'all',location:'kurdistan',device_type:'all',daily_budget:10,days:1,
  start_immediately:true,payment_method:'app_balance',video_code:'actual-code',video_link:'https://www.tiktok.com/@fixture/video/123456789'};
const typed=(type,id)=>({...base,tiktok_ad_type:type,goal:type==='views'?'views':'messages',
  category:type==='restaurant'?'food_beverage':type==='app_download'?'games_apps':'other',...(id?{asset_id:id}:{})});
const buy=(ad,key=uuid())=>role('authenticated',()=>scalar('select public.pa_submit_ad($1,$2::jsonb,10,18000) v',[key,JSON.stringify(ad)]));
const snapshot=()=>scalar(`select jsonb_build_object('balance',(select balance from public.pa_wallets where user_id='${user}'),
  'ads',(select count(*) from public.pa_ads),'ledger',(select count(*) from app_finance.ledger),
  'outbox',(select count(*) from app_finance.outbox),'submissions',(select count(*) from proxo_private.ad_submissions)) v`);
async function seed(kind,owner=user){
  const p=pagePayload(kind??'contact',[kind==='order'?'talabat':kind==='download'?'google_play':'telegram']);
  return scalar(`insert into public.proxolink_cards(user_id,name,card_number,page_kind,settings,client_request_id,
    template_key,template_version,status,publish_status) values($1,$2,$3,$4,$5::jsonb,$6,$7,$8,'active','ready') returning id v`,
    [owner,p.name,++number,kind,JSON.stringify(normalizeSettings(kind??'contact',p.settings)),p.client_request_id,p.template_key,p.template_version]);
}
try {
  await db.exec(await read('test/fixtures/secure-operations-database.sql'));
  await db.exec(await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'));
  await db.exec(`create function public.fastpay_create_order(uuid,text,numeric,text default 'IQD',text default null,text default null,integer default 10,text default null) returns jsonb language sql as $$select '{"legacy_create":true}'::jsonb$$;
    create function public.fastpay_apply_refund(text,numeric,text default null,boolean default true,jsonb default null) returns jsonb language sql as $$select '{"legacy_refund":true}'::jsonb$$;`);
  const checkout=await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
  await db.exec(checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('),checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')));
  for(const name of (await fs.readdir(new URL('../proxo_app/supabase/migrations/',import.meta.url))).filter(n=>/^2026102[23].*\.sql$/.test(n)).sort())
    await db.exec(await read('proxo_app/supabase/migrations/'+name));
  await db.exec(await read('proxo_app/supabase/migrations/20261006220119_proxolink_v6_independent_pages.sql'));
  const core=await scalar("select prosrc v from pg_proc where oid='public.pa_create_ad(jsonb,numeric,uuid,text,numeric)'::regprocedure");
  await db.exec(await read('proxo_app/supabase/migrations/20261025120000_tiktok_typed_page_eligibility.sql'));
  check(core===await scalar("select prosrc v from pg_proc where oid='public.pa_create_ad_before_typed_pages(jsonb,numeric,uuid,text,numeric)'::regprocedure"),'financial core body unchanged');
  for(const name of ['anon','authenticated','service_role'])check(!await scalar("select has_function_privilege($1,'public.pa_create_ad_before_typed_pages(jsonb,numeric,uuid,text,numeric)','EXECUTE') v",[name]),'renamed core inaccessible to '+name);
  for(const name of ['anon','authenticated'])check(!await scalar("select has_function_privilege($1,'public.pa_create_ad(jsonb,numeric,uuid,text,numeric)','EXECUTE') v",[name]),'wrapper remains server-only for '+name);
  await db.query('insert into auth.users(id,email_confirmed_at) values($1,now()),($2,now())',[user,other]);
  await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[session,user]);
  await db.query('insert into public.profiles(id) values($1),($2)',[user,other]);
  await db.query('update public.pa_wallets set balance=1000 where user_id=$1',[user]);
  const contact=await seed('contact'),order=await seed('order'),download=await seed('download'),legacy=await seed(null),foreign=await seed('contact',other);
  const archived=await seed('contact'),failedPage=await seed('contact');
  await db.query('update public.proxolink_cards set archived_at=now() where id=$1',[archived]);
  await db.query("update public.proxolink_cards set publish_status='failed' where id=$1",[failedPage]);
  const before=await snapshot();
  const invalid=[typed('contact',archived),typed('contact',failedPage),typed('contact',order),typed('restaurant',contact),typed('app_download',order),typed('restaurant',legacy),
    typed('contact',foreign),typed('contact',uuid()),typed('contact','bad-id'),typed('views',contact),
    {...typed('restaurant',order),category:'other'},{...typed('contact',contact),goal:'views'},
    {...typed('contact',contact),tiktok_ad_type:null}];
  for(const ad of invalid)check(['INVALID_ASSET','INVALID_AD_TYPE'].includes((await buy(ad)).code),'mismatched/foreign/malformed typed asset rejected');
  assert.deepEqual(await snapshot(),before);checks++;
  const key=uuid(),first=await buy(typed('contact',contact),key);check(first.ok,'contact accepted');
  assert.deepEqual(await buy(typed('contact',contact),key),first);checks++;
  for(const [type,id] of [['restaurant',order],['app_download',download],['views',null],['contact',legacy]])check((await buy(typed(type,id))).ok,type+' accepted with authoritative page kind');
  const after=await snapshot();check(after.ads===5&&after.outbox===5&&Number(after.balance)===950,'five accepted types have exactly five ads/outbox/debits');
  check(await scalar("select request->'ad'->>'tiktok_ad_type'='contact' v from proxo_private.ad_submissions where submission_id=$1",[key]),'typed request persisted with immutable submission');
  await db.query("update public.proxolink_cards set status='inactive' where id=$1",[contact]);
  assert.deepEqual(await buy(typed('contact',contact),key),first);checks++;
  check((await buy(typed('contact',contact))).code==='INVALID_ASSET','fresh purchase refuses now inactive page');
  // Old payloads keep the original contract, including their historical lack
  // of kind filtering. No old pending attempt is reinterpreted as a new flow.
  check((await buy({...base,asset_id:order})).ok,'legacy request delegates unchanged');
  // Reset only synthetic rate counters before the failure injection.
  await db.exec('delete from app_finance.request_limits');
  const atomicBefore=await snapshot();
  await db.exec("create function app_finance.fixture_typed_fail() returns trigger language plpgsql as $$begin raise exception 'typed_outbox_failure';end$$; create trigger fixture_typed_fail before insert on app_finance.outbox for each row execute function app_finance.fixture_typed_fail()");
  let failed=false;try{await buy(typed('restaurant',order));}catch(e){failed=e.message.includes('typed_outbox_failure');}
  check(failed,'failure injected after financial core reaches outbox');
  assert.deepEqual(await snapshot(),atomicBefore);checks++;
  console.log(`VERIFIED: ${checks} PostgreSQL checks: type/owner/status filtering, null legacy adapter, unchanged core and grants, idempotent purchase, exact debit/outbox count, injected failure atomic rollback.`);
} finally {await db.close();}
