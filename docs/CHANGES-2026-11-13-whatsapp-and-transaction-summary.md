# تۆماری گۆڕانکارییەکان — Proxo Balance

**ماوە:** ١٣ تا ١٤ی تشرینی دووەمی ٢٠٢٦
**کات:** هەموو کاتەکان بە کاتی بەغدان (UTC+3).
**پڕۆژەی Supabase:** `Exchange` (`pycxuugoblkslvwebxuu`). هیچ پڕۆژەیەکی نوێ دروست نەکراوە.
**n8n:** workflow ـی `Wevlix - OTP (Send / Status / Verify via Supabase)` (`P94cdiTilUPThRg8`).
**دەستکاری نەکراون:** فۆڵدەری `proxo_app` و نرخ و کرێکان.

---

## پوختەی خێرا

| بەروار و کات | وەشان | گۆڕانکاری | شوێن |
|---|---|---|---|
| 2026-11-13 23:42 | v17 | دیزاینی هاوسەنگی کارتی مامەڵە، پوختەی مامەڵە و هەڵسەنگاندن | `index.html`، `assets/js/app.js`، `assets/css/transaction-summary.css` |
| 2026-11-13 23:51 | v18 | جیاکردنەوەی سەردێر و ناونیشان و دەق، و ڕێزبەندی بەشەکانی پوختە | `assets/js/app.js`، `assets/css/transaction-summary.css`، `index.html` |
| 2026-11-13 23:59 | v19 | Supabase: ئاگاداری واتسئاپ بۆ پەسەندکردنی داواکاری | migration `ex_whatsapp_order_notifications` |
| 2026-11-14 00:04 | v19 | n8n: ناردنی نامەی پەسەندکردن لە ڕێگەی Wevlix | workflow `P94cdiTilUPThRg8` |
| 2026-11-14 00:05 | v19 | دوگمەی چالاککردنی ئاگاداری واتسئاپ و bottom sheet ـی ژمارە لە پڕۆفایل | `index.html`، `assets/js/whatsapp-notify.js` (نوێ)، `assets/css/whatsapp-notify.css` (نوێ)، `assets/js/app.js` |
| 2026-11-14 00:08 | v19 | خاوەنی پڕۆژە v19 ـی خستە سەر GitHub | commit `7d1841e` |
| 2026-11-14 00:10 | — | یەکەم نامەی ڕاستەقینە نێردرا و گەیشت (داواکاری `PJ65G3NHGWLL`) | — |
| 2026-11-14 00:20 | v20 | Supabase: فەنکشنەکانی لۆگی واتسئاپ بۆ پانێڵی ئادمین | migration `ex_admin_whatsapp_log` |
| 2026-11-14 00:40 | v20 | پوختەی مامەڵە بوو بە سکرینێکی ناو ئەپ، و پەڕەی «نامەکانی واتسئاپ» لە پانێڵ زیاد کرا | commit `8da89d4` (٩ فایل، بڕوانە خوارەوە) |
| 2026-11-14 00:55 | v21 | Supabase: ئاگاداری ڕەتکردنەوەی داواکاری، و خشتەی قاڵبەکان | migration `ex_whatsapp_order_rejected` |
| 2026-11-14 00:56 | v21 | n8n: ناردنی گشتی هەموو قاڵبەکان، و پشکنینی دۆخی قاڵبەکان هەر ١٥ خولەک | workflow `P94cdiTilUPThRg8` |
| 2026-11-14 00:56 | v21 | پانێڵ: ستوونی «جۆر» و دۆخی قاڵبەکان | commit `50c20ce`: `assets/js/exchange-whatsapp-admin.js`، `exchange-admin.html` |

---

## ١. دیزاینی پوختەی مامەڵە (v17 و v18)

**بەروار:** 2026-11-13، کاتژمێر 23:42 (v17) و 23:51 (v18)

**فایلەکان:**
- `assets/js/app.js`:
  - `tfHeroHTML`، `tfCodeHTML`، `tfRouteHTML`، `tfRow`، `tfSection`
  - `tfSplitOf`، `tfSplitRows`
  - `renderTransactionSummary`، `openTxDetail`
  - `orderCardHTML`، `fbFlatHTML`
- `assets/css/transaction-summary.css`: بە تەواوی دووبارە نووسراوەتەوە.
- `index.html`: ژمارەی وەشانی فایلەکانی CSS و JS نوێ کراونەتەوە.

