-- Proxo Balance admin contract signing
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.is_contract_admin()
returns boolean language sql stable security definer set search_path=''
as $$
  select exists(
    select 1 from public.ex_profiles p
    where p.id=(select auth.uid()) and p.is_admin=true and coalesce(p.is_banned,false)=false
      and (p.role='super_admin' or p.staff_permissions is null or 'view'=any(p.staff_permissions))
  );
$$;
revoke all on function private.is_contract_admin() from public, anon;
grant execute on function private.is_contract_admin() to authenticated;

create table if not exists public.ex_admin_contracts (
  id uuid primary key default gen_random_uuid(),
  contract_number text not null unique,
  title text not null,
  website_name text not null,
  monthly_rent bigint not null check (monthly_rent>0),
  currency text not null default 'IQD',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  owner_admin_id uuid not null references public.ex_profiles(id) on delete restrict,
  renter_admin_id uuid not null references public.ex_profiles(id) on delete restrict,
  owner_full_name text not null,
  renter_full_name text not null,
  terms jsonb not null default '[]'::jsonb,
  owner_signature_data text,
  owner_signed_at timestamptz,
  renter_signature_data text,
  renter_signed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ex_admin_contract_party_chk check(owner_admin_id<>renter_admin_id),
  constraint ex_admin_contract_dates_chk check(ends_at>starts_at),
  constraint ex_admin_contract_terms_chk check(jsonb_typeof(terms)='array'),
  constraint ex_admin_contract_owner_signature_chk check(owner_signature_data is null or (length(owner_signature_data)<=350000 and owner_signature_data like 'data:image/png;base64,%')),
  constraint ex_admin_contract_renter_signature_chk check(renter_signature_data is null or (length(renter_signature_data)<=350000 and renter_signature_data like 'data:image/png;base64,%'))
);
alter table public.ex_admin_contracts enable row level security;
revoke all on table public.ex_admin_contracts from anon, authenticated;
grant select on table public.ex_admin_contracts to authenticated;
grant update(owner_signature_data,renter_signature_data) on public.ex_admin_contracts to authenticated;
grant select,insert,update,delete on table public.ex_admin_contracts to service_role;

drop policy if exists "Contract parties can read contracts" on public.ex_admin_contracts;
create policy "Contract parties can read contracts" on public.ex_admin_contracts for select to authenticated
using((select private.is_contract_admin()) and (select auth.uid()) in(owner_admin_id,renter_admin_id));

drop policy if exists "Contract parties can update own signature" on public.ex_admin_contracts;
create policy "Contract parties can update own signature" on public.ex_admin_contracts for update to authenticated
using((select private.is_contract_admin()) and (select auth.uid()) in(owner_admin_id,renter_admin_id))
with check((select private.is_contract_admin()) and (select auth.uid()) in(owner_admin_id,renter_admin_id));

create or replace function private.enforce_contract_signature_update()
returns trigger language plpgsql set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());
begin
  if not private.is_contract_admin() then raise exception 'CONTRACT_ADMIN_REQUIRED'; end if;
  if old.owner_signature_data is not null and old.renter_signature_data is not null then raise exception 'CONTRACT_LOCKED'; end if;
  if row(new.id,new.contract_number,new.title,new.website_name,new.monthly_rent,new.currency,new.starts_at,new.ends_at,new.owner_admin_id,new.renter_admin_id,new.owner_full_name,new.renter_full_name,new.terms,new.created_at)
     is distinct from
     row(old.id,old.contract_number,old.title,old.website_name,old.monthly_rent,old.currency,old.starts_at,old.ends_at,old.owner_admin_id,old.renter_admin_id,old.owner_full_name,old.renter_full_name,old.terms,old.created_at)
  then raise exception 'CONTRACT_FIELDS_IMMUTABLE'; end if;
  if v_uid=old.owner_admin_id then
    if new.renter_signature_data is distinct from old.renter_signature_data then raise exception 'CANNOT_SIGN_FOR_OTHER_PARTY'; end if;
    if new.owner_signature_data is distinct from old.owner_signature_data then
      if new.owner_signature_data is not null and (length(new.owner_signature_data)>350000 or new.owner_signature_data not like 'data:image/png;base64,%') then raise exception 'INVALID_SIGNATURE'; end if;
      new.owner_signed_at:=case when new.owner_signature_data is null then null else now() end;
    else new.owner_signed_at:=old.owner_signed_at; end if;
    new.renter_signed_at:=old.renter_signed_at;
  elsif v_uid=old.renter_admin_id then
    if new.owner_signature_data is distinct from old.owner_signature_data then raise exception 'CANNOT_SIGN_FOR_OTHER_PARTY'; end if;
    if new.renter_signature_data is distinct from old.renter_signature_data then
      if new.renter_signature_data is not null and (length(new.renter_signature_data)>350000 or new.renter_signature_data not like 'data:image/png;base64,%') then raise exception 'INVALID_SIGNATURE'; end if;
      new.renter_signed_at:=case when new.renter_signature_data is null then null else now() end;
    else new.renter_signed_at:=old.renter_signed_at; end if;
    new.owner_signed_at:=old.owner_signed_at;
  else raise exception 'NOT_A_CONTRACT_PARTY';
  end if;
  new.updated_at:=now();
  return new;
