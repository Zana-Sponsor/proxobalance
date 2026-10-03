// ═══════════════════════════════════════════════════════════════════════════
// TOOLS — ProxoLink landing-page builder
// ═══════════════════════════════════════════════════════════════════════════
//
// Two screens, one visual system:
//
//   ئامرازە دروستکراوەکان   (list)   — every landing page the user has made
//   پەڕەی نوێ زیادبکە        (create) — style → information → logo → platforms
//
// Layout, spacing and shapes follow the supplied reference screenshots:
// white page, large softly-rounded inputs on a near-white fill, external
// labels above every field, a 3 × 2 platform card grid, a dashed logo drop
// area, and one strong CTA at the very bottom.
//
// What this file deliberately does NOT do:
//   • no Live Preview, no WebView, no HTML rendering while typing
//   • no in-app preview route — Preview opens the real generated page in
//     an in-app read-only WebView (widgets/html_preview_sheet.dart)
//   • no decorative icons inside ordinary inputs, no nested form cards
//
// Untouched: buildCardHtml(), the templates, the Supabase columns, the
// filename rules, and the Cloudflare-Worker → Telegram delivery.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart' show supabase;
import '../services/filename_sanitizer.dart';
import '../services/html_generator.dart';
import '../widgets/html_preview_sheet.dart';
import '../services/telegram_delivery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/proxo_error_ui.dart';
import '../widgets/proxo_toast.dart';
import 'ad_create_screen.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TOKENS
// ═════════════════════════════════════════════════════════════════════════════
// Shapes and rhythm come from the reference screenshots; every colour and the
// type ramp come from app_theme.dart, so Tools stays part of Proxo rather than
// growing a parallel design system.

// ── Palette ─ measured from the reference screenshots ──────────────────────
// Every value below was sampled from 1000082622/23/24.jpg (1080×2400, 393 dp
// viewport, 2.74809 device px per dp). See TOOLS_PIXEL_SPEC.md for the
// measurement of each one.

const Color _kPage    = Color(0xFFFFFFFF); // page background
const Color _kSurface = Color(0xFFFFFFFF);

/// Text. Sampled from the darkest 2% of each glyph run:
/// title #030814, label #030813, list-card name #030713 → slate-900.
const Color _kInk   = Color(0xFF0F172A);

/// Secondary text — subtitles, descriptions, captions, list-card meta.
/// slate-500.
const Color _kSlate = Color(0xFF64748B);

/// The quietest text tier — placeholders, hints, disabled glyphs. slate-400.
/// ⚠ پێشتر `_kSlate`ی #64748B ناوی «muted» بوو و هیچ ئاستێکی سێیەم نەبوو،
/// بۆیە جێگرەوە و ژێرناو هەردووکیان هەمان تۆخی هەبوو.
const Color _kMuted = Color(0xFF94A3B8);

/// ── ACCENT ────────────────────────────────────────────────────────────────
/// شینی سیستەم (#0265FF). لەم شاشەیەدا **تەنها** بۆ سێ شت:
///   ١. ڕووی دوگمە سەرەکییەکان (`_PrimaryButton`, `_NewToolPill`)
///   ٢. کەناری فۆکەسی خانەکان و کێرسەر — هەروەک `auth_screen`
///   ٣. لینکی دەقی (پێشبینین / نموونەیەک هەڵبژێرە) — هەروەک `AuthTextLink`
///
/// ⚠ **نەک** بۆ: ڕووی کارتەکان، ڕووی خانەکانی گرید، پاشبنەمای شاشە،
/// سەرناوی بەشەکان، یان ئایکۆنە ئاساییەکان. ئەو شوێنانە سلەیتن.
/// پێشتر `_kPrimary` ناوی بوو و بە هەڵە وەک «ڕەنگی مۆدیوول» بەکارهاتبوو،
/// بۆیە شینەکە بڵاوببووەوە بۆ کارتی پلاتفۆرم، کەناری ستایل، خەڵەکی تەم،
/// سویچی زمان، چیپ و ئایکۆنی دۆخی بەتاڵ.
const Color _kAccent = AppColors.accent;

/// ڕووی نەرمی بێلایەن — خەڵەکی ئەڤاتار و ئایکۆنی دۆخی بەتاڵ.
/// ⚠ ناوی `_kPrimarySoft` بوو؛ هیچ کاتێک شین نەبووە (#F1F5F9)، بەڵام ناوەکە
/// وای دەنواند کە تۆنێکی ئەکسێنتە.
const Color _kNeutralSoft = Color(0xFFF1F5F9);

const Color _kFill       = Color(0xFFF8FAFC); // input / unselected card fill
/// ⚠ بوو #E3E8EE. ئێستا #E2E8F0 — دەقاودەق هەمان هێڵی `AuthTokens.line`
/// و هەمان سنووری کارتەکان، بۆیە یەک هێڵی مووی نەرم لە هەموو شاشەکەدا.
const Color _kFillBorder = Color(0xFFE2E8F0);
const Color _kLogoFill   = Color(0xFFFBFCFE); // drop area is lighter than a field
const Color _kDash       = Color(0xFFE2E8F0);
const Color _kFillErr    = Color(0xFFFEF7F7);
const Color _kPlaceholder= Color(0xFFF1F3F8); // skeleton bones only
const Color _kLine       = Color(0xFFE2E8F0);
const Color _kHairline   = Color(0xFFEDF0F4);
const Color _kBarLine    = Color(0xFFF2F3F5);
const Color _kDanger     = Color(0xFFEF4444);
const Color _kGreen      = Color(0xFF16A34A);
const Color _kGreenSoft  = Color(0xFFCBEADA); // logo circle
/// چیپی ناوی ستایل لەسەر کارتی لیست.
/// ⚠ بوو #EAF2FF لەگەڵ دەقی شین — واتە ڕووێکی شینی کاڵ **لەناو کارتێکدا**،
/// کە ئێستا قەدەغەیە: شین تەنها ڕووی دوگمەیە. ئێستا سلەیتێکی بێلایەنە.
const Color _kChipBg  = Color(0xFFF1F5F9);
const Color _kChipInk = _kSlate;

// ── Geometry (dp) ──────────────────────────────────────────────────────────
// gutter 44 px ÷ 2.74809 = 16.01 · content 992 px = 361.0 = 393 − 2×16
const double _kGutter      = 16.0;
const double _kContentMaxW = 361.0;
const double _kRule        = 1.0;
const double _kBarHeight   = 56.0;
const double _kBarTap      = 44.0;
const double _kBarIcon     = 22.0;
const double _kBarPadH     = 12.0;   // puts the × centre 34 dp in, as measured

/// گۆشەی کۆنترۆڵەکان — خانە، ناوچەی لۆگۆ، کارتی پلاتفۆرم، سویچی زمان.
/// ⚠ بوو 20. لەسەر کارتێکی 64 dp بەرز، گۆشەی 20 وای لێدەکرد کارتەکە
/// وەک بلوێکێکی هەڵئاوسا دەربکەوێت. 14 لە نێوان گۆشەی خانەی
/// `auth_screen` (12) و ئەوەی کۆن دایە، بۆیە نە قەڵەوە نە توندە.
const double _kR      = 14.0;
const double _kRList  = 20.0;  // شیتی نموونەکان

// ── دوگمەی سەرەکی — دەقاودەق وەک `auth_screen.dart` ────────────────────────
// ئەم سێ ژمارەیە **کۆپیی** `AuthTokens.primary / buttonHeight / buttonRadius`ن.
// ئەگەر ڕۆژێک `AuthTokens` گۆڕا، ئێرەش دەگۆڕێت — بۆیە لێرە بە ئاماژە
// نووسراون نەک بە hexی نوێ.
const Color  _kBtnBg     = _kAccent;      // #0265FF — AuthTokens.primary
const Color  _kBtnFg     = Colors.white;  // #FFFFFF — AuthTokens.onPrimary
/// ⚠ بوو 48 (= `AuthTokens.buttonHeight`). لەسەر ئامێر 48 هێشتا وەک
/// بلوێکێکی قورس دەخوێندرایەوە لە کۆتایی فۆڕمێکی درێژدا. 45 لە ناوەڕاستی
/// مەودای داواکراوی 44–46دایە.
const double _kBtnHeight = 45.0;
const double _kBtnRadius = 12.0;          //           AuthTokens.buttonRadius
const double _kBtnFs     = 14.5;          //           AuthTokens.buttonText.fontSize
/// ⚠ نوێ. پێشتر CTAـەکە تەواوی پانی ستوونی ناوەڕۆک (361 dp) دەگرت، کە
/// لەگەڵ بەرزایی 56دا وای دەکرد ببێتە بلوێکێکی ڕەق لە بنی پەڕەکە.
/// بە 300 dpـی ناوەڕاست‌کراو، دوگمەکە هێشتا سەرەکییە بەڵام هەڵدەکشێت.
/// بیکە `double.infinity` ئەگەر دەتەوێت بگەڕێتەوە بۆ پانی تەواو.
const double _kBtnMaxW   = 300.0;

/// بەرزایی پیلی «ئامرازی نوێ». ئەمە دوگمەیەکی ناوهێڵیی باوەشکراوە
/// (hug-width) لە سەرەوەی لیستەکە، نەک CTAیەکی تەواوپان — بۆیە کورتترە.
/// بکەیە `_kBtnHeight` ئەگەر دەتەوێت دەقاودەق هەمان بەرزایی CTA بێت.
const double _kPillHeight = 36.0;  // ⚠ بوو 40
/// گۆشەی کارت — هەمان ژمارەی فۆڕمی دروستکردن و کارتە خێراکانی سەرەکی.
const double _kRCard  = 16.0;
/// هێڵی مووی دەوری کارت — هەمان #E2E8F0ـی خانەکانی فۆڕم.
const Color _kCardHairline = Color(0xFFE2E8F0);
/// بەرزکردنەوەیەکی زۆر سووک. سنوورەکە کاری دیاریکردنی لێوارەکە دەکات،
/// بۆیە سێبەرەکە تەنها قووڵایی زیاد دەکات.
/// ⚠ بوو `0x05000000 / blur 8` (٢٪). بلەری 8 لەسەر ڕەنگێکی ئەوەندە
/// کاڵ سێبەرەکەی دەکردە هەوایەکی بڵاو بەبێ لێوار. ئێستا ٤٪ بە بلەری 5:
/// نزیکتر، ڕوونتر، و کارتەکە وەک وەرەقەیەکی تەنک دەردەکەوێت نەک بلوێک.
const List<BoxShadow> _kCardLift = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 5, offset: Offset(0, 2)),
];
const double _kRChip  = 8.0;   // status chip: fitted 7.18 → 7.7
const double _kRTile  = 20.0;  // style preview tile

