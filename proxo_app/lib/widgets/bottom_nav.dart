import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_locale.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProxoBottomNav
//
// ── MOTION PASS (this revision) ─────────────────────────────────────────────
// Brief: the bar should feel calm and immediate — a sliding indicator, icons
// that softly morph outline→filled, and the reference's fading touch capsule.
// Only this file and MainShell's tab-entrance block are touched. Public API
// (`currentIndex`, `onTap`), tab order and routes are unchanged, so MainShell
// needs no integration edits.
//
//   what                     before              after
//   ─────────────────────────────────────────────────────────────────────────
//   active marker            none (colour only)  48×3 pill on the top edge,
//                                                ease-slides between slots
//   outline → filled         instant swap        cross-fade, one 140ms driver
//                                                shared with the colour lerp
//   touch feedback           scale bounce        64×34 soft capsule pulse
//   FAB feedback             scale 0.94 down     subtle 1.04 tap response
//
// ── Geometry baseline ───────────────────────────────────────────────────────
// glyph box 24 → gap 6 → label box 14 = 44dp of content, centred in a 74dp
// slot. Icon centres, label centres and tap areas are identical by
// construction, not by tuning. The label row keeps its FIXED height so a
// FittedBox that has to scale down (narrow phone, large accessibility text)
// can never shorten one Column and drop its icon below the other three.
//
// ── DO NOT WRAP THE PILL IN Center / Align WITHOUT A heightFactor ───────────
// Scaffold lays out bottomNavigationBar with LOOSE constraints (maxHeight =
// the whole Scaffold), so a bare Center expands to constraints.biggest — the
// nav bar claims the full screen and the body is left with zero height.
// The pill must stay height-shrink-wrapped: Padding → SizedBox(_S.pillH).
// ─────────────────────────────────────────────────────────────────────────────

// ── ڕەنگەکان: هەمووی لە `AppColors`ەوە دێن ─────────────────────────────────
// active   = پرایمەری شینی ئەپەکە (هەمان شینی FAB) — ئیندیکەیتەریش هەر ئەمە.
// inactive = خۆڵەمێشی ناوەند. ئەگەر `AppColors.navIdle` زۆر ڕەنگ‌پڕووکاو
//            بوو (لە #A8B0BE سووکتر)، تەنها ئەم دێڕەی خوارەوە بگۆڕە —
//            هیچ شوێنێکی تر ڕەنگی نەچالاکی نەخشاند ناکات.
class _C {
  static const active   = AppColors.navActive;
  static const inactive = AppColors.navIdle;   // ← تاکە خاڵی گۆڕینی ڕەنگی نەچالاک
  static const barBg    = AppColors.navBg;
  static const line     = AppColors.navLine;
  static const shadow   = Color(0x0D000000);   // 5% — تەنها لێوارێکی نەرم
}

// ── Sizing tokens (dp) — یەک سەرچاوە بۆ هەموو ئەم فایلە ────────────────────
class _S {
  static const double pillH     = 74;    // بەرزایی پیلەکە
  static const double hPad      = 6;     // پەدینگی ناوەوەی ئاسۆیی
  static const double glyphBox  = 24;    // بۆکسی ئایکۆن — هەردوو دۆخ وەک یەک
  static const double gap       = 6;     // ئایکۆن → لەیبڵ
  static const double labelSize = 11.5;
  static const double labelLead = 1.2;
  static const double labelBoxH = 14;    // = ceil(11.5 × 1.2) — نەگۆڕ
  static const double minTap    = 48;    // کەمترین ناوچەی دەستلێدان
  static const double fabSz     = 48;
  static const double fabRise   = 0;

  // ── One-shot press pill ──────────────────────────────────────────────────
  // Sits BEHIND the glyph only — never behind the label. It is 64×34 around a
  // 24dp glyph box, so it overflows that box by 20dp horizontally and 5dp
  // vertically and is painted, deliberately, outside its parent's bounds.
  //
  // That is the only way to add it without moving anything: making the pill a
  // real 32dp-tall layout box would push the content column from 44dp to 52dp
  // and drop the label 4dp. Nothing in the chain from here up to the bar's
  // Stack clips (that Stack is Clip.none, and Row/Column/Padding/Expanded
  // never clip), so the overflow renders. If a ClipRect is ever introduced
  // above a nav item, this pill is what will get cut off first.
  //
  // Bottom edge lands 1dp above the label: glyph centre sits at 27dp inside
  // the 74dp slot, so the pill spans 10–44dp and the label starts at 45dp.
  // NAMED pressPill*, not pill*: `_S.pillH` already means the height of the
  // BAR itself (74dp). Two different concepts under one name is how this got
  // shadowed the first time.
  static const double pressPillW      = 64;
  static const double pressPillH      = 34;
  static const double pressPillRadius = 17;

