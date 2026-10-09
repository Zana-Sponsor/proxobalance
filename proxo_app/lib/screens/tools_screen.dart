import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/proxolink_pages_controller.dart';
import '../models/proxo_card.dart';
import '../models/proxolink_page_type.dart';
import '../services/proxolink_service.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/ad_validation_notifications.dart';
import '../widgets/proxo_refresh.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxolink_page_card.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'proxolink_create_page_screen.dart';

class ToolsScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onUseForAd;
  final bool initialCreate, isActive;
  final ProxoLinkRepository? repository;
  final ProxoRefreshController? refreshController;
  final Future<bool> Function(Uri)? externalLauncher;
  const ToolsScreen({super.key, this.onUseForAd, this.initialCreate = false,
    this.isActive = true, this.repository, this.refreshController, this.externalLauncher});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}
class _ToolsScreenState extends State<ToolsScreen> {
  late final ProxoLinkRepository _repository;
  late final ProxoLinkPagesController _pages;
  final _notices = AdValidationController();
  final _scroll = ScrollController();
  final _localRefresh = ProxoRefreshController();
  final _launching = <String>{};
  final _confirming = <String>{};
  bool _creating = false;
  ProxoLinkFailure? _announced;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProxoLinkService(Supabase.instance.client);
    _pages = ProxoLinkPagesController(_repository)..addListener(_changed);
    unawaited(_pages.refresh());
    if (widget.initialCreate) WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_create());
    });
  }
  void _changed() {
    if (!mounted) return;
    if (_pages.error != null && !identical(_announced, _pages.error)) {
      _announced = _pages.error; _notices.show({'load': _pages.error!.message});
    }
    setState(() {});
  }
  Future<void> _create() async {
    if (_creating) return;
    _creating = true;
    final owner = _repository.ownerScope;
    ProxoCard? saved;
    try {
      saved = await Navigator.of(context).push<ProxoCard>(MaterialPageRoute(
        builder: (_) => ProxoLinkCreatePageScreen(repository: _repository)));
    } finally { _creating = false; }
    if (!mounted || saved == null || owner != _repository.ownerScope) return;
    _pages.upsert(saved);
    if (saved.publishStatus == 'failed') _notices.show({'create': const ProxoLinkFailure('publish_failed').message});
    if (widget.onUseForAd != null && saved.available) widget.onUseForAd!(saved.toJson());
  }
  Future<void> _preview(ProxoCard page) async {
    if (!_launching.add(page.id)) return;
    final owner = _repository.ownerScope;
    try {
      final uri = _repository.publicUrl(page.id, pageType: page.pageType.key);
      if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.path != page.publicPath || uri.hasQuery || uri.hasFragment) {
        throw const ProxoLinkFailure('invalid_request');
      }
      final opened = await (widget.externalLauncher?.call(uri) ?? launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened) throw const ProxoLinkFailure('browser_launch_failed');
    } catch (e) {
      if (mounted && owner == _repository.ownerScope) _notices.show({'browser':
        (e is ProxoLinkFailure ? e : const ProxoLinkFailure('browser_launch_failed')).message});
    } finally { _launching.remove(page.id); }
  }
  Future<void> _delete(ProxoCard page) async {
    if (_pages.busy.contains(page.id) || !_confirming.add(page.id)) return;
    final owner = _repository.ownerScope;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(context: context, builder: (context) => Directionality(
      textDirection: TextDirection.rtl, child: AlertDialog(
        title: const ProxoText('سڕینەوەی پەڕە'),
        content: ProxoText(page.name),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const ProxoText('پاشگەزبوونەوە')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const ProxoText('سڕینەوە'))])));
    } finally { _confirming.remove(page.id); }
    if (!mounted || confirmed != true || owner != _repository.ownerScope) return;
    try { await _pages.manage(page, 'delete'); }
    catch (e) { if (mounted && owner == _repository.ownerScope) _notices.show({'delete':
      (e is ProxoLinkFailure ? e : const ProxoLinkFailure('network_error')).message}); }
  }
  @override
  void dispose() {
    _pages.removeListener(_changed); _pages.dispose(); _scroll.dispose();
    _notices.dispose(); _localRefresh.dispose(); super.dispose();
  }
  Widget _createButton() => FilledButton(onPressed: _create, child: const ProxoText('پەڕە دروستبکە'));
  @override
  Widget build(BuildContext context) => Theme(data: AdUi.theme(context), child: Directionality(
    textDirection: TextDirection.rtl, child: Builder(builder: (context) => Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Column(children: [
        ReceiptAppBar(title: 'ئامرازەکان', onBack: Navigator.of(context).canPop() ? () => Navigator.of(context).maybePop() : null),
        Expanded(child: Stack(children: [
          ProxoRefresh(controller: widget.refreshController ?? _localRefresh,
            scrollController: _scroll, pullToRefresh: true, onRefresh: _pages.refresh,
            child: ListView.builder(key: const PageStorageKey('tools-owner-pages'), controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              itemCount: _pages.pages.isEmpty ? (_pages.loading ? 4 : 2) : _pages.pages.length + 1,
              findChildIndexCallback: (key) {
                if (key == const ValueKey('tools-primary')) return 0;
                if (key is ValueKey<String>) {
                  final index = _pages.pages.indexWhere((p) => 'tools-row-${p.id}' == key.value);
                  if (index >= 0) return index + 1;
                }
                return null;
              },
              itemBuilder: (context, index) => Align(
                key: index == 0 ? const ValueKey('tools-primary') : _pages.pages.isEmpty
                  ? ValueKey('tools-placeholder-$index') : ValueKey('tools-row-${_pages.pages[index-1].id}'),
                alignment: Alignment.topCenter,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(padding: const EdgeInsets.only(bottom: 16), child: _item(context, index)))))),
          Positioned(top: 12, left: 16, right: 16, child: AdValidationNotifications(controller: _notices)),
        ])),
      ]),
    ))));
  Widget _item(BuildContext context, int index) {
    if (index == 0) return _createButton();
    if (_pages.pages.isEmpty) {
      if (_pages.loading) return const ProxoLinkPageSkeleton();
      return Padding(padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 12), child: Column(children: [
        Icon(_pages.error == null ? Icons.article_outlined : Icons.cloud_off_outlined, size: 40, color: AdUi.secondary),
        const SizedBox(height: 20),
        ProxoText(_pages.error == null ? 'هێشتا هیچ پەڕەیەکت دروست نەکردووە' : 'نەتوانرا پەڕەکان بار بکرێن',
          textAlign: TextAlign.center, style: AdUi.heading(context)),
        const SizedBox(height: 10),
        if (_pages.error == null) const ProxoText('پەڕەیەک دروستبکە و بەستەرەکەت بەکاربهێنە.', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        if (_pages.error != null) OutlinedButton(onPressed: () => (widget.refreshController ?? _localRefresh).refresh(),
          child: const ProxoText('دووبارە هەوڵ بدەرەوە')),
      ]));
    }
    final page = _pages.pages[index - 1];
    return ProxoArrival(key: ValueKey('proxolink-page-${page.id}'), index: index - 1,
      animateOnRefresh: _pages.changedIds.contains(page.id),
      child: ProxoLinkPageCard(page: page, busy: _pages.busy.contains(page.id),
        onPreview: () => _preview(page), onDelete: () => _delete(page)));
  }
}