const double _kFieldH    = 48.0;   // = AuthTokens.buttonHeight, unchanged
const double _kAreaH     = 76.0;   // ⚠ بوو 80
/// ⚠ بوو 168 — یەک لە سێی درێژی شاشەیەک بۆ خانەیەکی لۆگۆ. 136 هێشتا
/// جێگای خەڵەکە + دوو دێڕ دەقی تێدایە بەبێ ئەوەی فۆڕمەکە پان بکاتەوە.
const double _kLogoH     = 136.0;
/// ⚠ بوو 56. ئێستا دەقاودەق بەرزایی دوگمەی `auth_screen`.
const double _kCtaH      = _kBtnHeight;
/// ⚠ بوو 110. پاش بچووککردنەوەی ئەڤاتار (38)، ناو (14.5) و پاڵدانەکە،
/// ناوەڕۆکی ڕاستەقینەی کارتەکە ≈ 92 dp دەبێت.
const double _kListCardH = 88.0;

/// پاڵدانی ناوەوەی کارت — ئاسۆیی/ستوونی.
/// ⚠ بوو 16 / 14 و بە `_kGutter`ـەوە بەستراوە، واتە پاڵدانی ناوەوەی کارت
/// هەمان گەتەری پەڕەکە بوو و کارتەکە قەڵەو دەردەکەوت.
const double _kCardPadH = 13.0;  // ⚠ بوو 14
const double _kCardPadV = 11.0;  // ⚠ بوو 12

// Platform grid: cards 312 px = 113.53 dp, gaps 28 px = 10.19 dp,
// 3×113.53 + 2×10.19 = 361.0 ✓. Height 192 px = 69.87 for a 1-line label;
// the reference lets a 2-line label grow the card to 236 px = 85.88.
// ⚠ ژمارە کۆنەکان (70 / 15.5 / 9.8) لە وێنە ڕەسەنەکانەوە پێوراون، بەڵام
// ئەو وێنانە ئایکۆنی 17.5 dpیان هەبوو. ئێستا ئایکۆنەکە 20ـە (بەپێی مەودای
// 20–24)، بۆیە ئەگەر پاڵدانەکە هەر 15.5 بمابایەوە کارتەکە دەبووە 76 dp.
const int    _kPlatCols = 3;
const double _kPlatGap  = 10.0;
const double _kPlatMinH = 64.0;   // ⚠ بوو 70
const double _kPlatPadV = 11.0;   // ⚠ بوو 15.5
const double _kPlatIconGap = 7.0; // ⚠ بوو 9.8
const double _kPlatIcon = 20.0;   // ⚠ بوو 17.5 — خوارتر لە مەودای داواکراو

const double _kLogoCircle = 42.0; // ⚠ بوو 48
const double _kLogoGlyph  = 20.0; // ink 20.38
const double _kLogoGap1   = 11.0; // ⚠ بوو 13.8
const double _kLogoGap2   = 7.0;  // ⚠ بوو 9.1

// Three complete style previews must fit inside the same 361 dp content
// column as the form.  The old fixed 126 dp width needed 398 dp for three
// tiles (3 * 126 + 2 * 10), so the third preview was clipped on a 393 dp
// phone.  Keep only the source aspect here; the painted width is calculated
// from the real viewport below.
const int    _kVisibleStyles     = 3;
const double _kStyleSourceW      = 126.0;
const double _kStyleSourceH      = 210.0;
const double _kStyleGap          = 10.0;
const double _kStyleViewportMaxW =
    _kContentMaxW + (_kGutter * 2); // 393 dp

// ── Vertical rhythm ────────────────────────────────────────────────────────
// Derived from ink-to-ink distances, then corrected by where the face puts its
// ink inside a `height: 1.40` line box, so the *painted* result lands where
// the reference's does — not just the layout boxes.
//   contact-row pitch  input→input   242 px = 88.06 dp
//   = 48 (field) + 12 (_kGapRow) + 19.6 (label line) + 8 (_kGapLabel) = 87.6
const double _kGapLabel   = 8.0;   // label → its field
const double _kGapRow     = 12.0;  // field → next contact label   (14.2 ink)
const double _kGapField   = 20.0;  // field → next main label      (23.6 ink)
const double _kGapSection = 22.0;  // block → next section title   (22.6 ink)
const double _kGapSubtitle= 11.0;  // section title → its subtitle (15.6 ink)
const double _kGapAfterSub= 11.0;  // subtitle → the control below (10.9 ink)
const double _kGapControl = 20.0;  // control → control            (20.4 ink)
const double _kGapCards   = 12.0;  // between created-cards        (34 px)

// ── Type ───────────────────────────────────────────────────────────────────
// ⚠ ئەم بەشە بە تەواوی گۆڕا. پێشتر هەموو ژمارەکان بە `_kKuBump` (1.06)
// لێکدەدرانەوە لە شوێنی بانگکردندا، **سەرەڕای** `_typeScale` (تا 1.06)،
// واتە قەبارەی کۆتایی دوو جار زیاد دەکرا:
//
//     16 (نۆمینال) × 1.06 (typeScale لەسەر 412 dp) × 1.06 (KuBump) ≈ 18 dp
//
// بۆیە سەرناوی کارتێک کە «16»ی نووسرابوو لە 18 dp دەکێشرا، و دوگمەی CTA
// کە «16» بوو لە 17+ دەکێشرا. ئەوە بەڕاستی هۆکاری گەورەییەکە بوو.
//
// ئێستا: هەموو ژمارەکان **ئامانجی کۆتایی dp**ن. تەنها `_typeScale` لێیان
// دەدرێت (بۆ لەخۆگرتنی پانی ئامێر)، و `kKuFontBump` هیچ شوێنێک لەم
// فایلەدا بەکار نایەت. ئەگەر ڕۆژێک فۆنتەکە گۆڕا و ئینکەکە بچووکتر
// بووەوە، ژمارەکانی خوارەوە ڕاست بکەرەوە — نەک بەربەستێکی زیادکراو.
const String _kFont       = kAppFont;
const double _kLineH      = 1.40;

/// AppBar title — LITERAL dp, no bump at the call site (see `_ToolsTopBar`).
/// w700: AppBar titles are the one place the app asks for Bold.
// ⚠ ئەم گروپە هەمووی ئێستا **دەقاودەق dp**ـە: هیچ کامیان بە `_kKuBump`
// (1.06) لێک نادرێنەوە لە شوێنی بانگکردنیان. ئەوە هۆکاری سەرەکی
// «گەورەیی»ـەکە بوو — سەرناوی کارت لە 16 نووسرابوو بەڵام لە 16 × 1.06 ×
// 1.06 ≈ 18 dp دەکێشرا لەسەر تەلەفۆنی 412 dp. سنووری داواکراو 14–15 بوو.
const double _kFsBarTitle = 18.0;  // ⚠ بوو 18.5
const double _kFsLabel    = 13.5;  // ⚠ بوو 14 + bump ≈ 14.8
const double _kFsSection  = 14.0;  // سەرناوی بەش — سەرەوەی مەودای 14–15
const double _kFsInput    = 14.5;  // ⚠ بوو 16 + bump ≈ 17 — زۆر گەورە بۆ خانەیەکی 48
const double _kFsSub      = 12.0;  // ژێرناوی بەش
const double _kFsLogoT    = 13.5;  // ⚠ بوو 14 + bump
const double _kFsLogoS    = 12.0;  // ⚠ بوو 13 + bump
const double _kFsPlatform = 12.5;  // ⚠ بوو 13 + bump ≈ 13.8
const double _kFsCta      = _kBtnFs; // ⚠ بوو 16 + bump ≈ 17 — ئێستا 14.5ی auth
// ── Empty-state type — SHARED WITH `ad_screen.dart` ────────────────────────
// The ads empty state and this one are the same layout with different art, so
// they read as one component only if these four numbers are identical in both
// files. They are LITERAL dp: neither screen multiplies them by `_kKuBump`,
// because they are the final painted target, not a nominal size to be scaled.
//
// ⚠ If you change one of these, change the twin in `ad_screen.dart`
// (`_kEmptyFsTitle` / `_kEmptyFsBody` / `_kEmptyLhTitle` / `_kEmptyLhBody`).
const double _kFsEmptyTitle  = 17.0;
const double _kFsEmptyBody   = 13.0;
const double _kLhEmptyTitle  = 1.35;
const double _kLhEmptyBody   = 1.40;

// ── کارتی ئامراز ───────────────────────────────────────────────────────────
// سەرناو 14–15 / w600، وەسف 12–13 / ئاسایی. دەقاودەق dp، بێ `_kKuBump`.
const double _kFsCardName = 14.5;  // ⚠ بوو 16 (+ bump ≈ 17)
const double _kFsCardSub  = 12.0;  // ⚠ بوو 13.5 → 12.5 → 12
const double _kFsAction   = 12.5;  // ⚠ بوو 13 (+ bump)
const double _kFsMeta     = 11.5;  // ⚠ بوو 12

// ── Responsive ─────────────────────────────────────────────────────────────
// The anchor is the reference device itself (393 dp), so at 393 dp the scale
// is exactly 1.000 and every token above IS its measured dp value. The clamps
// and the max-width behaviour are the ones ad_details / faq already use.
const double _kRefWidth = 393.0;
const double _kRefScale = 1.00;
const double _kScaleMin = 0.86;
const double _kScaleMax = 1.06;
const double _kTypeMin  = 0.92;

double _scaleFor(BuildContext c) =>
    (MediaQuery.sizeOf(c).width / _kRefWidth * _kRefScale)
        .clamp(_kScaleMin, _kScaleMax);

double _typeScale(double s) => s.clamp(_kTypeMin, _kScaleMax);

double _styleViewportWidth(BuildContext c) =>
    math.min(MediaQuery.sizeOf(c).width, _kStyleViewportMaxW);

double _styleTileWidth(BuildContext c) {
  final gap = _kStyleGap * _scaleFor(c);
  final available = _styleViewportWidth(c) - (_kGutter * 2);
  return (available - gap * (_kVisibleStyles - 1)) / _kVisibleStyles;
}

/// Bottom breathing room at the end of every scroll. The shell Scaffold in
/// main.dart lays this screen out ABOVE its bottom nav (extendBody is
/// false), so this is a comfort gap, not clearance.
double _bottomGap(BuildContext c) => 40 + MediaQuery.paddingOf(c).bottom;

