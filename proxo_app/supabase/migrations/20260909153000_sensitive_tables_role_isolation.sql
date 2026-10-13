-- Remove legacy TRUE policies from user-sensitive tables. Public catalogue
-- content remains readable, but personal/session/financial rows are owner-only.

do $block$
declare r record;
begin
  for r in
    select schemaname,tablename,policyname from pg_policies
    where schemaname='public' and tablename=any(array[
      'ad_revenue_transactions','chat_sessions','deleted_accounts',
      'direct_discount_usages','direct_discounts','ex_otp_codes',
      'lc_feedback','lc_messages','lc_sessions','live_chat_history',
      'pa_banned_devices','pa_banners','pa_challenges','pa_coins',
      'pa_device_tokens','pa_login_history','pa_referrals','pa_section_locks',
      'pa_settings','pa_story_views','pa_support','pa_user_sessions',
      'pa_voucher_codes','weekly_giveaway_entries','weekly_giveaway_winners'
    ])
  loop
    execute format('drop policy if exists %I on %I.%I',r.policyname,r.schemaname,r.tablename);
  end loop;
end
$block$;

-- Financial records.
create policy "ad revenue own select" on public.ad_revenue_transactions
 for select to authenticated using ((select auth.uid())::text=user_id);
create policy "ad revenue admin all" on public.ad_revenue_transactions
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));
create policy "direct usage own select" on public.direct_discount_usages
 for select to authenticated using ((select auth.uid())::text=user_id);
create policy "direct discounts eligible select" on public.direct_discounts
 for select to authenticated using (
   is_active=true and (starts_at is null or starts_at<=now())
   and (expires_at is null or expires_at>now())
   and (is_public=true or restricted_to_user_id=(select auth.uid()))
 );
create policy "direct discounts admin all" on public.direct_discounts
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

-- Owner-bound app data.
create policy "coins own select" on public.pa_coins
 for select to authenticated using ((select auth.uid())=user_id);
create policy "coins admin all" on public.pa_coins
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "device token own select" on public.pa_device_tokens
 for select to authenticated using ((select auth.uid())=user_id);
create policy "device token own insert" on public.pa_device_tokens
 for insert to authenticated with check ((select auth.uid())=user_id);
create policy "device token own update" on public.pa_device_tokens
 for update to authenticated using ((select auth.uid())=user_id)
 with check ((select auth.uid())=user_id);
create policy "device token own delete" on public.pa_device_tokens
 for delete to authenticated using ((select auth.uid())=user_id);

create policy "login history own select" on public.pa_login_history
 for select to authenticated using ((select auth.uid())=user_id);
create policy "login history own insert" on public.pa_login_history
 for insert to authenticated with check ((select auth.uid())=user_id);
create policy "login history admin all" on public.pa_login_history
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "referrals own select" on public.pa_referrals
 for select to authenticated using (
   (select auth.uid())=referrer_id or (select auth.uid())=referred_id
 );
create policy "referrals own insert" on public.pa_referrals
 for insert to authenticated with check (
   (select auth.uid())=referred_id and referrer_id<>(select auth.uid())
 );
create policy "referrals admin all" on public.pa_referrals
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "story views own select" on public.pa_story_views
 for select to authenticated using ((select auth.uid())=user_id);
create policy "story views own insert" on public.pa_story_views
 for insert to authenticated with check ((select auth.uid())=user_id);
create policy "story views admin select" on public.pa_story_views
 for select to authenticated using ((select public.pa_is_admin()));

create policy "support own select" on public.pa_support
 for select to authenticated using ((select auth.uid())=user_id);
create policy "support own insert" on public.pa_support
 for insert to authenticated with check (
   (select auth.uid())=user_id and coalesce(is_admin,false)=false
 );
create policy "support admin all" on public.pa_support
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "sessions own select" on public.pa_user_sessions
 for select to authenticated using ((select auth.uid())=user_id);
create policy "sessions own insert" on public.pa_user_sessions
 for insert to authenticated with check ((select auth.uid())=user_id);
create policy "sessions own update" on public.pa_user_sessions
 for update to authenticated using ((select auth.uid())=user_id)
 with check ((select auth.uid())=user_id);
create policy "sessions admin all" on public.pa_user_sessions
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "live history own select" on public.live_chat_history
 for select to authenticated using ((select auth.uid())=user_id);
create policy "live history admin all" on public.live_chat_history
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "giveaway entry own select" on public.weekly_giveaway_entries
 for select to authenticated using ((select auth.uid())=user_id);
create policy "giveaway winners own select" on public.weekly_giveaway_winners
 for select to authenticated using ((select auth.uid())=user_id);

-- Public catalogue/configuration data: readable, never writable by normal users.
create policy "banners public read" on public.pa_banners
 for select to anon,authenticated using (true);
create policy "banners admin all" on public.pa_banners
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));
create policy "challenges public read active" on public.pa_challenges
 for select to anon,authenticated using (coalesce(is_active,true));
create policy "challenges admin all" on public.pa_challenges
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));
create policy "section locks public read" on public.pa_section_locks
 for select to anon,authenticated using (true);
