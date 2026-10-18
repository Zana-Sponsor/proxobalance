import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../theme/proxo_chrome.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

/// Shared secondary-screen header. Scaffold owns the status-bar inset.
class ProxoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProxoAppBar({
    super.key,
    required this.title,
    this.actions,
    this.toolbarHeight = 64,
    this.titleStyle,
    this.titleMaxLines = 2,
  });
  final String title;
  final double toolbarHeight;
  final TextStyle? titleStyle;
  final int? titleMaxLines;
  final List<Widget>? actions;
  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: toolbarHeight,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    leadingWidth: 56,
    leading: IconButton(
      tooltip: ProxoStrings.text('گەڕانەوە'),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () => Navigator.of(context).maybePop(),
      icon: ProxoSymbol(
        Directionality.of(context) == TextDirection.rtl
            ? ProxoSymbolName.back
            : ProxoSymbolName.forward,
      ),
    ),
    title: ProxoText(
      title,
      translate: true,
      maxLines: titleMaxLines,
      style:
          titleStyle ??
          const TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF0F172A)),
    ),
    actions: actions,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: ProxoChrome.border),
    ),
  );
}
