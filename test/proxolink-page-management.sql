\set ON_ERROR_STOP on
-- Disposable database only. Legacy rows and advertisement references unchanged.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.proxolink_cards c JOIN public.v6_legacy_snapshot s USING(id)
   WHERE to_jsonb(c)-ARRAY['page_kind','settings','archived_at']<>s.data) THEN RAISE EXCEPTION 'legacy changed'; END IF;
 IF EXISTS(SELECT 1 FROM public.pa_ads a JOIN public.v6_ad_snapshot s USING(id)
   WHERE to_jsonb(a)<>s.data) THEN RAISE EXCEPTION 'ads changed'; END IF;
 IF has_table_privilege('anon','public.proxolink_cards','SELECT') OR
   has_table_privilege('anon','public.proxolink_cards','INSERT') THEN RAISE EXCEPTION 'anon management grant'; END IF;
 IF has_function_privilege('authenticated','public.proxolink_v6_management_guard()','EXECUTE') OR
   has_function_privilege('anon','public.proxolink_v6_management_guard()','EXECUTE') THEN RAISE EXCEPTION 'trigger execution grant'; END IF;
END $$;
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
INSERT INTO public.proxolink_cards(id,user_id,name,page_kind,template_key,template_version,client_request_id,settings)
VALUES(auth.uid(),auth.uid(),'Generated','contact','pill',6,gen_random_uuid(),
 '{"providers":[{"provider_key":"telegram","destination_url":"https://t.me/proxo_iq","enabled":true,"sort_order":0}]}'),
 (auth.uid(),auth.uid(),'Another','contact','pill',6,gen_random_uuid(),
 '{"providers":[{"provider_key":"whatsapp","destination_url":"https://wa.me/9647501234567","enabled":true,"sort_order":0}]}');
DO $$ DECLARE before_id uuid; before_time timestamptz; n int; BEGIN
 SELECT id,updated_at INTO before_id,before_time FROM public.proxolink_cards WHERE name='Generated';
 IF before_id=auth.uid() THEN RAISE EXCEPTION 'client UUID accepted'; END IF;
 SELECT count(DISTINCT id) INTO n FROM public.proxolink_cards WHERE page_kind='contact';
 IF n<>2 THEN RAISE EXCEPTION 'multiple pages lost'; END IF;
 UPDATE public.proxolink_cards SET name='Edited' WHERE id=before_id;
 IF NOT EXISTS(SELECT 1 FROM public.proxolink_cards WHERE id=before_id AND name='Edited' AND updated_at>before_time) THEN RAISE EXCEPTION 'edit UUID/timestamp'; END IF;
 BEGIN UPDATE public.proxolink_cards SET created_at=now()-interval '1 year' WHERE id=before_id;
   RAISE EXCEPTION 'created_at mutation'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN UPDATE public.proxolink_cards SET page_kind='order' WHERE id=before_id;
   RAISE EXCEPTION 'type mutation'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN UPDATE public.proxolink_cards SET user_id='99999999-9999-4999-8999-999999999999' WHERE id=before_id;
   RAISE EXCEPTION 'owner mutation'; EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE public.proxolink_cards SET archived_at=clock_timestamp(),status='inactive' WHERE id=before_id;
 BEGIN UPDATE public.proxolink_cards SET archived_at=NULL WHERE id=before_id;
   RAISE EXCEPTION 'unarchive mutation'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN INSERT INTO public.proxolink_cards(user_id,name,page_kind,template_key,template_version,client_request_id,settings)
   VALUES(auth.uid(),'Unsupported','order','pill',6,gen_random_uuid(),
   '{"providers":[{"provider_key":"lezzoo","destination_url":"https://lezzoo.com/restaurant/test","enabled":true,"sort_order":0}]}');
   RAISE EXCEPTION 'new unsupported provider'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
SET LOCAL request.jwt.claim.sub='99999999-9999-4999-8999-999999999999';
SET LOCAL request.test_admin='true';
DO $$ DECLARE n int; BEGIN
 IF EXISTS(SELECT 1 FROM public.proxolink_cards WHERE page_kind IS NOT NULL) THEN RAISE EXCEPTION 'cross-owner read'; END IF;
 UPDATE public.proxolink_cards SET archived_at=clock_timestamp(),status='inactive' WHERE page_kind IS NOT NULL;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'cross-owner archive'; END IF;
END $$;
ROLLBACK;
SELECT 'VERIFIED: database-generated UUIDs, multiple pages, stable edits, owner isolation, timestamps, immutable archive, strict new providers and grants';
