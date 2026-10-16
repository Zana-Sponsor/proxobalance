import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/account_setup_service.dart';
import '../services/app_telemetry_service.dart';
import 'auth_screen.dart';
import '../theme/app_locale.dart';
import '../theme/app_theme.dart';

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
    _service = widget.service ?? AccountSetupService.forClient(Supabase.instance.client);
    _scope = _service.scope;
    _ready = _service.isReady;
    _auth = _service.client.auth.onAuthStateChange.listen((_) {
      final next = _service.scope;
      if (!mounted || next == _scope) return;
      ++_generation;
      _service.clear();
      setState(() { _scope = next; _ready = false; _busy = false; _failed = false; });
      if (next != null) _retry();
    });
    if (!_ready && _scope != null) _retry();
  }
  @override
  void dispose() { ++_generation; unawaited(_auth?.cancel()); super.dispose(); }
  Future<void> _retry() async {
    if (_busy) return;
    final generation = _generation;
    bool current() => mounted && generation == _generation;
    setState(() { _busy = true; _failed = false; });
    try {
      await _service.ensure(onPhase: (phase) {
        if (current()) setState(() => _phase = phase);
      });
      if (current()) setState(() => _ready = _service.isReady);
    } catch (error) {
      if (current()) {
        AppTelemetryService.active?.event('error', 'account_setup_failed', outcome: 'failure');
        setState(() => _failed = true);
      }
    } finally { if (current()) setState(() => _busy = false); }
  }
  String _text(String en, String ku, String ar, String kmr) => switch(ProxoLocale.current.value.languageCode) {
    'en' => en, 'ar' => ar, 'kmr' => kmr, _ => ku,
  };
  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    if (_scope == null) return const AuthScreen();
    if (_ready && _service.isReady) return KeyedSubtree(key: ValueKey(_scope), child: widget.child);
    final message = _failed
      ? _text('Account setup could not finish. Please retry.', 'ئامادەکردنی هەژمار تەواو نەبوو. تکایە دووبارە هەوڵ بدەرەوە.', 'تعذر إكمال إعداد الحساب. حاول مرة أخرى.', 'ئامادەکرنا هەژمارێ تەمام نەبوو. جارەکا دی هەوڵ بدە.')
      : switch (_phase) {
        AccountSetupPhase.verifying => _text('Creating your account', 'هەژمارەکەت ئامادە دەکرێت', 'جارٍ إنشاء حسابك', 'هەژمارێ تە دهێتە ئامادەکرن'),
        AccountSetupPhase.profile => _text('Preparing your profile', 'پڕۆفایلەکەت ئامادە دەکرێت', 'جارٍ إعداد ملفك الشخصي', 'پرۆفایلێ تە دهێتە ئامادەکرن'),
        _ => _text('Finishing setup', 'ئامادەکردن تەواو دەکرێت', 'جارٍ إنهاء الإعداد', 'ئامادەکرن د تەمام دبیت'),
      };
    return PopScope(canPop: false, child: Scaffold(backgroundColor: AppColors.bg,
      body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/proxo_logo.png', width: 150),
          const SizedBox(height: 28),
          if (!_failed) const CircularProgressIndicator(),
          const SizedBox(height: 20), Text(message, textAlign: TextAlign.center),
          if (_failed) ...[const SizedBox(height: 20), FilledButton(onPressed: _busy ? null : _retry,
            child: Text(_text('Retry','دووبارە هەوڵبدەرەوە','إعادة المحاولة','جارەکا دی هەوڵ بدە')))],
        ]))))));
  }
}
