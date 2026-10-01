-- Close legacy account-takeover RPCs. Password/email mutations now require a
-- fresh, single-use OTP belonging to the target Auth user.
create or replace function public.proxo_reset_password(
  p_user_id uuid, p_otp_id uuid, p_new_password text
)
returns boolean
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_otp uuid;
begin
  if p_user_id is null or p_otp_id is null or char_length(p_new_password)<6 then
    return false;
  end if;
  delete from public.otp_codes o
   where o.id=p_otp_id
     and o.user_id=p_user_id
     and o.is_used=true
     and o.purpose='reset_password'
     and o.created_at>now()-interval '15 minutes'
  returning o.id into v_otp;
  if v_otp is null then return false; end if;
  update auth.users
     set encrypted_password=extensions.crypt(p_new_password,extensions.gen_salt('bf')),
         updated_at=now()
   where id=p_user_id;
  return found;
end
$function$;

create or replace function public.proxo_confirm_email(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_email text;
  v_otp uuid;
begin
  select lower(email) into v_email from auth.users where id=p_user_id;
  if v_email is null then raise exception 'invalid_user' using errcode='42501'; end if;
  delete from public.otp_codes o
   where o.id=(
     select id from public.otp_codes
      where user_id=p_user_id and lower(email)=v_email and is_used=true
        and purpose in ('signup','login')
        and created_at>now()-interval '15 minutes'
      order by created_at desc limit 1 for update skip locked
   )
  returning o.id into v_otp;
  if v_otp is null then raise exception 'otp_required' using errcode='42501'; end if;
  update auth.users set email_confirmed_at=coalesce(email_confirmed_at,now()),
    updated_at=now() where id=p_user_id;
end
$function$;

-- Old APIs allowed anyone to change a password by knowing an email address.
revoke all on function public.reset_user_password(text,text) from public,anon,authenticated;
grant execute on function public.reset_user_password(text,text) to service_role;
revoke all on function public.update_user_password(text,text) from public,anon,authenticated;
grant execute on function public.update_user_password(text,text) to service_role;
revoke all on function public.find_user_by_email(text) from public,anon,authenticated;
grant execute on function public.find_user_by_email(text) to service_role;

revoke all on function public.proxo_reset_password(uuid,uuid,text) from public;
grant execute on function public.proxo_reset_password(uuid,uuid,text) to anon,authenticated,service_role;
revoke all on function public.proxo_confirm_email(uuid) from public;
grant execute on function public.proxo_confirm_email(uuid) to anon,authenticated,service_role;

do $block$
declare r record;
begin
  for r in
    select p.oid::regprocedure signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any(array[
      'pa_find_transaction','pa_login_close_session','pa_login_heartbeat',
      'pa_login_logout_others','submit_ad_update','submit_identity_verification'
    ])
  loop
    execute format('revoke all on function %s from public,anon',r.signature);
    execute format('grant execute on function %s to authenticated,service_role',r.signature);
  end loop;
end
$block$;
