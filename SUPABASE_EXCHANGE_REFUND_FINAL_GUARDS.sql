-- Preserve original refunded orders and restore a redeemed reward once.
create or replace function public.ex_balance_credit_refund(
 p_order_id uuid,p_admin_id uuid,p_verification_reference text,p_failure_reason text,
 p_confirmed_received boolean,p_confirmed_failed boolean
) returns public.ex_refund_cases language plpgsql security definer set search_path='' as $fn$
declare v_order public.ex_orders%rowtype;v_case public.ex_refund_cases%rowtype;
        v_journal uuid;v_amt bigint;v_reward_id uuid;
begin
 if not exists(select 1 from public.ex_profiles
    where id=p_admin_id and is_admin=true and is_banned=false) then
    raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_confirmed_received is distinct from true or p_confirmed_failed is distinct from true
    or length(btrim(coalesce(p_failure_reason,'')))<10
    or length(btrim(coalesce(p_verification_reference,'')))<6 then
    raise exception 'VERIFIED_FUNDS_AND_FAILED_PAYOUT_PROOF_REQUIRED' using errcode='22023'; end if;
 select * into v_order from public.ex_orders where id=p_order_id for update;
 if not found then raise exception 'ORDER_NOT_FOUND' using errcode='22023'; end if;
 if v_order.status='پەسەندکرا' or v_order.from_method='USDT'
    or v_order.to_method='USDT' or v_order.amount<>trunc(v_order.amount)
    or v_order.amount<10000 or v_order.amount>1000000000 then
    raise exception 'ORDER_NOT_ELIGIBLE_FOR_IQD_REFUND' using errcode='22023'; end if;
 -- Never credit a receipt that has already been resubmitted as another order.
 if v_order.receipt_hash is not null and exists(
   select 1 from public.ex_orders o where o.receipt_hash=v_order.receipt_hash and o.id<>v_order.id
 ) then raise exception 'RECEIPT_HAS_MULTIPLE_ORDERS' using errcode='23505'; end if;
 if exists(select 1 from public.ex_refund_cases where order_id=p_order_id) or
    exists(select 1 from public.ex_refund_cases r join public.ex_orders o on o.id=r.order_id
     where o.receipt_hash is not null and o.receipt_hash=v_order.receipt_hash) then
    raise exception 'ORDER_ALREADY_REFUNDED' using errcode='23505'; end if;
 v_amt:=v_order.amount::bigint;
 v_journal:=public.ex_balance_post(v_order.user_id,v_amt,0,'verified_refund',
     'refund:'||v_order.id::text,v_order.id,null,p_admin_id,
     left(p_failure_reason,2000),left(btrim(p_verification_reference),160));
 insert into public.ex_refund_cases(order_id,user_id,amount_iqd,receipt_url,
    bank_verification_reference,failure_reason,verified_by,
    confirmed_funds_received,confirmed_payout_failed,journal_id)
 values(v_order.id,v_order.user_id,v_amt,v_order.receipt_url,
    left(btrim(p_verification_reference),160),left(btrim(p_failure_reason),2000),
    p_admin_id,true,true,v_journal) returning * into v_case;
 update public.ex_orders set balance_refund_case_id=v_case.id,balance_refunded_at=now()
  where id=v_order.id;
 -- A refunded order must not consume a free-transaction or fee-discount reward.
 update public.ex_reward_usages set reversed_at=now()
  where order_id=v_order.id and reversed_at is null
  returning reward_id into v_reward_id;
 if v_reward_id is not null then
  update public.ex_user_rewards set used_count=greatest(0,used_count-1),updated_at=now()
   where id=v_reward_id;
 end if;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_verified_refund',v_order.user_id,
       'refund:'||v_case.id||' order:'||v_order.order_code||' IQD:'||v_amt);
 insert into public.ex_notifications(user_id,order_id,type,title,message)
 values(v_order.user_id,v_order.id,'admin','پارەکەت گەڕێندرایەوە',
        'بڕی '||v_amt||' دینار بۆ باڵانسی هەژمارەکەت زیاد کرا.');
 return v_case;
end $fn$;
revoke all on function public.ex_balance_credit_refund(uuid,uuid,text,text,boolean,boolean) from public,anon,authenticated;
grant execute on function public.ex_balance_credit_refund(uuid,uuid,text,text,boolean,boolean) to service_role;



create or replace function public.ex_balance_guard_refunded_order()
returns trigger language plpgsql set search_path='' as $fn$
begin
 if tg_op='INSERT' then
   if new.receipt_hash is not null and exists(
     select 1 from public.ex_refund_cases r join public.ex_orders o on o.id=r.order_id
     where o.receipt_hash=new.receipt_hash) then
      raise exception 'REFUNDED_RECEIPT_NOT_REUSABLE' using errcode='23505';
   end if;
   return new;
 end if;
 if tg_op='UPDATE' and old.balance_refunded_at is not null then
   if new.status is distinct from old.status or
      new.amount is distinct from old.amount or
      new.total is distinct from old.total or
      new.from_method is distinct from old.from_method or
      new.to_method is distinct from old.to_method or
      new.receipt_hash is distinct from old.receipt_hash or
      new.receipt_url is distinct from old.receipt_url or
      new.phone is distinct from old.phone then
      raise exception 'REFUNDED_ORDER_IMMUTABLE' using errcode='23514';
   end if;
 end if;
 if tg_op='UPDATE' and new.status='پەسەندکرا'
     and old.status is distinct from new.status
     and exists(select 1 from public.ex_refund_cases where order_id=old.id) then
      raise exception 'REFUNDED_ORDER_CANNOT_BE_APPROVED' using errcode='23514';
 end if;
 return new;
end $fn$;
create trigger trg_ex_orders_guard_refunded_financials before update of
  amount,total,from_method,to_method,receipt_hash,receipt_url,phone
 on public.ex_orders for each row execute function public.ex_balance_guard_refunded_order();
