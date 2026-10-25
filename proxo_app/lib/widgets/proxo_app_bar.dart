import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../theme/app_locale.dart';
import '../theme/proxo_chrome.dart';
import '../theme/proxo_design_tokens.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

/// Shared secondary-screen header. Scaffold owns the status-bar inset.
class ProxoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProxoAppBar({
    super.key,
    required this.title,
    this.actions,
    this.toolbarHeight = ProxoChrome.toolbarHeight,
    this.titleStyle,
    this.titleMaxLines = 2,
  });

  /// Measure before Scaffold reads preferredSize, so accessibility text can
  /// grow the header instead of being clipped inside a fixed-height toolbar.
  factory ProxoAppBar.adaptive(
    BuildContext context, {
    Key? key,
    required String title,
    List<Widget>? actions,
    TextStyle? titleStyle,
  }) {
    final style = titleStyle ?? ProxoDesign.appBar;
    final sideWidth = _sideWidth(actions);
    final painter = TextPainter(
      text: TextSpan(text: ProxoStrings.text(title), style: style),
      textDirection: ProxoLocale.directionOf(ProxoLocale.current.value),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(
        maxWidth: math.max(
            1, MediaQuery.sizeOf(context).width - 2 * (sideWidth + 16)));
    final height = math.max(ProxoChrome.toolbarHeight, painter.height + 16);
    painter.dispose();
    return ProxoAppBar(
      key: key,
      title: title,
      actions: actions,
      titleStyle: style,
      titleMaxLines: null,
      toolbarHeight: height,
    );
  }

  static double _sideWidth(List<Widget>? actions) =>
      math.max(60, (actions?.length ?? 0) * ProxoChrome.actionSize + 12);
  final String title;
  final double toolbarHeight;
  final TextStyle? titleStyle;
  final int? titleMaxLines;
  final List<Widget>? actions;
  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
  @override
  Widget build(BuildContext context) {
    final direction = ProxoLocale.directionOf(ProxoLocale.watch(context));
    final sideWidth = _sideWidth(actions);
    return Directionality(
      textDirection: direction,
      child: AppBar(
        toolbarHeight: toolbarHeight,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: sideWidth,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                tooltip: ProxoStrings.text('گەڕانەوە'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: ProxoSymbol(
                  direction == TextDirection.rtl
                      ? ProxoSymbolName.back
                      : ProxoSymbolName.forward,
                  size: ProxoChrome.toolbarIconSize,
                ),
              )),
        ),
        titleSpacing: 16,
        title: ProxoText(
          title,
          key: const ValueKey('proxo-screen-title'),
          translate: true,
          textAlign: TextAlign.center,
          // AppBar otherwise disables wrapping and clamps accessibility scale.
          // Match the factory's measured title, including the user's scaler.
          softWrap: true,
          overflow: TextOverflow.visible,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: titleMaxLines,
          style: titleStyle ?? ProxoDesign.appBar,
        ),
        actions: [
          SizedBox(
            width: sideWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in actions ?? const <Widget>[])
                  SizedBox(width: ProxoChrome.actionSize, child: action),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: ProxoChrome.border),
        ),
      ),
    );
  }
}
