import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/painting.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_cache.dart';
import 'account_setup_service.dart';
import 'ad_snapshot_cache.dart';
import 'auth_activity_service.dart';
import 'proxolink_service.dart' show newProxoRequestId;

/// Bounded best-effort diagnostics. Codes only: no raw errors, route parameters,
/// form values, receipts, passwords, tokens, OTPs, personal device names or IPs.
class AppTelemetryService with WidgetsBindingObserver {
  AppTelemetryService(
    this.client, {
    Future<Map<String, String>> Function()? deviceCollector,
    Future<String> Function()? installationLoader,
  }) : _collect = deviceCollector ?? _collectDevice,
       _installationLoader = installationLoader ?? _loadInstallation;
  final SupabaseClient client;
  final Future<Map<String, String>> Function() _collect;
  final Future<String> Function() _installationLoader;
  static final _instances = Expando<AppTelemetryService>();
  static AppTelemetryService forClient(SupabaseClient c) =>
      _instances[c] ??= AppTelemetryService(c);
  static AppTelemetryService? active;
  final List<Map<String, Object?>> _events = [];
  StreamSubscription<AuthState>? _auth;
  Timer? _heartbeat;
  Future<void>? _sending;
  Future<Map<String, String>>? _device;
  Future<String>? _installation;
  String _run = newProxoRequestId(), _section = 'home';
  String? _scope;
  int _sequence = 0, _eventSequence = 0;
  bool _foreground = false, _disposed = false, _started = false;
  bool _sendAgain = false;
  FlutterExceptionHandler? _previousFlutterError;
  bool Function(Object, StackTrace)? _previousPlatformError;
  int get queuedEvents => _events.length;
  String get currentSection => _section;
  String? get sessionScope => _currentScope(client);
  static const sections = <String>{
    'home',
    'ads',
    'tools',
    'profile',
    'account_setup',
    'create_ad',
    'ad_details',
    'deposit',
    'notifications',
    'transactions',
    'transaction_details',
    'edit_profile',
    'faq',
    'tasks',
    'levels',
    'vouchers',
    'discounts',
    'tutorials',
    'best_metrics',
    'pages',
    'page_editor',
    'page_details',
    'create_page',
    'browser',
    'whatsapp_marketing',
    'auth',
    'other',
  };
  static String? _currentScope(SupabaseClient c) {
    final s = c.auth.currentSession;
    final id = AuthActivityService.sessionId(s);
    return s == null || id == null ? null : '${s.user.id}:$id';
  }

  static Future<String> _loadInstallation() async {
    final p = await SharedPreferences.getInstance();
    final old = p.getString('proxo.installation.v1');
    if (old != null) return old;
    final id = newProxoRequestId();
    if (!await p.setString('proxo.installation.v1', id))
      throw StateError('installation_storage');
    return id;
  }

