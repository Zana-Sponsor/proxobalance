import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FaqScreen — پرسیارە دووبارەکان
//
// شاشەیەکی سەربەخۆیە کە لە کارتی «پرسیارە دووبارەکان»ی پەڕەی سەرەکییەوە
// دەکرێتەوە. هیچ شتێکی نوێی دیزاین لێرە دانەنراوە: هەموو ژمارەکان لە
// شاشەکانی ئێستاوە هاتوون.
//
// ── SOURCE OF TRUTH FOR EVERY NUMBER BELOW ──────────────────────────────────
//   بار (بەرزایی، پادینگ، هێڵی مووی ژێری، قەبارەی گلیف، ستایلی ناونیشان)
//       = `_TopBar` لە `ad_details.dart` (کە خۆی = `ProxoTopBar`).
//   سکەیڵ (`_scaleFor` / `_typeScale`)
//       = `ad_details.dart`، کە خۆی = `_campaignScaleFor`ی `ad_screen.dart`.
//   گەتەر، سنووری پانی ناوەڕۆک، پادینگی خوارەوەی سکڕۆڵ
//       = `ad_details.dart` (`_kGutter` / `_kContentMaxWidth`).
//   سنوور و سێبەری کارت
//       = تۆکنە هاوبەشەکانی `app_theme.dart` — `kProxoCardBorder`,
//         `kProxoCardBorderWidth`, `kProxoCardShadow`. هیچ کۆپییەکی ئەو
//         نرخانە لێرە دانەنراوە.
//   ڕادیوس و پادینگ و بۆشایی کارت
//       = کارتەکانی Quick Actionی `home_screen.dart` (18 / 16 / 14 / 12) —
//         ئەم شاشەیە لەوێوە دەکرێتەوە، بۆیە هەمان قەبارەی کارتی هەیە.
//   فۆنت و زیادکردنی کوردی (`_kKuBump`)
//       = Rabar + 1.06، هەمان `ad_details.dart` و `ad_screen.dart`.
//   مۆشن (کردنەوە/داخستن)
//       = ئەکۆردیۆنی ئێستای `ad_screen.dart`: چیڤرۆن 280ms easeInOut،
//         بەرزایی 300ms easeOutCubic.
//
// وەک `ad_details.dart` ڕوونی کردووەتەوە، تۆکنەکانی ئەو فایلانە
// library-private ن و ناتوانرێن ئیمپۆرت بکرێن، بۆیە لێرەش دووبارە
// کراونەتەوە و هەریەکەیان ناوی سەرچاوەکەی لەگەڵدایە. ئەگەر یەکێکیان
// گۆڕا، ئەمەشیان بگۆڕە.
// ─────────────────────────────────────────────────────────────────────────────

// ═════════════════════════════════════════════════════════════════════════════
// FAQ CONTENT — ئەمە تەنها شوێنی گۆڕینی پرسیار و وەڵامەکانە
// ═════════════════════════════════════════════════════════════════════════════
// هەموو دەقەکان لێرەن. بۆ زیادکردن/لابردن/گۆڕین تەنها ئەم لیستە دەستکاری
// بکە — هیچ ویجێتێک دەستکاری ناوێت. ڕیزبەندی لیستەکە = ڕیزبەندی پیشاندان.
//
// ⚠ ئێستا لۆکاڵە. هیچ خشتەیەکی FAQ لە Supabase نییە، بۆیە هیچ بەستنەوەیەکی
// باکئێند نەکراوە (وەک داواکراو).

/// یەک پرسیار + وەڵامەکەی.
class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

