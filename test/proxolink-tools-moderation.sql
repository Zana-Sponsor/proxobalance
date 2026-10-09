\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
INSERT INTO public.proxolink_cards(user_id,name,page_kind,template_key,template_version,client_request_id,settings,tt)
VALUES(auth.uid(),'All four','order','pill',6,gen_random_uuid(),
 '{"providers":[{"provider_key":"talabat","destination_url":"https://talabat.com/restaurant/test","enabled":true,"sort_order":0},{"provider_key":"wade","destination_url":"https://wadedelivery.com/restaurant/test","enabled":true,"sort_order":1},{"provider_key":"toters","destination_url":"https://totersapp.com/restaurant/test","enabled":true,"sort_order":2},{"provider_key":"lezzoo","destination_url":"https://lezzoo.com/restaurant/test","enabled":true,"sort_order":3}]}','proxo_iq');
DO $$ DECLARE n int; BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.proxolink_cards WHERE name='All four' AND moderation_status='pending' AND id<>auth.uid() AND id<>client_request_id) THEN RAISE EXCEPTION 'pending/default/generated identity'; END IF;
 BEGIN UPDATE public.proxolink_cards SET moderation_status='approved' WHERE name='All four'; RAISE EXCEPTION 'owner approval allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.proxolink_cards SET moderation_status='rejected' WHERE name='All four'; RAISE EXCEPTION 'owner rejection allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.proxolink_cards SET publish_status='failed' WHERE name='All four';
 IF NOT EXISTS(SELECT 1 FROM public.proxolink_cards WHERE name='All four' AND moderation_status='pending') THEN RAISE EXCEPTION 'technical failure conflated'; END IF;
 BEGIN UPDATE public.proxolink_cards SET created_at=now()-interval '1 year' WHERE name='All four'; RAISE EXCEPTION 'creation mutation'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN UPDATE public.proxolink_cards SET tt='<script>evil</script>' WHERE name='All four'; RAISE EXCEPTION 'TikTok injection'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
SET LOCAL request.jwt.claim.sub='99999999-9999-4999-8999-999999999999';
SET LOCAL request.test_admin='true';
DO $$ DECLARE n int; BEGIN
 IF EXISTS(SELECT 1 FROM public.proxolink_cards WHERE name='All four') THEN RAISE EXCEPTION 'cross owner read'; END IF;
 DELETE FROM public.proxolink_cards WHERE name='All four'; GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'cross owner delete'; END IF;
END $$;
RESET ROLE;
SET LOCAL ROLE service_role;
UPDATE public.proxolink_cards SET moderation_status='approved' WHERE name='All four';
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.proxolink_cards WHERE name='All four' AND moderation_status='approved') THEN RAISE EXCEPTION 'trusted approval'; END IF;
 BEGIN UPDATE public.proxolink_cards SET moderation_status='banana' WHERE name='All four'; RAISE EXCEPTION 'invalid moderation'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN UPDATE public.proxolink_cards SET moderation_status='pending' WHERE name='All four'; RAISE EXCEPTION 'terminal status reset'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
SET LOCAL request.test_admin='';
DO $$ DECLARE n int; BEGIN
 DELETE FROM public.proxolink_cards WHERE name='All four'; GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'real owner deletion'; END IF;
 BEGIN DELETE FROM public.proxolink_cards WHERE name='Legacy preserved'; RAISE EXCEPTION 'ad dependency removed'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 IF has_table_privilege('anon','public.proxolink_cards','SELECT') OR has_function_privilege('authenticated','public.proxolink_moderation_guard()','EXECUTE') THEN RAISE EXCEPTION 'unsafe grant'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE k text; bad jsonb; BEGIN
 FOR k,bad IN VALUES ('order','{"providers":[{"provider_key":"wade","destination_url":"https://evil.example/test","enabled":true,"sort_order":0}]}'::jsonb),
  ('order','{"providers":[{"provider_key":"lezzoo","destination_url":"javascript:evil","enabled":true,"sort_order":0}]}'::jsonb),
  ('contact','{"providers":[{"provider_key":"talabat","destination_url":"https://talabat.com/test","enabled":true,"sort_order":0}]}'::jsonb)
 LOOP IF public.proxolink_v6_settings_valid(k,bad) THEN RAISE EXCEPTION 'invalid provider accepted'; END IF; END LOOP;
 INSERT INTO public.proxolink_cards(user_id,name,page_kind,template_key,template_version,client_request_id,settings)
 VALUES('11111111-1111-4111-8111-111111111111','Reject test','contact','pill',6,gen_random_uuid(),'{"providers":[{"provider_key":"telegram","destination_url":"https://t.me/proxo_iq","enabled":true,"sort_order":0}]}');
 UPDATE public.proxolink_cards SET moderation_status='rejected' WHERE name='Reject test';
 IF NOT EXISTS(SELECT 1 FROM public.proxolink_cards WHERE name='Reject test' AND moderation_status='rejected') THEN RAISE EXCEPTION 'trusted rejection'; END IF;
 IF EXISTS(SELECT 1 FROM public.proxolink_cards c JOIN public.v6_legacy_snapshot s USING(id) WHERE to_jsonb(c)-ARRAY['page_kind','settings','archived_at','moderation_status']<>s.data) THEN RAISE EXCEPTION 'legacy changed'; END IF;
 IF EXISTS(SELECT 1 FROM public.pa_ads a JOIN public.v6_ad_snapshot s USING(id) WHERE to_jsonb(a)<>s.data) THEN RAISE EXCEPTION 'ad changed'; END IF;
END $$;
ROLLBACK;
SELECT 'VERIFIED: moderation/default/owner denial/trusted transitions; four providers; identity; actual owner delete; FK/anonymous/grant/legacy protections';
