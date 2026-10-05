-- Wallet badges, private saved recipients, reward reminders and scoped staff rights.
-- Existing accounts, balances, fees and public transaction IDs remain unchanged.
alter table public.ex_wallets
 add column badge text not null default 'none' check(badge in ('none','popular','most_popular','new')),
 add column badge_version uuid not null default gen_random_uuid();
create function public.ex_wallet_badge_version() returns trigger
 language plpgsql set search_path='' as $fn$
begin
 if new.badge is distinct from old.badge then new.badge_version:=gen_random_uuid();end if;
 return new;
end $fn$;
revoke all on function public.ex_wallet_badge_version() from public,anon,authenticated;
create trigger trg_ex_wallet_badge_version before update on public.ex_wallets
 for each row execute function public.ex_wallet_badge_version();

create table public.ex_wallet_badge_views(
 user_id uuid not null references auth.users(id) on delete cascade,
 wallet_id uuid not null references public.ex_wallets(id) on delete cascade,
 badge_version uuid not null,
 seen_at timestamptz not null default now(),
 primary key(user_id,wallet_id,badge_version)
);
alter table public.ex_wallet_badge_views enable row level security;
revoke all on public.ex_wallet_badge_views from anon,authenticated;
grant select,insert on public.ex_wallet_badge_views to authenticated;
grant all on public.ex_wallet_badge_views to service_role;
create policy ex_wallet_badge_views_own_select on public.ex_wallet_badge_views for select to authenticated
 using(user_id=(select auth.uid()));
create policy ex_wallet_badge_views_own_insert on public.ex_wallet_badge_views for insert to authenticated
 with check(user_id=(select auth.uid()) and exists(
  select 1 from public.ex_wallets w where w.id=wallet_id and w.badge='new' and w.badge_version=ex_wallet_badge_views.badge_version));
create index ex_wallet_badge_views_wallet_idx on public.ex_wallet_badge_views(wallet_id);

create table public.ex_saved_recipients(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 label text not null check(char_length(btrim(label)) between 1 and 60),
 wallet_key text not null references public.ex_wallets(key) on update cascade on delete cascade,
 phone text not null check(phone ~ '^[0-9]{6,32}$'),
 created_at timestamptz not null default now(),
 unique(user_id,wallet_key,phone)
);
alter table public.ex_saved_recipients enable row level security;
revoke all on public.ex_saved_recipients from anon,authenticated;
grant select,insert,update,delete on public.ex_saved_recipients to authenticated;
grant all on public.ex_saved_recipients to service_role;
create policy ex_saved_recipients_own_select on public.ex_saved_recipients for select to authenticated using(user_id=(select auth.uid()));
create policy ex_saved_recipients_own_insert on public.ex_saved_recipients for insert to authenticated with check(user_id=(select auth.uid()));
create policy ex_saved_recipients_own_update on public.ex_saved_recipients for update to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy ex_saved_recipients_own_delete on public.ex_saved_recipients for delete to authenticated using(user_id=(select auth.uid()));
create index ex_saved_recipients_wallet_idx on public.ex_saved_recipients(wallet_key);
create function public.ex_saved_recipient_guard() returns trigger
 language plpgsql security definer set search_path='' as $fn$
begin
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.user_id is distinct from old.user_id
     or new.created_at is distinct from old.created_at) then
  raise exception 'RECIPIENT_OWNER_IMMUTABLE' using errcode='42501';end if;
 if not exists(select 1 from public.ex_wallets where key=new.wallet_key and allow_receive and key<>'AccountBalance')
   or (new.wallet_key<>'QiCard' and new.phone !~ '^07[0-9]{9}$') then
  raise exception 'INVALID_RECIPIENT' using errcode='22023';end if;
 new.label:=btrim(new.label);
 if tg_op='INSERT' then
  perform pg_advisory_xact_lock(hashtextextended('recipients:'||new.user_id::text,0));
  if (select count(*) from public.ex_saved_recipients where user_id=new.user_id)>=50 then
   raise exception 'RECIPIENT_LIMIT_50' using errcode='22023';end if;
 end if;
 return new;
end $fn$;
revoke all on function public.ex_saved_recipient_guard() from public,anon,authenticated;
create trigger trg_ex_saved_recipient_guard before insert or update on public.ex_saved_recipients
 for each row execute function public.ex_saved_recipient_guard();

