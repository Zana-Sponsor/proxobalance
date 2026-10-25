import 'dart:async';
import '../services/unread_notification_counter.dart';
import '../services/app_telemetry_service.dart';
import '../services/auth_activity_service.dart';
import 'proxo_app_bar.dart';
import 'package:proxo_app/l10n/proxo_strings.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import '../models/receipt_pricing.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import '../theme/proxo_chrome.dart';
import '../theme/proxo_surface.dart';
import '../screens/faq_screen.dart' show FaqScreen;
import '../theme/app_theme.dart';
import '../main.dart' show supabase;
import '../l10n/tx_strings.dart';
import '../theme/app_locale.dart';
import '../screens/transaction_detail_screen.dart'
    show TransactionDetailScreen, TxReceiptData, TxReceiptKind;
import 'receipt/receipt_kit.dart';
import 'receipt/tx_history_layout.dart';
import '../screens/profile_screen.dart' show ProfileScreen;
import 'proxo_error_ui.dart';
import '../screens/auth_screen.dart' show AuthScreen;
import '../screens/deposit_screen.dart' show DepositScreen;
import 'package:proxo_app/widgets/proxo_text.dart';

part 'tx_history_page.dart';
part 'voucher_page.dart';
part 'discount_codes_page.dart';

const _cDark = AppColors.ink;
const _cMt = Color(0xFF8A95A8);
const _cBg = Color(0xFFF4F6FB);
const _cB1 = AppColors.line;

const TextStyle _kBase =
    TextStyle(fontFamily: kAppFont, decoration: TextDecoration.none);
const Color _kIconBg = Color(0xFFF6F6F8);
const Color _kTextDark = Color(0xFF000000);
const Color _kTextMuted = Color(0xFF454C63);
const Color _kActiveBlue = Color(0xFF0B34F6);

/// The drawer owns one action at a time. Its Navigator is captured before the
/// closing animation removes the drawer context from the tree.
class ProxoSidebar extends StatefulWidget {
  const ProxoSidebar({
    super.key,
    this.onClose,
    this.onNavigate,
    this.currentIndex = 0,
    this.signOut,
  });

  final VoidCallback? onClose;
  final void Function(String route)? onNavigate;
  final int currentIndex;

  /// Allows a host to supply its account logout operation.
  final Future<void> Function()? signOut;

  @override
  State<ProxoSidebar> createState() => _ProxoSidebarState();
}

