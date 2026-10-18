import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/proxo_strings.dart';
import 'proxo_text.dart';

abstract final class ResultsUi {
  static const ink = Color(0xFF182338);
  static const muted = Color(0xFF667085);
  static const blue = Color(0xFF046CFA);
  static const line = Color(0xFFE7EBF1);
  static const banner = Color(0xFFF5F0E8);
  static const font = 'RabarAuthRegular';
  static const radius = BorderRadius.all(Radius.circular(20));
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
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      'assets/icons/results/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  );
}

class ResultRank extends StatelessWidget {
  const ResultRank({super.key, required this.rank});
  final int rank;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ResultsUi.line),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      children: [
        const ResultIcon('trophy', size: 17, color: Color(0xFFB77918)),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: ResultsUi.radius,
          border: Border.all(color: ResultsUi.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ResultsUi.banner,
                borderRadius: BorderRadius.circular(22),
              ),
              child: ResultIcon(
                error ? 'refresh' : 'trophy',
                size: 34,
                color: const Color(0xFFB77918),
              ),
            ),
            const SizedBox(height: 20),
            ProxoText(
              error
                  ? 'ئەنجامەکان بار نەبوون'
                  : 'هێشتا ئەنجامی ئەم هەفتەیە هەڵنەبژێردراوە',
              translate: true,
              textAlign: TextAlign.center,
              style: ResultsUi.text(size: 16),
            ),
            const SizedBox(height: 20),
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