-- NULL preserves existing full-admin access. A non-NULL list restricts staff.
alter table public.ex_profiles add column staff_permissions text[];
alter table public.ex_profiles add constraint ex_staff_permissions_valid check(
 staff_permissions is null or (array_position(staff_permissions,null) is null
 and staff_permissions <@ array['view','approve_orders','refunds','manage_fees','manage_rewards']::text[]
 and ('view'=any(staff_permissions) or cardinality(staff_permissions)=0)));
create function public.ex_staff_can(p_user_id uuid,p_permission text) returns boolean
 language sql stable security definer set search_path='' as $fn$
 select coalesce((select is_admin and not is_banned and
  (role='super_admin' or staff_permissions is null or p_permission=any(staff_permissions))
  from public.ex_profiles where id=p_user_id),false);
$fn$;
revoke all on function public.ex_staff_can(uuid,text) from public,anon,authenticated;
grant execute on function public.ex_staff_can(uuid,text) to service_role;
-- The caller-scoped wrapper is safe to use from RLS; it exposes no other user's rights.
create function public.ex_staff_has(p_permission text) returns boolean
 language sql stable security definer set search_path='' as $fn$
 select public.ex_staff_can(auth.uid(),p_permission);
$fn$;
revoke all on function public.ex_staff_has(text) from public,anon;
grant execute on function public.ex_staff_has(text) to authenticated,service_role;
create or replace function public.is_ex_admin() returns boolean
 language sql stable security definer set search_path='' as $fn$
 select coalesce((select is_admin and not is_banned
  and (role='super_admin' or staff_permissions is null)
  from public.ex_profiles where id=auth.uid()),false);
$fn$;
-- Legacy privileged RPCs keep their full-admin gate. Scoped staff use only the
-- explicit API actions/new policies below; hiding buttons is never authorization.
create function public.ex_staff_profile_guard() returns trigger
 language plpgsql security definer set search_path='' as $fn$
begin
 if tg_op='INSERT' and not public.ex_is_backend_request() then new.staff_permissions:=null;end if;
 if tg_op='UPDATE' and new.staff_permissions is distinct from old.staff_permissions then
  if not public.ex_is_backend_request() and not public.ex_is_super_admin() then
   raise exception 'SUPER_ADMIN_REQUIRED' using errcode='42501';end if;
  if old.role='super_admin' or new.role='super_admin' or old.id=auth.uid() then
   raise exception 'STAFF_PERMISSION_TARGET_FORBIDDEN' using errcode='42501';end if;
 end if;
 return new;
end $fn$;
revoke all on function public.ex_staff_profile_guard() from public,anon,authenticated;
create trigger trg_ex_staff_profile_guard before insert or update on public.ex_profiles
 for each row execute function public.ex_staff_profile_guard();
create function public.ex_staff_set_permissions(p_user_id uuid,p_permissions text[]) returns jsonb
 language plpgsql security definer set search_path='' as $fn$
begin
 if not public.ex_is_super_admin() then raise exception 'SUPER_ADMIN_REQUIRED' using errcode='42501';end if;
 if p_user_id=auth.uid() or not exists(select 1 from public.ex_profiles
   where id=p_user_id and is_admin and role<>'super_admin') then
  raise exception 'STAFF_PERMISSION_TARGET_FORBIDDEN' using errcode='42501';end if;
 update public.ex_profiles set staff_permissions=p_permissions where id=p_user_id;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
  values(auth.uid(),'staff_permissions_changed',p_user_id,coalesce(array_to_string(p_permissions,','),'full_admin'));
 return jsonb_build_object('user_id',p_user_id,'permissions',p_permissions);
end $fn$;
revoke all on function public.ex_staff_set_permissions(uuid,text[]) from public,anon;
grant execute on function public.ex_staff_set_permissions(uuid,text[]) to authenticated;
create policy ex_staff_read_orders on public.ex_orders for select to authenticated
 using((select public.ex_staff_has('view')));
create policy ex_staff_read_profiles on public.ex_profiles for select to authenticated
 using((select public.ex_staff_has('view')));
create policy ex_staff_read_audit on public.ex_admin_audit_log for select to authenticated
 using((select public.ex_staff_has('view')));
create policy ex_staff_write_wallets on public.ex_wallets for all to authenticated
 using((select public.ex_staff_has('manage_fees'))) with check((select public.ex_staff_has('manage_fees')));
create policy ex_staff_write_rates on public.ex_rates for all to authenticated
 using((select public.ex_staff_has('manage_fees'))) with check((select public.ex_staff_has('manage_fees')));

