import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CacheScopeChanged implements Exception {}
class _Entry {
  _Entry(this.value, this.expires, this.bytes);
  final Object value;
  final DateTime expires;
  final int bytes;
}
/// Small account-scoped LRU, never an authorization source. No disk persistence.
class AccountCache {
  AccountCache({this.maxEntries = 32, this.maxBytes = 2 * 1024 * 1024, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final int maxEntries, maxBytes;
  final DateTime Function() _clock;
  final _values = LinkedHashMap<String, _Entry>();
  final Map<String, Future<Object>> _pending = {};
  final Map<String,int> _versions = {};
  String? _owner;
  int _epoch = 0;
  int get length => _values.length;
  int get bytes => _values.values.fold(0,(n,e)=>n+e.bytes);
  void bind(String? owner) { if (_owner != owner) { clear(); _owner = owner; } }
  void clear() { ++_epoch; _values.clear(); _pending.clear(); _versions.clear(); }
  void invalidate(String key) { _values.remove(key); _pending.remove(key); _versions[key]=(_versions[key]??0)+1; }
  Future<T> get<T extends Object>(String key, Future<T> Function() loader, {Duration ttl = const Duration(minutes: 5), bool force = false}) {
    if (_owner == null) return Future.error(CacheScopeChanged());
    if (force) invalidate(key);
    final cached = _values.remove(key);
    if (cached != null && cached.expires.isAfter(_clock())) { _values[key]=cached; return Future.value(cached.value as T); }
    final pending = _pending[key];
    if (pending != null) return pending.then((v)=>v as T);
    final owner = _owner, epoch = _epoch, version = _versions[key]??0;
    late final Future<T> request;
    request = Future<T>.sync(loader).then((v) {
      if (_owner != owner || _epoch != epoch) throw CacheScopeChanged();
      if ((_versions[key]??0)==version) {
        final size=utf8.encode(jsonEncode(v)).length;
        if (size<=maxBytes) {
          _values[key]=_Entry(v,_clock().add(ttl),size);
          while (_values.length>maxEntries || bytes>maxBytes) { _values.remove(_values.keys.first); }
        }
      }
      return v;
    }).whenComplete(() { if (identical(_pending[key],request)) _pending.remove(key); });
    _pending[key]=request;
    return request;
  }
}
class AppDataCache {
  AppDataCache._(this.client) { cache.bind(client.auth.currentUser?.id); }
  final SupabaseClient client;
  final AccountCache cache=AccountCache();
  final ValueNotifier<int> financialRevision=ValueNotifier(0);
  static final _instances=Expando<AppDataCache>();
  static AppDataCache forClient(SupabaseClient c) => _instances[c]??=AppDataCache._(c);
  void bindOwner() => cache.bind(client.auth.currentUser?.id);
  void financialChanged() {
    bindOwner();
    for(final key in ['wallet','transactions','ads','profile']) { cache.invalidate(key); }
    financialRevision.value++;
  }
}
