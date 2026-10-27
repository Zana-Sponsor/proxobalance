import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/ad_platform.dart';

void main() {
  test(
      'automatic metrics remain unknown until that exact report field is known',
      () {
    final automatic = {
      'platform': 'TIKTOK',
      'fulfillment_kind': 'tiktok_conversation_auto',
      'status': 'paused',
      'spend': 0,
      'clicks': 0
    };
    expect(hasAdMetricEvidence(automatic, 'spend'), isFalse);
    final reported = {
      ...automatic,
      'provider_metrics_available': ['spend']
    };
    expect(hasAdMetricEvidence(reported, 'spend'), isTrue);
    expect(hasAdMetricEvidence(reported, 'clicks'), isFalse);
    expect(
        hasAdMetricEvidence({'platform': 'META', 'status': 'paused'}, 'spend'),
        isFalse);
    expect(hasAdMetricEvidence({'service_type': 'tiktok'}, 'clicks'), isTrue);
  });
  test('platform scope trusts only canonical identity or verified legacy data',
      () {
    final records = <Map<String, dynamic>>[
      {'id': 'meta-facebook', 'platform': 'META', 'service_type': 'tiktok'},
      {'id': 'meta-instagram', 'platform': 'META'},
      {'id': 'meta-both', 'platform': 'META'},
      {'id': 'tiktok', 'platform': 'TIKTOK'},
      {'id': 'legacy-tiktok', 'service_type': 'tiktok'},
      {'id': 'unknown', 'title': 'Meta TikTok', 'goal': 'views'},
      {'id': 'unknown-service', 'service_type': 'meta'},
      {'id': 'unknown-platform', 'platform': 'OTHER', 'service_type': 'tiktok'},
    ];
    List<String> ids(AdPlatformFilter filter) => records
        .where((ad) => matchesAdPlatform(ad, filter))
        .map((ad) => ad['id'] as String)
        .toList();
    expect(ids(AdPlatformFilter.all), hasLength(8));
    expect(ids(AdPlatformFilter.meta),
        ['meta-facebook', 'meta-instagram', 'meta-both']);
    expect(ids(AdPlatformFilter.tiktok), ['tiktok', 'legacy-tiktok']);
    expect(adPlatformPredicate(AdPlatformFilter.all), isNull);
    expect(adPlatformPredicate(AdPlatformFilter.meta), 'platform.eq.META');
    expect(adPlatformPredicate(AdPlatformFilter.tiktok),
        'platform.eq.TIKTOK,and(platform.is.null,service_type.eq.tiktok)');
  });
}
