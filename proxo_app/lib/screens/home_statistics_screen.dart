import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import '../theme/proxo_ui.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxo_empty_state.dart';

/// These are cumulative counters from the existing pa_ads query. They are not
/// represented as daily performance: created_at is not a metric event date.
class HomeStatisticsScreen extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() loadAds;
  const HomeStatisticsScreen({super.key, required this.loadAds});
  @override
  State<HomeStatisticsScreen> createState() => _HomeStatisticsScreenState();
}

class _HomeStatisticsScreenState extends State<HomeStatisticsScreen> {
  late Future<List<Map<String, dynamic>>> _rows;
  @override
  void initState() {
    super.initState();
    _rows = widget.loadAds();
  }

  void _retry() {
    final request = widget.loadAds();
    setState(() { _rows = request; });
  }
  num _number(dynamic value) =>
      value is num ? value : num.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: ProxoUi.background,
          appBar: AppBar(
              title: const ProxoText('ئامارەکان', style: ProxoUi.title),
              leading: IconButton(
                  tooltip: 'گەڕانەوە',
                  onPressed: () => Navigator.pop(context),
                  icon: const SolarIcon(SolarIcons.altArrowRight,
                      style: SolarIconStyle.linear,
                      size: ProxoUi.iconSize,
                      color: ProxoUi.ink))),
          body: FutureBuilder<List<Map<String, dynamic>>>(
              future: _rows,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return SingleChildScrollView(
                      child: ProxoEmptyState(
                          icon: const SolarIcon(SolarIcons.dangerTriangle,
                              size: 32, color: ProxoUi.primary),
                          title: 'ئامارەکان بار نەبوون',
                          description:
                              'پەیوەندییەکەت بپشکنە و دووبارە هەوڵ بدەرەوە.',
                          actionLabel: 'دووبارە',
                          onAction: _retry));
                }
                final ads = snapshot.data ?? [];
                if (ads.isEmpty) {
                  return const SingleChildScrollView(
                      child: ProxoEmptyState(
                          icon: SolarIcon(SolarIcons.target,
                              size: 32, color: ProxoUi.primary),
                          title: 'هێشتا ئامار نییە',
                          description: 'ئەنجامی ڕیکلامەکانت لێرە دەردەکەوێت.'));
                }
                double total(String field) =>
                    ads.fold(0.0, (sum, row) => sum + _number(row[field]));
                final spend = total('spend') + total('prev_spend');
                final impressions =
                    total('impressions') + total('prev_impressions');
                final clicks = total('clicks');
                final metrics = <(String, String)>[
                  ('تێچووی گشتی', '\$${spend.toStringAsFixed(2)}'),
                  ('بینین', impressions.toInt().toString()),
                  ('کرتە', clicks.toInt().toString()),
                  ('گۆڕین', total('conversions').toInt().toString()),
                  (
                    'CTR',
                    '${(impressions == 0 ? 0 : clicks / impressions * 100).toStringAsFixed(2)}%'
                  ),
                ];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(ProxoUi.pagePadding),
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const ProxoText('کۆی ئەنجامی ڕیکلامەکانت',
                                    style: ProxoUi.sectionTitle),
                                const SizedBox(height: 8),
                                const ProxoText(
                                    'ئەم ژمارانە کۆی داتای تۆمارکراوی هەموو ڕیکلامەکانتن.',
                                    style: ProxoUi.secondary),
                                const SizedBox(height: 24),
                                for (final metric in metrics) ...[
                                  Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: ProxoUi.cardDecoration,
                                      child: Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          spacing: 16,
                                          runSpacing: 8,
                                          children: [
                                            ProxoText(metric.$1,
                                                style: ProxoUi.body),
                                            ProxoText(metric.$2,
                                                style: ProxoUi.amount)
                                          ])),
                                  const SizedBox(height: 12),
                                ],
                              ]))),
                );
              }),
        ),
      );
}