create policy "section locks admin all" on public.pa_section_locks
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));
create policy "settings public read" on public.pa_settings
 for select to anon,authenticated using (true);
create policy "settings admin all" on public.pa_settings
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

-- These tables cannot prove row ownership (OTP, deleted email, anonymous chat,
-- device bans and legacy vouchers), so only trusted server code may access them.
-- This is intentionally fail-closed.
do $block$
declare t text;
begin
  foreach t in array array[
    'chat_sessions','deleted_accounts','ex_otp_codes','lc_feedback','lc_messages',
    'lc_sessions','pa_banned_devices','pa_voucher_codes'
  ]
  loop
    execute format('revoke all on public.%I from public, anon, authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end
$block$;

-- Apply least privilege grants to the owner-bound tables.
do $block$
declare t text;
begin
  foreach t in array array[
    'ad_revenue_transactions','direct_discount_usages','pa_coins',
    'live_chat_history','weekly_giveaway_entries','weekly_giveaway_winners'
  ]
  loop
    execute format('revoke all on public.%I from public, anon, authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end
$block$;

revoke all on public.direct_discounts from public,anon,authenticated;
grant select on public.direct_discounts to authenticated;
grant all on public.direct_discounts to service_role;

revoke all on public.pa_device_tokens from public,anon,authenticated;
grant select,insert,update,delete on public.pa_device_tokens to authenticated;
grant all on public.pa_device_tokens to service_role;
revoke all on public.pa_login_history from public,anon,authenticated;
grant select,insert on public.pa_login_history to authenticated;
grant all on public.pa_login_history to service_role;
revoke all on public.pa_referrals from public,anon,authenticated;
grant select,insert on public.pa_referrals to authenticated;
grant all on public.pa_referrals to service_role;
revoke all on public.pa_story_views from public,anon,authenticated;
grant select,insert on public.pa_story_views to authenticated;
grant all on public.pa_story_views to service_role;
revoke all on public.pa_support from public,anon,authenticated;
grant select,insert on public.pa_support to authenticated;
grant all on public.pa_support to service_role;
revoke all on public.pa_user_sessions from public,anon,authenticated;
grant select,insert,update on public.pa_user_sessions to authenticated;
grant all on public.pa_user_sessions to service_role;

revoke all on public.pa_banners,public.pa_challenges,public.pa_section_locks,public.pa_settings
 from public,anon,authenticated;
grant select on public.pa_banners,public.pa_challenges,public.pa_section_locks,public.pa_settings
 to anon,authenticated;
grant all on public.pa_banners,public.pa_challenges,public.pa_section_locks,public.pa_settings
 to service_role;

-- Owner-policy indexes.
create index if not exists ad_revenue_transactions_user_idx on public.ad_revenue_transactions(user_id);
create index if not exists direct_discount_usages_user_idx on public.direct_discount_usages(user_id);
create index if not exists pa_coins_user_idx on public.pa_coins(user_id);
create index if not exists pa_device_tokens_user_idx on public.pa_device_tokens(user_id);
create index if not exists pa_login_history_user_idx on public.pa_login_history(user_id);
create index if not exists pa_referrals_referrer_idx on public.pa_referrals(referrer_id);
create index if not exists pa_referrals_referred_idx on public.pa_referrals(referred_id);
create index if not exists pa_story_views_user_idx on public.pa_story_views(user_id);
create index if not exists pa_support_user_idx on public.pa_support(user_id);
create index if not exists pa_user_sessions_user_idx on public.pa_user_sessions(user_id);
create index if not exists live_chat_history_user_idx on public.live_chat_history(user_id);

-- Prevent direct invocation of high-risk legacy/internal SECURITY DEFINER RPCs.
do $block$
declare r record;
begin
  for r in
    select p.oid::regprocedure signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any(array[
      'admin_request_identity_verification','admin_review_identity_verification',
      'claim_challenge_reward','decrement_promo_used_count',
      'increment_promo_used_count','get_public_ad_status','handle_auto_referral',
      'handle_signup_voucher','pa_assert_ad_allowed','pa_assert_balance_unlocked',
      'pa_force_logout','pa_guard_balance_lock','pa_lh_alerts','pa_lh_enrich',
      'pa_lock_wallet','pa_notify_account_locked','pa_on_ban_force_logout',
      'pa_protect_profile_columns','pa_reseal_profiles','register_ad_activity'
    ])
  loop
    execute format('revoke all on function %s from public,anon,authenticated',r.signature);
    execute format('grant execute on function %s to service_role',r.signature);
  end loop;
end
$block$;

-- Trigger functions never need direct PostgREST execution.
do $block$
declare r record;
begin
  for r in
    select distinct p.oid::regprocedure signature
    from pg_trigger g join pg_proc p on p.oid=g.tgfoid
    join pg_namespace n on n.oid=p.pronamespace
    where not g.tgisinternal and n.nspname='public'
  loop
    execute format('revoke all on function %s from public,anon,authenticated',r.signature);
    execute format('grant execute on function %s to service_role',r.signature);
  end loop;
end
$block$;

alter view public.chat_agent_profiles set (security_invoker=true);
revoke all on public.chat_agent_profiles from public,anon,authenticated;
grant select on public.chat_agent_profiles to service_role;