TextStyle _t({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _kInk,
  double height = _kLineH,
}) =>
    TextStyle(
      fontFamily: _kFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      decoration: TextDecoration.none,
    );

// ── Copy ────────────────────────────────────────────────────────────────────
const String _kTxtListTitle   = 'ئامرازە دروستکراوەکان';
const String _kTxtCreateTitle = 'پەڕەی نوێ زیادبکە';
const String _kTxtClose       = 'داخستن';
const String _kTxtNew         = 'ئامرازی نوێ';

/// Platform glyphs. `PlatformBtn.iconWidget` hard-codes its own size and
/// colour, so the grid resolves the raw `IconData` here instead and paints
/// it at the size/colour the selected state needs.
FaIconData _platformIcon(String id) {
  switch (id) {
    case 'wa':
      return FontAwesomeIcons.whatsapp;
    case 'vb':
      return FontAwesomeIcons.viber;
    case 'tg':
      return FontAwesomeIcons.telegram;
    case 'ig':
      return FontAwesomeIcons.instagram;
    case 'ph':
      return FontAwesomeIcons.phone;
    case 'as':
      return FontAwesomeIcons.mobileScreenButton;
    default:
      return FontAwesomeIcons.link;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAGE CONTROLLER — data flow unchanged from the previous implementation
// ═════════════════════════════════════════════════════════════════════════════

enum PlView { list, form }

class ToolsScreen extends StatelessWidget {
  final void Function(Map<String, dynamic>)? onUseForAd;
  final bool initialCreate;
  const ToolsScreen({super.key, this.onUseForAd, this.initialCreate = false});
  @override
  Widget build(BuildContext context) => ProxolinkPage(onUseForAd: onUseForAd, initialCreate: initialCreate);
}

class ProxolinkPage extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onUseForAd;
  final bool initialCreate;
  const ProxolinkPage({super.key, this.onUseForAd, this.initialCreate = false});
  @override
  State<ProxolinkPage> createState() => _ProxolinkPageState();
}

class _ProxolinkPageState extends State<ProxolinkPage> {
  PlView _view = PlView.list;
  final List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;
  int _formKey = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialCreate) _view = PlView.form;
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final data = await supabase
          .from('proxolink_cards')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final loaded = <Map<String, dynamic>>[];
      for (final row in data) {
        final styleStr = row['style'] as String? ?? 'dark';
        final style = PlStyle.values
            .firstWhere((s) => s.nameEn == styleStr, orElse: () => PlStyle.dark);
        // `color_theme` is stored as a theme KEY ('purple', 'dark', ...),
        // matching the website — not a hex string. themeByKey() also
        // tolerates a legacy hex value from an older build, just in case.
        final cardTheme = themeByKey(row['color_theme'] as String?);
        loaded.add({
          'id': row['id']?.toString(),
          'name': row['name'] ?? '',
          'bio': row['bio'] ?? '',
          // The website writes the tiktok handle to column `tt`; an
          // older Flutter build wrote `tiktok` instead. Read both so
          // cards created from either client display correctly.
          'tiktok': (row['tt'] as String?) ?? (row['tiktok'] as String?) ?? '',
          'style': style,
          'theme': cardTheme.swatch,
          'themeKey': cardTheme.key,
          'platforms': Map<String, String>.from(
              (row['platforms'] as Map?)
                      ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
                  {}),
          // Likewise, `avatar_b64` is the real/shared column; `logo_b64`
          // was Flutter-only and is unused in production data.
          'logoB64': (row['avatar_b64'] as String?) ??
              (row['logo_b64'] as String?) ??
              '',
          'logo': null,
          'card_number': row['card_number'],
          'checked_btns': row['checked_btns'],
          'html_content': row['html_content'] as String?,
          // Read straight through so the list card can show a real creation
          // date instead of inventing metadata (§25).
          'created_at': row['created_at']?.toString(),
        });
      }
      if (!mounted) return;
      setState(() {
        _cards.addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToForm() => setState(() {
        _formKey++;
        _view = PlView.form;
      });

  void _goToList() => setState(() => _view = PlView.list);

  void _onCardCreated(Map<String, dynamic> card) {
    if (widget.initialCreate && widget.onUseForAd != null) {
      widget.onUseForAd!(card);
      return;
    }
    setState(() {
      _cards.insert(0, card);
      _view = PlView.list;
    });
  }

  Future<void> _onDelete(int i) async {
    final id = _cards[i]['id'] as String?;
    if (id != null) {
      try {
        await supabase.from('proxolink_cards').delete().eq('id', id);
      } catch (_) {}
    }
    if (mounted) setState(() => _cards.removeAt(i));
  }

  void _onUseForAd(Map<String, dynamic> card) {
    if (widget.onUseForAd != null) {
      widget.onUseForAd!(card);
      return;
    }
    Navigator.push(context,
        ProxoPageRoute<String>(builder: (_) => AdCreateScreen(proxoCard: card)));
  }

  @override
  Widget build(BuildContext context) {
    final inForm = _view == PlView.form;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope<Object?>(
        // System back inside the Create form returns to the list instead of
        // dropping the user out of the Tools tab entirely.
        canPop: !inForm,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && inForm) _goToList();
        },
        child: Scaffold(
          backgroundColor: _kPage,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: child,
            ),
            child: inForm
                ? _FormView(
                    key: ValueKey('form_$_formKey'),
                    onClose: _goToList,
                    onCreated: _onCardCreated,
                  )
                : _isLoading
                    ? const _SkeletonView(key: ValueKey('skeleton'))
                    : _ListView(
                        key: const ValueKey('list'),
                        cards: _cards,
                        onAdd: _goToForm,
                        onUseForAd: _onUseForAd,
                        onDelete: _onDelete,
                      ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED CHROME — the one top bar both Tools screens use
// ═════════════════════════════════════════════════════════════════════════════
// Same 56 dp content height, same gutter, same white surface and same bottom
// hairline as ProxoTopBar / ad_details / faq, with the device safe-area inset
// added on top. No Material AppBar, no elevation.

class _ToolsTopBar extends StatelessWidget {
  final String title;

  /// Physical LEFT in this RTL screen — where the reference puts its close
  /// control. Null on the list screen: it's a bottom-nav tab root, so there
  /// is nothing to pop and a control there would be dead.
  final VoidCallback? onClose;

  const _ToolsTopBar({required this.title, this.onClose});

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    final topPadding = MediaQuery.paddingOf(context).top;

    final Widget endSlot = onClose == null
        ? const SizedBox(width: _kBarTap)
        : _Pressable(
            semanticLabel: _kTxtClose,
            onTap: onClose!,
            child: SizedBox(
              width: _kBarTap,
              height: _kBarTap,
              child: Center(
                child: Icon(Icons.close_rounded,
                    size: _kBarIcon * s, color: _kInk),
              ),
            ),
          );

    return Container(
      height: _kBarHeight + topPadding,
      padding: EdgeInsets.only(
        top: topPadding,
        left: _kBarPadH,
        right: _kBarPadH,
      ),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBarLine, width: _kRule)),
      ),
      // children[0] lands on the physical RIGHT in RTL, children.last on the
      // physical LEFT — the close control's side is therefore explicit, not
      // left to mirroring.
      child: Row(
        children: [
          const SizedBox(width: _kBarTap),
          Expanded(
            child: Center(
              child: ProxoText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                // ⚠ NO `_kKuBump` here — `_kFsBarTitle` is already the final
                // dp target (18.5), so multiplying it again is what pushed the
                // header out of proportion with the rest of the app's titles.
                style: _t(
                    size: _kFsBarTitle * t,
                    weight: FontWeight.w700,
                    height: 1.20),
              ),
            ),
          ),
          endSlot,
        ],
      ),
    );
  }
}

/// Soft, fast press feedback — same feel as the rest of the app's bars.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double pressScale;
  const _Pressable({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.pressScale = 0.92,
  });
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? widget.pressScale : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      );
}

/// Matches ad_details / faq: iOS-style physics, so the Android glow is off.
class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
          BuildContext ctx, Widget child, ScrollableDetails d) =>
      child;
}

/// Content stops widening past the reference phone and centres instead, so
/// tablets get the same proportions with wider gutters. = `_capped` in
/// ad_details.dart.
Widget _capped(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kContentMaxW),
        child: child,
      ),
    );

/// Section heading, with the optional muted sub-line the references use
/// under «پلاتفۆرمی پەیوەندی هەڵبژێرە».
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? subtitle;
  const _SectionLabel(this.text, {this.subtitle});
  @override
  Widget build(BuildContext context) {
    final t = _typeScale(_scaleFor(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: _kGapAfterSub),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProxoText(text,
              style: _t(
                  size: _kFsSection * t, weight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: _kGapSubtitle),
            ProxoText(subtitle!,
                style: _t(size: _kFsSub * t, color: _kSlate)),
          ],
        ],
      ),
    );
  }
}

/// External field label. Stronger than the placeholder, never bold (§13).
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: _kGapLabel),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProxoText(
              text,
              style: _t(
                size: _kFsLabel * _typeScale(_scaleFor(context)),
                weight: FontWeight.w600,
              ),
            ),
            if (required)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: ProxoText('*',
                    style: _t(
                        size: _kFsLabel * 0.9, color: _kDanger, height: 1.0)),
              ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// LIST — ئامرازە دروستکراوەکان
// ═════════════════════════════════════════════════════════════════════════════

