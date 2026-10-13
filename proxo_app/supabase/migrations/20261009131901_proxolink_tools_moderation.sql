-- Isolated migration only. Existing table, owner boundary, assets and ad FKs retained.
-- No production application, publication activation, role system or admin UI.
alter table public.proxolink_cards add column if not exists moderation_status text not null default 'pending';
do $$ begin
 if not exists(select 1 from pg_constraint where conrelid='public.proxolink_cards'::regclass and conname='proxolink_moderation_status_check') then
  alter table public.proxolink_cards add constraint proxolink_moderation_status_check check(moderation_status in ('pending','approved','rejected'));
 end if;
 if not exists(select 1 from pg_constraint where conrelid='public.proxolink_cards'::regclass and conname='proxolink_v6_tiktok_check') then
  alter table public.proxolink_cards add constraint proxolink_v6_tiktok_check check(page_kind is null or tt is null or tt='' or tt ~ '^[A-Za-z0-9._]{1,40}$') not valid;
 end if;
end $$;
-- The invoker role, not a client field/GUC/user_metadata, controls moderation.
-- Existing trusted backend uses service_role. Authenticated owners (including
-- direct REST callers) cannot approve/reject. No new privileged RPC/grants.
create or replace function public.proxolink_moderation_guard() returns trigger
language plpgsql set search_path='' as $$ begin
 if tg_op='INSERT' then
  if new.moderation_status is distinct from 'pending' then
   raise exception 'new_page_must_be_pending' using errcode='23514';
  end if;
 elsif new.moderation_status is distinct from old.moderation_status then
  if current_user not in ('service_role','postgres') then
   raise exception 'moderation_requires_trusted_server' using errcode='42501';
  end if;
  if old.moderation_status<>'pending' or new.moderation_status not in ('approved','rejected') then
   raise exception 'invalid_moderation_transition' using errcode='23514';
  end if;
 end if;
 return new;
end $$;
revoke all on function public.proxolink_moderation_guard() from public,anon,authenticated;
drop trigger if exists proxolink_moderation_guard on public.proxolink_cards;
create trigger proxolink_moderation_guard before insert or update on public.proxolink_cards for each row execute function public.proxolink_moderation_guard();
-- Remove only the historical-only authoring restriction. The existing settings
-- CHECK retains all provider/type/host validation. Identity/time/state stay guarded.
create or replace function public.proxolink_v6_management_guard() returns trigger
language plpgsql set search_path='' as $$ begin
 if new.page_kind is null then return new; end if;
 if tg_op='INSERT' then
  new.id=gen_random_uuid(); new.created_at=clock_timestamp();
 else
  if new.created_at is distinct from old.created_at then
   raise exception 'immutable_page_created_at' using errcode='23514';
  end if;
  if old.archived_at is not null and new.archived_at is distinct from old.archived_at then
   raise exception 'immutable_page_archive' using errcode='23514';
  end if;
 end if;
 new.updated_at=clock_timestamp();
 if new.status is null or new.status not in ('active','inactive') or new.publish_status is null or new.publish_status not in ('creating','ready','failed') then
  raise exception 'invalid_page_state' using errcode='23514';
 end if;
 return new;
end $$;
revoke all on function public.proxolink_v6_management_guard() from public,anon,authenticated;
-- Actual owner DELETE; FK restrictions remain the final dependency authority.
drop policy if exists "V6 archive instead of delete" on public.proxolink_cards;
drop policy if exists "V6 owner delete" on public.proxolink_cards;
create policy "V6 owner delete" on public.proxolink_cards as restrictive for delete to authenticated
 using(page_kind is null or (select auth.uid())=user_id);
-- Existing owner-created indexes already satisfy newest-first collection reads.
