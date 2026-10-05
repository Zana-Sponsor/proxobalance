-- Synthetic users only. All fixtures, permission changes and alerts roll back.
begin;
set local request.jwt.claim.role='service_role';
create temporary table feature_fixture as select
 gen_random_uuid() as customer,gen_random_uuid() as other_customer,
 gen_random_uuid() as staff,gen_random_uuid() as super_admin,
 gen_random_uuid() as wallet,gen_random_uuid() as recipient;
grant select on feature_fixture to authenticated;
do $test$
declare f record;r uuid;
begin
 select * into f from feature_fixture;
 insert into auth.users(id,email,raw_user_meta_data) values
 (f.customer,'feature-customer-'||f.customer||'@example.invalid','{"full_name":"Feature Customer"}'),
 (f.other_customer,'feature-other-'||f.other_customer||'@example.invalid','{"full_name":"Other Customer"}'),
 (f.staff,'feature-staff-'||f.staff||'@example.invalid','{"full_name":"Feature Staff"}'),
 (f.super_admin,'feature-super-'||f.super_admin||'@example.invalid','{"full_name":"Feature Super Admin"}');
 update public.ex_profiles set role='super_admin' where id=f.super_admin;
 update public.ex_profiles set role='admin',staff_permissions=array['view'] where id=f.staff;
 insert into public.ex_wallets(id,key,name,allow_from,allow_receive,badge)
  values(f.wallet,'feature-'||f.wallet,'Feature Wallet',true,true,'new');
 insert into public.ex_saved_recipients(id,user_id,label,wallet_key,phone)
  values(f.recipient,f.other_customer,'Other private recipient','FastPay','07700000002');
 insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,used_count,valid_until,created_by)
  values(f.customer,'free_transactions',100,2,1,now()+interval '12 hours',f.super_admin) returning id into r;
 if (select count(*) from public.ex_notifications where reward_id=r and reward_alert_kind is not null)<>2 then
  raise exception 'Missing last-use or expiry reminder';end if;
 perform public.ex_reward_emit_reminders(f.customer);
 perform public.ex_reward_emit_reminders(f.customer);
 if (select count(*) from public.ex_notifications where reward_id=r and reward_alert_kind is not null)<>2 then
  raise exception 'Duplicate reminders';end if;
 insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,used_count,valid_until,created_by)
  values(f.customer,'free_transactions',100,2,2,now()+interval '12 hours',f.super_admin) returning id into r;
 if exists(select 1 from public.ex_notifications where reward_id=r) then raise exception 'Exhausted reward reminder';end if;
 insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,used_count,valid_until,created_by)
  values(f.customer,'free_transactions',100,2,1,now()-interval '1 hour',f.super_admin) returning id into r;
 if exists(select 1 from public.ex_notifications where reward_id=r) then raise exception 'Expired reward reminder';end if;
 if has_function_privilege('authenticated','public.ex_staff_can(uuid,text)','EXECUTE')
   or has_function_privilege('authenticated','public.ex_reward_emit_reminders(uuid)','EXECUTE')
   or has_table_privilege('anon','public.ex_saved_recipients','SELECT')
   or has_table_privilege('authenticated','public.ex_wallet_badge_views','DELETE') then
  raise exception 'Privileged function/table is exposed';end if;
