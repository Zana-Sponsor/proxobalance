-- Phase 2: run after preview API, browser and Flutter verification.
-- Keep card IDs, owners, profile data, phone/link values and ad relationships.
CREATE SCHEMA IF NOT EXISTS proxo_release_backup;
REVOKE ALL ON SCHEMA proxo_release_backup FROM PUBLIC,anon,authenticated;
CREATE TABLE proxo_release_backup.cards_before_four AS SELECT * FROM public.proxolink_cards;
CREATE TABLE proxo_release_backup.templates_before_four AS SELECT * FROM public.proxolink_templates;
CREATE TABLE proxo_release_backup.ad_card_relationships_before_four AS SELECT id,user_id,card_id,asset_id FROM public.pa_ads;
REVOKE ALL ON ALL TABLES IN SCHEMA proxo_release_backup FROM PUBLIC,anon,authenticated;
ALTER TABLE proxo_release_backup.cards_before_four ENABLE ROW LEVEL SECURITY;
ALTER TABLE proxo_release_backup.templates_before_four ENABLE ROW LEVEL SECURITY;
ALTER TABLE proxo_release_backup.ad_card_relationships_before_four ENABLE ROW LEVEL SECURITY;
UPDATE public.proxolink_cards SET
  template_key=CASE coalesce(template_key,style)
    WHEN 'dark' THEN 'pill-dark' WHEN 'neon' THEN 'pill-mint'
    WHEN 'zoom' THEN 'pill' WHEN 'banner' THEN 'pill' WHEN 'pill' THEN 'pill'
    WHEN 'pill-mint' THEN 'pill-mint' WHEN 'pill-dark' THEN 'pill-dark'
    ELSE 'pill-white' END,
  template_version=2,publish_status='ready',last_publish_error_code=NULL,last_publish_error_at=NULL,
  published_at=coalesce(published_at,now())
WHERE NOT(template_version=2 AND template_key IS NOT NULL AND template_key IN ('pill','pill-mint','pill-dark','pill-white'));
UPDATE public.proxolink_cards SET style=template_key WHERE style IS DISTINCT FROM template_key;
-- The old eight template definitions are retired; no user-owned card is deleted.
DELETE FROM public.proxolink_templates WHERE NOT(template_key IN ('pill','pill-mint','pill-dark','pill-white') AND version=2);
ALTER TABLE public.proxolink_templates DROP CONSTRAINT proxolink_templates_template_key_check;
ALTER TABLE public.proxolink_templates ADD CONSTRAINT proxolink_templates_template_key_check CHECK(template_key IN ('pill','pill-mint','pill-dark','pill-white'));
ALTER TABLE public.proxolink_templates DROP CONSTRAINT proxolink_templates_renderer_variant_check;
ALTER TABLE public.proxolink_templates ADD CONSTRAINT proxolink_templates_renderer_variant_check CHECK(renderer_variant='standard');
