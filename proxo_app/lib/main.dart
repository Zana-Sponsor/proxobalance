// main.dart — Proxo App entry point

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'services/admin_notifier.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ad_screen.dart';
import 'screens/ad_create_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/faq_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/proxo_refresh.dart';
import 'widgets/proxo_sidebar.dart';
import 'screens/profile_screen.dart';
import 'widgets/no_internet_widget.dart';
import 'theme/app_theme.dart';
import 'theme/app_locale.dart';
import 'widgets/auth/auth_design.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global constants
// n8nDeleteAccountWebhook removed — delete-user Edge Function handles auth deletion
// ─────────────────────────────────────────────────────────────────────────────

const double kIqdRate = 1800.0;

const String kSupabaseUrl     = 'https://cojchkwssmasiejcgvbk.supabase.co';
const String kSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvamNoa3dzc21hc2llamNndmJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMTE1MTIsImV4cCI6MjA5Mjg4NzUxMn0'
    '.RCALy3wpKHGAkmXWcBqEb_QFEUmh6ErdRbfrBmagvtw';
bool firebaseAvailable = false;

/// URL ی n8n کراوەکەت بنووسەرەوە — بۆ ناردنی OTP ئیمێڵ
const String n8nOtpLoginWebhook = 'https://email.proxopages.com/webhook/send_otp';

/// URL ی n8n کراوەکەت بنووسەرەوە — بۆ ئاگاداری تۆمارکردن / چوونەژوورەوە
const String n8nWebhookUrl = 'https://email.proxopages.com/webhook/send_otp';

// ─────────────────────────────────────────────────────────────────────────────
// Wevlix — OTPـی واتساپ (ناردن / دۆخ / پشتڕاستکردنەوە)
// ─────────────────────────────────────────────────────────────────────────────
// ڕێڕەوەکان لە وۆرکفلۆی n8nـەوە هاتوون:
//   POST  wevlix/otp/send    { phone, purpose?, clientMessageId?, locale? }
//         → { success, messageId, phone, status, expiresAt, reused }
//   GET   wevlix/otp/status  ?messageId=…
//   POST  wevlix/otp/verify  { phone, code }
//         → ئەنجامی `rpc/verify_otp_whatsapp(p_phone, p_code)`
//
// ⚠ هەمان هۆستی OTPـی ئیمەیڵ دانراوە چونکە هەردوو وۆرکفلۆکە لەسەر یەک
// نموونەی n8nـن. ئەگەر Wevlix لەسەر هۆستێکی جیاوازە، تەنها ئەم سێ دێڕە
// بگۆڕە.
const String _n8nBase = 'https://email.proxopages.com/webhook';
const String wevlixOtpSendUrl   = '$_n8nBase/wevlix/otp/send';
const String wevlixOtpStatusUrl = '$_n8nBase/wevlix/otp/status';
const String wevlixOtpVerifyUrl = '$_n8nBase/wevlix/otp/verify';

// ─────────────────────────────────────────────────────────────────────────────
// Navigator key
// ─────────────────────────────────────────────────────────────────────────────

final navigatorKey = GlobalKey<NavigatorState>();

/// تابی چالاکی `MainShell` — بۆ ئەو پەڕانەی لە دەرەوەی شێڵەوە دەکرێنەوە
/// (وەک مێژووی مامەڵەکان) و هەمان Bottom Nav پیشان دەدەن.
final ValueNotifier<int> mainShellTab = ValueNotifier<int>(0);

/// داواکاری گۆڕینی تاب لە دەرەوەی شێڵەوە. `MainShell` گوێی لێ دەگرێت،
/// هەمان `_onTabTap` بەکاردەهێنێت (بۆیە ڕەفتاری تابەکان وەک خۆیەتی)،
/// و پاشان دەیکاتەوە `null`.
final ValueNotifier<int?> mainShellTabRequest = ValueNotifier<int?>(null);

// ─────────────────────────────────────────────────────────────────────────────
// Supabase client
// ─────────────────────────────────────────────────────────────────────────────

late final SupabaseClient supabase;