**چی گۆڕا:**
- **بەشی سەرەوە:** ئایکۆنی دۆخ، ناونیشان، بڕی سەرەکی و نیشانەی دۆخ لە ناوەڕاستدان.
- **بەشەکان بە ڕیز:**
  1. «وردەکاری بڕ»: بڕی نێردراو، کرێی خزمەتگوزاری، بڕی داشکاندن، کۆی گشتی دوای کرێ.
  2. «دابەشکردنی بڕ»: بڕی نێردراو بۆ وەرگر، بڕی گەڕاوە بۆ باڵانس.
  3. «زانیاری مامەڵە».
  4. تێبینییەکان.
  5. هەڵسەنگاندن.
  6. پسووڵەی گەیاندن.
- **یاسای پاشماوە:** هەر بڕێک لە ١٠٠٠ دینار کەمتر بێت دەگەڕێتەوە بۆ باڵانسی کڕیار (`ProxoPayoutRounding`). نموونە: ١٠,٠٠٠ − کرێی ٢٠٠ = ٩,٨٠٠؛ لەوە ٩,٠٠٠ دەچێت بۆ وەرگر و ٨٠٠ دەگەڕێتەوە بۆ باڵانس.
- **ئاستەکانی نووسین:**
  - ناونیشانی پەڕە: 18px، 700.
  - سەردێری بەش: 15px، 700، بە هێڵێکی ڕەنگاوڕەنگ لە تەنیشتی.
  - ناوی ڕیز: 13px، خۆڵەمێشی.
  - بڕ و زانیاری: 14px، 500.
- **هەڵسەنگاندن:** تەنها ئەستێرە و تێبینی ماونەتەوە.
- **کارتی لیستی مامەڵەکان:** دیزاینی نوێ (`.tx-item`)، ئایکۆنی 40px، و هێڵەکانی هاوتەریب.

---

## ٢. ئاگاداری واتسئاپ بۆ پەسەندکردنی داواکاری (v19)

### Supabase: migration `ex_whatsapp_order_notifications`
**بەروار:** 2026-11-13 23:59 (وەشانی migration: `20261113205903`، بە UTC)

**خشتە نوێیەکان:**
- `ex_whatsapp_settings`: ژمارەی واتسئاپی هەر کڕیارێک (E.164)، و دۆخی چالاک یان ناچالاک. RLS هەیە: هەر کڕیارێک تەنها هی خۆی دەبینێت.
- `ex_whatsapp_consent_log`: هەر جارێک کڕیار ئاگاداری چالاک یان ناچالاک دەکات تۆمار دەکرێت.
- `ex_whatsapp_messages`: هەر نامەیەک لێرە تۆمار دەکرێت:
  - دۆخەکان: `queued`، `sending`، `sent`، `failed`.
  - هەروەها: ژمارەی هەوڵەکان، `wevlix_message_id` و هەڵەی کۆتایی.
- `ex_whatsapp_worker_keys`: کلیلی n8n. تەنها hash ـی کلیلەکە پاشەکەوت دەکرێت.

**فەنکشنەکان:**
- `ex_wa_normalize_phone(text)`: ژمارەی وەک `07xxxxxxxxx` دەکاتە `+9647xxxxxxxxx`. ژمارەی عەرەبی و فارسیش وەردەگرێت.
- `ex_my_whatsapp_settings()` و `ex_set_whatsapp_settings(p_enabled, p_phone)`: بۆ کڕیار.
- `ex_wa_queue_order_approved()`: فەنکشنی trigger ـی `trg_ex_orders_zz_whatsapp_approved` لەسەر `ex_orders`. لە کاتی پەسەندکردندا نامە دەخاتە نۆبە. ئەگەر هەڵەیەکی تێدا ڕووبدات، پەسەندکردنی داواکارییەکە ڕاناوەستێت.
- `ex_wa_claim(p_key, p_limit)` و `ex_wa_report(p_key, p_id, p_ok, p_message_id, p_error)`: بۆ n8n. ئەگەر ناردن سەرنەکەوێت، تا ٥ جار هەوڵ دەداتەوە.

### n8n
**بەروار:** 2026-11-14 00:04 (publish)

- زنجیرەی نوێ: `Every Minute - WhatsApp Outbox` ← `Claim Messages - Exchange` ← `IF - Has Message` ← `Send ... - Wevlix` ← `Report Result - Exchange`.
- Wevlix: `POST https://api.wevlix.com/v1/messages/template`.
- قاڵب: `proxo_order_approved_v2` (`85a354fb-07e4-4f83-a91b-8ceeb5740045`).
- سێ webhook ـی OTP (`send`، `status`، `verify`) ناچالاک کراون. پێشتر ئەم workflow ـە بە تەواوی ناچالاک بوو، بۆیە endpoint ـەکانی OTP وەک خۆیان ناچالاک ماونەتەوە.

