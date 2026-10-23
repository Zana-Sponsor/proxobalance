-- OAuth authorization grants are NOT proof of the Marketing API / BC identity
-- join. This migration never inserts or connects an advertising account.
begin;
alter table app_tiktok_dm.settings add column connection_enabled boolean not null default false;

create function app_tiktok_dm.valid_oauth_envelope(e jsonb) returns boolean
language sql immutable set search_path='' as $$
 select coalesce(jsonb_typeof(e)='object' and e->'v'='1'::jsonb
  and e-array['v','kid','iv','tag','ciphertext']='{}'::jsonb
  and jsonb_typeof(e->'kid')='string' and jsonb_typeof(e->'iv')='string' and jsonb_typeof(e->'tag')='string' and jsonb_typeof(e->'ciphertext')='string'
  and e->>'kid' ~ '^[A-Za-z0-9_-]{1,40}$'
  and e->>'iv' ~ '^[A-Za-z0-9_-]{16}$' and e->>'tag' ~ '^[A-Za-z0-9_-]{22}$'
  and char_length(e->>'ciphertext') between 1 and 32768 and e->>'ciphertext' ~ '^[A-Za-z0-9_-]+$',false);
$$;
create table app_tiktok_dm.oauth_requests(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),idempotency_key uuid not null,
 requested_username text not null check(requested_username ~ '^[a-z0-9_.]{2,24}$'),
 state_hash text not null unique check(state_hash ~ '^[a-f0-9]{64}$'),state_ciphertext jsonb not null check(app_tiktok_dm.valid_oauth_envelope(state_ciphertext)),
 app_id text not null check(app_id ~ '^[0-9]{1,40}$'),redirect_uri text not null,expires_at timestamptz not null,
 status text not null default 'PENDING' check(status in ('PENDING','EXCHANGING','VERIFYING','VERIFIED_UNLINKED','USERNAME_MISMATCH','MISSING_PERMISSION','REJECTED','UNAVAILABLE','EXPIRED','REVOKING','REVOKED')),
 consumed_at timestamptz,authorized_username text,open_id text,scope jsonb not null default '[]' check(jsonb_typeof(scope)='array'),
 credential_ciphertext jsonb check(credential_ciphertext is null or app_tiktok_dm.valid_oauth_envelope(credential_ciphertext)),
 access_expires_at timestamptz,refresh_expires_at timestamptz,evidence jsonb not null default '{}',error_code text,
 grant_status text not null default 'NONE' check(grant_status in ('NONE','ACTIVE','REFRESHING','REVOKING','REVOKED','RECONCILE')),
 lease_token uuid,lease_until timestamptz,lease_kind text check(lease_kind in ('callback','refresh','revoke')),
 revoke_requested_at timestamptz,revoked_at timestamptz,token_request_id text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(user_id,idempotency_key)
);
create index tiktok_oauth_owner on app_tiktok_dm.oauth_requests(user_id,created_at desc);
create index tiktok_oauth_due on app_tiktok_dm.oauth_requests(grant_status,access_expires_at);
create table app_tiktok_dm.oauth_events(id bigint generated always as identity primary key,request_id uuid not null references app_tiktok_dm.oauth_requests(id),
 event text not null,status text not null,grant_status text not null,error_code text,created_at timestamptz not null default now());
create function app_tiktok_dm.oauth_audit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and (old.id,old.user_id,old.idempotency_key,old.requested_username,old.state_hash,old.state_ciphertext,old.app_id,old.redirect_uri,old.expires_at,old.created_at)
  is distinct from (new.id,new.user_id,new.idempotency_key,new.requested_username,new.state_hash,new.state_ciphertext,new.app_id,new.redirect_uri,new.expires_at,new.created_at) then
  raise exception 'OAUTH_BINDING_IMMUTABLE' using errcode='42501';end if;
 insert into app_tiktok_dm.oauth_events(request_id,event,status,grant_status,error_code) values(new.id,tg_op,new.status,new.grant_status,new.error_code);
 return new;
end $$;
create trigger tiktok_oauth_audit after insert or update on app_tiktok_dm.oauth_requests for each row execute function app_tiktok_dm.oauth_audit();
create trigger tiktok_oauth_events_immutable before update or delete on app_tiktok_dm.oauth_events for each row execute function app_finance.immutable_ledger();
create function app_tiktok_dm.oauth_private(r app_tiktok_dm.oauth_requests) returns jsonb language sql stable set search_path='' as $$
 select (to_jsonb(r)-'state_hash')||jsonb_build_object('ok',true);
