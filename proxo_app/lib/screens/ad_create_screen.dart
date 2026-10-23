import '../widgets/form_help_actions.dart';
import '../services/meta_ad_draft.dart';
import '../widgets/ad_objective_icon.dart';
import '../widgets/ad_brand_logo.dart';
import '../widgets/ad_help_notice.dart';
import '../widgets/ad_payment_card.dart';
import '../widgets/ad_schedule_picker.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/l10n/proxo_strings.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart' show supabase;
import '../services/ad_categories.dart';
import '../services/ad_forecast.dart';
import '../services/ad_submission.dart';
import '../services/tiktok_dm_accounts.dart';
import '../widgets/tiktok_dm_account_picker.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/proxo_symbol.dart';
import '../theme/proxo_surface.dart';
import '../widgets/ad_validation_notifications.dart';
import '../widgets/proxo_text.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'ad_confirmation_screen.dart';
import 'tools_screen.dart';

class AdCreateScreen extends StatefulWidget {
  final String platform;
  final Map<String, dynamic>? proxoCard;
  final VoidCallback? onAdCreated;
  final AdCreationRepository? repository;
  final TikTokDmRepository? tiktokRepository;
  final Future<Map<String, dynamic>?> Function(BuildContext)? createContactPage;
  const AdCreateScreen(
      {super.key,
      this.platform = 'TIKTOK',
      this.proxoCard,
      this.onAdCreated,
      this.repository,
      this.tiktokRepository,
      this.createContactPage});
  @override
  State<AdCreateScreen> createState() => _AdCreateScreenState();
}

