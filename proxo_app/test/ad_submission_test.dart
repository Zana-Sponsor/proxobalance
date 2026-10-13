import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/ad_forecast.dart';

AdDraft validDraft(
        {String goal = 'views', String? asset, bool immediate = true}) =>
    AdDraft(
        title: 'ڕیکلام ABC-123',
        link: 'https://www.tiktok.com/@proxo/video/123456789',
        code: 'VIDEO-ABC-123',
        goal: goal,
        category: 'cosmetics_beauty',
        assetId: asset,
        paymentMethod: 'app_balance',
        schedule: DateTime(2030, 1, 1),
        immediate: immediate);

void main() {
  test('form validation covers required fields and invalid targeting', () {
    final errors = const AdDraft().validate();
    expect(
        errors.keys,
        containsAll([
          'title',
          'code',
          'link',
          'goal',
          'category',
          'schedule',
          'payment'
        ]));
    expect(validDraft().validate(), isEmpty);
    expect(validDraft(goal: 'messages').validate(), contains('asset'));
    expect(
        validDraft(goal: 'messages', asset: 'contact-id').validate(), isEmpty);
    expect(
        const AdDraft(dailyBudget: 15, days: 10, ages: ['all', '18-24'])
            .validate()
            .keys,
        containsAll(['budget', 'audience']));
  });
  test('scheduling validates future dates, immediate uses server clock', () {
    final old = AdDraft.fromJson({
      ...validDraft().toJson(),
      'start_date': '2000-01-01',
      'start_immediately': false
    });
    expect(old.validate(), contains('schedule'));
    expect(
        AdDraft.fromJson({...old.toJson(), 'start_immediately': true})
            .validate(),
        isEmpty);
  });
  test('frozen submission survives serialization without bidi controls', () {
    final request = AdPendingSubmission.create(
        validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
    final restored = AdPendingSubmission.fromJson(request.toJson());
    expect(restored.id, request.id);
    expect(restored.draft.toJson(), request.draft.toJson());
    expect(restored.fastPayOrderId.length, lessThanOrEqualTo(32));
    expect(restored.draft.toJson().toString(), isNot(contains('\u2066')));
  });
  test('daily budget multiplication never compounds an earlier total', () {
    var q = const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800);
    for (final days in [2, 3, 5, 1, 7, 2]) {
      q = q.forBudget(10, days);
      expect(q.grossUsd, 10 * days);
      expect(q.totalIqd, 18000 * days);
      expect(q.sponsorIqd + q.serviceIqd, q.grossIqd);
    }
  });
  test('frozen checkout uses the exact server-quoted IQD amount', () {
    final quote = AdQuote.fromJson(const {
      'gross_usd': 10,
      'cost_usd': 10,
      'rate': 1800,
      'amount_iqd': 17999
    });
    expect(quote.totalIqd, 17999);
    expect(AdQuote.fromJson(quote.toJson()).totalIqd, 17999);
    expect(quote.forBudget(10, 2).totalIqd, 36000);
  });
  test(
      'fee is included, percentage/fixed coupons and levels use existing formula',
      () {
    const q = AdQuote(
        grossUsd: 10,
        costUsd: 10,
        rate: 1800,
        promoPercent: 10,
        levelPercent: 5,
        levelFixedIqd: 1800);
    final twoDays = q.forBudget(10, 2);
    expect(twoDays.grossUsd, 20);
    expect(twoDays.serviceIqd, 7200);
    expect(twoDays.promoUsd, 2);
    expect(twoDays.levelUsd, 2);
    expect(twoDays.costUsd, 16);
    expect(twoDays.forBudget(10, 1, clearPromo: true).promoUsd, 0);
    expect(
        const AdQuote(
                grossUsd: 10, costUsd: 10, rate: 1800, promoFixedIqd: 2000)
            .forBudget(10, 2)
            .promoIqd,
        2000);
    expect(adIqd(2000, discount: true), '−2,000 د.ع');
  });
  test(
      'views forecast uses delivery budget and never counts every impression as a view',
      () {
    final f = AdForecast.calculate(goal: 'views', dailyBudget: 10, days: 1);
    expect(f.viewsLow, (8 / 0.18 * 1000 * 0.6).floor());
    expect(f.viewsHigh, (8 / 0.12 * 1000 * 0.8).floor());
    expect(f.clicksLow, isNull);
    expect(f.provisionalViews, isTrue);
    final doubled =
        AdForecast.calculate(goal: 'views', dailyBudget: 10, days: 2);
    expect(doubled.viewsLow, closeTo(f.viewsLow * 2, 1));
  });
  test('messages forecast has contact clicks and historical view-rate bounds',
      () {
    final f = AdForecast.calculate(
        goal: 'messages', dailyBudget: 20, days: 3, historicalViewRate: 0.72);
    expect(f.provisionalViews, isFalse);
    expect(f.viewsLow, lessThan(f.viewsHigh));
    expect(f.clicksLow, (48 / 0.25 * 1000 * 0.005).floor());
    expect(f.clicksHigh, (48 / 0.15 * 1000 * 0.012).floor());
  });
}
