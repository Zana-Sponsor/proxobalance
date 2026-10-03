// section_title_with_gradient_dividers.dart
//
// ═════════════════════════════════════════════════════════════════════════════
// SectionTitleWithGradientDividers — ────── ناونیشان ──────
// ═════════════════════════════════════════════════════════════════════════════
// ویجێتێکی گشتی و دووبارە‌بەکارهێنراو. هیچ شتێکی «باشترین ئامارەکان» بە
// تایبەتی تێدا نییە — ناونیشانەکە دەنێردرێت، بۆیە هەر بەشێکی داهاتووی
// ئەپەکە دەتوانێت هەمان سەردێڕ بەکاربهێنێت.
//
// ── داواکارییەکان و چۆن جێبەجێکراون (§2) ────────────────────────────────────
//   • ساختار         Expanded(هێڵ) · ناونیشان · Expanded(هێڵ)
//                    → هیچ پانییەکی جێگیر نییە، خۆی خۆی دەگونجێنێت.
//   • ناونیشان       هەمیشە لە ناوەڕاستی چاو دەمێنێتەوە: هەردوو هێڵەکە
//                    `Expanded`ی یەکسانن، بۆیە هەر بۆشاییەکی ماوە بە
//                    دوو بەشی یەکسان دابەش دەکرێت.
//   • ئەستووری هێڵ   ≈ 2 dp، تەخت، ڕاست، چوارگۆشە، بێ گۆشەی گەرد
//                    → `Container` + `BoxDecoration` بەبێ `borderRadius`.
//                      (`BorderRadius.zero`ـیش هەمان ئەنجامە؛ لێرە بە
//                      تەواوی دانەنراوە.) `Divider`ی مێتریاڵ بەکارنەهێنراوە
//                      چونکە گرادیێنت قبوڵ ناکات.
//   • گرادیێنت       لای ناونیشان ≈ ڕوون (شەفاف) → لای دەرەوە دیارتر.
//   • ئاوێنەیی       هەردوو هێڵەکە دەقاودەق پێچەوانەی یەکترن.
//   • RTL            گرادیێنتەکان بە `Alignment.centerLeft/centerRight`
//                    دیاری کراون — نەک `AlignmentDirectional` — و ڕیزەکە
//                    بە زۆر LTRـە، بۆیە RTL هەرگیز ئاراستەی بینراوی
//                    هێڵەکان نابڕێتەوە. تەنها دەقی ناوەڕاست RTLـە.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

class SectionTitleWithGradientDividers extends StatelessWidget {
  /// دەقی سەردێڕ. بۆ ئەم بەشە: «باشترین ئامارەکان».
  final String title;

  /// ستایلی دەق. ئەگەر نەنێردرێت، Rabar-ی ئەپەکە بەکاردێت.
  final TextStyle? titleStyle;

  /// ئەستووری هێڵەکان بە dp — داواکراوە ≈ 2.
  final double thickness;

  /// بۆشایی نێوان ناونیشان و هەر هێڵێک.
  final double gap;

  /// ڕەنگی هێڵ لە **کۆتایی دەرەوە**دا. لای ناونیشان بۆ شەفاف دەڕوات.
  final Color color;

  /// بەرزترین ڕوونی هێڵ لە لێواری دەرەوەدا (0…1).
  final double maxOpacity;

  /// ئاراستەی دەقی ناونیشان. بنەڕەت RTLـە (کوردی).
  final TextDirection titleDirection;

  const SectionTitleWithGradientDividers({
    super.key,
    required this.title,
    this.titleStyle,
    this.thickness = 2.0,
    this.gap = 12.0,
    this.color = AppColors.ink,
    this.maxOpacity = 0.22,
    this.titleDirection = TextDirection.rtl,
  });

  /// یەک هێڵ. [outwardToRight] واتە «دیارتر بەرەو ڕاست».
  Widget _line({required bool outwardToRight}) {
    final Color visible = color.withOpacity(maxOpacity.clamp(0.0, 1.0));
    final Color faded = color.withOpacity(0.0);

    return Expanded(
      child: Container(
        height: thickness,
        // بێ `borderRadius` — بۆیە هەردوو کۆتایی تەخت و چوارگۆشەن.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // ئەم دوو `Alignment`ـە فیزیکین و لە `Directionality` ناڕوانن،
            // بۆیە RTL نایانگۆڕێتەوە.
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: outwardToRight
                // چەپ = لای ناونیشان (شەفاف) → ڕاست = لێواری دەرەوە (دیار)
                ? <Color>[faded, visible]
                // چەپ = لێواری دەرەوە (دیار) → ڕاست = لای ناونیشان (شەفاف)
                : <Color>[visible, faded],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Section-heading token (15 / SemiBold) already matched this default —
    // only `height` changes: this title is single-line + ellipsized, so it
    // takes the tight (1.10–1.16) band instead of the old 1.35, which was
    // sized for wrapping text this widget never actually shows.
    final TextStyle style = titleStyle ?? AppTypography.sectionHeading();

    return Directionality(
      // ڕیزەکە فیزیکییە: هێڵی چەپ هەمیشە لای چەپە، هێڵی ڕاست لای ڕاست —
      // بێ گوێدانە ئاراستەی پەڕەکە.
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints c) {
          // ناونیشانەکە بە پانی سروشتی خۆی دەکێشرێت (نەک وەک بەشێکی
          // `flex`)، بۆیە هەردوو `Expanded`ـەکە **دەقاودەق** یەکسان
          // دەبن و دەقەکە لە ناوەڕاستدا دەمێنێتەوە. سنوورێکی بەرزی
          // پانی تەنها بۆ ئەوەیە کە ناونیشانێکی زۆر درێژ هێڵەکان ون
          // نەکات — لەو کاتەدا ellipsis دەخوات.
          final double maxTitle = c.hasBoundedWidth
              ? ((c.maxWidth - gap * 2) * 0.72).clamp(0.0, double.infinity)
              : double.infinity;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // هێڵی چەپ: دەرەوەی چەپ دیار → لای ناونیشان شەفاف.
              _line(outwardToRight: false),
              SizedBox(width: gap),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTitle),
                child: Directionality(
                  textDirection: titleDirection,
                  child: ProxoText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
              ),
              SizedBox(width: gap),
              // هێڵی ڕاست: لای ناونیشان شەفاف → دەرەوەی ڕاست دیار.
              _line(outwardToRight: true),
            ],
          );
        },
      ),
    );
  }
}