### ماڵپەڕ
**بەروار:** 2026-11-14 00:05

- `index.html`:
  - ڕیزی «ئاگاداری لە ڕێگەی واتسئاپ» لەگەڵ دوگمەی چالاککردن (`#waRow`، `#waSwitch`) لە پڕۆفایل.
  - bottom sheet ـی `#whatsappSheet`، بە دەقی: «ژمارەکەت زیاد بکە بۆ ئەوەی ئاگادارییەکان لە ڕێگەی واتسئاپەوە پێت بگات».
- `assets/js/whatsapp-notify.js` (فایلی نوێ): کاری دوگمەکە، bottom sheet ـەکە و پاشەکەوتکردن لە Supabase.
- `assets/css/whatsapp-notify.css` (فایلی نوێ): ستایلی دوگمە و sheet، بۆ ڕووکاری ڕووناک و تاریک.
- `assets/js/app.js`: بانگکردنی `loadWhatsappSettings()` کاتێک پڕۆفایل دەکرێتەوە.

---

## ٣. پوختەی مامەڵە وەک سکرینی ناو ئەپ، و لۆگی واتسئاپ لە پانێڵ (v20)

### Supabase: migration `ex_admin_whatsapp_log`
**بەروار:** 2026-11-14 00:20 (وەشانی migration: `20261113212020`)

- `ex_admin_whatsapp_log(p_status, p_query, p_limit)`: لۆگی نامەکان، لەگەڵ کۆدی ئۆردەر و ناوی کڕیار.
- `ex_admin_whatsapp_stats()`: ئامارەکان (کڕیاری چالاککردوو، نێردراوی ئەمڕۆ، کۆی نێردراو، لە نۆبەدا، سەرنەکەوتوو).
- `ex_admin_whatsapp_retry(p_id)`: دووبارە ناردنەوەی نامەی سەرنەکەوتوو.
- **دەسەڵاتەکان:**
  - بینینی لۆگ و ئامار: `is_ex_admin()` یان `ex_staff_has('view')`.
  - دووبارە ناردنەوە: `ex_staff_has('approve_orders')`.

### ماڵپەڕ: commit `8da89d4`
**بەروار:** 2026-11-14 00:40

| فایل | گۆڕانکاری |
|---|---|
| `index.html` | سکرینی `#pageSummary` (route ـی `summary`) زیاد کرا. bottom sheet ـی `#txSheet` و پەڕە جیاکراوەکەی `#transactionSummaryPage` لابران. بانگکردنی `transaction-summary-route.js` لابرا. |
| `assets/js/app.js` | route ـی نوێ: `/summarytransaction/<secure_token>`، لەگەڵ ئەم فەنکشنانە: `openTxDetail`، `renderTxScreen`، `fetchTxScreenOrder`، `txDetailHTML`، `closeTxDetail`، `resetTxScreenState`. هەروەها `BASE_PATH` و `routeFromLocation` و `urlFor` نوێ کرانەوە. کڕیارێک کە نەچووبێتە ژوورەوە سەرەتا دەچێتە ژوورەوە و دواتر هەمان مامەڵەی بۆ دەکرێتەوە (`sessionStorage: px_pending_summary`). |
| `assets/css/transaction-summary.css` | ستایلی `#pageSummary`. ئەو CSS ـەی `body.transaction-summary-active` ـی تێدابوو لابرا، چونکە کاتی کردنەوەی لینکەکە هەموو ئەپەکەی دەشاردەوە. |
| `exchange-admin.html` | پەڕەی «نامەکانی واتسئاپ» (`#pgWhatsapp`) و لینکەکەی لە لیستی لای ڕاست. |
| `assets/js/exchange-whatsapp-admin.js` | فایلی نوێ: ئامار، لۆگ، گەڕان، فلتەر، دووبارە ناردنەوە، و نوێبوونەوەی خۆکار هەر ٣٠ چرکە. |
| `assets/js/exchange-staff.js` | `whatsapp:'view'` بۆ دەسەڵاتی کارمەندان. |
| `assets/js/svg-icons.js` | ئایکۆنی `whatsapp`. |
| `assets/css/exchange-features.css` | ستایلی پەڕەی واتسئاپ لە پانێڵ. |
| `test/transaction-summary.test.js` | تاقیکردنەوەکان بۆ سکرینە نوێیەکە نوێ کرانەوە. ٩ لە ٩ سەرکەوتوون. |

---

## ٤. ئاگاداری واتسئاپ بۆ ڕەتکردنەوەی داواکاری (v21)

### Supabase: migration `ex_whatsapp_order_rejected`
**بەروار:** 2026-11-14 00:55 (وەشانی migration: `20261113215507`)

