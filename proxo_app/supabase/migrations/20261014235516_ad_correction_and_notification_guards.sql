-- Reviewed source for a CLI-generated migration. Apply to an isolated database
-- first. This repository's workflow never links to a hosted Supabase project.
BEGIN;
CREATE OR REPLACE FUNCTION public.submit_ad_update(p_ad_id uuid,p_field text,p_value text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_ad public.pa_ads%ROWTYPE;
  v_value text := btrim(p_value);
  v_patch jsonb;
  v_now timestamptz := now();
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication_required' USING ERRCODE='42501'; END IF;
  IF p_field IS NULL OR NOT (p_field = ANY(ARRAY['video_code','video_link','title','goal','gender','location','start_date','start_time'])) THEN
    RAISE EXCEPTION 'unsupported_correction_field' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_ad FROM public.pa_ads WHERE id=p_ad_id AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ad_not_found' USING ERRCODE='42501'; END IF;
  IF NOT coalesce(v_ad.needs_update,false) OR v_ad.update_field IS DISTINCT FROM p_field THEN
    RAISE EXCEPTION 'correction_not_requested' USING ERRCODE='42501';
  END IF;
  IF v_ad.update_submitted_at IS NOT NULL THEN RAISE EXCEPTION 'correction_already_submitted' USING ERRCODE='55000'; END IF;
  IF v_value IS NULL OR v_value='' OR length(v_value)>4000 THEN RAISE EXCEPTION 'invalid_correction_value' USING ERRCODE='22023'; END IF;
  IF (p_field='goal' AND v_value NOT IN ('messages','engagement','views'))
     OR (p_field='gender' AND v_value NOT IN ('all','male','female'))
     OR (p_field='location' AND v_value NOT IN ('all','kurdistan','iraq'))
     OR (p_field='video_link' AND v_value !~ '^https://[^[:space:]/]+[.][^[:space:]]+') THEN
    RAISE EXCEPTION 'invalid_correction_value' USING ERRCODE='22023';
  END IF;
  -- jsonb_populate_record applies each existing column's actual SQL type,
  -- including DATE/TIME. No client-supplied identifier reaches SQL unchecked.
  v_patch := jsonb_build_object(p_field,v_value,'status','review',
    'update_submitted_at',v_now,'updated_at',v_now);
  EXECUTE format('UPDATE public.pa_ads AS a SET %1$I=(jsonb_populate_record(NULL::public.pa_ads,$1)).%1$I, status=''review'', update_submitted_at=$2, updated_at=$2 WHERE a.id=$3',p_field)
    USING v_patch,v_now,p_ad_id;
  RETURN jsonb_build_object('ok',true,'patch',v_patch);
END;
$$;
REVOKE ALL ON FUNCTION public.submit_ad_update(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_ad_update(uuid,text,text) TO authenticated,service_role;

-- RLS controls whose row is visible; these invoker triggers additionally
-- protect server-controlled columns. Existing privileged RPCs remain usable.
CREATE OR REPLACE FUNCTION public.pa_guard_client_ad_write()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_user IN ('postgres','service_role','supabase_admin') OR public.pa_is_admin() THEN RETURN NEW; END IF;
  IF to_jsonb(NEW) IS DISTINCT FROM to_jsonb(OLD) THEN
    RAISE EXCEPTION 'ad_changes_require_authorized_rpc' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS pa_guard_client_ad_write ON public.pa_ads;
CREATE TRIGGER pa_guard_client_ad_write BEFORE UPDATE ON public.pa_ads
  FOR EACH ROW EXECUTE FUNCTION public.pa_guard_client_ad_write();

CREATE OR REPLACE FUNCTION public.pa_guard_notification_content()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_user IN ('postgres','service_role','supabase_admin') OR public.pa_is_admin() THEN RETURN NEW; END IF;
  IF (to_jsonb(NEW)-ARRAY['is_read','updated_at']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['is_read','updated_at']) THEN
    RAISE EXCEPTION 'notification_content_is_server_owned' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS pa_guard_notification_content ON public.pa_notifications;
CREATE TRIGGER pa_guard_notification_content BEFORE UPDATE ON public.pa_notifications
  FOR EACH ROW EXECUTE FUNCTION public.pa_guard_notification_content();
REVOKE ALL ON FUNCTION public.pa_guard_client_ad_write() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.pa_guard_notification_content() FROM PUBLIC,anon,authenticated;
COMMIT;
