-- Admin-directed rejection/refund and a per-order principal cap for fee rewards.
-- Existing rewards keep unlimited amount coverage until an admin grants a cap.
-- No customer, order, refund, balance or reward grant is created by this script.
alter table public.ex_user_rewards add column if not exists max_amount_iqd bigint;
alter table public.ex_user_rewards add constraint ex_user_rewards_amount_cap_check
  check (max_amount_iqd is null or max_amount_iqd between 1 and 1000000000);
alter table public.ex_orders
  add column if not exists reward_covered_amount_iqd numeric,
  add column if not exists reward_cap_iqd bigint;
alter table public.ex_reward_usages
  add column if not exists covered_amount_iqd numeric,
  add column if not exists amount_cap_iqd bigint;
comment on column public.ex_user_rewards.max_amount_iqd is
  'Maximum principal covered by this reward per transaction; NULL means unlimited.';

-- Pure pricing helper. The uncovered principal keeps the normal route fee.
-- With a fixed per-transfer fee, any uncovered principal still bears that fee.
create or replace function public.ex_reward_quote(
 p_amount numeric,p_rate_type text,p_rate_value numeric,
 p_kind text,p_percent numeric,p_cap bigint
) returns jsonb language plpgsql immutable set search_path='' as $fn$
declare v_base numeric;v_base_fee numeric;v_covered numeric:=0;
 v_excess numeric;v_excess_total numeric;v_eligible_fee numeric:=0;v_discount numeric:=0;
begin
 if p_amount is null or p_amount<0 or p_amount>1000000000
    or p_amount='NaN'::numeric or p_rate_value is null or p_rate_value<0
    or p_rate_value='NaN'::numeric
    or (p_cap is not null and (p_cap<1 or p_cap>1000000000)) then
   raise exception 'INVALID_REWARD_PRICING' using errcode='22023';end if;
 if p_rate_type='fee_percent' then
   if p_rate_value>100 then raise exception 'INVALID_FEE_PERCENT' using errcode='22023';end if;
   v_base:=floor(greatest(0,p_amount-p_amount*p_rate_value/100));
 elsif p_rate_type='fee_fixed' then
   v_base:=floor(greatest(0,p_amount-p_rate_value));
 elsif p_rate_type='multiplier' then
   v_base:=floor(p_amount*p_rate_value);
 else raise exception 'INVALID_REWARD_RATE_TYPE' using errcode='22023';end if;
 v_base_fee:=greatest(p_amount-v_base,0);
 if p_kind in ('free_transactions','fee_discount') and v_base_fee>0 then
   if p_kind='fee_discount' and (p_percent is null or p_percent<=0 or p_percent>100) then
     raise exception 'INVALID_REWARD_PERCENT' using errcode='22023';end if;
   v_covered:=least(p_amount,coalesce(p_cap,p_amount));
 end if;
 v_excess:=p_amount-v_covered;
 if p_rate_type='fee_percent' then
   v_excess_total:=floor(greatest(0,v_excess-v_excess*p_rate_value/100));
 elsif p_rate_type='fee_fixed' then
   v_excess_total:=floor(greatest(0,v_excess-p_rate_value));
 else v_excess_total:=floor(v_excess*p_rate_value);end if;
 v_eligible_fee:=greatest(0,v_base_fee-greatest(v_excess-v_excess_total,0));
 if p_kind='free_transactions' then v_discount:=v_eligible_fee;
 elsif p_kind='fee_discount' then v_discount:=floor(v_eligible_fee*p_percent/100);end if;
 v_discount:=least(v_base_fee,greatest(v_discount,0));
 return jsonb_build_object('base_total',v_base,'base_fee',v_base_fee,
   'covered_amount_iqd',v_covered,'excess_amount_iqd',v_excess,
   'discount_iqd',v_discount,'total',v_base+v_discount,
   'fee',greatest(p_amount-v_base-v_discount,0));
end $fn$;
revoke all on function public.ex_reward_quote(numeric,text,numeric,text,numeric,bigint)
  from public,anon,authenticated;
grant execute on function public.ex_reward_quote(numeric,text,numeric,text,numeric,bigint) to service_role;

