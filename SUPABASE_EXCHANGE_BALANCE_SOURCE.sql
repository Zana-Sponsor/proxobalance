-- AccountBalance is a real Send source. Existing routes and balances are preserved.
alter table public.ex_orders add column balance_request_key uuid,
  add column balance_debit_journal_id uuid references public.ex_balance_journal(id) on delete restrict;
create unique index ex_orders_balance_request_once on public.ex_orders(user_id,balance_request_key)
  where balance_request_key is not null;
alter table public.ex_balance_journal drop constraint ex_balance_journal_kind_check;
alter table public.ex_balance_journal add constraint ex_balance_journal_kind_check
  check(kind in ('verified_refund','payout_hold','payout_cancel','payout_paid','order_debit'));
insert into public.ex_wallets(key,name,fee,fee_type,allow_from,allow_receive,is_locked,sort_order)
 values('AccountBalance','باڵانسی هەژمار',2,'percent',true,false,false,0);
alter table public.ex_wallets add constraint ex_wallets_balance_send_only
 check(key<>'AccountBalance' or allow_receive=false);
insert into public.ex_rates(from_method,to_method,rate_type,rate_value,is_active)
 select 'AccountBalance',key,'fee_percent',2,allow_receive and not is_locked
 from public.ex_wallets where key not in ('AccountBalance','USDT');
create or replace function public.ex_balance_post(
 p_user_id uuid,p_available_delta bigint,p_held_delta bigint,p_kind text,
 p_key text,p_order_id uuid,p_payout_id uuid,p_actor uuid,p_note text,p_evidence text default null
) returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_balance public.ex_customer_balances%rowtype;
        v_journal uuid; v_available bigint; v_held bigint; v_clearing bigint;
begin
 if p_kind not in ('verified_refund','payout_hold','payout_cancel','payout_paid','order_debit')
    or p_user_id is null or p_available_delta is null or p_held_delta is null
    or (p_available_delta=0 and p_held_delta=0)
    or length(coalesce(p_key,''))<4 or p_actor is null then
   raise exception 'INVALID_LEDGER_POST' using errcode='22023';
 end if;
 perform set_config('ex_balance.authorized_post','yes',true);
 insert into public.ex_customer_balances(user_id) values(p_user_id) on conflict(user_id) do nothing;
 select * into strict v_balance from public.ex_customer_balances
   where user_id=p_user_id for update;
 v_available:=v_balance.available_iqd+p_available_delta;
 v_held:=v_balance.held_iqd+p_held_delta;
 if v_available<0 or v_held<0 then
   raise exception 'INSUFFICIENT_BALANCE' using errcode='23514';
 end if;
 v_clearing:=-(p_available_delta+p_held_delta);
 insert into public.ex_balance_journal(operation_key,kind,user_id,order_id,payout_id,actor_id,note,evidence_ref)
 values(p_key,p_kind,p_user_id,p_order_id,p_payout_id,p_actor,p_note,p_evidence)
 returning id into v_journal;
 update public.ex_customer_balances set available_iqd=v_available,held_iqd=v_held,
   revision=revision+1,updated_at=now() where user_id=p_user_id;
 if p_available_delta<>0 then
   insert into public.ex_balance_entries(journal_id,account,user_id,delta_iqd,balance_after_iqd)
     values(v_journal,'customer_available',p_user_id,p_available_delta,v_available);
 end if;
 if p_held_delta<>0 then
   insert into public.ex_balance_entries(journal_id,account,user_id,delta_iqd,balance_after_iqd)
     values(v_journal,'customer_held',p_user_id,p_held_delta,v_held);
 end if;
 if v_clearing<>0 then
   insert into public.ex_balance_entries(journal_id,account,user_id,delta_iqd)
     values(v_journal,'platform_clearing',null,v_clearing);
 end if;
 perform set_config('ex_balance.authorized_post','no',true);
 return v_journal;
