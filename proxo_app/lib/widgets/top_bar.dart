import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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

  static const double _contentHeight = 54.0;
  static const double _sidePadding = 16.0;
  static const Color _ink = AppColors.ink;
  static const Color _hairline = Color(0xFFF2F3F5);

  static const double _iconSize = 21.0;
  static const double _logoHeight = 20.0;
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
        onTap: onBackTap,
        child: const Icon(Icons.arrow_forward_rounded, size: _iconSize, color: _ink),
      );
    }
    if (automaticallyImplyLeading && Navigator.canPop(context)) {
      return _BarIconButton(
        onTap: () => Navigator.maybePop(context),
        child: const Icon(Icons.arrow_forward_rounded, size: _iconSize, color: _ink),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMenuTap != null)
          _MenuIcon(color: _ink, onTap: onMenuTap),
        const SizedBox(width: 8),
        NotificationBell(
          onTap: onNotificationTap ?? () {},
          iconSize: _iconSize,
        ),
        if (onSearchTap != null) ...[
          const SizedBox(width: 6),
          _BarIconButton(
            onTap: onSearchTap,
            child: const Icon(Icons.search_rounded, size: _iconSize, color: _ink),
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
            Semantics(
              label: 'Proxo',
              image: true,
              child: Image.asset(
                _logoAsset,
                height: _logoHeight,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _BarIconButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(child: child),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;

  const _MenuIcon({required this.color, this.onTap});

  Widget _bar() => Container(
        width: 17,
        height: 1.8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _bar(),
            const SizedBox(height: 3.5),
            _bar(),
            const SizedBox(height: 3.5),
            _bar(),
          ],
        ),
      ),
    );
  }
}