class _ProxoSidebarState extends State<ProxoSidebar> {
  String? _avatarUrl;
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  bool _loading = true;
  bool _busy = false;
  bool _signingOut = false;
  Timer? _tabReset;
  String? _logoutError;
  int _unreadNotifs = 0;
  final ScrollController _menuScroll = ScrollController();
  late final UnreadNotificationCounter _counter;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _userEmail = _visibleEmail(user?.email);
    _userPhone =
        (user?.userMetadata?['phone'] ?? user?.phone ?? '').toString().trim();
    _userName = (user?.userMetadata?['full_name'] ?? '').toString().trim();
    _counter = UnreadNotificationCounter.forClient(supabase);
    _unreadNotifs = _counter.count.value;
    _counter.count.addListener(_unreadChanged);
    _counter.acquire();
    _load();
  }

  void _unreadChanged() {
    if (mounted) setState(() => _unreadNotifs = _counter.count.value);
  }

  @override
  void dispose() {
    _tabReset?.cancel();
    _counter.count.removeListener(_unreadChanged);
    _counter.release();
    _menuScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, email, phone, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || supabase.auth.currentUser?.id != user.id) return;
      final name = (profile?['full_name'] ?? '').toString().trim();
      final email = _visibleEmail(profile?['email'] ?? user.email);
      final phone = (profile?['phone'] ?? _userPhone).toString().trim();
      final avatar = (profile?['avatar_url'] ?? '').toString();
      setState(() {
        _userName = name.isNotEmpty
            ? name
            : (_userName.isNotEmpty ? _userName : 'بەکارهێنەر');
        _userEmail = email;
        _userPhone = phone;
        _avatarUrl = avatar.isNotEmpty ? avatar : null;
        _loading = false;
      });
    } catch (_) {
      AppTelemetryService.active
          ?.event('error', 'sidebar_profile_failed', outcome: 'failure');
      if (mounted && supabase.auth.currentUser?.id == user.id) {
        setState(() => _loading = false);
      }
    }
  }

  static String _visibleEmail(Object? value) {
    final email = value?.toString().trim() ?? '';
    return email.toLowerCase().endsWith('@phone.proxopages.com') ? '' : email;
  }

  void _openProfile() => widget.onNavigate != null
      ? _tab('profile')
      : unawaited(_go(() => const ProfileScreen()));

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    // Closing a drawer must never pop the private route underneath it.
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isEndDrawerOpen ?? false) scaffold!.closeEndDrawer();
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
  }

  bool _claimAction() {
    if (_busy || !mounted) return false;
    setState(() => _busy = true);
    return true;
  }

  Future<void> _navigate(Future<void> Function(NavigatorState) action) async {
    if (!_claimAction()) return;
    final nav = Navigator.of(context, rootNavigator: true);
    final route = ModalRoute.of(context);
    final owner = supabase.auth.currentUser?.id;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    _close();
    try {
      if (!reducedMotion) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // A pending drawer action must not re-open private UI after logout or
      // replace a different route that appeared during the close animation.
      if (owner == null ||
          !nav.mounted ||
          route?.isCurrent == false ||
          owner != supabase.auth.currentUser?.id) {
        return;
      }
      await action(nav);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go(Widget Function() page) => _navigate((nav) async {
        await nav.push(ProxoPageRoute<void>(builder: (_) => page()));
      });

  void _tab(String route) {
    if (!_claimAction()) return;
    final navigate = widget.onNavigate;
    _close();
    // MainShell animates the retained tab; no second route is pushed.
    navigate?.call(route);
    _tabReset?.cancel();
    _tabReset = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  Future<void> _signOut() async {
    if (!_claimAction()) return;
    final nav = Navigator.of(context, rootNavigator: true);
    final route = ModalRoute.of(context);
    final signOut =
        widget.signOut ?? AuthActivityService.forClient(supabase).signOut;
    setState(() {
      _signingOut = true;
      _logoutError = null;
    });
    try {
      await signOut();
    } catch (_) {
      // Remote revocation may fail after the SDK clears local credentials.
      // Session state below determines whether protected UI may remain.
    } finally {
      final cleared = supabase.auth.currentSession == null;
      if (mounted) {
        setState(() {
          _busy = false;
          _signingOut = false;
          if (!cleared) {
            _logoutError =
                'دەرچوون سەرکەوتوو نەبوو. تکایە دووبارە هەوڵ بدەرەوە.';
          }
        });
      }
      // Let ProxoApp's already-scheduled auth listener replace the route first.
      // Embedded hosts still need a fallback, checked after that same frame.
      if (cleared) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!nav.mounted ||
              route?.isCurrent == false ||
              supabase.auth.currentSession != null) {
            return;
          }
          nav.pushAndRemoveUntil(
              ProxoPageRoute<void>(builder: (_) => const AuthScreen()),
              (_) => false);
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final panelWidth = math.min(MediaQuery.sizeOf(context).width - 24, 336.0);
    return Directionality(
      textDirection: Directionality.of(context),
      child: SizedBox(
        key: const ValueKey('sidebar-panel'),
        width: panelWidth,
        child: Material(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The close control remains reachable even when the menu is
                // scrolled or large text makes its content taller than a phone.
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    const Expanded(
                      child: ProxoText('مێنیو',
                          translate: true, style: ProxoSurface.title),
                    ),
                    IconButton(
                      key: const ValueKey('sidebar-close'),
                      tooltip: ProxoStrings.text('داخستنی مێنیو'),
                      onPressed: _close,
                      constraints: const BoxConstraints.tightFor(
                          width: ProxoChrome.actionSize,
                          height: ProxoChrome.actionSize),
                      icon: const ProxoSymbol(ProxoSymbolName.close,
                          size: ProxoChrome.toolbarIconSize,
                          color: AppColors.inkMuted),
                    ),
                  ]),
                ),
                const Divider(height: 1, color: ProxoChrome.border),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('sidebar-scroll'),
                    controller: _menuScroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _accountCard(),
                        const SizedBox(height: 8),
                        _section('بەڕێوەبردن'),
                        _item('home', ProxoSymbolName.home, 'سەرەکی',
                            () => _tab('home'),
                            selected: widget.currentIndex == 0),
                        _item('ads', ProxoSymbolName.ads, 'ڕیکلامەکان',
                            () => _tab('ads'),
                            selected: widget.currentIndex == 1),
                        _item('tools', ProxoSymbolName.tools, 'پەڕەکان',
                            () => _tab('tools'),
                            selected: widget.currentIndex == 3),
                        _section('هەژمار'),
                        _item(
                            'deposit',
                            ProxoSymbolName.wallet,
                            'باڵانس و پارەدان',
                            () => _go(() => const DepositScreen())),
                        _item(
                            'transactions',
                            ProxoSymbolName.history,
                            'مێژووی مامەڵەکان',
                            () => _go(() => const TxHistoryPage())),
                        _item(
                            'discounts',
                            ProxoSymbolName.discount,
                            'کۆدی داشکاندن',
                            () => _go(() => const DiscountCodesPage())),
                        _item(
                            'notifications',
                            ProxoSymbolName.bell,
                            'ئاگادارییەکان',
                            () => _navigate((nav) async {
                                  await nav.pushNamed('/notifications');
                                }),
                            badge: _unreadNotifs),
                        _item('profile', ProxoSymbolName.settings,
                            'پڕۆفایل و ڕێکخستنەکان', _openProfile,
                            selected: widget.currentIndex == 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: ProxoChrome.border),
                        ),
                        _item('help', ProxoSymbolName.help, 'یارمەتی و پشتگیری',
                            () => _go(() => const FaqScreen())),
                        const SizedBox(height: 12),
                        if (_logoutError != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: ProxoText(_logoutError!,
                                translate: true,
                                key: const ValueKey('sidebar-logout-error'),
                                style: ProxoSurface.secondary
                                    .copyWith(color: const Color(0xFFB42318))),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _item('logout', ProxoSymbolName.logout,
                            _signingOut ? 'دەرچوون…' : 'چوونەدەرەوە', _signOut,
                            danger: true, loading: _signingOut),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: ProxoText(text,
            translate: true,
            style: const TextStyle(
                fontFamily: ProxoSurface.fontFamily,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted)),
      );

  Widget _accountCard() {
    final contact = _userEmail.isNotEmpty ? _userEmail : _userPhone;
    return Container(
      key: const ValueKey('sidebar-account'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProxoChrome.surface,
        borderRadius: BorderRadius.circular(ProxoSurface.radius),
      ),
      child: Row(children: [
        ClipOval(
          child: SizedBox.square(
            dimension: 40,
            child: _avatarUrl == null
                ? _avatarFallback()
                : Image.network(_avatarUrl!,
                    fit: BoxFit.cover,
                    cacheWidth:
                        (40 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                    errorBuilder: (_, __, ___) => _avatarFallback()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProxoText(
                _userName.isNotEmpty
                    ? _userName
                    : (_loading ? 'بارکردن…' : 'بەکارهێنەر'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ProxoSurface.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (contact.isNotEmpty) ...[
                const SizedBox(height: 4),
                Tooltip(
                  message: contact,
                  child: ProxoText(
                    contact,
                    key: const ValueKey('sidebar-contact'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: ProxoSurface.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _avatarFallback() => const ColoredBox(
      color: Color(0xFFE6EDFE),
      child:
          ProxoSymbol(ProxoSymbolName.user, size: 22, color: AppColors.accent));

  Widget _item(
      String id, ProxoSymbolName icon, String label, VoidCallback onTap,
      {bool selected = false,
      bool danger = false,
      bool loading = false,
      int badge = 0}) {
    final color = danger
        ? const Color(0xFFB42318)
        : selected
            ? AppColors.accent
            : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: !_busy,
        child: Material(
          color: danger
              ? const Color(0xFFFFF2F1)
              : selected
                  ? ProxoChrome.selected
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(ProxoSurface.controlRadius),
          child: InkWell(
            key: ValueKey('sidebar-$id'),
            onTap: _busy ? null : onTap,
            borderRadius: BorderRadius.circular(ProxoSurface.controlRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  SizedBox.square(
                      dimension: 24,
                      child: loading
                          ? CircularProgressIndicator(
                              strokeWidth: 2, color: color)
                          : ProxoSymbol(icon, size: 22, color: color)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ProxoText(label,
                          translate: true,
                          style: TextStyle(
                              fontFamily: ProxoSurface.fontFamily,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: selected || danger
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: color))),
                  if (badge > 0) ...[
                    const SizedBox(width: 8),
                    Semantics(
                        label: ProxoStrings.format(
                            '{count} نەخوێندراوە', {'count': badge}),
                        excludeSemantics: true,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                child: Text(badge > 99 ? '99+' : '$badge',
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                        fontFamily: ProxoSurface.fontFamily,
                                        fontSize: 11,
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white))))),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
