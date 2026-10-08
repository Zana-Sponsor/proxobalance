import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/proxolink_pages_controller.dart';
import '../models/proxo_card.dart';
import '../models/proxolink_page_type.dart';
import '../services/proxolink_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxolink_page_card.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'ad_create_screen.dart';
import 'card_webview_screen.dart';
import 'proxolink_page_details_screen.dart';
import 'proxolink_page_editor.dart';
import 'proxolink_page_editor_screen.dart';

/// Canonical My Pages entry point, retaining the existing ad-picker/native API.
class ToolsScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onUseForAd;
  final bool initialCreate;
  final bool isActive;
  final ProxoLinkRepository? repository;
  const ToolsScreen({
    super.key,
    this.onUseForAd,
    this.initialCreate = false,
    this.isActive = true,
    this.repository,
  });
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late final ProxoLinkRepository _repository;
  late final ProxoLinkPagesController _pages;
  final _editor = GlobalKey<ProxoLinkPageEditorState>();
  bool _initialForm = false;
  ProxoCard? _created;
  ProxoCard get _latestCreated =>
      _pages.pages.firstWhere((p) => p.id == _created!.id);
  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ProxoLinkService(Supabase.instance.client);
    _pages = ProxoLinkPagesController(_repository);
    _initialForm = widget.initialCreate;
    unawaited(_pages.refresh());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ToolsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) unawaited(_pages.refresh());
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: ProxoText(text)));
  }

  Future<void> _back() async {
    if (_initialForm) {
      if (!await (_editor.currentState?.requestClose() ?? Future.value(true)) ||
          !mounted)
        return;
      setState(() => _initialForm = false);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _saved(ProxoCard? card) async {
    if (!mounted) return;
    if (card != null) {
      _pages.upsert(card);
      if (card.available && widget.initialCreate && widget.onUseForAd != null) {
        widget.onUseForAd!(card.toJson());
        return;
      }
    } else {
      unawaited(_pages.refresh());
    }
    setState(() {
      _initialForm = false;
      _created = card;
    });
  }

  Future<void> _edit([ProxoCard? page]) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    final saved = await Navigator.push<ProxoCard>(
      context,
      ProxoPageRoute<ProxoCard>(
        settings: RouteSettings(
          name: page == null ? 'proxolink_create' : 'proxolink_edit',
        ),
        builder: (_) =>
            ProxoLinkPageEditorScreen(repository: _repository, existing: page),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      await _saved(saved);
    } else {
      await _pages.refresh();
    }
  }

  Future<void> _open(ProxoCard page) async {
    await Navigator.push<bool>(
      context,
      ProxoPageRoute<bool>(
        settings: const RouteSettings(name: 'proxolink_details'),
        builder: (_) => ProxoLinkPageDetailsScreen(
          initialPage: page,
          repository: _repository,
          onChanged: _pages.upsert,
        ),
      ),
    );
    if (mounted) await _pages.refresh();
  }

  void _public(ProxoCard page) => Navigator.push(
    context,
    ProxoPageRoute<void>(
      builder: (_) => CardWebViewScreen(
        title: page.name,
        loadUrl: () async =>
            _repository.publicUrl(page.id, pageType: page.pageType.key),
      ),
    ),
  );
  void _use(ProxoCard page) {
    if (!page.available) return;
    if (widget.onUseForAd != null) {
      widget.onUseForAd!(page.toJson());
      return;
    }
    Navigator.push(
      context,
      ProxoPageRoute<void>(
        builder: (_) => AdCreateScreen(proxoCard: page.toJson()),
      ),
    );
  }

  Future<void> _action(ProxoCard page, String action) async {
    if (_pages.busy.contains(page.id)) return;
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
    try {
      await _pages.manage(page, action);
    } on ProxoLinkFailure catch (e) {
      _message(e.message);
      if (e.code == 'edit_conflict') await _pages.refresh();
    } catch (_) {
      _message(const ProxoLinkFailure('network_error').message);
    }
  }

  Future<void> _more(ProxoCard page) async {
    final choices = <String, String>{
      'details': 'بەڕێوەبردن',
      'edit': 'دەستکاریکردن',
      'copy': 'کۆپی لینک',
      if (page.available) 'share': 'هاوبەشکردن',
      if (page.publishStatus == 'ready')
        (page.available ? 'deactivate' : 'activate'): (page.available
            ? 'ناچالاککردن'
            : 'چالاککردن'),
      'delete': page.pageKind == null ? 'سڕینەوە' : 'ئەرشیفکردن',
    };
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in choices.entries)
                ListTile(
                  title: ProxoText(item.value),
                  onTap: () => Navigator.pop(context, item.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'details') {
      await _open(page);
      return;
    }
    if (choice == 'edit') {
      await _edit(page);
      return;
    }
    if (choice == 'copy') {
      await Clipboard.setData(
        ClipboardData(
          text: _repository
              .publicUrl(page.id, pageType: page.pageType.key)
              .toString(),
        ),
      );
      _message('بەستەرەکە کۆپی کرا');
      return;
    }
    if (choice == 'share') {
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        '${page.name}\n${_repository.publicUrl(page.id, pageType: page.pageType.key)}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
      return;
    }
    await _action(page, choice);
  }

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const ProxoText('پەڕەی نوێ'),
      ),
      if (_created != null &&
          _pages.pages.any((p) => p.id == _created!.id)) ...[
        const SizedBox(height: 16),
        AdFormSection(
          title: 'پەڕەکە پاشەکەوت کرا',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _open(_latestCreated),
                child: const ProxoText('زانیاری پەڕە'),
              ),
              OutlinedButton(
                onPressed: () => _edit(_latestCreated),
                child: const ProxoText('دەستکاری پەڕە'),
              ),
            ],
          ),
        ),
      ],
      if (_pages.loading && _pages.pages.isNotEmpty)
        const LinearProgressIndicator(),
      if (_pages.error != null) ...[
        const SizedBox(height: 16),
        AdFormSection(
          title: _pages.error!.message,
          child: OutlinedButton(
            onPressed: _pages.refresh,
            child: const ProxoText('دووبارە هەوڵبدەرەوە'),
          ),
        ),
      ] else if (!_pages.loading && _pages.pages.isEmpty) ...[
        const SizedBox(height: 16),
        const AdFormSection(
          title: 'پەڕەیەکت نییە',
          child: ProxoText(
            'پەڕەی پەیوەندی، ڕێستۆرانت یان داگرتنی ئەپ دروست بکە.',
          ),
        ),
      ],
    ],
  );
  Widget _list() => ListenableBuilder(
    listenable: _pages,
    builder: (context, _) => RefreshIndicator(
      onRefresh: _pages.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        itemCount:
            1 +
            (_pages.loading && _pages.pages.isEmpty ? 3 : _pages.pages.length),
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AdUi.sectionGap),
              child: index == 0
                  ? _header()
                  : _pages.loading && _pages.pages.isEmpty
                  ? const ProxoLinkPageSkeleton()
                  : _row(_pages.pages[index - 1]),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _row(ProxoCard page) => ProxoLinkPageCard(
    key: ValueKey('proxolink-page-${page.id}'),
    page: page,
    repository: _repository,
    busy: _pages.busy.contains(page.id),
    onOpen: () => _open(page),
    onMore: () => _more(page),
    onPublic: () => _public(page),
    onUse: () => _use(page),
    onRetry: () => _action(page, 'retry'),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: AdUi.theme(context),
    child: PopScope<Object?>(
      canPop: !_initialForm,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              ReceiptAppBar(
                title: _initialForm ? 'دروستکردنی پەڕە' : 'پەڕەکانم',
                onBack: _back,
              ),
              Expanded(
                child: _initialForm
                    ? ProxoLinkPageEditor(
                        key: _editor,
                        repository: _repository,
                        onSaved: _saved,
                      )
                    : _list(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
