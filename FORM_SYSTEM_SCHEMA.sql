-- Proxo dynamic form system
-- Prepared for the pa_* Supabase project. Review, test in a transaction, then apply deliberately.

begin;

create table if not exists public.pa_forms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  description text,
  product_image_url text,
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
  placeholder text,
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

-- Database-level ownership guard: an ad may only reference a form owned by the same user.
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

-- Database-level submission guard: owner is derived from the form, and an optional ad
-- must belong to that owner and reference that exact form.
create or replace function public.pa_form_submission_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select f.user_id into v_owner
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

-- Public visitors never insert directly into Supabase.
-- /api/forms verifies the form/ad relationship and writes with the server service role.

commit;