class _AdCreateScreenState extends State<AdCreateScreen>
    with WidgetsBindingObserver {
  bool get _isMeta => widget.platform == 'META';
  bool _metaAllowed = false, _accessLoading = true;
  bool _metaFastPayAllowed = false;
  bool _tiktokDmAllowed = false,
      _tiktokFastPayAllowed = false,
      _tiktokDmSeen = true;
  String _messageDestination = 'external_contact';
  TikTokDmSelection? _tiktokSelection;
  bool get _isTikTokDirect =>
      !_isMeta &&
      _goal == 'messages' &&
      _messageDestination == 'direct_message';
  late final TikTokDmRepository _tiktokRepository =
      widget.tiktokRepository ?? SupabaseTikTokDmRepository(supabase);
  MetaAdSelection _selection = const MetaAdSelection();
  final _page = TextEditingController();
  int _ageMin = 18, _ageMax = 65;
  DateTime? _trustedAt;
  final Stopwatch _serverElapsed = Stopwatch();
  DateTime _now() =>
      adScheduleNow(instant: _trustedAt?.add(_serverElapsed.elapsed));
  List<int> get _budgetOptions =>
      _isMeta ? const [2, 3, 4, 5, 10, 20, 50, 100, 200, 500, 1000] : _budgets;
  int _accessRevision = 0;
  Timer? _clockTimer;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_resume());
  }

  Future<void> _resume() async {
    await _refreshAccess();
    if (mounted) _refreshQuote();
  }

  Future<void> _refreshAccess() async {
    final revision = ++_accessRevision;
    DateTime? time;
    var allowed = !_isMeta;
    var fastPayAllowed = !_isMeta;
    var dmAllowed = false, dmFastPay = false, dmSeen = true;
    try {
      time = await _repository.serverTime();
      allowed = !_isMeta || await _repository.metaAvailable();
      fastPayAllowed = !_isMeta || await _repository.metaFastPayAvailable();
      if (!_isMeta) {
        dmAllowed = await _repository.tiktokDmAvailable();
        if (dmAllowed) {
          dmFastPay = await _repository.tiktokDmFastPayAvailable();
          dmSeen = await _repository.tiktokDmSeen();
        }
      }
    } catch (_) {
      allowed = !_isMeta;
    }
    if (!mounted || revision != _accessRevision) return;
    ++_quoteRevision;
    setState(() {
      if (time != null) {
        _trustedAt = time;
        _serverElapsed
          ..reset()
          ..start();
      }
      _metaAllowed = allowed && (!_isMeta || _trustedAt != null);
      _metaFastPayAllowed = fastPayAllowed;
      _tiktokDmAllowed = dmAllowed && _trustedAt != null;
      _tiktokFastPayAllowed = dmFastPay;
      _tiktokDmSeen = dmSeen;
      if (!_tiktokDmAllowed) _tiktokSelection = null;

      _accessLoading = false;
      _validateSchedule();
    });
    _scheduleClockTick();
  }

  void _validateSchedule() {
    if (_immediate || _date == null || _time == null) return;
    final selected = DateTime.utc(
        _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    if (!selected.isAfter(_now())) {
      _fieldErrors['schedule'] = 'کاتی دەستپێک دەبێت لە داهاتوودا بێت';
    } else {
      _fieldErrors.remove('schedule');
    }
  }

  void _textChanged() {
    if (mounted) _refreshQuote();
  }

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
  String? _goal, _category, _assetId, _appliedCoupon;
  String _payment = 'app_balance';
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
  bool _markingDirectMessageSeen = false;
  Map<String, String> _fieldErrors = {};
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isMeta) _daily = 5;
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
    for (final c in [_name, _code, _link, _note, _page]) {
      c.addListener(_textChanged);
    }
    _scheduleClockTick();
    unawaited(_initialize());
  }

  void _scheduleClockTick() {
    _clockTimer?.cancel();
    final now = _now();
    _clockTimer = Timer(
        Duration(milliseconds: 60000 - now.second * 1000 - now.millisecond),
        () {
      if (!mounted) return;
      setState(_validateSchedule);
      _refreshQuote();
      _scheduleClockTick();
    });
  }

  Future<void> _initialize() async {
    final initialDraft = _draftFingerprint();
    await _refreshAccess();
    await _loadPending(restoreDraft: initialDraft == _draftFingerprint());
    await Future.wait([if (!_isMeta) _loadAssets(), _loadQuote()]);
  }

  String _draftFingerprint() {
    final draft = _draft().toJson();
    // The trusted clock can advance while recovery loads. It is not an edit.
    if (_immediate) {
      draft.remove('start_date');
      draft.remove('start_time');
    }
    return jsonEncode({...draft, 'coupon_input': _coupon.text});
  }

  Future<void> _loadPending({bool restoreDraft = false}) async {
    final beforeLoad = _draftFingerprint();
    if (mounted) setState(() => _pendingLoading = true);
    try {
      final pending =
          await _repository.pending().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _pendingLoadFailed = false;
        _pending = pending;
        if (pending != null &&
            restoreDraft &&
            beforeLoad == _draftFingerprint() &&
            pending.draft.isMeta == _isMeta) {
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
    _page.text = d.pageUrl;
    _selection =
        MetaAdSelection(placements: d.placements, destinations: d.destinations);
    _ageMin = d.ageMin;
    _ageMax = d.ageMax;
    _code.text = d.code;
    _link.text = d.link;
    _note.text = d.note;
    _goal = d.goal;
    _messageDestination = d.messageDestination;
    _tiktokSelection =
        d.isTikTokDirect && d.tiktokAccountId != null && d.tiktokItemId != null
            ? TikTokDmSelection(
                accountId: d.tiktokAccountId!,
                itemId: d.tiktokItemId!,
                username: d.tiktokUsername ?? '',
                caption: d.tiktokVideoCaption,
                permalink: '')
            : null;
    _category = isSupportedAdCategory(d.category) ? d.category : null;
    _assetId = d.assetId;
    _payment = d.paymentMethod == 'fastpay' ? 'fastpay' : 'app_balance';
    _location = d.location;
    _gender = d.gender;
    _device = d.device;
    _daily = _budgetOptions.contains(d.dailyBudget)
        ? d.dailyBudget
        : (_isMeta ? 5 : 10);
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
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _page.dispose();
    _quoteTimer?.cancel();
    _errors.dispose();
    for (final c in [_name, _code, _link, _note, _coupon]) {
      c.dispose();
    }
    super.dispose();
  }

  AdDraft _draft({String? coupon, bool replaceCoupon = false}) {
    final now = _now();
    final schedule = _immediate
        ? DateTime.utc(now.year, now.month, now.day, now.hour, now.minute + 2)
        : _date == null || _time == null
            ? null
            : DateTime.utc(_date!.year, _date!.month, _date!.day, _time!.hour,
                _time!.minute);
    return AdDraft(
        title: _name.text,
        platform: widget.platform,
        pageUrl: _page.text,
        placements: _selection.placements,
        destinations: _selection.destinations,
        ageMin: _ageMin,
        ageMax: _ageMax,
        link: _link.text,
        code: _code.text,
        note: _note.text,
        goal: _goal,
        messageDestination: _messageDestination,
        tiktokAccountId: _isTikTokDirect ? _tiktokSelection?.accountId : null,
        tiktokItemId: _isTikTokDirect ? _tiktokSelection?.itemId : null,
        tiktokUsername: _isTikTokDirect ? _tiktokSelection?.username : null,
        tiktokVideoCaption:
            _isTikTokDirect ? _tiktokSelection?.caption ?? '' : '',
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
    if ((_isMeta && !_metaAllowed) ||
        (_isTikTokDirect && (!_tiktokDmAllowed || _tiktokSelection == null))) {
      if (mounted) setState(() => _quoteBusy = false);
      return;
    }
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
        : await Navigator.of(context).push<Map<String, dynamic>>(ProxoPageRoute(
            settings: const RouteSettings(name: 'tools'),
            builder: (routeContext) => ToolsScreen(
                initialCreate: true,
                onUseForAd: (card) => Navigator.of(routeContext).pop(card))));
    if (!mounted) return;
    await _loadAssets();
    if (mounted &&
        card != null &&
        _assets.any((a) => '${a['id']}' == '${card['id']}')) {
      setState(() {
        _assetId = card['id']?.toString();
        _fieldErrors.remove('asset');
      });
      _refreshQuote();
    }
  }

  Future<void> _checkout() async {
    if (_openingConfirmation || _pendingLoading) return;
    setState(() => _openingConfirmation = true);
    try {
      await _prepareCheckout();
    } finally {
      if (mounted) setState(() => _openingConfirmation = false);
    }
  }

  Future<void> _prepareCheckout() async {
    if (_pendingLoadFailed) {
      await _loadPending();
      if (!mounted || _pendingLoadFailed) return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_pending != null) {
      await _openConfirmation(_pending!, resume: true);
      return;
    }
    await _refreshAccess();
    if (!mounted) return;
    final draft = _draft();
    final errors = draft.validate(now: _now());
    if (_isMeta && !_metaAllowed) {
      errors['platform'] = 'ئەم خزمەتگوزارییە بەردەست نییە';
    }
    if (_isMeta && draft.paymentMethod == 'fastpay' && !_metaFastPayAllowed) {
      errors['payment'] = 'FastPay ئێستا بەردەست نییە';
    }
    if (_isTikTokDirect && !_tiktokDmAllowed) {
      errors['tiktok_account'] = 'نامەی ڕاستەوخۆ ئێستا بەردەست نییە';
    }
    if (_isTikTokDirect &&
        draft.paymentMethod == 'fastpay' &&
        !_tiktokFastPayAllowed) {
      errors['payment'] = 'FastPay ئێستا بەردەست نییە';
    }

    if (!_isMeta &&
        !_isTikTokDirect &&
        draft.goal == 'messages' &&
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
      final revision = ++_quoteRevision;
      final quote = await _repository.quote(draft);
      if (!mounted || revision != _quoteRevision) return;
      setState(() {
        _quote = quote;
        _quoteBusy = false;
        _quoteError = null;
      });
      if (draft.paymentMethod == 'app_balance' &&
          quote.balanceUsd + 0.000001 < quote.costUsd) {
        setState(() => _quoteError =
            ProxoStrings.text('باڵانسی پێویستت بەردەست نییە') +
                '\n' +
                ProxoStrings.format(
                    'بەردەست: {available} USD — پێویست: {required} USD', {
                  'available': quote.balanceUsd.toStringAsFixed(2),
                  'required': quote.costUsd.toStringAsFixed(2)
                }));
        return;
      }
      if (draft.paymentMethod == 'fastpay' && quote.totalIqd < 1000) {
        setState(() => _quoteError = 'بڕی پارەدان بۆ FastPay زۆر کەمە');
        return;
      }
      await _openConfirmation(AdPendingSubmission.create(draft, quote));
    } catch (e) {
      if (mounted) {
        final message = e is AdSubmissionFailure
            ? e.message
            : 'پشکنینی نرخ سەرکەوتوو نەبوو';
        setState(() => _quoteError = message);
        _errors.show({'submission': message});
      }
    } finally {
      if (mounted) setState(() => _openingConfirmation = false);
    }
  }

  Future<void> _openConfirmation(AdPendingSubmission request,
      {bool resume = false}) async {
    if (!mounted) return;
    setState(() => _openingConfirmation = true);
    try {
      final result = await Navigator.of(context).push<AdConfirmationResult>(
          ProxoPageRoute(
              settings: const RouteSettings(name: 'ad_confirmation'),
              builder: (_) => AdConfirmationScreen(
                  request: request, repository: _repository, resume: resume)));
      if (!mounted) return;
      if (result?.adId != null) {
        // Clear completed state before notifying the parent. A form kept alive
        // by a shell/failed pop must never display a completed submission again.
        _resetCompletedForm();
        widget.onAdCreated?.call();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop('refresh');
        }
        return;
      }
      await _refreshAccess();
      if (!mounted) return;
      if (result?.useWallet == true) {
        setState(() {
          _payment = 'app_balance';
        });
      }
      await _loadQuote();
      await _loadPending();
      if (!mounted) return;
      // Navigation can finish before persistence / an in-flight request. Keep
      // its identity locally as well; never create a second financial operation.
      if (result?.pending == true && _pending == null) {
        setState(() => _pending = request);
      }
    } catch (error) {
      if (mounted) {
        _errors.show({
          'submission': error is AdSubmissionFailure
              ? error.message
              : 'داواکارییەکە تەواو نەکرا؛ دووبارە هەوڵ بدەرەوە'
        });
      }
    } finally {
      if (mounted) setState(() => _openingConfirmation = false);
    }
  }

  void _resetCompletedForm() {
    _quoteTimer?.cancel();
    ++_quoteRevision;
    _errors.clear();
    setState(() {
      for (final controller in [_name, _code, _link, _note, _coupon]) {
        controller.clear();
      }
      _goal = _category = _assetId = _appliedCoupon = null;
      _messageDestination = 'external_contact';
      _tiktokSelection = null;
      _payment = 'app_balance';
      _location = _gender = _device = 'all';
      _ages
        ..clear()
        ..add('all');
      _daily = _isMeta ? 5 : 10;
      _page.clear();
      _selection = const MetaAdSelection();
      _ageMin = 18;
      _ageMax = 65;
      _days = 1;
      _immediate = true;
      _date = null;
      _time = null;
      _fieldErrors = {};
      _pending = null;
      _pendingLoadFailed = false;
      _quoteError = _couponMessage = null;
      _couponValid = _couponBusy = _quoteBusy = false;
      _quote = null;
    });
    _quoteTimer?.cancel();
    ++_quoteRevision;
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: AdUi.theme(context),
      child: Builder(
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                  top: false,
                  bottom: false,
                  child: Column(children: [
                    ReceiptAppBar(
                        translateTitle: true,
                        title: 'دروستکردنی ڕیکلام',
                        onBack: () => Navigator.of(context).maybePop()),
                    Expanded(
                        child: Stack(children: [
                      if (_isMeta && (_accessLoading || !_metaAllowed))
                        Center(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: _accessLoading || _pendingLoading
                                    ? const CircularProgressIndicator()
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            const ProxoText(
                                                'ئەم خزمەتگوزارییە بەردەست نییە'),
                                            if (_pending != null)
                                              FilledButton(
                                                  key: const ValueKey(
                                                      'resume-pending-ad'),
                                                  onPressed:
                                                      _openingConfirmation
                                                          ? null
                                                          : _checkout,
                                                  child: const ProxoText(
                                                      'پشکنینی هەمان داواکاری')),
                                            if (_pendingLoadFailed)
                                              TextButton(
                                                  onPressed: _loadPending,
                                                  child: const ProxoText(
                                                      'دووبارە پشکنینەوە')),
                                          ])))
                      else
                        SingleChildScrollView(
                          key: const ValueKey('ad-form-scroll'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                              ProxoSurface.gutter,
                              16,
                              ProxoSurface.gutter,
                              28 + MediaQuery.paddingOf(context).bottom),
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 600),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_pendingLoadFailed) ...[
                                          AdFormSection(
                                              title: 'پشکنینی داواکاریی پێشوو',
                                              child: Column(children: [
                                                ProxoText(
                                                    'داواکارییە پێشووەکە بار نەبوو؛ پێش داواکارییەکی نوێ دووبارە هەوڵ بدەرەوە.',
                                                    translate: true,
                                                    style: AdUi.text(context)),
                                                TextButton(
                                                    onPressed: _pendingLoading
                                                        ? null
                                                        : _loadPending,
                                                    child: const ProxoText(
                                                        'دووبارە پشکنینەوە',
                                                        translate: true)),
                                              ])),
                                          const SizedBox(height: 18),
                                        ],
                                        if (_pending != null) ...[
                                          AdFormSection(
                                              title: 'داواکارییەکی پێشوو',
                                              child: Column(children: [
                                                ProxoText(
                                                    'دەتوانیت زانیارییەکان دەستکاری بکەیت. پێش ناردنێکی نوێ، ئەنجامی داواکاریی پێشوو بپشکنە.',
                                                    translate: true,
                                                    style: AdUi.text(context)),
                                                const SizedBox(height: 12),
                                                FilledButton(
                                                    key: const ValueKey(
                                                        'resume-pending-ad'),
                                                    onPressed:
                                                        _openingConfirmation
                                                            ? null
                                                            : _checkout,
                                                    child: const ProxoText(
                                                        'پشکنینی هەمان داواکاری',
                                                        translate: true)),
                                              ])),
                                          const SizedBox(height: 18),
                                        ],
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              AdHelpNotice(
                                                  platform: widget.platform),
                                              _objective(context),
                                              const SizedBox(
                                                  height: AdUi.sectionGap),
                                              _information(context),
                                              const SizedBox(
                                                  height: AdUi.sectionGap),
                                              if (_isTikTokDirect) ...[
                                                if (_tiktokDmAllowed)
                                                  TikTokDmAccountPicker(
                                                      repository:
                                                          _tiktokRepository,
                                                      selectedAccountId:
                                                          _tiktokSelection
                                                              ?.accountId,
                                                      selectedItemId:
                                                          _tiktokSelection
                                                              ?.itemId,
                                                      onChanged: (selection) {
                                                        setState(() {
                                                          _tiktokSelection =
                                                              selection;
                                                          _fieldErrors.remove(
                                                              'tiktok_account');
                                                          _fieldErrors.remove(
                                                              'tiktok_video');
                                                        });
                                                        _refreshQuote();
                                                      })
                                                else
                                                  const ProxoText(
                                                      'نامەی ڕاستەوخۆ ئێستا بەردەست نییە'),
                                                _error(
                                                    context, 'tiktok_account'),
                                                _error(context, 'tiktok_video'),
                                                const SizedBox(
                                                    height: AdUi.sectionGap),
                                              ],
                                              if (!_isMeta &&
                                                  _goal == 'messages' &&
                                                  !_isTikTokDirect) ...[
                                                _contactAsset(context),
                                                const SizedBox(
                                                    height: AdUi.sectionGap),
                                              ],
                                              _audience(context),
                                              const SizedBox(
                                                  height: AdUi.sectionGap),
                                              _budget(context),
                                              const SizedBox(
                                                  height: AdUi.sectionGap),
                                              _schedule(context),
                                              const SizedBox(
                                                  height: AdUi.sectionGap),
                                              if (!_isMeta) ...[
                                                _couponSection(context),
                                                const SizedBox(
                                                    height: AdUi.sectionGap),
                                              ],
                                              _forecast(context),
                                              const SizedBox(
                                                  height: AdUi.sectionGap),
                                              _pricing(context),
                                              const SizedBox(
                                                  height: AdUi.sectionGap),
                                              _submission(context),
                                            ]),
                                      ]))),
                        ),
                      Positioned(
                          top: 8,
                          left: ProxoSurface.gutter,
                          right: ProxoSurface.gutter,
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: AdValidationNotifications(
                                      controller: _errors)))),
                    ])),
                  ])),
            )),
      ));
  Widget _label(BuildContext context, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProxoText(label,
          translate: true,
          style: AdUi.text(context),
          textAlign: TextAlign.right));
  Widget _error(BuildContext context, String key) => _fieldErrors[key] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ProxoText(_fieldErrors[key]!,
              translate: true,
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
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                textDirection: direction,
                textAlign: TextAlign.start,
                keyboardType: keyboard,
                maxLines: maxLines,
                style: AdUi.text(context),
                autocorrect: !ltr,
                textInputAction: maxLines == 1
                    ? TextInputAction.next
                    : TextInputAction.newline,
                onChanged: (_) {
                  if (_fieldErrors.containsKey(id)) {
                    setState(() => _fieldErrors.remove(id));
                  }
                },
                decoration: const InputDecoration())),
        _error(context, id),
      ]);
  Widget _information(BuildContext context) => AdFormSection(
      title: 'زانیاری ڕیکلام',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _field(context, 'title', _name, 'ناوی ڕیکلام',
            keyboard: TextInputType.name),
        if (!_isTikTokDirect) const SizedBox(height: 20),
        if (!_isMeta && !_isTikTokDirect) ...[
          _field(context, 'code', _code, 'کۆدی ڤیدیۆ', ltr: true),
          const FormHelpActions(helpKey: 'ad_video_code'),
          const SizedBox(height: 20),
        ],
        // Existing video processing and thumbnails require the URL as well as the authorization code.
        if (!_isTikTokDirect)
          _field(context, 'link', _link,
              _isMeta ? 'لینکی پۆست / ڤیدیۆ' : 'بەستەری ڤیدیۆ',
              ltr: true, keyboard: TextInputType.url),
        if (!_isMeta && !_isTikTokDirect)
          const FormHelpActions(
              helpKey: 'ad_video_link',
              exampleAsset: 'assets/images/ad_video_link_example.png',
              exampleCaption:
                  'سکرینشۆتی خانەی بەستەر لە ئەپی Proxo؛ بەستەری ڤیدیۆی خۆت دابنێ',
              sampleValue:
                  'https://www.tiktok.com/@scout2015/video/6718335390845095173'),
        if (_isMeta) ...[
          const SizedBox(height: 20),
          _field(context, 'page', _page, 'لینکی پەیجی فەیسبووک',
              ltr: true, keyboard: TextInputType.url),
        ],
        if (!_isMeta) ...[
          const SizedBox(height: 8),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: ProxoText('تێبینی (ئارەزوومەندانە)',
                  translate: true,
                  style: AdUi.text(context, color: AdUi.secondary)),
              children: [
                _field(context, 'note', _note, 'تێبینی', maxLines: 3)
              ]),
        ],
      ]));
  Widget _choices(BuildContext context, String field, String value,
          List<(String, String)> options, ValueChanged<String> onChanged) =>
      LayoutBuilder(builder: (context, constraints) {
        double? choiceWidth;
        if (field == 'goal' || field == 'contact-destination') {
          var widest = 0.0;
          for (final option in options) {
            final painter = TextPainter(
                text: TextSpan(
                    text: ProxoStrings.text(option.$2),
                    style: AdUi.text(context)),
                textDirection: TextDirection.rtl,
                textScaler: MediaQuery.textScalerOf(context))
              ..layout();
            widest = math.max(widest, painter.width);
            painter.dispose();
          }
          choiceWidth = math.min(
              constraints.maxWidth, widest + (field == 'goal' ? 62 : 34));
        }
        return Wrap(
            spacing: 10,
            runSpacing: 10,
            textDirection: TextDirection.rtl,
            children: [
              for (final option in options)
                SizedBox(
                    width: choiceWidth,
                    child: Stack(
                        fit: StackFit.passthrough,
                        clipBehavior: Clip.none,
                        children: [
                          AdChoice(
                              key: ValueKey('$field-${option.$1}'),
                              label: option.$2,
                              icon: field == 'goal'
                                  ? AdObjectiveIcon(option.$1)
                                  : null,
                              selected: value == option.$1,
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                onChanged(option.$1);
                                if (field != 'goal') _refreshQuote();
                                setState(() => _fieldErrors.remove(field));
                              }),
                          if (field == 'contact-destination' &&
                              option.$1 == 'direct_message' &&
                              !_tiktokDmSeen)
                            Positioned(
                                top: -7,
                                left: 8,
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: AdUi.blue,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: ProxoText('نوێ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(color: Colors.white)))),
                        ]))
            ]);
      });
  void _markDirectMessageSeen() {
    if (_tiktokDmSeen || _markingDirectMessageSeen) return;
    _markingDirectMessageSeen = true;
    unawaited(_repository
        .markTikTokDmSeen()
        .then((_) {
          if (mounted) setState(() => _tiktokDmSeen = true);
        })
        .catchError((_) {})
        .whenComplete(() {
          _markingDirectMessageSeen = false;
        }));
  }

  Widget _objective(BuildContext context) => AdFormSection(
      title: 'ئامانجی ڕیکلام',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _choices(
            context,
            'goal',
            _goal ?? '',
            _isMeta
                ? metaObjectiveLabels.entries
                    .map((e) => (e.key, e.value))
                    .toList()
                : const [('views', 'بینین'), ('messages', 'نامە')], (v) {
          setState(() {
            if (_goal != v) _tiktokSelection = null;
            _goal = v;
          });
          if (_isTikTokDirect) _markDirectMessageSeen();
          _refreshQuote();
        }),
        if (!_isMeta && _goal == 'messages') ...[
          const SizedBox(height: 20),
          _label(context, 'شوێنی پەیوەندی'),
          _choices(context, 'contact-destination', _messageDestination, const [
            ('direct_message', 'نامەی ڕاستەوخۆ'),
            ('external_contact', 'پەیوەندی دەرەکی')
          ], (value) {
            setState(() {
              _messageDestination = value;
              _tiktokSelection = null;
              _fieldErrors.remove('asset');
              _fieldErrors.remove('tiktok_account');
              _fieldErrors.remove('tiktok_video');
              _quote = null;
            });
            if (value == 'direct_message') _markDirectMessageSeen();
            _refreshQuote();
          }),
          _error(context, 'destination'),
        ],
        _error(context, 'goal'),
        if (_isMeta) ...[
          const SizedBox(height: 20),
          _label(context, 'شوێنی پیشاندان'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in const [
              ('facebook', 'فەیسبووک'),
              ('instagram', 'ئینستاگرام')
            ])
              AdChoice(
                  key: ValueKey('placement-${p.$1}'),
                  label: p.$2,
                  icon: AdBrandLogo(p.$1),
                  selected: _selection.placements.contains(p.$1),
                  onTap: () {
                    final next = _selection.togglePlacement(p.$1);
                    if (identical(next, _selection)) {
                      setState(() => _fieldErrors['placements'] =
                          'لانیکەم یەک شوێنی پیشاندان هەڵبژێرە');
                      return;
                    }
                    setState(() {
                      _selection = next;
                      _fieldErrors.remove('placements');
                      if (_goal == 'messages' && next.destinations.isEmpty) {
                        _fieldErrors['destinations'] =
                            'لانیکەم یەک ڕێگای نامەی بەردەست هەڵبژێرە';
                      }
                    });
                    _refreshQuote();
                  }),
          ]),
          _error(context, 'placements'),
          AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: _goal != 'messages'
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label(context, 'ڕێگاکانی نامە'),
                            Wrap(spacing: 10, runSpacing: 10, children: [
                              for (final d in const [
                                ('WHATSAPP', 'واتسئاپ', 'whatsapp'),
                                ('MESSENGER', 'مەسنجەر', 'messenger'),
                                (
                                  'INSTAGRAM_DIRECT',
                                  'نامەی ئینستاگرام',
                                  'instagram'
                                )
                              ])
                                AdChoice(
                                    key: ValueKey('destination-${d.$1}'),
                                    label: d.$2,
                                    icon: AdBrandLogo(d.$3),
                                    selected:
                                        _selection.destinations.contains(d.$1),
                                    onTap: !_selection.available(d.$1) &&
                                            !_selection.destinations
                                                .contains(d.$1)
                                        ? null
                                        : () {
                                            final next = _selection
                                                .toggleDestination(d.$1);
                                            setState(() {
                                              if (identical(next, _selection)) {
                                                _fieldErrors['destinations'] =
                                                    'لانیکەم یەک ڕێگای نامەی بەردەست هەڵبژێرە';
                                              } else {
                                                _selection = next;
                                                _fieldErrors
                                                    .remove('destinations');
                                              }
                                            });
                                            _refreshQuote();
                                          }),
                            ]),
                            _error(context, 'destinations'),
                            if (!_selection.placements.contains('facebook'))
                              ProxoText('بۆ مەسنجەر، فەیسبووک چالاک بکە',
                                  style: AdUi.text(context,
                                      color: AdUi.secondary)),
                            if (!_selection.placements.contains('instagram'))
                              ProxoText(
                                  'بۆ نامەی ئینستاگرام، ئینستاگرام چالاک بکە',
                                  style: AdUi.text(context,
                                      color: AdUi.secondary)),
                          ]))),
        ],
      ]));
  Widget _contactAsset(BuildContext context) => AdFormSection(
      title: 'پەڕەی پەیوەندی',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_assetsLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_assetsFailed)
          TextButton(
              onPressed: _loadAssets,
              child: const ProxoText('دووبارە بارکردنەوەی پەڕەکان',
                  translate: true))
        else if (_assets.isEmpty)
          ProxoText('پەڕەی پەیوەندیت نییە؛ پەڕەیەکی نوێ دروست بکە.',
              translate: true, style: AdUi.text(context, color: AdUi.secondary))
        else
          DropdownButtonFormField<String>(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              key: ValueKey('asset-$_assetId-${_assets.length}'),
              initialValue: _assetId,
              isExpanded: true,
              isDense: false,
              itemHeight: null,
              style: AdUi.text(context),
              decoration: AdUi.dropdownDecoration,
              hint: const ProxoText('پەڕەی پەیوەندی هەڵبژێرە', translate: true),
              items: [
                for (final a in _assets)
                  DropdownMenuItem(
                      value: '${a['id']}',
                      child: ProxoText('${a['name'] ?? ''}'))
              ],
              onChanged: (v) {
                setState(() {
                  _assetId = v;
                  _fieldErrors.remove('asset');
                });
                _refreshQuote();
              }),
        _error(context, 'asset'),
        const SizedBox(height: 14),
        Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
                onPressed: _createContact,
                child:
                    const ProxoText('دروستکردنی پەڕەی نوێ', translate: true))),
      ]));
  Widget _audience(BuildContext context) => AdFormSection(
      title: 'ئامانجی بینەران',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(context, 'شوێن'),
        _choices(
            context,
            'location',
            _location,
            _isMeta
                ? const [
                    ('all', 'هەموو عێراق'),
                    ('erbil', 'هەولێر'),
                    ('sulaymaniyah', 'سلێمانی'),
                    ('duhok', 'دهۆک'),
                    ('baghdad', 'بەغدا')
                  ]
                : const [
                    ('all', 'هەموو'),
                    ('kurdistan', 'کوردستان'),
                    ('iraq', 'عێراق')
                  ],
            (v) => setState(() => _location = v)),
        const SizedBox(height: 24),
        _label(context, 'تەمەن'),
        if (_isMeta) ...[
          AdValueRow(
              label: 'تەمەن',
              value: '$_ageMin – ${_ageMax == 65 ? '65+' : _ageMax}'),
          RangeSlider(
              key: const ValueKey('meta-age'),
              min: 18,
              max: 65,
              divisions: 47,
              values: RangeValues(_ageMin.toDouble(), _ageMax.toDouble()),
              onChanged: (v) {
                setState(() {
                  _ageMin = v.start.round();
                  _ageMax = v.end.round();
                });
                _refreshQuote();
              }),
        ] else
          Wrap(spacing: 10, runSpacing: 10, children: [
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
                  onTap: () {
                    setState(() {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (age == 'all') {
                        _ages
                          ..clear()
                          ..add('all');
                      } else {
                        _ages.remove('all');
                        if (!_ages.add(age)) _ages.remove(age);
                        if (_ages.isEmpty) _ages.add('all');
                      }
                    });
                    _refreshQuote();
                  })
          ]),
        const SizedBox(height: 24),
        _label(context, 'ڕەگەز'),
        _choices(
            context,
            'gender',
            _gender,
            const [('all', 'هەموو'), ('male', 'نێر'), ('female', 'مێ')],
            (v) => setState(() => _gender = v)),
        if (!_isMeta) ...[
          const SizedBox(height: 24),
          _label(context, 'جۆری پۆل'),
          DropdownButtonFormField<String>(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              key: ValueKey('category-$_category'),
              initialValue: _category,
              isExpanded: true,
              isDense: false,
              itemHeight: null,
              style: AdUi.text(context),
              decoration: AdUi.dropdownDecoration,
              hint: const ProxoText('پۆلی ڕیکلام هەڵبژێرە', translate: true),
              items: [
                for (final c in kAdCategories)
                  DropdownMenuItem(
                      value: c.slug, child: ProxoText(c.label, translate: true))
              ],
              onChanged: (v) {
                setState(() {
                  _category = v;
                  _fieldErrors.remove('category');
                });
                _refreshQuote();
              }),
          _error(context, 'category'),
          const SizedBox(height: 24),
          _label(context, 'جۆری ئامێر'),
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
        ],
        _error(context, 'audience'),
      ]));
  String _budgetIqd(int usd) => adIqd(usd * (_quote?.rate ?? 1800));

  Widget _budget(BuildContext context) => AdFormSection(
      title: 'بودجە و ماوەی ڕیکلام',
      child: Column(children: [
        AdValueRow(
            label: 'بودجەی ڕۆژانە',
            value: _budgetIqd(_daily),
            valueColor: AdUi.blue),
        const SizedBox(height: 6),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(
                key: const ValueKey('daily-budget-slider'),
                min: 0,
                max: (_budgetOptions.length - 1).toDouble(),
                divisions: _budgetOptions.length - 1,
                value: _budgetOptions.indexOf(_daily).toDouble(),
                activeColor: AdUi.blue,
                label: _budgetIqd(_daily),
                onChanged: (v) {
                  setState(() => _daily = _budgetOptions[v.round()]);
                  _refreshQuote();
                })),
        AdValueRow(
            label: _budgetIqd(_budgetOptions.last),
            value: _budgetIqd(_budgetOptions.first),
            color: AdUi.secondary),
        const SizedBox(height: 24),
        AdValueRow(
            label: 'ماوەی ڕیکلام',
            value: ProxoStrings.format('{count} ڕۆژ', {'count': _days}),
            valueColor: AdUi.blue),
        const SizedBox(height: 6),
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
        const AdValueRow(label: '7 ڕۆژ', value: '1 ڕۆژ', color: AdUi.secondary),
        const Divider(height: 32, color: AdUi.controlLine),
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
            const [('now', 'ئێستا'), ('later', 'دیاریکردنی کات')],
            (v) => setState(() => _immediate = v == 'now')),
        AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topRight,
            child: _immediate
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Wrap(spacing: 10, runSpacing: 10, children: [
                      OutlinedButton(
                          key: const ValueKey('ad-date'),
                          onPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final date = await showAdDatePicker(
                                context: context,
                                now: _now,
                                initialDate: _date);
                            if (mounted && date != null) {
                              setState(() {
                                _date = date;
                                _fieldErrors.remove('schedule');
                                _validateSchedule();
                              });
                              _refreshQuote();
                            }
                          },
                          child: ProxoText(
                              translate: true,
                              _date == null
                                  ? 'بەروار هەڵبژێرە'
                                  : '${_date!.day}/${_date!.month}/${_date!.year}')),
                      OutlinedButton(
                          key: const ValueKey('ad-time'),
                          onPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final now = _now();
                            final time = await showAdTimePicker(
                                context: context,
                                date: _date ?? now,
                                now: _now,
                                initialTime: _time);
                            if (mounted && time != null) {
                              setState(() {
                                _date ??= DateUtils.dateOnly(now);
                                _time = time;
                                _validateSchedule();
                              });
                              _refreshQuote();
                            }
                          },
                          child: ProxoText(
                              translate: true,
                              _time == null
                                  ? 'کات هەڵبژێرە'
                                  : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}')),
                    ]))),
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
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
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
                    hint: ProxoText('کۆدی داشکاندن (ئارەزوومەندانە)',
                        translate: true)))),
        const SizedBox(height: 14),
        Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
                onPressed: _couponBusy ? null : _applyCoupon,
                child: ProxoText(_couponBusy ? 'پشکنین…' : 'بەکارهێنانی کۆد',
                    translate: true))),
        if (_couponMessage != null) ...[
          const SizedBox(height: 8),
          ProxoText(_couponMessage!,
              translate: true,
              style: AdUi.text(context,
                  color: _couponValid ? AdUi.green : const Color(0xFFB74956)))
        ],
      ]));
  Widget _forecast(BuildContext context) {
    if (_isMeta || _isTikTokDirect) {
      return AdFormSection(
          title: 'پێشبینی ئەنجام',
          child: ProxoText('پێشبینی بەردەست نییە',
              style: AdUi.text(context, color: AdUi.secondary)));
    }
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
                translate: true,
                style: AdUi.text(context, color: AdUi.secondary))
          else ...[
            Container(
                key: const ValueKey('forecast-results'),
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                    color: AdUi.controlSurface,
                    borderRadius: AdUi.controlRadius),
                child: Column(children: [
                  AdValueRow(
                      label: 'پێشبینی بینینەکان',
                      value: range(f.viewsLow, f.viewsHigh)),
                  if (_goal == 'messages') ...[
                    const Divider(height: 28, color: AdUi.controlLine),
                    AdValueRow(
                        label: 'پێشبینی کرتەکان',
                        value: range(f.clicksLow!, f.clicksHigh!)),
                  ],
                ])),
            if (_goal == 'messages') ...[
              const SizedBox(height: 12),
              ProxoText('کرتەی پەڕەی پەیوەندی؛ بە گریمانەی کاتی.',
                  translate: true,
                  style: AdUi.text(context, color: AdUi.secondary))
            ],
            if (f.provisionalViews) ...[
              const SizedBox(height: 10),
              ProxoText('پێشبینی بینین بە گریمانەی کاتی.',
                  translate: true,
                  style: AdUi.text(context, color: AdUi.secondary))
            ],
          ],
          const SizedBox(height: 18),
          ProxoText(adForecastDisclaimer,
              translate: true,
              style: AdUi.text(context, color: AdUi.secondary)),
        ]));
  }

  Widget _pricing(BuildContext context) => AdFormSection(
      title: 'پوختەی نرخ',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_quote != null) ...[
          AdPriceDetails(quote: _quote!),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                  color: AdUi.controlSurface, borderRadius: AdUi.controlRadius),
              child: AdValueRow(
                  label: 'باڵانسی بەردەست',
                  value: adIqd(_quote!.balanceUsd * _quote!.rate),
                  color: AdUi.secondary,
                  valueColor: AdUi.ink)),
          if (_payment == 'app_balance' &&
              _quote!.balanceUsd + 0.000001 < _quote!.costUsd) ...[
            const SizedBox(height: 10),
            ProxoText('باڵانسی پێویستت بەردەست نییە',
                translate: true,
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
              translate: true,
              style: AdUi.text(context, color: const Color(0xFFB74956))),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _loadQuote,
                  child: const ProxoText('دووبارە پشکنین', translate: true)))
        ],
      ]));
  Widget _submission(BuildContext context) => AdFormSection(
      title: 'ناردنی ڕیکلام',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(context, 'شێوازەکانی پارەدان'),
        AdPaymentCard(
          value: _payment,
          busy: _openingConfirmation,
          fastPayEnabled: _isMeta
              ? _metaFastPayAllowed
              : _isTikTokDirect
                  ? _tiktokFastPayAllowed
                  : true,
          onChanged: (value) {
            setState(() {
              _payment = value;
              _fieldErrors.remove('payment');
            });
            _refreshQuote();
          },
        ),
        _error(context, 'payment'),
        const SizedBox(height: 16),
        FilledButton(
            key: const ValueKey('review-ad'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(ProxoSurface.controlRadius)),
            ),
            onPressed: _openingConfirmation || _couponBusy || _pendingLoading
                ? null
                : _checkout,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: _openingConfirmation
                      ? const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)
                      : const ProxoSymbol(ProxoSymbolName.check,
                          size: 20, color: Colors.white)),
              const SizedBox(width: 8),
              Flexible(
                  child: ProxoText(
                      _pending != null
                          ? 'پشکنینی داواکاریی پێشوو'
                          : 'سپۆنسەر بکە${_quote == null ? '' : ' — ${adIqd(_quote!.totalIqd)}'}',
                      textAlign: TextAlign.center)),
            ])),
      ]));
}
