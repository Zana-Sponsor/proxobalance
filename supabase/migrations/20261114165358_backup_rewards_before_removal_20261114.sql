-- Applied to the Exchange project on 2026-11-14 (migration 20261114165358).
-- Full backup of the discount/reward system before it is removed.
-- Private schema: not exposed through the API, no access for anon/authenticated.
create schema if not exists backup_rewards_20261114;
revoke all on schema backup_rewards_20261114 from public, anon, authenticated;

create table backup_rewards_20261114.ex_user_rewards as table public.ex_user_rewards;
create table backup_rewards_20261114.ex_reward_usages as table public.ex_reward_usages;
create table backup_rewards_20261114.ex_user_rewards_expiry_backup_20261105 as table public.ex_user_rewards_expiry_backup_20261105;
create table backup_rewards_20261114.ex_notifications_reward_rows as
  select * from public.ex_notifications where reward_id is not null or reward_alert_kind is not null;
create table backup_rewards_20261114.ex_orders_reward_columns as
  select id, order_code, user_id, reward_id, reward_discount_iqd, reward_original_fee_iqd, reward_covered_amount_iqd, reward_cap_iqd, reward_scope, fee, total
  from public.ex_orders where reward_id is not null or coalesce(reward_discount_iqd,0)<>0;
create table backup_rewards_20261114.ex_profiles_staff_permissions as
  select id, staff_permissions from public.ex_profiles where 'manage_rewards' = any(staff_permissions);

create table backup_rewards_20261114.object_definitions (kind text, name text, definition text);
insert into backup_rewards_20261114.object_definitions
select 'function', p.oid::regprocedure::text, pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and (p.proname ~* 'reward|discount' or p.proname in ('ex_admin_order_delete','ex_admin_order_set_status','ex_admin_reject_and_refund'));
insert into backup_rewards_20261114.object_definitions
select 'trigger', c.relname||'.'||t.tgname, pg_get_triggerdef(t.oid)
from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_proc p on p.oid=t.tgfoid
where not t.tgisinternal and (t.tgname ~* 'reward' or p.proname ~* 'reward');
insert into backup_rewards_20261114.object_definitions
select 'policy', schemaname||'.'||tablename||'.'||policyname, format('cmd=%s roles=%s using=%s check=%s', cmd, roles, qual, with_check)
from pg_policies where tablename ~* 'reward';
insert into backup_rewards_20261114.object_definitions
select 'constraint', c.conrelid::regclass::text||'.'||conname, pg_get_constraintdef(c.oid)
from pg_constraint c where pg_get_constraintdef(c.oid) ~* 'ex_user_rewards|ex_reward_usages|reward' or conname='ex_staff_permissions_valid';
insert into backup_rewards_20261114.object_definitions
select 'cron', jobname, schedule||' :: '||command from cron.job where jobname ~* 'reward';

revoke all on all tables in schema backup_rewards_20261114 from public, anon, authenticated;
