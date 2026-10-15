import 'package:solar_iconkit/solar_iconkit.dart';
import '../l10n/proxo_strings.dart';
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
import '../widgets/proxo_refresh.dart';
import '../widgets/ad_feedback.dart';
import '../widgets/proxo_popup.dart';
import '../widgets/best_metrics_home_section.dart';
import '../widgets/home_quick_actions.dart';
import '../widgets/ad_form_components.dart';
import '../main.dart' show supabase, navigatorKey;
import 'package:proxo_app/widgets/proxo_text.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────

const Color kProxoBlue   = AppColors.accent;
const Color _kBannerTop  = AppColors.accent;
const Color _kBannerBot  = AppColors.accent;
const Color _kDeltaUp    = Color(0xFF74F96E);
const Color _kDeltaDown  = Color(0xFFFFC0B4);
const Color _kBannerInk  = AppColors.ink;

const Color _kPageBg = Colors.white;

const double _kRefContentW = 398.0;

double _scaleFor(double contentWidth) =>
    (contentWidth / _kRefContentW).clamp(0.86, 1.06);

const TextStyle _kBase =
    TextStyle(fontFamily: kAppFont, decoration: TextDecoration.none);

// ─────────────────────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────────────────────

num? _asNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

String _grouped(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}

String _money(double v) {
  final cents = (v.abs() * 100).round();
  final frac = (cents % 100).toString().padLeft(2, '0');
  return '${v < 0 ? '-' : ''}\$${_grouped(cents ~/ 100)}.$frac';
}

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

  static const String _kDashColumns =
      'id,title,status,spend,prev_spend,clicks,impressions,'
      'prev_impressions,conversions,budget,total_budget,'
      'tiktok_ad_id,created_at,start_date,end_date,'
      'thumbnail_url,feedback_rating,feedback_at';

  static const List<String> kRanges = <String>[
    'Today',
    'Last 7 days',
    'Last 30 days',
    'All time',
  ];

  String _range = 'Last 7 days';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskNotifPermission());
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
        final isGranted = s.authorizationStatus == AuthorizationStatus.authorized ||
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

  Future<void> _loadAds() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
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
      });
      if (widget.isActive) unawaited(_maybePromptForFeedback(rows));
    } catch (e) {
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
      final int index = _ads.indexWhere((Map<String, dynamic> ad) =>
          (ad['id'] ?? '').toString() == adId);
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

  Duration? _rangeSpan() {
    switch (_range) {
      case 'Today':        return const Duration(days: 1);
      case 'Last 7 days':  return const Duration(days: 7);
      case 'Last 30 days': return const Duration(days: 30);
      default:             return null;
    }
  }

  DateTime? _createdAt(Map<String, dynamic> ad) =>
      DateTime.tryParse(ad['created_at']?.toString() ?? '')?.toLocal();

  _Totals _totalsIn(DateTime? from, DateTime? to) {
    var spend = 0.0;
    var clicks = 0, impressions = 0, conversions = 0;
    for (final ad in _ads) {
      if (from != null || to != null) {
        final at = _createdAt(ad);
        if (at == null) continue;
        if (from != null && at.isBefore(from)) continue;
        if (to != null && !at.isBefore(to)) continue;
      }
      spend += (_asNum(ad['prev_spend'])?.toDouble() ?? 0) +
               (_asNum(ad['spend'])?.toDouble() ?? 0);
      clicks += _asNum(ad['clicks'])?.toInt() ?? 0;
      impressions += (_asNum(ad['prev_impressions'])?.toInt() ?? 0) +
                     (_asNum(ad['impressions'])?.toInt() ?? 0);
      conversions += _asNum(ad['conversions'])?.toInt() ?? 0;
    }
    return _Totals(
      spend: spend,
      clicks: clicks,
      impressions: impressions,
      conversions: conversions,
    );
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
      case 'create': case '/create': widget.onCreateTap?.call(); return;
      case 'deposit': case '/deposit': case 'wallet': case '/wallet':
        widget.onAddBalanceTap?.call(); return;
      case 'tools': case '/tools': case 'assets': case '/assets':
        widget.onToolsTap?.call(); return;
      case 'create-page': widget.onCreatePageTap?.call(); return;
      case 'faq': case '/faq': widget.onFaqTap?.call(); return;
      case '/my-ads': case '/notifications': case '/profile':
      case '/transactions': case '/coupons':
        await Navigator.of(context).pushNamed(route); return;
    }
    final uri = Uri.tryParse(route);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      try { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } catch (_) {}
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ئەم بەستەرە بەردەست نییە')));
  }

  void _onRangeChanged(String r) {
    if (r == _range) return;
    setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final width = MediaQuery.sizeOf(context).width;
    final s = _scaleFor(width - 32);

    final span = _rangeSpan();
    final now = DateTime.now();
    final from = span == null ? null : now.subtract(span);
    final current = _totalsIn(from, null);
    final previous = span == null
        ? const _Totals.zero()
        : _totalsIn(now.subtract(span * 2), from);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kPageBg,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Reveal(animation: _aBanner,
                      child: RepaintBoundary(child: ProxoBanner(
                        onStart: widget.onCreateTap, onNavigate: _openBannerTarget))),
                    const SizedBox(height: AdUi.sectionGap),
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
                    const SizedBox(height: AdUi.sectionGap),
                    _Reveal(
                      animation: _aWeekly,
                      child: RepaintBoundary(
                        child: BestMetricsHomeSection(key: _bestMetricsKey),
                      ),
                    ),
                    const SizedBox(height: AdUi.sectionGap),
                    ExpansionTile(
                      title: ProxoText('پوختەی ڕیکلامەکان', translate: true, style: AdUi.heading(context)),
                      children: [
                    _Reveal(
                      animation: _aBanner,
                      child: RepaintBoundary(
                        child: ProxoOverviewBanner(
                          scale: s,
                          range: _range,
                          ranges: kRanges,
                          onRangeChanged: _onRangeChanged,
                          spend: current.spend,
                          clicks: current.clicks,
                          conversions: current.conversions,
                          ctr: current.ctr,
                          spendDelta: current.deltaOf(previous.spend, current.spend),
                          clicksDelta: current.deltaOf(
                              previous.clicks.toDouble(), current.clicks.toDouble()),
                          conversionsDelta: current.deltaOf(
                              previous.conversions.toDouble(),
                              current.conversions.toDouble()),
                          ctrDelta: current.deltaOf(previous.ctr, current.ctr),
                        ),
                      ),
                    ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Totals {
  final double spend;
  final int clicks;
  final int impressions;
  final int conversions;

  const _Totals({
    required this.spend,
    required this.clicks,
    required this.impressions,
    required this.conversions,
  });

  const _Totals.zero()
      : spend = 0,
        clicks = 0,
        impressions = 0,
        conversions = 0;

  double get ctr => impressions > 0 ? clicks / impressions * 100 : 0;

  double? deltaOf(double before, double after) {
    if (before <= 0) return after > 0 ? null : 0;
    return (after - before) / before * 100;
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

class ProxoOverviewBanner extends StatelessWidget {
  final double scale;
  final String range;
  final List<String> ranges;
  final ValueChanged<String> onRangeChanged;
  final double spend;
  final int clicks;
  final int conversions;
  final double ctr;
  final double? spendDelta;
  final double? clicksDelta;
  final double? conversionsDelta;
  final double? ctrDelta;

  const ProxoOverviewBanner({
    super.key,
    required this.scale,
    required this.range,
    required this.ranges,
    required this.onRangeChanged,
    required this.spend,
    required this.clicks,
    required this.conversions,
    required this.ctr,
    this.spendDelta,
    this.clicksDelta,
    this.conversionsDelta,
    this.ctrDelta,
  });

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final metrics = [
      ('تێچوو', _money(spend), spendDelta, SolarIcons.dollarMinimalistic),
      ('کرتەکان', _grouped(clicks), clicksDelta, SolarIcons.cursorSquare),
      ('کرداری سەرکەوتوو', _grouped(conversions), conversionsDelta, SolarIcons.target),
      ('ڕێژەی کرتە', '${ctr.toStringAsFixed(2)}%', ctrDelta, SolarIcons.arrowRightUp),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.accent,
        borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12, runSpacing: 10, children: [
            const ProxoText('پوختەی ڕیکلامەکان', translate: true,
              style: TextStyle(fontFamily: kAppFont, fontSize: 16, height: 1.5, color: Colors.white)),
            _RangePill(scale: 1, label: range, ranges: ranges, onSelected: onRangeChanged),
          ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(14) > 21 ? 1 : 2;
          final width = (constraints.maxWidth - (columns-1)*12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final metric in metrics)
            SizedBox(width: width, child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [SolarIcon(metric.$4, style: SolarIconStyle.linear, size: 22, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: ProxoText(metric.$1, translate: true,
                    style: const TextStyle(fontFamily:kAppFont,fontSize:13,height:1.5,color:Colors.white)))]),
                const SizedBox(height: 10),
                ProxoText(metric.$2, textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily:kAppFont,fontSize:21,height:1.3,color:Colors.white)),
                const SizedBox(height: 6),
                ProxoText(metric.$3 == null ? '—' : '${metric.$3! >= 0 ? '+' : ''}${metric.$3!.toStringAsFixed(1)}%',
                  textDirection:TextDirection.ltr,
                  style: const TextStyle(fontFamily:kAppFont,fontSize:12,height:1.5,color:Colors.white)),
              ])))]);
        }),
      ]),
    );
  }
}

