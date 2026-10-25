-- Run only in an isolated test database after the additive migration.
begin;
do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.app_release_policies'::regclass) then
    raise exception 'RLS must be enabled';
  end if;
  if has_table_privilege('anon', 'public.app_release_policies', 'INSERT') or
     has_table_privilege('authenticated', 'public.app_release_policies', 'UPDATE') or
     has_table_privilege('anon', 'public.app_release_policies', 'SELECT') then
    raise exception 'Direct client access must be denied';
  end if;
  if not has_function_privilege('anon', 'public.proxo_app_update_policy(text,text)', 'EXECUTE') then
    raise exception 'Policy must be readable before login';
  end if;
  if public.proxo_app_update_policy('android', 'stable') is not null then
    raise exception 'Migration must not activate a policy';
  end if;
  begin
    insert into public.app_release_policies(platform, latest_build, latest_version, required_enabled)
      values ('android', 12, '1.0.12', true);
    raise exception 'Unverified forced update was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.app_release_policies(platform, latest_build, latest_version, message)
      values ('android', 12, '1.0.12', repeat('x', 601));
    raise exception 'Oversized message was accepted';
  exception when check_violation then null;
  end;
end $$;

insert into public.app_release_policies(platform, latest_build, latest_version)
values ('android', 12, '1.0.12');
do $$ begin
  if public.proxo_app_update_policy('android', 'stable') is not null then
    raise exception 'Disabled policy leaked';
  end if;
end $$;
update public.app_release_policies set enabled = true, release_verified = true,
  published_at = now() + interval '1 day',
  update_url = 'https://play.google.com/store/apps/details?id=com.proxo.proxoapp';
do $$ begin
  if public.proxo_app_update_policy('android', 'stable') is not null then
    raise exception 'Future unpublished build leaked';
  end if;
end $$;
update public.app_release_policies set published_at = now() - interval '1 day';
set local role anon;
do $$ begin
  if (public.proxo_app_update_policy('android', 'stable')->>'latest_build')::int <> 12 then
    raise exception 'Anonymous policy read failed';
  end if;
  if public.proxo_app_update_policy('ios', 'stable') is not null or
     public.proxo_app_update_policy('android', 'beta') is not null then
    raise exception 'Platform/channel policy leaked';
  end if;
end $$;
reset role;
update public.app_release_policies set minimum_build = 11, required_enabled = true;
do $$ begin
  if not (public.proxo_app_update_policy('android', 'stable')->>'required_enabled')::boolean then
    raise exception 'Verified required policy not returned';
  end if;
end $$;
update public.app_release_policies set enabled = false, required_enabled = false;
do $$ begin
  if public.proxo_app_update_policy('android', 'stable') is not null then
    raise exception 'Withdrawal did not remove policy';
  end if;
end $$;
rollback;
