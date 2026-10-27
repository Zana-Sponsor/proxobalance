-- Provider-generated offline report pages are auditable observations. The
-- currently documented response has no completeness/finality watermark. Do not
-- promote elapsed time, equal samples or a service-supplied boolean to settlement.
begin;
create table app_tiktok_dm.report_candidates(
 id uuid primary key default gen_random_uuid(),job_id uuid not null references app_finance.outbox(id),
 ad_id uuid not null references public.pa_ads(id),user_id uuid not null references auth.users(id),
 advertiser_id text not null,adgroup_id text not null,currency text not null check(currency='USD'),
 report_start_date date not null,report_end_date date not null,advertiser_timezone text not null,
 reported_spend_usd numeric(20,6) not null check(reported_spend_usd>=0 and reported_spend_usd::text not in ('NaN','Infinity','-Infinity')),
 captured_at timestamptz not null,evidence_hash text not null check(evidence_hash ~ '^[a-f0-9]{64}$'),
 database_payload_hash text not null,payload jsonb not null,created_at timestamptz not null default now(),
 unique(job_id,evidence_hash),check(report_end_date>=report_start_date),
 check(payload->'completeness_verified'='false'::jsonb and payload->'settlement_verified'='false'::jsonb and payload->'refund_authorized'='false'::jsonb));
create index tiktok_report_candidates_job_time on app_tiktok_dm.report_candidates(job_id,captured_at desc);
create trigger tiktok_report_candidate_immutable before update or delete on app_tiktok_dm.report_candidates for each row execute function app_finance.immutable_ledger();
alter table app_tiktok_dm.report_candidates enable row level security;
revoke all on app_tiktok_dm.report_candidates from public,anon,authenticated,service_role;
create function app_tiktok_dm.ingest_report_candidate(p_user_id uuid,p_id uuid,p_token uuid,p_payload jsonb) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare j app_finance.outbox%rowtype;ad public.pa_ads%rowtype;q app_tiktok_dm.quotes%rowtype;account app_tiktok_dm.accounts%rowtype;
 existing app_tiktok_dm.report_candidates%rowtype;tz text;start_day date;end_day date;captured timestamptz;earliest timestamptz;
 amount numeric;total numeric;row_count integer;distinct_count integer;candidate uuid;starts timestamptz;
