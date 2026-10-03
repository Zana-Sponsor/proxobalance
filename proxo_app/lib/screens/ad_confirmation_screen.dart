import 'dart:async';
import 'package:flutter/material.dart';

import '../services/ad_categories.dart';
import '../services/ad_submission.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/proxo_text.dart';
import '../widgets/receipt/receipt_kit.dart';

const kAdConfirmationSeconds =
    int.fromEnvironment('PROXO_AD_CONFIRM_SECONDS', defaultValue: 10);

class AdConfirmationResult {
  final String? adId;
  final bool useWallet;
  const AdConfirmationResult({this.adId, this.useWallet = false});
}

class AdConfirmationScreen extends StatefulWidget {
  final AdPendingSubmission request;
  final AdCreationRepository repository;
  final Duration countdown;
  final bool resume;
  const AdConfirmationScreen(
      {super.key,
      required this.request,
      required this.repository,
      this.countdown = const Duration(seconds: kAdConfirmationSeconds),
      this.resume = false});
  @override
  State<AdConfirmationScreen> createState() => _AdConfirmationScreenState();
}

class _AdConfirmationScreenState extends State<AdConfirmationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _countdown = AnimationController(
      vsync: this,
      duration: widget.countdown > Duration.zero
          ? widget.countdown
          : const Duration(seconds: 10));
  final _payment = ValueNotifier<AdPaymentProgress>(const AdPaymentProgress());
  bool _processing = false, _success = false, _cancelled = false;
  AdSubmissionFailure? _failure;
  bool get _canCancel =>
      !_processing &&
      !_success &&
      (_failure?.uncertain != true) &&
      (!widget.resume || _failure != null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdown.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_cancelled) {
        unawaited(_submit());
      }
    });
    if (widget.resume) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_submit()));
    } else {
      _countdown.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_processing ||
        _success ||
        _failure != null ||
        _cancelled ||
        widget.resume) {
      return;
    }
    // Do not submit unseen while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      _countdown.forward();
    } else {
      _countdown.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown.dispose();
    // The repository may finish after process/navigation interruption.
    // Keep its notifier alive until that future completes.
    if (!_processing) _payment.dispose();
    super.dispose();
  }

  void _cancel() {
    if (!_canCancel) return;
    _cancelled = true;
    _countdown.stop();
    Navigator.of(context).pop(
        AdConfirmationResult(useWallet: _failure?.paymentCredited == true));
  }

  Future<void> _submit() async {
    if (_processing || _success || _cancelled || !mounted) return;
    _countdown.stop();
    setState(() {
      _processing = true;
      _failure = null;
    });
    try {
      final adId = await widget.repository.submit(widget.request, _payment);
      if (!mounted) {
        _payment.dispose();
        return;
      }
      setState(() {
        _processing = false;
        _success = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(AdConfirmationResult(adId: adId));
    } catch (error) {
      if (!mounted) {
        _payment.dispose();
        return;
      }
      setState(() {
        _processing = false;
        _failure = error is AdSubmissionFailure
            ? error
            : const AdSubmissionFailure('NETWORK', uncertain: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: AdUi.theme(context),
      child: Builder(
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: PopScope<AdConfirmationResult>(
              canPop: _canCancel && _failure?.paymentCredited != true,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  _cancelled = true;
                  _countdown.stop();
                } else if (_canCancel) {
                  _cancel();
                }
              },
              child: Scaffold(
                backgroundColor: Colors.white,
                body: Column(children: [
                  ReceiptAppBar(
                      title: 'پشتڕاستکردنەوەی ڕیکلام',
                      onBack: _canCancel ? _cancel : null),
                  Expanded(
                      child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                      child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          child: _success
                                              ? TweenAnimationBuilder<double>(
                                                  key: const ValueKey(
                                                      'ad-success'),
                                                  tween:
                                                      Tween(begin: 0.7, end: 1),
                                                  duration: const Duration(
                                                      milliseconds: 450),
                                                  curve: Curves.easeOutBack,
                                                  builder: (_, value, child) =>
                                                      Transform.scale(
                                                          scale: value,
                                                          child: child),
                                                  child: const SizedBox(
                                                      width: 144,
                                                      height: 144,
                                                      child: Icon(
                                                          Icons
                                                              .check_circle_outline,
                                                          size: 88,
                                                          color: AdUi.blue)))
                                              : _timer(context))),
                                  const SizedBox(height: 20),
                                  ProxoText(
                                      _success
                                          ? 'ڕیکلامەکەت بە سەرکەوتوویی تۆمارکرا'
                                          : _processing || widget.resume
                                              ? 'داواکاریەکە تەواو دەکرێت'
                                              : 'ڕیکلامەکەت ئامادەیە',
                                      textAlign: TextAlign.center,
                                      style: AdUi.heading(context)),
                                  const SizedBox(height: 8),
                                  ProxoText(
                                      _processing
                                          ? 'تکایە چاوەڕێ بکە تا ئەنجامی پارەدان پشتڕاست دەکرێتەوە.'
                                          : _success
                                              ? 'دەگەڕێیتەوە بۆ ڕیکلامەکانت.'
                                              : _failure != null
                                                  ? _failure!.message
                                                  : 'دەتوانیت پێش کۆتایی ژمێرەر پاشگەز ببیتەوە.',
                                      textAlign: TextAlign.center,
                                      style: AdUi.text(context,
                                          color: AdUi.secondary)),
                                  const SizedBox(height: 24),
                                  Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(
                                          color: Color(0xFFF5F9FF),
                                          borderRadius: AdUi.radius),
                                      child: AdValueRow(
                                          label: 'کۆی گشتی',
                                          value: adIqd(
                                              widget.request.quote.totalIqd),
                                          color: AdUi.blue)),
                                  const SizedBox(height: 18),
                                  AdFormSection(
                                      title: 'کورتەی ڕیکلام',
                                      child: _summary()),
                                  const SizedBox(height: 18),
                                  AdFormSection(
                                      title: 'وردەکاری نرخ',
                                      child: AdPriceDetails(
                                          quote: widget.request.quote,
                                          showTotal: false)),
                                  if (_processing) ...[
                                    const SizedBox(height: 18),
                                    ValueListenableBuilder<AdPaymentProgress>(
                                        valueListenable: _payment,
                                        builder: (context, p, _) =>
                                            AdFormSection(
                                                title: 'پارەدان',
                                                child: Column(children: [
                                                  ProxoText(p.message,
                                                      style:
                                                          AdUi.text(context)),
                                                  if (p.waitingForPayment) ...[
                                                    if (p.qrUrl != null) ...[
                                                      const SizedBox(
                                                          height: 18),
                                                      SizedBox(
                                                          height: 200,
                                                          child: Image.network(
                                                              p.qrUrl!,
                                                              fit: BoxFit
                                                                  .contain,
                                                              errorBuilder: (_,
                                                                      __,
                                                                      ___) =>
                                                                  const ProxoText(
                                                                      'کردنەوەی FastPay لێبدە'))),
                                                    ],
                                                    if (p.deepLink != null) ...[
                                                      const SizedBox(
                                                          height: 14),
                                                      OutlinedButton(
                                                          onPressed: () async {
                                                            try {
                                                              await widget
                                                                  .repository
                                                                  .openPayment(p
                                                                      .deepLink!);
                                                            } catch (_) {
                                                              /* QR remains available if the app cannot open. */
                                                            }
                                                          },
                                                          child: const ProxoText(
                                                              'کردنەوەی FastPay')),
                                                    ],
                                                  ],
                                                ]))),
                                  ],
                                ]))),
                  )),
                ]),
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_failure != null) ...[
                              FilledButton(
                                  key: const ValueKey('retry-submission'),
                                  onPressed: _processing ? null : _submit,
                                  child: const ProxoText(
                                      'دووبارە پشکنینی هەمان داواکاری')),
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton(
                                key: const ValueKey('cancel-submission'),
                                onPressed: _canCancel ? _cancel : null,
                                child: ProxoText(
                                    _failure != null && !_failure!.uncertain
                                        ? 'گەڕانەوە بۆ دەستکاری'
                                        : 'پاشگەزبوونەوە')),
                          ])),
                ),
              ),
            )),
      ));

  Widget _timer(BuildContext context) => AnimatedBuilder(
      animation: _countdown,
      builder: (context, _) {
        final seconds = (_countdown.duration!.inMilliseconds *
                (1 - _countdown.value) /
                1000)
            .ceil();
        return SizedBox(
            width: 144,
            height: 144,
            child: Stack(alignment: Alignment.center, children: [
              const DecoratedBox(
                  decoration: BoxDecoration(
                      color: Color(0xFFF5F9FF), shape: BoxShape.circle),
                  child: SizedBox.expand()),
              Positioned.fill(
                  child: CircularProgressIndicator(
                      value: _processing || widget.resume
                          ? null
                          : 1 - _countdown.value,
                      color: AdUi.blue,
                      backgroundColor: const Color(0xFFEAF1FF),
                      strokeWidth: 3)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: ProxoText(
                        _processing || widget.resume ? '…' : '$seconds',
                        key: ValueKey(seconds),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium!
                            .copyWith(
                                color: AdUi.blue, fontWeight: FontWeight.w400),
                        textAlign: TextAlign.center)),
                if (!_processing && !widget.resume)
                  ProxoText('چرکە',
                      style: AdUi.text(context, color: AdUi.secondary)),
              ]),
            ]));
      });

  Widget _summary() {
    final d = widget.request.draft;
    String two(int n) => '$n'.padLeft(2, '0');
    final s = d.schedule;
    final rows = <(String, String)>[
      ('ناوی ڕیکلام', d.title),
      ('کۆدی ڤیدیۆ', d.code),
      ('ئامانج', d.goal == 'messages' ? 'نامە و فرۆش' : 'کارلێک و بینین'),
      if (d.goal == 'messages')
        ('پەڕەی پەیوەندی', d.assetName ?? d.assetId ?? ''),
      ('بودجەی ڕۆژانە', '\$${d.dailyBudget}'),
      (
        'دەستپێک',
        d.immediate
            ? 'زووترین کاتی بەردەست'
            : s == null
                ? ''
                : '${two(s.day)}/${two(s.month)}/${s.year} ${two(s.hour)}:${two(s.minute)}'
      ),
      ('پارەدان', d.paymentMethod == 'fastpay' ? 'FastPay' : 'باڵانسی هەژمار'),
    ];
    return Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        AdValueRow(label: rows[i].$1, value: rows[i].$2),
      ],
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: ProxoText('ئامانجی بینەران', style: AdUi.text(context)),
          children: [
            AdValueRow(label: 'پۆل', value: adCategoryLabel(d.category)),
            const SizedBox(height: 12),
            AdValueRow(
                label: 'شوێن',
                value: {
                      'all': 'هەموو',
                      'kurdistan': 'کوردستان',
                      'iraq': 'عێراق'
                    }[d.location] ??
                    d.location),
            const SizedBox(height: 12),
            AdValueRow(
                label: 'تەمەن',
                value: d.ages.contains('all') ? 'هەموو' : d.ages.join(', ')),
            const SizedBox(height: 12),
            AdValueRow(
                label: 'ڕەگەز',
                value: {
                      'all': 'هەموو',
                      'male': 'نێر',
                      'female': 'مێ'
                    }[d.gender] ??
                    d.gender),
            const SizedBox(height: 12),
            AdValueRow(
                label: 'ئامێر',
                value: {
                      'all': 'هەموو',
                      'iphone': 'iPhone',
                      'android': 'Android'
                    }[d.device] ??
                    d.device),
          ]),
      if (d.note.isNotEmpty)
        ProxoText(d.note, style: AdUi.text(context, color: AdUi.secondary)),
    ]);
  }
}
