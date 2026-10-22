import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The same quiet Proxo artwork for missing or failed advert thumbnails.
/// The enclosing thumbnail owns its size, aspect ratio and rounded clip.
class ProxoThumbnailFallback extends StatelessWidget {
  const ProxoThumbnailFallback({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Proxo',
        image: true,
        child: const RepaintBoundary(
          child: CustomPaint(
            painter: _ProxoThumbnailPatternPainter(),
            child: SizedBox.expand(),
          ),
        ),
      );
}

/// Retains the original Advertisements thumbnail pattern: one laid-out word
/// repeated eighteen times, with six gently staggered rows and no animation.
class _ProxoThumbnailPatternPainter extends CustomPainter {
  const _ProxoThumbnailPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFBFDFF),
    );

    const columns = 3;
    const rows = 6;
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    final word = TextPainter(
      text: TextSpan(
        text: 'Proxo',
        style: TextStyle(
          fontFamily: 'Rabar',
          fontSize: size.width * .105,
          fontWeight: FontWeight.w400,
          color: const Color(0x1F046CFA),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final wordScale = math.min(
      1.0,
      math.min(cellWidth * .72 / math.max(word.width, 1),
          cellHeight * .60 / math.max(word.height, 1)),
    );
    for (var row = 0; row < rows; row++) {
      final stagger = (row.isOdd ? .025 : -.025) * size.width;
      for (var column = 0; column < columns; column++) {
        final x = (column + .5) * cellWidth + stagger;
        final y = (row + .75) * size.height / (rows + .5);
        canvas.save();
        canvas.translate(
            x - word.width * wordScale / 2, y - word.height * wordScale / 2);
        canvas.scale(wordScale);
        word.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
    word.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProxoThumbnailPatternPainter oldDelegate) =>
      false;
}
