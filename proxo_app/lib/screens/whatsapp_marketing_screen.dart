import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/proxo_strings.dart';
import '../theme/app_locale.dart';
import '../widgets/auth/auth_design.dart';
import '../widgets/auth/auth_widgets.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxo_app_bar.dart';

/// Loaded only when opened; no additional read/subscription on the Profile tab.
class WhatsappMarketingScreen extends StatefulWidget {
  const WhatsappMarketingScreen({super.key});
  @override
  State<WhatsappMarketingScreen> createState() => _WhatsappMarketingScreenState();
}

class _WhatsappMarketingScreenState extends State<WhatsappMarketingScreen> {
  SupabaseClient get _client => Supabase.instance.client;
  bool? _choice;
  bool _savedChoice = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final owner = _client.auth.currentUser?.id;
    if (owner == null) {
      if (mounted) setState(() => _error = AuthStrings.errServer);
      return;
    }
    if (mounted) setState(() => _error = null);
    try {
      final row = await _client.from('whatsapp_marketing_preferences')
          .select('opted_in').eq('user_id', owner).maybeSingle();
      if (!mounted || _client.auth.currentUser?.id != owner) return;
      setState(() { _choice = row?['opted_in'] == true; _savedChoice = _choice!; });
    } catch (_) {
      if (mounted) setState(() => _error = AuthStrings.errServer);
    }
  }

  Future<void> _save() async {
    if (_choice == null || _saving) return;
    final owner = _client.auth.currentUser?.id;
    if (owner == null) {
      if (mounted) setState(() => _error = AuthStrings.errServer);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final result = await _client.rpc('pa_set_whatsapp_marketing', params: {
        'p_opted_in': _choice, 'p_version': 'whatsapp-marketing-v1',
        'p_locale': ProxoLocale.current.value.languageCode,
      });
      if (result is! Map || result['ok'] != true) throw StateError('not_saved');
      if (!mounted || _client.auth.currentUser?.id != owner) return;
      setState(() => _savedChoice = _choice!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: ProxoText(
        ProxoStrings.text('هەڵبژاردنەکەت تۆمار کرا', arabic: 'تم حفظ اختيارك'))));
    } catch (_) {
      if (mounted) setState(() => _error = AuthStrings.errServer);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Scaffold(backgroundColor: AuthTokens.pageBackground,
      appBar: ProxoAppBar(title: ProxoStrings.text('ئاگاداریی واتسئاپ',
        arabic: 'إشعارات واتساب')),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_choice == null && _error == null) const Center(child: CircularProgressIndicator())
          else if (_choice != null) ...[
            AuthWhatsappConsent(value: _choice!, onChanged: _saving ? null :
              (value) => setState(() => _choice = value)),
            const SizedBox(height: AuthTokens.gapBetweenFields),
            AuthPrimaryButton(label: ProxoStrings.text('تۆمارکردنی هەڵبژاردن', arabic: 'حفظ الاختيار'),
              loading: _saving, enabled: _choice != _savedChoice, onPressed: _save),
          ],
          if (_error != null) ...[
            const SizedBox(height: AuthTokens.gapBetweenFields),
            AuthAlert(message: _error),
            if (_choice == null) AuthPrimaryButton(label: ProxoStrings.text('دووبارە هەوڵ بدەرەوە',
              arabic: 'حاول مجدداً'), onPressed: _load),
          ],
        ]),
      )),
    );
  }
}
