-- Prevent cancellation while finance is transferring external money.
alter table public.ex_payout_requests drop constraint ex_payout_requests_status_check;
alter table public.ex_payout_requests add constraint ex_payout_requests_status_check
 check(status in ('pending','processing','paid','cancelled'));
alter table public.ex_payout_requests add column if not exists processing_started_at timestamptz;
alter table public.ex_payout_requests add column if not exists processing_verification text;

create or replace function public.ex_balance_claim_payout(
 p_payout_id uuid,p_admin_id uuid,p_verification text
) returns public.ex_payout_requests language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;
begin
 if not exists(select 1 from public.ex_profiles
    where id=p_admin_id and is_admin=true and is_banned=false) then
   raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_verification,'')))<10 then
   raise exception 'DESTINATION_OWNERSHIP_VERIFICATION_REQUIRED' using errcode='22023';end if;
 select * into v_req from public.ex_payout_requests where id=p_payout_id for update;
 if not found then raise exception 'PAYOUT_NOT_FOUND' using errcode='22023';end if;
 if v_req.status='processing' and v_req.reviewed_by=p_admin_id then return v_req;end if;
 if v_req.status<>'pending' then
   raise exception 'PAYOUT_ALREADY_CLAIMED_OR_FINAL' using errcode='23514';end if;
 update public.ex_payout_requests set status='processing',reviewed_by=p_admin_id,
  processing_started_at=now(),processing_verification=left(btrim(p_verification),500),
  updated_at=now()
 where id=p_payout_id returning * into v_req;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
  values(p_admin_id,'balance_payout_processing',v_req.user_id,
   'payout:'||p_payout_id||' IQD:'||v_req.amount_iqd);
 return v_req;
end $fn$;
revoke all on function public.ex_balance_claim_payout(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ex_balance_claim_payout(uuid,uuid,text) to service_role;

-- Existing customer/admin cancellation routine accepts pending only.
-- A processing payout requires explicit bank confirmation it was NOT transferred.
create or replace function public.ex_balance_abort_processing(
 p_payout_id uuid,p_admin_id uuid,p_reason text,
 p_bank_reference text,p_confirmed_unpaid boolean
) returns public.ex_payout_requests language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;v_journal uuid;
begin
 if not exists(select 1 from public.ex_profiles
   where id=p_admin_id and is_admin=true and is_banned=false) then
   raise exception 'ADMIN_REQUIRED' using errcode='42501';end if;
 if p_confirmed_unpaid is distinct from true or
   length(btrim(coalesce(p_reason,'')))<10 or
   length(btrim(coalesce(p_bank_reference,'')))<6 then
   raise exception 'BANK_CONFIRMED_UNPAID_REQUIRED' using errcode='22023';end if;
 select * into v_req from public.ex_payout_requests where id=p_payout_id for update;
 if not found or v_req.status<>'processing' then
   raise exception 'PAYOUT_NOT_PROCESSING' using errcode='23514';end if;
 v_journal:=public.ex_balance_post(v_req.user_id,v_req.amount_iqd,-v_req.amount_iqd,
   'payout_cancel','payout-abort:'||v_req.id,null,v_req.id,p_admin_id,
   left(btrim(p_reason),500),left(btrim(p_bank_reference),160));
 update public.ex_payout_requests set status='cancelled',
  settled_journal_id=v_journal,verification_reference=left(btrim(p_bank_reference),160),
  admin_note=left(btrim(p_reason),500),reviewed_by=p_admin_id,updated_at=now()
 where id=v_req.id returning * into v_req;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_payout_processing_aborted',v_req.user_id,
   'payout:'||v_req.id||' bank:'||left(btrim(p_bank_reference),160));
 insert into public.ex_notifications(user_id,type,title,message)
 values(v_req.user_id,'admin','داواکاری ناردن هەڵوەشێندرایەوە',
   'پارەکەت دوای پشتڕاستکردنەوەی نەئەنجامدانی ناردن بۆ باڵانسی بەردەست گەڕێندرایەوە.');
 return v_req;
end $fn$;
revoke all on function public.ex_balance_abort_processing(uuid,uuid,text,text,boolean)
 from public,anon,authenticated;
grant execute on function public.ex_balance_abort_processing(uuid,uuid,text,text,boolean) to service_role;

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

