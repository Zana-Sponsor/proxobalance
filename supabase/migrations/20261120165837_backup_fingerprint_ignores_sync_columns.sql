-- The fingerprint that decides "new data or not" leaves out columns that machines
-- rewrite on their own, or every night would look new:
--   ex_whatsapp_templates.checked_at  (n8n template sync, every minute)
--   ex_site_controls.updated_at / updated_by, ex_site_schedules.last_state
--     (the working-hours schedule pauses and opens sections every day)
-- The file itself still carries every column. One md5 per table, then one md5 of those.
create or replace function public.ex_backup_export(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
set statement_timeout = '60s'
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
  v_volatile constant jsonb := '{
    "ex_whatsapp_templates": ["checked_at"],
    "ex_site_controls": ["updated_at", "updated_by"],
    "ex_site_schedules": ["last_state"]}'::jsonb;
  v_t text; v_skip text[]; v_rows jsonb; v_hash text; v_n bigint;
  v_data jsonb := '{}'::jsonb; v_counts jsonb := '{}'::jsonb; v_total bigint := 0;
  v_hashes text := ''; v_fp text; v_last text;
begin
  if not public.ex_backup_key_ok(p_key) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  foreach v_t in array v_tables loop
    v_skip := coalesce(array(select jsonb_array_elements_text(v_volatile -> v_t)), '{}'::text[]);
    -- rows in a fixed order, so the same data always gives the same fingerprint
    execute format(
      'select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text), ''[]''::jsonb),
              coalesce(md5(string_agg((to_jsonb(x) - $1)::text, chr(10) order by (to_jsonb(x) - $1)::text)), ''''),
              count(*)
         from public.%I x', v_t)
      into v_rows, v_hash, v_n using v_skip;
    v_data := v_data || jsonb_build_object(v_t, v_rows);
    v_counts := v_counts || jsonb_build_object(v_t, v_n);
    v_total := v_total + v_n;
    v_hashes := v_hashes || v_t || ':' || v_hash || chr(10);
  end loop;
  v_fp := md5(v_hashes);
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