const List<FaqItem> kFaqItems = <FaqItem>[
  FaqItem(
    question: 'چۆن کەمپەینی نوێ دروست بکەم؟',
    answer: 'لە پەڕەی سەرەکی، کارتی «کەمپەینی نوێ» هەڵبژێرە یان لە باری '
        'خوارەوە دوگمەی ناوەڕاست دابگرە. پاشان زانیاریەکانی ڕیکلامەکەت '
        'پڕ بکەرەوە و بینێرە.',
  ),
  FaqItem(
    question: 'کەمپەینەکەم چەند کات دەخایەنێت تا پەسەند بکرێت؟',
    answer: 'زۆربەی کەمپەینەکان لە ماوەی چەند کاتژمێرێکدا پێداچوونەوەیان '
        'بۆ دەکرێت. دوای پەسەندکردن، دۆخی ڕیکلامەکەت دەبێتە «چالاک» و '
        'ئاگادارییەکت بۆ دەنێردرێت.',
  ),
  FaqItem(
    question: 'چۆن دەتوانم دۆخی ڕیکلامەکەم ببینم؟',
    answer: 'لە باری خوارەوە بەشی «کەمپەینەکان» بکەرەوە. لەوێ هەموو '
        'ڕیکلامەکانت لەگەڵ دۆخیان دەبینیت، و بە کلیک لەسەر هەر یەکێکیان '
        'وردەکاری تەواو و ئامارەکانی دەبینیت.',
  ),
  FaqItem(
    question: 'ئامرازی پەیوەندی چییە؟',
    answer: 'ئامرازێکە بۆ دروستکردنی لاندینگ پەیجێکی پەیوەندی — لینکێکی '
        'تایبەت کە کڕیارەکانت بە ئاسانی لە ڕێگەیەوە پەیوەندیت پێوە دەکەن. '
        'لە پەڕەی سەرەکی یان بەشی «ئامرازەکان» دەیدۆزیتەوە.',
  ),
  FaqItem(
    question: 'چۆن دەتوانم پەیوەندی بە پشتگیری بکەم؟',
    answer: 'لە بەشی «پڕۆفایل» ← «پشتگیری» دەتوانیت ڕاستەوخۆ پەیوەندیمان '
        'پێوە بکەیت. تیمەکەمان ئامادەیە بۆ یارمەتیدانت.',
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
// TOKENS — mirrored, with the file each one comes from
// ═════════════════════════════════════════════════════════════════════════════

// ── Palette — هەمووی لە تۆکنە سیمانتیکەکانی `app_theme.dart`ـەوە ────────────
const Color _kPageBg   = AppColors.surfaceBase;   // = home / ad_details page
const Color _kCardBg   = AppColors.surfaceCard;
const Color _kInk      = AppColors.ink;           // = home Quick Action title
const Color _kSubtle   = AppColors.inkMuted;      // = home Quick Action subtitle
const Color _kHairline = AppColors.surfaceHairline;
const Color _kBarLine  = Color(0xFFF2F3F5);       // = ProxoTopBar._hairline
                                                  //   (= `_kBarLine` in ad_details)

// ── Geometry ────────────────────────────────────────────────────────────────
const double _kGutter        = 18.0; // = _kGutter (ad_details) — never scaled
const double _kContentMaxW   = 398.0; // = _kContentMaxWidth (ad_details)
const double _kRule          = 1.0;  // = _dsRule — never scaled
const double _kBarHeight     = 56.0; // = ProxoTopBar._contentHeight
const double _kBarTap        = 44.0; // = _kBarTap — both ≥ the 44 dp minimum
const double _kBarBackIcon   = 25.0; // = _kBarBackIcon (ad_details chevron)

/// بۆشایی نێوان هێڵی مووی بار و یەکەم کارت. لە `_kTopGap`ی `ad_details`
/// (34) بچووکترە چونکە لەوێ دەقێکی ساردە کە دەبێت لە بار جیا بکرێتەوە،
/// لێرە یەکەم شت کارتێکی سنووردارە کە خۆی جیای دەکاتەوە.
const double _kTopGap        = 22.0;

/// کارتی پرسیار — دەقاودەق قەبارەی کارتەکانی Quick Actionی پەڕەی سەرەکی،
/// چونکە ئەم شاشەیە لە یەکێک لەوان دەکرێتەوە.
const double _kCardRadius    = 18.0; // = _kQaRadius   (home_screen)
const double _kCardPadH      = 16.0; // = _kQaPadH     (home_screen)
const double _kCardPadV      = 14.0; // = _kQaPadV     (home_screen)
const double _kCardGap       = 12.0; // = _kQaGapCard  (home_screen)
const double _kChevron       = 20.0; // = `_RangePill`ی home_screen
const double _kChevronGap    = 10.0; // پرسیار → چیڤرۆن
const double _kAnswerGap     = 12.0; // هێڵی موو → وەڵام

// ── Type ramp ───────────────────────────────────────────────────────────────
// Rabar، هەمان ستراتیژی قورسایی: پرسیار w500 (= ناونیشانی کارتی Quick
// Action)، وەڵام w400. هیچ شتێک لەم شاشەیەدا لە w500 قورستر نییە.
const String _kFont       = kAppFont;
const double _kKuBump     = kKuFontBump; // §8: تاقە سەرچاوە — app_theme.dart
const double _kFsBarTitle = 15.0; // in-page bar title (sectionHeading tier);
                                   // ad_details.dart's own bar title has since
                                   // drifted to 20 — flagging, not resolving
                                   // here since that screen is out of scope
                                   // this round
const double _kFsQuestion = 14.0; // was 13.8 (reverse-engineered from the old
                                   // ×1.06 Rabar bump: 13.8×1.06≈14.6). Now
                                   // that kKuFontBump=1.00 that arithmetic no
                                   // longer applies, so re-based directly on
                                   // the cardTitle tier (14) instead of
                                   // silently rendering ~5% smaller than
                                   // originally intended.
const double _kFsAnswer   = 13.0; // was 12.4, same stale ×1.06 math as above
                                   // (12.4×1.06≈13.1) — re-based on the body
                                   // tier (13) directly
const double _kLhBarTitle = 1.16; // was 1.30 — single-line, ellipsized, so
                                   // the tight (1.10–1.16) band applies, not
                                   // the multiline one
const double _kLhQuestion = 1.30; // was 1.45 — wraps, but the spec's
                                   // multiline band tops out at 1.35
const double _kLhAnswer   = 1.35; // was 1.75 (a deliberate "paragraph, not a
                                   // row" choice) — kept the "more breathing
                                   // room than a title" intent by using the
                                   // top of the multiline band rather than
                                   // matching the question's 1.30, instead of
                                   // the old value which sat well outside it

// ── Motion — = ئەکۆردیۆنی ئێستای `ad_screen.dart` ───────────────────────────
const Duration _kChevronDur = Duration(milliseconds: 280);
const Duration _kExpandDur  = Duration(milliseconds: 300);
const Curve    _kChevronCrv = Curves.easeInOut;
const Curve    _kExpandCrv  = Curves.easeOutCubic;

// ── Copy ────────────────────────────────────────────────────────────────────
const String _kTxtScreen = 'پرسیارە دووبارەکان';
const String _kTxtBack   = 'گەڕانەوە';

/// ── Back affordance side ────────────────────────────────────────────────────
/// شاشەکە RTLـە، و لە RTLدا دوگمەی گەڕانەوە لە سەرەتای بارە — واتە لای
/// **ڕاستی فیزیکی** (هەمان شتی `tx_history_page` و `notifications_screen`).
/// `ad_details.dart` بە داواکاری تایبەت لای چەپە؛ ئەگەر ویستت ئەمەش وابێت،
/// تەنها ئەم یەک نرخە بگۆڕە بۆ `true` — هیچی تر دەستکاری ناوێت.
const bool _kBackOnPhysicalLeft = false;

// ── Responsive scale — = _scaleFor / _typeScale (ad_details) ────────────────
const double _kRefWidth = 430.0;
const double _kRefScale = 1.06;
const double _kScaleMin = 0.86;
const double _kScaleMax = 1.06;
const double _kTypeMin  = 0.92;

double _scaleFor(BuildContext c) =>
    (MediaQuery.sizeOf(c).width / _kRefWidth * _kRefScale)
        .clamp(_kScaleMin, _kScaleMax);

double _typeScale(double s) => s.clamp(_kTypeMin, _kScaleMax);

// ═════════════════════════════════════════════════════════════════════════════
// FaqScreen
// ═════════════════════════════════════════════════════════════════════════════

class FaqScreen extends StatelessWidget {
  /// پرسیارەکان. بە شێوەی بنەڕەت `kFaqItems`ی سەرەوەیە؛ پارامیتەرەکە تەنها
  /// بۆ ئەوەیە کە ڕۆژێک لە شوێنێکی تر (یان لە باکئێندەوە) دابین بکرێن،
  /// بەبێ دەستکاریکردنی ئەم فایلە.
  final List<FaqItem> items;

  const FaqScreen({super.key, this.items = kFaqItems});

  @override
  Widget build(BuildContext context) {
    final double s = _scaleFor(context);
    final double t = _typeScale(s);
    final MediaQueryData mq = MediaQuery.of(context);

    return Directionality(
      // هەموو شاشەکە RTLـە، وەک هەموو ئەپەکە. تەنها ڕیزی کرۆمی بار
      // دەکرێت بگۆڕدرێت — بڕوانە `_kBackOnPhysicalLeft`.
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kPageBg,
        body: Column(
          children: [
            _TopBar(
              scale: s,
              topPadding: mq.padding.top,
              title: _kTxtScreen,
              // `maybePop` وەک `ad_details.dart` — ڕێگە بە ڕووتەکە دەدات
              // خۆی پۆپ بکات و هەرگیز بەکارهێنەر گیر ناخوات.
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ScrollConfiguration(
                // = `_NoGlowBehavior`ی ad_details: فیزیکسەکە iOS-styleـە،
                // بۆیە گلۆی ئەندرۆید ناوێت.
                behavior: const _NoGlowBehavior(),
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    _kGutter,
                    _kTopGap * s,
                    _kGutter,
                    // دەمێنێتەوە لە سەرووی باری جێستی/ناڤیگەیشنی ئامێر.
                    mq.padding.bottom + 28 * s,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: _kCardGap * s),
                  itemBuilder: (_, i) => _capped(
                    _FaqTile(scale: s, typeScale: t, item: items[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// = `_capped` لە `ad_details.dart` (کە خۆی = ڕاپەڕی کارتی کەمپەین).
  /// دوای ئامێری ڕیفرێنس ناوەڕۆک فراوان نابێت، بەڵکو دەچێتە ناوەڕاست —
  /// بۆیە تابلێت و فۆڵدەبڵ هەمان ڕێژەی مۆبایل وەردەگرن، تەنها بە گەتەری
  /// فراوانتر. لەسەر هەموو مۆبایلێک هیچ ناگۆڕێت (430 − 2×18 = 394 < 398).
  Widget _capped(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kContentMaxW),
          child: child,
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// Top bar — = `_TopBar` in ad_details.dart, minus the overflow control
// ═════════════════════════════════════════════════════════════════════════════
// هەمان 56 dp بەرزایی ناوەڕۆک، هەمان گەتەر، هەمان ڕووی سپی و هەمان هێڵی
// مووی خوارەوەی `ProxoTopBar`، لەگەڵ ئینسێتی سەیف-ئێریای ئامێر لە سەرەوە
// — بۆیە باری ئەم شاشەیە دەقاودەق لەو شوێنەدایە کە باری هەموو شاشەکانی
// تر لێیەتی. نە `AppBar`، نە `SliverAppBar`، نە ئێلیڤەیشن.

class _TopBar extends StatelessWidget {
  final double scale;
  final double topPadding;
  final String title;
  final VoidCallback onBack;

  const _TopBar({
    required this.scale,
    required this.topPadding,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double t = _typeScale(s);

    final Widget back = _Pressable(
      semanticLabel: _kTxtBack,
      pressScale: 0.90,
      onTap: onBack,
      child: SizedBox(
        width: _kBarTap,
        height: _kBarTap,
        child: Center(
          child: Icon(
            // لە RTLدا «دواوە» بەرەو ڕاستە — هەمان گلیفی باری
            // `ad_details.dart`.
            Icons.chevron_right_rounded,
            size: _kBarBackIcon * s,
            color: _kInk,
          ),
        ),
      ),
    );

    return Container(
      height: _kBarHeight + topPadding,
      padding: EdgeInsets.only(
        // 44 dp بۆکس، 6 dp لە لێواری شاشە: ناوەندی گلیفەکە 28 dp ژوورەوە
        // دەکەوێت — هەمان حسابی `ad_details.dart`.
        top: topPadding,
        left: _kGutter - 12,
        right: _kGutter - 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBarLine, width: _kRule)),
      ),
      child: Directionality(
        textDirection:
            _kBackOnPhysicalLeft ? TextDirection.ltr : TextDirection.rtl,
        child: Row(
          children: [
            back,
            Expanded(
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: _kFsBarTitle * t * _kKuBump,
                    // Was Regular — this is the page's AppBar-equivalent
                    // title (back button + centered text), and titles at
                    // this tier take SemiBold.
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                    height: _kLhBarTitle,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            // بۆکسێکی بەتاڵ بە هەمان پانی دوگمەی گەڕانەوە، بۆیە ناونیشانەکە
            // بە ڕاستی لە ناوەڕاستی بارەکەدایە و بەلای لاوە لانادات.
            const SizedBox(width: _kBarTap),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _FaqTile — یەک کارتی پرسیار، بە کردنەوە/داخستن
// ═════════════════════════════════════════════════════════════════════════════
// کارتەکە دەقاودەق هەمان سیستەمی کارتی ئەپەکەیە: ڕووی سپی، سنووری هاوبەش
// (`kProxoCardBorder` / `kProxoCardBorderWidth`) و سێبەری هاوبەش
// (`kProxoCardShadow`) — هەر سێکیان لە `app_theme.dart`ـەوە دێن و هیچ
// کۆپییەکیان لێرە نییە.
//
// سنوورەکە لە `foregroundDecoration`دایە بۆ ئەوەی هێڵی مووەکە **لەسەر**
// ڕیپڵی دەستلێدان بکێشرێت و لە کاتی پەنجەداناندا تۆنی نەگۆڕێت — هەمان
// شێوازی کارتەکانی Quick Actionی پەڕەی سەرەکی.
//
// تەنها ڕیزی پرسیارەکە دەستلێدراوە، نەک وەڵامەکە: بەو شێوەیە بەکارهێنەر
// دەتوانێت وەڵامێکی درێژ بخوێنێتەوە/هەڵبژێرێت بەبێ ئەوەی بە هەڵە دایبخات.

class _FaqTile extends StatefulWidget {
  final double scale;
  final double typeScale;
  final FaqItem item;

  const _FaqTile({
    required this.scale,
    required this.typeScale,
    required this.item,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final double s = widget.scale;
    final double t = widget.typeScale;
    final BorderRadius radius = BorderRadius.circular(_kCardRadius * s);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: radius,
        boxShadow: kProxoCardShadow,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: kProxoCardBorder,
          width: kProxoCardBorderWidth,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ڕیزی پرسیار (هەمیشە دیارە، دەستلێدراوە) ──────────────────
            InkWell(
              onTap: _toggle,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _kCardPadH * s,
                  vertical: _kCardPadV * s,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.question,
                        // بێ `maxLines`: پرسیاری درێژی کوردی بە ئاسایی
                        // دەپێچێتەوە و هەرگیز نابڕدرێت.
                        style: TextStyle(
                          fontFamily: _kFont,
                          fontSize: _kFsQuestion * t * _kKuBump,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                          height: _kLhQuestion,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    SizedBox(width: _kChevronGap * s),
                    AnimatedRotation(
                      // داخراو → خوارەوە، کراوە → سەرەوە.
                      turns: _open ? 0.5 : 0.0,
                      duration: _kChevronDur,
                      curve: _kChevronCrv,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: _kChevron * s,
                        color: _kSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── وەڵام (تەنها لە دۆخی کراوەدا) ────────────────────────────
            AnimatedSize(
              duration: _kExpandDur,
              curve: _kExpandCrv,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        _kCardPadH * s,
                        0,
                        _kCardPadH * s,
                        _kCardPadV * s,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // هێڵی مووی ناو-کارت — هەمان جیاکەرەوەی ڕیزەکانی
                          // کارتەکانی `ad_details.dart`. بۆشایی سەرەوەی
                          // لە پادینگی خوارەوەی ڕیزی پرسیارەوە دێت
                          // (`_kCardPadV`)، بۆیە لێرە دووبارە نەکراوەتەوە.
                          const Divider(
                            height: _kRule,
                            thickness: _kRule,
                            color: _kHairline,
                          ),
                          SizedBox(height: _kAnswerGap * s),
                          Text(
                            widget.item.answer,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: _kFont,
                              fontSize: _kFsAnswer * t * _kKuBump,
                              fontWeight: FontWeight.w400,
                              color: _kSubtle,
                              height: _kLhAnswer,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared bits — = the same helpers in ad_details.dart (library-private there)
// ═════════════════════════════════════════════════════════════════════════════

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final double pressOpacity;
  final String? semanticLabel;

  const _Pressable({
    required this.child,
    this.onTap,
    this.pressScale = 0.97,
    this.pressOpacity = 0.90,
    this.semanticLabel,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.pressScale : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _down ? widget.pressOpacity : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// = `_NoGlowBehavior` لە `ad_details.dart`.
class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext ctx, Widget child, ScrollableDetails d) =>
      child;
}
