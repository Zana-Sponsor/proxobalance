import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_locale.dart';
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
  @override
  void didUpdateWidget(covariant ProxoBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && widget.currentIndex != 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = _keys[widget.currentIndex].currentContext;
        if (context != null) Scrollable.ensureVisible(context, alignment: .5,
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180));
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final labels = ProxoLocale.isArabic
      ? ['الرئيسية', 'الإعلانات', 'إنشاء إعلان', 'الأدوات', 'الملف']
      : ['سەرەکی', 'ڕیکلامەکان', 'دروستکردنی ڕیکلام', 'ئامرازەکان', 'پڕۆفایل'];
    const icons = [SolarIconsOutline.home2, SolarIconsOutline.clapperboardPlay,
      SolarIconsBold.addCircle, SolarIconsOutline.widget_2, SolarIconsOutline.userRounded];
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
                          ? const Center(child: Icon(SolarIconsBold.addCircle, size: 48, color: AppColors.accent))
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            AnimatedContainer(duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
                              width: 48, height: 32,
                              decoration: BoxDecoration(color: active ? ProxoChrome.selected : Colors.transparent,
                                borderRadius: BorderRadius.circular(16)),
                              child: Icon(icons[i], size: ProxoChrome.iconSize, color: color)),
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
