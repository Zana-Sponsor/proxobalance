-- Entire fixture is rolled back; no real customer funds are used.
begin;
set local request.jwt.claim.role='service_role';
do $test$
declare u uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();
 o public.ex_orders%rowtype;r public.ex_orders%rowtype;reward uuid;before_orders bigint;before_journals bigint;
 f public.ex_refund_cases%rowtype;
begin
 insert into auth.users(id,email,raw_user_meta_data) values
 (u,'balance-source-'||u||'@example.invalid','{"full_name":"Balance Source Fixture"}'),
 (a,'balance-source-admin-'||a||'@example.invalid','{"full_name":"Balance Admin Fixture"}');
 update public.ex_profiles set is_admin=true where id=a;
 perform public.ex_balance_post(u,100000,0,'verified_refund','fixture-source:'||u,null,null,a,'Fixture opening funds');
 insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,max_amount_iqd,reward_scope,created_by)
 values(u,'free_transactions',100,1,50000,'wallets',a) returning id into reward;
 o:=public.ex_balance_create_order(u,k,'FastPay',60000,'07700000001');
 if o.total<>59800 or o.fee<>200 or o.balance_debit_journal_id is null or o.receipt_url is not null
  or (select available_iqd from public.ex_customer_balances where user_id=u)<>40000 then
  raise exception 'Balance source fee, reward, debit or proof is wrong';end if;
 r:=public.ex_balance_create_order(u,k,'FastPay',60000,'07700000001');
 if r.id<>o.id or (select used_count from public.ex_user_rewards where id=reward)<>1
  or (select available_iqd from public.ex_customer_balances where user_id=u)<>40000 then
  raise exception 'Retry debited or consumed quota twice';end if;
 begin
  perform public.ex_balance_create_order(u,k,'FastPay',10000,'07700000001');
  raise exception 'Changed payload reused request key';
 exception when invalid_parameter_value then null;end;
 r:=public.ex_balance_create_order(u,gen_random_uuid(),'FastPay',10000,'07700000001');
 if r.fee<>200 or r.total<>9800 or r.reward_id is not null then
  raise exception 'Exhausted reward did not restore normal 2 percent fee';end if;
 update public.ex_orders set status='ڕەتکرا' where id=r.id;
 if (select available_iqd from public.ex_customer_balances where user_id=u)<>30000 then
  raise exception 'Ordinary rejection credited balance automatically';end if;
 select count(*) into before_orders from public.ex_orders;
 select count(*) into before_journals from public.ex_balance_journal;
 begin
  perform public.ex_balance_create_order(u,gen_random_uuid(),'FastPay',40000,'07700000001');
  raise exception 'Insufficient balance was accepted';
 exception when check_violation then null;end;
 if (select count(*) from public.ex_orders)<>before_orders or
  (select count(*) from public.ex_balance_journal)<>before_journals then
  raise exception 'Failed debit left partial order or journal';end if;
 begin
  update public.ex_orders set amount=70000 where id=o.id;
  raise exception 'Debited order amount was mutable';
 exception when check_violation then null;end;
 f:=public.ex_admin_reject_and_refund(o.id,a,'fixture-ref-'||o.id,'Explicit fixture refund requested by admin',true);
 if f.bank_verification_reference<>'balance-debit:'||o.balance_debit_journal_id::text
  or (select available_iqd from public.ex_customer_balances where user_id=u)<>90000 then
  raise exception 'Manual refund did not verify internal debit';end if;
 perform public.ex_admin_reject_and_refund(o.id,a,'fixture-ref-'||o.id,'Explicit fixture refund requested by admin',true);
 if (select available_iqd from public.ex_customer_balances where user_id=u)<>90000 then
  raise exception 'Retry credited refund twice';end if;
 begin
  perform public.ex_balance_create_order(u,gen_random_uuid(),'FastPay',100000,'07700000001');
  raise exception 'Insufficient balance with reward was accepted';
 exception when check_violation then null;end;
 if (select used_count from public.ex_user_rewards where id=reward)<>0 then
  raise exception 'Failed debit consumed restored reward quota';end if;
 begin
  update public.ex_orders set status='پەسەندکرا' where id=o.id;
  raise exception 'Refunded balance order was approved';
 exception when check_violation then null;end;
 if has_function_privilege('authenticated','public.ex_balance_create_order(uuid,uuid,text,bigint,text,uuid)','execute')
   or has_function_privilege('anon','public.ex_balance_create_order(uuid,uuid,text,bigint,text,uuid)','execute') then
  raise exception 'Balance RPC publicly executable';end if;
 if exists(select 1 from public.ex_balance_journal j join public.ex_balance_entries e on e.journal_id=j.id
  where j.user_id=u group by j.id having sum(e.delta_iqd)<>0) then
  raise exception 'Journal is not double entry';end if;
end $test$;
rollback;
select 'PASS: 2 percent, capped reward exhaustion, atomic debit, retry, manual refund and permissions' as result;
