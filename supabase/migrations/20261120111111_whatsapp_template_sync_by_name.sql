-- v56: keep the WhatsApp templates in step with Wevlix.
--   • A template is found by its id, or by its name when it was made again in Wevlix
--     (the new id is taken over).
--   • A template that is no longer in Wevlix stops sending (active = false), so no
--     message is queued with a template that does not exist.
create or replace function public.ex_wa_sync_templates(p_key text, p_templates jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_count integer := 0;
  v_list jsonb := case when jsonb_typeof(p_templates) = 'array' then p_templates else '[]'::jsonb end;
begin
  if p_key is null or not exists (select 1 from public.ex_whatsapp_worker_keys k
      where k.active and k.key_hash = encode(extensions.digest(p_key, 'sha256'), 'hex')) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  with items as (
    select value as item from jsonb_array_elements(v_list)
  ), pick as (
    select t.kind, coalesce(
      (select i.item from items i where i.item ->> 'id' = t.template_id limit 1),
      (select i.item from items i
        where i.item ->> 'name' = t.template_name
          and not exists (select 1 from public.ex_whatsapp_templates o where o.template_id = i.item ->> 'id' and o.kind <> t.kind)
        order by coalesce((i.item -> 'readiness' ->> 'canSend')::boolean, false) desc, i.item ->> 'updatedAt' desc nulls last
        limit 1)) as item
    from public.ex_whatsapp_templates t
  )
  update public.ex_whatsapp_templates t set
    template_id = p.item ->> 'id',
    active = coalesce((p.item -> 'readiness' ->> 'canSend')::boolean, false),
    meta_status = p.item ->> 'status',
    template_name = coalesce(p.item ->> 'name', t.template_name),
    checked_at = now(),
    updated_at = case when t.active is distinct from coalesce((p.item -> 'readiness' ->> 'canSend')::boolean, false)
                        or t.template_id is distinct from p.item ->> 'id' then now() else t.updated_at end
  from pick p
  where p.kind = t.kind and p.item is not null;
  get diagnostics v_count = row_count;

  -- not in Wevlix any more: it cannot send (only when Wevlix answered with a full, single page)
  if jsonb_array_length(v_list) between 1 and 49 then
    update public.ex_whatsapp_templates t set
      active = false, meta_status = null, checked_at = now(),
      updated_at = case when t.active then now() else t.updated_at end
    where not exists (select 1 from jsonb_array_elements(v_list) x
                       where x.value ->> 'id' = t.template_id or x.value ->> 'name' = t.template_name);
  end if;

  return jsonb_build_object('ok', true, 'updated', v_count,
    'templates', (select jsonb_agg(jsonb_build_object('kind', kind, 'active', active, 'status', meta_status)) from public.ex_whatsapp_templates));
end $function$;
