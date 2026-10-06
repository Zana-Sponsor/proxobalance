-- Synthetic reporting fixtures. All accounts and orders are rolled back.
begin;
set local request.jwt.claim.role='service_role';
create temporary table report_names_fixture as select gen_random_uuid() customer,gen_random_uuid() super_admin,gen_random_uuid() staff,gen_random_uuid() other_staff;
grant select on report_names_fixture to authenticated;
do $test$
declare f record;
begin
 select * into f from report_names_fixture;
 insert into auth.users(id,email,raw_user_meta_data) values
 (f.customer,'report-customer-'||f.customer||'@example.invalid','{"full_name":"Report Customer"}'),
 (f.super_admin,'report-super-'||f.super_admin||'@example.invalid','{"full_name":"Report Super"}'),
 (f.staff,'report-staff-'||f.staff||'@example.invalid','{"full_name":"Report Staff"}'),
 (f.other_staff,'report-other-'||f.other_staff||'@example.invalid','{"full_name":"Report Other"}');
 update public.ex_profiles set role='super_admin' where id=f.super_admin;
 update public.ex_profiles set role='admin' where id in(f.staff,f.other_staff);
 update public.ex_user_rewards set active=false where user_id in(f.customer,f.super_admin,f.staff,f.other_staff) and campaign_key='welcome_signup_v1';
 insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,handled_by)
 values (f.customer,'FastPay','FIB',100000,98000,'07700000001',f.staff),
 (f.customer,'FastPay','FIB',50000,49000,'07700000001',f.other_staff),
 (f.customer,'FastPay','FIB',20000,19600,'07700000001',null),
 (f.customer,'FastPay','FIB',10000,9800,'07700000001',f.staff);
 update public.ex_orders set status=case when amount=10000 then 'ڕەتکرا' else 'پەسەندکرا' end,
   decided_at='2100-01-10 09:00:00+00' where user_id=f.customer;
end $test$;
set local role authenticated;
set local request.jwt.claim.role='authenticated';
select set_config('request.jwt.claim.sub',(select super_admin::text from report_names_fixture),true);
do $test$
declare stats jsonb; f record;
begin
 select * into f from report_names_fixture;
 stats:=public.ex_admin_deduction_stats('2100-01-10','2100-01-10',500);
 if stats->>'scope'<>'all' or (stats->>'approved_orders')::int<>3 or (stats->>'total_deduction_iqd')::numeric<>3400 then raise exception 'Super report lost global approved fees';end if;
 if jsonb_array_length(stats->'by_admin')<>3 then raise exception 'Report merged unknown handler into a named admin';end if;
 if not exists(select 1 from jsonb_array_elements(stats->'orders') o where o->>'handled_by'=f.staff::text and o->>'handling_admin_name'='Report Staff') then raise exception 'Staff name missing';end if;
 if not exists(select 1 from jsonb_array_elements(stats->'orders') o where o->>'handled_by'=f.other_staff::text and o->>'handling_admin_name'='Report Other') then raise exception 'Other staff name missing';end if;
 if not exists(select 1 from jsonb_array_elements(stats->'orders') o where o->>'handled_by' is null and o->>'handling_admin_name' is null) then raise exception 'Unattributed order was dropped or given a false admin name';end if;
 if exists(select 1 from jsonb_array_elements(stats->'orders') o where o->>'handling_admin_name' in('Report Customer','Report Super') or o->>'order_code' not like 'P%') then raise exception 'Export names or public codes identify the wrong actor';end if;
 stats:=public.ex_admin_deduction_stats('2100-01-10','2100-01-10',1);
 if jsonb_array_length(stats->'orders')<>1 or (stats->>'total_deduction_iqd')::numeric<>3400 then raise exception 'Row limit truncated total profit';end if;
 -- The profile read used by exchange statistics obeys staff RLS.
 if (select count(*) from public.ex_profiles where id in(f.staff,f.other_staff) and full_name in('Report Staff','Report Other'))<>2 then raise exception 'Statistics cannot read handling names';end if;
end $test$;
select set_config('request.jwt.claim.sub',(select staff::text from report_names_fixture),true);
do $test$
declare stats jsonb;f record;
begin
 select * into f from report_names_fixture;
 stats:=public.ex_admin_deduction_stats('2100-01-10','2100-01-10',500);
 if stats->>'scope'<>'own' or (stats->>'approved_orders')::int<>1 or (stats->>'total_deduction_iqd')::numeric<>2000 or jsonb_array_length(stats->'by_admin')<>1 then raise exception 'Personal report includes another admin';end if;
 if exists(select 1 from jsonb_array_elements(stats->'orders') o where o->>'handled_by' is distinct from f.staff::text or o->>'handling_admin_name'<>'Report Staff') then raise exception 'Personal report mislabeled handler';end if;
 begin
  perform public.ex_admin_deduction_stats('2100-01-11','2100-01-10',500);
  raise exception 'Invalid date range accepted';
 exception when invalid_parameter_value then null;end;
end $test$;
select set_config('request.jwt.claim.sub',(select customer::text from report_names_fixture),true);
do $test$
begin
 begin
  perform public.ex_admin_deduction_stats('2100-01-10','2100-01-10',500);
  raise exception 'Customer read private reports';
 exception when insufficient_privilege then null;end;
end $test$;
reset role;
rollback;
select 'PASS: global super-admin reporting, personal staff scope, correct names, unknown handlers, public P codes and date limits; fixtures rolled back' as result;