String _rangeLabel(String value) => ProxoStrings.text(switch(value) {
  'Today' => 'ئەمڕۆ',
  'Last 7 days' => '٧ ڕۆژی ڕابردوو',
  'Last 30 days' => '٣٠ ڕۆژی ڕابردوو',
  'All time' => 'هەموو کاتەکان',
  _ => value,
});

class _RangePill extends StatelessWidget {
  const _RangePill({required this.scale,required this.label,required this.ranges,required this.onSelected});
  final double scale;
  final String label;
  final List<String> ranges;
  final ValueChanged<String> onSelected;
  @override Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return PopupMenuButton<String>(
      tooltip: ProxoStrings.text('ماوە هەڵبژێرە'), onSelected:onSelected,
      itemBuilder: (_) => [for(final range in ranges) PopupMenuItem<String>(
        value:range, height:48, child:ProxoText(_rangeLabel(range)))],
      child: Semantics(button:true,label:_rangeLabel(label),
        child: Container(constraints:const BoxConstraints(minHeight:48),
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12)),
          child:Row(mainAxisSize:MainAxisSize.min,children:[
            Flexible(child:ProxoText(_rangeLabel(label),style:const TextStyle(fontSize:13,height:1.5,color:AppColors.accent))),
            const SizedBox(width:8),
            const SolarIcon(SolarIcons.altArrowDown,style:SolarIconStyle.linear,size:18,color:AppColors.accent),
          ]))),
    );
  }
}