end $test$;
set local role authenticated;
set local request.jwt.claim.role='authenticated';
select set_config('request.jwt.claim.sub',(select customer::text from feature_fixture),true);
do $test$
declare f record;v uuid;
begin
 select * into f from feature_fixture;
 if exists(select 1 from public.ex_saved_recipients where user_id=f.other_customer) then
  raise exception 'Other recipients leaked';end if;
 insert into public.ex_saved_recipients(user_id,label,wallet_key,phone)
  values(f.customer,'My recipient','FastPay','07700000003') returning id into v;
 update public.ex_saved_recipients set label='My updated recipient' where id=v;
 if (select label from public.ex_saved_recipients where id=v)<>'My updated recipient' then raise exception 'Own recipient cannot update';end if;
 begin
  insert into public.ex_saved_recipients(user_id,label,wallet_key,phone)
   values(f.other_customer,'Forged owner','FastPay','07700000004');
  raise exception 'Foreign recipient insertion accepted';
 exception when insufficient_privilege then null;end;
 begin
  update public.ex_saved_recipients set user_id=f.other_customer where id=v;
  raise exception 'Recipient owner changed';
 exception when insufficient_privilege then null;end;
 begin
  insert into public.ex_saved_recipients(user_id,label,wallet_key,phone)
   values(f.customer,'Bad phone','FastPay','123456');
  raise exception 'Invalid recipient phone accepted';
 exception when invalid_parameter_value then null;end;
 insert into public.ex_wallet_badge_views(user_id,wallet_id,badge_version)
  select f.customer,w.id,w.badge_version from public.ex_wallets w where w.id=f.wallet;
 if (select count(*) from public.ex_wallet_badge_views where wallet_id=f.wallet)<>1 then raise exception 'New badge not remembered';end if;
 begin
  insert into public.ex_wallet_badge_views(user_id,wallet_id,badge_version)
   select f.other_customer,w.id,w.badge_version from public.ex_wallets w where w.id=f.wallet;
  raise exception 'Foreign badge read accepted';
 exception when insufficient_privilege then null;end;
 begin
  insert into public.ex_wallet_badge_views(user_id,wallet_id,badge_version)
   values(f.customer,f.wallet,gen_random_uuid());
  raise exception 'Fake badge version accepted';
 exception when insufficient_privilege then null;end;
 perform public.ex_refresh_reward_alerts();
 if (select count(*) from public.ex_notifications where reward_alert_kind is not null)<>2 then raise exception 'Alert refresh duplicated';end if;
 delete from public.ex_saved_recipients where id=v;
end $test$;
select set_config('request.jwt.claim.sub',(select staff::text from feature_fixture),true);
do $test$
declare f record;n integer;
begin
 select * into f from feature_fixture;
 if public.is_ex_admin() or not public.ex_staff_has('view') or public.ex_staff_has('refunds') then
  raise exception 'View-only staff rights incorrect';end if;
 update public.ex_wallets set badge='popular' where id=f.wallet;
 get diagnostics n=row_count;
 if n<>0 then raise exception 'View-only staff changed wallet';end if;
 begin
  perform public.ex_admin_allow_ip('192.0.2.12','Forbidden fixture');
  raise exception 'Scoped staff used legacy security RPC';
 exception when others then
  if sqlerrm='Scoped staff used legacy security RPC' then raise;end if;end;
 begin
  perform public.ex_notify_user(f.customer,'Forbidden','Forbidden');
  raise exception 'Scoped staff sent unrestricted notification';
 exception when others then
  if sqlerrm='Scoped staff sent unrestricted notification' then raise;end if;end;
 begin
  update public.ex_profiles set staff_permissions=null where id=f.staff;
  raise exception 'Staff elevated own permissions';
 exception when insufficient_privilege then null;end;
 begin
  perform public.ex_staff_set_permissions(f.staff,null);
  raise exception 'Staff used super-admin permission RPC';
 exception when insufficient_privilege then null;end;
