import '../theme/proxo_design_tokens.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/proxo_banner.dart';
// home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/proxo_toast.dart';
import '../widgets/proxo_refresh.dart';
import '../widgets/ad_feedback.dart';
import '../widgets/proxo_popup.dart';
import '../widgets/best_metrics_home_section.dart';
import '../widgets/home_quick_actions.dart';
import '../main.dart' show supabase, navigatorKey;

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onMenuTap;
  final VoidCallback? onCreateTap;
  final VoidCallback? onAddBalanceTap;
  final VoidCallback? onGoToAds;
  final VoidCallback? onToolsTap;
  final VoidCallback? onCreatePageTap;
  final VoidCallback? onFaqTap;
  final VoidCallback? onDuplicateTap;
  final VoidCallback? onReportsTap;
  final ProxoRefreshController? refreshController;

  const HomeScreen({
    super.key,
    this.isActive = true,
    this.refreshController,
    this.onMenuTap,
    this.onCreateTap,
    this.onAddBalanceTap,
    this.onGoToAds,
    this.onToolsTap,
    this.onCreatePageTap,
    this.onFaqTap,
    this.onDuplicateTap,
    this.onReportsTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey<BestMetricsHomeSectionState> _bestMetricsKey =
      GlobalKey<BestMetricsHomeSectionState>();

  // The removed overview no longer needs campaign totals. Keep the small
  // feedback query because completed adverts must still be rateable on Home.
  static const String _kFeedbackColumns =
      'id,title,status,thumbnail_url,feedback_rating,feedback_at,created_at';

  List<Map<String, dynamic>> _ads = const [];
  bool _feedbackDialogOpen = false;
  bool _activationRefreshQueued = false;
  RealtimeChannel? _feedbackChannel;

  bool _popupDialogOpen = false;
  RealtimeChannel? _popupChannel;

  /// Home may rebuild while the bottom navigation moves, but a pending rating
  /// should never interrupt the user twice in one app session. If dismissed,
  /// it is offered again after the next cold start.
  static bool _feedbackPromptShownThisSession = false;

  /// هەمان یاسا بۆ ڕاگەیاندنی ئادمین: یەک جار لە هەر کردنەوەیەکی ئەپدا،
  /// تەنانەت ئەگەر بەکارهێنەر چەند جار بێتەوە سەر تابی سەرەکی.
  ///
  /// ⚠ ئەمە جیاوازە لە «بینراو»ی هەمیشەیی، کە لە `proxo_popup.dart`دا
  ///   بە `pa_popup_views` هەڵدەگیرێت. ئەمە تەنها ئەم سێشنەیە.
  static bool _popupShownThisSession = false;

  late final AnimationController _intro;
  late final Animation<double> _aBanner;
  late final Animation<double> _aActions;
  late final Animation<double> _aWeekly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _aBanner = CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.00, 0.50, curve: Curves.easeOutCubic));
    _aActions = CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.16, 0.68, curve: Curves.easeOutCubic));
    _aWeekly = CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.34, 1.00, curve: Curves.easeOutCubic));
    _intro.forward();

    _loadAds();
    _startFeedbackRealtime();
    _startPopupRealtime();
    unawaited(_maybeShowAdminPopup());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeAskNotifPermission());
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // The tab switch itself stays instant; fresh data and a possible prompt
      // are resolved after the bottom-nav indicator has settled.
      unawaited(_reloadAfterTabSettle());
    }
  }

  Future<void> _reloadAfterTabSettle() async {
    if (_activationRefreshQueued) return;
    _activationRefreshQueued = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted || !widget.isActive) return;
      await Future.wait(<Future<void>>[
        _loadAds(),
        _bestMetricsKey.currentState?.refresh(forceRefresh: false) ??
            Future<void>.value(),
      ]);
    } finally {
      _activationRefreshQueued = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intro.dispose();
    _scrollCtrl.dispose();
    _feedbackChannel?.unsubscribe();
    _popupChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_reloadAfterTabSettle());
    }
  }

  void _startFeedbackRealtime() {
    final User? user = supabase.auth.currentUser;
    if (user == null) return;
    _feedbackChannel?.unsubscribe();
    _feedbackChannel = supabase.channel('home_feedback_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'pa_ads',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (PostgresChangePayload payload) {
          if (!mounted || !widget.isActive) return;
          final Map<String, dynamic> changed = payload.newRecord;
          final String status =
              (changed['status'] ?? '').toString().trim().toLowerCase();
          if ((status == 'completed' || status == 'done') &&
              changed['feedback_rating'] == null) {
            unawaited(_maybePromptForFeedback(<Map<String, dynamic>>[changed]));
          }
        },
      )
      ..subscribe();
  }

  /// ڕاگەیاندنی ئادمین — گشتییە، بۆیە هیچ فلتەرێکی `user_id` نییە.
  ///
  /// هەم `insert` هەم `update` گوێ لێدەگیرێت: ئادمین لەوانەیە ڕیزێکی
  /// کۆن دووبارە چالاک بکاتەوە (`is_active = true`) نەک ڕیزێکی نوێ
  /// دابنێت.
  void _startPopupRealtime() {
    _popupChannel?.unsubscribe();
    _popupChannel = supabase.channel('home_popups')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'pa_popups',
        callback: (_) => unawaited(_maybeShowAdminPopup()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'pa_popups',
        callback: (_) => unawaited(_maybeShowAdminPopup()),
      )
      ..subscribe();
  }

  Future<void> _maybeShowAdminPopup() async {
    if (_popupShownThisSession || _popupDialogOpen || _feedbackDialogOpen) {
      return;
    }

    final ProxoPopup? popup = await fetchPendingProxoPopup();
    if (popup == null) return;

    // فرەیمی یەکەمی شاشەی سەرەکی و ڕێکخستنی تاب ئازاد دەهێڵدرێنەوە،
    // وەک `_maybePromptForFeedback`.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted ||
        !widget.isActive ||
        _popupShownThisSession ||
        _popupDialogOpen ||
        _feedbackDialogOpen ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    _popupDialogOpen = true;
    try {
      // ⚠ `showProxoPopup` سەرەتا وێنەکە دادەبەزێنێت و تەنها ئەگەر
      //   سەرکەوتوو بوو دەیکاتەوە. ئەگەر `false` گەڕایەوە، واتە وێنەکە
      //   نەهات — ئەو کاتە `_popupShownThisSession` دانانرێت، تاکو
      //   هەوڵێکی دواتری ئەم سێشنە (وەک گەڕانەوە بۆ تابی سەرەکی)
      //   بتوانێت دووبارە هەوڵ بدات.
      final bool shown = await showProxoPopup(context, popup);
      if (shown) _popupShownThisSession = true;
    } finally {
      _popupDialogOpen = false;
    }
  }

  // Shared across Home instances: the OS dialog may outlive its first screen.
  static bool _notificationRequestInFlight = false;
  Future<void> _maybeAskNotifPermission() async {
    if (!mounted || !widget.isActive || _notificationRequestInFlight) return;
    _notificationRequestInFlight = true;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    try {
      if (isAndroid) {
        final status = await ph.Permission.notification.status;
        if (status.isGranted) return;
        if (status.isPermanentlyDenied) return;
      } else {
        final s = await FirebaseMessaging.instance.getNotificationSettings();
        final isDenied = s.authorizationStatus == AuthorizationStatus.denied;
        final isGranted =
            s.authorizationStatus == AuthorizationStatus.authorized ||
                s.authorizationStatus == AuthorizationStatus.provisional;
        if (isDenied) return;
        if (isGranted) return;
      }
      if (!mounted) return;
      if (isAndroid) {
        final requested = await ph.Permission.notification.request();
        if (!requested.isGranted) return;
      } else {
        final requested = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (requested.authorizationStatus != AuthorizationStatus.authorized &&
            requested.authorizationStatus != AuthorizationStatus.provisional)
          return;
      }
      if (!mounted) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase.from('pa_device_tokens').upsert(
            {
              'user_id': user.id,
              'token': token,
              'platform': isAndroid ? 'android' : 'ios',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'user_id, token',
          );
        }
      }
    } catch (_) {
      // Notification setup is optional. A platform/FCM failure must not throw
      // an unhandled asynchronous exception or prevent Home from working.
    } finally {
      _notificationRequestInFlight = false;
    }
  }

  Future<void>? _adsRequest;
  String? _adsRequestOwner;

  // Opening, activation and pull-to-refresh can overlap. Reuse only an
  // in-flight request for this owner; a later explicit refresh still fetches.
  Future<void> _loadAds() {
    final owner = supabase.auth.currentUser?.id;
    if (owner == null) return Future<void>.value();
    if (_adsRequest != null && _adsRequestOwner == owner) return _adsRequest!;
    _adsRequestOwner = owner;
    late final Future<void> request;
    request = _fetchAds(owner).whenComplete(() {
      if (identical(_adsRequest, request)) {
        _adsRequest = null;
        _adsRequestOwner = null;
      }
    });
    _adsRequest = request;
    return request;
  }

  Future<void> _fetchAds(String owner) async {
    try {
      final res = await supabase
          .from('pa_ads')
          .select(_kFeedbackColumns)
          .eq('user_id', owner)
          .order('created_at', ascending: false);
      if (!mounted || supabase.auth.currentUser?.id != owner) return;
      final List<Map<String, dynamic>> rows =
          List<Map<String, dynamic>>.from(res as List? ?? const []);
      _ads = rows;
      if (widget.isActive) unawaited(_maybePromptForFeedback(rows));
    } catch (e) {
      debugPrint('HomeScreen: feedback fetch failed: $e');
    }
  }

  Future<void> _maybePromptForFeedback(
    List<Map<String, dynamic>> rows,
  ) async {
    if (_feedbackDialogOpen ||
        _feedbackPromptShownThisSession ||
        _popupDialogOpen) {
      return;
    }

    Map<String, dynamic>? candidate;
    for (final Map<String, dynamic> ad in rows) {
      final String status =
          (ad['status'] ?? '').toString().trim().toLowerCase();
      final String id = (ad['id'] ?? '').toString().trim();
      if ((status == 'completed' || status == 'done') &&
          ad['feedback_rating'] == null &&
          id.isNotEmpty) {
        candidate = ad;
        break;
      }
    }
    if (candidate == null) return;
    final Map<String, dynamic> pendingAd = candidate;

    // Leave navigation and the first Home frame completely free. This also
    // avoids competing with the OS notification-permission surface.
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted ||
        !widget.isActive ||
        _feedbackDialogOpen ||
        _feedbackPromptShownThisSession ||
        _popupDialogOpen ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final String adId = (pendingAd['id'] ?? '').toString();
    _feedbackPromptShownThisSession = true;
    _feedbackDialogOpen = true;
    try {
      final int? rating = await showAdFeedbackDialog(
        context,
        adId: adId,
        adTitle: (pendingAd['title'] ?? 'ڕیکلام').toString(),
        thumbnailUrl: pendingAd['thumbnail_url']?.toString(),
      );
      if (!mounted || rating == null) return;

      // Patch the warm feedback list without rebuilding the Home layout.
      final int index = _ads.indexWhere(
          (Map<String, dynamic> ad) => (ad['id'] ?? '').toString() == adId);
      if (index >= 0) {
        _ads = List<Map<String, dynamic>>.from(_ads)
          ..[index] = <String, dynamic>{
            ..._ads[index],
            'feedback_rating': rating,
            'feedback_at': DateTime.now().toUtc().toIso8601String(),
          };
      }
    } finally {
      _feedbackDialogOpen = false;
    }
  }

  Future<void> _refresh() async {
    await Future.wait(<Future<void>>[
      _loadAds(),
      _bestMetricsKey.currentState?.refresh() ?? Future<void>.value(),
    ]);
  }

  Future<void> _openBannerTarget(String target) async {
    final route = target.trim();
    switch (route) {
      case 'create':
      case '/create':
        widget.onCreateTap?.call();
        return;
      case 'deposit':
      case '/deposit':
      case 'wallet':
      case '/wallet':
        widget.onAddBalanceTap?.call();
        return;
      case 'tools':
      case '/tools':
      case 'assets':
      case '/assets':
        widget.onToolsTap?.call();
        return;
      case 'create-page':
        widget.onCreatePageTap?.call();
        return;
      case 'faq':
      case '/faq':
        widget.onFaqTap?.call();
        return;
      case '/my-ads':
      case '/notifications':
      case '/profile':
      case '/transactions':
      case '/coupons':
        await Navigator.of(context).pushNamed(route);
        return;
    }
    final uri = Uri.tryParse(route);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (mounted) showProxoToast(context, 'ئەم بەستەرە بەردەست نییە');
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ProxoTopBar(
          topPadding: MediaQuery.of(context).padding.top,
          onMenuTap: widget.onMenuTap,
          onNotificationTap: () =>
              navigatorKey.currentState?.pushNamed('/notifications'),
        ),
        body: AppBackground(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ProxoRefresh(
              pullToRefresh: true,
              controller: widget.refreshController,
              scrollController: _scrollCtrl,
              onRefresh: _refresh,
              onArrive: () {
                if (mounted) _intro.forward(from: 0.0);
              },
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Reveal(
                            animation: _aBanner,
                            child: RepaintBoundary(
                                child: ProxoBanner(
                                    onStart: widget.onCreateTap,
                                    onNavigate: _openBannerTarget))),
                        const SizedBox(height: ProxoDesign.sectionGap),
                        _Reveal(
                          animation: _aActions,
                          child: RepaintBoundary(
                            child: HomeQuickActions(
                              onCreateTap: widget.onCreateTap,
                              onAddBalanceTap: widget.onAddBalanceTap,
                              onToolsTap: widget.onToolsTap,
                              onCreatePageTap: widget.onCreatePageTap,
                              onFaqTap: widget.onFaqTap,
                            ),
                          ),
                        ),
                        const SizedBox(height: ProxoDesign.sectionGap),
                        _Reveal(
                          animation: _aWeekly,
                          child: RepaintBoundary(
                            child: BestMetricsHomeSection(key: _bestMetricsKey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _Reveal({required this.animation, required this.child});

  static final Animatable<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero);

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(_slide),
          child: child,
        ),
      );
}
