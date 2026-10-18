import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../services/featured_image_cache.dart';
import 'best_results_design.dart';

/// The exact same provider/cache key is used in the banner and full cards.
class ResultThumbnail extends StatelessWidget {
  const ResultThumbnail({super.key, this.url, this.radius = 14});
  final String? url;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: FeaturedImageCache.validUrl(url)
        ? Image(
            image: FeaturedImageCache.provider(url!),
            fit: BoxFit.cover,
            semanticLabel: ProxoStrings.text('ئەنجامی ڕیکلامی هەڵبژێردراو'),
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, synchronous) => synchronous
                ? child
                : AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: frame == null ? const _Placeholder() : child,
                  ),
            errorBuilder: (_, __, ___) => const _Placeholder(),
          )
        : const _Placeholder(),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF0F3F7),
    child: Center(
      child: ResultIcon('image', size: 30, color: Color(0xFF98A4B5)),
    ),
  );
}
