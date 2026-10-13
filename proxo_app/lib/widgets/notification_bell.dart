// notification_bell.dart
// بیخەرە ناو:  lib/widgets/notification_bell.dart
//
// ── بەکارهێنان لە Topbar ──────────────────────────────────────────────────────
//
//   NotificationBell(
//     onTap: () => Navigator.pushNamed(context, '/notifications'),
//   )
//
//   یان ئەگەر navigatorKey بەکاردەهێنیت:
//
//   NotificationBell(
//     onTap: () => navigatorKey.currentState?.pushNamed('/notifications'),
//   )
//
// ── pubspec.yaml ─────────────────────────────────────────────────────────────
//   dependencies:
//     supabase_flutter: ^2.5.6
//
// ── Supabase table: pa_notifications ────────────────────────────────────────
//   user_id  uuid   (= auth.uid())
//   is_read  bool   (false = نەخوێنراوە)
//
// ── کارکردن ──────────────────────────────────────────────────────────────────
//  • دەستپێک: Supabase query → ژمارەی نەخوێنراوەکان
//  • Realtime: INSERT + UPDATE لە pa_notifications → ئۆتۆماتیک نوێدەبێتەوە
//  • ئەگەر count > 99 → "99+" نیشان دەدات
//  • ئانیمەیشنی pulse (وەک index.html) بۆ badge
//  • کرتەکردن → onTap دەخوێنێتەوە
//
// ── UI ───────────────────────────────────────────────────────────────────────
//  • زەنگی ساکار (outline) — بێ بۆکس/بۆردەر، وەک top_bar.png
//  • ڕەنگ: #1C2333 · قەبارە: iconSize (default 26)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationBell  — public widget
// ─────────────────────────────────────────────────────────────────────────────

class NotificationBell extends StatefulWidget {
  /// کرتەکردن روو دەکات بەم → بچۆ بەشی ئاگاداریەکان
  final VoidCallback onTap;

  /// قەبارەی زەنگ (default 26 — بۆ گونجاندن لەگەڵ top_bar.png)
  final double iconSize;

  const NotificationBell({
    super.key,
    required this.onTap,
    this.iconSize = 26,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {

  static const Color _ink = AppColors.ink; // وەک زەنگ لە reference (re-sampled)

  int _unread = 0;

  // Pulse animation — وەک notifPulse لە CSS
  late AnimationController _pulse;
  late Animation<double>    _scale;
  late Animation<double>    _shadow;

  RealtimeChannel? _channel;

  // ── دەستپێکردن ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0),  weight: 40),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _shadow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 4.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _fetchUnread();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Supabase: ژمارەی نەخوێنراوەکان ───────────────────────────────────────

  Future<void> _fetchUnread() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final res = await Supabase.instance.client
          .from('pa_notifications')
          .select()
          .eq('user_id', uid)
          .eq('is_read', false)
          .count(CountOption.exact);

      final count = res.count ?? 0;
      _setCount(count);
    } catch (_) {}
  }

  // ── Realtime: INSERT و UPDATE گوێ دەگرێت ─────────────────────────────────

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _channel = Supabase.instance.client
        .channel('notif_bell_$uid')
        .onPostgresChanges(
          event:    PostgresChangeEvent.insert,
          schema:   'public',
          table:    'pa_notifications',
          filter:   PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'user_id',
            value:  uid,
          ),
          callback: (_) => _fetchUnread(),
        )
        .onPostgresChanges(
          event:    PostgresChangeEvent.update,
          schema:   'public',
          table:    'pa_notifications',
          filter:   PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'user_id',
            value:  uid,
          ),
          callback: (_) => _fetchUnread(),
        )
        .subscribe();
  }

  // ── count گۆڕین + animation ───────────────────────────────────────────────

  void _setCount(int count) {
    if (!mounted) return;
    setState(() => _unread = count);

    if (count > 0) {
      // pulse بەردەوام
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.reset();
    }
  }

  // ── پیشاندانی ژمارە ───────────────────────────────────────────────────────

  String get _label {
    if (_unread <= 0)  return '';
    if (_unread >= 99) return '99+';
    return '$_unread';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width:  widget.iconSize,
        height: widget.iconSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [

            // ── زەنگی ساکار (بێ بۆکس) ─────────────────────────────────────
            Icon(
              Icons.notifications_none_rounded,
              size:  widget.iconSize,
              color: _ink,
            ),

            // ── Badge (نەخوێنراو) ──────────────────────────────────────────
            if (_unread > 0)
              // PositionedDirectional, not Positioned: `right` is a PHYSICAL
              // edge and does not mirror, so under RTL the badge sat on the
              // bell's inner side pointing at the screen centre. `end` puts it
              // on the outer corner in both directions.
              PositionedDirectional(
                top: -6,
                end: -6,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color:       Color.fromRGBO(220, 38, 38,
                                         0.35 + _shadow.value * 0.15),
                            blurRadius:  4 + _shadow.value,
                            spreadRadius: _shadow.value * 0.3,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                  child: Center(
                    child: ProxoText(
                      _label,
                      style: const TextStyle(
                        fontFamily:  kAppFont,
                        fontSize:    9,
                        fontWeight:  FontWeight.w700,
                        color:       Colors.white,
                        height:      1,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// نموونەی بەکارهێنان لە AppBar / Topbar
// ─────────────────────────────────────────────────────────────────────────────
//
//  ProxoTopBar(
//    onMenuTap:         () => scaffoldKey.currentState?.openDrawer(),
//    onNotificationTap: () => Navigator.pushNamed(context, '/notifications'),
//    topPadding:        MediaQuery.of(context).padding.top,
//  )
//
// ─────────────────────────────────────────────────────────────────────────────
//
// ── خوێندنەوەی ئاگاداریەکان + نیشاندانی is_read ────────────────────────────
//
// کاتێک بەشی ئاگاداریەکان کرایەوە، مارک بکە وەک خوێنراو:
//
//   await Supabase.instance.client
//       .from('pa_notifications')
//       .update({'is_read': true})
//       .eq('user_id', uid)
//       .eq('is_read', false);
//
// ئەمە ئۆتۆماتیکی UPDATE event دەنێرێت → badge خۆی نوێ دەبێتەوە بە 0
// ─────────────────────────────────────────────────────────────────────────────
