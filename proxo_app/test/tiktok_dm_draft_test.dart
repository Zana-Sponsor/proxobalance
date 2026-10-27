import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/ad_platform.dart';

AdDraft directDraft() => const AdDraft(
    title: 'ڕیکلامی نامە',
    goal: 'messages',
    messageDestination: 'direct_message',
    category: 'services',
    tiktokAccountId: '22222222-2222-4222-8222-222222222222',
    tiktokItemId: '7612345678901234567',
    tiktokUsername: 'verified.shop',
    tiktokVideoCaption: 'کەلوپەلە نوێیەکان',
    paymentMethod: 'app_balance',
    dailyBudget: 10,
    days: 3,
    immediate: true);

void main() {
  test('Direct Message requires a connected identity and video, no manual post',
      () {
    expect(directDraft().validate(), isEmpty);
    final missing = AdDraft.fromJson({
      ...directDraft().toJson(),
      'tiktok_account_id': null,
      'tiktok_item_id': null,
    });
    expect(missing.validate().keys.toSet(), {'tiktok_account', 'tiktok_video'});
    expect(
        directDraft().toAd().keys,
        isNot(anyOf(contains('video_link'), contains('video_code'),
            contains('post_code'), contains('asset_id'))));
  });

  test(
      'review identity and caption survive recovery without becoming authority',
      () {
    final restored = AdDraft.fromJson(directDraft().toJson());
    expect(restored.isTikTokDirect, isTrue);
    expect(restored.tiktokUsername, 'verified.shop');
    expect(restored.tiktokVideoCaption, 'کەلوپەلە نوێیەکان');
    expect(restored.toAd(), directDraft().toAd());
    expect(restored.toAd().containsKey('tiktok_username'), isFalse);
    expect(restored.toAd().containsKey('tiktok_video_caption'), isFalse);
  });

  test(
      'External Contact and Views retain manual validation and omit inactive IDs',
      () {
    for (final overrides in [
      {'message_destination': 'external_contact'},
      {'goal': 'views'}
    ]) {
      final manual =
          AdDraft.fromJson({...directDraft().toJson(), ...overrides});
      expect(manual.isTikTokDirect, isFalse);
      expect(manual.validate(), containsPair('code', isNotEmpty));
      expect(manual.validate(), containsPair('link', isNotEmpty));
      expect(manual.validate().containsKey('asset'), manual.goal == 'messages');
      expect(manual.toAd().containsKey('tiktok_account_id'), isFalse);
      expect(manual.toAd().containsKey('tiktok_item_id'), isFalse);
    }
    expect(AdDraft.fromJson({'goal': 'messages'}).messageDestination,
        'external_contact');
  });

  test('TikTok keeps its customer minimum and has no engagement objective', () {
    for (final override in [
      {'daily_budget': 5},
      {'goal': 'engagement'}
    ]) {
      expect(
          AdDraft.fromJson({...directDraft().toJson(), ...override}).validate(),
          isNotEmpty);
    }
  });

  test(
      'edited budget invalidates immutable TikTok quote while preserving estimate',
      () {
    const quote = AdQuote(
        grossUsd: 30,
        costUsd: 30,
        rate: 1500,
        days: 3,
        tiktokContract: {'quote_id': 'immutable'});
    final restored = AdQuote.fromJson(quote.toJson());
    expect(restored.tiktokContract?['quote_id'], 'immutable');
    expect(restored.forBudget(20, 3).tiktokContract, {'preview_only': true});
  });

  test('automated TikTok ads cannot enter legacy manual actions', () {
    expect(isManualTikTokAd({'platform': 'TIKTOK'}), isTrue);
    expect(isManualTikTokAd({'service_type': 'tiktok'}), isTrue);
    expect(
        isManualTikTokAd({
          'platform': 'TIKTOK',
          'fulfillment_kind': 'tiktok_conversation_auto'
        }),
        isFalse);
    expect(
        isManualTikTokAd(
            {'platform': 'TIKTOK', 'message_destination': 'direct_message'}),
        isFalse);
    expect(isManualTikTokAd({'platform': 'META'}), isFalse);
  });
}
