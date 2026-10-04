-- Run only after authenticated Vercel preview/production endpoint and mobile
-- verification. Inside the caller's transaction set:
--   select set_config('proxolink.production_verified','true',true);
-- This guard prevents an unverified or automatic migration from exposing cards.
do $$ begin
 if current_setting('proxolink.production_verified',true) is distinct from 'true' then
  raise exception 'Verify live ProxoLink endpoints and mobile flows before cutover';
 end if;
end $$;

lock table public.proxolink_cards in share row exclusive mode;
lock table public.pa_ads in share row exclusive mode;
do $$ begin
 if (select count(*) from proxolink_private.card_migration_manifest_20261004)
    <> (select count(*) from public.proxolink_cards) then
  raise exception 'The customer migration checkpoint no longer covers every card';
 end if;
 if exists (
  select 1 from public.proxolink_cards c
  left join proxolink_private.card_migration_manifest_20261004 m on m.card_id=c.id
  where m.card_id is null or m.user_id<>c.user_id
    or md5(coalesce(c.html_content,''))<>m.expected_legacy_html_md5
    or md5(coalesce(c.avatar_b64,''))<>m.expected_avatar_md5
    or jsonb_build_object('name',c.name,'bio',c.bio,'tt',c.tt,'tiktok',c.tiktok,
      'platforms',c.platforms,'style',c.style,'template_key',c.template_key,
      'template_version',c.template_version,'color_theme',c.color_theme,
      'avatar_path',c.avatar_path,'card_language',c.card_language,
      'status',c.status,'publish_status',c.publish_status)<>m.expected_fields
 ) then raise exception 'A customer card changed; reverify that card without overwriting it'; end if;
 if exists (
  select 1 from proxolink_private.card_migration_manifest_20261004 m
  left join public.proxolink_templates t
    on t.template_key=m.recovered_fields->>'template_key'
    and t.version=(m.recovered_fields->>'template_version')::integer and t.is_active
  where t.id is null or not exists(select 1 from storage.objects o
    where o.bucket_id='proxolink-templates' and o.name=t.storage_path)
    or (t.requires_avatar and m.recovered_fields->>'avatar_path' is null)
    or (m.recovered_fields->>'avatar_path' is not null and (
       m.verified_avatar_sha256 is null or not exists(select 1 from storage.objects o
       where o.bucket_id='proxolink-assets' and o.name=m.recovered_fields->>'avatar_path')))
 ) then raise exception 'An exact template version or verified binary avatar is missing'; end if;
 if (select public from storage.buckets where id='proxolink-templates') is distinct from false
 then raise exception 'The template bucket must remain private'; end if;
 if (select count(*) from public.proxolink_templates where is_active and is_catalog_visible)<>8
 then raise exception 'The live catalog must contain the eight original templates'; end if;
end $$;

update public.proxolink_cards c set
 bio=m.recovered_fields->>'bio',tt=m.recovered_fields->>'tt',tiktok=m.recovered_fields->>'tiktok',
 platforms=m.recovered_fields->'platforms',template_key=m.recovered_fields->>'template_key',
 template_version=(m.recovered_fields->>'template_version')::integer,
 avatar_path=m.recovered_fields->>'avatar_path',publish_status='ready',
 last_publish_error_code=null,last_publish_error_at=null,
 published_at=coalesce(c.published_at,now())
from proxolink_private.card_migration_manifest_20261004 m where m.card_id=c.id;

alter table public.proxolink_cards add constraint proxolink_status_check check(status in ('active','inactive'));
alter table public.proxolink_cards add constraint proxolink_card_template_fk
 foreign key(template_key,template_version) references public.proxolink_templates(template_key,version) on delete restrict;
create trigger proxolink_ad_card_validation before insert or update of asset_id,card_id,user_id,goal
 on public.pa_ads for each row execute function proxolink_private.validate_ad_card();
create trigger proxolink_ad_link_sync after insert or update of asset_id,card_id,status,user_id
 on public.pa_ads for each row execute function proxolink_private.sync_ad_link();

-- One independently generated token for each existing authoritative ad UUID.
-- Completed/rejected ads retain their own inactive history link.
insert into public.pa_ad_contact_links(ad_id,card_id,owner_user_id,public_token,status,version,is_current,deactivated_at)
 select a.id,coalesce(a.asset_id,a.card_id),a.user_id,
  translate(rtrim(encode(extensions.gen_random_bytes(24),'base64'),'='),'+/','-_'),
  case when a.status in ('completed','rejected','cancelled','canceled','failed','inactive','paused') then 'inactive' else 'active' end,
  1,true,case when a.status in ('completed','rejected','cancelled','canceled','failed','inactive','paused') then now() end
 from public.pa_ads a join public.proxolink_cards c on c.id=coalesce(a.asset_id,a.card_id)
  and c.user_id=a.user_id and c.publish_status='ready'
 where not exists(select 1 from public.pa_ad_contact_links l where l.ad_id=a.id)
 on conflict do nothing;

-- Client reads safe structured columns only. All card mutations go through
-- authenticated, owner-checked Vercel validation and optimistic publication.
revoke all on public.proxolink_cards from public,anon,authenticated;
drop policy if exists "cards admin all" on public.proxolink_cards;
drop policy if exists "cards own all" on public.proxolink_cards;
create policy "ProxoLink owner or admin reads safe cards" on public.proxolink_cards
 for select to authenticated using(user_id=(select auth.uid()) or (select public.pa_is_admin()));
grant select(id,user_id,name,bio,tt,tiktok,platforms,style,color_theme,template_key,
 template_version,card_language,avatar_path,status,publish_status,card_number,
 created_at,updated_at,published_at,client_request_id,creation_request_hash,
 last_publish_error_code,last_publish_error_at) on public.proxolink_cards to authenticated;
grant all on public.proxolink_cards to service_role;

-- Existing full rows were verified in the private rollback backup before any
-- cleanup. No client can retrieve legacy HTML/base64, even through SELECT *.
alter table public.proxolink_cards drop column html_content;
alter table public.proxolink_cards drop column avatar_b64;
alter table public.proxolink_cards drop column logo_b64;
