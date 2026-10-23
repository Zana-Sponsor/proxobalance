-- Explicit administrator approval for later paid activation. This migration
-- does not enable the existing OFF flag or perform any provider mutation.
-- Approval/audit records are immutable; work stays in app_finance.outbox.
begin;

create table app_tiktok_dm.activation_approvals (
 id uuid primary key,job_id uuid not null unique references app_finance.outbox(id),
 approved_by uuid not null references auth.users(id),reason text not null check(char_length(reason) between 1 and 1000),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'),
 approved_at timestamptz not null default clock_timestamp(),expires_at timestamptz not null
);
alter table app_tiktok_dm.activation_approvals enable row level security;
revoke all on app_tiktok_dm.activation_approvals from public,anon,authenticated,service_role;
create table app_tiktok_dm.activation_events (
 id bigint generated always as identity primary key,job_id uuid not null references app_finance.outbox(id),
 approval_id uuid not null references app_tiktok_dm.activation_approvals(id),
 stage text not null check(stage in ('ad','adgroup','campaign')),
 event text not null check(event in ('INTENT','ENABLED','DISABLED')),
 attempt integer not null check(attempt>0),evidence jsonb not null,
 created_at timestamptz not null default clock_timestamp(),unique(job_id,stage,event,attempt)
);
alter table app_tiktok_dm.activation_events enable row level security;
revoke all on app_tiktok_dm.activation_events from public,anon,authenticated,service_role;
create index tiktok_activation_events_job on app_tiktok_dm.activation_events(job_id,id);
create function app_tiktok_dm.immutable_activation() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'ACTIVATION_AUDIT_IMMUTABLE' using errcode='42501';end $$;
create trigger tiktok_activation_approval_immutable before update or delete on app_tiktok_dm.activation_approvals
 for each row execute function app_tiktok_dm.immutable_activation();
create trigger tiktok_activation_event_immutable before update or delete on app_tiktok_dm.activation_events
 for each row execute function app_tiktok_dm.immutable_activation();

alter table app_finance.outbox add column activation_approval_id uuid references app_tiktok_dm.activation_approvals(id);
alter table app_finance.outbox add column activation_stages jsonb not null default '{}' check(jsonb_typeof(activation_stages)='object');
alter table app_finance.outbox add column activation_status text not null default 'unapproved'
 check(activation_status in ('unapproved','approved','activating','reconcile','completed'));
alter table app_finance.outbox add column activation_available_at timestamptz not null default now();
create index tiktok_activation_due on app_finance.outbox(activation_available_at)
 where activation_approval_id is not null and activation_status<>'completed';

