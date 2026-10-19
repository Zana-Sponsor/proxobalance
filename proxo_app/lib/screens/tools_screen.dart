import 'package:proxo_app/theme/app_theme.dart';
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
import '../widgets/proxo_symbol.dart';
import '../widgets/proxolink_page_card.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'proxolink_create_page_screen.dart';

class ToolsScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onUseForAd;
  final bool initialCreate, isActive;
  final ProxoLinkRepository? repository;
  final ProxoRefreshController? refreshController;
  final Future<bool> Function(Uri)? externalLauncher;
  const ToolsScreen(
      {super.key,
      this.onUseForAd,
      this.initialCreate = false,
      this.isActive = true,
      this.repository,
      this.refreshController,
      this.externalLauncher});
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
    _repository =
        widget.repository ?? ProxoLinkService(Supabase.instance.client);
    _pages = ProxoLinkPagesController(_repository)..addListener(_changed);
    unawaited(_pages.refresh());
    if (widget.initialCreate)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_create());
      });
  }

  void _changed() {
    if (!mounted) return;
    // A new request clears error. Allow its failure to be announced even when
    // the repository reuses the same const failure object as the last request.
    if (_pages.error == null) _announced = null;
    if (_pages.error != null && !identical(_announced, _pages.error)) {
      _announced = _pages.error;
      _notices.show({'load': _pages.error!.message});
    }
    setState(() {});
  }

  Future<void> _create() async {
    if (_creating) return;
    _creating = true;
    final owner = _repository.ownerScope;
    ProxoCard? saved;
    try {
      saved = await Navigator.of(context).push<ProxoCard>(ProxoPageRoute(
          settings: const RouteSettings(name: 'create_page'),
          builder: (_) => ProxoLinkCreatePageScreen(repository: _repository)));
    } finally {
      _creating = false;
    }
    if (!mounted || saved == null || owner != _repository.ownerScope) return;
    _pages.upsert(saved);
    if (saved.publishStatus == 'failed')
      _notices
          .show({'create': const ProxoLinkFailure('publish_failed').message});
    if (widget.onUseForAd != null && saved.available)
      widget.onUseForAd!(saved.toJson());
  }

  Future<void> _preview(ProxoCard page) async {
    if (!_launching.add(page.id)) return;
    final owner = _repository.ownerScope;
    try {
      final uri = _repository.publicUrl(page.id, pageType: page.pageType.key);
      if (uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.path != page.publicPath ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const ProxoLinkFailure('invalid_request');
      }
      final opened = await (widget.externalLauncher?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened) throw const ProxoLinkFailure('browser_launch_failed');
    } catch (e) {
      if (mounted && owner == _repository.ownerScope)
        _notices.show({
          'browser': (e is ProxoLinkFailure
                  ? e
                  : const ProxoLinkFailure('browser_launch_failed'))
              .message
        });
    } finally {
      _launching.remove(page.id);
    }
  }

  Future<void> _delete(ProxoCard page) async {
    if (_pages.busy.contains(page.id) || !_confirming.add(page.id)) return;
    final owner = _repository.ownerScope;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                  title: const ProxoText('سڕینەوەی پەڕە', translate: true),
                  content: ProxoText(page.name),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child:
                            const ProxoText('پاشگەزبوونەوە', translate: true)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const ProxoText('سڕینەوە', translate: true))
                  ])));
    } finally {
      _confirming.remove(page.id);
    }
    if (!mounted || confirmed != true || owner != _repository.ownerScope)
      return;
    try {
      await _pages.manage(page, 'delete');
    } catch (e) {
      if (mounted && owner == _repository.ownerScope)
        _notices.show({
          'delete': (e is ProxoLinkFailure
                  ? e
                  : const ProxoLinkFailure('network_error'))
              .message
        });
    }
  }

  @override
  void dispose() {
    _pages.removeListener(_changed);
    _pages.dispose();
    _scroll.dispose();
    _notices.dispose();
    _localRefresh.dispose();
    super.dispose();
  }

  Widget _createButton() => FilledButton.icon(
      key: const ValueKey('tools-create-page'),
      onPressed: _create,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon:
          const ProxoSymbol(ProxoSymbolName.add, size: 20, color: Colors.white),
      label: const ProxoText('پەڕە دروستبکە', translate: true));
  @override
  Widget build(BuildContext context) => Theme(
      data: AdUi.theme(context),
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
              builder: (context) => Scaffold(
                    backgroundColor: const Color(0xFFF8FAFD),
                    body: Column(children: [
                      ReceiptAppBar(
                          translateTitle: true,
                          title: 'ئامرازەکان',
                          onBack: Navigator.of(context).canPop()
                              ? () => Navigator.of(context).maybePop()
                              : null),
                      Expanded(
                          child: Stack(children: [
                        ProxoRefresh(
                            controller:
                                widget.refreshController ?? _localRefresh,
                            scrollController: _scroll,
                            pullToRefresh: true,
                            onRefresh: _pages.refresh,
                            child: ListView.builder(
                                key: const PageStorageKey('tools-owner-pages'),
                                controller: _scroll,
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 24, 20, 32),
                                itemCount: _pages.pages.isEmpty
                                    ? (_pages.loading ? 4 : 1)
                                    : _pages.pages.length + 1,
                                findChildIndexCallback: (key) {
                                  if (key == const ValueKey('tools-primary'))
                                    return 0;
                                  if (key is ValueKey<String>) {
                                    final index = _pages.pages.indexWhere((p) =>
                                        'tools-row-${p.id}' == key.value);
                                    if (index >= 0) return index + 1;
                                  }
                                  return null;
                                },
                                itemBuilder: (context, index) => Align(
                                    key: index == 0
                                        ? const ValueKey('tools-primary')
                                        : _pages.pages.isEmpty
                                            ? ValueKey(
                                                'tools-placeholder-$index')
                                            : ValueKey(
                                                'tools-row-${_pages.pages[index - 1].id}'),
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 600),
                                        child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: _item(context, index)))))),
                        Positioned(
                            top: 12,
                            left: 16,
                            right: 16,
                            child: AdValidationNotifications(
                                controller: _notices)),
                      ])),
                    ]),
                  ))));
  Widget _item(BuildContext context, int index) {
    if (_pages.pages.isEmpty) {
      if (_pages.loading)
        return index == 0 ? _createButton() : const ProxoLinkPageSkeleton();
      return _emptyState(context);
    }
    if (index == 0) return _createButton();
    final page = _pages.pages[index - 1];
    return ProxoArrival(
        key: ValueKey('proxolink-page-${page.id}'),
        index: index - 1,
        animateOnRefresh: _pages.changedIds.contains(page.id),
        child: ProxoLinkPageCard(
            page: page,
            busy: _pages.busy.contains(page.id),
            onPreview: () => _preview(page),
            onDelete: () => _delete(page)));
  }

  Widget _emptyState(BuildContext context) {
    final failed = _pages.error != null;
    return Container(
      key: ValueKey(failed ? 'tools-error-state' : 'tools-empty-state'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdUi.controlLine),
        boxShadow: AdUi.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
            child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF4FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCE9FC)),
          ),
          child: ProxoSymbol(
              failed ? ProxoSymbolName.warning : ProxoSymbolName.tools,
              size: 32,
              color: AdUi.blue),
        )),
        const SizedBox(height: 24),
        ProxoText(
            failed
                ? 'نەتوانرا پەڕەکان بار بکرێن'
                : 'هێشتا هیچ پەڕەیەکت دروست نەکردووە',
            translate: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, height: 1.5, color: AdUi.ink)),
        const SizedBox(height: 12),
        ProxoText(
            failed
                ? _pages.error!.message
                : 'پەڕەیەک دروستبکە و بەستەرەکەت بەکاربهێنە.',
            translate: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, height: 1.65, color: AdUi.secondary)),
        if (!failed) ...[
          const SizedBox(height: 24),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ProxoPageType.values)
                  DecoratedBox(
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F8FC),
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: ProxoText(type.label,
                              translate: true,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AdUi.secondary))))
              ]),
        ],
        const SizedBox(height: 28),
        if (failed)
          OutlinedButton(
              key: const ValueKey('tools-retry-pages'),
              onPressed: () =>
                  (widget.refreshController ?? _localRefresh).refresh(),
              child: const ProxoText('دووبارە هەوڵ بدەرەوە', translate: true))
        else
          _createButton(),
      ]),
    );
  }
}
