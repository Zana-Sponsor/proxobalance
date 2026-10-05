-- Stop customer cancellations the instant an admin claims a payout.
-- Claims MUST precede all external bank/wallet transfers.
alter table public.ex_payout_requests drop constraint if exists ex_payout_requests_status_check;
alter table public.ex_payout_requests add constraint ex_payout_requests_status_check
 check(status in ('pending','processing','paid','cancelled'));
create or replace function public.ex_balance_start_payout(
 p_payout_id uuid,p_admin_id uuid,p_destination_verification text
) returns public.ex_payout_requests
language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;
begin
 if not exists(select 1 from public.ex_profiles where id=p_admin_id
   and is_admin=true and is_banned=false) then
     raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_destination_verification,'')))<6
   or length(btrim(p_destination_verification))>160 then
     raise exception 'DESTINATION_OWNERSHIP_PROOF_REQUIRED' using errcode='22023'; end if;
 select * into v_req from public.ex_payout_requests where id=p_payout_id for update;
 if not found or v_req.status<>'pending' then
     raise exception 'PAYOUT_NOT_PENDING' using errcode='22023'; end if;
 update public.ex_payout_requests set
   status='processing', verification_reference=btrim(p_destination_verification),
   reviewed_by=p_admin_id,updated_at=now()
 where id=v_req.id returning * into v_req;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_payout_processing',v_req.user_id,
  'payout:'||v_req.id||' IQD:'||v_req.amount_iqd);
 return v_req;
end $fn$;
revoke all on function public.ex_balance_start_payout(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ex_balance_start_payout(uuid,uuid,text) to service_role;

create or replace function public.ex_balance_mark_payout_paid(
 p_payout_id uuid,p_admin_id uuid,p_reference text,p_verification_reference text,
 p_receipt_url text,p_note text
) returns public.ex_payout_requests language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;v_journal uuid;
begin
 if not exists(select 1 from public.ex_profiles where id=p_admin_id and is_admin=true and is_banned=false) then
   raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_reference,'')))<6
    or length(btrim(coalesce(p_verification_reference,'')))<6
    or coalesce(p_receipt_url,'') not like 'https://%'
    or length(btrim(coalesce(p_note,'')))<10 then
   raise exception 'PAID_PROOF_AND_DESTINATION_VERIFICATION_REQUIRED' using errcode='22023'; end if;
 select * into v_req from public.ex_payout_requests where id=p_payout_id for update;
 if not found or v_req.status<>'processing' then
   raise exception 'PAYOUT_ALREADY_FINAL_OR_MISSING' using errcode='22023'; end if;
 if v_req.verification_reference is distinct from btrim(p_verification_reference) then
    raise exception 'DESTINATION_VERIFICATION_MISMATCH' using errcode='22023'; end if;
 v_journal:=public.ex_balance_post(v_req.user_id,0,-v_req.amount_iqd,
    'payout_paid','payout-paid:'||v_req.id,null,v_req.id,p_admin_id,
    left(btrim(p_note),500),left(p_receipt_url,2000));
 update public.ex_payout_requests set status='paid',settled_journal_id=v_journal,
    transfer_reference=left(btrim(p_reference),160),
    verification_reference=left(btrim(p_verification_reference),160),
    payout_receipt_url=left(p_receipt_url,2000),admin_note=left(btrim(p_note),500),
    reviewed_by=p_admin_id,updated_at=now()
  where id=v_req.id returning * into v_req;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_payout_paid',v_req.user_id,
    'payout:'||v_req.id||' IQD:'||v_req.amount_iqd);
 insert into public.ex_notifications(user_id,type,title,message)
 values(v_req.user_id,'admin','ناردنی باڵانس تەواو بوو',
    'داواکاری ناردنی '||v_req.amount_iqd||' دینار جێبەجێ کرا.');
 return v_req;
end $fn$;

-- Read-only admin reconciliation across the immutable ledger and current liabilities.
create or replace function public.ex_admin_balance_reconcile(p_admin_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_unbalanced bigint;v_balance_drift bigint;v_hold_drift bigint;
 v_unlinked_refunds bigint;v_liability numeric;v_clearing numeric;
begin
 if not exists(select 1 from public.ex_profiles where id=p_admin_id
   and is_admin=true and is_banned=false) then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
 end if;
 select count(*) into v_unbalanced from (
   select j.id from public.ex_balance_journal j
   left join public.ex_balance_entries e on e.journal_id=j.id
   group by j.id
   having count(e.id)<2 or coalesce(sum(e.delta_iqd),0)<>0
 ) drift;
 with actual as (
   select user_id,
    coalesce(sum(delta_iqd) filter(where account='customer_available'),0) as available,
    coalesce(sum(delta_iqd) filter(where account='customer_held'),0) as held
   from public.ex_balance_entries where user_id is not null group by user_id
 )
 select count(*) into v_balance_drift
 from public.ex_customer_balances b left join actual a using(user_id)
 where b.available_iqd<>coalesce(a.available,0)
    or b.held_iqd<>coalesce(a.held,0);
 with waiting as (
   select user_id,coalesce(sum(amount_iqd),0) as amt from public.ex_payout_requests
   where status in ('pending','processing') group by user_id
 )
 select count(*) into v_hold_drift
 from public.ex_customer_balances b left join waiting w using(user_id)
 where b.held_iqd<>coalesce(w.amt,0);
 select count(*) into v_unlinked_refunds
 from public.ex_refund_cases r
 join public.ex_orders o on o.id=r.order_id
 where o.balance_refund_case_id is distinct from r.id
    or o.balance_refunded_at is null
    or not exists(
      select 1 from public.ex_balance_entries e
       where e.journal_id=r.journal_id and e.account='customer_available'
         and e.user_id=r.user_id and e.delta_iqd=r.amount_iqd
    );
 select coalesce(sum(available_iqd+held_iqd),0) into v_liability
   from public.ex_customer_balances;
 select coalesce(sum(delta_iqd),0) into v_clearing
   from public.ex_balance_entries where account='platform_clearing';
 return jsonb_build_object(
   'unbalanced_journals',v_unbalanced,'balance_mismatches',v_balance_drift,
   'held_payout_mismatches',v_hold_drift,'unlinked_refunds',v_unlinked_refunds,
   'customer_liability_iqd',v_liability,'platform_clearing_iqd',v_clearing,
   'clearing_mismatch',v_liability+v_clearing<>0,
   'checked_at',now()
 );
end $fn$;
revoke all on function public.ex_admin_balance_reconcile(uuid) from public,anon,authenticated;
grant execute on function public.ex_admin_balance_reconcile(uuid) to service_role;