end $fn$;
revoke all on function public.ex_balance_post(uuid,bigint,bigint,text,text,uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.ex_balance_post(uuid,bigint,bigint,text,text,uuid,uuid,uuid,text,text) to service_role;


-- Account balance is never an external deposit destination and requires the atomic RPC.
create or replace function public.ex_balance_order_guard()
returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 if tg_op='INSERT' then
  if new.to_method='AccountBalance' then raise exception 'BALANCE_IS_SEND_ONLY' using errcode='22023';end if;
  if new.from_method='AccountBalance' then
   if current_setting('ex_balance.order_authorized',true) is distinct from new.user_id::text
      or new.balance_request_key is null or new.amount<>trunc(new.amount)
      or new.to_method='USDT' then
    raise exception 'ATOMIC_BALANCE_ORDER_REQUIRED' using errcode='42501';end if;
   new.receipt_url:=null;new.receipt_hash:=null;new.transaction_reference:=null;
   new.balance_debit_journal_id:=null;
  elsif new.balance_request_key is not null or new.balance_debit_journal_id is not null then
   raise exception 'INVALID_BALANCE_ORDER_FIELDS' using errcode='22023';
  end if;
 elsif old.from_method='AccountBalance' or new.from_method='AccountBalance' then
  if new.user_id is distinct from old.user_id or new.from_method is distinct from old.from_method
    or new.to_method is distinct from old.to_method or new.amount is distinct from old.amount
    or new.total is distinct from old.total or new.fee is distinct from old.fee
    or new.reward_id is distinct from old.reward_id or new.balance_request_key is distinct from old.balance_request_key
    or (old.balance_debit_journal_id is not null and new.balance_debit_journal_id is distinct from old.balance_debit_journal_id) then
   raise exception 'BALANCE_ORDER_FINANCIALS_IMMUTABLE' using errcode='23514';end if;
 end if;
 return new;
end $fn$;
revoke all on function public.ex_balance_order_guard() from public,anon,authenticated;
create trigger trg_ex_orders_balance_guard before insert or update on public.ex_orders
 for each row execute function public.ex_balance_order_guard();

create or replace function public.ex_balance_order_debit()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare j uuid;
begin
 if new.from_method='AccountBalance' then
  j:=public.ex_balance_post(new.user_id,-new.amount::bigint,0,'order_debit',
    'balance-order:'||new.id::text,new.id,null,new.user_id,'ناردن لە باڵانسی هەژمار',new.balance_request_key::text);
  update public.ex_orders set balance_debit_journal_id=j where id=new.id;
 end if;
 return null;
end $fn$;
revoke all on function public.ex_balance_order_debit() from public,anon,authenticated;
create trigger trg_ex_orders_balance_debit after insert on public.ex_orders
 for each row execute function public.ex_balance_order_debit();

create or replace function public.ex_balance_create_order(
 p_user_id uuid,p_request_key uuid,p_to text,p_amount bigint,p_phone text,p_security_log_id uuid default null
) returns public.ex_orders language plpgsql security definer set search_path='' as $fn$
declare o public.ex_orders%rowtype;
begin
 if p_user_id is null or p_request_key is null then raise exception 'INVALID_BALANCE_REQUEST' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,0));
 select * into o from public.ex_orders where user_id=p_user_id and balance_request_key=p_request_key;
 if found then
  if o.to_method is distinct from p_to or o.amount is distinct from p_amount or o.phone is distinct from p_phone then
   raise exception 'BALANCE_REQUEST_KEY_CONFLICT' using errcode='22023';end if;
  return o;
 end if;
 if p_amount is null or p_amount<10000 or p_amount>1000000000
    or not exists(select 1 from public.ex_profiles where id=p_user_id and not is_banned)
    or not exists(select 1 from public.ex_wallets where key='AccountBalance' and allow_from and not is_locked)
    or not exists(select 1 from public.ex_wallets where key=p_to and allow_receive and not is_locked)
    or p_to in ('AccountBalance','USDT')
    or not exists(select 1 from public.ex_rates where from_method='AccountBalance' and to_method=p_to and is_active)
    or p_phone is null or (p_to='QiCard' and p_phone !~ '^[0-9]{6,32}$')
    or (p_to<>'QiCard' and p_phone !~ '^07[0-9]{9}$') then
   raise exception 'INVALID_BALANCE_ORDER' using errcode='22023';end if;
 perform set_config('ex_balance.order_authorized',p_user_id::text,true);
 insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,balance_request_key,security_log_id)
 values(p_user_id,'AccountBalance',p_to,p_amount,0,p_phone,p_request_key,p_security_log_id) returning * into o;
 perform set_config('ex_balance.order_authorized','',true);
 select * into o from public.ex_orders where id=o.id;
 return o;
end $fn$;
revoke all on function public.ex_balance_create_order(uuid,uuid,text,bigint,text,uuid) from public,anon,authenticated;
grant execute on function public.ex_balance_create_order(uuid,uuid,text,bigint,text,uuid) to service_role;
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
   or (v_order.from_method<>'AccountBalance' and nullif(btrim(v_order.receipt_url),'') is null) then
   raise exception 'ORDER_NOT_ELIGIBLE_FOR_ADMIN_REFUND' using errcode='22023';end if;
 if v_order.receipt_hash is not null and exists(select 1 from public.ex_orders o
   where o.receipt_hash=v_order.receipt_hash and o.id<>v_order.id) then
   raise exception 'RECEIPT_HAS_MULTIPLE_ORDERS' using errcode='23505';end if;
 if exists(select 1 from public.ex_refund_cases r join public.ex_orders o on o.id=r.order_id
   where o.receipt_hash is not null and o.receipt_hash=v_order.receipt_hash) then
   raise exception 'RECEIPT_ALREADY_REFUNDED' using errcode='23505';end if;
 if v_order.from_method='AccountBalance' then
   if not exists(select 1 from public.ex_balance_journal j
     join public.ex_balance_entries e on e.journal_id=j.id
     where j.id=v_order.balance_debit_journal_id and j.order_id=v_order.id
       and j.user_id=v_order.user_id and j.kind='order_debit'
       and e.account='customer_available' and e.delta_iqd=-v_order.amount) then
     raise exception 'BALANCE_DEBIT_PROOF_REQUIRED' using errcode='22023';end if;
   p_verification_reference:='balance-debit:'||v_order.balance_debit_journal_id::text;
 end if;
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

