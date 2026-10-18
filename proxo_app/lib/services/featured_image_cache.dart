import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// One bounded file cache and one decoded-image key for Home and details.
/// No eager download of the whole carousel: only the next item is warmed.
abstract final class FeaturedImageCache {
  static final manager = CacheManager(
    Config(
      'proxoFeaturedThumbnailsV1',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 120,
    ),
  );
  static bool validUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  static const decodedWidth = 640;
  static ImageProvider provider(String url) => ResizeImage.resizeIfNeeded(
    decodedWidth,
    null,
    CachedNetworkImageProvider(url, cacheManager: manager),
  );
  static Future<void> warm(BuildContext context, String? url) async {
    if (!validUrl(url)) return;
    await precacheImage(provider(url!), context, onError: (_, __) {});
  }
}
