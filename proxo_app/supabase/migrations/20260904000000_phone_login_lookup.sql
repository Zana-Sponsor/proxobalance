-- ─────────────────────────────────────────────────────────────────────────────
-- pa_phone_exists — pre-check before sending a WhatsApp OTP
-- ─────────────────────────────────────────────────────────────────────────────
-- The login screen must know whether a number belongs to an existing account
-- BEFORE it fires the send-OTP webhook, so we do not pay Wevlix to deliver a
-- code that could never be used.
--
-- Why this needs SECURITY DEFINER:
--   `profiles` has RLS enabled and all seven of its policies are scoped to the
--   `authenticated` role. A user sitting on the login screen is `anon`, so a
--   direct `select ... from profiles where phone = $1` returns zero rows for
--   EVERY number — including real ones. The pre-check would reject all logins.
--
-- ⚠ Deliberately returns ONLY a boolean. It never returns the id, email, name
-- or any other column, so it cannot be used to read profile data. The function
-- is also STABLE and takes an exact-match argument — no LIKE, no listing.
--
-- ⚠ Known trade-off: this is a phone-number enumeration oracle. Anyone with the
-- anon key can test whether a given number has an account. That is inherent to
-- the requirement — the screen must tell an unregistered user to sign up first,
-- which reveals the same fact. It is limited, not eliminated:
--   • one boolean per call, exact match only
--   • no data beyond existence
-- If enumeration becomes a concern, put a rate limit in front of it (pg_cron
-- counter table, or move the check into the Edge Function behind a captcha).
-- Do NOT "fix" it by removing the pre-check — that just moves the cost to the
-- Wevlix bill.

create or replace function public.pa_phone_exists(p_phone text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where phone = p_phone
  );
$$;

comment on function public.pa_phone_exists(text) is
  'Login pre-check: does an account exist for this E.164 phone? Boolean only.';

revoke all on function public.pa_phone_exists(text) from public;
grant execute on function public.pa_phone_exists(text) to anon, authenticated;
