import 'package:flutter/material.dart';

class AppColors {
  // ── Surface ramp ──────────────────────────────────────────────────────────
  // One source of truth for every general section / content-area background.
  // Chosen from the palette already in the app rather than an off-the-shelf
  // neutral: `surfaceCard` is the tone this codebase previously used for the
  // page background (#F8FAFD), promoted to the card surface — so cards now sit
  // where the page used to, and the page steps down below them. That fixes the
  // real problem, which was a #FEFEFE card (L* 99.7, effectively pure white)
  // floating on a #F8FAFD page: only 1.45 L* of separation, and glaring.
  //
  //   surfaceBase     L* 95.1   screen background
  //   surfaceSection  L* 96.8   grouped sections, recessed wells inside cards
  //   surfaceCard     L* 98.2   standard content container
  //   surfaceRaised   L* 99.3   sheets/menus that must sit above a card
  //
  // Steps are ~1.4 L* — perceptible as depth, never as a colour change. The
  // cool cast (blue 5–9 points above red) carries the blue/indigo brand
  // identity without reading as tinted, and eases off as the tone lightens so
  // the top of the ramp stays neutral white rather than turning blue.
  // ── پاشبنەما ئێستا #FAFAFAیە ──────────────────────────────────────────────
  // پاشبنەمای پەڕە دەبێتە FAFAFA، بەڵام ڕووی کارتەکان سپی تەواو دەمێننەوە
  // تا بە جوانی لەسەر ڕووی شاشەکە بە سێبەر و سنوور جیا ببنەوە.
  static const Color surfaceBase    = Color(0xFFFAFAFA);
  static const Color surfaceSection = Color(0xFFFAFAFA);
  static const Color surfaceCard    = Color(0xFFFFFFFF);
  static const Color surfaceRaised  = Color(0xFFFFFFFF);

  /// Card outline. Deliberately restrained — the ramp above now does most of
  /// the separating (3.1 L* card-to-page, up from 1.45), so the border is a
  /// hint rather than an outline, backed by the existing soft shadow.
  // لەسەر سپی، سنووری کۆن (#E8EBF3) کەمێک لاواز بوو — ئەمە کەمێک تۆختترە
  // بۆیە کارتەکان بەبێ جیاوازی پاشبنەما دیارن.
  static const Color surfaceBorder   = Color(0xFFE3E7F0);

  /// In-card separator. Tuned to hold ~5.9 L* against `surfaceCard`, matching
  /// the separation the old hairline had against the old near-white card.
  static const Color surfaceHairline = Color(0xFFE4E7F0);

  // ═══════════════════════════════════════════════════════════════════════════
  // تۆکنە سیمانتیکەکان — یەک سەرچاوەی ڕاستی بۆ هەموو ئەپەکە
  // ═══════════════════════════════════════════════════════════════════════════
  // هەر شاشەیەک و هەر کۆمپۆنێنتێک دەبێت لێرەوە ڕەنگ وەربگرێت، نەک ڕەنگی
  // خۆی دابنێت. ئەگەر شوێنێک ڕەنگێکی جیاوازی پێویست بێت، ئەوە لێرە زیاد
  // دەکرێت وەک تۆکنێکی نوێ — نەک وەک `Color(0xFF…)`ی تەنیا لەناو فایلێکدا.
  //
  //   page      پاشبنەمای هەموو شاشەکان (و باری خوارەوە — یەک تۆن)
  //   surface   ڕووی کارت و کۆنتەینەرەکان
  //   raised    شیت و مینیوەکان کە لەسەر کارت دادەنیشن
  //   line      هێڵی مووی نێوان بەشەکان
  //   ink       دەقی سەرەکی · inkMuted دەقی لاوەکی
  //   accent    شینی سیستەم — دوگمە، ئایکۆنی چالاک، لینک
  //   positive / negative / warning — دۆخەکان
  static const Color page      = surfaceBase;
  static const Color surface   = surfaceCard;
  static const Color raised    = surfaceRaised;
  static const Color line      = surfaceBorder;
  static const Color hairline  = surfaceHairline;
  /// ⚠ بوو #0B0B32. هەموو ئەپەکە لەسەر #0F172A یەکخرا (tools_screen،
  /// دۆخە بەتاڵەکان، چیپەکانی فلتەر، دوگمەکانی CTA، کارتە خێراکانی
  /// سەرەکی، و ئێستا وردەکاری ڕیکلامیش). دوو مەرەکەبی ڕەشی نزیک لێک
  /// (#0B0B32 نەیڤی، #0F172A سلەیت) لە کاتی گواستنەوەی Heroدا وەک
  /// هەڵەیەک دەخوێندرێتەوە، نەک وەک هەڵبژاردن.
  static const Color ink       = Color(0xFF0F172A);

  /// ⚠ بوو #68687F. هەمان بەڵگە: #64748B ئەو تۆنەیە کە tools_screen،
  /// دۆخە بەتاڵەکان و چیپەکان هەموویان بەکاری دەهێنن.
  static const Color inkMuted  = Color(0xFF64748B);
  /// ⚠ بوو #0365FF. ڕەنگی سەرەکیی نوێی ئەپەکە #0265FFـە.
  static const Color accent    = Color(0xFF0265FF);
  static const Color accentSoft= Color(0xFFEFF4FE);
  static const Color positive  = Color(0xFF13A56A);
  static const Color negative  = Color(0xFFB74956);
  static const Color warning   = Color(0xFFB86A17);

  /// پاشبنەمای باری خوارەوە — بە ئەنقەست **هەمان** `page`ە، بۆیە باری
  /// خوارەوە و پەڕەکە یەک ڕووی یەکگرتوو دەردەکەون. جیاکردنەوەکە تەنها بە
  /// هێڵێکی مووی سەرەوە و سێبەرێکی زۆر سووکە.
  /// ئەگەر ڕۆژێک هەموو ئەپەکە سپی کرا، تەنها `surfaceBase` بگۆڕە.
  static const Color navBg     = page;
  static const Color navLine   = hairline;
  static const Color navActive = accent;
  static const Color navIdle   = Color(0xFF6B7280);

