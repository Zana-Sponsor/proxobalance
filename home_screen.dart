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
import '../main.dart' show supabase, navigatorKey, kAppFont;

String? _sCachedUserName;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────

const Color kProxoBlue   = AppColors.accent;
const Color _kBannerTop  = AppColors.accent;
const Color _kBannerBot  = AppColors.accent;
const Color _kDeltaUp    = Color(0xFF74F96E);
const Color _kDeltaDown  = Color(0xFFFFC0B4);
const Color _kBannerInk  = AppColors.ink;

const Color _kPageBg = AppColors.surfaceBase;

const double _kRefContentW = 398.0;

double _scaleFor(double contentWidth) =>
    (contentWidth / _kRefContentW).clamp(0.86, 1.06);

const TextStyle _kBase =
    TextStyle(fontFamily: kAppFont, decoration: TextDecoration.none);

const TextStyle _kBaseKu = TextStyle(
  fontFamily: kAppFont,
  fontFamilyFallback: ['Arial', 'sans-serif'],
  decoration: TextDecoration.none,
);

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions Tokens — هاوسەنگکراو و توندوتۆڵ
// ─────────────────────────────────────────────────────────────────────────────

const double _kQaRadius     = 16.0;
const double _kQaPadH       = 14.0;
/// ⚠ بوو 14 ⇒ بەرزایی کارت 72. 16 دەیکاتە 76 — هەمان بۆکسی ئایکۆن،
/// بۆشاییەکی زیاتر لە دەوریدا، بۆیە ڕیزەکە چڕ دەرناکەوێت.
const double _kQaPadV       = 16.0;
const double _kQaGapBanner  = 16.0;
const double _kQaGapCard    = 10.0; 

// بۆکسی ئایکۆن — سکوێرکڵێکی 44×44 بە پاشبنەمایەکی پاستێلی سووک.
// 44 هەروەها کەمترین ئامانجی دەستلێدانی پێشنیارکراوە، بۆیە ئایکۆنەکە
// خۆی ناوچەیەکی گونجاوی هەیە تەنانەت ئەگەر ڕۆژێک دەستلێدانی جیای هەبوو.
const double _kQaIconBox    = 44.0;
const double _kQaIconRadius = 14.0; // ≈ 0.32 × بۆکس — سکوێرکڵ، نەک بازنە
const double _kQaIconSize   = 22.0;
const double _kQaIconGap    = 14.0; // ⚠ بوو 12

const double _kQaChevron    = 22.0; // پێشتر 26.0 بوو
const double _kQaChevronGap =  8.0; 

// تایپۆگرافی — ژمارە کۆتاییەکانی بریفەکە بە dp. ⚠ ئەم فایلە
// `kKuFontBump` جێبەجێ **ناکات** (هەرگیز نەیکردووە)، بۆیە ئەمانە
// دەقاودەق ئەوەن کە دەکێشرێن، تەنها بە `s`ی شاشە.
const double _kQaFsTitle    = 15.0; // w700
const double _kQaFsSub      = 12.0; // w400
const double _kQaTitleGap   =  3.5; // بۆشاییەکی مامناوەندی گونجاو
const double _kQaLhTitle    = 1.22; // بەرزایی هێڵی سروشتی
const double _kQaLhSub      = 1.30; 

/// چیڤرۆن — سووکترین توخمی کارتەکە. ⚠ نابێت شین بێت: ئەوە وەک
/// دوگمەیەکی جیاواز دەخوێندرێتەوە، لە کاتێکدا هەموو کارتەکە خۆی
/// دەستلێدانێکە.
const Color _kQaChevronInk = Color(0xFFCBD5E1);

// ── ڕووی کارت ──────────────────────────────────────────────────────────────
// ⚠ پێشتر `kProxoCardBorder` (#D4D9E1) + `kProxoCardShadow`
// (0 8px 30px rgba(15,23,42,.07)) بوون — تۆکنی کارتی گەورەی ئەپەکە. لەسەر
// سێ ڕیزی بچووکی تەنیشت یەکتر ئەو سێبەرە قووڵە وا دەکرد کارتەکان وەک سێ
// تەختەی مەلەوەر دەربکەون نەک وەک یەک لیست. ئەمانە تایبەتن بەم ڕیزانە:
// سنوورێکی زۆر سووک + سێبەرێکی 3٪ی نزیک.
/// ⚠ بوو #F1F5F9. لەسەر پەڕەیەکی #FAFAFA ئەو سنوورە بە زەحمەت
/// دەبینرا، بۆیە کارتەکان پشتیان بە سێبەرەکە دەبەست بۆ دیاریکردنی
/// لێوارەکەیان — و ئەوە وای دەکرد قورس و «تۆخ» دەربکەون. سنوورێکی
/// دیارتر واتە دەکرێت سێبەرەکە سووکتر بێت.
const Color _kQaBorder = Color(0xFFE2E8F0);
const double _kQaBorderW = 1.0;
/// ⚠ بوو `0x08000000 / blur 10 / (0,4)`. لەگەڵ سنوورێکی دیارتردا
/// ئەو قووڵاییە زیادە بوو و کارتەکانی وەک تەختەی مەلەوەر دەردەخست.
const List<BoxShadow> _kQaShadow = [
  BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
];

