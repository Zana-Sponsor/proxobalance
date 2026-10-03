import 'package:flutter/material.dart';
import '../controllers/proxo_card_controller.dart';
import '../models/proxo_card.dart';
import '../widgets/html_preview_sheet.dart';
import '../widgets/proxo_toast.dart';
import '../widgets/proxo_error_ui.dart';
import '../theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

class ProxoCardsListScreen extends StatefulWidget {
  final VoidCallback? onCreateTap;
  const ProxoCardsListScreen({super.key, this.onCreateTap});
  @override State<ProxoCardsListScreen> createState() => _ProxoCardsListScreenState();
}

class _ProxoCardsListScreenState extends State<ProxoCardsListScreen> {
  final _ctrl = ProxoCardController();

  static const _ink   = AppColors.ink;
  static const _bg    = AppColors.page;
  static const _muted = AppColors.inkMuted;
  static const _bord  = Color(0xFFEAECF2);
  static const _red   = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _ctrl.fetchCards();
    _ctrl.addListener(() { if (mounted) setState(() {}); });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  /// ⚠ پێشبینین ئێستا **ناوەکی**یە، نەک دەرەکی.
  ///
  /// پێشتر HTMLـەکە دەنووسرایە فایلێکی کاتی و بە `FileProvider`ـەوە
  /// دەدرا بە وێبگەڕی مۆبایلەکە. ئەوە هەڵبژێرەری ئەپی ئەندرۆیدی
  /// دەکردەوە، کە ئەدیتەری کۆدیشی تێدابوو — بۆیە بەکارهێنەر دەیتوانی
  /// سەرچاوەی خاو ببینێت و دەستکاری بکات.
  ///
  /// هەمان ڕێڕەوی شاشەی ئامرازەکان بەکاردەهێنێت.
  Future<void> _openPreview(ProxoCard card) async {
    final ok = await HtmlPreviewSheet.open(
      context,
      html: card.htmlContent,
      title: card.name,
    );
    if (!ok && mounted) {
      showProxoToast(context, 'ناوەڕۆکی ئەم کارتە بەردەست نییە',
          type: ProxoToastType.error);
    }
  }

