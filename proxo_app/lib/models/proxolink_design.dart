import 'proxolink_page_type.dart';

/// Customer labels are independent of the authoritative API/database keys.
abstract final class ProxoLinkDesign {
  static const labels = <String, String>{
    'pill': 'ستایلی کلاسیک',
    'pill-mint': 'ستایلی سروشتی',
    'pill-dark': 'ستایلی تاریک',
    'pill-white': 'ستایلی ڕووناک',
  };

  static String label(String key, {String fallback = 'شێوازی پەڕە'}) =>
      labels[key] ?? fallback;

  static String thumbnail(String key, ProxoPageType type) {
    if (!labels.containsKey(key)) throw ArgumentError.value(key, 'key');
    return 'assets/proxolink_thumbnails/${type.key}-$key.png';
  }
}
