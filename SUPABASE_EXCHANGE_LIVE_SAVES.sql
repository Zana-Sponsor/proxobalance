-- Owner-only invalidation signals also cover recipient deletion, without
-- exposing private recipient DELETE payloads through an unfiltered channel.
create table public.ex_customer_feature_changes(
 user_id uuid primary key references auth.users(id) on delete cascade,
 revision bigint not null default 1,
 updated_at timestamptz not null default now()
);
alter table public.ex_customer_feature_changes enable row level security;
revoke all on public.ex_customer_feature_changes from public,anon,authenticated;
grant select on public.ex_customer_feature_changes to authenticated;
grant all on public.ex_customer_feature_changes to service_role;
create policy ex_feature_changes_own_read on public.ex_customer_feature_changes
 for select to authenticated using(user_id=(select auth.uid()));
create function public.ex_customer_features_changed() returns trigger
 language plpgsql security definer set search_path='' as $fn$
declare owner_id uuid;
begin
 owner_id=case when tg_op='DELETE' then old.user_id else new.user_id end;
 if exists(select 1 from auth.users where id=owner_id) then
  insert into public.ex_customer_feature_changes(user_id) values(owner_id)
  on conflict(user_id) do update set revision=public.ex_customer_feature_changes.revision+1,updated_at=now();
 end if;
 return null;
end $fn$;
revoke all on function public.ex_customer_features_changed() from public,anon,authenticated;
create trigger ex_recipients_changed after insert or update or delete on public.ex_saved_recipients
 for each row execute function public.ex_customer_features_changed();
create trigger ex_badge_views_changed after insert on public.ex_wallet_badge_views
 for each row execute function public.ex_customer_features_changed();

-- Preserve RLS on every published table. Only owner-filtered INSERT/UPDATE
-- subscriptions are used for private data.
do $pub$
declare t text;
begin
 foreach t in array array['ex_rates','ex_user_rewards','ex_profiles',
   'ex_customer_feature_changes','ex_customer_balances','ex_payout_requests'] loop
  if not exists(select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
   execute format('alter publication supabase_realtime add table public.%I',t);
  end if;
 end loop;
end $pub$;

-- One transaction saves the wallet and all edited directions. This runs
-- as the authenticated caller; existing wallet/rate RLS still applies.
create function public.ex_staff_save_wallet(p_wallet_id uuid,p_wallet jsonb,p_routes jsonb)
 returns jsonb language plpgsql security invoker set search_path='' as $fn$
declare w public.ex_wallets; old_key text; route jsonb; k text; n text;
begin
 if auth.uid() is null or not public.ex_staff_has('manage_fees') then
  raise exception 'STAFF_PERMISSION_REQUIRED' using errcode='42501';
 end if;
 k=btrim(p_wallet->>'key'); n=btrim(p_wallet->>'name');
 if coalesce(k,'')='' or coalesce(n,'')='' or coalesce(jsonb_typeof(p_routes),'')<>'array' then
  raise exception 'INVALID_WALLET' using errcode='22023';
 end if;
 if p_wallet_id is not null then
  select key into old_key from public.ex_wallets where id=p_wallet_id for update;
  if not found then raise exception 'WALLET_NOT_FOUND' using errcode='P0002';end if;
  if old_key='AccountBalance' and k<>old_key then
   raise exception 'ACCOUNT_BALANCE_KEY_FIXED' using errcode='22023';end if;
  update public.ex_wallets set name=n,key=k,wallet_number=p_wallet->>'wallet_number',
   image_url=p_wallet->>'image_url',price=(p_wallet->>'price')::numeric,
   fee=(p_wallet->>'fee')::numeric,fee_type=p_wallet->>'fee_type',
   allow_from=(p_wallet->>'allow_from')::boolean,allow_receive=(p_wallet->>'allow_receive')::boolean,
   is_locked=(p_wallet->>'is_locked')::boolean,badge=p_wallet->>'badge'
   where id=p_wallet_id returning * into w;
  if not found then raise exception 'WALLET_WRITE_DENIED' using errcode='42501';end if;
 else
  insert into public.ex_wallets(name,key,wallet_number,image_url,price,fee,fee_type,
   allow_from,allow_receive,is_locked,badge,sort_order)
   values(n,k,p_wallet->>'wallet_number',p_wallet->>'image_url',
   (p_wallet->>'price')::numeric,(p_wallet->>'fee')::numeric,p_wallet->>'fee_type',
   (p_wallet->>'allow_from')::boolean,(p_wallet->>'allow_receive')::boolean,
   (p_wallet->>'is_locked')::boolean,p_wallet->>'badge',
   (select coalesce(max(sort_order),0)+1 from public.ex_wallets)) returning * into w;
 end if;
 if old_key is not null and old_key<>k then
  update public.ex_rates set from_method=k where from_method=old_key;
  update public.ex_rates set to_method=k where to_method=old_key;
 end if;
 for route in select value from jsonb_array_elements(p_routes) loop
  if (route->>'from_method') is null or (route->>'to_method') is null
   or (route->>'from_method')=(route->>'to_method')
   or (route->>'from_method'<>k and route->>'to_method'<>k)
   or not exists(select 1 from public.ex_wallets where key=route->>'from_method')
   or not exists(select 1 from public.ex_wallets where key=route->>'to_method')
   or coalesce(route->>'rate_type','') not in ('multiplier','fee_percent','fee_fixed')
   or coalesce(route->>'rate_value','') in ('','NaN','Infinity','-Infinity')
   or (route->>'rate_value')::numeric<0 then
   raise exception 'INVALID_WALLET_ROUTE' using errcode='22023';
  end if;
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value,is_active)
   values(route->>'from_method',route->>'to_method',route->>'rate_type',
   (route->>'rate_value')::numeric,(route->>'is_active')::boolean)
   on conflict(from_method,to_method) do update set
    rate_type=excluded.rate_type,rate_value=excluded.rate_value,is_active=excluded.is_active;
 end loop;
 return to_jsonb(w);
end $fn$;
revoke all on function public.ex_staff_save_wallet(uuid,jsonb,jsonb) from public,anon;
grant execute on function public.ex_staff_save_wallet(uuid,jsonb,jsonb) to authenticated;
