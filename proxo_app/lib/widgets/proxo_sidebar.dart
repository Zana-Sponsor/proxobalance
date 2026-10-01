import '../models/receipt_pricing.dart';
import '../screens/ad_detail_screen.dart' show adDetailsRoute;
// lib/widgets/proxo_sidebar.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import '../theme/app_theme.dart';
import '../main.dart'
    show supabase, kIqdRate, navigatorKey, mainShellTab, mainShellTabRequest;
import '../l10n/tx_strings.dart';
import '../theme/app_locale.dart';
import '../screens/transaction_detail_screen.dart'
    show TransactionDetailScreen, TxReceiptData, TxReceiptKind;
import 'bottom_nav.dart' show ProxoBottomNav;
import 'top_bar.dart' show ProxoTopBar;
import 'receipt/receipt_kit.dart';
import 'tasks_page.dart';
import 'levels_page.dart';
import '../screens/profile_screen.dart' show ProfileScreen;
import 'proxo_error_ui.dart';
import '../screens/auth_screen.dart' show AuthScreen;
import '../screens/deposit_screen.dart' show DepositScreen;

part 'tx_history_page.dart';
part 'voucher_page.dart';
// ⚠ `part 'deposit_sheet.dart';` لابرا. ئەو فایلە **لە پڕۆژەکەدا نەبوو**،
// بۆیە ئەم فایلە هەر کۆمپایل نەدەبوو: ڕاگەیاندنی `part`ێک بۆ فایلێکی
// نەبوو هەڵەیەکی کۆمپایلە، و `_DepositSheet` هەرگیز پێناسە نەکرابوو.
// جێگرەوەکەی `screens/deposit_screen.dart`ـە — کە بە ئەنقەست بۆ ئەمە
// نووسرابوو (بڕوانە سەرەتای ئەو فایلە) بەڵام هیچ شوێنێک بانگ نەدەکرا.
part 'discount_codes_page.dart';

const _kTgDepBot  = '8547356331:AAGwypl4NFS5dsXTp3DQW2L0mz7_Ttx7M70';
const _kTgChatId  = '6259019006';

const _cDark  = AppColors.ink;
const _cDark2 = Color(0xFF2E3A50);
const _cMt    = Color(0xFF8A95A8);
const _cBg    = Color(0xFFF4F6FB);
const _cB1    = AppColors.line;
const _cB2    = Color(0xFFD0D4DE);
const _cWhite = Color(0xFFFFFFFF);
const _cBlue  = AppColors.accent;
const _cGreen = Color(0xFF16A34A);
const _cRed   = Color(0xFFDC2626);
const _cYellow= Color(0xFFD97706);

const TextStyle _kBase =
    TextStyle(fontFamily: kAppFont, decoration: TextDecoration.none);
const Color _kIconBg       = Color(0xFFF6F6F8);
const Color _kTextDark     = Color(0xFF000000);
const Color _kTextMuted    = Color(0xFF454C63);
const Color _kGlyph        = AppColors.ink;
const Color _kChevron      = Color(0xFF3E4260);
const Color _kActiveBg     = Color(0xFFF5F8FE);
const Color _kActiveTile   = Color(0xFFF0F3FC);
const Color _kActiveBlue   = Color(0xFF0B34F6);
const Color _kAccentBar    = Color(0xFF0D4CF5);
const Color _kBadgeBg      = Color(0xFFEBE5FE);
const Color _kBadgeText    = Color(0xFF5426F8);
const Color _kDivider      = Color(0xFFF0F1F4);
const Color _kInviteBg     = Color(0xFFFFFFFF);
const Color _kInviteBorder = Color(0xFFF1F0F7);
const Color _kGiftTile     = Color(0xFFF1F2F8);
const Color _kLogoutBg     = Color(0xFFF7F7F9);
const Color _kLogoutRed    = Color(0xFFE81F27);
const Color _kLevelDot     = Color(0xFF23E37F);
const Color _kCardBottom   = Color(0xFF5A55FC);
const Color _kCardTop      = Color(0xFF8792FB);
const Color _kAvatarTop    = Color(0xFF2E6BFA);
const Color _kAvatarBottom = Color(0xFF5B15FB);

