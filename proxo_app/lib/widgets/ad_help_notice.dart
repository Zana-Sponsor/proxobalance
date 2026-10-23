import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/context_help_service.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

class AdHelpNotice extends StatefulWidget {
  const AdHelpNotice({super.key, required this.platform});
  final String platform;
  @override
  State<AdHelpNotice> createState() => _AdHelpNoticeState();
}

class _AdHelpNoticeState extends State<AdHelpNotice>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _notice;
  DateTime? _lastLoad;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant AdHelpNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.platform != widget.platform) {
      _notice = null;
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_lastLoad == null ||
            DateTime.now().difference(_lastLoad!) >
                const Duration(minutes: 2))) {
      _load();
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    try {
      final value = await Supabase.instance.client.rpc('pa_ad_help', params: {
        'p_platform': widget.platform
      }).timeout(const Duration(seconds: 5));
      if (mounted && revision == _revision) {
        setState(() {
          _notice = value is Map ? Map<String, dynamic>.from(value) : null;
          _lastLoad = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _notice = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _notice;
    if (n == null ||
        n['active'] != true ||
        n['message'] is! String ||
        (n['message'] as String).trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final uri =
        ContextHelpService.validVideoUrl('${n['video_url'] ?? ''}'.trim());
    return Padding(
        padding: const EdgeInsets.only(bottom: AdUi.sectionGap),
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
                color: AdUi.controlSurface, borderRadius: AdUi.controlRadius),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProxoText(n['message'] as String,
                      style: AdUi.text(context, color: AdUi.secondary)),
                  if (uri != null)
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                            onPressed: () => launchUrl(uri,
                                mode: LaunchMode.externalApplication),
                            child: const ProxoText('بینینی فێرکاری'))),
                ])));
  }
}
