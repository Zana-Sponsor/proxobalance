import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/account_setup_service.dart';
import '../services/app_telemetry_service.dart';
import 'auth_screen.dart';
import '../theme/app_locale.dart';
import '../widgets/auth/auth_design.dart';
import '../widgets/auth/auth_icon.dart';
import '../widgets/auth/auth_logo.dart';
import '../widgets/auth/auth_widgets.dart';

class AccountSetupGate extends StatefulWidget {
  const AccountSetupGate({super.key, required this.child, this.service});
  final Widget child;
  final AccountSetupService? service;
  @override
  State<AccountSetupGate> createState() => _AccountSetupGateState();
}

class _AccountSetupGateState extends State<AccountSetupGate> {
  late final AccountSetupService _service;
  AccountSetupPhase _phase = AccountSetupPhase.verifying;
  bool _busy = false;
  bool _failed = false;
  bool _ready = false;
  int _generation = 0;
  String? _scope;
  StreamSubscription<AuthState>? _auth;
  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        AccountSetupService.forClient(Supabase.instance.client);
    _scope = _service.scope;
    _ready = _service.isReady;
    _auth = _service.client.auth.onAuthStateChange.listen((_) {
      final next = _service.scope;
      if (!mounted || next == _scope) return;
      ++_generation;
      _service.clear();
      setState(() {
        _scope = next;
        _ready = false;
        _busy = false;
        _failed = false;
      });
      if (next != null) _retry();
    });
    if (!_ready && _scope != null) _retry();
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_auth?.cancel());
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    final generation = _generation;
    bool current() => mounted && generation == _generation;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _service.ensure(
        onPhase: (phase) {
          if (current()) setState(() => _phase = phase);
        },
      );
      if (current()) setState(() => _ready = _service.isReady);
    } catch (error) {
      if (current()) {
        AppTelemetryService.active?.event(
          'error',
          'account_setup_failed',
          outcome: 'failure',
        );
        setState(() => _failed = true);
      }
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    if (_scope == null) return const AuthScreen();
    final section = _ready && _service.isReady
        ? AppSectionObserver.forWidget(widget.child)
        : 'account_setup';
    AppSectionObserver.instance.register(ModalRoute.of(context), section);
    if (_ready && _service.isReady)
      return KeyedSubtree(key: ValueKey(_scope), child: widget.child);
    return AccountSetupView(
      phase: _phase,
      failed: _failed,
      busy: _busy,
      onRetry: _retry,
    );
  }
}

/// Presentation is separate from provisioning: progress reflects actual phases,
/// never a timer or a simulated percentage. Small/large-text screens can scroll.
class AccountSetupView extends StatelessWidget {
  const AccountSetupView({
    super.key,
    required this.phase,
    this.failed = false,
    this.busy = false,
    required this.onRetry,
  });
  final AccountSetupPhase phase;
  final bool failed, busy;
  final Future<void> Function() onRetry;

  String _text(String en, String ku, String ar, String kmr) =>
      switch (ProxoLocale.current.value.languageCode) {
        'en' => en,
        'ar' => ar,
        'kmr' => kmr,
        _ => ku,
      };

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final step = phase.index.clamp(0, 2);
    final labels = [
      _text('Your account', 'هەژمارەکەت', 'حسابك', 'هەژمارێ تە'),
      _text('Your profile', 'پڕۆفایلەکەت', 'ملفك الشخصي', 'پرۆفایلێ تە'),
      _text(
        'Ready to begin',
        'ئامادەی دەستپێکردن',
        'جاهز للبدء',
        'ئامادەی دەستپێکرنێ',
      ),
    ];
    final title = failed
        ? _text(
            'Let’s try again',
            'با دووبارە هەوڵ بدەینەوە',
            'لنحاول مرة أخرى',
            'بلا جارەکا دی هەوڵ بدەین',
          )
        : _text(
            'Getting things ready',
            'هەژمارەکەت ئامادە دەکەین',
            'نجهّز حسابك',
            'هەژمارێ تە ئامادە دکەین',
          );
    final detail = failed
        ? _text(
            'Setup could not finish. You can safely retry.',
            'ئامادەکردنی هەژمار تەواو نەبوو. تکایە دووبارە هەوڵ بدەرەوە.',
            'تعذر إكمال الإعداد. يمكنك إعادة المحاولة بأمان.',
            'ئامادەکرنا هەژمارێ تەمام نەبوو. جارەکا دی هەوڵ بدە.',
          )
        : _text(
            'Just a moment. We’ll open Proxo when everything is ready.',
            'کەمێک چاوەڕێ بکە؛ کە تەواو بوو خۆکارانە دەچیتە ناو پڕۆکسۆ.',
            'لحظة من فضلك؛ سنفتح Proxo تلقائياً عندما يكتمل الإعداد.',
            'کەمەک چاڤەرێ بکە؛ دێ پاشی ب خۆکارانە چیە ناڤ پڕۆکسۆ.',
          );
    return Directionality(
      textDirection: ProxoLocale.directionOf(ProxoLocale.current.value),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AuthTokens.pageBackground,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 400,
                      minHeight: (constraints.maxHeight - 48).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AuthLogo(),
                        ),
                        const SizedBox(height: 44),
                        Center(
                          child: SizedBox.square(
                            dimension: 100,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: failed
                                        ? AuthTokens.dangerBg
                                        : AuthTokens.accentSoft,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Center(
                                    child: AuthIcon(
                                      failed ? 'refresh' : 'person_add',
                                      size: 36,
                                      color: failed
                                          ? AuthTokens.danger
                                          : AuthTokens.accent,
                                    ),
                                  ),
                                ),
                                if (!failed)
                                  const SizedBox.square(
                                    dimension: 98,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AuthTokens.accent,
                                      backgroundColor: AuthTokens.accentSoft,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AuthTokens.title.copyWith(fontSize: 22),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          detail,
                          textAlign: TextAlign.center,
                          style: AuthTokens.subtitle,
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AuthTokens.fieldFill,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AuthTokens.lineOff),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(height: 18),
                                _SetupStep(
                                  label: labels[i],
                                  icon: const [
                                    'shield',
                                    'person',
                                    'check_circle',
                                  ][i],
                                  complete: i < step,
                                  current: i == step,
                                  failed: failed && i == step,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (failed) ...[
                          const SizedBox(height: 24),
                          AuthPrimaryButton(
                            label: _text(
                              'Try again',
                              'دووبارە هەوڵبدەرەوە',
                              'إعادة المحاولة',
                              'جارەکا دی هەوڵ بدە',
                            ),
                            onPressed: onRetry,
                            loading: busy,
                          ),
                        ],
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.label,
    required this.icon,
    required this.complete,
    required this.current,
    required this.failed,
  });
  final String label, icon;
  final bool complete, current, failed;
  @override
  Widget build(BuildContext context) {
    final color = failed
        ? AuthTokens.danger
        : complete
        ? AuthTokens.success
        : current
        ? AuthTokens.accent
        : AuthTokens.inkMuted;
    return Semantics(
      liveRegion: current,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: failed
                  ? AuthTokens.dangerBg
                  : complete
                  ? AuthTokens.successBg
                  : current
                  ? AuthTokens.accentSoft
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AuthIcon(
              failed
                  ? 'error'
                  : complete
                  ? 'check_circle'
                  : icon,
              size: 21,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: AuthTokens.fieldLabel.copyWith(color: color),
            ),
          ),
          if (current && !failed)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsetsDirectional.only(start: 10),
              decoration: const BoxDecoration(
                color: AuthTokens.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
