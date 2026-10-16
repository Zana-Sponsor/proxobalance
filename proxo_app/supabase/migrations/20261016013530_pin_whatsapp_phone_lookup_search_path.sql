-- Pin the canonical phone helpers used by the OTP Edge handlers.
-- Both inspected bodies use pg_catalog built-ins and fully qualified
-- public objects; this changes name resolution, not matching semantics.
begin;
alter function public.pa_normalize_phone(text) set search_path = '';
alter function public.pa_profile_by_phone(text) set search_path = '';
commit;
