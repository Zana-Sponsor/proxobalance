-- Applied to the Exchange project on 2026-11-14 (migration 20261114170219).
-- Permanently remove the discount/reward system (backup: schema backup_rewards_20261114).
-- Kept on purpose: ex_orders.reward_* columns on past orders (financial history used by refund/settlement math).
-- Supersedes the reward parts of the older SUPABASE_*.sql files; do not re-run those reward files.

-- 1) Server pricing without any discount (replaces trg_ex_orders_zz_reward, which also priced every order)
create or replace function public.ex_order_quote(p_amount numeric, p_rate_type text, p_rate_value numeric)
returns jsonb language plpgsql immutable set search_path to '' as $f$
declare v_base numeric;
begin
  if p_amount is null or p_amount<0 or p_amount>1000000000 or p_amount='NaN'::numeric
     or p_rate_value is null or p_rate_value<0 or p_rate_value='NaN'::numeric then
    raise exception 'INVALID_ORDER_PRICING' using errcode='22023'; end if;
  if p_rate_type='fee_percent' then
    if p_rate_value>100 then raise exception 'INVALID_FEE_PERCENT' using errcode='22023'; end if;
    v_base:=floor(greatest(0,p_amount-p_amount*p_rate_value/100));
  elsif p_rate_type='fee_fixed' then v_base:=floor(greatest(0,p_amount-p_rate_value));
  elsif p_rate_type='multiplier' then v_base:=floor(p_amount*p_rate_value);
  else raise exception 'INVALID_ORDER_RATE_TYPE' using errcode='22023'; end if;
  return jsonb_build_object('total',v_base,'fee',greatest(p_amount-v_base,0));
end $f$;

create or replace function public.ex_orders_apply_pricing()
returns trigger language plpgsql security definer set search_path to '' as $f$
declare v_rate public.ex_rates%rowtype; v_quote jsonb;
begin
  new.reward_id:=null; new.reward_discount_iqd:=0; new.reward_original_fee_iqd:=null;
  new.reward_covered_amount_iqd:=null; new.reward_cap_iqd:=null; new.reward_scope:=null;
  if new.from_method='USDT' or new.to_method='USDT' then return new; end if;
  select * into v_rate from public.ex_rates where from_method=new.from_method and to_method=new.to_method and is_active limit 1 for share;
  if not found then raise exception 'EXCHANGE_RATE_NOT_AVAILABLE' using errcode='22023'; end if;
  v_quote:=public.ex_order_quote(new.amount, v_rate.rate_type,
    public.ex_effective_rate_value_b(v_rate.rate_type,v_rate.rate_value,v_rate.fee_tier_enabled,v_rate.fee_tier_limit_iqd,
      v_rate.fee_tier_low_percent,v_rate.fee_tier_high_percent,v_rate.fee_brackets,new.amount));
  new.total:=(v_quote->>'total')::numeric; new.fee:=(v_quote->>'fee')::numeric;
  return new;
end $f$;
revoke all on function public.ex_orders_apply_pricing() from public, anon, authenticated;

create trigger trg_ex_orders_zz_pricing before insert on public.ex_orders
  for each row execute function public.ex_orders_apply_pricing();
drop trigger if exists trg_ex_orders_zz_reward on public.ex_orders;

