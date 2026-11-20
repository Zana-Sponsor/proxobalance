-- v56: the customer can cancel a waiting order; the admin can put an order
-- "under review" (then it can no longer be cancelled); the admins get a
-- WhatsApp message when an order waits 15 minutes.
--   • Cancelled: no WhatsApp message (only an admin rejection sends one).
--     Paid from the account balance → the amount returns to the balance at once.
--     Paid from a wallet → it waits until an admin checks the receipt and
--     returns the amount to the balance (ex_admin_reject_and_refund keeps the
--     order cancelled).
--   • Prices and fees are not touched.

-- ── statuses ──────────────────────────────────────────────────────────
alter table public.ex_orders drop constraint if exists ex_orders_status_check;
alter table public.ex_orders add constraint ex_orders_status_check check (status = any (array[
  'چاوەڕوانە', 'لەژێر پێداچوونەوەدایە', 'پێویستی بە ڕاستکردنەوەیە', 'ڕاستکراوەتەوە',
  'پەسەندکرا', 'ڕەتکرا', 'هەڵوەشێنرایەوە']));
alter table public.ex_orders
  add column if not exists review_started_at timestamptz,
  add column if not exists review_by uuid,
  add column if not exists cancelled_at timestamptz;

-- a balance order the customer cancels is recorded like every other return to the balance
alter table public.ex_refund_cases drop constraint if exists ex_refund_cases_refund_kind_check;
alter table public.ex_refund_cases add constraint ex_refund_cases_refund_kind_check
  check (refund_kind = any (array['failed_payout', 'admin_rejection', 'customer_cancel']));
alter table public.ex_refund_cases drop constraint if exists ex_refund_cases_confirmation_kind_check;
alter table public.ex_refund_cases add constraint ex_refund_cases_confirmation_kind_check
  check ((refund_kind = 'failed_payout' and confirmed_payout_failed)
      or (refund_kind in ('admin_rejection', 'customer_cancel') and not confirmed_payout_failed));

