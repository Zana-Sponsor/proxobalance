-- Retire v4 only after the v5 production deployment and customer pages pass verification.
DELETE FROM public.proxolink_templates WHERE template_key IN ('pill','pill-mint','pill-dark','pill-white') AND version=4;
