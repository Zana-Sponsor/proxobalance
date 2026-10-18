import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Display-only, account-scoped offline snapshots. Never used to authorize a
/// payment. Four snapshots / 200 rows / 2 MiB total, expiring after 24 hours.
class AdSnapshotCache {
  AdSnapshotCache(this.owner, this.currentOwner, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final String? owner;
  final String? Function() currentOwner;
  final DateTime Function() _clock;
  final Map<String, Map<String, dynamic>> _memory = {};
  int _generation = 0;
  static const ttl = Duration(hours: 24);
  static const maxBytes = 2 * 1024 * 1024;
  String get _prefix => 'proxo.ads.v4.$owner.';
  bool get _valid => owner != null && owner == currentOwner();
  static const _privateFields = {'video_code', 'post_code', 'customer_note',
    'feedback_comment', 'receipt_b64', 'gateway_payload', 'access_token'};
  Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    if (!_valid) return;
    final generation = _generation;
    final safe = rows.take(50).map((row) => Map<String, dynamic>.from(row)
      ..removeWhere((key, _) => _privateFields.contains(key))).toList();
    final value = <String, dynamic>{'v': 4, 'at': _clock().toIso8601String(), 'rows': safe};
    final text = jsonEncode(value);
    if (utf8.encode(text).length > maxBytes) return;
    final p = await SharedPreferences.getInstance();
    if (!_valid || generation != _generation) return;
    _memory.remove(key); _memory[key] = value;
    while (_memory.length > 4 || _memory.values.fold<int>(0, (n, v) => n + utf8.encode(jsonEncode(v)).length) > maxBytes) { _memory.remove(_memory.keys.first); }
    await p.setString('$_prefix$key', text);
    final keys = p.getKeys().where((k) => k.startsWith(_prefix)).toList()
      ..sort((a, b) => _stamp(p.getString(a)).compareTo(_stamp(p.getString(b))));
    int size() => keys.fold(0, (n, k) => n + utf8.encode(p.getString(k) ?? '').length);
    while (keys.length > 4 || size() > maxBytes) { await p.remove(keys.removeAt(0)); }
    // The old v1-v3 snapshots could contain authorization codes and v1 had no
    // expiry. They are never read or migrated into the new display cache.
    for (final k in p.getKeys().where((k) => k.startsWith('proxo_ads_cache_$owner'))) { await p.remove(k); }
  }
  static String _stamp(String? raw) {
    try { return (jsonDecode(raw ?? '{}') as Map)['at']?.toString() ?? ''; } catch (_) { return ''; }
  }
  Future<List<Map<String, dynamic>>?> read(String key) async {
    if (!_valid) return null;
    final generation = _generation;
    final p = await SharedPreferences.getInstance();
    if (!_valid || generation != _generation) return null;
    final raw = p.getString('$_prefix$key');
    try {
      final value = _memory[key] ?? (raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map));
      if (value == null || value['v'] != 4) return null;
      final at = DateTime.tryParse(value['at']?.toString() ?? '');
      if (at == null || _clock().difference(at).isNegative || _clock().difference(at) > ttl) {
        _memory.remove(key); await p.remove('$_prefix$key'); return null;
      }
      return (value['rows'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (_) { _memory.remove(key); await p.remove('$_prefix$key'); return null; }
  }
  void clearMemory() { _memory.clear(); }
  Future<void> invalidate() async {
    ++_generation; _memory.clear();
    if (owner != null) await clearStoredFor(owner!);
  }
  static Future<void> clearStoredFor(String owner) async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('proxo.ads.v4.$owner.') || k.startsWith('proxo_ads_cache_$owner'))) {
      await p.remove(k);
    }
  }
}