- خشتەی نوێ `ex_whatsapp_templates` (`kind`، `template_id`، `active`، `meta_status`):
  - `order_approved`: `85a354fb-07e4-4f83-a91b-8ceeb5740045`، چالاکە.
  - `order_rejected`: `eeb58bf2-02a9-4516-ab9b-a93af9659d74` (`proxo_order_rejected`)، تا Meta پەسەندی نەکات ناچالاکە.
- `ex_wa_queue_order_approved()` نوێ کرایەوە:
  - ئێستا بۆ هەردوو دۆخی «پەسەندکرا» و «ڕەتکرا» کار دەکات.
  - شێوەی params گشتی کراوە: `{"body":[...], "button":[secure_token]}`.
  - بۆ ڕەتکردنەوە، هۆکارەکە لە `admin_note` وەردەگیرێت و دێڕەکانی دەکرێنە یەک دێڕ. ئەگەر بەتاڵ بێت، ڕستەیەکی جێگرەوە دادەنرێت.
- `ex_wa_sync_templates(p_key, p_templates)`: n8n دۆخی قاڵبەکانی Wevlix دەنێرێت، و هەر جۆرێک تەنها دوای پەسەندکردنی Meta چالاک دەبێت.
- `ex_admin_whatsapp_log` ستوونی `kind` ـی بۆ زیاد کرا، و `ex_admin_whatsapp_stats` بەشی `templates` ـی بۆ زیاد کرا.

### n8n
**بەروار:** 2026-11-14 00:56 (publish)

- `Send Order Approved - Wevlix` ناوی گۆڕا بۆ `Send Template - Wevlix`. ئێستا گۆڕاوەکانی body و button لە `params.body` و `params.button` وەردەگرێت.
- زنجیرەی نوێ: `Every 15 Minutes - Template Sync` ← `Get Templates - Wevlix` ← `Sync Templates - Exchange`.

### ماڵپەڕ: commit `50c20ce`
**بەروار:** 2026-11-14 00:56

- `assets/js/exchange-whatsapp-admin.js`: ستوونی «جۆر» (پەسەندکردن یان ڕەتکردنەوە)، و هێڵی دۆخی قاڵبەکان.
- `exchange-admin.html`: دەقی ڕوونکردنەوەی پەڕەکە نوێ کرایەوە، و `exchange-whatsapp-admin.js?v=2`.

---

## تێبینی بۆ دیڤلۆپەر

1. **کلیلەکان لە n8n:** کلیلی Wevlix و کلیلی worker ڕاستەوخۆ لە ناو node ـەکاندا نووسراون، وەک node ـە کۆنەکانی OTP. باشترە بگوازرێنەوە بۆ n8n Credentials. کلیلی worker لە Supabase تەنها بە hash پاشەکەوت کراوە (`ex_whatsapp_worker_keys`). بۆ گۆڕینی، کلیلێکی نوێ زیاد بکە و کۆنەکە بکە `active=false`.
2. **`assets/js/transaction-summary-route.js`:** ئیتر بانگ ناکرێت و دەتوانرێت بسڕدرێتەوە.
3. **تاقیکردنەوەکان:**
   - `test/transaction-summary.test.js` و `test/exchange-proxo-shell.test.js` هەموویان سەرکەوتوون.
   - ئەو تاقیکردنەوانەی تر کە سەرنەکەوتوون، پێش ئەم گۆڕانکارییانەش سەرنەکەوتوو بوون. پێشتر ٨٩ بوون، ئێستا ٨٧ن، و هیچ تاقیکردنەوەیەکی نوێ بەهۆی ئەم گۆڕانکارییانەوە نەشکاوە.
4. **`.github/workflows/exchange-production-smoke.yml`:** هێشتا بەدوای `app.js?v=70` و `admin.js?v=31` دەگەڕێت، بۆیە پێشتریش سەرنەکەوتوو بووە. پێویستە بۆ وەشانە نوێیەکان نوێ بکرێتەوە: `app.js?v=80`، `admin.js?v=32`، `exchange-staff.js?v=9`.
5. **ناردنی نامەی واتسئاپ:** تەنها بۆ ئەو کڕیارانە دەنێردرێت کە ئاگاداری واتسئاپیان چالاک کردووە. هیچ نامەیەکی بازرگانی (marketing) ناردن نییە.
6. **ڕێگای چاکسازی:** لۆگی هەموو نامەکان لە `ex_whatsapp_messages` و لە پەڕەی «نامەکانی واتسئاپ»ی پانێڵدا هەیە. هۆکاری هەڵەکان لە ستوونی `last_error` تۆمار دەکرێت.
