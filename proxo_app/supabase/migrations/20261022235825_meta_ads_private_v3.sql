-- Private Meta v3 pilot. Deliberately OFF. Review/apply only in a disposable DB
-- before a separately authorized production rollout. No provider calls occur here.
begin;
create schema if not exists app_meta;
revoke all on schema app_meta from public,anon,authenticated;
grant usage on schema app_meta to authenticated,service_role;

create table app_meta.settings (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 fastpay_enabled boolean not null default false,
 updated_at timestamptz not null default now()
);
insert into app_meta.settings(singleton) values(true);
create table app_meta.testers (
 user_id uuid primary key references auth.users(id) on delete cascade,
 enabled boolean not null default false,
 expires_at timestamptz,
 created_at timestamptz not null default now()
);
-- These are verified account references, never bearer tokens or client claims.
create table app_meta.connections (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null check(status in ('authorized','revoked')),
 ad_account_id text not null check(ad_account_id ~ '^(act_)?[0-9]+$'),
 page_id text not null check(page_id ~ '^[0-9]+$'),
 instagram_account_id text check(instagram_account_id ~ '^[0-9]+$'),
 whatsapp_phone_number_id text check(whatsapp_phone_number_id ~ '^[0-9]+$'),
 access_token_env text not null check(access_token_env ~ '^META_[A-Z0-9_]{1,100}$'),
 capabilities jsonb not null default '{}' check(jsonb_typeof(capabilities)='object'),
 verified_at timestamptz not null,
 expires_at timestamptz not null,
 created_at timestamptz not null default now(),
 check(expires_at>verified_at)
);
create unique index meta_one_authorized_connection on app_meta.connections(user_id) where status='authorized';
create table app_meta.quotes (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 connection_id uuid not null references app_meta.connections(id),
 configuration jsonb not null check(jsonb_typeof(configuration)='object'),
 config_hash text not null check(config_hash ~ '^[a-f0-9]{64}$'),
 evidence jsonb not null check(jsonb_typeof(evidence)='object'),
 forecast jsonb not null,
 pricing jsonb not null,
 payable_minor bigint not null check(payable_minor>0),
 amount_iqd bigint not null check(amount_iqd>0),
 rate numeric(20,6) not null check(rate>0),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default(now()+interval '5 minutes')
);
create index meta_quotes_owner on app_meta.quotes(user_id,created_at desc);
alter table public.pa_ads add column if not exists platform text;
alter table public.pa_ads add column if not exists meta_configuration jsonb;
alter table public.pa_ads add column if not exists meta_quote_id uuid references app_meta.quotes(id);
alter table public.pa_ads add column if not exists meta_start_at timestamptz;
alter table public.pa_ads add column if not exists meta_end_at timestamptz;
alter table public.pa_ads add column if not exists meta_provider_status text;
alter table public.pa_ads add column if not exists meta_review_status text;
alter table public.pa_ads add column if not exists meta_status_checked_at timestamptz;
alter table public.pa_ads add column if not exists meta_metrics_checked_at timestamptz;
alter table public.pa_ads add column if not exists provider_metrics_available jsonb not null default '[]'::jsonb;
alter table public.pa_ads add constraint pa_ads_platform_v3 check(platform is null or platform in ('META','TIKTOK'));
-- The legacy TikTok URL guard continues to apply to every non-Meta record.
alter table public.pa_ads drop constraint if exists pa_ads_tiktok_video_link_valid;
alter table public.pa_ads add constraint pa_ads_tiktok_video_link_valid check(
 (platform='META' and video_link ~* '^https://(www\.|m\.|web\.)?(facebook\.com|instagram\.com|fb\.watch)/')
 or (platform is distinct from 'META' and video_link ~* '^https://([[:alnum:]-]+\.)*tiktok\.com([/:?#]|$)')
) not valid;
create unique index meta_quote_consumed_once on public.pa_ads(meta_quote_id) where meta_quote_id is not null;
create table app_meta.jobs (
 id uuid primary key default gen_random_uuid(),
 ad_id uuid not null unique references public.pa_ads(id),
 user_id uuid not null references auth.users(id),
 quote_id uuid not null unique references app_meta.quotes(id),
 status text not null default 'queued' check(status in ('queued','leased','paused','reconcile','refund_pending','refunded')),
 stages jsonb not null default '{}',
 terminal_failure boolean not null default false,
 provider_ids jsonb not null default '{}',
 observation jsonb,
 attempts integer not null default 0,
 lease_token uuid,
 lease_kind text,
 lease_until timestamptz,
 available_at timestamptz not null default now(),
 last_error_code text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index meta_jobs_due on app_meta.jobs(status,available_at);
create index meta_jobs_owner on app_meta.jobs(user_id,created_at desc);

create function app_meta.immutable_quote() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'META_QUOTE_IMMUTABLE'; end $$;
create trigger meta_quote_immutable before update or delete on app_meta.quotes for each row execute function app_meta.immutable_quote();
create function app_meta.immutable_ad_snapshot() returns trigger language plpgsql set search_path='' as $$
begin
 if (old.platform='META' or new.platform='META') and
  (old.platform is distinct from new.platform or old.meta_configuration is distinct from new.meta_configuration or
   old.meta_quote_id is distinct from new.meta_quote_id or old.meta_start_at is distinct from new.meta_start_at or
   old.meta_end_at is distinct from new.meta_end_at or old.total_budget is distinct from new.total_budget or
   old.charged_price_iqd is distinct from new.charged_price_iqd or old.receipt_uid is distinct from new.receipt_uid) then
  raise exception 'META_ORDER_SNAPSHOT_IMMUTABLE';
 end if;
 return new;
end $$;
create trigger meta_ad_snapshot_immutable before update on public.pa_ads for each row execute function app_meta.immutable_ad_snapshot();

create function app_meta.allowed(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select s.enabled and t.enabled and (t.expires_at is null or t.expires_at>now())
 from app_meta.settings s join app_meta.testers t on t.user_id=p_user where s.singleton),false)
 and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_user
 and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null) and not coalesce(p.is_banned,false));
