import '../widgets/form_help_actions.dart';

import 'package:proxo_app/l10n/proxo_strings.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/proxo_card.dart';
import '../models/proxolink_design.dart';
import '../models/proxolink_page_type.dart';
import '../services/proxolink_service.dart';
import '../services/proxolink_pending_request.dart';
import '../theme/proxo_surface.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/ad_validation_notifications.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxo_symbol.dart';
import '../widgets/proxo_empty_state.dart';
import '../widgets/proxolink_design_selector.dart';
import '../widgets/receipt/receipt_kit.dart';

/// New authoring presentation. Templates remain private server documents;
/// only twelve bundled raster thumbnails are decoded in this route.
class ProxoLinkCreatePageScreen extends StatefulWidget {
  final ProxoLinkRepository repository;
  final ProxoLinkPendingRequestStore pendingRequests;
  final ProxoPageType initialType;
  final bool lockType;
  const ProxoLinkCreatePageScreen({
    super.key,
    required this.repository,
    this.initialType = ProxoPageType.contact,
    this.lockType = false,
    this.pendingRequests = const ProxoLinkPendingRequestStore(),
  });
  @override
  State<ProxoLinkCreatePageScreen> createState() => _CreatePageState();
}

class _CreatePageState extends State<ProxoLinkCreatePageScreen> {
  final _name = TextEditingController(),
      _bio = TextEditingController(),
      _tt = TextEditingController();
  final _notices = AdValidationController();
  final _values = <String, TextEditingController>{};
  final _scroll = ScrollController();
  ProxoPageType _type = ProxoPageType.contact;
  List<ProxoTemplate> _templates = [];
  List<ProxoProvider> _providers = [];
  String _design = 'pill', _request = newProxoRequestId();
  String? _owner, _avatar;
  Uint8List? _image;
  ProxoCard? _completedPage, _failedSavedPage;
  bool _returningPage = false;
  String? _loadFailure;
  bool _loading = true, _busy = false, _picking = false, _invalidated = false;
  bool _loadInFlight = false;
  StreamSubscription<AuthState>? _auth;
  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _owner = widget.repository.ownerScope;
    final repo = widget.repository;
    if (repo is ProxoLinkService) {
      _auth = repo.db.auth.onAuthStateChange.listen((_) {
        if (_owner != repo.ownerScope && mounted) {
          unawaited(_clearPendingRequest());
          _invalidated = true;
          _name.clear();
          _bio.clear();
          _tt.clear();
          for (final c in _values.values) {
            c.clear();
          }
          setState(() {
            _image = null;
            _avatar = null;
          });
          _notice('owner', const ProxoLinkFailure('unauthorized').message);
        }
      });
    }
    unawaited(_load());
  }

  bool get _sameOwner =>
      !_invalidated && _owner == widget.repository.ownerScope;
  void _notice(String field, String message) => _notices.show({field: message});
  Future<void> _load() async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    if (mounted)
      setState(() {
        _loading = true;
        _loadFailure = null;
      });
    try {
      var pending = await widget.pendingRequests
          .read(_owner)
          .timeout(const Duration(seconds: 10));
      if (!mounted || !_sameOwner) return;
      final originRoute = ModalRoute.of(context);
      if (pending != null) {
        _request = pending;
        try {
          final rows = await widget.repository.cards();
          if (!mounted || !_sameOwner) return;
          for (final page in rows) {
            if (page.clientRequestId == pending &&
                (_owner == null || page.userId == _owner)) {
              if (widget.lockType && page.pageType != widget.initialType) {
                // The old request is already durably stored. A new typed
                // route must neither return nor edit an unrelated page kind.
                await _clearPendingRequest();
                if (!mounted || !_sameOwner) return;
                pending = null;
                _request = newProxoRequestId();
                break;
              }
              if (page.available) {
                await _returnPage(page, originRoute);
                return;
              }
              // A stored failed render is recoverable, not a successful page.
              _failedSavedPage = page;
              _type = page.pageType;
              _name.text = page.name;
              _bio.text = page.bio;
              _tt.text = page.tt;
              _design = page.templateKey;
              _avatar = page.avatarPath;
              break;
            }
          }
        } on ProxoLinkFailure catch (e) {
          if (e.code == 'unauthorized') rethrow;
          // A list refresh failure must not make the authoring form unusable.
          // Retaining this ID still prevents duplicate creates on retry.
        }
      }
      final results = await Future.wait<Object>([
        widget.repository.templates(),
        widget.repository.providers(),
      ]);
      if (!mounted || !_sameOwner) return;
      final repository = widget.repository;
      if (repository is ProxoLinkAuthoringAvailability &&
          (repository as ProxoLinkAuthoringAvailability).pageCreationEnabled ==
              false) {
        throw const ProxoLinkFailure('page_creation_unavailable');
      }
      final templates = (results[0] as List<ProxoTemplate>)
          .where(
            (t) => t.version == 6 && ProxoLinkDesign.labels.containsKey(t.key),
          )
          .toList();
      if (!templates
          .map((t) => t.key)
          .toSet()
          .containsAll(ProxoLinkDesign.labels.keys))
        throw const ProxoLinkFailure('template_not_found');
      final providers = results[1] as List<ProxoProvider>;
      if (ProxoPageType.values.any(
        (type) => !providers.any((provider) => provider.pageType == type.key),
      )) {
        throw const ProxoLinkFailure('providers_unavailable');
      }
      setState(() {
        _templates = templates;
        _providers = providers;
        for (final p in _providers) {
          _values.putIfAbsent(p.key, TextEditingController.new);
        }
        for (final provider
            in (_failedSavedPage?.settings['providers'] as List? ?? [])) {
          if (provider is Map &&
              _values.containsKey(provider['provider_key'])) {
            _values[provider['provider_key']]!.text =
                '${provider['destination_url'] ?? ''}';
          }
        }
        // Only the random request key is retained, never form/customer content.
        _request = pending ?? _request;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || !_sameOwner) return;
      setState(() {
        _loading = false;
        _loadFailure = _failure(e);
      });
    } finally {
      _loadInFlight = false;
    }
  }

  String _failure(Object e) =>
      (e is ProxoLinkFailure ? e : const ProxoLinkFailure('network_error'))
          .message;
  Future<void> _clearPendingRequest() async {
    try {
      await widget.pendingRequests
          .clear(_owner)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // The server's confirmed result remains successful if local cleanup
      // fails. A stale key can be reconciled with that same saved page later.
    }
  }

  Future<void> _returnPage(ProxoCard page, Route<dynamic>? originRoute) async {
    if (!mounted || !_sameOwner || _returningPage) return;
    if (widget.lockType && page.pageType != widget.initialType) {
      // A late response can reconcile an older request of another type after
      // the initial refresh failed. Keep this typed form and start a fresh
      // request only now that the older page is known to be stored.
      await _clearPendingRequest();
      if (!mounted || !_sameOwner) return;
      setState(() {
        _request = newProxoRequestId();
        // Uploaded paths are scoped to a request ID. Keep the picked bytes so
        // the next explicit save uploads them into the renewed request folder.
        _avatar = null;
        _completedPage = null;
        _failedSavedPage = null;
      });
      _notice('save', const ProxoLinkFailure('invalid_page_type').message);
      return;
    }
    if (!page.available) {
      _failedSavedPage = page;
      _notice('save', const ProxoLinkFailure('publish_failed').message);
      return;
    }
    _completedPage = page;
    if (originRoute?.isCurrent != true) {
      setState(() => _loading = false);
      return;
    }
    _returningPage = true;
    try {
      await _clearPendingRequest();
      if (mounted && _sameOwner && originRoute?.isCurrent == true) {
        Navigator.of(context).pop(page);
      }
    } finally {
      _returningPage = false;
    }
  }

  Future<void> _pickImage() async {
    if (_busy || _picking || !_sameOwner) return;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length < 12 || bytes.length > 10 * 1024 * 1024)
        throw const ProxoLinkFailure('invalid_avatar');
      if (!mounted || !_sameOwner) return;
      setState(() {
        _image = bytes;
        _avatar = null;
      });
    } catch (e) {
      if (mounted) _notice('image', _failure(e));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty || _name.text.length > 160)
      errors['name'] = 'تکایە ${_type.nameLabel} بنووسە.';
    if (_bio.text.length > 2000)
      errors['bio'] = 'کورتە باس دەبێت لە ٢٠٠٠ پیت کەمتر بێت.';
    final tt = _tt.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (tt.isNotEmpty && !RegExp(r'^[A-Za-z0-9._]{1,40}$').hasMatch(tt))
      errors['tt'] = const ProxoLinkFailure('invalid_tiktok').message;
    final selected = _providers.where(
      (p) =>
          p.pageType == _type.key &&
          (_values[p.key]?.text.trim().isNotEmpty ?? false),
    );
    if (selected.isEmpty)
      errors['providers'] = const ProxoLinkFailure('provider_required').message;
    for (final p in selected) {
      final value = _values[p.key]!.text.trim();
      if (p.inputKind == 'url') {
        final uri = Uri.tryParse(value);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          errors[p.key] =
              '${p.label}: ${const ProxoLinkFailure('invalid_provider_destination').message}';
        }
      }
    }
    return errors;
  }

  Future<void> _save() async {
    if (_busy || _picking || !_sameOwner || _templates.isEmpty) return;
    final errors = _validate();
    if (errors.isNotEmpty) {
      _notices.show(errors);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final originRoute = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await widget.pendingRequests
          .write(_owner, _request)
          .timeout(const Duration(seconds: 10));
      if (!mounted || !_sameOwner) {
        await _clearPendingRequest();
        return;
      }
      if (_image != null && _avatar == null) {
        _avatar = await widget.repository
            .uploadAvatar(_request, _image!)
            .timeout(const Duration(seconds: 30));
      }
      if (!mounted || !_sameOwner) throw const ProxoLinkFailure('unauthorized');
      var order = 0;
      final submitted = <String, dynamic>{
        'client_request_id': _request,
        'page_kind': _type.key,
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'tt': _tt.text.trim().replaceFirst(RegExp(r'^@'), ''),
        'template_key': _design,
        'template_version': 6,
        'card_language': 'ku',
        'color_theme': 'purple',
        'avatar_path': _avatar,
        'settings': {
          'providers': [
            for (final p in _providers.where((p) => p.pageType == _type.key))
              if (_values[p.key]!.text.trim().isNotEmpty)
                {
                  'provider_key': p.key,
                  'destination_url': _values[p.key]!.text.trim(),
                  'enabled': true,
                  'sort_order': order++,
                },
          ],
        },
      };
      final saved = await widget.repository.save(
        submitted,
        existing: _failedSavedPage,
      );
      if (!mounted || !_sameOwner) return;
      await _returnPage(saved, originRoute);
    } on ProxoLinkFailure catch (e) {
      if (!mounted || !_sameOwner) return;
      if (e.savedCard != null) {
        await _returnPage(e.savedCard!, originRoute);
        return;
      }
      if (e.code == 'idempotency_conflict') {
        // A timed-out request may finish after the reopening lookup. Resolve
        // that same owner/request instead of trapping the user on a retry that
        // can never succeed or creating a duplicate with a new request ID.
        try {
          final rows = await widget.repository.cards();
          if (!mounted || !_sameOwner) return;
          final matches = rows.where(
            (page) =>
                page.clientRequestId == _request &&
                (_owner == null || page.userId == _owner),
          );
          if (matches.isNotEmpty) {
            await _returnPage(matches.first, originRoute);
            return;
          }
        } catch (_) {
          // Keep the existing request for a later safe reconciliation.
        }
        if (!mounted || !_sameOwner) return;
      }
      // Every failure releases editing. Corrections keep the original request
      // ID: a late committed request is reconciled, never duplicated.
      _notice('save', e.message);
    } catch (e) {
      if (mounted && _sameOwner) _notice('save', _failure(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_auth?.cancel());
    _name.dispose();
    _bio.dispose();
    _tt.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    _notices.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    int? limit,
    TextInputType? keyboard,
  }) => ProxoDirectionalInput(
    controller: controller,
    keyboardType: keyboard,
    builder: (context, direction) => TextFormField(
      controller: controller,
      readOnly: _busy || !_sameOwner,
      textDirection: direction,
      decoration: InputDecoration(labelText: ProxoStrings.text(label)),
      minLines: lines,
      maxLines: lines == 1 ? 1 : 6,
      maxLength: limit,
      keyboardType: keyboard,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final originRoute = ModalRoute.of(context);
    // A dialog or another pushed screen can cover this route while a save
    // finishes. Return its result only after this specific route is current.
    if (_completedPage != null &&
        !_returningPage &&
        _sameOwner &&
        originRoute?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _completedPage != null)
          unawaited(_returnPage(_completedPage!, originRoute));
      });
    }
    return Theme(
      data: AdUi.theme(context),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: const Color(0xFFF8FAFD),
            body: Column(
              children: [
                ReceiptAppBar(
                  translateTitle: true,
                  title: 'دروستکردنی پەڕە',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _loadFailure != null
                                ? _loadError()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FormHelpActions(
                                        helpKey: 'page_creation',
                                        exampleAsset: ProxoLinkDesign.thumbnail(
                                          _design,
                                          _type,
                                        ),
                                        exampleCaption: 'نمونەی پەڕەکە؛ ناو و وێنە و بەستەرەکانی خۆت دابنێ',
                                      ),
                                      const SizedBox(height: 12),
                                      if (_loading)
                                        const LinearProgressIndicator(
                                          minHeight: 2,
                                        ),
                                      AbsorbPointer(
                                        absorbing:
                                            _loading || _busy || !_sameOwner,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            AdFormSection(
                                              title: 'جۆری پەڕە',
                                              child: Column(
                                                children: [
                                                  for (final type
                                                      in ProxoPageType.values.where(
                                                        (type) =>
                                                            (!widget.lockType &&
                                                                _failedSavedPage ==
                                                                    null) ||
                                                            type == _type,
                                                      ))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      child: SizedBox(
                                                        width: double.infinity,
                                                        child: AdChoice(
                                                          key: ValueKey(
                                                            'create-type-${type.key}',
                                                          ),
                                                          label: type.label,
                                                          selected:
                                                              _type == type,
                                                          onTap: () =>
                                                              setState(() {
                                                                _type = type;
                                                              }),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AdUi.sectionGap,
                                            ),
                                            AdFormSection(
                                              title: 'زانیاری سەرەکی',
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: _picking
                                                        ? null
                                                        : _pickImage,
                                                    icon: ProxoSymbol(
                                                      _image == null
                                                          ? ProxoSymbolName
                                                                .gallery
                                                          : ProxoSymbolName
                                                                .check,
                                                      size: 22,
                                                      color: AdUi.blue,
                                                    ),
                                                    label: ProxoText(
                                                      _type.imageLabel,
                                                    ),
                                                  ),
                                                  if (_image != null) ...[
                                                    const SizedBox(height: 12),
                                                    Center(
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            AdUi.controlRadius,
                                                        child: Image.memory(
                                                          _image!,
                                                          width: 80,
                                                          height: 80,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 16),
                                                  _field(
                                                    _name,
                                                    _type.nameLabel,
                                                    limit: 160,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  _field(
                                                    _bio,
                                                    'کورتە باس',
                                                    lines: 3,
                                                    limit: 2000,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  _field(
                                                    _tt,
                                                    'ناوی تیک تۆک',
                                                    limit: 40,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AdUi.sectionGap,
                                            ),
                                            AdFormSection(
                                              title: 'پەیوەندی و دووگمەکان',
                                              child: Column(
                                                children: [
                                                  for (final p
                                                      in _providers.where(
                                                        (p) =>
                                                            p.pageType ==
                                                            _type.key,
                                                      ))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 16,
                                                          ),
                                                      child: _field(
                                                        _values[p.key]!,
                                                        p.label,
                                                        keyboard:
                                                            p.inputKind ==
                                                                'phone'
                                                            ? TextInputType
                                                                  .phone
                                                            : p.inputKind ==
                                                                  'url'
                                                            ? TextInputType.url
                                                            : TextInputType
                                                                  .text,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AdUi.sectionGap,
                                            ),
                                            AdFormSection(
                                              title: 'ستایلی پەڕە',
                                              child: ProxoLinkDesignSelector(
                                                templates: _templates,
                                                pageType: _type,
                                                selectedKey: _design,
                                                onSelected: (t) => setState(
                                                  () => _design = t.key,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      FilledButton(
                                        key: const ValueKey(
                                          'create-page-submit',
                                        ),
                                        onPressed:
                                            _busy ||
                                                _loading ||
                                                !_sameOwner ||
                                                _templates.isEmpty
                                            ? null
                                            : _save,
                                        child: _busy
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const ProxoText(
                                                'پەڕە دروستبکە',
                                                translate: true,
                                              ),
                                      ),
                                      if (_templates.isEmpty && !_loading)
                                        TextButton(
                                          onPressed: _load,
                                          child: const ProxoText(
                                            'دووبارە هەوڵ بدەرەوە',
                                            translate: true,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: ProxoSurface.gutter,
                        right: ProxoSurface.gutter,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: AdValidationNotifications(
                              controller: _notices,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadError() => ProxoEmptyState(
    key: const ValueKey('create-page-load-error'),
    symbol: ProxoSymbolName.info,
    title: 'نەتوانرا پەڕە ئامادە بکرێت',
    body: _loadFailure!,
    isError: true,
    action: OutlinedButton(
      onPressed: _loading ? null : _load,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(ProxoSurface.actionHeight),
        textStyle: ProxoSurface.body,
      ),
      child: const ProxoText('دووبارە هەوڵ بدەرەوە', translate: true),
    ),
  );
}
