// notifications_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../main.dart' show supabase;
import '../widgets/proxo_error_ui.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────

class _Palette {
  static const bg = AppColors.surfaceBase;
  static const card = AppColors.surfaceCard;
  static const primary = Color(0xFF0365FF);
  static const success = Color(0xFF13A56A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const divider = Color(0xFFE5E7EB);
  static const textPrimary = AppColors.ink;
  static const textSecondary = AppColors.inkMuted;
  static const unreadBg = Color(0xFFF0F5FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Kurdish digit + date/time helpers
// ─────────────────────────────────────────────────────────────────────────────

const _kDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String _kd(int n) =>
    n.toString().split('').map((c) => _kDigits[int.parse(c)]).join();

const _kMonths = [
  'کانوونی دووەم',
  'شوبات',
  'ئازار',
  'نیسان',
  'ئایار',
  'حوزەیران',
  'تەممووز',
  'ئاب',
  'ئەیلوول',
  'تشرینی یەکەم',
  'تشرینی دووەم',
  'کانوونی یەکەم',
];

String _formatKurdishDate(DateTime dt) =>
    '${_kd(dt.day)} ${_kMonths[dt.month - 1]} ${_kd(dt.year)}';

String _formatKurdishTime(DateTime dt) {
  final h24 = dt.hour;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final period = h24 < 12 ? 'AM' : 'PM';
  return '${_kd(h12).padLeft(2, _kDigits[0])}:${_kd(dt.minute).padLeft(2, _kDigits[0])} $period';
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  final min = diff.inMinutes;
  if (min < 1) return 'ئێستا';
  if (min < 60) return '${_kd(min)} خولەک پێش';
  final hr = diff.inHours;
  if (hr < 24) return '${_kd(hr)} کاتژمێر پێش';
  if (_isYesterday(dt)) return 'دوێنێ';
  if (diff.inDays < 7) return '${_kd(diff.inDays)} ڕۆژ پێش';
  return _formatKurdishDate(dt);
}

bool _isToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

bool _isYesterday(DateTime dt) {
  final y = DateTime.now().subtract(const Duration(days: 1));
  return dt.year == y.year && dt.month == y.month && dt.day == y.day;
}

bool _isThisWeek(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  return diff.inDays < 7 && !_isToday(dt) && !_isYesterday(dt);
}

bool _isThisMonth(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year &&
      dt.month == now.month &&
      !_isToday(dt) &&
      !_isYesterday(dt) &&
      !_isThisWeek(dt);
}

String _groupLabel(DateTime dt) {
  if (_isToday(dt)) return 'ئەمڕۆ';
  if (_isYesterday(dt)) return 'دوێنێ';
  if (_isThisWeek(dt)) return 'ئەم هەفتەیە';
  if (_isThisMonth(dt)) return 'ئەم مانگە';
  return 'کۆنتر';
}

const _groupOrder = ['ئەمڕۆ', 'دوێنێ', 'ئەم هەفتەیە', 'ئەم مانگە', 'کۆنتر'];

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _Notif {
  final String id;
  final String type;
  final String? title;
  final String? body;
  bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? meta;

  _Notif({
    required this.id,
    required this.type,
    this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
    this.meta,
  });

  factory _Notif.fromMap(Map<String, dynamic> m) => _Notif(
        id: m['id'] as String? ?? '',
        type: m['type'] as String? ?? 'general',
        title: m['title'] as String?,
        body: m['body'] as String?,
        isRead: m['is_read'] as bool? ?? false,
        createdAt: m['created_at'] != null
            ? (DateTime.tryParse(m['created_at'] as String) ?? DateTime.now())
                .toLocal()
            : DateTime.now(),
        meta: m['meta'] as Map<String, dynamic>?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Categories & Types
// ─────────────────────────────────────────────────────────────────────────────

enum _Cat {
  wallet,
  payment,
  gift,
  promotion,
  announcement,
  message,
  security,
  update,
  success,
  warning,
  error,
}

class _CatStyle {
  final List<Color> gradient;
  const _CatStyle(this.gradient);
}

const _catStyles = <_Cat, _CatStyle>{
  _Cat.wallet: _CatStyle([Color(0xFF34D399), Color(0xFF059669)]),
  _Cat.payment: _CatStyle([Color(0xFF10B981), Color(0xFF047857)]),
  _Cat.gift: _CatStyle([Color(0xFFFB923C), Color(0xFFEA580C)]),
  _Cat.promotion: _CatStyle([Color(0xFFC084FC), Color(0xFF7C3AED)]),
  _Cat.announcement: _CatStyle([Color(0xFF818CF8), Color(0xFF4F46E5)]),
  _Cat.message: _CatStyle([Color(0xFF60A5FA), AppColors.accent]),
  _Cat.security: _CatStyle([Color(0xFF94A3B8), Color(0xFF475569)]),
  _Cat.update: _CatStyle([Color(0xFF22D3EE), Color(0xFF0891B2)]),
  _Cat.success: _CatStyle([Color(0xFF4ADE80), Color(0xFF16A34A)]),
  _Cat.warning: _CatStyle([Color(0xFFFBBF24), Color(0xFFD97706)]),
  _Cat.error: _CatStyle([Color(0xFFF87171), Color(0xFFDC2626)]),
};

class _NotifTypeDef {
  final IconData icon;
  final _Cat cat;
  final String defaultTitle;
  final String defaultBody;
  const _NotifTypeDef(this.icon, this.cat, this.defaultTitle, this.defaultBody);
}

const _typeMap = <String, _NotifTypeDef>{
  'ad_approved': _NotifTypeDef(Icons.task_alt_rounded, _Cat.success,
      'ڕیکلامەکەت پەسەندکرا', 'ڕیکلامەکەت پەسەندکرا و ئامادەی بڵاوکردنەوەیە.'),
  'ad_rejected': _NotifTypeDef(Icons.cancel_rounded, _Cat.error,
      'ڕیکلامەکەت ڕەتکرایەوە', 'ڕیکلامەکەت ڕەتکرایەوە. تکایە زانیاریەکان بپشکنە.'),
  'ad_active': _NotifTypeDef(Icons.campaign_rounded, _Cat.announcement,
      'ڕیکلامەکەت چالاکبوو', 'ڕیکلامەکەت ئێستا چالاکە و دەرباز دەبێت.'),
  'ad_completed': _NotifTypeDef(Icons.emoji_events_rounded, _Cat.success,
      'ڕیکلامەکەت تەواوبوو', 'ڕیکلامەکەت بە سەرکەوتوویی تەواوبوو.'),
  'ad_paused': _NotifTypeDef(Icons.pause_circle_rounded, _Cat.warning,
      'ڕیکلامەکەت وەستاوە', 'ڕیکلامەکەت وەستێنرا. دەتوانیت دوبارەی چالاک بکەیت.'),
  'new_ad': _NotifTypeDef(Icons.rocket_launch_rounded, _Cat.promotion,
      'ڕیکلامی نوێ دروستکرا', 'ڕیکلامی نوێت بە سەرکەوتوویی دروستکرا.'),
  'deposit_approved': _NotifTypeDef(Icons.verified_rounded, _Cat.payment,
      'پارەدانەکەت پەسەندکرا', 'داواکاری پارەدانەکەت پەسەندکرا.'),
  'deposit_rejected': _NotifTypeDef(Icons.highlight_off_rounded, _Cat.error,
      'پارەدانەکەت ڕەتکرایەوە', 'داواکاری پارەدانەکەت ڕەتکرایەوە.'),
  'balance_added': _NotifTypeDef(Icons.account_balance_wallet_rounded,
      _Cat.wallet, 'باڵانس زیادکرا', 'باڵانسی هەژمارەکەت نوێ کرایەوە.'),
  'refund': _NotifTypeDef(Icons.currency_exchange_rounded, _Cat.wallet,
      'پارەکەت گەڕایەوە', 'پارەی داواکاریەکەت بۆ هەژمارەکەت گەڕایەوە.'),
  'refund_rejected_ad': _NotifTypeDef(Icons.currency_exchange_rounded,
      _Cat.wallet, 'پارەی ڕیکلامی ڕەتکراو گەڕایەوە',
      'پارەی ڕیکلامی ڕەتکراوەکەت گەڕایەوە.'),
  'new_asset': _NotifTypeDef(Icons.card_giftcard_rounded, _Cat.gift,
      'ئامرازێکی نوێ زیادکرا', 'تایبەتمەندییەکی نوێ زیادکرا.'),
  'admin_msg': _NotifTypeDef(Icons.forum_rounded, _Cat.message,
      'پەیامی ئادمین', 'پەیامێکی نوێت وەرگرت.'),
  'system_update': _NotifTypeDef(Icons.system_update_rounded, _Cat.update,
      'نوێکردنەوەی سیستەم', 'وەشانی نوێی ئەپ ئامادەیە.'),
  'general': _NotifTypeDef(Icons.notifications_rounded, _Cat.message,
      'ئاگاداری', 'ئاگادارییەکی نوێت هەیە.'),
  'warning': _NotifTypeDef(Icons.warning_amber_rounded, _Cat.warning,
      'ئاگادارکردنەوە', 'تکایە ئاگادارییەکە بخوێنەوە.'),
  'error': _NotifTypeDef(Icons.gpp_bad_rounded, _Cat.error, 'کێشە',
      'کێشەیەک لە هەژمارەکەت تۆمارکراوە.'),
  'security': _NotifTypeDef(Icons.shield_rounded, _Cat.security,
      'ئاسایشی هەژمار', 'چالاکیەک لەسەر هەژمارەکەت تۆمارکراوە.'),
};

_NotifTypeDef _typeOf(String type) =>
    _typeMap[type] ?? _typeMap['general']!;

bool _isWalletNav(String type) =>
    type.startsWith('deposit_') || type == 'balance_added' || type == 'refund';

bool _isAdNav(String type) =>
    type.startsWith('ad_') || type == 'new_ad' || type == 'refund_rejected_ad';

enum _FilterCategory { all, unread, ads, payments, support, system }
enum _FilterDate { all, today, yesterday, thisWeek, thisMonth }

const _categoryLabels = {
  _FilterCategory.all: 'هەموو',
  _FilterCategory.unread: 'نەخوێندراوەکان',
  _FilterCategory.ads: 'ڕیکلامەکان',
  _FilterCategory.payments: 'پارەدانەکان',
  _FilterCategory.support: 'پشتگیری',
  _FilterCategory.system: 'سیستەم',
};

const _dateLabels = {
  _FilterDate.all: 'هەموو',
  _FilterDate.today: 'ئەمڕۆ',
  _FilterDate.yesterday: 'دوێنێ',
  _FilterDate.thisWeek: 'ئەم هەفتەیە',
  _FilterDate.thisMonth: 'ئەم مانگە',
};

const _kNotifEnabled = 'proxo_notifications_enabled';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsScreen
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_Notif> _notifs = [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _markingAll = false;
  bool _notifEnabled = true;

  _FilterCategory _filterCategory = _FilterCategory.all;
  _FilterDate _filterDate = _FilterDate.all;

  final Set<String> _pinned = {};
  final Set<String> _muted = {};
  final Set<String> _archived = {};

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  List<_Notif> get _filtered {
    return _notifs.where((n) {
      if (_archived.contains(n.id)) return false;

      bool catOk;
      switch (_filterCategory) {
        case _FilterCategory.all:
          catOk = true;
          break;
        case _FilterCategory.unread:
          catOk = !n.isRead;
          break;
        case _FilterCategory.ads:
          catOk = _isAdNav(n.type);
          break;
        case _FilterCategory.payments:
          catOk = _isWalletNav(n.type);
          break;
        case _FilterCategory.support:
          catOk = n.type == 'admin_msg';
          break;
        case _FilterCategory.system:
          catOk = n.type == 'system_update' ||
              n.type == 'general' ||
              n.type == 'warning' ||
              n.type == 'error' ||
              n.type == 'new_asset';
          break;
      }

      bool dateOk;
      switch (_filterDate) {
        case _FilterDate.all:
          dateOk = true;
          break;
        case _FilterDate.today:
          dateOk = _isToday(n.createdAt);
          break;
        case _FilterDate.yesterday:
          dateOk = _isYesterday(n.createdAt);
          break;
        case _FilterDate.thisWeek:
          dateOk = DateTime.now().difference(n.createdAt).inDays < 7;
          break;
        case _FilterDate.thisMonth:
          final now = DateTime.now();
          dateOk =
              n.createdAt.year == now.year && n.createdAt.month == now.month;
          break;
      }

      return catOk && dateOk;
    }).toList()
      ..sort((a, b) {
        final ap = _pinned.contains(a.id) ? 0 : 1;
        final bp = _pinned.contains(b.id) ? 0 : 1;
        if (ap != bp) return ap - bp;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  bool get _hasActiveFilters =>
      _filterCategory != _FilterCategory.all || _filterDate != _FilterDate.all;

  int get _unreadCount => _notifs.where((n) => !n.isRead).length;

  List<MapEntry<String, List<_Notif>>> get _grouped {
    final filtered = _filtered;
    final groups = <String, List<_Notif>>{};
    for (final n in filtered) {
      groups.putIfAbsent(_groupLabel(n.createdAt), () => []).add(n);
    }
    return _groupOrder
        .where((k) => groups.containsKey(k))
        .map((k) => MapEntry(k, groups[k]!))
        .toList();
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _notifEnabled = prefs.getBool(_kNotifEnabled) ?? true);
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() { _loading = false; _loadFailed = false; });
        return;
      }
      final data = await supabase
          .from('pa_notifications')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _notifs = (data as List)
              .map((m) => _Notif.fromMap(m as Map<String, dynamic>))
              .toList();
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (e) {
      debugPrint('Notifications: load failed: $e');
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  void _subscribeRealtime() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    _channel = supabase
        .channel('notif_screen_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pa_notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pa_notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── سفرکردنەوەی خێرا بەبێ لاگ (Optimistic UI) ──────────────────────────────
  Future<void> _markAllRead() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || _markingAll || _unreadCount == 0) return;

    HapticFeedback.lightImpact();
    // ١. دەستبەجێ سفر دەبێتەوە لەسەر شاشەکە
    setState(() {
      for (final n in _notifs) {
        n.isRead = true;
      }
    });

    // ٢. ناردنی داواکاری بۆ داتابەیس بە بێ وەستانی UI
    try {
      await supabase
          .from('pa_notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> _markSingleRead(String id) async {
    final idx = _notifs.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifs[idx].isRead) return;
    setState(() => _notifs[idx].isRead = true);
    try {
      await supabase.from('pa_notifications').update({'is_read': true}).eq('id', id);
    } catch (_) {}
  }

  Future<void> _deleteNotif(String id) async {
    final removed = _notifs.firstWhere((n) => n.id == id, orElse: () => _Notif(
        id: id, type: 'general', isRead: true, createdAt: DateTime.now()));
    final idx = _notifs.indexWhere((n) => n.id == id);
    if (mounted) setState(() => _notifs.removeWhere((n) => n.id == id));
    try {
      await supabase.from('pa_notifications').delete().eq('id', id);
    } catch (e) {
      if (mounted && idx != -1) {
        setState(() => _notifs.insert(idx.clamp(0, _notifs.length), removed));
        _showSnack('سڕینەوە سەرنەکەوت', _Palette.error);
      }
    }
  }

  void _archiveNotif(String id) {
    HapticFeedback.lightImpact();
    setState(() => _archived.add(id));
    _showSnack('ئاگادارییەکە چووە بۆ ئارشیف', _Palette.success,
        tone: ProxoErrorTone.success);
  }

  void _togglePin(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_pinned.contains(id)) {
        _pinned.remove(id);
      } else {
        _pinned.add(id);
      }
    });
  }

  void _toggleMute(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_muted.contains(id)) {
        _muted.remove(id);
      } else {
        _muted.add(id);
      }
    });
  }

  void _showSnack(String msg, Color color, {ProxoErrorTone? tone}) {
    showProxoErrorSnack(
      context,
      msg,
      tone: tone ??
          (color == _Palette.error
              ? ProxoErrorTone.danger
              : color == _Palette.warning
                  ? ProxoErrorTone.warning
                  : color == _Palette.success
                      ? ProxoErrorTone.success
                      : ProxoErrorTone.info),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _handleTap(_Notif n) async {
    HapticFeedback.selectionClick();
    unawaited(_markSingleRead(n.id));
  }

  void _handleLongPress(_Notif n) {
    HapticFeedback.mediumImpact();
    final isPinned = _pinned.contains(n.id);
    final isMuted = _muted.contains(n.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _Palette.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Palette.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                if (!n.isRead)
                  _ActionTile(
                    icon: Icons.mark_email_read_rounded,
                    label: 'وەک خوێندراوە نیشانبکە',
                    color: _Palette.primary,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _markSingleRead(n.id);
                    },
                  ),
                _ActionTile(
                  icon: isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  label: isPinned ? 'لادانی پن' : 'پن بکە',
                  color: _Palette.warning,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _togglePin(n.id);
                  },
                ),
                _ActionTile(
                  icon: isMuted
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_off_outlined,
                  label: isMuted ? 'چالاککردنەوەی ئاگاداری' : 'بێدەنگ بکە',
                  color: _Palette.textSecondary,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _toggleMute(n.id);
                  },
                ),
                _ActionTile(
                  icon: Icons.archive_outlined,
                  label: 'بیخە ئارشیف',
                  color: _Palette.textSecondary,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _archiveNotif(n.id);
                  },
                ),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'بسڕەوە',
                  color: _Palette.error,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _deleteNotif(n.id);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterSheet(
        selectedCategory: _filterCategory,
        selectedDate: _filterDate,
        onApply: (cat, date) {
          setState(() {
            _filterCategory = cat;
            _filterDate = date;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _Palette.bg,
        body: RefreshIndicator(
          color: _Palette.primary,
          displacement: 80,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              _buildSliverAppBar(),
              if (_loading)
                _buildSkeletonSliver()
              else if (_grouped.isEmpty && _loadFailed)
                _buildErrorSliver()
              else if (_grouped.isEmpty)
                _buildEmptySliver()
              else
                _buildListSliver(),
            ],
          ),
        ),
      ),
    );
  }

