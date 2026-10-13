-- Include bank-processing payouts in held liabilities.
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