-- Server-generated reminders are idempotent and use the existing notification bell.
alter table public.ex_notifications
 add column reward_id uuid references public.ex_user_rewards(id) on delete set null,
 add column reward_alert_kind text check(reward_alert_kind in ('last_use','expiring'));
create unique index ex_reward_alert_once on public.ex_notifications(reward_id,reward_alert_kind)
 where reward_id is not null and reward_alert_kind is not null;
create index ex_notifications_reward_idx on public.ex_notifications(reward_id) where reward_id is not null;
create index ex_rewards_expiring_idx on public.ex_user_rewards(valid_until)
 where active and valid_until is not null;
create function public.ex_reward_emit_reminders(p_user_id uuid default null) returns integer
 language plpgsql security definer set search_path='' as $fn$
declare n integer:=0;m integer;
begin
 insert into public.ex_notifications(user_id,type,title,message,reward_id,reward_alert_kind)
 select r.user_id,'admin','یەک مامەڵەی پاداشتەکەت ماوە',
  'تەنها یەک بەکارهێنانی پاداشتەکەت ماوە. تایبەت بە '||
  case r.reward_scope when 'korek' then 'کۆڕەک' when 'asiacell' then 'ئاسیاسێڵ' else 'جزدانەکان' end||'.',
  r.id,'last_use'
 from public.ex_user_rewards r join public.ex_profiles p on p.id=r.user_id
 where r.active and not p.is_banned and (p_user_id is null or r.user_id=p_user_id)
  and (r.valid_until is null or r.valid_until>now()) and r.max_uses-r.used_count=1
 on conflict(reward_id,reward_alert_kind) where reward_id is not null and reward_alert_kind is not null do nothing;
 get diagnostics n=row_count;
 insert into public.ex_notifications(user_id,type,title,message,reward_id,reward_alert_kind)
 select r.user_id,'admin','پاداشتەکەت بە زوویی بەسەر دەچێت',
  'پاداشتەکەت تا '||to_char(r.valid_until at time zone 'Asia/Baghdad','YYYY-MM-DD HH24:MI')||
  ' بەردەستە. تایبەت بە '||case r.reward_scope when 'korek' then 'کۆڕەک'
   when 'asiacell' then 'ئاسیاسێڵ' else 'جزدانەکان' end||'.',
  r.id,'expiring'
 from public.ex_user_rewards r join public.ex_profiles p on p.id=r.user_id
 where r.active and not p.is_banned and (p_user_id is null or r.user_id=p_user_id)
  and r.valid_until>now() and r.valid_until<=now()+interval '24 hours'
  and (r.max_uses is null or r.used_count<r.max_uses)
 on conflict(reward_id,reward_alert_kind) where reward_id is not null and reward_alert_kind is not null do nothing;
 get diagnostics m=row_count;
 return n+m;
end $fn$;
revoke all on function public.ex_reward_emit_reminders(uuid) from public,anon,authenticated;
grant execute on function public.ex_reward_emit_reminders(uuid) to service_role;
create function public.ex_refresh_reward_alerts() returns integer
 language plpgsql security definer set search_path='' as $fn$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
 return public.ex_reward_emit_reminders(auth.uid());
end $fn$;
revoke all on function public.ex_refresh_reward_alerts() from public,anon;
grant execute on function public.ex_refresh_reward_alerts() to authenticated;
create function public.ex_reward_reminder_trigger() returns trigger
 language plpgsql security definer set search_path='' as $fn$
begin
 perform public.ex_reward_emit_reminders(new.user_id);return null;
end $fn$;
revoke all on function public.ex_reward_reminder_trigger() from public,anon,authenticated;
create trigger trg_ex_reward_reminders after insert or update of used_count,active,valid_until,max_uses
 on public.ex_user_rewards for each row execute function public.ex_reward_reminder_trigger();
create function public.ex_notification_reward_guard() returns trigger
 language plpgsql set search_path='' as $fn$
begin
 if not public.ex_is_backend_request() and
  (new.reward_id is distinct from old.reward_id or new.reward_alert_kind is distinct from old.reward_alert_kind) then
  raise exception 'REWARD_ALERT_IMMUTABLE' using errcode='42501';end if;
 return new;
end $fn$;
revoke all on function public.ex_notification_reward_guard() from public,anon,authenticated;
create trigger trg_ex_notification_reward_guard before update on public.ex_notifications
 for each row execute function public.ex_notification_reward_guard();

