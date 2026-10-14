import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/proxo_strings.dart';
import '../services/ad_activation_bridge.dart';
import '../theme/app_locale.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

/// Only server-created activation notifications count. A metrics update or an
/// old active campaign must never be presented as a new activation.
class AdActivationEvent {
  const AdActivationEvent(this.id, this.adId, this.createdAt);
  final String id, adId;
  final DateTime createdAt;
  static AdActivationEvent? parse(Map<String, dynamic> row,
      {required String userId, required DateTime now}) {
    if (row['user_id'] != userId || row['type'] != 'ad_active') return null;
    final created = DateTime.tryParse('${row['created_at']}')?.toUtc();
    if (created == null) return null;
    final age = now.toUtc().difference(created);
    if (age.isNegative || age > const Duration(minutes: 5)) return null;
    final meta = row['meta'];
    final adId = (meta is Map ? meta['ad_id'] : null) ?? row['related_id'];
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty || adId == null || !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch('$adId')) return null;
    return AdActivationEvent(id, '$adId', created);
  }
}

class AdActivationNotice extends StatelessWidget {
  const AdActivationNotice({super.key, required this.adTitle,
    required this.onOpen, required this.onClose});
  final String adTitle;
  final VoidCallback onOpen, onClose;
  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Semantics(liveRegion: true, container: true,
      child: Material(color: Colors.white, elevation: 6,
        shadowColor: const Color(0x240F172A), borderRadius: BorderRadius.circular(16),
        child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE9FF))),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 10),
              child: ProxoSymbol(ProxoSymbolName.verified, size: 24, color: Color(0xFF157347))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ProxoText('ڕیکلامەکەت چالاک بوو', translate: true,
                style: TextStyle(fontSize: 14, color: Color(0xFF0F172A), height: 1.5)),
              if (adTitle.isNotEmpty) ProxoText(adTitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF64748B))),
              TextButton(onPressed: onOpen,
                style: TextButton.styleFrom(minimumSize: const Size(48,48),
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
                child: const ProxoText('بینین', translate: true)),
            ])),
            IconButton(tooltip: ProxoStrings.text('داخستن'), onPressed: onClose,
              constraints: const BoxConstraints(minWidth:48,minHeight:48),
              icon: const ProxoSymbol(ProxoSymbolName.close, size:22)),
          ]))));
  }
}

