import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show supabase;
import '../services/proxolink_service.dart';
import '../theme/app_locale.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// Aggregate data is authorized by the database for this exact advertisement.
/// Opening this section never opens a tracked page or generates a visit.
class ProxoLinkAdSection extends StatefulWidget {
  final String adId;
  final Future<Map<String, dynamic>> Function(String id)? loadSummary;
  const ProxoLinkAdSection({super.key, required this.adId, this.loadSummary});
  @override
  State<ProxoLinkAdSection> createState() => _ProxoLinkAdSectionState();
}

class _ProxoLinkAdSectionState extends State<ProxoLinkAdSection> {
  Map<String, dynamic>? _summary;
  bool _loading = true, _failed = false;
  int _request = 0;
  bool get _arabic => ProxoLocale.current.value.languageCode == 'ar';
  String _text(String ku, String ar) => _arabic ? ar : ku;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProxoLinkAdSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adId != widget.adId) {
      _summary = null;
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final summary = widget.loadSummary != null
          ? await widget.loadSummary!(widget.adId)
          : Map<String, dynamic>.from(
              await supabase.rpc(
                'proxolink_ad_summary',
                params: {'p_ad_id': widget.adId},
              ),
            );
      if (summary['ad_id'] != widget.adId) throw const FormatException();
      if (mounted && request == _request)
        setState(() {
          _summary = summary;
          _loading = false;
        });
    } catch (_) {
      if (mounted && request == _request)
        setState(() {
          _failed = true;
          _loading = false;
        });
    }
  }

  Uri? get _trackedUrl {
    final path = _summary?['tracked_path'];
    if (path is! String ||
        !RegExp(r'^/a/[A-Za-z0-9_-]{20,128}$').hasMatch(path))
      return null;
    final base = Uri.parse(ProxoLinkService.publicBase);
    return base.scheme == 'https' ? base.resolve(path) : null;
  }

  Future<void> _copy() async {
    final url = _trackedUrl;
    if (url == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: url.toString()));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ProxoText(
              _text('بەسەرکەوتوویی کۆپی کرا', 'تم النسخ بنجاح'),
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: ProxoText(_text('کۆپی نەکرا', 'تعذّر النسخ'))),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AdUi.theme(context),
    child: Builder(
      builder: (context) => AdFormSection(
        title: 'ProxoLink',
        subtitle: _text(
          'ئاماری پەڕەی پەیوەندیی ئەم ڕیکلامە',
          'إحصاءات صفحة الاتصال لهذا الإعلان',
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
            ? OutlinedButton(
                onPressed: _load,
                child: ProxoText(
                  _text('دووبارە هەوڵ بدەرەوە', 'إعادة المحاولة'),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdValueRow(
                    label: _text('بینینی پەڕە', 'مشاهدات الصفحة'),
                    value: '${_summary?['page_views'] ?? 0}',
                  ),
                  const SizedBox(height: 16),
                  AdValueRow(
                    label: _text('کلیک لە دوگمەکان', 'نقرات الأزرار'),
                    value: '${_summary?['button_clicks'] ?? 0}',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      for (final entry in const {
                        'whatsapp': 'WhatsApp',
                        'viber': 'Viber',
                        'telegram': 'Telegram',
                        'instagram': 'Instagram',
                        'phone': 'Phone',
                        'tiktok': 'TikTok',
                      }.entries)
                        ProxoText(
                          '${entry.value}: ${(_summary?['buttons'] as Map?)?[entry.key] ?? 0}',
                          style: AdUi.text(context, color: AdUi.secondary),
                          textDirection: TextDirection.ltr,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_trackedUrl != null) ...[
                    ProxoText(
                      _trackedUrl.toString(),
                      style: AdUi.text(context),
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_outlined),
                      label: ProxoText(
                        _text(
                          'کۆپی بەستەری ئەم ڕیکلامە',
                          'نسخ رابط هذا الإعلان',
                        ),
                      ),
                    ),
                  ] else
                    ProxoText(
                      _text(
                        'بەستەری چالاک بۆ ئەم ڕیکلامە بەردەست نییە.',
                        'لا يوجد رابط نشط لهذا الإعلان.',
                      ),
                      style: AdUi.text(context, color: AdUi.secondary),
                    ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: ProxoText(
                      _text('نوێکردنەوەی ئامار', 'تحديث الإحصاءات'),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}