  // ── sliver app bar ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    final unread = _unreadCount;
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      toolbarHeight: 56,
      collapsedHeight: 56,
      expandedHeight: 56,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leadingWidth: 0,
      leading: const SizedBox.shrink(),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProxoText(
            'ئاگادارییەکان',
            style: TextStyle(
              fontFamily: kAppFont,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: _Palette.textPrimary,
              height: 1.2,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: _Palette.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ProxoText(
                unread > 99 ? '٩٩+' : _kd(unread),
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            onPressed: _showFilterSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.tune_rounded,
                    color: _hasActiveFilters
                        ? _Palette.primary
                        : _Palette.textSecondary,
                    size: 21),
                if (_hasActiveFilters)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _Palette.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (unread > 0)
          IconButton(
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded,
                color: _Palette.primary, size: 21),
          ),
      ],
      flexibleSpace: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward_rounded,
                  color: _Palette.textPrimary, size: 21),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: _Palette.divider),
      ),
    );
  }

  Widget _buildSkeletonSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: _SkeletonCard(),
          ),
          childCount: 8,
        ),
      ),
    );
  }

  Widget _buildErrorSliver() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ProxoErrorView(
        title: 'ئاگادارییەکان بار نەبوون',
        message: 'نەتوانرا ئاگادارییەکانت بار بکرێن.\n'
            'ئینتەرنێتەکەت بپشکنەوە و دووبارە هەوڵ بدەرەوە.',
        actionLabel: 'دووبارە هەوڵ بدەرەوە',
        onAction: _load,
      ),
    );
  }

  Widget _buildEmptySliver() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF4FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off_outlined,
                    size: 34, color: _Palette.primary),
              ),
              const SizedBox(height: 16),
              const ProxoText(
                'هیچ ئاگادارییەک نییە',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _Palette.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const ProxoText(
                'کاتێک ئاگادارییەکی نوێت هەبێت لێرە دەردەکەوێت',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 12.5,
                  color: _Palette.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListSliver() {
    final groups = _grouped;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            int cursor = 0;
            for (final group in groups) {
              if (index == cursor) {
                return _SectionHeader(label: group.key);
              }
              cursor++;
              for (int i = 0; i < group.value.length; i++) {
                if (index == cursor) {
                  final n = group.value[i];
                  final isLast = i == group.value.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    child: _NotifCard(
                      key: ValueKey(n.id),
                      notif: n,
                      isPinned: _pinned.contains(n.id),
                      isMuted: _muted.contains(n.id),
                      onTap: () => _handleTap(n),
                      onLongPress: () => _handleLongPress(n),
                      onDelete: () => _deleteNotif(n.id),
                      onArchive: () => _archiveNotif(n.id),
                    ),
                  );
                }
                cursor++;
              }
            }
            return const SizedBox.shrink();
          },
          childCount:
              groups.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6, right: 2),
      child: ProxoText(
        label,
        style: const TextStyle(
          fontFamily: kAppFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _Palette.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotifCard
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatefulWidget {
  final _Notif notif;
  final bool isPinned;
  final bool isMuted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  const _NotifCard({
    super.key,
    required this.notif,
    required this.isPinned,
    required this.isMuted,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onArchive,
  });

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard> {
  bool _expanded = false;

  void _handleCardTap() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notif;
    final t = _typeOf(n.type);
    final style = _catStyles[t.cat]!;
    final title = (n.title?.trim().isNotEmpty ?? false) ? n.title! : t.defaultTitle;
    final body = (n.body?.trim().isNotEmpty ?? false) ? n.body! : t.defaultBody;
    final isUnread = !n.isRead;

    return Dismissible(
      key: ValueKey('dismiss_${n.id}'),
      direction: DismissDirection.horizontal,
      background: const _SwipeBackground(
        alignment: Alignment.centerRight,
        color: _Palette.success,
        icon: Icons.archive_rounded,
        label: 'ئارشیف',
      ),
      secondaryBackground: const _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: _Palette.error,
        icon: Icons.delete_rounded,
        label: 'سڕینەوە',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          widget.onDelete();
        } else {
          widget.onArchive();
        }
        return true;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleCardTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(14),
          splashColor: _Palette.primary.withOpacity(0.04),
          highlightColor: _Palette.primary.withOpacity(0.02),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isUnread ? _Palette.unreadBg : _Palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUnread ? const Color(0xFFD6E4FF) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.03),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── جێگیرکردنی قەبارەی ئایکۆن بەبێ تێکچوون ──
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: style.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(t.icon, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (widget.isPinned)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.push_pin_rounded,
                                  size: 11, color: _Palette.warning),
                            ),
                          if (widget.isMuted)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.notifications_off_rounded,
                                  size: 11, color: _Palette.textSecondary),
                            ),
                          Expanded(
                            child: ProxoText(
                              title,
                              maxLines: _expanded ? null : 1,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: kAppFont,
                                fontSize: 13.5,
                                fontWeight:
                                    isUnread ? FontWeight.w700 : FontWeight.w600,
                                color: _Palette.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: _Palette.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ProxoText(
                        body,
                        maxLines: _expanded ? null : 1,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 11.5,
                          color: _Palette.textSecondary,
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          ProxoText(
                            _timeAgo(n.createdAt),
                            style: const TextStyle(
                              fontFamily: kAppFont,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                              color: _Palette.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 2.5,
                            height: 2.5,
                            decoration: const BoxDecoration(
                              color: _Palette.divider,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          ProxoText(
                            _formatKurdishTime(n.createdAt),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: kAppFont,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                              color: _Palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SwipeBackground
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          ProxoText(
            label,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SkeletonCard
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final base = Color.lerp(
            const Color(0xFFEDEFF3), const Color(0xFFF6F7F9), t)!;
        return Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: base, borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 12,
                      width: 130,
                      decoration: BoxDecoration(
                          color: base, borderRadius: BorderRadius.circular(5)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: base, borderRadius: BorderRadius.circular(5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionTile
// ─────────────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ProxoText(
                label,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _Palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterSheet
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final _FilterCategory selectedCategory;
  final _FilterDate selectedDate;
  final void Function(_FilterCategory, _FilterDate) onApply;

  const _FilterSheet({
    required this.selectedCategory,
    required this.selectedDate,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterCategory _cat;
  late _FilterDate _date;

  @override
  void initState() {
    super.initState();
    _cat = widget.selectedCategory;
    _date = widget.selectedDate;
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _Palette.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ProxoText(
          label,
          style: TextStyle(
            fontFamily: kAppFont,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _Palette.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: _Palette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _Palette.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ProxoText(
                      'فلتەر',
                      style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _Palette.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _cat = _FilterCategory.all;
                        _date = _FilterDate.all;
                      }),
                      child: const ProxoText(
                        'پاک بکەرەوە',
                        style: TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 12,
                          color: _Palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ProxoText(
                  'جۆر',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _Palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _FilterCategory.values.map((cat) {
                    return _chip(_categoryLabels[cat]!, _cat == cat, () {
                      HapticFeedback.selectionClick();
                      setState(() => _cat = cat);
                    });
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const ProxoText(
                  'بەروار',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _Palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _FilterDate.values.map((d) {
                    return _chip(_dateLabels[d]!, _date == d, () {
                      HapticFeedback.selectionClick();
                      setState(() => _date = d);
                    });
                  }).toList(),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    widget.onApply(_cat, _date);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _Palette.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const ProxoText(
                      'جێبەجێ بکە',
                      style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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
}
