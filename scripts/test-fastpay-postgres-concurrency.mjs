/** Real overlapping PostgreSQL sessions. Only a fresh, local synthetic DB. */
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {fastpayDatabaseFixtureSql,legacyCheckoutMigrationSql} from './fastpay-database-fixture.mjs';

const host=process.env.PGHOST,port=process.env.PGPORT,database=process.env.PGDATABASE,userName=process.env.PGUSER;
if(!['127.0.0.1','localhost','::1'].includes(host)||database!=='fastpay_concurrency_test'||userName!=='postgres'||!/^\d{1,5}$/.test(port??'')||Number(port)<1||Number(port)>65535)
 throw new Error('Local synthetic database required: PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGDATABASE=fastpay_concurrency_test');
const children=new Set();let checks=0;
const check=(value,label)=>{assert.ok(value,label);checks++;};
const literal=value=>"'"+String(value).replaceAll("'","''")+"'";
const jsonLiteral=value=>literal(JSON.stringify(value))+'::jsonb';
const user='11111111-1111-4111-8111-111111111111';
const payload={amount_iqd:18000,currency:'IQD',environment:'sandbox',merchant_reference:'fixture-merchant',expires_in:10,
 success_url:'https://example.invalid/success',cancel_url:'https://example.invalid/cancel',callback_url:'https://example.invalid/ipn',purpose:'wallet_deposit',note:'concurrency fixture'};
const checkoutSql=order=>`select public.pa_legacy_fastpay_checkout('prepare',${literal(user)},${literal(order)},${jsonLiteral(payload)});`;
const asService=sql=>`set role service_role;${sql}`;
const parseResult=output=>JSON.parse(output.trim().split('\n').find(line=>line.startsWith('{')));

function session(name,sql,{hold=false,timeoutMs=30000}={}){
 // Do not inherit PG service files, PGOPTIONS, remote connection strings, or
 // other libpq routing options. All connection arguments are explicit.
 const child=spawn('psql',['-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-h',host,'-p',port,'-U',userName,'-d',database],{
  env:{PATH:process.env.PATH,LANG:'C',LC_ALL:'C',PGPASSWORD:process.env.PGPASSWORD??'',PGSSLMODE:'disable',PGCONNECT_TIMEOUT:'5',
   PGAPPNAME:name,PGOPTIONS:'-c statement_timeout=20000 -c lock_timeout=15000'},stdio:['pipe','pipe','pipe'],
 });
 children.add(child);let output='',errors='',readyResolve,readyReject,ended=false;
 const ready=new Promise((resolve,reject)=>{readyResolve=resolve;readyReject=reject;});
 // A non-held session does not expose ready, but still handles early failures.
 ready.catch(()=>{});
 const timer=setTimeout(()=>child.kill('SIGTERM'),timeoutMs);
 const done=new Promise((resolve,reject)=>{
  child.stdout.on('data',chunk=>{output+=chunk.toString();if(output.includes('FASTPAY_LOCK_READY'))readyResolve();});
  child.stderr.on('data',chunk=>{errors+=chunk.toString();});
  child.on('error',error=>{ended=true;clearTimeout(timer);children.delete(child);readyReject(error);reject(error);});
  child.on('close',code=>{ended=true;clearTimeout(timer);children.delete(child);
   if(code===0){readyResolve();resolve(output);}else{const error=new Error(`psql ${name} failed (${code}): ${errors.slice(-5000)}`);readyReject(error);reject(error);}
  });
 });
 done.catch(()=>{});
 child.stdin.on('error',()=>{});
 if(hold)child.stdin.write(sql+'\n\\echo FASTPAY_LOCK_READY\n');else child.stdin.end(sql+'\n');
 return {ready,done,release(){if(!ended)child.stdin.end('commit;\n\\q\n');},stop(){child.kill('SIGTERM');}};
}
const query=sql=>session('fastpay-fixture-control',sql).done;
async function waitForLocks(names){
 const deadline=Date.now()+10000;
 while(Date.now()<deadline){
  const count=Number((await query(`select count(*) from pg_stat_activity where application_name in (${names.map(literal).join(',')}) and state='active' and wait_event_type='Lock';`)).trim());
  if(count===names.length){checks++;return;}
  await new Promise(resolve=>setTimeout(resolve,75));
 }
 throw new Error('Concurrent sessions did not reach the expected database lock');
}

