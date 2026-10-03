-- Additive preparation. Cutover of client grants/legacy columns is separate.
create schema if not exists proxolink_private;
revoke all on schema proxolink_private from public,anon,authenticated;
create table if not exists proxolink_private.cards_backup_20261003 as
  select * from public.proxolink_cards;
alter table proxolink_private.cards_backup_20261003 enable row level security;
revoke all on proxolink_private.cards_backup_20261003 from public,anon,authenticated;
grant usage on schema proxolink_private to service_role;
grant select on proxolink_private.cards_backup_20261003 to service_role;

alter table public.proxolink_cards add column if not exists creation_request_hash text;
alter table public.proxolink_cards drop constraint if exists proxolink_card_language_check;
alter table public.proxolink_cards add constraint proxolink_card_language_check check(card_language in ('ku','ar','en'));
alter table public.proxolink_cards add constraint proxolink_template_version_check check(template_version>0);
alter table public.proxolink_cards add constraint proxolink_platforms_object_check check(jsonb_typeof(platforms)='object');
create index if not exists proxolink_cards_owner_created_idx on public.proxolink_cards(user_id,created_at desc);
create index if not exists proxolink_cards_owner_ready_idx on public.proxolink_cards(user_id,status,publish_status);

create or replace function proxolink_private.touch_updated_at() returns trigger
language plpgsql set search_path='' as $$ begin new.updated_at=clock_timestamp(); return new; end $$;
revoke all on function proxolink_private.touch_updated_at() from public,anon,authenticated;
create trigger proxolink_cards_updated before update on public.proxolink_cards
for each row execute function proxolink_private.touch_updated_at();
create trigger proxolink_templates_updated before update on public.proxolink_templates
for each row execute function proxolink_private.touch_updated_at();

revoke all on public.proxolink_templates,public.pa_ad_contact_links,public.pa_contact_events,public.proxolink_publish_attempts from anon,authenticated;
grant all on public.proxolink_templates,public.pa_ad_contact_links,public.pa_contact_events,public.proxolink_publish_attempts to service_role;
alter table public.proxolink_templates enable row level security;
alter table public.pa_ad_contact_links enable row level security;
alter table public.pa_contact_events enable row level security;
alter table public.proxolink_publish_attempts enable row level security;

alter table public.pa_ads add constraint pa_ads_proxolink_asset_fk foreign key(asset_id) references public.proxolink_cards(id) on delete restrict;
alter table public.pa_ads add constraint pa_ads_proxolink_card_fk foreign key(card_id) references public.proxolink_cards(id) on delete restrict;

create or replace function proxolink_private.validate_ad_card() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_card public.proxolink_cards%rowtype; v_id uuid;
begin
  if tg_op='UPDATE' and new.asset_id is not distinct from old.asset_id
    and new.card_id is not distinct from old.card_id and new.user_id=old.user_id
    and new.goal is not distinct from old.goal then return new; end if;
  v_id=coalesce(new.asset_id,new.card_id);
  if new.asset_id is not null and new.card_id is not null and new.asset_id<>new.card_id then raise exception 'PROXOLINK_CARD_MISMATCH'; end if;
  if v_id is null then
    if new.goal='messages' then raise exception 'ASSET_REQUIRED'; end if;
    return new;
  end if;
  select * into v_card from public.proxolink_cards where id=v_id for share;
  if not found or v_card.user_id<>new.user_id or v_card.status<>'active' or v_card.publish_status<>'ready' then raise exception 'ASSET_UNAVAILABLE'; end if;
  return new;
end $$;
revoke all on function proxolink_private.validate_ad_card() from public,anon,authenticated;
create trigger proxolink_validate_ad_card before insert or update of asset_id,card_id,user_id,goal on public.pa_ads
for each row execute function proxolink_private.validate_ad_card();

create or replace function proxolink_private.protect_live_card() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.status='inactive' and old.status='active' then
    perform 1 from public.pa_ads where (asset_id=old.id or card_id=old.id)
      and status not in ('completed','rejected','cancelled','canceled','failed') for share;
    if found then raise exception 'PROXOLINK_AD_DEPENDENCY'; end if;
  end if;
  return new;
end $$;
revoke all on function proxolink_private.protect_live_card() from public,anon,authenticated;
create trigger proxolink_protect_live_card before update of status on public.proxolink_cards
for each row execute function proxolink_private.protect_live_card();

update storage.buckets set file_size_limit=10485760 where id='proxolink-assets';
drop policy if exists "ProxoLink asset owner insert" on storage.objects;
drop policy if exists "ProxoLink asset owner update" on storage.objects;
drop policy if exists "ProxoLink asset owner delete" on storage.objects;
create policy "ProxoLink asset owner insert" on storage.objects for insert to authenticated with check(
 bucket_id='proxolink-assets' and (storage.foldername(name))[1]=(select auth.uid())::text
 and name~('^'||(select auth.uid())::text||'/[0-9a-f-]{36}/[A-Za-z0-9_-]+[.](jpg|jpeg|png|webp)$'));