$$;
create function app_meta.capabilities() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); begin
 return jsonb_build_object('ok',true,'meta_enabled',app_meta.allowed(u),'meta_public_enabled',false,
  'meta_fastpay_enabled',app_meta.allowed(u) and (select fastpay_enabled from app_meta.settings where singleton),
  'meta_paid_activation_enabled',false,'server_time',clock_timestamp());
end $$;
create function public.pa_ad_capabilities() returns jsonb language sql security invoker set search_path='' as $$select app_meta.capabilities();$$;

-- Defense in depth: the authenticated acceptance function does not trust an API
-- request to normalize arrays, money, schedule, or platform routing correctly.
create function app_meta.valid_configuration(c jsonb,p_future boolean default true) returns boolean
language plpgsql stable set search_path='' as $$
declare config_key text; daily numeric; days integer; p jsonb; d jsonb; n integer; start_at timestamptz;
begin
 if c is null or jsonb_typeof(c)<>'object' or octet_length(c::text)>16384 then return false; end if;
 for config_key in select jsonb_object_keys(c) loop
  if config_key not in ('schema_version','platform','ad_name','objective','page_url','post_url','placements','destinations','currency','budget_daily','duration_days','payment_method','schedule','targeting') then return false; end if;
 end loop;
 if c->>'schema_version' is distinct from '3' or c->>'platform' is distinct from 'META'
 or c->>'currency' is distinct from 'USD' or coalesce(c->>'objective','') not in ('MESSAGES','VIDEO_VIEWS','VIDEO_ENGAGEMENT')
 or coalesce(c->>'payment_method','') not in ('WALLET','FASTPAY') or char_length(btrim(coalesce(c->>'ad_name',''))) not between 1 and 120
 or coalesce(c->>'page_url','') !~ '^https://(www\.|m\.|web\.)?facebook\.com/[^[:space:]@]+'
 or coalesce(c->>'post_url','') !~ '^https://((www\.|m\.|web\.)?facebook\.com/|(www\.)?instagram\.com/(p|reel|tv)/|fb\.watch/)[^[:space:]@]+' then return false; end if;
 if jsonb_typeof(c->'budget_daily') is distinct from 'number' or jsonb_typeof(c->'duration_days') is distinct from 'number' then return false; end if;
 daily:=(c->>'budget_daily')::numeric; days:=(c->>'duration_days')::integer;
 if daily not between 2 and 1000 or daily<>round(daily,2) or days not between 1 and 7 or (c->>'duration_days')::numeric<>days then return false; end if;
 p:=c->'placements'; d:=c->'destinations';
 if jsonb_typeof(p) is distinct from 'array' or jsonb_array_length(p) not between 1 and 2 then return false; end if;
 select count(distinct value) into n from jsonb_array_elements_text(p);
 if n<>jsonb_array_length(p) or exists(select 1 from jsonb_array_elements_text(p) where value not in ('facebook','instagram')) then return false; end if;
 if c->>'objective'='MESSAGES' then
  if jsonb_typeof(d) is distinct from 'array' or jsonb_array_length(d) not between 1 and 3 then return false; end if;
  select count(distinct value) into n from jsonb_array_elements_text(d);
  if n<>jsonb_array_length(d) or exists(select 1 from jsonb_array_elements_text(d) where value not in ('WHATSAPP','MESSENGER','INSTAGRAM_DIRECT'))
   or (d ? 'MESSENGER' and not p ? 'facebook') or (d ? 'INSTAGRAM_DIRECT' and not p ? 'instagram') then return false; end if;
 elsif c ? 'destinations' then return false; end if;
 if jsonb_typeof(c->'schedule') is distinct from 'object' or c#>>'{schedule,timezone}' is distinct from 'Asia/Baghdad'
 or coalesce(c#>>'{schedule,mode}','') not in ('IMMEDIATE','SCHEDULED')
 or exists(select 1 from jsonb_object_keys(c->'schedule') k where k not in ('mode','timezone','start_at')) then return false; end if;
 if c#>>'{schedule,mode}'='IMMEDIATE' then
  if (c->'schedule') ? 'start_at' then return false; end if;
 else
  if coalesce(c#>>'{schedule,start_at}','') !~ '(Z|[+-][0-9]{2}:[0-9]{2})$' then return false; end if;
  start_at:=(c#>>'{schedule,start_at}')::timestamptz;
  if p_future and (start_at<=now() or start_at>now()+interval '90 days') then return false; end if;
 end if;
 if jsonb_typeof(c->'targeting') is distinct from 'object'
 or exists(select 1 from jsonb_object_keys(c->'targeting') k where k not in ('location','gender','age_min','age_max'))
 or coalesce(c#>>'{targeting,location}','') not in ('all','erbil','sulaymaniyah','duhok','baghdad')
 or coalesce(c#>>'{targeting,gender}','') not in ('ALL','MALE','FEMALE')
 or coalesce((c#>>'{targeting,age_min}')::numeric,0) not between 18 and 65
 or coalesce((c#>>'{targeting,age_max}')::numeric,0) not between (c#>>'{targeting,age_min}')::numeric and 65
 or (c#>>'{targeting,age_min}')::numeric<>trunc((c#>>'{targeting,age_min}')::numeric)
 or (c#>>'{targeting,age_max}')::numeric<>trunc((c#>>'{targeting,age_max}')::numeric) then return false; end if;
 return true;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or invalid_datetime_format then return false;
end $$;

create function app_meta.quote_result(q app_meta.quotes) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('ok',true,'quote_id',q.id,'configuration',q.configuration,'evidence',q.evidence,'forecast',q.forecast,
 'config_hash',q.config_hash,'pricing',q.pricing,'expires_at',q.expires_at,'server_time',clock_timestamp(),
 'gross_usd',q.payable_minor::numeric/100,'cost_usd',q.payable_minor::numeric/100,'rate',q.rate,'amount_iqd',q.amount_iqd,
 'balance_usd',coalesce((select balance from public.pa_wallets where user_id=q.user_id),0),
 'promo_discount_usd',0,'level_discount_usd',0);
$$;
create function app_meta.job_result(j app_meta.jobs) returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(j)||jsonb_build_object('configuration',q.configuration,'evidence',q.evidence,'pricing',q.pricing,
 'config_hash',q.config_hash,'connection',to_jsonb(c),'start_at',a.meta_start_at,'end_at',a.meta_end_at)
 from app_meta.quotes q join app_meta.connections c on c.id=q.connection_id join public.pa_ads a on a.id=j.ad_id where q.id=j.quote_id;
$$;

create function app_meta.accept(p_submission_id uuid,p_quote_id uuid,p_configuration jsonb,p_expected_total_minor bigint,p_expected_total_iqd bigint,p_payment_transaction_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); req jsonb; previous proxo_private.ad_submissions%rowtype; q app_meta.quotes%rowtype;
 conn app_meta.connections%rowtype; ad public.pa_ads%rowtype; tx public.pa_transactions%rowtype;
 result jsonb; cost numeric(20,6); balance numeric(20,6); starts timestamptz; ends timestamptz; receipt uuid:=gen_random_uuid(); job_id uuid:=gen_random_uuid(); method text;
begin
 if p_submission_id is null then return jsonb_build_object('ok',false,'code','INVALID_INPUT'); end if;
 req:=jsonb_build_object('platform','META','quote_id',p_quote_id,'configuration',p_configuration,
 'expected_total_minor',p_expected_total_minor,'expected_total_iqd',p_expected_total_iqd,'payment_transaction_id',p_payment_transaction_id);
 perform pg_advisory_xact_lock(hashtextextended(u::text||':'||p_submission_id::text,0));
 select * into previous from proxo_private.ad_submissions where user_id=u and submission_id=p_submission_id;
 if found then
  if previous.request is distinct from req then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT'); end if;
  return previous.result;
 end if;
 if not app_meta.allowed(u) then return jsonb_build_object('ok',false,'code','META_DISABLED'); end if;
 if not app_finance.rate_allowed(u,'meta_accept',20) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
 perform public.pa_assert_ad_allowed(u);
 if not app_meta.valid_configuration(p_configuration) then return jsonb_build_object('ok',false,'code','INVALID_CONFIGURATION'); end if;
 select * into q from app_meta.quotes where id=p_quote_id and user_id=u for update;
 if not found then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND'); end if;
 if q.expires_at<=now() then return jsonb_build_object('ok',false,'code','QUOTE_EXPIRED'); end if;
 if q.configuration is distinct from p_configuration or q.payable_minor is distinct from p_expected_total_minor or q.amount_iqd is distinct from p_expected_total_iqd then
  return jsonb_build_object('ok',false,'code','QUOTE_CHANGED'); end if;
 if exists(select 1 from public.pa_ads where meta_quote_id=q.id) then return jsonb_build_object('ok',false,'code','QUOTE_ALREADY_USED'); end if;
 select * into conn from app_meta.connections where id=q.connection_id and user_id=u and status='authorized' and expires_at>now() for share;
 if not found then return jsonb_build_object('ok',false,'code','CONNECTION_EXPIRED'); end if;
 cost:=q.payable_minor::numeric/100;
 method:=case when p_configuration->>'payment_method'='FASTPAY' then 'fastpay' else 'app_balance' end;
 if method='fastpay' then
  if not (select fastpay_enabled from app_meta.settings where singleton) then return jsonb_build_object('ok',false,'code','META_FASTPAY_UNAVAILABLE'); end if;
  select * into tx from public.pa_transactions where id=p_payment_transaction_id and user_id=u for update;
  if not found or tx.gateway is distinct from 'fastpay' or tx.method is distinct from 'fastpay' or tx.status is distinct from 'approved'
   or tx.gateway_status is distinct from 'PAID' or not tx.wallet_credited or tx.ad_id is not null or tx.amount is distinct from cost
   or tx.gateway_amount is distinct from q.amount_iqd or tx.fx_rate is distinct from q.rate
   or tx.meta_quote_id is distinct from q.id then
   return jsonb_build_object('ok',false,'code','PAYMENT_NOT_VERIFIED'); end if;
 elsif p_payment_transaction_id is not null then return jsonb_build_object('ok',false,'code','UNEXPECTED_PAYMENT_TRANSACTION'); end if;
 balance:=public.pa_lock_wallet(u);
 if balance<cost then return jsonb_build_object('ok',false,'code','INSUFFICIENT_FUNDS','balance',balance,'required',cost); end if;
 starts:=case when p_configuration#>>'{schedule,mode}'='IMMEDIATE' then clock_timestamp() else (p_configuration#>>'{schedule,start_at}')::timestamptz end;
 ends:=starts+make_interval(hours=>24*(p_configuration->>'duration_days')::integer);
 insert into public.pa_ads(user_id,ad_number,status,title,goal,category,age_groups,gender,location,daily_budget,budget,days,total_budget,
 video_link,start_date,start_time,end_date,target_age,target_gender,target_location,service_type,platform,charged_price_iqd,charged_usd_iqd_rate,
 effective_usd_iqd_rate,usd_iqd_rate,service_budget_usd,pricing_source,payment_method,payment_status,payment_transaction_id,receipt_uid,
 meta_configuration,meta_quote_id,meta_start_at,meta_end_at,pricing_total_iqd_snapshot,pricing_ad_budget_iqd_snapshot,pricing_service_fee_iqd_snapshot,
 pricing_discount_iqd_snapshot,pricing_daily_iqd_snapshot,pricing_usd_iqd_rate_snapshot,pricing_days_snapshot,pricing_payment_method_snapshot,pricing_snapshot_at)
 values(u,'TEMP00000000',case when starts>now()+interval '5 minutes' then 'scheduled' else 'pending' end,p_configuration->>'ad_name',p_configuration->>'objective',
 'other',jsonb_build_array((p_configuration#>>'{targeting,age_min}')||'-'||(p_configuration#>>'{targeting,age_max}')),lower(p_configuration#>>'{targeting,gender}'),p_configuration#>>'{targeting,location}',(p_configuration->>'budget_daily')::numeric,
 cost,(p_configuration->>'duration_days')::integer,cost,p_configuration->>'post_url',(starts at time zone 'Asia/Baghdad')::date,
 (starts at time zone 'Asia/Baghdad')::time,(ends at time zone 'Asia/Baghdad')::date,p_configuration->'targeting',lower(p_configuration#>>'{targeting,gender}'),
 p_configuration#>>'{targeting,location}','meta','META',q.amount_iqd,q.rate,q.rate,q.rate,cost,'meta_v3_immutable_quote',method,'paid',p_payment_transaction_id,
 receipt,p_configuration,q.id,starts,ends,q.amount_iqd,q.amount_iqd,0,0,round((p_configuration->>'budget_daily')::numeric*q.rate),q.rate,
 (p_configuration->>'duration_days')::integer,method,now()) returning * into ad;
 update public.pa_wallets set balance=pa_wallets.balance-cost,updated_at=now() where user_id=u returning pa_wallets.balance into balance;
 if method='fastpay' then update public.pa_transactions set ad_id=ad.id,ad_public_id=ad.public_ad_id,ad_title=ad.title,updated_at=now() where id=tx.id; end if;
 insert into public.pa_transactions(id,user_id,type,kind,method,status,amount,currency,note,balance_after,ad_id,ad_public_id,ad_title)
 values(receipt,u,'ad_payment','ad_payment',method,'approved',cost,'USD',format('ڕیکلام: %s | ئایدی ڕیکلام: %s',ad.title,ad.public_ad_id),balance,ad.id,ad.public_ad_id,ad.title);
 insert into app_meta.jobs(id,ad_id,user_id,quote_id) values(job_id,ad.id,u,q.id);
 result:=jsonb_build_object('ok',true,'platform','META','ad_id',ad.id,'ad_number',ad.public_ad_id,'public_ad_id',ad.public_ad_id,
 'status',ad.status,'payment_method',method,'payment_status','paid','payment_transaction_id',p_payment_transaction_id,'receipt_uid',receipt,
 'charged_usd',cost,'charged_iqd',q.amount_iqd,'rate',q.rate,'gross_usd',cost,'promo_discount_usd',0,'level_discount_usd',0,'balance_after',balance,
 'job_id',job_id,'start_at',starts,'end_at',ends,'quote_id',q.id);
 insert into proxo_private.ad_submissions(user_id,submission_id,request,result) values(u,p_submission_id,req,result);
 return result;
end $$;
create function public.pa_meta_accept(p_submission_id uuid,p_quote_id uuid,p_configuration jsonb,p_expected_total_minor bigint,p_expected_total_iqd bigint,p_payment_transaction_id uuid default null)
returns jsonb language sql security invoker set search_path='' as $$select app_meta.accept(p_submission_id,p_quote_id,p_configuration,p_expected_total_minor,p_expected_total_iqd,p_payment_transaction_id);$$;

create function app_meta.service(p_action text,p_user_id uuid default null,p_id uuid default null,p_token uuid default null,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare conn app_meta.connections%rowtype; q app_meta.quotes%rowtype; j app_meta.jobs%rowtype;
 ad public.pa_ads%rowtype; debit public.pa_transactions%rowtype; c jsonb; e jsonb; f jsonb; price jsonb;
 daily bigint; total bigint; fx numeric; st text; kind text; stage_data jsonb; result jsonb; credit uuid; balance numeric(20,6); safe boolean; hash text; observed_at timestamptz;
begin
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>65536 then return jsonb_build_object('ok',false,'code','INVALID_INPUT'); end if;
 if p_action='gate' then
  if not app_meta.allowed(p_user_id) then return jsonb_build_object('ok',false,'code','META_DISABLED'); end if;
  if not app_finance.rate_allowed(p_user_id,'meta_preflight',30) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
  return jsonb_build_object('ok',true,'enabled',true,'paid_activation_enabled',false);
 end if;
 if p_action='connection' then
  if not app_meta.allowed(p_user_id) then return jsonb_build_object('ok',false,'code','META_DISABLED'); end if;
  select * into conn from app_meta.connections where user_id=p_user_id and status='authorized' and expires_at>now();
  if not found then return jsonb_build_object('ok',false,'code','CONNECTION_REQUIRED'); end if;
  return jsonb_build_object('ok',true,'connection',to_jsonb(conn));
 end if;
 if p_action='store_quote' then
  if not app_meta.allowed(p_user_id) then return jsonb_build_object('ok',false,'code','META_DISABLED'); end if;
  if not app_finance.rate_allowed(p_user_id,'meta_quote',30) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
  c:=p_payload->'configuration'; e:=p_payload->'evidence'; f:=p_payload->'forecast';
  if not app_meta.valid_configuration(c) then return jsonb_build_object('ok',false,'code','INVALID_CONFIGURATION'); end if;
  select * into conn from app_meta.connections where user_id=p_user_id and status='authorized' and expires_at>now() for share;
  if not found then return jsonb_build_object('ok',false,'code','CONNECTION_REQUIRED'); end if;
  if jsonb_typeof(e) is distinct from 'object' or e->>'authorized' is distinct from 'true' or e->>'ready' is distinct from 'true'
   or e->>'connection_id' is distinct from conn.id::text then return jsonb_build_object('ok',false,'code','PREFLIGHT_REQUIRED'); end if;
  if c->>'payment_method'='FASTPAY' and not (select fastpay_enabled from app_meta.settings where singleton) then return jsonb_build_object('ok',false,'code','META_FASTPAY_UNAVAILABLE'); end if;
  daily:=((c->>'budget_daily')::numeric*100)::bigint; total:=daily*(c->>'duration_days')::integer; fx:=public.fastpay_rate();
  if fx is null or fx<=0 or fx::text in ('NaN','Infinity','-Infinity') then return jsonb_build_object('ok',false,'code','PRICING_UNAVAILABLE'); end if;
  price:=jsonb_build_object('currency','USD','daily_budget_minor',daily,'duration_days',(c->>'duration_days')::integer,
   'media_budget_minor',total,'adjustments','[]'::jsonb,'payable_minor',total,'amount_iqd',round(total::numeric/100*fx),'rate',fx);
  hash:=p_payload->>'config_hash';
  if coalesce(hash,'') !~ '^[a-f0-9]{64}$' then return jsonb_build_object('ok',false,'code','INVALID_FINGERPRINT'); end if;
  if f is null or jsonb_typeof(f)<>'object' then f:=jsonb_build_object('status','UNAVAILABLE','reason','SUPPORTED_ESTIMATE_NOT_AVAILABLE','horizon','CAMPAIGN','reach',null,'results',null); end if;
  insert into app_meta.quotes(user_id,connection_id,configuration,config_hash,evidence,forecast,pricing,payable_minor,amount_iqd,rate,expires_at)
  values(p_user_id,conn.id,c,hash,e,f,price,total,round(total::numeric/100*fx),fx,least(now()+interval '5 minutes',conn.expires_at)) returning * into q;
  return app_meta.quote_result(q);
 end if;
 if p_action='claim' then
  kind:=coalesce(p_payload->>'kind','create');
  if kind not in ('create','status','reconcile') then return jsonb_build_object('ok',false,'code','INVALID_WORKER_KIND'); end if;
  -- A lost response after intent is never treated as a failed provider request.
  update app_meta.jobs x set status='reconcile',lease_until=null,last_error_code='PROVIDER_OUTCOME_UNKNOWN',updated_at=now()
  where x.status='leased' and x.lease_until<now() and exists(select 1 from jsonb_each(x.stages) s where s.value->>'state'='inflight');
  update app_meta.jobs x set status='reconcile',lease_until=null,terminal_failure=true,last_error_code='CREATE_ATTEMPTS_EXHAUSTED',updated_at=now()
  where x.status='leased' and x.lease_until<now() and x.attempts>=8
   and not exists(select 1 from jsonb_each(x.stages) s where s.value->>'state'='inflight');
  select x.* into j from app_meta.jobs x
  where x.available_at<=now() and (p_id is null or x.id=p_id)
   and (p_user_id is null or x.user_id=p_user_id)
   and (x.lease_until is null or x.lease_until<now())
   and ((kind='create' and (x.status='queued' or (x.status='leased' and x.attempts<8)) and app_meta.allowed(x.user_id))
     or (kind='status' and x.status='paused')
     or (kind='reconcile' and x.status in ('reconcile','refund_pending')))
  order by x.available_at,x.created_at for update skip locked limit 1;
  if not found then return null; end if;
  -- Reading/reconciling/refunding an accepted order remains possible when OFF.
  update app_meta.jobs set status=case when kind='create' then 'leased' else status end,
   lease_kind=kind,lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1,updated_at=now()
   where id=j.id returning * into j;
  return app_meta.job_result(j);
 end if;
 select * into j from app_meta.jobs where (id=p_id or (p_action='refund' and ad_id=p_id)) and (p_user_id is null or user_id=p_user_id) for update;
 if not found then return jsonb_build_object('ok',false,'code','JOB_NOT_FOUND'); end if;
 if p_action='job' then return app_meta.job_result(j); end if;
 if p_action='refund' then
  select * into ad from public.pa_ads where id=j.ad_id for update;
  select * into debit from public.pa_transactions where id=ad.receipt_uid and ad_id=ad.id and user_id=j.user_id and type='ad_payment' for update;
  if not found then return jsonb_build_object('ok',false,'code','ORIGINAL_DEBIT_NOT_FOUND'); end if;
  if p_payload ? 'expected_amount' and (p_payload->>'expected_amount')::numeric is distinct from debit.amount then return jsonb_build_object('ok',false,'code','AMOUNT_MISMATCH'); end if;
  if j.status='refunded' then return jsonb_build_object('ok',true,'status','refunded','already_refunded',true,'refund_transaction_id',ad.refund_tx_id,'ad_id',ad.id); end if;
  if debit.status not in ('approved','refund_pending') or ad.refunded_at is not null then return jsonb_build_object('ok',false,'code','INVALID_REFUND_STATE'); end if;
  if exists(select 1 from app_finance.ledger where original_transaction_id=debit.id and amount>0) then return jsonb_build_object('ok',false,'code','REFUND_RECONCILIATION_REQUIRED'); end if;
  safe:=not exists(select 1 from jsonb_each(j.stages) s where s.value->>'state'='inflight')
   and (j.provider_ids='{}'::jsonb or (j.observation->>'chain_paused'='true'
    and j.observation->>'spend_minor'='0' and (j.observation->>'verified_at')::timestamptz>now()-interval '10 minutes'));
  update public.pa_transactions set status='refund_pending',updated_at=now() where id=debit.id;
  if not coalesce(safe,false) then
   update app_meta.jobs set status='refund_pending',last_error_code='REFUND_RECONCILIATION_REQUIRED',updated_at=now() where id=j.id;
   return jsonb_build_object('ok',false,'code','REFUND_RECONCILIATION_REQUIRED','status','refund_pending','ad_id',ad.id);
  end if;
  balance:=public.pa_lock_wallet(j.user_id); credit:=gen_random_uuid();
  update public.pa_wallets set balance=pa_wallets.balance+debit.amount,updated_at=now() where user_id=j.user_id returning pa_wallets.balance into balance;
  insert into public.pa_transactions(id,user_id,type,kind,method,status,amount,currency,note,balance_after,ad_id,ad_public_id,ad_title,original_transaction_id)
  values(credit,j.user_id,'refund','refund',debit.method,'approved',debit.amount,'USD',left(coalesce(p_payload->>'reason','meta_private_paused_refund'),500),balance,
   ad.id,ad.public_ad_id,ad.title,debit.id);
  update public.pa_transactions set status='refunded',refunded_at=now(),updated_at=now() where id=debit.id;
  update public.pa_ads set refunded_amount=debit.amount,refunded_at=now(),refund_tx_id=credit::text,payment_status='refunded',status='rejected',updated_at=now() where id=ad.id;
  update app_meta.jobs set status='refunded',lease_until=null,lease_token=null,last_error_code=null,updated_at=now() where id=j.id;
  return jsonb_build_object('ok',true,'status','refunded','refund_transaction_id',credit,'original_transaction_id',debit.id,'amount',debit.amount,'balance_after',balance,'ad_id',ad.id);
 end if;
 if p_token is null or j.lease_token is distinct from p_token or j.lease_until is null then return jsonb_build_object('ok',false,'code','STALE_LEASE'); end if;
 if p_action='intent' then
  if not app_meta.allowed(j.user_id) then return jsonb_build_object('ok',false,'code','META_DISABLED'); end if;
  if j.status<>'leased' or j.lease_kind<>'create' or j.lease_until<=now() then return jsonb_build_object('ok',false,'code','STALE_LEASE'); end if;
  st:=p_payload->>'stage'; hash:=p_payload->>'request_hash';
  if coalesce(st,'') not in ('campaign','adset','creative','ad') or coalesce(hash,'') !~ '^[a-f0-9]{64}$' then return jsonb_build_object('ok',false,'code','INVALID_STAGE'); end if;
  if j.stages ? st then return jsonb_build_object('ok',false,'code',case when j.provider_ids ? st then 'STAGE_ALREADY_COMPLETE' else 'PROVIDER_OUTCOME_UNKNOWN' end); end if;
  if exists(select 1 from jsonb_each(j.stages) s where s.value->>'state'='inflight')
   or (st in ('adset','creative','ad') and not j.provider_ids ? 'campaign')
   or (st='adset' and j.provider_ids ? 'ad')
   or (st='ad' and (not j.provider_ids ? 'adset' or not j.provider_ids ? 'creative')) then return jsonb_build_object('ok',false,'code','INVALID_STAGE_ORDER'); end if;
  stage_data:=jsonb_build_object('state','inflight','request_hash',hash,'name','proxo:'||j.id||':'||st||':'||(select left(config_hash,12) from app_meta.quotes where id=j.quote_id),'started_at',clock_timestamp());
  update app_meta.jobs set stages=jsonb_set(stages,array[st],stage_data),observation=null,updated_at=now() where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'stage',stage_data,'job',app_meta.job_result(j));
 end if;
 if p_action='reject' then
  st:=p_payload->>'stage'; stage_data:=j.stages->st;
  if stage_data->>'state' is distinct from 'inflight' or p_payload->>'request_hash' is distinct from stage_data->>'request_hash'
   or nullif(p_payload->>'error_code','') is null then return jsonb_build_object('ok',false,'code','INVALID_REJECTION'); end if;
  update app_meta.jobs set stages=jsonb_set(stages,array[st],stage_data||jsonb_build_object('state','rejected','error_code',left(p_payload->>'error_code',80))),
   terminal_failure=true,last_error_code=left(p_payload->>'error_code',80),updated_at=now() where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'job',app_meta.job_result(j));
 end if;
 if p_action='complete' then
  st:=p_payload->>'stage'; stage_data:=j.stages->st;
  if coalesce(st,'') not in ('campaign','adset','creative','ad') or coalesce(p_payload->>'provider_id','') !~ '^[0-9]{1,40}$'
   or stage_data is null or stage_data->>'state' not in ('inflight','complete') then return jsonb_build_object('ok',false,'code','INVALID_STAGE'); end if;
  if j.lease_kind='reconcile' and (p_payload->>'request_hash' is distinct from stage_data->>'request_hash' or p_payload->>'reconciled' is distinct from 'true') then
   return jsonb_build_object('ok',false,'code','RECONCILIATION_EVIDENCE_REQUIRED'); end if;
  if j.provider_ids ? st and j.provider_ids->>st is distinct from p_payload->>'provider_id' then return jsonb_build_object('ok',false,'code','PROVIDER_ID_CONFLICT'); end if;
  update app_meta.jobs set provider_ids=jsonb_set(provider_ids,array[st],to_jsonb(p_payload->>'provider_id')),
   stages=jsonb_set(stages,array[st],stage_data||jsonb_build_object('state','complete','provider_id',p_payload->>'provider_id','completed_at',clock_timestamp())),
   observation=null,updated_at=now() where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'job',app_meta.job_result(j));
 end if;
 if p_action='observe' then
  begin observed_at:=(p_payload->>'verified_at')::timestamptz;
  exception when others then return jsonb_build_object('ok',false,'code','INVALID_OBSERVATION'); end;
  if observed_at is null or observed_at>now()+interval '1 minute' or observed_at<now()-interval '10 minutes'
   or jsonb_typeof(p_payload->'chain_paused') is distinct from 'boolean'
   or coalesce(jsonb_typeof(p_payload->'spend_minor'),'missing') not in ('number','null')
   or (p_payload->>'spend_minor')::numeric<0 or (p_payload->>'spend_minor')::numeric<>trunc((p_payload->>'spend_minor')::numeric) then
   return jsonb_build_object('ok',false,'code','INVALID_OBSERVATION'); end if;
  update app_meta.jobs set observation=p_payload,updated_at=now() where id=j.id returning * into j;
  update public.pa_ads set meta_provider_status=left(p_payload->>'provider_status',80),meta_review_status=left(p_payload->>'review_status',80),
   meta_status_checked_at=observed_at,meta_metrics_checked_at=case when jsonb_typeof(p_payload->'spend_minor')='number' then observed_at else meta_metrics_checked_at end,
   provider_metrics_available=case when jsonb_typeof(p_payload->'spend_minor')='number' and not provider_metrics_available ? 'spend' then provider_metrics_available||'"spend"'::jsonb else provider_metrics_available end,
   spend=coalesce((p_payload->>'spend_minor')::numeric/100,spend),current_spend=coalesce((p_payload->>'spend_minor')::numeric/100,current_spend),
   status=case when p_payload->>'chain_paused'='true' and refunded_at is null then 'paused' else status end,updated_at=now()
   where id=j.ad_id;
  return jsonb_build_object('ok',true,'job',app_meta.job_result(j));
 end if;
 if p_action='finish' then
  st:=p_payload->>'status';
  if coalesce(st,'') not in ('paused','reconcile') then return jsonb_build_object('ok',false,'code','PAID_ACTIVATION_DISABLED'); end if;
  if exists(select 1 from jsonb_each(j.stages) s where s.value->>'state'='inflight') then st:='reconcile'; end if;
  if j.status='refund_pending' then st:='refund_pending'; end if;
  if j.status='refunded' then return jsonb_build_object('ok',false,'code','JOB_ALREADY_REFUNDED'); end if;
  if st='reconcile' and p_payload->>'error_code'='PROVIDER_CHAIN_INCOMPLETE' and not j.terminal_failure
   and not exists(select 1 from jsonb_each(j.stages) s where s.value->>'state' in ('inflight','rejected')) and app_meta.allowed(j.user_id) then st:='queued'; end if;
  update app_meta.jobs set status=st,terminal_failure=terminal_failure or (coalesce(p_payload->>'terminal_failure','false')='true' and not exists(select 1 from jsonb_each(j.stages) s where s.value->>'state'='inflight')),
   lease_until=null,lease_token=null,available_at=now()+interval '5 minutes',
   last_error_code=left(p_payload->>'error_code',80),updated_at=now() where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'job',app_meta.job_result(j));
 end if;
 return jsonb_build_object('ok',false,'code','UNKNOWN_ACTION');
end $$;
create function public.pa_meta_service(p_action text,p_user_id uuid default null,p_id uuid default null,p_token uuid default null,p_payload jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$select app_meta.service(p_action,p_user_id,p_id,p_token,p_payload);$$;

-- Shared ad help is a narrow, server-administered setting. Platform entries win
-- over the all-platform fallback; malformed/disabled settings never block forms.
create function app_meta.help(p_platform text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); scope text; c jsonb;
begin
 if lower(coalesce(p_platform,'')) not in ('meta','tiktok') then return null; end if;
 foreach scope in array array[lower(p_platform),'all'] loop
  begin select value::jsonb into c from public.pa_settings where key='ad_help_'||scope;
  exception when others then c:=null; end;
  if c->>'active'='true' and char_length(btrim(coalesce(c->>'message',''))) between 1 and 500 and
   (nullif(c->>'video_url','') is null or c->>'video_url' ~ '^https://[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}([/?#][^[:space:]\\]*)?$') then
   return jsonb_build_object('scope',scope,'message',c->>'message','video_url',nullif(c->>'video_url',''),'active',true);
  end if;
 end loop; return null;
end $$;
create function public.pa_ad_help(p_platform text) returns jsonb language sql security invoker set search_path='' as $$select app_meta.help(p_platform);$$;
create function app_meta.set_help(p_scope text,p_config jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); begin
 if not public.pa_is_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_scope not in ('all','meta','tiktok') or jsonb_typeof(p_config) is distinct from 'object'
  or jsonb_typeof(p_config->'active') is distinct from 'boolean'
  or char_length(btrim(coalesce(p_config->>'message',''))) not between 1 and 500
  or (nullif(p_config->>'video_url','') is not null and p_config->>'video_url' !~ '^https://[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}([/?#][^[:space:]\\]*)?$')
  or exists(select 1 from jsonb_object_keys(p_config) k where k not in ('active','message','video_url')) then
  return jsonb_build_object('ok',false,'code','INVALID_HELP'); end if;
 insert into public.pa_settings(key,value,updated_at) values('ad_help_'||p_scope,p_config::text,now())
 on conflict(key) do update set value=excluded.value,updated_at=excluded.updated_at;
 return jsonb_build_object('ok',true);
end $$;
create function public.pa_set_ad_help(p_scope text,p_config jsonb) returns jsonb language sql security invoker set search_path='' as $$select app_meta.set_help(p_scope,p_config);$$;

-- Keep the established recovery endpoint available even with the pilot OFF.
create function app_meta.submission_status(p_submission_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); result jsonb; begin
 select s.result into result from proxo_private.ad_submissions s where s.user_id=u and s.submission_id=p_submission_id;
 return coalesce(result,jsonb_build_object('ok',false,'code','NOT_FOUND'));
end $$;
create or replace function public.pa_ad_submission_status(p_submission_id uuid) returns jsonb language sql security invoker set search_path='' as $$select app_meta.submission_status(p_submission_id);$$;

-- Legacy cancellation cannot bypass Meta's external-outcome/refund checks.
alter function app_finance.refund_ad(uuid,uuid,text,boolean) rename to refund_ad_tiktok_v2;
revoke all on function app_finance.refund_ad_tiktok_v2(uuid,uuid,text,boolean) from public,anon,authenticated;
create function app_finance.refund_ad(p_key uuid,p_ad_id uuid,p_reason text,p_admin boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); begin
 if exists(select 1 from public.pa_ads where id=p_ad_id and platform='META') then return jsonb_build_object('ok',false,'code','META_REFUND_REQUIRES_SERVER'); end if;
 return app_finance.refund_ad_tiktok_v2(p_key,p_ad_id,p_reason,p_admin);
end $$;
revoke all on function app_finance.refund_ad(uuid,uuid,text,boolean) from public,anon;
grant execute on function app_finance.refund_ad(uuid,uuid,text,boolean) to authenticated;

-- Durable quote binding is separate from gateway_payload: verified IPNs may
-- replace gateway_payload. The existing order-create workflow must persist this
-- FK from the service quote response before the pilot FastPay flag is enabled.
alter table public.pa_transactions add column if not exists meta_quote_id uuid references app_meta.quotes(id);
create unique index meta_fastpay_quote_once on public.pa_transactions(meta_quote_id) where meta_quote_id is not null and gateway='fastpay';
create function app_meta.immutable_payment_binding() returns trigger language plpgsql set search_path='' as $$
begin
 if old.meta_quote_id is not null and old.meta_quote_id is distinct from new.meta_quote_id then raise exception 'META_PAYMENT_BINDING_IMMUTABLE'; end if;
 return new;
end $$;
create trigger meta_payment_binding_immutable before update of meta_quote_id on public.pa_transactions for each row execute function app_meta.immutable_payment_binding();
alter function public.pa_quote_ad_checkout(uuid,jsonb,uuid,text) rename to pa_quote_ad_checkout_tiktok_v2;
revoke all on function public.pa_quote_ad_checkout_tiktok_v2(uuid,jsonb,uuid,text) from public,anon,authenticated,service_role;
create function app_meta.fastpay_quote(p_user_id uuid,p_ad jsonb,p_promo_id uuid,p_promo_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare q app_meta.quotes%rowtype; quote_id uuid;
begin
 if p_ad->>'platform' is distinct from 'META' then return public.pa_quote_ad_checkout_tiktok_v2(p_user_id,p_ad,p_promo_id,p_promo_code); end if;
 if not app_meta.allowed(p_user_id) then return jsonb_build_object('ok',false,'code','META_DISABLED'); end if;
 if not (select fastpay_enabled from app_meta.settings where singleton) then return jsonb_build_object('ok',false,'code','META_FASTPAY_UNAVAILABLE'); end if;
 if p_promo_id is not null or nullif(btrim(p_promo_code),'') is not null then return jsonb_build_object('ok',false,'code','INVALID_PROMO'); end if;
 begin quote_id:=(p_ad->>'quote_id')::uuid; exception when invalid_text_representation then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND'); end;
 select * into q from app_meta.quotes where id=quote_id and user_id=p_user_id;
 if not found then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND'); end if;
 if q.expires_at<=now() then return jsonb_build_object('ok',false,'code','QUOTE_EXPIRED'); end if;
 if q.configuration->>'payment_method'<>'FASTPAY' or (p_ad ? 'configuration' and p_ad->'configuration' is distinct from q.configuration) then return jsonb_build_object('ok',false,'code','QUOTE_CHANGED'); end if;
 if exists(select 1 from public.pa_ads where meta_quote_id=q.id) then return jsonb_build_object('ok',false,'code','QUOTE_ALREADY_USED'); end if;
 return app_meta.quote_result(q)||jsonb_build_object('meta_quote_id',q.id);
end $$;
create function public.pa_quote_ad_checkout(p_user_id uuid,p_ad jsonb,p_promo_id uuid default null,p_promo_code text default null)
returns jsonb language sql security invoker set search_path='' as $$select app_meta.fastpay_quote(p_user_id,p_ad,p_promo_id,p_promo_code);$$;
revoke all on function public.pa_quote_ad_checkout(uuid,jsonb,uuid,text) from public,anon,authenticated;
grant execute on function public.pa_quote_ad_checkout(uuid,jsonb,uuid,text) to service_role;

do $$ declare t text; r record; begin
 foreach t in array array['settings','testers','connections','quotes','jobs'] loop
  execute format('alter table app_meta.%I enable row level security',t);
  execute format('revoke all on app_meta.%I from public,anon,authenticated,service_role',t);
 end loop;
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_meta' loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',r.sig);
 end loop;
end $$;
grant execute on function app_meta.capabilities(),app_meta.help(text),app_meta.set_help(text,jsonb),app_meta.submission_status(uuid),
 app_meta.accept(uuid,uuid,jsonb,bigint,bigint,uuid) to authenticated;
grant execute on function app_meta.service(text,uuid,uuid,uuid,jsonb),app_meta.fastpay_quote(uuid,jsonb,uuid,text) to service_role;
revoke all on function public.pa_ad_capabilities(),public.pa_ad_help(text),public.pa_set_ad_help(text,jsonb),public.pa_ad_submission_status(uuid),
 public.pa_meta_accept(uuid,uuid,jsonb,bigint,bigint,uuid) from public,anon;
grant execute on function public.pa_ad_capabilities(),public.pa_ad_help(text),public.pa_set_ad_help(text,jsonb),public.pa_ad_submission_status(uuid),
 public.pa_meta_accept(uuid,uuid,jsonb,bigint,bigint,uuid) to authenticated;
revoke all on function public.pa_meta_service(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.pa_meta_service(text,uuid,uuid,uuid,jsonb) to service_role;
commit;
