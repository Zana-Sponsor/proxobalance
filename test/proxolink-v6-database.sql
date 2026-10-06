\set ON_ERROR_STOP on
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.proxolink_cards c JOIN public.v6_legacy_snapshot s USING(id)
   WHERE to_jsonb(c)-ARRAY['page_kind','settings','archived_at']<>s.data) THEN RAISE EXCEPTION 'legacy data changed'; END IF;
 IF EXISTS(SELECT 1 FROM public.pa_ads a JOIN public.v6_ad_snapshot s USING(id) WHERE to_jsonb(a)<>s.data) THEN RAISE EXCEPTION 'advertisement relationships changed'; END IF;
END $$;
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
INSERT INTO public.proxolink_cards(user_id,name,page_kind,template_key,template_version,client_request_id,settings)
 VALUES (auth.uid(),'Contact','contact','pill-white',6,gen_random_uuid(),'{"providers":[{"provider_key":"telegram","destination_url":"https://t.me/proxo_iq","enabled":true,"sort_order":0}]}'),
 (auth.uid(),'Restaurant','order','pill',6,gen_random_uuid(),'{"providers":[{"provider_key":"talabat","destination_url":"https://iraq.talabat.com/iraq/restaurant/test","enabled":true,"sort_order":0},{"provider_key":"toters","destination_url":"https://www.totersapp.com/restaurant/test","enabled":true,"sort_order":1}]}'),
 (auth.uid(),'Download','download','pill-dark',6,gen_random_uuid(),'{"providers":[{"provider_key":"google_play","destination_url":"https://play.google.com/store/apps/details?id=com.proxo.app","enabled":true,"sort_order":0},{"provider_key":"app_store","destination_url":"https://apps.apple.com/us/app/proxo/id123456789","enabled":true,"sort_order":1}]}');
DO $$ DECLARE n int;BEGIN
 SELECT count(DISTINCT id) INTO n FROM public.proxolink_cards WHERE page_kind IS NOT NULL;
 IF n<>3 OR EXISTS(SELECT 1 FROM public.proxolink_cards WHERE page_kind IS NOT NULL AND (id=user_id OR id=client_request_id)) THEN RAISE EXCEPTION 'independent page UUID failed'; END IF;
 BEGIN UPDATE public.proxolink_cards SET page_kind='order' WHERE page_kind='contact';RAISE EXCEPTION 'type mutation accepted';EXCEPTION WHEN check_violation THEN NULL;END;
 BEGIN UPDATE public.proxolink_cards SET id=user_id WHERE page_kind='download';RAISE EXCEPTION 'identity mutation accepted';EXCEPTION WHEN check_violation THEN NULL;END;
 BEGIN UPDATE public.proxolink_cards SET user_id='99999999-9999-4999-8999-999999999999' WHERE page_kind='order';RAISE EXCEPTION 'owner mutation accepted';EXCEPTION WHEN check_violation THEN NULL;END;
 DELETE FROM public.proxolink_cards WHERE page_kind IS NOT NULL;
 GET DIAGNOSTICS n=ROW_COUNT;IF n<>0 THEN RAISE EXCEPTION 'hard delete allowed';END IF;
END $$;
UPDATE public.proxolink_cards SET name=name||' edited' WHERE page_kind IS NOT NULL;
SET LOCAL request.jwt.claim.sub='99999999-9999-4999-8999-999999999999';
SET LOCAL request.test_admin='true';
DO $$ DECLARE n int;BEGIN
 IF EXISTS(SELECT 1 FROM public.proxolink_cards WHERE page_kind IS NOT NULL) THEN RAISE EXCEPTION 'RLS exposed other pages';END IF;
 UPDATE public.proxolink_cards SET name='takeover' WHERE page_kind IS NOT NULL;GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'RLS cross-owner update';END IF;
 BEGIN INSERT INTO public.proxolink_cards(user_id,name,page_kind,template_key,template_version,client_request_id,settings)
 VALUES ('11111111-1111-4111-8111-111111111111','Spoof','contact','pill',6,gen_random_uuid(),'{"providers":[{"provider_key":"korek","destination_url":"tel:+9647501234567","enabled":true,"sort_order":0}]}');
 RAISE EXCEPTION 'RLS owner spoof accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
DO $$ DECLARE kind text; config jsonb;BEGIN
 FOR kind,config IN VALUES
  ('download','{"providers":[{"provider_key":"google_play","destination_url":"javascript:evil","enabled":true,"sort_order":0}]}'::jsonb),
  ('contact','{"providers":[{"provider_key":"talabat","destination_url":"https://talabat.com/test","enabled":true,"sort_order":0}]}'::jsonb),
  ('order','{"providers":[{"provider_key":"talabat","destination_url":"https://talabat.com.evil.example/test","enabled":true,"sort_order":0}]}'::jsonb),
  ('download','{"providers":[{"provider_key":"app_store","destination_url":"https://apps.apple.com/app/no-id","enabled":true,"sort_order":0}]}'::jsonb),
  ('contact','{"providers":[{"provider_key":"telegram","enabled":true,"sort_order":0}]}'::jsonb),
  ('contact','{"providers":[{"provider_key":"phone","destination_url":"tel:+9647501234567","enabled":true,"sort_order":0}]}'::jsonb)
 LOOP
  IF public.proxolink_v6_settings_valid(kind,config) IS DISTINCT FROM false THEN RAISE EXCEPTION 'invalid settings accepted';END IF;
 END LOOP;
END $$;
ROLLBACK;
SELECT 'VERIFIED: additive migration, legacy/ad preservation, database UUIDs, immutable identities, owner RLS, safe providers, archive boundary';
