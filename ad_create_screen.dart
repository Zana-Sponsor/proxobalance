import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:solar_iconkit/solar_iconkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/proxo_pricing.dart';
import '../services/ad_categories.dart';
import '../main.dart' show supabase;
import '../widgets/proxo_toast.dart';
import '../widgets/wave_overscroll.dart';

// ═════════════════════════════════════════════════════════════════════════════
// تۆکنەکانی ئەم شاشەیە — هەموویان ئەلیاسی سیستەمی هاوبەشن
// ═════════════════════════════════════════════════════════════════════════════
// ⚠ ئەم شاشەیە پێشتر لەسەر `AppColors`ی کۆن دەڕۆیشت:
//
//     AppColors.dark    #1C2333  ← دەق **و** پڕکەرەوەی توخمە چالاکەکان
//     AppColors.muted   #6E7787  ← لەیبڵی لاوەکی
//     AppColors.muted2  #6B7585  ← هەمان کار، تۆنێکی جیاواز
//     AppColors.border  #E8EAF0  ← سنوور
//
// دوو کێشە: (١) `dark` هەم وەک دەق و هەم وەک ڕەنگی سەرەکی بەکاردەهات،
// بۆیە دوگمەی ناردن و خانەی ئایکۆنەکان **ڕەشی شین‌باو** بوون نەک شینی
// سیستەم — واتە ئەم شاشەیە تاقە شوێن بوو کە ڕەنگی سەرەکی جیاوازی
// هەبوو. (٢) `muted`/`muted2` هەردووکیان لە ئاستی خوێندنەوەی گونجاو
// خوارتر بوون لەسەر #FAFAFA.
//
// ئێستا ڕۆڵەکان جیا کراونەتەوە: دەق `_cInk`/`_cSlate`، ڕەنگی سەرەکی
// `_cAccent`، ئایکۆن `_cIcon`.
const Color _cInk    = AdSurface.ink;    // #0B0B32 — ناونیشان و بەها
const Color _cSlate  = AdSurface.slate;  // #334155 — لەیبڵی لاوەکی
const Color _cIcon   = AdSurface.icon;   // #475569 — گلیفە لاوەکییەکان
const Color _cAccent = AdSurface.accent; // #0365FF — ڕەنگی سەرەکی
const Color _cCard   = AdSurface.card;   // سپی — ڕووی کارت و خانەکان
const Color _cPage   = AdSurface.page;   // #FAFAFA — پاشبنەمای شاشە
const Color _cLine   = AdSurface.border; // #E2E8F0 — هەموو سنوورەکان

/// ⚠ پڕکەرەوەی خانەکان. پێشتر `_cCard` (سپی) بوو، واتە خانەکە و
/// کارتەکەی ژێری هەمان ڕەنگیان هەبوو و تەنها سنوورەکە جیای دەکردنەوە.
/// تۆنێکی سووکی سلەیت وا دەکات خانەکە وەک شوێنێکی نووسین بخوێندرێتەوە.
const Color _cFieldFill = Color(0xFFF8FAFC);

/// Solar IconKit glyphs used by this screen. Keeping the names in one place
/// makes it easy to swap an icon without touching the UI implementation.
class _Ico {
  const _Ico._();

  static const String messages = SolarIcons.chatRoundDots;
  static const String views = SolarIcons.eye;
  static const String warning = SolarIcons.dangerTriangle;
  static const String expand = SolarIcons.altArrowUp;
}

class _TextOption {
  final String value;
  final String label;

  const _TextOption(this.value, this.label);
}

/// Only gender and location use this moving selection surface. Age and device
/// targeting deliberately use independent, non-sliding choices.
class _GlideSegmented extends StatelessWidget {
  final String value;
  final List<_TextOption> options;
  final ValueChanged<String> onChanged;