end $test$;
select set_config('request.jwt.claim.sub',(select super_admin::text from feature_fixture),true);
select public.ex_staff_set_permissions((select staff from feature_fixture),array['view','manage_fees']);
select set_config('request.jwt.claim.sub',(select staff::text from feature_fixture),true);
do $test$
declare f record;old_version uuid;new_version uuid;
begin
 select * into f from feature_fixture;
 if not public.ex_staff_has('manage_fees') or public.ex_staff_has('refunds') or public.is_ex_admin() then
  raise exception 'Fee permission spilled into other rights';end if;
 select badge_version into old_version from public.ex_wallets where id=f.wallet;
 update public.ex_wallets set badge='popular' where id=f.wallet;
 select badge_version into new_version from public.ex_wallets where id=f.wallet;
 if new_version=old_version then raise exception 'Badge version did not change';end if;
 update public.ex_wallets set badge='new' where id=f.wallet;
 perform set_config('request.jwt.claim.sub',f.customer::text,true);
 if exists(select 1 from public.ex_wallet_badge_views v join public.ex_wallets w
   on w.id=v.wallet_id and w.badge_version=v.badge_version where w.id=f.wallet) then
  raise exception 'New badge campaign already seen';end if;
end $test$;

select set_config('request.jwt.claim.sub',(select staff::text from feature_fixture),true);
do $live$
declare f record;w jsonb;saved jsonb;before_name text;
begin
 select * into f from feature_fixture;
 select to_jsonb(x) into w from public.ex_wallets x where id=f.wallet;
 saved=public.ex_staff_save_wallet(f.wallet,w||'{"name":"Atomic fixture","badge":"popular"}'::jsonb,
  jsonb_build_array(jsonb_build_object('from_method',w->>'key','to_method','FastPay','rate_type','fee_percent','rate_value',2,'is_active',true)));
 if saved->>'name'<>'Atomic fixture' or not exists(select 1 from public.ex_rates where from_method=w->>'key' and to_method='FastPay' and rate_value=2) then
  raise exception 'Atomic wallet/routes save failed';end if;
 begin
  perform public.ex_staff_save_wallet(f.wallet,w||'{"name":"Must roll back"}'::jsonb,
   jsonb_build_array(jsonb_build_object('from_method',w->>'key','to_method','FastPay','rate_type','invalid','rate_value',4,'is_active',true)));
  raise exception 'Invalid route accepted';
 exception when invalid_parameter_value then null;end;
 if (select name from public.ex_wallets where id=f.wallet)<>'Atomic fixture' then raise exception 'Partial wallet save committed';end if;
 begin
  perform public.ex_staff_save_wallet(gen_random_uuid(),w,'[]');
  raise exception 'Missing wallet reported saved';
 exception when no_data_found then null;end;
end $live$;
select set_config('request.jwt.claim.sub',(select customer::text from feature_fixture),true);
do $live$
declare f record;revision_before bigint;r uuid;
begin
 select * into f from feature_fixture;
 select coalesce(revision,0) into revision_before from public.ex_customer_feature_changes where user_id=f.customer;
 revision_before=coalesce(revision_before,0);
 insert into public.ex_saved_recipients(user_id,label,wallet_key,phone)
  values(f.customer,'Live fixture','FastPay','07700000009') returning id into r;
 update public.ex_saved_recipients set label='Live updated fixture' where id=r;
 delete from public.ex_saved_recipients where id=r;
 if (select revision from public.ex_customer_feature_changes where user_id=f.customer)<>revision_before+3 then
  raise exception 'Recipient CRUD invalidation missing';end if;
 if exists(select 1 from public.ex_customer_feature_changes where user_id=f.other_customer) then
  raise exception 'Foreign change signals leaked';end if;
 if has_table_privilege('authenticated','public.ex_customer_feature_changes','UPDATE')
  or has_function_privilege('anon','public.ex_staff_save_wallet(uuid,jsonb,jsonb)','EXECUTE') then
  raise exception 'Unexpected signal/function privilege';end if;
 begin
  perform public.ex_staff_save_wallet(null,'{}','[]');raise exception 'Customer edited wallet';
 exception when insufficient_privilege then null;end;
end $live$;

reset role;
rollback;
select 'PASS: atomic wallet/routes saves, partial-write rollback, missing-row refusal, private CRUD invalidation, owner RLS and staff permissions; fixtures rolled back' as result;
