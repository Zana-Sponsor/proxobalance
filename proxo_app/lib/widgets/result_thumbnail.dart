import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../services/featured_image_cache.dart';
import 'best_results_design.dart';
import 'proxo_thumbnail_fallback.dart';

/// The exact same provider/cache key is used in the banner and full cards.
class ResultThumbnail extends StatelessWidget {
  const ResultThumbnail({
    super.key,
    this.url,
    this.radius = ResultsUi.thumbnailRadius,
  });
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
                frameBuilder: (context, child, frame, synchronous) =>
                    synchronous
                        ? child
                        : AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            child: frame == null
                                ? const ProxoThumbnailFallback()
                                : child,
                          ),
                errorBuilder: (_, __, ___) => const ProxoThumbnailFallback(),
              )
            : const ProxoThumbnailFallback(),
      );
}
