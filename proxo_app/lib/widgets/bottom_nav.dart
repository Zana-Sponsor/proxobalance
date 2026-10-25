import '../theme/app_locale.dart';
import '../l10n/proxo_strings.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'proxo_symbol.dart';
import '../theme/app_theme.dart';
import '../theme/proxo_chrome.dart';
import 'proxo_text.dart';
import 'ad_brand_logo.dart';

/// All destinations share Solar Outline, a 24dp glyph and a 48dp minimum
/// target. At large text sizes the strip scrolls instead of shrinking labels.
/// Physical tab order and the create-ad callback remain unchanged.
class ProxoBottomNav extends StatefulWidget {
  const ProxoBottomNav(
      {super.key,
      required this.currentIndex,
      required this.onTap,
      this.metaEnabled = false,
      this.accentColor,
      this.mutedColor,
      this.dividerColor,
      this.onCreatePlatform});
  final Color? accentColor, mutedColor, dividerColor;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool metaEnabled;
  final ValueChanged<String>? onCreatePlatform;
  @override
  State<ProxoBottomNav> createState() => _ProxoBottomNavState();
}

class _ProxoBottomNavState extends State<ProxoBottomNav> {
  final _keys = List.generate(5, (_) => GlobalKey());
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  LocalHistoryEntry? _history;
  bool _expanded = false;

  void _close() {
    if (!_expanded) return;
    _portal.hide();
    final history = _history;
    _history = null;
    history?.remove();
    if (mounted) setState(() => _expanded = false);
  }

  void _tap(int index) {
    if (index != 2 || !widget.metaEnabled || widget.onCreatePlatform == null) {
      _close();
      widget.onTap(index);
      return;
    }
    if (_expanded) {
      _close();
      return;
    }
    _history = LocalHistoryEntry(onRemove: () {
      _history = null;
      _close();
    });
    ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    setState(() => _expanded = true);
    _portal.show();
  }

  @override
  void dispose() {
    _expanded = false;
    _history?.remove();
    super.dispose();
  }

  Offset _launcherOffset(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(280.0, screenWidth - 32);
    final box = _keys[2].currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return const Offset(0, -10);
    final center = box.localToGlobal(Offset(box.size.width / 2, 0)).dx;
    final bounded = center.clamp(16 + width / 2, screenWidth - 16 - width / 2);
    return Offset(bounded - center, -10);
  }

