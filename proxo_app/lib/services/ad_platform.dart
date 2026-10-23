/// Platform identity comes only from persisted data. Unknown historical rows
/// remain visible in All, without being relabelled as either provider.
enum AdPlatformFilter { all, meta, tiktok }

String? persistedAdPlatform(Map<String, dynamic> ad) {
  final platform = ad['platform']?.toString().trim().toUpperCase();
  if (platform == 'META' || platform == 'TIKTOK') return platform;
  if ((platform == null || platform.isEmpty) &&
      ad['service_type']?.toString().trim().toLowerCase() == 'tiktok') {
    return 'TIKTOK';
  }
  return null;
}

bool matchesAdPlatform(Map<String, dynamic> ad, AdPlatformFilter filter) =>
    filter == AdPlatformFilter.all ||
    persistedAdPlatform(ad) == filter.name.toUpperCase();

/// Provider-managed Conversation ads must never enter manual fulfillment,
/// thumbnail scraping, cancellation or edit actions for legacy TikTok orders.
bool isManualTikTokAd(Map<String, dynamic> ad) =>
    persistedAdPlatform(ad) == 'TIKTOK' &&
    ad['fulfillment_kind'] != 'tiktok_conversation_auto' &&
    ad['message_destination'] != 'direct_message';

bool isProviderManagedAd(Map<String, dynamic> ad) =>
    persistedAdPlatform(ad) == 'META' ||
    (persistedAdPlatform(ad) == 'TIKTOK' && !isManualTikTokAd(ad));

/// A provider ID or paused state does not prove that a metrics report exists.
/// The server records only fields present in an authoritative observation.
bool hasAdMetricEvidence(Map<String, dynamic> ad, String metric) =>
    !isProviderManagedAd(ad) ||
    (ad['provider_metrics_available'] is List &&
        (ad['provider_metrics_available'] as List).contains(metric));

/// PostgREST predicate, applied before ordering and pagination. The legacy
/// mapping is deliberately limited to the verified existing TikTok service.
String? adPlatformPredicate(AdPlatformFilter filter) => switch (filter) {
      AdPlatformFilter.all => null,
      AdPlatformFilter.meta => 'platform.eq.META',
      AdPlatformFilter.tiktok =>
        'platform.eq.TIKTOK,and(platform.is.null,service_type.eq.tiktok)',
    };
