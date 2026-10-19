import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/proxo_strings.dart';
import '../services/unread_notification_counter.dart';
import '../theme/app_theme.dart';
import '../theme/proxo_chrome.dart';
import 'proxo_symbol.dart';

/// Shares one owner-filtered unread subscription with every drawer and bell.
class NotificationBell extends StatefulWidget {
  const NotificationBell(
      {super.key,
      required this.onTap,
      this.iconSize = ProxoChrome.toolbarIconSize});
  final VoidCallback onTap;
  final double iconSize;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final UnreadNotificationCounter _counter;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _counter = UnreadNotificationCounter.forClient(Supabase.instance.client);
    _unread = _counter.count.value;
    _counter.count.addListener(_countChanged);
    _counter.acquire();
  }

  @override
  void dispose() {
    _counter.count.removeListener(_countChanged);
    _counter.release();
    _pulse.dispose();
    super.dispose();
  }

  void _countChanged() {
    if (!mounted || _unread == _counter.count.value) return;
    setState(() => _unread = _counter.count.value);
    if (_unread > 0 && !MediaQuery.disableAnimationsOf(context)) {
      _pulse.forward(from: 0);
    } else {
      _pulse.reset();
    }
  }

  void _open() {
    // A second tap during the route transition must not stack notifications.
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final label = ProxoStrings.text('ئاگادارییەکان');
    final countLabel =
        ProxoStrings.format('{count} نەخوێندراوە', {'count': _unread});
    return Semantics(
      button: true,
      label: '$label؛ $countLabel',
      onTap: _open,
      excludeSemantics: true,
      child: SizedBox.square(
        key: const ValueKey('notification-bell-target'),
        dimension: 48,
        child: IconButton(
          tooltip: label,
          onPressed: _open,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          padding: EdgeInsets.zero,
          icon: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const SizedBox.square(dimension: 48),
                ProxoSymbol(ProxoSymbolName.bell,
                    size: widget.iconSize, color: AppColors.ink),
                if (_unread > 0)
                  PositionedDirectional(
                    top: 4,
                    end: 2,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Container(
                        key: const ValueKey('notification-badge'),
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFFD92D20),
                            borderRadius: BorderRadius.circular(9),
                            border:
                                Border.all(color: Colors.white, width: 1.5)),
                        // The full count is announced above. This tiny decorative
                        // badge stays inside its 48dp target at every text scale.
                        child: Text(_unread > 99 ? '99+' : '$_unread',
                            textDirection: TextDirection.ltr,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                                fontFamily: kAppFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1)),
                      ),
                    ),
                  ),
              ]),
        ),
      ),
    );
  }
}