$$;

alter function app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) rename to service_before_oauth;
revoke all on function app_tiktok_dm.service_before_oauth(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
create function app_tiktok_dm.service(p_action text,p_user_id uuid default null,p_id uuid default null,p_token uuid default null,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare r app_tiktok_dm.oauth_requests%rowtype; st text;kind text;err text;exp timestamptz;refresh_exp timestamptz;e jsonb;result jsonb;scope_lost boolean:=false;
begin
 if p_action='list_accounts' then
  result:=app_tiktok_dm.service_before_oauth(p_action,p_user_id,p_id,p_token,p_payload);
  update app_tiktok_dm.oauth_requests set status='EXPIRED',error_code='TIKTOK_AUTHORIZATION_EXPIRED',updated_at=now() where user_id=p_user_id and status='PENDING' and expires_at<=now();
  select * into r from app_tiktok_dm.oauth_requests where user_id=p_user_id and status not in ('REVOKED','EXPIRED') order by created_at desc limit 1;
  return result||jsonb_build_object('pending_request',case when r.id is not null then app_tiktok_dm.oauth_private(r) else null end);
 end if;
 if p_action not like 'oauth\_%' escape '\' then return app_tiktok_dm.service_before_oauth(p_action,p_user_id,p_id,p_token,p_payload);end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>65536 then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 if p_action='oauth_start' then
  if p_user_id is null or p_id is null then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
  perform pg_advisory_xact_lock(hashtextextended('tiktok:oauth:'||p_user_id::text||':'||p_id::text,0));
  select * into r from app_tiktok_dm.oauth_requests where user_id=p_user_id and idempotency_key=p_id for update;
  if found then
   if r.requested_username is distinct from p_payload->>'requested_username' or r.app_id is distinct from p_payload->>'app_id' or r.redirect_uri is distinct from p_payload->>'redirect_uri' then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');end if;
   if r.status='PENDING' and r.expires_at<=now() then update app_tiktok_dm.oauth_requests set status='EXPIRED',error_code='TIKTOK_AUTHORIZATION_EXPIRED',updated_at=now() where id=r.id returning * into r;end if;
   return app_tiktok_dm.oauth_private(r);
  end if;
  if not exists(select 1 from app_tiktok_dm.settings s join app_tiktok_dm.testers t on t.user_id=p_user_id
   join auth.users u on u.id=t.user_id join public.profiles p on p.id=u.id where s.singleton and s.connection_enabled and t.enabled
   and (t.expires_at is null or t.expires_at>now()) and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null) and not coalesce(p.is_banned,false)) then
   return jsonb_build_object('ok',false,'code','TIKTOK_CONNECTION_DISABLED');end if;
  if not app_finance.rate_allowed(p_user_id,'tiktok_oauth_start',5) then return jsonb_build_object('ok',false,'code','RATE_LIMITED');end if;
  exp:=(p_payload->>'expires_at')::timestamptz;
  if p_payload-array['requested_username','state_hash','state_ciphertext','app_id','redirect_uri','expires_at']<>'{}'::jsonb
   or coalesce(p_payload->>'requested_username','') !~ '^[a-z0-9_.]{2,24}$' or coalesce(p_payload->>'state_hash','') !~ '^[a-f0-9]{64}$'
   or not app_tiktok_dm.valid_oauth_envelope(p_payload->'state_ciphertext') or coalesce(p_payload->>'app_id','') !~ '^[0-9]{1,40}$'
   or coalesce(p_payload->>'redirect_uri','') !~ '^https://[^/@?#:]+/[^?#]*/$' or char_length(p_payload->>'redirect_uri')>2048
   or exp is null or exp<=now() or exp>now()+interval '15 minutes' then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
  insert into app_tiktok_dm.oauth_requests(user_id,idempotency_key,requested_username,state_hash,state_ciphertext,app_id,redirect_uri,expires_at)
   values(p_user_id,p_id,p_payload->>'requested_username',p_payload->>'state_hash',p_payload->'state_ciphertext',p_payload->>'app_id',p_payload->>'redirect_uri',exp) returning * into r;
  return app_tiktok_dm.oauth_private(r);
 end if;
 if p_action in ('oauth_status','oauth_revoke') then
  select * into r from app_tiktok_dm.oauth_requests where id=p_id and user_id=p_user_id for update;
  if not found then return jsonb_build_object('ok',false,'code','TIKTOK_OAUTH_REQUEST_NOT_FOUND');end if;
  if p_action='oauth_status' then
   if r.status='PENDING' and r.expires_at<=now() then update app_tiktok_dm.oauth_requests set status='EXPIRED',error_code='TIKTOK_AUTHORIZATION_EXPIRED',updated_at=now() where id=r.id returning * into r;end if;
   return app_tiktok_dm.oauth_private(r);
  end if;
  if r.status='REVOKED' then return app_tiktok_dm.oauth_private(r);end if;
  update app_tiktok_dm.oauth_requests set revoke_requested_at=coalesce(revoke_requested_at,now()),
   status=case when credential_ciphertext is null and lease_kind is distinct from 'callback' then 'REVOKED' else 'REVOKING' end,
   grant_status=case when credential_ciphertext is null then grant_status else 'REVOKING' end,
   consumed_at=coalesce(consumed_at,now()),updated_at=now() where id=r.id returning * into r;
  return app_tiktok_dm.oauth_private(r);
 end if;
 if p_action='oauth_claim' then
  if p_payload-array['state_hash']<>'{}'::jsonb or coalesce(p_payload->>'state_hash','') !~ '^[a-f0-9]{64}$' then return jsonb_build_object('ok',false,'code','TIKTOK_CALLBACK_INVALID');end if;
  select * into r from app_tiktok_dm.oauth_requests where state_hash=p_payload->>'state_hash' for update;
  if not found then return jsonb_build_object('ok',false,'code','TIKTOK_CALLBACK_INVALID');end if;
  if r.consumed_at is not null or r.status<>'PENDING' then return jsonb_build_object('ok',false,'code','TIKTOK_AUTHORIZATION_REPLAY');end if;
  if r.expires_at<=now() then
   update app_tiktok_dm.oauth_requests set status='EXPIRED',consumed_at=now(),error_code='TIKTOK_AUTHORIZATION_EXPIRED',updated_at=now() where id=r.id;
   return jsonb_build_object('ok',false,'code','TIKTOK_AUTHORIZATION_EXPIRED');end if;
  update app_tiktok_dm.oauth_requests set status='EXCHANGING',consumed_at=now(),lease_token=gen_random_uuid(),lease_kind='callback',lease_until=now()+interval '2 minutes',updated_at=now() where id=r.id returning * into r;
  return app_tiktok_dm.oauth_private(r);
 end if;
 if p_action='oauth_token_claim' then
  kind:=p_payload->>'kind';if kind is null or kind not in ('refresh','revoke') or p_payload-array['kind']<>'{}'::jsonb then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
  -- A lost refresh response may have rotated the token. Never refresh it again.
  update app_tiktok_dm.oauth_requests set grant_status='RECONCILE',error_code='TIKTOK_OAUTH_OUTCOME_UNKNOWN',lease_token=null,lease_until=null,lease_kind=null,updated_at=now()
   where lease_kind='refresh' and lease_until<=now();
  -- A consumed callback is never re-exchanged. Retained grants need revocation.
  update app_tiktok_dm.oauth_requests set status='UNAVAILABLE',grant_status=case when credential_ciphertext is not null then 'REVOKING' else 'NONE' end,
   revoke_requested_at=case when credential_ciphertext is not null then coalesce(revoke_requested_at,now()) else revoke_requested_at end,
   error_code='TIKTOK_OAUTH_OUTCOME_UNKNOWN',lease_token=null,lease_until=null,lease_kind=null,updated_at=now()
   where lease_kind='callback' and lease_until<=now();
  select * into r from app_tiktok_dm.oauth_requests where credential_ciphertext is not null
   and (lease_until is null or lease_until<=now()) and (
    (kind='revoke' and grant_status='REVOKING') or
    (kind='refresh' and grant_status='ACTIVE' and revoke_requested_at is null and status='VERIFIED_UNLINKED' and access_expires_at<=now()+interval '10 minutes' and refresh_expires_at>now()))
   order by updated_at,id for update skip locked limit 1;
  if not found then return null;end if;
  update app_tiktok_dm.oauth_requests set grant_status=case when kind='refresh' then 'REFRESHING' else 'REVOKING' end,
   lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes',lease_kind=kind,updated_at=now() where id=r.id returning * into r;
  return app_tiktok_dm.oauth_private(r);
 end if;
 if p_action not in ('oauth_complete','oauth_fail','oauth_token_complete') then return jsonb_build_object('ok',false,'code','UNKNOWN_ACTION');end if;
 select * into r from app_tiktok_dm.oauth_requests where id=p_id for update;
 if not found then return jsonb_build_object('ok',false,'code','TIKTOK_OAUTH_REQUEST_NOT_FOUND');end if;
 if p_token is null or r.lease_token is distinct from p_token or r.lease_until<=now() then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
 st:=p_payload->>'status';err:=p_payload->>'error_code';
 if err is not null and (err !~ '^TIKTOK_[A-Z0-9_]{1,72}$') then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 if p_action='oauth_fail' then
  if r.lease_kind<>'callback' or st is null or st not in ('UNAVAILABLE','REJECTED','MISSING_PERMISSION','USERNAME_MISMATCH') or p_payload-array['status','error_code','grant_exchanged']<>'{}'::jsonb then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
  update app_tiktok_dm.oauth_requests set status=st,error_code=err,
   grant_status=case when credential_ciphertext is not null then 'REVOKING' when p_payload->>'grant_exchanged'='true' then 'RECONCILE' else 'NONE' end,
   revoke_requested_at=case when credential_ciphertext is not null then coalesce(revoke_requested_at,now()) else revoke_requested_at end,
   lease_token=null,lease_until=null,lease_kind=null,updated_at=now() where id=r.id returning * into r;
  return app_tiktok_dm.oauth_private(r);
 end if;
 if p_action='oauth_token_complete' then
  if r.lease_kind not in ('refresh','revoke') or st is null or st not in ('REFRESHED','REVOKED','RECONCILE') then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
  if st='RECONCILE' then
   if p_payload-array['status','error_code']<>'{}'::jsonb then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
   update app_tiktok_dm.oauth_requests set grant_status='RECONCILE',error_code=err,lease_token=null,lease_until=null,lease_kind=null,updated_at=now() where id=r.id returning * into r;
   return app_tiktok_dm.oauth_private(r);
  end if;
  if coalesce(p_payload->>'provider_request_id','') !~ '^[A-Za-z0-9_-]{1,200}$' then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
  if st='REVOKED' then
   if r.lease_kind<>'revoke' or p_payload-array['status','provider_request_id']<>'{}'::jsonb then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
   update app_tiktok_dm.oauth_requests set status='REVOKED',grant_status='REVOKED',credential_ciphertext=null,access_expires_at=null,refresh_expires_at=null,revoked_at=now(),
    token_request_id=p_payload->>'provider_request_id',lease_token=null,lease_until=null,lease_kind=null,updated_at=now() where id=r.id returning * into r;
   return app_tiktok_dm.oauth_private(r);
  end if;
  if r.lease_kind<>'refresh' or p_payload-array['status','provider_request_id','open_id','scope','credential_ciphertext','access_expires_at','refresh_expires_at']<>'{}'::jsonb
   or p_payload->>'open_id' is distinct from r.open_id then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 else
  if r.lease_kind<>'callback' or st is null or st not in ('VERIFYING','VERIFIED_UNLINKED','USERNAME_MISMATCH','MISSING_PERMISSION','REJECTED','UNAVAILABLE')
   or p_payload-array['status','authorized_username','open_id','scope','credential_ciphertext','access_expires_at','refresh_expires_at','evidence','error_code']<>'{}'::jsonb then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
  if r.open_id is not null and r.open_id is distinct from p_payload->>'open_id' then return jsonb_build_object('ok',false,'code','TIKTOK_OAUTH_IDENTITY_MISMATCH');end if;
  e:=coalesce(p_payload->'evidence',r.evidence);
  if jsonb_typeof(e) is distinct from 'object' or e-array['app_id','token_creator_id','profile_username','verified_at','request_ids']<>'{}'::jsonb
   or e->>'app_id' is distinct from r.app_id or jsonb_typeof(e->'request_ids') is distinct from 'object'
   or (e->'request_ids')-array['exchange','token_info','profile']<>'{}'::jsonb
   or coalesce(e->'request_ids'->>'exchange','') !~ '^[A-Za-z0-9_-]{1,200}$'
   or (e->>'verified_at')::timestamptz is null or (e->>'verified_at')::timestamptz<now()-interval '5 minutes' or (e->>'verified_at')::timestamptz>now()+interval '1 minute' then return jsonb_build_object('ok',false,'code','INVALID_OAUTH_EVIDENCE');end if;
  if st in ('VERIFIED_UNLINKED','USERNAME_MISMATCH') then
   if e->>'token_creator_id' is distinct from p_payload->>'open_id' or e->>'profile_username' is distinct from p_payload->>'authorized_username'
    or coalesce(p_payload->>'authorized_username','') !~ '^[a-z0-9_.]{2,24}$'
    or coalesce(e->'request_ids'->>'token_info','') !~ '^[A-Za-z0-9_-]{1,200}$' or coalesce(e->'request_ids'->>'profile','') !~ '^[A-Za-z0-9_-]{1,200}$'
    or (st='VERIFIED_UNLINKED' and p_payload->>'authorized_username' is distinct from r.requested_username)
    or (st='USERNAME_MISMATCH' and p_payload->>'authorized_username'=r.requested_username) then return jsonb_build_object('ok',false,'code','INVALID_OAUTH_EVIDENCE');end if;
  end if;
 end if;
 exp:=(p_payload->>'access_expires_at')::timestamptz;refresh_exp:=(p_payload->>'refresh_expires_at')::timestamptz;
 if not app_tiktok_dm.valid_oauth_envelope(p_payload->'credential_ciphertext') or char_length(coalesce(p_payload->>'open_id','')) not between 1 and 256
  or jsonb_typeof(p_payload->'scope') is distinct from 'array' or jsonb_array_length(p_payload->'scope')>100
  or exists(select 1 from jsonb_array_elements(p_payload->'scope') s where jsonb_typeof(s)<>'string' or (s#>>'{}') !~ '^[A-Za-z0-9._-]{1,100}$')
  or exp is null or exp<=now() or exp>now()+interval '25 hours' or refresh_exp is null or refresh_exp<=now() or refresh_exp>now()+interval '367 days' then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 if st='VERIFIED_UNLINKED' and not (p_payload->'scope' ?& array['user.info.basic','user.info.username']) then return jsonb_build_object('ok',false,'code','TIKTOK_OAUTH_SCOPE_MISSING');end if;
 scope_lost:=st='REFRESHED' and not (p_payload->'scope' ?& array['user.info.basic','user.info.username']);
 update app_tiktok_dm.oauth_requests set
  status=case when scope_lost then 'MISSING_PERMISSION' when st='REFRESHED' then status when revoke_requested_at is not null then 'REVOKING' else st end,
  grant_status=case when scope_lost or revoke_requested_at is not null or st in ('USERNAME_MISMATCH','MISSING_PERMISSION','REJECTED','UNAVAILABLE') then 'REVOKING' else 'ACTIVE' end,
  revoke_requested_at=case when scope_lost or st in ('USERNAME_MISMATCH','MISSING_PERMISSION','REJECTED','UNAVAILABLE') then coalesce(revoke_requested_at,now()) else revoke_requested_at end,
  authorized_username=coalesce(p_payload->>'authorized_username',authorized_username),open_id=p_payload->>'open_id',scope=p_payload->'scope',credential_ciphertext=p_payload->'credential_ciphertext',
  access_expires_at=exp,refresh_expires_at=refresh_exp,evidence=coalesce(e,evidence),error_code=case when scope_lost then 'TIKTOK_OAUTH_SCOPE_MISSING' else err end,token_request_id=coalesce(p_payload->>'provider_request_id',token_request_id),
  lease_token=case when st='VERIFYING' then lease_token else null end,lease_until=case when st='VERIFYING' then lease_until else null end,
  lease_kind=case when st='VERIFYING' then lease_kind else null end,updated_at=now() where id=r.id returning * into r;
 return app_tiktok_dm.oauth_private(r);
exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format or numeric_value_out_of_range or check_violation then
 return jsonb_build_object('ok',false,'code','INVALID_INPUT');
 when unique_violation then return jsonb_build_object('ok',false,'code','TIKTOK_OAUTH_STATE_CONFLICT');
end $$;
alter table app_tiktok_dm.oauth_requests enable row level security;
alter table app_tiktok_dm.oauth_events enable row level security;
revoke all on app_tiktok_dm.oauth_requests,app_tiktok_dm.oauth_events from public,anon,authenticated,service_role;
revoke all on sequence app_tiktok_dm.oauth_events_id_seq from public,anon,authenticated,service_role;
revoke all on function app_tiktok_dm.valid_oauth_envelope(jsonb),app_tiktok_dm.oauth_private(app_tiktok_dm.oauth_requests),app_tiktok_dm.oauth_audit(),app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) to service_role;
commit;
