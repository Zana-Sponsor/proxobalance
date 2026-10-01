import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart' show showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../theme/proxo_icons.dart';
import '../main.dart' show supabase;
import '../widgets/proxo_toast.dart';
import '../widgets/proxo_error_ui.dart';
import '../widgets/top_bar.dart';
import '../widgets/proxo_refresh.dart';
import '../widgets/ad_feedback.dart';
import 'ad_create_screen.dart';
import 'ad_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdScreen — ڕیکلامەکانم
// ─────────────────────────────────────────────────────────────────────────────
//
// The advertiser's own ad list: filter bar, ad cards, pagination, and the
// actions that hang off a card (details, duplicate, cancel, share).
//
// ── THE CARD ────────────────────────────────────────────────────────────────
// The collapsed card carries only what identifies an ad:
//
//   header      portrait thumbnail (`thumbnail_url`, illustrated fallback when absent) ·
//               ad name · `#code` (tap to copy) · status pill
//   metrics     three equal white mini-cards with soft elevation —
//               بینینەکان · کرتەکان · تێچوو
//   control     «بینینی زیاتر», which expands the card in place to reveal
//               تێچووی کرتە · ڕێژەی کرتە · کرداری سەرکەوتوو. Tapping any
//               metric opens an app-styled explanation sheet.
//
// Everything else about an ad — dates, budget, objective, audience, video
// link — lives in `ad_details.dart`. It was removed from the CARD, never from
// the data: no column left `_adColumns` and no query changed.
//
// ── SCALE ───────────────────────────────────────────────────────────────────
// One number drives the whole card: `_campaignScale` = width ÷ 430 × 1.06,
// clamped to 0.86–1.06, with type on a tighter 0.92 floor (`_typeScaleFor`).
// Every dimension is that factor times a constant, so the card holds its
// proportions from 320 dp to 430 dp without a single absolute position.
// Columns are `Expanded`; values sit in `FittedBox(scaleDown)`. There is no
// hardcoded width anywhere in the card.
//
// ── PERFORMANCE ─────────────────────────────────────────────────────────────
// Thumbnails decode at their painted pixel size, `RepaintBoundary` isolates
// every card, and `findChildIndexCallback` keeps keyed cards matched by ad id
// when the list changes. Returning from `ad_details.dart` costs nothing
// unless the ad actually changed — see `_openAdDetails` — and pull-to-refresh
// updates values in place rather than tearing the list down; see
// `_syncAdsSilently`.
// ─────────────────────────────────────────────────────────────────────────────

enum AdFilter { all, active, pending, review, scheduled, rejected, completed, paused }

// ── پارسکردنی سەلامەتی ژمارە — لادانی هەڵەی 'X as num?' کاتێک خانەیەکی
// داتابەیس بەشێوەیەکی چاوەڕوان نەکراو (بۆ نموونە String یان '') دەگەڕێتەوە.
// ئەم هەڵەیە هۆکاری ئەوە بوو کە مۆدالی "وردەکاری ڕیکلام" بەتاڵ و خۆڵەمێشی
// (grey) دەردەکەوت بۆ هەندێک ڕیکلام کە داتاکەی تەواو نەبوو.
num? _asNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyAdsIllustration — ئیلوستراسیۆنی «هیچ ڕیکلامێک نییە»
// ─────────────────────────────────────────────────────────────────────────────
// ⚠ ئەم دۆخە بەتاڵە ئێستا جیاوازە لە هی `home_screen.dart`: ئارتوۆرکی
// نوێی سندوق + مێگافۆن (`empty_ads_box.png`) و ڕەمپێکی نوێی تایپ و
// بۆشایی وەرگرتووە، لە کاتێکدا داشبۆرد هێشتا لەسەر `empty_ads.png`ی
// کۆنە. ئەگەر ویستت هەردووکیان یەک بن، هەمان ژمارە و هەمان ئاسێت لە
// `home_screen.dart`ـیش دابنێ (بڕوانە تێبینی «Empty-state language»).
//
// وێنەکە شەفافە (پڕکەرەوەی ناو مێگافۆنیش)، بۆیە لەسەر هەر یەکێک لە چوار
// ئاستی `AppColors`ـەکە هەمان شێوە دەبینرێت. ڕەنگەکانی خۆی لە شینی
// سیستەمن، بۆیە هیچ تینتێکی پێ نادرێت — ئەگەرنا پیلە سووکەکان و گلیفەکە
// یەک تۆن دەبن و قووڵایی لەدەست دەدەن.
const double _kEmptyArtW      = 216.0;         // پانی ئارتوۆرکەکە (dp)
const double _kEmptyArtAspect = 966.0 / 672.0; // = 1.4375، ڕاستەوخۆ لە فایلەکەوە
const String _kEmptyArtAsset  = 'assets/images/empty_ads_box.png';
// قەبارەی ڕاستەقینەی فایلەکە بە px — تەنها بۆ سنووری `cacheWidth/Height`.
const int _kEmptyArtPxW = 720;
const int _kEmptyArtPxH = 501;

class _EmptyAdsIllustration extends StatelessWidget {
  final double scale;
  final String? semanticLabel;

