-- Proxo dynamic form system
-- Applied to Supabase project cojchkwssmasiejcgvbk.
-- Safe to re-run: tables/indexes use IF NOT EXISTS and policies/triggers/functions are replaced deliberately.

create table if not exists public.pa_forms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  description text check (description is null or char_length(description) <= 2000),
  product_image_url text check (
    product_image_url is null or product_image_url = '' or product_image_url like 'https://%'
  ),
  button_text text not null default 'داواکاری بنێرە'
    check (char_length(button_text) between 1 and 60),
  status text not null default 'active'
    check (status in ('active','inactive','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pa_forms_user_created_idx
  on public.pa_forms (user_id, created_at desc);

create table if not exists public.pa_form_fields (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.pa_forms(id) on delete cascade,
  field_key text not null check (field_key ~ '^[a-z][a-z0-9_]{0,39}$'),
  label text not null check (char_length(label) between 1 and 80),
  placeholder text check (placeholder is null or char_length(placeholder) <= 120),
  field_type text not null default 'text'
    check (field_type in ('text','phone','email','number','textarea','select')),
  required boolean not null default false,
  options jsonb not null default '[]'::jsonb
    check (jsonb_typeof(options) = 'array'),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (form_id, field_key)
);

create index if not exists pa_form_fields_form_sort_idx
  on public.pa_form_fields (form_id, sort_order, created_at);

create table if not exists public.pa_form_submissions (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.pa_forms(id) on delete cascade,
  ad_id uuid references public.pa_ads(id) on delete set null,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb
    check (jsonb_typeof(answers) = 'object'),
  attribution jsonb not null default '{}'::jsonb
    check (jsonb_typeof(attribution) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists pa_form_submissions_form_created_idx
  on public.pa_form_submissions (form_id, created_at desc);

create index if not exists pa_form_submissions_ad_created_idx
  on public.pa_form_submissions (ad_id, created_at desc)
  where ad_id is not null;

create index if not exists pa_form_submissions_owner_created_idx
  on public.pa_form_submissions (owner_user_id, created_at desc);

alter table public.pa_ads
  add column if not exists form_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pa_ads_form_id_fkey'
      and conrelid = 'public.pa_ads'::regclass
  ) then
    alter table public.pa_ads
      add constraint pa_ads_form_id_fkey
      foreign key (form_id) references public.pa_forms(id) on delete set null;
  end if;
end $$;

create index if not exists pa_ads_form_id_idx
  on public.pa_ads (form_id)
  where form_id is not null;

create or replace function public.pa_touch_form_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists pa_forms_touch_updated_at_trg on public.pa_forms;
create trigger pa_forms_touch_updated_at_trg
before update on public.pa_forms
for each row execute function public.pa_touch_form_updated_at();

create or replace function public.pa_ads_form_owner_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.form_id is not null and not exists (
    select 1
    from public.pa_forms f
    where f.id = new.form_id
      and f.user_id = new.user_id
      and f.status = 'active'
  ) then
    raise exception 'FORM_OWNER_MISMATCH';
  end if;
  return new;
end;
$$;

drop trigger if exists pa_ads_form_owner_guard_trg on public.pa_ads;
create trigger pa_ads_form_owner_guard_trg
before insert or update of form_id, user_id on public.pa_ads
for each row execute function public.pa_ads_form_owner_guard();

create or replace function public.pa_form_submission_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select f.user_id
  into v_owner
  from public.pa_forms f
  where f.id = new.form_id
    and f.status = 'active';

  if v_owner is null then
    raise exception 'FORM_NOT_ACTIVE';
  end if;

  new.owner_user_id := v_owner;

  if new.ad_id is not null and not exists (
    select 1
    from public.pa_ads a
    where a.id = new.ad_id
      and a.user_id = v_owner
      and a.form_id = new.form_id
  ) then
    raise exception 'FORM_AD_MISMATCH';
  end if;

  return new;
end;
$$;

drop trigger if exists pa_form_submission_guard_trg on public.pa_form_submissions;
create trigger pa_form_submission_guard_trg
before insert or update of form_id, ad_id, owner_user_id
on public.pa_form_submissions
for each row execute function public.pa_form_submission_guard();

alter table public.pa_forms enable row level security;
alter table public.pa_form_fields enable row level security;
alter table public.pa_form_submissions enable row level security;

drop policy if exists "forms select own" on public.pa_forms;
create policy "forms select own"
on public.pa_forms for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "forms insert own" on public.pa_forms;
create policy "forms insert own"
on public.pa_forms for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "forms update own" on public.pa_forms;
create policy "forms update own"
on public.pa_forms for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "forms delete own" on public.pa_forms;
create policy "forms delete own"
on public.pa_forms for delete to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "form fields select own" on public.pa_form_fields;
create policy "form fields select own"
on public.pa_form_fields for select to authenticated
using (exists (
  select 1 from public.pa_forms f
  where f.id = form_id and f.user_id = (select auth.uid())
));

drop policy if exists "form fields insert own" on public.pa_form_fields;
create policy "form fields insert own"
on public.pa_form_fields for insert to authenticated
with check (exists (
  select 1 from public.pa_forms f
  where f.id = form_id and f.user_id = (select auth.uid())
));

drop policy if exists "form fields update own" on public.pa_form_fields;
create policy "form fields update own"
on public.pa_form_fields for update to authenticated
using (exists (
  select 1 from public.pa_forms f
  where f.id = form_id and f.user_id = (select auth.uid())
))
with check (exists (
  select 1 from public.pa_forms f
  where f.id = form_id and f.user_id = (select auth.uid())
));

drop policy if exists "form fields delete own" on public.pa_form_fields;
create policy "form fields delete own"
on public.pa_form_fields for delete to authenticated
using (exists (
  select 1 from public.pa_forms f
  where f.id = form_id and f.user_id = (select auth.uid())
));

drop policy if exists "form submissions select own" on public.pa_form_submissions;
create policy "form submissions select own"
on public.pa_form_submissions for select to authenticated
using ((select auth.uid()) = owner_user_id);

create or replace function public.pa_create_form(
  p_title text,
  p_description text default null,
  p_product_image_url text default null,
  p_button_text text default 'داواکاری بنێرە',
  p_fields jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_form_id uuid;
  v_item jsonb;
  v_key text;
  v_label text;
  v_placeholder text;
  v_type text;
  v_required boolean;
  v_options jsonb;
  v_order integer := 0;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;

  p_title := btrim(coalesce(p_title, ''));
  p_description := nullif(btrim(coalesce(p_description, '')), '');
  p_product_image_url := nullif(btrim(coalesce(p_product_image_url, '')), '');
  p_button_text := btrim(coalesce(p_button_text, 'داواکاری بنێرە'));

  if char_length(p_title) not between 1 and 120
     or char_length(coalesce(p_description, '')) > 2000
     or char_length(p_button_text) not between 1 and 60
     or (p_product_image_url is not null and p_product_image_url !~ '^https://')
     or jsonb_typeof(coalesce(p_fields, '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_fields, '[]'::jsonb)) > 20
  then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end if;

  insert into public.pa_forms (
    user_id, title, description, product_image_url, button_text
  ) values (
    v_user, p_title, p_description, p_product_image_url, p_button_text
  )
  returning id into v_form_id;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_fields, '[]'::jsonb))
  loop
    v_order := v_order + 1;
    v_key := lower(btrim(coalesce(v_item->>'field_key', '')));
    v_label := btrim(coalesce(v_item->>'label', ''));
    v_placeholder := nullif(btrim(coalesce(v_item->>'placeholder', '')), '');
    v_type := lower(btrim(coalesce(v_item->>'field_type', 'text')));
    v_required := lower(coalesce(v_item->>'required', 'false')) in ('true','1','yes');
    v_options := case
      when jsonb_typeof(v_item->'options') = 'array' then v_item->'options'
      else '[]'::jsonb
    end;

    if v_key !~ '^[a-z][a-z0-9_]{0,39}$'
       or char_length(v_label) not between 1 and 80
       or char_length(coalesce(v_placeholder, '')) > 120
       or v_type not in ('text','phone','email','number','textarea','select')
       or (v_type = 'select' and jsonb_array_length(v_options) = 0)
       or exists (
         select 1 from public.pa_form_fields f
         where f.form_id = v_form_id and f.field_key = v_key
       )
    then
      raise exception 'INVALID_FORM_FIELD';
    end if;

    insert into public.pa_form_fields (
      form_id, field_key, label, placeholder, field_type,
      required, options, sort_order
    ) values (
      v_form_id, v_key, v_label, v_placeholder, v_type,
      v_required, v_options, v_order
    );
  end loop;

  return jsonb_build_object(
    'ok', true,
    'form_id', v_form_id,
    'form_path', '/form/' || v_form_id::text
  );
end;
$$;

revoke all on function public.pa_create_form(text,text,text,text,jsonb) from public;
grant execute on function public.pa_create_form(text,text,text,text,jsonb) to authenticated;

create or replace function public.pa_attach_form_to_ad(
  p_ad_id uuid,
  p_form_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;

  if not exists (
    select 1 from public.pa_ads a
    where a.id = p_ad_id and a.user_id = v_user
  ) then
    return jsonb_build_object('ok', false, 'code', 'AD_NOT_FOUND');
  end if;

  if not exists (
    select 1 from public.pa_forms f
    where f.id = p_form_id and f.user_id = v_user and f.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'FORM_NOT_FOUND');
  end if;

  update public.pa_ads
  set form_id = p_form_id,
      updated_at = now()
  where id = p_ad_id and user_id = v_user;

  return jsonb_build_object(
    'ok', true,
    'ad_id', p_ad_id,
    'form_id', p_form_id,
    'form_path', '/form/' || p_form_id::text,
    'destination_path', '/form/' || p_form_id::text || '?ad=' || p_ad_id::text
  );
end;
$$;

revoke all on function public.pa_attach_form_to_ad(uuid,uuid) from public;
grant execute on function public.pa_attach_form_to_ad(uuid,uuid) to authenticated;

create or replace function public.pa_get_public_form(p_form_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_form public.pa_forms%rowtype;
  v_fields jsonb;
begin
  select *
  into v_form
  from public.pa_forms
  where id = p_form_id
    and status = 'active';

  if not found then
    return jsonb_build_object('ok', false, 'code', 'FORM_NOT_FOUND');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', f.id,
        'field_key', f.field_key,
        'label', f.label,
        'placeholder', f.placeholder,
        'field_type', f.field_type,
        'required', f.required,
        'options', f.options,
        'sort_order', f.sort_order
      )
      order by f.sort_order, f.created_at
    ),
    '[]'::jsonb
  )
  into v_fields
  from public.pa_form_fields f
  where f.form_id = p_form_id;

  return jsonb_build_object(
    'ok', true,
    'form', jsonb_build_object(
      'id', v_form.id,
      'title', v_form.title,
      'description', v_form.description,
      'product_image_url', v_form.product_image_url,
      'button_text', v_form.button_text
    ),
    'fields', v_fields
  );
end;
$$;

revoke all on function public.pa_get_public_form(uuid) from public;
grant execute on function public.pa_get_public_form(uuid) to anon, authenticated;

create or replace function public.pa_submit_public_form(
  p_form_id uuid,
  p_ad_id uuid default null,
  p_answers jsonb default '{}'::jsonb,
  p_attribution jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_field record;
  v_value text;
  v_clean_answers jsonb := '{}'::jsonb;
  v_clean_attr jsonb := '{}'::jsonb;
  v_submission_id uuid;
begin
  if jsonb_typeof(coalesce(p_answers, '{}'::jsonb)) <> 'object'
     or jsonb_typeof(coalesce(p_attribution, '{}'::jsonb)) <> 'object'
  then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end if;

  select f.user_id
  into v_owner
  from public.pa_forms f
  where f.id = p_form_id
    and f.status = 'active';

  if v_owner is null then
    return jsonb_build_object('ok', false, 'code', 'FORM_NOT_FOUND');
  end if;

  if p_ad_id is not null and not exists (
    select 1
    from public.pa_ads a
    where a.id = p_ad_id
      and a.user_id = v_owner
      and a.form_id = p_form_id
  ) then
    return jsonb_build_object('ok', false, 'code', 'FORM_AD_MISMATCH');
  end if;

  for v_field in
    select field_key, field_type, required, options
    from public.pa_form_fields
    where form_id = p_form_id
    order by sort_order, created_at
  loop
    v_value := btrim(coalesce(p_answers->>v_field.field_key, ''));

    if v_field.required and v_value = '' then
      return jsonb_build_object(
        'ok', false,
        'code', 'INVALID_FIELD',
        'field', v_field.field_key,
        'message', 'تکایە ئەم خانەیە پڕ بکەرەوە.'
      );
    end if;

    if char_length(v_value) > (case when v_field.field_type = 'textarea' then 2000 else 500 end) then
      return jsonb_build_object(
        'ok', false,
        'code', 'INVALID_FIELD',
        'field', v_field.field_key,
        'message', 'دەقەکە زۆر درێژە.'
      );
    end if;

    if v_value <> '' and v_field.field_type = 'phone'
       and v_value !~ '^[0-9+() -]{6,25}$'
    then
      return jsonb_build_object(
        'ok', false,
        'code', 'INVALID_FIELD',
        'field', v_field.field_key,
        'message', 'ژمارەی مۆبایل دروست بنووسە.'
      );
    end if;

    if v_value <> '' and v_field.field_type = 'email'
       and v_value !~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    then
      return jsonb_build_object(
        'ok', false,
        'code', 'INVALID_FIELD',
        'field', v_field.field_key,
        'message', 'ئیمەیڵەکە دروست نییە.'
      );
    end if;

    if v_value <> '' and v_field.field_type = 'number'
       and v_value !~ '^-?[0-9]+([.][0-9]+)?$'
    then
      return jsonb_build_object(
        'ok', false,
        'code', 'INVALID_FIELD',
        'field', v_field.field_key,
        'message', 'تکایە ژمارەیەکی دروست بنووسە.'
      );
    end if;

    if v_value <> '' and v_field.field_type = 'select'
       and not exists (
         select 1
         from jsonb_array_elements_text(v_field.options) o(value)
         where o.value = v_value
       )
    then
      return jsonb_build_object(
        'ok', false,
        'code', 'INVALID_FIELD',
        'field', v_field.field_key,
        'message', 'هەڵبژاردەکە دروست نییە.'
      );
    end if;

    v_clean_answers := v_clean_answers || jsonb_build_object(v_field.field_key, v_value);
  end loop;

  v_clean_attr := jsonb_strip_nulls(jsonb_build_object(
    'ttclid', nullif(left(btrim(coalesce(p_attribution->>'ttclid','')), 500), ''),
    'utm_source', nullif(left(btrim(coalesce(p_attribution->>'utm_source','')), 200), ''),
    'utm_medium', nullif(left(btrim(coalesce(p_attribution->>'utm_medium','')), 200), ''),
    'utm_campaign', nullif(left(btrim(coalesce(p_attribution->>'utm_campaign','')), 300), ''),
    'utm_content', nullif(left(btrim(coalesce(p_attribution->>'utm_content','')), 300), ''),
    'utm_term', nullif(left(btrim(coalesce(p_attribution->>'utm_term','')), 300), '')
  ));

  insert into public.pa_form_submissions (
    form_id, ad_id, owner_user_id, answers, attribution
  ) values (
    p_form_id, p_ad_id, v_owner, v_clean_answers, v_clean_attr
  )
  returning id into v_submission_id;

  return jsonb_build_object(
    'ok', true,
    'submission_id', v_submission_id
  );
end;
$$;

revoke all on function public.pa_submit_public_form(uuid,uuid,jsonb,jsonb) from public;
grant execute on function public.pa_submit_public_form(uuid,uuid,jsonb,jsonb) to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'form-assets',
  'form-assets',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "form assets insert own" on storage.objects;
create policy "form assets insert own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'form-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "form assets update own" on storage.objects;
create policy "form assets update own"
on storage.objects for update to authenticated
using (
  bucket_id = 'form-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'form-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "form assets delete own" on storage.objects;
create policy "form assets delete own"
on storage.objects for delete to authenticated
using (
  bucket_id = 'form-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);


-- Explicit function grants.
-- Supabase may grant EXECUTE directly to anon/authenticated when a function is created,
-- so revoke/grant the exact roles after all CREATE OR REPLACE statements above.

revoke execute on function public.pa_create_form(text,text,text,text,jsonb) from public, anon;
grant execute on function public.pa_create_form(text,text,text,text,jsonb) to authenticated, service_role;

revoke execute on function public.pa_attach_form_to_ad(uuid,uuid) from public, anon;
grant execute on function public.pa_attach_form_to_ad(uuid,uuid) to authenticated, service_role;

-- Trigger helper functions are not public RPC endpoints.
revoke execute on function public.pa_ads_form_owner_guard() from public, anon, authenticated;
revoke execute on function public.pa_form_submission_guard() from public, anon, authenticated;
revoke execute on function public.pa_touch_form_updated_at() from public, anon, authenticated;

-- These two RPCs are intentionally public because the landing page is public.
-- They expose only display-safe data / validated submissions.
revoke execute on function public.pa_get_public_form(uuid) from public;
grant execute on function public.pa_get_public_form(uuid) to anon, authenticated, service_role;

revoke execute on function public.pa_submit_public_form(uuid,uuid,jsonb,jsonb) from public;
grant execute on function public.pa_submit_public_form(uuid,uuid,jsonb,jsonb) to anon, authenticated, service_role;
