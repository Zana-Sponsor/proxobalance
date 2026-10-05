-- Proxo Balance Exchange: per-customer fee rewards.
-- Additive migration: no existing customer receives a reward until an admin grants it.
create table if not exists public.ex_user_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  kind text not null check (kind in ('free_transactions','fee_discount')),
  discount_percent numeric(5,2) not null check (discount_percent > 0 and discount_percent <= 100),
  max_uses integer check (max_uses is null or max_uses > 0),
  used_count integer not null default 0 check (used_count >= 0),
  valid_until timestamptz,
  active boolean not null default true,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ex_reward_free_exact check (kind <> 'free_transactions' or (discount_percent = 100 and max_uses is not null)),
  constraint ex_reward_remaining check (max_uses is null or used_count <= max_uses)
);
create index if not exists ex_user_rewards_eligible_idx on public.ex_user_rewards(user_id,active,valid_until,created_at);
alter table public.ex_user_rewards enable row level security;
drop policy if exists ex_rewards_read_own on public.ex_user_rewards;
create policy ex_rewards_read_own on public.ex_user_rewards
  for select to authenticated using ((select auth.uid()) = user_id);
revoke all on table public.ex_user_rewards from anon, authenticated;
grant select on table public.ex_user_rewards to authenticated;
grant all on table public.ex_user_rewards to service_role;

alter table public.ex_orders
  add column if not exists reward_id uuid references public.ex_user_rewards(id) on delete restrict,
  add column if not exists reward_discount_iqd numeric not null default 0,
  add column if not exists reward_original_fee_iqd numeric;

create table if not exists public.ex_reward_usages (
  id uuid primary key default gen_random_uuid(),
  reward_id uuid not null references public.ex_user_rewards(id) on delete restrict,
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  order_id uuid not null unique references public.ex_orders(id) on delete restrict,
  original_fee_iqd numeric not null check (original_fee_iqd >= 0),
  discount_iqd numeric not null check (discount_iqd > 0),
  created_at timestamptz not null default now(),
  reversed_at timestamptz
);
create index if not exists ex_reward_usages_reward_idx on public.ex_reward_usages(reward_id, created_at);
alter table public.ex_reward_usages enable row level security;
drop policy if exists ex_reward_usages_read_own on public.ex_reward_usages;
create policy ex_reward_usages_read_own on public.ex_reward_usages
  for select to authenticated using ((select auth.uid()) = user_id);
revoke all on table public.ex_reward_usages from anon,authenticated;
grant select on table public.ex_reward_usages to authenticated;
grant all on table public.ex_reward_usages to service_role;

-- All financial math and quota consumption happen inside the order INSERT
-- transaction. FOR UPDATE serializes simultaneous requests for the last use.
create or replace function public.ex_rewards_apply_on_order()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
declare v_reward public.ex_user_rewards%rowtype;
  v_fee numeric;
  v_discount numeric;
begin
  -- Never accept a caller-supplied reward, discount or fee snapshot.
  new.reward_id := null;
  new.reward_discount_iqd := 0;
  new.reward_original_fee_iqd := null;
  -- USDT transfers change currency; IQD amounts cannot be subtracted.
  if new.from_method = 'USDT' or new.to_method = 'USDT' then return new; end if;
  v_fee := greatest(new.amount - new.total, 0);
  if v_fee <= 0 then return new; end if;
  select * into v_reward from public.ex_user_rewards
   where user_id = new.user_id and active = true
     and (valid_until is null or valid_until > now())
     and (max_uses is null or used_count < max_uses)
   order by valid_until asc nulls last,
      case when kind='free_transactions' then 0 else 1 end,
      created_at asc, id asc
   limit 1 for update;
  if not found then return new; end if;
  v_discount := case when v_reward.kind='free_transactions' then v_fee
                     else floor(v_fee * v_reward.discount_percent / 100) end;
  v_discount := least(v_fee, greatest(v_discount, 0));
  if v_discount <= 0 then return new; end if;
  update public.ex_user_rewards
    set used_count=used_count+1,updated_at=now() where id=v_reward.id;
  new.reward_id := v_reward.id;
  new.reward_discount_iqd := v_discount;
  new.reward_original_fee_iqd := v_fee;
  new.total := new.total + v_discount;
  new.fee := greatest(new.amount - new.total,0);
  return new;
end
$fn$;
revoke all on function public.ex_rewards_apply_on_order() from public, anon, authenticated;

create or replace function public.ex_rewards_record_order()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
begin
  if new.reward_id is not null and new.reward_discount_iqd > 0 then
    insert into public.ex_reward_usages(reward_id,user_id,order_id,original_fee_iqd,discount_iqd)
    values(new.reward_id,new.user_id,new.id,new.reward_original_fee_iqd,new.reward_discount_iqd);
  end if;
  return null;
end
$fn$;
revoke all on function public.ex_rewards_record_order() from public,anon,authenticated;

create or replace function public.ex_rewards_restore_on_rejection()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
declare v_reward_id uuid;
begin
  if old.status is distinct from 'ڕەتکرا' and new.status = 'ڕەتکرا'
     and old.reward_id is not null then
    update public.ex_reward_usages
       set reversed_at=now()
     where order_id=old.id and reversed_at is null
     returning reward_id into v_reward_id;
    if v_reward_id is not null then
      update public.ex_user_rewards set used_count=greatest(used_count-1,0),
        updated_at=now() where id=v_reward_id;
    end if;
  end if;
  return null;
end
$fn$;
revoke all on function public.ex_rewards_restore_on_rejection() from public,anon,authenticated;

drop trigger if exists trg_ex_orders_zz_reward on public.ex_orders;
create trigger trg_ex_orders_zz_reward before insert on public.ex_orders
  for each row execute function public.ex_rewards_apply_on_order();
drop trigger if exists trg_ex_orders_reward_usage on public.ex_orders;
create trigger trg_ex_orders_reward_usage after insert on public.ex_orders
  for each row execute function public.ex_rewards_record_order();
drop trigger if exists trg_ex_orders_reward_restore on public.ex_orders;
create trigger trg_ex_orders_reward_restore after update of status on public.ex_orders
  for each row execute function public.ex_rewards_restore_on_rejection();
