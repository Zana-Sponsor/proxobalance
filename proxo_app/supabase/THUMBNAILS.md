# وێنۆچکەی ڕیکلامەکان

ڕێڕەوی production:

1. Flutter دوای دروستکردنی ڕیکلام، بەبێ ڕاگرتنی UI، `generate-ad-thumbnail`
   بانگ دەکات.
2. Edge Function ناسنامەی بەکارهێنەر و خاوەندارێتی ڕیکلامەکە پشتڕاست
   دەکاتەوە.
3. بەرگی ڤیدیۆ لە TikTok oEmbed وەردەگیرێت، پشکنینی جۆر/قەبارەی بۆ دەکرێت
   و بە پانی 360px و JPEG 78% ئامادە دەکرێت.
4. فایلەکە لە bucket ـی گشتی `ad-thumbnails` هەڵدەگیرێت؛ تەنها URL ـەکە
   لە `pa_ads.thumbnail_url` دادەنرێت.
5. Realtime تەنها کارتی پەیوەندیدار نوێ دەکاتەوە. لینکی نادروست، ڤیدیۆی
   private یان سڕاوە خانەی سپی و خڕ نیشان دەدات.

## Deploy

```bash
supabase functions deploy generate-ad-thumbnail
```

`--no-verify-jwt` بەکارمەهێنە. فەنکشنەکە هەم JWT و هەم `user_id`ی ڕیکلام
پشتڕاست دەکاتەوە. `fetch-tiktok-thumbnail` تەنها alias ـێکە بۆ وەشانە
کۆنەکانی ئەپ و Deployکردنی ئارەزوومەندانەیە؛ کۆدی نوێ تەنها
`generate-ad-thumbnail` بانگ دەکات.

هیچ secret ـێکی زیادە پێویست نییە. `SUPABASE_URL`، `SUPABASE_ANON_KEY` و
`SUPABASE_SERVICE_ROLE_KEY` لە ژینگەی Edge Functions ـدا بەکاردێن؛
`service_role` هەرگیز ناچێتە ناو Flutter.

لە یەکەم داواکاری، bucket ـی `ad-thumbnails` بە خۆکار دروست دەکرێت بە:

- public read (ثومبنەیلی TikTok داتای نهێنی نییە)
- تەنها `image/jpeg`
- سنووری 1MB بۆ هەر فایل
- cache ـی یەک ساڵ، لەگەڵ path ـی یەکتا بۆ هەر لینکی ڤیدیۆ

ئەگەر `pa_ads` پێشتر لە Realtime publication ـدا نەبێت، لە Dashboard ـی
Supabase لە **Database → Replication** چالاکی بکە. بەبێ Realtime ـیش URL
هەڵدەگیرێت و لە refresh ـی داهاتوودا پیشان دەدرێت.


## Canonical writer and retirement (2026-10-01)

`generate-ad-thumbnail` is the canonical implementation. The legacy alias
`fetch-tiktok-thumbnail` imports the same handler; it is not a second uploader.
Flutter invokes the canonical function after `pa_create_ad` completes, and on
missing/invalid thumbnail repair in the ad list and detail screen. The shared
Supabase client supplies the authenticated session; the server calls `getUser`
and checks `pa_ads.user_id` before privileged operations.

The supplied six-hour n8n thumbnail workflow is retired in
`n8n/workflows/Proxo_Thumbnail_Backfill_Retired.json`. This inactive, credential-free
export makes no network or database calls. Importing a file does not prove the
live workflow was deactivated: disable workflow `lzkAEAOYRZaoAr9M` in the real
n8n instance and verify no scheduled executions remain. Unrelated FastPay,
metrics, and campaign workflows must remain unchanged. Do not pass a service-role
key to the owner-authenticated endpoint as a substitute for a user session.
The original thumbnail workflow contained a hardcoded privileged credential;
rotate it through a coordinated credential migration. Never paste it into source.

## Binary and integrity checks

Sources: at most 8 MiB, JPEG/PNG/WebP magic bytes, declared MIME comparison,
successful decode, positive dimensions, at most 16 Mi pixels. WebP decoding uses
the bundled pinned @jsquash/webp 1.5.0 WASM decoder (Apache-2.0), because
ImageScript 1.2.15 only encodes WebP and does not decode it.
Output: binary Uint8Array JPEG, width at most 360px, quality 78, at most 1 MiB.
Storage download is decoded and checked before publishing; fresh upload bytes
must match exactly. Existing paths are checked before reuse. Corrupt deterministic
collisions receive a random version suffix. Objects are scoped by user/ad/video
hash. No automatic object deletion occurs, including failed/racing updates.

The database update compares the original video_link and thumbnail_url as well
as ID/owner. An in-flight result cannot overwrite a newly edited video or newer
thumbnail. Existing database video-change invalidation is preserved. AdScreen
clears its local preview and queues generation after a video-link edit; realtime
missing-thumbnail updates also queue generation. Failure releases the in-flight
guard so a subsequent refresh can retry. No card geometry/fallback design changed.

## Verification limits

Local tests cover binary generation, corrupt object reuse/collisions, ownership,
JSON rejection, and stale-video update prevention with mocked network/auth/storage.
A live owner-authenticated TikTok generation test and a Flutter device run are
still required. A Supabase dashboard login is not an app user's access token.
