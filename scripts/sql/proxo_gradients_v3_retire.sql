-- Run only after the v3 production renderer and all customer pages are verified.
-- Card IDs, contact values, profile data and ad relationships are not changed.
DELETE FROM public.proxolink_templates WHERE template_key IN ('pill','pill-mint','pill-dark','pill-white') AND version=2;
