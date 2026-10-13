import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'proxo_error_ui.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProxoNoInternetBanner
// بەکارهێنە وەک child لە Stack لە سەرەوەی Scaffold
// بە ئۆتۆماتیکی ئاگاداری دەدات کاتێک ئینتەرنێت نییە
// ─────────────────────────────────────────────────────────────────────────────

class ProxoNoInternetBanner extends StatefulWidget {
  const ProxoNoInternetBanner({super.key});

  @override
  State<ProxoNoInternetBanner> createState() => _ProxoNoInternetBannerState();
}

class _ProxoNoInternetBannerState extends State<ProxoNoInternetBanner>
    with SingleTickerProviderStateMixin {
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChange);
  }

  Future<void> _checkInitial() async {
    final result = await Connectivity().checkConnectivity();
    _onConnectivityChange(result);
  }

  void _onConnectivityChange(List<ConnectivityResult> result) {
    final isOffline = result.isEmpty ||
        result.every((r) => r == ConnectivityResult.none);
    if (isOffline == _offline) return;
    if (mounted) {
      setState(() => _offline = isOffline);
      if (isOffline) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline && _ctrl.isDismissed) return const SizedBox.shrink();
    return SafeArea(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
          child: _BannerContent(offline: _offline),
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final bool offline;
  const _BannerContent({required this.offline});

  @override
  Widget build(BuildContext context) {
    // Offline borrows the shared `offline` tone; "back online" borrows
    // `success`. Both are the same tinted-surface treatment used by every
    // other message in the app, so the banner reads as part of Proxo rather
    // than as a system alert dropped on top of it.
    final p = proxoErrorPalette(
        offline ? ProxoErrorTone.offline : ProxoErrorTone.success);

    return Container(
      margin: const EdgeInsets.fromLTRB(ProxoErrorStyle.s16,
          ProxoErrorStyle.s8, ProxoErrorStyle.s16, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: ProxoErrorStyle.s14, vertical: ProxoErrorStyle.s12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(ProxoErrorStyle.rSnack),
        border: Border.all(color: p.border),
        boxShadow: ProxoErrorStyle.snackShadow(p.accent),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Container(
              width: ProxoErrorStyle.wellSnack,
              height: ProxoErrorStyle.wellSnack,
              decoration: BoxDecoration(
                color: p.well,
                borderRadius: BorderRadius.circular(ProxoErrorStyle.rWell - 3),
              ),
              child: Center(
                child: Icon(
                  offline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  color: p.accent,
                  size: ProxoErrorStyle.iconSnack,
                ),
              ),
            ),
            const SizedBox(width: ProxoErrorStyle.s12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProxoText(
                    offline ? 'ئینتەرنێت نییە' : 'پەیوەندی گەڕایەوە',
                    style: ProxoErrorType.label(p.accent, kAppFont),
                  ),
                  const SizedBox(height: ProxoErrorStyle.s2),
                  ProxoText(
                    offline
                        ? 'تکایە پەیوەندی ئینتەرنێتەکەت بپشکنەوە'
                        : 'ئێستا دەتوانیت بەردەوام بی',
                    style: ProxoErrorType.body(p.ink, kAppFont),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProxoOfflineScreen
// بەکارهێنە کاتێک تەواوی نوێکردنەوەی پەیج بنووسیت
// ─────────────────────────────────────────────────────────────────────────────

class ProxoOfflineScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const ProxoOfflineScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Copy and the retry callback still belong to whoever shows this screen;
    // only the presentation is shared, so it matches the error state used by
    // the campaigns list, the cards list, the history pages and the rest.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ProxoErrorView(
          tone: ProxoErrorTone.offline,
          title: 'پەیوەندی ئینتەرنێت نییە',
          message: 'ئینتەرنێتەکەت بپشکنەوە\n'
              'دوای پشکنین دووبارە هەوڵ بدەرەوە',
          actionLabel: 'دووبارە هەوڵ بدەرەوە',
          onAction: onRetry,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// isConnected() — Helper بۆ پشکنینی ئینتەرنێت پێش هەر کارێکی نێتوۆرک
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> isConnected() async {
  final result = await Connectivity().checkConnectivity();
  return result.isNotEmpty && result.any((r) => r != ConnectivityResult.none);
}
