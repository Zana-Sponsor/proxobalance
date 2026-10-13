-- These helpers are only meaningful after authentication.  Keeping them off
-- the anonymous PostgREST surface reduces unnecessary SECURITY DEFINER entry
-- points without changing the signed-in application flow.
revoke execute on function public.is_ex_admin() from public, anon;
revoke execute on function public.pa_can_submit_ad() from public, anon;
revoke execute on function public.pa_trusted_device_forget(text) from public, anon;

grant execute on function public.pa_can_submit_ad() to authenticated;
grant execute on function public.pa_trusted_device_forget(text) to authenticated;
