-- Disposable test database ONLY. Mimics the existing V5 ownership/identity contract.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
GRANT USAGE ON SCHEMA auth TO anon,authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon,authenticated;
INSERT INTO auth.users VALUES ('11111111-1111-4111-8111-111111111111'),('99999999-9999-4999-8999-999999999999');
CREATE TABLE public.proxolink_cards(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id),
 name text NOT NULL,bio text,tt text,tiktok text,description text,platforms jsonb NOT NULL DEFAULT '{}',
 style text NOT NULL DEFAULT 'classic',template_key text,template_version integer NOT NULL DEFAULT 1,
 color_theme text,card_language text DEFAULT 'ku',page_type text NOT NULL DEFAULT 'contact' CHECK(page_type IN ('contact','food','download')),
 avatar_path text,status text DEFAULT 'inactive',publish_status text DEFAULT 'creating',card_number serial NOT NULL,
 created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now(),published_at timestamptz,
 client_request_id uuid,creation_request_hash text,last_publish_error_code text,last_publish_error_at timestamptz,
 UNIQUE(user_id,client_request_id)
);
ALTER TABLE public.proxolink_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cards own all" ON public.proxolink_cards FOR ALL TO authenticated USING(auth.uid()=user_id) WITH CHECK(auth.uid()=user_id);
-- Exercise restrictive V6 ownership even with a permissive privileged legacy policy.
CREATE POLICY "fixture legacy admin" ON public.proxolink_cards FOR ALL TO authenticated USING(current_setting('request.test_admin',true)='true') WITH CHECK(current_setting('request.test_admin',true)='true');
GRANT SELECT,INSERT,UPDATE,DELETE ON public.proxolink_cards TO authenticated;
GRANT USAGE ON SEQUENCE proxolink_cards_card_number_seq TO authenticated;
CREATE TABLE public.pa_ads(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid REFERENCES auth.users(id),card_id uuid REFERENCES public.proxolink_cards(id),asset_id uuid,status text);
CREATE TABLE public.proxolink_publish_attempts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),card_id uuid,user_id uuid,operation text,result text,error_code text);
INSERT INTO public.proxolink_cards(id,user_id,name,status,publish_status,platforms) VALUES
 ('22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111','Legacy preserved','active','ready','{"wa":"9647501234567","tg":"historical"}');
INSERT INTO public.pa_ads(user_id,card_id,asset_id,status) VALUES
 ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222','active');
CREATE TABLE public.v6_legacy_snapshot AS SELECT id,to_jsonb(c) data FROM public.proxolink_cards c;
CREATE TABLE public.v6_ad_snapshot AS SELECT id,to_jsonb(a) data FROM public.pa_ads a;
