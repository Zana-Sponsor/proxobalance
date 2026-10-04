-- The current product scope keeps contact analytics and tokens server-only.
-- Retain the owner-checked helper for trusted server verification without
-- exposing its aggregate counts or tracking tokens to Flutter clients.
revoke all on function public.proxolink_ad_summary(uuid) from public,anon,authenticated;
grant execute on function public.proxolink_ad_summary(uuid) to service_role;
