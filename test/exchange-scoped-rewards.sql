-- Synthetic data only: execute after SUPABASE_EXCHANGE_SCOPED_REWARDS.sql.
begin;
set local request.jwt.claim.role='service_role';
do $test$
declare
  u uuid:=gen_random_uuid();a uuid:=gen_random_uuid();
  route text:='scope-fixture-'||gen_random_uuid()::text;
  dest text:=route||'-destination';
  w uuid;k uuid;s uuid;o public.ex_orders%rowtype;
begin
  if public.ex_reward_route_scope('FastPay','FIB')<>'wallets'
     or public.ex_reward_route_scope('Korek','FIB')<>'korek'
     or public.ex_reward_route_scope('Asiacell','FIB')<>'asiacell'
     or public.ex_reward_route_scope('FIB','Korek')<>'korek'
     or public.ex_reward_route_scope('FIB','Asiacell')<>'asiacell'
     or public.ex_reward_route_scope('USDT','Korek') is not null then
    raise exception 'Route scope classification failed';
  end if;
  insert into auth.users(id,email,raw_user_meta_data) values
    (u,'scope-user-'||u||'@example.invalid','{"full_name":"Scope Fixture Customer"}'),
    (a,'scope-admin-'||a||'@example.invalid','{"full_name":"Scope Fixture Admin"}');
  update public.ex_profiles set is_admin=true where id=a;
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value) values
    (route,dest,'fee_percent',2),('Korek',dest,'fee_percent',20),
    ('Asiacell',dest,'multiplier',0.86),(route,'Korek','fee_percent',18);
  insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,max_amount_iqd,created_by)
    values(u,'free_transactions',100,2,50000,a) returning id into w;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,reward_scope)
    values(u,route,dest,60000,0,'07700000001','https://example.invalid/wallet.png','korek') returning * into o;
  if o.reward_id<>w or o.fee<>200 or o.reward_scope<>'wallets' then
    raise exception 'Wallet reward or authoritative scope failed';
  end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,sender_phone)
    values(u,'Korek',dest,60000,0,'07700000001','https://example.invalid/korek-normal.png','07700000001') returning * into o;
  if o.reward_id is not null or o.fee<>12000 then raise exception 'Wallet reward spilled into Korek';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,sender_phone)
    values(u,'Asiacell',dest,60000,0,'07700000001','https://example.invalid/asia-normal.png','07700000001') returning * into o;
  if o.reward_id is not null or o.fee<>8400 then raise exception 'Wallet reward spilled into Asiacell';end if;
  if (select used_count from public.ex_user_rewards where id=w)<>1 then
    raise exception 'Carrier transfer consumed wallet quota';end if;
  insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,max_amount_iqd,reward_scope,created_by)
    values(u,'fee_discount',25,3,40000,'korek',a) returning id into k;
  insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,max_amount_iqd,reward_scope,created_by)
    values(u,'fee_discount',50,3,30000,'asiacell',a) returning id into s;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,sender_phone)
    values(u,'Korek',dest,60000,0,'07700000001','https://example.invalid/korek-discount.png','07700000001') returning * into o;
  if o.reward_id<>k or o.fee<>10000 or o.total<>50000 or o.reward_scope<>'korek'
     or not exists(select 1 from public.ex_reward_usages where order_id=o.id and reward_scope='korek') then
    raise exception 'Independent Korek rate/cap/discount/snapshot failed';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,sender_phone)
    values(u,'Asiacell',dest,60000,0,'07700000001','https://example.invalid/asia-discount.png','07700000001') returning * into o;
  if o.reward_id<>s or o.fee<>6300 or o.total<>53700 or o.reward_scope<>'asiacell' then
    raise exception 'Independent Asiacell multiplier/cap/discount failed';end if;
  update public.ex_orders set status='ڕەتکرا' where id=o.id;
  if (select used_count from public.ex_user_rewards where id=s)<>0
     or (select used_count from public.ex_user_rewards where id=k)<>1
     or (select used_count from public.ex_user_rewards where id=w)<>1 then
    raise exception 'Rejection restored a different reward scope quota';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(u,route,'Korek',60000,0,'07700000001','https://example.invalid/receive-korek.png') returning * into o;
  if o.reward_id<>k or o.fee<>9000 or o.total<>51000 then
    raise exception 'Receiving Korek used wallet reward or wrong route fee';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(u,route,dest,60000,0,'07700000001','https://example.invalid/wallet-second.png') returning * into o;
  if o.reward_id<>w or o.fee<>200 then raise exception 'Wallet quota was altered by carrier orders';end if;
  if has_column_privilege('authenticated','public.ex_user_rewards','reward_scope','UPDATE')
     or has_column_privilege('authenticated','public.ex_orders','reward_scope','UPDATE') then
    raise exception 'Customer can alter applied reward scope';end if;
end
$test$;
rollback;
select 'PASS: separate wallet/Korek/Asiacell pricing, quotas and snapshots; fixtures rolled back' as result;