begin
 select * into j from app_finance.outbox where id=p_id and fulfillment_kind='tiktok_conversation_auto' for update;
 if not found then return jsonb_build_object('ok',false,'code','JOB_NOT_FOUND');end if;
 select * into ad from public.pa_ads where id=j.ad_id;
 if p_user_id is not null and p_user_id<>ad.user_id then return jsonb_build_object('ok',false,'code','JOB_NOT_FOUND');end if;
 if p_token is null or j.lease_token is distinct from p_token or j.lease_until is null or j.lease_until<=now() then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
 if octet_length(p_payload::text)>1048576 then return jsonb_build_object('ok',false,'code','INVALID_REPORT_CANDIDATE');end if;
 select * into q from app_tiktok_dm.quotes where id=ad.tiktok_quote_id;
 select * into account from app_tiktok_dm.accounts where id=q.account_id;
 tz:=q.evidence->>'advertiser_timezone';
 if tz is null or not exists(select 1 from pg_timezone_names where name=tz) then return jsonb_build_object('ok',false,'code','REPORT_TIMEZONE_UNVERIFIED');end if;
 starts:=(ad.start_date+ad.start_time) at time zone 'Asia/Baghdad';
 start_day:=(starts at time zone tz)::date;end_day:=(ad.completed_at at time zone tz)::date;
 earliest:=greatest(ad.completed_at+interval '18 hours',((end_day+1)::timestamp at time zone tz)+interval '16 hours',ad.refund_eligible_at);
 begin captured:=(p_payload->>'captured_at')::timestamptz;amount:=(p_payload->>'spend_usd')::numeric;
 exception when others then return jsonb_build_object('ok',false,'code','INVALID_REPORT_CANDIDATE');end;
 if ad.status not in ('completed','rejected') or ad.completed_at is null or ad.refund_eligible_at is null
  or ad.refund_eligible_at<ad.completed_at+interval '2 hours' or starts>ad.completed_at or end_day-start_day not between 0 and 29
  or now()<earliest or captured is null or captured<now()-interval '10 minutes' or captured>now()+interval '1 minute'
  or captured<earliest or p_payload->>'source' is distinct from 'TIKTOK_OFFLINE_REPORT_CANDIDATE'
  or p_payload->'schema_version' is distinct from '1'::jsonb or p_payload->>'api_version' is distinct from 'v1.3'
  or p_payload->>'advertiser_id' is distinct from account.advertiser_id or p_payload->>'advertiser_id' is distinct from q.evidence#>>'{identity,advertiser_id}'
  or p_payload->>'adgroup_id' is distinct from j.provider_ids->>'adgroup' or not j.provider_ids ? 'adgroup'
  or p_payload->>'currency' is distinct from 'USD' or p_payload#>>'{scope,timezone}' is distinct from tz
  or p_payload#>>'{scope,start_date}' is distinct from start_day::text or p_payload#>>'{scope,end_date}' is distinct from end_day::text
  or p_payload->'provider_published_at' is distinct from 'null'::jsonb
  or p_payload->'pagination_complete' is distinct from 'true'::jsonb or p_payload->'latency_elapsed' is distinct from 'true'::jsonb
  or p_payload->'completeness_verified' is distinct from 'false'::jsonb or p_payload->'settlement_verified' is distinct from 'false'::jsonb
  or p_payload->'refund_authorized' is distinct from 'false'::jsonb or p_payload->>'finality_blocker' is distinct from 'PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE'
  or jsonb_typeof(p_payload->'spend_usd') is distinct from 'string' or coalesce(p_payload->>'spend_usd','') !~ '^[0-9]{1,14}(\.[0-9]{1,6})?$'
  or amount is null or amount<0 or coalesce(p_payload->>'evidence_hash','') !~ '^[a-f0-9]{64}$'
  or jsonb_typeof(p_payload->'records') is distinct from 'array' or jsonb_array_length(p_payload->'records') not between 1 and 2000
  or jsonb_typeof(p_payload->'pages') is distinct from 'array' or jsonb_array_length(p_payload->'pages') not between 1 and 20
  or p_payload#>>'{query,advertiser_id}' is distinct from account.advertiser_id
  or p_payload#>>'{query,data_level}' is distinct from 'AUCTION_ADGROUP'
  or p_payload#>'{query,dimensions}' is distinct from '["adgroup_id","ad_type","stat_time_day"]'::jsonb
  or p_payload#>'{query,metrics}' is distinct from '["spend"]'::jsonb then return jsonb_build_object('ok',false,'code','INVALID_REPORT_CANDIDATE');end if;
 if exists(select 1 from jsonb_array_elements(p_payload->'records') r where r#>>'{dimensions,adgroup_id}' is distinct from j.provider_ids->>'adgroup'
  or coalesce(r#>>'{dimensions,ad_type}','')='' or coalesce(r#>>'{dimensions,stat_time_day}','') !~ '^\d{4}-\d{2}-\d{2} 00:00:00$'
  or coalesce(r#>>'{metrics,spend}','') !~ '^[0-9]{1,14}(\.[0-9]{1,6})?$') then return jsonb_build_object('ok',false,'code','INVALID_REPORT_ROWS');end if;
 begin
  if exists(select 1 from jsonb_array_elements(p_payload->'records') r where (r#>>'{dimensions,stat_time_day}')::timestamp::date not between start_day and end_day) then return jsonb_build_object('ok',false,'code','INVALID_REPORT_ROWS');end if;
  select sum((r#>>'{metrics,spend}')::numeric),count(*),count(distinct r->'dimensions') into total,row_count,distinct_count from jsonb_array_elements(p_payload->'records') r;
 exception when others then return jsonb_build_object('ok',false,'code','INVALID_REPORT_ROWS');end;
 if total is distinct from amount or row_count<>distinct_count then return jsonb_build_object('ok',false,'code','INVALID_REPORT_ROWS');end if;
 select * into existing from app_tiktok_dm.report_candidates where job_id=j.id and evidence_hash=p_payload->>'evidence_hash';
 if found then
  if existing.payload is distinct from p_payload then return jsonb_build_object('ok',false,'code','REPORT_EVIDENCE_CONFLICT');end if;
  return jsonb_build_object('ok',true,'candidate_id',existing.id,'duplicate',true,'settlement_verified',false);end if;
 insert into app_tiktok_dm.report_candidates(job_id,ad_id,user_id,advertiser_id,adgroup_id,currency,report_start_date,report_end_date,advertiser_timezone,reported_spend_usd,captured_at,evidence_hash,database_payload_hash,payload)
 values(j.id,ad.id,ad.user_id,account.advertiser_id,j.provider_ids->>'adgroup','USD',start_day,end_day,tz,amount,captured,p_payload->>'evidence_hash',encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),p_payload) returning id into candidate;
 return jsonb_build_object('ok',true,'candidate_id',candidate,'settlement_verified',false,'code','PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE');
end $$;

alter function app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) rename to service_before_report_boundary;
revoke all on function app_tiktok_dm.service_before_report_boundary(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
create function app_tiktok_dm.service(p_action text,p_user_id uuid default null,p_id uuid default null,p_token uuid default null,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare j app_finance.outbox%rowtype;ad public.pa_ads%rowtype;candidate uuid;
begin
 if p_action='ingest_report_candidate' then return app_tiktok_dm.ingest_report_candidate(p_user_id,p_id,p_token,p_payload);end if;
 if p_action in ('settlement_lookup','final_observe','refund') then
  select x.* into j from app_finance.outbox x join public.pa_ads a on a.id=x.ad_id where x.fulfillment_kind='tiktok_conversation_auto'
   and (x.id=p_id or (p_action='refund' and x.ad_id=p_id)) and (p_user_id is null or a.user_id=p_user_id) for update of x;
  if not found then return jsonb_build_object('ok',false,'code','JOB_NOT_FOUND');end if;
  if p_action in ('settlement_lookup','final_observe') then
   if p_token is null or j.lease_token is distinct from p_token or j.lease_until is null or j.lease_until<=now() then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
   if p_action='final_observe' then
    -- No present provider response proves complete final spend. In particular,
    -- legacy account.capabilities.settled_reports and booleans have no authority.
    return jsonb_build_object('ok',false,'settled',false,'code','PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE');end if;
   select id into candidate from app_tiktok_dm.report_candidates where job_id=j.id order by captured_at desc limit 1;
   return jsonb_build_object('ok',true,'settlement_verified',false,'candidate_id',candidate,'code','PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE');
  end if;
  -- Pre-delivery compensation still delegates to the existing strict check:
  -- no possible ad, no unknown creation, and paused ancestors when present.
  select * into ad from public.pa_ads where id=j.ad_id;
  if ad.unused_budget_refunded_at is not null and (ad.unused_budget_refund_usd=0 or exists(
   select 1 from app_finance.ledger where transaction_id=ad.unused_budget_refund_tx_id and original_transaction_id=ad.receipt_uid
    and user_id=ad.user_id and amount=ad.unused_budget_refund_usd and amount>0)) then
   return app_tiktok_dm.service_before_report_boundary(p_action,p_user_id,p_id,p_token,p_payload);end if;
  if j.provider_ids ? 'ad' then return jsonb_build_object('ok',false,'code','FINAL_SPEND_NOT_RECONCILED');end if;
 end if;
 return app_tiktok_dm.service_before_report_boundary(p_action,p_user_id,p_id,p_token,p_payload);
end $$;
revoke all on function app_tiktok_dm.ingest_report_candidate(uuid,uuid,uuid,jsonb),app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) to service_role;
commit;