  const _EmptyAdsIllustration({required this.scale, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final double w = _kEmptyArtW * scale;
    final double h = w / _kEmptyArtAspect;
    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;

    return RepaintBoundary(
      child: Image.asset(
        _kEmptyArtAsset,
        width: w,
        height: h,
        // بە قەبارەی پێویست دیکۆد بکە، نەک وێنەی تەواو بۆ بۆکسێکی
        // نزیکەی 200 dp؛ بەمە memory و سکڕۆڵ سووکتر دەبن.
        cacheWidth: (w * dpr).ceil().clamp(72, _kEmptyArtPxW),
        cacheHeight: (h * dpr).ceil().clamp(50, _kEmptyArtPxH),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

String _thousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED TOKENS (`_ds…`) — the app-wide ramp this screen draws from
// ═════════════════════════════════════════════════════════════════════════════
// These are the dashboard's tokens, renamed only by prefix because this file
// already owns a `_k…` namespace. Surfaces and ink come from `AppColors` in
// `app_theme.dart`, so the screen follows the app if the ramp ever moves.

// Reference palette: electric blue campaign accent, near-white card, cool page
// background, navy ink, muted slate labels, and green positive deltas.
const Color _dsBlue      = AppColors.accent;
// Surfaces come from the app-wide ramp in app_theme.dart — see AppColors.
//
// ⚠ پاشبنەمای پەڕە **لێرەدا** پێناسە دەکرێت، نەک لە `AppColors.surfaceBase`ەوە.
// ئەمە بە ئەنقەستە: #FAFAFA تەنها بۆ ئەم شاشەیە داواکراوە، و گۆڕینی
// `surfaceBase` هەموو شاشەکانی تری ئەپەکەی دەگرتەوە. ئەگەر ڕۆژێک هەموو
// ئەپەکە چووە سەر ئەم تۆنە، ئەمە بگەڕێنەرەوە بۆ `AppColors.surfaceBase`.
//
// خۆڵەمێشێکی بێلایەن (بێ تۆنی شین) — کارتی سپی و پیلی سپی لەسەری بە
// هێڵی مووی و سێبەری نەرمەکەیان جیا دەبنەوە.
const Color _dsPageBg    = AdSurface.page;
const Color _dsCard      = AppColors.surfaceCard;
const Color _dsBorder    = AppColors.surfaceBorder;
const Color _dsInk       = AppColors.ink;
const Color _dsSubtle    = AppColors.inkMuted;
const Color _dsSkeleton  = Color(0xFFE2E5EF); // لەسەر سپی دیارتر
const Color _dsInfoBg    = Color(0xFFF0F4FF);

/// سێبەری کارتەکانی ئەم شاشەیە (بانەری ئۆفلاین، کارتی ئاگاداری، دۆخی
/// بەتاڵ) — ئێستا **هەمان** `kProxoCardShadow`ی کارتی ڕیکلامە، نەک
/// کۆپییەکی لاوازتر.
///
/// پێشتر دوو قووڵایی جیاواز لەسەر یەک شاشە بوون:
///   کارتی ڕیکلام   0 8px 30px rgba(15,23,42,.07)   ← app_theme
///   `_DsCard`      0 4px 12px rgba(0,0,0,.063)     ← کۆپییەکی ناوخۆیی
/// لەسەر پەڕەی سپیی پێشوو ئەم جیاوازییە بەزەحمەت دەبینرا. لەسەر #FAFAFA
/// هەر دوو کارتەکە زیاتر لە پەڕەکە هەڵدەستن، بۆیە جیاوازییەکەیان ڕوون
/// دەبێتەوە — کارتی ئاگاداری تەخت دەردەکەوت لە تەنیشت کارتی ڕیکلامدا.
/// ئێستا یەک سەرچاوەی «قووڵایی» بۆ هەموو شاشەکە هەیە.
const List<BoxShadow> _dsCardShadow = AdSurface.cardShadow;

// ── Geometry (dp at scale 1.0 = a 430 dp device) ────────────────────────────
const double _dsScreenPad   = 16.0;  // 390 spec: 16 px gutter → card width 358
const double _dsCardRadius = AdSurface.cardRadius;
const double _dsCardPad    = 18.0;
const double _dsTile       = 46.0;
const double _dsTileIcon   = 26.0;
const double _dsTileGutter = 14.0;
const double _dsGapCard    = 12.0;  // v2: ڕیتمی لیستی پوختتر (بوو 19)
const double _dsRowGap     = 16.0;
const double _dsTitleGap   = 4.0;   // title → subtitle
const double _dsTrailGap   = 12.0;  // text column → trailing affordance
const double _dsRule       = 1.0;   // hairline, never scaled

// ── Type ramp — the dashboard's, unchanged ─────────────────────────────────
const double _dsFsTitle    = 14.0;  // w700 / h 1.30–1.35 / ls −0.2
const double _dsFsAction   = 11.0;  // w700 — "View All"
const double _dsFsBody     = 11.0;  // w400 / h 1.35
const double _dsFsMicro    =  9.5;  // w400 / h 1.35
const double _dsFsAmount   = 14.0;  // w700 / h 1.35
const double _dsFsStatLbl  = 10.5;  // w500 / h 1.25
const double _dsFsStatVal  = 14.2;  // w700 / ls −0.2 / h 1.2
const double _dsFsDelta    = 11.0;  // w600 / h 1.2
const double _dsFsPill     =  9.8;  // w600 / h 1.0 — measured 9.8 dp painted
const double _dsFsChip     = 11.0;  // w600 / h 1.2

// ── Empty-state language ────────────────────────────────────────────────────
// A direct mirror of the refined below-banner system in `home_screen.dart`, so
// the Campaigns empty state and the Dashboard empty state are the same object
// seen twice. Values are duplicated rather than imported because the two files
// deliberately keep separate token namespaces — if one moves, move the other.

// ═════════════════════════════════════════════════════════════════════════════
// RESPONSIVE SCALE — one factor, anchored on the 430 dp reference device
// ═════════════════════════════════════════════════════════════════════════════
// The whole card is authored in "constant units" measured off the reference
// raster, and EVERY dimension is multiplied by this one factor — so nothing is
// ever stretched independently and the proportions the reference fixes
// (padding, gutters, icon-to-text, column widths, bar thickness, button
// height, radii, section spacing) hold at every width.
//
//   scale = screenWidth / 430 × 1.06, clamped
//
// The × 1.06 is what makes the reference device land exactly where it was
// measured: at 430 dp the factor is 1.06, which is the painted-dp multiplier
// every `_kCampaign…` constant was derived against. Below the clamp floor the
// card stops shrinking with the screen and simply carries a slightly larger
// share of it, which is what keeps a 320 dp phone legible.
//
//   320 → 0.860 (floor)   360 → 0.887   375 → 0.924   390 → 0.961
//   393 → 0.969           412 → 1.015   430 → 1.060 (reference, exact)
const double _kRefDeviceWidth = 430.0; // the reference screenshot's device
const double _kRefScale       = 1.06;  // painted dp per constant unit there
const double _kScaleMin       = 0.86;
const double _kScaleMax       = 1.06;

/// UNCHANGED, and deliberately so: this is byte-for-byte `home_screen.dart`'s
/// `_scaleFor`, so a 14 dp label in this screen's sheets, notices and offline
/// banner is still the same physical size as a 14 dp label on the dashboard of
/// the same device. The campaign card does NOT use it — see `_campaignScaleFor`
/// below — because the card is measured against a 430 dp raster, not the 393 dp
/// the dashboard was authored at.
double _dsScaleFor(double contentWidth) =>
    (contentWidth / 393.0).clamp(_kScaleMin, _kScaleMax);

double _responsiveScale(BuildContext context) =>
    _dsScaleFor(MediaQuery.sizeOf(context).width);

/// The campaign card's single scale factor, anchored on the reference device.
///
///   scale = screenWidth ÷ 430 × 1.06, clamped to 0.86 … 1.06
///
/// EVERY card dimension is this one number times a measured constant, so no
/// part of the card can stretch independently of any other: padding, gutters,
/// icon-to-text gaps, column flexes, bar thickness, button height, radii and
/// section spacing all move together. At 430 dp it returns exactly 1.06 — the
/// painted-dp multiplier every `_kCampaign…` constant was derived against — so
/// the reference layout is reproduced to the pixel there and adapts
/// proportionally everywhere else.
double _campaignScaleFor(double screenWidth) =>
    (screenWidth / _kRefDeviceWidth * _kRefScale).clamp(_kScaleMin, _kScaleMax);

double _campaignScale(BuildContext context) =>
    _campaignScaleFor(MediaQuery.sizeOf(context).width);

/// Type and glyph-adjacent sizes ride the SAME factor, on a tighter floor.
///
/// Geometry may shrink to 0.86 on a 320 dp phone, but a 10.5 label taken to
/// 0.86 lands at 9.0 dp, which is below comfortable reading size. Clamping the
/// type factor to 0.92 costs ~0.6 dp of column width per label — verified to
/// still fit at 320 dp — and keeps every string legible. At the 430 dp
/// reference the two factors are identical (1.06), so the measured layout is
/// reproduced exactly; they only diverge on small phones.
const double _kTypeScaleMin = 0.92;

double _typeScaleFor(double scale) => scale.clamp(_kTypeScaleMin, _kScaleMax);

/// Widest the card is ever drawn. Past the reference device the card stops
/// growing and centres instead, so a foldable or a tablet gets the reference
/// proportions with wider gutters rather than a stretched metric strip.
/// 430 − 2 × 16.1 gutters = the reference card's own painted width.
const double _kCampaignCardMaxWidth = AdSurface.contentMaxWidth;

// ═════════════════════════════════════════════════════════════════════════════
// Back-compatible aliases
// ═════════════════════════════════════════════════════════════════════════════
// Each of these RESOLVES TO A SHARED `_ds…` VALUE, so the state logic and
// painters that reference them follow the app ramp without a call-site change.
// Nothing here is a new number; each is an alias.

/// Readability multiplier. The card's type used to run 23 % over the measured
/// mock because larger glyphs were asked for twice. The dashboard ramp is now
/// the source of truth, so this is 1.0 — but it is deliberately still wired to
/// every card font size below. Set it back to 1.23 to restore the old, larger
/// card type in one edit; nothing else needs to change.
const double _kReadableBump = 1.0;

const double _kBtnHeight     = 30.0;          // = _PrimaryButton's height
const double _kBtnRadius     = 8.0;           // = _PrimaryButton's radius
const double _kBtnChevron    = 16.0;
const double _kBtnChevronPad = 13.0;          // = _PrimaryButton's h-padding

// ═════════════════════════════════════════════════════════════════════════════
// CAMPAIGN CARD — v6 geometry, measured off the reference screenshot
// ═════════════════════════════════════════════════════════════════════════════
// The mock of record is the single-card reference screenshot (853 × 1844 px).
// It renders on a 430 dp device at 1.984 px/dp, and `_responsiveScale` clamps
// to 1.06 there, so — exactly as for the previous revision — every constant
// below is
//
//     constant = raw px ÷ 1.984 ÷ 1.06 = raw px ÷ 2.103
//
// and the painted dp on the reference device is `constant × 1.06`. The 1.06
// clamp is load-bearing: do not "fix" it to 1.0 without re-deriving these.
//
// Each line carries the raw px measurement it came from. Text sizes are
// derived from measured ink through Inter's cap height (0.72727 em) and, for
// strings with a descender, cap + descender (0.937 em).
//
// The card holds, top to bottom: header (tile + name + Ad ID + status pill),
// the flight-date row, the day-counter row, Budget Progress + its bar, a
// four-column metric strip with full-height dividers, and the two soft
// light-blue action buttons.
// ── دیوارەی لاپەڕە — یەک ژمارە بۆ TopBar، فلتەرەکان و کارتەکان ─────────────
//
// `ProxoTopBar` (lib/widgets/top_bar.dart، دێڕی 70) پەدینگێکی **جێگیری**
// 18 dp بەکاردەهێنێت:
//
//     padding: EdgeInsets.only(top: topPadding, left: 18, right: 18)
//
// ئەو ژمارەیە لەگەڵ هیچ سکەیڵێکدا ناگۆڕێت. بەڵام گەتەری ئەم لاپەڕەیە
// 15.2 × scale بوو، واتە:
//
//     390 dp تەلەفۆن → 15.2 × 0.961 = 14.6 dp
//     430 dp تەلەفۆن → 15.2 × 1.060 = 16.1 dp
//
// بۆیە لێواری کارتەکان و پیلە فلتەرەکان لە هیچ پانییەکدا لەگەڵ لۆگۆ و
// دوگمەی مێنیوی سەرەوە لەسەر یەک هێڵی ستوونی نەبوون — جیاوازی 1.9 تا
// 3.4 dp، کە بە چاو بەرچاوە کاتێک سکڕۆڵ دەکەیت.
//
// ئێستا هەمان 18ی جێگیرە و **لە هیچ شوێنێکدا لە سکەیڵ نادرێت**، بۆیە
// TopBar → فلتەر → کارت لە هەموو ئامێرێکدا یەک لێواریان هەیە.
//
// نرخەکەی: کارتەکە لەسەر تەلەفۆنێکی 390 dp نزیکەی 6.8 dp تەسکتر دەبێت لە
// پێشوو. ئەوە بە ئەنقەستە — بەرامبەری هێڵێکی ستوونی ڕاست‌وڕەوانە.
const double _kPageGutter               = AdSurface.pageGutter;
const double _kCampaignPageGutter       = _kPageGutter;
// سەرەی یەکەم کارت. 7.1 → 8.0 بۆ ئەوەی بۆشایی نێوان پیلەکان و یەکەم کارت
// ببێتە 8 (پەدینگی خواروی بار) + 8 = 16 dp تەواو. ڕیتمی ستوونی ئێستا:
//     TopBar → پیل   12 dp
//     پیل   → کارت   16 dp
//     کارت  → کارت   19 dp   (`_dsGapCard`)
// بۆشایی گەورەتر بەرەو خوارەوە دەڕوات، بۆیە پیلەکان بە سەرەوە دەلکێن و
// کارتەکان هەناسەیان هەیە — گواستنەوەیەکی سروشتی، نەک سێ بۆشایی هاوشێوە.
const double _kCampaignListTop          =  8.0;
const double _kCampaignPadLeft          = AdSurface.cardPad;  // 14
const double _kCampaignPadRight         = AdSurface.cardPad;
const double _kCampaignPadTop           = AdSurface.cardPad;
const double _kCampaignPadBottom        = AdSurface.cardPad;

// ── Header ──────────────────────────────────────────────────────────────────
const double _kCampaignTileSize         = AdSurface.thumbSize;   // 52
const double _kCampaignTileRadius       = AdSurface.thumbRadius; // 12
const double _kCampaignHeaderHeight     = _kCampaignTileSize;
const double _kCampaignTileTextGap      = 10.0;  // v2 (بوو 12)
/// ناو → #کۆد. ⚠ بوو 2.5، کە لەگەڵ ناونیشانێکی w700دا دوو دێڕەکەی
/// بەیەکەوە دەلکاند. 4 هێندە هەیە کە جیایان بکاتەوە بەبێ ئەوەی
/// ستوونەکە بتەقێنێت.
const double _kCampaignTitleIdGap       =  4.0;

// ── پەستان — یەک تۆکن بۆ هەموو ڕووکارە لێدراوەکان ──────────────────────────
// پێشتر هەر پێکهاتەیەک سکەیڵی خۆی هەبوو: دوگمەی کارت 0.97، پیلی فلتەر 0.96،
// دوگمەی داخستنی شیت 0.90. جیاوازییەکی بچووکە بەڵام بە پەنجە هەست پێدەکرێت —
// هەر ڕووکارێک «قورسایی»ەکی جیاوازی هەبوو. ئێستا هەموویان یەک ژمارە
// دەخوێننەوە، بۆیە پیلی فلتەر و دوگمەی کارت دەقاودەق یەک کاردانەوەیان هەیە.
//
// تاقە دەرچوون: خودی کارتەکە (`_kCardTapOpensDetails`) لەسەر 0.985 دەمێنێتەوە —
// ڕووبەرێکی گەورەیە و 0.97ی لەسەر بە جوڵەیەکی زۆر گەورە دەردەکەوێت. ئەوە
// هەڵبژاردنێکی دیزاینە، نەک لاسەنگی.
const double _kPressScale   = 0.97;
const double _kPressOpacity = 0.55;

// ── کاردانەوەی داگرتنی کارت — سکەیڵ + چینێکی شینی زۆر نەرم ──────────────────
// پێشتر کارتەکان بە کەمکردنەوەی «ڕوونی» (opacity) کاردانەوەیان دەنواند —
// ئەوە هەموو ناوەڕۆکەکە (دەق، ئایکۆن، شین) پێکەوە بێهێز دەکردەوە و وەک
// خۆڵەمێشی دەردەکەوت. ئێستا لەبری ئەوە چینێکی **شین** بەسەر ڕووی کارتەکەدا
// دادەنرێت: هەمان زمانی ڕەنگی ئەپ، بەبێ ڕەش/خۆڵەمێشی.
//
//   • ڕووە سپی/ڕووناکەکان (کارتی ڕیکلام، دوگمە نەرمەکان)  → `_kPressTint`
//   • ڕووە شینە قووڵەکان (وەک کارتی Overview / CTA-ی شین) → `_kPressTintOnBlue`
//
// چینەکە بە هەمان `borderRadius`ی کارتەکە وێنا دەکرێت، بۆیە هەرگیز لە
// گۆشە خڕەکان نایەتە دەرەوە — و چونکە `ClipRRect` بەکارنەهێنراوە، سێبەری
// کارتەکە وەک خۆی دەمێنێتەوە (کلیپ سێبەری دەبڕی).
const Color _kPressTint       = Color(0x0F0D73E8); // ~6% شینی سەرەکی
const Color _kPressTintOnBlue = Color(0x14FFFFFF); // ~8% سپی بۆ ڕووی شین

/// خێرا بەڵام نەرم. `_kFbPressDur`ی پیلەکان 90ms-ە؛ کارت ڕووبەرێکی
/// گەورەترە بۆیە 110ms تەواوتر جێگیر دەبێت — هەردووکیان لە خشتەی
/// داواکراوی 90–120ms دان.
const Duration _kCardPressDur = Duration(milliseconds: 110);

// ── Action buttons ──────────────────────────────────────────────────────────
// ⚠ بەرزایی/گۆشە/بۆشایی دوگمەکان پێشتر لێرە بوون و پیلی فلتەر لێیانەوە
// دەیخوێندەوە. ئێستا هەردووکیان لە `AdSurface`ـەوە دێن (§ باری فلتەر)،
// بۆیە ئەو سێ ژمارەیە لابران — نەک بەجێبمێننەوە و دوو سەرچاوەی ڕاستی
// دروست بکەن.

// ── Campaign-local colours — sampled from the reference screenshot ──────────
// These deliberately DUPLICATE rather than mutate the shared _ds* tokens: the
// _ds* palette is used across the whole screen (sidebar, sheets, filter bar),
// and only the campaign card is being restyled here. Scoping the sampled
// values keeps every other surface byte-identical to before.
const Color _kCampaignBlue     = AdSurface.accent; // #0365FF
const Color _kCampaignInk      = AdSurface.ink;    // #0B0B32
const Color _kCampaignSubtle   = AdSurface.slate;  // #334155 — بوو #68687F
const Color _kCampaignSoftBlue = AppColors.accentSoft;

// ── سنوور و سێبەری کارتی ڕیکلام ────────────────────────────────────────────
// ئێستا ئەلیاسی تۆکنە هاوبەشەکانی `app_theme.dart`ن، نەک کۆپییەکیان — بۆیە
// کارتی ڕیکلام، سکێلیتۆنەکەی و کارتەکانی `ad_details.dart` هەموویان لە یەک
// شوێنەوە دەخوێننەوە و مەحاڵە لێک دوور بکەونەوە.
//
// `_dsCardShadow` ئێستا هەر ئەم تۆکنەیە (بڕوانە سەرەوە)، بۆیە هەموو
// کارتەکانی شاشەکە یەک قووڵاییان هەیە. `_kCampaignBorder` هێشتا جیایە،
// چونکە پیلەکان و هێڵە ناوەکییەکان هێڵێکی سووکتر دەخوازن.
//
//   border:     1px solid #D4D9E1;
//   box-shadow: 0 8px 30px rgba(15, 23, 42, 0.07);
const double _kAdCardBorderW    = AdSurface.hairline;

// (ئێستا تیرەکە لە قەبارەی دەقی ڕێژەکەوە دەردەهێنرێت — _kAdCardTrendIconRatio)
// ── قەبارەی ئایکۆنەکانی کارت — پەیوەستە بە دەقەکەی تەنیشتی ────────────────
// پێشتر هەموو ئایکۆنەکان یەک قەبارەی چەسپاویان هەبوو (18 dp)، کە بەرامبەر
// بە دەقی 11–12 dp زۆر گەورە دەرکەوت. ئێستا هەر ئایکۆنێک لە قەبارەی ئەو
// شتەوە دەردەهێنرێت کە لەگەڵیدا دادەنیشێت — دەق یان بازنە یان خشتە — بۆیە
// لە هەموو ئامێرێکدا هاوسەنگی ئۆپتیکی خۆی دەپارێزێت.
/// ئایکۆنی سپی ناو خشتەی شینی سەرپەڕە = تیرەی خشتە × ئەمە.
const double _kAdCardIconTileRatio = 0.48;

// ── زمان و فۆنتی کارتی ڕیکلام ──────────────────────────────────────────────
// کارتەکە بە تەواوی کوردی (سۆرانی)یە و لە RTL دەخرێتە ڕوو. فۆنتی Rabar
// لە pubspec.yaml تۆمارکراوە (assets/fonts/Rabar_021.ttf).
const String _kAdCardFont = 'Rabar';
/// Card numbers and currency use the same normal Rabar family as labels.
const String _kAdCardNumFont = _kAdCardFont;
/// Retained for existing sheets and skeleton geometry only, never card text.
const double _kAdCardKuBump = kKuFontBump; // §8: تاقە سەرچاوە — app_theme.dart

// ═════════════════════════════════════════════════════════════════════════════
// باری فلتەری سەرەوە — دیزاینی iOS (دۆخ + ماوە)
// ═════════════════════════════════════════════════════════════════════════════
// دوو پیلی هاوقەبارە لە سەرەوەی لیستەکە. زمانەکەی گرامەری iOS-ە: پڕکەرەوەی
// systemGray6، ستادیۆم، لەیبڵێکی ورد، چیڤرۆنێکی بچووک، و کاردانەوەیەکی
// دەستبەجێ (سکەیڵی 0.96 لە 90ms + هەستی سەلێکشن). کاتێک فلتەرێک چالاک بێت
// پیلەکە دەبێتە شینی سووک — هەمان تۆنی کارتەکە، بۆیە یەک سیستەمی ڕەنگ.
// بۆشایی: سەرەوە زیاتر لە خوارەوە، بۆیە بارەکە بە باری سەرەوەوە نانووسێت
// و لە ناوچەی سەلامەتدا (SafeArea + پەدینگی TopBar) دەمێنێتەوە. گەتەری
// تەنیش هەمان `_kCampaignPageGutter`ی کارتەکەیە، بۆیە پیل و کارت دەقاودەق
// لەسەر یەک هێڵن.
// ── ڕیتمی ستوونی: TopBar → پیل → کارت ──────────────────────────────────────
//     TopBar → پیل   `_kFbBarPadTop`                       12 dp
//     پیل   → کارت   `_kFbBarPadBottom` + `_kCampaignListTop` = 8 + 8 = 16 dp
//     کارت  → کارت   `_dsGapCard`                           19 dp
// بۆشاییەکان بەرەو خوارەوە گەورە دەبن، بۆیە پیلەکان بە باری سەرەوە دەلکێن
// و کارتەکان جیا دەبنەوە — گواستنەوەیەکی زنجیرەیی، نەک سێ بۆشایی هاوشێوە
// کە هەموو شتێک وەک یەک بلۆکی تەخت دەردەخات.

// ── یەکخستن لەگەڵ کارتی ڕیکلام ──────────────────────────────────────────────
// ئەم ژمارانە ئیتر سەربەخۆ نین: هەر یەکەیان ڕاستەوخۆ لە تۆکنەکانی خودی
// کارتەکەوە دێت، بۆیە ئەگەر ڕۆژێک کارتەکە بگۆڕدرێت فلتەرەکەش لەگەڵی
// دەگۆڕێت — نەک دوو سیستەمی جیاواز.
//   بەرزایی  = بەرزایی دوگمەکانی کارت (وردەکاری / هاوبەشکردن)
//   گۆشە     = گۆشەی هەمان دوگمەکان، نەک ستادیۆم
//   بۆشایی   = هەمان بۆشایی نێوان ئەو دوو دوگمەیە
//   ئایکۆن→دەق = هەمان جیاوازی ئایکۆن و لەیبڵی دوگمە


/// تاپ لەسەر هەموو کارتەکە وردەکاری دەکاتەوە (وەک لیستەکانی iOS). هەمان
/// `onTap`ی پێشووە کە دوگمەی «وردەکاری» بانگی دەکات — هیچ ڕێڕەوێکی نوێ
/// نییە. بکە بە `false` ئەگەر دەتەوێت تەنها دوگمەکە کاری پێبکات.
const bool _kCardTapOpensDetails = true;
// پیلەکان هەمان ڕووی کارتەکەن (سپی تەواو) لەسەر پەڕەی #FAFAFA، بۆیە
// بەبێ هیچ بلۆکێکی خۆڵەمێشی جیا دەبنەوە — هەمان زمانی کارتەکە.
/// هایلایتی پەستانی ڕیزی شیت. پێشتر systemGray6ی iOS بوو (#F2F2F7) — ڕەنگێکی
/// بێگانە بۆ ئەم سیستەمە. ئێستا هەمان شینی سووکی دوگمەکانی کارت و پیلی چالاک.
const Color  _kFbRowPress     = _kCampaignSoftBlue;
/// قەبارەی دەقی ڕیزی شیت. پێشتر 17.2 بوو — لە `_kCampaignFsTitle` (16.8)
/// **گەورەتر**، واتە هەڵبژاردنێکی فلتەر لە ناوی ڕیکلامەکە گەورەتر
/// دەردەکەوت. ئێستا پلەی دووەمی ڕەمپی کارتەکەیە، بۆیە هەرەمەکە دروستە:
/// سەرپەڕەی شیت (16.8) > ڕیزی شیت (15.0) > پیلی فلتەر (12.9).
const double _kFbFsSheetItem  = _kCampaignFsStatValue;
const Duration _kFbPressDur   = Duration(milliseconds: 90);

/// لەیبڵی کوردی — بەهای ناوەوە (ئینگلیزی) هەرگیز ناگۆڕێت، چونکە هەر ئەوە
/// query‌ی Supabase و `_filterDefs` بەڕێوە دەبات. تەنها نمایشەکە کوردییە.
// ── باری فلتەر ─────────────────────────────────────────────────────────────
// هەشت دۆخەکە بە یەک نیگا دیارن. هەر تابێک ئامانجی دەستلێدانی 40dpـی هەیە،
// بەڵام ڕووکارەکە هێمنە: تەنها دەق و هێڵێکی 2dp بۆ دۆخی هەڵبژێردراو.
const double _kFbChipH      = 40.0;
const double _kFbChipRadius = 10.0;
const double _kFbChipPadH   = 12.0;
const double _kFbChipGap    =  2.0;
const double _kFbChipFs     = 12.5;
const double _kFbIndicatorH =  2.0;
const double _kFbIndicatorInset = 8.0;

/// پەدینگی باری چیپەکان — `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`.
/// ⚠ ئاسۆییەکە **سکەیڵ ناکرێت**: دەبێت لەگەڵ گەتەری کارتەکان ڕێک بێت لەسەر
/// هەموو ئامێرێک، بۆیە ژمارەیەکی جێگیرە نەک `× s`.
const double _kFbBarPadH    = _kCampaignPageGutter;
const double _kFbBarPadV    =  8.0;

/// نەهەڵبژێردراو — دەقی slate بەبێ پڕکەرەوە، w500.
const Color _kFbChipIdleInk    = Color(0xFF475569);

/// هەڵبژێردراو — دەقی شینی سەرەکی و هێڵێکی باریک لە خوارەوە.
const Color _kFbChipOnInk  = Color(0xFF0265FF);
const Color _kFbTrack      = Color(0xFFE2E8F0);
const Color _kFbPressed    = Color(0xFFF1F5F9);

const Map<String, String> _kFbStatusKu = {
  'All Status': 'هەموو دۆخەکان',
  'Active'    : 'چالاک',
  'Pending'   : 'چاوەڕوان',
  'In Review' : 'پێداچوونەوە',
  'Scheduled' : 'خشتەکراو',
  'Rejected'  : 'ڕەتکراوە',
  'Completed' : 'تەواوبوو',
  'Paused'    : 'ڕاگیراوە',
};


// ── Campaign status badge — reference screenshot ────────────────────────────
// A tinted stadium carrying the status label only; the reference draws no dot.
const double _kCampaignBadgeH      = 22.0;
const double _kCampaignBadgeRadius = _kCampaignBadgeH / 2; // stadium
const double _kCampaignBadgePadS   =  8.0;
const double _kCampaignBadgePadE   =  8.0;

// ── Campaign filter chip — report v4 §5.2 ─────────────────────────────────
// The shared _dsChip* tokens describe a STADIUM (radius = height/2). The
// reference chip is not a pill: its corner radius measures 13.5 raw against a
// 63 raw height. Scoped locally so the shared tokens keep serving other chips.

// ── Campaign type ramp — solved from PER-GLYPH cap heights ─────────────────
// Measuring a whole string overstates its size whenever the string carries a
// comma or a descender, so every size below comes from one unambiguous cap or
// lining figure divided by Inter's cap height (1490/2048 = 0.72727 em):
//   "S" of Summer 24 raw · "A" of Ad ID 17 · "J" of June 17 · "D" of Day 16 ·
//   "B" of Budget Progress 17 · "4" of 420.50 17 · "C" of Clicks 16 ·
//   "4" of 45,890 21 · "A" of Active 16 · "V"/"S" of the buttons 19/18 ·
//   "12%" 15
// ڕەمپی تایپ — پێداچوونەوەی خوێندنەوە
// ژمارە کۆنەکان لە ڕیفرنسێکی ئینگلیزی/Inter-ەوە پێورابوون؛ لە کوردی و
// Rabar-دا ئەو قەبارانە بچووک دەخوێندرێنەوە، بەتایبەت لەیبڵە بچووکەکان.
// هەر ئاستێک بەرزکراوەتەوە بەڵام ڕیزبەندی هەرمی خۆی پاراستووە:
// ناونیشان > بەهای مەتریک > دوگمە > بودجە/ڕێککەوت > لەیبڵ > ڕێژە.
// ژمارە کۆنەکان لە کۆتایی هەر دێڕێکدا نووسراون بۆ گەڕانەوە.
const double _kCampaignFsTitle     = 16.8;  // was 15.7 — ناوی ڕیکلام, w700
const double _kCampaignFsId        = 11.4;  // v2: 11–12 — «#کۆدی ڕیکلام», w400
const double _kCampaignFsStatLabel = 11.0;
const double _kCampaignFsStatValue = 15.0;  // was 13.8 — بەهای مەتریک, w700
const double _kCampaignFsBadge     = 10.8;

/// Summed from the parts above so the skeleton can never drift out of sync
/// with the card's own vertical rhythm. The real card does NOT pin this as a
/// height — its content decides, so a wrapped label or a missing day counter
/// grows or shrinks it instead of clipping.
const double _kCampaignCardHeight =
    _kCampaignPadTop +
    _kAdcHeaderH +
    _kAdcRowGap +
    _kAdcStatTileH +
    _kAdcToggleGapTop +
    _kAdcToggleH +
    _kCampaignPadBottom;

// ── Vertical rhythm — the dashboard's list rhythm, on the 8 dp grid ─────────

const double _kFsTitle     = _dsFsTitle    * _kReadableBump;
const double _kFsId        = _dsFsBody     * _kReadableBump;
const double _kFsPill      = _dsFsPill     * _kReadableBump;
const double _kFsLabel     = _dsFsChip;
const double _kFsLabelCard = _dsFsStatLbl  * _kReadableBump;
const double _kFsValue     = _dsFsStatVal  * _kReadableBump;
const double _kFsTrend     = _dsFsDelta    * _kReadableBump;
const double _kFsFoot      = _dsFsAmount   * _kReadableBump;
const double _kFsBtn       = _dsFsBody     * _kReadableBump;

// ── دروستکردنی share username (پێش پێویستی: full_name → username → email) ────
String _resolveShareUsername() {
  final user = supabase.auth.currentUser;
  final meta = user?.userMetadata ?? const <String, dynamic>{};

  final fullName = (meta['full_name'] ?? meta['name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;

  final username = (meta['username'] ?? '').toString().trim();
  if (username.isNotEmpty) return username;

  final email = (user?.email ?? '').toString().trim();
  if (email.isNotEmpty) return email;

  return 'Proxo';
}

// ── دروستکردنی لینکی شێرکردن بە تەواوی لای کلاینت — هیچ API-یەک بانگ ناکرێت ──
String buildShareUrl({required String adId, required String username}) {
  final encodedUsername = Uri.encodeQueryComponent(username);
  return 'https://www.proxopages.com/?share_ad=$adId&by=$encodedUsername';
}

// ── شێرکردنی ڕیکلام لەگەڵ share_plus — بێ API، بێ ڕاژە، دەستبەجێ ────────────
Future<void> _shareAd({
  required Map<String, dynamic> ad,
  required BuildContext context,
}) async {
  final id = (ad['id'] ?? '').toString();
  final username = _resolveShareUsername();
  final shareUrl = buildShareUrl(adId: id, username: username);
  // pa_ads هیچ خانەیەکی `campaign_name`ی نییە (پشکنین کرا لەسەر خودی
  // داتابەیس) — بۆیە fallback-ەکەی لابرا.
  final campaignName = (ad['title'] ?? 'ڕیکلامی Proxo').toString();

  final message =
      '🚀 ئەم ڕیکلامە لە Proxo ببینە\n\n'
      'ڕیکلام:\n$campaignName\n\n'
      'بەستەر:\n$shareUrl';

  unawaited(Share.share(message));
}

// ═════════════════════════════════════════════════════════════════════════════
// _T — text styles resolved once per scale, then memoised
// ═════════════════════════════════════════════════════════════════════════════
// The dashboard reaches Inter through `GoogleFonts.inter`; this screen reaches
// the same face through `kAppFont`, the family bundled in pubspec. Same
// glyphs, same metrics, but resolved locally — so there is no font fetch and
// no first-paint reflow on a slow connection, which is exactly what the
// caching brief asks for.
//
// Every style is built once per distinct scale and reused for the life of the
// process, so a frame on this screen allocates no TextStyle at all.

class _T {
  final TextStyle title, subtitle, amount, micro, statLabel, statValue,
      delta, pill, chip, button, sheetTitle, sheetItem;

  const _T._({
    required this.title, required this.subtitle, required this.amount,
    required this.micro, required this.statLabel, required this.statValue,
    required this.delta, required this.pill, required this.chip,
    required this.button, required this.sheetTitle, required this.sheetItem,
  });

  static double _cachedScale = double.nan;
  static _T? _cached;

  static _T of(double s) {
    final _T? hit = _cached;
    if (hit != null && (_cachedScale - s).abs() < 0.0005) return hit;
    final _T built = _T._(
      // = _kFsRowTitle 14 / w700 / ls −0.2 / h 1.30
      title: TextStyle(fontFamily: kAppFont, fontSize: _kFsTitle * s,
          fontWeight: FontWeight.w700, color: _dsInk,
          letterSpacing: -0.2 * s, height: 1.30),
      // = _kFsBody 10.5 / w400 / h 1.35
      subtitle: TextStyle(fontFamily: kAppFont, fontSize: _kFsId * s,
          fontWeight: FontWeight.w400, color: _dsSubtle, height: 1.35),
      // = _kFsAmount 12.5 / w700 / ls −0.2 / h 1.35
      amount: TextStyle(fontFamily: kAppFont, fontSize: _kFsFoot * s,
          fontWeight: FontWeight.w700, color: _dsInk,
          letterSpacing: -0.2 * s, height: 1.35),
      // = _kFsMicro 9.5 / w400 / h 1.35
      micro: TextStyle(fontFamily: kAppFont, fontSize: _dsFsMicro * s,
          fontWeight: FontWeight.w400, color: _dsSubtle, height: 1.35),
      // = _StatColumn's label 10.5 / w500 / h 1.25
      statLabel: TextStyle(fontFamily: kAppFont, fontSize: _kFsLabelCard * s,
          fontWeight: FontWeight.w600, color: _dsSubtle, height: 1.25),
      // = _StatColumn's value 15 / w700 / ls −0.2 / h 1.2
      statValue: TextStyle(fontFamily: kAppFont, fontSize: _kFsValue * s,
          fontWeight: FontWeight.w700, color: _dsInk,
          letterSpacing: -0.2 * s, height: 1.2),
      // = _StatColumn's delta 11 / w600 / h 1.2
      delta: TextStyle(fontFamily: kAppFont, fontSize: _kFsTrend * s,
          fontWeight: FontWeight.w600, height: 1.2),
      // = _StatusBadge's label 12.30 / w700 / h 1.0
      pill: TextStyle(fontFamily: kAppFont, fontSize: _kFsPill * s,
          fontWeight: FontWeight.w600, height: 1.0),
      // = _RangePill's label 10.5 / w600 / h 1.2
      chip: TextStyle(fontFamily: kAppFont, fontSize: _kFsLabel * s,
          fontWeight: FontWeight.w600, color: _dsInk, height: 1.2),
      // = _PrimaryButton's label 10.5 / w700 / h 1.2
      button: TextStyle(fontFamily: kAppFont, fontSize: _kFsBtn * s,
          fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
      sheetTitle: TextStyle(fontFamily: kAppFont, fontSize: _dsFsTitle * s,
          fontWeight: FontWeight.w700, color: _dsInk,
          letterSpacing: -0.2 * s, height: 1.35),
      sheetItem: TextStyle(fontFamily: kAppFont, fontSize: _dsFsAmount * s,
          fontWeight: FontWeight.w600, color: _dsInk, height: 1.35),
    );
    _cachedScale = s;
    _cached = built;
    return built;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _DsCard — the dashboard's `_CardShell`
// ═════════════════════════════════════════════════════════════════════════════
// White (or tinted), radius 16, padding 18, borderless with the system's two
// shadows. Optional ink response, bounded by `InkWell.borderRadius` rather
// than a clip layer so a long list never pays for one.

class _DsCard extends StatelessWidget {
  final double scale;
  final Widget child;
  final EdgeInsets? padding;
  final Color color;
  final Color? border;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  const _DsCard({
    required this.scale,
    required this.child,
    this.padding,
    this.color = _dsCard,
    this.border,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(_dsCardRadius * scale);
    Widget content = Padding(
      padding: padding ?? EdgeInsets.all(_dsCardPad * scale),
      child: child,
    );
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: _dsBlue.withOpacity(0.06),
          highlightColor: _dsBlue.withOpacity(0.03),
          child: content,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: border ?? _dsBorder, width: _dsRule),
        boxShadow: shadow ?? _dsCardShadow,
      ),
      child: content,
    );
  }
}

/// The dashboard's `_PrimaryButton`, stretched full width: `kProxoBlue`,
/// radius 12, height 30, 10.5/w700 white label.
class _DsPrimaryButton extends StatelessWidget {
  final double scale;
  final String label;
  final Widget? leading;
  final IconData? trailing;
  final VoidCallback? onTap;

  /// Opt-in overrides. All default to null, which reproduces the compact
  /// notice-card button exactly — `_buildNoticeCard` passes none of them and
  /// is unchanged. `_buildEmpty` passes all four to match the Dashboard's
  /// refined CTA (40 dp tall, radius 12, 11.5/w600 label).
  final double? height;
  final double? radius;
  final double? leadingGap;
  final TextStyle? labelStyle;

  const _DsPrimaryButton({
    required this.scale,
    required this.label,
    this.leading,
    this.trailing,
    this.onTap,
    this.height,
    this.radius,
    this.leadingGap,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final BorderRadius r =
        BorderRadius.circular((radius ?? _kBtnRadius) * s);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: _dsBlue,
        borderRadius: r,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          splashColor: Colors.white.withOpacity(0.18),
          highlightColor: Colors.white.withOpacity(0.08),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: (height ?? _kBtnHeight) * s),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: _kBtnChevronPad * s, vertical: 5 * s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    SizedBox(width: (leadingGap ?? 8) * s),
                  ],
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: labelStyle ?? _T.of(s).button),
                  ),
                  if (trailing != null) ...[
                    SizedBox(width: 6 * s),
                    Icon(trailing, size: _kBtnChevron * s, color: Colors.white),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdScreen extends StatefulWidget {
  final String? initialAdId;
  final AdFilter? initialFilter;

  /// Opens the shared sidebar. The drawer itself lives in `MainShell` (its
  /// `_sidebarOpen` / `_sidebarKey` state and the `ProxoSidebar` in its Stack),
  /// exactly as it does for `HomeScreen` — this screen only reports the tap, it
  /// owns no sidebar state and builds no drawer of its own.
  ///
  /// Null when `AdScreen` is pushed as a standalone route (`/my-ads`), where
  /// there is no shell to open; `ProxoTopBar` already tolerates a null handler.
  final VoidCallback? onMenuTap;

  /// ئایا ئەم شاشەیە ئێستا تابی چالاکە؟ `MainShell` شاشەکان لە `IndexedStack`دا
  /// زیندوو ڕادەگرێت، بۆیە گەڕانەوە بۆ تابەکە `initState` بانگ ناکاتەوە. ئەم
  /// بەهایە false→true دەکات، و ئەوە ئەوەیە کە سکێلیتۆنی کردنەوە دەخوڵقێنێت.
  /// بنەڕەت `true`ە، بۆیە کاتێک وەک ڕێڕەوێکی سەربەخۆ (`/my-ads`) دەکرێتەوە
  /// هیچ شتێک ناگۆڕێت.
  final bool isActive;

  /// Handle owned by `MainShell`, fired when the Campaigns tab is tapped while
  /// already active. Null when this screen is pushed standalone (`/my-ads`),
  /// where there is no bar to re-tap.
  final ProxoRefreshController? refreshController;

  const AdScreen({
    super.key,
    this.initialAdId,
    this.initialFilter,
    this.onMenuTap,
    this.isActive = true,
    this.refreshController,
  });
  @override
  State<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends State<AdScreen>
    with TickerProviderStateMixin {
  AdFilter _filter = AdFilter.all;
  List<Map<String, dynamic>> _ads = [];
  final Map<String, List<Map<String, dynamic>>> _memoryCache =
      <String, List<Map<String, dynamic>>>{};
  bool _loading = true;
  bool _isOffline = false;
  bool _hasError = false;
  String _errorMsg = '';
  /// Whether the current failure looked like a connectivity problem — drives
  /// the tone and icon of the error state, nothing else.
  bool _offlineError = false;

  // ── پاگینەیشن ──────────────────────────────────────────────
  bool _loadingMore = false;

  /// سینکی پشتەوەی ئێستا، ئەگەر هەبێت.
  ///
  /// بۆچی Future و نەک `bool`: `RefreshIndicator` سپینەرەکەی هەتا
  /// تەواوبوونی ئەو Future-ە ڕادەگرێت کە `onRefresh` دەیگەڕێنێتەوە.
  /// ئەگەر تەنها ئاڵایەکی `bool`مان هەبووایە، ڕاکێشانێک لە کاتی سینکێکی
  /// پشتەوەدا دەستبەجێ Future-ێکی تەواوبووی دەگەڕاندەوە و سپینەرەکە
  /// یەکسەر دەڕۆیشت. ئێستا هەردوو بانگکەر **هەمان** Future وەردەگرن:
  /// یەک داواکاریی تۆڕ، و سپینەرەکە بە ڕاستی چاوەڕێی دەکات.
  Future<bool>? _silentSync;
  bool _hasMore = true;
  static const int _pageSize = 20;

  /// هاتنە ژوورەوەی کارتەکان دوای گۆڕینی فلتەر.
  ///
  /// **یەک** کۆنترۆڵەر بۆ هەموو لیستەکە، نەک یەکێک بۆ هەر کارتێک. هۆکارەکە
  /// تەنها بیرگە نییە:
  ///
  ///   • `SliverList` کارتەکان بە تەمەڵی دروست دەکات. بە کۆنترۆڵەری
  ///     تایبەت بە هەر کارتێک، هەر کارتێک کە بە سکڕۆڵ دەهاتە ناو
  ///     دیمەن ئەنیمەیشنەکەی **لە نوێوە** دەستی پێدەکرد — واتە
  ///     فەیدینێکی نەویست لە ناوەڕاستی سکڕۆڵدا.
  ///   • بەم شێوەیە، کارتێک کە دواتر دروست دەبێت بەهای ئێستای
  ///     کۆنترۆڵەرەکە دەخوێنێتەوە (1.0 = تەواوبوو) و دەستبەجێ بە
  ///     تەواوی دیار دەردەکەوێت.
  ///
  /// بەهای دەستپێک 1.0-ە: بارکردنی یەکەم لەڕێی کراسفەیدی سکێلیتۆنەوە
  /// دێت و پێویستی بەمە نییە.
  late final AnimationController _entranceCtrl;
  final ScrollController _scrollCtrl = ScrollController();
  String? _highlightId;
  DateTime? _lastSync;
  RealtimeChannel? _metricsChannel;

  // One background generation per missing/legacy thumbnail at a time.
  // Requests are serialized below so TikTok and Storage are never hit by a
  // burst when a page of old ads is loaded. Failed ids are released in the
  // finally block so refreshes and video changes can retry after completion.
  static final Set<String> _legacyThumbnailAttempts = <String>{};

  /// ئیندێکسی دۆخی هەڵبژێردراو لە `_filterDefs`دا — پیلی «دۆخ» ئەمە نیشان
  /// دەدات. ئەنیمەیشنی باری کۆنی پیل لەگەڵ خودی بارەکە لابرا.
  int _pillIndex = 0;

  /// کراسفەیدی چینی سکێلیتۆن. کورت بە ئەنقەست: ئەمە تەنها گۆڕینی ڕوونییە،
  /// نەک ئەنیمەیشنێکی «داخڵبوون» — هیچ جوڵە یان سکەیڵێکی لەگەڵدا نییە.
  static const Duration _kSkeletonFade = Duration(milliseconds: 180);
  static const _filterDefs = [
    (AdFilter.all,       'All Status'),
    (AdFilter.active,    'Active'),
    (AdFilter.pending,   'Pending'),
    (AdFilter.review,    'In Review'),
    (AdFilter.scheduled, 'Scheduled'),
    (AdFilter.rejected,  'Rejected'),
    (AdFilter.completed, 'Completed'),
    (AdFilter.paused,    'Paused'),
  ];

  // ── ماوە (Date range) — پیلی «ماوە» لە باری سەرەوە ئەمە دەگۆڕێت، و
  // کاریگەری ڕاستەوخۆی هەیە لەسەر query‌ی Supabase (created_at >= cutoff).
  // بڕوانە _dateRangeCutoff() و _loadAds/_loadMore.
  // ── فلتەری ماوە — بەبێ ڕووکار، بە ئەنقەست ─────────────────────────────
  // باری فلتەر تەنها دۆخ پیشان دەدات (هەشت چیپ). فلتەری ماوە بە تەواوی لە
  // ڕووکارەکە لابرا — نە شیت، نە چیپ، نە مینیو.
  //
  // بەڵام لۆجیکەکەی **نەسڕدراوەتەوە**، چونکە سێ شت هێشتا پێویستیان پێیەتی:
  //   • `_dateRangeCutoff()` — `created_at >= cutoff`ی query‌ی Supabase
  //   • کلیلی کاش (`_cacheKey…`) — ماوەکەی تێدایە
  //   • سەلماندنی کاش — `decoded['range']` بەراورد دەکات
  //
  // بە `final` و 'All time' واتە `_dateRangeCutoff()` هەمیشە `null`
  // دەگەڕێنێتەوە: هیچ بڕینێکی کات نییە، هەموو ڕیکلامەکان دەهێنرێن. ئەمە
  // دەقاودەق هەمان ڕەفتاری بنەڕەتی پێشووە.
  //
  // ⚠ `final`ـە بە ئەنقەست: بۆ ئەوەی هیچ کۆدێک بەبێ ڕووکارێک بۆی نەتوانێت
  // بیگۆڕێت و بەکارهێنەر بە لیستێکی بڕدراوەوە بمێنێتەوە کە هیچ ڕێگایەکی
  // نییە بۆ ڕاستکردنەوەی.
  final String _dateRangeLabel = _kFbDateDefault;
  /// ڕیزبەندی: نوێترین سەرەوە. فلتەری ڕیزبەندی لە ڕووکاردا نەماوە، بەڵام
  /// query‌ەکە هێشتا پێویستی پێیەتی.
  final bool _sortAscending = false;

  static const String _kFbDateDefault = 'All time';

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this, duration: _kAdcEnterTotal, value: 1.0);

    if (widget.initialFilter != null) {
      _filter = widget.initialFilter!;
      final idx = _filterDefs.indexWhere((d) => d.$1 == widget.initialFilter);
      if (idx >= 0) _pillIndex = idx;
    }
    if (widget.initialAdId != null) _highlightId = widget.initialAdId;
    _loadAds();
    _startMetricsRealtime();

    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant AdScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // گەڕانەوە بۆ تابی ڕیکلامەکان: ناوەڕۆکی هەڵگیراو دەستبەجێ دەمێنێتەوە
    // و تەنها سینکێکی بێدەنگ لە پشتەوە دەکرێت. هیچ سکێلیتۆن یان
    // دواخستنێکی دەستکرد لە ناو گواستنەوەی BottomNavدا نییە.
    if (widget.isActive && !oldWidget.isActive) {
      unawaited(_syncAdsSilently());
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _metricsChannel?.unsubscribe();
    super.dispose();
  }

  // ── Infinite scroll trigger ───────────────────────────────
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        !_loadingMore && _hasMore && !_loading) {
      _loadMore();
    }
  }

  // ── REALTIME: نوێکردنەوەی خۆکاری ئامار ──────────────────────
  void _startMetricsRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _metricsChannel?.unsubscribe();
    _metricsChannel = supabase.channel('ads_metrics_rt_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'pa_ads',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          final changed = payload.newRecord;
          final old = payload.oldRecord;
          if (changed.isEmpty) return;
          final metricsChanged =
              old['spend']         != changed['spend'] ||
              old['clicks']        != changed['clicks'] ||
              old['impressions']   != changed['impressions'] ||
              old['tiktok_ad_id']  != changed['tiktok_ad_id'] ||
              old['status']        != changed['status'] ||
              old['feedback_rating'] != changed['feedback_rating'] ||
              old['feedback_at']   != changed['feedback_at'] ||
              old['thumbnail_url'] != changed['thumbnail_url'];
          if (!metricsChanged) return;
          if (!mounted) return;
          final String changedId = (changed['id'] ?? '').toString();
          final bool exists = _ads.any(
            (ad) => (ad['id'] ?? '').toString() == changedId,
          );
          if (!exists) {
            // ڕیکلامێک لە دۆخێکی ترەوە هاتە ناو فلتەری چالاک؛ چونکە لە
            // پەڕەی ئێستا نەبوو، سینکی بێدەنگ شوێنی دروستی دەدۆزێتەوە.
            if (_matchesFilter(changed, _filter)) {
              unawaited(_syncAdsSilently());
            }
            return;
          }
          _applyLocalAdPatch(changedId, changed);
          _queueLegacyThumbnailMigrations(<Map<String, dynamic>>[changed]);
        },
      )
      ..subscribe();
  }

  // ── کاش — ڕیکلامەکان لە بیرگەی ئامێرەکەدا هەڵدەگیرێن ─────────────────────
  // بۆ چی: کاتێک بەشەکە دەکرێتەوە، لیستەکە دەستبەجێ لە ئامێرەکەوە دێت و
  // داواکاری Supabase لە پشتەوە دەڕوات. بۆیە هیچ کاتێکی چاوەڕوانی نییە،
  // و بەبێ ئینتەرنێتیش کارتەکان دەبینرێن.
  //
  // ژمارەی وەشان 3 — لە v1دا تەنها لیستێکی خاو هەڵدەگیرا، بێ کات و بێ
  // ماوە؛ لە v3دا هەر ماوە و هەر دۆخێک کاشی سەربەخۆی خۆی هەیە:
  //   • `range` — کاش بەپێی فلتەری ماوە جیا دەکرێتەوە. بەبێ ئەمە کاشی
  //     «٣٠ ڕۆژ» بۆ «ئەمڕۆ» نیشان دەدرا کە هەڵەیە.
  //   • `at`    — تەمەنی کاش. لە `_kCacheTtl` زیاتر بێت پشتگوێ دەخرێت،
  //     بۆیە داتای زۆر کۆن هەرگیز دەرناکەوێت.
  // کاشی v1 هێشتا دەخوێندرێتەوە (بێ ڕیستارت، بێ لۆدینگی بەتاڵ).
  static const _cacheKey = 'proxo_ads_cache_';
  static const int _kCacheVersion = 3;
  static const Duration _kCacheTtl = Duration(hours: 24);

  String _cacheKeyFor(String userId, AdFilter filter) =>
      '$_cacheKey${userId}_${_dateRangeLabel.replaceAll(' ', '_')}_${filter.name}';

  String _memoryCacheKey(AdFilter filter) =>
      '${_dateRangeLabel.replaceAll(' ', '_')}|${filter.name}';

  Future<void> _saveCache(
    List<Map<String, dynamic>> ads, {
    AdFilter? filter,
  }) async {
    try {
      final AdFilter target = filter ?? _filter;
      _memoryCache[_memoryCacheKey(target)] =
          List<Map<String, dynamic>>.from(ads);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyFor(userId, target), jsonEncode({
        'v': _kCacheVersion,
        'range': _dateRangeLabel,
        'filter': target.name,
        'at': DateTime.now().toIso8601String(),
        'ads': ads,
      }));
    } catch (_) {}
  }

  Future<bool> _loadCached({AdFilter? filter}) async {
    try {
      final AdFilter target = filter ?? _filter;
      final List<Map<String, dynamic>>? memory =
          _memoryCache[_memoryCacheKey(target)];
      if (memory != null) {
        if (mounted && target == _filter) {
          setState(() {
            _ads = List<Map<String, dynamic>>.from(memory);
            _hasMore = memory.length >= _pageSize;
          });
        }
        return true;
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final prefs = await SharedPreferences.getInstance();
      // کاشی v1/v2 تەنها بۆ «هەموو دۆخەکان» گونجاوە. بەکارهێنانی ئەو
      // کاشە بۆ فلتەرێکی تایبەت pagination ـەکە هەڵە دەکات.
      final raw = prefs.getString(_cacheKeyFor(userId, target)) ??
          (target == AdFilter.all
              ? prefs.getString(
                    '$_cacheKey${userId}_${_dateRangeLabel.replaceAll(' ', '_')}',
                  ) ??
                  prefs.getString('$_cacheKey$userId')
              : null);
      if (raw == null || raw.isEmpty) return false;

      final decoded = jsonDecode(raw);
      List<Map<String, dynamic>> list;
      if (decoded is List) {
        // v1: لیستێکی خاو، بێ کات — قبووڵ دەکرێت یەک جار.
        list = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['range'] != _dateRangeLabel) return false;
        final String? cachedFilter = decoded['filter']?.toString();
        if (cachedFilter != null && cachedFilter != target.name) return false;
        final DateTime? at = DateTime.tryParse((decoded['at'] ?? '').toString());
        if (at == null || DateTime.now().difference(at) > _kCacheTtl) {
          return false;
        }
        list = (decoded['ads'] as List).cast<Map<String, dynamic>>();
      } else {
        return false;
      }

      _memoryCache[_memoryCacheKey(target)] =
          List<Map<String, dynamic>>.from(list);
      if (mounted && target == _filter) {
        setState(() {
          _ads = list;
          _hasMore = list.length >= _pageSize;
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── مۆری کاتی سنووردارکەر بۆ فلتەری ماوە (Date range) — ئەگەر 'All
  // time' بێت null دەگەڕێنێتەوە (هیچ سنوورێک نییە). ماوەکانی تر بەپێی
  // کاتی ناوخۆیی ئامێرەکە دەژمێردرێن، پاشان بۆ UTC دەگۆڕدرێن پێش
  // ناردن بۆ Supabase (created_at ستوونێکی timestamptz ە). ──────────
  DateTime? _dateRangeCutoff() {
    final now = DateTime.now();
    switch (_dateRangeLabel) {
      case 'Today':        return DateTime(now.year, now.month, now.day);
      case 'Last 7 days':  return now.subtract(const Duration(days: 7));
      case 'Last 30 days': return now.subtract(const Duration(days: 30));
      case 'All time':
      default:              return null;
    }
  }

  Future<void> _loadAds({bool refresh = false}) async {
    final AdFilter requestedFilter = _filter;
    if (refresh) {
      setState(() => _hasMore = true);
      // گۆڕینی فلتەری ماوە بە `refresh: true` دێت. ئەگەر کاشێکی نوێی ئەو
      // ماوەیە هەبێت، دەستبەجێ نیشان دەدرێت و داواکاریەکە لە پشتەوە
      // دەڕوات — بۆیە گۆڕینی فلتەر شاشەیەکی بەتاڵ نانوێنێت.
      await _loadCached(filter: requestedFilter);
    } else {
      setState(() => _loading = true);
      final bool cached = await _loadCached(filter: requestedFilter);
      // کاش ئامادەیە → دەستبەجێ نمایش بدە. داواکاریی تۆڕ لە خوارەوە
      // بەردەوامە، بەڵام هیچ دواخستنی دەستکرد یان سکێلیتۆنی زۆرەملێ نییە.
      if (mounted && requestedFilter == _filter && cached) {
        setState(() => _loading = false);
      }
    }
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { _hasError = true; _offlineError = false; _errorMsg = 'تکایە دووبارە بچۆ ژوورەوە'; });
        return;
      }
      final cutoff = _dateRangeCutoff();
      var query = supabase
          .from('pa_ads')
          .select(_adColumns)
          .eq('user_id', user.id);
      if (requestedFilter == AdFilter.completed) {
        query = query.inFilter('status', const <String>['completed', 'done']);
      } else if (requestedFilter != AdFilter.all) {
        query = query.eq('status', requestedFilter.name);
      }
      if (cutoff != null) {
        query = query.gte('created_at', cutoff.toUtc().toIso8601String());
      }
      final res = await query
          .order('created_at', ascending: _sortAscending)
          .limit(_pageSize);

      final fresh = List<Map<String, dynamic>>.from(res ?? []);
      await _saveCache(fresh, filter: requestedFilter);
      if (mounted && requestedFilter == _filter) {
        DateTime? latestUpdate;
        for (final ad in fresh) {
          final raw = ad['updated_at']?.toString() ?? ad['created_at']?.toString();
          if (raw == null) continue;
          try {
            final dt = DateTime.parse(raw).toLocal();
            if (latestUpdate == null || dt.isAfter(latestUpdate)) latestUpdate = dt;
          } catch (_) {}
        }
        setState(() {
          _ads = fresh;
          _lastSync = latestUpdate ?? DateTime.now();
          _isOffline = false;
          _hasError = false;
          _offlineError = false;
          _errorMsg = '';
          _hasMore = fresh.length >= _pageSize;
        });
        _queueLegacyThumbnailMigrations(fresh);
        if (_highlightId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAd(_highlightId!));
        }
      }
    } catch (e) {
      if (mounted) {
        final cached = await _loadCached(filter: requestedFilter);
        if (requestedFilter != _filter) return;
        if (!cached && _ads.isEmpty) {
          // The offline / general split stays here, in the screen that knows
          // what it was doing. What changed is that the exception itself is
          // logged rather than printed at the user — it told them nothing and
          // looked broken.
          debugPrint('AdScreen: _loadAds failed: $e');
          final bool offline = e.toString().contains('SocketException') ||
              e.toString().contains('network');
          setState(() {
            _hasError = true;
            _offlineError = offline;
            _errorMsg = offline
                ? 'ئینتەرنێتەکەت بپشکنەوە و دووبارە هەوڵ بدەرەوە'
                : 'نەتوانرا ڕیکلامەکانت بار بکرێن — دووبارە هەوڵ بدەرەوە';
          });
        } else {
          setState(() => _isOffline = _ads.isNotEmpty);
        }
        if (refresh) {
          showProxoToast(
            context,
            e.toString().contains('SocketException')
                ? 'ئینتەرنێت نییە — نوێکردنەوە سەرنەکەوت'
                : 'نوێکردنەوە سەرنەکەوت — دووبارە هەوڵ بدەرەوە',
            type: e.toString().contains('SocketException')
                ? ProxoToastType.noInternet
                : ProxoToastType.error);
        }
      }
    } finally {
      if (mounted && requestedFilter == _filter) {
        setState(() => _loading = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // سینکی بێدەنگ — نوێکردنەوە بەبێ سکێلیتۆن، بەبێ لەدەستدانی شوێنی سکڕۆڵ
  // ═══════════════════════════════════════════════════════════════════════
  // جیاوازییەکەی لەگەڵ `_loadAds(refresh: true)`:
  //
  //   • هیچ `_loading`ێک دانانرێت → نە سکێلیتۆن، نە سپینەر
  //   • هەمان ژمارەی ئەو ڕیزانە دەهێنێتەوە کە ئێستا لە حەوزەدان، بۆیە
  //     پەڕەکانی «زیاتر بار بکە» ون نابن و سکڕۆڵ نابازێت
  //   • ئەگەر داتاکە **دەقاودەق** هەمان داتای ئێستا بێت، هیچ `setState`ێک
  //     ناکرێت — واتە سفر بنیاتنانەوە بۆ لیستێک کە نەگۆڕاوە
  //   • هەڵە بێدەنگە: ئەگەر تۆڕ نەبوو، ئەوەی لەسەر شاشەیە دەمێنێتەوە
  //
  // [applyAfter] ئەگەر دابنرێت، `setState`ەکە چاوەڕێی ئەو Future-ە دەکات.
  // بەکاردێت بۆ ئەوەی نوێکردنەوە **دوای** تەواوبوونی ئەنیمەیشنی
  // گەڕانەوە بێت، نەک لە ناوەڕاستیدا — داواکاریی تۆڕەکە هەر لە یەکەم
  // ساتەوە دەڕوات، بۆیە چاوەڕوانییەکە هیچ نانرخێنێت.
  Future<bool> _syncAdsSilently({
    Future<void>? applyAfter,
    bool announceErrors = false,
  }) {
    final Future<bool>? inFlight = _silentSync;
    if (inFlight != null) return inFlight;

    final Future<bool> run = _runSilentSync(
      applyAfter: applyAfter,
      announceErrors: announceErrors,
    );
    _silentSync = run;
    // `identical`: ئەگەر سینکێکی نوێ دەستی پێکردبێت پێش ئەوەی ئەمە
    // تەواو بێت، نابێت ئەوەی نوێ بسڕدرێتەوە.
    run.whenComplete(() {
      if (identical(_silentSync, run)) _silentSync = null;
    });
    return run;
  }

  Future<bool> _runSilentSync({
    Future<void>? applyAfter,
    required bool announceErrors,
  }) async {
    final AdFilter requestedFilter = _filter;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      // هەمان ژمارەی ڕیزەکانی ئێستا (لانیکەم یەک پەڕە) — بۆیە ئەگەر
      // بەکارهێنەر سێ پەڕەی بار کردبێت، سێ پەڕە دەگەڕێتەوە.
      final int wanted = max(_pageSize, _ads.length);
      final cutoff = _dateRangeCutoff();
      var query = supabase
          .from('pa_ads')
          .select(_adColumns)
          .eq('user_id', user.id);
      if (requestedFilter == AdFilter.completed) {
        query = query.inFilter('status', const <String>['completed', 'done']);
      } else if (requestedFilter != AdFilter.all) {
        query = query.eq('status', requestedFilter.name);
      }
      if (cutoff != null) {
        query = query.gte('created_at', cutoff.toUtc().toIso8601String());
      }
      final res = await query
          .order('created_at', ascending: _sortAscending)
          .limit(wanted);

      final fresh = List<Map<String, dynamic>>.from(res ?? []);
      if (applyAfter != null) await applyAfter;
      if (!mounted) return false;

      unawaited(_saveCache(fresh, filter: requestedFilter));
      // بەکارهێنەر لە ماوەی داواکارییەکەدا فلتەری گۆڕیوە؛ وەڵامی کۆن
      // تەنها لە کاشی فلتەری خۆیدا هەڵدەگیرێت و UI ـی نوێ نانووسێتەوە.
      if (requestedFilter != _filter) return false;

      // هیچ نەگۆڕاوە → هیچ کارێک. ئەمە باوترین حاڵەتە (بەکارهێنەر تەنها
      // سەیری وردەکارییەکی کرد و گەڕایەوە)، بۆیە گەڕانەوە دەبێتە سفر کار.
      if (_adsSignature(fresh) == _adsSignature(_ads)) return false;

      setState(() {
        _ads = fresh;
        _lastSync = DateTime.now();
        _isOffline = false;
        _hasError = false;
        _offlineError = false;
        _errorMsg = '';
        _hasMore = fresh.length >= wanted;
      });
      return true;
    } catch (e) {
      // شکست **هەرگیز** ناوەڕۆکی شاشەکە ناگۆڕێت: نە `_hasError`، نە
      // شاشەی بەتاڵ، نە هەڵوەشاندنەوەی لیستەکە. ئەوەی لەبەرچاوە
      // دەمێنێتەوە، چونکە داتای کۆن لە هیچ باشترە.
      debugPrint('AdScreen: silent sync skipped: $e');
      // تەنها کاتێک بەکارهێنەر خۆی داوای نوێکردنەوەی کردووە (ڕاکێشان)
      // پێی دەڵێین سەرنەکەوت — ئەگەرنا تۆستێک بۆ کارێکی پشتەوە دەردەکەوێت
      // کە داوای نەکردووە.
      if (announceErrors && mounted) {
        final bool offline = e.toString().contains('SocketException') ||
            e.toString().contains('network');
        showProxoToast(
          context,
          offline
              ? 'ئینتەرنێت نییە — نوێکردنەوە سەرنەکەوت'
              : 'نوێکردنەوە سەرنەکەوت — دووبارە هەوڵ بدەرەوە',
          type: offline ? ProxoToastType.noInternet : ProxoToastType.error,
        );
      }
      return false;
    }
  }

  // ── ڕاکێشان بۆ نوێکردنەوە ──────────────────────────────────────────────
  // سپینەری خودی `RefreshIndicator` **تاقە** نیشانەی بارکردنە:
  //
  //   • کارتەکان لە شوێنی خۆیان دەمێننەوە و بەهاکانیان لە جێی خۆیاندا
  //     نوێ دەبنەوە کاتێک داواکارییەکە دەگەڕێتەوە
  //   • نە سکێلیتۆن، نە شاشەی بەتاڵ
  //   • شوێنی سکڕۆڵ دەمێنێتەوە چونکە لیستەکە هەرگیز هەڵناوەشێنرێتەوە
  //   • ئەگەر داتاکە نەگۆڕابێت، هیچ `setState`ێک ناکرێت — سپینەرەکە
  //     دەڕوات و هیچ فرەیمێک دووبارە بنیات نانرێتەوە
  //
  // ⚠ `_loadAds(refresh: true)` نا: ئەوە دۆخی بارکردن و هەڵەی تەواوی
  // شاشە بەڕێوە دەبات؛ هەمووی بۆ ڕاکێشانێکی سادە زۆر قورسە.
  /// Shared by the pull gesture and the tab re-tap — same fetch either way.
  /// The card entrance is deliberately NOT played here: `ProxoRefresh.onArrive`
  /// fires it once the strip is fully open, so the cards animate in under the
  /// closing spinner rather than the instant a warm response lands, which can
  /// be ~80ms in while the strip is still on its way down.
  Future<void> _handlePullRefresh() =>
      _syncAdsSilently(announceErrors: true);

  /// شوێنەوارێکی هەرزان بۆ بەراوردکردنی دوو لیست بەبێ بەراوردی قووڵ.
  /// تەنها ئەو خانانەی کارتەکە نمایشیان دەکات + `updated_at`.
  String _adsSignature(List<Map<String, dynamic>> ads) {
    final StringBuffer b = StringBuffer();
    for (final Map<String, dynamic> ad in ads) {
      b
        ..write(ad['id'])
        ..write('|')
        ..write(ad['updated_at'])
        ..write('|')
        ..write(ad['status'])
        ..write('|')
        ..write(ad['title'])
        ..write('|')
        ..write(ad['spend'])
        ..write('|')
        ..write(ad['clicks'])
        ..write('|')
        ..write(ad['impressions'])
        ..write('|')
        ..write(ad['conversions'])
        ..write('|')
        ..write(ad['feedback_rating'])
        ..write('|')
        ..write(ad['feedback_at'])
        ..write('|')
        ..write(ad['thumbnail_url'])
        ..write('|')
        ..write(ad['needs_update'])
        ..write('|')
        ..write(ad['update_submitted_at'])
        ..write(';');
    }
    return b.toString();
  }

  /// نوێکردنەوەی خێرای یەک ڕیز لە حەوزەی ناوخۆیی — بەبێ هیچ داواکارییەکی
  /// تۆڕ. بەکاردێت کاتێک ئێمە خۆمان ئەو گۆڕانکارییەمان لە داتابەیس کردووە
  /// و ئەنجامەکەی دەزانین (بۆ نموونە: ڕەتکردنەوەی ڕیکلام)، بۆیە کارتەکە
  /// دەستبەجێ نوێ دەبێتەوە و سینکی ڕاستەقینە لە پشتەوە دوایی دێت.
  void _applyLocalAdPatch(Object? adId, Map<String, dynamic> patch) {
    if (adId == null) return;
    final String key = adId.toString();
    final int i = _ads.indexWhere((a) => (a['id'] ?? '').toString() == key);
    if (i < 0) return;
    final Map<String, dynamic> next = <String, dynamic>{..._ads[i], ...patch};
    setState(() {
      final List<Map<String, dynamic>> updated =
          List<Map<String, dynamic>>.from(_ads);
      // ئەگەر دۆخەکە لە فلتەری چالاک دەرچوو، ڕیزەکە دەستبەجێ لادەبرێت؛
      // بەمە offset ـی pagination هەمیشە ژمارەی ڕاستەقینەی ڕیزەکانی
      // هەمان فلتەرە.
      if (_matchesFilter(next, _filter)) {
        updated[i] = next;
      } else {
        updated.removeAt(i);
      }
      _ads = updated;
    });
    unawaited(_saveCache(_ads, filter: _filter));
  }

  void _queueLegacyThumbnailMigrations(List<Map<String, dynamic>> rows) {
    final List<String> ids = <String>[];
    for (final row in rows) {
      final String id = (row['id'] ?? '').toString().trim();
      final String thumbnail =
          (row['thumbnail_url'] ?? '').toString().trim();
      final bool isNetworkUrl = _adcThumbnailUri(thumbnail) != null;
      // An empty value is the main repair case: no object has been generated
      // yet. Previously it was skipped here, so the Edge Function was never
      // invoked and the card stayed blank forever. Only a usable network URL
      // means there is nothing to repair.
      if (id.isEmpty || isNetworkUrl) continue;
      if (_legacyThumbnailAttempts.add(id)) ids.add(id);
    }
    if (ids.isNotEmpty) unawaited(_migrateLegacyThumbnails(ids));
  }

  Future<void> _migrateLegacyThumbnails(List<String> adIds) async {
    for (final id in adIds) {
      final sourceRows = _ads.where((ad) => (ad['id'] ?? '').toString() == id);
      final String? requestedVideo = sourceRows.isEmpty
          ? null : sourceRows.first['video_link']?.toString();
      try {
        final response = await supabase.functions.invoke(
          'generate-ad-thumbnail',
          body: <String, dynamic>{'ad_id': id},
        );
        final data = response.data;
        final String url = data is Map
            ? (data['thumbnail_url'] ?? '').toString().trim()
            : '';
        final currentRows = _ads.where((ad) => (ad['id'] ?? '').toString() == id);
        final bool sameVideo = currentRows.isNotEmpty &&
            currentRows.first['video_link']?.toString() == requestedVideo;
        if (mounted && sameVideo && _adcThumbnailUri(url) != null) {
          _applyLocalAdPatch(id, <String, dynamic>{'thumbnail_url': url});
        }
      } catch (error) {
        // Missing/legacy thumbnail repair is best-effort and never blocks the
        // rest of the ads list. Let a later refresh retry failures; valid URLs skip this queue naturally.
        // Release the in-flight guard after every outcome so link changes and
        // non-throwing failures can be retried.
        debugPrint('AdScreen: thumbnail generation failed: $error');
      } finally {
        _legacyThumbnailAttempts.remove(id);
        if (mounted) {
          final latest = _ads.where((ad) => (ad['id'] ?? '').toString() == id);
          if (latest.isNotEmpty && latest.first['video_link']?.toString() != requestedVideo) {
            _queueLegacyThumbnailMigrations(<Map<String, dynamic>>[latest.first]);
          }
        }
      }
    }
  }

  static const String _adColumns =
    'id,title,status,spend,clicks,impressions,'
    'conversions,cpm,prev_spend,prev_impressions,tiktok_ad_id,'
    'start_date,start_time,end_date,daily_budget,total_budget,'
    'budget,days,video_link,reject_reason,'
    'needs_update,update_field,update_reason,'
    'update_requested_at,update_submitted_at,'
    'ad_number,promo_code,video_code,goal,gender,'
    'location,age_groups,created_at,updated_at,'
    'device_type,customer_note,payment_method,payment_status,payment_transaction_id,'
    'level_discount_iqd,level_discount_percent,level_name_at_purchase,asset_id,'
    'thumbnail_url,feedback_rating,feedback_comment,feedback_at,completed_at';

  // ── Load More (Pagination) ────────────────────────────────
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final AdFilter requestedFilter = _filter;
    final int start = _ads.length;
    setState(() => _loadingMore = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final cutoff = _dateRangeCutoff();
      var query = supabase
          .from('pa_ads')
          .select(_adColumns)
          .eq('user_id', user.id);
      if (requestedFilter == AdFilter.completed) {
        query = query.inFilter('status', const <String>['completed', 'done']);
      } else if (requestedFilter != AdFilter.all) {
        query = query.eq('status', requestedFilter.name);
      }
      if (cutoff != null) {
        query = query.gte('created_at', cutoff.toUtc().toIso8601String());
      }
      final res = await query
          .order('created_at', ascending: _sortAscending)
          .range(start, start + _pageSize - 1);
      if (mounted && requestedFilter == _filter) {
        final more = List<Map<String, dynamic>>.from(res ?? []);
        setState(() {
          _ads.addAll(more);
          _hasMore = more.length >= _pageSize;
        });
        unawaited(_saveCache(_ads, filter: requestedFilter));
        _queueLegacyThumbnailMigrations(more);
      }
    } catch (_) {
    } finally {
      if (mounted && requestedFilter == _filter) {
        setState(() => _loadingMore = false);
      }
    }
  }

  // ── Duplicate (fixed: کلیک لەسەری ئێستا دەتباتە بەشی دروستکردنی ڕیکلام) ──
  // پێشتر ئەم فەنکشنە بەبێ ڕوونکردنەوە کڕینێکی نوێی لە شاردا دەکرد و ڕاستەوخۆ
  // لە داتابەیس داینەدەکرد — ئەمە هەڵەیەک بوو، چونکە بەکارهێنەر هیچ فۆرمێکی
  // دروستکردنی ڕیکلامی نەدەبینی و ناتوانی هیچ شتێک بگۆڕێت پێش پارەدان.
  // ئێستا تەنها داتای ڕیکلامەکە ئامادە دەکات و دەیبات بۆ AdCreateScreen وەک
  // خاڵی دەستپێک، بۆ ئەوەی بەکارهێنەر پێش کڕین بتوانێت هەموو شتێک ببینێت و
  // بیگۆڕێت.
  Future<void> _duplicateAd(Map<String, dynamic> ad, {
    required void Function() onLoading,
    required void Function() onDone,
  }) async {
    onLoading();
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('تکایە دووبارە بچۆ ژوورەوە');

      // ── پشکنینی کەرەستەی پەیوەندی (goal=messages) — لەوانەیە سڕابێتەوە ──
      String? assetId = ad['asset_id']?.toString();
      if (ad['goal'] == 'messages' && assetId != null && assetId.isNotEmpty) {
        final assetRow = await supabase
            .from('proxolink_cards')
            .select('id')
            .eq('id', assetId)
            .maybeSingle();
        if (assetRow == null) {
          assetId = null;
          if (mounted) {
            showProxoToast(context,
              '⚠️ کەرەستەی پەیوەندییەکەی ڕیکلامی سەرەکی سڕاوەتەوە — تکایە کەرەستەیەکی نوێ هەڵبژێرە',
              type: ProxoToastType.error);
          }
        }
      }

      // ── داتای ڕیکلامەکە ئامادەکردن وەک خاڵی دەستپێکی فۆرمی دروستکردن ──
      // (هیچ نووسینێک بۆ داتابەیس ناکرێت لێرە — کڕین و پاشەکەوتکردن هەر
      // لەناو خودی فۆرمی دروستکردندا (AdCreateScreen) ئەنجام دەدرێت).
      final duplicateData = <String, dynamic>{...ad, 'asset_id': assetId}
        ..remove('id')
        ..remove('tiktok_ad_id')
        ..remove('spend')
        ..remove('clicks')
        ..remove('impressions')
        ..remove('conversions')
        ..remove('cpm')
        ..remove('prev_spend')
        ..remove('prev_impressions')
        ..remove('reject_reason')
        ..remove('created_at')
        ..remove('updated_at')
        ..remove('ad_number')
        ..remove('promo_code')      // پرۆمۆکۆدی جارێک بەکارهاتوو دووبارە نایەتەکارهێنان
        ..remove('level_discount_percent')
        ..remove('level_discount_iqd')
        ..remove('level_name_at_purchase')
        ..remove('start_date')
        ..remove('end_date')
        ..remove('status');

      if (!mounted) return;
      await Navigator.of(context).push(ProxoPageRoute<String>(
        builder: (_) => AdCreateScreen(proxoCard: duplicateData),
      ));

      // پاش گەڕانەوە لە فۆرمی دروستکردن، لیستەکە نوێ بکەرەوە بۆ ئەوەی
      // ڕیکلامی نوێی دروستکراو دەربکەوێت.
      //
      // ⚠ `_loadAds()` نا: ئەوە `_loading = true` دادەنێت، واتە سکێلیتۆنی
      // تەواوی شاشە لەسەر لیستێک کە پێشتر داتای هەیە — و لەو ساتەدا
      // شاشەی وردەکاری هێشتا لە سەرەوەیە. سینکی بێدەنگ هەمان داتا
      // دەهێنێت بەبێ هیچ گۆڕانێکی بینراو.
      if (mounted) unawaited(_syncAdsSilently());
    } catch (e) {
      debugPrint('AdScreen: duplicate ad failed: $e');
      if (mounted) {
        showProxoToast(context,
          'نەتوانرا ڕیکلامەکە دووبارە بکرێتەوە — دووبارە هەوڵ بدەرەوە',
          type: ProxoToastType.error);
      }
    } finally {
      onDone();
    }
  }

  bool _matchesFilter(Map<String, dynamic> ad, AdFilter filter) {
    if (filter == AdFilter.all) return true;
    final String status = (ad['status'] ?? '').toString().trim().toLowerCase();
    if (filter == AdFilter.completed) {
      return status == 'completed' || status == 'done';
    }
    return status == filter.name;
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == AdFilter.all
          ? _ads
          : _ads.where((ad) => _matchesFilter(ad, _filter)).toList();

  void _scrollToAd(String adId) {
    if (_filter != AdFilter.all) {
      _setFilter(0, AdFilter.all);
      return;
    }
    final idx = _ads.indexWhere((a) => a['id']?.toString() == adId);
    if (idx < 0 || !_scrollCtrl.hasClients) return;
    const double cardHeight = 280.0;
    final offset = (idx * cardHeight).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(offset,
      duration: const Duration(milliseconds: 480), curve: Curves.easeInOut);
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  void _setFilter(int index, AdFilter filter) {
    // هەڵبژاردنی هەمان فلتەر = هیچ؛ هیچ rebuild یان ئەنیمەیشنێکی زیادە نییە.
    if (filter == _filter && index == _pillIndex) return;
    // پێش کەمکردنەوەی لیستەکە ئۆفسێت دەگەڕێتەوە بۆ سەرەوە؛ بەمە
    // BouncingScrollPhysics هیچ settle/bounce ـێکی دوای فلتەر دروست ناکات.
    if (_scrollCtrl.hasClients && _scrollCtrl.offset > 0) {
      _scrollCtrl.jumpTo(0);
    }
    setState(() {
      _filter = filter;
      _pillIndex = index;
      _ads = <Map<String, dynamic>>[];
      _loadingMore = false;
      _hasMore = true;
      _hasError = false;
      _offlineError = false;
      _errorMsg = '';
    });
    // یەکەم جار بۆ ئەم دۆخە لە Supabase دێت؛ جارەکانی دواتر کاشی
    // ناوخۆیی دەستبەجێ پیشان دەدرێت و تەنها لە پشتەوە نوێ دەبێتەوە.
    unawaited(_loadAds().whenComplete(() {
      if (mounted && _filter == filter) {
        _entranceCtrl.forward(from: 0.0);
      }
    }));
  }

  // ═══════════════════════════════════════════════════════════
  // ڕەتکردنەوەی ڕیکلام
  // ═══════════════════════════════════════════════════════════
  static const List<String> _cancelReasons = [
    'وردەکارییەکانم هەڵە پڕکردۆتەوە',
    'کۆد یان لینکی ڕیکلامەکە هەڵەیە',
    'دەمەوێت بودجەی ڕیکلامەکە بگۆڕم',
    'دەمەوێت ڕیکلامێکی نوێ بکەم',
    'هۆکارێکی تر',
  ];
  /// `true` دەگەڕێنێتەوە ئەگەر ڕیکلامەکە بەڕاستی ڕەتکرابێتەوە.
  ///
  /// پێشتر ئەم فەنکشنە خۆی `_loadAds(refresh: true)`ی بانگ دەکرد — واتە
  /// داواکارییەکی نوێی تۆڕ + سکێلیتۆن، لە کاتێکدا شاشەی وردەکاری هێشتا
  /// لە سەرەوە بوو. ئێستا ئەنجامەکە دەگەڕێنێتەوە و بانگکەرەکە بڕیار
  /// دەدات کەی و چۆن لیستەکە نوێ بکرێتەوە.
  Future<bool> _openCancelAdDialog(Map<String, dynamic> ad) async {
    final status     = (ad['status'] ?? '').toString();
    final tiktokAdId = ad['tiktok_ad_id']?.toString();
    if (!(status == 'pending' && (tiktokAdId == null || tiktokAdId.isEmpty))) {
      showProxoToast(context, 'ئەم ڕیکلامە ناتوانرێت ڕەت بکرێتەوە', type: ProxoToastType.error);
      return false;
    }

    int? selReason;
    final otherCtrl = TextEditingController();
    bool submitting  = false;
    String? errText;

    final bool? cancelled = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          bool canConfirm() {
            if (selReason == null) return false;
            if (selReason == 4) return otherCtrl.text.trim().length >= 3;
            return true;
          }

          Future<void> submit() async {
            if (!canConfirm() || submitting) return;
            setSheetState(() { submitting = true; errText = null; });
            try {
              final finalReason = selReason == 4
                  ? otherCtrl.text.trim()
                  : _cancelReasons[selReason!];
              final user = supabase.auth.currentUser;
              if (user == null) throw Exception('تکایە دووبارە بچۆ ژوورەوە');
              final raw = await supabase.rpc('pa_cancel_pending_ad', params: {
                'p_ad_id': ad['id'],
                'p_reason': finalReason,
              });
              final result = Map<String, dynamic>.from(raw as Map);
              if (result['ok'] != true) {
                final code = (result['code'] ?? '').toString();
                throw Exception(code == 'ALREADY_REFUNDED'
                    ? 'پارەکە پێشتر گەڕێنراوەتەوە'
                    : 'ئەم ڕیکلامە ناتوانرێت ڕەت بکرێتەوە');
              }
              final fullReason =
                  'بەکارهێنەر خۆی ڕەتیکردەوە — هۆکار: $finalReason';

              if (!mounted) return;
              Navigator.pop(ctx, true);
              // دۆخە نوێیەکە پێشتر زانراوە — بۆیە کارتەکە دەستبەجێ و
              // بەبێ داواکاریی تۆڕ نوێ دەبێتەوە. سینکی ڕاستەقینە دوای
              // داخستنی شاشەی وردەکاری لە پشتەوە دەڕوات.
              _applyLocalAdPatch(ad['id'], {
                'status': 'rejected',
                'reject_reason': fullReason,
              });
              showProxoToast(context,
                '✅ ڕیکلامەکە ڕەتکرایەوە و پارەکەت گەڕایەوە بۆ باڵانسەکەت.',
                type: ProxoToastType.success);
            } catch (e) {
              debugPrint('AdScreen: cancel ad failed: $e');
              setSheetState(() {
                submitting = false;
                errText = 'ڕەتکردنەوەی ڕیکلامەکە سەرنەکەوت — دووبارە هەوڵ بدەرەوە';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AdSurface.sheetRadius)),
              ),
              padding: const EdgeInsets.fromLTRB(AdSurface.sheetPad,
                  AdSurface.sheetPad, AdSurface.sheetPad, AdSurface.sheetPad),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AdSurface.sheetGrabber,
                      borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.10),
                      shape: BoxShape.circle),
                    child: const Icon(ProxoIcons.blocked, size: 18, color: AppColors.red),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('ڕەتکردنەوەی ڕیکلام',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: kAppFont, fontSize: 16,
                        fontWeight: FontWeight.w700, color: Color(0xFF121212))),
                  ),
                ]),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('هۆکاری ڕەتکردنەوە هەڵبژێرە، بودجەکەت بەتەواوی دەگەڕێتەوە بۆ باڵانسەکەت.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: kAppFont, fontSize: 12, height: 1.6,
                      color: AdSurface.slate)),
                ),
                const SizedBox(height: 16),
                ...List.generate(_cancelReasons.length, (i) {
                  final sel = selReason == i;
                  return GestureDetector(
                    onTap: () => setSheetState(() { selReason = i; }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFDC2626).withOpacity(0.06) : AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel ? const Color(0xFFDC2626) : AppColors.border1,
                          width: sel ? 1.6 : 1),
                      ),
                      child: Row(children: [
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? const Color(0xFFDC2626) : const Color(0xFFBBBDC8),
                              width: 1.6),
                          ),
                          child: sel ? Center(
                            child: Container(
                              width: 9, height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626), shape: BoxShape.circle),
                            ),
                          ) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_cancelReasons[i],
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: kAppFont, fontSize: 12.5,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                            color: sel ? const Color(0xFFDC2626) : const Color(0xFF121212)))),
                      ]),
                    ),
                  );
                }),
                if (selReason == 4) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: otherCtrl,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(fontFamily: kAppFont, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'هۆکارەکەت بنووسە...',
                      hintStyle: const TextStyle(fontFamily: kAppFont, fontSize: 12, color: Color(0xFFBBBDC8)),
                      filled: true, fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border1)),
                    ),
                  ),
                ],
                if (errText != null) ...[
                  const SizedBox(height: 10),
                  // Sits in the layout above the confirm button, so it never
                  // covers the button or the reason list.
                  ProxoInlineError(message: errText!),
                ],
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: canConfirm() && !submitting ? submit : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: canConfirm() ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: submitting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                          : Text('دڵنیام، ڕەتی بکەوە',
                              style: TextStyle(
                                fontFamily: kAppFont, fontSize: 14, fontWeight: FontWeight.w700,
                                // دۆخی ناچالاک — تۆنێکی تۆختر لە #9CA3AFی
                        // پێشوو، بۆیە دەقەکە هێشتا دەخوێندرێتەوە کاتێک
                        // دوگمەکە بەردەست نییە.
                        color: canConfirm() ? Colors.white : AdSurface.icon)),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );

    // ⚠ `otherCtrl` تەنها لەم شیتەدا ژیا — دوای داخستنی، دەسڕدرێتەوە.
    // پێشتر هەرگیز `dispose` نەدەکرا و بۆ هەر جارێک کە شیتەکە دەکرایەوە
    // کۆنترۆڵەرێکی نوێ بەجێدەما.
    otherCtrl.dispose();
    return cancelled == true;
  }

  /// تاقە ڕێگای کۆپیکردن لەم شاشەیەدا — کارتەکە و شاشەی وردەکاری
  /// هەردووکیان ئەمە بەکاردەهێنن، بۆیە پەیام و هەستەکە هەمیشە یەکسانن.
  ///
  /// بەهای **خاو** کۆپی دەکرێت (`ad_number` یان `id`ی Supabase) — بێ
  /// `#`، بێ لەیبڵ، بێ بۆشایی — بۆ ئەوەی ڕاستەوخۆ لە گەڕان/پشتگیریدا
  /// بەکاربێت.
  // ═══════════════════════════════════════════════════════════════════════
  // شیتی دەستکاری — بەکارهێنەر خانە داواکراوەکە ڕاست دەکاتەوە
  // ═══════════════════════════════════════════════════════════════════════
  // ئەم شاشەیە خاوەنی هەموو نووسینەکانی Supabase-ە (وەک شیتی
  // ڕەتکردنەوە)، بۆیە شاشەی وردەکاری تەنها بانگی دەکات و ئەنجامەکە
  // وەردەگرێت — هیچ لۆجیکی داتابەیسێکی خۆی نییە.
  //
  // ئەگەر پاشەکەوتکردن سەرکەوتوو بوو، ئەو `Map`ـە دەگەڕێنێتەوە کە
  // نووسرا (بۆ نموونە `{video_code: 'ABC', status: 'review', …}`)، بۆیە
  // بانگکەرەکە دەتوانێت دۆخی خۆی نوێ بکاتەوە بەبێ داواکارییەکی نوێ.
  // `null` = بەکارهێنەر پاشگەز بووەوە یان شکستی هێنا.
  Future<Map<String, dynamic>?> _openAdFixSheet(Map<String, dynamic> ad) async {
    final String field = (ad[_kAdcColUpdateField] ?? '').toString().trim();
    if (field.isEmpty) {
      showProxoToast(context, 'خانەی داواکراو دیاری نەکراوە',
          type: ProxoToastType.error);
      return null;
    }

    final String label = _kAdcFieldLabels[field] ?? field;
    final String reason = (ad[_kAdcColUpdateReason] ?? '').toString().trim();
    final List<(String, String)>? choices = _kAdcFieldChoices[field];
    final bool isDate = field == 'start_date';
    final bool isTime = field == 'start_time';
    final bool isLink = field == 'video_link';
    final String current = (ad[field] ?? '').toString().trim();

    final TextEditingController ctrl = TextEditingController(text: current);
    String value = current;
    bool submitting = false;
    String? errText;

    final Map<String, dynamic>? saved =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // ── پشکنین ─────────────────────────────────────────────────
          // بەتاڵ هەرگیز نانێردرێت، و بەهایەکی نەگۆڕاو هەروەها — ئەگەرنا
          // ئادمین «وەڵامی هات» دەبینێت لەگەڵ هەمان بەهای هەڵەدا.
          String? validate() {
            final String v = value.trim();
            if (v.isEmpty) return 'ئەم خانەیە پێویستە پڕ بکرێتەوە';
            if (v == current) return 'هیچ گۆڕانکارییەکت نەکردووە';
            if (isLink) {
              final Uri? u = Uri.tryParse(v);
              if (u == null || !u.hasScheme || !u.host.contains('.')) {
                return 'لینکەکە دروست نییە — دەبێت بە https:// دەست پێبکات';
              }
            }
            return null;
          }

          Future<void> save() async {
            final String? err = validate();
            if (err != null) {
              setSheetState(() => errText = err);
              return;
            }
            if (submitting) return;
            setSheetState(() {
              submitting = true;
              errText = null;
            });
            try {
              final user = supabase.auth.currentUser;
              if (user == null) throw Exception('تکایە دووبارە بچۆ ژوورەوە');

              // ⚠ `needs_update` لێرەدا **پاک ناکرێتەوە** — بڕوانە
              // کۆنتراتەکەی سەرەوە. تەنها `update_submitted_at` دۆخەکە
              // دەگۆڕێت بۆ «جێبەجێ کرا» لای ئادمین.
              final String now = DateTime.now().toIso8601String();
              final Map<String, dynamic> patch = <String, dynamic>{
                field: value.trim(),
                _kAdcColSubmittedAt: now,
                'status': _kAdcStatusReview,
                'updated_at': now,
              };
              await supabase
                  .from('pa_ads')
                  .update(patch)
                  .eq('id', ad['id'])
                  .eq('user_id', user.id);

              if (!ctx.mounted) return;
              Navigator.pop(ctx, patch);
            } catch (e) {
              debugPrint('AdScreen: ad fix submit failed: $e');
              final bool offline = e.toString().contains('SocketException') ||
                  e.toString().contains('network');
              setSheetState(() {
                submitting = false;
                errText = offline
                    ? 'ئینتەرنێت نییە — دووبارە هەوڵ بدەرەوە'
                    : 'ناردنەوەکە سەرنەکەوت — دووبارە هەوڵ بدەرەوە';
              });
            }
          }

          // ── خودی خانەکە ────────────────────────────────────────────
          Widget input() {
            if (choices != null) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (String key, String kuLabel) in choices)
                    GestureDetector(
                      onTap: () => setSheetState(() {
                        value = key;
                        errText = null;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: value == key
                              ? _kAdcFixBg
                              : AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: value == key
                                ? _kAdcFixInk
                                : AppColors.border1,
                            width: value == key ? 1.6 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: value == key
                                    ? _kAdcFixInk
                                    : const Color(0xFFBBBDC8),
                                width: 1.6,
                              ),
                            ),
                            child: value == key
                                ? const Center(
                                    child: SizedBox(
                                      width: 9,
                                      height: 9,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _kAdcFixInk,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kuLabel,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: kAppFont,
                                fontSize: 12.5,
                                fontWeight: value == key
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: value == key
                                    ? _kAdcFixInk
                                    : const Color(0xFF121212),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ],
              );
            }

            if (isDate || isTime) {
              return GestureDetector(
                onTap: () async {
                  if (isDate) {
                    final DateTime base =
                        DateTime.tryParse(value) ?? DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: ctx,
                      initialDate: base,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 1)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked == null) return;
                    // 'YYYY-MM-DD' — هەمان فۆرماتی ئێستای ستوونەکە،
                    // ئەوەی `DateTime.tryParse` لە کارتەکەدا دەیخوێنێتەوە.
                    setSheetState(() {
                      value = '${picked.year.toString().padLeft(4, '0')}-'
                          '${picked.month.toString().padLeft(2, '0')}-'
                          '${picked.day.toString().padLeft(2, '0')}';
                      errText = null;
                    });
                  } else {
                    final List<String> parts = value.split(':');
                    final TimeOfDay? picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                        hour: int.tryParse(
                                parts.isNotEmpty ? parts[0] : '') ??
                            12,
                        minute: int.tryParse(
                                parts.length > 1 ? parts[1] : '') ??
                            0,
                      ),
                    );
                    if (picked == null) return;
                    setSheetState(() {
                      value = '${picked.hour.toString().padLeft(2, '0')}:'
                          '${picked.minute.toString().padLeft(2, '0')}';
                      errText = null;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border1),
                  ),
                  child: Row(children: [
                    Icon(
                      isDate
                          ? ProxoIcons.calendar
                          : ProxoIcons.clock,
                      size: 18,
                      color: _kCampaignSubtle,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value.isEmpty ? 'هەڵبژێرە' : value,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF121212),
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }

            return TextField(
              controller: ctrl,
              autofocus: true,
              // کۆد و لینک هەردووکیان لاتینن — LTR بۆ ئەوەی پیتەکان
              // پێچەوانە نەبنەوە لەناو فۆرمێکی RTLدا.
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              keyboardType:
                  isLink ? TextInputType.url : TextInputType.text,
              textInputAction: TextInputAction.done,
              onChanged: (String v) => setSheetState(() {
                value = v;
                errText = null;
              }),
              onSubmitted: (_) => save(),
              style: const TextStyle(fontFamily: kAppFont, fontSize: 13),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 12,
                    color: Color(0xFFBBBDC8)),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border1),
                ),
              ),
            );
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(
                          top: Radius.circular(AdSurface.sheetRadius)),
                ),
                padding: const EdgeInsets.fromLTRB(AdSurface.sheetPad,
                  AdSurface.sheetPad, AdSurface.sheetPad, AdSurface.sheetPad),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AdSurface.sheetGrabber,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                          color: _kAdcFixWell, shape: BoxShape.circle),
                      child: const Icon(ProxoIcons.edit,
                          size: 18, color: _kAdcFixInk),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF121212),
                        ),
                      ),
                    ),
                  ]),
                  // ── تێبینی ئادمین، سەرووی خانەکە ────────────────────
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: _kAdcFixBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kAdcFixBorder),
                      ),
                      child: Text(
                        reason,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 12.5,
                          height: 1.7,
                          fontWeight: FontWeight.w600,
                          color: _kAdcFixInk,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  input(),
                  if (errText != null) ...[
                    const SizedBox(height: 10),
                    ProxoInlineError(message: errText!),
                  ],
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: submitting ? null : save,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: submitting
                            ? const Color(0xFFE5E7EB)
                            : _kCampaignBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Text(
                              _kAdcFixSave,
                              style: TextStyle(
                                fontFamily: kAppFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );

    ctrl.dispose();
    if (saved == null || !mounted) return null;

    // کارتەکە دەستبەجێ نوێ دەبێتەوە — بەبێ داواکاریی نوێی تۆڕ، چونکە
    // ئێمە خۆمان ئەم گۆڕانکاریەمان نووسیوە و ئەنجامەکەی دەزانین.
    if (isLink) saved['thumbnail_url'] = null;
    _applyLocalAdPatch(ad['id'], saved);
    if (isLink) {
      _queueLegacyThumbnailMigrations(<Map<String, dynamic>>[
        <String, dynamic>{...ad, ...saved},
      ]);
    }
    showProxoToast(context, _kAdcFixOkMsg, type: ProxoToastType.success);
    return saved;
  }

  void _copyText(String text) {
    final String raw = text.trim();
    if (raw.isEmpty) return;
    Clipboard.setData(ClipboardData(text: raw));
    // هەمان هەستی سووکی `_IosPressable` لە کاتی تاپ — دڵنیایی فیزیکی
    // کە کۆپی کرا، بەبێ چاوەڕوانی بینینی تۆست.
    HapticFeedback.selectionClick();
    if (!mounted) return;
    showProxoToast(context, _kAdcCopiedMsg, type: ProxoToastType.success);
  }

  bool _feedbackDialogOpen = false;

  Future<void> _openAdFeedback(Map<String, dynamic> ad) async {
    if (_feedbackDialogOpen) return;
    final String id = (ad['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    _feedbackDialogOpen = true;
    try {
      final int? rating = await showAdFeedbackDialog(
        context,
        adId: id,
        adTitle: (ad['title'] ?? 'ڕیکلام').toString(),
        thumbnailUrl: ad['thumbnail_url']?.toString(),
      );
      if (!mounted || rating == null) return;
      _applyLocalAdPatch(id, <String, dynamic>{
        'feedback_rating': rating,
        'feedback_at': DateTime.now().toUtc().toIso8601String(),
      });
      showProxoToast(
        context,
        'سوپاس بۆ فیدباکەکەت',
        type: ProxoToastType.success,
      );
    } finally {
      _feedbackDialogOpen = false;
    }
  }

  // ── وردەکاری مۆدال ───────────────────────────────────────
  // ── فلاگی پاراستن — ڕێگری لە کردنەوەی دووبارەی مۆدالی وردەکاری ڕیکلام
  // پێش ئەوەی یەکەمیان داخرێت. بەبێ ئەم فلاگە، ئەگەر بەکارهێنەر خێرا دوو
  // جار لەسەر کارتێک کلیک بکات (یان GestureDetector دووجار onTap
  // بگەڕێنێتەوە)، دوو مۆدال ڕوویەک دەکەونە سەر یەک، و کلیکی یەکەم لە
  // دەرەوە تەنها سەرەوەکەیان دادەخات، بۆیە وادیارە بەشەکە دەبێتە دوو
  // بەش و لاچوونی تەواو کاتی زیاتری دەوێت (لاگ).
  bool _adDetailsOpen = false;

  // ── کردنەوەی شاشەی «وردەکاری ڕیکلام» ────────────────────────────────────
  // تاقە گۆڕانکاری ئەم فایلە: تاپ لەسەر کارتێک ئێستا شاشەی `ad_details.dart`
  // دەکاتەوە لە جیاتی شیتی خوارەوە. هەمان `Map<String, dynamic>`ی pa_ads
  // دەنێردرێت — هیچ داواکارییەکی نوێی داتابەیس، هیچ مۆدێلێکی دووبارە.
  //
  // هەموو کردارەکان لێرەوە پێدەدرێن وەک callback، بۆیە شاشەی نوێ هیچ
  // لۆجیکێکی بازرگانی خۆی نییە: هاوبەشکردن `_shareAd`ە، دووبارەکردنەوە
  // `_duplicateAd`ە، هەڵوەشاندنەوە `_openCancelAdDialog`ە، و کۆپیکردن
  // `_copyText`ە — هەر چواریان پێشتر لەم فایلەدا بوون.
  //
  // ── گەڕانەوە ───────────────────────────────────────────────────────────
  // گەڕانەوە لە شاشەی وردەکاری بە بنەڕەت **سفر کارە**: نە داواکاریی
  // Supabase، نە سکێلیتۆن، نە `setState`. لیستەکە، شوێنی سکڕۆڵەکەی و
  // دۆخی هەر کارتێک (لەوانەش «بینینی زیاتر»ی کراوە) وەک خۆیان دەمێننەوە.
  //
  // تەنها کاتێک کارێکی ڕاستەقینە دەکرێت کە ڕیکلامەکە بەڕاستی گۆڕابێت.
  // ئەوەش بە دوو ڕێگا دەزانرێت، بۆ ئەوەی هیچ ڕێگایەکی داخستن لەبیر نەکرێت:
  //
  //   1. `Navigator.pop(context, true)` — دوگمەی گەڕانەوەی خودی شاشەکە
  //   2. `AdDetailsOutcome` — ئۆبجێکتێکی هاوبەش کە شاشەی وردەکاری
  //      نیشانەی دەکات. ئەمە کاری دەکات تەنانەت لەگەڵ دوگمەی گەڕانەوەی
  //      سیستەم، سوایپی iOS، یان predictive back-ی ئەندرۆید — کە هیچیان
  //      ناتوانن `result` بگەڕێننەوە.
  //
  // پاشان سینکەکە **بێدەنگە** و `setState`ەکەی دواخراوە تا ئەنیمەیشنی
  // دەرچوون تەواو دەبێت — داواکارییەکە هەر دەستبەجێ دەڕوات، بۆیە
  // چاوەڕوانییەکە هیچ کاتێک زیاد ناکات، بەڵام هیچ فرەیمێکی ئەنیمەیشن
  // بە بنیاتنانەوەی لیستەکە قورس ناکرێت.
  Future<void> _openAdDetails(Map<String, dynamic> ad) async {
    if (_adDetailsOpen) return;
    _adDetailsOpen = true;

    final String status     = (ad['status'] ?? '').toString();
    final String tiktokAdId = (ad['tiktok_ad_id'] ?? '').toString();
    // هەمان مەرجی `isCancellable`ی کارتەکە — نەک مەرجێکی نوێ.
    final bool isCancellable = status == 'pending' && tiktokAdId.isEmpty;

    final AdDetailsOutcome outcome = AdDetailsOutcome();

    try {
      final bool? changed = await Navigator.of(context).push<bool>(
        adDetailsRoute(
          ad: ad,
          outcome: outcome,
          onShare: () => _shareAd(ad: ad, context: context),
          onRepeat: ({required onLoading, required onDone}) =>
              _duplicateAd(ad, onLoading: onLoading, onDone: onDone),
          onCancel: isCancellable ? () => _openCancelAdDialog(ad) : null,
          onFix: () => _openAdFixSheet(ad),
          onCopyId: _copyText,
        ),
      );

      if (!mounted) return;
      if (changed != true && !outcome.changed) return; // ← ڕێگای باو: هیچ

      unawaited(_syncAdsSilently(
        applyAfter: Future<void>.delayed(kAdDetailsSettleDelay),
      ));
    } finally {
      _adDetailsOpen = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _AdGlowBehavior(),
      child: Directionality(
        // Reference is LTR end-to-end (matches ProxoTopBar, which is
        // itself pinned to LTR).
        textDirection: TextDirection.ltr,
        child: Scaffold(
          // پاشبنەمای فڵات AppColors.bg گۆڕدرا بۆ AppBackground (لە
          // app_theme.dart)، هەمان تۆنی بنەڕەتی بەڵام بە gradient-ی
          // زۆر سووک لە سەرەوە بۆ خوارەوە بۆ قووڵییەکی زیاتر — هیچ
          // شتێکی تر (کارت، سێبەر، سنوور، بۆشایی) نەگۆڕدراوە.
          backgroundColor: _dsPageBg,
          // ── سنووردارکردنی textScaler — ڕێگری لە شکانی proportion-ی
          // کارتەکان دەکات ئەگەر یوزەر فۆنتی زۆر گەورە هەڵبژاردبێت لە
          // ڕێکخستنەکانی ئامێر، بەبێ ئەوەی پێشوازی لە هەڵبژاردنی یوزەر
          // بکەین بە تەواوی — تەنها لەناو سنوورێکی سەلامەتدا (٪90-١٢٥).
          // Shared components — ad_screen.dart owns Campaigns content only.
          appBar: ProxoTopBar(
            topPadding: MediaQuery.paddingOf(context).top,
            onMenuTap: widget.onMenuTap,
          ),
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context)
                  // The v4 measurements assume textScaler 1.0. Allowing 1.18
                  // inflated every label ~18%, which wrapped "Impressions",
                  // the card title, the ID and both filter chips. Capped at
                  // 1.0 so the card matches the reference; raise this again if
                  // system font scaling matters more than exact geometry.
                  .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.0),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(children: [
                // باری فلتەر — دۆخ + ماوە، دیزاینی iOS.
                _buildTopFilters(),
                if (_isOffline) _buildOfflineBanner(),
                Expanded(child: _buildBody()),
              ]),
            ),
          ),
          // NO bottomNavigationBar here — deliberately.
          //
          // CONFIRMED in main.dart: the root shell's Scaffold renders
          //     bottomNavigationBar: ProxoBottomNav(
          //       currentIndex: _tabIndex, onTap: _onTabTap)
          // and hosts this screen as its `body` (tab index 1). Adding a nav
          // here painted a SECOND pill stacked under the shell's.
          //
          // The shell also owns slot 2 (the centre FAB) through _onTabTap, so
          // the create flow is already wired — nothing to duplicate here.
          //
          // Only if main.dart is ever changed to NOT render the nav, restore:
          //   bottomNavigationBar: ProxoBottomNav(
          //     currentIndex: 1,              // Campaigns
          //     onTap: (i) {                  // slot 2 is the centre FAB
          //       if (i == 2) {
          //         Navigator.push(context, MaterialPageRoute(
          //             builder: (_) => const AdCreateScreen()));
          //       }
          //     },
          //   ),
        ),
      ),
    );
  }

  // ── Offline banner ────────────────────────────────────────
  Widget _buildOfflineBanner() {
    final double s = _responsiveScale(context);
    final _T t = _T.of(s);
    return Padding(
      // هەمان گەتەری لاپەڕە. پێشتر `_dsScreenPad * s` بوو (16 × scale)،
      // بۆیە بانەری ئۆفلاین لە نێوان پیلەکان و کارتەکاندا بە لێوارێکی
      // جیاوازەوە دەردەکەوت و زنجیرەی ستوونی دەشکاند.
      padding: EdgeInsets.fromLTRB(
          _kCampaignPageGutter, _dsTitleGap * s, _kCampaignPageGutter, 0),
      child: _DsCard(
        scale: s,
        // Cached-data notice: same card geometry as before, but on the shared
        // `offline` tone instead of the cream info tone, so a connection
        // notice looks the same here as it does everywhere else in the app.
        color: proxoErrorPalette(ProxoErrorTone.offline).surface,
        padding: EdgeInsets.symmetric(
            horizontal: _dsCardPad * s, vertical: _dsRowGap * s * 0.75),
        child: Row(children: [
          Container(
            width: _dsTile * s, height: _dsTile * s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: proxoErrorPalette(ProxoErrorTone.offline).well,
                shape: BoxShape.circle),
            child: Icon(ProxoIcons.offline,
                size: _dsTileIcon * s,
                color: proxoErrorPalette(ProxoErrorTone.offline).accent),
          ),
          SizedBox(width: _dsTileGutter * s),
          Expanded(
            child: Text('پەیوەندی نییە — داتای پاشەکەوتکراو نیشان دەدرێت',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.subtitle),
          ),
          SizedBox(width: _dsTrailGap * s),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: () => _loadAds(refresh: true),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: _dsTileGutter * s),
                child: Text('دووبارە',
                    style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: _dsFsAction * s,
                        fontWeight: FontWeight.w700,
                        color: _dsBlue)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // باری فلتەری سەرەوە (دۆخ + ماوە) — دیزاینی iOS
  // ═══════════════════════════════════════════════════════════
  // هیچ لۆجیکێکی نوێ نییە: پیلی دۆخ هەمان `_setFilter`/`_filterDefs`
  // بەکاردەهێنێت، و پیلی ماوە هەمان `_dateRangeLabel` + `_loadAds(refresh:)`
  // کە پێشتر لە باری فلتەری کۆندا بوون. تەنها ڕووکارەکە نوێیە.
  Widget _buildTopFilters() {
    final double s = _responsiveScale(context);
    final int idx =
        (_pillIndex >= 0 && _pillIndex < _filterDefs.length) ? _pillIndex : 0;

    return RepaintBoundary(
      child: Directionality(
        textDirection: TextDirection.rtl,
        // SafeArea لای سەرەوە: ئەگەر ڕۆژێک TopBar لابرا یان شاشەکە چووە ژێر
        // نۆچ/دەستکاری، چیپەکان هەرگیز ناچنە ژێر بارە سیستەمییەکە.
        child: SafeArea(
          top: false,
          bottom: false,
          // ⚠ پەدینگ لێرەیە، **نەک** لەناو سکڕۆڵەکەدا وەک `padding:`.
          //
          // `SingleChildScrollView(padding:)` پەدینگەکە دەخاتە ناو ناوەڕۆکی
          // سکڕۆڵکراوەوە، واتە گەتەری سەرەتا لەگەڵ چیپەکاندا دەڕوات و لە
          // کۆتاییدا ون دەبێت. بەڵام ئەمە ڕیزێکی فلتەرە کە دەبێت لەگەڵ
          // لێواری کارتەکان ڕێک بێت لە هەموو دۆخێکدا، بۆیە پەدینگی ئاسۆیی
          // دەبێت **دەرەوەی** ویوپۆرتەکە بێت.
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _kFbBarPadH,
              vertical: _kFbBarPadV * s,
            ),
            // ── هەمان سنووری پانی کارتەکان ───────────────────────────────
            // هەر کارتێک خۆی لە `ConstrainedBox(maxWidth: 398)`ێکدا ناوەڕاست
            // دەکات، بۆیە لەسەر شاشەی پان (تابلێت، فۆڵدەبڵ) کارتەکان لە 398
            // dp دەوەستن و ناوەڕاست دەبن. بەبێ هەمان سنوور لێرە، باری فلتەر
            // بە درێژایی هەموو پانییەکە دەکێشرا و چیپەکان لە دەرەوەی لێواری
            // کارتەکان دەردەکەوتن.
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _kCampaignCardMaxWidth),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _kFbTrack, width: 1),
                    ),
                  ),
                  child: SizedBox(
                    height: _kFbChipH * s,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _filterDefs.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(width: _kFbChipGap * s),
                      itemBuilder: (context, i) {
                        final String statusEn = _filterDefs[i].$2;
                        return _StatusChip(
                          scale: s,
                          selected: i == idx,
                          label: _kFbStatusKu[statusEn] ?? statusEn,
                          onTap: () => _setFilter(i, _filterDefs[i].$1),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Body — CustomScrollView + SliverList ─────────────────
  // ── AnimatedSwitcher دەکاتە کراسفەیدی نەرم لەنێوان سکێلیتۆن و
  // ناوەڕۆکی ڕاستەقینە — بەبێ هیچ جامپ یان فلیکەرێک ──────────
  Widget _buildBody() {
    // ── ئەرکی ئەم مێتۆدە: نیشاندانی ناوەڕۆک بەبێ هیچ جوڵەیەکی لایەوت ─────
    //
    // پێشتر لێرە `AnimatedSwitcher`ێک هەبوو کە تەواوی داری ناوەڕۆکەکەی
    // دەگۆڕی لەنێوان «سکێلیتۆن» و «ناوەڕۆک»دا، بە فەید + `SlideTransition`ی
    // ستوونی. ئەوە چوار کێشەی جیای دروست دەکرد لە ساتی فلتەرکردندا:
    //
    //   1. `SlideTransition` خۆی — کارتەکان بە ئەنقەست دەبازین
    //   2. `layoutBuilder`ەکەی هەردوو لیستەکەی پێکەوە لە `Stack`ێکدا
    //      دەهێشتەوە کە قەبارەی لە منداڵەکانییەوە دەهات، بۆیە کاتێک ژمارەی
    //      کارتەکان دەگۆڕا بەرزایی گشتی دەبازی
    //   3. هەردوو `CustomScrollView`ەکە هەمان `_scrollCtrl`یان پێوە
    //      دەلکا لە ماوەی گواستنەوەکەدا — یەک کۆنترۆڵەر بە دوو
    //      `ScrollPosition`ەوە، کە `_onScroll` تێکدەدات و لە release دا
    //      دەبێتە هۆی لەرینەوە
    //   4. لیستی ناوەڕۆک بە تەواوی هەڵدەوەشێنرایەوە و دووبارە دروست
    //      دەکرایەوە، بۆیە `PageStorageKey` ئۆفسێتەکەی لە فرەیمێکی
    //      دواتردا دەگەڕاندەوە — جیتەرێکی بەرچاو
    //
    // ئێستا: لیستی ناوەڕۆک **هەرگیز هەڵناوەشێنرێتەوە** لە کاتی فلتەرکردندا.
    // سکێلیتۆنەکە تەنها وەک چینێکی داپۆشەری ڕەق لەسەری دادەنرێت لەناو
    // `Stack`ێکی `StackFit.expand`دا — واتە قەبارەی چینەکە لە دایکەکەیەوە
    // دێت، نەک لە منداڵەکانییەوە، بۆیە **مەحاڵە** بەرزایی بگۆڕێت. تەنها
    // شتێک کە ئەنیمەیت دەکرێت ڕوونی (opacity)ی خۆیەتی — نە جوڵە، نە
    // سکەیڵ، نە بۆشایی.
    final bool showSkeleton = _loading;
    // بارکردنی یەکەم: هێشتا هیچ داتایەک نییە بۆ داپۆشین.
    final bool firstLoad = showSkeleton && _ads.isEmpty;

    Widget base;
    if (firstLoad) {
      base = const SizedBox.expand();
    } else if (_hasError) {
      base = _buildErrorState();
    } else if (_filtered.isEmpty) {
      // لە ماوەی فلتەرکردندا «هیچ ڕیکلامێک نییە» نیشان نادرێت — ئەگەرنا
      // بۆ چەند فرەیمێک دەردەکەوێت و پاشان دەفەوتێت.
      base = showSkeleton ? const SizedBox.expand() : _buildEmpty();
    } else {
      base = _buildContentList();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: _kSkeletonFade,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              // تەنها فەید. بە ئەنقەست هیچ `SlideTransition`،
              // `ScaleTransition` یان `SizeTransition`ێک نییە.
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              // قەبارە لە دایکەوە دێت (`StackFit.expand`)، نەک لە
              // منداڵەکانەوە — بۆیە هاتن و چوونی سکێلیتۆنەکە هەرگیز
              // لایەوتی دەوروبەری ناگۆڕێت.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: showSkeleton
                  ? _SkeletonOverlay(
                      key: const ValueKey('sk'),
                      count: _skeletonOverlayCount,
                    )
                  : const SizedBox.expand(key: ValueKey('sk_none')),
            ),
          ),
        ),
      ],
    );
  }

  /// ژمارەی کارتی سکێلیتۆن لە چینی داپۆشەردا.
  ///
  /// دەبێت لانیکەم ئەوەندە بێت کە هەموو کارتە بینراوەکان بپۆشێت، ئەگەرنا
  /// کارتی کۆن لە ژێر چینەکەوە دەردەکەوێت. سەروو بە 4 بەستراوەتەوە —
  /// زیاتر لەوە بە هیچ شێوەیەک لە ویوپۆرتدا جێی نابێتەوە.
  int get _skeletonOverlayCount {
    return max(2, min(_filtered.length, 4));
  }

  /// لیستی ناوەڕۆک. ئیتر هیچ ڕەوتێکی `skeleton` تێدا نییە — سکێلیتۆن
  /// چینێکی داپۆشەری جیایە لە `_buildBody`دا، بۆیە ئەم لیستە لە کاتی
  /// فلتەرکردندا هەرگیز هەڵناوەشێنرێتەوە و `_scrollCtrl` هەمیشە تەنها بە
  /// یەک `ScrollPosition`ەوە دەلکێت.
  Widget _buildContentList() {
    final items = _filtered;
    // `RefreshIndicator` بە ئاراستەی ستوونی کار دەکات، بۆیە RTL هیچ
    // کاریگەرییەکی لەسەر ئیشارەتەکە نییە؛ سپینەرەکە خۆی هەمیشە لە
    // ناوەڕاستی ئاسۆیی دادەنیشێت. `AlwaysScrollableScrollPhysics` وەک
    // دایکی `BouncingScrollPhysics` دەمێنێتەوە بۆ ئەوەی ڕاکێشان تەنانەت
    // کاتێک لیستەکە لە یەک شاشە کورتترە کار بکات.
    return ProxoRefresh(
      controller: widget.refreshController,
      scrollController: _scrollCtrl,
      onRefresh: _handlePullRefresh,
      // Reuses the entrance this screen already has — see the note on
      // `ProxoRefresh.onArrive`. No second animation system, and the stagger
      // stays the one that was tuned here (40ms / 240ms / 6 slots).
      onArrive: () {
        if (mounted) _entranceCtrl.forward(from: 0.0);
      },
      child: RefreshIndicator(
        color: AppColors.dark,
        onRefresh: _handlePullRefresh,
        child: CustomScrollView(
          // The AnimatedSwitcher in _buildBody tears the list down and rebuilds
          // it whenever the screen flips between skeleton, empty and content.
          // A PageStorageKey makes the offset survive that, so a silent
          // background refresh never yanks the user back to the top.
          key: const PageStorageKey('ads_list'),
          controller: _scrollCtrl,
          // سکڕۆڵی نەرم: فیزیکسی iOS (بۆنس + دیسێلەرەیشنی نەرم) لە جیاتی
          // Clamping-ی ئەندرۆید، لەگەڵ کاشێکی فراوانتر بۆ ئەوەی کارتی داهاتوو
          // پێش گەیشتن ڕەیستەر بکرێت — بۆیە سکڕۆڵ ناوەستێت.
          // 2400 → 1200. cacheExtent-ی گەورە کارتی زیاتر پێش وەخت
          // ڕەیستەر دەکات — لەسەر کۆمپیوتەر باشە، بەڵام لەسەر مۆبایل
          // واتە لایەری زیاتر لە بیرگەدا و کاری زیاتر بۆ GPU لە کاتی
          // گەڕانەوە لە شیتی وردەکارییەوە. 1200 ≈ دوو کارت لە پێش و
          // دوو لە پاش — بەسە بۆ سکڕۆڵێکی بێ‌وەستان.
          cacheExtent: 1200,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  _kCampaignPageGutter,
                  _kCampaignListTop * _campaignScale(context),
                  _kCampaignPageGutter,
                  0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final ad = items[i];
                    // هەموو ڕیزە بارکراوەکان بە lazy SliverList وێنا
                    // دەکرێن؛ دوگمەی دووەمی «زیاتر» لابرا تا تەنها
                    // کۆنترۆڵی ناو خودی کارت بمێنێتەوە.
                    return _AdcListEntrance(
                      key: ValueKey(ad['id']),
                      index: i,
                      animation: _entranceCtrl,
                      child: RepaintBoundary(
                        child: _AdCard(
                          ad: ad,
                          isHighlighted: _highlightId == ad['id']?.toString(),
                          onTap: () => _openAdDetails(ad),
                          onCopyId: _copyText,
                          onFix: () => _openAdFixSheet(ad),
                          onFeedback: () => _openAdFeedback(ad),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                  // کاتێک لیستەکە دەگۆڕێت (ڕیکلامێکی نوێ لە سەرەوە زیاد
                  // دەبێت، یان یەکێک دەڕژێتە دەرەوەی فلتەرەکە)، ئەمە وا
                  // دەکات Flutter منداڵە کلیلدارەکان **بە کلیل** بدۆزێتەوە
                  // نەک بە ئیندێکس. بەبێ ئەمە، زیادکردنی یەک ڕیکلام واتە
                  // هەموو کارتەکانی خوارەوە بە یەک ئیندێکس دەشێوێن و
                  // state-یان (لەوانەش «بینینی زیاتر»ی کراوە) لەدەست دەچێت.
                  findChildIndexCallback: (Key key) {
                    if (key is! ValueKey) return null;
                    final Object? id = key.value;
                    if (id == null) return null;
                    final int i = items.indexWhere(
                        (a) => (a['id'] ?? '').toString() == id.toString());
                    return i < 0 ? null : i;
                  },
                  addRepaintBoundaries: false, // We add them manually
                  addAutomaticKeepAlives: false,
                ),
              ),
            ),
            // ── Load more indicator ──
            SliverToBoxAdapter(
              child: Padding(
                // ── 110 بۆ گەردی float-ی ژێرەوە زیادکراوە بەسەر بۆشایی
                // سەلامەتی خوارەوەی ئامێر (گلید-بار/ئیشارەی ماڵەوە) بۆ
                // ئەوەی هیچ کارتێک لە پشتی نەشاردرێتەوە لەسەر هیچ ئامێرێک.
                padding: EdgeInsets.only(bottom: 110 + MediaQuery.of(context).padding.bottom),
                child: _loadingMore
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: _dsBlue)),
                        ))
                    : !_hasMore && items.length >= _pageSize
                        ? Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: _dsRowGap *
                                    _responsiveScale(context)),
                            child: Center(
                              child: Text(
                                'هەموو ${items.length} ڕیکلام نیشان دران',
                                style:
                                    _T.of(_responsiveScale(context)).micro,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error / Empty / Skeleton ─────────────────────────────
  // Both of these are the dashboard's `_NoActiveCampaignsCard`: a tinted
  // `_CardShell`, a 46 dp circular well, a 14 dp gutter, a 14/w700 title,
  // 5 dp, a 10.5/w400 body, 12 dp, and a `_PrimaryButton`. Only the tone
  // differs — the Rejected pair for an error, the system's cream for empty.
  Widget _buildErrorState() {
    // Same card geometry as before — only the tone and the icon now follow
    // whether this was a connectivity failure or something else, using the
    // app-wide error palette so it matches the rest of Proxo exactly.
    final p = proxoErrorPalette(
        _offlineError ? ProxoErrorTone.offline : ProxoErrorTone.danger);
    return _buildNoticeCard(
      wellColor: p.well,
      iconColor: p.accent,
      cardColor: p.surface,
      icon: p.icon,
      title: _offlineError ? 'پەیوەندی نییە' : 'هەڵەیەک ڕوویدا',
      body: _errorMsg,
      action: 'دووبارە هەوڵ بدەرەوە',
      onAction: () => _loadAds(refresh: true),
    );
  }

  // ── حاڵەتی بەتاڵ — بێ کارت، بێ بۆکسی پشتەوە ────────────────────────────
  // یەک کۆمپۆنێنتی یەکگرتوو: ئیلوستراسیۆن → ناونیشان → دەقی لاوەکی →
  // دوگمە، هەموویان لە ناوەڕاستی ستوونێکدا و هەموو بۆشاییەکان لەسەر
  // هەمان پێوەری `s`.
  //
  // ⚠ ئەم ڕەمپە ئێستا **جیاوازە** لە هی داشبۆرد (`_EmptyCampaignsState`
  // لە `home_screen.dart`)، کە هێشتا لەسەر ئارتوۆرک و ژمارە کۆنەکانە.
  // ئەگەر ویستت هەردووکیان یەک بن، هەمان ژمارەکان بۆ ئەوێش ببە.
  // پێوانەکانی خودی ئارتوۆرکەکە لە ئاستی فایلدان (`_kEmptyArtW` و هاوڕێکانی
  // لە سەرەوە)، چونکە `_EmptyAdsIllustration` وێدژێتێکی سەربەخۆیە.
  static const double _kEmptyArtGap    = 28.0;  // ئیلوستراسیۆن → ناونیشان
  static const double _kEmptyTitleGap  = 10.0;  // ناونیشان → دەقی لاوەکی
  static const double _kEmptyBodyGap   = 28.0;  // دەقی لاوەکی → دوگمە
  static const double _kEmptyBodyMax   = 300.0; // پانی زۆرترینی ڕستەکە

  // ── تایپی دۆخی بەتاڵ — هاوبەشە لەگەڵ `tools_screen.dart` ─────────────────
  // ئەم چوار ژمارەیە دەبێت **دەقاودەق** وەک ئەوانەی `tools_screen.dart`
  // بن (`_kFsEmptyTitle` / `_kFsEmptyBody` / `_kLhEmptyTitle` /
  // `_kLhEmptyBody`)، چونکە هەردوو دۆخی بەتاڵ یەک کۆمپۆنێنتن بە ئارتوۆرکی
  // جیاواز. ئەگەر یەکێکیان گۆڕا، ئەوی تریش بگۆڕە.
  //
  // ⚠ ژمارە **کۆتایی**ن بە dp: بە ئەنقەست `_kAdCardKuBump` جێبەجێ
  // ناکرێن، وەک لای tools. `s` (پێوەری شاشە) هێشتا جێبەجێ دەکرێت.
  static const double _kEmptyFsTitle   = 17.0;
  static const double _kEmptyFsBody    = 13.0;
  static const double _kEmptyLhTitle   = 1.35;
  static const double _kEmptyLhBody    = 1.40;

  /// ناونیشان — هەمان مەرەکەبی tools (`_kInk`, slate-900). ⚠ بوو
  /// `#000000`ی ڕەق، کە لە هیچ شوێنێکی تری ئەپەکەدا بەکارنەهاتووە.
  static const Color _kEmptyInkTitle = Color(0xFF0F172A);

  /// دەقی لاوەکی — slate-500، هەمان `_kMuted`ی tools. پێشتر هەمان ڕەشی
  /// ناونیشانەکە بوو، بۆیە هیچ هێرارکییەکی ڕەنگ نەبوو.
  static const Color _kEmptyInkBody = Color(0xFF64748B);

  static const FontWeight _kEmptyFwTitle = FontWeight.w700;

  // ── دوگمەی CTA — هەمان «ئامرازی نوێ +»ی tools ────────────────────────────
  // ⚠ پێشتر مستطیلێکی شینی پان بوو بە «گلۆ»ی شین لە ژێری. ئێستا کەپسولێکی
  // تۆخی بچووکە کە پانییەکەی لە ناوەڕۆکەکەیەوە دێت — دەقاودەق ئەو
  // کۆمپۆنێنتەی لە شاشەی ئامرازەکاندا هەیە.
  static const double _kEmptyBtnH      = 42.0;  // = tools `_NewToolPill`
  static const double _kEmptyBtnHMin   = 42.0;  // هێشتا ≥ 42 بۆ دەستلێدان
  static const double _kEmptyBtnPadH   = 18.0;  // = tools
  static const double _kEmptyFsBtn     = 13.0;  // = tools `_kFsAction`
  static const double _kEmptyBtnIcon   = 17.0;  // = tools
  static const double _kEmptyBtnIconGap = 7.0;  // = tools
  static const Color  _kEmptyBtnFill   = Color(0xFF0265FF);

  /// پێوەری دۆخی بەتاڵ — **نەک** `_responsiveScale`.
  ///
  /// `_responsiveScale` پانی تەواوی شاشە بەسەر 393 دادەبەشێت، بەڵام
  /// `home_screen.dart` پانی ناوەڕۆک (پانی شاشە − 32) بەسەر 398 دادەبەشێت.
  /// لەسەر مۆبایلێکی 390 dp ئەوە 0.992 بەرامبەر 0.899ە — واتە هەمان ژمارەی
  /// dp لە دوو شاشەکەدا ~10% جیاواز دەردەدەکەوت. ئەمە دەقاودەق فۆرمولەی
  /// داشبۆردە، بۆیە هەردوو دۆخی بەتاڵ لەسەر یەک ئامێر **یەک قەبارەی
  /// فیزیکییان** هەیە.
  double _emptyStateScale(BuildContext context) =>
      ((MediaQuery.sizeOf(context).width - 32) / 398.0)
          .clamp(_kScaleMin, _kScaleMax);

  Widget _buildEmpty() {
    // `s` هەمان پێوەری داشبۆردە (بڕوانە `_emptyStateScale`)، و **هەمان `s`**
    // بۆ دەقەکانیش بەکاردێت نەک `_typeScaleFor` — چونکە داشبۆرد وا دەکات،
    // و مەبەست ئەوەیە هەردوو دۆخی بەتاڵ تەواو یەک بن. لە 320 dpـیش
    // ناونیشانەکە 15.3 dp دەبێت، کە بەئاسانی دەخوێندرێتەوە.
    final double s = _emptyStateScale(context);
    final double horizontalInset = _kCampaignPageGutter;
    final double bottomInset = _dsScreenPad * s;
    // ناوچەی دەستلێدان هەرگیز لە 44 dp کەمتر نابێتەوە، تەنانەت لەسەر
    // مۆبایلە باریکەکانیش کە `s` لێیان کەمە.
    final double btnH = max(_kEmptyBtnHMin, _kEmptyBtnH * s);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight = constraints.maxHeight.isFinite
            ? max(0.0, constraints.maxHeight - bottomInset)
            : 460 * s;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            key: const PageStorageKey('empty_ads_state'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                horizontalInset, 0, horizontalInset, bottomInset),
            children: [
              SizedBox(
                height: availableHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ئارتوۆرکی سندوق + مێگافۆن — بڕوانە
                      // `_EmptyAdsIllustration` لە سەرەوەی فایلەکە.
                      _EmptyAdsIllustration(
                        scale: s,
                        semanticLabel: 'هێشتا هیچ ڕیکلامێک نییە!',
                      ),
                      SizedBox(height: _kEmptyArtGap * s),
                      Text(
                        'هێشتا هیچ ڕیکلامێک نییە!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _kAdCardFont,
                          fontSize: _kEmptyFsTitle * s,
                          fontWeight: _kEmptyFwTitle,
                          color: _kEmptyInkTitle,
                          height: _kEmptyLhTitle,
                        ),
                      ),
                      SizedBox(height: _kEmptyTitleGap * s),
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: _kEmptyBodyMax * s),
                        child: Text(
                          'کاتێک ڕیکلامێک تۆمار دەکەیت، لێرە دەردەکەوێت.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: _kAdCardFont,
                            fontSize: _kEmptyFsBody * s,
                            fontWeight: FontWeight.w400,
                            color: _kEmptyInkBody,
                            height: _kEmptyLhBody,
                          ),
                        ),
                      ),
                      SizedBox(height: _kEmptyBodyGap * s),
                      // ── CTA: کەپسولی تۆخ، دەقاودەق وەک «ئامرازی نوێ +» ──
                      // ⚠ چیتر مستطیلێکی شینی پان نییە. سێ شت گۆڕان:
                      //   • ڕوو  شینی #0365FF  →  تۆخی #0F172A
                      //   • شێوە پانی پڕ + «گلۆ»ی شین  →  کەپسولی بچووک
                      //     بەبێ هیچ سێبەرێک، پانی بە ناوەڕۆکەکەیەوە
                      //   • ناوەڕۆک تەنها دەق  →  دەق + ئایکۆنی «+»
                      //
                      // `MainAxisSize.min` واتە پانییەکەی لە ڕیزەکەیەوە
                      // دێت، نەک لە ستوونەکەوە — بۆیە `ConstrainedBox`ی
                      // پێشوو لابرا: هیچی نەدەکرد جگە لە سنووردارکردنی
                      // شتێک کە خۆی شرینک‌ڕاپ دەبێت.
                      _IosPressable(
                        semanticLabel: 'ڕیکلامێک بکە',
                        pressScale: _kPressScale,
                        pressOpacity: 1.0,
                        pressTint: _kPressTintOnBlue,
                        pressRadius: BorderRadius.circular(btnH / 2),
                        pressDuration: _kCardPressDur,
                        onTap: () => Navigator.push(
                          context,
                          ProxoPageRoute<String>(
                            builder: (_) => const AdCreateScreen(),
                          ),
                        ),
                        child: Container(
                          height: btnH,
                          padding: EdgeInsets.symmetric(
                              horizontal: _kEmptyBtnPadH * s),
                          decoration: BoxDecoration(
                            color: _kEmptyBtnFill,
                            borderRadius: BorderRadius.circular(btnH / 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'ڕیکلامێک بکە',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: _kAdCardFont,
                                  fontSize: _kEmptyFsBtn * s,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(width: _kEmptyBtnIconGap * s),
                              Icon(ProxoIcons.add,
                                  size: _kEmptyBtnIcon * s,
                                  color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoticeCard({
    required Color wellColor,
    required Color iconColor,
    required Color cardColor,
    required String title,
    required String body,
    required String action,
    required VoidCallback onAction,
    IconData? icon,
    CustomPainter? painter,
  }) {
    final double s = _responsiveScale(context);
    final _T t = _T.of(s);
    return ListView(
      // A scroll view rather than a Center, so the notice still reaches the
      // RefreshIndicator's pull gesture and never overflows on a short screen.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          _kCampaignPageGutter,
          _kCampaignListTop * _campaignScale(context),
          _kCampaignPageGutter,
          _dsScreenPad * s),
      children: [
        _DsCard(
          scale: s,
          color: cardColor,
          child: Row(children: [
            Container(
              width: _dsTile * s, height: _dsTile * s,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: wellColor, shape: BoxShape.circle),
              child: painter != null
                  ? CustomPaint(
                      size: Size(_dsTileIcon * s, _dsTileIcon * s),
                      painter: painter)
                  : Icon(icon, size: _dsTileIcon * s, color: iconColor),
            ),
            SizedBox(width: _dsTileGutter * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1,
                      overflow: TextOverflow.ellipsis, style: t.title),
                  SizedBox(height: _dsTitleGap * s),
                  Text(body, maxLines: 3,
                      overflow: TextOverflow.ellipsis, style: t.subtitle),
                ],
              ),
            ),
            SizedBox(width: _dsTrailGap * s),
            _DsPrimaryButton(scale: s, label: action, onTap: onAction),
          ]),
        ),
      ],
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// _AdCard — پرێمیەم کارتی ڕیکلام کە مەچی وێنەی ڕیفرنسە
// ─────────────────────────────────────────────────────────────────────────────

// ═════════════════════════════════════════════════════════════════════════════
// AD CARD v2 — تۆکنەکانی کارتی پوختی نوێ
// ═════════════════════════════════════════════════════════════════════════════
// کارتی پێشوو هەموو کەمپینەکەی هەڵدەگرت (بەروار، ڕۆژژمێر، باری بودجە،
// چوار مەتریک بە ئایکۆن و ڕێژەی گۆڕانەوە، دوو دوگمە). ئێستا کارتی لیست
// تەنها ئەوە پیشان دەدات کە بۆ ناسینەوەی ڕیکلامەکە پێویستە:
//
//   وێنۆچکە · ناوی ڕیکلام · #کۆد · دۆخ · سێ مەتریکی سەرەکی · «بینینی زیاتر»
//
// ⚠ هیچ داتایەک لادراوە: بەروار، بودجە، ئامانج، بینەر و هەموو ئەوانەی تر
// هێشتا لە داتابەیس و لە شاشەی «وردەکاری ڕیکلام»دان — تەنها لە کارتی
// لیستەکەدا نمایش ناکرێن.
//
// Keep the existing responsive geometry and type scales. Card text uses
// normal Rabar at its base size, without an additional Kurdish size bump.

// ── جیۆمیتری ────────────────────────────────────────────────────────────────
// Card-local geometry. The surrounding screen keeps its original tokens.
const double _kAdcCardRadius = 20.0;
const double _kAdcCardPad = 16.0;
const double _kAdcThumb = 78.0;
const double _kAdcThumbHeight = 104.0; // 3:4 portrait preview, cropped, never stretched.
const double _kAdcThumbRadius = 12.0;
const double _kAdcHeaderH = _kAdcThumbHeight;
const double _kAdcThumbGap = 12.0;
const double _kAdcRowGap = 16.0;
const double _kAdcTileRadius = 12.0;
const double _kAdcTilePadH = 8.0;
const double _kAdcTilePadV = 12.0;
const double _kAdcTileBorderW = 1.0; // Status notes only, never numeric tiles.
const double _kAdcMetricGap = 12.0;
const double _kAdcToggleGapTop = 12.0;
const double _kAdcToggleH = 40.0;
const double _kAdcToggleRadius = 12.0;
const double _kAdcToggleGap = 8.0;
const double _kAdcChevronW = 11.0;
const double _kAdcChevronH = 6.4;
const double _kAdcChevronStroke = 1.5;
const double _kAdcToggleIconWell = 20.0;
const double _kAdcStatTileH = 80.0;
// Preserve the existing label-slot geometry independently of text size.
// This is a layout measurement, not a font-size adjustment.
const double _kAdcMetricLabelSlotBase = 11.66;
const double _kAdcBudgetGapTop = 12.0;
const double _kAdcBudgetBarH = 3.5;
// Existing update-request banner colours remain unchanged.
const Color _kAdcTileBg = Color(0xFFE4EBF7);
const Color _kAdcTileBorder = Color(0xFFEDF1F6);
const Color _kAdcInk = Color(0xFF172033);
const Color _kAdcLabelInk = Color(0xFF707987);
const Color _kAdcMutedInk = Color(0xFF808894);
const Color _kAdcToggleSurface = Color(0xFFF7F8FA);
const Color _kAdcToggleInk = Color(0xFF586579);
const Color _kAdcBudgetTrack = Color(0xFFE2E8F0);
const List<BoxShadow> _kAdcCardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x090F172A), blurRadius: 24, offset: Offset(0, 6)),
  BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
];
const List<BoxShadow> _kAdcMetricShadow = <BoxShadow>[
  BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 3)),
  BoxShadow(color: Color(0x040F172A), blurRadius: 3, offset: Offset(0, 1)),
];

