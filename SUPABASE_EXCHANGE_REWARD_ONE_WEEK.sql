-- Every customer reward is valid for exactly one week from the moment it is
-- granted, and every new grant sends one organised notification.
-- Previous expiries of rewards changed by this migration are kept in a private
-- backup table so the change can be reviewed or reverted.

create table if not exists public.ex_user_rewards_expiry_backup_20261105(
  reward_id uuid primary key,
  previous_valid_until timestamptz,
  backed_up_at timestamptz not null default now()
);
alter table public.ex_user_rewards_expiry_backup_20261105 enable row level security;
revoke all on public.ex_user_rewards_expiry_backup_20261105 from public,anon,authenticated;

-- Kurdish digits with Kurdish thousands separator, e.g. 10000 -> ١٠٬٠٠٠.
create or replace function public.ex_reward_ku_number(p numeric)
returns text language sql immutable set search_path='' as $fn$
  select translate(to_char(p,'FM999,999,999,990'),'0123456789,','٠١٢٣٤٥٦٧٨٩٬')
$fn$;

create or replace function public.ex_reward_scope_label(p_scope text)
returns text language sql immutable set search_path='' as $fn$
  select case p_scope when 'korek' then 'کۆڕەک' when 'asiacell' then 'ئاسیاسێڵ' else 'واڵێتەکان' end
$fn$;

-- One organised sentence group: what, where, cap, uses, validity.
create or replace function public.ex_reward_summary_text(r public.ex_user_rewards)
returns text language sql stable set search_path='' as $fn$
  select concat_ws(' · ',
    case when r.kind='free_transactions'
      then case when coalesce(r.max_uses,1)=1 then 'یەک' else public.ex_reward_ku_number(r.max_uses) end
        ||' مامەڵەی بێ کرێی خزمەتگوزاری'
      else public.ex_reward_ku_number(r.discount_percent)||'٪ داشکاندن لە کرێی خزمەتگوزاری'
    end||' بۆ '||public.ex_reward_scope_label(r.reward_scope),
    case when r.max_discount_iqd is not null
      then 'زۆرترین داشکاندن '||public.ex_reward_ku_number(r.max_discount_iqd)||' دینار' end,
    case when r.max_amount_iqd is not null
      then 'بۆ بڕی تا '||public.ex_reward_ku_number(r.max_amount_iqd)||' دینار' end,
    case when r.kind<>'free_transactions' then
      case when coalesce(r.max_uses,1)=1 then 'یەک جار'
           else public.ex_reward_ku_number(r.max_uses)||' جار' end end,
    'بۆ ماوەی ٧ ڕۆژ کارایە')||'.'
$fn$;
revoke all on function public.ex_reward_summary_text(public.ex_user_rewards) from public,anon,authenticated;

-- New grants: exactly seven days, whatever the source (feedback, welcome, admin).
create or replace function public.ex_reward_one_week_guard()
returns trigger language plpgsql set search_path='' as $fn$
begin
  new.created_at:=coalesce(new.created_at,now());
  new.valid_until:=new.created_at+interval '7 days';
  return new;
end $fn$;
revoke all on function public.ex_reward_one_week_guard() from public,anon,authenticated;
drop trigger if exists trg_ex_reward_one_week on public.ex_user_rewards;
create trigger trg_ex_reward_one_week before insert on public.ex_user_rewards
  for each row execute function public.ex_reward_one_week_guard();

-- Existing usable rewards without expiry or beyond one week get one full week from now.
insert into public.ex_user_rewards_expiry_backup_20261105(reward_id,previous_valid_until)
  select id,valid_until from public.ex_user_rewards
   where active and (max_uses is null or used_count<max_uses)
     and (valid_until is null or valid_until>now()+interval '7 days')
  on conflict(reward_id) do nothing;
update public.ex_user_rewards r set valid_until=now()+interval '7 days',updated_at=now()
  from public.ex_user_rewards_expiry_backup_20261105 b
 where b.reward_id=r.id and (r.valid_until is null or r.valid_until>now()+interval '7 days');

