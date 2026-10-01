-- Consolidate duplicate owner policies and use init-plan-safe auth checks.
do $block$
declare r record;
begin
  for r in select schemaname,tablename,policyname from pg_policies
   where schemaname='public' and tablename=any(array[
     'profiles','proxolink_cards','pa_assets','pa_notifications','pa_coin_transactions'
   ])
  loop
    execute format('drop policy if exists %I on %I.%I',r.policyname,r.schemaname,r.tablename);
  end loop;
end
$block$;

create policy "profiles select own" on public.profiles
 for select to authenticated using ((select auth.uid())=id);
create policy "profiles insert own" on public.profiles
 for insert to authenticated with check ((select auth.uid())=id);
create policy "profiles update own" on public.profiles
 for update to authenticated using ((select auth.uid())=id)
 with check ((select auth.uid())=id);
create policy "profiles admin all" on public.profiles
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "cards own all" on public.proxolink_cards
 for all to authenticated using ((select auth.uid())=user_id)
 with check ((select auth.uid())=user_id);
create policy "cards admin all" on public.proxolink_cards
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "legacy assets own select" on public.pa_assets
 for select to authenticated using ((select auth.uid())=user_id);
create policy "legacy assets admin all" on public.pa_assets
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "notifications own select" on public.pa_notifications
 for select to authenticated using ((select auth.uid())=user_id);
create policy "notifications own update" on public.pa_notifications
 for update to authenticated using ((select auth.uid())=user_id)
 with check ((select auth.uid())=user_id);
create policy "notifications own delete" on public.pa_notifications
 for delete to authenticated using ((select auth.uid())=user_id);
create policy "notifications admin all" on public.pa_notifications
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

create policy "coin transactions own select" on public.pa_coin_transactions
 for select to authenticated using ((select auth.uid())=user_id);
create policy "coin transactions admin all" on public.pa_coin_transactions
 for all to authenticated using ((select public.pa_is_admin()))
 with check ((select public.pa_is_admin()));

revoke all on public.profiles from public,anon,authenticated;
grant select,insert,update on public.profiles to authenticated;
grant all on public.profiles to service_role;
revoke all on public.proxolink_cards from public,anon,authenticated;
grant select,insert,update,delete on public.proxolink_cards to authenticated;
grant all on public.proxolink_cards to service_role;
revoke all on public.pa_assets from public,anon,authenticated;
grant select on public.pa_assets to authenticated;
grant all on public.pa_assets to service_role;
revoke all on public.pa_notifications from public,anon,authenticated;
grant select,update,delete on public.pa_notifications to authenticated;
grant all on public.pa_notifications to service_role;
revoke all on public.pa_coin_transactions from public,anon,authenticated;
grant select on public.pa_coin_transactions to authenticated;
grant all on public.pa_coin_transactions to service_role;

create index if not exists proxolink_cards_user_idx on public.proxolink_cards(user_id);
create index if not exists pa_assets_user_idx on public.pa_assets(user_id);
create index if not exists pa_notifications_user_created_idx
 on public.pa_notifications(user_id,created_at desc);
create index if not exists pa_coin_transactions_user_idx
 on public.pa_coin_transactions(user_id);
create index if not exists pa_ads_direct_discount_idx
 on public.pa_ads(direct_discount_id) where direct_discount_id is not null;