// Both rows reserve the same two-line label slot. Extra text scaling grows
// every tile equally instead of clipping Kurdish labels or numeric values.
double _adcMetricHeight(BuildContext context, double scale) {
  final t = _typeScaleFor(scale);
  final scaler = MediaQuery.textScalerOf(context);
  final labelHeight = scaler.scale(_kAdcMetricLabelSlotBase * t) * 1.3 * 2;
  final valueHeight = scaler.scale(_kAdcFsStatValue * t) * 1.25;
  return max(_kAdcStatTileH * scale,
      labelHeight + valueHeight + (2 * _kAdcTilePadV + 4) * scale);
}

Duration _adcMotionDuration(BuildContext context) =>
    MediaQuery.of(context).disableAnimations ? Duration.zero : _kAdcExpandDur;

// Shared card typography: normal Rabar, original base sizes, w400.
const double _kAdcFsTitle    = 16.0;
const double _kAdcFsStatValue= 16.0;
const double _kAdcFsToggle   = 12.2;
const double _kAdcFsSheetBody= 12.8; // دەقی ڕوونکردنەوە     (12.5–13.5)

// ── ئەنیمەیشنی کردنەوە/داخستن ───────────────────────────────────────────────
const Duration _kAdcExpandDur   = Duration(milliseconds: 240);
const Curve    _kAdcExpandCurve = Curves.easeInOutCubic;

