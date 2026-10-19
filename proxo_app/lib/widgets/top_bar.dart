import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../theme/app_theme.dart';
import '../theme/proxo_chrome.dart';
import 'notification_bell.dart';
import 'proxo_symbol.dart';

/// The toolbar is 56dp; Scaffold adds the system inset exactly once.
class ProxoTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ProxoTopBar({
    super.key,
    this.onMenuTap,
    this.onBackTap,
    this.automaticallyImplyLeading = false,
    this.onNotificationTap,
    this.onSearchTap,
    this.actions = const <Widget>[],
    this.topPadding = 0,
    this.userName = '—',
    this.balance = '0 IQD',
    this.onBalanceTap,
  });

  final VoidCallback? onMenuTap;
  final VoidCallback? onBackTap;
  final bool automaticallyImplyLeading;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSearchTap;
  final List<Widget> actions;

  /// Legacy minimum inset, excluded from preferredSize to avoid double space.
  final double topPadding;
  final String userName;
  final String balance;
  final VoidCallback? onBalanceTap;

  @override
  Size get preferredSize => const Size.fromHeight(ProxoChrome.toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final back = onBackTap ??
        (automaticallyImplyLeading && Navigator.canPop(context)
            ? () => Navigator.maybePop(context)
            : null);
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        minimum: EdgeInsets.only(top: topPadding),
        child: Container(
          key: const ValueKey('proxo-toolbar'),
          height: ProxoChrome.toolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: ProxoChrome.border))),
          child: Row(children: [
            if (back != null)
              _BarIconButton(
                  label: 'گەڕانەوە',
                  onTap: back,
                  symbol: Directionality.of(context) == TextDirection.rtl
                      ? ProxoSymbolName.back
                      : ProxoSymbolName.forward)
            else ...[
              if (onMenuTap != null)
                _BarIconButton(
                    label: 'مێنیو',
                    onTap: onMenuTap,
                    symbol: ProxoSymbolName.menu),
              if (onNotificationTap != null)
                NotificationBell(
                    onTap: onNotificationTap!,
                    iconSize: ProxoChrome.toolbarIconSize),
              if (onSearchTap != null)
                _BarIconButton(
                    label: 'گەڕان',
                    onTap: onSearchTap,
                    symbol: ProxoSymbolName.search),
              ...actions,
            ],
            const Spacer(),
            Semantics(
                label: 'Proxo',
                image: true,
                child: Image.asset('assets/images/proxo_logo.png',
                    key: const ValueKey('proxo-toolbar-logo'),
                    height: 24,
                    width: 84,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true)),
          ]),
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton(
      {required this.onTap, required this.label, required this.symbol});
  final VoidCallback? onTap;
  final String label;
  final ProxoSymbolName symbol;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: ProxoStrings.text(label),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: const EdgeInsets.all(12),
        icon: ProxoSymbol(symbol,
            size: ProxoChrome.toolbarIconSize, color: AppColors.ink),
      );
}