create policy "ProxoLink unreferenced asset owner delete" on storage.objects for delete to authenticated using(
 bucket_id='proxolink-assets' and (storage.foldername(name))[1]=(select auth.uid())::text
 and not exists(select 1 from public.proxolink_cards where avatar_path=storage.objects.name));
-- Published objects are immutable: clients upload new filenames for replacements.

-- Raw IP is not retained; events keep bounded operational visitor detail.
create or replace function proxolink_private.forbid_raw_ip() returns trigger
language plpgsql set search_path='' as $$ begin new.ip_address=null; return new; end $$;
revoke all on function proxolink_private.forbid_raw_ip() from public,anon,authenticated;
create trigger proxolink_no_raw_ip before insert or update on public.pa_contact_events
for each row execute function proxolink_private.forbid_raw_ip();

-- Run only after 20261003_proxolink_private_staging.sql.
-- Token issuance is atomic and callable ONLY with the trusted service role.
create or replace function public.proxolink_issue_ad_link(
  p_ad_id uuid,
  p_owner_user_id uuid,
  p_public_token text
)
returns table (
  link_id uuid, link_ad_id uuid, link_card_id uuid,
  link_public_token text, link_version integer
)
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_ad public.pa_ads%rowtype;
  v_card public.proxolink_cards%rowtype;
  v_current public.pa_ad_contact_links%rowtype;
  v_new public.pa_ad_contact_links%rowtype;
  v_version integer;
begin
  if p_public_token is null
    or p_public_token !~ '^[A-Za-z0-9_-]{20,128}$'
  then
    raise exception 'invalid_tracking_token';
  end if;
  -- Lock the exact ad so two concurrent requests cannot issue two current
  -- links. The caller must have been verified by Proxo Auth on the server.
  select * into v_ad from public.pa_ads
  where id=p_ad_id and user_id=p_owner_user_id for update;
  if not found or coalesce(v_ad.asset_id,v_ad.card_id) is null then
    raise exception 'ad_not_found_or_not_owned';
  end if;
  select * into v_card from public.proxolink_cards
  where id=coalesce(v_ad.asset_id,v_ad.card_id) and user_id=p_owner_user_id
    and status='active' and publish_status='ready';
  if not found then
    raise exception 'card_not_available';
  end if;
  select * into v_current from public.pa_ad_contact_links
  where ad_id=p_ad_id and is_current=true for update;
  if found and v_current.card_id=v_card.id
    and v_current.status='active' then
    return query select v_current.id,v_current.ad_id,v_current.card_id,
      v_current.public_token,v_current.version;
    return;
  end if;
  select coalesce(max(version),0)+1 into v_version
  from public.pa_ad_contact_links where ad_id=p_ad_id;
  if v_current.id is not null then
    update public.pa_ad_contact_links
    set is_current=false,status='inactive',deactivated_at=now()
    where id=v_current.id;
  end if;
  insert into public.pa_ad_contact_links(
    ad_id,card_id,owner_user_id,public_token,version
  ) values(
    v_ad.id,v_card.id,p_owner_user_id,p_public_token,v_version
  ) returning * into v_new;
  return query select v_new.id,v_new.ad_id,v_new.card_id,
    v_new.public_token,v_new.version;
end
$$;
revoke all on function public.proxolink_issue_ad_link(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.proxolink_issue_ad_link(uuid,uuid,text)
  to service_role;

-- Create/version a unique link after an authoritative advertisement exists.
create or replace function proxolink_private.sync_ad_link() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_token text;
begin
  if tg_op='UPDATE' and (new.asset_id is distinct from old.asset_id or new.card_id is distinct from old.card_id) then
    update public.pa_ad_contact_links set is_current=false,status='inactive',deactivated_at=now() where ad_id=new.id and is_current;
  end if;
  if coalesce(new.asset_id,new.card_id) is null then return new; end if;
  if new.status in ('completed','rejected','cancelled','canceled','failed','inactive','paused') then
    update public.pa_ad_contact_links set status='inactive',deactivated_at=coalesce(deactivated_at,now()) where ad_id=new.id and is_current;
    return new;
  end if;
  v_token=translate(rtrim(encode(extensions.gen_random_bytes(24),'base64'),'='),'+/','-_');
  perform public.proxolink_issue_ad_link(new.id,new.user_id,v_token);
  return new;
end $$;
revoke all on function proxolink_private.sync_ad_link() from public,anon,authenticated;
create trigger proxolink_sync_ad_link after insert or update of asset_id,card_id,status on public.pa_ads
for each row execute function proxolink_private.sync_ad_link();

-- Preserve raw event counts/history; remove visitor identifiers after 30 days.
create or replace function proxolink_private.retain_contact_events() returns void
language sql security definer set search_path='' as $$
 update public.pa_contact_events set ip_address=null,ip_hash=null,visitor_hash=null,session_id=null,user_agent=null,device_type=null,browser=null,os=null,referrer=null
 where created_at<now()-interval '30 days' and (ip_hash is not null or session_id is not null or user_agent is not null);
$$;
revoke all on function proxolink_private.retain_contact_events() from public,anon,authenticated;
grant execute on function proxolink_private.retain_contact_events() to service_role;