// ── هاتنە ژوورەوەی لیست (تەنها لە گۆڕینی فلتەردا) ─────────────────────────
// فەیدێکی زۆر کورت بەبێ سلاید و stagger؛ بۆیە لیست نابازێت و هەموو
// کارتەکان یەککات دەردەکەون.
const int _kAdcEnterStaggerMs = 0;
const int _kAdcEnterDurMs     = 140;
const int _kAdcEnterMaxSlot   = 0;
const int _kAdcEnterTotalMs   =
    _kAdcEnterDurMs + _kAdcEnterMaxSlot * _kAdcEnterStaggerMs;
const Duration _kAdcEnterTotal = Duration(milliseconds: _kAdcEnterTotalMs);

/// پەیامی کۆپیکردن — یەک شوێن، بۆیە کارت و شاشەی وردەکاری هەرگیز
/// دوو پەیامی جیاوازیان نییە.
const String _kAdcCopiedMsg = 'بەسەرکەوتوویی کۆپی کرا';

// ═════════════════════════════════════════════════════════════════════════════
// داواکاری دەستکاری (ئادمین → بەکارهێنەر) — کۆنتراتی `pa_ads`
// ═════════════════════════════════════════════════════════════════════════════
// ئەم بەشە **دەقاودەق** بەدوای ئەو خانانەدا دەڕوات کە پانێڵی وێب
// (`ProxoPanel`, `confirmAdUpdateRequest`) دەینووسێت. هیچ خانەیەکی نوێ
// دروست نەکراوە:
//
//   ئادمین داوا دەکات →  needs_update = true
//                        update_field = 'video_code' | 'video_link' | …
//                        update_reason = تێبینی بە کوردی
//                        update_requested_at = now
//                        update_submitted_at = null
//
//   بەکارهێنەر دەینێرێتەوە →  <update_field> = بەهای نوێ
//                             update_submitted_at = now
//                             status = 'review'
//                             updated_at = now
//
//   ئادمین پەسەندی دەکات →  هەر پێنج خانەکە پاک دەکرێنەوە
//
// ⚠ **`needs_update` بە `true` دەمێنێتەوە** دوای ناردنەوە. لە پانێڵەکەدا
// `_fmtAdUpdateBox` یەکەم شت `if(!a?.needs_update) return ''` دەکات —
// بۆیە ئەگەر ئێمە لێرەدا `false`ی بکەین، داواکارییەکە بە تەواوی لە
// چاوی ئادمین ون دەبێت و هەرگیز «جێبەجێ کرا» نابینێت. ئەوەی دۆخەکە
// دەگۆڕێت تەنها `update_submitted_at`ە: `null` = چاوەڕوانی بەکارهێنەر،
// دانراو = «وەڵامی هات» + بەها نوێیەکە + دوگمەی پەسەندکردن.
const String _kAdcColNeedsUpdate  = 'needs_update';
const String _kAdcColUpdateField  = 'update_field';
const String _kAdcColUpdateReason = 'update_reason';
const String _kAdcColSubmittedAt  = 'update_submitted_at';