  // ── Top sliding indicator ────────────────────────────────────────────────
  // Sits flush against the inside of the 1px hairline, i.e. the very top edge
  // of the bar, and is the full-length pill shape at any width (radius 999
  // clamps to height/2, so 1.5 here — the shape is a stadium either way).
  // The supplied reference measures about 131 physical pixels on a 2.75 DPR
  // handset: 131 / 2.75 = 47.6dp. Rounded to 48dp so it stays crisp.
  static const double indW      = 48;
  static const double indH      = 3;
  static const double indRadius = 999;
}

// ── Motion tokens ───────────────────────────────────────────────────────────
class _M {
  // Frame measurement of the supplied reference: the indicator completes a
  // one-slot move in roughly 0.23s, accelerating and decelerating without a
  // spring overshoot. A bounded controller also stops its ticker exactly at
  // the end instead of spending extra frames settling an invisible tail.
  static const Duration indicatorSlide = Duration(milliseconds: 230);
  static const Curve indicatorCurve = Curves.easeInOut;

  // outline→filled cross-fade + colour lerp. One driver for both so the glyph
  // never solidifies ahead of, or behind, the colour.
  static const Duration stateFade  = Duration(milliseconds: 140);
  static const Curve    stateCurve = Curves.easeOutCubic;

  // One-shot press pill measured from the reference: 0 → 9% black → 0 over
  // about 520ms, with a ~100ms attack and a long, calm ~420ms fade-out.
  //
  // ⚠ The 0.09 is applied ONCE, as the alpha of the tint itself. Writing
  // `Opacity(opacity: pulse, child: … Colors.black.withOpacity(0.09) …)` with
  // a pulse that peaks at 0.09 multiplies the two and yields 0.0081 alpha —
  // invisible on the white bar. Animating the colour's own alpha is
  // the same visual target with none of that trap.
  static const Duration pillPulse = Duration(milliseconds: 520);
  static const double   pillPeak  = 0.09;
  static const Color    pillTint  = Colors.black;
  static const double   pillUpW   = 20;   // 20% of 520ms = 104ms attack
  static const double   pillDownW = 80;   // 80% of 520ms = 416ms decay

  // The reference nav glyphs do not scale. The centre FAB has no counterpart
  // there, so it keeps only a restrained 4% response of its own.
  static const Duration bounce      = Duration(milliseconds: 160);
  static const double   bouncePeak  = 1.04;
  static const double   bounceUpW   = 40;   // 64ms out
  static const double   bounceDownW = 60;   // 96ms back
}

/// Restrained tap response for the centre FAB. Regular nav glyphs intentionally
/// do not scale because the supplied reference keeps their geometry fixed.
Animation<double> _bounceAnimation(AnimationController c) {
  return TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: _M.bouncePeak)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: _M.bounceUpW,
    ),
    TweenSequenceItem(
      tween: Tween(begin: _M.bouncePeak, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: _M.bounceDownW,
    ),
  ]).animate(c);
}

/// Alpha curve for the press pill: 0 → [_M.pillPeak] → 0.
///
/// A TweenSequence, NOT a forward/reverse pair, and that is the whole point of
/// the "one-shot" requirement. `forward()` on tap-down + `reverse()` on tap-up
/// is the usual way to build a press highlight, and it is exactly what leaves
/// the pill sitting there for the duration of a long-press. Here the sequence
/// ends at 0 on its own, so the fade-out is not conditional on the finger ever
/// lifting — hold for ten seconds and the pill is still gone after 520ms.
///
/// It also self-heals on a re-tap: `forward(from: 0)` restarts the sequence
/// from a known 0, so rapid tapping re-flashes cleanly rather than compounding.
Animation<double> _pillPulseAnimation(AnimationController c) {
  return TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: _M.pillPeak)
          .chain(CurveTween(curve: Curves.easeOutQuad)),
      weight: _M.pillUpW,
    ),
    TweenSequenceItem(
      tween: Tween(begin: _M.pillPeak, end: 0.0)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: _M.pillDownW,
    ),
  ]).animate(c);
}