-- ── customer: cancel ──────────────────────────────────────────────────
create or replace function public.ex_order_cancel(p_order uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  o public.ex_orders%rowtype;
  v_case public.ex_refund_cases%rowtype;
  v_journal uuid;
  v_amt bigint;
  v_ref text;
  v_tag text;
  v_note text := 'هەڵوەشاندنەوەی داواکاری لەلایەن کڕیار';
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode = '42501'; end if;
  if exists (select 1 from public.ex_site_controls where key in ('site', 'transactions') and paused) then
    raise exception 'SECTION_PAUSED' using errcode = 'P0001';
  end if;
  select * into o from public.ex_orders where id = p_order and user_id = v_uid and user_deleted_at is null for update;
  if not found then raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  if o.status = 'لەژێر پێداچوونەوەدایە' then raise exception 'ORDER_UNDER_REVIEW' using errcode = 'P0001'; end if;
  if o.status not in ('چاوەڕوانە', 'پێویستی بە ڕاستکردنەوەیە', 'ڕاستکراوەتەوە')
     or o.balance_refunded_at is not null or o.balance_refund_case_id is not null
     or o.payout_settlement_id is not null or coalesce(o.shortfall_refunded_iqd, 0) > 0
     or o.from_method = 'USDT' or o.to_method = 'USDT'
     or (o.from_method <> 'AccountBalance' and nullif(btrim(coalesce(o.receipt_url, '')), '') is null) then
    raise exception 'ORDER_NOT_CANCELLABLE' using errcode = 'P0001';
  end if;

  -- no "status changed" notice and no WhatsApp message for the customer's own cancel
  perform set_config('ex_admin.silent', o.id::text, true);
  update public.ex_orders set status = 'هەڵوەشێنرایەوە', cancelled_at = now(),
         review_started_at = null, review_by = null
   where id = o.id;

  v_tag := chr(8296) || coalesce(o.order_code, o.order_number::text) || chr(8297);
  if o.from_method = 'AccountBalance' then
    if not exists (select 1 from public.ex_balance_journal j
        join public.ex_balance_entries e on e.journal_id = j.id
       where j.id = o.balance_debit_journal_id and j.order_id = o.id and j.user_id = o.user_id
         and j.kind = 'order_debit' and e.account = 'customer_available' and e.delta_iqd = -o.amount) then
      raise exception 'BALANCE_DEBIT_PROOF_REQUIRED' using errcode = '22023';
    end if;
    v_amt := o.amount::bigint;
    v_ref := 'balance-debit:' || o.balance_debit_journal_id::text;
    v_journal := public.ex_balance_post(o.user_id, v_amt, 0, 'verified_refund', 'refund:' || o.id::text,
      o.id, null, v_uid, v_note, v_ref);
    insert into public.ex_refund_cases (order_id, user_id, amount_iqd, receipt_url, bank_verification_reference,
      failure_reason, verified_by, confirmed_funds_received, confirmed_payout_failed, journal_id, refund_kind)
    values (o.id, o.user_id, v_amt, null, v_ref, v_note, v_uid, true, false, v_journal, 'customer_cancel')
    returning * into v_case;
    update public.ex_orders set balance_refund_case_id = v_case.id, balance_refunded_at = now() where id = o.id;
    insert into public.ex_notifications (user_id, order_id, type, title, message)
    values (o.user_id, o.id, 'order_status', 'داواکارییەکەت هەڵوەشێنرایەوە',
      'داواکاری ' || v_tag || ' هەڵوەشێنرایەوە و بڕی ' || to_char(v_amt, 'FM999,999,999,999') || ' دینار گەڕایەوە بۆ باڵانسەکەت.');
  else
    insert into public.ex_notifications (user_id, order_id, type, title, message)
    values (o.user_id, o.id, 'order_status', 'داواکارییەکەت هەڵوەشێنرایەوە',
      'داواکاری ' || v_tag || ' هەڵوەشێنرایەوە. دوای پشکنینی پسوولەکە، بڕەکە دەخرێتە سەر باڵانسەکەت.');
  end if;

  select * into o from public.ex_orders where id = p_order;
  return jsonb_build_object('status', o.status, 'refunded', o.balance_refunded_at is not null,
    'amount_iqd', case when o.balance_refunded_at is not null then o.amount end);
end;
$$;
revoke all on function public.ex_order_cancel(uuid) from public, anon;
grant execute on function public.ex_order_cancel(uuid) to authenticated, service_role;

-- ── admin: under review (/api/admin order_review) ─────────────────────
create or replace function public.ex_admin_order_review(p_order uuid, p_on boolean, p_admin uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare o public.ex_orders%rowtype;
begin
  if p_admin is null or not public.ex_admin_can_manage_orders(p_admin, 'basic') then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  select * into o from public.ex_orders where id = p_order for update;
  if not found then raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  if o.balance_refunded_at is not null or o.payout_settlement_id is not null then
    raise exception 'ORDER_NOT_REVIEWABLE' using errcode = 'P0001';
  end if;
  if coalesce(p_on, true) then
    if o.status not in ('چاوەڕوانە', 'ڕاستکراوەتەوە') then raise exception 'ORDER_NOT_REVIEWABLE' using errcode = 'P0001'; end if;
    update public.ex_orders set status = 'لەژێر پێداچوونەوەدایە', review_started_at = now(), review_by = p_admin
     where id = o.id returning * into o;
  else
    if o.status <> 'لەژێر پێداچوونەوەدایە' then raise exception 'ORDER_NOT_IN_REVIEW' using errcode = 'P0001'; end if;
    perform set_config('ex_admin.silent', o.id::text, true);
    update public.ex_orders
       set status = case when o.correction_count > 0 and o.correction_responded_at is not null then 'ڕاستکراوەتەوە' else 'چاوەڕوانە' end,
           review_started_at = null, review_by = null
     where id = o.id returning * into o;
  end if;
  insert into public.ex_admin_audit_log (admin_id, action, target_user_id, detail)
  values (p_admin, case when coalesce(p_on, true) then 'order_review_start' else 'order_review_stop' end, o.user_id, 'order:' || o.order_code);
  return to_jsonb(o);
end;
$$;
revoke all on function public.ex_admin_order_review(uuid, boolean, uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_order_review(uuid, boolean, uuid) to service_role;

-- approving works from "under review" too (one line of each approval function)
do $patch$
declare
  v_fn regprocedure;
  v_def text;
  v_old constant text := $q$if o.status not in ('چاوەڕوانە','ڕاستکراوەتەوە') or o.status is null$q$;
  v_new constant text := $q$if o.status not in ('چاوەڕوانە','ڕاستکراوەتەوە','لەژێر پێداچوونەوەدایە') or o.status is null$q$;
begin
  foreach v_fn in array array[
    'public.ex_admin_approve_order_settlement(uuid,uuid,uuid,timestamptz,numeric,numeric,boolean,boolean,text,text)'::regprocedure,
    'public.ex_admin_approve_order_with_refund(uuid,uuid,uuid,timestamptz,numeric,numeric,boolean,boolean,text,text,numeric,text)'::regprocedure]
  loop
    v_def := pg_get_functiondef(v_fn);
    if position(v_new in v_def) > 0 then continue; end if;
    if position(v_old in v_def) = 0 then raise exception 'approval status check not found in %', v_fn; end if;
    execute replace(v_def, v_old, v_new);
  end loop;
end $patch$;

-- a cancelled wallet order: the admin checks the receipt, then returns the amount
-- to the balance; the order stays cancelled (no "rejected", so no WhatsApp message)
create or replace function public.ex_admin_reject_and_refund(p_order_id uuid, p_admin_id uuid, p_verification_reference text, p_reason text, p_confirmed_received boolean)
returns public.ex_refund_cases
language plpgsql
security definer
set search_path = ''
as $function$
declare v_order public.ex_orders%rowtype;v_case public.ex_refund_cases%rowtype;
 v_journal uuid;v_amt bigint;
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
 if v_order.status<>'هەڵوەشێنرایەوە' then
   update public.ex_orders set status='ڕەتکرا',admin_note=btrim(p_reason),decided_at=now()
     where id=v_order.id;
 end if;
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
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_admin_rejection_refund',v_order.user_id,
   'refund:'||v_case.id||' order:'||v_order.order_code||' IQD:'||v_amt);
 insert into public.ex_notifications(user_id,order_id,type,title,message)
 values(v_order.user_id,v_order.id,'admin','پارەکەت گەڕێندرایەوە',
   case when v_order.status='هەڵوەشێنرایەوە'
     then 'داواکاری '||chr(8296)||coalesce(v_order.order_code,'')||chr(8297)||' هەڵوەشێنرایەوە و بڕی '||to_char(v_amt,'FM999,999,999,999')||' دینار بۆ باڵانسی هەژمارەکەت زیاد کرا.'
     else 'بە بڕیاری ئادمین، مامەڵەکەت ڕەتکرایەوە و بڕی '||v_amt||' دینار بۆ باڵانسی هەژمارەکەت زیاد کرا.' end);
 return v_case;
end $function$;

-- manual status in the panel knows the two new statuses
create or replace function public.ex_admin_order_set_status(p_order uuid, p_status text, p_reason text default null::text, p_clear_reason boolean default false, p_notify boolean default false, p_admin_id uuid default null::uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_admin uuid := coalesce(auth.uid(), p_admin_id);
  o public.ex_orders%rowtype; n public.ex_orders%rowtype;
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
  v_note text; v_notified boolean := false;
begin
  if v_admin is null or not public.ex_admin_can_manage_orders(v_admin,'basic') then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  if p_status is null or p_status not in ('چاوەڕوانە','لەژێر پێداچوونەوەدایە','پێویستی بە ڕاستکردنەوەیە','ڕاستکراوەتەوە','پەسەندکرا','ڕەتکرا','هەڵوەشێنرایەوە') then
    raise exception 'STATUS_INVALID' using errcode='22023';
  end if;
  if v_reason is not null and length(v_reason) > 500 then raise exception 'REASON_TOO_LONG' using errcode='22023'; end if;
  select * into o from public.ex_orders where id = p_order for update;
  if not found then raise exception 'ORDER_NOT_FOUND' using errcode='P0002'; end if;

  v_note := case when coalesce(p_clear_reason,false) then null when v_reason is not null then v_reason else o.admin_note end;
  if p_status = o.status and v_note is not distinct from o.admin_note then
    raise exception 'NO_CHANGES' using errcode='22023';
  end if;
  if p_status is distinct from o.status then
    if o.payout_settlement_id is not null then raise exception 'ORDER_SETTLED_LOCKED' using errcode='23514'; end if;
    if o.balance_refunded_at is not null or exists(select 1 from public.ex_refund_cases where order_id=o.id) then
      raise exception 'ORDER_REFUNDED_LOCKED' using errcode='23514'; end if;
    if o.shortfall_refunded_iqd > 0 or exists(select 1 from public.ex_order_shortfall_refunds where order_id=o.id) then
      raise exception 'ORDER_SHORTFALL_LOCKED' using errcode='23514'; end if;
  end if;

  perform set_config('ex_admin.order_manual', o.id::text, true);
  if not coalesce(p_notify,false) then perform set_config('ex_admin.silent', o.id::text, true); end if;

  begin
    update public.ex_orders set
      status = p_status,
      admin_note = v_note,
      decided_at = case when p_status = o.status then o.decided_at
                        when p_status in ('پەسەندکرا','ڕەتکرا') then now() else null end,
      handled_by = case when p_status = o.status then o.handled_by
                        when p_status in ('پەسەندکرا','ڕەتکرا') then v_admin else null end,
      review_started_at = case when p_status = 'لەژێر پێداچوونەوەدایە' then coalesce(o.review_started_at, now()) else null end,
      review_by = case when p_status = 'لەژێر پێداچوونەوەدایە' then coalesce(o.review_by, v_admin) else null end,
      cancelled_at = case when p_status = 'هەڵوەشێنرایەوە' then coalesce(o.cancelled_at, now()) else null end
    where id = o.id returning * into n;
  exception when unique_violation then
    raise exception 'DUPLICATE_RECEIPT' using errcode='23505';
  end;

  if coalesce(p_notify,false) and p_status = o.status then
    insert into public.ex_notifications(user_id,order_id,type,title,message)
    values(o.user_id,o.id,'order_status','دۆخی داواکارییەکەت گۆڕا',
      'داواکاری '||chr(8296)||o.order_code||chr(8297)||' - '||p_status||coalesce(' — '||v_note,''));
  end if;
  v_notified := coalesce(p_notify,false);

  insert into public.ex_order_admin_actions(order_id,order_code,user_id,admin_id,action,reason,notified,old_data,new_data)
  values(o.id,o.order_code,o.user_id,v_admin,'status',v_reason,v_notified,
    jsonb_build_object('status',o.status,'admin_note',o.admin_note,'decided_at',o.decided_at,'handled_by',o.handled_by),
    jsonb_build_object('status',n.status,'admin_note',n.admin_note,'decided_at',n.decided_at,'handled_by',n.handled_by));
  insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
  values(v_admin,'order_manual_status',o.user_id,'order:'||o.order_code||' '||o.status||' -> '||n.status||case when v_notified then ' notify' else ' silent' end);
  return jsonb_build_object('order',to_jsonb(n),'notified',v_notified);
end $function$;

-- the customer's notice for the new statuses
create or replace function public.ex_notify_order_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare order_tag text := chr(8296) || coalesce(new.order_code,'P-' || lpad(new.order_number::text,6,'0')) || chr(8297);
  v_message text;
begin
  if current_setting('ex_admin.silent',true) is not distinct from old.id::text then
    return new;
  end if;
  if new.status is distinct from old.status then
    if new.status = 'پەسەندکرا' and new.payout_settlement_id is not null then
      v_message := 'داواکاری ' || order_tag || ' پەسەندکرا. ' ||
        case when new.payout_iqd > 0 then 'بڕی ' || new.payout_iqd || ' دینار بۆ وەرگر نێردرا. '
          else 'ناردنی دەرەکی نییە. ' end ||
        case when new.payout_rounding_iqd > 0 then 'پاشماوەی ' || new.payout_rounding_iqd || ' دینار بۆ باڵانسی هەژمارەکەت گەڕێندرایەوە.'
          else 'پاشماوەی گەڕاندنەوە نییە.' end;
    elsif new.status = 'پەسەندکرا' then
      v_message := 'داواکاری ' || order_tag || ' بە سەرکەوتوویی پەسەندکرا و بڕەکە دەگاتە دەستت.';
    elsif new.status = 'ڕەتکرا' then
      v_message := 'داواکاری ' || order_tag || ' ڕەتکرایەوە.';
    elsif new.status = 'لەژێر پێداچوونەوەدایە' then
      v_message := 'داواکاری ' || order_tag || ' لەژێر پێداچوونەوەدایە.';
    elsif new.status = 'هەڵوەشێنرایەوە' then
      v_message := 'داواکاری ' || order_tag || ' هەڵوەشێنرایەوە.';
    else v_message := 'داواکاری ' || order_tag || ' - ' || new.status;
    end if;
    if nullif(new.admin_note,'') is not null and new.status <> 'لەژێر پێداچوونەوەدایە' then
      v_message := v_message || case when new.status = 'ڕەتکرا' then ' هۆکار: ' else ' — ' end || new.admin_note;
    end if;
    insert into public.ex_notifications(user_id,order_id,type,title,message) values(new.user_id,new.id,
      case when new.status = 'پەسەندکرا' then 'order_approved' when new.status = 'ڕەتکرا' then 'order_rejected' else 'order_status' end,
      case when new.status = 'پەسەندکرا' then 'داواکارییەکەت پەسەندکرا 🎉'
        when new.status = 'ڕەتکرا' then 'داواکارییەکەت ڕەتکرایەوە ❌'
        when new.status = 'لەژێر پێداچوونەوەدایە' then 'داواکارییەکەت لەژێر پێداچوونەوەدایە'
        when new.status = 'هەڵوەشێنرایەوە' then 'داواکارییەکەت هەڵوەشێنرایەوە'
        else 'دۆخی داواکارییەکەت گۆڕا' end,v_message);
  end if;
  return new;
end $function$;

-- an account with a cancelled order that still waits for its money is not closed yet
create or replace function public.ex_account_deletion_blocker(p_user uuid)
returns text
language sql
stable security definer
set search_path = ''
as $function$
  select case
    when exists (select 1 from public.ex_profiles p where p.id = p_user and (p.role <> 'user' or p.is_admin)) then 'STAFF'
    when coalesce((select b.available_iqd + b.held_iqd from public.ex_customer_balances b where b.user_id = p_user), 0) > 0 then 'BALANCE'
    when exists (select 1 from public.ex_orders o where o.user_id = p_user and o.status not in ('پەسەندکرا','ڕەتکرا')
                   and not (o.status = 'هەڵوەشێنرایەوە' and o.balance_refunded_at is not null)) then 'OPEN_ORDERS'
    when exists (select 1 from public.ex_payout_requests r where r.user_id = p_user and r.status in ('pending','processing')) then 'OPEN_PAYOUTS'
    else null end
$function$;
create or replace function public.ex_account_deletion_info()
returns jsonb
language plpgsql
stable security definer
set search_path = ''
as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode = '42501'; end if;
  return jsonb_build_object(
    'blocker', public.ex_account_deletion_blocker(v_uid),
    'balance_iqd', coalesce((select b.available_iqd + b.held_iqd from public.ex_customer_balances b where b.user_id = v_uid), 0),
    'open_orders', (select count(*) from public.ex_orders o where o.user_id = v_uid and o.status not in ('پەسەندکرا','ڕەتکرا')
                      and not (o.status = 'هەڵوەشێنرایەوە' and o.balance_refunded_at is not null)));
end $function$;

-- ── admin WhatsApp: an order waiting 15 minutes ───────────────────────
create table if not exists public.ex_admin_alert_phones (
  phone      text primary key check (phone ~ '^\+9647[0-9]{9}$'),
  label      text check (label is null or char_length(label) <= 60),
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid
);
alter table public.ex_admin_alert_phones enable row level security;
revoke all on public.ex_admin_alert_phones from anon, authenticated;

create table if not exists public.ex_order_admin_alerts (
  order_id   uuid primary key references public.ex_orders(id) on delete cascade,
  alerted_at timestamptz not null default now(),
  recipients integer not null default 0
);
alter table public.ex_order_admin_alerts enable row level security;
revoke all on public.ex_order_admin_alerts from anon, authenticated;

-- the template is found by its name once it is created in Wevlix; it sends after Meta approves it
alter table public.ex_whatsapp_templates alter column template_id drop not null;
insert into public.ex_whatsapp_templates (kind, template_id, template_name, active, updated_at)
values ('admin_order_waiting', null, 'proxo_admin_order_waiting', false, now())
on conflict (kind) do nothing;

create or replace function public.ex_wa_sync_templates(p_key text, p_templates jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_count integer := 0;
begin
  if p_key is null or not exists (select 1 from public.ex_whatsapp_worker_keys k
      where k.active and k.key_hash = encode(extensions.digest(p_key, 'sha256'), 'hex')) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.ex_whatsapp_templates t set
    template_id = coalesce(t.template_id, x.item ->> 'id'),
    active = coalesce((x.item -> 'readiness' ->> 'canSend')::boolean, false),
    meta_status = x.item ->> 'status',
    template_name = coalesce(x.item ->> 'name', t.template_name),
    checked_at = now(),
    updated_at = case when t.active is distinct from coalesce((x.item -> 'readiness' ->> 'canSend')::boolean, false) then now() else t.updated_at end
  from (select value as item from jsonb_array_elements(coalesce(p_templates, '[]'::jsonb))) x
  where t.template_id = x.item ->> 'id'
     or (t.template_id is null and t.template_name = x.item ->> 'name'
         and not exists (select 1 from public.ex_whatsapp_templates o where o.template_id = x.item ->> 'id'));
  get diagnostics v_count = row_count;
  return jsonb_build_object('ok', true, 'updated', v_count,
    'templates', (select jsonb_agg(jsonb_build_object('kind', kind, 'active', active, 'status', meta_status)) from public.ex_whatsapp_templates));
end $function$;

create or replace function public.ex_admin_order_alerts_tick()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl public.ex_whatsapp_templates;
  o record;
  v_code text;
  v_amount text;
  v_sent integer;
  v_count integer := 0;
begin
  select * into v_tpl from public.ex_whatsapp_templates where kind = 'admin_order_waiting' and active and template_id is not null;
  if not found or not exists (select 1 from public.ex_admin_alert_phones where active) then return 0; end if;
  for o in
    select x.id, x.order_code, x.order_number, x.amount, x.from_method,
           coalesce(x.correction_responded_at, x.created_at) as since
      from public.ex_orders x
     where x.status in ('چاوەڕوانە', 'ڕاستکراوەتەوە')
       and x.balance_refunded_at is null
       and coalesce(x.correction_responded_at, x.created_at) <= now() - interval '15 minutes'
       and x.created_at >= now() - interval '24 hours'
       and not exists (select 1 from public.ex_order_admin_alerts a where a.order_id = x.id)
     order by x.created_at
     limit 20
  loop
    v_code := coalesce(o.order_code, o.order_number::text);
    v_amount := to_char(o.amount, 'FM999,999,999,990.##') || case when o.from_method = 'USDT' then ' USD' else ' IQD' end;
    v_amount := regexp_replace(v_amount, '\. ', ' ');
    insert into public.ex_whatsapp_messages (kind, order_id, user_id, phone, template_id, params)
    select 'admin_order_waiting', null, null, p.phone, v_tpl.template_id,
           jsonb_build_object('body', jsonb_build_array(v_code, floor(extract(epoch from now() - o.since) / 60)::int::text, v_amount),
                              'button', jsonb_build_array(v_code), 'order_code', v_code)
      from public.ex_admin_alert_phones p where p.active;
    get diagnostics v_sent = row_count;
    insert into public.ex_order_admin_alerts (order_id, recipients) values (o.id, v_sent) on conflict (order_id) do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.ex_admin_order_alerts_tick() from public, anon, authenticated;
grant execute on function public.ex_admin_order_alerts_tick() to service_role;

-- the WhatsApp log shows the order code of an admin message too
create or replace function public.ex_admin_whatsapp_log(p_status text default null::text, p_query text default null::text, p_limit integer default 200)
returns table(id uuid, kind text, created_at timestamptz, sent_at timestamptz, updated_at timestamptz, status text, attempts integer,
  last_error text, wevlix_message_id text, phone text, order_id uuid, order_code text, order_status text, user_id uuid,
  customer_name text, username text, email text)
language plpgsql
stable security definer
set search_path = ''
as $function$
declare q text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if not (public.is_ex_admin() or public.ex_staff_has('view')) then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  return query
  select m.id, m.kind, m.created_at, m.sent_at, m.updated_at, m.status, m.attempts, m.last_error, m.wevlix_message_id, m.phone,
         m.order_id, coalesce(o.order_code, m.params ->> 'order_code'), o.status, m.user_id, p.full_name, p.username, p.email
    from public.ex_whatsapp_messages m
    left join public.ex_orders o on o.id = m.order_id
    left join public.ex_profiles p on p.id = m.user_id
   where (p_status is null or p_status = 'all' or m.status = p_status or (p_status = 'pending' and m.status in ('queued','sending')))
     and (q is null or coalesce(o.order_code, m.params ->> 'order_code') ilike '%' || q || '%' or m.phone ilike '%' || q || '%'
          or p.full_name ilike '%' || q || '%' or p.username ilike '%' || q || '%' or p.email ilike '%' || q || '%')
   order by m.created_at desc
   limit greatest(1, least(coalesce(p_limit, 200), 500));
end $function$;

do $cron$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'ex-admin-order-alerts';
  perform cron.schedule('ex-admin-order-alerts', '* * * * *', 'select public.ex_admin_order_alerts_tick()');
end $cron$;
