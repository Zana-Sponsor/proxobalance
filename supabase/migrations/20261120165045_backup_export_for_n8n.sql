-- Nightly backup for n8n ("Supabase Backup" workflow).
-- n8n calls ex_backup_export with the anon key and its own backup key (only the
-- key's sha256 is stored here). It gets the important tables as one JSON object and
-- a fingerprint; when the fingerprint equals the last one sent, nothing has changed
-- and n8n sends nothing. After Telegram accepts the file, n8n calls ex_backup_mark.
-- Left out on purpose: passwords, codes and keys (ex_auth_*, ex_otp_codes,
-- ex_whatsapp_settings, ex_whatsapp_worker_keys, ex_backup_keys) and logs that
-- only grow (suspicious_events, ex_error_logs, ex_user_activity, ex_notifications ...).

create table if not exists public.ex_backup_keys (
  id uuid primary key default gen_random_uuid(),
  key_hash text not null unique,
  label text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.ex_backup_keys enable row level security;
revoke all on public.ex_backup_keys from anon, authenticated;

create table if not exists public.ex_backup_runs (
  id bigserial primary key,
  fingerprint text not null,
  counts jsonb not null default '{}'::jsonb,
  file_bytes integer,
  telegram_message_id bigint,
  sent_at timestamptz not null default now()
);
alter table public.ex_backup_runs enable row level security;
revoke all on public.ex_backup_runs from anon, authenticated;

-- The n8n key's sha256 row (label 'n8n Supabase Backup') was added with this migration
-- on the server; it is not kept in the repository.

create or replace function public.ex_backup_key_ok(p_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_key is not null and exists (
    select 1 from public.ex_backup_keys k
     where k.active and k.key_hash = encode(extensions.digest(p_key, 'sha256'), 'hex'));
$$;
revoke all on function public.ex_backup_key_ok(text) from public, anon, authenticated;

create or replace function public.ex_backup_export(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tables constant text[] := array[
    -- customers and orders
    'ex_profiles', 'ex_orders', 'ex_order_feedback', 'ex_order_correction_history', 'ex_order_admin_actions',
    'ex_saved_recipients', 'ex_support_cases', 'ex_account_deletions', 'ex_whatsapp_consent_log',
    -- money
    'ex_customer_balances', 'ex_balance_journal', 'ex_balance_entries', 'ex_balance_config', 'ex_refund_cases',
    'ex_payout_requests', 'ex_order_shortfall_refunds', 'ex_order_payout_settlements',
    'ex_order_settlement_receipts', 'ex_order_profit_ledger',
    -- identity
    'ex_kyc_requests', 'ex_identity_verifications', 'ex_kyc_events',
    -- wallets, prices and site settings
    'ex_wallets', 'ex_rates', 'ex_change_log', 'ex_site_controls', 'ex_site_schedules', 'ex_banners',
    'ex_broadcasts', 'ex_whatsapp_templates', 'ex_admin_alert_phones', 'ex_admin_contracts',
    -- admin record and blocked addresses
    'ex_admin_audit_log', 'banned_ips', 'ex_ip_allowlist'];
  v_t text; v_rows jsonb; v_n bigint;
  v_data jsonb := '{}'::jsonb; v_counts jsonb := '{}'::jsonb; v_total bigint := 0;
  v_fp text; v_last text;
begin
  if not public.ex_backup_key_ok(p_key) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  foreach v_t in array v_tables loop
    -- rows in a fixed order, so the same data always gives the same fingerprint
    execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text), ''[]''::jsonb), count(*) from public.%I x', v_t)
      into v_rows, v_n;
    v_data := v_data || jsonb_build_object(v_t, v_rows);
    v_counts := v_counts || jsonb_build_object(v_t, v_n);
    v_total := v_total + v_n;
  end loop;
  v_fp := md5(v_data::text);
  select r.fingerprint into v_last from public.ex_backup_runs r order by r.sent_at desc, r.id desc limit 1;
  if v_last is not distinct from v_fp then
    return jsonb_build_object('changed', false, 'fingerprint', v_fp, 'rows', v_total, 'counts', v_counts);
  end if;
  return jsonb_build_object(
    'changed', true, 'fingerprint', v_fp, 'rows', v_total, 'counts', v_counts,
    'orders', v_counts -> 'ex_orders', 'customers', v_counts -> 'ex_profiles',
    'backup', jsonb_build_object(
      'project', 'Proxo Exchange (pycxuugoblkslvwebxuu)',
      'generated_at', now(),
      'fingerprint', v_fp,
      'counts', v_counts,
      'tables', v_data));
end $$;

create or replace function public.ex_backup_mark(p_key text, p_fingerprint text, p_counts jsonb default '{}'::jsonb,
                                                 p_file_bytes integer default null, p_message_id bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.ex_backup_key_ok(p_key) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{32}$' then
    raise exception 'bad fingerprint' using errcode = '22023';
  end if;
  insert into public.ex_backup_runs (fingerprint, counts, file_bytes, telegram_message_id)
  values (p_fingerprint, coalesce(p_counts, '{}'::jsonb), p_file_bytes, p_message_id);
  delete from public.ex_backup_runs where sent_at < now() - interval '400 days';
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.ex_backup_export(text) from public, authenticated;
revoke all on function public.ex_backup_mark(text, text, jsonb, integer, bigint) from public, authenticated;
grant execute on function public.ex_backup_export(text) to anon, service_role;
grant execute on function public.ex_backup_mark(text, text, jsonb, integer, bigint) to anon, service_role;