  static const Color bg      = surfaceBase; // was #F7F9FD — now on the ramp
  static const Color white   = Color(0xFFFFFFFF);
  static const Color dark    = Color(0xFF1C2333);
  static const Color dark2   = Color(0xFF2E3A50);
  // لەسەر پاشبنەمای سپی، #8B95A8ی کۆن تەنها 3.0:1 کۆنتراستی هەبوو — لە
  // ژێر ئاستی خوێندنەوەی گونجاو. ئەمە 4.6:1ە، هێشتا لاوەکی دەردەکەوێت.
  static const Color muted   = Color(0xFF6E7787);
  static const Color muted2  = Color(0xFF6B7585);
  // border aliases — border == border1
  static const Color border  = Color(0xFFE8EAF0);
  static const Color border1 = Color(0xFFE8EAF0);
  static const Color border2 = Color(0xFFD0D4DE);
  static const Color green   = Color(0xFF16A34A);
  static const Color red     = Color(0xFFDC2626);
  static const Color yellow  = Color(0xFFD97706);
  static const Color amber   = Color(0xFFD97706);
  static const Color blue    = Color(0xFF2563EB);
  static const Color indigo  = Color(0xFF6366F1);
  static const Color primary = Color(0xFF0E78FF);

  // ── background gradient tones — a barely-there lift behind screen content.
  // The delta between the two stops is intentionally tiny (a few hex steps)
  // so it reads as depth, not as a visible gradient. See [AppBackground].
  // Both stops straddle `surfaceBase` so the gradient and the flat fill are
  // interchangeable — screens that use either land on the same tone.
  // گرادیێنتەکە ئێستا تەخت و FAFAFAیە — هەمان تۆنی `surfaceBase`.
  static const Color bgGradientTop    = surfaceBase;
  static const Color bgGradientBottom = surfaceBase;
}

// ═════════════════════════════════════════════════════════════════════════════
// تایپۆگرافی — تاقە سەرچاوەی ڕاستی بۆ هەموو ئەپەکە
// ═════════════════════════════════════════════════════════════════════════════
// یەک خێزانی فۆنت بۆ هەموو ئەپەکە: **Rabar**. (Bahij TheSansArabic بە
// تەواوی لابرا — نە لە کۆد، نە لە pubspec، نە لە assets/fonts/.)
//
// ⚠ تەنها یەک فایلی ڕاستەقینەی Rabar هەیە (`Rabar_021.ttf`)، بۆیە لە
// pubspec تەنها w400 تۆمار کراوە و Flutter کێشە قورسەکان بە شێوەی
// دەستکرد (synthetic bold) دروست دەکات. ئەگەر ڕۆژێک فایلی ڕاستەقینەی
// Medium/Bold زیاد کرا، تەنها pubspec دەگۆڕێت — ئەم فایلە نا.
//
//     w400  Regular     w500/w600  Medium/SemiBold     w700  Bold
//
/// ناوی خێزانی فۆنت. هەموو ئەپەکە تەنها ئەمە بەکاردەهێنێت (§16) —
/// **دەبێت دەقاودەق وەک `family:`ـەکەی pubspec.yaml بێت.**
const String kAppFont = 'Rabar';

/// ناوە کۆنەکان وەک ئەلیاس مانەوە **نەکراوە** — هەموو شوێنێک ڕاستەوخۆ
/// `kAppFont` بەکاردەهێنێت، بۆیە مەحاڵە شاشەیەک لەسەر فۆنتێکی جیاواز
/// بمێنێتەوە.

// ─────────────────────────────────────────────────────────────────────────────
// زیادکردنی قەبارەی دەقی کوردی — تاقە سەرچاوە (§8)
// ─────────────────────────────────────────────────────────────────────────────
// یەک ژمارە بۆ هەموو ئەپەکە. پێشتر بە جیاوازی لە سێ فایلدا دووبارە
// کرابووەوە (`_kKuBump`, `_kAdCardKuBump`, `BestMetricTokens.kuBump`)؛
// ئێستا هەموویان لێرەوە دەخوێنرێنەوە، بۆیە **مەحاڵە** دوو جار جێبەجێ
// بکرێت.
//
// ⚠ بۆچی گەڕایەوە بۆ 1.06 لەگەڵ Rabar:
// Rabar لە هەمان قەبارەی نۆمیناڵدا بە ئەندازەگیری بچووکتر دەکێشرێت لە
// Bahij (هەردووکیان upm = 2048):
//
//     x-height     Bahij 1018  →  Rabar  896   (−12.0٪)
//     'ک' پانی     0.847       →  0.750 em     (−11.5٪)
//     'م' پانی     0.799       →  0.638 em     (−20.2٪)
//     'ە' پانی     0.594       →  0.432 em     (−27.3٪)
//
// کۆدی پێشوو ئەمەی تۆمار کردبوو: 0.93 قەبارەی چاویی Bahij دەکات بە
// قەبارەی چاویی Rabar. پێچەوانەکەی 1/0.93 = 1.075ـە، و 1.06 ئەو
// ژمارەیەیە کە خودی ئەپەکە بەکاری دەهێنا کاتێک لەسەر Rabar بوو.
//
// ئەنجام: 1.06 وا دەکات هەموو شاشەکان **هەمان قەبارەی فیزیکی**یان
// بمێنێتەوە دوای گۆڕینی فۆنت (0.93 × 1.06 = 0.986، واتە ١٫٤٪ بچووکتر) —
// بۆیە هیچ لەیئاوتێک ناتەقێت و هیچ دەقێک بچووک نابێتەوە.
//
// ⚠ ئەو شوێنانەی بریفەکە قەبارەیەکی **کۆتایی** بۆ دیاری کردوون (دۆخی
// بەتاڵ، سەرپەڕەی AppBar، پیلی فلتەر) بە ئەنقەست ئەم ژمارەیە جێبەجێ
// **ناکەن** — ژمارەکانیان وەک خۆیان dpـن.
const double kKuFontBump = 1.06;