// ─────────────────────────────────────────────────────────────────────────────
// main()
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PERF: gesture resampling بۆ scroll ی جوانتر

  await ProxoLocale.load();

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
  supabase = Supabase.instance.client;

  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    debugPrint('[Firebase] init failed: $e\n$st');
    firebaseAvailable = false;
  }

  if (firebaseAvailable) {
    try {
      await NotificationService.instance.init(navigatorKey: navigatorKey);
    } catch (e, st) {
      debugPrint('[NotificationService] init failed: $e\n$st');
    }
  }

  runApp(const ProxoApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// ProxoApp
// ─────────────────────────────────────────────────────────────────────────────

class ProxoApp extends StatelessWidget {
  const ProxoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: ProxoLocale.current,
      // Rebuilds when the app language changes; the value itself is consumed
      // by ProxoLocaleScope inside, not by MaterialApp.
      builder: (context, locale, __) => _buildApp(locale),
    );
  }

  Widget _buildApp(Locale locale) {
    final Locale frameworkLocale = locale.languageCode == 'ckb'
        ? ProxoLocale.arabic
        : locale;
    return MaterialApp(
      title: 'Proxo',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: frameworkLocale,
      supportedLocales: const <Locale>[
        ProxoLocale.arabic,
        ProxoLocale.english,
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Flutter's stock delegates do not include ckb. Map Sorani to Arabic for
      // framework-owned labels/date pickers while ProxoLocaleScope keeps the
      // app's actual ckb/ar choice and correct RTL direction.
      builder: (context, child) => ProxoLocaleScope(
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        fontFamily: kAppFont,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        // Shared Auth surface; screens that omit an explicit background still
        // use the same white canvas.
        scaffoldBackgroundColor: AuthTokens.pageBackground,
        textTheme: const TextTheme().apply(
          fontFamily: kAppFont,
          decoration: TextDecoration.none,
        ),
      ),
      home: const SplashScreen(nextScreen: _AuthGate()),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // هەموو ڕێڕەوە ناودارەکان `ProxoPageRoute`ن، بۆیە ماوەی هاتن و
      // چوونیان هەمان ئەوەیە کە ڕێڕەوە دەستکردەکان هەیانە (250ms).
      // `MaterialPageRoute` خۆی 300msـە و `reverseTransitionDuration`ی
      // جیاوازی نییە — ئیشارەتی سوایپی هەبوو، بەڵام هەستەکەی جیاواز بوو.
      case '/my-ads':
        return ProxoPageRoute<void>(builder: (_) => const AdScreen());
      case '/notifications':
        return ProxoPageRoute<void>(
            builder: (_) => const NotificationsScreen());
      case '/wallet':
        return ProxoPageRoute<void>(builder: (_) => const MainShell());
      case '/profile':
        return ProxoPageRoute<void>(builder: (_) => const ProfileScreen());
      case '/transactions':
        return ProxoPageRoute<void>(builder: (_) => const TxHistoryPage());
      case '/coupons':
        return ProxoPageRoute<void>(builder: (_) => const DiscountCodesPage());
      case '/faq':
        return ProxoPageRoute<void>(builder: (_) => const FaqScreen());
      case '/assets':
        return ProxoPageRoute<void>(builder: (_) => const MainShell());
      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AuthGate
// ─────────────────────────────────────────────────────────────────────────────

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<AuthState>? _authSub;
  String? _lastKnownUserId;

  @override
  void initState() {
    super.initState();
    _lastKnownUserId = supabase.auth.currentUser?.id;
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      if (!mounted) return;
      if (AuthScreen.inOtpFlow) return;
      final event   = data.event;
      final session = data.session;
      if (session != null) _lastKnownUserId = session.user.id;

      if (session != null &&
          (event == AuthChangeEvent.signedIn ||
           event == AuthChangeEvent.tokenRefreshed ||
           event == AuthChangeEvent.userUpdated)) {

        if (firebaseAvailable) {
          NotificationService.instance.saveTokenAfterLogin();
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      } else if (event == AuthChangeEvent.signedOut) {
        final uid = session?.user.id ?? _lastKnownUserId;
        if (uid != null) {
          // fire-and-forget — نابێت ڕێگری لە navigation بکات
          unawaited(supabase.from('pa_activity_log').insert({
            'user_id': uid,
            'action': 'logout',
            'description': 'چوونەدەرەوە لە هەژمار',
          }).catchError((e) {
            debugPrint('[PROXO][ACTIVITY_LOG] $e');
          }));
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    if (session != null) return const MainShell();
    // AuthScreen now opens on its Sign In view by default (_Tab.login /
    // _Step.form) — it is the refactored screen, not a legacy fallback.
    return const AuthScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MainShell
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int  _tabIndex       = 0;
  int  _refreshCounter = 0;

  /// ⚠ `_sidebarOpen` و `_sidebarKey` لابران.
  ///
  /// سایدباڕەکە پێشتر `Stack`ێکی دەستکرد بوو کە بە
  /// `Alignment.centerLeft` بە لێواری **فیزیکیی چەپ**ەوە بەستراوە —
  /// پێچەوانەی ئاراستەی خوێندنەوەی کوردی، و پێچەوانەی خودی پانێڵەکەش، کە
  /// سێبەرەکەی `Offset(-4, 0)`ە واتە بۆ چەپ دەیدات: پانێڵێکی
  /// **ڕاست**ـبەست. هەروەها هیچ ئەنیمەیشنێکی نەبوو (لەناکاو دەردەکەوت)، و
  /// دوگمەی «دواوە»ی سیستەم دەیخست نەک بیدات.
  ///
  /// ئێستا `Scaffold.endDrawer`ی ڕاستەقینەیە، بۆیە سلاید، سکڕیم، ئیشارەتی
  /// سوایپ لە لێوارەوە، فۆکەس‌تڕاپ و داخستن بە دوگمەی دواوە هەموویان
  /// خۆڕاییان دەست دەکەوێت.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openSidebar() => _scaffoldKey.currentState?.openEndDrawer();
  void _closeSidebar() => _scaffoldKey.currentState?.closeEndDrawer();

  // ── Keep-alive tabs ──────────────────────────────────────────────────────
  // Each tab is built once, on its first visit, then kept alive inside the
  // IndexedStack in _buildBody(). Switching BACK to a tab you've already
  // opened is instant — no rebuild, no re-fetch from Supabase, no skeleton
  // flash — because its widget/state was never torn down. A tab you haven't
  // opened yet is a cheap SizedBox.shrink() placeholder until its first tap,
  // so nothing is built or fetched before it's needed.
  final Set<int> _builtTabs = {0};

  // Order of real tabs; slot 2 is the FAB and never owns a screen.
  static const List<int> _tabOrder = [0, 1, 3, 4];

  // ── Tab re-selection refresh ─────────────────────────────────────────────
  // One handle per real tab, handed down to that screen's ProxoRefresh. The
  // shell owns them rather than the screens because the shell is what knows a
  // re-tap happened; a screen has no idea its own tab was pressed again.
  //
  // A handle whose screen hasn't been built yet (not in _builtTabs) is simply
  // unattached, and refresh() no-ops — correct, since an unbuilt tab has
  // nothing to refresh and will fetch on first open anyway.
  final Map<int, ProxoRefreshController> _refreshers = {
    for (final int i in _tabOrder) i: ProxoRefreshController(),
  };

  @override
  void initState() {
    super.initState();
    mainShellTab.value = _tabIndex;
    mainShellTabRequest.addListener(_onExternalTabRequest);
    // FIX: ئاگاداری پاشەکەوتکراو کاتی داخستنی ئەپ — دوای کردنەوەی تەواو navigate بکە
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (firebaseAvailable) {
        NotificationService.instance.navigateFromPending();
      }
    });
  }

  void _onExternalTabRequest() {
    final int? index = mainShellTabRequest.value;
    if (index == null || !mounted) return;
    mainShellTabRequest.value = null;
    unawaited(_onTabTap(index));
  }

  @override
  void dispose() {
    mainShellTabRequest.removeListener(_onExternalTabRequest);
    for (final ProxoRefreshController c in _refreshers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Shared by bottom-nav taps and the sidebar's onNavigate. IndexedStack swaps
  // the visible child in the same frame, matching the supplied reference and
  // avoiding a whole-screen opacity layer during every tab change.
  void _switchTab(int index) {
    if (index == _tabIndex) return;
    setState(() {
      _builtTabs.add(index);
      _tabIndex = index;
    });
    mainShellTab.value = index;
  }

  Future<void> _onTabTap(int index) async {
      // ── Re-tap on the active tab = refresh ───────────────────────────────
      // Fire-and-forget on purpose. Awaiting would hold this handler open for
      // the whole drop + fetch + settle (~1s), and a second tap during that
      // window is already a no-op inside the controller, so there is nothing
      // to serialise.
      if (index == _tabIndex && index != 2) {
        unawaited(_refreshers[index]?.refresh() ?? Future<void>.value());
        return;
      }
      if (index == 2) {
        // ⚠ <String>، نەک <void>: `AdCreateScreen` بە
        // `Navigator.pop(context, 'refresh')` دەگەڕێتەوە، و ئەم
        // ڕیزە بەهاکە بەکاردەهێنێت. `Route<void>` بەهاکە دەگۆڕێت بۆ
        // `void` و بەراوردەکە کۆمپایل نابێت.
        final result = await Navigator.of(context).push(
          ProxoPageRoute<String>(builder: (_) => const AdCreateScreen()),
        );
        // FIX: هەڵە → بگەڕێوە سەرەکی + refresh هەموو بەشەکان
        if (result == 'refresh' && mounted) {
          setState(() {
            _tabIndex = 1;
            _refreshCounter++;
            _builtTabs.add(1);
          });
          mainShellTab.value = 1;
        }
        return;
      }
      _switchTab(index);
    }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          key: ValueKey('home_$_refreshCounter'),
          isActive: _tabIndex == 0,
          refreshController: _refreshers[0],
          onMenuTap:   _openSidebar,
          onCreateTap: () => _onTabTap(2),
          onGoToAds:   () => _onTabTap(1),
          // کوێک ئاکشنەکانی پەڕەی سەرەکی:
          //   ئامرازی پەیوەندی → تابی Tools ی ئێستا (3)
          //   پرسیارە دووبارەکان → شاشەی تایبەتی FAQ، وەک ڕووتێکی پوش‌کراو
          //     (هەمان شێوازی `AdCreateScreen`) — باری خوارەوە و تابەکان
          //     دەستیان لێنەدراوە، و «دواوە» دەگەڕێتەوە سەر پەڕەی سەرەکی.
          onToolsTap:  () => _onTabTap(3),
          onCreatePageTap: () => Navigator.of(context).push(
            ProxoPageRoute<void>(builder: (_) => const ToolsScreen(initialCreate: true))),
          onFaqTap:    () => Navigator.of(context).push(
                ProxoPageRoute<void>(builder: (_) => const FaqScreen()),
              ),
        );
      case 1:
        return RepaintBoundary(
          key: ValueKey('ads_$_refreshCounter'),
          child: AdScreen(
            key: ValueKey('ads_$_refreshCounter'),
            refreshController: _refreshers[1],
            // تابەکان لە IndexedStackدا زیندوو دەمێننەوە، بۆیە AdScreen
            // خۆی نازانێت کەی گەڕاوەتەوە پێش چاو. ئەمە پێی دەڵێت — و ئەو
            // سکێلیتۆنی کردنەوە نیشان دەدات پێش کارتەکان.
            isActive: _tabIndex == 1,
            // Same closure HomeScreen gets above — one sidebar, one owner.
            onMenuTap: _openSidebar,
          ),
        );
      case 3:
        return RepaintBoundary(
          key: const ValueKey('tools'),
          child: ToolsScreen(isActive: _tabIndex == 3, refreshController: _refreshers[3]),
        );
      case 4:
        return RepaintBoundary(
          key: const ValueKey('profile'),
          child: ProfileScreen(
            onBottomNavTap: _onTabTap,
            refreshController: _refreshers[4],
          ),
        );
      default:
        return HomeScreen(
          key: ValueKey('home_def_$_refreshCounter'),
          isActive: _tabIndex == 0,
          onMenuTap:   _openSidebar,
          onCreateTap: () => _onTabTap(2),
          onGoToAds:   () => _onTabTap(1),
          onToolsTap:  () => _onTabTap(3),
          onCreatePageTap: () => Navigator.of(context).push(
            ProxoPageRoute<void>(builder: (_) => const ToolsScreen(initialCreate: true))),
          onFaqTap:    () => Navigator.of(context).push(
                ProxoPageRoute<void>(builder: (_) => const FaqScreen()),
              ),
        );
    }
  }

  Widget _buildBody() {
    // IndexedStack lays every built tab out but paints/hit-tests only the
    // active one — the mechanism that makes revisiting a tab instant.
    return IndexedStack(
      index: _tabIndex,
      children: [
        _builtTabs.contains(0) ? _buildTab(0) : const SizedBox.shrink(),
        _builtTabs.contains(1) ? _buildTab(1) : const SizedBox.shrink(),
        const SizedBox.shrink(), // slot 2 = FAB, never a body tab
        _builtTabs.contains(3) ? _buildTab(3) : const SizedBox.shrink(),
        _builtTabs.contains(4) ? _buildTab(4) : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // ── بۆچی `Directionality.ltr` تەنها لە دەوری ئەم `Scaffold`ـەدا ──
          // `Scaffold` لای دراوەرەکان بە ئاراستەی دەقەوە چارەسەر دەکات:
          // `drawer:` = لای *start*، `endDrawer:` = لای *end*. لەناو RTLدا
          // ئەوە پێچەوانە دەبێتەوە — واتە `endDrawer` دەکەوێتە لای **چەپ**.
          //
          // ئەپەکە بە گشتی RTLـە، بۆیە تەنها ئەم `Scaffold`ـە دەخرێتە ناو
          // LTRـەوە تا «end» ببێت بە لێواری فیزیکیی ڕاست، و پاشان `body` و
          // خودی دراوەرەکە دیسان دەکرێنەوە بۆ RTL. هیچ شتێکی تر ئاراستەی
          // ناگۆڕێت: `ProxoBottomNav` خۆی LTRی خۆی دادەنێت، و هەر تابێک
          // `Directionality`ی خۆی هەیە.
          //
          // ⚠ ڕێگای جێگرەوە: `drawer:` بەبێ هیچ لفەیەکی LTR — لەناو RTLدا
          // ئەویش دەکەوێتە لای ڕاست. ئەوە کورتترە، بەڵام `endDrawer` بوو
          // ئەوەی داواکراوە، و ئەمە دەقاودەق ئەو ڕەفتارە دەداتەوە.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.bg,
            endDrawer: Directionality(
              textDirection: TextDirection.rtl,
              child: ProxoSidebar(
                onClose: _closeSidebar,
                onNavigate: (page) {
                  _closeSidebar();
                  if (page == 'ads')       _switchTab(1);
                  if (page == 'tools')     _switchTab(3);
                  if (page == 'tutorials') _switchTab(4);
                },
              ),
            ),
            // ⚠ `Drawer` نییە بەڵکو ڕاستەوخۆ `ProxoSidebar`ە: پانێڵەکە
            // خۆی `Container(width: …)` + `Material` + سێبەری خۆی هەیە،
            // بۆیە لفەکردنی بە `Drawer` دوو ڕوو و دوو سێبەری لەسەر یەک
            // دادەنا. `DrawerController` هیچ پانییەکی ناسەپێنێت.
            // The kept-alive IndexedStack switches immediately. Motion stays
            // in the tiny bottom-nav indicator and press capsule, exactly like
            // the supplied reference; no full-screen opacity/saveLayer pass.
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: _buildBody(),
            ),
            bottomNavigationBar: ProxoBottomNav(
              currentIndex: _tabIndex,
              onTap: _onTabTap,
            ),
            ),
          ),
          // ── No Internet Banner ──────────────────────────────────────────
          const Positioned(
            top: 0, left: 0, right: 0,
            child: ProxoNoInternetBanner(),
          ),
        ],
      ),
    );
  }
}