  Future<void> _confirmDelete(ProxoCard card) async {
    final cardName = card.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white,
          title: const ProxoText('سڕینەوەی کەرەستە',
              style: TextStyle(fontFamily: kAppFont, fontSize: 15,
                  fontWeight: FontWeight.w700, color: _ink)),
          content: ProxoText('دڵنیای؟  "$cardName"  دەسڕیتەوە.',
              style: const TextStyle(fontFamily: kAppFont, fontSize: 13,
                  color: _muted, height: 1.35)),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const ProxoText('پاشگەزبوونەوە',
                    style: TextStyle(fontFamily: kAppFont, color: _muted,
                        fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: const ProxoText('سڕینەوە',
                    style: TextStyle(fontFamily: kAppFont, color: _red,
                        fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      final res = await _ctrl.deleteCard(card.id);
      if (!res && mounted) {
        // `_ctrl.error` holds the exception string — useful in the log, never
        // on screen. The wording the user sees belongs to this screen, which
        // knows the failure was a delete.
        debugPrint('ProxoCardsList: delete failed: ${_ctrl.error}');
        showProxoToast(context, 'سڕینەوەی کارتەکە سەرنەکەوت — دووبارە هەوڵ بدەرەوە',
          type: ProxoToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(children: [
          _Header(onCreateTap: widget.onCreateTap),
          Expanded(
            child: _ctrl.loading
                ? const Center(child: CircularProgressIndicator(
                    color: _ink, strokeWidth: 2))
                : _ctrl.error != null
                    ? _ErrorState(error: _ctrl.error!, onRetry: _ctrl.fetchCards)
                    : _ctrl.cards.isEmpty
                        ? _EmptyState(onCreate: widget.onCreateTap)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                            itemCount: _ctrl.cards.length,
                            itemBuilder: (_, i) => _CardRow(
                              card: _ctrl.cards[i],
                              onPreview: () => _openPreview(_ctrl.cards[i]),
                              onDelete:  () => _confirmDelete(_ctrl.cards[i]),
                            ),
                          ),
          ),
        ]),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback? onCreateTap;
  const _Header({this.onCreateTap});
  static const _ink = AppColors.ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceCard,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border(bottom: BorderSide(color: Color(0xFFEAECF2))),
          ),
          child: Row(children: [
            // + نوێ pill
            GestureDetector(
              onTap: onCreateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _ink, borderRadius: BorderRadius.circular(22)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 5),
                  ProxoText('نوێ', style: TextStyle(fontFamily: kAppFont, fontSize: 12,
                      // Was Bold — an ordinary "create" pill, not a rare/
                      // high-priority moment.
                      fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ),
            const Spacer(),
            // Title
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
              ProxoText('کەرەستەی پەیوەندی', style: TextStyle(fontFamily: kAppFont,
                  fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
              SizedBox(height: 1),
              ProxoText('ProxoLink Cards', style: TextStyle(fontFamily: kAppFont,
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
            ]),
            const SizedBox(width: 10),
            // Icon btn
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.link_rounded, color: Colors.white, size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Card Row ───────────────────────────────────────────────────
class _CardRow extends StatelessWidget {
  final ProxoCard card;
  final VoidCallback onPreview;
  final VoidCallback onDelete;
  static const _ink   = AppColors.ink;
  static const _muted = AppColors.inkMuted;
  static const _bord  = Color(0xFFEAECF2);
  static const _red   = Color(0xFFDC2626);
  const _CardRow({required this.card, required this.onPreview, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final init = card.name.isNotEmpty ? card.name[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bord),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(color: _ink, shape: BoxShape.circle),
          child: Center(child: ProxoText(init, style: const TextStyle(fontFamily: kAppFont,
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 11),
        // Name + chips
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProxoText(card.name, style: const TextStyle(fontFamily: kAppFont, fontSize: 14,
              fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 4),
          Row(children: [
            _Chip(card.style, dark: true),
            const SizedBox(width: 4),
            _Chip(card.colorTheme),
          ]),
        ])),
        // Buttons
        _Btn(icon: Icons.remove_red_eye_outlined, color: _ink, onTap: onPreview),
        const SizedBox(width: 7),
        _Btn(icon: Icons.delete_outline_rounded, color: _red,
            bg: const Color(0x0BDC2626), border: const Color(0x33DC2626),
            onTap: onDelete),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool dark;
  const _Chip(this.label, {this.dark = false});
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? AppColors.ink : const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(20)),
      // Was 9/Bold — below the smallest defined role (11.5) with no fixed-
      // size container forcing it; the chip has no hard-coded height, so it
      // grows with the text instead of clipping.
      child: ProxoText(label, style: TextStyle(fontFamily: kAppFont, fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : AppColors.inkMuted)),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final Color color;
  final Color? bg, border; final VoidCallback onTap;
  const _Btn({required this.icon, required this.color, this.bg, this.border, required this.onTap});
  @override Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border ?? const Color(0xFFEAECF2))),
      child: Icon(icon, size: 15, color: color),
    ));
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback? onCreate;
  const _EmptyState({this.onCreate});
  static const _ink = AppColors.ink;
  @override Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.link_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 18),
        const ProxoText('هیچ کەرەستەیەک نییە', style: TextStyle(fontFamily: kAppFont,
            fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 7),
        const ProxoText('بەکەم کلیک کارتی پەیوەندیت دروستبکە.', style: TextStyle(
            fontFamily: kAppFont, fontSize: 12, color: AppColors.inkMuted, height: 1.35),
            textAlign: TextAlign.center),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: onCreate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(14)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 16),
              SizedBox(width: 7),
              ProxoText('دروستبکە', style: TextStyle(fontFamily: kAppFont, fontSize: 13,
                  fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    ));
  }
}

// ── Error state ────────────────────────────────────────────────
// Loading the card list failed. The `error` string the controller captured is
// deliberately not shown — it is a Postgrest/Socket exception, which tells the
// user nothing. This screen supplies its own wording instead, and keeps the
// controller's own retry entry point.
class _ErrorState extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});
  @override Widget build(BuildContext context) {
    debugPrint('ProxoCardsList: load failed: $error');
    final bool offline = error.contains('SocketException') ||
        error.contains('ClientException') ||
        error.contains('Failed host lookup');
    return ProxoErrorView(
      tone: offline ? ProxoErrorTone.offline : ProxoErrorTone.danger,
      title: offline ? 'ئینتەرنێت نییە' : 'کارتەکان بار نەبوون',
      message: offline
          ? 'ئینتەرنێتەکەت بپشکنەوە و دووبارە هەوڵ بدەرەوە'
          : 'نەتوانرا لیستی کارتەکانت بار بکرێت.\nتکایە دووبارە هەوڵ بدەرەوە.',
      actionLabel: 'دووبارە هەوڵبدە',
      onAction: onRetry,
    );
  }
}
