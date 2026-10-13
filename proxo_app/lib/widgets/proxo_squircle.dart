// proxo_squircle.dart — Squircle / superellipse geometry
//
// ═════════════════════════════════════════════════════════════════════════════
// بۆچی ئەم فایلە هەیە
// ═════════════════════════════════════════════════════════════════════════════
// داواکراوە (§10 / §12) کە وێنۆچکەی «باشترین ئامارەکان» و هەر سێ کارتی
// ئاماری تەنیشتی هەمان **زمانی گۆشە** هەبێت — نەک یەکێکیان گۆشەی گەردی
// ئاسایی و ئەوی تر گۆشەی تیژ. یەک ڕێگا هەیە بۆ ئەوەی ئەمە هەرگیز لێک
// جیا نەبێتەوە: هەردووکیان لە **یەک** شێوەوە دەردەچن، تەنها بە ڕادیوسی
// جیاواز. ئەمە ئەو شێوەیەیە.
//
// `BorderRadius.circular` گۆشەیەکی کەوانەیی (circular arc) دەکێشێت:
// کەوانەکە لە خاڵی پەیوەندی‌دا بەتوندی دەست پێدەکات، بۆیە «شکانێک» لە
// نێوان هێڵی ڕاست و گۆشەکەدا هەست پێدەکرێت. superellipse ئەو گواستنەوەیە
// درێژ دەکاتەوە، بۆیە گۆشەکە بەردەوام (continuous) دەردەکەوێت — هەمان
// شتێک کە iOS و Figma (corner smoothing) دەیکەن.
//
// ── چۆن ──────────────────────────────────────────────────────────────────────
// هەر گۆشەیەک یەک کیوبیک بەزیەرە:
//
//     • `_kRun`  — گۆشەکە چەند dp پێش خاڵی گۆشە لەسەر لێوارەکە دەست
//                  پێدەکات، وەک ڕێژەیەک لە ڕادیوس. > 1 واتە درێژتر لە
//                  کەوانەیەکی گەرد → گواستنەوەیەکی نەرمتر.
//     • `_kCtrl` — دووری خاڵی کۆنترۆڵ لە گۆشەکەوە. کەمتر لە 0.4477 (ئەو
//                  ژمارەیەی کەوانەی گەرد پێی دەکێشرێت) واتە کەوانەکە
//                  زیاتر خۆی بۆ گۆشەکە دەکێشێت.
//
// ئەم دوو ژمارەیە پێکەوە شێوەکە دیاری دەکەن. **مەیانگۆڕە بۆ یەک شوێن** —
// ئەگەر بگۆڕدرێن، هەموو ئەو شوێنانەی ئەم شێوەیە بەکاردەهێنن پێکەوە
// دەگۆڕێن، کە مەبەستەکەیە.
//
// ⚠ ئەمە هیچ شێوەیەکی ئێستای ئەپەکە ناگۆڕێت: هیچ فایلێکی هەیوو ئەمە
// بەکارناهێنێت. تەنها کۆمپۆنێنتە نوێیەکانی «باشترین ئامارەکان» لێی
// وەردەگرن.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Superellipse ("squircle") corner geometry — one source of truth.
class ProxoSquircle {
  ProxoSquircle._();

  /// درێژی ڕەوتی گۆشە لەسەر لێوارەکە ÷ ڕادیوس.
  static const double kRun = 1.28;

  /// دووری خاڵی کۆنترۆڵ لە گۆشەکەوە ÷ ڕادیوس.
  /// (کەوانەیەکی تەواو گەرد 0.4477 بەکاردەهێنێت.)
  static const double kCtrl = 0.30;