  static Future<Map<String, String>> _collectDevice() async {
    final d = await collectAuthDevice();
    final info = await PackageInfo.fromPlatform();
    d.remove('device_name');
    return {
      ...d,
      'app_version': info.version,
      'build_number': info.buildNumber,
    };
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    active = this;
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _bind();
    _auth = client.auth.onAuthStateChange.listen((_) => _bind());
    _previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      error(details.exception);
      _previousFlutterError?.call(details);
    };
    _previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, s) {
      error(e);
      return _previousPlatformError?.call(e, s) ?? false;
    };
  }

  void _bind() {
    final next = _currentScope(client);
    if (next != _scope) {
      final previousOwner = _scope?.split(':').first;
      if (previousOwner != null)
        unawaited(
          AdSnapshotCache.clearStoredFor(previousOwner)
              .catchError((Object _) {}),
        );
      _scope = next;
      _run = newProxoRequestId();
      _sequence = 0;
      _eventSequence = 0;
      _events.clear();
      AppDataCache.forClient(client).bindOwner();
      AccountSetupService.forClient(client).clear();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    _heartbeat?.cancel();
    if (_scope != null && _foreground)
      _heartbeat = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(flush()),
      );
    if (_scope != null) unawaited(flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _bind();
  }

  @override
  void didHaveMemoryPressure() {
    AppDataCache.forClient(client).cache.clear();
    _events.clear();
  }

  void section(String section) {
    if (!sections.contains(section) || section == _section) return;
    _section = section;
    event('section', 'enter');
    unawaited(flush());
  }

  void event(
    String kind,
    String code, {
    String? outcome,
    int? durationMs,
    String? sectionName,
    String? expectedScope,
  }) {
    final scope = _currentScope(client);
    if (_disposed ||
        scope == null ||
        (expectedScope != null && scope != expectedScope))
      return;
    if (!const {'section', 'error', 'action', 'performance'}.contains(kind) ||
        (outcome != null &&
            !const {'success', 'failure', 'incomplete'}.contains(outcome)) ||
        !sections.contains(sectionName ?? _section))
      return;
    if (!RegExp(r'^[A-Za-z0-9_.:-]{1,100}$').hasMatch(code)) return;
    if (_events.length >= 100) _events.removeAt(0);
    _events.add({
      'id': newProxoRequestId(),
      'kind': kind,
      'section': sectionName ?? _section,
      'code': code,
      'ordinal': ++_eventSequence,
      if (outcome != null) 'outcome': outcome,
      if (durationMs != null) 'duration_ms': durationMs.clamp(0, 600000),
    });
  }

  void error(Object error, {String? expectedScope}) => event(
    'error',
    error.runtimeType.toString().replaceAll(RegExp('[^A-Za-z0-9_.:-]'), '_'),
    outcome: 'failure',
    expectedScope: expectedScope,
  );
  Future<void> flush() {
    if (_disposed || _currentScope(client) == null) return Future.value();
    if (_sending != null) {
      _sendAgain = true;
      return _sending!;
    }
    late final Future<void> request;
    request = _flush().whenComplete(() {
      if (identical(_sending, request)) _sending = null;
      if (_sendAgain && !_disposed) {
        _sendAgain = false;
        unawaited(flush());
      }
    });
    return _sending = request;
  }

  Future<void> _flush() async {
    final owner = _currentScope(client), run = _run;
    final batch = List<Map<String, Object?>>.from(_events.take(20));
    final seq = ++_sequence, fg = _foreground, sectionName = _section;
    try {
      final installation = await (_installation ??= _installationLoader())
          .timeout(const Duration(seconds: 3));
      Map<String, String> device;
      try {
        device = await (_device ??= _collect()).timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {
        _device = null;
        device = {};
      }
      if (_disposed || owner != _currentScope(client) || run != _run) return;
      final result = await client
          .rpc(
            'pa_record_app_telemetry',
            params: {
              'p_batch': {
                'installation_id': installation,
                'run_id': run,
                'sequence': seq,
                'foreground': fg,
                'section': sectionName,
                'device': device,
                'events': batch,
              },
            },
          )
          .timeout(const Duration(seconds: 8));
      if (result is Map &&
          result['ok'] == true &&
          owner == _currentScope(client) &&
          run == _run) {
        final ids = batch.map((e) => e['id']).toSet();
        _events.removeWhere((e) => ids.contains(e['id']));
      }
    } catch (_) {
      _installation = null; /* Retry on next heartbeat; never recursively log telemetry failure. */
    }
  }

  Future<void> beforeLogout() async {
    if (!_started) return;
    _foreground = false;
    _heartbeat?.cancel();
    event('action', 'logout', outcome: 'success');
    try {
      await flush().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _events.clear();
    AppDataCache.forClient(client).cache.clear();
    AccountSetupService.forClient(client).clear();
  }

  Future<void> dispose() async {
    _disposed = true;
    _heartbeat?.cancel();
    await _auth?.cancel();
    _events.clear();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      FlutterError.onError = _previousFlutterError;
      PlatformDispatcher.instance.onError = _previousPlatformError;
    }
    if (identical(active, this)) active = null;
  }
}

/// Only known screen codes are recorded. A dialog or an unknown route name
/// cannot leak an account identifier or replace the section under it.
class AppSectionObserver extends NavigatorObserver {
  static final instance = AppSectionObserver();
  final Map<Route<dynamic>, String> _names = {};
  final List<Route<dynamic>> _routes = [];
  String tab = 'home';
  static const routeSections = {
    '/': 'shell',
    '/my-ads': 'ads',
    '/notifications': 'notifications',
    '/wallet': 'shell',
    '/profile': 'profile',
    '/transactions': 'transactions',
    '/coupons': 'discounts',
    '/faq': 'faq',
    '/assets': 'shell',
  };
  static const widgetSections = {
    'MainShell': 'shell',
    'HomeScreen': 'home',
    'AdScreen': 'ads',
    'ToolsScreen': 'tools',
    'ProfileScreen': 'profile',
    'AccountSetupGate': 'account_setup',
    'AuthScreen': 'auth',
    'AuthShell': 'auth',
    'AdCreateScreen': 'create_ad',
    'AdDetailScreen': 'ad_details',
    'DepositScreen': 'deposit',
    'NotificationsScreen': 'notifications',
    'TxHistoryPage': 'transactions',
    'TransactionDetailScreen': 'transaction_details',
    'EditProfileScreen': 'edit_profile',
    'FaqScreen': 'faq',
    'TasksPage': 'tasks',
    'LevelsPage': 'levels',
    'VoucherPage': 'vouchers',
    'DiscountCodesPage': 'discounts',
    'TutorialScreen': 'tutorials',
    'BestMetricsScreen': 'best_metrics',
    'ProxoCardsListScreen': 'pages',
    'ProxoLinkPageEditor': 'page_editor',
    'ProxoLinkPageDetailsScreen': 'page_details',
    'ProxoLinkCreatePageScreen': 'create_page',
    'CardWebViewScreen': 'browser',
    'WhatsappMarketingScreen': 'whatsapp_marketing',
  };
  static String forWidget(Widget child) =>
      widgetSections[child.runtimeType.toString()] ?? 'other';
  void register(Route<dynamic>? route, String section) {
    if (route == null ||
        (!AppTelemetryService.sections.contains(section) && section != 'shell'))
      return;
    _names[route] = section;
    _showVisible();
  }

  void selectTab(String name) {
    if (!const {'home', 'ads', 'tools', 'profile'}.contains(name)) return;
    tab = name;
    _showVisible();
  }

  void _showVisible() {
    for (final route in _routes.reversed) {
      final name = _names[route] ?? routeSections[route.settings.name];
      if (name != null) {
        AppTelemetryService.active?.section(name == 'shell' ? tab : name);
        return;
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _showVisible();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _names.remove(route);
    _showVisible();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _names.remove(route);
    _showVisible();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    _names.remove(oldRoute);
    if (index >= 0) {
      if (newRoute == null)
        _routes.removeAt(index);
      else
        _routes[index] = newRoute;
    }
    _showVisible();
  }
}

class TrackedSection extends StatefulWidget {
  const TrackedSection({super.key, required this.child});
  final Widget child;
  @override
  State<TrackedSection> createState() => _TrackedSectionState();
}

class _TrackedSectionState extends State<TrackedSection> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppSectionObserver.instance.register(
      ModalRoute.of(context),
      AppSectionObserver.forWidget(widget.child),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