-- 2) Cut the reward blocks out of three admin functions (each line is checked before it is removed)
do $do$
declare d text; l text[]; out text[];
begin
  select pg_get_functiondef('public.ex_admin_order_delete(uuid,text,text,uuid)'::regprocedure) into d;
  l:=string_to_array(d, E'\n');
  if l[10] <> '  v_blocks text[] := ''{}''; v_usage public.ex_reward_usages%rowtype;' then raise exception 'delete: line 10 changed: %', l[10]; end if;
  if l[52] !~ 'ex_reward_usages' or l[58] <> '  end if;' or l[59] !~ 'delete from public.ex_notifications' then raise exception 'delete: block 52-58 changed'; end if;
  l[10]:='  v_blocks text[] := ''{}'';';
  out:=l[1:51]||l[59:array_length(l,1)];
  execute array_to_string(out, E'\n');

  select pg_get_functiondef('public.ex_admin_order_set_status(uuid,text,text,boolean,boolean,uuid)'::regprocedure) into d;
  l:=string_to_array(d, E'\n');
  if l[11] <> '  v_note text; v_usage_reward uuid; v_reward_restored boolean := false; v_notified boolean := false;' then raise exception 'set_status: line 11 changed: %', l[11]; end if;
  if l[51] !~ 'leaving' or l[52] !~ 'reward_id is not null' or l[61] <> '  end if;' or l[62] <> '' then raise exception 'set_status: block 51-61 changed'; end if;
  if l[73] !~ ',''reward_reapplied'',v_reward_restored\)\);' or l[76] !~ ',''reward_reapplied'',v_reward_restored\);' then raise exception 'set_status: return lines changed'; end if;
  l[11]:='  v_note text; v_notified boolean := false;';
  l[73]:=replace(l[73], ',''reward_reapplied'',v_reward_restored));', '));');
  l[76]:=replace(l[76], ',''reward_reapplied'',v_reward_restored);', ');');
  out:=l[1:50]||l[62:array_length(l,1)];
  execute array_to_string(out, E'\n');

  select pg_get_functiondef('public.ex_admin_reject_and_refund(uuid,uuid,text,text,boolean)'::regprocedure) into d;
  l:=string_to_array(d, E'\n');
  if l[8] <> ' v_journal uuid;v_amt bigint;v_reward_id uuid;' then raise exception 'refund: line 8 changed: %', l[8]; end if;
  if l[55] !~ 'previously rejected' or l[56] !~ 'ex_reward_usages' or l[61] <> ' end if;' or l[62] !~ 'insert into public.ex_admin_audit_log' then raise exception 'refund: block 55-61 changed'; end if;
  l[8]:=' v_journal uuid;v_amt bigint;';
  out:=l[1:54]||l[62:array_length(l,1)];
  execute array_to_string(out, E'\n');
end $do$;

-- 3) Triggers, scheduled job
drop trigger if exists trg_ex_orders_reward_usage on public.ex_orders;
drop trigger if exists trg_ex_orders_reward_restore on public.ex_orders;
drop trigger if exists ex_order_feedback_award_reward on public.ex_order_feedback;
drop trigger if exists trg_ex_notification_reward_guard on public.ex_notifications;
drop trigger if exists trg_ex_reward_one_week on public.ex_user_rewards;
drop trigger if exists trg_ex_reward_reminders on public.ex_user_rewards;
select cron.unschedule(jobid) from cron.job where jobname='exchange-reward-reminders';

-- 4) Reward functions (before the tables: one takes the table's row type)
drop function if exists public.ex_award_order_feedback_reward();
drop function if exists public.ex_notification_reward_guard();
drop function if exists public.ex_refresh_reward_alerts();
drop function if exists public.ex_reward_emit_reminders(uuid);
drop function if exists public.ex_reward_emit_reminders();
drop function if exists public.ex_reward_ku_number(numeric);
drop function if exists public.ex_reward_one_week_guard();
drop function if exists public.ex_reward_quote(numeric,text,numeric,text,numeric,bigint);
drop function if exists public.ex_reward_reminder_trigger();
drop function if exists public.ex_reward_route_scope(text,text);
drop function if exists public.ex_reward_scope_label(text);
drop function if exists public.ex_reward_summary_text(public.ex_user_rewards);
drop function if exists public.ex_rewards_apply_on_order();
drop function if exists public.ex_rewards_record_order();
drop function if exists public.ex_rewards_restore_on_rejection();

-- 5) Discount notifications and their columns
delete from public.ex_notifications where reward_id is not null or reward_alert_kind is not null;
alter table public.ex_notifications drop constraint if exists ex_notifications_reward_id_fkey;
alter table public.ex_notifications drop constraint if exists ex_notifications_reward_alert_kind_check;
alter table public.ex_notifications drop column if exists reward_alert_kind;
alter table public.ex_notifications drop column if exists reward_id;

-- 6) Orders keep their history columns, but no longer point at a reward table
alter table public.ex_orders drop constraint if exists ex_orders_reward_id_fkey;

-- 7) Reward tables (their policies and realtime entry go with them)
drop table if exists public.ex_reward_usages;
drop table if exists public.ex_user_rewards_expiry_backup_20261105;
drop table if exists public.ex_user_rewards;

-- 8) No staff member can manage rewards any more
update public.ex_profiles set staff_permissions = array_remove(staff_permissions,'manage_rewards') where 'manage_rewards' = any(staff_permissions);
alter table public.ex_profiles drop constraint ex_staff_permissions_valid;
alter table public.ex_profiles add constraint ex_staff_permissions_valid check (
  staff_permissions is null or (array_position(staff_permissions, null::text) is null
  and staff_permissions <@ array['view','approve_orders','refunds','manage_fees']::text[]
  and ('view' = any(staff_permissions) or cardinality(staff_permissions) = 0)));
