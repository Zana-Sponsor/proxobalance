// home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/proxo_refresh.dart';
import '../widgets/ad_feedback.dart';
import '../widgets/proxo_popup.dart';
import '../widgets/best_metrics_home_section.dart';
import '../widgets/home_quick_actions.dart';
import '../theme/proxo_ui.dart';
import 'home_statistics_screen.dart';
import '../main.dart' show supabase, navigatorKey;
import 'package:proxo_app/widgets/proxo_text.dart';

String? _sCachedUserName;
String? _sCachedUserId;

class HomeScreen extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onMenuTap;
  final VoidCallback? onCreateTap;
  final VoidCallback? onGoToAds;
  final VoidCallback? onToolsTap;
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
    this.onGoToAds,
    this.onToolsTap,
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

  static const String _kDashColumns =
      'id,title,status,spend,prev_spend,clicks,impressions,'
      'prev_impressions,conversions,budget,total_budget,'
      'tiktok_ad_id,created_at,start_date,end_date,'
      'thumbnail_url,feedback_rating,feedback_at';

  String _userName = '—';
  Object? _dashboardError;
  bool _statisticsOpen = false;

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

    _loadUser();
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

  Future<void> _maybeAskNotifPermission() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
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
    } catch (_) {}
    if (!mounted) return;

    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    if (isAndroid) {
      await ph.Permission.notification.request();
    } else {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

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
  }

  Future<void> _loadUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (_sCachedUserId == user.id && _sCachedUserName != null) {
      if (mounted) setState(() => _userName = _sCachedUserName!);
      return;
    }
    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      final name = profile?['full_name']?.toString() ??
          user.email?.split('@').first ??
          '—';
      _sCachedUserId = user.id;
      _sCachedUserName = name;
      if (mounted) setState(() => _userName = name);
    } catch (_) {}
  }

  Future<void> _loadAds() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Sign in required');
      final res = await supabase
          .from('pa_ads')
          .select(_kDashColumns)
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      final List<Map<String, dynamic>> rows =
          List<Map<String, dynamic>>.from(res as List? ?? const []);
      setState(() {
        _ads = rows;
        _dashboardError = null;
      });
      if (widget.isActive) unawaited(_maybePromptForFeedback(rows));
    } catch (e) {
      if (mounted) setState(() => _dashboardError = e);
      debugPrint('HomeScreen: dashboard fetch failed: $e');
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

      // Feedback does not affect any visible dashboard total. Patch the warm
      // list without rebuilding the whole Home screen.
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
      _loadUser(),
      _loadAds(),
      _bestMetricsKey.currentState?.refresh() ?? Future<void>.value(),
    ]);
  }

  void _openStatistics() {
    if (widget.onReportsTap != null) {
      widget.onReportsTap!();
      return;
    }
    if (_statisticsOpen) return;
    _statisticsOpen = true;
    Navigator.of(context).push(ProxoPageRoute<void>(
      builder: (_) => HomeStatisticsScreen(loadAds: () async {
        await _loadAds();
        if (_dashboardError != null) throw _dashboardError!;
        return List<Map<String, dynamic>>.unmodifiable(_ads);
      }),
    )).whenComplete(() => _statisticsOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ProxoUi.background,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: HomeContent(
                  userName: _userName,
                  onCreateTap: widget.onCreateTap,
                  onToolsTap: widget.onToolsTap,
                  onFaqTap: widget.onFaqTap,
                  onStatisticsTap: _openStatistics,
                  resultsKey: _bestMetricsKey,
                  headerAnimation: _aBanner,
                  actionsAnimation: _aActions,
                  resultsAnimation: _aWeekly,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The actual Home content, independent of authentication and network setup.
/// This keeps presentation testable while HomeScreen owns lifecycle/data.
class HomeContent extends StatelessWidget {
  final String userName;
  final VoidCallback? onCreateTap, onToolsTap, onFaqTap, onStatisticsTap;
  final GlobalKey<BestMetricsHomeSectionState>? resultsKey;
  final HomeResultsLoader? loadResults;
  final Animation<double> headerAnimation, actionsAnimation, resultsAnimation;

  const HomeContent(
      {super.key,
      this.userName = '',
      this.onCreateTap,
      this.onToolsTap,
      this.onFaqTap,
      this.onStatisticsTap,
      this.resultsKey,
      this.loadResults,
      this.headerAnimation = const AlwaysStoppedAnimation(1),
      this.actionsAnimation = const AlwaysStoppedAnimation(1),
      this.resultsAnimation = const AlwaysStoppedAnimation(1)});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Reveal(
                    animation: headerAnimation,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProxoText(
                              userName.isEmpty || userName == '—'
                                  ? 'بەخێربێیت بۆ پڕۆکسۆ'
                                  : 'بەخێربێیت، $userName',
                              style: ProxoUi.title),
                          const SizedBox(height: ProxoUi.gap4),
                          const ProxoText('کەمپەینەکانت بە ئاسانی بەڕێوە ببە.',
                              style: ProxoUi.secondary),
                          Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                key: const ValueKey('home-view-statistics'),
                                onPressed: onStatisticsTap,
                                style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 8)),
                                child: ProxoText('بینینی ئامارەکان',
                                    style: ProxoUi.label
                                        .copyWith(color: ProxoUi.primary)),
                              )),
                        ])),
                const SizedBox(height: ProxoUi.gap16),
                _Reveal(
                    animation: actionsAnimation,
                    child: RepaintBoundary(
                        child: HomeQuickActions(
                            onCreateTap: onCreateTap,
                            onToolsTap: onToolsTap,
                            onFaqTap: onFaqTap))),
                const SizedBox(height: ProxoUi.gap24),
                _Reveal(
                    animation: resultsAnimation,
                    child: RepaintBoundary(
                        child: BestMetricsHomeSection(
                            key: resultsKey, loadPreview: loadResults))),
              ],
            ),
          ),
        ),
      );
}

class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _Reveal({required this.animation, required this.child});
  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: animation, child: child);
}
