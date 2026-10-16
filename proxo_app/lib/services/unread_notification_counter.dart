import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_telemetry_service.dart';

/// One count request and one owner-filtered subscription shared by all mounted
/// bells/drawers. The last consumer releases both subscription and cached count.
class UnreadNotificationCounter {
  UnreadNotificationCounter(this.client, {Future<int> Function(String)? load,
      VoidCallback Function(String, VoidCallback)? subscribe}) {
    _load = load ?? ((owner) => client.from('pa_notifications').count(CountOption.exact)
        .eq('user_id', owner).eq('is_read', false));
    _subscribe = subscribe ?? _subscribeRealtime;
  }
  final SupabaseClient client;
  late final Future<int> Function(String) _load;
  late final VoidCallback Function(String, VoidCallback) _subscribe;
  static final _instances = Expando<UnreadNotificationCounter>();
  static UnreadNotificationCounter forClient(SupabaseClient c) => _instances[c] ??= UnreadNotificationCounter(c);
  final count = ValueNotifier<int>(0);
  StreamSubscription<AuthState>? _auth;
  VoidCallback? _stop;
  Future<void>? _pending;
  String? _owner;
  int _consumers = 0, _generation = 0;
  bool _dirty = false;
  int get consumers => _consumers;
  void acquire() {
    if (++_consumers != 1) return;
    _auth = client.auth.onAuthStateChange.listen((_) => _bind());
    _bind();
  }
  void release() {
    if (_consumers == 0 || --_consumers != 0) return;
    ++_generation; _stop?.call(); _stop = null;
    unawaited(_auth?.cancel()); _auth = null;
    _pending = null; _owner = null; _dirty = false; count.value = 0;
  }
  void _bind() {
    final next = client.auth.currentUser?.id;
    if (next == _owner) return;
    ++_generation; _stop?.call(); _stop = null;
    _owner = next; _pending = null; _dirty = false; count.value = 0;
    if (next == null || _consumers == 0) return;
    _stop = _subscribe(next, () { _dirty = true; unawaited(refresh()); });
    unawaited(refresh());
  }
  VoidCallback _subscribeRealtime(String owner, VoidCallback changed) {
    final channel = client.channel('unread_shared_$owner')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'pa_notifications',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: owner),
        callback: (_) => changed()).subscribe();
    return () { unawaited(client.removeChannel(channel)); };
  }
  Future<void> refresh() {
    if (_pending != null) return _pending!;
    if (_owner == null || _consumers == 0) return Future.value();
    final owner = _owner!, generation = _generation;
    _dirty = false;
    late final Future<void> request;
    request = _load(owner).then((value) {
      if (generation == _generation && _consumers > 0 && owner == client.auth.currentUser?.id) count.value = value;
    }).catchError((Object _) {
      AppTelemetryService.active?.event('error', 'notification_count_failed', outcome: 'failure');
    }).whenComplete(() {
      if (identical(_pending, request)) {
        _pending = null;
        if (_dirty) unawaited(refresh());
      }
    });
    return _pending = request;
  }
}
