import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/ad_detail_strings.dart';
import '../models/ad_receipt_data.dart';
import '../models/receipt_pricing.dart';
import '../main.dart' show supabase;
import '../theme/app_locale.dart';
import '../theme/app_theme.dart';
import '../widgets/receipt/ad_receipt_card.dart';
import '../widgets/receipt/receipt_kit.dart';

// ═════════════════════════════════════════════════════════════════════════════
// AdDetailScreen — پسوولەی ڕیکلام (Proxo Ad Detail — V2)
// ═════════════════════════════════════════════════════════════════════════════
//
// یەک کارتی سپی، گۆشەی چوارگۆشە، بێ سنوور:
//
//   پسوولەی ڕیکلام ················· [Proxo]
//   ─────────────
//   ئایدی ڕیکلام · ڕێکەوت
//   ─────────────
//   ئامانجی ڕیکلام   (تەمەن، ڕەگەز، شوێن، ئامێر، پۆل)
//   ─────────────
//   پوختە            (نرخی سەرەتایی، داشکاندن*، کۆی کۆتایی)
//   ─────────────
//   زانیاری پارەدان  (ڕێگای پارەدان)
//   ─────────────
//   ناوی ڕیکلام
//   ژ.م پسوولە       (pa_ads.id — UIDی تەواو)
//
//   [ داوڵۆند بکە بە PDF ]   ← دەرەوەی کارت
//
// * تەنها ئەگەر داشکاندن > 0 بێت؛ دەنا هیچ شوێنێک ناگرێت.
//
// هەموو ژمارەیەکی دیزاین لە `receipt_kit.dart`ـەوە دێت.
//
// ⚠ API ـی ئەم فایلە (adDetailsRoute، AdDetailsOutcome، kAdsTable،
// kAdDetailsSettleDelay، AdRepeatCallback) وەک خۆی ماوەتەوە، بۆیە
// `ad_screen.dart` هیچ گۆڕانکارییەکی ناوێت.
// ═════════════════════════════════════════════════════════════════════════════

// ── خشتە و کۆڵۆمەکان ─────────────────────────────────────────────────────────

const String kAdsTable = 'pa_ads';

/// تەنها ئەو کۆڵۆمانەی پسوولەکە پێویستیەتی.
const String _kAdColumns = 'id,public_ad_id,title,status,'
    'created_at,updated_at,thumbnail_url,needs_update,reject_reason,'
    'age_groups,target_age,gender,target_gender,location,target_location,'
    'device_type,category,payment_method,'
    'charged_price_iqd,payment_status,payment_transaction_id,'
    'pricing_ad_budget_iqd_snapshot,pricing_service_fee_iqd_snapshot,'
    'pricing_payment_method_snapshot,pricing_snapshot_at,'
    'pricing_total_iqd_snapshot,pricing_discount_iqd_snapshot,'
    'global_discount_iqd,direct_discount_iqd,level_discount_iqd';

/// کۆڵۆمانەی پێویستن بۆ ئەوەی ڕیزی لیست ڕاستەوخۆ پیشان بدرێت بەبێ
/// «پەڕینی» بەهاکان دوای بارکردن.
const List<String> _kRequiredForInstant = <String>[
  'id',
  'public_ad_id',
  'title',
  'created_at',
  'age_groups',
  'gender',
  'location',
  'device_type',
  'category',
  'payment_method',
  'payment_status',
  'payment_transaction_id',
  'pricing_ad_budget_iqd_snapshot',
  'pricing_service_fee_iqd_snapshot',
  'pricing_payment_method_snapshot',
  'pricing_snapshot_at',
  'charged_price_iqd',
  'pricing_total_iqd_snapshot',
  'pricing_discount_iqd_snapshot',
];

const Duration kAdDetailsSettleDelay = Duration(milliseconds: 260);

// ── API ـی لیست ─────────────────────────────────────────────────────────────

class AdDetailsOutcome {
  bool changed = false;

  void markChanged() => changed = true;
}

typedef AdRepeatCallback = void Function({
  required void Function() onLoading,
  required void Function() onDone,
});

