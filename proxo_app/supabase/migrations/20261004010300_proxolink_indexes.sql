create index if not exists pa_ad_contact_links_owner_idx on public.pa_ad_contact_links(owner_user_id);
create index if not exists pa_ads_proxolink_asset_idx on public.pa_ads(asset_id) where asset_id is not null;
create index if not exists pa_ads_proxolink_card_idx on public.pa_ads(card_id) where card_id is not null;
alter table proxolink_private.cards_backup_20261003 add primary key(id);
-- Publish audit is server-only, with its access granted to service_role.
drop policy if exists "Owner reads own ProxoLink publish history" on public.proxolink_publish_attempts;