-- Static approval identity excludes mutable observations/capability freshness.
-- It is recomputed from the current authoritative quote and captured ledger;
-- any identity, funding or accepted schedule drift invalidates new writes.
create function app_tiktok_dm.activation_binding(j app_finance.outbox) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('job_id',j.id,'ad_id',a.id,'user_id',a.user_id,'quote_id',q.id,
  'config_hash',q.config_hash,'configuration',q.ad,'provider_ids',j.provider_ids,
  'account_id',c.id,'identity_id',c.identity_id,'identity_type',c.identity_type,
  'advertiser_id',c.advertiser_id,'business_center_id',c.business_center_id,'asset_id',c.asset_id,
  'debit_id',d.id,'debit_amount',d.amount,'currency',d.currency,'ledger_id',l.id,'ledger_amount',l.amount,
  'start_at',(a.start_date+a.start_time) at time zone 'Asia/Baghdad',
  'end_at',((a.start_date+a.start_time) at time zone 'Asia/Baghdad')+make_interval(hours=>a.days*24),
  'gross_budget_usd',a.proxo_total_budget_usd,'declared_budget_usd',a.tiktok_declared_budget_usd,
  'stop_threshold_usd',a.spend_stop_threshold_usd)
 from public.pa_ads a join app_tiktok_dm.quotes q on q.id=j.tiktok_quote_id and q.id=a.tiktok_quote_id and q.user_id=a.user_id
 join app_tiktok_dm.accounts c on c.id=q.account_id and c.id=a.tiktok_account_id and c.user_id=a.user_id
 join public.pa_transactions d on d.id=a.receipt_uid and d.ad_id=a.id and d.user_id=a.user_id
 join app_finance.ledger l on l.transaction_id=d.id and l.user_id=a.user_id and l.operation='ad_payment'
 where a.id=j.ad_id and j.fulfillment_kind='tiktok_conversation_auto' and a.fulfillment_kind='tiktok_conversation_auto'
 and a.goal='messages' and a.message_destination='direct_message' and c.identity_id=a.tiktok_identity_id
 and d.type='ad_payment' and d.status='approved' and d.currency='USD' and d.amount>=0 and d.amount=a.total_budget
 and d.amount=(q.pricing->>'cost_usd')::numeric and l.amount=-d.amount and l.currency='USD'
 and not exists(select 1 from app_finance.ledger r where r.original_transaction_id=d.id and r.amount>0)
 and j.provider_ids ?& array['campaign','adgroup','ad'] and (select count(*) from jsonb_object_keys(j.provider_ids))=3
 and j.provider_ids->>'campaign'=a.tiktok_campaign_id and j.provider_ids->>'adgroup'=a.tiktok_adgroup_id and j.provider_ids->>'ad'=a.tiktok_ad_id
 and not exists(select 1 from jsonb_each(j.provider_ids) x where x.value#>>'{}' !~ '^[0-9]{1,40}$')
 and not exists(select 1 from unnest(array['campaign','adgroup','ad']) s
  where j.stages->s->>'state' is distinct from 'complete' or j.stages->s->>'provider_id' is distinct from j.provider_ids->>s);
$$;

create function app_tiktok_dm.activation_can_mutate(j app_finance.outbox) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select s.activation_enabled and app_tiktok_dm.allowed(a.user_id)
  and p.expires_at>now() and p.snapshot=app_tiktok_dm.activation_binding(j)
  and exists(select 1 from public.profiles u where u.id=p.approved_by and coalesce(u.is_admin,false) and not coalesce(u.is_banned,false))
  and c.status='CONNECTED' and c.available_status='AVAILABLE' and c.can_pull_video and c.can_manage_message and c.message_ads_eligible
  and c.last_verified_at>now()-interval '24 hours' and c.last_verified_at<=now()+interval '1 minute'
  and not j.terminal_failure and j.stop_intent is null and j.status='completed' and j.activation_status<>'completed'
  and a.status not in ('completed','rejected') and a.unused_budget_refunded_at is null and a.refunded_at is null
  and a.spend_stop_triggered_at is null and a.stop_reason is null
  and coalesce(a.current_spend,a.spend,0)<a.spend_stop_threshold_usd
  and ((a.start_date+a.start_time) at time zone 'Asia/Baghdad')+make_interval(hours=>a.days*24)>now()
  and not exists(select 1 from jsonb_each(j.stages) x where x.value->>'state'='inflight')
  from app_tiktok_dm.activation_approvals p join public.pa_ads a on a.id=j.ad_id
  join app_tiktok_dm.accounts c on c.id=a.tiktok_account_id cross join app_tiktok_dm.settings s
  where p.id=j.activation_approval_id and p.job_id=j.id and s.singleton),false);
$$;

