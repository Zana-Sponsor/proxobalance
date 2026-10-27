-- Synthetic security and accounting fixtures; no real accounts are modified.
begin;
set local request.jwt.claim.role='service_role';
create temporary table admin_workspace_fixture as select gen_random_uuid() customer,gen_random_uuid() super_admin,gen_random_uuid() staff,gen_random_uuid() other_staff;
grant select on admin_workspace_fixture to authenticated;
do $test$
declare f record;
begin
 select * into f from admin_workspace_fixture;
 insert into auth.users(id,email,raw_user_meta_data) values
 (f.customer,'workspace-customer-'||f.customer||'@example.invalid','{"full_name":"Workspace Customer"}'),
 (f.super_admin,'workspace-super-'||f.super_admin||'@example.invalid','{"full_name":"Workspace Super"}'),
 (f.staff,'workspace-staff-'||f.staff||'@example.invalid','{"full_name":"Workspace Staff"}'),
 (f.other_staff,'workspace-other-'||f.other_staff||'@example.invalid','{"full_name":"Workspace Other"}');
 update public.ex_profiles set role='super_admin' where id=f.super_admin;
 -- Personal-report fee fixtures use their normal, undiscounted route prices.
 update public.ex_user_rewards set active=false where user_id in(f.customer,f.super_admin,f.staff,f.other_staff) and campaign_key='welcome_signup_v1';
end $test$;
set local role authenticated;
set local request.jwt.claim.role='authenticated';
select set_config('request.jwt.claim.sub',(select super_admin::text from admin_workspace_fixture),true);
select public.ex_admin_set_role((select staff from admin_workspace_fixture),'admin');
do $test$
declare f record;
begin
 select * into f from admin_workspace_fixture;
 if (select staff_permissions from public.ex_profiles where id=f.staff) is distinct from array['view','approve_orders']::text[] then raise exception 'New admin got unrestricted permissions';end if;
 perform public.ex_staff_set_permissions(f.staff,null); -- legacy/full permissions still cannot grant security access
 perform public.ex_staff_set_permissions(f.staff,array['view']::text[]);
 perform set_config('request.jwt.claim.sub',f.staff::text,true);
 if public.ex_staff_has('approve_orders') then raise exception 'Super admin could not restrict staff rights';end if;
 perform set_config('request.jwt.claim.sub',f.super_admin::text,true);
 perform public.ex_staff_set_permissions(f.staff,array[]::text[]);
 perform set_config('request.jwt.claim.sub',f.staff::text,true);
 if public.ex_staff_has('view') then raise exception 'Super admin could not suspend staff rights';end if;
 perform set_config('request.jwt.claim.sub',f.super_admin::text,true);
 update public.ex_profiles set is_banned=true where id=f.staff;
 perform public.ex_staff_set_permissions(f.staff,null);
 perform set_config('request.jwt.claim.sub',f.staff::text,true);
 if public.ex_staff_has('view') then raise exception 'Banned staff retained permissions';end if;
 perform set_config('request.jwt.claim.sub',f.super_admin::text,true);
 update public.ex_profiles set is_banned=false where id=f.staff;
 perform public.ex_admin_set_role(f.staff,'user');
 perform set_config('request.jwt.claim.sub',f.staff::text,true);
 if (select is_admin from public.ex_profiles where id=f.staff) or public.ex_staff_has('view') then
  raise exception 'Super admin could not remove staff role';end if;
 perform set_config('request.jwt.claim.sub',f.super_admin::text,true);
 perform public.ex_admin_set_role(f.staff,'admin');
 perform public.ex_staff_set_permissions(f.staff,null);
 perform set_config('request.jwt.claim.sub',f.staff::text,true);
 if not public.ex_staff_has('approve_orders') then raise exception 'Super admin could not restore staff rights';end if;
 perform set_config('request.jwt.claim.sub',f.super_admin::text,true);
 update public.ex_profiles set is_banned=true where id=f.customer;
 update public.ex_profiles set is_banned=false where id=f.customer;
end $test$;
select set_config('request.jwt.claim.sub',(select staff::text from admin_workspace_fixture),true);
do $test$
declare f record;
begin
 select * into f from admin_workspace_fixture;
 begin
  update public.ex_profiles set is_banned=true where id=f.customer;
  raise exception 'Non-super admin banned user';
 exception when insufficient_privilege then null;end;
 begin
  perform public.ex_admin_set_role(f.customer,'admin');
  raise exception 'Non-super admin promoted user';
 exception when insufficient_privilege then null;end;
 begin
  perform public.ex_admin_list_otp(1);
  raise exception 'Non-super admin read OTP';
 exception when others then if sqlerrm='Non-super admin read OTP' then raise;end if;end;
 begin
  perform public.ex_admin_list_events(1,null,null,null);
  raise exception 'Non-super admin read login logs';
 exception when others then if sqlerrm='Non-super admin read login logs' then raise;end if;end;
 if exists(select 1 from public.ex_admin_audit_log) then raise exception 'Non-super admin read audit logs';end if;
end $test$;
reset role;
set local request.jwt.claim.role='service_role';
select set_config('request.jwt.claim.sub','',true);
do $test$
declare f record;
begin
 select * into f from admin_workspace_fixture;
 update public.ex_profiles set role='admin' where id=f.other_staff;
 insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,status,decided_at,handled_by)
 values (f.customer,'FastPay','FIB',100000,98000,'07700000001','پەسەندکرا',now(),f.staff),
 (f.customer,'FastPay','FIB',50000,49000,'07700000001','پەسەندکرا',now(),f.other_staff),
 (f.customer,'FastPay','FIB',10000,9800,'07700000001','ڕەتکرا',now(),f.staff);
update public.ex_orders set status=case when amount=10000 then 'ڕەتکرا' else 'پەسەندکرا' end,decided_at=now() where user_id=f.customer;
end $test$;
set local role authenticated;
set local request.jwt.claim.role='authenticated';
select set_config('request.jwt.claim.sub',(select staff::text from admin_workspace_fixture),true);
do $test$
declare stats jsonb;
begin
 stats:=public.ex_staff_monthly_activity();
 if (stats->>'handled_orders')::int<>2 or (stats->>'deduction_iqd')::numeric<>2000 then raise exception 'Personal activity includes another admin or rejected fees: %',stats;end if;
 stats:=public.ex_admin_deduction_stats();
 if (stats->>'approved_orders')::int<>1 or (stats->>'total_deduction_iqd')::numeric<>2000 then raise exception 'Personal report exposed another admin: %',stats;end if;
end $test$;
reset role;
rollback;
select 'PASS: safe promotion, super-only bans/roles/OTP/logs and personal monthly deduction scope; fixtures rolled back' as result;