/// دۆخی «چاوەڕوانی پێداچوونەوە» لە داتابەیسدا `'review'`ە، نەک
/// `'pending_review'` — پانێڵەکە بەم بەهایە پاڵاوتن دەکات
/// (`.eq('status','review')`) و ڕیزی پەسەندکردنی خۆی لەسەری بنیات
/// دەنێت (`.in('status',['pending','review'])`).
const String _kAdcStatusReview = 'review';

/// ناوی کوردی هەر خانەیەک — هەمان `AD_UPDATE_FIELDS`ی پانێڵەکە.
const Map<String, String> _kAdcFieldLabels = <String, String>{
  'video_code': 'کۆدی ڤیدیۆ',
  'video_link': 'لینکی ڤیدیۆ',
  'title': 'ناونیشانی ڕیکلام',
  'goal': 'ئامانجی ڕیکلام',
  'gender': 'ڕەگەز',
  'location': 'شوێن',
  'start_date': 'ڕێکەوتی دەستپێکردن',
  'start_time': 'کاتی دەستپێکردن',
};

/// خانە هەڵبژاردەییەکان و بەها ڕێگەپێدراوەکانیان. بەهاکان **دەقاودەق**
/// ئەوانەن کە پانێڵەکە دەیانخوێنێتەوە (`goalKu`, `_genderLabel`,
/// `_locationLabel`) — بۆیە هیچ بەهایەکی نوێ ناچێتە ناو داتابەیسەوە.
const Map<String, List<(String, String)>> _kAdcFieldChoices =
    <String, List<(String, String)>>{
  'goal': [
    ('messages', 'نامە'),
    ('engagement', 'کارلێک'),
    ('views', 'بینین'),
  ],
  'gender': [
    ('all', 'هەمووان'),
    ('male', 'نێر'),
    ('female', 'مێ'),
  ],
  'location': [
    ('all', 'هەمووان'),
    ('kurdistan', 'کوردستان'),
    ('iraq', 'عێراق'),
  ],
};

