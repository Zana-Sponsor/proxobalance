// lib/widgets/proxo_popup.dart
//
// ═════════════════════════════════════════════════════════════════════════════
// ڕاگەیاندنی وێنەیی ئادمین — پۆپ ئەپێکی گشتی
// ═════════════════════════════════════════════════════════════════════════════
//
// ئادمین لە پانێڵەوە وێنەیەک دادەنێت، هەموو بەکارهێنەرێک **یەک جار**
// دەیبینێت. هەمان ڕێڕەوی `showAdFeedbackDialog`: ڕیئەڵتایم + پۆپ ئەپ.
//
// ── لای سێرڤەر ──────────────────────────────────────────────────────────
//
//   خشتە:      `pa_popups`
//     id uuid · image_url text · link text? · is_active bool
//     starts_at timestamptz · ends_at timestamptz? · created_at · updated_at
//
//   RLS:       خوێندنەوە بۆ هەمووان، نووسین تەنها بە `pa_is_admin()`
//              (دەقاودەق هەمان شێوەی `pa_banners`)
//   بەردەڵانە: `popup-images` — گشتی، ٤MB، jpeg/png/webp
//   ڕیئەڵتایم: خشتەکە خراوەتە ناو `supabase_realtime`
//
// ── تۆمارکردنی «بینراو» لە داتابەیس ────────────────────────────────────
//
//   خشتە:      `pa_popup_views`
//     id uuid · popup_id uuid · user_id uuid · viewed_at timestamptz
//     UNIQUE (popup_id, user_id)
//
//   RLS:       بەکارهێنەر تەنها دەتوانێت تۆماری خۆی بخوێنێتەوە/زیاد بکات؛
//              ئادمین بە `pa_is_admin()` هەموو تۆمارەکان دەبینێت.
//
// بەمە «یەک جار» بە هەژماری بەکارهێنەرەوە بەستراوە، نەک بە مۆبایل؛
// سڕینەوە یان دووبارە دامەزراندنەوەی ئەپ پۆپ ئەپەکە دووبارە ناداتەوە.
//
// ── وێنەکە: یان تەواو دەردەکەوێت، یان هیچ ───────────────────────────────
//
// پۆپ ئەپەکە **پێش** کردنەوەی پیشان نادرێت — سەرەتا وێنەکە بە تەواوی
// دادەبەزێت و قەبارەی ڕاستەقینەی دەخوێنرێتەوە. ئەگەر شکستی هێنا، هیچ
// ناکرێتەوە و ئەنتری کاشەکە دەسڕێتەوە بۆ هەوڵی داهاتوو.
//
// ئەمە هەمان دەرسی وێنۆچکەکانە: خانەیەکی سپی کە هیچی تێدا نییە خراپترە
// لە هیچ.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show supabase;
import '../theme/app_theme.dart';

const Color _kPopupMuted = Color(0xFF64748B);
const Color _kPopupSurface = Color(0xFFF1F5F9);
const Color _kPopupAccent = Color(0xFF2563EB);
const Color _kPopupOnAccent = Color(0xFFFFFFFF);
const Color _kPopupScrim = Color(0x660F172A);
const Color _kCloseScrim = Color(0x73000000);

/// ماوەی چاوەڕوانی بۆ داگرتنی وێنەکە پێش کردنەوەی پۆپ ئەپەکە.
const Duration _kImageTimeout = Duration(seconds: 8);

// ═════════════════════════════════════════════════════════════════════════════
// مۆدێل
// ═════════════════════════════════════════════════════════════════════════════

@immutable
class ProxoPopup {
  final String id;
  final String imageUrl;

  /// بەستەرێکی ئیختیاری. ئەگەر هەبوو، دەستلێدان لەسەر وێنەکە و دوگمەیەکی
  /// خوارەوە دەیکاتەوە. ئەگەر `null` بوو، تەنها وێنەیەکە.
  final String? link;

  const ProxoPopup({
    required this.id,
    required this.imageUrl,
    this.link,
  });

