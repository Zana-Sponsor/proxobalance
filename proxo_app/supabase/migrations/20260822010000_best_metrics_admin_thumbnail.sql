-- Best Metrics thumbnails — admin-supplied model.
-- (Already applied to the live database.)
--
-- Automatic TikTok generation was tested and is not achievable server-side:
-- TikTok blocks datacenter IPs on every route (oembed -> HTML shell,
-- canonical page -> no og:image, api/img -> 403). Thumbnails are set by the
-- admin when featuring an ad.
--
-- No new column. pa_ads.thumbnail_url accepts BOTH shapes the app renders:
--     data:image/<type>;base64,....   (uploaded image)
--     https://....                    (Storage / CDN link)

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pa_ads_thumbnail_url_shape_chk'
  ) then
    alter table public.pa_ads
      add constraint pa_ads_thumbnail_url_shape_chk
      check (
        thumbnail_url is null
        or thumbnail_url = ''
        or thumbnail_url like 'data:image/%;base64,%'
        or thumbnail_url like 'https://%'
      )
      not valid;
  end if;
end $$;

comment on column public.pa_ads.thumbnail_url is
  'Best Metrics thumbnail, set by the admin when featuring an ad. Either a '
  'data:image/<t>;base64,... payload (uploaded image, keep under ~400KB) or '
  'an https:// URL. Cleared automatically when video_link changes.';

-- The video_link guard trigger from 20260822000000 is retained unchanged.
