import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_activity_service.dart';

enum AccountSetupPhase { verifying, profile, finishing, ready }

/// Completion is deliberately NOT persisted. A restored login revalidates the
/// server records after process termination; retries reuse the same Auth user.
class AccountSetupService {
  AccountSetupService(this.client);
  final SupabaseClient client;
  static final _instances = Expando<AccountSetupService>();
  static AccountSetupService forClient(SupabaseClient c) =>
      _instances[c] ??= AccountSetupService(c);
  Future<void>? _pending;
  String? _pendingScope;
  String? _readyScope;
  String? get scope {
    final s = client.auth.currentSession;
    final id = AuthActivityService.sessionId(s);
    return s == null || id == null ? null : '${s.user.id}:$id';
  }
  bool get isReady => scope != null && _readyScope == scope;
  void clear() { _readyScope = null; _pending = null; _pendingScope = null; }
  Future<void> ensure({void Function(AccountSetupPhase)? onPhase}) {
    final owner = scope;
    if (owner == null) return Future.error(StateError('NOT_AUTHENTICATED'));
    if (isReady) return Future.value();
    if (_pendingScope == owner && _pending != null) return _pending!;
    _pendingScope = owner;
    late final Future<void> request;
    request = _ensure(owner, onPhase).whenComplete(() {
      if (identical(_pending, request)) { _pending = null; _pendingScope = null; }
    });
    return _pending = request;
  }
  Future<void> _ensure(String owner, void Function(AccountSetupPhase)? phase) async {
    phase?.call(AccountSetupPhase.verifying);
    final user = (await client.auth.getUser().timeout(const Duration(seconds: 15))).user;
    if (user == null || scope != owner) throw StateError('SESSION_CHANGED');
    phase?.call(AccountSetupPhase.profile);
    final result = await client.rpc('pa_ensure_account_ready').timeout(const Duration(seconds: 20));
    if (scope != owner || result is! Map || result['ready'] != true || result['user_id'] != user.id) {
      throw StateError('SETUP_INCOMPLETE');
    }
    phase?.call(AccountSetupPhase.finishing);
    // Read as the actual user, so a definer function cannot hide an RLS failure.
    final records = await Future.wait([
      client.from('profiles').select('id').eq('id', user.id).maybeSingle(),
      client.from('pa_wallets').select('user_id').eq('user_id', user.id).maybeSingle(),
      client.from('pa_user_points').select('user_id').eq('user_id', user.id).maybeSingle(),
    ]).timeout(const Duration(seconds: 15));
    if (scope != owner || records.any((r) => r == null)) throw StateError('SETUP_RECORDS_UNAVAILABLE');
    _readyScope = owner;
    phase?.call(AccountSetupPhase.ready);
  }
}
