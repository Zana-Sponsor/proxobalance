// lib/widgets/discount_codes_page.dart
// ─────────────────────────────────────────────────────────────────────────────
// DiscountCodesPage — part of proxo_sidebar.dart
// Lists codes from the existing `promo_codes` table that are active,
// unexpired, and either global or restricted to the current user.
// No new tables/columns — reads only what's already in the schema.
// ─────────────────────────────────────────────────────────────────────────────

part of 'proxo_sidebar.dart';

class DiscountCodesPage extends StatefulWidget {
  const DiscountCodesPage({super.key});

  @override
  State<DiscountCodesPage> createState() => _DiscountCodesPageState();
}

class _PromoCode {
  final String code;
  final String discountType; // 'percentage' | 'fixed'
  final double discountValue;
  final int discountIqd;
  final DateTime? expiresAt;
  final String? description;
  final int maxUses;
  final int usedCount;

  _PromoCode({
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountIqd,
    required this.expiresAt,
    required this.description,
    required this.maxUses,
    required this.usedCount,
  });

  factory _PromoCode.fromMap(Map<String, dynamic> m) => _PromoCode(
        code: (m['code'] ?? '').toString(),
        discountType: (m['discount_type'] ?? 'percentage').toString(),
        discountValue: (m['discount_value'] as num?)?.toDouble() ?? 0,
        discountIqd: (m['discount_iqd'] as num?)?.toInt() ?? 0,
        expiresAt: m['expires_at'] != null ? DateTime.tryParse(m['expires_at'].toString()) : null,
        description: m['description']?.toString(),
        maxUses: (m['max_uses'] as num?)?.toInt() ?? 1,
        usedCount: (m['used_count'] as num?)?.toInt() ?? 0,
      );

  bool get isExhausted => usedCount >= maxUses;
}

class _DiscountCodesPageState extends State<DiscountCodesPage> {
  bool _loading = true;
  /// Separates a genuinely empty code list from a failed fetch.
  bool _loadFailed = false;
  List<_PromoCode> _codes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      final rows = await supabase
          .from('promo_codes')
          .select('code, discount_type, discount_value, discount_iqd, expires_at, '
              'description, max_uses, used_count, is_active, restricted_to_user_id')
          .eq('is_active', true)
          .or('restricted_to_user_id.is.null,restricted_to_user_id.eq.$uid')
          .order('created_at', ascending: false);

      final now = DateTime.now();
      final list = (rows as List)
          .map((m) => _PromoCode.fromMap(m as Map<String, dynamic>))
          .where((c) => c.expiresAt == null || c.expiresAt!.isAfter(now))
          .where((c) => !c.isExhausted)
          .toList();

      if (mounted) setState(() { _codes = list; _loading = false; _loadFailed = false; });
    } catch (e) {
      debugPrint('DiscountCodes: load failed: $e');
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    // This page is LTR/English, so the shared snack is told as much.
    showProxoErrorSnack(
      context,
      'Copied "$code"',
      tone: ProxoErrorTone.success,
      label: 'Copied',
      duration: const Duration(seconds: 1),
      fontFamily: kAppFont,
      textDirection: TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.surfaceBase,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceCard,
          elevation: 0,
          foregroundColor: _kTextDark,
          title: ProxoText('Discount Codes',
            // AppBar title role → SemiBold, not Bold
            style: _kBase.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: _kTextDark)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_codes.isEmpty && _loadFailed)
                ? ProxoErrorView(
                    fontFamily: kAppFont,
                    title: "Couldn't load discount codes",
                    message: 'Check your connection and try again.',
                    actionLabel: 'Try again',
                    onAction: _load,
                  )
                : _codes.isEmpty
                ? Center(child: ProxoText('No discount codes available right now.',
                    style: _kBase.copyWith(fontSize: 13, color: _kTextMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _codes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = _codes[i];
                      final label = c.discountType == 'percentage'
                          ? '${c.discountValue.toStringAsFixed(0)}% off'
                          : '${c.discountIqd} IQD off';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kIconBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              ProxoText(c.code,
                                // card-title role → SemiBold, not Bold
                                style: _kBase.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark)),
                              const SizedBox(height: 3),
                              ProxoText(label,
                                style: _kBase.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: _kActiveBlue)),
                              if (c.description != null && c.description!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                ProxoText(c.description!,
                                  style: _kBase.copyWith(fontSize: 12, color: _kTextMuted)),
                              ],
                              if (c.expiresAt != null) ...[
                                const SizedBox(height: 3),
                                ProxoText('Expires ${c.expiresAt!.toLocal().toString().split(' ').first}',
                                  style: _kBase.copyWith(fontSize: 11.5, color: _kTextMuted)),
                              ],
                            ]),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _copy(c.code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: _kActiveBlue, borderRadius: BorderRadius.circular(10)),
                              child: ProxoText('Copy',
                                // button role: 13 (not 12.5) / SemiBold (not Bold)
                                style: _kBase.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
      ),
    );
  }
}
