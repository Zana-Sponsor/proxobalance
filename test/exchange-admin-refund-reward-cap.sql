-- Run after SUPABASE_EXCHANGE_ADMIN_REFUND_REWARD_CAP.sql as a trusted backend.
-- Every synthetic user, order, reward and ledger entry is rolled back.
begin;
set local request.jwt.claim.role = 'service_role';
do $test$
declare
  v_admin uuid := gen_random_uuid();
  v_user uuid := gen_random_uuid();
  v_reward uuid;
  v_route text := 'cap-test-' || gen_random_uuid()::text;
  v_ref text := 'refund-test-' || gen_random_uuid()::text;
  v_first public.ex_orders%rowtype;
  v_second public.ex_orders%rowtype;
  v_third public.ex_orders%rowtype;
  v_proof public.ex_orders%rowtype;
  v_case public.ex_refund_cases%rowtype;
  v_retry public.ex_refund_cases%rowtype;
  v_quote jsonb;
  v_input jsonb;
  v_role text;
begin
  -- Shared golden examples for database and browser decimal arithmetic.
  for v_input in select value from jsonb_array_elements('[
    [60000,"fee_percent",2,"free_transactions",100,50000,59800,200,1000],
    [50000,"fee_percent",2,"free_transactions",100,50000,50000,0,1000],
    [49999,"fee_percent",2,"free_transactions",100,50000,49999,0,1000],
    [50001,"fee_percent",2,"free_transactions",100,50000,50000,1,1000],
    [60000,"fee_percent",2.2,"free_transactions",100,50000,59780,220,1100],
    [60000,"multiplier",0.86,"free_transactions",100,50000,58600,1400,7000],
    [60000,"fee_percent",2,"fee_discount",50,50000,59300,700,500],
    [60000,"fee_percent",2,"free_transactions",100,null,60000,0,1200],
    [60000,"fee_fixed",1000,"free_transactions",100,50000,59000,1000,0],
    [50000,"fee_fixed",1000,"free_transactions",100,50000,50000,0,1000],
    [60000,"fee_fixed",123.5,"free_transactions",100,50000,59876,124,0],
    [60000.5,"fee_percent",2,"free_transactions",100,50000,59800,200.5,1000],
    [60000,"fee_percent",2,null,null,null,58800,1200,0]
  ]'::jsonb) loop
    v_quote := public.ex_reward_quote((v_input->>0)::numeric,v_input->>1,
      (v_input->>2)::numeric,v_input->>3,(v_input->>4)::numeric,(v_input->>5)::bigint);
    if (v_quote->>'total')::numeric is distinct from (v_input->>6)::numeric
       or (v_quote->>'fee')::numeric is distinct from (v_input->>7)::numeric
       or (v_quote->>'discount_iqd')::numeric is distinct from (v_input->>8)::numeric then
      raise exception 'Database pricing golden example failed: % / %', v_input, v_quote;
    end if;
  end loop;
  foreach v_role in array array['anon','authenticated'] loop
    if has_function_privilege(v_role,
      'public.ex_admin_reject_and_refund(uuid,uuid,text,text,boolean)','EXECUTE')
       or has_function_privilege(v_role,
      'public.ex_balance_credit_refund(uuid,uuid,text,text,boolean,boolean)','EXECUTE') then
      raise exception 'Untrusted role can credit a balance: %',v_role;
    end if;
    if has_any_column_privilege(v_role,'public.ex_orders','INSERT')
       or has_column_privilege(v_role,'public.ex_orders','reward_cap_iqd','UPDATE') then
      raise exception 'Untrusted role can forge order pricing: %',v_role;
    end if;
  end loop;
  if not has_function_privilege('service_role',
    'public.ex_admin_reject_and_refund(uuid,uuid,text,text,boolean)','EXECUTE') then
    raise exception 'Trusted server cannot issue manual refunds';
  end if;

  insert into auth.users(id,email,raw_user_meta_data) values
    (v_admin,'cap-admin-'||v_admin||'@example.invalid','{"full_name":"Regression Admin"}'),
    (v_user,'cap-user-'||v_user||'@example.invalid','{"full_name":"Regression Customer"}');
  update public.ex_profiles set is_admin=true where id=v_admin;
  -- Welcome grants are tested separately; these fixtures exercise admin grants.
  update public.ex_user_rewards set active=false where user_id in(v_user,v_admin) and campaign_key='welcome_signup_v1';
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value)
    values(v_route,v_route||'-destination','fee_percent',2);
  insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,
    max_amount_iqd,created_by) values(v_user,'free_transactions',100,2,50000,v_admin)
    returning id into v_reward;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,fee,phone,
    receipt_url,receipt_hash,reward_discount_iqd,reward_covered_amount_iqd,reward_cap_iqd)
    values(v_user,v_route,v_route||'-destination',60000,999999,0,'07700000001',
      'https://example.invalid/first.png',md5(v_route||'1')||md5(v_route||'a'),
      999999,60000,999999) returning * into v_first;
  if v_first.total<>59800 or v_first.fee<>200 or v_first.reward_id<>v_reward
     or v_first.reward_covered_amount_iqd<>50000 or v_first.reward_cap_iqd<>50000
     or v_first.reward_discount_iqd<>1000 then
    raise exception 'Authoritative insert pricing/cap snapshots failed';
  end if;
  if not exists(select 1 from public.ex_reward_usages where order_id=v_first.id
      and covered_amount_iqd=50000 and amount_cap_iqd=50000 and discount_iqd=1000)
     or (select used_count from public.ex_user_rewards where id=v_reward)<>1 then
    raise exception 'Reward usage snapshots or quota failed';
  end if;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,
    receipt_url,receipt_hash) values(v_user,v_route,v_route||'-destination',50000,0,
    '07700000002','https://example.invalid/second.png',md5(v_route||'2')||md5(v_route||'b'))
    returning * into v_second;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,
    receipt_url,receipt_hash) values(v_user,v_route,v_route||'-destination',60000,0,
    '07700000003','https://example.invalid/third.png',md5(v_route||'3')||md5(v_route||'c'))
    returning * into v_third;
  if v_second.fee<>0 or v_second.total<>50000 or v_third.fee<>1200
     or v_third.reward_id is not null
     or (select used_count from public.ex_user_rewards where id=v_reward)<>2 then
    raise exception 'Two-use reward or exhausted quota failed';
  end if;
  if exists(select 1 from public.ex_customer_balances where user_id=v_user) then
    raise exception 'Order insertion automatically credited a balance';
  end if;
  begin
    perform public.ex_admin_reject_and_refund(v_first.id,v_user,v_ref,
      'An ordinary user must not refund',true);
    raise exception 'Non-admin refund was allowed';
  exception when insufficient_privilege then null;end;
  begin
    perform public.ex_admin_reject_and_refund(v_first.id,v_admin,v_ref,
      'Funds must be independently verified',false);
    raise exception 'Refund without received funds was allowed';
  exception when invalid_parameter_value then null;end;

  -- Pending order: explicit admin decision, with no failed-payout precondition.
  v_case := public.ex_admin_reject_and_refund(v_first.id,v_admin,v_ref,
    'Admin chose to reject this received transfer',true);
  select * into v_first from public.ex_orders where id=v_first.id;
  if v_case.refund_kind<>'admin_rejection' or v_case.confirmed_payout_failed
     or not v_case.confirmed_funds_received or v_case.amount_iqd<>60000
     or v_first.status<>'ڕەتکرا' or v_first.balance_refund_case_id<>v_case.id
     or v_first.balance_refunded_at is null
     or (select available_iqd from public.ex_customer_balances where user_id=v_user)<>60000
     or (select used_count from public.ex_user_rewards where id=v_reward)<>1 then
    raise exception 'Manual full-amount refund or one-time quota restoration failed';
  end if;
  if (select sum(delta_iqd) from public.ex_balance_entries where journal_id=v_case.journal_id)<>0
     or (select count(*) from public.ex_balance_entries where journal_id=v_case.journal_id)<>2
     or not exists(select 1 from public.ex_admin_audit_log
       where admin_id=v_admin and action='balance_admin_rejection_refund') then
    raise exception 'Balanced immutable journal or admin audit missing';
  end if;
  v_retry := public.ex_admin_reject_and_refund(v_first.id,v_admin,v_ref,
    'Admin retries the same received transfer',true);
  if v_retry.id<>v_case.id
     or (select count(*) from public.ex_balance_journal where user_id=v_user)<>1
     or (select available_iqd from public.ex_customer_balances where user_id=v_user)<>60000
     or (select used_count from public.ex_user_rewards where id=v_reward)<>1 then
    raise exception 'Duplicate refund credited twice or restored quota twice';
  end if;

  -- Duplicate settlement evidence must roll back rejection, quota and credit.
  begin
    perform public.ex_admin_reject_and_refund(v_second.id,v_admin,v_ref,
      'A duplicate settlement reference must be refused',true);
    raise exception 'Duplicate settlement reference was allowed';
  exception when unique_violation then null;end;
  if (select status from public.ex_orders where id=v_second.id)<>'چاوەڕوانە'
     or (select available_iqd from public.ex_customer_balances where user_id=v_user)<>60000
     or (select used_count from public.ex_user_rewards where id=v_reward)<>1
     or exists(select 1 from public.ex_reward_usages where order_id=v_second.id and reversed_at is not null)
     or exists(select 1 from public.ex_refund_cases where order_id=v_second.id) then
    raise exception 'Failed refund left partial financial changes';
  end if;
  update public.ex_orders set status='ڕەتکرا' where id=v_second.id;
  if (select available_iqd from public.ex_customer_balances where user_id=v_user)<>60000
     or exists(select 1 from public.ex_refund_cases where order_id=v_second.id) then
    raise exception 'Ordinary rejection automatically refunded';
  end if;
  update public.ex_orders set status='پەسەندکرا' where id=v_third.id;
  begin
    perform public.ex_admin_reject_and_refund(v_third.id,v_admin,v_ref||'-approved',
      'An approved order must not be credited',true);
    raise exception 'Approved order was refunded';
  exception when invalid_parameter_value then null;end;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(v_user,v_route,v_route||'-destination',60000,0,'07700000004',
      'https://example.invalid/proof.png') returning * into v_proof;
  update public.ex_orders set payout_receipt_url='https://example.invalid/paid.png' where id=v_proof.id;
  begin
    perform public.ex_admin_reject_and_refund(v_proof.id,v_admin,v_ref||'-proof',
      'An order with payout proof must not be credited',true);
    raise exception 'Order with payout proof was refunded';
  exception when invalid_parameter_value then null;end;
end
$test$;
rollback;
select 'PASS: cap pricing, admin-only manual refund, atomic rollback and idempotency; fixtures rolled back' as result;
