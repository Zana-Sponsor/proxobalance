// lib/widgets/tasks_page.dart
// ─────────────────────────────────────────────────────────────────────────────
// TasksPage — ئەرکەکان
// Shows active challenges fetched from Supabase pa_challenges +
// pa_challenge_progress, with claim-reward flow.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../main.dart' show supabase;
import 'proxo_toast.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Map<String, dynamic>> _challenges = [];
  Map<String, Map<String, dynamic>> _progressMap = {};
  bool _loading = true;
  Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      final challenges = await supabase
          .from('pa_challenges')
          .select()
          .eq('is_active', true)
          .order('created_at');

      final progressRows = await supabase
          .from('pa_challenge_progress')
          .select()
          .eq('user_id', userId);

      final map = <String, Map<String, dynamic>>{};
      for (final row in (progressRows as List)) {
        final r = Map<String, dynamic>.from(row as Map);
        map[r['challenge_id'] as String] = r;
      }

      if (mounted) {
        setState(() {
          _challenges = (challenges as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _progressMap = map;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('TasksPage: load failed: $e');
      if (mounted) {
        setState(() => _loading = false);
        showProxoToast(context, 'ئەرکەکان بار نەبوون — دووبارە هەوڵ بدەرەوە',
            type: ProxoToastType.error);
      }
    }
  }

  Future<void> _claimReward(Map<String, dynamic> challenge) async {
    final challengeId = challenge['id'] as String;
    if (_claiming.contains(challengeId)) return;

    setState(() => _claiming.add(challengeId));
    try {
      final raw = await supabase.rpc('pa_claim_challenge', params: {
        'p_challenge_id': challengeId,
      });
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] != true) {
        final message = switch ((result['code'] ?? '').toString()) {
          'ALREADY_CLAIMED' => 'ئەم خەڵاتە پێشتر وەرگیراوە',
          'NOT_COMPLETED' => 'ئەرکەکە هێشتا تەواو نەبووە',
          'CHALLENGE_UNAVAILABLE' => 'ئەم ئەرکە چیتر بەردەست نییە',
          _ => 'خەڵاتەکە وەرنەگیرا — دووبارە هەوڵ بدەرەوە',
        };
        throw Exception(message);
      }

      if (mounted) {
        showProxoToast(context, 'خەڵاتەکەت وەرگیرا! 🎉',
            type: ProxoToastType.success);
      }

      await _load();
    } catch (e) {
      debugPrint('TasksPage: claim reward failed: $e');
      if (mounted) {
        showProxoToast(context, 'خەڵاتەکە وەرنەگیرا — دووبارە هەوڵ بدەرەوە',
            type: ProxoToastType.error);
      }
    } finally {
      if (mounted) setState(() => _claiming.remove(challengeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(children: [
            // ── Header
            _buildHeader(),
            // ── Body
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
        Expanded(
          child: Text('ئەرکەکان',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // AppBar-title role: SemiBold, not Bold
            style: AppTypography.appBarTitle(color: AppColors.dark))),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            shape: BoxShape.circle),
          child: const Center(
            child: FaIcon(FontAwesomeIcons.listCheck, size: 15,
              color: Color(0xFF8B5CF6)))),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.dark, strokeWidth: 2));
    }

    if (_challenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                shape: BoxShape.circle),
              child: const Center(
                child: FaIcon(FontAwesomeIcons.listCheck, size: 28,
                  color: Color(0xFF8B5CF6)))),
            const SizedBox(height: 16),
            Text('هیچ ئەرکێکی چالاک نییە ئێستا',
              style: AppTypography.body(color: AppColors.muted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.dark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
        itemCount: _challenges.length,
        itemBuilder: (_, i) => _challengeCard(_challenges[i]),
      ),
    );
  }

  Widget _challengeCard(Map<String, dynamic> challenge) {
    final challengeId = challenge['id'] as String;
    final title = challenge['title']?.toString() ?? '';
    final description = challenge['description']?.toString() ?? '';
    final goalType = challenge['goal_type']?.toString() ?? 'ads_count';
    final goalValue = (challenge['goal_value'] as num?)?.toDouble() ?? 1;
    final rewardPoints = (challenge['reward_points'] as num?)?.toDouble() ?? 0;
    final rewardIqd = (challenge['reward_iqd'] as num?)?.toDouble() ?? 0;

    final progressRow = _progressMap[challengeId];
    final userProgress = (progressRow?['progress'] as num?)?.toDouble() ?? 0;
    final claimed = progressRow?['claimed'] == true;
    final completed = userProgress >= goalValue;

    final progressFraction = (goalValue > 0
        ? (userProgress / goalValue).clamp(0.0, 1.0)
        : 0.0);

    final isClaiming = _claiming.contains(challengeId);

    // Goal label
    String goalLabel;
    if (goalType == 'ads_count') {
      goalLabel =
          '${userProgress.toInt()} لە ${goalValue.toInt()} ڕیکلام';
    } else {
      goalLabel =
          '${userProgress.toStringAsFixed(1)} لە ${goalValue.toStringAsFixed(1)} دۆلار خەرجکراو';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))
        ]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Title row + reward badges
          Row(children: [
            Expanded(
              child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // cardTitle role: SemiBold, not Bold
                style: AppTypography.cardTitle(color: AppColors.dark))),
            // Reward badges
            if (rewardPoints > 0)
              _rewardBadge(
                '${rewardPoints.toInt()} خاڵ',
                const Color(0xFF8B5CF6)),
            if (rewardPoints > 0 && rewardIqd > 0)
              const SizedBox(width: 6),
            if (rewardIqd > 0)
              _rewardBadge(
                '${rewardIqd.toInt()} IQD',
                const Color(0xFF22C55E)),
          ]),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description,
              style: const TextStyle(fontFamily: kAppFont, fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.muted,
                height: 1.35, // was 1.6, above the multiline band's ceiling
                decoration: TextDecoration.none)),
          ],

          const SizedBox(height: 14),

          // ── Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 7,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                completed
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF8B5CF6)))),

          const SizedBox(height: 8),

          // ── Goal label
          Text(goalLabel,
            style: AppTypography.caption(color: AppColors.muted)),

          // ── Claim button
          if (completed && !claimed) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: isClaiming ? null : () => _claimReward(challenge),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isClaiming
                      ? AppColors.dark.withOpacity(0.5)
                      : AppColors.dark,
                  borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: isClaiming
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : Text('وەرگرتنی خەڵات',
                          // button role: SemiBold, not Bold
                          style: AppTypography.button(
                              color: Colors.white, size: 13)))),
            ),
          ],

          if (claimed) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF22C55E).withOpacity(0.3))),
              child: const Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  FaIcon(FontAwesomeIcons.circleCheck, size: 14,
                    color: Color(0xFF22C55E)),
                  SizedBox(width: 6),
                  Text('خەڵاتەکەت وەرگیرا',
                    style: TextStyle(fontFamily: kAppFont, fontSize: 13,
                      // was Bold — routine positive feedback, not a rare/
                      // blocking moment
                      fontWeight: FontWeight.w600, color: Color(0xFF22C55E),
                      decoration: TextDecoration.none)),
                ])),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _rewardBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25))),
      // Was 11/Bold — below the caption floor (11.5) with no fixed-size
      // container forcing it; the badge has no hard-coded height, so it
      // grows with the text instead of clipping (same fix as the
      // ProxoLink chip in proxo_cards_list_screen.dart).
      child: Text(text,
        style: AppTypography.caption(color: color, weight: FontWeight.w600)));
  }
}