const Color _navBg          = Color(0xFFFFFFFF);
const Color _navPrimary     = AppColors.accent;
const Color _navSelected    = Color(0xFFEEF4FF);
const Color _navText        = AppColors.ink;
const Color _navMuted       = AppColors.inkMuted;
const Color _navDivider     = Color(0xFFEEF2F7);
const Color _navSurface     = Color(0xFFF6F8FC);
const Color _navAvatarBg    = Color(0xFFE6EDFE);
const Color _navIconInk     = Color(0xFF2C3648);  // ⚠ بوو #374151 — تۆزێک تۆخکرا.

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
const Color _navIconTileBg     = Color(0xFFEFF3FA);
const Color _navIconTileLine   = Color(0xFFE1E8F3);
const Color _navIconTileBgSel  = Color(0xFFDCE8FF);
const Color _navLogoutTileBg   = Color(0xFFFDEAEA);
const Color _navLogoutTileLine = Color(0xFFF7D5D5);
const double _navIconTileLineW = 1.0;
const Color _navLogoutBg    = Color(0xFFFEF4F4);
const Color _navLogoutInk   = Color(0xFFEF4444);
const Color _navPanelShadow = Color(0x0F101828);

const Color  _navLiftShadow = Color(0x141B2A4A);
const double _navLift       = 1.5;

const double _navMaxWidth         = 304.0;
const double _navGutter           = 22.0;
const double _navTopGap           = 26.0;
const double _navBottomGap        = 28.0;
const double _navRadius           = 15.0;
const double _navCardHeight       = 82.0;
const double _navCardPadding      = 12.0;
const double _navAvatar           = 48.0;
const double _navAvatarGlyph      = 25.0;
const double _navAvatarGap        = 20.0;
const double _navNameSize         = 16.0;
const double _navEmailSize        = 12.5;
const double _navChevron          = 20.0;
const double _navCardToMenu       = 21.75;
const double _navRowHeight        = 54.0;
const double _navRowGap           = 3.67;
const double _navRowInset         = 9.5;
const double _navIconTile         = 40.0;
const double _navIconTileRadius   = 13.0;
// ⚠ ڕێژەی ئایکۆن بۆ خانە = 22/40 ≈ ٥٥٪. هەردووکیان بە هەمان `sw`
//   دەگۆڕدرێن، بۆیە ئەم ڕێژەیە لەسەر هەموو شاشەیەک دەپارێزرێت و
//   ئایکۆنەکە هەرگیز نە تەنگ دەبێتەوە نە دەبڕدرێت.
const double _navGlyph            = 22.0;
const double _navTileGap          = 16.5;
const double _navLabelSize        = 14.5;
const double _navMenuToDivider    = 9.3;
const double _navDividerThickness = 1.0;
const double _navDividerToLogout  = 21.0;
const double _navLogoutHeight     = 56.0;
const double _navNameToEmail      = 4.0;
const double _navChevronGap       = 8.0;
const double _navRowPadV          = 6.0;
const double _navBadgeSize        = 20.0;
const double _navBadgeTextSize    = 12.0;
const double _navRevealSlide      = 0.06;
const int    _navMenuRows         = 8;  // ⚠ بوو ٩ — «باوچەرەکان» لابرا.
const double _navMinTapTarget     = 48.0;
const double _navMinCardHeight    = 56.0;

class _LevelTier {
  final int number;
  final String nameEn;
  final double minPoints;
  final double discountPercent;
  final double discountIqd;
  final String icon;
  final Color color;
  _LevelTier({
    required this.number,
    required this.nameEn,
    required this.minPoints,
    required this.discountPercent,
    required this.discountIqd,
    required this.icon,
    required this.color,
  });

  factory _LevelTier.fromMap(Map<String, dynamic> m) => _LevelTier(
        number: (m['level_number'] as num?)?.toInt() ?? 0,
        nameEn: (m['name_en'] ?? '').toString(),
        minPoints: (m['min_points'] as num?)?.toDouble() ?? 0,
        discountPercent: (m['discount_percent'] as num?)?.toDouble() ?? 0,
        discountIqd: (m['discount_iqd'] as num?)?.toDouble() ?? 0,
        icon: (m['icon'] ?? 'medal').toString(),
        color: _parseHexColor(m['color']?.toString()),
      );
}