create function app_tiktok_dm.approve_activation(p_job_id uuid,p_approval_id uuid,p_reason text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_finance.actor();j app_finance.outbox%rowtype;p app_tiktok_dm.activation_approvals%rowtype;b jsonb;observed timestamptz;
begin
 -- Existing live authorization model: profile is_admin, not user-editable JWT metadata.
 if not public.is_admin() then return jsonb_build_object('ok',false,'code','ADMIN_REQUIRED');end if;
 if p_job_id is null or p_approval_id is null or char_length(btrim(coalesce(p_reason,''))) not between 1 and 1000 then
  return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 select * into j from app_finance.outbox where id=p_job_id and fulfillment_kind='tiktok_conversation_auto' for update;
 if not found then return jsonb_build_object('ok',false,'code','JOB_NOT_FOUND');end if;
 select * into p from app_tiktok_dm.activation_approvals where id=p_approval_id or job_id=j.id;
 if found then
  if p.id<>p_approval_id or p.job_id<>j.id or p.reason<>btrim(p_reason) or p.approved_by<>actor then
   return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');end if;
  return jsonb_build_object('ok',true,'approval_id',p.id,'job_id',j.id,'expires_at',p.expires_at,'already_approved',true);
 end if;
 if not (select activation_enabled from app_tiktok_dm.settings where singleton) then
  return jsonb_build_object('ok',false,'code','TIKTOK_ACTIVATION_DISABLED');end if;
 b:=app_tiktok_dm.activation_binding(j);
 if b is null or j.status<>'completed' or j.terminal_failure or j.stop_intent is not null
  or j.activation_status<>'unapproved' or j.activation_stages<>'{}'::jsonb
  or (j.lease_until is not null and j.lease_until>now()) then return jsonb_build_object('ok',false,'code','ACTIVATION_NOT_READY');end if;
 begin observed:=(j.observation->>'provider_observed_at')::timestamptz;
 exception when others then return jsonb_build_object('ok',false,'code','ACTIVATION_PAUSE_PROOF_REQUIRED');end;
 if observed is null or observed<now()-interval '10 minutes' or observed>now()+interval '1 minute'
  or j.observation->>'chain_paused' is distinct from 'true'
  or j.observation->>'provider_ad_id' is distinct from j.provider_ids->>'ad'
  or j.observation->>'provider_adgroup_id' is distinct from j.provider_ids->>'adgroup'
  or exists(select 1 from unnest(array['campaign','adgroup','ad']) x
    where j.observation#>>array['raw_statuses',x,'operation_status'] is distinct from 'DISABLE')
  or (jsonb_typeof(j.observation->'spend_usd')='number' and (j.observation->>'spend_usd')::numeric >= (b->>'stop_threshold_usd')::numeric) then
  return jsonb_build_object('ok',false,'code','ACTIVATION_PAUSE_PROOF_REQUIRED');end if;
 insert into app_tiktok_dm.activation_approvals(id,job_id,approved_by,reason,snapshot,expires_at)
  values(p_approval_id,j.id,actor,btrim(p_reason),b,(b->>'end_at')::timestamptz) returning * into p;
 update app_finance.outbox set activation_approval_id=p.id,activation_status='approved',activation_available_at=now()
  where id=j.id returning * into j;
 if not app_tiktok_dm.activation_can_mutate(j) then
  -- Roll the entire statement back; never leave an unusable approval behind.
  raise exception 'ACTIVATION_NOT_READY' using errcode='P0001';end if;
 return jsonb_build_object('ok',true,'approval_id',p.id,'job_id',j.id,'expires_at',p.expires_at);
exception when raise_exception then
 if sqlerrm='ACTIVATION_NOT_READY' then return jsonb_build_object('ok',false,'code','ACTIVATION_NOT_READY');end if;
 raise;
end $$;
create function public.pa_tiktok_dm_approve_activation(p_job_id uuid,p_approval_id uuid,p_reason text) returns jsonb
language sql security invoker set search_path='' as $$select app_tiktok_dm.approve_activation(p_job_id,p_approval_id,p_reason);$$;

create function app_tiktok_dm.activation_result(j app_finance.outbox) returns jsonb
language sql stable security definer set search_path='' as $$
 select app_tiktok_dm.job_result(j)||jsonb_build_object('activation_approval',to_jsonb(p),'activation_can_mutate',app_tiktok_dm.activation_can_mutate(j))
 from app_tiktok_dm.activation_approvals p where p.id=j.activation_approval_id;
$$;

alter function app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) rename to service_before_activation;
revoke all on function app_tiktok_dm.service_before_activation(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
create function app_tiktok_dm.service(p_action text,p_user_id uuid default null,p_id uuid default null,p_token uuid default null,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare j app_finance.outbox%rowtype;st text;entry jsonb;observed timestamptz;result jsonb;attempt integer;desired text;
begin
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>262144 then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 if p_action='claim' and p_payload->>'kind'='activate' then
  select x.* into j from app_finance.outbox x where x.fulfillment_kind='tiktok_conversation_auto' and x.activation_approval_id is not null
   and x.activation_status<>'completed' and (p_id is null or x.id=p_id) and (x.lease_until is null or x.lease_until<now())
   and x.activation_available_at<=now()
   and (app_tiktok_dm.activation_can_mutate(x) or exists(select 1 from jsonb_each(x.activation_stages) t where t.value->>'state'='inflight'))
   order by x.activation_available_at,x.id for update skip locked limit 1;
  if not found then return null;end if;
  update app_finance.outbox set lease_kind='activate',lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes',
   activation_status=case when exists(select 1 from jsonb_each(activation_stages) t where t.value->>'state'='inflight') then 'reconcile' else 'activating' end
   where id=j.id returning * into j;
  return app_tiktok_dm.activation_result(j);
 end if;
 if p_action in ('activation_intent','activation_complete','activation_reconcile','finish','refund','final_observe') then
  select x.* into j from app_finance.outbox x join public.pa_ads a on a.id=x.ad_id
   where x.fulfillment_kind='tiktok_conversation_auto' and (x.id=p_id or (p_action='refund' and x.ad_id=p_id))
    and (p_user_id is null or a.user_id=p_user_id) for update of x;
  if p_action in ('refund','final_observe') and found and exists(select 1 from jsonb_each(j.activation_stages) t where t.value->>'state'='inflight') then
   return jsonb_build_object('ok',false,'code','ACTIVATION_OUTCOME_UNKNOWN');end if;
  if p_action like 'activation_%' or (p_action='finish' and j.lease_kind='activate') then
   if j.id is null then return jsonb_build_object('ok',false,'code','JOB_NOT_FOUND');end if;
   if p_token is null or p_token is distinct from j.lease_token or j.lease_kind is distinct from 'activate' or j.lease_until is null then
    return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
   if p_action='finish' then
    update app_finance.outbox set lease_token=null,lease_until=null,
     activation_status=case when exists(select 1 from jsonb_each(activation_stages) t where t.value->>'state'='inflight') then 'reconcile'
       when activation_stages->'campaign'->>'state'='complete' then 'completed' else 'approved' end,
     activation_available_at=now()+interval '1 minute',last_error_code=left(p_payload->>'error_code',80)
     where id=j.id returning * into j;
    return jsonb_build_object('ok',true,'job',app_tiktok_dm.activation_result(j));
   end if;
   st:=p_payload->>'stage';entry:=j.activation_stages->st;
   if coalesce(st,'') not in ('ad','adgroup','campaign') or coalesce(p_payload->>'request_hash','') !~ '^[a-f0-9]{64}$' then
    return jsonb_build_object('ok',false,'code','INVALID_ACTIVATION_STAGE');end if;
   if p_action='activation_intent' then
    if j.lease_until<=now() then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
    if not app_tiktok_dm.activation_can_mutate(j) then return jsonb_build_object('ok',false,'code','TIKTOK_ACTIVATION_DISABLED');end if;
    if entry is not null and entry->>'request_hash' is distinct from p_payload->>'request_hash' then
     return jsonb_build_object('ok',false,'code','ACTIVATION_INTENT_CONFLICT');end if;
    if entry->>'state'='complete' then return jsonb_build_object('ok',false,'code','ACTIVATION_STAGE_ALREADY_COMPLETE');end if;
    if exists(select 1 from jsonb_each(j.activation_stages) t where t.value->>'state'='inflight') then
     return jsonb_build_object('ok',false,'code','ACTIVATION_OUTCOME_UNKNOWN');end if;
    if (st in ('adgroup','campaign') and j.activation_stages->'ad'->>'state' is distinct from 'complete')
     or (st='campaign' and j.activation_stages->'adgroup'->>'state' is distinct from 'complete') then
     return jsonb_build_object('ok',false,'code','INVALID_ACTIVATION_STAGE_ORDER');end if;
    if entry is not null and (entry->>'state' is distinct from 'retryable' or (entry->>'observed_at')::timestamptz<now()-interval '10 minutes') then
     return jsonb_build_object('ok',false,'code','ACTIVATION_RECONCILIATION_REQUIRED');end if;
    attempt:=coalesce((entry->>'attempt')::integer,0)+1;
    if attempt>8 then return jsonb_build_object('ok',false,'code','ACTIVATION_ATTEMPTS_EXHAUSTED');end if;
    entry:=coalesce(entry,'{}')||jsonb_build_object('state','inflight','request_hash',p_payload->>'request_hash','provider_id',j.provider_ids->>st,
      'approval_id',j.activation_approval_id,'attempt',attempt,'started_at',clock_timestamp());
    update app_finance.outbox set activation_stages=jsonb_set(activation_stages,array[st],entry),activation_status='activating' where id=j.id returning * into j;
    insert into app_tiktok_dm.activation_events(job_id,approval_id,stage,event,attempt,evidence)
     values(j.id,j.activation_approval_id,st,'INTENT',attempt,entry);
    return jsonb_build_object('ok',true,'job',app_tiktok_dm.activation_result(j));
   end if;
   desired:=case when p_action='activation_complete' then 'ENABLE' else 'DISABLE' end;
   begin observed:=(p_payload->>'provider_observed_at')::timestamptz;
   exception when others then return jsonb_build_object('ok',false,'code','INVALID_ACTIVATION_OBSERVATION');end;
   if entry is null or entry->>'state' not in ('inflight','complete','retryable')
    or p_payload->>'request_hash' is distinct from entry->>'request_hash'
    or p_payload->>'provider_id' is distinct from j.provider_ids->>st or p_payload->>'provider_id' is distinct from entry->>'provider_id'
    or p_payload->>'operation_status' is distinct from desired or observed is null or observed<now()-interval '10 minutes' or observed>now()+interval '1 minute'
    or observed<(entry->>'started_at')::timestamptz
    or (p_action='activation_reconcile' and p_payload->>'reconciled' is distinct from 'true') then
    return jsonb_build_object('ok',false,'code','INVALID_ACTIVATION_OBSERVATION');end if;
   if entry->>'state'<>'inflight' then
    if (entry->>'state'='complete' and desired='ENABLE') or (entry->>'state'='retryable' and desired='DISABLE') then
     return jsonb_build_object('ok',true,'already_recorded',true,'job',app_tiktok_dm.activation_result(j));end if;
    return jsonb_build_object('ok',false,'code','ACTIVATION_STATE_CONFLICT');end if;
   entry:=entry||jsonb_build_object('state',case when desired='ENABLE' then 'complete' else 'retryable' end,
    'operation_status',desired,'observed_at',observed,'reconciled',coalesce(p_payload->>'reconciled','false')='true');
   update app_finance.outbox set activation_stages=jsonb_set(activation_stages,array[st],entry),
    activation_status=case when st='campaign' and desired='ENABLE' then 'completed' else 'activating' end
    where id=j.id returning * into j;
   insert into app_tiktok_dm.activation_events(job_id,approval_id,stage,event,attempt,evidence)
    values(j.id,j.activation_approval_id,st,case when desired='ENABLE' then 'ENABLED' else 'DISABLED' end,(entry->>'attempt')::integer,entry);
   return jsonb_build_object('ok',true,'job',app_tiktok_dm.activation_result(j));
  end if;
 end if;
 return app_tiktok_dm.service_before_activation(p_action,p_user_id,p_id,p_token,p_payload);
end $$;

revoke all on function app_tiktok_dm.immutable_activation(),app_tiktok_dm.activation_binding(app_finance.outbox),
 app_tiktok_dm.activation_can_mutate(app_finance.outbox),app_tiktok_dm.activation_result(app_finance.outbox),
 app_tiktok_dm.approve_activation(uuid,uuid,text),app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb),
 public.pa_tiktok_dm_approve_activation(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function app_tiktok_dm.approve_activation(uuid,uuid,text),public.pa_tiktok_dm_approve_activation(uuid,uuid,text) to authenticated;
grant execute on function app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) to service_role;
commit;
