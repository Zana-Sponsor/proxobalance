import '../l10n/proxo_strings.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/proxo_chrome.dart';
import 'package:solar_icons/solar_icons.dart';
import 'notification_bell.dart';

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

  static const double _contentHeight = 56.0;
  static const double _sidePadding = 12.0;
  static const Color _ink = AppColors.ink;
  static const Color _hairline = Color(0xFFF2F3F5);

  static const double _iconSize = ProxoChrome.iconSize;
  static const double _logoHeight = 24.0;
  static const String _logoAsset = 'assets/images/proxo_logo.png';

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

  @override
  Size get preferredSize => Size.fromHeight(_contentHeight + topPadding);

  Widget _buildRightCluster(BuildContext context) {
    if (onBackTap != null) {
      return _BarIconButton(
        onTap: onBackTap, label: 'گەڕانەوە',
        child: const ProxoSolarIcon(SolarIconsOutline.altArrowRight, size: _iconSize, color: _ink),
      );
    }
    if (automaticallyImplyLeading && Navigator.canPop(context)) {
      return _BarIconButton(
        onTap: () => Navigator.maybePop(context), label: 'گەڕانەوە',
        child: const ProxoSolarIcon(SolarIconsOutline.altArrowRight, size: _iconSize, color: _ink),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMenuTap != null)
          _BarIconButton(onTap: onMenuTap, label: 'مێنیو', child: const ProxoSolarIcon(SolarIconsOutline.hamburgerMenu, size: _iconSize, color: _ink)),

        NotificationBell(
          onTap: onNotificationTap ?? () {},
          iconSize: _iconSize,
        ),
        if (onSearchTap != null) ...[

          _BarIconButton(
            onTap: onSearchTap, label: 'گەڕان',
            child: const ProxoSolarIcon(SolarIconsOutline.magnifier, size: _iconSize, color: _ink),
          ),
        ],
        ...actions,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _contentHeight + topPadding,
      padding: EdgeInsets.only(
        top: topPadding,
        left: _sidePadding,
        right: _sidePadding,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _hairline, width: 1)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // بەشی لای ڕاست: مێنیو + زەنگ
            _buildRightCluster(context),

            // بەشی لای چەپ: لۆگۆ
            Flexible(child: Semantics(
              label: 'Proxo',
              image: true,
              child: Image.asset(
                _logoAsset,
                height: _logoHeight,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String label;
  const _BarIconButton({required this.onTap, required this.child, required this.label});
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap, tooltip: ProxoStrings.text(label),
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    padding: const EdgeInsets.all(12), icon: child,
  );
}
