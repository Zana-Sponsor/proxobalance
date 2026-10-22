import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_cache.dart';
import 'app_telemetry_service.dart';
import 'proxolink_service.dart' show newProxoRequestId;

class TopupFailure implements Exception {
  const TopupFailure(this.code);
  final String code;
}

/// Only a hash and random retry key are persisted, never receipt/form contents.
/// Re-entering the same details after termination recovers the committed result.
class TopupService {
  TopupService(this.client);
  final SupabaseClient client;
  static final Map<String, Future<Map<String, dynamic>>> _pending = {};
  static Future<void> _storageQueue = Future.value();
  Future<String> _retryKey(String owner, String fingerprint) {
    final answer = Completer<String>();
    _storageQueue = _storageQueue.then((_) async {
      try {
        final p = await SharedPreferences.getInstance();
        final storage = 'proxo.topup.retry.v2.$owner';
        final now = DateTime.now().millisecondsSinceEpoch;
        final entries = <String, dynamic>{};
        final raw = p.getString(storage);
        if (raw != null)
          entries.addAll(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        // Migrate the previous one-request format without losing an uncertain
        // request when the user edits a form and later restores its details.
        final legacy = p.getString('proxo.topup.retry.v1.$owner');
        if (legacy != null) {
          final old = Map<String, dynamic>.from(jsonDecode(legacy) as Map);
          if (old['fingerprint'] is String)
            entries.putIfAbsent(old['fingerprint'], () => old);
        }
        entries.removeWhere((_, value) =>
            value is! Map ||
            value['at'] is! int ||
            (value['complete'] == true &&
                now - (value['at'] as int) >
                    const Duration(days: 7).inMilliseconds));
        if (!entries.containsKey(fingerprint) && entries.length >= 32) {
          final completed = entries.keys
              .where((k) => entries[k]['complete'] == true)
              .toList()
            ..sort((a, b) =>
                (entries[a]['at'] as int).compareTo(entries[b]['at'] as int));
          if (completed.isNotEmpty) entries.remove(completed.first);
        }
        if (!entries.containsKey(fingerprint) && entries.length >= 32) {
          // Never evict an unresolved retry key just to allow another charge.
          throw const TopupFailure('TOO_MANY_PENDING_REQUESTS');
        }
        final key =
            entries[fingerprint]?['key'] as String? ?? newProxoRequestId();
        entries[fingerprint] = {
          'key': key,
          'at': now,
          'complete': entries[fingerprint]?['complete'] == true
        };
        if (!await p.setString(storage, jsonEncode(entries)))
          throw const TopupFailure('STORAGE_UNAVAILABLE');
        await p.remove('proxo.topup.retry.v1.$owner');
        answer.complete(key);
      } catch (error, stack) {
        answer.completeError(error, stack);
      }
    });
    // Bound the caller, not the storage queue: a late write must remain ahead
    // of subsequent retries so the same fingerprint never acquires two keys.
    return answer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      throw const TopupFailure('STORAGE_UNAVAILABLE');
    });
  }

  Future<void> _completed(String owner, String fingerprint) {
    _storageQueue = _storageQueue.then((_) async {
      try {
        final p = await SharedPreferences.getInstance();
        final key = 'proxo.topup.retry.v2.$owner';
        final entries = Map<String, dynamic>.from(
            jsonDecode(p.getString(key) ?? '{}') as Map);
        if (entries[fingerprint] is Map) {
          entries[fingerprint]['complete'] = true;
          await p.setString(key, jsonEncode(entries));
        }
      } catch (_) {/* Keep uncertain keys when completion persistence fails. */}
    });
    // The server has already committed. A stalled local bookkeeping write
    // must not turn a successful top-up request into an endless loading state.
    // Keep that write in the queue so subsequent requests cannot overtake it.
    return _storageQueue.timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  Future<Map<String, dynamic>> submit(
      {required String method,
      required int grossIqd,
      required String sender,
      required String note,
      required String receipt}) {
    final owner = client.auth.currentUser?.id;
    if (owner == null)
      return Future.error(const TopupFailure('NOT_AUTHENTICATED'));
    final details = {
      'method': method,
      'gross': grossIqd,
      'sender': sender,
      'note': note,
      'receipt': sha256.convert(utf8.encode(receipt)).toString()
    };
    final fingerprint =
        sha256.convert(utf8.encode(jsonEncode(details))).toString();
    final scope = '$owner:$fingerprint';
    return _pending.putIfAbsent(
        scope,
        () => Future<Map<String, dynamic>>.microtask(() async {
              try {
                return await _submit(owner, fingerprint, method, grossIqd,
                    sender, note, receipt);
              } finally {
                _pending.remove(scope);
              }
            }));
  }

  Future<Map<String, dynamic>> _submit(
      String owner,
      String fingerprint,
      String method,
      int gross,
      String sender,
      String note,
      String receipt) async {
    final telemetry = AppTelemetryService.active;
    final telemetryScope = telemetry?.sessionScope;
    final key = await _retryKey(owner, fingerprint);
    if (client.auth.currentUser?.id != owner)
      throw const TopupFailure('SESSION_CHANGED');
    telemetry?.event('action', 'topup_submit',
        outcome: 'incomplete', expectedScope: telemetryScope);
    final watch = Stopwatch()..start();
    try {
      final raw = await client.rpc('pa_submit_topup', params: {
        'p_key': key,
        'p_method': method,
        'p_gross_iqd': gross,
        'p_sender': sender,
        'p_note': note,
        'p_receipt': receipt
      }).timeout(const Duration(seconds: 30));
      if (client.auth.currentUser?.id != owner)
        throw const TopupFailure('SESSION_CHANGED');
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] != true)
        throw TopupFailure(result['code'] as String? ?? 'TOPUP_FAILED');
      await _completed(owner, fingerprint);
      if (client.auth.currentUser?.id != owner)
        throw const TopupFailure('SESSION_CHANGED');
      AppDataCache.forClient(client).financialChanged();
      telemetry?.event('action', 'topup_submit',
          outcome: 'success', expectedScope: telemetryScope);
      return result;
    } catch (e) {
      telemetry?.error(e, expectedScope: telemetryScope);
      rethrow;
    } finally {
      telemetry?.event('performance', 'topup_request',
          durationMs: watch.elapsedMilliseconds, expectedScope: telemetryScope);
    }
  }
}
