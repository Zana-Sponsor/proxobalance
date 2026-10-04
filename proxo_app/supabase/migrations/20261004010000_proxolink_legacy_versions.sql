-- Historical CSS revisions remain private and pinned to their original cards.
-- They never replace the eight immutable v1 catalog templates.
alter table public.proxolink_templates add column if not exists renderer_options jsonb not null default '{}'::jsonb;
alter table public.proxolink_templates drop constraint if exists proxolink_templates_renderer_variant_check;
alter table public.proxolink_templates add constraint proxolink_templates_renderer_variant_check
  check(renderer_variant in ('standard','legacy_dark_inline','legacy_standard'));
alter table public.proxolink_templates add constraint proxolink_renderer_options_object_check
  check(jsonb_typeof(renderer_options)='object');