/// ⚠ پارامەترەکانی `onShare`، `onRepeat`، `onCancel`، `onFix` بۆ
/// گونجاندن لەگەڵ `ad_screen.dart` وەردەگیرێن. دیزاینی V2 تەنها دوگمەی
/// PDF ـی هەیە، بۆیە ئەمانە لەم شاشەیەدا پیشان نادرێن.
Route<bool> adDetailsRoute({
  Map<String, dynamic>? ad,
  String? adId,
  AdDetailsOutcome? outcome,
  VoidCallback? onShare,
  AdRepeatCallback? onRepeat,
  VoidCallback? onCancel,
  VoidCallback? onFix,
  void Function(String text)? onCopyId,
}) {
  final String id = (adId ?? ad?['id'])?.toString().trim() ?? '';
  assert(id.isNotEmpty, 'adDetailsRoute: ئایدی ڕیکلام پێویستە');

  return ProxoPageRoute<bool>(
    settings: const RouteSettings(name: 'ad_details'),
    builder: (_) => AdDetailScreen(
      adId: id,
      initialAd: ad,
      outcome: outcome,
      onShare: onShare,
      onRepeat: onRepeat,
      onCancel: onCancel,
      onFix: onFix,
      onCopyId: onCopyId,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// پارس و فۆرمات
// ═════════════════════════════════════════════════════════════════════════════

String _str(dynamic v) => (v ?? '').toString().trim();

class AdDetailScreen extends StatefulWidget {
  final String adId;
  final Map<String, dynamic>? initialAd;
  final AdDetailsOutcome? outcome;
  final VoidCallback? onShare;
  final AdRepeatCallback? onRepeat;
  final VoidCallback? onCancel;
  final VoidCallback? onFix;
  final void Function(String text)? onCopyId;

  /// Optional data source for isolated widget tests and previews.
  /// Normal navigation uses the existing authenticated Supabase client.
  final Future<Map<String, dynamic>?> Function(String id)? loadAd;

  const AdDetailScreen({
    super.key,
    required this.adId,
    this.initialAd,
    this.outcome,
    this.onShare,
    this.onRepeat,
    this.onCancel,
    this.onFix,
    this.onCopyId,
    this.loadAd,
  });

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  final GlobalKey _receiptKey = GlobalKey(debugLabel: 'ad_receipt');

  Map<String, dynamic>? _ad;
  AdReceiptData? _receipt;
  String? _receiptLang;

  bool _loading = false;
  bool _notFound = false;
  bool _thumbnailRepairing = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    ProxoLocale.current.addListener(_onLocaleChanged);
    final Map<String, dynamic>? seed = widget.initialAd;
    if (seed != null &&
        _str(seed['id']).isNotEmpty &&
        _str(seed['id']) == widget.adId &&
        _kRequiredForInstant.every(seed.containsKey)) {
      _ad = Map<String, dynamic>.from(seed);
    }
    _loading = _ad == null;
    _load(silent: _ad != null);
  }

  void _onLocaleChanged() {
    setState(() => _receipt = null);
  }

  @override
  void didUpdateWidget(covariant AdDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adId != widget.adId) {
      _ad = null;
      _receipt = null;
      _receiptLang = null;
      _load();
    }
  }

  @override
  void dispose() {
    ++_requestVersion;
    ProxoLocale.current.removeListener(_onLocaleChanged);
    super.dispose();
  }

  // ── داتا ──────────────────────────────────────────────────────────────────

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    final int request = ++_requestVersion;
    if (!silent) {
      setState(() {
        _loading = true;
        _notFound = false;
      });
    }

    try {
      final loader = widget.loadAd;
      final dynamic res = loader != null
          ? await loader(widget.adId)
          : await supabase
              .from(kAdsTable)
              .select(_kAdColumns)
              .eq('id', widget.adId)
              .maybeSingle();
      if (!mounted || request != _requestVersion) return;

      if (res == null) {
        setState(() {
          _ad = null;
          _receipt = null;
          _receiptLang = null;
          _loading = false;
          _notFound = true;
        });
        widget.outcome?.markChanged();
        return;
      }

      final Map<String, dynamic> next = Map<String, dynamic>.from(
        res as Map<dynamic, dynamic>,
      );
      if (_str(next['id']).isEmpty || _str(next['id']) != widget.adId) {
        throw const FormatException('The receipt does not match the ad UID.');
      }
      // Optional receipt-only lookup. A zero-value ledger entry is not a payment.
      if (loader == null &&
          !ReceiptPricing.from(next).noPaymentRequired &&
          receiptText(next['payment_transaction_id']).isEmpty) {
        try {
          final transaction = await supabase
              .from('pa_transactions')
              .select('id,method,gateway')
              .eq('ad_id', widget.adId)
              .eq('type', 'ad_payment')
              .eq('status', 'approved')
              .gt('amount', 0)
              .order('created_at', ascending: true)
              .limit(1)
              .maybeSingle();
          if (transaction != null) {
            next['receipt_transaction_id'] = transaction['id'];
            next['receipt_payment_method'] =
                transaction['method'] ?? transaction['gateway'];
          }
        } catch (_) {
          // Missing optional payment information does not invalidate an ad.
        }
      }
      if (!mounted || request != _requestVersion) return;
      final Map<String, dynamic>? prev = _ad;

      setState(() {
        _ad = next;
        _receipt = null; // لە build دووبارە دروست دەکرێتەوە
        _loading = false;
        _notFound = false;
      });

      if (prev != null && _differs(prev, next)) {
        widget.outcome?.markChanged();
      }
      if (loader == null) unawaited(_repairThumbnailIfNeeded(next));
    } catch (e) {
      debugPrint('AdDetailScreen: load failed — $e');
      if (!mounted || request != _requestVersion) return;
      setState(() => _loading = false);
    }
  }

  bool _differs(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['status'] != b['status'] ||
      a['updated_at'] != b['updated_at'] ||
      a['needs_update'] != b['needs_update'] ||
      a['reject_reason'] != b['reject_reason'] ||
      a['thumbnail_url'] != b['thumbnail_url'];

  /// وێنۆچکە لەم شاشەیەدا پیشان نادرێت، بەڵام لیستی ڕیکلامەکان پێویستیەتی.
  /// هەمان Edge Function ـی پێشوو، بێدەنگ.
  Future<void> _repairThumbnailIfNeeded(Map<String, dynamic> ad) async {
    if (_thumbnailRepairing) return;
    final Uri? parsed = Uri.tryParse(_str(ad['thumbnail_url']));
    final bool hasThumb = parsed != null &&
        (parsed.scheme == 'https' || parsed.scheme == 'http') &&
        parsed.host.isNotEmpty;
    final String id = _str(ad['id']);
    if (hasThumb || id.isEmpty) return;

    _thumbnailRepairing = true;
    try {
      final response = await supabase.functions.invoke(
        'generate-ad-thumbnail',
        body: <String, dynamic>{'ad_id': id},
      );
      final dynamic data = response.data;
      final String url = data is Map ? _str(data['thumbnail_url']) : '';
      final Uri? u = Uri.tryParse(url);
      if (u != null && u.scheme == 'https' && u.host.isNotEmpty) {
        final Map<String, dynamic>? current = _ad;
        if (mounted && current != null && _str(current['id']) == id) {
          _ad = <String, dynamic>{...current, 'thumbnail_url': url};
        }
        widget.outcome?.markChanged();
      }
    } catch (error) {
      debugPrint('AdDetailScreen: thumbnail generation failed — $error');
    } finally {
      _thumbnailRepairing = false;
    }
  }

  // ── کردارەکان ─────────────────────────────────────────────────────────────

  void _back() => Navigator.of(context).pop(widget.outcome?.changed ?? false);

  Future<void> _copy(String text) async {
    final String raw = text.trim();
    if (raw.isEmpty || raw == '—') return;
    try {
      await Clipboard.setData(ClipboardData(text: raw));
      if (!mounted) return;
      unawaited(HapticFeedback.selectionClick());
      showReceiptMessage(context, AdDetailStrings.current.copied);
    } catch (_) {
      if (mounted) {
        showReceiptMessage(context, AdDetailStrings.current.copyFailed);
      }
    }
  }

  /// PDF = هەمان کارت (بڕوانە `exportReceiptPdf`).
  Future<void> _exportPdf(AdDetailStrings l) async {
    final bool ok = await exportReceiptPdf(
      boundaryKey: _receiptKey,
      title: l.receiptTitle,
      fileStem: _receipt?.adId ?? 'ad',
    );
    if (!ok && mounted) {
      showReceiptMessage(context, AdDetailStrings.current.pdfFailed);
    }
  }

  // ── بنیاتنان ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Locale locale = ProxoLocale.current.value;
    final AdDetailStrings l = AdDetailStrings.of(locale);
    final MediaQueryData mq = MediaQuery.of(context);

    // مۆدێلەکە تەنها کاتێک دووبارە دروست دەکرێت کە داتا یان زمان بگۆڕێت.
    final Map<String, dynamic>? ad = _ad;
    if (ad != null &&
        (_receipt == null || _receiptLang != locale.languageCode)) {
      _receipt = AdReceiptData.from(ad, l);
      _receiptLang = locale.languageCode;
    }

    return Directionality(
      // کوردی و عەرەبی هەردووکیان RTL ن.
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: mq,
        child: Scaffold(
          backgroundColor: ReceiptTokens.page,
          body: Column(
            children: <Widget>[
              ReceiptAppBar(title: l.appBarTitle, onBack: _back),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: _buildBody(l),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AdDetailStrings l) {
    final AdReceiptData? r = _receipt;

    if (r == null && _loading) return const ReceiptSpinner();

    if (r == null && _notFound) {
      return ReceiptStateView(
        title: l.notFoundTitle,
        message: l.notFoundBody,
        actionLabel: l.back,
        onAction: _back,
      );
    }

    if (r == null) {
      return ReceiptStateView(
        title: l.loadErrorTitle,
        message: l.loadErrorBody,
        actionLabel: l.retry,
        onAction: () => _load(),
      );
    }

    return ReceiptBody(
      children: <Widget>[
        RepaintBoundary(
          key: _receiptKey,
          child: ReceiptSurface(
            child: AdReceiptCard(r: r, l: l, onCopy: (String v) => _copy(v)),
          ),
        ),
        _fullWidth(
          ReceiptPdfButton(label: l.pdfButton, onPressed: () => _exportPdf(l)),
        ),
      ],
    );
  }

  Widget _fullWidth(Widget child) => ReceiptWidth(child: child);
}