// فۆنتی لەیبڵەکان — دەبێت **دەقاودەق** وەک `pubspec.yaml` بێت.
const String _kNavFont = kAppFont;

/// Bottom-nav icons from `assets/icons/nav/`.
///
/// Each tab has an outline asset for the inactive state and a `_fill` asset
/// for the active state (home/home_fill, megaphone/megaphone_fill, …). Both
/// live on the same 512×512 canvas with matching geometry, which is what
/// makes the cross-fade in [_navGlyph] land exactly on top of itself.
///
/// The outline weight is baked into the raster: home.png measures ~31px of
/// stroke on 512, which at the 24dp glyph box is 31/512 × 24 ≈ 1.45dp — the
/// 1.5px the brief asks for, already. Changing `_S.glyphBox` changes the
/// apparent stroke with it, so those two tokens move together.
enum _Glyph { home, campaigns, tools, profile }

/// ⚠ `widget_fill.png` و `user_fill.png` بە هەڵە **پێچەوانە**ن لە ناوەکانیان.
///
/// پێوانەی داپۆشینی مەرەکەب لەسەر هەمان کەنڤاسی 512×512:
///
///     home.png        22.1٪   →  home_fill.png        63.4٪   ✓ ڕاست
///     megaphone.png   16.7٪   →  megaphone_fill.png   32.5٪   ✓ ڕاست
///     widget.png      50.8٪   →  widget_fill.png      29.3٪   ✗ پێچەوانە
///     user.png        52.1٪   →  user_fill.png        21.0٪   ✗ پێچەوانە
///
/// واتە بۆ ئەم دوو تابە فایلی «پڕ» لە ڕاستیدا هێڵکێشراوەکەیە. ئەنجامەکەی
/// ئەوە بوو کە «ئامرازەکان» و «پرۆفایل» لە کاتی هەڵبژاردندا **بەتاڵ**
/// دەبوونەوە، لە کاتێکدا «سەرەکی» و «ڕیکلامەکان» پڕ دەبوون.
///
/// چارەسەرەکە لێرەیە و نەک بە ناوگۆڕینی فایلەکان، بۆیە ئەگەر ڕۆژێک
/// ئارتوۆرکەکە نوێ کرایەوە و ناوەکان ڕاست بوون، تەنها ئەم `switch`ـە
/// دەگەڕێتەوە بۆ فۆرمی ئاسایی.
///
/// ⚠ چارەسەری جێگرەوە — دانانی `Icons.grid_view_rounded` /
/// `Icons.person_rounded`ی مێتریاڵ — دۆخی پڕبوونی ڕاست دەکردەوە، بەڵام
/// ئەو دوو تابە بە کێش و ستایلێکی جیاواز لە دوو تابەکەی تەنیشتیان
/// دەکێشران (ڤێکتۆری مێتریاڵ بەرامبەر ڕەستەری ئەم کیتە) — واتە
/// ناڕێکییەکی بینراوی نوێ لە جیاتی کۆنەکە.
String _glyphAsset(_Glyph g, bool filled) {
  switch (g) {
    case _Glyph.home:
      return filled
          ? 'assets/icons/nav/home_fill.png'
          : 'assets/icons/nav/home.png';
    case _Glyph.campaigns:
      return filled
          ? 'assets/icons/nav/megaphone_fill.png'
          : 'assets/icons/nav/megaphone.png';
    // ↓ بە ئەنقەست پێچەوانە — بڕوانە تێبینییەکەی سەرەوە.
    case _Glyph.tools:
      return filled
          ? 'assets/icons/nav/widget.png'
          : 'assets/icons/nav/widget_fill.png';
    case _Glyph.profile:
      return filled
          ? 'assets/icons/nav/user.png'
          : 'assets/icons/nav/user_fill.png';
  }
}

