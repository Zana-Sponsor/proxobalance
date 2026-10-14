-- Disposable database only. Fictional IDs; no production data or credentials.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
GRANT USAGE ON SCHEMA auth TO authenticated,anon,service_role;
CREATE FUNCTION public.pa_is_admin() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT current_setting('request.test_admin',true)='true' $$;
CREATE TABLE public.pa_ads(id uuid PRIMARY KEY,user_id uuid,title text,video_code text,video_link text,goal text,gender text,location text,start_date date,start_time time,status text,budget numeric,needs_update boolean,update_field text,update_reason text,update_requested_at timestamptz,update_submitted_at timestamptz,updated_at timestamptz);
ALTER TABLE public.pa_ads ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_ads ON public.pa_ads FOR ALL TO authenticated USING(user_id=auth.uid()) WITH CHECK(user_id=auth.uid());
GRANT SELECT,UPDATE ON public.pa_ads TO authenticated;
CREATE TABLE public.pa_notifications(id uuid PRIMARY KEY,user_id uuid,type text,meta jsonb,is_read boolean,created_at timestamptz,updated_at timestamptz);
ALTER TABLE public.pa_notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_notifications ON public.pa_notifications FOR ALL TO authenticated USING(user_id=auth.uid()) WITH CHECK(user_id=auth.uid());
GRANT SELECT,UPDATE,DELETE ON public.pa_notifications TO authenticated;
INSERT INTO public.pa_ads(id,user_id,title,status,budget,needs_update,update_field) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Before','pending',100,true,'title'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Other','pending',100,true,'title'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','11111111-1111-4111-8111-111111111111','Scheduled','pending',100,true,'start_date');
INSERT INTO public.pa_notifications VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','11111111-1111-4111-8111-111111111111','general','{}',false,now(),now());