  /// A closed superellipse path for [rect] with corner [radius].
  ///
  /// لێوارەکان ڕاستن — تەنها گۆشەکان کەوانەیین، بۆیە بۆ کارت و وێنۆچکە
  /// گونجاوە (superellipse-ی ڕەها هەموو لێوارەکە دەبڕێت، کە لێرە هەڵەیە).
  static Path path(Rect rect, double radius) {
    final double w = rect.width;
    final double h = rect.height;
    if (w <= 0 || h <= 0) return Path();

    final double half = math.min(w, h) / 2;
    final double r = radius.clamp(0.0, half);
    if (r <= 0) return Path()..addRect(rect);

    // ڕەوتەکە هەرگیز نابێت لە نیوەی هیچ لایەکی تێپەڕێت، ئەگەرنا دوو
    // گۆشەی تەنیشت یەک لەسەر یەک دەکەون.
    final double run = math.min(r * kRun, half);
    final double c = r * kCtrl;

    final double l = rect.left;
    final double t = rect.top;
    final double rt = rect.right;
    final double b = rect.bottom;

    return Path()
      ..moveTo(l + run, t)
      ..lineTo(rt - run, t)
      ..cubicTo(rt - c, t, rt, t + c, rt, t + run)
      ..lineTo(rt, b - run)
      ..cubicTo(rt, b - c, rt - c, b, rt - run, b)
      ..lineTo(l + run, b)
      ..cubicTo(l + c, b, l, b - c, l, b - run)
      ..lineTo(l, t + run)
      ..cubicTo(l, t + c, l + c, t, l + run, t)
      ..close();
  }
}

/// [OutlinedBorder] wrapper, so the same shape can drive `ShapeDecoration`,
/// `Material(shape:)`, `ClipPath` and `InkWell(customBorder:)` alike.
///
/// بەکاربهێنە بۆ هەر ڕوویەک کە دەبێت هەمان گۆشەی وێنۆچکەی هەبێت.
@immutable
class ProxoSquircleBorder extends OutlinedBorder {
  final double radius;

  const ProxoSquircleBorder({
    this.radius = 0,
    super.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) => ProxoSquircleBorder(
        radius: radius * t,
        side: side.scale(t),
      );

  @override
  ProxoSquircleBorder copyWith({BorderSide? side, double? radius}) =>
      ProxoSquircleBorder(
        radius: radius ?? this.radius,
        side: side ?? this.side,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      ProxoSquircle.path(
        rect.deflate(side.strokeInset),
        math.max(0, radius - side.strokeInset),
      );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      ProxoSquircle.path(rect.inflate(side.strokeOutset), radius);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    canvas.drawPath(
      ProxoSquircle.path(rect.deflate(side.width / 2), radius - side.width / 2),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is ProxoSquircleBorder) {
      return ProxoSquircleBorder(
        radius: lerpDouble(a.radius, radius, t)!,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is ProxoSquircleBorder) {
      return ProxoSquircleBorder(
        radius: lerpDouble(radius, b.radius, t)!,
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProxoSquircleBorder &&
          other.radius == radius &&
          other.side == side);

  @override
  int get hashCode => Object.hash(radius, side);

  @override
  String toString() => 'ProxoSquircleBorder($radius, $side)';
}

/// Clips [child] to the shared squircle. Same corner maths as the border, so
/// a clipped image and a decorated card can never drift apart.
///
/// وێنۆچکە ئەمە بەکاردەهێنێت (§10: بڕینی نەرم، `BoxFit.cover`, بێ درزی
/// وێنە)، و کارتە ئامارییەکان `ShapeDecoration`ی سەرەوە — هەردووکیان یەک
/// `ProxoSquircle.path`ن.
class ProxoSquircleClip extends StatelessWidget {
  final double radius;
  final Widget child;

  const ProxoSquircleClip({
    super.key,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _SquircleClipper(radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _SquircleClipper extends CustomClipper<Path> {
  final double radius;
  const _SquircleClipper(this.radius);

  @override
  Path getClip(Size size) =>
      ProxoSquircle.path(Offset.zero & size, radius);

  @override
  bool shouldReclip(covariant _SquircleClipper oldClipper) =>
      oldClipper.radius != radius;
}