create or replace function public.ex_rewards_apply_on_order()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare v_reward public.ex_user_rewards%rowtype;v_rate public.ex_rates%rowtype;v_quote jsonb;
begin
 new.reward_id:=null;new.reward_discount_iqd:=0;new.reward_original_fee_iqd:=null;
 new.reward_covered_amount_iqd:=null;new.reward_cap_iqd:=null;
 if new.from_method='USDT' or new.to_method='USDT' then return new;end if;
 select * into v_rate from public.ex_rates
  where from_method=new.from_method and to_method=new.to_method and is_active
  limit 1 for share;
 if not found then raise exception 'EXCHANGE_RATE_NOT_AVAILABLE' using errcode='22023';end if;
 v_quote:=public.ex_reward_quote(new.amount,v_rate.rate_type,v_rate.rate_value,null,null,null);
 new.total:=(v_quote->>'total')::numeric;new.fee:=(v_quote->>'fee')::numeric;
 if new.fee<=0 then return new;end if;
 select * into v_reward from public.ex_user_rewards
  where user_id=new.user_id and active
   and (valid_until is null or valid_until>now())
   and (max_uses is null or used_count<max_uses)
  order by valid_until asc nulls last,
   case when kind='free_transactions' then 0 else 1 end,created_at,id
  limit 1 for update;
 if not found then return new;end if;
 v_quote:=public.ex_reward_quote(new.amount,v_rate.rate_type,v_rate.rate_value,
   v_reward.kind,v_reward.discount_percent,v_reward.max_amount_iqd);
 if (v_quote->>'discount_iqd')::numeric<=0 then return new;end if;
 update public.ex_user_rewards set used_count=used_count+1,updated_at=now() where id=v_reward.id;
 new.reward_id:=v_reward.id;
 new.reward_discount_iqd:=(v_quote->>'discount_iqd')::numeric;
 new.reward_original_fee_iqd:=(v_quote->>'base_fee')::numeric;
 new.reward_covered_amount_iqd:=(v_quote->>'covered_amount_iqd')::numeric;
 new.reward_cap_iqd:=v_reward.max_amount_iqd;
 new.total:=(v_quote->>'total')::numeric;new.fee:=(v_quote->>'fee')::numeric;
 return new;
end $fn$;
revoke all on function public.ex_rewards_apply_on_order() from public,anon,authenticated;

create or replace function public.ex_rewards_record_order()
returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 if new.reward_id is not null and new.reward_discount_iqd>0 then
  insert into public.ex_reward_usages(reward_id,user_id,order_id,original_fee_iqd,
    discount_iqd,covered_amount_iqd,amount_cap_iqd)
  values(new.reward_id,new.user_id,new.id,new.reward_original_fee_iqd,
    new.reward_discount_iqd,new.reward_covered_amount_iqd,new.reward_cap_iqd);
 end if;
 return null;
end $fn$;
revoke all on function public.ex_rewards_record_order() from public,anon,authenticated;

alter table public.ex_refund_cases
  add column if not exists refund_kind text not null default 'failed_payout';
alter table public.ex_refund_cases add constraint ex_refund_cases_refund_kind_check
  check(refund_kind in ('failed_payout','admin_rejection'));
alter table public.ex_refund_cases drop constraint ex_refund_cases_confirmed_payout_failed_check;
alter table public.ex_refund_cases add constraint ex_refund_cases_confirmation_kind_check
  check ((refund_kind='failed_payout' and confirmed_payout_failed)
    or (refund_kind='admin_rejection' and not confirmed_payout_failed));
comment on column public.ex_refund_cases.failure_reason is
  'Refund reason/note, including an admin-directed rejection; not necessarily a payout failure.';

-- Only an explicit authenticated admin action calls this service-only RPC.
-- No failure event or ordinary status rejection automatically credits a balance.
create or replace function public.ex_admin_reject_and_refund(
 p_order_id uuid,p_admin_id uuid,p_verification_reference text,p_reason text,
 p_confirmed_received boolean
) returns public.ex_refund_cases language plpgsql security definer set search_path='' as $fn$
declare v_order public.ex_orders%rowtype;v_case public.ex_refund_cases%rowtype;
 v_journal uuid;v_amt bigint;v_reward_id uuid;
