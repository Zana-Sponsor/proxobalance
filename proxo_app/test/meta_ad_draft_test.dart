import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/meta_ad_draft.dart';

AdDraft metaDraft({String goal = 'messages', String method = 'app_balance'}) =>
    AdDraft(
        platform: 'META',
        title: 'ڕیکلام',
        pageUrl: 'https://www.facebook.com/proxo',
        link: 'https://www.facebook.com/proxo/posts/pfbidExample',
        goal: goal,
        dailyBudget: 5,
        days: 3,
        paymentMethod: method,
        immediate: true);

void main() {
  test('new Meta draft starts with both placements and three destinations', () {
    expect(metaDraft().validate(), isEmpty);
    expect(metaDraft().toMetaContract()['destinations'],
        ['INSTAGRAM_DIRECT', 'MESSENGER', 'WHATSAPP']);
    expect(metaDraft().toMetaContract()['budget_daily'], 5);
    expect(metaDraft().toMetaContract()['duration_days'], 3);
  });
  test('placement rejection is atomic and explicit off choices stay off', () {
    const start = MetaAdSelection();
    final withoutWhatsApp = start.toggleDestination('WHATSAPP');
    final facebook = withoutWhatsApp.togglePlacement('instagram');
    expect(facebook.destinations, {'MESSENGER'});
    expect(identical(facebook.togglePlacement('facebook'), facebook), isTrue);
    expect(facebook.togglePlacement('instagram').destinations, {'MESSENGER'});
    expect(
        identical(facebook.toggleDestination('MESSENGER'), facebook), isTrue);
  });
  test('removing a placement never auto substitutes a destination', () {
    const messenger = MetaAdSelection(destinations: {'MESSENGER'});
    final instagram = messenger.togglePlacement('facebook');
    expect(instagram.placements, {'instagram'});
    expect(instagram.destinations, isEmpty);
    expect(instagram.toggleDestination('WHATSAPP').destinations, {'WHATSAPP'});
  });
  test('invalid selected destination can be removed without toggling another',
      () {
    const selection = MetaAdSelection(
        destinations: {'WHATSAPP', 'MESSENGER'}, unavailable: {'WHATSAPP'});
    expect(selection.toggleDestination('WHATSAPP').destinations, {'MESSENGER'});
    expect(
        identical(selection.toggleDestination('MESSENGER'), selection), isTrue);
  });
  test('views and engagement omit destinations and TikTok-only fields', () {
    for (final goal in ['views', 'engagement']) {
      final draft = metaDraft(goal: goal);
      expect(draft.validate(), isEmpty);
      expect(draft.toMetaContract().containsKey('destinations'), isFalse);
      expect(draft.toMetaContract().containsKey('video_code'), isFalse);
    }
  });
  test('restored drafts preserve platform and explicit empty destinations', () {
    final draft =
        AdDraft.fromJson({...metaDraft().toJson(), 'destinations': const []});
    expect(draft.isMeta, isTrue);
    expect(draft.destinations, isEmpty);
    expect(draft.validate(), contains('destinations'));
    expect(AdDraft.fromJson(const {}).platform, 'TIKTOK');
  });
  test('Baghdad schedule is converted to one UTC instant', () {
    final draft = AdDraft.fromJson({
      ...metaDraft().toJson(),
      'start_immediately': false,
      'start_date': '2030-01-01',
      'start_time': '00:30'
    });
    expect(draft.toMetaContract()['schedule']['start_at'],
        '2029-12-31T21:30:00.000Z');
  });
  test('Page and post URLs remain distinct lookup candidates', () {
    expect(validMetaUrl('https://facebook.com'), isFalse);
    expect(validMetaUrl('https://facebook.com', page: true), isFalse);
    expect(validMetaUrl('https://facebook.com/proxo/posts/pfbid123'), isTrue);
    expect(
        validMetaUrl('https://facebook.com/proxo/posts/pfbid123', page: true),
        isFalse);
    expect(validMetaUrl('https://instagram.com/p/123'), isTrue);
    expect(validMetaUrl('https://instagram.com/p/123', page: true), isFalse);
    expect(validMetaUrl('https://facebook.com.evil.test/proxo'), isFalse);
  });
}
