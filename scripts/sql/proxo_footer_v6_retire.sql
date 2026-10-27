-- Retire v5 only after the v6 production renderer has been verified.
DELETE FROM public.proxolink_templates WHERE template_key IN ('pill','pill-mint','pill-dark','pill-white') AND version=5;