/// Outline and filled stacked on one another, cross-faded by [fill] (0 = pure
/// outline, 1 = pure solid). A layer whose opacity has reached 0 or 1 is
/// dropped from the tree entirely, so a resting tab paints exactly one image
/// with no `Opacity` layer — the cross-fade costs nothing except while it runs.
Widget _navGlyph(
  BuildContext context,
  _Glyph g,
  Color color,
  double fill,
  double box,
) {
  // 512×512 PNG بۆ ~24 dp — بەبێ `cacheWidth` هەموو ڕەستەرەکە دیکۆد دەبێت.
  final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
  final int cache = (box * dpr).ceil().clamp(16, 512);

  Widget layer(bool filled, double opacity) {
    final Widget img = Image.asset(
      _glyphAsset(g, filled),
      width: box,
      height: box,
      cacheWidth: cache,
      cacheHeight: cache,
      color: color,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
    );
    if (opacity >= 1.0) return img;
    return Opacity(opacity: opacity, child: img);
  }

  // بۆکسەکە هەمیشە `box × box`ـە بۆ هەر چوار تابەکە و بۆ هەردوو دۆخ،
  // بۆیە ناوەندی ئایکۆنەکان دەقاودەق لەسەر یەک هێڵن.
  return SizedBox(
    width: box,
    height: box,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (fill < 1.0) layer(false, 1.0 - fill),
        if (fill > 0.0) layer(true, fill),
      ],
    ),
  );
}

class _NavItemData {
  final _Glyph glyph;
  final String label;
  const _NavItemData({required this.glyph, required this.label});
}

/// Five slots. Slot 2 is the FAB — it opens a pushed route rather than
/// selecting a tab, so it never takes the indicator.
List<_NavItemData?> _navItems() => ProxoLocale.isArabic
    ? const <_NavItemData?>[
        _NavItemData(glyph: _Glyph.home, label: 'الرئيسية'),
        _NavItemData(glyph: _Glyph.campaigns, label: 'الإعلانات'),
        null,
        _NavItemData(glyph: _Glyph.tools, label: 'الأدوات'),
        _NavItemData(glyph: _Glyph.profile, label: 'الملف'),
      ]
    : const <_NavItemData?>[
        _NavItemData(glyph: _Glyph.home, label: 'سەرەکی'),
        _NavItemData(glyph: _Glyph.campaigns, label: 'ڕیکلامەکان'),
        null,
        _NavItemData(glyph: _Glyph.tools, label: 'ئامرازەکان'),
        _NavItemData(glyph: _Glyph.profile, label: 'پڕۆفایل'),
      ];

const int _kFabSlot = 2;

// ─────────────────────────────────────────────────────────────────────────────
// ProxoBottomNav
// ─────────────────────────────────────────────────────────────────────────────

class ProxoBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ProxoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<ProxoBottomNav> createState() => _ProxoBottomNavState();
}

