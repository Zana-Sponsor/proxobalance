-- v57
--   • Wallets live only in ex_wallets: the two wallet rules the code used to know by
--     name (a card number instead of a phone; the sender's phone for carrier credit)
--     become columns, set from the admin panel.
--   • OTP codes are no longer readable or editable from the panel, and the old
--     browser OTP check is closed (the server checks codes itself).
--   • A ban can carry a reason, shown to the customer.
--   • Rates and fees are not touched.

-- ── wallet rules ──────────────────────────────────────────────────────
alter table public.ex_wallets
  add column if not exists recipient_format text not null default 'phone',
  add column if not exists sender_phone_required boolean not null default false;
alter table public.ex_wallets drop constraint if exists ex_wallets_recipient_format_check;
alter table public.ex_wallets add constraint ex_wallets_recipient_format_check check (recipient_format in ('phone', 'card'));
-- the rules that were written in the code until now
update public.ex_wallets set recipient_format = 'card' where key = 'QiCard' and recipient_format <> 'card';
update public.ex_wallets set sender_phone_required = true where key in ('Korek', 'Asiacell') and not sender_phone_required;

-- a recipient for this wallet: a card (6–32 digits) or an Iraqi mobile number
create or replace function public.ex_wallet_recipient_ok(p_wallet text, p_value text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when p_value is null then false
    when coalesce((select w.recipient_format from public.ex_wallets w where w.key = p_wallet), 'phone') = 'card'
      then p_value ~ '^[0-9]{6,32}$'
    else p_value ~ '^07[0-9]{9}$'
  end;
$$;
grant execute on function public.ex_wallet_recipient_ok(text, text) to authenticated, service_role;

do $patch$
declare
  v_def text;
  procedure_patch constant jsonb := jsonb_build_array(
    jsonb_build_object('fn', 'public.ex_orders_enforce_sender_identity()',
      'old', $q$if new.from_method in ('Korek', 'Asiacell') then$q$,
      'new', $q$if exists (select 1 from public.ex_wallets w where w.key = new.from_method and w.sender_phone_required) then$q$),
    jsonb_build_object('fn', 'public.ex_saved_recipient_guard()',
      'old', $q$(new.wallet_key<>'QiCard' and new.phone !~ '^07[0-9]{9}$')$q$,
      'new', $q$not public.ex_wallet_recipient_ok(new.wallet_key, new.phone)$q$));
  p jsonb;
  v_fn regprocedure;
begin
  for p in select * from jsonb_array_elements(procedure_patch) loop
    v_fn := (p ->> 'fn')::regprocedure;
    v_def := pg_get_functiondef(v_fn);
    if position(p ->> 'new' in v_def) > 0 then continue; end if;
    if position(p ->> 'old' in v_def) = 0 then raise exception 'wallet rule not found in %', v_fn; end if;
    execute replace(v_def, p ->> 'old', p ->> 'new');
  end loop;

  -- paying from the balance: the same recipient rule
  select p2.oid::regprocedure into v_fn from pg_proc p2 join pg_namespace n on n.oid = p2.pronamespace
   where n.nspname = 'public' and p2.proname = 'ex_balance_create_order';
  v_def := pg_get_functiondef(v_fn);
  if position('ex_wallet_recipient_ok' in v_def) = 0 then
    if position($q$(p_to='QiCard' and p_phone !~ '^[0-9]{6,32}$')$q$ in v_def) = 0
       or position($q$(p_to<>'QiCard' and p_phone !~ '^07[0-9]{9}$')$q$ in v_def) = 0 then
      raise exception 'wallet rule not found in %', v_fn;
    end if;
    v_def := replace(v_def, $q$(p_to='QiCard' and p_phone !~ '^[0-9]{6,32}$')$q$, $q$not public.ex_wallet_recipient_ok(p_to, p_phone)$q$);
    v_def := replace(v_def, $q$(p_to<>'QiCard' and p_phone !~ '^07[0-9]{9}$')$q$, 'false');
    execute v_def;
  end if;
end $patch$;

-- ── OTP: nobody reads codes from the panel; the browser cannot check codes ──
drop function if exists public.ex_admin_list_otp(integer);
drop function if exists public.ex_admin_update_otp(uuid, text, text, timestamptz, boolean, text);
drop function if exists public.ex_admin_create_otp(text, text, text, integer);
drop function if exists public.ex_admin_expire_otp(uuid);
drop function if exists public.ex_admin_delete_otp(uuid);
revoke all on function public.ex_verify_otp(text, text, text) from public, anon, authenticated;
grant execute on function public.ex_verify_otp(text, text, text) to service_role;

-- ── ban reason ────────────────────────────────────────────────────────
alter table public.ex_profiles
  add column if not exists ban_reason text,
  add column if not exists banned_at timestamptz;
alter table public.ex_profiles drop constraint if exists ex_profiles_ban_reason_check;
alter table public.ex_profiles add constraint ex_profiles_ban_reason_check check (ban_reason is null or char_length(ban_reason) <= 300);
update public.ex_profiles set banned_at = now() where is_banned and banned_at is null;
