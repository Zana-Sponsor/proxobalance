import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/proxo_card.dart';
import '../models/proxolink_page_type.dart';
import '../models/proxolink_template_meta.dart';
import '../services/proxolink_service.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxolink_preview.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'ad_create_screen.dart';
import 'card_webview_screen.dart';

class ToolsScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onUseForAd;
  final bool initialCreate;
  final ProxoLinkRepository? repository;
  const ToolsScreen({
    super.key,
    this.onUseForAd,
    this.initialCreate = false,
    this.repository,
  });
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late final ProxoLinkRepository _repository;
  List<ProxoCard> _cards = [];
  bool _loading = true, _failed = false, _form = false;
  ProxoCard? _editing;
  final Set<String> _busy = {};
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ProxoLinkService(Supabase.instance.client);
    _form = widget.initialCreate;
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final cards = await _repository.cards();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _failed = false;
      });
      _poll?.cancel();
      if (cards.any((c) => c.publishStatus == 'creating')) {
        _poll = Timer(const Duration(seconds: 5), _refresh);
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _failed = true;
        });
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: ProxoText(text)));
  }

  void _create() {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _editing = null;
      _form = true;
    });
  }
  void _edit(ProxoCard card) {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _editing = card;
      _form = true;
    });
  }
  void _use(ProxoCard card) {
    if (!card.available) return;
    if (widget.onUseForAd != null) {
      widget.onUseForAd!(card.toJson());
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdCreateScreen(proxoCard: card.toJson()),
      ),
    );
  }

  Future<void> _saved(ProxoCard? card) async {
    if (card != null &&
        card.available &&
        widget.initialCreate &&
        widget.onUseForAd != null) {
      widget.onUseForAd!(card.toJson());
      return;
    }
    setState(() {
      _form = false;
      _editing = null;
    });
    await _refresh();
  }

  Future<void> _action(ProxoCard card, String action) async {
    if (_busy.contains(card.id)) return;
    if (action == 'delete' || action == 'deactivate') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: ProxoText(
            action == 'delete' ? 'سڕینەوەی پەڕە' : 'ناچالاککردنی پەڕە',
            style: AdUi.heading(context),
          ),
          content: ProxoText(
            action == 'delete'
                ? 'پەڕەکە دەسڕدرێتەوە و بەستەرەکە بەردەست نابێت.'
                : 'بەستەری گشتیی پەڕەکە ناچالاک دەبێت.',
            style: AdUi.text(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const ProxoText('پاشگەزبوونەوە'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const ProxoText('بەردەوامبوون'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() => _busy.add(card.id));
    try {
      await _repository.action(card.id, action);
      await _refresh();
    } on ProxoLinkFailure catch (e) {
      _message(e.message);
    } catch (_) {
      _message(const ProxoLinkFailure('network_error').message);
    } finally {
      if (mounted) setState(() => _busy.remove(card.id));
    }
  }

  Future<void> _more(ProxoCard card) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const ProxoText('دەستکاریکردن'),
                leading: const Icon(Icons.edit_outlined),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              if (card.available) ...[
                ListTile(
                  title: const ProxoText('کۆپی لینک'),
                  leading: const Icon(Icons.link),
                  onTap: () => Navigator.pop(context, 'copy'),
                ),
                ListTile(
                  title: const ProxoText('هاوبەشکردن'),
                  leading: const Icon(Icons.share_outlined),
                  onTap: () => Navigator.pop(context, 'share'),
                ),
                ListTile(
                  title: const ProxoText('ناچالاککردن'),
                  leading: const Icon(Icons.pause_circle_outline),
                  onTap: () => Navigator.pop(context, 'deactivate'),
                ),
              ],
              if (card.publishStatus == 'ready' && !card.available)
                ListTile(
                  title: const ProxoText('چالاککردن'),
                  leading: const Icon(Icons.play_circle_outline),
                  onTap: () => Navigator.pop(context, 'activate'),
                ),
              ListTile(
                title: const ProxoText('سڕینەوە'),
                leading: const Icon(Icons.delete_outline),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'edit') {
      _edit(card);
      return;
    }
    if (choice == 'copy') {
      await Clipboard.setData(
        ClipboardData(text: _repository.publicUrl(card.id, pageType: card.pageType.key).toString()),
      );
      _message('بەستەرەکە کۆپی کرا');
      return;
    }
    if (choice == 'share') {
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        '${card.name}\n${_repository.publicUrl(card.id, pageType: card.pageType.key)}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
      return;
    }
    await _action(card, choice);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AdUi.theme(context),
    child: Builder(
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope<Object?>(
          canPop: !_form,
          onPopInvokedWithResult: (popped, _) {
            if (!popped && _form) setState(() => _form = false);
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  ReceiptAppBar(
                    title: _form
                        ? (_editing == null
                              ? 'دروستکردنی پەڕەی پەیوەندی'
                              : 'دەستکاریکردنی پەڕە')
                        : 'پەڕەکانی پەیوەندی',
                    onBack: () {
                      if (_form) {
                        setState(() => _form = false);
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Expanded(
                    child: _form
                        ? _ContactForm(
                            key: ValueKey(_editing?.id ?? 'new'),
                            repository: _repository,
                            existing: _editing,
                            onSaved: _saved,
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                20,
                                16,
                                24,
                              ),
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 600,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: _create,
                                          icon: const Icon(Icons.add),
                                          label: const ProxoText('پەڕەی نوێ'),
                                        ),
                                        const SizedBox(height: AdUi.sectionGap),
                                        if (_loading)
                                          const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        else if (_failed)
                                          _LoadFailure(onRetry: _refresh)
                                        else if (_cards.isEmpty)
                                          AdFormSection(
                                            title: 'پەڕەیەکت نییە',
                                            child: ProxoText(
                                              'پەڕەی پەیوەندی دروست بکە بۆ کۆکردنەوەی ڕێگاکانی پەیوەندی لە یەک شوێن.',
                                              style: AdUi.text(
                                                context,
                                                color: AdUi.secondary,
                                              ),
                                            ),
                                          ),
                                        for (final card in _cards)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: AdUi.sectionGap,
                                            ),
                                            child: _ContactRow(
                                              card: card,
                                              busy: _busy.contains(card.id),
                                              onMore: () => _more(card),
                                              onUse: () => _use(card),
                                              onRetry: () =>
                                                  _action(card, 'retry'),
                                              onPreview: () => Navigator.push(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      CardWebViewScreen(
                                                        title: card.name,
                                                        loadUrl: () =>
                                                            _repository.preview(
                                                              card.id,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadFailure({required this.onRetry});
  @override
  Widget build(BuildContext context) => AdFormSection(
    title: 'نەتوانرا زانیارییەکان پیشان بدرێن',
    child: OutlinedButton(
      onPressed: onRetry,
      child: const ProxoText('دووبارە هەوڵبدەرەوە'),
    ),
  );
}

class _ContactRow extends StatelessWidget {
  final ProxoCard card;
  final bool busy;
  final VoidCallback onMore, onUse, onRetry, onPreview;
  const _ContactRow({
    required this.card,
    required this.busy,
    required this.onMore,
    required this.onUse,
    required this.onRetry,
    required this.onPreview,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: AdUi.cardPadding,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: AdUi.radius,
      boxShadow: AdUi.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AdUi.controlSurface,
              child: card.avatarUrl == null
                  ? const Icon(Icons.person_outline, color: AdUi.secondary)
                  : ClipOval(
                      child: Image.network(
                        card.avatarUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_outline,
                          color: AdUi.secondary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProxoText(card.name, style: AdUi.text(context)),
                  const SizedBox(height: 6),
                  ProxoText(
                    '${card.createdAt.toLocal().year}/${card.createdAt.toLocal().month}/${card.createdAt.toLocal().day}',
                    style: AdUi.text(context, color: AdUi.secondary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: busy ? null : onMore,
              tooltip: 'زیاتر',
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuietChip(label: card.pageType.label),
            _QuietChip(label: card.templateKey),
            _QuietChip(label: card.stateLabel),
            if (busy || card.publishStatus == 'creating')
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (card.canPreview)
              OutlinedButton(
                onPressed: busy ? null : onPreview,
                child: const ProxoText('پێشبینین'),
              ),
            if (card.available)
              FilledButton(
                onPressed: busy ? null : onUse,
                child: const ProxoText('ڕیکلام'),
              ),
            if (card.canRetry)
              FilledButton(
                onPressed: busy ? null : onRetry,
                child: const ProxoText('دووبارە هەوڵبدەرەوە'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _QuietChip extends StatelessWidget {
  final String label;
  const _QuietChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: const BoxDecoration(
      color: AdUi.controlSurface,
      borderRadius: AdUi.controlRadius,
    ),
    child: ProxoText(label, style: AdUi.text(context, color: AdUi.secondary)),
  );
}

class _ContactForm extends StatefulWidget {
  final ProxoLinkRepository repository;
  final ProxoCard? existing;
  final Future<void> Function(ProxoCard?) onSaved;
  const _ContactForm({
    super.key,
    required this.repository,
    this.existing,
    required this.onSaved,
  });
  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _bio = TextEditingController(),
      _tt = TextEditingController();
  final _contacts = <String, TextEditingController>{};
  final _enabled = <String>{};
  late String _id;
  String? _avatarPath;
  Uint8List? _avatar;
  bool _avatarUploaded=false;
  Uri? _remoteAvatar;
  String _template = 'pill', _theme = 'purple', _language = 'ku';
  int _version = 6;
  ProxoPageType? _kind;
  List<ProxoProvider>? _providers;
  final _order = <String>[];
  Timer? _previewDebounce;
  int _previewRevision = 0;
  bool get _legacy => widget.existing != null && widget.existing!.pageKind == null;
  List<ProxoProvider> get _typeProviders => (_providers ?? []).where((p)=>p.pageType == _kind?.key).toList()
    ..sort((a,b)=>_order.indexOf(a.key).compareTo(_order.indexOf(b.key)));
  void _changed() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 500), () {
      if(mounted) setState(()=>_previewRevision++);
    });
  }
  void _moveProvider(String key,int delta){
    final visible=_typeProviders.map((p)=>p.key).toList(),index=visible.indexOf(key);
    final target=index+delta;if(target<0 || target>=visible.length)return;
    final a=_order.indexOf(key),b=_order.indexOf(visible[target]);
    _order[a]=visible[target];_order[b]=key;_previewRevision++;
  }
  Future<Uri> _livePreview() => _legacy
    ? widget.repository.templatePreview(_template,_version,theme:_theme,language:_language)
    : widget.repository.formPreview({..._data(), 'name':_name.text.trim().isEmpty ? _kind!.nameLabel : _name.text.trim()},existing:widget.existing);
  List<ProxoTemplate>? _templates;
  bool _catalogFailed = false, _saving = false;
  bool _restoredDraft = false;
  String? _error;
  late final String _pendingKey;
  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _bio.addListener(_changed);
    _id = widget.existing?.id ?? newProxoRequestId();
    _pendingKey =
        'proxolink.pending.${widget.repository is ProxoLinkService ? (widget.repository as ProxoLinkService).db.auth.currentUser?.id : 'test'}';
    if (widget.existing != null) _fill(widget.existing!.toJson());
    unawaited(_initialize());
  }

  void _fill(Map<String, dynamic> j) {
    _name.text = j['name'] as String? ?? '';
    _bio.text = j['bio'] as String? ?? '';
    _tt.text = j['tt'] as String? ?? '';
    _kind = ProxoPageTypeInfo.parse(j['page_kind'] as String?);
    _template = j['template_key'] as String? ?? 'pill';
    _version = (j['template_version'] as num?)?.toInt() ?? 6;
    if(widget.existing == null){
      const aliases={'dark':'pill-dark','light':'pill-white','classic':'pill-white','card':'pill-white','neon':'pill-mint','zoom':'pill','banner':'pill'};
      _template=aliases[_template] ?? _template;_version=6;
    }
    _theme = themeByKey(j['color_theme'] as String?).key;
    _language = j['card_language'] as String? ?? 'ku';
    _avatarPath = j['avatar_path'] as String?;
    _id = j['client_request_id'] as String? ?? _id;
    _enabled.clear();
    final configured = (j['settings'] as Map?)?['providers'] as List?;
    if(configured != null){
      final keys=configured.map((p)=>(p as Map)['provider_key'] as String).toList();
      _order..removeWhere(keys.contains)..insertAll(0,keys);
    }
    final values = configured == null ? j['platforms'] as Map? ?? {} : {for(final p in configured) (p as Map)['provider_key']:p['destination_url']};
    const aliases = {
      'wa': 'whatsapp', 'vb': 'viber', 'ig': 'instagram', 'tg': 'telegram',
      'ph': 'korek', 'as': 'asiacell', 'phone':'korek', 'asya':'asiacell',
    };
    for (final e in values.entries) {
      final key = aliases[e.key] ?? e.key;
      if (_contacts.containsKey(key)) {
        _contacts[key]!.text = e.value.toString();
        if(configured == null || configured.any((p)=>(p as Map)['provider_key']==key && p['enabled']==true)) _enabled.add(key as String);
      }
    }
  }

  Future<void> _initialize() async {
    await _loadCatalog();
    if (widget.existing == null && widget.repository is ProxoLinkService) {
      final pending = (await SharedPreferences.getInstance()).getString(
        _pendingKey,
      );
      if (pending != null && mounted) {
        try {
          setState(() {
            _fill(Map<String, dynamic>.from(jsonDecode(pending) as Map));
            _restoredDraft = true;
          });
        } catch (_) {
          /* Leave an invalid local draft untouched; no server mutation. */
        }
      }
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final templates = await widget.repository.templates();
      final providers = await widget.repository.providers();
      Uri? avatar;
      if(widget.existing?.avatarPath != null){
        try{final preview=await widget.repository.preview(widget.existing!.id);avatar=preview.replace(path:'${widget.existing!.publicPath}/avatar');}catch(_){}
      }
      if(!mounted)return;
      _providers = providers;
      for(final p in providers){
        if(!_contacts.containsKey(p.key)){
          _contacts[p.key]=TextEditingController()..addListener(_changed);
          _order.add(p.key);
        }
      }
      if(widget.existing != null)_fill(widget.existing!.toJson());
      if (templates.isEmpty)
        throw const ProxoLinkFailure('templates_unavailable');
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _remoteAvatar = avatar;
        _catalogFailed = false;
        if (!templates.any((t) => t.key == _template)) {
          const aliases={'dark':'pill-dark','light':'pill-white','classic':'pill-white','card':'pill-white','neon':'pill-mint','zoom':'pill','banner':'pill'};
          _template=aliases[_template] ?? templates.first.key;
          _version=templates.firstWhere((t)=>t.key==_template).version;
        }
        if (widget.existing == null && !_restoredDraft) {
          _version = templates.firstWhere((t) => t.key == _template).version;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _catalogFailed = true);
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _name.dispose();
    _bio.dispose();
    _tt.dispose();
    for (final c in _contacts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 10 * 1024 * 1024)
        throw const ProxoLinkFailure('invalid_avatar');
      setState(() {
        _avatar = bytes;
        _avatarUploaded=false;
        _error = null;
      });
      final uploaded = await widget.repository.uploadAvatar(_id,bytes);
      if(!mounted)return;
      setState(() { _avatarPath=uploaded; _avatarUploaded=true; _previewRevision++; });
    } on ProxoLinkFailure catch(e){
      if(mounted)setState(()=>_error=e.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = const ProxoLinkFailure('invalid_avatar').message,
        );
    }
  }

  String _legacyProviderId(String key) => const {'whatsapp':'wa','viber':'vb','instagram':'ig','telegram':'tg','korek':'ph','asiacell':'as'}[key]!;
  Map<String, dynamic> _data() => {
    'client_request_id': _id,
    'name': _name.text.trim(), 'bio': _bio.text.trim(),
    'template_key': _template, 'template_version': _version,
    'color_theme': _theme, 'card_language': _language, 'avatar_path': _avatarPath,
    if(!_legacy) 'page_kind':_kind!.key,
    if(!_legacy) 'settings':{'providers':[
      for(final p in _typeProviders)
        if(_contacts[p.key]!.text.trim().isNotEmpty)
          {'provider_key':p.key,'destination_url':_contacts[p.key]!.text.trim(),
           'enabled':_enabled.contains(p.key),'sort_order':_typeProviders.indexOf(p)},
    ]},
    if(_legacy) 'tt': _tt.text.trim().replaceFirst(RegExp(r'^@'), ''),
    if(_legacy) 'platforms': {
      for(final p in _typeProviders)
        if(_enabled.contains(p.key))
          _legacyProviderId(p.key):_contacts[p.key]!.text.trim(),
    },
  };
  Future<void> _save() async {
    if (_saving || _templates == null || !_form.currentState!.validate())
      return;
    final template = _templates!.firstWhere((t) => t.key == _template);
    if (template.requiresAvatar && _avatar == null && _avatarPath == null) {
      setState(
        () => _error = const ProxoLinkFailure('avatar_required').message,
      );
      return;
    }
    if (!_typeProviders.any((p)=>_enabled.contains(p.key)) && (!_legacy || _tt.text.trim().isEmpty)) {
      setState(() => _error = 'تکایە کەمترین یەک دووگمە زیاد بکە.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_avatar != null && !_avatarUploaded) {
        _avatarPath = await widget.repository.uploadAvatar(_id, _avatar!);
        _avatar = null;
      }
      final payload = _data();
      if (widget.existing == null && widget.repository is ProxoLinkService) {
        await (await SharedPreferences.getInstance()).setString(
          _pendingKey,
          jsonEncode(payload),
        );
      }
      final card = await widget.repository.save(
        payload,
        existing: widget.existing,
      );
      if (widget.existing == null)
        await (await SharedPreferences.getInstance()).remove(_pendingKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ProxoText('پەڕەکە بە سەرکەوتوویی پاشەکەوت کرا.'),
          ),
        );
        await widget.onSaved(card);
      }
    } on ProxoLinkFailure catch (e) {
      if (e.savedCardId != null) {
        await (await SharedPreferences.getInstance()).remove(_pendingKey);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: ProxoText(e.message)));
          await widget.onSaved(null);
        }
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error = const ProxoLinkFailure('network_error').message,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool ltr = false,
    int lines = 1,
    int? limit,
    bool required = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      textDirection: ltr
          ? TextDirection.ltr
          : ProxoTextDirection.of(controller.text),
      textAlign: ltr ? TextAlign.left : TextAlign.right,
      keyboardType: keyboard,
      maxLines: lines,
      maxLength: limit,
      style: AdUi.text(context),
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) => required && (value == null || value.trim().isEmpty)
          ? 'تکایە ئەم خانەیە پڕ بکەرەوە.'
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) => _kind == null ? Center(
    child: SingleChildScrollView(child:Padding(padding: const EdgeInsets.all(16),child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[const ProxoText('جۆری پەڕە هەڵبژێرە'),const SizedBox(height:20),
        for(final type in ProxoPageType.values) Padding(padding:const EdgeInsets.only(bottom:12),
          child:OutlinedButton(onPressed:()=>setState(()=>_kind=type),child:ProxoText(type.label))),
      ],
    ))),
  ) : AbsorbPointer(
    absorbing: _saving,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdFormSection(
                  title: _kind!.imageLabel,
                  child: Column(
                    children: [
                      if (_avatar != null)
                        ClipOval(
                          child: Image.memory(
                            _avatar!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (_remoteAvatar != null)
                        ClipOval(
                          child: Image.network(
                            _remoteAvatar.toString(),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person_outline),
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickAvatar,
                        icon: const Icon(Icons.photo_outlined),
                        label: const ProxoText('هەڵبژاردنی وێنە'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AdUi.sectionGap),
                AdFormSection(
                  title: 'زانیارییەکانی پەڕە',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(_name, _kind!.nameLabel, required: true, limit: 160),
                      _field(_bio, 'بایۆ', lines: 4, limit: 2000),
                      if(_legacy) _field(_tt, 'ناوی تیکتۆک', ltr: true, limit: 40),
                      DropdownButtonFormField<String>(
                        initialValue: _language,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'زمانی پەڕە',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ku',
                            child: ProxoText('کوردی'),
                          ),
                          DropdownMenuItem(
                            value: 'ar',
                            child: ProxoText('عربی'),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: ProxoText('English'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _language = value!),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final theme in kCardThemes)
                            Semantics(
                              label: theme.key,
                              selected: _theme == theme.key,
                              button: true,
                              child: InkWell(
                                onTap: () => setState(() => _theme = theme.key),
                                borderRadius: AdUi.controlRadius,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: theme.swatch,
                                    borderRadius: AdUi.controlRadius,
                                  ),
                                  child: _theme == theme.key
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AdUi.sectionGap),
                AdFormSection(
                  title: _kind!.label,
                  child: Column(
                    children: [
                      for (final p in _typeProviders) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: ProxoText(p.label, style: AdUi.text(context)),
                          value: _enabled.contains(p.key),
                          onChanged: (enabled) => setState(() {
                            if (enabled) {
                              _enabled.add(p.key);
                            } else {
                              _enabled.remove(p.key);
                            }
                            _previewRevision++;
                          }),
                        ),
                        Row(children: [
                          IconButton(
                            tooltip: 'بۆ سەرەوە',
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: () => setState(() {
                              _moveProvider(p.key, -1);
                            }),
                          ),
                          IconButton(
                            tooltip: 'بۆ خوارەوە',
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: () => setState(() {
                              _moveProvider(p.key, 1);
                            }),
                          ),
                        ]),
                        if (_enabled.contains(p.key))
                          _field(
                            _contacts[p.key]!,
                            p.hint,
                            ltr: true,
                            required: true,
                            limit: 2048,
                            keyboard: p.inputKind == 'phone'
                                ? TextInputType.phone
                                : TextInputType.text,
                          ),
                      ],
                    ],
                  ),
                ),
                AdFormSection(
                  title: 'شێوازی پەڕە',
                  child: _catalogFailed
                      ? _LoadFailure(onRetry: _loadCatalog)
                      : _templates == null
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final t in _templates!)
                                  AdChoice(
                                    label: t.label,
                                    selected: t.key == _template,
                                    onTap: () => setState(() {
                                      _template = t.key;
                                      _version = t.version;
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: AdUi.controlRadius,
                              child: SizedBox(
                                height: 460,
                                child: ProxoLinkPreview(
                                  key: ValueKey('$_template/$_version/$_theme/$_language/${_kind!.key}/$_previewRevision'),
                                  loadUrl: _livePreview,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CardWebViewScreen(
                                    title: 'پێشبینینی شێواز',
                                    allowContactActions: false,
                                    loadUrl: _livePreview,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.open_in_full),
                              label: const ProxoText('پێشبینینی تەواو'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AdUi.sectionGap),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ProxoText(
                      _error!,
                      style: AdUi.text(
                        context,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AdUi.sectionGap),
                FilledButton(
                  onPressed: _saving || _templates == null ? null : _save,
                  child: _saving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Flexible(child: ProxoText('لە دروستکردندایە...')),
                          ],
                        )
                      : ProxoText(
                          widget.existing == null
                              ? 'دروستکردن'
                              : 'پاشەکەوتکردن',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