async function seedAttempt(suffix){
 // These are deliberately synthetic SQL fixtures, not a bypass available to
 // clients. Service actions then exercise the real lock/closure functions.
 const id=`aaaaaaaa-aaaa-4aaa-8aaa-${suffix.padStart(12,'0')}`;
 const tx=`bbbbbbbb-bbbb-4bbb-8bbb-${suffix.padStart(12,'0')}`;
 const quote=`cccccccc-cccc-4ccc-8ccc-${suffix.padStart(12,'0')}`;
 const order='AP'+suffix.padStart(28,'0');
 await query(`
 insert into app_meta.quotes(id,user_id,connection_id,configuration,config_hash,evidence,forecast,pricing,payable_minor,amount_iqd,rate)
 values(${literal(quote)},${literal(user)},'dddddddd-dddd-4ddd-8ddd-dddddddddddd','{}',repeat('a',64),'{}','{}','{}',1000,18000,1800);
 insert into public.pa_transactions(id,user_id,amount,method,kind,type,status,gateway,gateway_status,fastpay_order_id,currency,gateway_amount,fx_rate,meta_quote_id,expires_at)
 values(${literal(tx)},${literal(user)},10,'fastpay','deposit','deposit','pending','fastpay','CREATED',${literal(order)},'IQD',18000,1800,${literal(quote)},now()+interval '10 minutes');
 insert into app_finance.ad_payment_attempts(id,user_id,submission_id,platform,meta_quote_id,order_id,payment_transaction_id,environment,merchant_reference,configuration,pricing,evidence,cost_usd,amount_iqd,fx_rate)
 values(${literal(id)},${literal(user)},gen_random_uuid(),'META',${literal(quote)},${literal(order)},${literal(tx)},'sandbox','fixture-merchant','{}','{}','{}',10,18000,1800);
 `);
 return {id,tx};
}