class _ProxoBottomNavState extends State<ProxoBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide =
      AnimationController(
        vsync: this,
        duration: _M.indicatorSlide,
        value: 1.0,
      );

  /// Slot positions are held as fractional indices, not pixels, so the bar
  /// re-derives the indicator's x from the live width on every layout —
  /// rotation, split-screen and font-scale changes need no special handling.
  late double _fromSlot;
  late double _toSlot;

  double get _liveSlot => lerpDouble(
        _fromSlot,
        _toSlot,
        _M.indicatorCurve.transform(_slide.value),
      )!;

  @override
  void initState() {
    super.initState();
    final start = widget.currentIndex == _kFabSlot ? 0 : widget.currentIndex;
    _fromSlot = _toSlot = start.toDouble();
  }

  @override
  void didUpdateWidget(covariant ProxoBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _retarget(widget.currentIndex);
    }
  }

  void _retarget(int index) {
    // The FAB pushes AdCreateScreen; the underlying tab is still whatever it
    // was, so the indicator holds its place instead of jumping to the centre.
    if (index == _kFabSlot) return;

    final double target = index.toDouble();
    if (target == _toSlot && !_slide.isAnimating) return;

    // Start from wherever the pill actually IS, not from the previous slot's
    // centre. Tapping three tabs in quick succession therefore reads as one
    // continuous glide instead of three restarted animations.
    _fromSlot = _liveSlot;
    _toSlot = target;
    _slide.forward(from: 0.0);
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    final List<_NavItemData?> items = _navItems();

    return Directionality(
      // Nav order stays LTR under the app's Sorani RTL locale, so slot 0 is
      // the physical left edge and the indicator's +x is rightward.
      textDirection: TextDirection.ltr,
      // پانی تەواو، بێ مارجن و بێ گۆشەی خڕ: باری خوارەوە بەشێکە لە پەڕەکە،
      // نەک تەختەیەکی مەلەوەر لەسەری.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _C.barBg,
          border: Border(top: BorderSide(color: _C.line, width: 1)),
          boxShadow: [
            BoxShadow(
              color: _C.shadow,
              blurRadius: 14,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: safeBot),
          // SizedBox, not Center — see the note at the top of this file.
          child: SizedBox(
            height: _S.pillH,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Slot geometry, recomputed on every layout pass.
                final double slotW =
                    (constraints.maxWidth - _S.hPad * 2) / items.length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Tabs: 5 equal slots, slot 2 is the FAB spacer ───────
                    // Positioned.fill, NOT a bare child. A non-positioned
                    // Stack child is laid out with LOOSENED constraints, so
                    // the Row shrink-wrapped to its content (48dp, the
                    // ConstrainedBox floor) and sat pinned to the TOP of the
                    // 74dp pill — while the FAB below is Positioned.fill +
                    // Center and therefore at the true centre, 13dp lower.
                    // Filling gives the Row a tight 74dp so `stretch` does
                    // what its comment claims and both line up.
                    Positioned.fill(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: _S.hPad),
                        child: Row(
                          // stretch ⇒ هەر تابێک تەواوی بەرزایی پیلەکە (74dp)
                          // وەک ناوچەی دەستلێدان دەگرێت.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(items.length, (i) {
                            final data = items[i];
                            if (data == null) {
                              return const Expanded(child: SizedBox());
                            }
                            return Expanded(
                              child: _NavItem(
                                glyph: data.glyph,
                                label: data.label,
                                active: widget.currentIndex == i,
                                onTap: () => widget.onTap(i),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    // ── Centre FAB — fully inside the bar, true centre ──────
                    Positioned.fill(
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, -_S.fabRise),
                          child: _AddFab(
                            size: _S.fabSz,
                            onTap: () => widget.onTap(_kFabSlot),
                          ),
                        ),
                      ),
                    ),

                    // ── Top sliding indicator ───────────────────────────────
                    // Only this strip repaints per frame; the tabs and the FAB
                    // sit outside the AnimatedBuilder and are untouched by the
                    // slide.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: _S.indH,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _slide,
                          builder: (context, child) {
                            final double centreX =
                                _S.hPad + (_liveSlot + 0.5) * slotW;
                            return Transform.translate(
                              offset:
                                  Offset(centreX - _S.indW / 2, 0),
                              child: child,
                            );
                          },
                          child: const Align(
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: _S.indW,
                              height: _S.indH,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _C.active,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(_S.indRadius),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavItem
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final _Glyph glyph;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.glyph,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with TickerProviderStateMixin {
  /// Selection: drives the colour lerp AND the outline→filled cross-fade from
  /// a single value, so the glyph can never solidify out of step with its
  /// colour. 0 = inactive, 1 = active.
  late final AnimationController _select = AnimationController(
    vsync: this,
    duration: _M.stateFade,
    value: widget.active ? 1.0 : 0.0,
  );
  late final Animation<double> _selectT =
      CurvedAnimation(parent: _select, curve: _M.stateCurve);

  /// The reference's press capsule starts on tap-down, peaks softly and fades
  /// away on its own even when the finger stays down.
  late final AnimationController _pillCtrl =
      AnimationController(vsync: this, duration: _M.pillPulse);
  late final Animation<double> _pill = _pillPulseAnimation(_pillCtrl);

  @override
  void didUpdateWidget(covariant _NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      widget.active ? _select.forward() : _select.reverse();
    }
  }

  @override
  void dispose() {
    _select.dispose();
    _pillCtrl.dispose();
    super.dispose();
  }

  void _onPressStart() => _pillCtrl.forward(from: 0.0);

  @override
  Widget build(BuildContext context) {
    // MergeSemantics so the GestureDetector's tap action and this node collapse
    // into ONE announcement ("Campaigns, selected, button") instead of a
    // labelled node with a separate tappable child underneath it.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.label,
        child: GestureDetector(
          // opaque ⇒ تەواوی خانەکە (پانی شوێنەکە × 74dp) دەستلێدان وەردەگرێت،
          // نەک تەنها ئایکۆن و لەیبڵەکە.
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _onPressStart(),
          // بێ هەزە — وەک ڕووکارەکانی تر لە ئەپەکە، کاردانەوەکە تەنها بینراوە.
          onTap: widget.onTap,
          child: ConstrainedBox(
            // بیمە: ئەگەر ڕۆژێک `pillH` کەمبکرێتەوە، ناوچەی دەستلێدان
            // هێشتا لە 48dp کەمتر نابێتەوە.
            constraints: const BoxConstraints(
              minWidth: _S.minTap,
              minHeight: _S.minTap,
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge([_selectT, _pill]),
              builder: (context, _) {
                final double t = _selectT.value;
                // هەمان ڕەنگ بۆ ئایکۆن و لەیبڵ — یەک مامەڵەی چالاک/نەچالاک.
                final Color color = Color.lerp(_C.inactive, _C.active, t)!;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Stack sized by the glyph: a Positioned child does not
                    // contribute to a Stack's size, so the oversized pill adds
                    // nothing to layout and the 44dp content column is
                    // unchanged. Clip.none lets it paint past the 24dp box.
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Painted first = behind the glyph. Dropped entirely
                        // at rest, so an idle tab carries no extra render
                        // object for a highlight it isn't showing.
                        if (_pill.value > 0.001)
                          Positioned(
                            left: (_S.glyphBox - _S.pressPillW) / 2,
                            top: (_S.glyphBox - _S.pressPillH) / 2,
                            width: _S.pressPillW,
                            height: _S.pressPillH,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _M.pillTint
                                    .withOpacity(_pill.value),
                                borderRadius: BorderRadius.circular(
                                    _S.pressPillRadius),
                              ),
                            ),
                          ),
                        _navGlyph(
                          context,
                          widget.glyph,
                          color,
                          t,
                          _S.glyphBox,
                        ),
                      ],
                    ),
                    const SizedBox(height: _S.gap),
                    // بەرزایی جێگیر: FittedBox لە **ناوەوەی** ئەم بۆکسەدا
                    // بچووک دەبێتەوە، بۆیە بەرزایی ڕیزەکە هەرگیز ناگۆڕێت.
                    SizedBox(
                      height: _S.labelBoxH,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ProxoText(
                            widget.label,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _kNavFont,
                              fontSize: _S.labelSize,
                              // هەڵبژاردن بە ڕەنگ و گلیفی پڕکراو دیاردەکرێت،
                              // نەک بە قەبارە یان قورسایی.
                              fontWeight: FontWeight.w400,
                              color: color,
                              letterSpacing: 0,
                              height: _S.labelLead,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddFab — flat circle, no gradient, no shadow
// ─────────────────────────────────────────────────────────────────────────────

class _AddFab extends StatefulWidget {
  final double size;
  final VoidCallback onTap;

  const _AddFab({required this.size, required this.onTap});

  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab> with SingleTickerProviderStateMixin {
  // The reference has no centre FAB, so this unique control keeps only a very
  // small 4% response; the four regular nav glyphs remain geometrically still.
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: _M.bounce);
  late final Animation<double> _scale = _bounceAnimation(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Material(
          color: _C.active,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor: const Color(0x2EFFFFFF),
            highlightColor: const Color(0x14FFFFFF),
            onTapDown: (_) => _ctrl.forward(from: 0.0),
            onTap: widget.onTap, // ← هەمان onTap(2)ی پێشوو — هیچ نەگۆڕاوە
            // CustomPaint تەواوی بازنەکە پڕدەکاتەوە، بۆیە ناوەندی «+»
            // دەقاودەق ناوەندی بازنەکەیە.
            child: const CustomPaint(painter: _PlusPainter()),
          ),
        ),
      ),
    );
  }
}

// Plus: derived from the circle so the glyph keeps the exact proportions it
// had at 45dp (arm 8.0 / stroke 2.6) now that the circle is 48dp.
//   arm    = 8.0  / 45 = 0.1778 × diameter
//   stroke = 2.6  / 45 = 0.0578 × diameter
// Round caps extend each arm by stroke/2, and they do so symmetrically, so
// both strokes stay perfectly centred on (size/2, size/2).
class _PlusPainter extends CustomPainter {
  const _PlusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final arm = size.width * 0.1778;

    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.0578
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), p);
    canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), p);
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) => false;
}
