select test_assert((select last_login_at='2026-10-01T12:00:00Z' from profiles where id='11111111-1111-4111-8111-111111111111'),'backfill uses Auth time');
select test_assert(not has_function_privilege('anon','pa_record_app_session(uuid,jsonb)','execute'),'anon cannot record metadata');
select test_assert(not has_schema_privilege('anon','app_auth_audit','usage'),'private implementation is unavailable to anon');
set role supabase_auth_admin;
insert into auth.sessions(id,user_id,created_at,ip,user_agent) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111',now()-interval '2 minutes','192.0.2.1','fixture-agent'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222',now()-interval '1 minute','192.0.2.2','fixture-agent');
reset role;
select test_assert((select count(*)=2 from pa_activity_log where action='login'),'Auth inserts record each session');
select test_assert((select p.last_login_at=s.created_at from profiles p join auth.sessions s on s.user_id=p.id where p.id='11111111-1111-4111-8111-111111111111'),'server profile timestamp');
update auth.sessions set updated_at=now() where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select test_assert((select count(*)=2 from pa_activity_log where action='login'),'refresh does not duplicate login');
do $$ begin
  begin
    insert into auth.sessions(id,user_id) values
     ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','11111111-1111-4111-8111-111111111111');
    raise exception 'fixture transaction rollback' using errcode='ZX001';
  exception when sqlstate 'ZX001' then null; end;
end $$;
select test_assert((select count(*)=2 from pa_activity_log where action='login'),'failed Auth transaction cannot leave a login event');

set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
set request.jwt.claims='{"sub":"11111111-1111-4111-8111-111111111111","session_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}';
select pa_record_app_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '{"device_name":"Fixture Android","device_model":"Fixture Model","os":"Android","os_version":"13","platform":"android","user_id":"22222222-2222-4222-8222-222222222222","ip_address":"203.0.113.9","login_time":"2099-01-01"}');
select pa_record_app_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{"device_model":"duplicate"}');
select test_assert((select count(*)=1 from pa_login_history),'duplicate record is idempotent and RLS hides other owners');
select test_assert((select device_model='Fixture Model' and os='Android' and os_version='13' and ip_address='192.0.2.1' from pa_login_history),'metadata allowed fields and server IP');
do $$ begin
  begin
    perform pa_record_app_session('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','{}');
    raise exception 'another session accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform pa_record_app_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[]');
    raise exception 'array accepted';
  exception when invalid_parameter_value then null; end;
  begin
    insert into pa_login_history(user_id,session_id) values(auth.uid(),'forged');
    raise exception 'direct forged history accepted';
  exception when insufficient_privilege then null; end;
end $$;
update profiles set last_login_at='2099-01-01',last_logout_at='2099-01-01' where id=auth.uid();
select test_assert((select last_login_at<'2099-01-01' and last_logout_at is null from profiles),'owner cannot forge server times');
-- A signed token cannot claim someone else's session even when both arguments agree.
set request.jwt.claims='{"session_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}';
do $$ begin
  begin
    perform pa_record_app_session('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','{}');
    raise exception 'cross-owner session accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set request.jwt.claim.sub='';
set request.jwt.claims='{}';
set role supabase_auth_admin;
delete from auth.sessions where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
select test_assert((select logout_time is not null and session_duration>=120 from pa_login_history where session_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'actual revocation closes matching history');
select test_assert((select count(*)=1 from pa_activity_log where action='logout'),'one logout event');
select test_assert((select count(*)=1 from auth.sessions where user_id='22222222-2222-4222-8222-222222222222'),'another owner session remains active');
set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
set request.jwt.claims='{"session_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}';
do $$ begin
  begin
    perform pa_record_app_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{}');
    raise exception 'revoked session accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set request.jwt.claim.sub='';
set request.jwt.claims='{}';
set role supabase_auth_admin;
insert into auth.sessions(id,user_id,created_at) values
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','11111111-1111-4111-8111-111111111111',now()-interval '3 minutes'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','11111111-1111-4111-8111-111111111111',now()-interval '4 minutes');
delete from auth.sessions where user_id='11111111-1111-4111-8111-111111111111';
reset role;
select test_assert((select count(*)=3 from pa_activity_log where action='logout' and user_id='11111111-1111-4111-8111-111111111111'),'global revocation records every ended session even without app metadata');
select test_assert((select count(*)=1 from auth.sessions where user_id='22222222-2222-4222-8222-222222222222'),'global signout is owner scoped');
delete from auth.users where id='22222222-2222-4222-8222-222222222222';
select test_assert(not exists(select 1 from pa_activity_log where user_id='22222222-2222-4222-8222-222222222222'),'account deletion preserves audit erasure');
select 'Auth activity, metadata, isolation, idempotency and revocation assertions passed' as result;
