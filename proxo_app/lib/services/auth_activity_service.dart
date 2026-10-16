import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AuthDeviceCollector = Future<Map<String, String>> Function();

/// Enriches the server's Auth session log with device-reported model/OS data.
/// Server triggers own login/logout times; no writes run after signedOut.
/// This listener lives with the client, not with a route that navigation removes.
final class AuthActivityService {
  AuthActivityService(this._client, {AuthDeviceCollector? collectDevice})
      : _collectDevice = collectDevice ?? collectAuthDevice;

  static final _instances = Expando<AuthActivityService>();
  static AuthActivityService forClient(SupabaseClient client) =>
      _instances[client] ??= AuthActivityService(client);

  final SupabaseClient _client;
  final AuthDeviceCollector _collectDevice;
  StreamSubscription<AuthState>? _subscription;
  final Map<String, Future<void>> _pending = {};
  Future<Map<String, String>>? _device;
  String? _recordedSession;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _client.auth.onAuthStateChange.listen((state) {
      if (state.session != null &&
          (state.event == AuthChangeEvent.initialSession ||
              state.event == AuthChangeEvent.signedIn ||
              state.event == AuthChangeEvent.tokenRefreshed)) {
        unawaited(recordCurrentSession());
      }
    });
    unawaited(recordCurrentSession());
  }

  static String? _sessionId(Session? session) {
    if (session == null) return null;
    try {
      final parts = session.accessToken.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(
        base64Url.normalize(parts[1]),
      )));
      final id = payload is Map ? payload['session_id'] : null;
      return id is String &&
              RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
                  .hasMatch(id)
          ? id
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> recordCurrentSession() {
    final session = _client.auth.currentSession;
    final id = _sessionId(session);
    if (_disposed || session == null || id == null) return Future.value();
    final key = '${session.user.id}:$id';
    if (_recordedSession == key) return Future.value();
    return _pending.putIfAbsent(key,
        () => Future<void>.microtask(() => _record(session.user.id, id, key)));
  }

  Future<void> _record(String owner, String id, String key) async {
    try {
      final device = await (_device ??= _collectDevice())
          .timeout(const Duration(seconds: 3));
      final current = _client.auth.currentSession;
      // An old device lookup must never write under a newly signed-in owner.
      if (_disposed || current?.user.id != owner || _sessionId(current) != id) {
        return;
      }
      await _client.rpc('pa_record_app_session', params: {
        'p_session_id': id,
        'p_device': device,
      }).timeout(const Duration(seconds: 5));
      if (_client.auth.currentUser?.id == owner &&
          _sessionId(_client.auth.currentSession) == id) {
        _recordedSession = key;
      }
    } catch (error) {
      // Retry on the next Auth event/app start; never log tokens or raw errors.
      _device = null;
      debugPrint('[AuthActivity] metadata pending (${error.runtimeType})');
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> signOut() async {
    // Give an in-flight model lookup a bounded chance to finish while the JWT
    // still exists. The database records logout only when Auth revokes it.
    try {
      await recordCurrentSession().timeout(const Duration(seconds: 3));
    } catch (_) {}
    await _client.auth.signOut();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}

/// Avoid owner-assigned iPhone names, hardware IDs and third-party IP lookups.
/// Device fields are descriptive metadata, never authorization claims.
Future<Map<String, String>> collectAuthDevice() async {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  final result = <String, String>{'platform': platform};
  final info = DeviceInfoPlugin();
  // Let transient plugin failures reach the service's retry path. Caching a
  // platform-only success would otherwise permanently lose this phone's model.
  if (kIsWeb) {
    final web = await info.webBrowserInfo;
    result.addAll({'device_model': web.browserName.name, 'os': 'web'});
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    final android = await info.androidInfo;
    result.addAll({
      'device_name': '${android.brand} ${android.model}'.trim(),
      'device_model': android.model,
      'os': 'Android',
      'os_version': android.version.release,
    });
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    final ios = await info.iosInfo;
    result.addAll({
      'device_name': ios.model,
      'device_model': ios.utsname.machine,
      'os': 'iOS',
      'os_version': ios.systemVersion,
    });
  }
  return result;
}
