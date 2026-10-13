-- Additive V6 authoring guard. No backfill, deletes, ID/URL or ad changes.
-- Apply only to an approved isolated environment; production activation separate.
create or replace function public.proxolink_v6_management_guard() returns trigger
language plpgsql set search_path='' as $$
declare p jsonb;
begin
  if new.page_kind is null then return new; end if;
  if tg_op='INSERT' then
    -- Database owns PAGE_UUID even if a direct client attempts to supply one.
    new.id=gen_random_uuid();
    new.created_at=clock_timestamp();
  else
    if new.created_at is distinct from old.created_at then
      raise exception 'immutable_page_created_at' using errcode='23514';
    end if;
    if old.archived_at is not null and new.archived_at is distinct from old.archived_at then
      raise exception 'immutable_page_archive' using errcode='23514';
    end if;
  end if;
  new.updated_at=clock_timestamp();
  if new.status is null or new.status not in ('active','inactive') or
    new.publish_status is null or new.publish_status not in ('creating','ready','failed') then
    raise exception 'invalid_page_state' using errcode='23514';
  end if;
  for p in select value from jsonb_array_elements(new.settings->'providers') loop
    if p->>'provider_key' in ('lezzoo','wade') then
      -- Historical entries remain renderable, but cannot be added or rewritten.
      if tg_op='INSERT' then
        raise exception 'unsupported_page_provider' using errcode='23514';
      elsif not exists(select 1 from jsonb_array_elements(old.settings->'providers') q where q=p) then
        raise exception 'unsupported_page_provider' using errcode='23514';
      end if;
    end if;
  end loop;
  return new;
end $$;
revoke all on function public.proxolink_v6_management_guard() from public,anon,authenticated;
drop trigger if exists proxolink_v6_management_guard on public.proxolink_cards;
create trigger proxolink_v6_management_guard before insert or update on public.proxolink_cards
for each row execute function public.proxolink_v6_management_guard();
-- Anonymous clients never read private management columns or write any pages.
revoke all on public.proxolink_cards from public,anon;
-- Existing owner policies + restrictive V6 boundaries remain unchanged.
-- No new SECURITY DEFINER RPC or new authenticated privilege is introduced.
