\set ON_ERROR_STOP on
create function public.test_assert(ok boolean, message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',message; end if; end $$;

select test_assert(not has_table_privilege('anon','otp_whatsapp','select'),'anonymous OTP read denied');
select test_assert(not has_function_privilege('anon','get_or_generate_otp_whatsapp(text,text)','execute'),'anonymous generator denied');
select test_assert(not has_function_privilege('authenticated','verify_otp_whatsapp(text,text)','execute'),'old verifier denied');
select test_assert(not has_function_privilege('anon','pa_verify_whatsapp_otp(text,text,text)','execute'),'new verifier denied');
select test_assert(not has_function_privilege('authenticated','pa_record_signup_whatsapp_marketing(uuid,boolean,text,text)','execute'),'cannot forge signup consent');
select test_assert(not has_function_privilege('authenticated','pa_withdraw_whatsapp_marketing(text)','execute'),'cannot withdraw another phone');
select test_assert(not has_table_privilege('authenticated','whatsapp_marketing_preferences','update'),'no unaudited preference update');
select test_assert(not has_table_privilege('service_role','whatsapp_marketing_consent_events','update'),'audit cannot be edited by service');

set role service_role;
do $$ declare r json; c text; v_id uuid; begin
  r:=get_or_generate_otp_whatsapp('+9647500000010','signup');
  perform test_assert((r->>'success')::boolean,'first reservation');
  c:=r->>'code'; v_id:=(r->>'otp_id')::uuid;
  perform test_assert(c ~ '^[0-9]{6}$','six digit OTP');
  perform test_assert((r->>'expires_at')::timestamptz=now()+interval '5 minutes','five minute expiry');
  perform test_assert(exists(select 1 from otp_whatsapp where otp_whatsapp.id=v_id),'reserved before sending');
  perform test_assert(get_or_generate_otp_whatsapp('+9647500000010','signup')->>'error'='rate_limited','cooldown');
  perform test_assert((pa_finish_whatsapp_otp_send(v_id,1,'fixture-message-1','queued')->>'success')::boolean,'provider id recorded');
  perform test_assert(not (pa_finish_whatsapp_otp_send(v_id,2,'stale-message','queued')->>'success')::boolean,'stale send result rejected');
  perform test_assert(not (pa_verify_whatsapp_otp('+9647500000010',c,'login')->'data'->>'verified')::boolean,'purpose cannot be exchanged');
  perform test_assert((pa_verify_whatsapp_otp('+9647500000010',c,'signup')->'data'->>'verified')::boolean,'correct code');
  perform test_assert(not (pa_verify_whatsapp_otp('+9647500000010',c,'signup')->'data'->>'verified')::boolean,'one use only');
end $$;
do $$ declare r json; c text; v_id uuid; begin
  r:=get_or_generate_otp_whatsapp('+9647500000011','login'); c:=r->>'code'; v_id:=(r->>'otp_id')::uuid;
  for i in 2..5 loop
    update otp_whatsapp set last_sent_at=now()-interval '61 seconds' where otp_whatsapp.id=v_id;
    r:=get_or_generate_otp_whatsapp('+9647500000011','login');
    perform test_assert((r->>'send_count')::integer=i and r->>'code'=c,'reused sends count');
  end loop;
  update otp_whatsapp set last_sent_at=now()-interval '61 seconds' where otp_whatsapp.id=v_id;
  perform test_assert(get_or_generate_otp_whatsapp('+9647500000011','signup')->>'error'='rate_limited','five per hour across purposes');
  update otp_whatsapp set created_at=now()-interval '61 minutes',
    last_sent_at=now()-interval '57 minutes',expires_at=now()-interval '56 minutes' where otp_whatsapp.id=v_id;
  perform test_assert(get_or_generate_otp_whatsapp('+9647500000011','signup')->>'error'='rate_limited','recent resends survive the hour boundary');
  update otp_whatsapp set expires_at=now()+interval '1 minute' where otp_whatsapp.id=v_id;
  for i in 1..5 loop
    perform pa_verify_whatsapp_otp('+9647500000011',case when c='000000' then '999999' else '000000' end,'login');
  end loop;
  perform test_assert(not (pa_verify_whatsapp_otp('+9647500000011',c,'login')->'data'->>'verified')::boolean,'five wrong attempts lock correct code');
  r:=get_or_generate_otp_whatsapp('+9647500000012','login'); c:=r->>'code';
  update otp_whatsapp set expires_at=now()-interval '1 second' where phone='9647500000012';
  perform test_assert(not (pa_verify_whatsapp_otp('+9647500000012',c,'login')->'data'->>'verified')::boolean,'expired code rejected');
end $$;

select pa_record_signup_whatsapp_marketing('11111111-1111-4111-8111-111111111111',true,'whatsapp-marketing-v1','ckb');
select pa_record_signup_whatsapp_marketing('11111111-1111-4111-8111-111111111111',true,'whatsapp-marketing-v1','ckb');
select pa_record_signup_whatsapp_marketing('22222222-2222-4222-8222-222222222222',false,'whatsapp-marketing-v1','ar');
select test_assert(pa_whatsapp_marketing_allowed('11111111-1111-4111-8111-111111111111'),'accepted verified phone allowed');
select test_assert(not pa_whatsapp_marketing_allowed('22222222-2222-4222-8222-222222222222'),'refusal excluded');
select test_assert((select count(*)=2 from whatsapp_marketing_consent_events),'idempotent audit');
select test_assert((select consent_text like '%مارکێتینگی Proxo%' and accepted_at is not null from whatsapp_marketing_preferences where opted_in),'server copy and acceptance time');
select test_assert((select accepted_at is null and withdrawn_at is null from whatsapp_marketing_preferences where not opted_in),'refusal is not a withdrawal');
do $$ begin
  begin
    perform pa_record_signup_whatsapp_marketing('33333333-3333-4333-8333-333333333333',true,'whatsapp-marketing-v1','ckb');
    raise exception 'unverified phone accepted';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;
set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
select test_assert((select count(*)=1 from whatsapp_marketing_preferences),'RLS own preference only');
select pa_set_whatsapp_marketing(false,'whatsapp-marketing-v1','ckb');
do $$ begin
  begin
    perform pa_set_whatsapp_marketing(true,'forged-version','ckb');
    raise exception 'invalid version accepted';
  exception when invalid_parameter_value then null; end;
end $$;
set request.jwt.claim.sub='';
do $$ begin
  begin
    perform pa_set_whatsapp_marketing(true,'whatsapp-marketing-v1','ckb');
    raise exception 'unauthenticated update accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set role service_role;
select test_assert(not pa_whatsapp_marketing_allowed('11111111-1111-4111-8111-111111111111'),'withdrawal stops marketing');
select test_assert((select withdrawn_at is not null from whatsapp_marketing_preferences where user_id='11111111-1111-4111-8111-111111111111'),'withdrawal audited');
select pa_record_signup_whatsapp_marketing('11111111-1111-4111-8111-111111111111',true,'whatsapp-marketing-v1','ckb');
reset role;
update auth.users set phone='9647500000099' where id='11111111-1111-4111-8111-111111111111';
set role service_role;
select test_assert(not pa_whatsapp_marketing_allowed('11111111-1111-4111-8111-111111111111'),'new number needs fresh opt-in');
select pa_withdraw_whatsapp_marketing('+9647500000001');
select test_assert((select not opted_in from whatsapp_marketing_preferences where user_id='11111111-1111-4111-8111-111111111111'),'off-app opt-out honored');
reset role;
\echo 'WhatsApp OTP, consent, RLS and audit checks passed.'
