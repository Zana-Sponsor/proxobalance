-- Synchronize the wallet-ownership evidence between payout claim and settlement.
create or replace function public.ex_balance_claim_payout(
 p_payout_id uuid,p_admin_id uuid,p_verification text
) returns public.ex_payout_requests language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;
begin
 if not exists(select 1 from public.ex_profiles
    where id=p_admin_id and is_admin=true and is_banned=false) then
   raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_verification,'')))<10 or length(btrim(p_verification))>160 then
   raise exception 'DESTINATION_OWNERSHIP_VERIFICATION_REQUIRED' using errcode='22023';end if;
 select * into v_req from public.ex_payout_requests where id=p_payout_id for update;
 if not found then raise exception 'PAYOUT_NOT_FOUND' using errcode='22023';end if;
 if v_req.status='processing' and v_req.reviewed_by=p_admin_id then return v_req;end if;
 if v_req.status<>'pending' then
   raise exception 'PAYOUT_ALREADY_CLAIMED_OR_FINAL' using errcode='23514';end if;
 update public.ex_payout_requests set status='processing',reviewed_by=p_admin_id,
  processing_started_at=now(),processing_verification=left(btrim(p_verification),160),
  verification_reference=left(btrim(p_verification),160),
  updated_at=now()
 where id=p_payout_id returning * into v_req;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
  values(p_admin_id,'balance_payout_processing',v_req.user_id,
   'payout:'||p_payout_id||' IQD:'||v_req.amount_iqd);
 return v_req;
end $fn$;

update public.ex_payout_requests set verification_reference=processing_verification
where status='processing' and verification_reference is null
 and processing_verification is not null and length(processing_verification)<=160;
revoke execute on function public.ex_balance_start_payout(uuid,uuid,text) from service_role;
