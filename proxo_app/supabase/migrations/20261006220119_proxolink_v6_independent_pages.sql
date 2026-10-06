-- V6 is additive. NULL page_kind is the explicit legacy /contact adapter.
-- This migration does not update/delete cards, advertisements or template rows.
ALTER TABLE public.proxolink_cards ADD COLUMN IF NOT EXISTS page_kind text;
ALTER TABLE public.proxolink_cards ADD COLUMN IF NOT EXISTS settings jsonb;
ALTER TABLE public.proxolink_cards ADD COLUMN IF NOT EXISTS archived_at timestamptz;

CREATE OR REPLACE FUNCTION public.proxolink_v6_settings_valid(kind text, config jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE p jsonb; k text; u text; host text; orders integer[] := '{}'; keys text[] := '{}'; n integer; enabled_count integer := 0;
BEGIN
  IF kind NOT IN ('contact','order','download') OR config IS NULL OR jsonb_typeof(config) <> 'object'
    OR NOT config ? 'providers' OR (config - 'providers') <> '{}'::jsonb
    OR jsonb_typeof(config->'providers') <> 'array' OR jsonb_array_length(config->'providers') > 12 THEN RETURN false; END IF;
  FOR p IN SELECT value FROM jsonb_array_elements(config->'providers') LOOP
    IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR NOT p ?& ARRAY['provider_key','destination_url','enabled','sort_order'] OR (p - ARRAY['provider_key','destination_url','enabled','sort_order']) <> '{}'::jsonb
      OR jsonb_typeof(p->'provider_key') <> 'string' OR jsonb_typeof(p->'destination_url') <> 'string'
      OR jsonb_typeof(p->'enabled') <> 'boolean' OR jsonb_typeof(p->'sort_order') <> 'number'
      OR (p->>'sort_order') !~ '^[0-9]{1,3}$' THEN RETURN false; END IF;
    k := p->>'provider_key'; u := p->>'destination_url'; n := (p->>'sort_order')::integer;
    IF n > 100 OR n = ANY(orders) OR k = ANY(keys) OR length(u) > 2048
      OR u ~ '[[:cntrl:]<>\\]' OR u ~* '%(00|0a|0d|3c|3e|5c)' THEN RETURN false; END IF;
    keys := array_append(keys,k); orders := array_append(orders,n);
    IF (p->>'enabled')::boolean THEN enabled_count := enabled_count + 1; END IF;
    IF kind = 'contact' THEN
      CASE k
        WHEN 'whatsapp' THEN IF u !~ '^https://wa[.]me/[1-9][0-9]{7,14}/?([?]text=[^#]*)?$' THEN RETURN false; END IF;
        WHEN 'viber' THEN IF u !~ '^viber://chat[?]number=%2B[1-9][0-9]{7,14}$' THEN RETURN false; END IF;
        WHEN 'korek','asiacell' THEN IF u !~ '^tel:[+][1-9][0-9]{7,14}$' THEN RETURN false; END IF;
        WHEN 'telegram' THEN IF u !~ '^https://t[.]me/[A-Za-z][A-Za-z0-9_]{3,31}$' THEN RETURN false; END IF;
        WHEN 'instagram' THEN IF u !~ '^https://www[.]instagram[.]com/[A-Za-z0-9._]{1,30}$' THEN RETURN false; END IF;
        ELSE RETURN false;
      END CASE;
    ELSIF kind = 'order' THEN
      IF u !~ '^https://[A-Za-z0-9.-]+/[^#]+' THEN RETURN false; END IF;
      host := substring(u FROM '^https://([A-Za-z0-9.-]+)/');
      CASE k
        WHEN 'talabat' THEN IF host !~ '(^|[.])talabat[.]com$' THEN RETURN false; END IF;
        WHEN 'toters' THEN IF host !~ '(^|[.])(totersapp[.]com|toters[.]com)$' THEN RETURN false; END IF;
        WHEN 'lezzoo' THEN IF host !~ '(^|[.])(lezzoo[.]com|lezzoodevs[.]com)$' THEN RETURN false; END IF;
        WHEN 'wade' THEN IF host !~ '(^|[.])(wadedelivery[.]com|trytiptop[.]com)$' THEN RETURN false; END IF;
        ELSE RETURN false;
      END CASE;
    ELSE
      CASE k
        WHEN 'google_play' THEN IF u !~ '^https://play[.]google[.]com/store/apps/details/?[?]id=[A-Za-z][A-Za-z0-9_]*([.][A-Za-z][A-Za-z0-9_]*)+(&(hl|gl)=[A-Za-z_-]+)*$' THEN RETURN false; END IF;
        WHEN 'app_store' THEN IF u !~ '^https://apps[.]apple[.]com/([a-z]{2}/)?app/([^/?#]+/)?id[1-9][0-9]*/?([?](mt|l|platform|ct|pt)=[A-Za-z0-9_%.-]+(&(mt|l|platform|ct|pt)=[A-Za-z0-9_%.-]+)*)?$' THEN RETURN false; END IF;
        ELSE RETURN false;
      END CASE;
    END IF;
  END LOOP;
  RETURN enabled_count > 0;
EXCEPTION WHEN OTHERS THEN RETURN false;
END;
$$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='proxolink_v6_record_valid' AND conrelid='public.proxolink_cards'::regclass) THEN
    ALTER TABLE public.proxolink_cards ADD CONSTRAINT proxolink_v6_record_valid CHECK (
      page_kind IS NULL OR (
        page_kind IN ('contact','order','download') AND id <> user_id
        AND client_request_id IS NOT NULL AND id <> client_request_id AND user_id <> client_request_id
        AND public.proxolink_v6_settings_valid(page_kind,settings)
        AND template_key IN ('pill','pill-mint','pill-dark','pill-white') AND template_version = 6
        AND length(btrim(name)) BETWEEN 1 AND 160 AND (bio IS NULL OR length(bio)<=2000)
        AND card_language IN ('ku','ar','en')
        AND (avatar_path IS NULL OR (length(avatar_path)<=200 AND split_part(avatar_path,'/',1)=user_id::text
          AND split_part(avatar_path,'/',2) IN (id::text,client_request_id::text)
          AND avatar_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[A-Za-z0-9_-]+[.](webp|jpe?g|png)$'))
      )
    ) NOT VALID;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.proxolink_v6_identity_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF OLD.page_kind IS NOT NULL OR NEW.page_kind IS NOT NULL THEN
    IF OLD.id IS DISTINCT FROM NEW.id OR OLD.user_id IS DISTINCT FROM NEW.user_id
      OR OLD.page_kind IS DISTINCT FROM NEW.page_kind OR OLD.client_request_id IS DISTINCT FROM NEW.client_request_id THEN
      RAISE EXCEPTION 'ProxoLink page identity is immutable' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='proxolink_v6_identity_immutable' AND tgrelid='public.proxolink_cards'::regclass) THEN
    CREATE TRIGGER proxolink_v6_identity_immutable BEFORE UPDATE ON public.proxolink_cards
      FOR EACH ROW EXECUTE FUNCTION public.proxolink_v6_identity_guard();
  END IF;
END $$;
ALTER TABLE public.proxolink_cards ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='proxolink_cards' AND policyname='V6 owner boundary') THEN
    CREATE POLICY "V6 owner boundary" ON public.proxolink_cards AS RESTRICTIVE FOR ALL TO authenticated
      USING (page_kind IS NULL OR auth.uid() = user_id)
      WITH CHECK (page_kind IS NULL OR auth.uid() = user_id);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS proxolink_v6_owner_type_idx ON public.proxolink_cards(user_id,page_kind,created_at DESC)
  WHERE page_kind IS NOT NULL AND archived_at IS NULL;
REVOKE ALL ON FUNCTION public.proxolink_v6_identity_guard() FROM PUBLIC;
-- CHECK evaluation is safe/invoker-only: no SECURITY DEFINER or network calls.

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='proxolink_cards' AND policyname='V6 archive instead of delete') THEN
    CREATE POLICY "V6 archive instead of delete" ON public.proxolink_cards AS RESTRICTIVE FOR DELETE TO authenticated USING (page_kind IS NULL);
  END IF;
END $$;
