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
do $test$
declare f record;
begin
 select * into f from report_names_fixture;
 update public.ex_orders set decided_at=case when handled_by=f.staff then '2100-01-08 09:00:00+00'::timestamptz else '2100-01-10 09:00:00+00'::timestamptz end where user_id=f.customer;
 -- Duplicate display names must not merge different staff identities.
 update public.ex_profiles set full_name='Report Staff' where id=f.other_staff;
end $test$;
set local role authenticated;
set local request.jwt.claim.role='authenticated';
select set_config('request.jwt.claim.sub',(select super_admin::text from report_names_fixture),true);
do $test$
declare f record;stats jsonb;
begin
 select * into f from report_names_fixture;
 stats:=public.ex_admin_deduction_stats_filtered('2100-01-08','2100-01-10',1,f.staff);
 if (stats->>'approved_orders')::int<>1 or (stats->>'total_deduction_iqd')::numeric<>2000 or jsonb_array_length(stats->'orders')<>1 then raise exception 'Selected-admin totals include another handler';end if;
 if stats->>'report_admin_id'<>f.staff::text or stats->>'report_admin_name'<>'Report Staff' or stats->'orders'->0->>'handled_by'<>f.staff::text then raise exception 'Filter was applied after the row limit';end if;
 stats:=public.ex_admin_deduction_stats_filtered('2100-01-08','2100-01-10',500,f.other_staff);
 if (stats->>'total_deduction_iqd')::numeric<>1000 or stats->'orders'->0->>'handled_by'<>f.other_staff::text then raise exception 'Duplicate names merged staff reports';end if;
 stats:=public.ex_admin_deduction_stats_filtered('2100-01-10','2100-01-10',500,f.staff);
 if (stats->>'approved_orders')::int<>0 or jsonb_array_length(stats->'orders')<>0 or stats->>'report_admin_name'<>'Report Staff' then raise exception 'Empty date-filtered report lost selected identity';end if;
 stats:=public.ex_admin_deduction_stats_filtered('2100-01-08','2100-01-10',500,null,true);
 if (stats->>'approved_orders')::int<>1 or (stats->>'total_deduction_iqd')::numeric<>400 or not (stats->>'report_unassigned')::boolean then raise exception 'Unassigned filter includes named handlers';end if;
 stats:=public.ex_admin_deduction_stats_filtered('2100-01-08','2100-01-10',500);
 if (stats->>'approved_orders')::int<>3 or (stats->>'total_deduction_iqd')::numeric<>3400 then raise exception 'All-admin report changed';end if;
 begin
  perform public.ex_admin_deduction_stats_filtered(null,null,500,f.staff,true);
  raise exception 'Conflicting filters accepted';
 exception when invalid_parameter_value then null;end;
end $test$;
select set_config('request.jwt.claim.sub',(select staff::text from report_names_fixture),true);
do $test$
declare f record;stats jsonb;
begin
 select * into f from report_names_fixture;
 stats:=public.ex_admin_deduction_stats_filtered('2100-01-08','2100-01-10',500,f.staff);
 if (stats->>'total_deduction_iqd')::numeric<>2000 or stats->>'scope'<>'own' then raise exception 'Staff self-filter changed own scope';end if;
 begin
  perform public.ex_admin_deduction_stats_filtered(null,null,500,f.other_staff);
  raise exception 'Regular staff selected another handler';
 exception when insufficient_privilege then null;end;
 begin
  perform public.ex_admin_deduction_stats_filtered(null,null,500,null,true);
  raise exception 'Regular staff selected unattributed orders';
 exception when insufficient_privilege then null;end;
end $test$;
select set_config('request.jwt.claim.sub',(select customer::text from report_names_fixture),true);
do $test$
begin
 begin
  perform public.ex_admin_deduction_stats_filtered();
  raise exception 'Customer read filtered reports';
 exception when insufficient_privilege then null;end;
end $test$;
reset role;
rollback;
select 'PASS: selected-admin totals and rows, filter before row limits, duplicate names, empty dates, unknown handlers and server-enforced staff permissions; fixtures rolled back' as result;
