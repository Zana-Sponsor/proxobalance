# پلانی سادەکردنی پانێڵی باڵانس و چاککردنی دەستکاریی داراییی ئۆردەر

## ئامانج و شێوازی implementation

پانێڵی ئادمین بە HTML/CSS/JavaScriptی ئێستا دروستکراوە و backendی admin لە `api-handlers/admin.js` و Supabase RPC/migrationەکاندا جێگیرە. گۆڕانکاریی UI بە هەمان `.pg`، `goPage()`، sidebar و design systemی ئێستا دەکرێت؛ هیچ frameworkێکی نوێ زیاد ناکرێت و IDـی DOM و functionەکانی balance کە بە هەمان API دەبەسترێن پارێزراو دەبن.

بەشی باڵانس بە screenی پوختە، ڕیفاوند، payout، دەستکاریی دەستی و ئاگاداریی مەترسی دابەش دەکرێت. `loadBalanceAdmin()` بەهەمان APIـەکانی ئێستا داتا نوێ دەکاتەوە؛ ناوەڕۆکەکان تەنها دەگوازرێنەوە بۆ page containerی تایبەت، نەک ئەوەی کۆدی مامەڵە بە داتاکردنەوەی نوێ بگۆڕدرێت.

دەستکاریی orderی دارایی لە یەک RPCی server-enforced دەبێت. تەنها `super_admin` دەتوانێت edit بکات. بۆ orderی `AccountBalance`، گۆڕینی `amount` لە orderێکی نەsettled، نەrefunded و نەshortfall، بە deltaی `old_amount - new_amount` لە باڵانسی بەردەستدا ڕەنگدانەوەی دەبێت. deltaی پۆزەتیڤ credit و deltaی نێگەتیڤ debit ـە و debit تەنها ئەگەر باڵانس بەشی بکات سەرکەوتوو دەبێت. بۆ نموونە، 100,000 → 95,000 IQD، +5,000 IQD credit. نوێکردنەوەی order، balance cache، journal/entriesی جبرانی، correction history و audit لە transactionێکی یەکگرتوودا دەبن؛ تۆمارە مێژووییەکان overwrite ناکرێن.

بۆ sourceی دەرەکی، payout/settlementی تەواوبوو، full refund یان shortfallی پێشتر تۆمارکراو، دەستکاریی دارایی ڕەت دەکرێتەوە. refundی full، shortfall و roundingی payout جیاوازن و هیچ formulaی یەکگرتوو بۆیان دانانرێت. orderی کە balance deltaی ناوی نییە، تەنها خانە نادارایییەکانی دەستکاریکراو دەمێننەوە. بەکارهێنانی order fieldەکان بۆ refundی دەرەکی و بڕی refundی کۆن پاشەکشە ناکرێتەوە؛ جبرانی نوێ تەنها لە ڕێگای workflowی refundی پەسەندکراوەوە دەکرێت.

## دیزاین

- **جوڵەی دیزاین:** بەردەوامیی ڕووکاری dashboardی ئێستای Proxo؛ نەک دیزاینێکی جیاواز.
- **بنەماکان:** هەر screen یەک ئەرکی ڕوون؛ RTL و گونجاو بۆ مۆبایل؛ audit و status لە نزیک کردارەکە؛ پاراستنی هەمان wording، confirmation و permission.
- **ڕەنگ و هەست:** هەمان پەلەتی navy/سپی و ڕەنگی ئێستای status بۆ دەستکاریی نەگۆڕی مەعنای visual.
- **شێوازی layout:** sidebarی ئێستا بە pageی تایبەت؛ ناوەڕۆک بە cardی ئەرکی، سەردێڕ و ڕێنماییی کورت.
- **نیشانەی دیار:** ناونیشانی هەر screen بە iconی ئێستا؛ badgeی وضعیت و پەیامی success/errorی بەردەوام؛ ناوی لەکارکەوتوو/قوفڵکراو لە تەنیشت هۆکار.
- **کارلێک و جوڵە:** گواستنەوەی خێرا و سادەی ئێستا؛ confirmationی دارایی، نیشاندانی delta پێش پاشەکەوت و toastی بڕ و باڵانسی دوای commit.
- **تایپۆگرافی:** هەمان فونت و hierarchyی admin.css؛ دەقە RTL بەهەمان شێوە.
- **هەستی براند:** Proxo Balance بۆ ئادمین و تیمی دارایی؛ ورد، ئارام و ڕوون. CTAs بە دەستوری ڕوون و microcopy بە زمانەکەی بەکارهێنەر.

## ڕێکخستنی screenەکان

١. **پوختەی باڵانس:** totals/reconciliation و لیستی باڵانسی هەژمارەکان.
٢. **ڕیفاوند:** order lookup، shortfall/full refund، مێژووی refund و PDF report.
٣. **Payout:** queue و پێداچوونەوە/تەواوکردنی ناردن.
٤. **دەستکاریی دەستی:** زیاد/گەڕاندنەوە/کەمکردنەوەی باڵانس و logی manual.
٥. **ئاگاداریی مەترسی:** risk alerts و resolution.

## پێکهاتەی پڕۆژە

- `exchange-admin.html`: sidebar و screen containerەکان؛ ID و form ـەکانی API پارێزراو.
- `assets/js/admin.js`: page routing، order detail و refresh.
- `assets/js/exchange-staff.js`: page/action visibility بەپێی permission؛ super-admin gate بۆ order edit.
- `assets/js/exchange-order-manual.js`: order edit modal، financial eligibility/preview و refresh/toast.
- `assets/js/exchange-balance-admin.js`، `exchange-balance-manual.js`، `exchange-refund-report.js`: logicی ئێستای balance/refund؛ گۆڕینی handler تەنها ئەگەر بۆ page routing پێویست بێت.
- `api-handlers/admin.js`: validationی server، roleی strict `super_admin`، idempotency key و expected `updated_at` بۆ edit.
- `supabase/migrations/`: migrationی additive/controlled بۆ atomic correction RPC، balance guard و correction history؛ تەنها لە repo دادەنرێت، لە production جێبەجێ ناکرێت.
- `test/`: Node tests بۆ UI/auth/API contract و SQL migration invariants؛ هیچ testێک balanceی production نانووسێت.

## سنوور

هەموو edit ـەکان لە یەک RPCی transactionی Postgresدا قوفڵ، پشتڕاست، نوێ و audit دەکرێن. دابەزاندنی migration، گۆڕینی داتای production، deploy و pushی GitHub لەم implementationەدا نییە؛ بۆ ئەو کارانە پەسەندیی جیاواز پێویستە.