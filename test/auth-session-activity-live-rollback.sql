-- Explicitly authorized live diagnostic: all changes are rolled back.
begin;
set local statement_timeout='20s';
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
  sa uuid:=gen_random_uuid(); sb uuid:=gen_random_uuid(); x uuid; y uuid; t timestamptz:=now()-interval '2 minutes';
begin
  insert into auth.users(id,email,raw_user_meta_data,aud,role)
    values(a,'auth-audit-fixture-'||a||'@example.invalid','{"full_name":"Isolated audit fixture"}','authenticated','authenticated'),
          (b,'auth-audit-fixture-'||b||'@example.invalid','{"full_name":"Isolated audit fixture"}','authenticated','authenticated');
  insert into auth.sessions(id,user_id,created_at) values(sa,a,t),(sb,b,t);
  if (select count(*) from public.pa_activity_log where user_id=a and session_id=sa::text and action='login')<>1 then
    raise exception 'Live login event failed'; end if;
  if (select last_login_at from public.profiles where id=a) is distinct from t then
    raise exception 'Live last-login timestamp failed'; end if;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sa,'role','authenticated')::text,true);
  set local role authenticated;
  x:=public.pa_record_app_session(sa,'{"device_model":"Isolated fixture","device_name":"Isolated Android","os":"Android","os_version":"13","platform":"android"}');
  y:=public.pa_record_app_session(sa,'{"device_model":"duplicate"}');
  if x is distinct from y then raise exception 'Live duplicate session failed'; end if;
  perform public.pa_login_close_session(x);
  if exists(select 1 from public.pa_login_history where id=x and logout_time is not null) then
    raise exception 'Legacy RPC closed an active Auth session history'; end if;
  if (select count(*) from public.pa_login_history where session_id=sa::text)<>1
    or (select device_model from public.pa_login_history where id=x) is distinct from 'Isolated fixture'
    then raise exception 'Live model recording failed'; end if;
  begin
    perform public.pa_record_app_session(sb,'{}');
    raise exception 'Live cross-session metadata accepted';
  exception when insufficient_privilege then null; end;
  update public.profiles set last_login_at='2099-01-01',last_logout_at='2099-01-01' where id=a;
  if (select last_login_at from public.profiles where id=a) is distinct from t then
    raise exception 'Live timestamp forgery accepted'; end if;
  reset role;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
  delete from auth.sessions where id=sa;
  if (select count(*) from public.pa_activity_log where user_id=a and session_id=sa::text and action='logout')<>1
    or not exists(select 1 from public.pa_login_history where id=x and logout_time is not null and session_duration>=120)
    then raise exception 'Live logout recording failed'; end if;
  if not exists(select 1 from auth.sessions where id=sb) then raise exception 'Another owner session affected'; end if;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sa,'role','authenticated')::text,true);
  set local role authenticated;
  begin
    perform public.pa_record_app_session(sa,'{}');
    raise exception 'Live revoked session accepted';
  exception when insufficient_privilege then null; end;
  reset role;
end $$;
rollback;
select 'Live login/logout/device/isolation checks passed and rolled back' as result,
  count(*)=0 as no_fixture_users_remain from auth.users where email like 'auth-audit-fixture-%@example.invalid';

