import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/proxo_card.dart';
import '../models/proxolink_design.dart';
import '../models/proxolink_page_type.dart';
import '../services/proxolink_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxolink_page_card.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'card_webview_screen.dart';
import 'proxolink_page_editor_screen.dart';

class ProxoLinkPageDetailsScreen extends StatefulWidget {
  final ProxoCard initialPage;
  final ProxoLinkRepository repository;
  final ValueChanged<ProxoCard>? onChanged;
  const ProxoLinkPageDetailsScreen({
    super.key,
    required this.initialPage,
    required this.repository,
    this.onChanged,
  });
  @override
  State<ProxoLinkPageDetailsScreen> createState() =>
      _ProxoLinkPageDetailsScreenState();
}

class _ProxoLinkPageDetailsScreenState
    extends State<ProxoLinkPageDetailsScreen> {
  ProxoCard? _page;
  ProxoLinkFailure? _error;
  bool _loading = true, _busy = false;
  int _request = 0;
  StreamSubscription<AuthState>? _auth;
  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    var scope = widget.repository.ownerScope;
    if (widget.repository is ProxoLinkService) {
      _auth = (widget.repository as ProxoLinkService).db.auth.onAuthStateChange
          .listen((_) {
            if (scope == widget.repository.ownerScope) return;
            scope = widget.repository.ownerScope;
            ++_request;
            if (mounted)
              setState(() {
                _page = null;
                _error = const ProxoLinkFailure('unauthorized');
                _loading = false;
              });
          });
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    ++_request;
    unawaited(_auth?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request, owner = widget.repository.ownerScope;
    try {
      final page = await widget.repository.card(widget.initialPage.id);
      if (!mounted || request != _request) return;
      if (owner != widget.repository.ownerScope ||
          (owner != null && page?.userId != owner)) {
        throw const ProxoLinkFailure('unauthorized');
      }
      setState(() {
        _page = page;
        _error = page == null ? const ProxoLinkFailure('not_found') : null;
        _loading = false;
      });
      if (page != null) widget.onChanged?.call(page);
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = e is ProxoLinkFailure
            ? e
            : const ProxoLinkFailure('network_error');
      });
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: ProxoText(text)));
  Future<void> _edit() async {
    if (_page == null || _busy || _loading || _error != null) return;
    final saved = await Navigator.push<ProxoCard>(
      context,
      ProxoPageRoute<ProxoCard>(
        settings: const RouteSettings(name: 'proxolink_edit'),
        builder: (_) => ProxoLinkPageEditorScreen(
          repository: widget.repository,
          existing: _page,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _page = saved;
        _error = null;
      });
      widget.onChanged?.call(saved);
    } else {
      await _load();
    }
  }

  Future<void> _action(String action) async {
    final page = _page;
    if (page == null || _busy || _loading || _error != null) return;
    if (action == 'delete' || action == 'deactivate') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: ProxoText(
            action == 'delete' ? 'ئەرشیفکردنی پەڕە' : 'ناچالاککردنی پەڕە',
          ),
          content: const ProxoText(
            'بەستەری گشتی بەردەست نابێت. پەڕەی بەکارهاتوو لە ڕیکلامدا پارێزراوە.',
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
    setState(() => _busy = true);
    try {
      await widget.repository.manage(page, action);
      if (!mounted) return;
      if (action == 'delete') {
        Navigator.pop(context, true);
        return;
      }
      await _load();
    } on ProxoLinkFailure catch (e) {
      if (mounted) {
        _message(e.message);
        if (e.code == 'edit_conflict') await _load();
      }
    } catch (_) {
      if (mounted) _message(const ProxoLinkFailure('network_error').message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _preview({bool public = false}) {
    final page = _page!;
    Navigator.push(
      context,
      ProxoPageRoute<void>(
        builder: (_) => CardWebViewScreen(
          title: page.name,
          allowContactActions: public,
          loadUrl: public
              ? () async => widget.repository.publicUrl(
                  page.id,
                  pageType: page.pageType.key,
                )
              : () => widget.repository.preview(page.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _page, enabled = !_busy && !_loading && _error == null;
    return Theme(
      data: AdUi.theme(context),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              ReceiptAppBar(
                title: 'زانیاری و بەڕێوەبردنی پەڕە',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_loading) const LinearProgressIndicator(),
                              if (_error != null)
                                AdFormSection(
                                  title: _error!.message,
                                  child: OutlinedButton(
                                    onPressed: _load,
                                    child: const ProxoText(
                                      'دووبارە هەوڵبدەرەوە',
                                    ),
                                  ),
                                ),
                              if (page != null) ...[
                                AdFormSection(
                                  title: page.name,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        child: ProxoLinkPageImage(
                                          page: page,
                                          repository: widget.repository,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ProxoText(page.pageType.label),
                                      ProxoText(
                                        ProxoLinkDesign.label(page.templateKey),
                                      ),
                                      ProxoText(page.stateLabel),
                                      if (page.bio.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child: ProxoText(page.bio),
                                        ),
                                      const SizedBox(height: 12),
                                      ProxoText(
                                        'دروستکراو: ${pageDate(page.createdAt)}',
                                      ),
                                      ProxoText(
                                        'نوێکراوە: ${pageDate(page.updatedAt)}',
                                      ),
                                      const SizedBox(height: 12),
                                      const ProxoText('ئایدی پەڕە'),
                                      SelectableText(
                                        page.id,
                                        textDirection: TextDirection.ltr,
                                      ),
                                      const SizedBox(height: 12),
                                      const ProxoText('بەستەری هەمیشەیی'),
                                      SelectableText(
                                        widget.repository
                                            .publicUrl(
                                              page.id,
                                              pageType: page.pageType.key,
                                            )
                                            .toString(),
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AdUi.sectionGap),
                                AdFormSection(
                                  title: 'بەڕێوەبردن',
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: enabled ? _edit : null,
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const ProxoText('دەستکاریکردن'),
                                      ),
                                      if (page.canPreview)
                                        OutlinedButton(
                                          onPressed: enabled
                                              ? () => _preview()
                                              : null,
                                          child: const ProxoText(
                                            'پێشبینینی تەواو',
                                          ),
                                        ),
                                      if (page.available)
                                        OutlinedButton(
                                          onPressed: enabled
                                              ? () => _preview(public: true)
                                              : null,
                                          child: const ProxoText(
                                            'کردنەوەی پەڕە',
                                          ),
                                        ),
                                      OutlinedButton(
                                        onPressed: enabled
                                            ? () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: widget.repository
                                                        .publicUrl(
                                                          page.id,
                                                          pageType:
                                                              page.pageType.key,
                                                        )
                                                        .toString(),
                                                  ),
                                                );
                                                if (mounted)
                                                  _message(
                                                    'بەستەرەکە کۆپی کرا',
                                                  );
                                              }
                                            : null,
                                        child: const ProxoText('کۆپی لینک'),
                                      ),
                                      if (page.publishStatus == 'ready')
                                        OutlinedButton(
                                          onPressed: enabled
                                              ? () => _action(
                                                  page.available
                                                      ? 'deactivate'
                                                      : 'activate',
                                                )
                                              : null,
                                          child: ProxoText(
                                            page.available
                                                ? 'ناچالاککردن'
                                                : 'چالاککردن',
                                          ),
                                        ),
                                      if (page.canRetry)
                                        OutlinedButton(
                                          onPressed: enabled
                                              ? () => _action('retry')
                                              : null,
                                          child: const ProxoText(
                                            'دووبارە دروستکردنەوە',
                                          ),
                                        ),
                                      OutlinedButton(
                                        onPressed: enabled
                                            ? () => _action('delete')
                                            : null,
                                        child: const ProxoText('ئەرشیفکردن'),
                                      ),
                                      if (_busy)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
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
    );
  }
}
