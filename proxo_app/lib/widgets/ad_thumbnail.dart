import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart' show kAppFont;

/// Shared portrait thumbnail; images never change the surrounding card size.
class AdThumbnail extends StatelessWidget {
  final String? url;
  final ImageProvider? imageProvider;
  final double radius;
  const AdThumbnail(
      {super.key, this.url, this.imageProvider, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    final uri = Uri.tryParse(value);
    final valid = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imageProvider != null
          ? Image(
              image: imageProvider!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const AdThumbnailFallback())
          : valid
              ? CachedNetworkImage(
                  imageUrl: value,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (_, __) => const AdThumbnailFallback(),
                  errorWidget: (_, __, ___) => const AdThumbnailFallback(),
                )
              : const AdThumbnailFallback(),
    );
  }
}

/// Branded fallback only: inherits the real thumbnail's tight dimensions and
/// rounded clip from _AdcThumb. No independent aspect ratio, padding or motion.
class AdThumbnailFallback extends StatelessWidget {
  const AdThumbnailFallback({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
        child: CustomPaint(
          painter: _ProxoPatternPainter(),
          child: SizedBox.expand(),
        ),
      );
}

/// Paint one laid-out word eighteen times, in six gently staggered rows.
/// All positions and type sizes are proportional to the available thumbnail.
class _ProxoPatternPainter extends CustomPainter {
  const _ProxoPatternPainter();

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
          fontFamily: kAppFont,
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
  bool shouldRepaint(covariant _ProxoPatternPainter oldDelegate) => false;
}
