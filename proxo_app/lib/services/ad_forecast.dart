import 'proxo_pricing.dart';

const adForecastDisclaimer =
    'ئەم ژمارانە تەنها پێشبینی ئەنجامن و تیک تۆک ئەنجامەکان دیاری دەکات، لەوانەیە ڕێژەکە زیاتر یان کەمتر بێت لە ئەنجامی پێشبینی کراو.';

/// Planning assumptions, not guaranteed performance. CPM stays internal.
class AdForecast {
  final int viewsLow, viewsHigh;
  final int? clicksLow, clicksHigh;
  final bool provisionalViews;
  const AdForecast(
      {required this.viewsLow,
      required this.viewsHigh,
      this.clicksLow,
      this.clicksHigh,
      required this.provisionalViews});

  factory AdForecast.calculate(
      {required String goal,
      required int dailyBudget,
      required int days,
      double? historicalViewRate}) {
    final messages = goal == 'messages';
    final minCpm = messages ? 0.15 : 0.12;
    final maxCpm = messages ? 0.25 : 0.18;
    // Existing pricing includes a 20% service fee. Discounts affect checkout,
    // not delivery; never forecast using the discounted amount paid.
    final delivery = dailyBudget * days * (1 - ProxoPricing.serviceFeePercent);
    final impressionsLow = delivery / maxCpm * 1000;
    final impressionsHigh = delivery / minCpm * 1000;
    final validHistory = historicalViewRate != null &&
        historicalViewRate > 0 &&
        historicalViewRate < 1;
    final viewLow =
        validHistory ? (historicalViewRate * 0.85).clamp(0.05, 0.95) : 0.60;
    final viewHigh =
        validHistory ? (historicalViewRate * 1.15).clamp(0.05, 0.95) : 0.80;
    // pa_ads.clicks has no verified destination-click attribution. Until that
    // exists, contact-page CTR is explicitly provisional, not claimed history.
    return AdForecast(
        viewsLow: (impressionsLow * viewLow).floor(),
        viewsHigh: (impressionsHigh * viewHigh).floor(),
        clicksLow: messages ? (impressionsLow * 0.005).floor() : null,
        clicksHigh: messages ? (impressionsHigh * 0.012).floor() : null,
        provisionalViews: !validHistory);
  }
}
