-- ═══════════════════════════════════════════════════════════════════════════
-- باشترین ئامارەکان / Best Metrics — admin curation support
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠ ئەم مایگرەیشنە **پێشتر لەسەر داتابەیسی ژیندوو جێبەجێ کراوە**
--   (`best_metrics_curation_support`). ئەم فایلە کۆپی مێژووییەکەیە بۆ
--   ئەوەی مێژووی پڕۆژەکە و داتابەیسەکە یەک بن.
--
-- ── ئەوەی پێشتر هەبوو (پشکنراوە، نەک مەزەندەکراو) ──────────────────────────
--   pa_ads.is_featured    boolean default false
--   pa_ads.thumbnail_url  text
--   + ڕێسای RLS کە ڕێگا بە هەموو بەکارهێنەرێک دەدات ڕیکلامی
--     هەڵبژێردراو ببینێت (یەکێکیان بە ناوی
--     «هەموو کەس باشترین ئامارەکان ببین»).
--
-- بۆیە هیچ خانەیەکی «selected» یان «thumbnail»ـی نوێ دروست نەکراوە —
-- تەنها ئەوەی بەڕاستی کەم بوو زیادکراوە: ماوە و ڕیزبەندی.

alter table public.pa_ads
  add column if not exists featured_month smallint,
  add column if not exists featured_year  smallint,
  add column if not exists featured_sort  integer;

comment on column public.pa_ads.featured_month is
  'Best Metrics: calendar month (1-12) this ad is curated for. Set by admin.';
comment on column public.pa_ads.featured_year is
  'Best Metrics: calendar year this ad is curated for. Set by admin.';
comment on column public.pa_ads.featured_sort is
  'Best Metrics: admin ordering inside the month. Ascending, nulls last.';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pa_ads_featured_month_chk'
  ) then
    alter table public.pa_ads
      add constraint pa_ads_featured_month_chk
      check (featured_month is null or featured_month between 1 and 12);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'pa_ads_featured_year_chk'
  ) then
    alter table public.pa_ads
      add constraint pa_ads_featured_year_chk
      check (featured_year is null or featured_year between 2000 and 2200);
  end if;
end $$;

-- دەقاودەق شێوەی ئەو داواکارییەی ئەپەکە دەیکات.
create index if not exists pa_ads_best_metrics_idx
  on public.pa_ads (featured_year, featured_month, featured_sort, created_at desc)
  where is_featured;

-- ── دوو ئۆتۆماتیکی بچووک ────────────────────────────────────────────────────
--  ١. ئەگەر ئەدمین تەنها `is_featured` هەڵبکات، مانگ و ساڵ بە ئێستا
--     پڕدەکرێنەوە — بۆیە پانێلی ئەدمین هیچ گۆڕانێکی پێویست نییە.
--  ٢. ئەگەر `video_link` بگۆڕێت، `thumbnail_url` پووچ دەکرێتەوە. ئەمە
--     جێبەجێکردنی «دووبارە دروستی بکە کاتێک لینکی ڤیدیۆ گۆڕا»یە بەبێ
--     خانەیەکی زیادەی hash.
create or replace function public.pa_ads_best_metrics_guard()
returns trigger
language plpgsql
as $$
begin
  if new.is_featured is true
     and (new.featured_month is null or new.featured_year is null) then
    new.featured_month := extract(month from now())::smallint;
    new.featured_year  := extract(year  from now())::smallint;
  end if;

  if tg_op = 'UPDATE'
     and new.video_link is distinct from old.video_link then
    new.thumbnail_url := null;
  end if;

  return new;
end;
$$;

drop trigger if exists pa_ads_best_metrics_guard_trg on public.pa_ads;
create trigger pa_ads_best_metrics_guard_trg
  before insert or update on public.pa_ads
  for each row execute function public.pa_ads_best_metrics_guard();

-- ── چۆن ئەدمین ڕیکلامێک هەڵدەبژێرێت ────────────────────────────────────────
--   update public.pa_ads
--      set is_featured   = true,
--          featured_year = 2026,
--          featured_month = 8,
--          featured_sort = 1
--    where id = '<uuid>';
