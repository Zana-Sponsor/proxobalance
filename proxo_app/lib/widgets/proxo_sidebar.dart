import '../models/receipt_pricing.dart';
import '../screens/ad_detail_screen.dart' show adDetailsRoute;
// lib/widgets/proxo_sidebar.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/proxo_ui.dart';
import 'auth/auth_design.dart' show AuthTokens;
import '../screens/faq_screen.dart' show FaqScreen;
import '../theme/app_theme.dart';
import '../main.dart' show supabase, kIqdRate, navigatorKey;
import '../l10n/tx_strings.dart';
import '../theme/app_locale.dart';
import '../screens/transaction_detail_screen.dart'
    show TransactionDetailScreen, TxReceiptData, TxReceiptKind;
import 'receipt/receipt_kit.dart';
import 'receipt/tx_history_layout.dart';
import 'tasks_page.dart';
import 'levels_page.dart';
import '../screens/profile_screen.dart' show ProfileScreen;
import 'proxo_error_ui.dart';
import '../screens/auth_screen.dart' show AuthScreen;
import '../screens/deposit_screen.dart' show DepositScreen;
import 'package:proxo_app/widgets/proxo_text.dart';

part 'tx_history_page.dart';
part 'voucher_page.dart';
// ⚠ `part 'deposit_sheet.dart';` لابرا. ئەو فایلە **لە پڕۆژەکەدا نەبوو**،
// بۆیە ئەم فایلە هەر کۆمپایل نەدەبوو: ڕاگەیاندنی `part`ێک بۆ فایلێکی
// نەبوو هەڵەیەکی کۆمپایلە، و `_DepositSheet` هەرگیز پێناسە نەکرابوو.
// جێگرەوەکەی `screens/deposit_screen.dart`ـە — کە بە ئەنقەست بۆ ئەمە
// نووسرابوو (بڕوانە سەرەتای ئەو فایلە) بەڵام هیچ شوێنێک بانگ نەدەکرا.
part 'discount_codes_page.dart';

const _cDark = AppColors.ink;
const _cDark2 = Color(0xFF2E3A50);
const _cMt = Color(0xFF8A95A8);
const _cBg = Color(0xFFF4F6FB);
const _cB1 = AppColors.line;
const _cB2 = Color(0xFFD0D4DE);
const _cWhite = Color(0xFFFFFFFF);
const _cBlue = AppColors.accent;
const _cGreen = Color(0xFF16A34A);
const _cRed = Color(0xFFDC2626);
const _cYellow = Color(0xFFD97706);

const TextStyle _kBase =
    TextStyle(fontFamily: kAppFont, decoration: TextDecoration.none);
const Color _kIconBg = Color(0xFFF6F6F8);
const Color _kTextDark = Color(0xFF000000);
const Color _kTextMuted = Color(0xFF454C63);
const Color _kGlyph = AppColors.ink;
const Color _kChevron = Color(0xFF3E4260);
const Color _kActiveBg = Color(0xFFF5F8FE);
const Color _kActiveTile = Color(0xFFF0F3FC);
const Color _kActiveBlue = Color(0xFF0B34F6);
const Color _kAccentBar = Color(0xFF0D4CF5);
const Color _kBadgeBg = Color(0xFFEBE5FE);
const Color _kBadgeText = Color(0xFF5426F8);
const Color _kDivider = Color(0xFFF0F1F4);
const Color _kInviteBg = Color(0xFFFFFFFF);
const Color _kInviteBorder = Color(0xFFF1F0F7);
const Color _kGiftTile = Color(0xFFF1F2F8);
const Color _kLogoutBg = Color(0xFFF7F7F9);
const Color _kLogoutRed = Color(0xFFE81F27);
const Color _kLevelDot = Color(0xFF23E37F);
const Color _kCardTop = Color(0xFF8792FB);
const Color _kAvatarTop = Color(0xFF2E6BFA);
const Color _kAvatarBottom = Color(0xFF5B15FB);