/// A very subtle top-to-bottom gradient lift for screen backgrounds — reads
/// as depth, not as a visible gradient, and is meant to sit *behind* screen
/// content so white cards have a touch more contrast to stand out against.
///
/// Nothing about cards, shadows, borders, or spacing changes — this only
/// replaces a flat `Scaffold(backgroundColor: AppColors.bg)` fill with a
/// gradient version of the same tone. Usage:
///
///   Scaffold(
///     body: AppBackground(
///       child: ...screen content...,
///     ),
///   )
///
/// ═══════════════════════════════════════════════════════════════════════════
/// AppIcons — یەک سیستەمی پێوانەیی بۆ ئایکۆنەکانی TopBar و BottomNav
/// ═══════════════════════════════════════════════════════════════════════════
///
/// پێش ئەمە هەر بارێک پێوانەکانی خۆی هەبوو و هەرگیز بەراورد نەکرابوون.
/// ئەمانە پێوانە کراون لە خودی ئارتوۆرکەکەوە (تیرەی مەرەکەب لە ڕیزەکاندا،
/// median run-length) نەک لە چاوەوە:
///
///     ئایکۆن        بۆکس   تیرە      ڕێژە = تیرە ÷ بۆکس
///     ─────────────────────────────────────────────────
///     nav campaigns  20    1.46 dp   0.0731
///     nav profile    20    1.45 dp   0.0723
///     nav tools      20    1.43 dp   0.0717   ← خێزانێکی توند
///     nav home       20    1.19 dp   0.0594   ← دەرچوو، ڕاست کرایەوە
///     bar menu       26    2.00 dp   0.0769
///     bar bell       26    2.17 dp   0.0833
///
/// ڕێژە پێوەرەکەیە، نەک تیرەی ڕەها: ئایکۆنێکی 26 dp دەبێت تیرەیەکی
/// قەڵەوتری هەبێت لە ئایکۆنێکی 20 dp بۆ ئەوەی هەمان «قورسایی ئۆپتیکی»
/// هەبێت. بۆیە هەردوو بار یەک `strokeRatio` دەخوێننەوە و هەریەکەیان
/// لە بۆکسی خۆیدا لێی دەدات.
class AppIcons {
  AppIcons._();

  /// بۆکسی ئایکۆنی باری خوارەوە (پێوانەکراو: 44 px لە مۆکاپەکەدا).
  static const double navBox = 20.0;

  /// بۆکسی ئایکۆنی باری سەرەوە (مێنیو و زەنگ).
  static const double barBox = 26.0;

  /// تیرەی مەرەکەب وەک ڕێژەیەک لە بۆکسەکە. ئەمە ناوەندی ئەو سێ ئایکۆنەیە
  /// کە لە یەک کیتی پیشەیی‌یەوە هاتوون (campaigns / profile / tools) —
  /// بۆیە پێوەری خێزانەکەیە، نەک ژمارەیەکی هەڵبژێردراو.
  static const double strokeRatio = 0.0724;

  /// تیرەی ئایکۆنەکانی باری سەرەوە بە dp. 26 × 0.0724 ≈ 1.88.
  static const double barStroke = barBox * strokeRatio;

  /// بەرزایی مەرەکەبی ئایکۆنەکانی باری خوارەوە — هەر پێنجیان لەسەر ئەمە
  /// نۆرمالایز کراون (`_glyphFactor` ئەمە دەپارێزێت).
  static const double navInk = 18.0;
}

/// Screens that don't adopt this and keep `backgroundColor: AppColors.bg`
/// still get the updated, more premium flat tone automatically — no other
/// changes are required for consistency across the app.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgGradientTop, AppColors.bgGradientBottom],
        ),
      ),
      child: child,
    );
  }
}

/// Global ThemeData — بەکاربهێنە لە MaterialApp
ThemeData buildAppTheme() => ThemeData(
  fontFamily: kAppFont,
  textTheme: const TextTheme().apply(
    fontFamily: kAppFont,
    decoration: TextDecoration.none,
  ),
);