end;
$$;
revoke all on function private.enforce_contract_signature_update() from public,anon,authenticated;
drop trigger if exists trg_ex_admin_contract_signature_guard on public.ex_admin_contracts;
create trigger trg_ex_admin_contract_signature_guard before update on public.ex_admin_contracts
for each row execute function private.enforce_contract_signature_update();

update public.ex_profiles set full_name='ڕێکار ئازاد پیرداود'
where id='d4dc75d5-bc92-4bfc-8b5f-ec14a5c805ad'::uuid;
update public.ex_profiles set full_name='ژەنیار ژاکۆ عثمان'
where id='92651f70-2d25-4712-9f8d-cb6707efacbc'::uuid;

insert into public.ex_admin_contracts(contract_number,title,website_name,monthly_rent,currency,starts_at,ends_at,owner_admin_id,renter_admin_id,owner_full_name,renter_full_name,terms)
values(
 'PB-2026-10-08-001','گرێبەستی بەکرێدانی ماڵپەڕ','پڕۆکسۆ باڵانس',50000,'IQD',
 '2026-10-08 00:42:00+03','2026-11-08 00:42:00+03',
 'd4dc75d5-bc92-4bfc-8b5f-ec14a5c805ad','92651f70-2d25-4712-9f8d-cb6707efacbc',
 'ڕێکار ئازاد پیرداود','ژەنیار ژاکۆ عثمان',
 jsonb_build_array(
  'ئەم گرێبەستە تایبەتە بە بەکرێدانی بەکارهێنانی ماڵپەڕی «پڕۆکسۆ باڵانس» بۆ ماوەی یەک مانگ.',
  'ماوەی گرێبەست لە 08/10/2026 کاتژمێر 00:42 دەست پێ دەکات و لە 08/11/2026 کاتژمێر 00:42 کۆتایی دێت.',
  'کرێی ئەم ماوەیە 50,000 دیناری عێراقییە. نوێکردنەوەی گرێبەست پێویستی بە ڕێککەوتنی نوێی هەردوو لایەن هەیە.',
  'ماف و خاوەندارێتی ناوی ماڵپەڕ، دۆمەین، کۆد، داتابەیس و هەژمارە سەرەکییەکان لە لای خاوەنەکە دەمێنێتەوە، مەگەر بە نووسین بە شێوەیەکی تر ڕێککەوتبێت.',
  'بەکرێگر مافی فرۆشتن، گواستنەوە، سپاردنی دەستڕاگەیشتن یان گۆڕینی زانیارییە گرنگەکانی خاوەندارێتی بە کەسێکی سێیەم نییە بێ ڕەزامەندی نووسراوی خاوەن.',
  'بەکرێگر بەرپرسی بەکارهێنانی یاسایی و پاراستنی وشەی نهێنی و دەستڕاگەیشتنەکانی خۆیە.',
  'هەر گۆڕانکارییەکی مەترسیدار لە سیستەم، داتابەیس یان ڕێکخستنە سەرەکییەکان پێویستی بە ئاگادارکردنەوە و ڕەزامەندی خاوەن هەیە.',
  'لە کۆتایی ماوەکەدا، ئەگەر گرێبەست نوێ نەکرێتەوە، دەستڕاگەیشتنی بەکرێگر دەتوانرێت لەلایەن خاوەنەوە کۆتایی پێ بێت.',
  'واژووی هەر لایەن لەم بەڵگەنامەیە واتای پەسەندکردنی ناوەڕۆک و خاڵەکانی سەرەوەیە.',
  'ئەم گرێبەستە خۆی بەڵگەی پارەدان نییە؛ تۆماری پارەدان، ئەگەر هەبێت، بەڵگەی جیاوازە.'
 )
)
on conflict(contract_number) do nothing;