  static ProxoPopup? fromRow(Map<String, dynamic> row) {
    final String id = (row['id'] ?? '').toString().trim();
    final String image = (row['image_url'] ?? '').toString().trim();
    if (id.isEmpty || image.isEmpty) return null;

    final Uri? parsed = Uri.tryParse(image);
    final bool usable = parsed != null &&
        (parsed.scheme == 'https' || parsed.scheme == 'http') &&
        parsed.host.isNotEmpty;
    if (!usable) return null;

    final String link = (row['link'] ?? '').toString().trim();
    return ProxoPopup(
      id: id,
      imageUrl: image,
      link: link.isEmpty ? null : link,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// هێنان و تۆمارکردنی «بینراو»
// ═════════════════════════════════════════════════════════════════════════════

/// نوێترین ڕاگەیاندنی چالاک کە ئەم بەکارهێنەرە هێشتا نەیبینیوە.
///
/// تا پێنج ڕیز دەهێنێت نەک یەک: ئەگەر نوێترینیان بینرابێت، ئەوەی پێش
/// ئەو هێشتا دەردەکەوێت.
Future<ProxoPopup?> fetchPendingProxoPopup() async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final String nowIso = DateTime.now().toUtc().toIso8601String();
    final dynamic res = await supabase
        .from('pa_popups')
        .select('id,image_url,link,ends_at')
        .eq('is_active', true)
        .lte('starts_at', nowIso)
        .order('created_at', ascending: false)
        .limit(5);

    final List<dynamic> rows = (res as List<dynamic>?) ?? const <dynamic>[];
    if (rows.isEmpty) return null;

    final DateTime now = DateTime.now().toUtc();
    final List<ProxoPopup> candidates = <ProxoPopup>[];

    for (final dynamic raw in rows) {
      final Map<String, dynamic> row =
          Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);

      // ⚠ `ends_at` لێرە دەپشکنرێت نەک لە کوێری: مۆبایل و سێرڤەر
      //   لەوانەیە چەند چرکەیەک جیاوازییان هەبێت، و ڕیزێکی بەسەرچوو
      //   با بێدەنگ بەجێبمێنێت نەک ببێتە هەڵە.
      final String endsRaw = (row['ends_at'] ?? '').toString().trim();
      if (endsRaw.isNotEmpty) {
        final DateTime? ends = DateTime.tryParse(endsRaw);
        if (ends != null && ends.toUtc().isBefore(now)) continue;
      }

      final ProxoPopup? popup = ProxoPopup.fromRow(row);
      if (popup != null) candidates.add(popup);
    }
    if (candidates.isEmpty) return null;

    final List<String> popupIds =
        candidates.map((ProxoPopup popup) => popup.id).toList(growable: false);
    final dynamic viewsRes = await supabase
        .from('pa_popup_views')
        .select('popup_id')
        .eq('user_id', user.id)
        .inFilter('popup_id', popupIds);

    final List<dynamic> viewRows =
        (viewsRes as List<dynamic>?) ?? const <dynamic>[];
    final Set<String> seenPopupIds = viewRows
        .map((dynamic raw) => (raw as Map<dynamic, dynamic>)['popup_id'])
        .whereType<Object>()
        .map((Object id) => id.toString())
        .toSet();

    for (final ProxoPopup popup in candidates) {
      if (!seenPopupIds.contains(popup.id)) return popup;
    }
    return null;
  } catch (error) {
    // بێدەنگ: ڕاگەیاندنێک کە نایەت هەرگیز نابێتە هۆی شکاندنی شاشەی سەرەکی.
    debugPrint('ProxoPopup: هێنان شکستی هێنا — $error');
    return null;
  }
}