const Color _navBg = Color(0xFFFFFFFF);
const Color _navPrimary = AuthTokens.primary;
const Color _navSelected = Color(0xFFEEF4FF);
const Color _navText = AppColors.ink;
const Color _navMuted = AppColors.inkMuted;
const Color _navDivider = Color(0xFFEEF2F7);
const Color _navSurface = Color(0xFFF6F8FC);
const Color _navAvatarBg = Color(0xFFE6EDFE);
const Color _navIconInk = Color(0xFF2C3648); // ⚠ بوو #374151 — تۆزێک تۆخکرا.

// ── خانەی پشتی ئایکۆن ───────────────────────────────────────────────────
//
// ⚠ پێشتر ڕووی ئەم خانەیە `_navSurface` (#F6F8FC) بوو — کە لە سپیی
//   دراوەری خۆیەوە بە چاو جیا نەدەکرایەوە. واتە خانەیەک هەبوو بەڵام
//   هیچی نەدەکرد: ئایکۆنەکە لەسەر سپییەکی ڕووت دەسووڕایەوە.
//
//   لەگەڵیدا لە دۆخی هەڵبژێردراودا بە تەواوی `transparent` دەبوو، بۆیە
//   ڕیزی چالاک تاقە ڕیز بوو کە ئایکۆنەکەی هیچ پشتێکی نەبوو.
//
// ئێستا: ڕوویەکی تۆختر + هێڵێکی مووی سنوور. خانەکە شێوەی خۆی هەیە،
// ئایکۆنەکەش لەسەری دەردەکەوێت.
const Color _navIconTileBg = Color(0xFFEFF3FA);
const Color _navIconTileLine = Color(0xFFE1E8F3);
const Color _navIconTileBgSel = Color(0xFFDCE8FF);
const Color _navLogoutTileBg = Color(0xFFFDEAEA);
const Color _navLogoutTileLine = Color(0xFFF7D5D5);
const double _navIconTileLineW = 1.0;
const Color _navLogoutBg = Color(0xFFFEF4F4);
const Color _navLogoutInk = Color(0xFFEF4444);
const Color _navPanelShadow = Color(0x0F101828);

const Color _navLiftShadow = Color(0x141B2A4A);
const double _navLift = 0.0;

const double _navMaxWidth = 304.0;
// ⚠ ڕێژەی ئایکۆن بۆ خانە = 22/40 ≈ ٥٥٪. هەردووکیان بە هەمان `sw`
//   دەگۆڕدرێن، بۆیە ئەم ڕێژەیە لەسەر هەموو شاشەیەک دەپارێزرێت و
//   ئایکۆنەکە هەرگیز نە تەنگ دەبێتەوە نە دەبڕدرێت.
const double _navDividerThickness = 1.0;
const double _navRevealSlide = 0.06;

class _Ico {
  const _Ico._();

  static const String home = SolarIcons.home2;
  // ⚠ `megaphone` لە solar_iconkit ـی ئێستادا نییە.
  static const String ads = SolarIcons.target;
  static const String history = SolarIcons.history;
  static const String discount = SolarIcons.tag;
  static const String balance = SolarIcons.wallet;
  static const String notifications = SolarIcons.bell;
  static const String settings = SolarIcons.settings;
  static const String help = SolarIcons.questionCircle;

  static const String avatar = SolarIcons.user;
  static const String logout = SolarIcons.logout;
}

class ProxoSidebar extends StatefulWidget {
  const ProxoSidebar(
      {super.key,
      this.onClose,
      this.onNavigate,
      this.selectedRoute = 'home',
      this.client});

  final VoidCallback? onClose;
  final String selectedRoute;
  final SupabaseClient? client;

  /// ⚠ بوو `void Function(Widget page)?`. `MainShell` بەرامبەری
  /// دەکردەوە لەگەڵ `'ads'`, `'tools'`, `'tutorials'` — واتە بەراوردی
  /// `Widget == String`، کە **هەمیشە** `false`ە. بۆیە هیچ کامێک لەو
  /// سێ ڕێڕەوە هەرگیز کاری نەدەکرد و ئەرۆرێکیش نەدەدا.
  final void Function(String route)? onNavigate;

  @override
  State<ProxoSidebar> createState() => _ProxoSidebarState();
}