-- A dedicated, deduplicated "reward granted" notification.
alter table public.ex_notifications drop constraint if exists ex_notifications_reward_alert_kind_check;
alter table public.ex_notifications add constraint ex_notifications_reward_alert_kind_check
  check (reward_alert_kind = any (array['granted'::text,'last_use'::text,'expiring'::text]));

create or replace function public.ex_reward_emit_reminders(p_user_id uuid default null)
returns integer language plpgsql security definer set search_path='' as $fn$
declare n integer:=0;m integer:=0;k integer:=0;
begin
 -- 1) Newly granted reward (only rewards created in the last 15 minutes).
 insert into public.ex_notifications(user_id,type,title,message,reward_id,reward_alert_kind)
 select r.user_id,'admin',
  case when r.campaign_key like 'order_feedback_v1:%' then 'پاداشتی هەڵسەنگاندنەکەت ئامادەیە'
       when r.campaign_key='welcome_signup_v1' then 'پاداشتی هەژماری نوێت ئامادەیە'
       else 'پاداشتێکی نوێت پێدرا' end,
  case when r.campaign_key like 'order_feedback_v1:%'
       then 'سوپاس بۆ هەڵسەنگاندنەکەت. ' else '' end||public.ex_reward_summary_text(r),
  r.id,'granted'
 from public.ex_user_rewards r join public.ex_profiles p on p.id=r.user_id
 where r.active and not p.is_banned and (p_user_id is null or r.user_id=p_user_id)
  and r.used_count=0 and r.created_at>now()-interval '15 minutes'
  and (r.valid_until is null or r.valid_until>now())
 on conflict(reward_id,reward_alert_kind) where reward_id is not null and reward_alert_kind is not null do nothing;
 get diagnostics k=row_count;
 -- 2) One use left on a multi-use reward (a fresh single-use grant is covered by step 1).
 insert into public.ex_notifications(user_id,type,title,message,reward_id,reward_alert_kind)
 select r.user_id,'admin','یەک بەکارهێنانی پاداشتەکەت ماوە',
  'پاداشتەکەت تەنها یەک جاری تر بەکاردێت · '||public.ex_reward_scope_label(r.reward_scope)||
  coalesce(' · کارایە تا '||to_char(r.valid_until at time zone 'Asia/Baghdad','YYYY-MM-DD'),'')||'.',
  r.id,'last_use'
 from public.ex_user_rewards r join public.ex_profiles p on p.id=r.user_id
 where r.active and not p.is_banned and (p_user_id is null or r.user_id=p_user_id)
  and (r.valid_until is null or r.valid_until>now()) and r.max_uses-r.used_count=1 and r.used_count>0
 on conflict(reward_id,reward_alert_kind) where reward_id is not null and reward_alert_kind is not null do nothing;
 get diagnostics n=row_count;
 -- 3) Expires within 24 hours.
 insert into public.ex_notifications(user_id,type,title,message,reward_id,reward_alert_kind)
 select r.user_id,'admin','پاداشتەکەت بە زوویی بەسەر دەچێت',
  'پاداشتەکەت تا '||to_char(r.valid_until at time zone 'Asia/Baghdad','YYYY-MM-DD HH24:MI')||
  ' کارایە · '||public.ex_reward_scope_label(r.reward_scope)||'.',
  r.id,'expiring'
 from public.ex_user_rewards r join public.ex_profiles p on p.id=r.user_id
 where r.active and not p.is_banned and (p_user_id is null or r.user_id=p_user_id)
  and r.valid_until>now() and r.valid_until<=now()+interval '24 hours'
  and (r.max_uses is null or r.used_count<r.max_uses)
 on conflict(reward_id,reward_alert_kind) where reward_id is not null and reward_alert_kind is not null do nothing;
 get diagnostics m=row_count;
 return k+n+m;
end $fn$;
revoke all on function public.ex_reward_emit_reminders(uuid) from public,anon,authenticated;
grant execute on function public.ex_reward_emit_reminders(uuid) to service_role;
