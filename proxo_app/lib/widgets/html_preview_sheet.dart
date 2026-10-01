// ═════════════════════════════════════════════════════════════════════════════
// HtmlPreviewSheet — پێشبینینی ناوەکی، تەنها بۆ خوێندنەوە
// ═════════════════════════════════════════════════════════════════════════════
// ⚠ جێگرەوەی `LocalHtmlPreview.open()`.
//
// ئەو ڕێڕەوە HTMLـەکەی دەنووسییە فایلێکی کاش و بە
// `Intent.ACTION_VIEW` + `text/html` دەیدا بە ئەندرۆید. ئەندرۆیدیش
// **هەڵبژێرەری ئەپ** پیشان دەدا بە هەموو ئەو ئەپانەی `text/html`
// هەڵدەگرن — و ئەوە دەستنووسەکان و ئەدیتەرەکانی کۆدیش لەخۆدەگرێت.
//
// واتە «ئەدیتەری کۆد»ی کە بەکارهێنەر دەیبینی هەرگیز تایبەتمەندییەکی ئەم
// ئەپە نەبووە — دانەیەک بوو لە هەڵبژێرەری سیستەمەکەدا. بۆیە هەردوو
// کێشەکە (ئەدیتەری کۆد + هەڵبژێرەری وێبگەڕ) یەک ڕەگیان هەیە و یەک
// چارەسەریان: هەرگیز فایلەکە مەدە بە ئەپێکی دەرەکی.
//
// ── چۆن «تەنها خوێندنەوە» مسۆگەر دەکرێت ────────────────────────────────────
//   ١. `JavaScriptMode.disabled` — هیچ سکریپتێک ناخوێندرێتەوە، بۆیە نە
//      XSS و نە دەستکاریی DOM لە لایەن ناوەڕۆکەکەوە.
//   ٢. `onNavigationRequest` هەموو گەڕانێک ڕەت دەکاتەوە جگە لە
//      بارکردنی یەکەم — کلیک لەسەر لینک بەکارهێنەر لەم پەڕەیە
//      دەرناهێنێت و ناچێتە هیچ دۆمەینێکی تر.
//   ٣. `loadHtmlString` ناوەڕۆکەکە لە `about:blank`ـەوە دەکێشێت، بۆیە
//      هیچ خوێندنەوەیەکی فایلی ناوخۆیی و هیچ `origin`ێکی متمانەپێکراو
//      نییە.
//   ٤. هیچ ڕێگایەکی «کردنەوە لە دەرەوە» نییە. زیادکردنی ئەوە هەڵبژێرەری
//      سیستەم — و ئەدیتەرەکانی کۆدی — دەگەڕێنێتەوە.
//
// ⚠ فایلی کاش و `FileProvider` ئیتر پێویست نین بۆ ئەم ڕێڕەوە.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

class HtmlPreviewSheet extends StatefulWidget {
  const HtmlPreviewSheet({super.key, required this.html, this.title});

  final String html;
  final String? title;

  /// دەیکاتەوە وەک ڕووتێکی تەواوی شاشە. `true` دەگەڕێنێتەوە ئەگەر
  /// کرایەوە، `false` ئەگەر HTMLـەکە بەتاڵ/تێکچوو بوو.
  static Future<bool> open(
    BuildContext context, {
    required String? html,
    String? title,
  }) async {
    if (html == null || html.trim().isEmpty || !html.contains('<')) {
      return false;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => HtmlPreviewSheet(html: html, title: title),
      ),
    );
    return true;
  }

  @override
  State<HtmlPreviewSheet> createState() => _HtmlPreviewSheetState();
}

class _HtmlPreviewSheetState extends State<HtmlPreviewSheet> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // ⚠ `disabled`، نەک `unrestricted`. ناوەڕۆکی ئەم پەڕەیە لە
      // داتابەیسەوە دێت؛ ڕێپێدانی جاڤاسکریپت واتە ڕێپێدانی هەر شتێک کە
      // ئەو داتایە تێیدایە بۆ کارکردن لەناو ئەپەکەدا.
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
          // بارکردنی یەکەم `about:blank`ـە و ڕێپێدراوە؛ هەر گەڕانێکی تر
          // ڕەت دەکرێتەوە، بۆیە پێشبینینەکە هەرگیز ناگۆڕدرێت بۆ پەڕەیەکی
          // تر و بەکارهێنەر لەناو ئەپەکەدا دەمێنێتەوە.
          onNavigationRequest: (req) => req.url.startsWith('about:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(
            bottom: BorderSide(color: AdSurface.cardBorder, width: 1),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
            tooltip: 'داخستن',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.title?.trim().isNotEmpty == true
                ? widget.title!.trim()
                : 'پێشبینین',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        body: Stack(
          children: [
            // ناوەڕۆکی پێشبینین LTRـە (HTMLـی خۆی ئاراستەی خۆی دیاری
            // دەکات)، بۆیە لە RTLـی ئەپەکە دەردەهێنرێت.
            Directionality(
              textDirection: TextDirection.ltr,
              child: WebViewWidget(controller: _controller),
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