Color _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return _kCardBottom;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  try {
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return _kCardBottom;
  }
}

// ⚠ ئەمە بە ئەنقەست نەگۆڕدرا بۆ Solar.
//
// `_levelIconFor` لە هیچ شوێنێکی ئەم فایلەدا بانگ ناکرێت، بەڵام
// ئەم فایلە سێ `part`ی هەیە (`tx_history_page`، `voucher_page`،
// `discount_codes_page`) کە هەمان بوارە تایبەتییان هەیە و لەوانەیە
// یەکێکیان بانگی بکات. گۆڕینی جۆری گەڕاوەکەی لە `IconData`ـەوە بۆ
// `String` ئەوان دەشکێنێت.
//
// ئەگەر دڵنیایت هیچ کەس بەکاری ناهێنێت، دەتوانرێت بگۆڕدرێت بۆ:
//   'crown' → SolarIcons.crown · 'diamond'/'gem' → SolarIcons.diamond
//   'medal'/'award' → SolarIcons.medalStar
FaIconData _levelIconFor(String key) {
  switch (key) {
    case 'award':   return FontAwesomeIcons.award;
    case 'crown':   return FontAwesomeIcons.crown;
    case 'gem':     return FontAwesomeIcons.gem;
    case 'diamond': return FontAwesomeIcons.gem;
    case 'medal':
    default:        return FontAwesomeIcons.medal;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ئایکۆنەکان — Solar Linear (`solar_iconkit`)
// ═════════════════════════════════════════════════════════════════════════════
//
// پێشتر `Icons.*`ـی مێتریاڵ بوون. ئەوانە لە ٦١ dpـی ئەم دراوەرەدا ئەستوور
// و قەڵەو دەردەکەوتن و لەگەڵ شێوازی ئەپەکە نەدەگونجان. ئێستا هەموویان
// Solar Linearن — هەمان کۆمەڵەی `ad_detail_screen.dart`.
//
// ⚠ ناوی ئایکۆنەکان تەنها لێرەن. ئەگەر ئەنالایزەر یەکێکیانی نەناسییەوە
//   یان ئایکۆنێک بە دڵت نەبوو، هەر ئەم یەک ڕیزە بگۆڕە.
//   لیستی تەواو: solar-icons-web.vercel.app
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
  const ProxoSidebar({super.key, this.onClose, this.onNavigate});

  final VoidCallback? onClose;
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
  String? _avatarUrl;
  String _userName  = '';
  String _userEmail = '';
  String _initial   = '';
  bool   _loading   = true;

  late final AnimationController _intro;
  late final List<Animation<double>> _revealFade;
  late final List<Animation<Offset>> _revealSlide;
  final ScrollController _menuScroll = ScrollController();

  double _points = 0;
  List<_LevelTier> _levels = [];
  _LevelTier? _currentTier;
  _LevelTier? _nextTier;
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
    if (!mounted) return;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('full_name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final name   = (profile?['full_name'] ?? '').toString().trim();
      final email  = (profile?['email'] ?? user.email ?? '').toString();
      final avatar = (profile?['avatar_url'] ?? '').toString();

      final pointsRow = await supabase
          .from('pa_user_points')
          .select('points')
          .eq('user_id', user.id)
          .maybeSingle();
      final points = (pointsRow?['points'] as num?)?.toDouble() ?? 0;

      final levelRows = await supabase
          .from('pa_levels')
          .select('level_number, name_en, min_points, discount_percent, discount_iqd, icon, color')
          .order('level_number', ascending: true);
      final levels = (levelRows as List)
          .map((m) => _LevelTier.fromMap(m as Map<String, dynamic>))
          .toList();

      _LevelTier? current;
      _LevelTier? next;
      for (var i = 0; i < levels.length; i++) {
        if (points >= levels[i].minPoints) {
          current = levels[i];
          next = (i + 1 < levels.length) ? levels[i + 1] : null;
        }
      }
      current ??= levels.isNotEmpty ? levels.first : null;

      final unreadRows = await supabase
          .from('pa_notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      final unread = (unreadRows as List).length;

      if (mounted) {
        setState(() {
          _userName     = name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : '—');
          _userEmail    = email;
          _initial      = name.isNotEmpty ? name[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : '?');
          _avatarUrl    = avatar.isNotEmpty ? avatar : null;
          _points       = points;
          _levels       = levels;
          _currentTier  = current;
          _nextTier     = next;
          _unreadNotifs = unread;
          _loading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ⚠ پێشتر دوای `onClose` یەکێکی تریش `Navigator.pop` دەکرد.
  ///
  /// کاتێک سایدباڕەکە `Stack`ێکی دەستکرد بوو ئەوە پێویست بوو. ئێستا
  /// `Scaffold.endDrawer`ـە: `onClose` (= `closeEndDrawer`) خۆی
  /// دایدەخات، و ئەو `pop`ـە **ڕووتی ژێرەوە** لادەبات — واتە
  /// `MainShell` خۆی. ئەوە هۆکاری «بەستنەوە» و ونبوونی ستاکی
  /// ڕێنیشاندەری بوو.
  void _close() => widget.onClose?.call();

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
    final NavigatorState? nav = navigatorKey.currentState;
    _close();
    if (wait) await Future<void>.delayed(_closeAnim);
    nav?.push(ProxoPageRoute<void>(builder: (_) => page()));
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
    final NavigatorState? nav = navigatorKey.currentState;
    _close();
    await Future<void>.delayed(_closeAnim);
    try {
      await supabase.auth.signOut();
    } catch (_) {
      // شکستی سێرڤەر نابێت بەکارهێنەر لە دەرچوون بەربگرێت — تۆکێنی
      // ناوخۆیی بە هەر حاڵ لەلایەن SDKـەوە سڕدرایەوە.
    }
    nav?.pushAndRemoveUntil(
      ProxoPageRoute<void>(builder: (_) => const AuthScreen()),
      (r) => false,
    );
  }

  Future<void> _openDiscountCodes() => _go(() => const DiscountCodesPage());

  Future<void> _openNotifications() async {
    if (!mounted) return;
    // ⚠ بوو `await _close()`. `_close()` گەڕاندنەوەی `void`ـە، بۆیە
    // ئەمە کۆمپایل نەدەبوو. هەمان شێوازی `_go` / `_openDeposit`:
    // ڕێنیشاندەرەکە پێش داخستن بگرە، دواتر چاوەڕوانی ئەنیمەیشن بکە.
    final NavigatorState? nav = navigatorKey.currentState;
    _close();
    await Future<void>.delayed(_closeAnim);
    nav?.pushNamed('/notifications');
  }

  static String _fmtNum(double v) => v.round().toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double panelWidth = math.min(screenWidth * 0.78, _navMaxWidth);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: panelWidth,
        decoration: const BoxDecoration(
          color: _navBg,
          boxShadow: [
            BoxShadow(color: _navPanelShadow, blurRadius: 20, offset: Offset(-4, 0)),
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
                    child: m.scrolls ? _buildCompact(m) : _buildRelaxed(m),
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

  Widget _buildCompact(_NavMetrics m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scrollbar(
            controller: _menuScroll,
            child: SingleChildScrollView(
              controller: _menuScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                m.gutter, m.topGap, m.gutter, m.menuToDivider),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reveal(0, _buildAccountCard(m)),
                  SizedBox(height: m.cardToMenu),
                  ..._menuRows(m),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(m.gutter, 0, m.gutter, m.bottomGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _reveal(9, _buildDivider()),
              SizedBox(height: m.dividerToLogout),
              _reveal(10, _buildLogoutTile(m)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => const SizedBox(
        height: _navDividerThickness,
        child: DecoratedBox(decoration: BoxDecoration(color: _navDivider)),
      );

  List<Widget> _menuRows(_NavMetrics m) => [
        _reveal(1, _navItem(m,
          icon: _Ico.home,
          label: 'سەرەکی',
          onTap: _close,
          selected: true)),
        _reveal(2, _navItem(m,
          icon: _Ico.ads,
          // ⚠ بوو `_close` — تەنها دراوەرەکەی دادەخست و هیچی تر.
          label: 'ڕیکلامەکان',
          onTap: () {
            widget.onNavigate?.call('ads');
            _close();
          })),
        _reveal(3, _navItem(m,
          icon: _Ico.history,
          label: 'مێژووی مامەڵەکان',
          onTap: _openTxHistory)),
        _reveal(4, _navItem(m,
          icon: _Ico.discount,
          label: 'کۆدی داشکاندن',
          onTap: _openDiscountCodes)),
        // ⚠ ڕیزی «باوچەرەکان» لابرا. `VoucherPage` خۆی هێشتا ماوە
        //   (`part 'voucher_page.dart'`)، بۆیە ئەگەر ڕۆژێک ویستت
        //   بیگەڕێنیتەوە تەنها ڕیزێکی نوێ لێرە زیاد بکە.
        _reveal(5, _navItem(m,
          icon: _Ico.balance,
          // ⚠ بوو `_openTxHistory` — دەیبرد بۆ مێژووی مامەڵەکان، کە
          // ڕیزێکی سەربەخۆی خۆی هەیە لە سەرەوە. `_openDeposit` هەبوو
          // بەڵام هیچ شوێنێک بانگ نەدەکرا.
          label: 'باڵانس و پارەدان',
          onTap: _openDeposit)),
        _reveal(6, _navItem(m,
          icon: _Ico.notifications,
          label: 'ئاگادارییەکان',
          onTap: _openNotifications,
          badge: _unreadNotifs)),
        _reveal(7, _navItem(m,
          icon: _Ico.settings,
          label: 'ڕێکخستنەکان',
          onTap: _openProfile)),
        _reveal(8, _navItem(m,
          icon: _Ico.help,
          label: 'یارمەتی و پشتگیری',
          onTap: _close)),
      ];

  static const int _revealCount = 11;  // ⚠ بوو ١٢ — ڕیزێک کەم بووەوە.

  void _buildRevealAnimations() {
    Interval windowFor(int i) {
      final double begin = math.min(i * 0.038, 0.55);
      return Interval(begin, math.min(begin + 0.45, 1.0),
          curve: Curves.easeOutCubic);
    }

    _revealFade = List<Animation<double>>.generate(_revealCount,
        (i) => _intro.drive(CurveTween(curve: windowFor(i))));
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
    final String name = _userName.isNotEmpty
        ? _userName
        : (_loading ? 'بارکردن…' : '—');

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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _navAvatarBg,
                    image: _avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _avatarUrl == null
                      ? SolarIcon(
                          _Ico.avatar,
                          style: SolarIconStyle.linear,
                          size: m.avatarGlyph,
                          color: _navPrimary,
                        )
                      : null,
                ),
                SizedBox(width: m.avatarGap),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                        style: _kBase.copyWith(
                          fontSize: m.nameSize,
                          fontWeight: FontWeight.w600,
                          color: _navText,
                          height: 1.25,
                          letterSpacing: -0.1),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: m.nameToEmail),
                      Text(_userEmail,
                        style: _kBase.copyWith(
                          fontSize: m.emailSize,
                          fontWeight: FontWeight.w400,
                          color: _navMuted,
                          height: 1.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        color: selected
                            ? _navIconTileBgSel
                            : _navIconTileLine,
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
                    child: Text(label,
                      style: _kBase.copyWith(
                        fontSize: m.labelSize,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? _navPrimary : _navText,
                        height: 1.2,
                        letterSpacing: -0.05),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
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
          constraints: BoxConstraints(
            minWidth: m.badgeSize, minHeight: m.badgeSize),
          padding: EdgeInsets.symmetric(horizontal: m.badgeSize * 0.3),
          decoration: BoxDecoration(
            color: _navPrimary,
            borderRadius: BorderRadius.circular(m.badgeSize)),
          child: Text(count > 99 ? '+99' : '$count',
            maxLines: 1,
            style: _kBase.copyWith(
              fontSize: m.badgeTextSize, fontWeight: FontWeight.w700,
              color: Colors.white, height: 1.0)),
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
          onTap: _signOut,
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
                  child: Text('چوونەدەرەوە',
                    style: _kBase.copyWith(
                      fontSize: m.labelSize,
                      fontWeight: FontWeight.w600,
                      color: _navLogoutInk,
                      height: 1.2,
                      letterSpacing: -0.05),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
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

  static const double _gapBudget = _navTopGap + _navCardToMenu +
      _navMenuToDivider + _navDividerToLogout + _navBottomGap;

  static const double _itemBudget = _navCardHeight +
      _navMenuRows * (_navRowHeight + 2 * _navRowGap) + _navLogoutHeight;

  factory _NavMetrics.resolve({
    required double panelWidth,
    required double viewportHeight,
  }) {
    final double sw = (panelWidth / _navMaxWidth).clamp(0.84, 1.0);
    final double tile = _navIconTile * sw;

    double sg = 1.0;
    double sh = 1.0;
    final double natural = _gapBudget + _itemBudget + _navDividerThickness;
    if (viewportHeight.isFinite && viewportHeight < natural) {
      sg = ((viewportHeight - _itemBudget - _navDividerThickness) / _gapBudget)
          .clamp(0.62, 1.0);
      sh = ((viewportHeight - _gapBudget * sg - _navDividerThickness) /
              _itemBudget)
          .clamp(0.80, 1.0);
    }

    final double rowHeight =
        math.max(_navRowHeight * sh, _navMinTapTarget);
    final double logoutHeight =
        math.max(_navLogoutHeight * sh, _navMinTapTarget);
    final double cardHeight =
        math.max(_navCardHeight * sh, _navMinCardHeight);

    double padFor(double height) => math.max(
        2.0, math.min(_navRowPadV * sw, (height - tile) / 2));

    final double rowGap = _navRowGap * sh;
    final double topGap = _navTopGap * sg;
    final double bottomGap = _navBottomGap * sg;
    final double cardToMenu = _navCardToMenu * sg;
    final double menuToDivider = _navMenuToDivider * sg;
    final double dividerToLogout = _navDividerToLogout * sg;

    final double footerHeight = _navDividerThickness +
        dividerToLogout + logoutHeight + bottomGap;

    final double contentHeight = topGap +
        cardHeight +
        cardToMenu +
        _navMenuRows * (rowHeight + 2 * rowGap) +
        menuToDivider +
        _navDividerThickness +
        dividerToLogout +
        logoutHeight +
        bottomGap;

    return _NavMetrics._(
      gutter:          _navGutter * sw,
      topGap:          topGap,
      bottomGap:       bottomGap,
      cardToMenu:      cardToMenu,
      menuToDivider:   menuToDivider,
      dividerToLogout: dividerToLogout,
      radius:          _navRadius * sw,
      cardHeight:      cardHeight,
      cardPadding:     _navCardPadding * sw,
      cardPadV:        padFor(cardHeight).clamp(2.0, _navCardPadding * sw),
      avatar:          _navAvatar * sw,
      avatarGlyph:     _navAvatarGlyph * sw,
      avatarGap:       _navAvatarGap * sw,
      nameSize:        _navNameSize * sw,
      emailSize:       _navEmailSize * sw,
      nameToEmail:     _navNameToEmail * sw,
      chevron:         _navChevron * sw,
      chevronGap:      _navChevronGap * sw,
      rowHeight:       rowHeight,
      rowGap:          rowGap,
      rowInset:        _navRowInset * sw,
      rowPadV:         padFor(rowHeight),
      logoutPadV:      padFor(logoutHeight),
      iconTile:        tile,
      iconTileRadius:  _navIconTileRadius * sw,
      glyph:           _navGlyph * sw,
      tileGap:         _navTileGap * sw,
      labelSize:       _navLabelSize * sw,
      badgeSize:       _navBadgeSize * sw,
      badgeTextSize:   _navBadgeTextSize * sw,
      logoutHeight:    logoutHeight,
      scrolls:         viewportHeight.isFinite &&
                       contentHeight > viewportHeight + 0.5 &&
                       viewportHeight > footerHeight * 3,
    );
  }
}

class _NavScrollBehavior extends ScrollBehavior {
  const _NavScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) => child;
}
