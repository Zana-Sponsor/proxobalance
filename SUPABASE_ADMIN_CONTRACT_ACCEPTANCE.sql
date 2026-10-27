-- Proxo Balance contract acceptance and super-admin management.
-- Apply after SUPABASE_ADMIN_CONTRACTS.sql.

create or replace function private.is_contract_super_admin()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(
    select 1
    from public.ex_profiles p
    where p.id=(select auth.uid())
      and p.is_admin=true
      and coalesce(p.is_banned,false)=false
      and p.role='super_admin'
  );
$$;
revoke all on function private.is_contract_super_admin() from public,anon;
grant execute on function private.is_contract_super_admin() to authenticated;

alter table public.ex_admin_contracts
  add column if not exists owner_accepted_name text,
  add column if not exists owner_terms_accepted boolean not null default false,
  add column if not exists owner_terms_accepted_at timestamptz,
  add column if not exists renter_accepted_name text,
  add column if not exists renter_terms_accepted boolean not null default false,
  add column if not exists renter_terms_accepted_at timestamptz,
  add column if not exists completed_at timestamptz;

revoke update on public.ex_admin_contracts from authenticated;
grant select,insert,update on public.ex_admin_contracts to authenticated;

drop policy if exists "Contract parties can read contracts" on public.ex_admin_contracts;
drop policy if exists "Contract parties can update own signature" on public.ex_admin_contracts;
drop policy if exists "Contract admins can read contracts" on public.ex_admin_contracts;
drop policy if exists "Super admin can create contracts" on public.ex_admin_contracts;
drop policy if exists "Contract parties or super admin can update contracts" on public.ex_admin_contracts;

create policy "Contract admins can read contracts"
on public.ex_admin_contracts for select to authenticated
using(
  (select private.is_contract_super_admin())
  or ((select private.is_contract_admin()) and (select auth.uid()) in(owner_admin_id,renter_admin_id))
);

create policy "Super admin can create contracts"
on public.ex_admin_contracts for insert to authenticated
with check((select private.is_contract_super_admin()));

create policy "Contract parties or super admin can update contracts"
on public.ex_admin_contracts for update to authenticated
using(
  (select private.is_contract_super_admin())
  or ((select private.is_contract_admin()) and (select auth.uid()) in(owner_admin_id,renter_admin_id))
)
with check(
  (select private.is_contract_super_admin())
  or ((select private.is_contract_admin()) and (select auth.uid()) in(owner_admin_id,renter_admin_id))
);

create or replace function private.enforce_contract_write()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_super boolean := private.is_contract_super_admin();
  v_owner_name text;
  v_renter_name text;
  v_core_changed boolean := false;
  v_owner_changed boolean := false;
  v_renter_changed boolean := false;
