// lib/widgets/levels_page.dart
// ─────────────────────────────────────────────────────────────────────────────
// LevelsPage — ئاستەکان
// Shows all reward levels, user's current level, points, and progress bar
// toward the next level. Fetches from pa_levels + pa_user_points.
//
// ── Realtime sync ────────────────────────────────────────────────────────────
// Subscribes to pa_user_points via Supabase Realtime.
// When admin changes the user's points from the panel, the page updates
// automatically without any manual refresh — level, progress bar and
// points badge all animate to the new values within seconds.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../main.dart' show supabase;
import 'proxo_toast.dart';

class LevelsPage extends StatefulWidget {
  const LevelsPage({super.key});

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _levels = [];
  double _userPoints = 0;
  bool _loading = true;

  // ── Realtime ──────────────────────────────────────────────────────────────
  RealtimeChannel? _channel;
  bool _syncing = false; // نمایش ئینڤیکتەری بچووک کاتی نوێبوونەوە

  // ── Fallback safety net ────────────────────────────────────────────────────
  // ئەگەر Realtime کارنەکات (publication چالاک نەبووبێت، RLS ڕێگری
  // بکات، یان channel بپچڕێت)، ئەم Timer-ە خۆی هەموو 12 چرکە
  // پشکنین دەکات تا خاڵ هەرگیز کۆن نەمێنێتەوە.
  Timer? _fallbackPoll;
  bool _realtimeConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _subscribeRealtime();
    _fallbackPoll = Timer.periodic(const Duration(seconds: 12), (_) {
      // تەنها کاتێک Realtime دیاریکراو نییە یان دانەمەزراوە پشکنین بکە
      if (!_realtimeConnected) _silentRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _fallbackPoll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // کاتێک ئەپ دەگەڕێتەوە پێش (resume)، ڕاستەوخۆ خاڵی ڕاستەقینە بهێنەرەوە
    // ئەمە دڵنیایی زیادە ئەگەر Realtime لە background پچڕابوو
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  // ── Realtime subscription to pa_user_points ───────────────────────────────
  // کاتێک ئادمین لە پانێڵەوە خاڵ گۆڕی، هەردووکی INSERT و UPDATE
  // یەکسەر دەگاتە ئەمەوە و بەبێ لۆدینگ نوێ دەبێتەوە.
  void _subscribeRealtime() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _channel = supabase
        .channel('levels_page_user_points_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pa_user_points',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // خاڵی نوێ ڕاستەوخۆ لە payload بخوێنەوە (بەبێ کۆڵ زیادە)
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final newPts = (newRecord['points'] as num?)?.toDouble();
              if (newPts != null && mounted) {
                final oldLevel = _currentLevel?['id'];
                setState(() {
                  _userPoints = newPts;
                  _syncing = true;
                });
                // ئەگەر ئاست گۆڕدرا تۆستی خۆش نیشان بدە
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final newLevel = _currentLevel;
                  if (newLevel != null && newLevel['id'] != oldLevel) {
                    showProxoToast(
                      context,
                      '🎉 ئاستت گۆڕدرا: ${newLevel['name_ku'] ?? ''}',
                      type: ProxoToastType.success,
                    );
                  }
                  if (mounted) setState(() => _syncing = false);
                });
              }
            } else {
              // ئەگەر payload تازە نەبوو، کۆڵی سادە بکە
              _silentRefresh();
            }
          },
        )
        .subscribe((status, [error]) {
          // ── چاودێری دۆخی پەیوەندی Realtime ───────────────────────────
          // ئەگەر subscribe سەرکەوتوو نەبوو (channel_error, timed_out,
          // closed) واتە Realtime دانەمەزراوە یان RLS ڕێگری دەکات —
          // لەم حاڵەتەدا fallback polling چالاک دەبێت خۆکار.
          if (!mounted) return;
          _realtimeConnected = status == RealtimeSubscribeStatus.subscribed;
          if (!_realtimeConnected) {
            // یەکسەر جارێک هەوڵ بدە خاڵی ڕاستەقینە بهێنیت
            _silentRefresh();
          }
        });
  }

  // ── Silent refresh (خاڵ تازەکردنەوە بەبێ لۆدینگ ستیمێر) ──────────────────
  Future<void> _silentRefresh() async {
    if (!mounted) return;
    setState(() => _syncing = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final row = await supabase
          .from('pa_user_points')
          .select('points')
          .eq('user_id', userId)
          .maybeSingle();
      final pts = (row?['points'] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() => _userPoints = pts);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ── Full load (levels + points) ───────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      final levels = await supabase
          .from('pa_levels')
          .select()
          .order('level_number', ascending: true);

      final pointsRow = await supabase
          .from('pa_user_points')
          .select('points')
          .eq('user_id', userId)
          .maybeSingle();

      final userPoints = (pointsRow?['points'] as num?)?.toDouble() ?? 0;

      if (mounted) {
        setState(() {
          _levels = (levels as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _userPoints = userPoints;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('LevelsPage: load failed: $e');
      if (mounted) {
        setState(() => _loading = false);
        showProxoToast(context, 'ئاستەکان بار نەبوون — دووبارە هەوڵ بدەرەوە',
            type: ProxoToastType.error);
      }
    }
  }

  // ── Level helpers ─────────────────────────────────────────────────────────

  // Compute current level (highest min_points that is <= userPoints)
  // NOTE: intentionally order-independent — does not assume _levels is sorted.
  Map<String, dynamic>? get _currentLevel {
    Map<String, dynamic>? current;
    double? currentMin;
    for (final lvl in _levels) {
      final minPts = (lvl['min_points'] as num?)?.toDouble() ?? 0;
      if (minPts <= _userPoints && (currentMin == null || minPts > currentMin)) {
        current = lvl;
        currentMin = minPts;
      }
    }
    if (current != null) return current;
    if (_levels.isEmpty) return null;
    // fallback: lowest level (e.g. user has fewer points than any threshold)
    return _levels.reduce((a, b) {
      final aMin = (a['min_points'] as num?)?.toDouble() ?? 0;
      final bMin = (b['min_points'] as num?)?.toDouble() ?? 0;
      return aMin <= bMin ? a : b;
    });
  }

  // Compute next level (lowest min_points that is still > userPoints)
  Map<String, dynamic>? get _nextLevel {
    Map<String, dynamic>? next;
    double? nextMin;
    for (final lvl in _levels) {
      final minPts = (lvl['min_points'] as num?)?.toDouble() ?? 0;
      if (minPts > _userPoints && (nextMin == null || minPts < nextMin)) {
        next = lvl;
        nextMin = minPts;
      }
    }
    return next; // null = at max level
  }

  double get _progressToNextLevel {
    final cur = _currentLevel;
    final next = _nextLevel;
    if (cur == null || next == null) return 1.0;
    final curMin = (cur['min_points'] as num?)?.toDouble() ?? 0;
    final nextMin = (next['min_points'] as num?)?.toDouble() ?? 1;
    return ((_userPoints - curMin) / (nextMin - curMin)).clamp(0.0, 1.0);
  }

  // Map icon string from DB -> FontAwesomeIcons
  FaIconData _iconForString(String? iconStr) {
    switch (iconStr?.toLowerCase()) {
      case 'medal':   return FontAwesomeIcons.medal;
      case 'award':   return FontAwesomeIcons.award;
      case 'crown':   return FontAwesomeIcons.crown;
      case 'gem':     return FontAwesomeIcons.gem;
      case 'diamond': return FontAwesomeIcons.gem;
      default:        return FontAwesomeIcons.star;
    }
  }

  // Parse hex color string (#RRGGBB or RRGGBB) to Color
  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.dark;
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return AppColors.dark;
  }

  bool _isCurrentLevel(Map<String, dynamic> lvl) =>
      _currentLevel?['id'] == lvl['id'];

  bool _isAchieved(Map<String, dynamic> lvl) {
    final minPts = (lvl['min_points'] as num?)?.toDouble() ?? 0;
    return _userPoints >= minPts;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.bg, shape: BoxShape.circle,
              border: Border.all(color: AppColors.border)),
            child: const Center(
              child: FaIcon(FontAwesomeIcons.chevronRight, size: 14,
                color: AppColors.muted))),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('ئاستەکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // AppBar-title role: SemiBold, not Bold
            style: TextStyle(fontFamily: kAppFont, fontSize: 16,
              fontWeight: FontWeight.w600, color: AppColors.dark,
              height: 1.16,
              decoration: TextDecoration.none))),

        // ── Realtime sync indicator ──────────────────────────────────────
        // کاتی نوێبوونەوە: سپینەری بچووک. کاتی ئاسایشی: ئایکۆنی ئارەنجی
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _syncing
              ? const SizedBox(
                  key: ValueKey('spin'),
                  width: 36, height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFF97316)))))
              : Container(
                  key: const ValueKey('icon'),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    shape: BoxShape.circle),
                  child: const Center(
                    child: FaIcon(FontAwesomeIcons.layerGroup, size: 15,
                      color: Color(0xFFF97316)))),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.dark, strokeWidth: 2));
    }

    if (_levels.isEmpty) {
      return const Center(
        child: Text('هیچ ئاستێک بەردەست نییە',
          style: TextStyle(fontFamily: kAppFont, fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.muted, height: 1.30,
            decoration: TextDecoration.none)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.dark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 20),
          const Text('هەموو ئاستەکان',
            style: TextStyle(fontFamily: kAppFont, fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.muted,
              decoration: TextDecoration.none)),
          const SizedBox(height: 10),
          ..._levels.map((lvl) => _levelCard(lvl)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    final cur = _currentLevel;
    final next = _nextLevel;
    if (cur == null) return const SizedBox.shrink();

    final levelColor = _parseColor(cur['color'] as String?);
    final levelIcon  = _iconForString(cur['icon'] as String?);
    final levelName  = cur['name_ku']?.toString() ?? '';
    final isMax      = next == null;
    final progress   = _progressToNextLevel;
    final pointsToNext = isMax
        ? 0
        : ((next!['min_points'] as num?)?.toDouble() ?? 0) - _userPoints;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: AppColors.dark.withOpacity(0.28),
          blurRadius: 18, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Level icon + name row
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: levelColor.withOpacity(0.4), width: 1.5)),
            child: Center(
              child: FaIcon(levelIcon, size: 22, color: levelColor))),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ئاستی ئێستا',
              style: TextStyle(fontFamily: kAppFont, fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Colors.white54, decoration: TextDecoration.none)),
            const SizedBox(height: 2),
            Text(levelName,
              style: TextStyle(fontFamily: kAppFont, fontSize: 18,
                fontWeight: FontWeight.w700, color: levelColor,
                decoration: TextDecoration.none)),
          ]),
          const Spacer(),
          // Points badge — نیشانەی خاڵ بە AnimatedSwitcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  _userPoints.toInt().toString(),
                  key: ValueKey(_userPoints.toInt()),
                  style: const TextStyle(fontFamily: kAppFont, fontSize: 16,
                    fontWeight: FontWeight.w700, color: Colors.white,
                    decoration: TextDecoration.none)),
              ),
              const Text('خاڵ',
                style: TextStyle(fontFamily: kAppFont, fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.white60, decoration: TextDecoration.none)),
            ]),
          ),
        ]),

        const SizedBox(height: 18),

        // Progress bar — AnimatedContainer بۆ ئانیمەیشنی سادە
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: isMax ? 1.0 : progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor)))),

        const SizedBox(height: 10),

        // Progress label
        if (isMax)
          const Text('تۆ لە بەرزترین ئاستدایت! 🎉',
            style: TextStyle(fontFamily: kAppFont, fontSize: 12.5,
              fontWeight: FontWeight.w400, height: 1.16,
              color: Colors.white70, decoration: TextDecoration.none))
        else
          Text(
            '${pointsToNext.toInt()} خاڵ ماوە بۆ ${next!['name_ku']}',
            style: const TextStyle(fontFamily: kAppFont, fontSize: 12.5,
              fontWeight: FontWeight.w400, height: 1.16,
              color: Colors.white70, decoration: TextDecoration.none)),
      ]),
    );
  }

  // ── Individual level card ─────────────────────────────────────────────────

  Widget _levelCard(Map<String, dynamic> lvl) {
    final isCurrent  = _isCurrentLevel(lvl);
    final isAchieved = _isAchieved(lvl);
    final levelColor = _parseColor(lvl['color'] as String?);
    final levelIcon  = _iconForString(lvl['icon'] as String?);
    final levelName  = lvl['name_ku']?.toString() ?? '';
    final minPts     = (lvl['min_points'] as num?)?.toInt() ?? 0;
    final discPct    = (lvl['discount_percent'] as num?)?.toDouble() ?? 0;
    final discIqd    = (lvl['discount_iqd'] as num?)?.toInt() ?? 0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isAchieved ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? levelColor.withOpacity(0.6)
                : AppColors.border,
            width: isCurrent ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))
          ]),
        child: Row(children: [
          // Level icon circle
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: levelColor.withOpacity(0.3))),
            child: Center(
              child: FaIcon(levelIcon, size: 18, color: levelColor))),

          const SizedBox(width: 12),

          // Name + min points
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Was a bare Text with no overflow protection; wrapped in
                // Flexible now that the adjacent badge is wider (11.5 vs the
                // old below-floor 9.5), so a long level name truncates
                // instead of overflowing the row on a narrow phone.
                Flexible(
                  child: Text(levelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: kAppFont, fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.dark,
                      decoration: TextDecoration.none)),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: levelColor.withOpacity(0.3))),
                    child: Text('ئاستی ئێستا',
                      // Was 9.5/Bold — below the caption floor, and an
                      // ordinary status tag rather than a rare/high-priority
                      // moment; the pill has no fixed height so it grows
                      // with the text instead of clipping.
                      style: TextStyle(fontFamily: kAppFont, fontSize: 11.5,
                        fontWeight: FontWeight.w600, color: levelColor,
                        decoration: TextDecoration.none))),
                ],
              ]),
              const SizedBox(height: 3),
              Text('$minPts خاڵ پێویستە',
                style: const TextStyle(fontFamily: kAppFont, fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted, decoration: TextDecoration.none)),
            ])),

          const SizedBox(width: 10),

          // Discount badge column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
            if (discPct > 0)
              _discountBadge('${discPct.toInt()}%', levelColor),
            if (discPct > 0 && discIqd > 0)
              const SizedBox(height: 4),
            if (discIqd > 0)
              _discountBadge('${discIqd.toString()} IQD', levelColor),
          ]),

          const SizedBox(width: 8),

          // Achieved indicator
          if (isAchieved)
            FaIcon(
              isCurrent
                  ? FontAwesomeIcons.solidCircleCheck
                  : FontAwesomeIcons.circleCheck,
              size: 18,
              color: isCurrent ? levelColor : const Color(0xFF22C55E))
          else
            const FaIcon(FontAwesomeIcons.lock, size: 16,
              color: AppColors.muted),
        ]),
      ),
    );
  }

  Widget _discountBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.25))),
      // Was 10.5/Bold — same fix as the reward badge in tasks_page.dart:
      // below the caption floor, and the pill has no fixed height so it
      // grows with the text instead of clipping.
      child: Text(text,
        style: TextStyle(fontFamily: kAppFont, fontSize: 11.5,
          fontWeight: FontWeight.w600, color: color,
          decoration: TextDecoration.none)));
  }
}
