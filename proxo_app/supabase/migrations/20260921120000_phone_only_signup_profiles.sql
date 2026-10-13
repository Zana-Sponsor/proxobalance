-- Phone-only registration keeps the synthetic Auth address out of the public
-- profile. Existing email users are unchanged.
alter table public.profiles
  alter column email drop not null;

comment on column public.profiles.email is
  'Nullable for phone-only accounts; real email may be added later through the verified profile flow.';
