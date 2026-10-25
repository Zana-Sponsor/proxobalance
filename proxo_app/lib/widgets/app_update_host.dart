import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update_service.dart';
import '../theme/app_locale.dart';
import '../theme/proxo_design_tokens.dart';
import 'proxo_text.dart';
import 'proxo_png_icon.dart';
import 'proxo_symbol.dart';

/// Above the application's Navigator: auth redirects and nested navigation
/// cannot uncover the content while a verified required policy is active.
class AppUpdateHost extends StatefulWidget {
  const AppUpdateHost(
      {super.key,
      required this.child,
      required this.client,
      this.service,
      this.installedBuild,
      this.platform,
      this.launch});
  final Widget child;
  final SupabaseClient client;
  final AppUpdateService? service;
  final int? installedBuild;
  final String? platform;
  final Future<bool> Function(Uri)? launch;
  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost>
    with WidgetsBindingObserver {
  static const _channel =
      String.fromEnvironment('PROXO_RELEASE_CHANNEL', defaultValue: 'stable');
  AppUpdateService? _service;
  AppUpdatePolicy? _policy;
  int _build = 0;
  String? _platform;
  bool _checking = false, _opening = false, _launchFailed = false;
  DateTime? _lastCheck;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize().catchError((Object _) {
      // Missing platform metadata or preferences must not block app startup.
    });
  }

  Future<void> _initialize() async {
    _platform = widget.platform ??
        (kIsWeb
            ? null
            : switch (defaultTargetPlatform) {
                TargetPlatform.android => 'android',
                TargetPlatform.iOS => 'ios',
                _ => null
              });
    if (_platform == null) return;
    _build = widget.installedBuild ??
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ??
        0;
    if (!mounted || _build < 1) return;
    _service = widget.service ??
        AppUpdateService(
            preferences: await SharedPreferences.getInstance(),
            fetch: (platform, channel) => widget.client.rpc(
                'proxo_app_update_policy',
                params: {'p_platform': platform, 'p_channel': channel}));
    if (mounted) await _check();
  }

  Future<void> _check({bool force = false}) async {
    if (_checking || _service == null || _platform == null) return;
    if (!force &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 5))
      return;
    setState(() => _checking = true);
    final next = await _service!.load(_platform!, _channel);
    if (!mounted) return;
    setState(() {
      _lastCheck = DateTime.now();
      _checking = false;
      _policy = next != null &&
              _service!.shouldOffer(next, _platform!, _channel, _build)
          ? next
          : null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      _check(force: _policy?.isRequired(_build) == true);
  }

  Future<void> _later() async {
    final policy = _policy;
    if (policy == null || policy.isRequired(_build)) return;
    await _service!.defer(policy, _platform!, _channel, _build);
    if (mounted) setState(() => _policy = null);
  }

  Future<void> _update() async {
    if (_opening || _policy == null) return;
    setState(() {
      _opening = true;
      _launchFailed = false;
    });
    bool opened;
    try {
      opened = await (widget.launch?.call(_policy!.url) ??
          launchUrl(_policy!.url, mode: LaunchMode.externalApplication));
    } catch (_) {
      opened = false;
    }
    if (mounted)
      setState(() {
        _opening = false;
        _launchFailed = !opened;
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy;
    final required = policy?.isRequired(_build) == true;
    return Stack(fit: StackFit.expand, children: [
      Offstage(offstage: required, child: widget.child),
      if (policy != null) ...[
        const ModalBarrier(dismissible: false, color: Color(0x38000000)),
        Material(
          color: required ? Colors.white : Colors.transparent,
          child: SafeArea(
              child: Directionality(
            textDirection: ProxoLocale.directionOf(ProxoLocale.watch(context)),
            child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(ProxoDesign.gutter),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AppUpdateCard(
                        policy: policy,
                        required: required,
                        busy: _opening,
                        checking: _checking,
                        launchFailed: _launchFailed,
                        onUpdate: _update,
                        onLater: _later,
                        onRetry: () => _check(force: true)),
                  )),
            ),
          )),
        ),
      ],
    ]);
  }
}

class AppUpdateCard extends StatelessWidget {
  const AppUpdateCard(
      {super.key,
      required this.policy,
      required this.required,
      required this.onUpdate,
      required this.onLater,
      required this.onRetry,
      this.busy = false,
      this.checking = false,
      this.launchFailed = false});
  final AppUpdatePolicy policy;
  final bool required, busy, checking, launchFailed;
  final VoidCallback onUpdate, onLater, onRetry;
  @override
  Widget build(BuildContext context) => Container(
      key: ValueKey(required ? 'required-update' : 'optional-update'),
      padding: const EdgeInsets.all(ProxoDesign.cardPadding),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: ProxoDesign.border,
          boxShadow: ProxoDesign.shadow),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
                alignment: AlignmentDirectional.centerStart,
                child: ProxoPngIcon(ProxoSymbolName.download,
                    size: 28, color: ProxoDesign.blue)),
            const SizedBox(height: ProxoDesign.headingGap),
            ProxoText(
                required ? 'تکایە ئەپەکە نوێ بکەرەوە' : 'نوێکردنەوە بەردەستە',
                translate: true,
                style: ProxoDesign.heading),
            const SizedBox(height: ProxoDesign.headingGap),
            Text('Proxo ${policy.version}',
                textDirection: TextDirection.ltr, style: ProxoDesign.body),
            if (policy.message.isNotEmpty) ...[
              const SizedBox(height: ProxoDesign.helperGap),
              ProxoText(policy.message, style: ProxoDesign.body),
            ],
            if (launchFailed) ...[
              const SizedBox(height: ProxoDesign.helperGap),
              const ProxoText(
                  'بەستەرەکە نەکرایەوە. تکایە دووبارە هەوڵ بدەرەوە.',
                  translate: true,
                  style: ProxoDesign.helper),
            ],
            const SizedBox(height: ProxoDesign.sectionGap),
            FilledButton(
                key: const ValueKey('update-now'),
                onPressed: busy ? null : onUpdate,
                style: FilledButton.styleFrom(
                    backgroundColor: ProxoDesign.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, ProxoDesign.controlHeight),
                    padding: const EdgeInsets.all(12),
                    textStyle: ProxoDesign.button,
                    shape: const RoundedRectangleBorder(
                        borderRadius: ProxoDesign.border)),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const ProxoText('نوێکردنەوە', translate: true)),
            const SizedBox(height: ProxoDesign.controlGap),
            TextButton(
                key: ValueKey(required ? 'update-check-again' : 'update-later'),
                onPressed: checking ? null : (required ? onRetry : onLater),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, ProxoDesign.tapTarget),
                    foregroundColor: ProxoDesign.blue,
                    textStyle: ProxoDesign.button),
                child: ProxoText(required ? 'دووبارە پشکنین بکە' : 'دواتر',
                    translate: true)),
          ]));
}