  Widget _launcher(BuildContext context, Widget child) => OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Positioned(
            width: math.min(280, MediaQuery.sizeOf(context).width - 32),
            child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.bottomCenter,
                offset: _launcherOffset(context),
                child: TapRegion(
                    groupId: this,
                    onTapOutside: (_) => _close(),
                    child: Material(
                        elevation: 5,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Row(children: [
                                  for (final platform in const [
                                    ('META', 'meta', 'مێتا'),
                                    ('TIKTOK', 'tiktok', 'تیک تۆک')
                                  ])
                                    Expanded(
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 3),
                                            child: OutlinedButton(
                                                key: ValueKey(
                                                    'create-platform-${platform.$1}'),
                                                style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 12),
                                                    minimumSize:
                                                        const Size(0, 48)),
                                                onPressed: () {
                                                  _close();
                                                  widget.onCreatePlatform
                                                      ?.call(platform.$1);
                                                },
                                                child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      AdBrandLogo(platform.$2,
                                                          size: 22),
                                                      const SizedBox(height: 4),
                                                      ProxoText(platform.$3,
                                                          textAlign: TextAlign
                                                              .center,
                                                          style:
                                                              const TextStyle(
                                                                  fontFamily:
                                                                      kAppFont,
                                                                  fontSize:
                                                                      13)),
                                                    ])))),
                                ]))))))),
        child: TapRegion(
            groupId: this,
            child: CompositedTransformTarget(link: _link, child: child)),
      );
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expanded || widget.currentIndex == 2) return;
      final context = _keys[widget.currentIndex].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context,
            alignment: .5,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_expanded && ModalRoute.isCurrentOf(context) == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant ProxoBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex || !widget.metaEnabled) {
      _close();
    }
    if (oldWidget.currentIndex != widget.currentIndex) _revealSelected();
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final labels = [
      'سەرەکی',
      'ڕیکلامەکان',
      'دروستکردنی ڕیکلام',
      'ئامرازەکان',
      'پڕۆفایل'
    ].map(ProxoStrings.text).toList();
    const icons = [
      ProxoSymbolName.home,
      ProxoSymbolName.ads,
      ProxoSymbolName.add,
      ProxoSymbolName.tools,
      ProxoSymbolName.user
    ];
    const style = TextStyle(fontFamily: kAppFont, fontSize: 12, height: 1.5);
    double labelWidth = 0, labelHeight = 0;
    for (final i in [0, 1, 3, 4]) {
      final painter = TextPainter(
          text: TextSpan(text: labels[i], style: style),
          textDirection: TextDirection.rtl,
          textScaler: MediaQuery.textScalerOf(context))
        ..layout();
      labelWidth = math.max(labelWidth, painter.width);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    final height = math.max(80.0, 24 + 6 + labelHeight + 24);
    return Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: widget.dividerColor ?? ProxoChrome.border))),
            child: LayoutBuilder(builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, 640.0);
              final slot = math.max(width / 5, math.max(56.0, labelWidth + 16));
              return Align(
                  heightFactor: 1,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: List.generate(5, (i) {
                          final active = i != 2 && widget.currentIndex == i;
                          final color = active
                              ? (widget.accentColor ?? AppColors.accent)
                              : (widget.mutedColor ?? AppColors.inkMuted);
                          final item = Semantics(
                            key: _keys[i],
                            button: true,
                            selected: active,
                            label: i == 2 && _expanded
                                ? ProxoStrings.text('داخستن')
                                : labels[i],
                            onTap: () => _tap(i),
                            excludeSemantics: true,
                            child: Tooltip(
                                message: labels[i],
                                child: InkWell(
                                  key: ValueKey('bottom-nav-$i'),
                                  onTap: () => _tap(i),
                                  child: SizedBox(
                                    width: slot,
                                    height: height,
                                    child: i == 2
                                        ? Center(
                                            child: Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                    color: widget.accentColor ??
                                                        AppColors.accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18)),
                                                alignment: Alignment.center,
                                                child: AnimatedRotation(
                                                    turns: _expanded ? .125 : 0,
                                                    duration: MediaQuery.disableAnimationsOf(context)
                                                        ? Duration.zero
                                                        : const Duration(
                                                            milliseconds: 180),
                                                    curve: Curves.easeOutCubic,
                                                    child: const Icon(
                                                        Icons.add_rounded,
                                                        size: 28,
                                                        color: Colors.white))))
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                                AnimatedContainer(
                                                    duration: MediaQuery
                                                            .disableAnimationsOf(
                                                                context)
                                                        ? Duration.zero
                                                        : const Duration(
                                                            milliseconds: 160),
                                                    width: 48,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                        color: active
                                                            ? ProxoChrome
                                                                .selected
                                                            : Colors
                                                                .transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16)),
                                                    child: ProxoSymbol(icons[i],
                                                        size: ProxoChrome
                                                            .iconSize,
                                                        color: color)),
                                                const SizedBox(height: 6),
                                                ProxoText(labels[i],
                                                    textDirection:
                                                        TextDirection.rtl,
                                                    maxLines: 1,
                                                    style: style.copyWith(
                                                        color: color,
                                                        fontWeight: active
                                                            ? FontWeight.w600
                                                            : FontWeight.w400)),
                                              ]),
                                  ),
                                )),
                          );
                          return i == 2 ? _launcher(context, item) : item;
                        })),
                      ),
                    ),
                  ));
            }),
          ),
        ));
  }
}
