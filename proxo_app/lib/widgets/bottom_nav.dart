import '../theme/app_locale.dart';
import '../l10n/proxo_strings.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'proxo_symbol.dart';
import '../theme/app_theme.dart';
import '../theme/proxo_chrome.dart';
import 'proxo_text.dart';

/// All destinations share Solar Outline, a 24dp glyph and a 48dp minimum
/// target. At large text sizes the strip scrolls instead of shrinking labels.
/// Physical tab order and the create-ad callback remain unchanged.
class ProxoBottomNav extends StatefulWidget {
  const ProxoBottomNav({super.key, required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;
  @override
  State<ProxoBottomNav> createState() => _ProxoBottomNavState();
}

class _ProxoBottomNavState extends State<ProxoBottomNav> {
  final _keys = List.generate(5, (_) => GlobalKey());
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.currentIndex == 2) return;
      final context = _keys[widget.currentIndex].currentContext;
      if (context != null) Scrollable.ensureVisible(context, alignment: .5,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180));
    });
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _revealSelected(); }
  @override
  void didUpdateWidget(covariant ProxoBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) _revealSelected();
  }
  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final labels = ['سەرەکی', 'ڕیکلامەکان', 'دروستکردنی ڕیکلام', 'ئامرازەکان', 'پڕۆفایل'].map(ProxoStrings.text).toList();
    const icons = [ProxoSymbolName.home, ProxoSymbolName.ads,
      ProxoSymbolName.add, ProxoSymbolName.tools, ProxoSymbolName.user];
    const style = TextStyle(fontFamily: kAppFont, fontSize: 12, height: 1.5);
    double labelWidth = 0, labelHeight = 0;
    for (final i in [0, 1, 3, 4]) {
      final painter = TextPainter(text: TextSpan(text: labels[i], style: style),
        textDirection: TextDirection.rtl, textScaler: MediaQuery.textScalerOf(context))..layout();
      labelWidth = math.max(labelWidth, painter.width);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    final height = math.max(80.0, 24 + 6 + labelHeight + 24);
    return Material(color: Colors.white, child: SafeArea(top: false,
      child: Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: ProxoChrome.border))),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 640.0);
          final slot = math.max(width / 5, math.max(56.0, labelWidth + 16));
          return Align(heightFactor: 1, child: SizedBox(width: width, height: height,
            child: Directionality(textDirection: TextDirection.ltr,
              child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: List.generate(5, (i) {
                  final active = i != 2 && widget.currentIndex == i;
                  final color = active ? AppColors.accent : AppColors.inkMuted;
                  return Semantics(key: _keys[i], button: true, selected: active,
                    label: labels[i], onTap: () => widget.onTap(i), excludeSemantics: true,
                    child: Tooltip(message: labels[i], child: InkWell(
                      key: ValueKey('bottom-nav-$i'), onTap: () => widget.onTap(i),
                      child: SizedBox(width: slot, height: height,
                        child: i == 2
                          ? Center(child: Container(width: 56, height: 56,
                              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const ProxoSymbol(ProxoSymbolName.add, size: 36, color: Colors.white)))
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            AnimatedContainer(duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
                              width: 48, height: 32,
                              decoration: BoxDecoration(color: active ? ProxoChrome.selected : Colors.transparent,
                                borderRadius: BorderRadius.circular(16)),
                              child: ProxoSymbol(icons[i], size: ProxoChrome.iconSize, color: color)),
                            const SizedBox(height: 6),
                            ProxoText(labels[i], textDirection: TextDirection.rtl, maxLines: 1,
                              style: style.copyWith(color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                          ]),
                      ),
                    )),
                  );
                })),
              ),
            ),
          ));
        }),
      ),
    ));
  }
}
