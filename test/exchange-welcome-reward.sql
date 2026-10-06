-- Synthetic Auth signups exercise the real trigger and order pipeline.
-- Every fixture and monetary/quota change is rolled back.
begin;
set local request.jwt.claim.role='service_role';
create temporary table welcome_fixture as select
  gen_random_uuid() as u,gen_random_uuid() as other,gen_random_uuid() as expired,
  'welcome-fixture-'||gen_random_uuid()::text as route;
grant select on welcome_fixture to authenticated;
do $test$
declare f record;r public.ex_user_rewards%rowtype;o public.ex_orders%rowtype;
  first_order uuid;before_quota integer;
begin
  select * into f from welcome_fixture;
  insert into auth.users(id,email,created_at,raw_user_meta_data) values
    (f.u,'welcome-'||f.u||'@example.invalid',now(),'{"full_name":"Welcome Customer","discount_percent":100,"max_uses":99,"role":"super_admin"}'),
    (f.other,'welcome-other-'||f.other||'@example.invalid',now(),'{"full_name":"Welcome Other"}'),
    (f.expired,'welcome-expired-'||f.expired||'@example.invalid',now()-interval '8 days','{"full_name":"Expired Customer"}');
  select * into strict r from public.ex_user_rewards where user_id=f.u and campaign_key='welcome_signup_v1';
  if r.kind<>'fee_discount' or r.discount_percent<>50 or r.max_uses<>1
    or r.used_count<>0 or r.max_amount_iqd<>30000 or r.reward_scope<>'wallets'
    or r.valid_until<>r.created_at+interval '7 days' or not r.active then
    raise exception 'New account did not receive exact welcome terms';end if;
  if (select role from public.ex_profiles where id=f.u)<>'user' then
    raise exception 'Signup metadata granted authorization';end if;
  if (select count(*) from public.ex_notifications where reward_id=r.id)<>1
    or not exists(select 1 from public.ex_notifications where reward_id=r.id and title='پاداشتی هەژماری نوێت ئامادەیە') then
    raise exception 'Missing or duplicate welcome notification';end if;
  update auth.users set raw_user_meta_data='{"full_name":"Changed Name"}' where id=f.u;
  insert into public.ex_profiles(id,full_name,email) values(f.u,'Retry','retry@example.invalid') on conflict(id) do nothing;
  if (select count(*) from public.ex_user_rewards where user_id=f.u and campaign_key='welcome_signup_v1')<>1 then
    raise exception 'Profile/auth update granted a second welcome';end if;
  begin
    insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,campaign_key)
      values(f.u,'fee_discount',50,1,'welcome_signup_v1');
    raise exception 'Duplicate campaign accepted';
  exception when unique_violation then null;end;
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value) values
    (f.route,f.route||'-to','fee_percent',2),('Korek',f.route||'-to','fee_percent',20);
  -- Carrier rewards stay separate and never consume the wallet welcome.
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,sender_phone)
    values(f.u,'Korek',f.route||'-to',30000,0,'07700000001','07700000001') returning * into o;
  if o.reward_id is not null or o.fee<>6000 then raise exception 'Welcome leaked into carrier pricing';end if;
  -- A constraint failure after the financial trigger must roll back its quota.
  begin
    insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone)
      values(f.u,f.route,f.route||'-to',30000,0,null);
    raise exception 'Invalid order accepted';
  exception when not_null_violation then null;end;
  if (select used_count from public.ex_user_rewards where id=r.id)<>0 then
    raise exception 'Failed order consumed welcome';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,reward_discount_iqd)
    values(f.u,f.route,f.route||'-to',30000,999999,'07700000001',999999) returning * into o;
  first_order:=o.id;
  if o.reward_id<>r.id or o.fee<>300 or o.total<>29700 or o.reward_discount_iqd<>300
    or o.reward_cap_iqd<>30000 or o.reward_covered_amount_iqd<>30000 then
    raise exception 'First order 30k welcome math/snapshot failed';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone)
    values(f.u,f.route,f.route||'-to',30000,0,'07700000001') returning * into o;
  if o.reward_id is not null or o.fee<>600 or (select used_count from public.ex_user_rewards where id=r.id)<>1 then
    raise exception 'One-use reward applied again';end if;
  update public.ex_orders set status='ڕەتکرا' where id=first_order;
  update public.ex_orders set admin_note='Retry rejection update' where id=first_order;
  if (select used_count from public.ex_user_rewards where id=r.id)<>0 then
    raise exception 'Rejected-order restoration did not run exactly once';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone)
    values(f.other,f.route,f.route||'-to',60000,0,'07700000002') returning * into o;
  if o.fee<>900 or o.total<>59100 or o.reward_discount_iqd<>300
    or o.reward_covered_amount_iqd<>30000 then raise exception 'Uncovered 30k did not pay its normal fee';end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone)
    values(f.expired,f.route,f.route||'-to',30000,0,'07700000003') returning * into o;
  if o.reward_id is not null or o.fee<>600 then raise exception 'Expired welcome still applied';end if;
  if exists(select 1 from public.ex_customer_balances where user_id in(f.u,f.other,f.expired) and available_iqd<>0) then
    raise exception 'Fee welcome credited account money';end if;
  if has_function_privilege('authenticated','public.ex_handle_new_user()','EXECUTE')
    or has_any_column_privilege('authenticated','public.ex_user_rewards','UPDATE')
    or has_any_column_privilege('authenticated','public.ex_user_rewards','INSERT') then
    raise exception 'Customer can grant/change a welcome reward';end if;
end $test$;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select u::text from welcome_fixture),true);
do $rls$
begin
  if (select count(*) from public.ex_user_rewards where campaign_key='welcome_signup_v1')<>1
    or exists(select 1 from public.ex_user_rewards where user_id<>(select u from welcome_fixture)) then
    raise exception 'Customer saw another account welcome';end if;
end $rls$;
reset role;
rollback;
select 'PASS: automatic once-only 50%/30k/7-day reward, server pricing, rejection restoration, expiry and owner-only access; fixtures rolled back' as result;