/// تۆماری بینینەکە پێش کردنەوەی دیالۆگ دروست دەکات.
///
/// UNIQUE (popup_id, user_id) ڕێگە لە دوو تۆمار و دوو پیشاندان لە دوو
/// ئامێری جیاواز دەگرێت. ئەگەر نووسینەکە سەرکەوتوو نەبێت، پۆپ ئەپەکەش
/// پیشان نادرێت تا ئامارەکە ڕاست بمێنێتەوە.
Future<bool> recordProxoPopupView(String popupId) async {
  final String normalizedId = popupId.trim();
  final user = supabase.auth.currentUser;
  if (normalizedId.isEmpty || user == null) return false;

  try {
    await supabase.from('pa_popup_views').insert(<String, dynamic>{
      'popup_id': normalizedId,
      'user_id': user.id,
    });
    return true;
  } catch (error) {
    debugPrint('ProxoPopup: تۆمارکردنی بینین شکستی هێنا — $error');
    return false;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// کردنەوە
// ═════════════════════════════════════════════════════════════════════════════

/// وێنەکە دادەبەزێنێت، پاشان — تەنها ئەگەر سەرکەوتوو بوو — پۆپ ئەپەکە
/// دەکاتەوە و وەک «بینراو» تۆماری دەکات.
///
/// `true` واتە پیشاندرا.
Future<bool> showProxoPopup(BuildContext context, ProxoPopup popup) async {
  final CachedNetworkImageProvider provider =
      CachedNetworkImageProvider(popup.imageUrl);

  final Size? natural = await _resolveImageSize(provider);
  if (natural == null || natural.isEmpty) {
    // ⚠ ئەنتری کاشەکە دەسڕێتەوە. ئەگەر ڕیکۆردی ETagـەکە مابێت بەڵام
    //   فایلەکە نا، سێرڤەر 304 دەگەڕێنێتەوە و هیچ داتایەک نایەت —
    //   بەبێ سڕینەوە، هەوڵی داهاتووش هەر شکست دەهێنێت.
    unawaited(CachedNetworkImage.evictFromCache(popup.imageUrl));
    debugPrint('ProxoPopup: وێنە نەهات — ${popup.imageUrl}');
    return false;
  }

  if (!context.mounted) return false;

  final bool viewRecorded = await recordProxoPopupView(popup.id);
  if (!viewRecorded) return false;

  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: _kPopupScrim,
    builder: (_) => _ProxoPopupDialog(
      popup: popup,
      aspectRatio: natural.width / natural.height,
      provider: provider,
    ),
  );
  return true;
}

/// قەبارەی ڕاستەقینەی وێنەکە — یان `null` ئەگەر نەهات.
///
/// بەبێ ئەمە پۆپ ئەپەکە ناتوانێت ڕێژەی وێنەکە بزانێت و دەبێت خانەیەکی
/// چەسپاو دابنێت، کە وێنە پانەکان دەبڕێت و بەرزەکان دەتەنێتەوە.
Future<Size?> _resolveImageSize(ImageProvider<Object> provider) {
  final Completer<Size?> done = Completer<Size?>();
  final ImageStream stream = provider.resolve(const ImageConfiguration());

  late final ImageStreamListener listener;
  void finish(Size? value) {
    if (!done.isCompleted) done.complete(value);
    stream.removeListener(listener);
  }

  listener = ImageStreamListener(
    (ImageInfo info, bool _) => finish(Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    )),
    onError: (Object error, StackTrace? _) => finish(null),
  );
  stream.addListener(listener);

  return done.future.timeout(_kImageTimeout, onTimeout: () {
    stream.removeListener(listener);
    return null;
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// پۆپ ئەپەکە
// ═════════════════════════════════════════════════════════════════════════════

class _ProxoPopupDialog extends StatelessWidget {
  final ProxoPopup popup;
  final double aspectRatio;
  final ImageProvider<Object> provider;

  const _ProxoPopupDialog({
    required this.popup,
    required this.aspectRatio,
    required this.provider,
  });

  Future<void> _openLink(BuildContext context) async {
    final String? raw = popup.link;
    if (raw == null) return;
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return;

    Navigator.of(context).pop();
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('ProxoPopup: کردنەوەی بەستەر شکستی هێنا — $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final bool hasLink = popup.link != null;

    // وێنەکە هەرگیز لە ٦٢٪ی بەرزایی شاشە تێناپەڕێت، بۆیە وێنە بەرزەکان
    // پۆپ ئەپەکە لە شاشە دەرناکەن.
    final double maxImageHeight = screen.height * 0.62;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxImageHeight),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Semantics(
                    label: 'ڕاگەیاندن',
                    image: true,
                    child: GestureDetector(
                      onTap: hasLink ? () => _openLink(context) : null,
                      child: Image(
                        image: provider,
                        fit: BoxFit.cover,
                        // وێنەکە پێشتر بە تەواوی داگیراوە، بۆیە ئەم
                        // خانەیە تەنها بۆ فرەیمی یەکەمە.
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: _kPopupSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 10,
                end: 10,
                child: Material(
                  color: _kCloseScrim,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: Colors.white,
                        semanticLabel: 'داخستن',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasLink)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: Material(
                  color: _kPopupAccent,
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => _openLink(context),
                    child: const Center(
                      child: Text(
                        'کردنەوە',
                        style: TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _kPopupOnAccent,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'داخستن',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _kPopupMuted,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