class _ProxoSidebarState extends State<ProxoSidebar>
    with SingleTickerProviderStateMixin {
  SupabaseClient get _client => widget.client ?? supabase;
  bool _navigating = false;
  bool _signingOut = false;
  String? _avatarUrl;
  String _userName = '';
  String _userEmail = '';
  bool _loading = true;

  late final AnimationController _intro;
  late final List<Animation<double>> _revealFade;
  late final List<Animation<Offset>> _revealSlide;
  final ScrollController _menuScroll = ScrollController();

  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _buildRevealAnimations();
    _intro.forward();
    _load();
  }

  @override
  void dispose() {
    _intro.dispose();
    _menuScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final authName = (user.userMetadata?['full_name'] ?? '').toString().trim();
    _userName = authName.isEmpty ? 'بەکارهێنەر' : authName;
    _userEmail = (user.email ?? '').endsWith('@phone.proxopages.com')
        ? (user.phone ?? '')
        : (user.email ?? '');
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final name = profile?['full_name']?.toString().trim() ?? '';
      final email = profile?['email']?.toString().trim() ?? _userEmail;
      final avatar = profile?['avatar_url']?.toString().trim() ?? '';
      setState(() {
        if (name.isNotEmpty) _userName = name;
        if (!email.endsWith('@phone.proxopages.com')) _userEmail = email;
        _avatarUrl = avatar.isEmpty ? null : avatar;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    // Optional badge failure must never hide the successfully loaded identity.
    try {
      final rows = await _client
          .from('pa_notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (mounted) setState(() => _unreadNotifs = rows.length);
    } catch (_) {}
  }

  /// ⚠ پێشتر دوای `onClose` یەکێکی تریش `Navigator.pop` دەکرد.
  ///
  /// کاتێک سایدباڕەکە `Stack`ێکی دەستکرد بوو ئەوە پێویست بوو. ئێستا
  /// `Scaffold.endDrawer`ـە: `onClose` (= `closeEndDrawer`) خۆی
  /// دایدەخات، و ئەو `pop`ـە **ڕووتی ژێرەوە** لادەبات — واتە
  /// `MainShell` خۆی. ئەوە هۆکاری «بەستنەوە» و ونبوونی ستاکی
  /// ڕێنیشاندەری بوو.
  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Scaffold.maybeOf(context)?.closeEndDrawer();
    }
  }

  void _openTab(String route) {
    if (_navigating || _signingOut) return;
    _navigating = true;
    widget.onNavigate?.call(route);
    _close();
  }

  /// ماوەی ئەنیمەیشنی داخستنی دراوەر — `_kBaseSettleMs`ی Flutter.
  static const Duration _closeAnim = Duration(milliseconds: 250);

  /// ⚠ چۆن ڕێنیشاندەر لە سایدباڕەوە کار دەکات.
  ///
  /// `DrawerController` منداڵەکەی **بە تەواوی لە دارەکە دەردەهێنێت**
  /// کاتێک داخراوە (`build` تەنها `SizedBox`ـێک دەگەڕێنێتەوە). بۆیە هەر
  /// کۆدێک کە دوای داخستن `Navigator.of(context)` بەکاربهێنێت، لەسەر
  /// `BuildContext`ێکی مردوو کار دەکات — هیچ ڕوونادات و هیچ ئەرۆرێکیش
  /// نییە. ئەمە هۆکاری سەرەکیی «کردارە کارنەکەرەکان» بوو.
  ///
  /// چارەسەرەکە: ڕێنیشاندەری ڕەگ **پێش** داخستن بگرە و پاشان ئەوە
  /// بەکاربهێنە، نەک `context`.
  Future<void> _go(Widget Function() page, {bool wait = true}) async {
    if (_navigating || _signingOut) return;
    _navigating = true;
    final nav =
        navigatorKey.currentState ?? Navigator.of(context, rootNavigator: true);
    _close();
    if (wait) await Future<void>.delayed(_closeAnim);
    if (nav.mounted) {
      await nav.push(ProxoPageRoute<void>(builder: (_) => page()));
    }
    if (mounted) setState(() => _navigating = false);
  }

  Future<void> _openTasks() => _go(() => const TasksPage());

  Future<void> _openLevels() => _go(() => const LevelsPage());

  void _openPromoCodes() => _close();

  Future<void> _openProfile() => _go(() => const ProfileScreen());

  /// «باڵانس و پارەدان» → `DepositScreen`.
  ///
  /// ⚠ پێشتر `showModalBottomSheet`ێکی `_DepositSheet` بوو — کلاسێک کە
  /// لە هیچ شوێنێکی پڕۆژەکەدا پێناسە نەکرابوو (بڕوانە تێبینی `part`ـەکەی
  /// سەرەوە). ئێستا ڕاستەوخۆ دەچێتە شاشەی تەواوی داخڵکردنی باڵانس.
  ///
  /// بە `_go` دەڕوات، نەک بە کۆدێکی جیا: هەمان ڕێگەی هەموو ڕیزەکانی تری
  /// سایدباڕ — ڕێنیشاندەری ڕەگ **پێش** داخستن دەگیرێت، چاوەڕوانی
  /// ئەنیمەیشنی داخستن دەکرێت، پاشان `push`. ئەگەر `context`ـی دراوەرەکە
  /// بەکاربهێنرێت پاش داخستن، `BuildContext`ـەکە مردووە و هیچ ڕوونادات.
  Future<void> _openDeposit() => _go(() => const DepositScreen());

  Future<void> _openTxHistory() => _go(() => const TxHistoryPage());

  /// ⚠ پێشتر تەنها `signOut()` بوو و هیچ ڕێنیشاندەرێکی نەدەکرد. ئەوە
  /// پشتی بە گوێگرێکی دۆخی auth دەبەست بۆ گەڕاندنەوە بۆ شاشەی
  /// چوونەژوورەوە؛ ئەگەر ئەو گوێگرە نەبێت یان بەدواوە بێت، بەکارهێنەر
  /// لەسەر `MainShell`ێکی بێ سێشن دەمێنێتەوە.
  ///
  /// ئێستا ستاکەکە بە ڕوونی دەسڕدرێتەوە: هیچ ڕووتێکی پێشوو نامێنێتەوە
  /// کە بتوانرێت بگەڕێتەوە بۆی بە دوگمەی «دواوە».
  Future<void> _signOut() async {
    if (_signingOut || _navigating) return;
    setState(() => _signingOut = true);
    final nav = navigatorKey.currentState ?? Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _client.auth.signOut();
    } catch (_) {
      if (messenger.mounted && _client.auth.currentSession != null) {
        messenger.showSnackBar(const SnackBar(content: ProxoText(
          'دەرچوون سەرکەوتوو نەبوو. تکایە دووبارە هەوڵ بدەرەوە.')));
      }
    } finally {
      // Server revocation may fail after the SDK has already removed the
      // local session. Route by actual local auth state, not HTTP success.
      if (nav.mounted && _client.auth.currentSession == null) {
        nav.pushAndRemoveUntil(
          ProxoPageRoute<void>(builder: (_) => const AuthScreen()), (_) => false);
      }
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _openDiscountCodes() => _go(() => const DiscountCodesPage());

  Future<void> _openNotifications() async {
    if (_navigating || _signingOut) return;
    _navigating = true;
    final nav =
        navigatorKey.currentState ?? Navigator.of(context, rootNavigator: true);
    _close();
    await Future<void>.delayed(_closeAnim);
    if (nav.mounted) await nav.pushNamed('/notifications');
    if (mounted) setState(() => _navigating = false);
  }

  static String _fmtNum(double v) => v
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double panelWidth = math.min(screenWidth - 48, _navMaxWidth);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: panelWidth,
        decoration: const BoxDecoration(
          color: _navBg,
          boxShadow: [
            BoxShadow(
                color: _navPanelShadow, blurRadius: 20, offset: Offset(-4, 0)),
          ],
        ),
        child: Material(
          color: _navBg,
          child: SafeArea(
            left: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final _NavMetrics m = _NavMetrics.resolve(
                  panelWidth: panelWidth,
                  viewportHeight: constraints.maxHeight,
                );
                return RepaintBoundary(
                  child: ScrollConfiguration(
                    behavior: const _NavScrollBehavior(),
                    child: _buildRelaxed(m),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelaxed(_NavMetrics m) {
    return SingleChildScrollView(
      controller: _menuScroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(m.gutter, m.topGap, m.gutter, m.bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(child: ProxoText('مێنیو', style: ProxoUi.title)),
            IconButton(
                tooltip: 'داخستن',
                onPressed: _close,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const SolarIcon(SolarIcons.closeCircle,
                    size: 20, color: AuthTokens.inkMuted)),
          ]),
          const SizedBox(height: 8),
          _reveal(0, _buildAccountCard(m)),
          SizedBox(height: m.cardToMenu),
          ..._menuRows(m),
          SizedBox(height: m.menuToDivider),
          _reveal(9, _buildDivider()),
          SizedBox(height: m.dividerToLogout),
          _reveal(10, _buildLogoutTile(m)),
        ],
      ),
    );
  }

  Widget _buildDivider() => const SizedBox(
        height: _navDividerThickness,
        child: DecoratedBox(decoration: BoxDecoration(color: _navDivider)),
      );

  List<Widget> _menuRows(_NavMetrics m) => [
        _reveal(
            1,
            _navItem(m,
                icon: _Ico.home,
                label: 'سەرەکی',
                onTap: () => _openTab('home'),
                selected: widget.selectedRoute == 'home')),
        _reveal(
            2,
            _navItem(m,
                icon: _Ico.ads,
                // ⚠ بوو `_close` — تەنها دراوەرەکەی دادەخست و هیچی تر.
                label: 'ڕیکلامەکان',
                onTap: () => _openTab('ads'),
                selected: widget.selectedRoute == 'ads')),
        _reveal(
            3,
            _navItem(m,
                icon: _Ico.history,
                label: 'مێژووی مامەڵەکان',
                onTap: _openTxHistory)),
        _reveal(
            4,
            _navItem(m,
                icon: _Ico.discount,
                label: 'کۆدی داشکاندن',
                onTap: _openDiscountCodes)),
        // ⚠ ڕیزی «باوچەرەکان» لابرا. `VoucherPage` خۆی هێشتا ماوە
        //   (`part 'voucher_page.dart'`)، بۆیە ئەگەر ڕۆژێک ویستت
        //   بیگەڕێنیتەوە تەنها ڕیزێکی نوێ لێرە زیاد بکە.
        _reveal(
            5,
            _navItem(m,
                icon: _Ico.balance,
                // ⚠ بوو `_openTxHistory` — دەیبرد بۆ مێژووی مامەڵەکان، کە
                // ڕیزێکی سەربەخۆی خۆی هەیە لە سەرەوە. `_openDeposit` هەبوو
                // بەڵام هیچ شوێنێک بانگ نەدەکرا.
                label: 'باڵانس و پارەدان',
                onTap: _openDeposit)),
        _reveal(
            6,
            _navItem(m,
                icon: _Ico.notifications,
                label: 'ئاگادارییەکان',
                onTap: _openNotifications,
                badge: _unreadNotifs)),
        _reveal(
            7,
            _navItem(m,
                icon: _Ico.settings,
                label: 'ڕێکخستنەکان',
                selected: widget.selectedRoute == 'profile',
                onTap: _openProfile)),
        _reveal(
            8,
            _navItem(m,
                icon: _Ico.help,
                label: 'یارمەتی و پشتگیری',
                onTap: () => _go(() => const FaqScreen()))),
      ];

  static const int _revealCount = 11; // ⚠ بوو ١٢ — ڕیزێک کەم بووەوە.

  void _buildRevealAnimations() {
    Interval windowFor(int i) {
      final double begin = math.min(i * 0.038, 0.55);
      return Interval(begin, math.min(begin + 0.45, 1.0),
          curve: Curves.easeOutCubic);
    }

    _revealFade = List<Animation<double>>.generate(
        _revealCount, (i) => _intro.drive(CurveTween(curve: windowFor(i))));
    _revealSlide = List<Animation<Offset>>.generate(
        _revealCount,
        (i) => _intro.drive(
              Tween<Offset>(
                begin: const Offset(_navRevealSlide, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: windowFor(i))),
            ));
  }

  Widget _reveal(int index, Widget child) => FadeTransition(
        opacity: _revealFade[index],
        child: SlideTransition(position: _revealSlide[index], child: child),
      );

  Widget _buildAccountCard(_NavMetrics m) {
    final String name =
        _userName.isNotEmpty ? _userName : (_loading ? 'بارکردن…' : '—');

    // ⚠ ئەم کارتە **دەستلێدانی نییە**. پێشتر `InkWell(onTap: _openProfile)`
    //   بوو، بۆیە هەر کلیکێک لەسەر ناو یان ئیمێڵ دەیبرد بۆ شاشەی پڕۆفایل.
    //   ئێستا تەنها زانیارییە.
    //
    //   لەگەڵیدا چیڤرۆنەکەی لای چەپیش لابرا — ئەو ئامادەگییەکی دیدارییە
    //   کە دەڵێت «کلیکم لێبکە»، و مانەوەی لەسەر شتێکی ناکلیکی
    //   خەڵەتێنەرە.
    //
    //   بۆ چوونە پڕۆفایل ڕیزی «ڕێکخستنەکان» هەیە، کە هەر `_openProfile`
    //   بانگ دەکات.
    return Material(
      color: _navSurface,
      elevation: _navLift,
      shadowColor: _navLiftShadow,
      borderRadius: BorderRadius.circular(m.radius),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: m.cardHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: m.cardPadding, vertical: m.cardPadV),
          child: Row(children: [
            Container(
              width: m.avatar,
              height: m.avatar,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: _navAvatarBg),
              child: ClipOval(
                  child: _avatarUrl == null
                      ? SolarIcon(_Ico.avatar,
                          size: m.avatarGlyph, color: _navPrimary)
                      : Image.network(_avatarUrl!,
                          width: m.avatar,
                          height: m.avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => SolarIcon(_Ico.avatar,
                              size: m.avatarGlyph, color: _navPrimary))),
            ),
            SizedBox(width: m.avatarGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProxoText(name,
                      style: _kBase.copyWith(
                          fontSize: m.nameSize,
                          fontWeight: FontWeight.w600,
                          color: _navText,
                          height: 1.25,
                          letterSpacing: -0.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: m.nameToEmail),
                  ProxoText(_userEmail.isEmpty ? '—' : _userEmail,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      style: _kBase.copyWith(
                          fontSize: m.emailSize,
                          fontWeight: FontWeight.w400,
                          color: _navMuted,
                          height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(
    _NavMetrics m, {
    /// ناوی ئایکۆنی Solar — بڕوانە `_Ico`.
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    int badge = 0,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: m.rowGap),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? _navSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(m.radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(m.radius),
            splashColor: _navPrimary.withOpacity(0.08),
            highlightColor: _navPrimary.withOpacity(0.05),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: m.rowHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: m.rowInset, vertical: m.rowPadV),
                child: Row(children: [
                  Container(
                    width: m.iconTile,
                    height: m.iconTile,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? _navIconTileBgSel : _navIconTileBg,
                      borderRadius: BorderRadius.circular(m.iconTileRadius),
                      border: Border.all(
                        color: selected ? _navIconTileBgSel : _navIconTileLine,
                        width: _navIconTileLineW,
                      ),
                    ),
                    child: SolarIcon(
                      icon,
                      style: SolarIconStyle.linear,
                      size: m.glyph,
                      color: selected ? _navPrimary : _navIconInk,
                    ),
                  ),
                  SizedBox(width: m.tileGap),
                  Expanded(
                    child: ProxoText(label,
                        style: _kBase.copyWith(
                            fontSize: m.labelSize,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? _navPrimary : _navText,
                            height: 1.2,
                            letterSpacing: -0.05),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (badge > 0) ...[
                    SizedBox(width: m.chevronGap),
                    _buildBadge(m, badge),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(_NavMetrics m, int count) => Semantics(
        label: '$count نەخوێندراوە',
        excludeSemantics: true,
        child: Container(
          alignment: Alignment.center,
          constraints:
              BoxConstraints(minWidth: m.badgeSize, minHeight: m.badgeSize),
          padding: EdgeInsets.symmetric(horizontal: m.badgeSize * 0.3),
          decoration: BoxDecoration(
              color: _navPrimary,
              borderRadius: BorderRadius.circular(m.badgeSize)),
          child: ProxoText(count > 99 ? '+99' : '$count',
              maxLines: 1,
              style: _kBase.copyWith(
                  fontSize: m.badgeTextSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0)),
        ),
      );

  Widget _buildLogoutTile(_NavMetrics m) {
    return Semantics(
      button: true,
      child: Material(
        color: _navLogoutBg,
        elevation: _navLift,
        shadowColor: _navLiftShadow,
        borderRadius: BorderRadius.circular(m.radius),
        child: InkWell(
          onTap: _signingOut ? null : _signOut,
          borderRadius: BorderRadius.circular(m.radius),
          splashColor: _navLogoutInk.withOpacity(0.10),
          highlightColor: _navLogoutInk.withOpacity(0.06),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: m.logoutHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: m.rowInset, vertical: m.logoutPadV),
              child: Row(children: [
                Container(
                  width: m.iconTile,
                  height: m.iconTile,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _navLogoutTileBg,
                    borderRadius: BorderRadius.circular(m.iconTileRadius),
                    border: Border.all(
                      color: _navLogoutTileLine,
                      width: _navIconTileLineW,
                    ),
                  ),
                  child: SolarIcon(
                    _Ico.logout,
                    style: SolarIconStyle.linear,
                    size: m.glyph,
                    color: _navLogoutInk,
                  ),
                ),
                SizedBox(width: m.tileGap),
                Expanded(
                  child: ProxoText(_signingOut ? 'چاوەڕێبە…' : 'چوونەدەرەوە',
                      style: _kBase.copyWith(
                          fontSize: m.labelSize,
                          fontWeight: FontWeight.w600,
                          color: _navLogoutInk,
                          height: 1.2,
                          letterSpacing: -0.05),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavMetrics {
  const _NavMetrics._({
    required this.gutter,
    required this.topGap,
    required this.bottomGap,
    required this.cardToMenu,
    required this.menuToDivider,
    required this.dividerToLogout,
    required this.radius,
    required this.cardHeight,
    required this.cardPadding,
    required this.cardPadV,
    required this.avatar,
    required this.avatarGlyph,
    required this.avatarGap,
    required this.nameSize,
    required this.emailSize,
    required this.nameToEmail,
    required this.chevron,
    required this.chevronGap,
    required this.rowHeight,
    required this.rowGap,
    required this.rowInset,
    required this.rowPadV,
    required this.logoutPadV,
    required this.iconTile,
    required this.iconTileRadius,
    required this.glyph,
    required this.tileGap,
    required this.labelSize,
    required this.badgeSize,
    required this.badgeTextSize,
    required this.logoutHeight,
    required this.scrolls,
  });

  final double gutter, topGap, bottomGap, cardToMenu, menuToDivider;
  final double dividerToLogout, radius, cardHeight, cardPadding, cardPadV;
  final double avatar, avatarGlyph, avatarGap, nameSize, emailSize, nameToEmail;
  final double chevron, chevronGap, rowHeight, rowGap, rowInset, rowPadV;
  final double logoutPadV, iconTile, iconTileRadius, glyph, tileGap, labelSize;
  final double badgeSize, badgeTextSize, logoutHeight;
  final bool scrolls;

  factory _NavMetrics.resolve({
    required double panelWidth,
    required double viewportHeight,
  }) => const _NavMetrics._(
    gutter: 16, topGap: 8, bottomGap: 24,
    cardToMenu: 16, menuToDivider: 12, dividerToLogout: 12,
    radius: 16, cardHeight: 80, cardPadding: 12, cardPadV: 12,
    avatar: 48, avatarGlyph: 24, avatarGap: 12,
    nameSize: 14, emailSize: 12, nameToEmail: 4,
    chevron: 20, chevronGap: 8,
    rowHeight: 56, rowGap: 2, rowInset: 12, rowPadV: 8,
    logoutPadV: 8, iconTile: 32, iconTileRadius: 12, glyph: 20,
    tileGap: 12, labelSize: 14, badgeSize: 20, badgeTextSize: 12,
    logoutHeight: 56, scrolls: true,
  );
}

class _NavScrollBehavior extends ScrollBehavior {
  const _NavScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
