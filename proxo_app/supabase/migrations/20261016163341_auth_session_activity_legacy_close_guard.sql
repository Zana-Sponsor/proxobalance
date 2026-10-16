-- Keep the legacy manual-close RPC compatible with old unlinked app rows.
-- Auth-linked rows close only when Auth actually revokes their session.
create or replace function public.pa_login_close_session(p_login_id uuid)
returns void language sql security definer set search_path='' as $$
  update public.pa_login_history set logout_time=now()
  where id=p_login_id and logout_time is null and session_id is null
    and (user_id=auth.uid() or public.pa_is_admin());
$$;
revoke all on function public.pa_login_close_session(uuid) from public,anon;
grant execute on function public.pa_login_close_session(uuid) to authenticated;