/// ئایا ئەم ڕیکلامە چاوەڕێی دەستکاری بەکارهێنەرە؟
bool _adcNeedsFix(Map<String, dynamic> ad) =>
    ad[_kAdcColNeedsUpdate] == true &&
    (ad[_kAdcColSubmittedAt] == null ||
        ad[_kAdcColSubmittedAt].toString().isEmpty);

/// ئایا بەکارهێنەر دەستکارییەکەی ناردووە و چاوەڕێی ئادمینە؟
bool _adcFixSubmitted(Map<String, dynamic> ad) =>
    ad[_kAdcColNeedsUpdate] == true &&
    ad[_kAdcColSubmittedAt] != null &&
    ad[_kAdcColSubmittedAt].toString().isNotEmpty;

// ── ڕەنگی ئاگاداری — کارت و شاشەی وردەکاری هەردووکیان یەک تۆنیان هەیە ──
const Color _kAdcFixInk    = Color(0xFFB45309); // کەهرەبایی تۆخ — دەق
const Color _kAdcFixBg     = Color(0xFFFFF8EC); // ڕووی زۆر سووک
const Color _kAdcFixBorder = Color(0xFFF3DDB4);
const Color _kAdcFixWell   = Color(0xFFFDECC8); // خانەی ئایکۆن

const String _kAdcFixTitle  = 'داواکاری دەستکاری';
const String _kAdcFixCta    = 'دەستکاریکردن';
const String _kAdcFixSent   = 'نێردرا — چاوەڕوانی پێداچوونەوەی ئادمین';
const String _kAdcFixSave   = 'پاشەکەوتکردن و ناردنەوە';
const String _kAdcFixOkMsg  =
    'زانیارییەکان نوێکرانەوە و ڕیکلامەکە کەوتە دۆخی چاوەڕوانی';

// ── دەقەکان ─────────────────────────────────────────────────────────────────
const String _kAdcDash = '—';

const String _kAdcLblImpressions = 'بینینەکان';
const String _kAdcLblClicks      = 'کرتەکان';
const String _kAdcLblSpend       = 'تێچوو';
const String _kAdcLblCpc         = 'تێچووی کرتە';
const String _kAdcLblCtr         = 'ڕێژەی کرتە';
const String _kAdcLblConversions = 'کرداری سەرکەوتوو';
const String _kAdcSeeMore        = 'بینینی زیاتر';
const String _kAdcSeeLess        = 'بینینی کەمتر';

const String _kAdcInfoCpc =
    'تێچووی خەمڵێنراو بۆ هەر یەک کرتە (کلیک) کە لەسەر ڕیکلامەکە کراوە.';
const String _kAdcInfoCtr =
    'ڕێژەی سەدیی ئەو کەسانەی ڕیکلامەکەیان بینیوە و کرتەیان لەسەر کردووە.';
const String _kAdcInfoConversions =
    'کۆی ژمارەی ئەو کردارانەی کە بەکارهێنەران دوای کرتەکردن '
    'بە سەرکەوتووییان تەواو کردووە، وەک کڕین یان ناونووسین.';

// ── فۆرماتکردن — `null` هەمیشە دەبێتە «—»، هەرگیز ژمارەیەکی ساختە ──────────
String _adcInt(int? v) => v == null ? _kAdcDash : _thousands(v);

/// دراو: هەمان دراوەی داتاکە — `spend` لە `pa_ads`دا بە دۆلار هەڵدەگیرێت،
/// بۆیە هەمان `\$…` ی کارتی پێشوو و شاشەی وردەکاری بەکاردێت.
String _adcMoney(double? v) =>
    v == null ? _kAdcDash : '\$${v.toStringAsFixed(2)}';

String _adcPct(double? v) =>
    v == null ? _kAdcDash : '${v.toStringAsFixed(1)}%';

class _AdCard extends StatefulWidget {
  final Map<String, dynamic> ad;
  final bool isHighlighted;
  final VoidCallback onTap;
  final void Function(String text)? onCopyId;
  final VoidCallback? onFeedback;

  /// شیتی دەستکاری دەکاتەوە کاتێک ئادمین داوای ڕاستکردنەوەی کردووە.
  /// وەک هەموو نووسینەکانی تر، خودی کردارەکە لە `_AdScreenState`دایە.
  final VoidCallback? onFix;

  const _AdCard({
    required this.ad,
    required this.isHighlighted,
    required this.onTap,
    this.onCopyId,
    this.onFix,
    this.onFeedback,
  });

  static _StatusStyle _ss(String s) {
    switch (s.trim().toLowerCase()) {
      case 'active':
        return const _StatusStyle(
          'چالاک',
          Color(0xFF047857),
          Color(0xFFECFDF5),
          Color(0xFFA7F3D0),
        );
      case 'pending':
        return const _StatusStyle(
          'چاوەڕوان',
          Color(0xFFB45309),
          Color(0xFFFFFBEB),
          Color(0xFFFDE68A),
        );
      case 'scheduled':
        return const _StatusStyle(
          'خشتەکراو',
          Color(0xFF0369A1),
          Color(0xFFF0F9FF),
          Color(0xFFBAE6FD),
        );
      case 'rejected':
        return const _StatusStyle(
          'ڕەتکراوە',
          Color(0xFFB91C1C),
          Color(0xFFFEF2F2),
          Color(0xFFFECACA),
        );
      case 'completed':
      case 'done':
        return const _StatusStyle(
          'تەواوبوو',
          Color(0xFF6D28D9),
          Color(0xFFF5F3FF),
          Color(0xFFDDD6FE),
        );
      case 'paused':
        return const _StatusStyle(
          'ڕاگیراوە',
          Color(0xFF475569),
          Color(0xFFF8FAFC),
          Color(0xFFCBD5E1),
        );
      case 'review':
        return const _StatusStyle(
          'پێداچوونەوە',
          Color(0xFF4338CA),
          Color(0xFFEEF2FF),
          Color(0xFFC7D2FE),
        );
      default:
        return const _StatusStyle(
          'نەزانراو',
          Color(0xFF64748B),
          Color(0xFFF8FAFC),
          Color(0xFFE2E8F0),
        );
    }
  }

  @override
  State<_AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<_AdCard> {
  /// دۆخی «بینینی زیاتر» — هەر کارتێک دۆخی سەربەخۆی خۆی هەیە، چونکە لێرە
  /// (لە state-ی کارتەکە خۆیدا) هەڵدەگیرێت و لیستەکە `ValueKey(ad['id'])`
  /// بەکاردێنێت، بۆیە فلتەرکردن/نوێکردنەوە دۆخەکە تێکەڵ ناکات.
  bool _expanded    = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  /// شیتی ڕوونکردنەوەی مەتریکەکان — هەمان `_FbSheetSurface` +
  /// `_IosSheetHeader`ی شیتەکانی تری ئەم شاشەیە، بۆیە هیچ ستایلێکی نوێ
  /// دروست نەکراوە و ڕەنگ/گۆشە/سێبەرەکەی یەکسانە لەگەڵ ئەپەکە.
  void _showMetricInfo({required String title, required String body}) {
    final double s = _campaignScale(context);
    final double t = _typeScaleFor(s);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _FbSheetSurface(
        scale: s,
        children: [
          _IosSheetHeader(scale: s, title: title),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _kFbSheetGutter * s,
              0,
              _kFbSheetGutter * s,
              22 * s,
            ),
            child: Text(
              body,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: _kAdCardFont,
                fontSize: _kAdcFsSheetBody * t * _kAdCardKuBump,
                fontWeight: FontWeight.w400,
                color: _kCampaignSubtle,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════════════════════
    // داتا — مەتریکەکان، وێنۆچکە و دۆخی فیدباک هەموویان لە هەمان ڕیزی
    // `pa_ads`ەوە دێن؛ هیچ fetchێکی ناو خودی کارت نییە.
    // ═══════════════════════════════════════════════════════════════════════
    final status =
        (widget.ad['status'] ?? '').toString().trim().toLowerCase();
    final ss = _AdCard._ss(status);
    final id = (widget.ad['id'] ?? '').toString();
    final title = (widget.ad['title'] ?? _kAdcDash).toString();
    final tiktokAdId = widget.ad['tiktok_ad_id']?.toString();
    final adNumber = widget.ad['ad_number']?.toString();
    final displayId = (adNumber != null && adNumber.trim().isNotEmpty)
        ? adNumber.trim()
        : id;
    final thumbnailUrl = widget.ad['thumbnail_url']?.toString();
    final int? feedbackRating =
        _asNum(widget.ad['feedback_rating'])?.toInt();
    final bool isCompleted = status == 'completed' || status == 'done';

    final isTerminal = status == 'rejected' ||
        status == 'completed' ||
        status == 'paused' ||
        status == 'done';
    final isActive =
        !isTerminal && (tiktokAdId != null && tiktokAdId.isNotEmpty);
    final hasRealData = isActive || isTerminal;

    final prevSpend = _asNum(widget.ad['prev_spend'])?.toDouble() ?? 0;
    final curSpend = _asNum(widget.ad['spend'])?.toDouble() ?? 0;
    final prevImpr = _asNum(widget.ad['prev_impressions'])?.toInt() ?? 0;
    final curImpr = _asNum(widget.ad['impressions'])?.toInt() ?? 0;

    // ⚠ `null` = هێشتا خزمەت نەکراوە/داتای ڕاستەقینەی نییە → «—».
    // پێشتر لەو حاڵەتەدا سفر نمایش دەکرا؛ سفری ساختە لابرا.
    final double? spend = hasRealData ? (prevSpend + curSpend) : null;
    final int? clicks =
        hasRealData ? (_asNum(widget.ad['clicks'])?.toInt() ?? 0) : null;
    final int? impressions = hasRealData ? (prevImpr + curImpr) : null;
    final int? conversions =
        hasRealData ? _asNum(widget.ad['conversions'])?.toInt() : null;
    final double? totalBudget =
        _asNum(widget.ad['total_budget'])?.toDouble() ??
            _asNum(widget.ad['budget'])?.toDouble();
    final double? budgetProgress = status == 'active' &&
            spend != null &&
            totalBudget != null &&
            totalBudget > 0
        ? (spend / totalBudget).clamp(0.0, 1.0).toDouble()
        : null;

    // ── ژمێرەرەکانی بەشی کراوە ────────────────────────────────────────────
    // CPC و CTR ژمێردراون؛ conversions ڕاستەوخۆ لە خانە ڕاستەقینەکەوە
    // دێت. هەموویان لە `null` و دابەشکردن بەسەر سفردا پارێزراون.
    final double? cpc =
        (spend != null && clicks != null && clicks > 0) ? spend / clicks : null;
    final double? ctr = (clicks != null && impressions != null && impressions > 0)
        ? (clicks / impressions) * 100
        : null;
    // ── ڕەمپەکان ──────────────────────────────────────────────────────────
    final double rs = _campaignScale(context);
    final double rt = _typeScaleFor(rs);
    double s(double value) => value * rs;
    double ts(double value) => value * rt;

    final double metricHeight = _adcMetricHeight(context, rs);
    const Color cardBackground = Colors.white;
    final List<BoxShadow> cardShadow = widget.isHighlighted
        ? [
            BoxShadow(
              color: _kCampaignBlue.withOpacity(0.14),
              blurRadius: s(24),
              offset: Offset(0, s(8)),
            ),
            const BoxShadow(
              color: Color(0x081F2944),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ]
        : _kAdcCardShadow;

    // ── ناسنامەی ڕیکلام ───────────────────────────────────────────────────
    // بێ هیچ لەیبڵێک، تەنها '#' + کۆدەکە. ئەگەر بەهاکەی داتابەیس خۆی
    // '#'ی هەبێت، دووەمی زیاد ناکرێت. بەهای ناو Supabase هەرگیز ناگۆڕێت —
    // ئەمە تەنها نمایشە.
    final String rawId = displayId.trim();
    final String idText = rawId.isEmpty
        ? _kAdcDash
        : (rawId.startsWith('#') ? rawId : '#$rawId');

    // ── سەرپەڕە: وێنۆچکە · ناو · #کۆد · دۆخ ───────────────────────────────
    // بەرزایی کەمینە = خانەی وێنۆچکە، بۆیە سەری هەموو کارتەکان یەک ئاستە
    // تەنانەت ئەگەر پیتەی دۆخێک کورت بێت.
    final Widget header = ConstrainedBox(
      constraints: BoxConstraints(minHeight: s(_kAdcThumbHeight)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AdcThumb(
            url: thumbnailUrl,
            width: s(_kAdcThumb),
            height: s(_kAdcThumbHeight),
            radius: s(_kAdcThumbRadius),
            // ⚠ تەنها کاتێک `id` هەیە. ئەگەر دوو ڕیکلامی بێ‌ناسنامە لە یەک
            // لیستدا بن، دوو Heroی هاوتاگ دروست دەبن و Flutter هەڵە
            // دەدات — بۆیە بێ‌ناسنامە هیچ تاگێکی نییە و نافڕێت.
            heroTag: id.isEmpty ? null : AdSurface.thumbHeroTag(id),
          ),
          SizedBox(width: s(_kAdcThumbGap)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _kAdCardFont,
                    fontSize: ts(_kAdcFsTitle),
                    fontWeight: FontWeight.w400,
                    color: _kAdcInk,
                    height: AdSurface.lineTitle,
                  ),
                ),
                SizedBox(height: s(_kCampaignTitleIdGap)),
                // کۆپیکردنی کۆد لەسەر تاپ — هەمان `onCopyId`ی پێشوو.
                // GestureDetector-ی ناوەوە تاپەکە دەبات، بۆیە ناڤیگەیشنی
                // کارتەکە کار ناکات (وەک پێشوو).
                _IosPressable(
                  semanticButton: widget.onCopyId != null,
                  semanticLabel: 'کۆپیکردنی ناسنامەی ڕیکلام',
                  pressScale: 1.0,
                  pressOpacity: 0.55,
                  onTap: widget.onCopyId == null
                      ? null
                      : () => widget.onCopyId!(displayId),
                  // ⚠ `TextDirection.ltr`: کارتەکە RTL-ە، بەڵام کۆدەکە
                  // لاتینە. بەبێ ئەمە '#' لە کۆتاییەوە دەردەکەوێت
                  // ("PLWMBEVKHYSE#"). لەبەر ئەوەی ستوونەکە
                  // `crossAxisAlignment.start`ە، بۆکسی دەقەکە خۆی لە
                  // لێواری ڕاست دادەنیشێت و تەنها ڕیزبەندی ناوەوەی LTR-ە.
                  child: Text(
                    idText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: _kAdCardNumFont,
                      fontSize: ts(_kCampaignFsId),
                      fontWeight: FontWeight.w400,
                      color: _kAdcMutedInk,
                      height: AdSurface.lineMeta,
                    ),
                  ),
                ),
                SizedBox(height: s(8)),
                _CampaignStatusBadge(
                  scale: rs,
                  color: ss.color,
                  bg: ss.bg,
                  border: ss.border,
                  label: ss.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ── بانەری داواکاری دەستکاری ──────────────────────────────────────────
    // تەنها کاتێک دەردەکەوێت کە ئادمین داوای گۆڕانکاری کردبێت. دوای
    // ناردنەوە، هەمان شوێن دەبێتە دەقێکی هێمن — بۆیە بەکارهێنەر دەزانێت
    // وەڵامەکەی نێردراوە و پێویست ناکات دووبارە بینێرێت.
    final bool needsFix = _adcNeedsFix(widget.ad);
    final bool fixSent = _adcFixSubmitted(widget.ad);
    final String fixReason =
        (widget.ad[_kAdcColUpdateReason] ?? '').toString().trim();
    final String fixField =
        (widget.ad[_kAdcColUpdateField] ?? '').toString().trim();

    final Widget? fixBanner = (needsFix || fixSent)
        ? Padding(
            padding: EdgeInsets.only(top: s(_kAdcRowGap)),
            child: _AdcFixBanner(
              scale: rs,
              reason: fixReason,
              fieldLabel: _kAdcFieldLabels[fixField] ?? fixField,
              submitted: fixSent,
              onFix: needsFix ? widget.onFix : null,
            ),
          )
        : null;

    final String rejectReason =
        (widget.ad['reject_reason'] ?? '').toString().trim();
    final Widget? rejectionNote = status == 'rejected' && rejectReason.isNotEmpty
        ? Padding(
            padding: EdgeInsets.only(top: s(_kAdcRowGap)),
            child: _AdcStatusNote(
              scale: rs,
              title: 'هۆکاری ڕەتکردنەوە',
              body: rejectReason.startsWith('🔴 ')
                  ? rejectReason.substring(3)
                  : rejectReason,
              ink: ss.color,
              surface: ss.bg,
              border: ss.border,
            ),
          )
        : null;

    // Primary metrics: individual white tiles with identical geometry.
    Widget statTile(
      String label,
      double? amount,
      String Function(double) format,
    ) =>
        _AdcStatTile(
          scale: rs,
          label: label,
          amount: amount,
          format: format,
        );

    final Widget primaryStats = SizedBox(
      height: metricHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: statTile(
              _kAdcLblImpressions,
              impressions?.toDouble(),
              (double v) => _adcInt(v.round()),
            ),
          ),
          SizedBox(width: s(_kAdcMetricGap)),
          Expanded(
            child: statTile(
              _kAdcLblClicks,
              clicks?.toDouble(),
              (double v) => _adcInt(v.round()),
            ),
          ),
          SizedBox(width: s(_kAdcMetricGap)),
          Expanded(
            child: statTile(
              _kAdcLblSpend,
              spend,
              _adcMoney,
            ),
          ),
        ],
      ),
    );

    final Widget? budgetProgressBar = budgetProgress == null
        ? null
        : _AdcBudgetProgress(scale: rs, progress: budgetProgress);

    // Expanded metrics continue the same geometry and typography.
    Widget expTile(
      String label,
      String value,
      String info,
    ) =>
        _AdcExpandedStatTile(
          scale: rs,
          label: label,
          value: value,
          onInfo: () => _showMetricInfo(title: label, body: info),
        );

    final Widget expandedStats = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: s(16)),
          child: const Divider(height: 1, thickness: 0.5, color: Color(0xFFEBEDF0)),
        ),
        SizedBox(
          height: metricHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: expTile(
                  _kAdcLblCpc,
                  _adcMoney(cpc),
                  _kAdcInfoCpc,
                ),
              ),
              SizedBox(width: s(_kAdcMetricGap)),
              Expanded(
                child: expTile(
                  _kAdcLblCtr,
                  _adcPct(ctr),
                  _kAdcInfoCtr,
                ),
              ),
              SizedBox(width: s(_kAdcMetricGap)),
              Expanded(
                child: expTile(
                  _kAdcLblConversions,
                  _adcInt(conversions),
                  _kAdcInfoConversions,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final Widget? feedbackTile = isCompleted
        ? CompletedAdFeedbackTile(
            scale: rs,
            rating: feedbackRating,
            onTap: feedbackRating == null ? widget.onFeedback : null,
          )
        : null;

    // ── ئاراستە: کارتەکە بە تەواوی RTL (شاشەکە خۆی LTR دەمێنێتەوە) ────────
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: s(_dsGapCard)),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: _kCampaignCardMaxWidth),
            // ── تاپی کارت — بێ ڕیپڵ، بێ چینی ئینک، بێ سکەیڵ ──────────
            // پێشتر لێرە `_AdCardLongPressRipple` بوو: بازنەیەکی شین کە
            // لە شوێنی پەنجەوە بەسەر هەموو کارتەکەدا گەشەی دەکرد. ئەو
            // «ئاوە»ی ئەندرۆیدە و لەگەڵ ڕەفتاری ڕاستەوخۆی ئەم شاشەیە
            // ناگونجێت — تاپ دەبێت دەستبەجێ شاشەکە بکاتەوە، نەک سەرەتا
            // ئەنیمەیشنێک بنوێنێت.
            //
            // `HitTestBehavior.opaque`: هەموو ڕووی کارتەکە یەک ئامانجی
            // لێدانە، تەنانەت بۆشاییەکانی نێوان مینی‌کارتەکانیش. هەر
            // کۆنترۆڵێکی ناوەوە (کۆدەکە، «بینینی زیاتر»، دوگمەکانی (?))
            // `GestureDetector`ی خۆی هەیە، و لە Flutter دا ناوەوەیی
            // ئارینای تاپ دەباتەوە — بۆیە هیچ کامیان ناڤیگەیشن ناکەنەوە.
            child: Semantics(
              button: true,
              label: 'ڕیکلام',
              child: _IosPressable(
                semanticButton: false,
                pressScale: 1.0,
                pressTint: _kPressTint,
                pressRadius: BorderRadius.circular(s(_kAdcCardRadius)),
                onTap: _kCardTapOpensDetails ? widget.onTap : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(s(_kAdcCardRadius)),
                    boxShadow: cardShadow,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      s(_kAdcCardPad),
                      s(_kAdcCardPad),
                      s(_kAdcCardPad),
                      s(_kAdcCardPad),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        header,
                        if (fixBanner != null) fixBanner,
                        if (rejectionNote != null) rejectionNote,
                        SizedBox(height: s(_kAdcRowGap)),
                        primaryStats,
                        if (budgetProgressBar != null) ...<Widget>[
                          SizedBox(height: s(_kAdcBudgetGapTop)),
                          budgetProgressBar,
                        ],
                        // کردنەوە/داخستنی ستوونی لە شوێنی خۆیدا: بەرزایی
                        // کارتەکە خۆی دەگۆڕێت، هیچ شاشە/دیالۆگێکی نوێ
                        // ناکرێتەوە. سنوور/گۆشە/ڕوو/سێبەری کارتەکە وەک
                        // خۆیان دەمێننەوە چونکە ئەنیمەیشنەکە لە ناوەوەیە.
                        // AnimatedCrossFade includes AnimatedSize, retaining
                        // the outgoing row during collapse as well as expansion.
                        AnimatedCrossFade(
                          duration: _adcMotionDuration(context),
                          sizeCurve: _kAdcExpandCurve,
                          firstCurve: Curves.easeInOut,
                          secondCurve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          crossFadeState: _expanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: ExcludeSemantics(
                            excluding: !_expanded,
                            child: IgnorePointer(
                              ignoring: !_expanded,
                              child: expandedStats,
                            ),
                          ),
                        ),
                        if (feedbackTile != null) ...<Widget>[
                          SizedBox(height: s(_kAdcToggleGapTop)),
                          feedbackTile,
                        ],
                        SizedBox(height: s(_kAdcToggleGapTop)),
                        _AdcExpandToggle(
                          scale: rs,
                          expanded: _expanded,
                          onTap: _toggleExpanded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AD CARD v2 — پێکهاتە نمایشییەکان
// ═════════════════════════════════════════════════════════════════════════════
// هەر چوارەکیان بێ‌دەوڵەتن (stateless) و تەنها لە `_AdCard`ەوە بانگ
// دەکرێن. هیچیان داتا ناخوێننەوە و هیچ ژمێرینێک ناکەن — تەنها ئەو
// سترینگانە وێنا دەکەن کە کارتەکە پێیان دەدات.

/// Resolve only recognised URL forms. Never interpret Base64 or a video link
/// as an image, and never discard a signed URL's token/query parameters.
Uri? _adcParseThumbnailUrl(String? raw, {Uri? storageOrigin}) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
       (value.startsWith("'") && value.endsWith("'")))) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.isEmpty || value.toLowerCase() == 'null' ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(value) ||
      RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value)) return null;
  value = value.replaceAll(r'\/', '/').replaceAll('&amp;', '&');
  if (value.contains(r'\')) return null;
  if (value.startsWith('//')) value = 'https:$value';
  if (value.startsWith('/storage/v1/') || value.startsWith('storage/v1/')) {
    if (storageOrigin == null) return null;
    value = storageOrigin.resolve(value.startsWith('/') ? value : '/$value').toString();
  } else if (value.startsWith('ad-thumbnails/')) {
    if (storageOrigin == null) return null;
    value = storageOrigin.resolve('/storage/v1/object/public/$value').toString();
  } else if (RegExp(r'^[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+(?:[:/]|$)').hasMatch(value)) {
    value = 'https://$value';
  }
  try {
    var uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        RegExp(r'[\s%]').hasMatch(uri.host) || uri.path.isEmpty || uri.path == '/') {
      return null;
    }
    // Supabase Cloud serves HTTPS. Keep self-hosted/external HTTP URLs intact
    // rather than silently changing a server's supported protocol.
    if (uri.scheme == 'http' &&
        (uri.host.endsWith('.supabase.co') || uri.host.endsWith('.supabase.in'))) {
      uri = uri.replace(scheme: 'https');
    }
    return uri;
  } on FormatException {
    return null;
  }
}

Uri? _adcThumbnailUri(String? raw) {
  // Absolute network URLs do not depend on initialising the storage client.
  final absolute = _adcParseThumbnailUrl(raw);
  if (absolute != null) return absolute;
  try {
    final origin = Uri.parse(supabase.storage.from('ad-thumbnails').getPublicUrl(''));
    return _adcParseThumbnailUrl(raw, storageOrigin: origin);
  } catch (_) {
    return null;
  }
}

/// Thumbnail failures are local to this widget. A single bounded recovery
/// clears a stale cache entry, then uses Flutter's direct network loader.
/// Public storage recovery gets a fresh cacheNonce; signed/authenticated
/// storage recovery requests a fresh URL using existing user permissions.
/// Bucket visibility and RLS are never changed, and URLs/tokens aren't logged.
class _AdcThumb extends StatefulWidget {
  final String? url;
  final double width;
  final double height;
  final double radius;
  final String? heroTag;

  const _AdcThumb({
    required this.url,
    required this.width,
    required this.height,
    required this.radius,
    this.heroTag,
  });

  @override
  State<_AdcThumb> createState() => _AdcThumbState();
}

class _AdcThumbState extends State<_AdcThumb> {
  String? _imageUrl;
  int _generation = 0;
  int _attempt = 0;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    _resetSource();
  }

  void _resetSource() {
    _generation++;
    _attempt = 0;
    _recovering = false;
    _imageUrl = _adcThumbnailUri(widget.url)?.toString();
  }

  @override
  void didUpdateWidget(covariant _AdcThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resetSource();
  }

  /// Only recognise object endpoints belonging to the configured project.
  /// This prevents an external URL from triggering credentialed operations.
  (String, String)? _ownStorageObject(String url) {
    try {
      final uri = Uri.parse(url);
      final origin = Uri.parse(supabase.storage.from('ad-thumbnails').getPublicUrl(''));
      if (uri.origin != origin.origin) return null;
      final parts = uri.pathSegments;
      if (parts.length < 6 || parts[0] != 'storage' || parts[1] != 'v1' ||
          parts[2] != 'object' ||
          !['public', 'sign', 'authenticated'].contains(parts[3])) return null;
      final bucket = parts[4];
      final path = parts.skip(5).join('/');
      if (bucket.isEmpty || path.isEmpty || parts.contains('..')) return null;
      return (bucket, path);
    } catch (_) {
      return null;
    }
  }

  void _debugImageError(String stage, String url, Object error) {
    assert(() {
      final uri = Uri.tryParse(url);
      final endpoint = uri == null ? '[invalid URL]' : '${uri.origin}${uri.path}';
      // Keep HTTP/decoder/filesystem details without logging signed tokens.
      final message = error.toString().replaceAll(
        RegExp(r'https?://[^\s]+'), '[image URL]',
      );
      debugPrint('AdScreen thumbnail [$stage] $endpoint '
          '${error.runtimeType}: $message');
      return true;
    }());
  }

