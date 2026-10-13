-- A signed-in user may clear only the tombstone matching their own Auth email.
create or replace function public.pa_restore_deleted_account()
returns boolean
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_user uuid := auth.uid();
  v_email text;
  v_deleted integer;
begin
  if v_user is null then return false; end if;
  select lower(email) into v_email from auth.users where id=v_user;
  if v_email is null then return false; end if;
  delete from public.deleted_accounts where lower(email)=v_email;
  get diagnostics v_deleted = row_count;
  return v_deleted>0;
end
$function$;

revoke all on function public.pa_restore_deleted_account() from public,anon;
grant execute on function public.pa_restore_deleted_account() to authenticated,service_role;
revoke all on function public.pa_is_admin() from public,anon;
grant execute on function public.pa_is_admin() to authenticated,service_role;
revoke all on function public.is_admin() from public,anon;
grant execute on function public.is_admin() to authenticated,service_role;
