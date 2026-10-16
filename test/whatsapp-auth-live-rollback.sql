-- No outbound requests, Auth users, or durable records. Run as the database owner.
-- Only fixture numbers are touched; refuse any pre-existing fixture data.
begin;
set local statement_timeout = '20s';
do $$
declare v_fixture_phone text;
begin
  foreach v_fixture_phone in array array['+9647000000911','+9647000000912','+9647000000913','+9647000000914'] loop
    if exists(select 1 from public.otp_whatsapp where otp_whatsapp.phone=replace(v_fixture_phone,'+',''))
       or exists(select 1 from public.pa_profile_by_phone(v_fixture_phone)) then
      raise exception 'Fixture phone is in use; no tests run';
    end if;
  end loop;
end $$;
set local role service_role;
do $$
declare r json; c text; oid uuid; i integer;
begin
  if public.get_or_generate_otp_whatsapp('invalid','login')->>'error' is distinct from 'bad_request'
    or public.get_or_generate_otp_whatsapp('+9647000000911','marketing')->>'error' is distinct from 'bad_request'
    then raise exception 'Invalid input not rejected'; end if;
  r:=public.get_or_generate_otp_whatsapp('+9647000000911','signup');
  c:=r->>'code'; oid:=(r->>'otp_id')::uuid;
  if (r->>'success')::boolean is distinct from true or c !~ '^[0-9]{6}$'
    or (r->>'expires_at')::timestamptz <> now()+interval '5 minutes'
    then raise exception 'Reservation contract failed'; end if;
  if public.get_or_generate_otp_whatsapp('+9647000000911','signup')->>'error' is distinct from 'rate_limited'
    then raise exception 'Cooldown failed'; end if;
  if (public.pa_finish_whatsapp_otp_send(oid,1,'isolated-fixture-only','queued')->>'success')::boolean is distinct from true
    then raise exception 'Delivery recording failed'; end if;
  if (public.pa_finish_whatsapp_otp_send(oid,2,'stale-fixture-only','queued')->>'success')::boolean is distinct from false
    then raise exception 'Stale delivery accepted'; end if;
  if (public.pa_verify_whatsapp_otp('+9647000000911',c,'login')->'data'->>'verified')::boolean is distinct from false
    or (public.verify_otp_whatsapp('+9647000000911',c)->'data'->>'verified')::boolean is distinct from false
    then raise exception 'Purpose boundary failed'; end if;
  if (public.pa_verify_whatsapp_otp('+9647000000911',case when c='000000' then '999999' else '000000' end,'signup')->'data'->>'verified')::boolean is distinct from false
    then raise exception 'Wrong proof accepted'; end if;
  if (public.pa_verify_whatsapp_otp('+9647000000911',c,'signup')->'data'->>'verified')::boolean is distinct from true
    or (public.pa_verify_whatsapp_otp('+9647000000911',c,'signup')->'data'->>'verified')::boolean is distinct from false
    then raise exception 'Single use verification failed'; end if;
  r:=public.get_or_generate_otp_whatsapp('+9647000000912','login'); c:=r->>'code'; oid:=(r->>'otp_id')::uuid;
  update public.otp_whatsapp set expires_at=now()-interval '1 second' where id=oid;
  if (public.pa_verify_whatsapp_otp('+9647000000912',c,'login')->'data'->>'verified')::boolean is distinct from false
    then raise exception 'Expired proof accepted'; end if;
  r:=public.get_or_generate_otp_whatsapp('+9647000000913','login'); c:=r->>'code'; oid:=(r->>'otp_id')::uuid;
  for i in 1..5 loop
    perform public.pa_verify_whatsapp_otp('+9647000000913',case when c='000000' then '999999' else '000000' end,'login');
  end loop;
  if (public.pa_verify_whatsapp_otp('+9647000000913',c,'login')->'data'->>'verified')::boolean is distinct from false
    or not exists(select 1 from public.otp_whatsapp where id=oid and verify_attempts=5 and locked_at is not null)
    then raise exception 'Attempt lock failed'; end if;
  r:=public.get_or_generate_otp_whatsapp('+9647000000914','login'); c:=r->>'code'; oid:=(r->>'otp_id')::uuid;
  for i in 2..5 loop
    update public.otp_whatsapp set last_sent_at=now()-interval '61 seconds' where id=oid;
    r:=public.get_or_generate_otp_whatsapp('+9647000000914','login');
    if (r->>'send_count')::integer is distinct from i or r->>'code' is distinct from c
      then raise exception 'Resend accounting failed'; end if;
  end loop;
  update public.otp_whatsapp set last_sent_at=now()-interval '61 seconds' where id=oid;
  if public.get_or_generate_otp_whatsapp('+9647000000914','signup')->>'error' is distinct from 'rate_limited'
    then raise exception 'Cross-purpose quota failed'; end if;
  update public.otp_whatsapp set created_at=now()-interval '61 minutes', last_sent_at=now()-interval '57 minutes' where id=oid;
  if public.get_or_generate_otp_whatsapp('+9647000000914','signup')->>'error' is distinct from 'rate_limited'
    then raise exception 'Hour-boundary quota failed'; end if;
end $$;
rollback;
select 'OTP lifecycle assertions passed; fixture changes rolled back' as result,
  count(*)=0 as no_fixture_rows_remain
from public.otp_whatsapp where phone in ('9647000000911','9647000000912','9647000000913','9647000000914');
