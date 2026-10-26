-- A durable checkout that never acquired a gateway creation intent can be
-- closed without a provider request. This is distinct from an uncertain charge:
-- any creation intent, however old, continues through normal reconciliation.
begin;

create or replace function app_finance.ad_payment_result(a app_finance.ad_payment_attempts)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('ok',true,'attempt_id',a.id,'order_id',a.order_id,'transaction_id',a.payment_transaction_id,
 'environment',a.environment,'currency','IQD','amount_iqd',a.amount_iqd,'cost_usd',a.cost_usd,'fx_rate',a.fx_rate,
 'status',a.status,'expires_at',a.expires_at,'result',a.result,'ad_id',a.ad_id,'cancel_requested',a.cancel_requested_at is not null,
 'payment_not_started',a.status in ('cancelled','expired') and a.creation_hash is null and a.creation_started_at is null
   and a.gateway_transaction_id is null and a.verified_at is null and a.ad_id is null and a.result is null
   and not t.wallet_credited and t.gw_transaction_id is null and t.qr_url is null and t.qr_text is null,
 'qr_url',case when a.cancel_requested_at is null and a.status not in ('declined','cancelled','expired','funded','compensated') and a.expires_at>now() then t.qr_url end,
 'qr_text',case when a.cancel_requested_at is null and a.status not in ('declined','cancelled','expired','funded','compensated') and a.expires_at>now() then t.qr_text end)
 from public.pa_transactions t where t.id=a.payment_transaction_id;
$$;

-- Once a no-intent closure has been exposed to a client it is irreversible.
-- Even a later service call cannot reopen it or attach a payment to it. A
-- captured attempt has a creation hash and never meets this predicate.
create function app_finance.protect_closed_unstarted_payment() returns trigger
language plpgsql set search_path='' as $$
begin
 if old.status in ('cancelled','expired') and old.creation_hash is null and old.creation_started_at is null
  and (new.status not in ('cancelled','expired') or new.creation_hash is not null or new.creation_started_at is not null
    or new.gateway_transaction_id is not null or new.verified_at is not null or new.ad_id is not null or new.result is not null) then
  raise exception 'PAYMENT_ATTEMPT_CLOSED_UNSTARTED';
 end if;
 return new;
end $$;
create trigger ad_payment_closed_unstarted before update on app_finance.ad_payment_attempts
 for each row execute function app_finance.protect_closed_unstarted_payment();

-- Keep transaction history consistent for every no-intent closure path,
-- including the existing owner-cancel RPC and background expiry worker.
create function app_finance.close_unstarted_payment_receipt() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status in ('cancelled','expired') and new.creation_hash is null and new.creation_started_at is null
   and new.gateway_transaction_id is null and new.verified_at is null and new.ad_id is null and new.result is null then
  update public.pa_transactions set status='rejected',gateway_status=upper(new.status),
    fail_reason='Payment was not started',updated_at=now()
   where id=new.payment_transaction_id and not wallet_credited and gw_transaction_id is null and qr_url is null and qr_text is null
     and (status is distinct from 'rejected' or gateway_status is distinct from upper(new.status));
 end if;
 return new;
end $$;
create trigger ad_payment_unstarted_receipt after update of status on app_finance.ad_payment_attempts
 for each row execute function app_finance.close_unstarted_payment_receipt();

alter function app_finance.ad_payment_service(text,uuid,jsonb) rename to ad_payment_service_before_unstarted_closure;
revoke all on function app_finance.ad_payment_service_before_unstarted_closure(text,uuid,jsonb) from public,anon,authenticated,service_role;

create function app_finance.ad_payment_service(p_action text,p_attempt_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a app_finance.ad_payment_attempts%rowtype;t public.pa_transactions%rowtype;
begin
 if p_action='close_unstarted' then
  -- create_intent takes the same row lock before authorizing the gateway POST.
  -- If it won the race, return the actual started attempt with no closure proof.
  select * into a from app_finance.ad_payment_attempts where id=p_attempt_id for update;
  if not found then return jsonb_build_object('ok',false,'code','PAYMENT_ATTEMPT_NOT_FOUND');end if;
  if a.status='prepared' and a.creation_hash is null and a.creation_started_at is null
    and a.gateway_transaction_id is null and a.verified_at is null and a.ad_id is null and a.result is null then
   select * into t from public.pa_transactions where id=a.payment_transaction_id for update;
   if t.wallet_credited or t.gw_transaction_id is not null or t.qr_url is not null or t.qr_text is not null then
    return jsonb_build_object('ok',false,'code','PAYMENT_RECONCILIATION_REQUIRED');
   end if;
   if a.promo_reservation_id is not null then
    delete from public.promo_code_usages where id=a.promo_reservation_id and ad_id is null;
    if found then update public.promo_codes set used_count=greatest(coalesce(used_count,0)-1,0),updated_at=now() where id=a.promo_id;end if;
   end if;
   update app_finance.ad_payment_attempts set status='cancelled',cancel_requested_at=coalesce(cancel_requested_at,now()),
    last_error_code=left(p_payload->>'error_code',80),lease_token=null,lease_until=null where id=a.id returning * into a;
  end if;
  return app_finance.ad_payment_result(a);
 end if;
 if p_action in ('observe_verified','observe_status','unknown') then
  -- No lock-order change for the legacy verifier: it obtains the submission
  -- advisory lock before its row lock. The permanent trigger also closes the
  -- race if this read precedes a concurrent close_unstarted commit.
  select * into a from app_finance.ad_payment_attempts where id=p_attempt_id;
  if found and a.status in ('cancelled','expired') and a.creation_hash is null and a.creation_started_at is null then
   if p_action='unknown' then return app_finance.ad_payment_result(a);end if;
   return jsonb_build_object('ok',false,'code','PAYMENT_ATTEMPT_NOT_STARTED');
  end if;
 end if;
 return app_finance.ad_payment_service_before_unstarted_closure(p_action,p_attempt_id,p_payload);
end $$;

create or replace function public.pa_ad_payment_service(p_action text,p_attempt_id uuid default null,p_payload jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$select app_finance.ad_payment_service(p_action,p_attempt_id,p_payload);$$;
revoke all on function app_finance.protect_closed_unstarted_payment(),app_finance.close_unstarted_payment_receipt(),app_finance.ad_payment_service(text,uuid,jsonb),
 public.pa_ad_payment_service(text,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function app_finance.ad_payment_service(text,uuid,jsonb),public.pa_ad_payment_service(text,uuid,jsonb) to service_role;
commit;
