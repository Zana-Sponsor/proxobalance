import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/proxo_strings.dart';
import '../theme/app_locale.dart';
import '../theme/app_theme.dart';
import 'ad_form_components.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

/// Three equal shortcuts at normal text size. Accessible text uses compact
/// horizontal rows only when the three-column labels would become too tall.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions(
      {super.key,
      this.onCreateTap,
      this.onAddBalanceTap,
      this.onCreatePageTap,
      this.onToolsTap,
      this.onFaqTap});
  final VoidCallback? onCreateTap, onAddBalanceTap, onCreatePageTap;
  final VoidCallback? onToolsTap, onFaqTap;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final titles = ['دروستکردنی ڕیکلام', 'زیادکردنی باڵانس', 'دروستکردنی پەڕە']
        .map(ProxoStrings.text)
        .toList();
    const icons = [
      ProxoSymbolName.ads,
      ProxoSymbolName.wallet,
      ProxoSymbolName.tools
    ];
    const keys = ['home-create-ad', 'home-add-balance', 'home-create-page'];
    final callbacks = [onCreateTap, onAddBalanceTap, onCreatePageTap];
    const style = TextStyle(
        fontFamily: kAppFont,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AdUi.ink);
    final scaler = MediaQuery.textScalerOf(context);
    double height(String text, double width) {
      final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.rtl,
          textScaler: scaler)
        ..layout(maxWidth: math.max(1, width));
      final value = painter.height;
      painter.dispose();
      return value;
    }

    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: LayoutBuilder(builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 20) / 3;
              final textHeight = titles
                  .map((title) => height(title, tileWidth - 16))
                  .reduce(math.max);
              final stacked = tileWidth < 76 || textHeight > 74;
              final rowHeight = titles
                  .map((title) => height(title, constraints.maxWidth - 80))
                  .reduce(math.max);
              final cardHeight = stacked
                  ? math.max(60.0, rowHeight + 24)
                  : math.max(110.0, textHeight + 68);
              Widget card(int i) {
                final icon = Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                    child: ProxoSymbol(icons[i],
                        size: 22,
                        color:
                            callbacks[i] == null ? AdUi.secondary : AdUi.blue));
                final label = ProxoText(titles[i],
                    textAlign: stacked ? TextAlign.start : TextAlign.center,
                    style: style.copyWith(
                        color:
                            callbacks[i] == null ? AdUi.secondary : AdUi.ink));
                return Semantics(
                  button: true,
                  enabled: callbacks[i] != null,
                  label: titles[i],
                  onTap: callbacks[i],
                  excludeSemantics: true,
                  child: Material(
                    key: ValueKey(keys[i]),
                    color: Colors.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        side: BorderSide(color: Color(0xFFE5EBF4))),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: callbacks[i],
                      child: SizedBox(
                        height: cardHeight,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: stacked ? 14 : 8, vertical: 12),
                          child: stacked
                              ? Row(children: [
                                  icon,
                                  const SizedBox(width: 12),
                                  Expanded(child: label)
                                ])
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                      icon,
                                      const SizedBox(height: 8),
                                      Expanded(
                                          child: Align(
                                              alignment: Alignment.topCenter,
                                              child: label))
                                    ]),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            card(i)
                          ]
                        ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: card(i))
                          ]
                        ]);
            }),
          ),
        ));
  }
}
