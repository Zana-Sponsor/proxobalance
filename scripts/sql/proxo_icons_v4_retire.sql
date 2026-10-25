-- Run after all 21 live pages serve the verified v4 renderer.
-- No customer cards or advertisement rows are modified.
DELETE FROM public.proxolink_templates WHERE template_key IN ('pill','pill-mint','pill-dark','pill-white') AND version=3;
