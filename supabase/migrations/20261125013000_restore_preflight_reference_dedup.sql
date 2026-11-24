-- Restore the reference-based duplicate lookup in the preflight promotion function.
-- This keeps reused payment references visible in the existing admin receipt history.
create or replace function public.ex_customer_receipt_preflight_promote(p_order_id uuid,p_check_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare
  o public.ex_orders%rowtype; d public.ex_customer_receipt_preflights%rowtype; v_ref_norm text; v_duplicate uuid; v_amount_matches boolean;
begin
  select * into o from public.ex_orders where id=p_order_id;
  if not found then return false; end if;
  select * into d from public.ex_customer_receipt_preflights where id=p_check_id for update;
  if not found or d.status<>'complete' or d.is_receipt is distinct from true
     or d.amount_matches is distinct from true or d.receiver_matches is distinct from true
     or d.claimed_at is null or d.linked_order_id is not null or d.user_id<>o.user_id
     or d.from_method<>o.from_method or d.to_method<>o.to_method or d.expected_amount<>o.amount
     or d.receipt_url is distinct from o.receipt_url or d.receipt_hash is distinct from o.receipt_hash then return false; end if;
  v_amount_matches:=case when o.from_method='USDT' then abs(d.actual_amount-o.amount)<0.000001 else d.actual_amount=o.amount end;
  v_ref_norm:=nullif(upper(regexp_replace(coalesce(d.reference,''),'[^0-9A-Za-z]','','g')),'');
  if length(coalesce(v_ref_norm,''))<6 then v_ref_norm:=null; end if;
  if v_ref_norm is not null then
    select rr.order_id into v_duplicate from public.ex_receipt_reads rr join public.ex_orders prior on prior.id=rr.order_id
     where rr.reference_norm=v_ref_norm and rr.order_id<>o.id
       and (prior.status<>'ڕەتکرا' or prior.user_id<>o.user_id) order by prior.created_at limit 1;
  end if;
  insert into public.ex_receipt_reads(
    order_id,status,is_receipt,wallet,success,status_text,amount,currency,reference,reference_norm,paid_at,
    sender_name,sender_account,receiver_name,receiver_account,notes,amount_matches,duplicate_order_id,model,error,attempts,read_at
  ) values (
    o.id,'ok',true,nullif(left(d.wallet,60),''),d.success,nullif(left(d.status_text,120),''),d.actual_amount,
    nullif(left(upper(d.actual_currency),8),''),nullif(left(btrim(d.reference),120),''),v_ref_norm,nullif(left(d.paid_at,60),''),
    nullif(left(d.sender_name,120),''),nullif(left(d.sender_account,60),''),nullif(left(d.receiver_name,120),''),
    nullif(left(d.receiver_account,60),''),nullif(left(d.notes,400),''),v_amount_matches,v_duplicate,nullif(left(d.model,60),''),null,1,now()
  ) on conflict(order_id) do update set status=excluded.status,is_receipt=excluded.is_receipt,wallet=excluded.wallet,
    success=excluded.success,status_text=excluded.status_text,amount=excluded.amount,currency=excluded.currency,
    reference=excluded.reference,reference_norm=excluded.reference_norm,paid_at=excluded.paid_at,sender_name=excluded.sender_name,
    sender_account=excluded.sender_account,receiver_name=excluded.receiver_name,receiver_account=excluded.receiver_account,
    notes=excluded.notes,amount_matches=excluded.amount_matches,duplicate_order_id=excluded.duplicate_order_id,
    model=excluded.model,error=null,attempts=ex_receipt_reads.attempts+1,read_at=now();
  update public.ex_customer_receipt_preflights set linked_order_id=o.id,updated_at=now() where id=d.id;
  return true;
end; $$;