/// App-wide overlay, independent of which kept-alive tab is visible. Queries
/// use the signed-in client and explicit owner filters; no service role key.
class AdActivationNoticeHost extends StatefulWidget {
  const AdActivationNoticeHost({super.key, required this.client,
    required this.child, required this.onOpen});
  final SupabaseClient client;
  final Widget child;
  final ValueChanged<String> onOpen;
  @override State<AdActivationNoticeHost> createState() => _AdActivationNoticeHostState();
}
class _AdActivationNoticeHostState extends State<AdActivationNoticeHost> with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  Timer? _timer;
  String? _uid, _adId;
  String _title = '';
  int _generation = 0;
  bool _refreshing = false, _ready = false;
  final _seen = <String, int>{};
  final _inFlight = <String>{};
  DateTime? _lastRefresh;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    AdActivationBridge.onForeground = _foreground;
    _auth = widget.client.auth.onAuthStateChange.listen((_) => _bind());
    _bind();
  }
  Future<bool> _foreground(Map<String, dynamic> data) async {
    if (data['type'] != 'ad_active' || !_ready || _uid == null) return false;
    final id = data['ad_id']?.toString();
    if (id == null) return false;
    if (_seen.containsKey(id)) return true;
    // Query the owner-filtered server event; a push payload alone cannot
    // assert activation time or bypass the five-minute freshness check.
    _lastRefresh = null;
    await _refresh();
    return _seen.containsKey(id);
  }
  void _bind() {
    final uid = widget.client.auth.currentUser?.id;
    if (uid == _uid) return;
    _generation++; _ready = false; _refreshing = false; _uid = uid; _seen.clear(); _inFlight.clear();
    _timer?.cancel(); _adId = null; _title = ''; _lastRefresh = null;
    _channel?.unsubscribe(); _channel = null;
    if (mounted) setState(() {});
    if (uid == null) return;
    final generation = _generation;
    _channel = widget.client.channel('recent_ad_activation_$uid')
      ..onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'pa_notifications',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
        callback: (event) { unawaited(_consider(event.newRecord, generation)); })
      ..subscribe();
    unawaited(_restoreAndRefresh(uid, generation));
  }
  Future<void> _restoreAndRefresh(String uid, int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || generation != _generation) return;
    for (final entry in prefs.getStringList('proxo_recent_ad_notice_$uid') ?? <String>[]) {
      final parts = entry.split('|');
      if (parts.length == 2) _seen[parts[0]] = int.tryParse(parts[1]) ?? 0;
    }
    _prune(); _ready = true; await _refresh();
  }
  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(minutes:10)).millisecondsSinceEpoch;
    _seen.removeWhere((_,at) => at < cutoff);
    while (_seen.length > 100) { _seen.remove(_seen.keys.first); }
  }
  Future<void> _refresh() async {
    final uid = _uid; final generation = _generation;
    if (!_ready || uid == null || _refreshing || (_lastRefresh != null && DateTime.now().difference(_lastRefresh!) < const Duration(seconds:30))) return;
    _refreshing = true; _lastRefresh = DateTime.now();
    try {
      final rows = await widget.client.from('pa_notifications').select('id,user_id,type,created_at,related_id,meta')
        .eq('user_id', uid).eq('type','ad_active')
        .gte('created_at',DateTime.now().toUtc().subtract(const Duration(minutes:5)).toIso8601String())
        .order('created_at',ascending:false).limit(3);
      for (final row in rows) { await _consider(row,generation); }
    } catch (_) { /* The notification list remains available for retry. */ }
    finally { if (generation == _generation) _refreshing = false; }
  }
  Future<void> _consider(Map<String,dynamic> row, int generation) async {
    if (!mounted || !_ready || _uid == null || generation != _generation || _adId != null) return;
    final event = AdActivationEvent.parse(row,userId:_uid!,now:DateTime.now());
    if (event == null || _seen.containsKey(event.adId) || !_inFlight.add(event.adId)) return;
    try {
      final ad = await widget.client.from('pa_ads').select('id,title,status')
        .eq('id',event.adId).eq('user_id',_uid!).maybeSingle();
      if (!mounted || generation != _generation || _adId != null || ad?['status'] != 'active') return;
      // Do not cover the keyboard while the user is typing. The next resume
      // can retrieve the event while it is still fresh.
      if (MediaQuery.viewInsetsOf(context).bottom > 0 ||
          DateTime.now().toUtc().difference(event.createdAt) > const Duration(minutes: 5)) return;
      _seen[event.adId] = DateTime.now().millisecondsSinceEpoch; _prune();
      setState(() { _adId = event.adId; _title = '${ad?['title'] ?? ''}'; });
      if (!MediaQuery.accessibleNavigationOf(context)) {
        _timer = Timer(const Duration(seconds:7),_dismiss);
      }
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || generation != _generation) return;
      await prefs.setStringList('proxo_recent_ad_notice_$_uid', _seen.entries.map((e) => '${e.key}|${e.value}').toList());
    } catch (_) { /* No unverified activation is displayed. */ }
    finally { if (generation == _generation) _inFlight.remove(event.adId); }
  }
  void _dismiss() { _timer?.cancel(); if(mounted) setState(() => _adId = null); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
    if (state == AppLifecycleState.paused) _dismiss();
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this); _timer?.cancel();
    if (AdActivationBridge.onForeground == _foreground) AdActivationBridge.onForeground = null;
    _auth?.cancel(); _channel?.unsubscribe(); super.dispose();
  }
  @override Widget build(BuildContext context) {
    final id = _adId;
    return Stack(children: [widget.child,
      Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0,-0.12), end: Offset.zero).animate(animation), child: child)),
          child: id == null ? const SizedBox.shrink(key: ValueKey('empty')) :
            Padding(key: ValueKey(id), padding: const EdgeInsets.all(12), child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
                child: AdActivationNotice(adTitle: _title, onClose: _dismiss, onOpen: () {
                  _dismiss(); widget.onOpen(id);
                })))),
        ))),
    ]);
  }
}