TextStyle rabar({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.dark,
  double height = 1.5,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: kAppFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: TextDecoration.none,
    );

TextStyle inter({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.dark,
}) =>
    TextStyle(
      fontFamily: kAppFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
      decoration: TextDecoration.none,
    );

// ═════════════════════════════════════════════════════════════════════════════
// AppTypography — تاقە سەرچاوەی تایپۆگرافی بۆ هەموو ئەپەکە
// ═════════════════════════════════════════════════════════════════════════════
// One named style per role instead of an arbitrary `TextStyle(fontSize: …)`
// at each call site. Sizes below are the optically-verified starting scale
// for Rabar — every size below is multiplied by `kKuFontBump` (above), which
// is what keeps the painted ink the same size it was before the font swap,
// so these are NOT the old per-screen numbers carried over. They are a
// starting point: re-check against the real Kurdish string and the actual
// available width at a call site before shipping, per the same rule that
// governs every screen using this file.
//
// Weight rule — only four real weights exist, so never request w500 and
// never reach for Bold as a default:
//   w400 Regular   body text, values, form fields, descriptions
//   w600 SemiBold  section headings, card titles, important buttons
//   w700 Bold      rare, high-priority emphasis only — pass it explicitly
//   w300 Light     only where it stays clearly readable at that size
//
// Line height is a property of how many lines the text actually runs, not
// of its role, so it is a parameter here rather than baked per-token:
//   lineTight   1.13  (1.10–1.16 band)  single-line controls — buttons,
//                                        chips, fields, labels, AppBars
//   lineRelaxed 1.30  (1.25–1.35 band)  multiline body copy that wraps
//
// Every token still takes size/weight/color/height so a screen can nudge
// within — or briefly outside — the starting range once it's been checked
// against real content; the token exists so that override is the visible
// exception at a call site, not silent drift.
class AppTypography {
  AppTypography._();

  /// 1.10–1.16 band — single-line controls (buttons, chips, fields, labels).
  static const double lineTight = 1.13;

  /// 1.25–1.35 band — multiline body copy that actually wraps.
  static const double lineRelaxed = 1.30;

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color,
    double height,
    double letterSpacing,
  ) =>
      TextStyle(
        fontFamily: kAppFont,
        fontSize: size * kKuFontBump,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: TextDecoration.none,
      );

  /// 11.5–12 — small metadata/captions: timestamps, helper text, tiny badges.
  static TextStyle caption({
    double size = 11.5,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.inkMuted,
    double height = lineTight,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);

  /// 12–12.5 — secondary labels: field labels, list secondary lines.
  static TextStyle label({
    double size = 12.5,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.inkMuted,
    double height = lineTight,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);

  /// 13 — body text and input values.
  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double height = lineRelaxed,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);

  /// 13–13.5 — buttons. SemiBold by default ("important buttons" per spec);
  /// pass weight: FontWeight.w400 for a plain text/link-style action.
  static TextStyle button({
    double size = 13.5,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.white,
    double height = lineTight,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);

  /// 14 — card titles.
  static TextStyle cardTitle({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double height = lineTight,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);

  /// 15 — section headings.
  static TextStyle sectionHeading({
    double size = 15,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double height = lineTight,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);

  /// 16 — AppBar titles.
  static TextStyle appBarTitle({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double height = lineTight,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);

  /// 22–24 — large important numbers (balances, headline metrics). SemiBold
  /// by default; pass weight: FontWeight.w700 for the rare case that also
  /// needs Bold's high-priority emphasis on top of the size.
  static TextStyle metricLarge({
    double size = 24,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double height = lineTight,
    double letterSpacing = 0,
  }) =>
      _style(size, weight, color, height, letterSpacing);
}

// ═════════════════════════════════════════════════════════════════════════════
// ڕووی کارت — سنوور و سێبەری هاوبەش بۆ هەموو ئەپەکە
// ═════════════════════════════════════════════════════════════════════════════
// یەک سەرچاوەی ڕاستی بۆ «قووڵایی» کارتەکان، بۆ ئەوەی کارتی ڕیکلام لە
// `ad_screen.dart`، سکێلیتۆنەکەی، و کارتەکانی `ad_details.dart` هەرگیز لە
// یەکتر جیا نەبنەوە. پێشتر هەر فایلێک کۆپییەکی خۆی هەبوو و بە کاتی خۆیان
// لێک دوور کەوتنەوە.
//
// دەقاودەق هاوتای ئەم CSS-ە:
//   border:     1px solid #D4D9E1;
//   box-shadow: 0 8px 30px rgba(15, 23, 42, 0.07);
//
// ⚠ ئەم سێبەرە بە ئەنقەست **سکەیڵ ناکرێت** (وەک تۆکنە کۆنەکانی پێش خۆی):
// نرخەکان لە CSS-ەکەوە بە dp-ی جێگیر دێن.
const Color kProxoCardBorder = Color(0xFFD4D9E1);
const double kProxoCardBorderWidth = 1.0;
const List<BoxShadow> kProxoCardShadow = [
  BoxShadow(
    color: Color.fromRGBO(15, 23, 42, 0.07),
    offset: Offset(0, 8),
    blurRadius: 30,
    spreadRadius: 0,
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
// AdSurface — تاقە سەرچاوەی دیزاین بۆ ڕووکاری ڕیکلام
// ═════════════════════════════════════════════════════════════════════════════
// یەک تۆکن‌سێت بۆ هەر سێ بەشەکە، بۆیە مەحاڵە لێک جیا ببنەوە:
//
//   • `ad_screen.dart`   — لیستی ڕیکلامەکان و سکێلیتۆنەکەی
//   • باری فلتەر         — پیلی دۆخ و پیلی ماوە (لەناو `ad_screen.dart`)
//   • `ad_details.dart`  — شاشەی وردەکاری
//
// پێشتر هەر فایلێک کۆپییەکی خۆی هەبوو (`_kInk` ≠ `_kCampaignInk`،
// `_kRadiusMd` 18 ≠ `_kAdcCardRadius` 16، پەڕەی سپی ≠ پەڕەی #FAFAFA)، بۆیە
// گواستنەوە لە لیستەوە بۆ وردەکاری بە چاو دەبینرا. ئێستا هەردوو فایلەکە
// لێرەوە دەخوێننەوە — گۆڕینی یەک ژمارە لێرە هەردوو شاشەکە پێکەوە دەگۆڕێت.
//
// ⚠ ئەم تۆکنانە **سکەیڵ ناکرێن**. ژمارەکان بە dp-ی ڕاستەقینەن.
class AdSurface {
  AdSurface._();

  // ── ڕوو و پاشبنەما ────────────────────────────────────────────────────────
  /// پاشبنەمای هەردوو شاشەکە. کارتی سپی لەسەر ئەمە بە سێبەرێکی نەرم
  /// جیا دەبێتەوە بەبێ ئەوەی پێویستی بە سنوورێکی قورس بێت.
  static const Color page = Color(0xFFFAFAFA);

  /// ڕووی هەموو کارتەکان — سپی تەواو، لە هەردوو شاشەکەدا.
  static const Color card = Color(0xFFFFFFFF);

  /// هێڵی مووی سنووری کارت و پیل و جیاکەرەوەکان.
  static const Color border = Color(0xFFE2E8F0);
  static const double hairline = 1.0;

  // ── جیۆمەتری ──────────────────────────────────────────────────────────────
  /// گۆشەی خڕکراوی هەموو کارتێک — لیست و وردەکاری، هەردووکیان.
  static const double cardRadius = 16.0;

  /// پەدینگی ناوەوەی هەموو کارتێک.
  ///
  /// ⚠ بوو 14. کارتەکە بە 14 تەنگ دەردەکەوت — بەتایبەت لە دەوری
  /// پیتەی دۆخ و ڕیزی مەتریکەکان، کە هەردووکیان ڕووی ڕەنگاوڕەنگیان
  /// هەیە و بۆشایی زیاتریان دەوێت تا بەرامبەر لێواری کارتەکە
  /// «هەڵنەلوشرێن». ئەم ژمارەیە بۆ **هەردوو** شاشەکە کاردەکات.
  static const double cardPad = 16.0;
  static const EdgeInsets cardPadding = EdgeInsets.all(cardPad);

  /// گەتەری تەنیشی پەڕە — هەردوو شاشەکە یەک پانی ناوەڕۆکیان هەیە، بۆیە
  /// کارتەکە لە کاتی گواستنەوەدا نە پان دەبێت و نە تەسک.
  static const double pageGutter = 18.0;
  static const double contentMaxWidth = 398.0;

  // ── قووڵایی ───────────────────────────────────────────────────────────────
  /// سێبەرێکی ٤٪ی نەرم — دیارە وەک بەرزبوونەوە، نەک وەک «سێبەر».
  /// ⚠ بوو `0x0A000000 / blur 10 / (0, 3)`. ئێستا دەقاودەق هەمان سێبەری
  /// کارتە خێراکانی شاشەی سەرەکییە، بۆیە هەر سێ ڕووەکە — کارتی خێرا،
  /// کارتی لیستی ڕیکلام، و کارتی وردەکاری — یەک قووڵاییان هەیە.
  /// ⚠ بوو `0x08000000 / blur 10 / (0, 4)`. لەگەڵ سنوورێکی دیارتری
  /// #E2E8F0دا ئەو قووڵاییە زیادە بوو — سنوورەکە کاری دیاریکردنی
  /// لێوارەکە دەکات، بۆیە سێبەرەکە تەنها بەرزکردنەوەیەکی سووکی
  /// پێویستە. ئێستا دەقاودەق هەمان `_kCardLift`ی `tools_screen` و
  /// `_kQaShadow`ی شاشەی سەرەکییە.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// سنووری دەرەوەی کارت — **جیایە** لە `border`.
  ///
  /// `border` (#E2E8F0) هێڵی مووی ناو کارت و چیپەکانە: دەبێت بە ڕوونی
  /// ببینرێت چونکە کاری جیاکردنەوەی دوو ڕیزی تەنیشت یەکتری دەکات.
  /// سنووری دەرەوەی کارت ئەو کارە ناکات — سێبەرەکە جیاکردنەوەکە دەکات، و
  /// سنوورەکە تەنها لێوارێکی نەرم دیاری دەکات. بۆیە سووکترە.
  /// ⚠ بوو #F1F5F9. بەنچمارکەکە (فۆڕمی دروستکردنی `tools_screen`) و
  /// ئێستا کارتی لیستی ئامرازەکان و کارتە خێراکانی سەرەکی هەموویان
  /// #E2E8F0 بەکاردەهێنن. مانەوەی #F1F5F9 لێرە واتای ئەوە بوو کە
  /// کارتی ڕیکلام و کارتی وردەکاری تاقە کارتەکانی ئەپەکە بن بە
  /// سنوورێکی سووکتر — جیاوازییەکی بچووک، بەڵام لەسەر هەمان پەڕەدا
  /// دیار.
  static const Color cardBorder = Color(0xFFE2E8F0);

  // ── مەرەکەب ───────────────────────────────────────────────────────────────
  /// ناونیشان و بەها — هەمان `AppColors.ink`.
  static const Color ink = AppColors.ink; // #0B0B32

  /// لەیبڵ و مێتاداتا (ڕێککەوت، بودجە، دۆخ). سلەیتێکی ڕوون، نەک
  /// خۆڵەمێشێکی شۆردراو — پێشتر #68687F / #64748B / #94A3B8 بوون.
  static const Color slate = Color(0xFF334155);

  /// ئایکۆن و گلیفە لاوەکییەکان — چیڤرۆن، بازنەی (?)، ئایکۆنی (i)،
  /// ڕادیۆی هەڵنەبژێردراو، هێڵە وردەکان.
  ///
  /// ⚠ گلیف پێویستی بە تۆنێکی تۆختر هەیە لە دەق بۆ ئەوەی هەمان
  /// «قورسایی ئۆپتیکی» هەبێت: دەق ڕووبەرێکی داپۆشراوی هەیە، گلیفێکی
  /// هێڵکێشراو تەنها چەند پیکسلێکی تیرەیە. تۆنێکی سووک لەسەر دەق وەک
  /// «لاوەکی» دەخوێندرێتەوە؛ لەسەر گلیف وەک «ون».
  static const Color icon = Color(0xFF475569); // slate-600

  /// هێمنترین مەرەکەبی دەق. ⚠ بوو #64748B، و پێش ئەوەش #94A3B8 —
  /// هەردووکیان لەسەر ڕووی سپی شۆردراو دەردەکەوتن.
  /// ⚠ بوو `= icon` (#475569). دەق و گلیف پێویستیان بە دوو تۆنی جیاوازە
  /// (بڕوانە `icon` لە سەرەوە)، بۆیە ئەمە ئێستا مەرەکەبی **دەق**ی لاوەکییە
  /// و #64748B‌ـە — هەمان `AppColors.inkMuted`، هەمان `_kMuted`ی
  /// tools_screen، هەمان `_kFbChipIdleInk`.
  static const Color faint = AppColors.inkMuted;

  static const Color accent = AppColors.accent; // #0265FF // #0365FF
  static const Color onAccent = Color(0xFFFFFFFF);

  // ── وەزنە ─────────────────────────────────────────────────────────────────
  // Rabar تەنها یەک فەیسی ڕاستەقینەی هەیە، بۆیە w600/w700 بە کێشێکی
  // دەستکرد (synthetic bold) دەکێشرێن — جیاوازی هەیە، بەڵام کەمتر لە
  // فەیسێکی ڕاستەقینەی Bold. بڕوانە سەرەتای ئەم فایلە.
  /// ناونیشانی کەمپەین، ناوی ڕیکلام، کۆی گشتی.
  static const FontWeight wTitle = FontWeight.w700;

  /// بەهاکان، سەرناوی بەشەکان، دوگمەکان.
  static const FontWeight wStrong = FontWeight.w600;

  /// لەیبڵی لاوەکی و مێتاداتا.
  static const FontWeight wMeta = FontWeight.w500;

  // ── بەرزایی دێڕ ───────────────────────────────────────────────────────────
  // پیتی کوردی خاڵ و دووپاتەی سەرەوە/خوارەوەی زۆرە (ڕ، ژ، ێ، ڵ، ە)، بۆیە
  // 1.16ی پێشوو لە شاشەی وردەکاری دەبڕدرانەوە. هەردوو شاشەکە ئێستا لەناو
  // مەودای 1.30–1.35دان.
  static const double lineTitle = 1.30;
  static const double lineMeta = 1.35;

  // ── پیلی فلتەر ────────────────────────────────────────────────────────────
  // ⚠ پیلەکان پێشتر لە `_kCampaignButton*`ـەوە دەخوێندنەوە — واتە
  // بەرزایی **دوگمە**یان هەبوو (40 dp). دوگمە دەبێت گەورە بێت؛ فلتەر
  // نا. لەگەڵ `Expanded`ـیشدا هەریەکەیان نیوەی پانی شاشەکەی دەگرت،
  // بۆیە دوو پیلی بچووک وەک باڵێکی قورس دەردەکەوتن لە سەری لیستەکە.
  //
  // ئێستا سەربەخۆن و لە قەبارەی ناوەڕۆکی خۆیان دان.
  static const double pillHeight = 33.0; // بوو 38
  static const double pillRadius = 10.0; // بوو 12
  static const double pillPadH = 12.0; // بوو 14
  static const double pillPadV = 6.0;
  static const double pillGap = 8.0; // بوو 12
  static const double pillFontSize = 12.75;

  /// دۆخی نەهەڵبژێردراو — پڕکەرەوەی سپی، سنووری نەرم، دەقی سلەیت.
  static const Color pillIdleFill = card;
  static const Color pillIdleBorder = border;
  static const Color pillIdleInk = slate;

  /// دۆخی هەڵبژێردراو — شینی سەرەکی بە دەقی سپیی قەڵەو.
  static const Color pillActiveFill = accent;
  static const Color pillActiveBorder = accent;
  static const Color pillActiveInk = onAccent;

  // ── شیتی خوارەوە ──────────────────────────────────────────────────────────
  // ⚠ ئەم شاشەیە دوو خێزانی شیتی جیاوازی هەبوو کە هەرگیز بەراورد
  // نەکرابوون: شیتە «iOS»ـەکان (فلتەر، ماوە، ڕوونکردنەوە) بە گۆشەی 16
  // و گەتەری 18، و شیتە دەستکردەکان (ڕەتکردنەوە، دەستکاری) بە گۆشەی 26
  // و پەدینگی 20. جیاوازی 10 dpـی گۆشە لە نێوان دوو شیتی هەمان شاشەدا
  // ئەوەیە کە وەک «ناڕێک» دەخوێندرێتەوە. ئێستا هەر سێکیان لێرەوە دێن.
  static const double sheetRadius = 20.0;
  static const double sheetPad = 20.0;

  /// ڕووی شیت — سپی، وەک کارتەکان، لەسەر پەڕەی #FAFAFA.
  static const Color sheetSurface = card;

  /// دەستەکی ڕاکێشان. لەسەر ڕووی سپی دەبێت بە ڕوونی ببینرێت.
  static const Color sheetGrabber = Color(0xFFCBD5E1);

  // ── گواستنەوەی ڕێڕەو ──────────────────────────────────────────────────────
  // ⚠ ئەم چوارە ئێستا ئەلیاسی `ProxoMotion`ن، نەک ژمارەی سەربەخۆ.
  // ڕێڕەوی وردەکاری یەکەم ڕێڕەو بوو کە ماوە و کەرڤی «دروست»ی هەبوو،
  // بەڵام تاقە ڕێڕەویش بوو — واتە ئەپەکە دوو هەستی ناڤیگەیشنی هەبوو.
  // ئێستا هەموو ڕێڕەوەکان لە یەک شوێنەوە دەخوێننەوە.
  static const Duration routePush = ProxoMotion.routePush;

  /// ⚠ بوو 220ms — بە ئەنقەست کورتتر لە هاتنە ژوورەوە. ئەو لاسەنگییە
  /// خۆی سەرچاوەی هەستی «بازدان»ە: مێشک هاتن و چوونی یەک شت بە یەک
  /// خێرایی چاوەڕێ دەکات، و چوونەدەرەوەیەکی 12٪ خێراتر وەک بڕینەوە
  /// دەخوێندرێتەوە نەک وەک خێرایی.
  static const Duration routePop = ProxoMotion.routePop;

  static const Curve routeCurve = ProxoMotion.curve;

  /// پێچەوانەی **دەقیقی** `routeCurve` — نەک هەمان کەرڤ دووبارە.
  ///
  /// ئەمە خاڵێکی وردە کە زۆرجار هەڵە تێدەگیرێت: `CurvedAnimation` لە کاتی
  /// گەڕانەوەدا `reverseCurve.transform(parent.value)` دەژمێرێت، لە کاتێکدا
  /// `parent.value` لە 1 بۆ 0 دادەبەزێت. ئەگەر `easeOutCubic`ی تێبخەیت،
  /// خێرایی لای t=1 سفرە — واتە پەڕەکە سەرەتا **ناجوڵێت**، پاشان لەناکاو
  /// هەڵدەدات و دەردەچێت. ئەوە دەقاودەق ئەو «snap»ەیە کە دەبێت لابچێت.
  ///
  /// `FlippedCurve(c)` = `1 − c.transform(1 − t)`، کە بۆ `easeOutCubic`
  /// دەکاتە `t³` (واتە `easeInCubic`). ئەمە وا دەکات چوونەدەرەوە
  /// **لێدانەوەی دواوەی** هاتنە ژوورەوە بێت — هەمان شێوەی جوڵە، بە
  /// پێچەوانەوە. لەبەر ئەوەی لە `routeCurve`ـەوە دەردەهێنرێت، ئەگەر
  /// ڕۆژێک کەرڤی پاڵنان بگۆڕدرێت، ئەمەش خۆی لەگەڵی دەگۆڕێت.
  static const Curve routeCurveReverse = ProxoMotion.curveReverse;

  /// ئەوەی `ad_screen.dart` چاوەڕێی دەکات پێش ئەوەی بۆی هەبێت `setState`
  /// بکات دوای گەڕانەوە. دەبێت **درێژتر** بێت لە `routePop`، نەک کورتتر:
  /// هەر بنیاتنانەوەیەکی لیست کە بکەوێتە ناو پەنجەرەی ئەنیمەیشنەکەوە
  /// فرەیمێکی کەوتووە کە بەکارهێنەر دەیبینێت — هەر لەو ساتەدا کە
  /// لیستەکە دەگەڕێتەوە.
  static Duration get routeSettle =>
      routePop + const Duration(milliseconds: 30);

  /// ڕێڕەوی وردەکاری لە `pageTransitionsTheme`ی ئەپەکەوە دەخوێنێتەوە
  /// (`CupertinoPageTransitionsBuilder`)، بۆیە ئیشارەتی سوایپ لە لێواری
  /// دەست دەکەوێت — هەمان ئەوەی هەموو شاشەکانی تری ئەپەکە هەیانە.
  ///
  /// بیکە بە `false` بۆ گەڕانەوە بۆ سلایدی دەستکردی پێشوو (کەرڤی
  /// `routeCurve`، بەڵام **بێ** ئیشارەتی سوایپ — ئەو ئیشارەتە لە
  /// `PageRouteBuilder`دا بوونی نییە).
  static const bool useAppPageTransition = true;

  // ── Hero ──────────────────────────────────────────────────────────────────
  /// وێنۆچکەی ڕیکلام لە کارتەکەوە دەفڕێت بۆ شاشەی وردەکاری.
  /// ئەگەر لەسەر ئامێری ڕاستەقینە هەر کێشەیەکی هەبوو، تەنها ئەمە بکە بە
  /// `false` — هەردوو شاشەکە بەبێ هیچ گۆڕانکارییەکی تر کاریان دەکات.
  static const bool heroThumbnail = true;

  /// تاگی Hero بۆ وێنۆچکەی ڕیکلام. هەردوو شاشەکە هەمان `ad['id']`
  /// بەکاردەهێنن، بۆیە هەرگیز دوو تاگی جیاواز دروست نابن.
  static String thumbHeroTag(Object? adId) => 'ad-thumb-$adId';

  /// قەبارەی دیکۆدی وێنۆچکە بە dp — **هەردوو** لاکە هەمان ژمارە داوا
  /// دەکەن، و ئەوە بە ئەنقەستە.
  ///
  /// `CachedNetworkImage` بە `memCacheWidth/Height` وێنەکە دەخاتە ناو
  /// `ResizeImage`ـێکەوە، و `ResizeImage` پانی و بەرزی دەخاتە ناو
  /// کلیلی کاشەکەوە. بۆیە کارتێک کە 42 dp داوا دەکات و شاشەی
  /// وردەکاری کە 56 dp داوا دەکات دوو **دیکۆدی جیاواز**ی هەمان وێنەن.
  ///
  /// ئەنجامەکەی لە کاتی فڕینی Heroدا دەردەکەوێت: Flutter شاتڵی
  /// **مەبەست** بەکاردەهێنێت، بۆیە فڕینی چوونە ژوورەوە داوای دیکۆدی
  /// 56 dp دەکات — کە هێشتا ئامادە نییە. لە ناوەڕاستی فڕیندا
  /// جێگرەوەکە (خشتەی شینی مێگافۆن) دەردەکەوێت و پاشان وێنەکە
  /// جێی دەگرێتەوە. ئەوە دەقاودەق ئەو «چرپە»یەیە.
  ///
  /// یەک ژمارە = یەک کلیلی کاش = یەک دیکۆد، بۆیە فڕین لە هەردوو
  /// ئاراستەدا وێنەیەکی ئامادە دەبینێت. 60 dp لە سەرووی گەورەترین
  /// قەبارەی نمایشە (56 × 1.06 = 59.4)، بۆیە هیچ لایەک وێنەیەکی
  /// هەڵکێشراو نانوێنێت.
  static const double thumbDecodeDp = 60.0;

  /// خانەی وێنۆچکەی کارتی لیست.
  ///
  /// ⚠ بوو 42 — کە بەرامبەر بە ناونیشانێکی w700ی 14.4 dp و پیتەیەکی
  /// دۆخ بچووک دەردەکەوت، و سەرپەڕەی کارتەکەی تەنگ دەکردەوە
  /// (`_kAdcHeaderH` = هەر ئەم ژمارەیە). 52 وێنۆچکەکە دەکاتە
  /// توخمێکی ڕاستەقینەی سەرپەڕەکە، نەک ئایکۆنێک.
  ///
  /// دەستکەوتێکی لاوەکی: شاشەی وردەکاری وێنۆچکەیەکی 56 dpـی هەیە،
  /// بۆیە فڕینی Hero ئێستا 52 → 56ـە لە جیاتی 42 → 56 — نزیکەی
  /// هیچ گۆڕانێکی قەبارە، کە فڕینەکە هێمنتر دەکات.
  static const double thumbSize = 52.0;

  /// گۆشەی وێنۆچکە — لە هەردوو شاشەکەدا.
  static const double thumbRadius = 12.0;

  /// قەبارەی دیکۆد بە پیکسل بۆ ئەم ئامێرە.
  static int thumbDecodePx(double devicePixelRatio) =>
      (thumbDecodeDp * devicePixelRatio).round();

  /// فڕینی ڕاست‌هێڵ بۆ وێنۆچکە.
  ///
  /// `MaterialApp` بە بنەڕەت `HeroController`ێک دادەمەزرێنێت کە
  /// `MaterialRectArcTween` بەکاردەهێنێت، واتە هەموو Heroـیەک بە
  /// **کەوانە**دا دەفڕێت. ئەوە بۆ کارتێکی گەورە جوانە، بەڵام بۆ
  /// وێنۆچکەیەکی 42–56 dp کە مەودایەکی کورت دەبڕێت وەک هەڵسوڕانێکی
  /// بێ‌هۆ دەردەکەوێت — بەتایبەت لە کاتی گەڕانەوەدا، کە چاو چاوەڕێی
  /// دەکات ڕاستەوخۆ بگەڕێتەوە شوێنی خۆی لە لیستەکەدا.
  ///
  /// هەردوو لای Hero ئەم یەک فەنکشنە بەکاردەهێنن، بۆیە هاتن و چوون
  /// ناتوانن دوو ڕێڕەوی جیاواز بگرنەبەر.
  static RectTween thumbRectTween(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: end);
}

/// گرادیێنتی تۆخی بران.
///
/// ⚠ ئەم کلاسە **نوێیە**. کۆدی داواکراو ئاماژەی بە `ProxoInk.gradient`
/// دەکرد وەک شتێکی بوونی هەبێت، بەڵام لە ڕیپۆکەدا هیچ شوێنێک نەبوو —
/// هیچ گرادیێنتێکی تۆخ لە ئەپەکەدا نەبوو. لێرە دروست کراوە وەک تاقە
/// سەرچاوە، بۆیە هەر شوێنێکی تر پێویستی پێی بوو لێرەوە دەیخوێنێتەوە.
///
/// `start` دەقاودەق هەمان `AppColors.ink`ە، بۆیە گرادیێنتەکە لە هەمان
/// مەرەکەبی دوگمە سەرەکییەکانەوە دەست پێدەکات و تەنها بەرەو سلەیتێکی
/// ڕووناکتر دەڕوات — واتە لەتەنیشت دوگمەیەکی تەختی #0F172A دا وەک دوو
/// ڕەنگی جیاواز دەرناکەوێت.
abstract final class ProxoInk {
  /// ⚠ ئیتر گرادیێنت **نییە**. ڕوو ڕەنگێکی ڕەقی تاکە: #0265FF.
  ///
  /// `gradient` وەک خۆی ماوەتەوە بۆ ئەوەی شوێنە بەکارهێنەرەکانی
  /// نەشکێن (`AuthSegmentedControl`)، بەڵام هەردوو ستۆپەکەی ئێستا
  /// هەمان ڕەنگن — واتە بە چاو ڕەنگێکی ڕەقە.
  static const Color start = Color(0xFF0265FF);
  static const Color end   = Color(0xFF0265FF);

  /// ڕەنگی دەق لەسەر `start` — سپی، بۆ کۆنتراستێکی ڕوون.
  static const Color onInk = Color(0xFFFFFFFF);

  static const LinearGradient gradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [start, end],
  );

  // ── ئەمانە لە `deposit_screen.dart` بەکاردەهێنران بەڵام هەرگیز پێناسە
  //    نەکرابوون — بۆیە پڕۆژەکە build نەدەبوو. ─────────────────────────

  /// دەقی دوگمەیەکی ناچالاک (toggle) لەسەر باکگراوندی سپی.
  static const Color outlineText = start;

  /// ڕووی شینی ڕەق.
  static BoxDecoration fill({double radius = 12, bool elevated = true}) =>
      BoxDecoration(
        color: start,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? const <BoxShadow>[
                BoxShadow(
                    color: Color(0x290265FF),
                    blurRadius: 14,
                    offset: Offset(0, 4)),
              ]
            : null,
      );

  /// دوگمەی ناچالاک (کاتی ناردن).
  static BoxDecoration disabled({double radius = 12}) => BoxDecoration(
        color: const Color(0xFFB9C9E6),
        borderRadius: BorderRadius.circular(radius),
      );

  /// هەڵبژاردەی خێرا: چالاک = شین، ناچالاک = سپی بە سنووری شینی کاڵ.
  static BoxDecoration toggle(bool active, {double radius = 12}) => active
      ? fill(radius: radius, elevated: false)
      : BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFCFE0FF)),
        );
}

// ═════════════════════════════════════════════════════════════════════════════
// ProxoMotion — ماوە و کەرڤی ناڤیگەیشن بۆ هەموو ئەپەکە
// ═════════════════════════════════════════════════════════════════════════════
class ProxoMotion {
  ProxoMotion._();

  /// هاتنە ژوورەوە.
  static const Duration routePush = Duration(milliseconds: 250);

  /// چوونەدەرەوە — **دەقاودەق** وەک هاتنە ژوورەوە.
  ///
  /// ⚠ زۆرێک لە ڕێڕەوەکانی ئەم ئەپە پێشتر چوونەدەرەوەیەکی کورتتریان
  /// هەبوو (یان هیچ `reverseTransitionDuration`ێکیان نەبوو، بۆیە
  /// 300msـی بنەڕەتیان دەگرت). لاسەنگی نێوان هاتن و چوون خۆی
  /// سەرچاوەی هەستی «بڕینەوە»یە: مێشک هاتن و چوونی یەک شت بە یەک
  /// خێرایی چاوەڕێ دەکات.
  static const Duration routePop = routePush;

  static const Curve curve = Curves.easeOutCubic;

  /// پێچەوانەی **دەقیقی** `curve` — نەک هەمان کەرڤ دووبارە.
  /// بڕوانە `AdSurface.routeCurveReverse` بۆ ڕوونکردنەوەی تەواو:
  /// دووبارە بەکارهێنانی `easeOutCubic` لە گەڕانەوەدا پەڕەکە سەرەتا
  /// ڕادەگرێت پاشان هەڵیدەدات.
  static const Curve curveReverse = FlippedCurve(curve);
}

/// ڕێڕەوی ستانداردی ئەپەکە — **هەموو** ناڤیگەیشنێکی بەرەوپێش ئەمە
/// بەکاردەهێنێت.
///
/// ══ بۆچی `MaterialPageRoute` و نەک `PageRouteBuilder` ═══════════════════
/// `main.dart` ئەمەی دانراوە:
///
///     pageTransitionsTheme: AuthTokens.pageTransitionsTheme
///         → CupertinoPageTransitionsBuilder() بۆ android / iOS / macOS
///
/// ئەو builderە لەناو خۆیدا `_CupertinoBackGestureDetector` دادەمەزرێنێت —
/// **تاقە سەرچاوەی** ئیشارەتی «سوایپ لە لێوارەوە بۆ گەڕانەوە» لە
/// Flutterدا. بەڵام ئەو تیمە تەنها لەو ڕێڕەوانەدا کاردەکات کە
/// `buildTransitions`ی خۆیان **نەگۆڕیوە**.
///
/// `PageRouteBuilder` بە پێناسە `transitionsBuilder`ی خۆی هەیە، بۆیە
/// تیمەکە بە تەواوی پشتگوێ دەخات. ئەنجامەکەی لەم ئەپەدا ئەمە بوو:
/// نۆ شاشە (مێژووی مامەڵە، ئەرکەکان، ئاستەکان، ڤاوچەر، کۆدی داشکاندن،
/// پرۆفایل، سڕینەوەی هەژمار، باشترین مەتریک، وردەکاری ڕیکلام) هیچ
/// ئیشارەتی سوایپیان نەبوو، لە کاتێکدا شاشەکانی تر هەیانبوو.
///
/// ══ RTL ════════════════════════════════════════════════════════════════
/// `CupertinoPageTransition` ڕاستەوخۆ `Directionality.of(context)`
/// دەخوێنێتەوە و دەیدات بە `SlideTransition.textDirection`، و بۆکسی
/// ڕاکێشانەکەش `PositionedDirectional(start: 0)`ە. واتە لە RTLدا پەڕەی
/// نوێ لە **چەپ**ەوە دێتە ژوورەوە و ئیشارەتەکە لە لێواری **ڕاست**ەوەیە —
/// خۆکارانە، بەبێ هیچ کۆدێکی تایبەت. ڕێڕەوە دەستکردەکان `Offset(1, 0)`ی
/// چەسپاویان بەکاردەهێنا، کە هەمیشە لە ڕاستەوە دەهات — پێچەوانەی
/// ئاراستەی خوێندنەوەی زمانەکە.
///
/// ══ نرخەکەی ═══════════════════════════════════════════════════════════
/// کەرڤەکە `ProxoMotion.curve` نییە بەڵکو `linearToEaseOut`ی Cupertino
/// (زۆر نزیکە لێی — هەردووکیان خاوبوونەوەن). `_CupertinoBackGestureDetector`
/// لە Flutterدا پرایڤەتە، بۆیە مەحاڵە هەم ئیشارەتەکەت هەبێت و هەم
/// کەرڤی خۆت. ئیشارەتەکە گرنگترە.
///
/// ⚠ `fullscreenDialog: true` ئیشارەتی سوایپ **لادەبات** (بڕوانە
/// `CupertinoRouteTransitionMixin._isPopGestureEnabled`). تەنها بۆ
/// شاشەی مۆداڵی ڕاستەقینەی بەکاربهێنە کە لە خوارەوە دێن و دەبێت بە
/// دوگمە دابخرێن.
class ProxoPageRoute<T> extends MaterialPageRoute<T> {
  ProxoPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
    super.maintainState,
  });

  @override
  Duration get transitionDuration => ProxoMotion.routePush;

  @override
  Duration get reverseTransitionDuration => ProxoMotion.routePop;
}
