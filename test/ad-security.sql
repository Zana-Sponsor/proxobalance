\set ON_ERROR_STOP on
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
DO $$ BEGIN
 BEGIN
  UPDATE public.pa_ads SET status='active',budget=0 WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  RAISE EXCEPTION 'FAIL direct ad update allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  UPDATE public.pa_notifications SET type='ad_active',meta='{"ad_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}';
  RAISE EXCEPTION 'FAIL forged activation allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.pa_notifications SET is_read=true;
 IF NOT (SELECT is_read FROM public.pa_notifications LIMIT 1) THEN RAISE EXCEPTION 'mark read broke'; END IF;
 BEGIN
  PERFORM public.submit_ad_update('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','title','Other account');
  RAISE EXCEPTION 'FAIL cross-owner correction allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.submit_ad_update('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','video_code','wrong field');
  RAISE EXCEPTION 'FAIL unrequested correction allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.submit_ad_update('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','budget','1');
  RAISE EXCEPTION 'FAIL budget correction allowed';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.submit_ad_update('cccccccc-cccc-4ccc-8ccc-cccccccccccc','start_date','invalid date');
  RAISE EXCEPTION 'FAIL invalid date accepted';
 EXCEPTION WHEN invalid_datetime_format THEN NULL; END;
 PERFORM public.submit_ad_update('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','title','Corrected');
 IF NOT EXISTS(SELECT 1 FROM public.pa_ads WHERE title='Corrected' AND status='review' AND update_submitted_at IS NOT NULL AND budget=100 AND needs_update) THEN RAISE EXCEPTION 'corrected state invalid'; END IF;
 BEGIN
  PERFORM public.submit_ad_update('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','title','Replay');
  RAISE EXCEPTION 'FAIL replay allowed';
 EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 PERFORM public.submit_ad_update('cccccccc-cccc-4ccc-8ccc-cccccccccccc','start_date','2026-12-25');
 IF NOT EXISTS(SELECT 1 FROM public.pa_ads WHERE start_date=DATE '2026-12-25') THEN RAISE EXCEPTION 'date conversion failed'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF has_function_privilege('anon','public.submit_ad_update(uuid,text,text)','execute') THEN RAISE EXCEPTION 'anonymous RPC access'; END IF;
END $$;
SELECT 'All correction ownership, replay, type, read-state and notification tampering checks passed' AS result;