begin
  select nullif(btrim(p.full_name),'') into v_owner_name
    from public.ex_profiles p
   where p.id=new.owner_admin_id and p.is_admin=true and coalesce(p.is_banned,false)=false;
  select nullif(btrim(p.full_name),'') into v_renter_name
    from public.ex_profiles p
   where p.id=new.renter_admin_id and p.is_admin=true and coalesce(p.is_banned,false)=false;

  if v_owner_name is null or v_renter_name is null then raise exception 'CONTRACT_PARTY_ADMIN_INVALID'; end if;
  if new.owner_admin_id=new.renter_admin_id then raise exception 'CONTRACT_PARTIES_MUST_DIFFER'; end if;

  if tg_op='INSERT' then
    if not v_super then raise exception 'SUPER_ADMIN_REQUIRED'; end if;
    new.owner_full_name:=v_owner_name; new.renter_full_name:=v_renter_name;
    new.owner_signature_data:=null; new.owner_signed_at:=null; new.owner_accepted_name:=null;
    new.owner_terms_accepted:=false; new.owner_terms_accepted_at:=null;
    new.renter_signature_data:=null; new.renter_signed_at:=null; new.renter_accepted_name:=null;
    new.renter_terms_accepted:=false; new.renter_terms_accepted_at:=null;
    new.completed_at:=null; new.created_at:=coalesce(new.created_at,now()); new.updated_at:=now();
    return new;
  end if;

  v_core_changed :=
    row(new.contract_number,new.title,new.website_name,new.monthly_rent,new.currency,
        new.starts_at,new.ends_at,new.owner_admin_id,new.renter_admin_id,new.terms)
    is distinct from
    row(old.contract_number,old.title,old.website_name,old.monthly_rent,old.currency,
        old.starts_at,old.ends_at,old.owner_admin_id,old.renter_admin_id,old.terms);

  if v_core_changed
     or new.owner_full_name is distinct from old.owner_full_name
     or new.renter_full_name is distinct from old.renter_full_name then
    if not v_super then raise exception 'SUPER_ADMIN_REQUIRED'; end if;
    new.owner_full_name:=v_owner_name; new.renter_full_name:=v_renter_name;
    new.owner_signature_data:=null; new.owner_signed_at:=null; new.owner_accepted_name:=null;
    new.owner_terms_accepted:=false; new.owner_terms_accepted_at:=null;
    new.renter_signature_data:=null; new.renter_signed_at:=null; new.renter_accepted_name:=null;
    new.renter_terms_accepted:=false; new.renter_terms_accepted_at:=null;
    new.completed_at:=null; new.created_at:=old.created_at; new.updated_at:=now();
    return new;
  end if;

  v_owner_changed :=
    new.owner_signature_data is distinct from old.owner_signature_data
    or new.owner_accepted_name is distinct from old.owner_accepted_name
    or new.owner_terms_accepted is distinct from old.owner_terms_accepted;
  v_renter_changed :=
    new.renter_signature_data is distinct from old.renter_signature_data
    or new.renter_accepted_name is distinct from old.renter_accepted_name
    or new.renter_terms_accepted is distinct from old.renter_terms_accepted;

  if v_uid=old.owner_admin_id then
    if v_renter_changed
       or new.renter_signed_at is distinct from old.renter_signed_at
       or new.renter_terms_accepted_at is distinct from old.renter_terms_accepted_at then
      raise exception 'CANNOT_SIGN_FOR_OTHER_PARTY';
    end if;
    if old.owner_terms_accepted then
      if v_owner_changed then raise exception 'PARTY_ALREADY_ACCEPTED'; end if;
    elsif v_owner_changed then
      if not coalesce(new.owner_terms_accepted,false) then raise exception 'TERMS_ACCEPTANCE_REQUIRED'; end if;
      if new.owner_signature_data is null
         or length(new.owner_signature_data)>350000
         or new.owner_signature_data not like 'data:image/png;base64,%' then raise exception 'INVALID_SIGNATURE'; end if;
      if lower(regexp_replace(btrim(coalesce(new.owner_accepted_name,'')),'[[:space:]]+',' ','g'))
         <> lower(regexp_replace(btrim(v_owner_name),'[[:space:]]+',' ','g')) then raise exception 'SIGNER_NAME_MISMATCH'; end if;
      new.owner_accepted_name:=v_owner_name;
      new.owner_signed_at:=coalesce(old.owner_signed_at,now());
      new.owner_terms_accepted_at:=now();
    else
      new.owner_signature_data:=old.owner_signature_data; new.owner_accepted_name:=old.owner_accepted_name;
      new.owner_terms_accepted:=old.owner_terms_accepted; new.owner_signed_at:=old.owner_signed_at;
      new.owner_terms_accepted_at:=old.owner_terms_accepted_at;
    end if;
    new.renter_signature_data:=old.renter_signature_data; new.renter_accepted_name:=old.renter_accepted_name;
    new.renter_terms_accepted:=old.renter_terms_accepted; new.renter_signed_at:=old.renter_signed_at;
    new.renter_terms_accepted_at:=old.renter_terms_accepted_at;

  elsif v_uid=old.renter_admin_id then
    if v_owner_changed
       or new.owner_signed_at is distinct from old.owner_signed_at
       or new.owner_terms_accepted_at is distinct from old.owner_terms_accepted_at then
      raise exception 'CANNOT_SIGN_FOR_OTHER_PARTY';
    end if;
    if old.renter_terms_accepted then
      if v_renter_changed then raise exception 'PARTY_ALREADY_ACCEPTED'; end if;
    elsif v_renter_changed then
      if not coalesce(new.renter_terms_accepted,false) then raise exception 'TERMS_ACCEPTANCE_REQUIRED'; end if;
      if new.renter_signature_data is null
         or length(new.renter_signature_data)>350000
         or new.renter_signature_data not like 'data:image/png;base64,%' then raise exception 'INVALID_SIGNATURE'; end if;
      if lower(regexp_replace(btrim(coalesce(new.renter_accepted_name,'')),'[[:space:]]+',' ','g'))
         <> lower(regexp_replace(btrim(v_renter_name),'[[:space:]]+',' ','g')) then raise exception 'SIGNER_NAME_MISMATCH'; end if;
      new.renter_accepted_name:=v_renter_name;
      new.renter_signed_at:=coalesce(old.renter_signed_at,now());
      new.renter_terms_accepted_at:=now();
    else
      new.renter_signature_data:=old.renter_signature_data; new.renter_accepted_name:=old.renter_accepted_name;
      new.renter_terms_accepted:=old.renter_terms_accepted; new.renter_signed_at:=old.renter_signed_at;
      new.renter_terms_accepted_at:=old.renter_terms_accepted_at;
    end if;
    new.owner_signature_data:=old.owner_signature_data; new.owner_accepted_name:=old.owner_accepted_name;
    new.owner_terms_accepted:=old.owner_terms_accepted; new.owner_signed_at:=old.owner_signed_at;
    new.owner_terms_accepted_at:=old.owner_terms_accepted_at;
  else
    raise exception 'NOT_A_CONTRACT_PARTY';
  end if;

  new.owner_full_name:=old.owner_full_name; new.renter_full_name:=old.renter_full_name;
  new.created_at:=old.created_at; new.updated_at:=now();
  if new.owner_terms_accepted and new.renter_terms_accepted
     and new.owner_signature_data is not null and new.renter_signature_data is not null then
    new.completed_at:=coalesce(old.completed_at,now());
  else new.completed_at:=null;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_contract_write() from public,anon,authenticated;

drop trigger if exists trg_ex_admin_contract_signature_guard on public.ex_admin_contracts;
drop trigger if exists trg_ex_admin_contract_write_guard on public.ex_admin_contracts;
create trigger trg_ex_admin_contract_write_guard
before insert or update on public.ex_admin_contracts
for each row execute function private.enforce_contract_write();
