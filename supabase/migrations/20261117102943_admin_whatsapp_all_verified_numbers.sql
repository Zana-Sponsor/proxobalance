-- Include every customer with a verified, normalizable phone in the super-admin
-- WhatsApp controls. Customers without a settings row default to disabled.
create or replace function public.ex_admin_whatsapp_subscribers()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(jsonb_agg(to_jsonb(r) order by r.enabled desc, r.updated_at desc nulls last, r.full_name), '[]'::jsonb)
  from (
    select p.id as user_id,
           coalesce(s.enabled, false) as enabled,
           public.ex_wa_normalize_phone(p.phone) as phone,
           coalesce(s.created_at, p.created_at) as created_at,
           coalesce(s.updated_at, p.created_at) as updated_at,
           p.full_name,
           p.email,
           p.phone as account_phone,
           true as phone_verified,
           (select jsonb_build_object('enabled', c.enabled, 'at', c.created_at, 'by_admin', c.changed_by is not null)
              from public.ex_whatsapp_consent_log c
             where c.user_id = p.id
             order by c.created_at desc
             limit 1) as last_change,
           (select count(*) from public.ex_whatsapp_messages m where m.user_id = p.id and m.status = 'sent') as sent,
           (select count(*) from public.ex_whatsapp_messages m where m.user_id = p.id and m.status = 'failed') as failed
      from public.ex_profiles p
      left join public.ex_whatsapp_settings s on s.user_id = p.id
     where p.phone_verified_at is not null
       and public.ex_wa_normalize_phone(p.phone) is not null
  ) r;
$$;

create or replace function public.ex_admin_whatsapp_set(p_user uuid, p_enabled boolean, p_admin uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_phone text;
  v_cur public.ex_whatsapp_settings;
begin
  if p_user is null or p_enabled is null or p_admin is null then
    raise exception 'bad_input' using errcode = '22023';
  end if;

  select public.ex_wa_normalize_phone(p.phone)
    into v_phone
    from public.ex_profiles p
   where p.id = p_user
     and p.phone_verified_at is not null;
  if v_phone is null then
    raise exception 'phone_not_verified' using errcode = '22023';
  end if;

  select * into v_cur
    from public.ex_whatsapp_settings
   where user_id = p_user
   for update;

  if not found then
    insert into public.ex_whatsapp_settings (user_id, phone, enabled)
    values (p_user, v_phone, p_enabled)
    on conflict (user_id) do update
      set phone = excluded.phone,
          enabled = excluded.enabled,
          updated_at = now();
  elsif v_cur.enabled is not distinct from p_enabled
        and v_cur.phone is not distinct from v_phone then
    return jsonb_build_object('user_id', p_user, 'enabled', p_enabled, 'changed', false);
  else
    update public.ex_whatsapp_settings
       set enabled = p_enabled,
           phone = v_phone,
           updated_at = now()
     where user_id = p_user;
  end if;

  insert into public.ex_whatsapp_consent_log (user_id, enabled, phone, changed_by)
  values (p_user, p_enabled, v_phone, p_admin);

  return jsonb_build_object('user_id', p_user, 'enabled', p_enabled, 'changed', true);
end;
$$;

revoke all on function public.ex_admin_whatsapp_subscribers() from public, anon, authenticated;
revoke all on function public.ex_admin_whatsapp_set(uuid, boolean, uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_whatsapp_subscribers() to service_role;
grant execute on function public.ex_admin_whatsapp_set(uuid, boolean, uuid) to service_role;
