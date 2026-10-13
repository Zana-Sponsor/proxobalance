-- Match final payout proof against the recorded beneficiary verification at claim time.
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
 if v_req.processing_verification is null or
   v_req.processing_verification is distinct from btrim(p_verification_reference) then
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

