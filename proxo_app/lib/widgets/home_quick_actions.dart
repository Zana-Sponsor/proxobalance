import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/proxo_strings.dart';
import '../theme/app_locale.dart';
import '../theme/app_theme.dart';
import 'ad_form_components.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

/// Exactly three primary actions. Secondary destinations remain in navigation.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, this.onCreateTap, this.onAddBalanceTap,
    this.onCreatePageTap, this.onToolsTap, this.onFaqTap});
  final VoidCallback? onCreateTap, onAddBalanceTap, onCreatePageTap;
  // Retained for source compatibility; no extra Home buttons are rendered.
  final VoidCallback? onToolsTap, onFaqTap;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final titles = ['دروستکردنی ڕیکلام', 'زیادکردنی باڵانس', 'دروستکردنی پەڕە']
      .map(ProxoStrings.text).toList();
    const icons = [ProxoSymbolName.ads, ProxoSymbolName.wallet, ProxoSymbolName.tools];
    const keys = ['home-create-ad', 'home-add-balance', 'home-create-page'];
    final callbacks = [onCreateTap, onAddBalanceTap, onCreatePageTap];
    const style = TextStyle(fontFamily: kAppFont, fontSize: 13.5,
      fontWeight: FontWeight.w400, height: 1.55, color: AdUi.ink);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text) {
      final p = TextPainter(text: TextSpan(text: text, style: style),
        textDirection: TextDirection.rtl, textScaler: scaler)..layout();
      final w = p.width; p.dispose(); return w;
    }
    String balanced(String title) {
      final words = title.split(' ');
      if (words.length < 2) return title;
      var best = title; var score = double.infinity;
      for (var i = 1; i < words.length; i++) {
        final a = words.take(i).join(' '), b = words.skip(i).join(' ');
        final candidate = math.max(measure(a), measure(b));
        if (candidate < score) { score = candidate; best = '$a\n$b'; }
      }
      return best;
    }
    final labels = titles.map(balanced).toList();
    return Align(alignment: Alignment.topCenter, child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Directionality(textDirection: TextDirection.rtl,
        child: LayoutBuilder(builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - 20) / 3;
          final longestLine = labels.expand((s) => s.split('\n')).map(measure).reduce(math.max);
          final stacked = tileWidth - 20 < longestLine;
          Widget card(int i) => Semantics(button: true, enabled: callbacks[i] != null,
            label: titles[i], onTap: callbacks[i], excludeSemantics: true,
            child: Material(key: ValueKey(keys[i]),
              color: Colors.white, shape: const RoundedRectangleBorder(
                borderRadius: AdUi.radius, side: BorderSide(color: Color(0xFFE5EBF4))),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: callbacks[i], borderRadius: AdUi.radius,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 44, height: 44, alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.accentSoft,
                        borderRadius: BorderRadius.all(Radius.circular(14))),
                      child: ProxoSymbol(icons[i], size: 24,
                        color: callbacks[i] == null ? AdUi.secondary : AdUi.blue)),
                    const SizedBox(height: 12),
                    ProxoText(stacked ? titles[i] : labels[i], textAlign: TextAlign.center,
                      style: style.copyWith(color: callbacks[i] == null ? AdUi.secondary : AdUi.ink)),
                  ]),
                ),
              ),
            ),
          );
          return stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i=0;i<3;i++) ...[if(i>0) const SizedBox(height: 10),card(i)]])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for(var i=0;i<3;i++) ...[if(i>0) const SizedBox(width: 10),Expanded(child:card(i))]]);
        }),
      ),
    ));
  }
}
