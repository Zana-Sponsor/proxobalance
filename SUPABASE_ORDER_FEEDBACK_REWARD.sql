-- Each submitted review for an approved exchange earns one fee discount for a
-- future eligible IQD transaction in the same route scope. The maximum actual
-- discount value is 10,000 IQD (not a cap on principal/amount covered).
alter table public.ex_user_rewards
  add column if not exists max_discount_iqd bigint;

do $migration$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.ex_user_rewards'::regclass
      and conname='ex_user_rewards_discount_amount_cap_check'
  ) then
    alter table public.ex_user_rewards
      add constraint ex_user_rewards_discount_amount_cap_check
      check (max_discount_iqd is null or max_discount_iqd between 1 and 1000000000);
  end if;
end
$migration$;

comment on column public.ex_user_rewards.max_discount_iqd is
  'Maximum actual fee discount value per order in IQD; NULL means no discount-value cap.';

create or replace function public.ex_rewards_apply_on_order()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_reward public.ex_user_rewards%rowtype;
  v_rate public.ex_rates%rowtype;
  v_quote jsonb;
  v_scope text;
  v_discount numeric;
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
   order by case when campaign_key like 'order_feedback_v1:%' then 0 else 1 end,
    valid_until asc nulls last,
    case when kind='free_transactions' then 0 else 1 end,created_at,id
   limit 1 for update;
  if not found then return new;end if;
  v_quote:=public.ex_reward_quote(new.amount,v_rate.rate_type,v_rate.rate_value,
    v_reward.kind,v_reward.discount_percent,v_reward.max_amount_iqd);
  v_discount:=least((v_quote->>'discount_iqd')::numeric,
    coalesce(v_reward.max_discount_iqd,(v_quote->>'base_fee')::numeric));
  if v_discount<=0 then return new;end if;
  update public.ex_user_rewards set used_count=used_count+1,updated_at=now() where id=v_reward.id;
  new.reward_id:=v_reward.id;
  new.reward_discount_iqd:=v_discount;
  new.reward_original_fee_iqd:=(v_quote->>'base_fee')::numeric;
  new.reward_covered_amount_iqd:=(v_quote->>'covered_amount_iqd')::numeric;
  new.reward_cap_iqd:=v_reward.max_amount_iqd;
  new.reward_scope:=v_reward.reward_scope;
  new.total:=(v_quote->>'base_total')::numeric+v_discount;
  new.fee:=greatest((v_quote->>'base_fee')::numeric-v_discount,0);
  return new;
end
$function$;
revoke all on function public.ex_rewards_apply_on_order() from public,anon,authenticated;

create or replace function public.ex_award_order_feedback_reward()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_order record;
  v_scope text;
begin
  select id,user_id,from_method,to_method,order_code,status into v_order
   from public.ex_orders
   where id=new.order_id and user_id=new.user_id
   for share;
  if not found or v_order.status is distinct from 'پەسەندکرا' then
    raise exception 'FEEDBACK_REWARD_REQUIRES_APPROVED_OWN_ORDER' using errcode='42501';
  end if;
  v_scope:=public.ex_reward_route_scope(v_order.from_method,v_order.to_method);
  if v_scope is null then v_scope:='wallets';end if;
  insert into public.ex_user_rewards(
    user_id,kind,discount_percent,max_uses,used_count,valid_until,active,note,
    created_by,max_amount_iqd,max_discount_iqd,reward_scope,campaign_key
  ) values (
    new.user_id,'fee_discount',50,1,0,null,true,
    'Feedback reward for approved order '||coalesce(v_order.order_code,v_order.id::text),
    null,null,10000,v_scope,'order_feedback_v1:'||new.order_id::text
  );
  return new;
end
$function$;
revoke all on function public.ex_award_order_feedback_reward() from public,anon,authenticated;

drop trigger if exists ex_order_feedback_award_reward on public.ex_order_feedback;
create trigger ex_order_feedback_award_reward
after insert on public.ex_order_feedback
for each row execute function public.ex_award_order_feedback_reward();
