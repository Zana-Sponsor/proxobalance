-- Proxo Balance customer support cases
-- Run once in the Supabase SQL editor. Safe to re-run.

begin;

create table if not exists public.ex_support_cases (
  id uuid primary key default gen_random_uuid(),
  case_number integer not null
    default ((floor(random() * 900000) + 100000)::integer) unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null default 'general'
    check (category in ('order', 'payment', 'account', 'technical', 'general')),
  order_code text null
    check (order_code is null or order_code ~ '^P[A-Z0-9]{11}$'),
  description text not null
    check (char_length(btrim(description)) between 10 and 2000),
  image_path text null
    check (image_path is null or char_length(image_path) between 38 and 500),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'closed')),
  admin_note text null
    check (admin_note is null or char_length(admin_note) <= 2000),
  assigned_admin uuid null references auth.users(id) on delete set null,
  resolved_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Older installations used an increasing identity (100001, 100002, ...).
-- Convert it to a six-digit value; the API supplies a cryptographically random
-- number and retries the unique constraint if two requests ever collide.
alter table public.ex_support_cases
  alter column case_number drop identity if exists;
alter table public.ex_support_cases
  alter column case_number type integer using case_number::integer;
alter table public.ex_support_cases
  alter column case_number set default ((floor(random() * 900000) + 100000)::integer);
alter table public.ex_support_cases
  drop constraint if exists ex_support_cases_case_number_six_digits;
alter table public.ex_support_cases
  add constraint ex_support_cases_case_number_six_digits
  check (case_number between 100000 and 999999);

alter table public.ex_support_cases
  drop constraint if exists ex_support_cases_status_check;
update public.ex_support_cases
set status = 'in_progress'
where status in ('needs_correction', 'corrected');
alter table public.ex_support_cases
  drop constraint if exists ex_support_cases_correction_request_check,
  drop constraint if exists ex_support_cases_customer_response_check;
alter table public.ex_support_cases
  add constraint ex_support_cases_status_check
    check (status in ('open', 'in_progress', 'resolved', 'closed'));
alter table public.ex_support_cases
  drop column if exists correction_request,
  drop column if exists correction_requested_at,
  drop column if exists customer_response,
  drop column if exists customer_responded_at;

create index if not exists ex_support_cases_user_created_idx
  on public.ex_support_cases (user_id, created_at desc);
create index if not exists ex_support_cases_status_created_idx
  on public.ex_support_cases (status, created_at desc);
create index if not exists ex_support_cases_assigned_admin_idx
  on public.ex_support_cases (assigned_admin);

alter table public.ex_support_cases enable row level security;
revoke all on table public.ex_support_cases from anon, authenticated;
grant select on table public.ex_support_cases to authenticated;

drop policy if exists ex_support_cases_select_own_or_admin on public.ex_support_cases;
create policy ex_support_cases_select_own_or_admin
on public.ex_support_cases
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or (select public.is_ex_admin())
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'support-case-images',
  'support-case-images',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists support_case_images_insert_own on storage.objects;
create policy support_case_images_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'support-case-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists support_case_images_select_own_or_admin on storage.objects;
create policy support_case_images_select_own_or_admin
on storage.objects
for select
to authenticated
using (
  bucket_id = 'support-case-images'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.is_ex_admin())
  )
);

alter table public.ex_notifications
  add column if not exists support_case_id uuid null
  references public.ex_support_cases(id) on delete set null;

create index if not exists ex_notifications_support_case_id_idx
  on public.ex_notifications (support_case_id);

comment on table public.ex_support_cases is
  'Customer-created support cases. Writes are performed by the authenticated server endpoint; customers can read only their own rows.';

commit;