  Future<void> _recover(String url, int generation, Object error) async {
    if (!mounted || generation != _generation || _imageUrl != url ||
        _attempt != 0 || _recovering) return;
    // Called after the frame, never setState during an image error builder.
    setState(() => _recovering = true);
    _debugImageError('cached load failed; direct retry', url, error);
    try {
      await CachedNetworkImage.evictFromCache(url).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Disk eviction failure must not cause an unhandled async exception.
    }
    if (!mounted || generation != _generation) return;
    String nextUrl = url;
    final object = _ownStorageObject(url);
    if (object != null) {
      final uri = Uri.parse(url);
      if (uri.pathSegments[3] == 'public') {
        // Public images require no signing request/SELECT permission. Change
        // the cache key only after a failure, never on each build or scroll.
        final query = Map<String, dynamic>.from(uri.queryParametersAll);
        query['cacheNonce'] = DateTime.now().microsecondsSinceEpoch.toString();
        nextUrl = uri.replace(queryParameters: query).toString();
      } else {
        try {
          final signed = await supabase.storage.from(object.$1)
              .createSignedUrl(object.$2, 3600)
              .timeout(const Duration(seconds: 8));
          final validated = _adcParseThumbnailUrl(signed);
          if (validated != null) nextUrl = validated.toString();
        } catch (signingError) {
          _debugImageError('signed URL recovery failed', url, signingError);
          // If signing is denied/offline, try the original URL once.
        }
      }
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _imageUrl = nextUrl;
      _attempt = 1;
      _recovering = false;
    });
  }

  Widget _placeholder({bool loading = false, bool retry = false}) {
    final Widget artwork = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF4F6FA), Color(0xFFE9EDF4)],
        ),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: Color(0xCCFFFFFF), shape: BoxShape.circle),
          child: Icon(retry ? Icons.refresh_rounded : Icons.play_arrow_rounded,
              size: 20, color: const Color(0xFF8A97AC)),
        ),
      ),
    );
    if (loading) {
      return Semantics(
        label: 'بارکردنی وێنۆچکە',
        child: MediaQuery.of(context).disableAnimations ? artwork : Shimmer.fromColors(
          baseColor: const Color(0xFFDDE3EC),
          highlightColor: const Color(0xFFF9FAFC),
          period: const Duration(milliseconds: 1400),
          child: artwork,
        ),
      );
    }
    const Widget fallback = _AdcProxoThumbFallback();
    return Semantics(
      label: retry ? 'دووبارە بارکردنی وێنۆچکە' : 'وێنۆچکە بەردەست نییە',
      button: retry,
      child: retry ? GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(_resetSource),
        child: fallback,
      ) : fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl;
    final generation = _generation;
    Widget inner;
    if (url == null) {
      inner = _placeholder();
    } else if (_recovering) {
      inner = _placeholder(loading: true);
    } else if (_attempt > 0) {
      // A different provider avoids flutter_cache_manager's disk files and
      // conditional-request metadata on this one recovery attempt. Flutter
      // still has its normal in-memory image cache; this is not cache-free.
      inner = Image.network(
        url,
        key: ValueKey('direct:$url:$generation'),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        cacheHeight: (widget.height * MediaQuery.devicePixelRatioOf(context))
            .ceil().clamp(64, 1024).toInt(),
        frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
            wasSynchronouslyLoaded || frame != null
                ? child : _placeholder(loading: true),
        errorBuilder: (_, error, __) {
          _debugImageError('direct retry failed', url, error);
          return _placeholder(retry: true);
        },
      );
    } else {
      // One decode dimension preserves the original image's aspect ratio.
      // BoxFit.cover performs the final portrait crop at paint time.
      final int pixels = (widget.height * MediaQuery.devicePixelRatioOf(context))
          .ceil().clamp(64, 1024).toInt();
      inner = CachedNetworkImage(
        key: ValueKey('$url:$generation:$_attempt'),
        imageUrl: url,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        memCacheHeight: pixels,
        fadeInDuration: MediaQuery.of(context).disableAnimations
            ? Duration.zero : const Duration(milliseconds: 160),
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, __) => _placeholder(loading: true),
        errorWidget: (_, failedUrl, error) {
          if (_attempt == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_recover(failedUrl, generation, error));
            });
            return _placeholder(loading: true);
          }
          // Includes failed network responses and unsupported/corrupt images.
          return _placeholder(retry: true);
        },
      );
    }
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(width: widget.width, height: widget.height, child: inner),
    );
    final Widget body = AdSurface.heroThumbnail && widget.heroTag != null
        ? Hero(
            tag: widget.heroTag!,
            transitionOnUserGestures: true,
            createRectTween: AdSurface.thumbRectTween,
            flightShuttleBuilder: (_, __, ___, ____, _____) => Material(
              type: MaterialType.transparency, child: clipped),
            child: clipped,
          )
        : clipped;
    return RepaintBoundary(child: body);
  }
}


/// Branded fallback only: inherits the real thumbnail's tight dimensions and
/// rounded clip from _AdcThumb. No independent aspect ratio, padding or motion.
class _AdcProxoThumbFallback extends StatelessWidget {
  const _AdcProxoThumbFallback();

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
    child: CustomPaint(
      painter: _AdcProxoPatternPainter(),
      child: SizedBox.expand(),
    ),
  );
}

