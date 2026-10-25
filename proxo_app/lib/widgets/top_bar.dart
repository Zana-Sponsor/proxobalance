import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import '../theme/proxo_ui.dart';
import 'auth/auth_design.dart';
import 'notification_bell.dart';

/// Shared app bar: a stable 56 dp row and 48 dp interactive targets.
class ProxoTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onBackTap;
  final bool automaticallyImplyLeading;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSearchTap;
  final List<Widget> actions;
  final double topPadding;
  final String userName;
  final String balance;
  final VoidCallback? onBalanceTap;
  final int? notificationCount;

  const ProxoTopBar({
    super.key,
    this.onMenuTap,
    this.onBackTap,
    this.automaticallyImplyLeading = false,
    this.onNotificationTap,
    this.onSearchTap,
    this.actions = const [],
    this.topPadding = 0,
    this.userName = '—',
    this.balance = '0 IQD',
    this.onBalanceTap,
    this.notificationCount,
  });

  @override
  Size get preferredSize => Size.fromHeight(56 + topPadding);

  @override
  Widget build(BuildContext context) {
    final back = onBackTap ??
        (automaticallyImplyLeading && Navigator.canPop(context)
            ? () {
                Navigator.maybePop(context);
              }
            : null);
    return Container(
      height: preferredSize.height,
      padding: EdgeInsetsDirectional.only(start: 8, end: 16, top: topPadding),
      decoration: const BoxDecoration(
        color: AuthTokens.pageBackground,
        border: Border(bottom: BorderSide(color: AuthTokens.lineOff)),
      ),
      child: Row(children: [
        if (back != null)
          _BarIconButton(
            onTap: back,
            label: 'گەڕانەوە',
            icon: Directionality.of(context) == TextDirection.rtl
                ? SolarIcons.arrowRight
                : SolarIcons.arrowLeft,
          )
        else ...[
          if (onMenuTap != null)
            _BarIconButton(
                onTap: onMenuTap,
                label: 'مێنیو',
                icon: SolarIcons.hamburgerMenu),
          NotificationBell(
            onTap: onNotificationTap ??
                () => Navigator.of(context).pushNamed('/notifications'),
            iconSize: ProxoUi.iconSize,
            count: notificationCount,
          ),
          if (onSearchTap != null)
            _BarIconButton(
                onTap: onSearchTap, label: 'گەڕان', icon: SolarIcons.magnifier),
          ...actions,
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              label: 'Proxo',
              image: true,
              child: Image.asset('assets/images/proxo_logo.png',
                  height: 22,
                  width: 88,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton(
      {required this.onTap, required this.label, required this.icon});
  final VoidCallback? onTap;
  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.all(12),
        icon: SolarIcon(icon, size: ProxoUi.iconSize, color: AuthTokens.ink),
      );
}
