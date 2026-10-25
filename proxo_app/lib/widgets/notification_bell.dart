import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'auth/auth_design.dart';

/// A restrained badge contained within a full, accessible touch target.
/// [count] lets hosts that already own a notification stream supply its value.
class NotificationBell extends StatefulWidget {
  const NotificationBell(
      {super.key,
      required this.onTap,
      this.iconSize = 20,
      this.count,
      this.client});
  final VoidCallback onTap;
  final double iconSize;
  final int? count;
  final SupabaseClient? client;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  SupabaseClient get _client => widget.client ?? Supabase.instance.client;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.count == null) _start();
  }

  void _start() {
    _subscribe();
    _auth = _client.auth.onAuthStateChange.listen((_) => _subscribe());
  }

  @override
  void didUpdateWidget(NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count == null && widget.count != null) {
      _auth?.cancel();
      _channel?.unsubscribe();
      _generation++;
    } else if (oldWidget.count != null && widget.count == null) {
      _start();
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    final generation = ++_generation;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _unread = 0);
      return;
    }
    _fetchUnread(uid, generation);
    _channel = _client
        .channel('notif_bell_${identityHashCode(this)}_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pa_notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => _fetchUnread(uid, generation),
        )
        .subscribe();
  }

  Future<void> _fetchUnread(String uid, int generation) async {
    try {
      final result = await _client
          .from('pa_notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('is_read', false)
          .count(CountOption.exact);
      if (mounted && generation == _generation)
        setState(() => _unread = result.count);
    } catch (_) {
      // A temporary notification error must not replace the entire app bar.
    }
  }

  @override
  void dispose() {
    _generation++;
    _auth?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count ?? _unread;
    return Semantics(
      label: count > 0 ? 'ئاگادارییەکان، $count نەخوێندراوە' : 'ئاگادارییەکان',
      button: true,
      child: SizedBox.square(
        dimension: 48,
        child: Stack(children: [
          Positioned.fill(
              child: IconButton(
            tooltip: 'ئاگادارییەکان',
            onPressed: widget.onTap,
            padding: const EdgeInsets.all(12),
            icon: SolarIcon(SolarIcons.bell,
                size: widget.iconSize, color: AuthTokens.ink),
          )),
          if (count > 0)
            PositionedDirectional(
              top: 3,
              end: 1,
              child: IgnorePointer(
                  child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                    color: AuthTokens.danger,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5)),
                child: Text(count > 99 ? '99+' : '$count',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 10,
                        height: 1.2,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              )),
            ),
        ]),
      ),
    );
  }
}
