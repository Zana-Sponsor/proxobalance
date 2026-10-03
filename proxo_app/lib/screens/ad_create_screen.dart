import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show supabase;
import '../services/ad_categories.dart';
import '../services/ad_forecast.dart';
import '../services/ad_submission.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/ad_validation_notifications.dart';
import '../widgets/proxo_text.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'ad_confirmation_screen.dart';
import 'tools_screen.dart';

class AdCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? proxoCard;
  final VoidCallback? onAdCreated;
  final AdCreationRepository? repository;
  final Future<Map<String, dynamic>?> Function(BuildContext)? createContactPage;
  const AdCreateScreen(
      {super.key,
      this.proxoCard,
      this.onAdCreated,
      this.repository,
      this.createContactPage});
  @override
  State<AdCreateScreen> createState() => _AdCreateScreenState();
}

class _AdCreateScreenState extends State<AdCreateScreen> {
  static const _budgets = [10, 20, 50, 100, 200, 500, 1000];
  final _name = TextEditingController(),
      _code = TextEditingController(),
      _link = TextEditingController(),
      _note = TextEditingController(),
      _coupon = TextEditingController();
  final _errors = AdValidationController();
  late final AdCreationRepository _repository;
  List<Map<String, dynamic>> _assets = [];
  bool _assetsLoading = true, _assetsFailed = false;
  String? _goal, _category, _assetId, _payment, _appliedCoupon;
  String _location = 'all', _gender = 'all', _device = 'all';
  final Set<String> _ages = {'all'};
  int _daily = 10, _days = 1, _quoteRevision = 0;
  bool _immediate = true,
      _quoteBusy = true,
      _couponBusy = false,
      _openingConfirmation = false;
  DateTime? _date;
  TimeOfDay? _time;
  AdQuote? _quote;
  final Map<String, double?> _viewRates = {};
  String? _quoteError, _couponMessage;
  bool _couponValid = false;
  AdPendingSubmission? _pending;
  bool _pendingLoadFailed = false;
  bool _pendingLoading = true;
  Map<String, String> _fieldErrors = {};
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseAdCreationRepository(supabase);
    if (widget.proxoCard != null) {
      final j = widget.proxoCard!;
      if (j.containsKey('video_link') || j.containsKey('goal')) {
        _restore(AdDraft.fromJson(j));
        _immediate = true;
      } else {
        _goal = 'messages';
        _assetId = j['id']?.toString();
      }
    }
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _loadPending();
    await Future.wait([_loadAssets(), _loadQuote()]);
  }

  Future<void> _loadPending() async {
    if (mounted) setState(() => _pendingLoading = true);
    try {
      final pending = await _repository.pending();
      if (!mounted) return;
      setState(() {
        _pendingLoadFailed = false;
        _pending = pending;
        if (pending != null) {
          _restore(pending.draft);
          _quote = pending.quote;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _pendingLoadFailed = true);
      }
    } finally {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  void _restore(AdDraft d) {
    _name.text = d.title;
    _code.text = d.code;
    _link.text = d.link;
    _note.text = d.note;
    _goal = d.goal;
    _category = isSupportedAdCategory(d.category) ? d.category : null;
    _assetId = d.assetId;
    _payment = d.paymentMethod;
    _location = d.location;
    _gender = d.gender;
    _device = d.device;
    _daily = _budgets.contains(d.dailyBudget) ? d.dailyBudget : 10;
    _days = d.days.clamp(1, 7);
    _ages
      ..clear()
      ..addAll(d.ages);
    _immediate = d.immediate;
    _date = d.schedule;
    if (d.schedule != null) {
      _time = TimeOfDay(hour: d.schedule!.hour, minute: d.schedule!.minute);
    }
    _appliedCoupon = d.promoCode;
    _coupon.text = d.promoCode ?? '';
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _errors.dispose();
    for (final c in [_name, _code, _link, _note, _coupon]) {
      c.dispose();
    }
    super.dispose();
  }

  AdDraft _draft({String? coupon, bool replaceCoupon = false}) {
    final now = adScheduleNow();
    final schedule = _immediate
        ? DateTime(now.year, now.month, now.day, now.hour, now.minute + 2)
        : _date == null || _time == null
            ? null
            : DateTime(_date!.year, _date!.month, _date!.day, _time!.hour,
                _time!.minute);
    return AdDraft(
        title: _name.text,
        link: _link.text,
        code: _code.text,
        note: _note.text,
        goal: _goal,
        category: _category,
        assetId: _assetId,
        assetName: _assets
            .where((a) => '${a['id']}' == _assetId)
            .firstOrNull?['name']
            ?.toString(),
        paymentMethod: _payment,
        ages: List.unmodifiable(_ages),
        gender: _gender,
        location: _location,
        device: _device,
        dailyBudget: _daily,
        days: _days,
        schedule: schedule,
        immediate: _immediate,
        promoCode: replaceCoupon ? coupon : _appliedCoupon);
  }

  Future<void> _loadAssets() async {
    if (mounted) {
      setState(() {
        _assetsLoading = true;
        _assetsFailed = false;
      });
    }
    try {
      final assets = await _repository.loadAssets();
      if (mounted) {
        setState(() {
          _assets = assets;
          _assetsLoading = false;
          if (_assetId != null &&
              !assets.any((a) => '${a['id']}' == _assetId)) {
            _assetId = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _assetsLoading = false;
          _assetsFailed = true;
        });
      }
    }
  }

  void _refreshQuote({bool clearPromo = false}) {
    _quoteTimer?.cancel();
    _quoteRevision++;
    setState(() {
      _quote = _quote?.forBudget(_daily, _days, clearPromo: clearPromo);
      _quoteBusy = true;
      _quoteError = null;
    });
    _quoteTimer =
        Timer(const Duration(milliseconds: 180), () => unawaited(_loadQuote()));
  }

  Future<void> _loadQuote() async {
    final revision = ++_quoteRevision;
    if (mounted) {
      setState(() {
        _quoteBusy = true;
        _quoteError = null;
      });
    }
    try {
      final quote = await _repository.quote(_draft());
      if (!mounted || revision != _quoteRevision) return;
      setState(() {
        _quote = quote;
        _quoteBusy = false;
        if (_goal != null) _viewRates[_goal!] = quote.historicalViewRate;
      });
    } catch (e) {
      if (!mounted || revision != _quoteRevision) return;
      setState(() {
        _quoteBusy = false;
        _quoteError = e is AdSubmissionFailure
            ? e.message
            : 'نرخ و باڵانس بار نەبوو؛ دووبارە هەوڵ بدەرەوە';
        if (e is AdSubmissionFailure && e.code == 'INVALID_PROMO') {
          _appliedCoupon = null;
          _couponValid = false;
          _couponMessage = e.message;
          _quote = _quote?.forBudget(_daily, _days, clearPromo: true);
        }
      });
      if (e is AdSubmissionFailure && e.code == 'INVALID_PROMO') {
        unawaited(_loadQuote());
      }
    }
  }

  Future<void> _applyCoupon() async {
    if (_couponBusy) return;
    final value = _coupon.text.trim().toUpperCase();
    if (value.isEmpty) {
      setState(() {
        _couponMessage = 'کۆدی داشکاندن بنووسە';
        _couponValid = false;
      });
      return;
    }
    _quoteTimer?.cancel();
    final revision = ++_quoteRevision;
    setState(() {
      _couponBusy = true;
      _quoteBusy = true;
      _couponMessage = null;
    });
    try {
      final q =
          await _repository.quote(_draft(coupon: value, replaceCoupon: true));
      if (!mounted ||
          revision != _quoteRevision ||
          _coupon.text.trim().toUpperCase() != value) {
        return;
      }
      setState(() {
        _appliedCoupon = q.promoUsd > 0 ? value : null;
        _quote = q;
        _couponValid = q.promoUsd > 0;
        _couponMessage = _couponValid
            ? 'کۆدی داشکاندن بەکار هێنرا'
            : 'ئەم کۆدە داشکاندنی بەردەستی نییە';
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted || revision != _quoteRevision) return;
      setState(() {
        _appliedCoupon = null;
        _couponValid = false;
        _quote = _quote?.forBudget(_daily, _days, clearPromo: true);
        _couponMessage = e is AdSubmissionFailure
            ? e.message
            : 'پشکنینی کۆد سەرکەوتوو نەبوو';
      });
    } finally {
      if (mounted) {
        setState(() {
          _couponBusy = false;
          if (revision == _quoteRevision) _quoteBusy = false;
        });
      }
    }
  }

  Future<void> _createContact() async {
    final card = widget.createContactPage != null
        ? await widget.createContactPage!(context)
        : await Navigator.of(context).push<Map<String, dynamic>>(
            MaterialPageRoute(
                builder: (routeContext) => ToolsScreen(
                    initialCreate: true,
                    onUseForAd: (card) =>
                        Navigator.of(routeContext).pop(card))));
    if (!mounted) return;
    await _loadAssets();
    if (mounted &&
        card != null &&
        _assets.any((a) => '${a['id']}' == '${card['id']}')) {
      setState(() {
        _assetId = card['id']?.toString();
        _fieldErrors.remove('asset');
      });
    }
  }

  Future<void> _checkout() async {
    if (_openingConfirmation || _pendingLoading) return;
    if (_pendingLoadFailed) {
      await _loadPending();
      if (!mounted || _pendingLoadFailed) return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_pending != null) {
      await _openConfirmation(_pending!, resume: true);
      return;
    }
    final draft = _draft();
    final errors = draft.validate();
    if (draft.goal == 'messages' &&
        !_assets.any((a) => '${a['id']}' == draft.assetId)) {
      errors['asset'] = 'پەڕەی پەیوەندییەکی بەردەست هەڵبژێرە';
    }
    setState(() => _fieldErrors = errors);
    if (errors.isNotEmpty) {
      _errors.show(errors);
      return;
    }
    setState(() => _openingConfirmation = true);
    try {
      _quoteTimer?.cancel();
      ++_quoteRevision;
      final quote = await _repository.quote(draft);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _quoteBusy = false;
        _quoteError = null;
      });
      if (draft.paymentMethod == 'app_balance' &&
          quote.balanceUsd + 0.000001 < quote.costUsd) {
        setState(() => _quoteError = 'باڵانسی پێویستت بەردەست نییە');
        return;
      }
      if (draft.paymentMethod == 'fastpay' && quote.totalIqd < 1000) {
        setState(() => _quoteError = 'بڕی پارەدان بۆ FastPay زۆر کەمە');
        return;
      }
      await _openConfirmation(AdPendingSubmission.create(draft, quote));
    } catch (e) {
      if (mounted) {
        setState(() => _quoteError = e is AdSubmissionFailure
            ? e.message
            : 'پشکنینی نرخ سەرکەوتوو نەبوو');
      }
    } finally {
      if (mounted) setState(() => _openingConfirmation = false);
    }
  }

  Future<void> _openConfirmation(AdPendingSubmission request,
      {bool resume = false}) async {
    setState(() => _openingConfirmation = true);
    final result = await Navigator.of(context).push<AdConfirmationResult>(
        MaterialPageRoute(
            builder: (_) => AdConfirmationScreen(
                request: request, repository: _repository, resume: resume)));
    if (!mounted) return;
    if (result?.adId != null) {
      widget.onAdCreated?.call();
      if (mounted) Navigator.of(context).pop('refresh');
      return;
    }
    if (result?.useWallet == true) {
      setState(() => _payment = 'app_balance');
      await _loadQuote();
    }
    await _loadPending();
    if (mounted) setState(() => _openingConfirmation = false);
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: AdUi.theme(context),
      child: Builder(
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Column(children: [
                ReceiptAppBar(
                    title: 'دروستکردنی ڕیکلام',
                    onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                    child: Stack(children: [
                  SingleChildScrollView(
                    key: const ValueKey('ad-form-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_pendingLoadFailed) ...[
                                    AdFormSection(
                                        title: 'پشکنینی داواکاریی پێشوو',
                                        child: Column(children: [
                                          ProxoText(
                                              'داواکارییە پێشووەکە بار نەبوو؛ پێش داواکارییەکی نوێ دووبارە هەوڵ بدەرەوە.',
                                              style: AdUi.text(context)),
                                          TextButton(
                                              onPressed: _pendingLoading
                                                  ? null
                                                  : _loadPending,
                                              child: const ProxoText(
                                                  'دووبارە پشکنینەوە')),
                                        ])),
                                    const SizedBox(height: 18),
                                  ],
                                  if (_pending != null) ...[
                                    AdFormSection(
                                        title: 'داواکارییەکی پێشوو',
                                        child: Column(children: [
                                          ProxoText(
                                              'ئەنجامی داواکارییەکە پێویستی بە پشکنین هەیە.',
                                              style: AdUi.text(context)),
                                          const SizedBox(height: 12),
                                          FilledButton(
                                              onPressed: _openingConfirmation
                                                  ? null
                                                  : _checkout,
                                              child: const ProxoText(
                                                  'پشکنینی هەمان داواکاری')),
                                        ])),
                                    const SizedBox(height: 18),
                                  ],
                                  IgnorePointer(
                                      ignoring: _pending != null,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _information(context),
                                            const SizedBox(height: 18),
                                            _objective(context),
                                            const SizedBox(height: 18),
                                            _audience(context),
                                            const SizedBox(height: 18),
                                            _budget(context),
                                            const SizedBox(height: 18),
                                            _schedule(context),
                                            const SizedBox(height: 18),
                                            _couponSection(context),
                                            const SizedBox(height: 18),
                                            _forecast(context),
                                            const SizedBox(height: 18),
                                            _pricing(context),
                                            const SizedBox(height: 18),
                                            _submission(context),
                                          ])),
                                ]))),
                  ),
                  Positioned(
                      top: 8,
                      left: 16,
                      right: 16,
                      child: IgnorePointer(
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: 600,
                                      maxHeight:
                                          MediaQuery.sizeOf(context).height *
                                              0.28),
                                  child: SingleChildScrollView(
                                      child: AdValidationNotifications(
                                          controller: _errors)))))),
                ])),
              ]),
            )),
      ));
  Widget _label(BuildContext context, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProxoText(label,
          style: AdUi.text(context), textAlign: TextAlign.right));
  Widget _error(BuildContext context, String key) => _fieldErrors[key] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ProxoText(_fieldErrors[key]!,
              style: AdUi.text(context, color: const Color(0xFFB74956))));
  Widget _field(BuildContext context, String id,
          TextEditingController controller, String label,
          {bool ltr = false, TextInputType? keyboard, int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(context, label),
        ProxoDirectionalInput(
            controller: controller,
            forceLtr: ltr,
            keyboardType: keyboard,
            builder: (_, direction) => TextField(
                key: ValueKey('ad-$id'),
                controller: controller,
                textDirection: direction,
                textAlign: TextAlign.start,
                keyboardType: keyboard,
                maxLines: maxLines,
                style: AdUi.text(context),
                autocorrect: !ltr,
                textInputAction: maxLines == 1
                    ? TextInputAction.next
                    : TextInputAction.newline,
                onChanged: (_) => setState(() => _fieldErrors.remove(id)),
                decoration: const InputDecoration())),
        _error(context, id),
      ]);
  Widget _information(BuildContext context) => AdFormSection(
      title: 'زانیاری ڕیکلام',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _field(context, 'title', _name, 'ناوی ڕیکلام'),
        const SizedBox(height: 16),
        _field(context, 'code', _code, 'کۆدی ڤیدیۆ', ltr: true),
        const SizedBox(height: 16),
        // Existing video processing and thumbnails require the URL as well as the authorization code.
        _field(context, 'link', _link, 'بەستەری ڤیدیۆ',
            ltr: true, keyboard: TextInputType.url),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: ProxoText('تێبینی (ئارەزوومەندانە)',
                style: AdUi.text(context, color: AdUi.secondary)),
            children: [_field(context, 'note', _note, 'تێبینی', maxLines: 3)]),
      ]));
  Widget _choices(BuildContext context, String field, String value,
          List<(String, String)> options, ValueChanged<String> onChanged) =>
      Wrap(
          spacing: 8,
          runSpacing: 8,
          textDirection: TextDirection.rtl,
          children: [
            for (final o in options)
              AdChoice(
                  key: ValueKey('$field-${o.$1}'),
                  label: o.$2,
                  selected: value == o.$1,
                  onTap: () {
                    onChanged(o.$1);
                    setState(() => _fieldErrors.remove(field));
                  })
          ]);
  Widget _objective(BuildContext context) => AdFormSection(
      title: 'ئامانجی ڕیکلام',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _choices(context, 'goal', _goal ?? '', const [
          ('views', 'کارلێک و بینین'),
          ('messages', 'نامە و فرۆش')
        ], (v) {
          setState(() => _goal = v);
          _refreshQuote();
        }),
        _error(context, 'goal'),
        AnimatedSize(
            duration: const Duration(milliseconds: 240),
            alignment: Alignment.topCenter,
            child: _goal != 'messages'
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label(context, 'پەڕەی پەیوەندی'),
                          if (_assetsLoading)
                            const LinearProgressIndicator(minHeight: 2)
                          else if (_assetsFailed)
                            TextButton(
                                onPressed: _loadAssets,
                                child: const ProxoText(
                                    'دووبارە بارکردنەوەی پەڕەکان'))
                          else if (_assets.isEmpty)
                            ProxoText(
                                'پەڕەی پەیوەندیت نییە؛ پەڕەیەکی نوێ دروست بکە.',
                                style:
                                    AdUi.text(context, color: AdUi.secondary))
                          else
                            DropdownButtonFormField<String>(
                                key: ValueKey(
                                    'asset-$_assetId-${_assets.length}'),
                                initialValue: _assetId,
                                isExpanded: true,
                                style: AdUi.text(context),
                                hint:
                                    const ProxoText('پەڕەی پەیوەندی هەڵبژێرە'),
                                items: [
                                  for (final a in _assets)
                                    DropdownMenuItem(
                                        value: '${a['id']}',
                                        child: ProxoText('${a['name'] ?? ''}',
                                            maxLines: 2))
                                ],
                                onChanged: (v) => setState(() {
                                      _assetId = v;
                                      _fieldErrors.remove('asset');
                                    })),
                          _error(context, 'asset'),
                          const SizedBox(height: 10),
                          Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton(
                                  onPressed: _createContact,
                                  child:
                                      const ProxoText('دروستکردنی پەڕەی نوێ'))),
                        ]))),
      ]));
  Widget _audience(BuildContext context) => AdFormSection(
      title: 'ئامانجی بینەران',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(context, 'شوێن'),
        _choices(
            context,
            'location',
            _location,
            const [
              ('all', 'هەموو'),
              ('kurdistan', 'کوردستان'),
              ('iraq', 'عێراق')
            ],
            (v) => setState(() => _location = v)),
        const SizedBox(height: 18),
        _label(context, 'تەمەن'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final age in const [
            'all',
            '18-24',
            '25-34',
            '35-44',
            '45-54',
            '55+'
          ])
            AdChoice(
                key: ValueKey('age-$age'),
                label: age == 'all' ? 'هەموو' : age,
                selected: _ages.contains(age),
                onTap: () => setState(() {
                      if (age == 'all') {
                        _ages
                          ..clear()
                          ..add('all');
                      } else {
                        _ages.remove('all');
                        if (!_ages.add(age)) _ages.remove(age);
                        if (_ages.isEmpty) _ages.add('all');
                      }
                    }))
        ]),
        const SizedBox(height: 18),
        _label(context, 'ڕەگەز'),
        _choices(
            context,
            'gender',
            _gender,
            const [('all', 'هەموو'), ('male', 'نێر'), ('female', 'مێ')],
            (v) => setState(() => _gender = v)),
        const SizedBox(height: 18),
        _label(context, 'پۆل'),
        DropdownButtonFormField<String>(
            key: ValueKey('category-$_category'),
            initialValue: _category,
            isExpanded: true,
            style: AdUi.text(context),
            hint: const ProxoText('پۆلی ڕیکلام هەڵبژێرە'),
            items: [
              for (final c in kAdCategories)
                DropdownMenuItem(value: c.slug, child: ProxoText(c.label))
            ],
            onChanged: (v) => setState(() {
                  _category = v;
                  _fieldErrors.remove('category');
                })),
        _error(context, 'category'),
        const SizedBox(height: 18),
        _label(context, 'ئامێر'),
        _choices(
            context,
            'device',
            _device,
            const [
              ('all', 'هەموو'),
              ('iphone', 'iPhone'),
              ('android', 'Android')
            ],
            (v) => setState(() => _device = v)),
        _error(context, 'audience'),
      ]));
  String _budgetIqd(int usd) => adIqd(usd * (_quote?.rate ?? 1800));

  Widget _budget(BuildContext context) => AdFormSection(
      title: 'بودجە و ماوەی ڕیکلام',
      child: Column(children: [
        AdValueRow(label: 'بودجەی ڕۆژانە', value: _budgetIqd(_daily)),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(
                key: const ValueKey('daily-budget-slider'),
                min: 0,
                max: (_budgets.length - 1).toDouble(),
                divisions: _budgets.length - 1,
                value: _budgets.indexOf(_daily).toDouble(),
                activeColor: AdUi.blue,
                label: _budgetIqd(_daily),
                onChanged: (v) {
                  setState(() => _daily = _budgets[v.round()]);
                  _refreshQuote();
                })),
        const SizedBox(height: 12),
        AdValueRow(label: 'ماوەی ڕیکلام', value: '$_days ڕۆژ'),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(
                key: const ValueKey('duration-slider'),
                min: 1,
                max: 7,
                divisions: 6,
                value: _days.toDouble(),
                activeColor: AdUi.blue,
                label: '$_days',
                onChanged: (v) {
                  setState(() => _days = v.round());
                  _refreshQuote();
                })),
        const Divider(height: 24, color: ReceiptTokens.divider),
        AdValueRow(
            label: 'کۆی بودجە',
            value: _budgetIqd(_daily * _days),
            color: AdUi.blue),
        _error(context, 'budget'),
      ]));
  Widget _schedule(BuildContext context) => AdFormSection(
      title: 'بەروار و کاتی دەستپێک',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _choices(
            context,
            'schedule',
            _immediate ? 'now' : 'later',
            const [
              ('now', 'زووترین کاتی بەردەست'),
              ('later', 'دیاریکردنی کات')
            ],
            (v) => setState(() => _immediate = v == 'now')),
        if (!_immediate) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton(
                key: const ValueKey('ad-date'),
                onPressed: () async {
                  final now = adScheduleNow(),
                      today = DateTime(adScheduleNow().year,
                          adScheduleNow().month, adScheduleNow().day);
                  final lastDate =
                      DateUtils.dateOnly(now.add(const Duration(days: 90)));
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _date != null &&
                              !_date!.isBefore(today) &&
                              !DateUtils.dateOnly(_date!).isAfter(lastDate)
                          ? _date
                          : today,
                      firstDate: today,
                      lastDate: lastDate,
                      builder: (_, child) => Directionality(
                          textDirection: TextDirection.rtl, child: child!));
                  if (mounted && date != null) {
                    setState(() {
                      _date = date;
                      _fieldErrors.remove('schedule');
                    });
                  }
                },
                child: ProxoText(_date == null
                    ? 'بەروار هەڵبژێرە'
                    : '${_date!.day}/${_date!.month}/${_date!.year}')),
            OutlinedButton(
                key: const ValueKey('ad-time'),
                onPressed: () async {
                  final now = adScheduleNow();
                  final time = await showTimePicker(
                      context: context,
                      initialTime: _time ??
                          TimeOfDay(hour: now.hour, minute: now.minute),
                      builder: (_, child) => Directionality(
                          textDirection: TextDirection.rtl, child: child!));
                  if (mounted && time != null) {
                    setState(() {
                      _time = time;
                      _fieldErrors.remove('schedule');
                    });
                  }
                },
                child: ProxoText(_time == null
                    ? 'کات هەڵبژێرە'
                    : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}')),
          ])
        ],
        _error(context, 'schedule'),
      ]));
  Widget _couponSection(BuildContext context) => AdFormSection(
      title: 'کۆدی داشکاندن',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ProxoDirectionalInput(
            controller: _coupon,
            forceLtr: true,
            builder: (_, dir) => TextField(
                key: const ValueKey('ad-coupon'),
                controller: _coupon,
                textDirection: dir,
                style: AdUi.text(context),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                onChanged: (_) {
                  setState(() {
                    _appliedCoupon = null;
                    _couponMessage = null;
                    _couponValid = false;
                  });
                  _refreshQuote(clearPromo: true);
                },
                decoration: const InputDecoration(
                    hint: ProxoText('کۆدی داشکاندن (ئارەزوومەندانە)')))),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
                onPressed: _couponBusy ? null : _applyCoupon,
                child: ProxoText(_couponBusy ? 'پشکنین…' : 'بەکارهێنانی کۆد'))),
        if (_couponMessage != null) ...[
          const SizedBox(height: 8),
          ProxoText(_couponMessage!,
              style: AdUi.text(context,
                  color: _couponValid ? AdUi.green : const Color(0xFFB74956)))
        ],
      ]));
  Widget _forecast(BuildContext context) {
    final f = AdForecast.calculate(
        goal: _goal ?? 'views',
        dailyBudget: _daily,
        days: _days,
        historicalViewRate: _viewRates[_goal]);
    String range(int lo, int hi) {
      String n(int v) => '$v'.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
      return '${n(lo)} – ${n(hi)}';
    }

    return AdFormSection(
        title: 'پێشبینی ئەنجام',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_goal == null)
            ProxoText('سەرەتا ئامانجی ڕیکلام هەڵبژێرە.',
                style: AdUi.text(context, color: AdUi.secondary))
          else ...[
            AdValueRow(
                label: 'پێشبینی بینینەکان',
                value: range(f.viewsLow, f.viewsHigh)),
            if (_goal == 'messages') ...[
              const SizedBox(height: 12),
              AdValueRow(
                  label: 'پێشبینی کرتەکان',
                  value: range(f.clicksLow!, f.clicksHigh!)),
              const SizedBox(height: 6),
              ProxoText('کرتەی پەڕەی پەیوەندی؛ بە گریمانەی کاتی.',
                  style: AdUi.text(context, color: AdUi.secondary))
            ],
            if (f.provisionalViews) ...[
              const SizedBox(height: 6),
              ProxoText('پێشبینی بینین بە گریمانەی کاتی.',
                  style: AdUi.text(context, color: AdUi.secondary))
            ],
          ],
          const SizedBox(height: 14),
          ProxoText(adForecastDisclaimer,
              style: AdUi.text(context, color: AdUi.secondary)),
        ]));
  }

  Widget _pricing(BuildContext context) => AdFormSection(
      title: 'وردەکاری نرخ',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_quote != null) ...[
          AdPriceDetails(quote: _quote!),
          const SizedBox(height: 18),
          AdValueRow(
              label: 'باڵانسی بەردەست',
              value: adIqd(_quote!.balanceUsd * _quote!.rate)),
          if (_payment == 'app_balance' &&
              _quote!.balanceUsd + 0.000001 < _quote!.costUsd) ...[
            const SizedBox(height: 10),
            ProxoText('باڵانسی پێویستت بەردەست نییە',
                style: AdUi.text(context, color: const Color(0xFFB74956)))
          ],
        ],
        if (_quoteBusy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2)
        ],
        if (_quoteError != null) ...[
          const SizedBox(height: 12),
          ProxoText(_quoteError!,
              style: AdUi.text(context, color: const Color(0xFFB74956))),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _loadQuote,
                  child: const ProxoText('دووبارە پشکنین')))
        ],
      ]));
  Widget _submission(BuildContext context) => AdFormSection(
      title: 'ناردنی ڕیکلام',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(context, 'ڕێگای پارەدان'),
        _choices(
            context,
            'payment',
            _payment ?? '',
            const [('app_balance', 'باڵانسی هەژمار'), ('fastpay', 'FastPay')],
            (v) => setState(() => _payment = v)),
        _error(context, 'payment'),
        const SizedBox(height: 18),
        FilledButton(
            key: const ValueKey('review-ad'),
            onPressed: _openingConfirmation || _couponBusy || _pendingLoading
                ? null
                : _checkout,
            child: ProxoText(
                _openingConfirmation ? 'پشکنین…' : 'پشکنین و ناردنی ڕیکلام')),
      ]));
}
