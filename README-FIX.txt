Proxo — فایلە چاککراوەکان
=========================

پرۆژەی Flutter لەناو ئەم فۆڵدەرەدایە:

    proxo_app/

گرنگترین گۆڕانکارییەکان
-----------------------

1) شاشەی دروستکردنی ڕیکلام
   - دیزاینێکی نوێ و سادە، بە خانەی بێ ئایکۆنی زیادە.
   - کۆی نرخ لە کۆتایی فۆرم و باری جێگیری خوارەوە.
   - وردەکاری نرخ بە شێوەی collapsible bottom sheet.
   - هەڵبژاردنی ئارەزوومەندانەی FastPay یان باڵانسی هەژمار.
   - تێبینی، جۆری مۆبایل، ڕەگەز و شوێن، و پشکنینی کاتی تێپەڕیوو.

2) FastPay و Supabase
   - پارەدان پێش دروستکردنی ڕیکلام پشتڕاست دەکرێتەوە.
   - بڕی پارە لە سێرڤەرەوە دیاری دەکرێت، نەک لە مۆبایلەوە.
   - ڕێگای پارەدان و ناسنامەی مامەڵە لە pa_ads تۆمار دەکرێت.
   - هەموو گۆڕانکاریی دۆخی مامەڵە لە pa_transaction_events هەڵدەگیرێت.
   - migration و workflowـی n8n لە supabase/migrations و n8n/workflows دانراون.

3) Android / iOS
   - deep linkـی گەڕانەوە لە FastPay دانراوە: appfpclientProxo://fast-pay.cash
   - Gradle لە ڕێڕەوی Java و NDKـی جێگیر پاک کرایەوە.
   - buildـی بێ key.properties بە debug signing دەڕوات؛ production پێویستی بە keystore هەیە.

4) GitHub Actions
   - workflow ڕاستەوخۆ proxo_app دروست دەکات.
   - ئەگەر Gradle wrapper لە ئارشیفەکەدا نەبێت، workflow خۆکارانە دروستی دەکاتەوە.
   - هیچ وشەی نهێنییەک لە workflowـدا نییە.
   - بۆ production signing ئەم GitHub Secretsـانە دابنێ:
       PROXO_KEYSTORE_BASE64
       PROXO_STORE_PASSWORD
       PROXO_KEY_PASSWORD
       PROXO_KEY_ALIAS

ڕێنمایی جێبەجێکردن
------------------

    cd proxo_app
    flutter clean
    flutter pub get
    flutter run

بۆ ڕێکخستنی FastPay و migration:

    docs/FASTPAY_AD_CHECKOUT_SETUP.md

تێبینی: Flutter SDK لە ژینگەی چاککردنی فایلەکەدا بەردەست نەبوو؛
پشکنینی JSON، XML، plist، SQL، asset و importـە ناوخۆییەکان کراوە،
بەڵام flutter analyze/build دەبێت لەسەر Flutter 3.27.4 یان نوێتر بکرێت.
