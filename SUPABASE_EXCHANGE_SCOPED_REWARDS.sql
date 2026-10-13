-- Separate wallet, Korek and Asiacell rewards. No financial credit is created.
-- Existing rewards become wallet-only; historical applied values remain intact.
alter table public.ex_user_rewards add column reward_scope text not null default 'wallets'
  check(reward_scope in ('wallets','korek','asiacell'));
alter table public.ex_orders add column reward_scope text
  check(reward_scope is null or reward_scope in ('wallets','korek','asiacell'));
alter table public.ex_reward_usages add column reward_scope text
  check(reward_scope is null or reward_scope in ('wallets','korek','asiacell'));
comment on column public.ex_user_rewards.reward_scope is
  'Wallet-only, Korek or Asiacell eligibility. Separate scopes never share reward quotas.';

-- Any carrier leg uses a carrier-specific reward, never a wallet-only reward.
-- If both ends are carriers, the sending carrier determines the scope.
create or replace function public.ex_reward_route_scope(p_from text,p_to text)
returns text language sql immutable set search_path='' as $fn$
  select case
    when p_from='USDT' or p_to='USDT' then null
    when p_from='Korek' then 'korek'
    when p_from='Asiacell' then 'asiacell'
    when p_to='Korek' then 'korek'
    when p_to='Asiacell' then 'asiacell'
    else 'wallets'
  end;
$fn$;
revoke all on function public.ex_reward_route_scope(text,text) from public,anon,authenticated;
grant execute on function public.ex_reward_route_scope(text,text) to service_role;

create or replace function public.ex_rewards_apply_on_order()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare v_reward public.ex_user_rewards%rowtype;v_rate public.ex_rates%rowtype;v_quote jsonb;v_scope text;
begin
 new.reward_id:=null;new.reward_discount_iqd:=0;new.reward_original_fee_iqd:=null;
 new.reward_covered_amount_iqd:=null;new.reward_cap_iqd:=null;new.reward_scope:=null;
 if new.from_method='USDT' or new.to_method='USDT' then return new;end if;
 select * into v_rate from public.ex_rates
  where from_method=new.from_method and to_method=new.to_method and is_active
  limit 1 for share;
 if not found then raise exception 'EXCHANGE_RATE_NOT_AVAILABLE' using errcode='22023';end if;
 v_quote:=public.ex_reward_quote(new.amount,v_rate.rate_type,v_rate.rate_value,null,null,null);
 new.total:=(v_quote->>'total')::numeric;new.fee:=(v_quote->>'fee')::numeric;
 if new.fee<=0 then return new;end if;
 v_scope:=public.ex_reward_route_scope(new.from_method,new.to_method);
 select * into v_reward from public.ex_user_rewards
  where user_id=new.user_id and active and reward_scope=v_scope
   and (valid_until is null or valid_until>now())
   and (max_uses is null or used_count<max_uses)
  order by valid_until asc nulls last,
   case when kind='free_transactions' then 0 else 1 end,created_at,id
  limit 1 for update;
 if not found then return new;end if;
 v_quote:=public.ex_reward_quote(new.amount,v_rate.rate_type,v_rate.rate_value,
   v_reward.kind,v_reward.discount_percent,v_reward.max_amount_iqd);
 if (v_quote->>'discount_iqd')::numeric<=0 then return new;end if;
 update public.ex_user_rewards set used_count=used_count+1,updated_at=now() where id=v_reward.id;
 new.reward_id:=v_reward.id;
 new.reward_discount_iqd:=(v_quote->>'discount_iqd')::numeric;
 new.reward_original_fee_iqd:=(v_quote->>'base_fee')::numeric;
 new.reward_covered_amount_iqd:=(v_quote->>'covered_amount_iqd')::numeric;
 new.reward_cap_iqd:=v_reward.max_amount_iqd;new.reward_scope:=v_reward.reward_scope;
 new.total:=(v_quote->>'total')::numeric;new.fee:=(v_quote->>'fee')::numeric;
 return new;
end $fn$;
revoke all on function public.ex_rewards_apply_on_order() from public,anon,authenticated;

create or replace function public.ex_rewards_record_order()
returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 if new.reward_id is not null and new.reward_discount_iqd>0 then
  insert into public.ex_reward_usages(reward_id,user_id,order_id,original_fee_iqd,
    discount_iqd,covered_amount_iqd,amount_cap_iqd,reward_scope)
  values(new.reward_id,new.user_id,new.id,new.reward_original_fee_iqd,
    new.reward_discount_iqd,new.reward_covered_amount_iqd,new.reward_cap_iqd,new.reward_scope);
 end if;
 return null;
end $fn$;
revoke all on function public.ex_rewards_record_order() from public,anon,authenticated;


