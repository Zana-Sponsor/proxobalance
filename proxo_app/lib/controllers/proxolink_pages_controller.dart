import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/proxo_card.dart';
import '../services/proxolink_service.dart';

/// Owner-scoped, latest-request-wins state. No table-wide realtime subscription.
class ProxoLinkPagesController extends ChangeNotifier {
  final ProxoLinkRepository repository;
  List<ProxoCard> _pages = [];
  List<ProxoCard> get pages => UnmodifiableListView(_pages);
  bool loading = true;
  ProxoLinkFailure? error;
  final Set<String> busy = {};
  int _revision = 0;
  bool _disposed = false;
  Timer? _poll;
  String? _scope;
  Set<String> changedIds = {};
  StreamSubscription<AuthState>? _auth;
  ProxoLinkPagesController(this.repository) {
    _scope = repository.ownerScope;
    if (repository is ProxoLinkService) {
      _auth = (repository as ProxoLinkService).db.auth.onAuthStateChange.listen(
        (_) {
          if (_scope == repository.ownerScope) return;
          _scope = repository.ownerScope;
          // Clear private cards even when logout/another account races an old GET.
          ++_revision;
          _pages = [];
          error = null;
          loading = true;
          _notify();
          unawaited(refresh());
        },
      );
    }
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final revision = ++_revision, owner = repository.ownerScope;
    if (_scope != owner) { _scope = owner; _pages = []; busy.clear(); }
    _poll?.cancel();
    loading = true;
    error = null;
    _notify();
    try {
      final rows = await repository.cards();
      if (_disposed || revision != _revision) return;
      if (owner != repository.ownerScope) {
        _pages = [];
        loading = false;
        _notify();
        return;
      }
      final unique = <String, ProxoCard>{};
      for (final page in rows) {
        if (owner != null && page.userId != owner) continue;
        if (unique[page.id] == null ||
            page.updatedAt.isAfter(unique[page.id]!.updatedAt))
          unique[page.id] = page;
      }
      final previous = {for (final p in _pages) p.id: p};
      changedIds = unique.keys.where((id) => previous[id] == null ||
        jsonEncode(previous[id]!.toJson()) != jsonEncode(unique[id]!.toJson())).toSet();
      for (final id in unique.keys.toList()) {
        if (!changedIds.contains(id)) unique[id] = previous[id]!;
      }
      _pages = unique.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      loading = false;
      _notify();
      if (_pages.any((p) => p.publishStatus == 'creating')) {
        _poll = Timer(const Duration(seconds: 5), refresh);
      }
    } catch (e) {
      if (_disposed || revision != _revision) return;
      error = e is ProxoLinkFailure
          ? e
          : const ProxoLinkFailure('network_error');
      if (owner != repository.ownerScope || error!.code == 'unauthorized')
        _pages = [];
      loading = false;
      _notify();
    }
  }

  void upsert(ProxoCard page) {
    if (_disposed ||
        (repository.ownerScope != null && page.userId != repository.ownerScope))
      return;
    ++_revision;
    _poll?.cancel();
    _pages = [page, ..._pages.where((p) => p.id != page.id)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    loading = false;
    error = null;
    _notify();
  }

  Future<void> manage(ProxoCard page, String action) async {
    if (_disposed || busy.contains(page.id)) return;
    busy.add(page.id);
    _notify();
    try {
      final owner = repository.ownerScope;
      await repository.manage(page, action);
      if (_disposed || owner != repository.ownerScope) return;
      if (action == 'delete') {
        ++_revision;
        _pages.removeWhere((p) => p.id == page.id);
        loading = false;
        error = null;
        _notify();
      } else {
        await refresh();
      }
    } finally {
      busy.remove(page.id);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    _poll?.cancel();
    unawaited(_auth?.cancel());
    super.dispose();
  }
}
