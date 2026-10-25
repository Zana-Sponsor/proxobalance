import '../theme/proxo_design_tokens.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'proxo_symbol.dart';

import '../l10n/proxo_strings.dart';
import 'proxo_text.dart';

abstract final class ResultsUi {
  static const ink = ProxoDesign.ink;
  static const muted = ProxoDesign.muted;
  static const blue = ProxoDesign.blue;
  static const line = ProxoDesign.line;
  static const banner = ProxoDesign.blueSoft;
  static const font = ProxoDesign.font;
  static const radius =
      BorderRadius.all(Radius.circular(ProxoDesign.cardRadius));
  static const thumbnailWidth = 56.0;
  static const thumbnailHeight = 64.0;
  static const thumbnailRadius = 12.0;
  static TextStyle text({double size = 14, Color color = ink}) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );
  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    final text = base.textTheme.apply(fontFamily: font);
    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      colorScheme: base.colorScheme.copyWith(
        primary: blue,
        surface: Colors.white,
      ),
    );
  }

  static String number(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  static String usd(double value) =>
      '\$${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';
}

class ResultIcon extends StatelessWidget {
  const ResultIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = ResultsUi.blue,
  });
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ProxoSymbol(
      switch (name) {
        'eye' => ProxoSymbolName.eye,
        'wallet' => ProxoSymbolName.wallet,
        'image' => ProxoSymbolName.gallery,
        'play' => ProxoSymbolName.play,
        'refresh' => ProxoSymbolName.refresh,
        'click' => ProxoSymbolName.click,
        _ => ProxoSymbolName.trophy,
      },
      size: size,
      color: color);
}

class ResultRank extends StatelessWidget {
  const ResultRank({super.key, required this.rank});
  final int rank;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ProxoDesign.blueSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          children: [
            const ResultIcon('trophy', size: 16, color: ResultsUi.blue),
            ProxoText('#$rank', style: ResultsUi.text(size: 12)),
          ],
        ),
      );
}

class ResultsStateCard extends StatelessWidget {
  const ResultsStateCard({
    super.key,
    this.error = false,
    required this.onRefresh,
  });
  final bool error;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: ResultsUi.radius,
              border: Border.all(color: ResultsUi.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ResultsUi.banner,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ResultIcon(
                    error ? 'refresh' : 'trophy',
                    size: 24,
                    color: ResultsUi.blue,
                  ),
                ),
                const SizedBox(height: 12),
                ProxoText(
                  error
                      ? 'ئەنجامەکان بار نەبوون'
                      : 'هێشتا ئەنجامی ئەم هەفتەیە هەڵنەبژێردراوە',
                  translate: true,
                  textAlign: TextAlign.center,
                  style: ResultsUi.text(size: 14),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('home-results-retry'),
                  onPressed: onRefresh,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    side: const BorderSide(color: ResultsUi.line),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: ProxoControls.shape,
                  ),
                  icon: const ResultIcon('refresh', size: 19),
                  label: ProxoText(
                    ProxoStrings.text('نوێکردنەوە'),
                    style: ResultsUi.text(color: ResultsUi.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
