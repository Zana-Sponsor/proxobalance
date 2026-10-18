-- Reuse the existing public-read, administrator-write settings table.
-- Empty values mean the administrator has not published a tutorial yet.
-- Preserve any existing configured links on rerun.
insert into public.pa_settings (key, value) values
  ('tutorial_ad_video_code_url', ''),
  ('tutorial_ad_video_link_url', ''),
  ('tutorial_page_creation_url', '')
on conflict (key) do nothing;