  const _GlideSegmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rawIndex = options.indexWhere((option) => option.value == value);
    final selectedIndex = rawIndex < 0 ? 0 : rawIndex;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _cFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = (constraints.maxWidth - 6) / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: 3 + ((options.length - 1 - selectedIndex) * slotWidth),
                top: 3,
                bottom: 3,
                width: slotWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _cCard,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _cLine),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                textDirection: TextDirection.rtl,
                children: options.map((option) {
                  final selected = option.value == value;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(option.value),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 190),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontFamily: kAppFont,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? _cAccent : _cSlate,
                          ),
                          child: Text(option.label),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlainChoiceRow extends StatelessWidget {
  final String value;
  final List<_TextOption> options;
  final ValueChanged<String> onChanged;

  const _PlainChoiceRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => onChanged(options[index].value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: options[index].value == value
                      ? _cInk
                      : _cFieldFill,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: options[index].value == value ? _cInk : _cLine,
                  ),
                ),
                child: Text(
                  options[index].label,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: options[index].value == value
                        ? Colors.white
                        : _cSlate,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FloatingFormError {
  final int id;
  final String message;

  const _FloatingFormError(this.id, this.message);
}

class _FloatingErrorCard extends StatelessWidget {
  final String message;
  final Animation<double> animation;

  const _FloatingErrorCard({
    required this.message,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.14),
            end: Offset.zero,
          ).animate(curved),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SolarIcon(
                      _Ico.warning,
                      style: SolarIconStyle.linear,
                      size: 20,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _cInk,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FastPayStage { idle, creating, ready, opening, checking, waiting, paid, failed }

class _FastPayProgress {
  final _FastPayStage stage;
  final String message;
  final bool paid;
  final bool terminalFailure;

  const _FastPayProgress({
    this.stage = _FastPayStage.idle,
    this.message = 'پارەدان ئامادە دەکرێت…',
    this.paid = false,
    this.terminalFailure = false,
  });
}

// ─────────────────────────────────────────────
// AdCreateScreen — Create Ad (pgCreate)
// ─────────────────────────────────────────────

class AdCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? proxoCard;
  /// کاتێک ڕیکلام بەسەرکەوتوویی نێردرا دەخوێنرێت — بۆ navigate کردن بۆ "ڕیکلامەکانم"
  final VoidCallback? onAdCreated;
  const AdCreateScreen({super.key, this.proxoCard, this.onAdCreated});

  @override
  State<AdCreateScreen> createState() => _AdCreateScreenState();
}

class _AdCreateScreenState extends State<AdCreateScreen>
    with WidgetsBindingObserver {
  // ── form state ───────────────────────────────────────────
  final _adNameCtrl = TextEditingController();
  final _adLinkCtrl = TextEditingController();
  final _adCodeCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  static const String _fastPayCreateUrl =
      'https://email.proxopages.com/webhook/fastpay/order-create';
  static const String _fastPayStatusUrl =
      'https://email.proxopages.com/webhook/fastpay/order-status';

  String _goal = 'messages'; // messages | views
  bool _goalChosen = false;
  String? _category;
  final Set<String> _ages = {'all'};
  String _gender = 'all'; // all | male | female
  String _location = 'all'; // all | kurdistan | iraq
  String _deviceType = 'all'; // all | iphone | android
  String? _paymentMethod; // app_balance | fastpay
  int _dailyUSD = 10;
  int _days = 1;
  DateTime? _adDate;
  TimeOfDay? _adTime;

  bool _promoApplied = false;
  double _promoDiscount = 0;
  String _promoMsg = '';
  bool _promoOk = false;
  bool _promoLoading = false;
  String? _promoId;
  String? _promoDiscountType;
  double _promoDiscountValue = 0;

  bool _submitting = false;
  bool _priceExpanded = false;
  bool _creatingFastPayOrder = false;
  bool _checkingFastPay = false;
  bool _finalizingFastPay = false;
  bool _fastPaySheetOpen = false;
  String? _fastPayOrderId;
  String? _fastPayTransactionId;
  String? _fastPayQrUrl;
  String? _fastPayQrText;
  int? _fastPayAmountIqd;
  String? _fastPayCreateOrderId;
  int _fastPayIntentRevision = 0;
  Timer? _fastPayPollTimer;

  double _walletBalanceUsd = 0;
  bool _walletLoading = true;
  bool _walletLoadFailed = false;
  int _iqdRate = 1800;

  String? _nameError;
  String? _goalError;
  String? _categoryError;
  String? _assetError;
  String? _linkError;
  String? _codeError;
  String? _dateError;
  String? _timeError;
  String? _paymentError;

  final GlobalKey<AnimatedListState> _errorListKey =
      GlobalKey<AnimatedListState>();
  final List<_FloatingFormError> _floatingErrors = [];
  final List<Timer> _errorTimers = [];
  int _nextErrorId = 0;

  final ValueNotifier<_FastPayProgress> _fastPayProgress =
      ValueNotifier<_FastPayProgress>(const _FastPayProgress());

  // ── level-based discount (pa_levels) ───────────────────────
  Map<String, dynamic>? _currentLevel;
  bool _levelLoading = true;
  bool _levelLoadFailed = false;

  // ── ProxoLink asset selector (shown when goal = messages) ─
  List<Map<String, dynamic>> _assets = [];
  bool _assetsLoading = false;
  String? _selectedAssetId;
  Map<String, dynamic>? _selectedAsset;

  // ── budget steps ─────────────────────────────────────────
  static const _budSteps = [10, 20, 50, 100, 200, 500, 1000];
  static const Set<String> _allowedAgeGroups = {
    'all',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55+',
  };

  int get _budIndex =>
      _budSteps.indexOf(_dailyUSD).clamp(0, _budSteps.length - 1).toInt();
  double get _totalUSD => _dailyUSD * _days * 1.0;
  double get _serviceUSD =>
      _totalUSD * ProxoPricing.serviceFeePercent;
  double get _sponsorUSD => _totalUSD - _serviceUSD;

  // داشکاندنی ئاست (pa_levels) — ڕێژە + بڕی جاژمار بە IQD
  double get _levelDiscountPercent =>
      (_currentLevel?['discount_percent'] as num?)?.toDouble() ?? 0;
  double get _levelDiscountIqd =>
      (_currentLevel?['discount_iqd'] as num?)?.toDouble() ?? 0;
  String get _levelNameKu => _currentLevel?['name_ku']?.toString() ?? '';

  double get _levelDiscountUSD {
    if (_currentLevel == null) return 0;
    final pctDisc = _totalUSD * _levelDiscountPercent / 100;
    final iqdDisc = _levelDiscountIqd / _iqdRate;
    final disc = pctDisc + iqdDisc;
    return disc > _totalUSD ? _totalUSD : disc;
  }

  double get _finalUSD {
    final v = _totalUSD - _promoDiscount - _levelDiscountUSD;
    return v < 0 ? 0 : v;
  }

  int get _totalIQD => (_finalUSD * _iqdRate).round();
  int get _displayTotalIQD =>
      _paymentMethod == 'fastpay' && _fastPayAmountIqd != null
          ? _fastPayAmountIqd!
          : _totalIQD;
  int get _walletBalanceIQD => (_walletBalanceUsd * _iqdRate).round();
  bool get _quoteLoading => _walletLoading || _levelLoading;
  bool get _quoteLoadFailed => _walletLoadFailed || _levelLoadFailed;
  bool get _hasFastPayIntent =>
      _fastPayOrderId != null || _fastPayCreateOrderId != null;
  int get _walletAfterIQD {
    final remaining = _walletBalanceIQD - _totalIQD;
    return remaining < 0 ? 0 : remaining;
  }

  // estimated views/clicks
  String get _estViews {
    final base = (_totalUSD * 15000).toInt();
    final lo = (base * 0.8).toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final hi = (base * 1.2).toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$lo – $hi';
  }

  String get _estClicks {
    final base = (_totalUSD * 80).toInt();
    final lo = (base * 0.5).toStringAsFixed(0);
    final hi = (base * 2.5).toStringAsFixed(0);
    return '$lo – $hi';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPricingAndWallet();
    _loadUserLevel();
    _loadAssets().then((_) {
      if (widget.proxoCard != null && mounted) {
        final card = widget.proxoCard!;
        // ئایا داتای ڕیکلام (pa_ads) ە یان ProxoLink card؟
        final bool isAdData = card.containsKey('video_link') ||
                              card.containsKey('goal') ||
                              card.containsKey('video_code');
        if (isAdData) {
          // ── پڕکردنەوەی فۆرم لە داتای ڕیکلامی کۆن ──────────────
          setState(() {
            final title = card['title']?.toString();
            if (title != null && title.isNotEmpty) _adNameCtrl.text = title;

            final link = card['video_link']?.toString();
            if (link != null && link.isNotEmpty) _adLinkCtrl.text = link;

            final code = card['video_code']?.toString();
            if (code != null && code.isNotEmpty) _adCodeCtrl.text = code;

            final goal = card['goal']?.toString();
            if (goal == 'views' || goal == 'messages') {
              _goal = goal!;
              _goalChosen = true;
            }

            final category = card['category']?.toString();
            if (isSupportedAdCategory(category)) {
              _category = category;
            }

            final deviceType = card['device_type']?.toString();
            if (deviceType == 'all' ||
                deviceType == 'iphone' ||
                deviceType == 'android') {
              _deviceType = deviceType!;
            }

            final note = card['customer_note']?.toString();
            if (note != null && note.isNotEmpty) _noteCtrl.text = note;

            // ── ProxoLink card restore (asset_id) ─────────────────
            final assetIdStr = card['asset_id']?.toString();
            if (assetIdStr != null && assetIdStr.isNotEmpty) {
              try {
                final restoredAsset = _assets.firstWhere(
                  (a) => a['id']?.toString() == assetIdStr,
                );
                _selectedAssetId = assetIdStr;
                _selectedAsset = restoredAsset;
              } catch (_) {
                _selectedAssetId = null;
                _selectedAsset = null;
              }
            }

            final gender = card['gender']?.toString();
            if (gender == 'all' || gender == 'male' || gender == 'female') {
              _gender = gender!;
            }

            final location = card['location']?.toString();
            if (location == 'all' ||
                location == 'kurdistan' ||
                location == 'iraq') {
              _location = location!;
            }

            final ag = card['age_groups'];
            if (ag != null) {
              List<String> list;
              if (ag is List) {
                list = List<String>.from(ag.map((e) => e.toString()));
              } else {
                // ئەگەر wەک JSON string گەڕایەوە (e.g. '["18-24","25-34"]')
                final str = ag.toString().trim();
                if (str.startsWith('[') && str.endsWith(']')) {
                  try {
                    list = (json.decode(str) as List<dynamic>)
                        .map((e) => e.toString())
                        .toList();
                  } catch (_) {
                    list = [str];
                  }
                } else {
                  list = [str];
                }
              }
              final validAges = list
                  .where(_allowedAgeGroups.contains)
                  .toSet();
              _ages.clear();
              if (validAges.isEmpty || validAges.contains('all')) {
                _ages.add('all');
              } else {
                _ages.addAll(validAges);
              }
            }

            // type-safe num parse — prevents TypeError from aborting setState
            num? safeNum(dynamic v) {
              if (v == null) return null;
              if (v is num) return v;
              if (v is String) return num.tryParse(v);
              return null;
            }

            final daily = safeNum(card['daily_budget'])?.toInt();
            if (daily != null && _budSteps.contains(daily)) {
              _dailyUSD = daily;
            }

            final days = safeNum(card['days'])?.toInt();
            if (days != null && days >= 1 && days <= 7) _days = days;
          });
        } else {
          // ── ProxoLink card ─────────────────────────────────────
          final id = card['id']?.toString();
          if (id != null) {
            setState(() {
              _goal = 'messages';
              _goalChosen = true;
              _selectedAssetId = id;
              _selectedAsset = card;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fastPayPollTimer?.cancel();
    for (final timer in _errorTimers) {
      timer.cancel();
    }
    _fastPayProgress.dispose();
    _adNameCtrl.dispose();
    _adLinkCtrl.dispose();
    _adCodeCtrl.dispose();
    _promoCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _fastPayOrderId != null &&
        !_finalizingFastPay) {
      unawaited(_verifyFastPayPayment(fromResume: true));
    }
  }

  Future<void> _loadPricingAndWallet() async {
    if (!mounted) return;
    setState(() {
      _walletLoading = true;
      _walletLoadFailed = false;
    });
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _walletLoading = false;
          _walletLoadFailed = true;
        });
      }
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        supabase.rpc('pa_ad_pricing_rate', params: {
          'p_service_type': 'tiktok',
          'p_ad_override': null,
        }),
        supabase
            .from('pa_wallets')
            .select('balance')
            .eq('user_id', user.id)
            .maybeSingle(),
      ]);
      final rate = (results[0] as num?)?.toDouble() ?? 1800;
      final wallet = results[1] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _iqdRate = rate.round().clamp(1, 1000000).toInt();
          _walletBalanceUsd =
              (wallet?['balance'] as num?)?.toDouble() ?? 0;
          _recalculatePromoDiscount();
          _walletLoading = false;
          _walletLoadFailed = false;
        });
      }
    } catch (error) {
      debugPrint('AdCreate pricing/wallet load failed: $error');
      if (mounted) {
        setState(() {
          _walletLoading = false;
          _walletLoadFailed = true;
        });
      }
    }
  }

  // ── ProxoLink asset loader ────────────────────────────────
  Future<void> _loadAssets() async {
    if (!mounted) return;
    setState(() => _assetsLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _assetsLoading = false);
        return;
      }
      final res = await supabase
          .from('proxolink_cards')
          .select('id,name,style,color_theme,card_number,avatar_b64')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() {
        _assets = List<Map<String, dynamic>>.from(res);
        _assetsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _assetsLoading = false);
    }
  }

  // ── level discount loader (pa_levels + pa_user_points) ─────
  Future<void> _loadUserLevel() async {
    if (!mounted) return;
    setState(() {
      _levelLoading = true;
      _levelLoadFailed = false;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _levelLoading = false;
            _levelLoadFailed = true;
          });
        }
        return;
      }

      final levels = await supabase
          .from('pa_levels')
          .select()
          .order('level_number', ascending: true);

      final pointsRow = await supabase
          .from('pa_user_points')
          .select('points')
          .eq('user_id', user.id)
          .maybeSingle();

      final userPoints = (pointsRow?['points'] as num?)?.toDouble() ?? 0;

      final levelList = (levels as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // ئاستی ئێستا: بەرزترین min_points کە <= userPoints
      // (order-independent — پشت بە ڕیزبەندی query نابەستێت)
      Map<String, dynamic>? current;
      double? currentMin;
      for (final lvl in levelList) {
        final minPts = (lvl['min_points'] as num?)?.toDouble() ?? 0;
        if (minPts <= userPoints && (currentMin == null || minPts > currentMin)) {
          current = lvl;
          currentMin = minPts;
        }
      }
      if (current == null && levelList.isNotEmpty) {
        current = levelList.reduce((a, b) {
          final aMin = (a['min_points'] as num?)?.toDouble() ?? 0;
          final bMin = (b['min_points'] as num?)?.toDouble() ?? 0;
          return aMin <= bMin ? a : b;
        });
      }

      if (mounted) {
        setState(() {
          _currentLevel = current;
          _levelLoading = false;
          _levelLoadFailed = false;
        });
      }
    } catch (error) {
      debugPrint('AdCreate level load failed: $error');
      if (mounted) {
        setState(() {
          _levelLoading = false;
          _levelLoadFailed = true;
        });
      }
    }
  }

  Future<void> _retryQuoteData() async {
    if (_quoteLoading) return;
    await Future.wait<void>([
      _loadPricingAndWallet(),
      _loadUserLevel(),
    ]);
  }

  // ── age group multi-select ────────────────────────────────
  void _pickAge(String age) {
    setState(() {
      if (age == 'all') {
        _ages
          ..clear()
          ..add('all');
      } else {
        _ages.remove('all');
        if (_ages.contains(age)) {
          _ages.remove(age);
          if (_ages.isEmpty) _ages.add('all');
        } else {
          _ages.add(age);
        }
      }
    });
  }

  // ── budget stepper ────────────────────────────────────────
  void _changeBudget(int dir) {
    if (_hasFastPayIntent) _resetFastPayIntent();
    setState(() {
      final idx =
          (_budIndex + dir).clamp(0, _budSteps.length - 1).toInt();
      _dailyUSD = _budSteps[idx];
      _recalculatePromoDiscount();
    });
  }

  // ── days stepper ─────────────────────────────────────────
  void _changeDays(int dir) {
    if (_hasFastPayIntent) _resetFastPayIntent();
    setState(() {
      _days = (_days + dir).clamp(1, 7).toInt();
      _recalculatePromoDiscount();
    });
  }

  void _clearPromoValues({bool clearMessage = true}) {
    _promoApplied = false;
    _promoDiscount = 0;
    _promoId = null;
    _promoDiscountType = null;
    _promoDiscountValue = 0;
    if (clearMessage) _promoMsg = '';
  }

  void _recalculatePromoDiscount() {
    if (!_promoApplied ||
        _promoDiscountType == null ||
        _promoDiscountValue <= 0) {
      _promoDiscount = 0;
      return;
    }

    final rawDiscount = _promoDiscountType == 'percentage'
        ? _totalUSD * _promoDiscountValue / 100
        : _promoDiscountValue / _iqdRate;
    _promoDiscount = rawDiscount.clamp(0, _totalUSD).toDouble();
    _promoMsg = _promoDiscountType == 'percentage'
        ? 'داشکاندنی ${_promoDiscountValue.toStringAsFixed(0)}%: '
            '-\$${_promoDiscount.toStringAsFixed(2)}'
        : 'داشکاندنی ${_promoDiscountValue.toStringAsFixed(0)} IQD';
  }

  // ── promo code ────────────────────────────────────────────
  Future<void> _applyPromo() async {
    if (_hasFastPayIntent) _resetFastPayIntent();
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _promoMsg = 'کۆدی داشکاندن بنووسە';
        _promoOk = false;
      });
      return;
    }
    setState(() => _promoLoading = true);
    try {
      final res = await supabase
          .from('promo_codes')
          .select('*')
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (!mounted || _promoCtrl.text.trim().toUpperCase() != code) return;

      if (res == null) {
        setState(() {
          _promoMsg = 'ئەم کۆدە نادروستە یان بەسەرچووە';
          _promoOk = false;
          _clearPromoValues(clearMessage: false);
        });
      } else {
        // ── Check expiry ──────────────────────────────────────
        final expiresAt = res['expires_at'] != null
            ? DateTime.tryParse(res['expires_at'].toString())
            : null;
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          setState(() {
            _promoMsg = 'ماوەی ئەم کۆدە بەسەرچووە';
            _promoOk = false;
            _clearPromoValues(clearMessage: false);
          });
          if (mounted) setState(() => _promoLoading = false);
          return;
        }
        // ── Check max_uses ────────────────────────────────────
        final maxUses = (res['max_uses'] as num?)?.toInt();
        final usedCount = (res['used_count'] as num?)?.toInt() ?? 0;
        if (maxUses != null && usedCount >= maxUses) {
          setState(() {
            _promoMsg = 'سنووری بەکارهێنانی ئەم کۆدە تەواو بووە';
            _promoOk = false;
            _clearPromoValues(clearMessage: false);
          });
          if (mounted) setState(() => _promoLoading = false);
          return;
        }
        // discount_type: 'percentage' یان 'fixed'
        final storedDiscType = res['discount_type']?.toString();
        final discType = storedDiscType == 'fixed' ? 'fixed' : 'percentage';
        final discountValue =
            (res['discount_value'] as num?)?.toDouble() ?? 0;
        setState(() {
          _promoApplied = true;
          _promoOk = true;
          _promoId = res['id']?.toString();
          _promoDiscountType = discType;
          _promoDiscountValue = discountValue;
          _recalculatePromoDiscount();
        });
      }
    } catch (error) {
      debugPrint('AdCreate promo load failed: $error');
      if (mounted) {
        setState(() {
          _promoMsg = 'هەڵەیەک ڕوویدا؛ دووبارە هەوڵ بدەرەوە';
          _promoOk = false;
        });
      }
    } finally {
      if (mounted) setState(() => _promoLoading = false);
    }
  }

  // ── paste from clipboard ──────────────────────────────────
  Future<void> _paste(TextEditingController ctrl) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (mounted && data?.text != null) {
        ctrl.text = data!.text!;
      }
    } catch (_) {}
  }

  // ── submit ────────────────────────────────────────────────
  Future<void> _requestAdThumbnail(String adId) async {
    try {
      final response = await supabase.functions.invoke(
        'generate-ad-thumbnail',
        body: <String, dynamic>{'ad_id': adId},
      );
      final data = response.data;
      if (data is Map && data['ok'] != true) {
        debugPrint(
          'AdCreate: thumbnail unavailable (${data['reason'] ?? 'unknown'})',
        );
      }
    } catch (error, stackTrace) {
      // Thumbnail generation is intentionally non-blocking. The ad has
      // already been saved and the UI keeps a clean white placeholder.
      debugPrint('AdCreate: thumbnail request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _formatIQD(num value) => value.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );

  void _queueFormError(String message) {
    if (!mounted) return;
    final item = _FloatingFormError(++_nextErrorId, message);
    final listState = _errorListKey.currentState;
    _floatingErrors.insert(0, item);
    if (listState == null) {
      setState(() {});
    } else {
      listState.insertItem(0, duration: const Duration(milliseconds: 260));
    }

    final queueOffset = (_floatingErrors.length - 1).clamp(0, 10).toInt();
    final delay = 3300 + queueOffset * 260;
    late final Timer timer;
    timer = Timer(Duration(milliseconds: delay), () {
      _errorTimers.remove(timer);
      if (!mounted) return;
      final index = _floatingErrors.indexWhere((entry) => entry.id == item.id);
      if (index < 0) return;
      final removed = _floatingErrors.removeAt(index);
      _errorListKey.currentState?.removeItem(
        index,
        (context, animation) => _FloatingErrorCard(
          message: removed.message,
          animation: animation,
        ),
        duration: const Duration(milliseconds: 240),
      );
    });
    _errorTimers.add(timer);
  }

  bool _validateNewForm() {
    final now = DateTime.now();
    final name = _adNameCtrl.text.trim();
    final link = _adLinkCtrl.text.trim();
    final code = _adCodeCtrl.text.trim();
    final uri = Uri.tryParse(link);
    final linkHost = uri?.host.toLowerCase() ?? '';
    final isTikTokHost =
        linkHost == 'tiktok.com' || linkHost.endsWith('.tiktok.com');

    String? dateError;
    String? timeError;
    if (_adDate == null) {
      dateError = 'بەرواری دەستپێک هەڵبژێرە';
    }
    if (_adTime == null) {
      timeError = 'کاتی دەستپێک هەڵبژێرە';
    }
    if (_adDate != null && _adTime != null) {
      final selected = DateTime(
        _adDate!.year,
        _adDate!.month,
        _adDate!.day,
        _adTime!.hour,
        _adTime!.minute,
      );
      final today = DateTime(now.year, now.month, now.day);
      final selectedDay =
          DateTime(selected.year, selected.month, selected.day);
      if (selectedDay.isBefore(today)) {
        dateError = 'بەرواری دەستپێک نابێت پێش ئەمڕۆ بێت';
      } else if (selected.isBefore(now)) {
        timeError = 'کاتی هەڵبژێردراو تێپەڕیوە؛ کاتێکی دواتر هەڵبژێرە';
      }
    }

    final errors = <String>[];
    setState(() {
      _nameError = name.isEmpty ? 'ناوی ڕیکلام بنووسە' : null;
      _goalError = !_goalChosen ? 'ئامانجی ڕیکلام هەڵبژێرە' : null;
      _categoryError = !isSupportedAdCategory(_category)
          ? 'بەشی ڕیکلام هەڵبژێرە'
          : null;
      _assetError = _goalChosen &&
              _goal == 'messages' &&
              _selectedAssetId == null
          ? 'کەرەستەی پەیوەندی هەڵبژێرە'
          : null;
      _linkError = link.isEmpty
          ? 'بەستەری ڤیدیۆ بنووسە'
          : uri == null ||
                  uri.scheme != 'https' ||
                  !isTikTokHost
              ? 'بەستەرەکە دەبێت بەستەرێکی دروستی TikTok بێت'
              : null;
      _codeError = code.isEmpty ? 'کۆدی ڤیدیۆ بنووسە' : null;
      _dateError = dateError;
      _timeError = timeError;
      _paymentError = _paymentMethod == null
          ? 'ڕێگای پارەدان هەڵبژێرە'
          : null;

      for (final error in [
        _nameError,
        _goalError,
        _categoryError,
        _assetError,
        _linkError,
        _codeError,
        _dateError,
        _timeError,
        _paymentError,
      ]) {
        if (error != null) errors.add(error);
      }
    });

    for (final error in errors) {
      _queueFormError(error);
    }
    return errors.isEmpty;
  }

  Future<void> _handleCheckout() async {
    if (_submitting || _creatingFastPayOrder || _finalizingFastPay) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateNewForm()) return;

    if (_quoteLoading) {
      _queueFormError('چاوەڕێ بکە تا نرخ و باڵانس بار دەبن');
      return;
    }
    if (_quoteLoadFailed) {
      _queueFormError('نرخ یان باڵانس بار نەبوو؛ دووبارە هەوڵ بدەرەوە');
      unawaited(_retryQuoteData());
      return;
    }

    if (_paymentMethod == 'app_balance') {
      if (!_walletLoading && _walletBalanceUsd + 0.000001 < _finalUSD) {
        const message = 'باڵانسی هەژمارەکەت لەنرخی ئەم داواکاریە کەمترە';
        setState(() => _paymentError = message);
        _queueFormError(message);
        return;
      }
      await _createAdSecure(paymentMethod: 'app_balance');
      return;
    }

    if (_paymentMethod == 'fastpay') {
      if (_fastPayProgress.value.paid && _fastPayTransactionId != null) {
        await _createAdSecure(
          paymentMethod: 'fastpay',
          paymentTransactionId: _fastPayTransactionId,
        );
      } else if (_fastPayProgress.value.terminalFailure) {
        _resetFastPayIntent();
        if (mounted) setState(() {});
        await _createFastPayOrder();
      } else if (_fastPayOrderId != null) {
        await _showFastPaySheet();
        await _verifyFastPayPayment(showFailure: true);
      } else {
        await _createFastPayOrder();
      }
    }
  }

  Future<void> _showGoalInfo(String value) async {
    final isMessages = value == 'messages';
    final selected = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: _cCard,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _cLine,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isMessages ? 'نامە و فرۆش' : 'بینین و کارلێک',
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _cInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMessages
                    ? 'کڕیاران دەتوانن لە ڕێگەی کەرەستەی پەیوەندییەکەتەوە ڕاستەوخۆ پەیوەندیت پێوە بکەن. ئەم ئامانجە گونجاوە بۆ وەرگرتنی داواکاری و زیادکردنی فرۆش.'
                    : 'ڤیدیۆکەت بۆ کەسانی زیاتر پیشان دەدرێت تاکو بینین و کارلێک زیاد بکات. لەم ئامانجەدا کەرەستەی پەیوەندی پێویست نییە.',
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13,
                  height: 1.7,
                  color: _cSlate,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _cAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text(
                    'هەڵبژاردن',
                    style: TextStyle(
                      fontFamily: kAppFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == true && mounted) {
      setState(() {
        _goal = value;
        _goalChosen = true;
        _goalError = null;
        if (value != 'messages') {
          _selectedAssetId = null;
          _selectedAsset = null;
          _assetError = null;
        }
      });
    }
  }

  void _resetFastPayIntent() {
    _fastPayIntentRevision++;
    _fastPayPollTimer?.cancel();
    _fastPayPollTimer = null;
    _fastPayOrderId = null;
    _fastPayCreateOrderId = null;
    _fastPayTransactionId = null;
    _fastPayQrUrl = null;
    _fastPayQrText = null;
    _fastPayAmountIqd = null;
    if (mounted) {
      _fastPayProgress.value = const _FastPayProgress();
    }
  }

  Future<bool> _restoreFastPayOrderFromLedger(String orderId) async {
    final intentRevision = _fastPayIntentRevision;
    try {
      final row = await supabase
          .from('pa_transactions')
          .select(
            'id,amount,gateway_amount,status,gateway_status,'
            'fastpay_order_id,qr_url,qr_text,ad_id',
          )
          .eq('fastpay_order_id', orderId)
          .maybeSingle();
      if (row == null ||
          !mounted ||
          intentRevision != _fastPayIntentRevision ||
          orderId != _fastPayCreateOrderId) {
        return false;
      }

      final amountRaw = row['gateway_amount'] ?? row['amount'];
      final amountIqd = amountRaw is num
          ? amountRaw.round()
          : int.tryParse(amountRaw?.toString() ?? '');
      final status = row['status']?.toString().toLowerCase() ?? '';
      final gatewayStatus =
          row['gateway_status']?.toString().toUpperCase() ?? '';
      final paid = status == 'approved' && gatewayStatus == 'PAID';
      const terminalStatuses = {
        'EXPIRED',
        'DECLINED',
        'FAILED',
        'CANCELLED',
        'CANCELED',
        'REJECTED',
      };
      final terminal = terminalStatuses.contains(gatewayStatus);

      setState(() {
        _fastPayOrderId = row['fastpay_order_id']?.toString() ?? orderId;
        _fastPayCreateOrderId = orderId;
        _fastPayTransactionId = row['id']?.toString();
        _fastPayQrUrl = row['qr_url']?.toString();
        _fastPayQrText = row['qr_text']?.toString();
        if (amountIqd != null && amountIqd > 0) {
          _fastPayAmountIqd = amountIqd;
        }
      });

      if (paid) {
        _fastPayProgress.value = const _FastPayProgress(
          stage: _FastPayStage.paid,
          message: 'پارەدان بە سەرکەوتوویی پشتڕاستکرایەوە',
          paid: true,
        );
        final adId = row['ad_id']?.toString().trim();
        if (adId != null && adId.isNotEmpty) {
          await _completeAdCreation(adId, requestThumbnail: false);
        } else if (_fastPayTransactionId != null) {
          await _createAdSecure(
            paymentMethod: 'fastpay',
            paymentTransactionId: _fastPayTransactionId,
          );
        }
        return true;
      }

      if (terminal) {
        _fastPayProgress.value = _FastPayProgress(
          stage: _FastPayStage.failed,
          message: gatewayStatus == 'EXPIRED'
              ? 'ماوەی پارەدان بەسەرچوو'
              : 'پارەدان تەواو نەکرا',
          terminalFailure: true,
        );
        return true;
      }

      final hasQr = (_fastPayQrUrl?.isNotEmpty ?? false) ||
          (_fastPayQrText?.isNotEmpty ?? false);
      _fastPayProgress.value = _FastPayProgress(
        stage: hasQr ? _FastPayStage.ready : _FastPayStage.waiting,
        message: hasQr
            ? 'پارەدانەکە دووبارە گەڕێندرایەوە'
            : 'داواکاری پارەدان دەپشکنرێت…',
      );
      _startFastPayPolling();
      await _showFastPaySheet();
      return true;
    } catch (error) {
      debugPrint('FastPay ledger restore failed: $error');
      return false;
    }
  }

  Future<void> _createFastPayOrder() async {
    if (!mounted || _creatingFastPayOrder) return;
    final session = supabase.auth.currentSession;
    final user = session?.user;
    if (session == null || user == null) {
      _queueFormError('دووبارە بچۆ ژوورەوە');
      return;
    }
    final intentRevision = _fastPayIntentRevision;
    final retryingExistingIntent = _fastPayCreateOrderId != null;
    final orderId = _fastPayCreateOrderId ??
        'AD${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    _fastPayCreateOrderId = orderId;
    setState(() => _creatingFastPayOrder = true);
    _fastPayProgress.value = const _FastPayProgress(
      stage: _FastPayStage.creating,
      message: 'داواکاری پارەدان دروست دەکرێت…',
    );
    try {
      if (retryingExistingIntent &&
          await _restoreFastPayOrderFromLedger(orderId)) {
        return;
      }
      final response = await http
          .post(
            Uri.parse(_fastPayCreateUrl),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({
              'purpose': 'ad_checkout',
              'orderId': orderId,
              'currency': 'IQD',
              'note': 'Proxo ad payment',
              'ad': <String, dynamic>{
                'daily_budget': _dailyUSD,
                'days': _days,
              },
              'promoId': _promoApplied ? _promoId : null,
              'promoCode':
                  _promoApplied ? _promoCtrl.text.trim() : null,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
      if (response.statusCode != 200 || data['success'] != true) {
        throw StateError(data['message']?.toString() ?? 'FastPay error');
      }
      final quotedRaw = data['amountIqd'];
      final quotedAmount = quotedRaw is num
          ? quotedRaw.round()
          : int.tryParse(quotedRaw?.toString() ?? '');
      if (quotedAmount == null || quotedAmount <= 0) {
        throw const FormatException('Missing server-side FastPay quote');
      }

      if (!mounted ||
          intentRevision != _fastPayIntentRevision ||
          orderId != _fastPayCreateOrderId) {
        return;
      }
      setState(() {
        _fastPayOrderId = data['orderId']?.toString() ?? orderId;
        _fastPayTransactionId = data['transactionId']?.toString();
        _fastPayQrUrl = data['qrUrl']?.toString();
        _fastPayQrText = data['qrText']?.toString();
        _fastPayAmountIqd = quotedAmount;
      });
      _fastPayProgress.value = const _FastPayProgress(
        stage: _FastPayStage.ready,
        message: 'پارەدان ئامادەیە',
      );
      _startFastPayPolling();
      await _showFastPaySheet();
    } on TimeoutException {
      if (!mounted || intentRevision != _fastPayIntentRevision) return;
      if (await _restoreFastPayOrderFromLedger(orderId)) return;
      _queueFormError('FastPay وەڵامی نەدایەوە؛ دووبارە هەوڵ بدەرەوە');
      _fastPayProgress.value = const _FastPayProgress(
        stage: _FastPayStage.failed,
        message: 'پەیوەندیکردن بە FastPay سەرکەوتوو نەبوو',
      );
    } catch (error) {
      debugPrint('FastPay create failed: $error');
      if (!mounted || intentRevision != _fastPayIntentRevision) return;
      if (await _restoreFastPayOrderFromLedger(orderId)) return;
      _queueFormError('دروستکردنی پارەدان سەرکەوتوو نەبوو');
      _fastPayProgress.value = const _FastPayProgress(
        stage: _FastPayStage.failed,
        message: 'پارەدان دروست نەکرا',
      );
    } finally {
      if (mounted) setState(() => _creatingFastPayOrder = false);
    }
  }

  void _startFastPayPolling() {
    _fastPayPollTimer?.cancel();
    var attempts = 0;
    final intentRevision = _fastPayIntentRevision;
    final orderId = _fastPayOrderId;
    _fastPayPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      attempts++;
      if (attempts > 120 ||
          !mounted ||
          intentRevision != _fastPayIntentRevision ||
          orderId != _fastPayOrderId ||
          _fastPayOrderId == null ||
          _fastPayProgress.value.paid ||
          _fastPayProgress.value.terminalFailure) {
        timer.cancel();
        return;
      }
      unawaited(_verifyFastPayPayment());
    });
  }

  bool _isAllowedFastPayTarget(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'appfpp' || scheme == 'fastpay') return true;
    return scheme == 'https' && uri.host.isNotEmpty;
  }

  Future<void> _openFastPay() async {
    if (!mounted) return;
    final intentRevision = _fastPayIntentRevision;
    final targets = <Uri>[];
    final qrText = _fastPayQrText?.trim() ?? '';
    if (qrText.isNotEmpty) {
      final parsed = Uri.tryParse(qrText);
      if (parsed != null && _isAllowedFastPayTarget(parsed)) {
        targets.add(parsed);
      } else if (_fastPayOrderId != null) {
        targets.add(Uri.parse(
          'appFpp://fast-pay.cash/qrpay'
          '?qrdata=${Uri.encodeQueryComponent(qrText)}'
          '&clientUri=appfpclientProxo'
          '&transactionId=${Uri.encodeQueryComponent(_fastPayOrderId!)}',
        ));
      }
    }
    final qrUrl = Uri.tryParse(_fastPayQrUrl?.trim() ?? '');
    if (qrUrl != null && _isAllowedFastPayTarget(qrUrl)) {
      targets.add(qrUrl);
    }

    if (targets.isEmpty) {
      _queueFormError('بەستەری کردنەوەی FastPay بەردەست نییە');
      return;
    }

    _fastPayProgress.value = const _FastPayProgress(
      stage: _FastPayStage.opening,
      message: 'FastPay دەکرێتەوە…',
    );
    for (final target in targets) {
      try {
        final opened =
            await launchUrl(target, mode: LaunchMode.externalApplication);
        if (!mounted || intentRevision != _fastPayIntentRevision) return;
        if (opened) return;
      } catch (error) {
        debugPrint('FastPay launch failed for ${target.scheme}: $error');
      }
    }
    if (!mounted || intentRevision != _fastPayIntentRevision) return;
    _fastPayProgress.value = const _FastPayProgress(
      stage: _FastPayStage.failed,
      message: 'FastPay نەکرایەوە',
    );
    _queueFormError('نەتوانرا FastPay بکرێتەوە');
  }

  Future<void> _verifyFastPayPayment({
    bool fromResume = false,
    bool showFailure = false,
  }) async {
    final orderId = _fastPayOrderId;
    if (_checkingFastPay || _finalizingFastPay || orderId == null) {
      return;
    }
    final intentRevision = _fastPayIntentRevision;
    final session = supabase.auth.currentSession;
    if (session == null) return;

    _checkingFastPay = true;
    _fastPayProgress.value = const _FastPayProgress(
      stage: _FastPayStage.checking,
      message: 'پارەدان دەپشکنرێت…',
    );
    try {
      final response = await http
          .post(
            Uri.parse(_fastPayStatusUrl),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({'orderId': orderId}),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
      if (response.statusCode != 200 || data['success'] != true) {
        throw StateError(data['message']?.toString() ?? 'Status check failed');
      }
      if (!mounted ||
          intentRevision != _fastPayIntentRevision ||
          orderId != _fastPayOrderId) {
        return;
      }

      final paid = data['paid'] == true;
      final terminal = data['terminal'] == true;
      final gatewayStatus = data['gatewayStatus']?.toString() ?? '';
      final transactionId = data['transactionId']?.toString();
      final linkedAdId = data['adId']?.toString().trim();
      if (transactionId != null && transactionId.isNotEmpty) {
        setState(() => _fastPayTransactionId = transactionId);
      }

      if (paid) {
        _fastPayPollTimer?.cancel();
        _fastPayProgress.value = const _FastPayProgress(
          stage: _FastPayStage.paid,
          message: 'پارەدان بە سەرکەوتوویی پشتڕاستکرایەوە',
          paid: true,
        );
        _finalizingFastPay = true;
        setState(() {});
        if (linkedAdId != null && linkedAdId.isNotEmpty) {
          await _completeAdCreation(
            linkedAdId,
            requestThumbnail: false,
          );
          return;
        }
        if (_fastPayTransactionId == null) {
          throw StateError('Missing FastPay transaction id');
        }
        await _createAdSecure(
          paymentMethod: 'fastpay',
          paymentTransactionId: _fastPayTransactionId,
        );
        return;
      }

      if (terminal) {
        _fastPayPollTimer?.cancel();
        _fastPayProgress.value = _FastPayProgress(
          stage: _FastPayStage.failed,
          message: gatewayStatus == 'EXPIRED'
              ? 'ماوەی پارەدان بەسەرچوو'
              : 'پارەدان تەواو نەکرا',
          terminalFailure: true,
        );
        if (showFailure || fromResume) {
          _queueFormError('پارەدان پشتڕاست نەکرایەوە');
        }
      } else {
        _fastPayProgress.value = const _FastPayProgress(
          stage: _FastPayStage.waiting,
          message: 'هێشتا پارەدان تەواو نەکراوە',
        );
      }
    } on TimeoutException {
      if (!mounted || intentRevision != _fastPayIntentRevision) return;
      _fastPayProgress.value = const _FastPayProgress(
        stage: _FastPayStage.waiting,
        message: 'پشکنین درەنگ کەوت؛ دووبارە هەوڵ دەدرێتەوە',
      );
      if (showFailure || fromResume) {
        _queueFormError('پشکنینی FastPay درەنگ کەوت');
      }
    } catch (error) {
      debugPrint('FastPay status failed: $error');
      if (!mounted || intentRevision != _fastPayIntentRevision) return;
      _fastPayProgress.value = const _FastPayProgress(
        stage: _FastPayStage.waiting,
        message: 'هێشتا نەتوانرا پارەدان پشتڕاست بکرێتەوە',
      );
      if (showFailure || fromResume) {
        _queueFormError('پشکنینی پارەدان سەرکەوتوو نەبوو');
      }
    } finally {
      _checkingFastPay = false;
      _finalizingFastPay = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _restartFastPayPayment() async {
    if (!mounted || _creatingFastPayOrder || _finalizingFastPay) return;
    _resetFastPayIntent();
    setState(() {});
    await _createFastPayOrder();
  }

  Future<String?> _recoverCompletedFastPayAdId() async {
    final orderId = _fastPayOrderId;
    if (orderId == null) return null;
    final intentRevision = _fastPayIntentRevision;

    try {
      final row = await supabase
          .from('pa_transactions')
          .select('id,status,gateway_status,ad_id')
          .eq('fastpay_order_id', orderId)
          .maybeSingle();
      if (row == null ||
          row['status']?.toString().toLowerCase() != 'approved' ||
          row['gateway_status']?.toString().toUpperCase() != 'PAID') {
        return null;
      }
      if (!mounted ||
          intentRevision != _fastPayIntentRevision ||
          orderId != _fastPayOrderId) {
        return null;
      }

      final transactionId = row['id']?.toString().trim();
      if (transactionId != null && transactionId.isNotEmpty) {
        setState(() => _fastPayTransactionId = transactionId);
      }
      final adId = row['ad_id']?.toString().trim();
      return adId == null || adId.isEmpty ? null : adId;
    } catch (error) {
      debugPrint('FastPay ad recovery failed: $error');
      return null;
    }
  }

  Future<bool> _completeAdCreation(
    String adId, {
    bool requestThumbnail = true,
  }) async {
    if (requestThumbnail) {
      unawaited(_requestAdThumbnail(adId));
    }
    if (!mounted) return true;

    _toast('داواکارییەکەت بە سەرکەوتوویی نێردرا', ok: true);
    widget.onAdCreated?.call();
    if (!mounted) return true;

    if (_fastPaySheetOpen) {
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return true;
    }
    Navigator.of(context).pop('refresh');
    return true;
  }

  Future<bool> _createAdSecure({
    required String paymentMethod,
    String? paymentTransactionId,
  }) async {
    if (!mounted || _submitting) return false;
    setState(() => _submitting = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _queueFormError('دووبارە بچۆ ژوورەوە');
        return false;
      }
      if (_adDate == null || _adTime == null) {
        _queueFormError('بەروار و کاتی دەستپێک هەڵبژێرە');
        return false;
      }

      String two(int value) => value.toString().padLeft(2, '0');
      final startDate = DateTime(
        _adDate!.year,
        _adDate!.month,
        _adDate!.day,
        _adTime!.hour,
        _adTime!.minute,
      );
      final rpcRaw = await supabase.rpc('pa_create_ad', params: {
        'p_ad': <String, dynamic>{
          'title': _adNameCtrl.text.trim(),
          'goal': _goal,
          'category': _category,
          'age_groups': _ages.toList(growable: false),
          'gender': _gender,
          'location': _location,
          'device_type': _deviceType,
          'customer_note': _noteCtrl.text.trim(),
          'daily_budget': _dailyUSD.toDouble(),
          'days': _days,
          'video_link': _adLinkCtrl.text.trim(),
          'video_code': _adCodeCtrl.text.trim(),
          'post_code': _adCodeCtrl.text.trim(),
          'asset_id': _goal == 'messages' ? _selectedAssetId : null,
          'start_date':
              '${startDate.year}-${two(startDate.month)}-${two(startDate.day)}',
          'start_time': '${two(startDate.hour)}:${two(startDate.minute)}',
          'payment_method': paymentMethod,
          'payment_transaction_id': paymentTransactionId,
        },
        'p_cost_usd': _finalUSD,
        'p_promo_id': _promoApplied ? _promoId : null,
        'p_promo_code': _promoApplied ? _promoCtrl.text.trim() : null,
        'p_promo_discount': _promoApplied ? _promoDiscount : 0,
      });
      final rpc = Map<String, dynamic>.from(rpcRaw as Map);
      if (rpc['ok'] != true) {
        final code = (rpc['code'] ?? '').toString();
        if (paymentMethod == 'fastpay' && code == 'FASTPAY_ALREADY_USED') {
          final recoveredAdId = await _recoverCompletedFastPayAdId();
          if (recoveredAdId != null) {
            return await _completeAdCreation(
              recoveredAdId,
              requestThumbnail: false,
            );
          }
        }
        final message = switch (code) {
          'INSUFFICIENT_FUNDS' => 'باڵانسی پێویستت بەردەست نییە',
          'INVALID_PROMO' => 'کۆدی داشکاندن نادروستە یان بەسەرچووە',
          'INVALID_CATEGORY' => 'بەشی ڕیکلام نادروستە؛ دووبارە هەڵیبژێرە',
          'INVALID_ASSET' => 'ئەم کەرەستەی پەیوەندییە بەردەست نییە؛ یەکێکی دیکە هەڵبژێرە',
          'INVALID_SCHEDULE' => 'بەروار یان کاتی ڕیکلام تێپەڕیوە',
          'FASTPAY_TRANSACTION_REQUIRED' => 'مامەڵەی FastPay دیاری نەکراوە',
          'FASTPAY_TRANSACTION_NOT_FOUND' => 'مامەڵەی FastPay نەدۆزرایەوە',
          'FASTPAY_NOT_PAID' => 'پارەدانی FastPay هێشتا پشتڕاست نەکراوەتەوە',
          'FASTPAY_ALREADY_USED' => 'ئەم پارەدانە پێشتر بەکارهاتووە',
          'FASTPAY_AMOUNT_MISMATCH' => 'بڕی پارەدان لەگەڵ نرخی ڕیکلام یەک ناگرێتەوە',
          'NOT_AUTHENTICATED' => 'دووبارە بچۆ ژوورەوە',
          _ => 'زانیارییەکان دروست نین؛ دووبارە بپشکنەوە',
        };
        _queueFormError(message);
        return false;
      }

      final adId = rpc['ad_id']?.toString().trim();
      if (adId == null || adId.isEmpty) {
        throw const FormatException('pa_create_ad returned no ad_id');
      }
      return await _completeAdCreation(adId);
    } catch (error) {
      debugPrint('AdCreate secure submit failed: $error');
      if (paymentMethod == 'fastpay') {
        final recoveredAdId = await _recoverCompletedFastPayAdId();
        if (recoveredAdId != null) {
          return await _completeAdCreation(
            recoveredAdId,
            requestThumbnail: false,
          );
        }
      }
      _queueFormError(
        'ڕیکلامەکە دروست نەکرا؛ ئینتەرنێتەکەت بپشکنەوە',
      );
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    showProxoToast(context, msg,
      type: ok ? ProxoToastType.success : ProxoToastType.error);
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cPage,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildFlowHeader(),
                  Expanded(
                    child: WaveOverscroll(
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        cacheExtent: 500,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                        children: [
                          _buildGoalFlowSection(),
                          const SizedBox(height: 14),
                          _buildBasicInfoFlowSection(),
                          const SizedBox(height: 14),
                          _buildCategoryFlowSection(),
                          const SizedBox(height: 14),
                          _buildAudienceFlowSection(),
                          const SizedBox(height: 14),
                          _buildBudgetFlowSection(),
                          const SizedBox(height: 14),
                          _buildScheduleFlowSection(),
                          const SizedBox(height: 14),
                          _buildNoteFlowSection(),
                          const SizedBox(height: 14),
                          _buildEndCheckoutSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_priceExpanded)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _priceExpanded = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  ignoring: _floatingErrors.isEmpty,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 520),
                    child: AnimatedList(
                      key: _errorListKey,
                      shrinkWrap: true,
                      initialItemCount: _floatingErrors.length,
                      itemBuilder: (context, index, animation) {
                        if (index >= _floatingErrors.length) {
                          return const SizedBox.shrink();
                        }
                        return _FloatingErrorCard(
                          message: _floatingErrors[index].message,
                          animation: animation,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildExpandablePriceDock(),
      ),
    );
  }

  Widget _buildFlowHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: _cCard,
        border: Border(bottom: BorderSide(color: _cLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'دروستکردنی ڕیکلام',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _cInk,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'خانەکان بە زانیاریی دروست پڕ بکەرەوە',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: _cSlate,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _cSlate,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: _cLine),
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text(
              'گەڕانەوە',
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cLine, width: AdSurface.hairline),
      ),
      child: child,
    );
  }

  Widget _flowTitle(String title, {String? helper}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: kAppFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _cInk,
            height: 1.4,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(
            helper,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: _cSlate,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _flowLabel(
    String label, {
    bool important = false,
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _cInk,
              height: 1.4,
            ),
          ),
          if (important) ...[
            const SizedBox(width: 6),
            const Text(
              'پێویستە',
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
                height: 1.4,
              ),
            ),
          ] else if (optional) ...[
            const SizedBox(width: 6),
            const Text(
              'ئارەزوومەندانە',
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _cSlate,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _flowInputDecoration({
    required String hint,
    String? error,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: kAppFont,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: _cFieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: border(_cLine),
      enabledBorder: border(error == null ? _cLine : AppColors.red),
      focusedBorder: border(error == null ? _cAccent : AppColors.red, 1.3),
      errorText: error,
      errorStyle: const TextStyle(
        fontFamily: kAppFont,
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: AppColors.red,
        height: 1.4,
      ),
      suffixIcon: suffix,
      suffixIconConstraints: suffix == null
          ? null
          : const BoxConstraints(minWidth: 58, minHeight: 44),
    );
  }

  Widget _buildGoalFlowSection() {
    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle(
            'ئامانجی ڕیکلام',
            helper: 'یەکێکیان هەڵبژێرە؛ پێش دڵنیابوونەوە وردەکاری هەر ئامانجێک دەبینیت',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _goalFlowTile(
                  value: 'messages',
                  label: 'نامە و فرۆش',
                  solarIcon: _Ico.messages,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _goalFlowTile(
                  value: 'views',
                  label: 'بینین و کارلێک',
                  solarIcon: _Ico.views,
                ),
              ),
            ],
          ),
          if (_goalError != null) ...[
            const SizedBox(height: 7),
            Text(
              _goalError!,
              style: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _goalFlowTile({
    required String value,
    required String label,
    required String solarIcon,
  }) {
    final selected = _goalChosen && _goal == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showGoalInfo(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? _cAccent.withValues(alpha: 0.055)
                : _cFieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _cAccent : _cLine,
              width: selected ? 1.35 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SolarIcon(
                solarIcon,
                style: SolarIconStyle.linear,
                size: 22,
                color: selected ? _cAccent : _cIcon,
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? _cAccent : _cInk,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoFlowSection() {
    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle('زانیاریی ڕیکلام'),
          const SizedBox(height: 15),
          _flowLabel('ناوی ڕیکلام', important: true),
          TextField(
            controller: _adNameCtrl,
            maxLength: 50,
            textDirection: TextDirection.rtl,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _cInk,
            ),
            decoration: _flowInputDecoration(
              hint: 'ناوێکی کورت بۆ ڕیکلامەکە',
              error: _nameError,
            ).copyWith(counterText: ''),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _adNameCtrl,
              builder: (_, value, __) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${value.text.length}/50',
                  style: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 10,
                    color: _cSlate,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _goalChosen && _goal == 'messages'
                ? Padding(
                    key: const ValueKey('asset_picker'),
                    padding: const EdgeInsets.only(top: 14),
                    child: _buildFlowAssetPicker(),
                  )
                : const SizedBox.shrink(key: ValueKey('no_asset_picker')),
          ),
          const SizedBox(height: 14),
          _flowLabel('بەستەری ڤیدیۆی TikTok', important: true),
          TextField(
            controller: _adLinkCtrl,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) {
              if (_linkError != null) setState(() => _linkError = null);
            },
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 14,
              color: _cInk,
            ),
            decoration: _flowInputDecoration(
              hint: 'https://www.tiktok.com/...',
              error: _linkError,
              suffix: TextButton(
                onPressed: () async {
                  await _paste(_adLinkCtrl);
                  if (mounted) setState(() => _linkError = null);
                },
                child: const Text(
                  'لکاندن',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _cAccent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          _flowLabel('کۆدی ڤیدیۆ', important: true),
          TextField(
            controller: _adCodeCtrl,
            maxLength: 200,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            autocorrect: false,
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 14,
              color: _cInk,
            ),
            decoration: _flowInputDecoration(
              hint: 'کۆدی ڤیدیۆکە بنووسە',
              error: _codeError,
              suffix: TextButton(
                onPressed: () async {
                  await _paste(_adCodeCtrl);
                  if (mounted) setState(() => _codeError = null);
                },
                child: const Text(
                  'لکاندن',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _cAccent,
                  ),
                ),
              ),
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 6),
          const Text(
            'کۆدی هەڵە وا دەکات ڤیدیۆکە بە دروستی نەدۆزرێتەوە',
            style: TextStyle(
              fontFamily: kAppFont,
              fontSize: 10.5,
              color: AppColors.red,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowAssetPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flowLabel('کەرەستەی پەیوەندی', important: true),
        if (_assetsLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            color: _cAccent,
            backgroundColor: _cLine,
          )
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showFlowAssetSheet,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: _cFieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _assetError == null ? _cLine : AppColors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedAsset?['name']?.toString() ??
                            'کەرەستەیەک هەڵبژێرە',
                        style: TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: _selectedAsset == null ? _cSlate : _cInk,
                        ),
                      ),
                    ),
                    Text(
                      _selectedAsset == null ? 'هەڵبژاردن' : 'گۆڕین',
                      style: const TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _cAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_assetError != null) ...[
          const SizedBox(height: 5),
          Text(
            _assetError!,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppColors.red,
            ),
          ),
        ],
        const SizedBox(height: 5),
        const Text(
          'کەرەستەیەکی هەڵە وا دەکات کڕیار نەتوانێت پەیوەندیت پێوە بکات',
          style: TextStyle(
            fontFamily: kAppFont,
            fontSize: 10.5,
            color: AppColors.red,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Future<void> _showFlowAssetSheet() async {
    if (_assets.isEmpty) {
      _queueFormError('هیچ کەرەستەیەکی پەیوەندیت زیاد نەکردووە');
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.68,
          ),
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: _cCard,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _cLine,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'کەرەستەی پەیوەندی هەڵبژێرە',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _cInk,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _assets.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: _cLine,
                  ),
                  itemBuilder: (_, index) {
                    final asset = _assets[index];
                    final active = asset['id']?.toString() == _selectedAssetId;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        asset['name']?.toString() ?? '—',
                        style: TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 13.5,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? _cAccent : _cInk,
                        ),
                      ),
                      subtitle: Text(
                        '#${asset['card_number'] ?? '—'}',
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 11,
                          color: _cSlate,
                        ),
                      ),
                      onTap: () => Navigator.pop(sheetContext, asset),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedAsset = selected;
        _selectedAssetId = selected['id']?.toString();
        _assetError = null;
      });
    }
  }

  Widget _buildCategoryFlowSection() {
    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle(
            'بەشەکان',
            helper: 'ئەو بەشە هەڵبژێرە کە ڕیکلامەکەت باشتر وەسف دەکات',
          ),
          const SizedBox(height: 6),
          _flowLabel('بەشی ڕیکلام', important: true),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAdCategories.map((option) {
              final selected = _category == option.slug;
              return ChoiceChip(
                label: Text(option.label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  if (selected) return;
                  setState(() {
                    _category = option.slug;
                    _categoryError = null;
                  });
                  _resetFastPayIntent();
                },
                backgroundColor: _cFieldFill,
                selectedColor: _cAccent.withValues(alpha: 0.08),
                side: BorderSide(
                  color: selected ? _cAccent : _cLine,
                  width: selected ? 1.25 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                labelStyle: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _cAccent : _cSlate,
                  height: 1.35,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
              );
            }).toList(growable: false),
          ),
          if (_categoryError != null) ...[
            const SizedBox(height: 8),
            Text(
              _categoryError!,
              style: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.red,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudienceFlowSection() {
    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle('ئامانجی بینەران'),
          const SizedBox(height: 15),
          _flowLabel('تەمەن'),
          _buildFlowAgeChoices(),
          const SizedBox(height: 15),
          _flowLabel('ڕەگەز'),
          _GlideSegmented(
            value: _gender,
            options: const [
              _TextOption('all', 'هەموو'),
              _TextOption('male', 'نێر'),
              _TextOption('female', 'مێ'),
            ],
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 15),
          _flowLabel('شوێن'),
          _GlideSegmented(
            value: _location,
            options: const [
              _TextOption('all', 'هەموو'),
              _TextOption('kurdistan', 'کوردستان'),
              _TextOption('iraq', 'عێراق'),
            ],
            onChanged: (value) => setState(() => _location = value),
          ),
          const SizedBox(height: 15),
          _flowLabel('جۆری ئامێر'),
          _PlainChoiceRow(
            value: _deviceType,
            options: const [
              _TextOption('all', 'هەموو'),
              _TextOption('iphone', 'ئایفۆن'),
              _TextOption('android', 'ئەندرۆید'),
            ],
            onChanged: (value) => setState(() => _deviceType = value),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowAgeChoices() {
    const options = [
      _TextOption('all', 'هەموو'),
      _TextOption('13-17', '13–17'),
      _TextOption('18-24', '18–24'),
      _TextOption('25-34', '25–34'),
      _TextOption('35-44', '35–44'),
      _TextOption('45-54', '45–54'),
      _TextOption('55+', '+55'),
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: options.map((option) {
        final active = _ages.contains(option.value);
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _pickAge(option.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? _cInk : _cFieldFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _cInk : _cLine),
            ),
            child: Text(
              option.label,
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _cSlate,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBudgetFlowSection() {
    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle('بودجە و ماوە'),
          const SizedBox(height: 14),
          _flowStepperRow(
            label: 'بودجەی ڕۆژانە',
            value: '\$$_dailyUSD',
            onMinus: () => _changeBudget(-1),
            onPlus: () => _changeBudget(1),
          ),
          const Divider(height: 25, color: _cLine),
          _flowStepperRow(
            label: 'ماوەی ڕیکلام',
            value: '$_days ڕۆژ',
            onMinus: () => _changeDays(-1),
            onPlus: () => _changeDays(1),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cFieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cLine),
            ),
            child: Column(
              children: [
                _flowMetricRow('بینینی خەمڵێنراو', _estViews),
                const SizedBox(height: 9),
                _flowMetricRow(
                  _goal == 'messages'
                      ? 'کلیک و نامەی خەمڵێنراو'
                      : 'کارلێکی خەمڵێنراو',
                  _estClicks,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowStepperRow({
    required String label,
    required String value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    Widget control(String text, VoidCallback action) => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: action,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _cFieldFill,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _cLine),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: _cInk,
                  height: 1,
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _cSlate,
            ),
          ),
        ),
        control('−', onMinus),
        SizedBox(
          width: 78,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _cInk,
            ),
          ),
        ),
        control('+', onPlus),
      ],
    );
  }

  Widget _flowMetricRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _cSlate,
            ),
          ),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: kAppFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _cInk,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleFlowSection() {
    String dateLabel() {
      if (_adDate == null) return 'هەڵبژێرە';
      return '${_adDate!.year}/${_adDate!.month.toString().padLeft(2, '0')}/${_adDate!.day.toString().padLeft(2, '0')}';
    }

    String timeLabel() {
      if (_adTime == null) return 'هەڵبژێرە';
      return '${_adTime!.hour.toString().padLeft(2, '0')}:${_adTime!.minute.toString().padLeft(2, '0')}';
    }

    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle('بەروار و کاتی دەستپێک'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _flowPickerField(
                  label: 'بەروار',
                  value: dateLabel(),
                  selected: _adDate != null,
                  error: _dateError,
                  onTap: () async {
                    final now = DateTime.now();
                    final initial = _adDate != null && !_adDate!.isBefore(
                            DateTime(now.year, now.month, now.day))
                        ? _adDate!
                        : now;
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 90)),
                      builder: (_, child) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      ),
                    );
                    if (selected != null && mounted) {
                      setState(() {
                        _adDate = selected;
                        _dateError = null;
                        _timeError = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _flowPickerField(
                  label: 'کات',
                  value: timeLabel(),
                  selected: _adTime != null,
                  error: _timeError,
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: _adTime ?? TimeOfDay.now(),
                      builder: (_, child) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      ),
                    );
                    if (selected != null && mounted) {
                      setState(() {
                        _adTime = selected;
                        _timeError = null;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowPickerField({
    required String label,
    required String value,
    required bool selected,
    required String? error,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flowLabel(label, important: true),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 48,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _cFieldFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: error == null ? _cLine : AppColors.red,
                ),
              ),
              child: Text(
                value,
                textDirection: selected ? TextDirection.ltr : TextDirection.rtl,
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? _cInk : _cSlate,
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(
            error,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppColors.red,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoteFlowSection() {
    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle(
            'تێبینی',
            helper: 'ئەگەر زانیاریی زیادەت هەیە بۆ تیمی پێداچوونەوە، لێرە بینووسە',
          ),
          const SizedBox(height: 12),
          _flowLabel('تێبینی بۆ ڕیکلام', optional: true),
          TextField(
            controller: _noteCtrl,
            maxLength: 500,
            maxLines: 4,
            minLines: 3,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 14,
              color: _cInk,
              height: 1.55,
            ),
            decoration: _flowInputDecoration(
              hint: 'تێبینییەکەت لێرە بنووسە',
            ).copyWith(
              counterStyle: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 10,
                color: _cSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndCheckoutSection() {
    return _flowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowTitle('کۆی گشتی و پارەدان'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _cFieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cLine),
            ),
            child: Row(
              children: [
                const Text(
                  'کۆی گشتی',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _cSlate,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatIQD(_displayTotalIQD)} IQD',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _cInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _flowLabel('ڕێگای پارەدان', important: true),
          _paymentFlowChoice(
            value: 'app_balance',
            title: 'باڵانسی هەژمار',
            detail: _walletLoading
                ? 'باڵانس بار دەکرێت…'
                : _walletLoadFailed
                    ? 'باڵانس بار نەبوو؛ دووبارە هەوڵ بدەرەوە'
                    : 'باڵانسی بەردەست: '
                        '${_formatIQD(_walletBalanceIQD)} IQD',
          ),
          const SizedBox(height: 9),
          _paymentFlowChoice(
            value: 'fastpay',
            title: 'FastPay',
            detail: 'پارەدان بە QR یان کردنەوەی ئەپی FastPay',
          ),
          if (_quoteLoadFailed) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _quoteLoading
                    ? null
                    : () => unawaited(_retryQuoteData()),
                child: const Text(
                  'دووبارە بارکردنەوەی نرخ و باڵانس',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (_paymentMethod == 'app_balance' &&
              !_walletLoading &&
              !_walletLoadFailed) ...[
            const SizedBox(height: 8),
            Text(
              _walletBalanceUsd >= _finalUSD
                  ? 'دوای پارەدان: ${_formatIQD(_walletAfterIQD)} IQD دەمێنێتەوە'
                  : 'باڵانسی هەژمارەکەت لەنرخی ئەم داواکاریە کەمترە',
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: _walletBalanceUsd >= _finalUSD
                    ? _cSlate
                    : AppColors.red,
                height: 1.5,
              ),
            ),
          ],
          if (_paymentError != null) ...[
            const SizedBox(height: 7),
            Text(
              _paymentError!,
              style: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentFlowChoice({
    required String value,
    required String title,
    required String detail,
  }) {
    final selected = _paymentMethod == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_paymentMethod != value && _hasFastPayIntent) {
            _resetFastPayIntent();
          }
          setState(() {
            _paymentMethod = value;
            _paymentError = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? _cAccent.withValues(alpha: 0.045)
                : _cFieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _cAccent : _cLine,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? _cAccent : _cInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: _cSlate,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandablePriceDock() {
    final busy = _submitting ||
        _creatingFastPayOrder ||
        _finalizingFastPay ||
        _quoteLoading;
    String buttonLabel;
    if (_quoteLoading) {
      buttonLabel = 'نرخ و باڵانس پشکنین دەکرێت…';
    } else if (_creatingFastPayOrder) {
      buttonLabel = 'پارەدان دروست دەکرێت…';
    } else if (_finalizingFastPay || _submitting) {
      buttonLabel = 'داواکارییەکە تۆمار دەکرێت…';
    } else if (_paymentMethod == 'fastpay') {
      buttonLabel = 'بەردەوامبوون بۆ FastPay';
    } else {
      buttonLabel = 'ناردنی داواکاری';
    }

    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: _cCard,
            border: Border(top: BorderSide(color: _cLine)),
            boxShadow: [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_priceExpanded) ...[
                _priceDockDetails(),
                const SizedBox(height: 8),
              ],
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _priceExpanded = !_priceExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  child: Row(
                    children: [
                      const Text(
                        'کۆی گشتی',
                        style: TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _cSlate,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 220),
                        turns: _priceExpanded ? 0.5 : 0,
                        child: SolarIcon(
                          _Ico.expand,
                          style: SolarIconStyle.linear,
                          size: 19,
                          color: _cIcon,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_formatIQD(_displayTotalIQD)} IQD',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _cInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: busy ? null : _handleCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: _cAccent,
                    disabledBackgroundColor:
                        _cAccent.withValues(alpha: 0.55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              buttonLabel,
                              style: const TextStyle(
                                fontFamily: kAppFont,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          buttonLabel,
                          style: const TextStyle(
                            fontFamily: kAppFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceDockDetails() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _cFieldFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _cLine),
      ),
      child: Column(
        children: [
          _priceDockRow(
            'کرێی سپۆنسەرکردن',
            '${_formatIQD(_sponsorUSD * _iqdRate)} IQD',
          ),
          const SizedBox(height: 7),
          _priceDockRow(
            'کرێی خزمەتگوزاری',
            '${_formatIQD(_serviceUSD * _iqdRate)} IQD',
          ),
          if (_promoDiscount > 0) ...[
            const SizedBox(height: 7),
            _priceDockRow(
              'داشکاندنی کۆد',
              '-${_formatIQD(_promoDiscount * _iqdRate)} IQD',
              valueColor: AppColors.green,
            ),
          ],
          if (_levelDiscountUSD > 0) ...[
            const SizedBox(height: 7),
            _priceDockRow(
              'داشکاندنی ئاست ($_levelNameKu)',
              '-${_formatIQD(_levelDiscountUSD * _iqdRate)} IQD',
              valueColor: AppColors.green,
            ),
          ],
          const Divider(height: 19, color: _cLine),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCtrl,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_promoApplied) {
                      if (_hasFastPayIntent) _resetFastPayIntent();
                      setState(() {
                        _clearPromoValues();
                        _promoOk = false;
                      });
                    }
                  },
                  style: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _cInk,
                    letterSpacing: 1.1,
                  ),
                  decoration: _flowInputDecoration(
                    hint: 'کۆدی داشکاندن',
                  ).copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 43,
                child: FilledButton(
                  onPressed: _promoLoading ? null : _applyPromo,
                  style: FilledButton.styleFrom(
                    backgroundColor: _cInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: _promoLoading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'بەکارهێنان',
                          style: TextStyle(
                            fontFamily: kAppFont,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_promoMsg.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _promoMsg,
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _promoOk ? AppColors.green : AppColors.red,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceDockRow(
    String label,
    String value, {
    Color valueColor = _cInk,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _cSlate,
            ),
          ),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: kAppFont,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<void> _showFastPaySheet() async {
    if (!mounted || _fastPaySheetOpen) return;
    _fastPaySheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: ValueListenableBuilder<_FastPayProgress>(
          valueListenable: _fastPayProgress,
          builder: (_, progress, __) {
            final busy = progress.stage == _FastPayStage.creating ||
                progress.stage == _FastPayStage.opening ||
                progress.stage == _FastPayStage.checking;
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: BoxDecoration(
                color: _cCard,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _cLine,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.asset(
                          'assets/logos/fastpay.jpg',
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            color: _cFieldFill,
                            child: const Text(
                              'FastPay',
                              style: TextStyle(
                                fontFamily: kAppFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _cInk,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'پارەدان بە FastPay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _cInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatIQD(_displayTotalIQD)} IQD',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: _cInk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 196,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _cLine),
                      ),
                      child: _fastPayQrUrl == null || _fastPayQrUrl!.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _cAccent,
                              ),
                            )
                          : Image.network(
                              _fastPayQrUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, loading) =>
                                  loading == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: _cAccent,
                                          ),
                                        ),
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text(
                                  'وێنەی QR پیشان نەدرا؛ «کردنەوەی FastPay» لێبدە',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: kAppFont,
                                    fontSize: 12,
                                    color: _cSlate,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: progress.stage == _FastPayStage.checking ||
                                progress.stage == _FastPayStage.opening
                            ? null
                            : progress.paid
                                ? 1
                                : progress.stage == _FastPayStage.ready
                                    ? 0.35
                                    : progress.stage == _FastPayStage.waiting
                                        ? 0.6
                                        : 0.12,
                        color: progress.terminalFailure
                            ? AppColors.red
                            : _cAccent,
                        backgroundColor: _cLine,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: progress.terminalFailure
                            ? AppColors.red
                            : progress.paid
                                ? AppColors.green
                                : _cSlate,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: busy || progress.paid
                            ? null
                            : progress.terminalFailure
                                ? _restartFastPayPayment
                                : _openFastPay,
                        style: FilledButton.styleFrom(
                          backgroundColor: _cAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: busy
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 9),
                                  Text(
                                    'چاوەڕێ بکە…',
                                    style: TextStyle(
                                      fontFamily: kAppFont,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                progress.terminalFailure
                                    ? 'دروستکردنی پارەدانێکی نوێ'
                                    : 'کردنەوەی FastPay',
                                style: const TextStyle(
                                  fontFamily: kAppFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    if (!progress.terminalFailure) ...[
                      const SizedBox(height: 5),
                      TextButton(
                        onPressed: busy || progress.paid
                            ? null
                            : () => _verifyFastPayPayment(showFailure: true),
                        child: const Text(
                          'پشکنینی پارەدان',
                          style: TextStyle(
                            fontFamily: kAppFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _cSlate,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        ),
      );
    } finally {
      _fastPaySheetOpen = false;
    }
  }
}