class _ListView extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onUseForAd;
  final void Function(int) onDelete;
  const _ListView({
    required this.cards,
    required this.onAdd,
    required this.onUseForAd,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    return Column(
      children: [
        const _ToolsTopBar(title: _kTxtListTitle),
        Expanded(
          child: cards.isEmpty
              ? _EmptyState(onAdd: onAdd)
              : ScrollConfiguration(
                  behavior: const _NoGlowBehavior(),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(_kGutter * s, 18 * s,
                        _kGutter * s, _bottomGap(context)),
                    // +1 leading row for the "new tool" pill, which the
                    // references place above the list rather than in the bar.
                    itemCount: cards.length + 1,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: _kGapCards * s),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _capped(Align(
                          // physical LEFT in RTL — same side as the reference
                          alignment: AlignmentDirectional.centerEnd,
                          child: _NewToolPill(onTap: onAdd),
                        ));
                      }
                      final index = i - 1;
                      return _capped(
                        RepaintBoundary(
                          child: _ToolCard(
                            key: ValueKey(cards[index]['id'] ?? 'card_$index'),
                            card: cards[index],
                            onUseForAd: () => onUseForAd(cards[index]),
                            onDelete: () => _confirmDelete(context, index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, int i) async {
    final name = cards[i]['name'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kSurface,
          surfaceTintColor: _kSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kR)),
          title: ProxoText('سڕینەوەی ئامراز',
              style: _t(size: 15, weight: FontWeight.w600)),
          content: ProxoText('دڵنیایت لە سڕینەوەی "$name"؟',
              style: _t(size: 13, color: _kSlate, height: 1.7)),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: ProxoText('پاشگەزبوونەوە',
                  style: _t(size: 13, weight: FontWeight.w600, color: _kSlate)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: ProxoText('سڕینەوە',
                  style: _t(size: 13, weight: FontWeight.w600, color: _kDanger)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) onDelete(i);
  }
}

/// The reference's "+ ئامرازی نوێ" pill.
class _NewToolPill extends StatelessWidget {
  final VoidCallback onTap;
  const _NewToolPill({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    return _Pressable(
      semanticLabel: _kTxtNew,
      pressScale: 0.96,
      onTap: onTap,
      // ڕووەکە شینە — ئەمە دوگمەی کردارە. هەمان hexـی `auth_screen`،
      // هەمان گۆشە (12). ⚠ بوو گۆشەی 21 (ستادیۆم)، کە لە هیچ دوگمەیەکی
      // تری ئەپەکەدا نەبوو.
      child: Container(
        height: _kPillHeight * s,
        padding: EdgeInsets.symmetric(horizontal: 14 * s),
        decoration: BoxDecoration(
          color: _kBtnBg,
          borderRadius: BorderRadius.circular(_kBtnRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ناوەڕۆکی ناو دوگمەی شین: سپیی ڕەق — دەق و ئایکۆن پێکەوە.
            ProxoText(_kTxtNew,
                style: _t(
                    size: _kFsAction * t,
                    weight: FontWeight.w700,
                    color: _kBtnFg,
                    height: 1.2)),
            SizedBox(width: 6 * s),
            Icon(Icons.add_rounded, size: 16 * s, color: _kBtnFg),
          ],
        ),
      ),
    );
  }
}

// ── One created landing page ────────────────────────────────────────────────

class _ToolCard extends StatefulWidget {
  final Map<String, dynamic> card;
  final VoidCallback onUseForAd;
  final VoidCallback onDelete;
  const _ToolCard({
    required this.card,
    required this.onUseForAd,
    required this.onDelete,
    super.key,
  });
  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  Uint8List? _avatarBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decodeAvatar();
  }

  /// Decoded exactly once, not on every build.
  void _decodeAvatar() {
    final b64 = widget.card['logoB64'] as String? ?? '';
    if (b64.isEmpty) return;
    try {
      _avatarBytes =
          base64Decode(b64.contains(',') ? b64.split(',').last : b64);
    } catch (_) {/* fall back to the initial */}
  }

  String? _createdLabel() {
    final raw = widget.card['created_at'] as String?;
    if (raw == null || raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return null;
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}/${two(l.month)}/${two(l.day)}';
  }

  /// ⚠ پێشتر `LocalHtmlPreview.open()` بوو، کە فایلێکی HTML دەنووسی و
  /// بە ئەندرۆیدی دەدا. ئەندرۆید هەڵبژێرەری ئەپی پیشان دەدا، و ئەو
  /// هەڵبژێرەرە ئەدیتەری کۆدی تێدابوو — واتە بەکارهێنەری ئاسایی
  /// دەیتوانی سەرچاوەی خاوی پەڕەکە ببینێت و دەستکاری بکات.
  ///
  /// ئێستا لەناو ئەپەکەدا دەکێشرێت، بەبێ جاڤاسکریپت و بەبێ گەڕان —
  /// تەنها خوێندنەوە. بڕوانە `html_preview_sheet.dart`.
  Future<void> _preview() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await HtmlPreviewSheet.open(
      context,
      html: widget.card['html_content'] as String?,
      title: widget.card['name'] as String?,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      showProxoToast(context, 'ناوەڕۆکی ئەم کارتە بەردەست نییە',
          type: ProxoToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    final name = widget.card['name'] as String? ?? '';
    final style = widget.card['style'] as PlStyle? ?? PlStyle.dark;
    final created = _createdLabel();

    return Container(
      // 301 px ≈ 110 dp in the reference. A floor, not a fixed height, so a
      // long name or a wrapped date can still grow the card.
      constraints: BoxConstraints(minHeight: _kListCardH * s),
      // ⚠ بوو `_kRList` (24) + `kProxoCardShadow` بەبێ هیچ سنوورێک.
      //
      // فۆڕمی دروستکردن — سەرچاوەی ڕاستیی ڕووکاری ئەپەکە — گۆشەی 16، هێڵی
      // مووی #E2E8F0 و سێبەرێکی زۆر سووک بەکاردەهێنێت. کارتی لیستەکە
      // گۆشەیەکی گەورەتر و سێبەرێکی قووڵتری هەبوو بەبێ سنوور، بۆیە
      // لەتەنیشت فۆڕمەکەدا وەک کۆمپۆنێنتێکی جیاواز دەردەکەوت.
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRCard),
        border: Border.all(color: _kCardHairline, width: 1),
        boxShadow: _kCardLift,
      ),
      padding:
          EdgeInsets.symmetric(horizontal: _kCardPadH * s, vertical: _kCardPadV * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity (physical right) + icon actions (physical left) ────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(bytes: _avatarBytes, name: name, size: 36 * s),
              SizedBox(width: 10 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProxoText(
                      name.isEmpty ? 'بێ ناو' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(
                          size: _kFsCardName * t,
                          weight: FontWeight.w600,
                          height: 1.25),
                    ),
                    if (created != null) ...[
                      SizedBox(height: 4 * s),
                      ProxoText(
                        created,
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(
                            size: _kFsCardSub * t,
                            color: _kSlate,
                            height: 1.25),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 2 * s),
              _IconAction(
                  icon: Icons.campaign_outlined,
                  color: _kSlate,
                  semantic: 'ڕیکلام',
                  scale: s,
                  onTap: widget.onUseForAd),
              _IconAction(
                  icon: Icons.delete_outline_rounded,
                  color: _kDanger,
                  semantic: 'سڕینەوە',
                  scale: s,
                  onTap: widget.onDelete),
            ],
          ),
          SizedBox(height: 8 * s),
          // ── Style chip (physical right) + Preview (to its left) ─────────
          Row(
            children: [
              Container(
                height: 22 * s,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 10 * s),
                decoration: BoxDecoration(
                  color: _kChipBg,
                  borderRadius: BorderRadius.circular(_kRChip),
                ),
                child: ProxoText(style.nameKu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(
                        size: _kFsAction * t,
                        weight: FontWeight.w600,
                        color: _kChipInk,
                        height: 1.0)),
              ),
              SizedBox(width: 10 * s),
              _Pressable(
                semanticLabel: 'پێشبینین',
                pressScale: 0.95,
                onTap: _preview,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 5 * s),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // «پێشبینین» لینکی دەقییە، نەک لەیبڵ. شینەکە لێرە
                      // ڕێپێدراوە بە هەمان لۆژیکی `AuthTextLink` — دەقی
                      // شین لەسەر ڕووی سپی، نەک ڕووێکی شین.
                      ProxoText('پێشبینین',
                          style: _t(
                              size: _kFsAction * t,
                              weight: FontWeight.w600,
                              color: _kAccent,
                              height: 1.2)),
                      SizedBox(width: 5 * s),
                      _busy
                          ? SizedBox(
                              width: 13 * s,
                              height: 13 * s,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: _kAccent))
                          : Icon(Icons.open_in_new_rounded,
                              size: 14 * s, color: _kAccent),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String semantic;
  final double scale;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.semantic,
    required this.scale,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => _Pressable(
        semanticLabel: semantic,
        onTap: onTap,
        // ئایکۆنەکە 20 dpـە (خوارەوەی مەودای 20–24 — کارتێکی 94 dp بەرز
        // ناتوانێت دوو ئایکۆنی 24ی هەبێت بەبێ ئەوەی قەڵەو دەربکەوێت).
        // ⚠ ناوچەی کرتەکردن بوو 44 — دوو دانەیان 88 dpی ڕیزەکەی دەخوارد.
        child: SizedBox(
          width: 34 * scale,
          height: 34 * scale,
          child: Center(child: Icon(icon, size: 20 * scale, color: color)),
        ),
      );
}

class _Avatar extends StatelessWidget {
  final Uint8List? bytes;
  final String name;
  final double size;
  const _Avatar({required this.bytes, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kNeutralSoft,
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(color: _kLine, width: _kRule),
      ),
      alignment: Alignment.center,
      child: bytes != null
          ? Image.memory(
              bytes!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              // A user logo can be several megapixels — decode it at the
              // 40 dp it actually paints at, not at full resolution.
              cacheWidth: (size * dpr).round(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _initial(),
            )
          : _initial(),
    );
  }

  // ⚠ پیتەکە بوو `_kPrimary` (شین). ئەڤاتار ئایکۆنێکی ئاسایی کارتە،
  // نەک دوگمە — بۆیە مەرەکەب.
  Widget _initial() => ProxoText(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '؟',
        style: _t(
            size: size * 0.40,
            weight: FontWeight.w600,
            color: _kInk,
            height: 1.0),
      );
}

// ── Empty state (§34) ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(_kGutter + 14, 0, _kGutter + 14, 40 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚠ ئایکۆنەکە بوو شین. ئایکۆنی دۆخی بەتاڵ ئایکۆنێکی ئاساییە،
            // نەک دوگمە — بۆیە سلەیت لەسەر ڕووێکی بێلایەن.
            Container(
              width: 52 * s,
              height: 52 * s,
              decoration: BoxDecoration(
                color: _kNeutralSoft,
                borderRadius: BorderRadius.circular(_kR),
              ),
              child: Icon(Icons.link_rounded, size: 24 * s, color: _kSlate),
            ),
            SizedBox(height: 16 * s),
            ProxoText(
              'هیچ ئامرازێک نییە',
              textAlign: TextAlign.center,
              style: _t(
                size: _kFsEmptyTitle * t,
                weight: FontWeight.w700,
                height: _kLhEmptyTitle,
              ),
            ),
            SizedBox(height: 7 * s),
            ProxoText(
              'یەکەم پەڕەی دابەزینی پەیوەندیت دروست بکە و لەگەڵ کڕیارەکانت هاوبەشی بکە.',
              textAlign: TextAlign.center,
              // ⚠ 1.40, not the old 1.75. At 1.75 the two lines sat so far
              // apart they read as two separate sentences rather than one
              // wrapped one — and the ads empty state, which this is now
              // paired with, was never that loose.
              style: _t(
                size: _kFsEmptyBody * t,
                color: _kSlate,
                height: _kLhEmptyBody,
              ),
            ),
            SizedBox(height: 22 * s),
            _NewToolPill(onTap: onAdd),
          ],
        ),
      ),
    );
  }
}

// ── Loading state (§35) — one skeleton per card, same structure ─────────────

class _SkeletonView extends StatefulWidget {
  const _SkeletonView({super.key});
  @override
  State<_SkeletonView> createState() => _SkeletonViewState();
}

class _SkeletonViewState extends State<_SkeletonView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    return Column(
      children: [
        const _ToolsTopBar(title: _kTxtListTitle),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(_kGutter * s, 18 * s, _kGutter * s,
                _bottomGap(context)),
            itemCount: 4,
            separatorBuilder: (_, __) => SizedBox(height: _kGapCards * s),
            itemBuilder: (_, __) =>
                _capped(_SkeletonCard(pulse: _ctrl, scale: s)),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Animation<double> pulse;
  final double scale;
  const _SkeletonCard({required this.pulse, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return RepaintBoundary(
      child: FadeTransition(
        // A calm 0.55 → 1.0 pulse instead of a sweeping shimmer — cheap to
        // paint and far less noisy behind four stacked cards.
        opacity: Tween<double>(begin: 0.55, end: 1.0).animate(pulse),
        child: Container(
          height: _kListCardH * s,
          padding: EdgeInsets.symmetric(
              horizontal: _kCardPadH * s, vertical: _kCardPadV * s),
          // ⚠ دەبێت **دەقاودەق** وەک کارتی ڕاستەقینە بێت (`_kRCard` +
          // هێڵی موو + `_kCardLift`). ئەگەر سکێلیتۆنەکە گۆشە و سێبەری
          // جیاوازی هەبێت، لە ساتی هاتنی داتاکەدا کارتەکە دەبازێت.
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(_kRCard),
            border: Border.all(color: _kCardHairline, width: 1),
            boxShadow: _kCardLift,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ⚠ ئەم ژمارانە دەبێت دەقاودەق لەگەڵ کارتی ڕاستەقینەدا
                  // بگونجێن: ئەڤاتار 38، بۆشایی 10، دوو کرداری 38 dp.
                  _Bone(w: 36 * s, h: 36 * s, r: 11 * s),
                  SizedBox(width: 10 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(w: 110 * s, h: 11 * s, r: 5),
                        SizedBox(height: 7 * s),
                        _Bone(w: 70 * s, h: 9 * s, r: 5),
                      ],
                    ),
                  ),
                  SizedBox(width: 2 * s),
                  _Bone(w: 20 * s, h: 20 * s, r: 5),
                  SizedBox(width: 18 * s),
                  _Bone(w: 20 * s, h: 20 * s, r: 5),
                ],
              ),
              SizedBox(height: 12 * s),
              Row(
                children: [
                  _Bone(w: 58 * s, h: 22 * s, r: _kRChip),
                  SizedBox(width: 10 * s),
                  _Bone(w: 60 * s, h: 11 * s, r: 5),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double w, h, r;
  const _Bone({required this.w, required this.h, required this.r});
  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: _kPlaceholder,
          borderRadius: BorderRadius.circular(r),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// STYLE PREVIEWS — bundled, optimized, decoded at render size
// ═════════════════════════════════════════════════════════════════════════════
//
// The eight previews are local assets, so they cost ZERO mobile data after
// install and work fully offline. They were re-exported from the original
// ~1000 × 1667 PNGs (3.35 MB total) to 400 × 667 WebP (102 KB total) —
// still larger than the biggest size they ever paint at.
//
// `_v1` in the filename is the cache version: an AssetImage's cache key IS
// its path, so changing a preview later means shipping `<style>_v2.webp` and
// bumping this map — which invalidates only that one entry. There is no
// timestamp or random query anywhere, so a key is never accidentally unique.

const Map<PlStyle, String> _kStyleAsset = <PlStyle, String>{
  PlStyle.dark: 'assets/styles/dark_v1.webp',
  PlStyle.light: 'assets/styles/light_v1.webp',
  PlStyle.classic: 'assets/styles/classic_v1.webp',
  PlStyle.pill: 'assets/styles/pill_v1.webp',
  PlStyle.card: 'assets/styles/card_v1.webp',
  PlStyle.neon: 'assets/styles/neon_v1.webp',
  PlStyle.zoom: 'assets/styles/zoom_v1.webp',
  PlStyle.banner: 'assets/styles/banner_v1.webp',
};

class _StyleSelector extends StatefulWidget {
  final ValueNotifier<PlStyle> selected;
  const _StyleSelector({required this.selected});
  @override
  State<_StyleSelector> createState() => _StyleSelectorState();
}

class _StyleSelectorState extends State<_StyleSelector> {
  /// Built once per device configuration and reused for every rebuild, so
  /// the `Image` widgets keep receiving the *identical* provider instance
  /// and never re-resolve or re-decode.
  final Map<PlStyle, ImageProvider> _providers = {};
  int _decodeWidth = 0;
  bool _precacheScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final target = (_styleTileWidth(context) * dpr).round();
    if (target == _decodeWidth && _providers.isNotEmpty) return;

    _decodeWidth = target;
    _providers
      ..clear()
      ..addAll({
        for (final entry in _kStyleAsset.entries)
          entry.key: ResizeImage(
            AssetImage(entry.value),
            // Decode near the physical pixels actually painted (≈341 px on
            // a 3× phone) instead of the source bitmap. Full-resolution
            // decoding of all eight was ~53 MB of RAM; this is ~7 MB.
            width: target,
            allowUpscaling: false,
          ),
      });
    _precacheScheduled = false;
    _schedulePrecache();
  }

  /// Warms the cache AFTER the first frame, so nothing about this blocks
  /// first paint. They're local assets, so there is no network burst and no
  /// ordering to worry about — but they are still awaited one at a time so
  /// eight decodes never land on the same frame.
  void _schedulePrecache() {
    if (_precacheScheduled) return;
    _precacheScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final provider in _providers.values) {
        if (!mounted) return;
        try {
          await precacheImage(provider, context);
        } catch (_) {/* errorBuilder covers it at paint time */}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final viewportW = _styleViewportWidth(context);
    final itemW = _styleTileWidth(context);
    final imgH = itemW * (_kStyleSourceH / _kStyleSourceW);
    final labelH = 26 * _typeScale(s);

    return Center(
      child: SizedBox(
        width: viewportW,
        height: imgH + labelH,
        child: ScrollConfiguration(
          behavior: const _NoGlowBehavior(),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // A fixed extent means the list never measures children — one
            // less thing to do per scrolled frame.
            itemExtent: itemW + _kStyleGap * s,
            padding: const EdgeInsets.symmetric(horizontal: _kGutter),
            itemCount: PlStyle.values.length,
            itemBuilder: (_, i) {
              final style = PlStyle.values[i];
              return Padding(
                padding: EdgeInsetsDirectional.only(end: _kStyleGap * s),
                child: _StyleTile(
                  style: style,
                  provider: _providers[style],
                  selected: widget.selected,
                  width: itemW,
                  imageHeight: imgH,
                  onTap: () => widget.selected.value = style,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  final PlStyle style;
  final ImageProvider? provider;
  final ValueNotifier<PlStyle> selected;
  final double width, imageHeight;
  final VoidCallback onTap;
  const _StyleTile({
    required this.style,
    required this.provider,
    required this.selected,
    required this.width,
    required this.imageHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final radius = BorderRadius.circular(_kRTile);

    // Built ONCE here and passed to the builder below as its `child`, so
    // changing the selection rebuilds only the border and the label — the
    // image element is never rebuilt, re-resolved, or re-decoded.
    final Widget image = RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: imageHeight,
          child: provider == null
              ? const _PreviewFallback()
              : Image(
                  image: provider!,
                  width: width,
                  height: imageHeight,
                  // Source aspect equals this box's aspect, so `cover`
                  // neither stretches nor crops — it just fills cleanly.
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  frameBuilder: (_, child, frame, wasSync) {
                    // An already-cached image resolves synchronously: return
                    // it immediately with no fade, so scrolling back into
                    // view never flickers or restarts a placeholder.
                    if (wasSync || frame != null) return child;
                    return const _PreviewFallback();
                  },
                  errorBuilder: (_, __, ___) => const _PreviewFallback(),
                ),
        ),
      ),
    );

    return _Pressable(
      semanticLabel: style.nameKu,
      pressScale: 0.97,
      onTap: onTap,
      child: ValueListenableBuilder<PlStyle>(
        valueListenable: selected,
        builder: (context, value, child) {
          final isOn = value == style;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: width,
                height: imageHeight,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // ⚠ بوو شین. کەناری ستایلی هەڵبژێردراو مەرەکەبە —
                  // نیشانەی هەڵبژاردنە، نەک دوگمە.
                  border: Border.all(
                    color: isOn ? _kInk : _kLine,
                    width: isOn ? 2 : _kRule,
                  ),
                ),
                // Padding keeps the artwork inside the accent border so the
                // selected ring reads as a frame, not as a crop.
                padding: EdgeInsets.all(isOn ? 2 : _kRule),
                child: child,
              ),
              SizedBox(height: 6 * s),
              ProxoText(
                style.displayEn,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(
                  size: 11.5 * _typeScale(s),
                  weight: isOn ? FontWeight.w600 : FontWeight.w400,
                  color: isOn ? _kInk : _kSlate,
                  height: 1.2,
                ),
              ),
            ],
          );
        },
        child: image,
      ),
    );
  }
}

/// Placeholder AND error state. Same box, same radius, neutral fill — the
/// item can never collapse, shift the row, or show a broken-image glyph.
class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(color: _kPlaceholder),
        child: SizedBox.expand(),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// CREATE — پەڕەی نوێ زیادبکە
// ═════════════════════════════════════════════════════════════════════════════

class _FormView extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(Map<String, dynamic>) onCreated;
  const _FormView({required this.onClose, required this.onCreated, super.key});
  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _ttCtrl = TextEditingController();
  final _contactCtrls = <int, TextEditingController>{};

  /// Selection lives in notifiers rather than in setState, so picking a
  /// style or a colour repaints only that control — the style images and
  /// the rest of the form are never rebuilt.
  final _styleN = ValueNotifier<PlStyle>(PlStyle.dark);
  final _themeN = ValueNotifier<String>(kCardThemes.first.key);
  final _langN = ValueNotifier<CardLang>(CardLang.ku);

  XFile? _logo;
  String _logoB64 = '';
  final List<bool> _checked = [true, true, false, true, false, false];
  bool _errName = false, _errTT = false, _errPlatform = false, _errLogo = false;
  bool _isSaving = false;
  String? _statusLabel; // "پاشەکەوتکردن..." / "ناردن..."

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < kPlatformBtns.length; i++) {
      _contactCtrls[i] = TextEditingController();
    }
    // Clearing the logo error is the only thing style selection affects
    // outside the selector itself.
    _styleN.addListener(_onStyleChanged);
  }

  void _onStyleChanged() {
    if (_errLogo && !_styleN.value.requiresLogo) {
      setState(() => _errLogo = false);
    }
  }

  @override
  void dispose() {
    _styleN.removeListener(_onStyleChanged);
    _styleN.dispose();
    _themeN.dispose();
    _langN.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _ttCtrl.dispose();
    for (final c in _contactCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await File(file.path).readAsBytes();
    if (!mounted) return;
    setState(() {
      _logo = file;
      _logoB64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _errLogo = false;
    });
  }

  /// Numeric contact fields (WhatsApp / Viber / Phone / Asiacell) always
  /// normalize to a `9647XXXXXXXXX`-shaped number as the user types —
  /// mirrors the `oninput` handler on proxo-tools.js's own contact
  /// inputs for the same platform types.
  void _onNumericContactChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('9647')
        ? digits
        : '9647${digits.replaceFirst(RegExp(r'^9647?'), '')}';
    if (normalized == value) return;
    final ctrl = _contactCtrls[index]!;
    ctrl.value = ctrl.value.copyWith(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  /// Mirrors proxo-tools.js's `plValidateForm()`: name required, TikTok
  /// required, at least one filled platform required, and a profile
  /// image required for the styles that visually need one (dark/light/
  /// zoom/banner — see PlStyle.requiresLogo in html_generator.dart).
  bool _validate() {
    bool hasFilledPlatform = false;
    for (int i = 0; i < kPlatformBtns.length; i++) {
      if (_checked[i] && (_contactCtrls[i]?.text.trim().isNotEmpty ?? false)) {
        hasFilledPlatform = true;
        break;
      }
    }
    final nameEmpty = _nameCtrl.text.trim().isEmpty;
    final ttEmpty = _ttCtrl.text.trim().replaceAll('@', '').isEmpty;
    final noPlat = !hasFilledPlatform;
    final needsLogo = _styleN.value.requiresLogo && _logoB64.isEmpty;
    setState(() {
      _errName = nameEmpty;
      _errTT = ttEmpty;
      _errPlatform = noPlat;
      _errLogo = needsLogo;
    });
    if (nameEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          CustomToast.show(context, 'تکایە ناوت یان ناوی براندەکەت بنووسە'));
      return false;
    }
    if (ttEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => CustomToast.show(context, 'تکایە ناوی ئەکاونتی تیکتۆکت بنووسە'));
      return false;
    }
    if (needsLogo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => CustomToast.show(
          context, 'وێنەی پرۆفایل پێویستە بۆ ستایلی ${_styleN.value.nameKu}'));
      return false;
    }
    if (noPlat) {
      WidgetsBinding.instance.addPostFrameCallback((_) => CustomToast.show(
          context, 'تکایە کەمترین یەک پلاتفۆرم چالاک بکە و ژمارەکەی بنووسە'));
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate() || _isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _statusLabel = 'پاشەکەوتکردن...';
    });
    void snack(String msg, {bool error = false}) {
      if (!mounted) return;
      showProxoToast(context, msg,
          type: error ? ProxoToastType.error : ProxoToastType.success);
    }

    final name = _nameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    final tt = _ttCtrl.text.trim().replaceAll('@', '');
    final style = _styleN.value;
    final lang = _langN.value;
    final theme = themeByKey(_themeN.value);
    final contacts = <int, String>{
      for (int i = 0; i < kPlatformBtns.length; i++)
        i: _contactCtrls[i]?.text.trim() ?? '',
    };
    final platforms = <String, String>{};
    for (int i = 0; i < kPlatformBtns.length; i++) {
      if (!_checked[i]) continue;
      final val = contacts[i] ?? '';
      if (val.isNotEmpty) platforms[kPlatformBtns[i].id] = val;
    }

    // 1-2. VALIDATE (above) + GENERATE — the one and only generator, exactly
    // as before. Nothing about the produced HTML changed in this redesign.
    final html = buildCardHtml(
      name: name,
      bio: bio,
      tt: tt,
      logoB64: _logoB64,
      themeKey: theme.key,
      style: style,
      checked: _checked,
      contacts: contacts,
      lang: lang,
    );

    // 3. FILENAME from the user's name.
    final filename = sanitizeFilenameFromName(name);

    // 4. SAVE TEMPORARILY. Non-fatal if this fails (e.g. constrained
    // storage) — we still hold `html` in memory for steps 5-6.
    try {
      final dir = await getTemporaryDirectory();
      await File('${dir.path}/$filename').writeAsString(html);
    } catch (_) {/* ignore — see note above */}

    String? supabaseId;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          CustomToast.show(context, 'تکایە دووبارە بچۆ ژوورەوە');
          setState(() {
            _isSaving = false;
            _statusLabel = null;
          });
        }
        return;
      }
      final lastCard = await supabase
          .from('proxolink_cards')
          .select('card_number')
          .order('card_number', ascending: false)
          .limit(1)
          .maybeSingle();
      final cardNumber = ((lastCard?['card_number'] as num?)?.toInt() ?? 0) + 1;
      final res = await supabase.from('proxolink_cards').insert({
        'user_id': user.id,
        'name': name,
        'bio': bio,
        // The website writes the handle to `tt`; we also mirror it into
        // the older `tiktok` column so nothing that still reads that
        // column breaks. Same idea for avatar_b64/logo_b64 below.
        'tt': tt.isNotEmpty ? tt : null,
        'tiktok': tt.isNotEmpty ? tt : null,
        'style': style.nameEn,
        'color_theme': theme.key, // named key — matches the website
        'platforms': platforms,
        'avatar_b64': _logoB64.isNotEmpty ? _logoB64 : null,
        'logo_b64': _logoB64.isNotEmpty ? _logoB64 : null,
        'html_content': html,
        'checked_btns': _checked,
        'card_number': cardNumber,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();
      supabaseId = res['id']?.toString();
    } catch (_) {
      // Real failure: nothing was saved. Preserve the form exactly as
      // the user left it and let them retry.
      if (mounted) {
        CustomToast.show(
            context, 'پەیوەندی ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵ بدەرەوە');
        setState(() {
          _isSaving = false;
          _statusLabel = null;
        });
      }
      return;
    }

    // 5. SEND to the Cloudflare Worker, which forwards it to Telegram as
    // an actual .html document (no bot token in this client — see
    // telegram_delivery_service.dart).
    if (mounted) setState(() => _statusLabel = 'ناردن...');
    final userEmail = supabase.auth.currentUser?.email ?? '';
    final captionBuf = StringBuffer();
    captionBuf.writeln('🔗 ProxoLink — کەرەستەی نوێ');
    captionBuf.writeln('👤 ناو: $name');
    if (userEmail.isNotEmpty) captionBuf.writeln('📧 ئیمێڵ: $userEmail');
    if (tt.isNotEmpty) captionBuf.writeln('🎵 تیکتۆک: @$tt');
    captionBuf.writeln('🎨 ستایل: ${style.nameKu} / ${theme.key}');
    if (supabaseId != null) captionBuf.writeln('🆔 ID: $supabaseId');

    final delivery = await TelegramDeliveryService.sendHtmlDocument(
      htmlContent: html,
      filename: filename,
      caption: captionBuf.toString(),
    );

    // 6. SHOW SUCCESS/FAILURE. The card itself is already safely saved
    // in Supabase at this point regardless of the Telegram result, so a
    // delivery-notification hiccup is surfaced as a warning rather than
    // treated as an overall failure that would force the user to redo
    // the whole form.
    if (delivery.success) {
      snack('✅ کەرەستەکە دروستکرا و نێردرا');
    } else {
      snack('⚠️ کەرەستەکە پاشەکەوتکرا، بەڵام ناردنی تیلیگرام سەرکەوتوو نەبوو',
          error: true);
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _statusLabel = null;
    });
    widget.onCreated({
      'id': supabaseId,
      'name': name,
      'bio': bio,
      'tiktok': tt,
      'theme': theme.swatch,
      'themeKey': theme.key,
      'style': style,
      'logo': _logo,
      'logoB64': _logoB64,
      'checked': List<bool>.from(_checked),
      'platforms': platforms,
      'html_content': html,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _pickBioSample() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _BioSampleSheet(),
    );
    if (picked != null && mounted) {
      _bioCtrl.text = picked;
      _bioCtrl.selection =
          TextSelection.collapsed(offset: _bioCtrl.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);

    return Column(
      children: [
        _ToolsTopBar(title: _kTxtCreateTitle, onClose: widget.onClose),
        Expanded(
          child: GestureDetector(
            // Tapping any dead space puts the keyboard away.
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: ScrollConfiguration(
              behavior: const _NoGlowBehavior(),
              child: ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                    top: _kGapSection * s, bottom: _bottomGap(context)),
                children: [
                  // ── 1. STYLE ────────────────────────────────────────────
                  // The selector sits outside the horizontal gutter on
                  // purpose: it scrolls edge to edge and supplies its own.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _kGutter),
                    child: _capped(const _SectionLabel('ستایلی پەڕە هەڵبژێرە')),
                  ),
                  _StyleSelector(selected: _styleN),
                  SizedBox(height: _kGapSection * s),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _kGutter),
                    // Apply the page gutter before the max-width cap.  The
                    // previous order subtracted 16 dp twice and left every
                    // field and the CTA only 329 dp wide on a 393 dp phone.
                    child: _capped(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // ── 2. NAME ─────────────────────────────────────
                        const _FieldLabel('ناوی براند', required: true),
                        _Field(
                          controller: _nameCtrl,
                          hint: 'ناوی پەڕە یان براند',
                          hasError: _errName,
                          onChanged: (_) {
                            if (_errName) setState(() => _errName = false);
                          },
                        ),
                        if (_errName)
                          const ProxoFieldError(text: 'تکایە ناوت بنووسە'),
                        SizedBox(height: _kGapField * s),

                        // ── 3. BIO ──────────────────────────────────────
                        Row(
                          children: [
                            const _FieldLabel('وتەی کورت'),
                            const Spacer(),
                            _TextAction(
                                label: 'نموونەیەک هەڵبژێرە',
                                onTap: _pickBioSample),
                          ],
                        ),
                        _Field(
                          controller: _bioCtrl,
                          hint: 'پەیوەندیمان پێوە بکە',
                          maxLength: 150,
                          multiline: true,
                        ),
                        SizedBox(height: 6 * s),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: AnimatedBuilder(
                            // Only the counter repaints per keystroke — the
                            // form itself never rebuilds while typing.
                            animation: _bioCtrl,
                            builder: (_, __) => ProxoText(
                              '${_bioCtrl.text.length} / 150',
                              textDirection: TextDirection.ltr,
                              style: _t(
                                  size: _kFsMeta * t,
                                  color: _kMuted,
                                  height: 1.2),
                            ),
                          ),
                        ),
                        SizedBox(height: (_kGapField - 6 - _kFsMeta * 1.2) * s),

                        // ── 4. TIKTOK ───────────────────────────────────
                        const _FieldLabel('تیکتۆک', required: true),
                        _Field(
                          controller: _ttCtrl,
                          hint: 'username',
                          ltr: true,
                          prefix: '@',
                          hasError: _errTT,
                          onChanged: (_) {
                            if (_errTT) setState(() => _errTT = false);
                          },
                        ),
                        if (_errTT)
                          const ProxoFieldError(
                              text: 'تکایە ناوی ئەکاونتی تیکتۆکت بنووسە'),
                        SizedBox(height: _kGapField * s),

                        // ── 5. LOGO ─────────────────────────────────────
                        const _FieldLabel('لۆگۆ'),
                        _LogoField(
                          logo: _logo,
                          hasError: _errLogo,
                          onTap: _pickLogo,
                        ),
                        if (_errLogo)
                          const ProxoFieldError(
                              text: 'لۆگۆ پێویستە بۆ ئەم ستایلە'),
                        SizedBox(height: _kGapSection * s),

                        // ── 6. PLATFORMS ────────────────────────────────
                        const _SectionLabel(
                          'پلاتفۆرمی پەیوەندی هەڵبژێرە',
                          subtitle:
                              'ئەو ڕێگایانەی دەتەوێ بینەران پەیوەندیت پێوە بکەن',
                        ),
                        _PlatformGrid(
                          checked: _checked,
                          onToggle: (i, v) => setState(() {
                            _checked[i] = v;
                            _errPlatform = false;
                          }),
                        ),
                        if (_errPlatform)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: ProxoFieldError(
                                text: 'کەمترین یەک پلاتفۆرم پڕ بکەرەوە'),
                          ),

                        // ── 7. CONTACT VALUES ───────────────────────────
                        // Values stay in their controller when a platform is
                        // switched off, so re-selecting restores exactly what
                        // was typed.
                        ...List.generate(kPlatformBtns.length, (i) {
                          if (!_checked[i]) return const SizedBox.shrink();
                          final p = kPlatformBtns[i];
                          return Padding(
                            key: ValueKey('contact_${p.id}'),
                            padding: EdgeInsets.only(top: _kGapRow * s),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(p.label),
                                _Field(
                                  controller: _contactCtrls[i]!,
                                  hint: p.placeholder,
                                  ltr: true,
                                  keyboard: p.isNumeric
                                      ? TextInputType.phone
                                      : TextInputType.text,
                                  onChanged: p.isNumeric
                                      ? (v) => _onNumericContactChanged(i, v)
                                      : null,
                                ),
                              ],
                            ),
                          );
                        }),

                        // ── 8. COLOUR + LANGUAGE ────────────────────────
                        // Placed just before the CTA, where the reference
                        // puts its own theme selector.
                        SizedBox(height: _kGapSection * s),
                        const _FieldLabel('تەم هەڵبژێرە'),
                        _ThemeDots(selected: _themeN),
                        SizedBox(height: _kGapField * s),
                        const _FieldLabel('زمانی پەڕە'),
                        _LangToggle(selected: _langN),

                        // ── 9. CTA ──────────────────────────────────────
                        SizedBox(height: _kGapControl * s),
                        _PrimaryButton(
                          label: 'دروستکردن',
                          busyLabel: _statusLabel,
                          busy: _isSaving,
                          onTap: _submit,
                        ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FORM CONTROLS — one input design, used by every field on the screen
// ═════════════════════════════════════════════════════════════════════════════

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final bool ltr, hasError;
  final int? maxLength;

  /// `true` renders the 80 dp top-aligned box the reference uses for
  /// «وتەی کورت»; `false` renders the 48 dp single-line field.
  final bool multiline;
  final TextInputType? keyboard;
  final void Function(String)? onChanged;
  const _Field({
    required this.controller,
    required this.hint,
    this.prefix,
    this.ltr = false,
    this.hasError = false,
    this.maxLength,
    this.multiline = false,
    this.keyboard,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    final h = (multiline ? _kAreaH : _kFieldH) * s;

    // 132 px tall with one 16 dp line inside it → 12.8 dp above and below.
    // Derived, not chosen: (48 − 16 × 1.40) / 2.
    final padV = multiline ? 11.6 * s : (_kFieldH - _kFsInput * _kLineH) / 2 * s;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kR),
      borderSide:
          BorderSide(color: hasError ? _kDanger : _kFillBorder, width: _kRule),
    );

    return SizedBox(
      height: h,
      child: ProxoDirectionalInput(
        controller: controller,
        keyboardType:
            keyboard ?? (multiline ? TextInputType.multiline : TextInputType.text),
        forceLtr: ltr,
        builder: (context, inputDirection) => TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: multiline ? null : 1,
          expands: multiline,
          onChanged: onChanged,
          textDirection: inputDirection,
          // Latin handles / phone numbers stay left-aligned and readable even
          // inside the RTL screen; Kurdish text stays right-aligned.
          textAlign: TextAlign.start,
          textAlignVertical: multiline
              ? TextAlignVertical.top
              : TextAlignVertical.center,
          keyboardType:
              keyboard ??
              (multiline ? TextInputType.multiline : TextInputType.text),
          textInputAction: multiline
              ? TextInputAction.newline
              : TextInputAction.next,
          // شینی فۆکەس و کێرسەر دەمێننەوە: `AuthTextField` هەمان شت دەکات
          // (`focusedBorder: AuthTokens.accent`). ئەمە کەنارە، نەک ڕوو.
          cursorColor: _kAccent,
          style: _t(size: _kFsInput * t),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hint: proxoFieldText(hint),
            hintTextDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            // ⚠ جێگرەوە بوو #64748B — هەمان تۆخی ژێرناوەکان، بۆیە خانەی
            // بەتاڵ وەک خانەیەکی پڕکراوە دەخوێندرایەوە. ئێستا #94A3B8،
            // دەقاودەق `AuthTokens.placeholder`.
            hintStyle: _t(size: _kFsInput * t, color: _kMuted),
            prefix: proxoFieldText(prefix),
            prefixStyle: _t(size: _kFsInput * t, color: _kMuted),
            filled: true,
            fillColor: hasError ? _kFillErr : _kFill,
            contentPadding: EdgeInsets.symmetric(
              horizontal: _kGutter * s,
              vertical: padV,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kR),
              borderSide: BorderSide(
                color: hasError ? _kDanger : _kAccent,
                width: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reference's 3 × 2 platform picker: filled accent card when selected,
/// near-white card when not. Tapping toggles; the value field for a selected
/// platform appears below the grid.
class _PlatformGrid extends StatelessWidget {
  final List<bool> checked;
  final void Function(int, bool) onToggle;
  const _PlatformGrid({required this.checked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    return LayoutBuilder(
      builder: (context, c) {
        final gap = _kPlatGap * s;
        // Floor the width so three cards + two gaps can never exceed the
        // row and overflow on a 320 dp phone.
        final cardW =
            ((c.maxWidth - gap * (_kPlatCols - 1)) / _kPlatCols).floorToDouble();
        final rows = (kPlatformBtns.length / _kPlatCols).ceil();
        return Column(
          children: List.generate(rows, (r) {
            return Padding(
              padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
              // A Row with crossAxisAlignment.stretch cannot receive an
              // unbounded height from the page's vertical ListView.  That
              // produced a layout exception and left the whole form area
              // blank.  IntrinsicHeight resolves the row's natural height
              // first, then gives stretch a finite value so cards with a
              // wrapped label still stay equal-height.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(_kPlatCols, (col) {
                    final i = r * _kPlatCols + col;
                    return Padding(
                      padding: EdgeInsetsDirectional.only(
                          end: col == _kPlatCols - 1 ? 0 : gap),
                      child: SizedBox(
                        width: cardW,
                        child: i >= kPlatformBtns.length
                            ? SizedBox(height: _kPlatMinH * s)
                            : _PlatformCard(
                                platform: kPlatformBtns[i],
                                selected: checked[i],
                                onTap: () => onToggle(i, !checked[i]),
                                scale: s,
                              ),
                      ),
                    );
                  }),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final PlatformBtn platform;
  final bool selected;
  final VoidCallback onTap;
  final double scale;
  const _PlatformCard({
    required this.platform,
    required this.selected,
    required this.onTap,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = _typeScale(s);

    // ⚠ دۆخی هەڵبژێردراو بوو: **ڕووی شینی ڕەق + دەقی سپی**. ئەوە دقیقەن
    // ئەو شتەیە کە قەدەغەکراوە — ڕووێکی شین لەسەر کارتێکی گرید. شین ئێستا
    // تەنها لە دوو دوگمەی کردار ماوەتەوە.
    //
    // دۆخی نوێ: ڕووی سپی + کەناری مەرەکەبی 1.5 dp + ئایکۆن و دەقی مەرەکەب.
    // نەهەڵبژێردراو: ڕووی #F8FAFC + کەناری #E2E8F0 + ئایکۆنی سلەیت.
    // جیاوازی ڕوونە (ڕوو + کەنار + تۆخی ئینک پێکەوە دەگۆڕێن) بەبێ ئەوەی
    // پێویستی بە هیچ شینێک بێت.
    final Color fg   = selected ? _kInk : _kSlate;
    final Color line = selected ? _kInk : _kFillBorder;

    return _Pressable(
      semanticLabel: platform.label,
      pressScale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        // A floor, not a fixed height, so a 2-line label can still grow it.
        constraints: BoxConstraints(minHeight: _kPlatMinH * s),
        decoration: BoxDecoration(
          color: selected ? _kSurface : _kFill,
          borderRadius: BorderRadius.circular(_kR),
          border: Border.all(color: line, width: selected ? 1.5 : _kRule),
        ),
        padding: EdgeInsets.fromLTRB(
            6 * s, _kPlatPadV * s, 6 * s, _kPlatPadV * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(_platformIcon(platform.id), size: _kPlatIcon * s, color: fg),
            SizedBox(height: _kPlatIconGap * s),
            ProxoText(
              platform.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: _t(
                size: _kFsPlatform * t,
                weight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? _kInk : _kSlate,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo drop area. 461 px tall (168 dp), #FBFCFE, a 2 dp dashed #E2E8EE
/// outline with a 4.0 / 1.7 dp dash, and a 48 dp #CBEADA circle — every
/// number sampled from the reference.
class _LogoField extends StatelessWidget {
  final XFile? logo;
  final bool hasError;
  final VoidCallback onTap;
  const _LogoField(
      {required this.logo, required this.hasError, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

    return _Pressable(
      semanticLabel: 'لۆگۆ',
      pressScale: 0.985,
      onTap: onTap,
      child: CustomPaint(
        // foregroundPainter, NOT painter: `painter` draws *behind* the child,
        // and the child is an opaque rounded fill at exactly these bounds —
        // it would cover the dashes completely.
        foregroundPainter: _DashedRRectPainter(
          color: hasError ? _kDanger : _kDash,
          radius: _kR,
          dash: 4.0 * s,
          gap: 1.7 * s,
          strokeWidth: 2.0 * s,
        ),
        child: Container(
          height: _kLogoH * s,
          decoration: BoxDecoration(
            color: hasError ? _kFillErr : _kLogoFill,
            borderRadius: BorderRadius.circular(_kR),
          ),
          alignment: Alignment.center,
          child: logo == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _kLogoCircle * s,
                      height: _kLogoCircle * s,
                      decoration: const BoxDecoration(
                          color: _kGreenSoft, shape: BoxShape.circle),
                      child: Icon(Icons.image_outlined,
                          size: _kLogoGlyph * s, color: _kGreen),
                    ),
                    SizedBox(height: _kLogoGap1 * s),
                    ProxoText('لۆگۆ باربکە',
                        style: _t(
                            size: _kFsLogoT * t,
                            weight: FontWeight.w600,
                            height: 1.2)),
                    SizedBox(height: _kLogoGap2 * s),
                    ProxoText('کرتە بکە یان ڕابکێشە',
                        style: _t(
                            size: _kFsLogoS * t,
                            color: _kSlate,
                            height: 1.2)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_kR - 4),
                      child: Image.file(
                        File(logo!.path),
                        width: 80 * s,
                        height: 80 * s,
                        fit: BoxFit.cover,
                        cacheWidth: (80 * s * dpr).round(),
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            size: 26 * s,
                            color: _kSlate),
                      ),
                    ),
                    SizedBox(height: _kLogoGap1 * s),
                    // ⚠ بوو شین. ئەمە ژێرنووسی ڕێنمایییە، نەک لینک.
                    ProxoText('کرتە بکە بۆ گۆڕین',
                        style: _t(
                            size: _kFsLogoS * t,
                            weight: FontWeight.w600,
                            color: _kSlate,
                            height: 1.2)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Flutter has no dashed border, so the logo field's outline is painted.
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius, dash, gap, strokeWidth;
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          math.max(0.0, size.width - strokeWidth),
          math.max(0.0, size.height - strokeWidth)),
      Radius.circular(radius),
    );

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth;
}

/// Card colour — eight dots, accent ring on the selected one.
class _ThemeDots extends StatelessWidget {
  final ValueNotifier<String> selected;
  const _ThemeDots({required this.selected});

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    return ValueListenableBuilder<String>(
      valueListenable: selected,
      builder: (_, value, __) => Wrap(
        spacing: 12 * s,
        runSpacing: 12 * s,
        children: kCardThemes.map((theme) {
          final isOn = theme.key == value;
          return _Pressable(
            semanticLabel: theme.key,
            onTap: () => selected.value = theme.key,
            child: Container(
              width: 34 * s,
              height: 34 * s,
              padding: EdgeInsets.all(isOn ? 3 * s : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ⚠ بوو شین. خەڵەکەکە نیشانەی هەڵبژاردنە لەسەر خاڵی ڕەنگ.
                border: Border.all(
                  color: isOn ? _kInk : Colors.transparent,
                  width: isOn ? 2 : 0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kLine, width: _kRule),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Language of the text ON the generated page (Kurdish / Arabic).
class _LangToggle extends StatelessWidget {
  final ValueNotifier<CardLang> selected;
  const _LangToggle({required this.selected});

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    return ValueListenableBuilder<CardLang>(
      valueListenable: selected,
      builder: (_, value, __) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _kFill,
          borderRadius: BorderRadius.circular(_kR),
          border: Border.all(color: _kFillBorder, width: _kRule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: CardLang.values.map((lang) {
            final isOn = lang == value;
            return GestureDetector(
              onTap: () => selected.value = lang,
              // ⚠ پیلی هەڵبژێردراو بوو شین. سویچی بەشەکراو دوگمەی کردار
              // نییە — دوو دۆخی هەمان کۆنترۆڵە. ئێستا مەرەکەبی تۆخ
              // لەگەڵ دەقی سپی، هەروەک `AuthSegmentedControl`.
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    EdgeInsets.symmetric(horizontal: 18 * s, vertical: 7 * s),
                decoration: BoxDecoration(
                  color: isOn ? _kInk : Colors.transparent,
                  borderRadius: BorderRadius.circular(_kR - 3),
                ),
                child: ProxoText(
                  lang.label,
                  style: _t(
                    size: _kFsPlatform * t,
                    weight: FontWeight.w600,
                    color: isOn ? Colors.white : _kSlate,
                    height: 1.2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// A plain accent text link — used instead of a decorated helper row.
/// شینەکە لێرە ڕێپێدراوە: دەقی لینکە لەسەر ڕووی سپی، هەمان ڕەفتاری
/// `AuthTextLink`. هیچ ڕووێکی شینی نییە.
class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextAction({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
          child: ProxoText(
            label,
            style: _t(
              size: 11.5 * _typeScale(_scaleFor(context)),
              weight: FontWeight.w600,
              color: _kAccent,
              height: 1.2,
            ),
          ),
        ),
      );
}

/// The ten ready-made bio lines, moved out of the form into a sheet so the
/// Create screen isn't ten decorated rows longer than it needs to be.
class _BioSampleSheet extends StatelessWidget {
  const _BioSampleSheet();

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    final t = _typeScale(s);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(10),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(_kRList),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(18, 16 * s, 18, 12 * s),
                child: ProxoText('نموونەکان',
                    style: _t(
                        size: _kFsSection * t,
                        weight: FontWeight.w600)),
              ),
              const Divider(
                  height: _kRule, thickness: _kRule, color: _kHairline),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(vertical: 6 * s),
                  itemCount: kBioChips.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: _kRule,
                      thickness: _kRule,
                      color: _kHairline,
                      indent: 18,
                      endIndent: 18),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => Navigator.pop(context, kBioChips[i]),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 13 * s),
                      child: ProxoText(
                        kBioChips[i],
                        style: _t(
                            size: _kFsLogoS * t,
                            color: _kSlate,
                            height: 1.7),
                      ),
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

/// The one CTA for this module — a DIRECT copy of `AuthPrimaryButton`.
///
/// ⚠ پێشتر: بەرزایی 56، گۆشەی 20، `LinearGradient`ی دوو ستۆپ، سێبەرێکی
/// قووڵی `rgba(15,23,42,.22)` بە بلوری 20 و ئۆفسێتی (0,8)، و دەقی
/// 16 × bump ≈ 17 بە w600. هیچ کامیان لە `auth_screen`دا نەبوون.
///
/// ئێستا دەقاودەق: 48 dp بەرزایی · گۆشەی 12 · ڕووی ڕەقی #0265FF ·
/// دەقی 14.5 / w700 / سپی · بێ سێبەر · بێ گرادیێنت.
/// هەموو ناوەڕۆکی ناوەوە (دەق، سپینەر) سپیی ڕەقە.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final String? busyLabel;
  final bool busy;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.busyLabel,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = _scaleFor(context);
    // بەرزایی، گۆشە و قەبارەی دەق بە `s`/`t` لێک نادرێنەوە: ئەمانە
    // ئامانجی دەقاودەقی
    // `auth_screen`ن. ئەگەر لێکیان بدەینەوە، دوگمەی ئەم شاشەیە لەسەر
    // تەلەفۆنی 412 dp دەبێتە 50.9 dp لە کاتێکدا دوگمەی چوونەژوورەوە
    // هەر 48 دەمێنێتەوە — و دووبارە ناتەبا دەبن.
    return Opacity(
      opacity: busy ? 0.72 : 1.0,
      child: Center(
        // ⚠ `ConstrainedBox` نەک `SizedBox(width: _kBtnMaxW)`: لەسەر
        // تەلەفۆنێکی 320 dp، ستوونی ناوەڕۆک لە 300 تەسکترە، بۆیە پانییەکی
        // چەسپاو سەرڕێژ دەبوو. ئەمە دەڵێت «تا 300، بەڵام هەرگیز زیاتر
        // لەوەی باوکەکە ڕێی پێدەدات».
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kBtnMaxW),
          child: SizedBox(
            width: double.infinity,
            height: _kCtaH,
            child: Material(
              color: _kBtnBg,
              borderRadius: BorderRadius.circular(_kBtnRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy ? null : onTap,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy) ...[
                        SizedBox(
                          width: 15 * s,
                          height: 15 * s,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2.2, color: _kBtnFg),
                        ),
                        SizedBox(width: 9 * s),
                      ],
                      Flexible(
                        child: Padding(
                          // پەدینگی ئاسۆیی کە دەق لە لێواری دوگمەکە
                          // دوور دەخاتەوە بەبێ ئەوەی دوگمەکە پان بکاتەوە.
                          padding: EdgeInsets.symmetric(horizontal: 14 * s),
                          child: ProxoText(
                            busy ? (busyLabel ?? 'چاوەڕوان بە...') : label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                              size: _kFsCta,
                              weight: FontWeight.w700,
                              color: _kBtnFg,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ],
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