try{
 const fresh=(await query(`select current_database()='fastpay_concurrency_test'
  and not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname not in ('pg_catalog','information_schema') and n.nspname not like 'pg_toast%' and c.relkind in ('r','p','v','m','f'))
  and not exists(select 1 from pg_roles where rolname in ('anon','authenticated','service_role'));`)).trim();
 check(fresh==='t','requires fresh dedicated local database and roles');
 await session('fastpay-fixture-install',(await fastpayDatabaseFixtureSql())+'\n'+(await legacyCheckoutMigrationSql()),{timeoutMs:60000}).done;
 await query(`insert into auth.users(id,email_confirmed_at) values(${literal(user)},now());insert into public.profiles(id) values(${literal(user)});`);

 const gate=session('fastpay-prepare-gate',"begin;select pg_advisory_xact_lock(hashtextextended('legacy-fastpay:concurrent-order',0));",{hold:true});
 await gate.ready;
 const creates=[session('fastpay-prepare-a',asService(checkoutSql('concurrent-order'))),session('fastpay-prepare-b',asService(checkoutSql('concurrent-order')))];
 await waitForLocks(['fastpay-prepare-a','fastpay-prepare-b']);gate.release();await gate.done;
 const prepared=(await Promise.all(creates.map(s=>s.done))).map(parseResult);
 check(prepared.every(r=>r.ok)&&prepared.filter(r=>r.create_authorized===true).length===1,'simultaneous same-order prepare authorizes exactly one gateway creation');
 check(prepared[0].transaction_id===prepared[1].transaction_id&&prepared[0].request_hash===prepared[1].request_hash,'competing prepares recover the same receipt and fingerprint');
 check((await query("select (select count(*)=1 from public.pa_transactions where fastpay_order_id='concurrent-order') and (select count(*)=1 from app_finance.legacy_fastpay_checkouts) and (select count(*)=0 from app_finance.ledger) and (select balance=0 from public.pa_wallets limit 1);")).trim()==='t','simultaneous preparation creates one pending receipt and no credit');

 const paidGate=session('fastpay-paid-gate',"begin;select id from public.pa_transactions where fastpay_order_id='concurrent-order' for update;",{hold:true});await paidGate.ready;
 const paidSql="select public.fastpay_mark_paid('concurrent-order','concurrent-gateway-proof',18000,'IQD');";
 const payments=[session('fastpay-paid-a',asService(paidSql)),session('fastpay-paid-b',asService(paidSql))];
 await waitForLocks(['fastpay-paid-a','fastpay-paid-b']);paidGate.release();await paidGate.done;
 const funded=(await Promise.all(payments.map(s=>s.done))).map(parseResult);
 check(funded.every(r=>r.ok)&&funded.filter(r=>r.duplicate===true).length===1,'simultaneous identical paid callbacks produce one credit and one replay');
 check((await query("select (select balance=10 from public.pa_wallets limit 1) and (select count(*)=1 and sum(amount)=10 from app_finance.ledger) and (select wallet_credited and status='approved' from public.pa_transactions where fastpay_order_id='concurrent-order');")).trim()==='t','simultaneous callbacks preserve exactly one wallet and ledger credit');

 await query(`update app_finance.ad_payment_settings set enabled=true,merchant_reference='fixture-merchant';
 insert into app_meta.connections(id,user_id,status,ad_account_id,page_id,access_token_env,verified_at,expires_at)
 values('dddddddd-dddd-4ddd-8ddd-dddddddddddd',${literal(user)},'authorized','act_123','123','META_FIXTURE_TOKEN',now(),now()+interval '1 hour');`);
 for(const first of ['close_unstarted','create_intent']){
  const attempt=await seedAttempt(first==='close_unstarted'?'1':'2');
  const actionSql=action=>`select public.pa_ad_payment_service(${literal(action)},${literal(attempt.id)},${jsonLiteral(action==='create_intent'?{request_hash:'c'.repeat(64)}:{error_code:'FASTPAY_CONFIG_UNAVAILABLE'})});`;
  const winner=session('fastpay-ad-winner','begin;'+asService(actionSql(first)),{hold:true});await winner.ready;
  const second=first==='close_unstarted'?'create_intent':'close_unstarted';
  const loser=session('fastpay-ad-contender',asService(actionSql(second)));
  await waitForLocks(['fastpay-ad-contender']);winner.release();
  const [won,lost]=(await Promise.all([winner.done,loser.done])).map(parseResult);
  if(first==='close_unstarted'){
   check(won.payment_not_started===true&&lost.create_authorized!==true&&lost.payment_not_started===true,'committed no-intent closure wins against overlapping creation');
   check((await query(`select status='rejected' and gateway_status='CANCELLED' and not wallet_credited from public.pa_transactions where id=${literal(attempt.tx)};`)).trim()==='t','closure winner corrects original unpaid receipt');
  }else{
   check(won.create_authorized===true&&lost.payment_not_started===false&&lost.status==='creating','committed creation prevents overlapping closure from exposing absence proof');
   check((await query(`select status='pending' and gateway_status='CREATED' and not wallet_credited from public.pa_transactions where id=${literal(attempt.tx)};`)).trim()==='t','creation winner remains eligible for late verification');
  }
 }
 console.log(`FastPay PostgreSQL concurrency tests: ${checks} assertions passed across real overlapping sessions`);
}finally{
 for(const child of children)child.kill('SIGTERM');
}
