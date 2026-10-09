import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/proxo_card.dart';
import '../models/proxolink_page_type.dart';
import '../services/proxolink_service.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/ad_validation_notifications.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxolink_design_selector.dart';
import '../widgets/receipt/receipt_kit.dart';

/// New authoring presentation. Templates remain private server documents;
/// only twelve bundled raster thumbnails are decoded in this route.
class ProxoLinkCreatePageScreen extends StatefulWidget {
  final ProxoLinkRepository repository;
  const ProxoLinkCreatePageScreen({super.key, required this.repository});
  @override
  State<ProxoLinkCreatePageScreen> createState() => _CreatePageState();
}
class _CreatePageState extends State<ProxoLinkCreatePageScreen> {
  final _name = TextEditingController(), _bio = TextEditingController(), _tt = TextEditingController();
  final _notices = AdValidationController();
  final _values = <String, TextEditingController>{};
  final _scroll = ScrollController();
  ProxoPageType _type = ProxoPageType.contact;
  List<ProxoTemplate> _templates = [];
  List<ProxoProvider> _providers = [];
  String _design = 'pill', _request = newProxoRequestId();
  String? _owner, _avatar;
  Uint8List? _image;
  Map<String, dynamic>? _submitted;
  bool _loading = true, _busy = false, _picking = false, _invalidated = false;
  StreamSubscription<AuthState>? _auth;
  String get _pendingKey => 'proxolink-create-request-${_owner ?? 'fixture'}';
  @override
  void initState() {
    super.initState();
    _owner = widget.repository.ownerScope;
    final repo = widget.repository;
    if (repo is ProxoLinkService) {
      _auth = repo.db.auth.onAuthStateChange.listen((_) {
        if (_owner != repo.ownerScope && mounted) {
          unawaited(SharedPreferences.getInstance().then((prefs) => prefs.remove(_pendingKey)));
          _invalidated = true; _name.clear(); _bio.clear(); _tt.clear();
          for (final c in _values.values) { c.clear(); }
          setState(() { _image = null; _avatar = null; _submitted = null; });
          _notice('owner', const ProxoLinkFailure('unauthorized').message);
        }
      });
    }
    unawaited(_load());
  }
  bool get _sameOwner => !_invalidated && _owner == widget.repository.ownerScope;
  void _notice(String field, String message) => _notices.show({field: message});
  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([widget.repository.templates(), widget.repository.providers()]);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || !_sameOwner) return;
      final pending = prefs.getString(_pendingKey);
      if (pending != null) {
        final rows = await widget.repository.cards();
        if (!mounted || !_sameOwner) return;
        for (final page in rows) {
          if (page.clientRequestId == pending && (_owner == null || page.userId == _owner)) {
            await prefs.remove(_pendingKey);
            if (mounted) Navigator.of(context).pop(page);
            return;
          }
        }
      }
      final templates = (results[0] as List<ProxoTemplate>).where((t) => t.version == 6).toList();
      if (templates.map((t) => t.key).toSet().length != 4) throw const ProxoLinkFailure('template_not_found');
      setState(() {
        _templates = templates; _providers = results[1] as List<ProxoProvider>;
        for (final p in _providers) { _values[p.key] = TextEditingController(); }
        // Only the random request key is retained, never form/customer content.
        _request = prefs.getString(_pendingKey) ?? _request; _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _notice('load', _failure(e));
    }
  }
  String _failure(Object e) => (e is ProxoLinkFailure ? e : const ProxoLinkFailure('network_error')).message;
  Future<void> _pickImage() async {
    if (_busy || _picking || !_sameOwner) return;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length < 12 || bytes.length > 10 * 1024 * 1024) throw const ProxoLinkFailure('invalid_avatar');
      if (!mounted || !_sameOwner) return;
      setState(() { _image = bytes; _avatar = null; });
    } catch (e) { if (mounted) _notice('image', _failure(e)); }
    finally { if (mounted) setState(() => _picking = false); }
  }
  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty || _name.text.length > 160) errors['name'] = 'تکایە ${_type.nameLabel} بنووسە.';
    if (_bio.text.length > 2000) errors['bio'] = 'کورتە باس دەبێت لە ٢٠٠٠ پیت کەمتر بێت.';
    final tt = _tt.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (tt.isNotEmpty && !RegExp(r'^[A-Za-z0-9._]{1,40}$').hasMatch(tt)) errors['tt'] = const ProxoLinkFailure('invalid_tiktok').message;
    final selected = _providers.where((p) => p.pageType == _type.key && (_values[p.key]?.text.trim().isNotEmpty ?? false));
    if (selected.isEmpty) errors['providers'] = const ProxoLinkFailure('provider_required').message;
    for (final p in selected) {
      final value = _values[p.key]!.text.trim();
      if (p.inputKind == 'url') {
        final uri = Uri.tryParse(value);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
          errors[p.key] = '${p.label}: ${const ProxoLinkFailure('invalid_provider_destination').message}';
        }
      }
    }
    return errors;
  }
  Future<void> _save() async {
    if (_busy || _picking || !_sameOwner || _templates.isEmpty) return;
    final errors = _validate();
    if (errors.isNotEmpty) { _notices.show(errors); return; }
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, _request);
      if (_image != null && _avatar == null) {
        _avatar = await widget.repository.uploadAvatar(_request, _image!);
      }
      if (!mounted || !_sameOwner) throw const ProxoLinkFailure('unauthorized');
      var order = 0;
      _submitted ??= {
        'client_request_id': _request, 'page_kind': _type.key,
        'name': _name.text.trim(), 'bio': _bio.text.trim(),
        'tt': _tt.text.trim().replaceFirst(RegExp(r'^@'), ''),
        'template_key': _design, 'template_version': 6,
        'card_language': 'ku', 'color_theme': 'purple', 'avatar_path': _avatar,
        'settings': {'providers': [for (final p in _providers.where((p) => p.pageType == _type.key))
          if (_values[p.key]!.text.trim().isNotEmpty) {
            'provider_key': p.key, 'destination_url': _values[p.key]!.text.trim(),
            'enabled': true, 'sort_order': order++,
          }]},
      };
      final saved = await widget.repository.save(_submitted!);
      if (!mounted || !_sameOwner) return;
      await prefs.remove(_pendingKey);
      if (mounted) Navigator.of(context).pop(saved);
    } on ProxoLinkFailure catch (e) {
      if (!mounted || !_sameOwner) return;
      if (e.savedCard != null) {
        final prefs = await SharedPreferences.getInstance(); await prefs.remove(_pendingKey);
        if (mounted) Navigator.of(context).pop(e.savedCard);
      } else {
        // Definite validation rejection permits correction; uncertain network
        // outcomes keep the same first payload/key to avoid duplicate creates.
        if ({'invalid_provider_destination','invalid_page_settings','invalid_tiktok','invalid_avatar','invalid_card_name','invalid_bio'}.contains(e.code)) _submitted = null;
        _notice('save', e.message);
      }
    } catch (e) { if (mounted && _sameOwner) _notice('save', _failure(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() {
    unawaited(_auth?.cancel()); _name.dispose(); _bio.dispose(); _tt.dispose();
    for (final c in _values.values) { c.dispose(); }
    _notices.dispose(); _scroll.dispose(); super.dispose();
  }
  Widget _field(TextEditingController controller, String label, {int lines = 1, int? limit, TextInputType? keyboard}) =>
    ProxoDirectionalInput(controller: controller, keyboardType: keyboard, builder: (context, direction) =>
      TextFormField(controller: controller, textDirection: direction, decoration: InputDecoration(labelText: label),
        minLines: lines, maxLines: lines == 1 ? 1 : 6, maxLength: limit, keyboardType: keyboard));
  @override
  Widget build(BuildContext context) => Theme(data: AdUi.theme(context), child: Directionality(
    textDirection: TextDirection.rtl, child: Builder(builder: (context) => Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Column(children: [
        ReceiptAppBar(title: 'دروستکردنی پەڕە', onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: Stack(children: [
          SingleChildScrollView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                AbsorbPointer(absorbing: _busy || _submitted != null || !_sameOwner, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AdFormSection(title: 'جۆری پەڕە', child: Column(children: [for (final type in ProxoPageType.values)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: double.infinity,
                      child: AdChoice(key: ValueKey('create-type-${type.key}'), label: type.label, selected: _type == type,
                        onTap: () => setState(() { _type = type; }))))])),
                  const SizedBox(height: AdUi.sectionGap),
                  AdFormSection(title: 'زانیاری سەرەکی', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    OutlinedButton.icon(onPressed: _picking ? null : _pickImage,
                      icon: Icon(_image == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_outline),
                      label: ProxoText(_type.imageLabel)),
                    if (_image != null) ...[const SizedBox(height: 12), Center(child: ClipRRect(
                      borderRadius: AdUi.controlRadius, child: Image.memory(_image!, width: 80, height: 80, fit: BoxFit.cover)))],
                    const SizedBox(height: 16), _field(_name, _type.nameLabel, limit: 160),
                    const SizedBox(height: 16), _field(_bio, 'کورتە باس', lines: 3, limit: 2000),
                    const SizedBox(height: 16), _field(_tt, 'ناوی تیک تۆک', limit: 40),
                  ])),
                  const SizedBox(height: AdUi.sectionGap),
                  AdFormSection(title: 'پەیوەندی و دووگمەکان', child: Column(children: [
                    for (final p in _providers.where((p) => p.pageType == _type.key))
                      Padding(padding: const EdgeInsets.only(bottom: 16), child: _field(_values[p.key]!, p.label,
                        keyboard: p.inputKind == 'phone' ? TextInputType.phone : p.inputKind == 'url' ? TextInputType.url : TextInputType.text)),
                  ])),
                  const SizedBox(height: AdUi.sectionGap),
                  AdFormSection(title: 'ستایلی پەڕە', child: ProxoLinkDesignSelector(templates: _templates,
                    pageType: _type, selectedKey: _design, onSelected: (t) => setState(() => _design = t.key))),
                ])),
                const SizedBox(height: 24),
                FilledButton(key: const ValueKey('create-page-submit'), onPressed: _busy || _loading || !_sameOwner ? null : _save,
                  child: const ProxoText('پەڕە دروستبکە')),
                if (_templates.isEmpty && !_loading) TextButton(onPressed: _load, child: const ProxoText('دووبارە هەوڵ بدەرەوە')),
              ])))),
          Positioned(top: 12, left: 16, right: 16, child: AdValidationNotifications(controller: _notices)),
        ])),
      ]),
    ))));
}