/// Paint one laid-out word eighteen times, in six gently staggered rows.
/// All positions and type sizes are proportional to the available thumbnail.
class _AdcProxoPatternPainter extends CustomPainter {
  const _AdcProxoPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFBFDFF),
    );

    const int columns = 3;
    const int rows = 6;
    final double cellWidth = size.width / columns;
    final double cellHeight = size.height / rows;
    final word = TextPainter(
      text: TextSpan(
        text: 'Proxo',
        style: TextStyle(
          fontFamily: _kAdCardNumFont,
          fontSize: size.width * 0.105,
          fontWeight: FontWeight.w400,
          // #046CFA at 12.2% opacity; the background stays almost white.
          color: const Color(0x1F046CFA),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    // Fit uniformly inside each cell, preserving letter proportions and a
    // clear gutter even if the app's font changes in a later release.
    final double wordScale = min(
      1.0,
      min(cellWidth * 0.72 / max(word.width, 1.0),
          cellHeight * 0.60 / max(word.height, 1.0)),
    );
    for (int row = 0; row < rows; row++) {
      final double stagger = (row.isOdd ? 0.025 : -0.025) * size.width;
      for (int column = 0; column < columns; column++) {
        final double x = (column + 0.5) * cellWidth + stagger;
        // Slightly inset the outer rows so complete words clear the corners.
        final double y = (row + 0.75) * size.height / (rows + 0.5);
        canvas.save();
        canvas.translate(x - word.width * wordScale / 2,
            y - word.height * wordScale / 2);
        canvas.scale(wordScale);
        word.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
    word.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AdcProxoPatternPainter oldDelegate) => false;
}


/// تێبینییەکی کورت و بێ ئایکۆن بۆ دۆخە گرنگەکان، وەک هۆکاری
/// ڕەتکردنەوە. ڕەنگەکانی لە هەمان status badge ـەوە وەردەگرێت.
class _AdcStatusNote extends StatelessWidget {
  final double scale;
  final String title;
  final String body;
  final Color ink;
  final Color surface;
  final Color border;

  const _AdcStatusNote({
    required this.scale,
    required this.title,
    required this.body,
    required this.ink,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double t = _typeScaleFor(scale);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11 * s, vertical: 9 * s),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12 * s),
        border: Border.all(color: border, width: _kAdcTileBorderW),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _kAdCardFont,
              fontSize: 10.7 * t,
              fontWeight: FontWeight.w400,
              color: ink,
              height: 1.30,
            ),
          ),
          SizedBox(height: 3 * s),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _kAdCardFont,
              fontSize: 10.5 * t,
              fontWeight: FontWeight.w400,
              color: _kAdcMutedInk,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// بانەری «ئادمین داوای دەستکاری کردووە».
///
/// یەک ویجێت بۆ هەردوو دۆخەکە، بۆیە کارت و شاشەی وردەکاری هەرگیز دوو
/// شێوازی جیاوازیان نییە:
///
///   • `submitted == false` → تۆنی کەهرەبایی + دوگمەی «دەستکاریکردن»
///   • `submitted == true`  → هەمان چوارچێوە، بەڵام بێ دوگمە و بە دەقی
///     «نێردرا»، چونکە هیچ کارێک نەماوە بۆ بەکارهێنەر
class _AdcFixBanner extends StatelessWidget {
  final double scale;
  final String reason;
  final String fieldLabel;
  final bool submitted;
  final VoidCallback? onFix;

  const _AdcFixBanner({
    required this.scale,
    required this.reason,
    required this.fieldLabel,
    required this.submitted,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double t = _typeScaleFor(scale);
    final Color ink = submitted ? _kCampaignSubtle : _kAdcFixInk;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11 * s, vertical: 10 * s),
      decoration: BoxDecoration(
        color: submitted ? _kAdcTileBg : _kAdcFixBg,
        borderRadius: BorderRadius.circular(_kAdcTileRadius * s),
        border: Border.all(
          color: submitted ? _kAdcTileBorder : _kAdcFixBorder,
          width: _kAdcTileBorderW,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22 * s,
            height: 22 * s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: submitted ? _kAdcTileBorder : _kAdcFixWell,
              shape: BoxShape.circle,
            ),
            child: Icon(
              submitted
                  ? ProxoIcons.success
                  : ProxoIcons.alert,
              size: 18 * s,
              color: ink,
            ),
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  submitted ? _kAdcFixSent : _kAdcFixTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _kAdCardFont,
                    fontSize: 10.6 * t,
                    fontWeight: FontWeight.w400,
                    color: ink,
                    height: 1.30,
                  ),
                ),
                if (!submitted && reason.isNotEmpty) ...[
                  SizedBox(height: 2 * s),
                  Text(
                    reason,
                    // دوو دێڕ بەسە بۆ تێبینییەکی وەک «کۆدی ڤیدیۆ
                    // نادروستە، تکایە چاکی بکە» — درێژتری لە شاشەی
                    // وردەکاریدا بە تەواوی دەردەکەوێت.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _kAdCardFont,
                      fontSize: 10.4 * t,
                      fontWeight: FontWeight.w400,
                      color: _kCampaignSubtle,
                      height: 1.50,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onFix != null) ...[
            SizedBox(width: 8 * s),
            // ⚠ کۆنترۆڵێکی ناوەوەی سەربەخۆ: تاپی ئەمە ناڤیگەیشنی
            // کارتەکە هەڵناسووڕێنێت، وەک کۆدەکە و «بینینی زیاتر».
            _IosPressable(
              semanticLabel: _kAdcFixCta,
              pressScale: 1.0,
              pressTint: _kPressTint,
              pressRadius: BorderRadius.circular(8 * s),
              onTap: onFix,
              onLongPress: () {},
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 10 * s, vertical: 6 * s),
                decoration: BoxDecoration(
                  color: _kAdcFixInk,
                  borderRadius: BorderRadius.circular(8 * s),
                ),
                child: Text(
                  _kAdcFixCta,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: _kAdCardFont,
                    fontSize: 10.6 * t,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// هاتنە ژوورەوەی یەک کارت: فەیدێکی کورت، بەبێ سلاید و دواخستن.
///
/// هیچ دۆخێکی خۆی نییە و هیچ کۆنترۆڵەرێک دروست ناکات — تەنها ئەو
/// ئەنیمەیشنە دەخوێنێتەوە کە شاشەکە خۆی هەڵیدەگرێت. کاتێک ئەنیمەیشنەکە
/// لە 1.0 وەستاوە (واتە زۆربەی کات)، منداڵەکە **بەبێ** هیچ چینێکی
/// `Opacity` یان `Transform` دەگەڕێنرێتەوە، بۆیە لیستێکی وەستاو
/// دەقاودەق هەمان نرخی وێناکردنی پێشووی هەیە.
class _AdcListEntrance extends StatelessWidget {
  final int index;
  final Animation<double> animation;
  final Widget child;

  const _AdcListEntrance({
    super.key,
    required this.index,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      // `child` لە دەرەوەی بیلدەرەکەیە: کارتەکە لە ماوەی ئەنیمەیشنەکەدا
      // **دووبارە بنیات نانرێتەوە**، تەنها چینی ڕوونی/جوڵەکەی دەگۆڕێت.
      child: child,
      builder: (BuildContext ctx, Widget? ch) {
        final double v = animation.value;
        if (v >= 1.0) return ch!;

        // پەنجەرەی ئەم کارتە لەناو تایم‌لاینی گشتیدا.
        final int slot = index < _kAdcEnterMaxSlot ? index : _kAdcEnterMaxSlot;
        final double start =
            (slot * _kAdcEnterStaggerMs) / _kAdcEnterTotalMs;
        final double span = _kAdcEnterDurMs / _kAdcEnterTotalMs;

        double p = (v - start) / span;
        if (p <= 0.0) p = 0.0;
        if (p >= 1.0) return ch!;

        final double e = Curves.easeOutCubic.transform(p);
        return Opacity(opacity: e, child: ch);
      },
    );
  }
}

/// نیشاندەری پوختی بودجە بۆ ڕیکلامی چالاک. لەناو کارتی سپی کارتێکی
/// دووەم دروست ناکات؛ تەنها لەیبڵێکی سووک و هێڵێکی 3.5dp ـە.
class _AdcBudgetProgress extends StatelessWidget {
  final double scale;
  final double progress;

  const _AdcBudgetProgress({required this.scale, required this.progress});

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double t = _typeScaleFor(scale);
    final double safe = progress.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'بەکارهێنانی بودجە',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _kAdCardFont,
                  fontSize: 10.5 * t,
                  fontWeight: FontWeight.w400,
                  color: _kAdcMutedInk,
                  height: AdSurface.lineTitle,
                ),
              ),
            ),
            SizedBox(width: 8 * s),
            Text(
              '${(safe * 100).round()}%',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: _kAdCardNumFont,
                fontSize: 10.5 * t,
                fontWeight: FontWeight.w400,
                color: _kAdcToggleInk,
                height: AdSurface.lineTitle,
              ),
            ),
          ],
        ),
        SizedBox(height: 5 * s),
        Container(
          height: _kAdcBudgetBarH * s,
          decoration: BoxDecoration(
            color: _kAdcBudgetTrack,
            borderRadius: BorderRadius.circular(_kAdcBudgetBarH * s),
          ),
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: safe,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _kCampaignBlue,
                borderRadius: BorderRadius.circular(_kAdcBudgetBarH * s),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// مینی‌کارتی مەتریکی سەرەکی — تەنها لەیبڵ و بەها، بێ ئایکۆن.
class _AdcStatTile extends StatelessWidget {
  final double scale;
  final String label;
  final double? amount;
  final String Function(double) format;

  const _AdcStatTile({
    required this.scale,
    required this.label,
    required this.amount,
    required this.format,
  });

  @override
  Widget build(BuildContext context) => _AdcMetricTile(
    scale: scale,
    label: label,
    value: amount == null ? _kAdcDash : format(amount!),
  );
}

class _AdcExpandedStatTile extends StatelessWidget {
  final double scale;
  final String label;
  final String value;
  final VoidCallback onInfo;

  const _AdcExpandedStatTile({
    required this.scale,
    required this.label,
    required this.value,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) => _IosPressable(
    semanticButton: true,
    semanticLabel: 'ڕوونکردنەوەی $label',
    pressScale: 1.0,
    pressTint: const Color(0x060F172A),
    pressRadius: BorderRadius.circular(_kAdcTileRadius * scale),
    onTap: onInfo,
    onLongPress: () {},
    child: _AdcMetricTile(scale: scale, label: label, value: value),
  );
}

/// A single geometry/type system for both rows. Labels reserve two lines so
/// short labels and wrapped Kurdish labels share exactly the same baseline.
class _AdcMetricTile extends StatelessWidget {
  final double scale;
  final String label;
  final String value;

  const _AdcMetricTile({
    required this.scale,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final double t = _typeScaleFor(scale);
    final double labelSize = 11.0 * t;
    final double labelHeight = MediaQuery.textScalerOf(context)
        .scale(_kAdcMetricLabelSlotBase * t) * 2.6;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _kAdcTilePadH * scale,
          vertical: _kAdcTilePadV * scale,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kAdcTileRadius * scale),
          boxShadow: _kAdcMetricShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _kAdCardFont,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w400,
                    color: _kAdcLabelInk,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4 * scale),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _kAdCardNumFont,
                  fontSize: _kAdcFsStatValue * t,
                  fontWeight: FontWeight.w400,
                  color: _kAdcInk,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// کۆنترۆڵی «بینینی زیاتر / بینینی کەمتر» + چیڤرۆنێک کە بە نەرمی
/// دەسووڕێتەوە. تاپی ئەمە هەرگیز ناڤیگەیشنی کارتەکە ناکاتەوە.
class _AdcExpandToggle extends StatelessWidget {
  final double scale;
  final bool expanded;
  final VoidCallback onTap;

  const _AdcExpandToggle({
    required this.scale,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double t = _typeScaleFor(scale);
    final String label = expanded ? _kAdcSeeLess : _kAdcSeeMore;
    return _IosPressable(
      semanticLabel: label,
      pressScale: 1.0,
      pressTint: _kFbPressed,
      pressRadius: BorderRadius.circular(_kAdcToggleRadius * s),
      onTap: onTap,
      onLongPress: () {},
      child: Container(
        constraints: BoxConstraints(
          minHeight: _kAdcToggleH,
        ),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
        decoration: BoxDecoration(
          color: _kAdcToggleSurface,
          borderRadius: BorderRadius.circular(_kAdcToggleRadius * s),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // بۆ هاوسەنگی ناوەندی دەق؛ هیچ ئایکۆنی ئامار لێرە نییە.
            SizedBox(width: _kAdcToggleIconWell * s),
            SizedBox(width: _kAdcToggleGap * s),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _kAdCardFont,
                    fontSize: _kAdcFsToggle * t,
                    fontWeight: FontWeight.w400,
                    color: _kAdcToggleInk,
                    height: AdSurface.lineTitle,
                  ),
                ),
              ),
            ),
            SizedBox(width: _kAdcToggleGap * s),
            Container(
              width: _kAdcToggleIconWell * s,
              height: _kAdcToggleIconWell * s,
              alignment: Alignment.center,
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0.0,
                duration: _adcMotionDuration(context),
                curve: _kAdcExpandCurve,
                child: CustomPaint(
                  size: Size(_kAdcChevronW * s, _kAdcChevronH * s),
                  painter: _SvgChevronDownIcon(
                    color: _kAdcToggleInk,
                    strokeWidth: _kAdcChevronStroke * s,
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

// ═════════════════════════════════════════════════════════════════════════════
// باری چیپی فلتەر — سکێلیتۆن + چیپ
// ═════════════════════════════════════════════════════════════════════════════
// ⚠ `_IosFilterPill` (دوو دوگمەی کردنەوەی شیت) و `_IosOptionSheet` لێرەوە
// لابران. ئەو نەخشەیە دوو کلیکی دەویست بۆ گۆڕینی یەک فلتەر — کلیکێک بۆ
// کردنەوەی شیتەکە و کلیکێک بۆ هەڵبژاردن — و دۆخی ئێستا تەنها لەناو
// لەیبڵێکی کورتکراوەدا دەردەکەوت. ئێستا هەشت دۆخەکە هەموویان بە یەک
// نیگا دیارن و گۆڕین یەک کلیکە.

/// یەک تابی دۆخ؛ کاردانەوەکە تەنها ڕەنگێکی زۆر سووکە، بەبێ سکەیڵ و ripple.
class _StatusChip extends StatefulWidget {
  final String label;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.scale,
    required this.onTap,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip> {
  bool _down = false;
  void _set(bool v) { if (_down != v && mounted) setState(() => _down = v); }

  @override
  Widget build(BuildContext context) {
    final double s = widget.scale;
    final double t = _typeScaleFor(s);
    final bool on = widget.selected;

    final Color ink  = on ? _kFbChipOnInk  : _kFbChipIdleInk;

    return Semantics(
      button: true,
      selected: on,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => _set(true),
        onTapUp:     (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _kFbPressDur,
          curve: Curves.easeOut,
          height: _kFbChipH * s,
          padding: EdgeInsets.symmetric(horizontal: _kFbChipPadH * s),
          decoration: BoxDecoration(
            color: _down ? _kFbPressed : Colors.transparent,
            borderRadius: BorderRadius.circular(_kFbChipRadius * s),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 2 * s),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: _kAdCardFont,
                    fontSize: _kFbChipFs * t,
                    fontWeight: FontWeight.w500,
                    color: ink,
                    height: 1.0,
                  ),
                ),
              ),
              PositionedDirectional(
                start: _kFbIndicatorInset * s,
                end: _kFbIndicatorInset * s,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: on ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  child: Container(
                    height: _kFbIndicatorH,
                    decoration: BoxDecoration(
                      color: _kFbChipOnInk,
                      borderRadius: BorderRadius.circular(_kFbIndicatorH),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _IosPressable — کاردانەوەی «کلیکی نەرم»ی iOS بۆ هەر شتێک
// ═════════════════════════════════════════════════════════════════════════════
// یەک شێواز بۆ هەموو شوێنێک: لە `onTapDown`ەوە دەستبەجێ سکەیڵ دەکاتەوە و
// کەمێک ڕەنگ لادەدات، لە 90ms، بەبێ چاوەڕوانی سەلماندنی تاپ. هیچ ripple-ێک
// نییە — ڕیپڵ زمانی ئەندرۆیدە. هەستی سەلێکشن لە کاتی تاپ، و هەستی
// mediumImpact لە کاتی کلیکی درێژ (وەک مینیوی سیاقی iOS).
class _IosPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  /// 1.0 = بێ سکەیڵ (تەنها ڕەنگ لادان) — بۆ ڕیزە بچووکەکان.
  final double pressScale;
  /// ڕێژەی ڕوونی لە کاتی داگرتن. کاتێک `pressTint` دراوە ئەمە دەکرێتە
  /// 1.0 — دوو کاردانەوە پێکەوە زۆرن.
  final double pressOpacity;

  /// چینی ڕەنگی داگرتن. `null` = ڕەفتاری کۆنی «ڕوونی کەمکردنەوە».
  /// بۆ ڕووە ڕووناکەکان `_kPressTint` و بۆ ڕووە شینەکان `_kPressTintOnBlue`.
  final Color? pressTint;

  /// گۆشەی خڕی چینەکە — دەبێت **دەقاودەق** هی کارتەکە بێت، بۆیە
  /// چینەکە لە دەرەوەی کارتەکە دەرناکەوێت. ئەگەر `pressTint` دابنرێت و
  /// ئەمە نا، چینەکە بە گۆشەی تەخت وێنا دەکرێت.
  final BorderRadius? pressRadius;

  /// ماوەی ئەنیمەیشن. بنەڕەت = 90ms (هی پیلەکان).
  final Duration pressDuration;

  final String? semanticLabel;
  final bool semanticButton;

  const _IosPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.97,
    this.pressOpacity = 0.90,
    this.pressTint,
    this.pressRadius,
    this.pressDuration = _kFbPressDur,
    this.semanticLabel,
    this.semanticButton = true,
  });

  @override
  State<_IosPressable> createState() => _IosPressableState();
}

class _IosPressableState extends State<_IosPressable> {
  bool _down = false;
  void _set(bool v) { if (_down != v && mounted) setState(() => _down = v); }

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  /// ناوەڕۆک + چینی داگرتن. چینەکە `Positioned.fill`ە بەسەر منداڵەکەدا،
  /// بۆیە دەقاودەق هەمان بۆکسی کارتەکە دەگرێتەوە، و بە هەمان
  /// `borderRadius`ەوە وێنا دەکرێت — واتە کلیپکراوە بۆ گۆشە خڕەکان بەبێ
  /// `ClipRRect` (کلیپ سێبەری کارتەکەی دەبڕی).
  ///
  /// `IgnorePointer`: چینەکە هەرگیز تاپ نابڕێت — هەموو کارتەکە یەکسان
  /// کاردانەوە دەنوێنێت، وەک پێشوو.
  Widget _withTint(Widget child) {
    final Color? tint = widget.pressTint;
    if (tint == null) {
      return AnimatedOpacity(
        opacity: _down ? widget.pressOpacity : 1.0,
        duration: widget.pressDuration,
        curve: Curves.easeOut,
        child: child,
      );
    }
    return Stack(
      // `passthrough`: ڕەهەندەکانی دایک بەبێ گۆڕان دەگاتە منداڵەکە، بۆیە
      // هیچ شتێکی لایەوت ناگۆڕێت (گرنگە بۆ ڕەهەندی جێگیری کارت).
      fit: StackFit.passthrough,
      // `Stack` بە بنەڕەت `Clip.hardEdge`ە. سێبەری کارتەکە لە دەرەوەی
      // بۆکسەکەی وێنا دەکرێت، بۆیە کلیپ ڕێگری لێدەکات — `none` دەیپارێزێت.
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: widget.pressDuration,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                // `tint.withAlpha(0)` نەک `transparent`: `Color.lerp`
                // RGB-یش تێکەڵ دەکات، بۆیە ئەگەر لە ڕەشی ڕوونەوە دەست
                // پێبکات تۆنەکە لە ناوەڕاستی ئەنیمەیشندا تاریکتر دەبێت.
                color: _down ? tint : tint.withAlpha(0),
                borderRadius: widget.pressRadius,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_interactive) return widget.child;
    return Semantics(
      button: widget.semanticButton,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => _set(true),
        onTapUp:     (_) => _set(false),
        onTapCancel: () => _set(false),
        // بێ هەزە: کاردانەوەکە تەنها بینراوە (سکەیڵ + ڕوونی). هیچ
        // لەرینەوەیەک نییە، نە لە تاپ و نە لە کلیکی درێژدا.
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _set(false);
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _down ? widget.pressScale : 1.0,
          duration: widget.pressDuration,
          curve: Curves.easeOut,
          child: _withTint(widget.child),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// چینی سکێلیتۆن — داپۆشەرێکی ڕەق لەسەر لیستەکە
// ═════════════════════════════════════════════════════════════════════════════
// ئەمە جێگای هەردوو `_SkeletonAdCard` و `_AdCardReveal`ی پێشوو دەگرێتەوە.
//
// بۆچی داپۆشەر و نەک لیستێکی جێگرەوە:
//   • هەرگیز پێویست ناکات لیستی ڕاستەقینە هەڵبوەشێنرێتەوە، بۆیە نە
//     `_scrollCtrl` دوو جار دەلکێت، نە `PageStorageKey` پێویستی بە
//     گەڕاندنەوەی ئۆفسێت دەبێت، نە بەرزایی گشتی دەگۆڕێت
//   • قەبارەکەی لە دایکەوە دێت (`Positioned.fill`)، بۆیە هاتن و چوونی
//     تەنها ڕوونی دەگۆڕێت — سفر لایەوت شیفت
//
// **`Shimmer` بۆ هەر کارتێک بە جیا، نەک یەک ماسک بۆ هەموو ستوونەکە.**
// یەک ماسکی گشتی ئەرزانتر بوو، بەڵام کێشەیەکی بنەڕەتی هەبوو: ماسکەکە
// `BlendMode.srcIn`ە، بۆیە ڕووی سپیی کارتەکانیشی ڕەنگ دەکرد و هەر کارتێک
// دەبووە یەک بلۆکی ڕەقی یەکڕەنگ — سکێلیتۆنە وردەکەی ناوەوەی بە تەواوی
// دەشاردەوە. ئێستا چوارچێوەی کارتەکە لە دەرەوەی ماسکەکەیە و ماسکەکە تەنها
// بەسەر شێوە جێگرەوەکاندا دەڕوات.
//
// نرخەکەی: `_skeletonOverlayCount` هەرگیز لە 4 تێناپەڕێت، بۆیە زۆرترین
// حاڵەت 4 `AnimationController`ی 1400ms-ە، و هەر ماسکێک تەنها بۆکسی
// ناوەڕۆکی یەک کارت دەگرێتەوە نەک هەموو پەڕەکە — واتە ڕووبەری گشتیی
// ماسککراو لەوەی پێشوو **کەمترە**. هەموویان لە یەک فرەیمدا دروست دەبن،
// بۆیە سوێپەکان هاوکاتن و بە چاو وەک یەک شەپۆل دەردەکەون.
class _SkeletonOverlay extends StatelessWidget {
  final int count;
  const _SkeletonOverlay({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final double s = _campaignScale(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRect(
        child: ColoredBox(
          // ڕەق، نەک شەفاف: کارتەکانی ژێرەوە دەبێت بە تەواوی بشاردرێنەوە،
          // ئەگەرنا لە ماوەی فەیدەکەدا هەردوو چینەکە پێکەوە دەبینرێن.
          color: _dsPageBg,
          // ⚠ هیچ `Shimmer`ێک لێرە نییە — بە ئەنقەست.
          //
          // `Shimmer` ماسکێکی `BlendMode.srcIn` بەکاردێنێت: هەموو پیکسلێکی
          // ڕەقی منداڵەکەی دەکات بە ڕەنگی گرادیێنتەکە. کاتێک هەموو لیستەکەی
          // دەگرتەوە، ڕووی سپیی کارتەکە خۆی (`_dsCard`) دەکەوتە ژێر ماسکەکە
          // و بە یەک بلۆکی ڕەق ڕەنگ دەکرا — بۆیە بارە جیاکانی ناوەوە بە
          // تەواوی ون دەبوون و هەر کارتێک وەک **یەک مستطیلی خڕی بەتاڵ**
          // دەردەکەوت. ئێستا هەر کارتێک shimmer-ی خۆی هەیە کە تەنها بەسەر
          // شێوە جێگرەوەکاندا دەڕوات، و ڕوو/سنوور/سێبەری کارتەکە لە دەرەوەی
          // ماسکەکە دەمێنێتەوە — بڕوانە `SkeletonCard`.
          child: SingleChildScrollView(
            // NeverScrollable: چینەکە ناسکڕۆڵێت — لیستی ژێرەوە
            // ئۆفسێتی خۆی هەڵدەگرێت. `SingleChildScrollView` تەنها
            // لەبەر ئەوە بەکاردێت کە ئەگەر ژمارەی کارتەکان لە
            // ویوپۆرت درێژتر بوو، بەبێ هێمای overflow دەیبڕێت.
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              _kCampaignPageGutter,
              _kCampaignListTop * s,
              _kCampaignPageGutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < count; i++) const SkeletonCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _IosOptionSheet — شیتی فلتەر بە ڕادیۆ (وەک ڕیفرنسی «Sort by»)
// ═════════════════════════════════════════════════════════════════════════════
// پێکهاتەی ڕیفرنسەکە بە تەواوی: پانی تەواو، تەنها گۆشەی سەرەوە خڕ،
// ناونیشانێکی ناوەڕاست و قەڵەو، دوگمەی ✕ لای کۆتایی (لە RTLدا لای چەپ)،
// و ڕیزەکان بە بۆشاییەکی فراوان — **بەبێ هیچ هێڵێکی جیاکەرەوە**.
// ڕادیۆکە: بازنەیەکی داپۆشراو کاتێک هەڵبژێردراوە، بازنەیەکی بەتاڵ ئەگەرنا.
// ── پێوانەکان لە خودی ڕیفرنسەکەوە هەڵهێنراون ───────────────────────────────
// وێنەکە 1080 px پانە = 393 dp لەسەر 2.75x. هەموو ژمارەکانی خوارەوە لەوێوە
// دەرهێنراون، نەک بە چاو:
//   ناونیشان: ناوەندی y = 32 dp لە سەرەوەی شیتەوە · کاپ 38 px → فۆنت 19.2
//   ڕیزەکان : ناوەندەکان 85.5 / 134.5 / 183.6 → پیچی 49.1 dp · کاپ 34 px → 17.2
//   لەیبڵ   : 16 dp لە لێوارەوە · ڕادیۆ و ✕: ناوەندیان 28 dp لە لێوارەوە
//   ڕادیۆ   : تیرە 24 dp · ✕: فراوانی 16 dp
// ژمارە کۆنەکان لە سکرینشۆتێکی ڕیفرنسەوە پێورابوون و هیچ پەیوەندییەکیان بە
// کارتەکەوە نەبوو — بۆیە دەیانتوانی بەبێ ئەوەی کەس تێبینی بکات لێکتربدەن.
// ئێستا هەموویان لە تۆکنەکانی کارتەوە دەردەهێنرێن یان لەسەر تۆڕی 8 dp دان.
// ژمارە کۆنەکە لە کۆتایی هەر دێڕێکدا نووسراوە.
const double _kFbSheetTopRadius = AdSurface.sheetRadius;  // 20 — بوو 16
const double _kFbSheetHeadH     = 56.0;                  // 7 × 8 — was 64.0
const double _kFbFsSheetHead    = _kCampaignFsTitle;     // 16.8 — was 19.2
/// گەتەری لەیبڵ = پەدینگی ناوەوەی کارت، بۆیە دەقی ڕیزی شیت لە هەمان
/// دووری لێواری ڕووەکەوە دەست پێدەکات کە ناوەڕۆکی کارت دەیکات.
const double _kFbSheetGutter    = AdSurface.sheetPad;    // 20 — بوو 18
const double _kFbSheetEndInset  = AdSurface.sheetPad;    // 20 — بوو 18
/// پیچی ڕیز لەسەر تۆڕی 8 dp، و هەروەها = کەمترین ئامانجی دەستلێدانی 48 dp.
const double _kFbSheetRowPitch  = 48.0;                  // 6 × 8 — was 49.1
/// سێبەری شیت — هەمان بەهاکانی سێبەری کارت بەڵام بەرەوسەرەوە، چونکە شیتەکە
/// لە خوارەوە دێت. بۆیە لێواری سەرەوەی بەڕوونی لە پەڕەکە جیا دەبێتەوە.
const List<BoxShadow> _kFbSheetShadow = [
  BoxShadow(color: Color(0x1F07112A), blurRadius: 24, offset: Offset(0, -6)),
];
const double _kFbRadioSize      = 24.0;
const double _kFbRadioRing      =  1.7;
const double _kFbRadioDot       =  8.5;
const double _kFbCloseTap       = 44.0;
const double _kFbCloseGlyph     = 16.0;
const double _kFbCloseStroke    =  2.4;
/// ڕەنگی ڕادیۆی هەڵبژێردراو. ڕیفرنسەکە ڕەشە؛ لێرەدا شینی سیستەمەکە
/// بەکاردێت بۆ ئەوەی لەگەڵ فلتەری چالاک و کارتەکە یەک بێت. بۆ ڕەشی
/// ڕیفرنس، تەنها ئەمە بکە بە `_kCampaignInk`.
const Color _kFbRadioOn = _kCampaignBlue;

/// ڕووکاری هاوبەشی هەموو شیتەکانی خوارەوە — فلتەری دۆخ، فلتەری ماوە، و
/// مینیوی کلیکی درێژی کارت. هەر سێکیان پێشتر هەمان کۆدیان دووبارە
/// دەکردەوە بە دەستی، بۆیە دەیانتوانی لێکتربدەن.
///
/// ══ چارەسەری هێڵی زەردی ژێر دەق ═══════════════════════════════════════
/// `showCupertinoModalPopup` منداڵەکەی ڕاستەوخۆ دەخاتە ناو `Overlay`ی
/// `Navigator`ەوە. ئەو دارە هیچ `Material`ێکی باوانی نییە، بۆیە
/// `DefaultTextStyle`ی چالاک ئەوەیە کە `WidgetsApp` وەک ئاگادارکردنەوەی
/// پەرەپێدەر دایدەنێت:
///
///     decoration: TextDecoration.underline
///     decorationColor: Color(0xFFFFFF00)      ← زەردەکە
///     decorationStyle: TextDecorationStyle.double
///
/// هەموو `TextStyle`ەکانی ناوەوە `inherit: true`ن (بنەڕەت) و هیچیان
/// `decoration` دیاری ناکەن، بۆیە کاتێک لەگەڵ ئەو ستایلە تێکەڵ دەکرێن
/// هێڵە زەردەکە دەمێنێتەوە و بە هەموو دەقەکانی شیتەکەدا دەردەکەوێت.
///
/// دوو بەربەست دانراوە، بە ئەنقەست:
///   1. `Material` — سەرچاوەی ڕاستەقینەی کێشەکە لادەبات
///   2. `DefaultTextStyle` بە `decoration: TextDecoration.none` — تەنانەت
///      ئەگەر ڕۆژێک شیتێک بە ڕێگایەکی تر نمایش بکرێت، هێڵەکە ناگەڕێتەوە
class _FbSheetSurface extends StatelessWidget {
  final double scale;
  final List<Widget> children;
  const _FbSheetSurface({required this.scale, required this.children});

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: _kAdCardFont,
            color: _kCampaignInk,
            decoration: TextDecoration.none,
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AdSurface.sheetSurface, // سپی، لەسەر پەڕەی #FAFAFA
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_kFbSheetTopRadius * s),
              ),
              boxShadow: _kFbSheetShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// سەرپەڕەی هەردوو شیتەکە: ناونیشان لە ناوەڕاست، ✕ لای کۆتایی (چەپ لە RTL).
class _IosSheetHeader extends StatelessWidget {
  final double scale;
  final String title;
  const _IosSheetHeader({required this.scale, required this.title});

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double t = _typeScaleFor(s);
    return SizedBox(
      height: _kFbSheetHeadH * s,
      child: Stack(
        children: [
          // ⚠ ناونیشانەکە پێشتر `Center` بوو، بەڵام هەموو لەیبڵەکانی
          // ژێری لە گەتەرەوە دەست پێدەکەن. ناونیشانێکی ناوەڕاست لەسەر
          // لیستێکی start-aligned دوو ئەکسی جیاوازی ستوونی دروست دەکات —
          // ئەوەیە کە وەک «ناڕێک» دەخوێندرێتەوە. ئێستا ناونیشان و
          // لەیبڵەکان یەک لێواری دەستپێکیان هەیە (لە RTLدا لای ڕاست).
          PositionedDirectional(
            start: _kFbSheetGutter * s,
            end: (_kFbCloseTap + _kFbSheetEndInset) * s,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _kAdCardFont,
                  fontSize: _kFbFsSheetHead * t * _kAdCardKuBump,
                  fontWeight: FontWeight.w700,
                  color: _kCampaignInk,
                  height: 1.30,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            // ناوەندی ✕ دەخرێتە سەر ناوەندی ڕادیۆکانی ژێری: گەتەر
            // − نیوەی بۆکسی دەستلێدان + نیوەی ڕادیۆ.
            end: (_kFbSheetEndInset - _kFbCloseTap / 2 + _kFbRadioSize / 2) * s,
            top: 0,
            bottom: 0,
            child: Center(
              child: _IosPressable(
                semanticLabel: 'داخستن',
                pressScale: _kPressScale,
                pressOpacity: _kPressOpacity,
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  width: _kFbCloseTap * s,
                  height: _kFbCloseTap * s,
                  child: Center(
                    child: CustomPaint(
                      size: Size.square(_kFbCloseGlyph * s),
                      painter: _SheetClosePainter(
                        color: _kCampaignInk,
                        stroke: _kFbCloseStroke * s,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IosOptionSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String current;
  final String Function(String) labelOf;
  final void Function(String) onSelect;
  final double scale;

  const _IosOptionSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.labelOf,
    required this.onSelect,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;

    return _FbSheetSurface(
      scale: s,
      children: [
        _IosSheetHeader(scale: s, title: title),
        // ── ڕیزەکان — بێ جیاکەرەوە ──
        for (final o in options)
          _IosRadioRow(
            scale: s,
            label: labelOf(o),
            selected: o == current,
            onTap: () {
              Navigator.pop(context);
              onSelect(o);
            },
          ),
        SizedBox(height: 12 * s),
      ],
    );
  }
}

/// ڕیزێکی هەڵبژاردن: لەیبڵ لای ڕاست، ڕادیۆ لای چەپ، بێ هێڵی ژێرەوە.
class _IosRadioRow extends StatefulWidget {
  final double scale;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IosRadioRow({
    required this.scale,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_IosRadioRow> createState() => _IosRadioRowState();
}

class _IosRadioRowState extends State<_IosRadioRow> {
  bool _down = false;
  void _set(bool v) { if (_down != v && mounted) setState(() => _down = v); }

  @override
  Widget build(BuildContext context) {
    final double s = widget.scale;
    final double t = _typeScaleFor(s);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: widget.selected,
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => _set(true),
        onTapUp:     (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        // هەمان کاردانەوەی `_IosSheetRow`: هایلایتێکی ڕەنگ، نەک گۆڕینی
        // ڕوونی. پێشتر ئەم ڕیزە بە opacity کاردانەوەی دەنواند و ئەوی تر
        // بە ڕەنگ — دوو ڕیزی هاوشێوە بە دوو شێوەی جیا.
        child: AnimatedContainer(
          duration: _kFbPressDur,
          curve: Curves.easeOut,
          height: _kFbSheetRowPitch * s,
          color: _down ? _kFbRowPress : AdSurface.sheetSurface,
          padding: EdgeInsetsDirectional.only(
            start: _kFbSheetGutter * s,
            end: _kFbSheetEndInset * s,
          ),
          alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _kAdCardFont,
                      fontSize: _kFbFsSheetItem * t * _kAdCardKuBump,
                      // دەقاودەق هەمان زمانی پیلی چالاک: شین + w700 کاتێک
                      // هەڵبژێردراوە، مەرەکەبی ئاسایی + w500 ئەگەرنا.
                      fontWeight:
                          widget.selected ? FontWeight.w700 : FontWeight.w600,
                      color:
                          widget.selected ? _kCampaignBlue : _kCampaignInk,
                      height: 1.35,
                    ),
                  ),
                ),
                SizedBox(width: 12 * s),
                CustomPaint(
                  size: Size.square(_kFbRadioSize * s),
                  painter: _RadioPainter(
                    selected: widget.selected,
                    on: _kFbRadioOn,
                    off: _kCampaignSubtle,
                    ring: _kFbRadioRing * s,
                    dot: _kFbRadioDot * s,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// ✕ی سەرپەڕەی شیت — دوو هێڵی خاچ بە کۆتایی خڕ.
class _SheetClosePainter extends CustomPainter {
  final Color color;
  final double stroke;
  const _SheetClosePainter({required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(_SheetClosePainter old) =>
      old.color != color || old.stroke != stroke;
}

/// ڕادیۆ: بازنەی داپۆشراو + خاڵی سپی کاتێک هەڵبژێردراوە، بازنەی بەتاڵ ئەگەرنا.
class _RadioPainter extends CustomPainter {
  final bool selected;
  final Color on;
  final Color off;
  final double ring;
  final double dot;
  const _RadioPainter({
    required this.selected,
    required this.on,
    required this.off,
    required this.ring,
    required this.dot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    if (selected) {
      canvas.drawCircle(c, r - ring / 2, Paint()..color = on..isAntiAlias = true);
      canvas.drawCircle(
          c, dot / 2, Paint()..color = Colors.white..isAntiAlias = true);
    } else {
      canvas.drawCircle(
        c,
        r - ring / 2,
        Paint()
          // ⚠ بێ `withOpacity`: 55٪ی تۆنێکی سلەیت بازنەیەکی
          // هێڵکێشراوی 1.7 dp دەکاتە شتێکی بەزەحمەت دیار.
          ..color = off
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_RadioPainter old) =>
      old.selected != selected || old.on != on || old.off != off;
}

/// Campaign-card status badge.
///
/// A local duplicate of [_DsStatusBadge] — the shared widget is used elsewhere
/// on this screen, so rather than change it, the measured geometry from report
/// v4 §5 lives here. Every dimension below is (v4) unless marked otherwise.
class _CampaignStatusBadge extends StatelessWidget {
  final double scale;
  final Color color;
  final Color bg;
  final Color border;
  final String label;
  const _CampaignStatusBadge({
    required this.scale,
    required this.color,
    required this.bg,
    required this.border,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double t = _typeScaleFor(scale); // same type floor as the card
    return Container(
      // بەرزایی پێواو وەک کەمترین بەها، بۆ ئەوەی لەیبڵێکی درێژ
      // ("In Review") پیتەکە گەورە بکات لە جیاتی ئەوەی بڕژێت.
      constraints: BoxConstraints(
        minHeight: _kCampaignBadgeH * s,
        maxWidth: 128 * s,
      ),
      padding: EdgeInsetsDirectional.only(
        start: _kCampaignBadgePadS * s,
        end: _kCampaignBadgePadE * s,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(0.07), Colors.white),
        borderRadius: BorderRadius.circular(_kCampaignBadgeRadius * s),
      ),
      // Row(min)، نەک `alignment:` — پیتەکە لە ڕیزێکی بێ‌سنووردا دانراوە،
      // و Align لەو حاڵەتەدا بەرەو پانی بەردەست دەڕوات. ئەمە دەقاودەق
      // قەبارەی دەقەکە دەگرێت و بە ئەستوونی ناوەڕاستی دەکات.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6.5 * s,
            height: 6.5 * s,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5 * s),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _kAdCardFont,
                fontSize: _kCampaignFsBadge * t,
                fontWeight: FontWeight.w400,
                color: color,
                height: AdSurface.lineTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// دۆخی ڕیکلام: دەق، ڕەنگ، surface و سنووری تایبەت.
class _StatusStyle {
  final String label;
  final Color color;
  final Color bg;
  final Color border;
  const _StatusStyle(this.label, this.color, this.bg, this.border);
}

// ─────────────────────────────────────────────────────────────────────────────
// Scroll behavior (no glow)
// ─────────────────────────────────────────────────────────────────────────────
class _AdGlowBehavior extends ScrollBehavior {
  const _AdGlowBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext ctx, Widget child, ScrollableDetails d) => child;
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonCard — پێکهاتەی سکێلیتۆنی کارت
//
// پرێمیەم skeleton-loading system — تاک shimmer sweep بۆ هەموو لیستەکە
// (نەک بۆ هەر کارتێک بەتەنیا)، بە هەمان قەبارە/padding/spacing/radius ی
// کارتی ڕاستەقینە (_AdCard = "ContentCard"ـی ئەم سیستەمە) بۆ ئەوەی کاتێک
// داتا دێت هیچ layout shift یان جامپێک ڕوونادات. لە AdScreen._buildBody
// دا لەگەڵ AnimatedSwitcher (Fade + CrossFade) بەکاردێت.
// ─────────────────────────────────────────────────────────────────────────────

// ── ڕەنگەکانی shimmer (Light mode only) ──────────────────────────────────
class _SkeletonColors {
  /// = `_CampaignSkeleton`'s bar. The dashboard shows a flat placeholder; the
  /// shimmer sweep on top of it is this screen's own addition and is kept.
  static const Color base      = _dsSkeleton;
  static const Color highlight = Color(0xFFF8F9FC);
}

/// هەمان ئەنیمەیشنی پێشووی پڕۆژە — 1400ms، ئاراستەی RTL، هەمان دوو ڕەنگی
/// سەرەوە. تەنها لە دوو شوێنەوە بۆ یەک تۆکن گواسترایەوە بۆ ئەوەی باری فلتەر
/// و کارتەکان هەرگیز لێک جیا نەبنەوە. هێواش و ئارام — نە بریسکەیەکی ڕووناک،
/// نە خێرا، نە کاریگەریی قورسی GPU.
const Duration _kSkeletonShimmerPeriod = Duration(milliseconds: 1400);

/// بەرزایی باری جێگرەوەی دەق ÷ بەرزایی بۆکسی دێڕی دەقی ڕاستەقینە.
///
/// باری جێگرەوە **نابێت** بە تەواوی بەرزایی دێڕەکە بێت — ئەگەر وابێت وەک
/// بلۆک دەردەکەوێت نەک وەک دەق. بەڵام بۆکسی دەوروبەری هەر بارێک بەرزایی
/// دێڕی ڕاستەقینەی خۆی دەگرێت، بۆیە ڕیتمی ستوونی کارتەکە هەمان ڕیتمە و
/// کاتێک داتاکە دێت هیچ شتێک نابازێت.
const double _kSkTextInk = 0.62;

/// A 1:1 placeholder for `_AdCard`, built **element by element** — never as
/// one blank rounded rectangle.
///
/// ═══ چۆن shimmer کار دەکات (گرنگترین خاڵ) ══════════════════════════════
/// پاکێجی `shimmer` ماسکێکی `BlendMode.srcIn` بەکاردێنێت: گرادیێنتەکە
/// بەسەر **هەموو** پیکسلە ڕەقەکانی منداڵەکەیدا دەڕوات و ڕەنگی ڕاستەقینەیان
/// دەسڕێتەوە. واتە هەر ڕوویەکی پڕکراوە کە بخرێتە ژێر ماسکەکە — ڕووی سپیی
/// کارت، پڕکردنەوەی چیپی بەروار، پڕکردنەوەی دوگمە — دەبێتە یەک بلۆکی
/// یەکڕەنگ و هەموو ئەو شێوانەی لەسەریەتی ون دەبن.
///
/// بۆیە لێرەدا دوو چین هەیە:
///   • **دەرەوەی** ماسکەکە — ڕوو، سنوور، گۆشە، پەدینگ و سێبەری کارتەکە،
///     دەقاودەق هەمان تۆکنەکانی `_AdCard`
///   • **ناوەوەی** ماسکەکە — تەنها شێوە جێگرەوەکان، کە بە بۆشایی ڕوونەوە
///     لێک جیا کراونەتەوە بۆیە هەریەکەیان بە جیا دەبینرێت
///
/// هەر ئەلێمێنتێکی بینراوی کارتی ڕاستەقینە جێگرەوەی خۆی هەیە: خشتەی
/// بڵندگۆ · ناونیشان · کۆدی ڕیکلام · پیتەی دۆخ · چیپی بەروار (ئایکۆن +
/// دەق) · ڕێژەی پێشکەوتن · بار + سەری بازنەیی · هەر چوار مەتریک (بازنە +
/// لەیبڵ + بەها + ڕێژەی گۆڕان بە ئایکۆنەوە) · هەردوو دوگمە (ئایکۆن +
/// لەیبڵ).
///
/// هەموو پێوانەکان لە هەمان تۆکنی `_AdCard`ەوە دێن، و بەرزایی هەر بۆکسێکی
/// دەق لە `fontSize × height`ی هەمان `TextStyle`ەوە دەرهێنراوە — بۆیە
/// گۆڕینی سکێلیتۆن → ناوەڕۆک هیچ شتێک نابزوێنێت.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    // دەقاودەق هەمان سێ ڕەمپەکەی `_AdCardState.build`:
    //   s()  → جیۆمیتری   ts() → تایپ   kt() → تایپی کوردی (Rabar)
    final double rs = _campaignScale(context);
    final double rt = _typeScaleFor(rs);
    double s(double value) => value * rs;
    double ts(double value) => value * rt;
    double kt(double value) => value * rt * _kAdCardKuBump;

    // ── بەرزایی بۆکسی دێڕەکان — لە هەمان `TextStyle`ی کارتەکەوە ──────────
    final double lhTitle = kt(_kAdcFsTitle) * 1.30;
    final double lhId = ts(_kCampaignFsId) * 1.35;
    final double lhLabel = kt(_kCampaignFsStatLabel) * 1.25;
    final double lhValue = ts(_kAdcFsStatValue) * 1.20;
    final double lhToggle = kt(_kAdcFsToggle) * 1.30;
    // پیتەی دۆخ بەرزایی کەمینەی هەیە، بەڵام لەسەر تەلەفۆنی باریک دێڕی
    // دەقەکە لەوە بەرزتر دەبێت — هەمان `max`ی کارتی ڕاستەقینە.
    final double hBadge =
        max(s(_kCampaignBadgeH), kt(_kCampaignFsBadge) * 1.30);

    // ── جێگرەوەی یەک دێڕی دەق ────────────────────────────────────────────
    // بۆکسەکە بەرزایی **دێڕی ڕاستەقینەکە**ی هەیە، بەڵام بارە ڕەنگاوەکەی
    // ناوی باریکترە (`_kSkTextInk`) — بۆیە وەک دەق دەردەکەوێت نەک وەک
    // بلۆک، لە کاتێکدا ڕیتمی ستوونی کارتەکە بە تەواوی پارێزراوە.
    //
    //   width!=null → بۆکسێکی وردی width×lineHeight
    //   flex>0      → پانییەکی ڕێژەیی لە پانی بەردەستدا (flex : rest)
    Widget textLine({
      required double lineHeight,
      double? width,
      int flex = 0,
      int rest = 0,
    }) {
      final double ink = lineHeight * _kSkTextInk;
      if (width != null) {
        return SizedBox(
          width: width,
          height: lineHeight,
          child: Center(child: _bar(w: width, h: ink, r: s(3))),
        );
      }
      return SizedBox(
        height: lineHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: flex > 0 ? flex : 1,
              child: _bar(w: double.infinity, h: ink, r: s(3)),
            ),
            if (rest > 0) Spacer(flex: rest),
          ],
        ),
      );
    }

    // ── مینی‌کارتی مەتریک: لەیبڵ + بەها، بێ ئایکۆن ──────────────────────
    Widget statTileSkeleton() => Container(
          padding: EdgeInsets.symmetric(
            horizontal: s(_kAdcTilePadH),
            vertical: s(_kAdcTilePadV),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(_kAdcTileRadius)),
            border: Border.all(
              color: _SkeletonColors.base,
              width: _kAdcTileBorderW,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              textLine(lineHeight: lhLabel, width: s(42)),
              SizedBox(height: s(4)),
              textLine(lineHeight: lhValue, width: s(30)),
            ],
          ),
        );

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── سەرپەڕە: وێنۆچکە · ناو · کۆد · پیتەی دۆخ ────────────────────
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: s(_kAdcThumbHeight)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _bar(
                w: s(_kAdcThumb),
                h: s(_kAdcThumbHeight),
                r: s(_kAdcThumbRadius),
              ),
              SizedBox(width: s(_kAdcThumbGap)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    textLine(lineHeight: lhTitle, flex: 78, rest: 22),
                    SizedBox(height: s(_kCampaignTitleIdGap)),
                    textLine(lineHeight: lhId, flex: 46, rest: 54),
                    SizedBox(height: s(8)),
                    _bar(w: s(52), h: hBadge, r: s(_kCampaignBadgeRadius)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: s(_kAdcRowGap)),
        // ── سێ مینی‌کارتی هاوپان ────────────────────────────────────────
        SizedBox(
          height: _adcMetricHeight(context, rs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: statTileSkeleton()),
              SizedBox(width: s(_kAdcMetricGap)),
              Expanded(child: statTileSkeleton()),
              SizedBox(width: s(_kAdcMetricGap)),
              Expanded(child: statTileSkeleton()),
            ],
          ),
        ),
        SizedBox(height: s(_kAdcToggleGapTop)),
        // ── کۆنترۆڵی «بینینی زیاتر» ─────────────────────────────────────
        Container(
          height: _kAdcToggleH,
          padding: EdgeInsets.symmetric(horizontal: s(7)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(_kAdcToggleRadius)),
            border: Border.all(
              color: _SkeletonColors.base,
              width: _kAdcTileBorderW,
            ),
          ),
          child: Row(
            children: [
              _bar(
                w: s(_kAdcToggleIconWell),
                h: s(_kAdcToggleIconWell),
                r: s(_kAdcToggleIconWell / 2),
              ),
              Expanded(
                child: Center(
                  child: textLine(lineHeight: lhToggle, width: s(84)),
                ),
              ),
              _bar(
                w: s(_kAdcToggleIconWell),
                h: s(_kAdcToggleIconWell),
                r: s(_kAdcToggleIconWell / 2),
              ),
            ],
          ),
        ),
      ],
    );

    // ── چوارچێوەی کارتەکە — لە **دەرەوەی** ماسکەکە ───────────────────────
    // ڕوو، سنوور، گۆشە و سێبەر **دەقاودەق** هەمان تۆکنی کارتی ڕاستەقینەن
    // (`_kAdCardBorder` / `_kAdCardBorderW` / `_kAdCardShadow`)، نەک
    // کۆپییەکیان. بۆیە هەر گۆڕانکارییەک لەو تۆکنانەدا هەردوو لایەن
    // پێکەوە دەگرێتەوە و کاتێک داتاکە دێت تەنها ناوەڕۆکەکە دەگۆڕێت —
    // نە چوارچێوەکە، نە سێبەرەکە.
    return Directionality(
      // کارتی ڕاستەقینە خۆی RTL-ە، بۆیە سکێلیتۆنەکەش: وێنۆچکە لای ڕاست،
      // پیتەی دۆخ لای چەپ.
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: s(_dsGapCard)),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: _kCampaignCardMaxWidth,
            ),
            decoration: BoxDecoration(
              color: _dsCard,
              borderRadius: BorderRadius.circular(s(_kAdcCardRadius)),
              boxShadow: _kAdcCardShadow,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                s(_kAdcCardPad),
                s(_kAdcCardPad),
                s(_kAdcCardPad),
                s(_kAdcCardPad),
              ),
              // هەمان ئەنیمەیشنی پێشوو — هەمان دوو ڕەنگ، هەمان 1400ms،
              // هەمان ئاراستەی RTL — بەڵام تەنها بەسەر شێوە
              // جێگرەوەکاندا دەڕوات، نەک بەسەر ڕووی کارتەکەدا.
              child: Shimmer.fromColors(
                baseColor: _SkeletonColors.base,
                highlightColor: _SkeletonColors.highlight,
                period: _kSkeletonShimmerPeriod,
                direction: ShimmerDirection.rtl,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar({
    required double w,
    required double h,
    double r = 10,
  }) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: _SkeletonColors.base,
          borderRadius: BorderRadius.circular(r),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ContentCard — تێبینی: `_AdCard` لەم فایلەدا کاری ContentCard دەکات
// (کارتی داتای ڕاستەقینە دوای بارکردن). ناوی نەگۆڕدرا بۆ ئەوەی هەموو
// ئەو شوێنانەی لە فایلەکەدا ئاماژەیان پێدەدات نەشکێن.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SVG Painters — بەدووی AppColors و ڕەنگەکانی تایبەتەوە
// ─────────────────────────────────────────────────────────────────────────────

/// Shared base for every campaign icon.
///
/// Each subclass returns its glyph as a single [Path] in an arbitrary design
/// space (all of them use a 0–100 box). The base measures that path and maps
/// it onto the canvas so that:
///
///   * the painted ink exactly fills the box it is given — the CustomPaint
///     size IS the measured ink box from report v4 §6.2;
///   * [strokeWidth] is absolute, so the measured stroke reproduces exactly
///     instead of being derived from the canvas width;
///   * the scale is uniform, so the glyph's own proportions are preserved.
///
/// Report v4 §6.1 records that an icon's nominal box is not recoverable from
/// a raster — only its ink is. Normalising on ink is what makes the measured
/// numbers directly usable.
abstract class _CampaignIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _CampaignIconPainter({required this.color, required this.strokeWidth});

  /// The glyph, in any convenient coordinate space.
  Path buildPath();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || strokeWidth <= 0) return;
    final raw = buildPath();
    final b = raw.getBounds();
    if (b.width <= 0 || b.height <= 0) return;

    final availW = size.width - strokeWidth;
    final availH = size.height - strokeWidth;
    if (availW <= 0 || availH <= 0) return;

    // NON-UNIFORM fit, deliberately.
    //
    // The box handed in is the glyph's MEASURED ink from the reference
    // (report §6.2). A uniform fit would letterbox any glyph whose own path
    // aspect differs from the measured one, leaving it visibly narrower or
    // shorter than the reference. Measured aspects vs. these paths:
    //   chevron −16.7 %, cursor −9.8 %, dollar +6.9 %, eye +5.0 %,
    //   wallet +4.7 %, copy −4.8 %, megaphone +3.8 %  (rest < 2 %)
    // Fitting each axis independently makes the painted ink equal the
    // measured box exactly, which is the value the reference actually gives.
    final sx = availW / b.width;
    final sy = availH / b.height;

    // The path is transformed, not the canvas, so the stroke stays circular
    // and lands at exactly [strokeWidth] regardless of the axis ratio.
    final m = Matrix4.identity()
      ..translate(strokeWidth / 2 - b.left * sx, strokeWidth / 2 - b.top * sy)
      ..scale(sx, sy, 1.0);

    canvas.drawPath(
      raw.transform(m.storage),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _CampaignIconPainter old) =>
      old.runtimeType != runtimeType ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Trailing chevron for the filter chips and the sort control.
class _SvgChevronDownIcon extends _CampaignIconPainter {
  const _SvgChevronDownIcon({required super.color, required super.strokeWidth});
  @override
  Path buildPath() => Path()
    ..moveTo(24, 34)
    ..lineTo(50, 66)
    ..lineTo(76, 34);
}

// ═════════════════════════════════════════════════════════════════════════════
// Filter bar v6 glyphs
// ═════════════════════════════════════════════════════════════════════════════
//
// Same construction as _CampaignIconPainter — path declared in whatever units
// the trace was taken in, then fitted NON-UNIFORMLY to the ink box handed in,
// because that box IS the measured ink. _FbGlyphPainter adds one thing the
// older base cannot do: a solid sub-path, which the Sort By knobs and the
// Objective bullseye need alongside their strokes.

// ── Section icon painters ─────────────────────────────────────

// ── Detail field icons ────────────────────────────────────────

// ── Calendar helpers ──────────────────────────────────────────