begin
 if not exists(select 1 from public.ex_profiles
   where id=p_admin_id and is_admin and not is_banned) then
   raise exception 'ADMIN_REQUIRED' using errcode='42501';end if;
 if p_confirmed_received is distinct from true
   or length(btrim(coalesce(p_reason,''))) not between 10 and 2000
   or length(btrim(coalesce(p_verification_reference,''))) not between 6 and 160 then
   raise exception 'RECEIVED_FUNDS_REFERENCE_AND_REFUND_REASON_REQUIRED' using errcode='22023';end if;
 select * into v_order from public.ex_orders where id=p_order_id for update;
 if not found then raise exception 'ORDER_NOT_FOUND' using errcode='22023';end if;
 select * into v_case from public.ex_refund_cases where order_id=p_order_id;
 if found then return v_case;end if;
 if v_order.status='پەسەندکرا' or nullif(btrim(v_order.payout_receipt_url),'') is not null
   or v_order.from_method='USDT' or v_order.to_method='USDT'
   or v_order.amount<>trunc(v_order.amount) or v_order.amount<10000 or v_order.amount>1000000000
   or nullif(btrim(v_order.receipt_url),'') is null then
   raise exception 'ORDER_NOT_ELIGIBLE_FOR_ADMIN_REFUND' using errcode='22023';end if;
 if v_order.receipt_hash is not null and exists(select 1 from public.ex_orders o
   where o.receipt_hash=v_order.receipt_hash and o.id<>v_order.id) then
   raise exception 'RECEIPT_HAS_MULTIPLE_ORDERS' using errcode='23505';end if;
 if exists(select 1 from public.ex_refund_cases r join public.ex_orders o on o.id=r.order_id
   where o.receipt_hash is not null and o.receipt_hash=v_order.receipt_hash) then
   raise exception 'RECEIPT_ALREADY_REFUNDED' using errcode='23505';end if;
 -- The following status change, quota restoration, ledger posting and refund
 -- record all roll back together if any check/unique constraint fails.
 update public.ex_orders set status='ڕەتکرا',admin_note=btrim(p_reason),decided_at=now()
   where id=v_order.id;
 v_amt:=v_order.amount::bigint;
 v_journal:=public.ex_balance_post(v_order.user_id,v_amt,0,'verified_refund',
   'refund:'||v_order.id::text,v_order.id,null,p_admin_id,btrim(p_reason),btrim(p_verification_reference));
 insert into public.ex_refund_cases(order_id,user_id,amount_iqd,receipt_url,
   bank_verification_reference,failure_reason,verified_by,confirmed_funds_received,
   confirmed_payout_failed,journal_id,refund_kind)
 values(v_order.id,v_order.user_id,v_amt,v_order.receipt_url,btrim(p_verification_reference),
   btrim(p_reason),p_admin_id,true,false,v_journal,'admin_rejection') returning * into v_case;
 update public.ex_orders set balance_refund_case_id=v_case.id,balance_refunded_at=now()
   where id=v_order.id;
 -- Also handles a previously rejected order whose usage has not been restored.
 update public.ex_reward_usages set reversed_at=now()
   where order_id=v_order.id and reversed_at is null returning reward_id into v_reward_id;
 if v_reward_id is not null then
   update public.ex_user_rewards set used_count=greatest(0,used_count-1),updated_at=now()
    where id=v_reward_id;
 end if;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_admin_rejection_refund',v_order.user_id,
   'refund:'||v_case.id||' order:'||v_order.order_code||' IQD:'||v_amt);
 insert into public.ex_notifications(user_id,order_id,type,title,message)
 values(v_order.user_id,v_order.id,'admin','پارەکەت گەڕێندرایەوە',
   'بە بڕیاری ئادمین، مامەڵەکەت ڕەتکرایەوە و بڕی '||v_amt||' دینار بۆ باڵانسی هەژمارەکەت زیاد کرا.');
 return v_case;
end $fn$;
revoke all on function public.ex_admin_reject_and_refund(uuid,uuid,text,text,boolean)
  from public,anon,authenticated;
grant execute on function public.ex_admin_reject_and_refund(uuid,uuid,text,text,boolean) to service_role;

-- Compatibility for an older deployed server. The old failed flag is no
-- longer a precondition or a claim recorded on a new admin-directed refund.
create or replace function public.ex_balance_credit_refund(
 p_order_id uuid,p_admin_id uuid,p_verification_reference text,p_failure_reason text,
 p_confirmed_received boolean,p_confirmed_failed boolean
) returns public.ex_refund_cases language sql security definer set search_path='' as $fn$
 select public.ex_admin_reject_and_refund(p_order_id,p_admin_id,p_verification_reference,
   p_failure_reason,p_confirmed_received);
$fn$;
revoke all on function public.ex_balance_credit_refund(uuid,uuid,text,text,boolean,boolean)
  from public,anon,authenticated;
grant execute on function public.ex_balance_credit_refund(uuid,uuid,text,text,boolean,boolean) to service_role;