const Color _kQaFillCreate = Color(0xFFEEF2FF); // سووک و پاک
const Color _kQaFillTools  = Color(0xFFECFDF5);
const Color _kQaFillFaq    = Color(0xFFEFF6FF);

/// ⚠ کردنەوەی کەمپەین کرداری سەرەکیی ئەم شاشەیەیە، بۆیە ئایکۆنەکەی
/// شینی سەرەکی وەردەگرێت. دووانەکەی تر تۆنی خۆیان دەپارێزن — ئەگەر هەر
/// سێکیان شین بن، هیچیان جیا نابێتەوە.
const Color _kQaInkCreate = AppColors.accent;
const Color _kQaInkTools  = Color(0xFF059669);
const Color _kQaInkFaq     = Color(0xFF2563EB);

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

  String _userName = '—';
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
    _intro.forward();

    _loadUser();
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
      await _loadAds();
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

  Future<void> _loadUser() async {
    if (_sCachedUserName != null) {
      if (mounted) setState(() => _userName = _sCachedUserName!);
      return;
    }
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      final name = profile?['full_name']?.toString() ??
          user.email?.split('@').first ?? '—';
      _sCachedUserName = name;
      if (mounted) setState(() => _userName = name);
    } catch (_) {}
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
      _loadUser(),
      _loadAds(),
    ]);
  }

  void _onRangeChanged(String r) {
    if (r == _range) return;
    setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
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
                    SizedBox(height: _kQaGapBanner * s),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: _Reveal(
                        animation: _aActions,
                        child: RepaintBoundary(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _QuickActionCard(
                                scale: s,
                                icon: Icons.add_rounded,
                                title: 'کەمپەینی نوێ',
                                iconFill: _kQaFillCreate,
                                iconInk: _kQaInkCreate,
                                subtitle: 'کەمپەینێکی نوێ دروست بکە!',
                                onTap: widget.onCreateTap,
                              ),
                              SizedBox(height: _kQaGapCard * s),
                              _QuickActionCard(
                                scale: s,
                                icon: Icons.link_rounded,
                                title: 'ئامرازی پەیوەندی',
                                iconFill: _kQaFillTools,
                                iconInk: _kQaInkTools,
                                subtitle: 'لاندینگ پەیجێکی پەیوەندی دروست بکە!',
                                onTap: widget.onToolsTap,
                              ),
                              SizedBox(height: _kQaGapCard * s),
                              _QuickActionCard(
                                scale: s,
                                icon: Icons.question_mark_rounded,
                                title: 'پرسیارە دووبارەکان',
                                iconFill: _kQaFillFaq,
                                iconInk: _kQaInkFaq,
                                subtitle: 'وەڵامی پرسیارە باوەکان ببینە!',
                                onTap: widget.onFaqTap,
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _QuickActionIcon extends StatelessWidget {
  final double scale;
  final IconData icon;
  final Color fill;
  final Color ink;

  const _QuickActionIcon({
    required this.scale,
    required this.icon,
    required this.fill,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      width: _kQaIconBox * s,
      height: _kQaIconBox * s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_kQaIconRadius * s),
      ),
      child: Icon(
        icon,
        size: _kQaIconSize * s,
        color: ink,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final double scale;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconFill;
  final Color iconInk;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.scale,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconFill,
    required this.iconInk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final radius = BorderRadius.circular(_kQaRadius * s);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: radius,
        boxShadow: _kQaShadow,
      ),
      // `foregroundDecoration` بۆ سنوورەکە، نەک `decoration`: سنوورێکی
      // ناوەوە لەسەر `InkWell`ـەکە دەکێشرێت، بۆیە ڕیپڵی داگرتن لە ژێریدا
      // دەڕوات و لێوارەکە قایم دەمێنێتەوە.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _kQaBorder, width: _kQaBorderW),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _kQaPadH * s,
              vertical: _kQaPadV * s,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: _kQaChevron * s,
                    color: _kQaChevronInk,
                  ),
                  SizedBox(width: _kQaChevronGap * s),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _kBaseKu.copyWith(
                              color: AppColors.ink,
                              fontSize: _kQaFsTitle * s,
                              fontWeight: FontWeight.w700,
                              height: _kQaLhTitle,
                            ),
                          ),
                          SizedBox(height: _kQaTitleGap * s),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _kBaseKu.copyWith(
                              color: AppColors.inkMuted,
                              fontSize: _kQaFsSub * s,
                              fontWeight: FontWeight.w400,
                              height: _kQaLhSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: _kQaIconGap * s),
                  _QuickActionIcon(
                    scale: s,
                    icon: icon,
                    fill: iconFill,
                    ink: iconInk,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final s = scale;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * s),
        gradient: const LinearGradient(
          begin: Alignment(-0.28, -1),
          end: Alignment(0.28, 1),
          colors: [_kBannerTop, _kBannerBot],
        ),
        boxShadow: [
          BoxShadow(
            color: _kBannerBot.withOpacity(0.26),
            blurRadius: 26 * s,
            spreadRadius: -6 * s,
            offset: Offset(0, 12 * s),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 19 * s, 18 * s, 0),
            child: SizedBox(
              height: 28 * s,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Overview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _kBase.copyWith(
                        color: Colors.white,
                        fontSize: 15 * s,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2 * s,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * s),
                  _RangePill(
                    scale: s,
                    label: range,
                    ranges: ranges,
                    onSelected: onRangeChanged,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatColumn(
                  scale: s,
                  icon: Icons.monetization_on_outlined,
                  label: 'Spend',
                  value: _money(spend),
                  delta: spendDelta,
                ),
              ),
              _StatDivider(scale: s),
              Expanded(
                child: _StatColumn(
                  scale: s,
                  painter: const _CursorPainter(),
                  label: 'Clicks',
                  value: _grouped(clicks),
                  delta: clicksDelta,
                ),
              ),
              _StatDivider(scale: s),
              Expanded(
                child: _StatColumn(
                  scale: s,
                  icon: Icons.task_alt,
                  label: 'Conversions',
                  value: _grouped(conversions),
                  delta: conversionsDelta,
                ),
              ),
              _StatDivider(scale: s),
              Expanded(
                child: _StatColumn(
                  scale: s,
                  icon: Icons.percent,
                  label: 'CTR',
                  value: '${ctr.toStringAsFixed(2)}%',
                  delta: ctrDelta,
                ),
              ),
            ],
          ),
          SizedBox(height: 23 * s),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final double scale;
  const _StatDivider({required this.scale});

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 104 * scale,
        color: Colors.white.withOpacity(0.14),
      );
}

class _StatColumn extends StatelessWidget {
  final double scale;
  final IconData? icon;
  final CustomPainter? painter;
  final String label;
  final String value;
  final double? delta;

  const _StatColumn({
    required this.scale,
    this.icon,
    this.painter,
    required this.label,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final d = delta;
    final positive = d == null ? null : d >= 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 26 * s,
            width: 26 * s,
            child: painter != null
                ? CustomPaint(painter: painter)
                : Icon(icon, size: 26 * s, color: Colors.white),
          ),
          SizedBox(height: 13 * s),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: _kBase.copyWith(
                color: Colors.white,
                fontSize: 10.5 * s,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: _kBase.copyWith(
                color: Colors.white,
                fontSize: 15 * s,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2 * s,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: 12 * s),
          SizedBox(
            height: 13.2 * s,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    positive == null
                        ? Icons.trending_flat_rounded
                        : (positive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded),
                    size: 12 * s,
                    color: positive == null
                        ? Colors.white.withOpacity(0.55)
                        : (positive ? _kDeltaUp : _kDeltaDown),
                  ),
                  SizedBox(width: 4 * s),
                  Text(
                    d == null ? '—' : '${d.abs().round()}%',
                    maxLines: 1,
                    style: _kBase.copyWith(
                      color: positive == null
                          ? Colors.white.withOpacity(0.55)
                          : (positive ? _kDeltaUp : _kDeltaDown),
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final double scale;
  final String label;
  final List<String> ranges;
  final ValueChanged<String> onSelected;

  const _RangePill({
    required this.scale,
    required this.label,
    required this.ranges,
    required this.onSelected,
  });

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final origin = box.localToGlobal(Offset(0, box.size.height + 6),
        ancestor: overlay);
    final picked = await showMenu<String>(
      context: context,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        overlay.size.width - origin.dx - box.size.width,
        0,
      ),
      items: [
        for (final r in ranges)
          PopupMenuItem<String>(
            value: r,
            height: 42 * scale,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r,
                    style: _kBase.copyWith(
                      fontSize: 12.5 * scale,
                      fontWeight:
                          r == label ? FontWeight.w700 : FontWeight.w600,
                      color: r == label ? kProxoBlue : _kBannerInk,
                    ),
                  ),
                ),
                if (r == label)
                  Icon(Icons.check_rounded,
                      size: 16 * scale, color: kProxoBlue),
              ],
            ),
          ),
      ],
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Material(
      color: Colors.white.withOpacity(0.88),
      borderRadius: BorderRadius.circular(14 * s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: EdgeInsets.only(left: 12 * s, right: 9 * s),
          child: SizedBox(
            height: 28 * s,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14 * s, color: kProxoBlue),
                SizedBox(width: 3 * s),
                Text(
                  label,
                  maxLines: 1,
                  style: _kBase.copyWith(
                    color: kProxoBlue,
                    fontSize: 10.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: 5 * s),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16 * s, color: kProxoBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  const _CursorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24.0;
    canvas.save();
    canvas.scale(k);

    final path = Path()
      ..moveTo(4.2, 2.0)
      ..lineTo(18.8, 13.4)
      ..lineTo(11.7, 14.0)
      ..lineTo(14.8, 20.9)
      ..lineTo(12.0, 22.1)
      ..lineTo(8.9, 15.2)
      ..lineTo(4.2, 19.8)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) => false;
}
