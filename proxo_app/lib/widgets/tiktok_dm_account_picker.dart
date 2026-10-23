import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr/qr.dart' as qr;
import 'package:shimmer/shimmer.dart';

import '../services/tiktok_dm_accounts.dart';
import 'ad_brand_logo.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';
import 'tiktok_qr_tutorial.dart';

/// Cached metadata is scoped to the signed-in owner AND connected account.
/// It accelerates paint only; selection is disabled until a fresh server read.
final _accountCache = <String, (DateTime, TikTokDmAccounts)>{};
final _videoCache = <String, (DateTime, TikTokDmVideoPage)>{};
final _lastAccountByOwner = <String, String>{};
void clearTikTokDmCache(String ownerId, {String? accountId}) {
  _accountCache.remove(ownerId);
  if (accountId == null || _lastAccountByOwner[ownerId] == accountId) {
    _lastAccountByOwner.remove(ownerId);
  }
  _videoCache.removeWhere((key, _) => accountId == null
      ? key.startsWith('$ownerId:')
      : key == '$ownerId:$accountId');
}

class TikTokDmAccountPicker extends StatefulWidget {
  final TikTokDmRepository repository;
  final ValueChanged<TikTokDmSelection?> onChanged;
  final TikTokDmSelection? initialSelection;
  final String? selectedAccountId, selectedItemId;
  final bool enabled;
  const TikTokDmAccountPicker(
      {super.key,
      required this.repository,
      required this.onChanged,
      this.initialSelection,
      this.selectedAccountId,
      this.selectedItemId,
      this.enabled = true});
  @override
  State<TikTokDmAccountPicker> createState() => _TikTokDmAccountPickerState();
}

class _TikTokDmAccountPickerState extends State<TikTokDmAccountPicker>
    with WidgetsBindingObserver {
  List<TikTokDmAccount> _accounts = const [];
  List<TikTokDmVideo> _videos = const [];
  String? _accountId, _selectedItem, _nextCursor;
  TikTokDmConnection? _pending;
  TikTokDmFailure? _accountsError, _videosError;
  bool _accountsLoading = false,
      _videosLoading = false,
      _fresh = false,
      _offline = false,
      _connecting = false,
      _browsing = false,
      _disconnecting = false;
  final _videoUpdates = ValueNotifier<int>(0);
  int _accountRevision = 0, _videoRevision = 0;
  late String _owner;
  Future<void>? _accountRequest;
  Future<void>? _videoRequest;
  StreamSubscription<bool>? _network;
  TikTokDmAccount? get _selectedAccount {
    for (final account in _accounts) {
      if (account.id == _accountId && account.selectable) return account;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _owner = widget.repository.ownerId;
    _listenNetwork();
    _accountId = widget.selectedAccountId ??
        widget.initialSelection?.accountId ??
        _lastAccountByOwner[_owner];
    _selectedItem = widget.selectedItemId ?? widget.initialSelection?.itemId;
    final cached = _accountCache[_owner];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 10)) {
      _accounts = cached.$2.accounts;
    }
    unawaited(_loadAccounts());
  }

  @override
  void didUpdateWidget(covariant TikTokDmAccountPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_owner != widget.repository.ownerId ||
        oldWidget.repository != widget.repository) {
      _accountRevision++;
      _videoRevision++;
      _owner = widget.repository.ownerId;
      _accounts = const [];
      _videos = const [];
      _accountId = _lastAccountByOwner[_owner];
      _selectedItem = null;
      _fresh = false;
      _offline = false;
      _accountRequest = null;
      _videoRequest = null;
      unawaited(_network?.cancel());
      _listenNetwork();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onChanged(null);
        unawaited(_loadAccounts());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadAccounts());
  }

  @override
  void dispose() {
    _accountRevision++;
    _videoRevision++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_network?.cancel());
    _videoUpdates.dispose();
    super.dispose();
  }

  bool _current(int revision, {bool video = false}) =>
      mounted &&
      _owner == widget.repository.ownerId &&
      revision == (video ? _videoRevision : _accountRevision);
  TikTokDmFailure _failure(Object error) =>
      error is TikTokDmFailure ? error : const TikTokDmFailure('NETWORK');

  void _listenNetwork() {
    _network = widget.repository.offlineChanges.listen((offline) {
      if (!mounted || _owner != widget.repository.ownerId) return;
      _offline = offline;
      if (offline) {
        _videoRevision++;
        _videoRequest = null;
        setState(() {
          _fresh = false;
          _videosLoading = false;
          _videos = const [];
          _selectedItem = null;
          _videosError = const TikTokDmFailure('OFFLINE');
        });
        _videoUpdates.value++;
        widget.onChanged(null);
      } else if (_videosError?.code == 'OFFLINE') {
        unawaited(_loadVideos());
      }
    }, onError: (Object _) {
      /* A plugin error cannot establish offline state. */
    });
  }

  Future<void> _loadAccounts() {
    if (_accountRequest != null) return _accountRequest!;
    final task = _fetchAccounts();
    _accountRequest = task;
    return task.whenComplete(() {
      if (identical(_accountRequest, task)) _accountRequest = null;
    });
  }

  Future<void> _fetchAccounts() async {
    final revision = ++_accountRevision;
    setState(() {
      _accountsLoading = true;
      _accountsError = null;
    });
    try {
      final result = await widget.repository.accounts();
      if (!_current(revision)) return;
      _accountCache[_owner] = (DateTime.now(), result);
      if (_accountCache.length > 16) {
        _accountCache.remove(_accountCache.keys.first);
      }
      final available =
          result.accounts.where((account) => account.selectable).toList();
      var accountId = _accountId;
      if (!available.any((account) => account.id == accountId)) {
        accountId = available.length == 1 ? available.single.id : null;
        _lastAccountByOwner.remove(_owner);
      }
      setState(() {
        _accounts = result.accounts;
        _pending = result.pendingRequest;
        _accountsLoading = false;
      });
      _selectAccount(accountId, keepSelection: accountId == _accountId);
    } catch (error) {
      if (!_current(revision)) return;
      setState(() {
        _accountsLoading = false;
        _accountsError = _failure(error);
        _fresh = false;
        _videos = const [];
      });
      _videoUpdates.value++;
      widget.onChanged(null);
    }
  }

  void _selectAccount(String? accountId, {bool keepSelection = false}) {
    _videoRevision++;
    _videoRequest = null;
    final cached = _videoCache['$_owner:$accountId'];
    setState(() {
      _accountId = accountId;
      if (!keepSelection) _selectedItem = null;
      _videos = !_offline &&
              cached != null &&
              DateTime.now().difference(cached.$1) < const Duration(minutes: 10)
          ? cached.$2.videos
          : const [];
      _nextCursor = null;
      _fresh = false;
      _videosLoading = false;
      _videosError = _offline ? const TikTokDmFailure('OFFLINE') : null;
    });
    if (_selectedAccount != null) {
      _lastAccountByOwner[_owner] = accountId!;
      if (_lastAccountByOwner.length > 16) {
        _lastAccountByOwner.remove(_lastAccountByOwner.keys.first);
      }
    }
    _videoUpdates.value++;
    widget.onChanged(null);
    if (_selectedAccount != null && !_offline) unawaited(_loadVideos());
  }

  Future<void> _loadVideos({bool more = false}) {
    if (_videoRequest != null) return _videoRequest!;
    if (_offline || _selectedAccount == null || more && _nextCursor == null) {
      return Future.value();
    }
    final task = _fetchVideos(more: more);
    _videoRequest = task;
    return task.whenComplete(() {
      if (identical(_videoRequest, task)) _videoRequest = null;
    });
  }

  Future<void> _fetchVideos({required bool more}) async {
    final revision = ++_videoRevision, accountId = _accountId!;
    setState(() {
      _videosLoading = true;
      _videosError = null;
      if (!more) _fresh = false;
    });
    _videoUpdates.value++;
    if (!more) widget.onChanged(null);
    try {
      final page = await widget.repository
          .videos(accountId, cursor: more ? _nextCursor : null);
      if (!_current(revision, video: true) || _accountId != accountId) return;
      final combined = <String, TikTokDmVideo>{
        if (more)
          for (final video in _videos) video.itemId: video,
        for (final video in page.videos)
          if (video.accountId == accountId && video.selectable)
            video.itemId: video,
      }.values.toList(growable: false);
      _videoCache['$_owner:$accountId'] = (
        DateTime.now(),
        TikTokDmVideoPage(combined, nextCursor: page.nextCursor)
      );
      if (_videoCache.length > 32) _videoCache.remove(_videoCache.keys.first);
      setState(() {
        _videos = combined;
        _nextCursor = page.nextCursor;
        _videosLoading = false;
        _fresh = true;
        if (!_videos.any((video) => video.itemId == _selectedItem)) {
          _selectedItem = null;
        }
      });
      _videoUpdates.value++;
      for (final video in _videos) {
        if (video.itemId == _selectedItem) _chooseVideo(video);
      }
    } catch (error) {
      if (!_current(revision, video: true) || _accountId != accountId) return;
      setState(() {
        _videosLoading = false;
        _fresh = false;
        _videosError = _failure(error);
        _videos = const [];
        _selectedItem = null;
      });
      _videoUpdates.value++;
      widget.onChanged(null);
    }
  }

  void _chooseVideo(TikTokDmVideo video) {
    final account = _selectedAccount;
    if (!widget.enabled ||
        _owner != widget.repository.ownerId ||
        !_fresh ||
        account == null ||
        !video.selectable ||
        video.accountId != account.id) {
      return;
    }
    setState(() => _selectedItem = video.itemId);
    _videoUpdates.value++;
    widget.onChanged(TikTokDmSelection(
        accountId: account.id,
        itemId: video.itemId,
        username: account.username,
        caption: video.caption,
        permalink: video.permalink));
  }

  Future<void> _connect(
      {TikTokDmAccount? account, TikTokDmConnection? pending}) async {
    if (_connecting || !widget.enabled) return;
    _connecting = true;
    try {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          builder: (_) => TikTokDmConnectSheet(
              repository: widget.repository,
              initialUsername: account?.username,
              initialConnection: pending));
      if (mounted) await _loadAccounts();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _disconnect(TikTokDmAccount account) async {
    if (!widget.enabled || _disconnecting) return;
    _disconnecting = true;
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                  title: const ProxoText('پچڕاندنی پەیوەندی'),
                  content: ProxoText(
                      'پەیوەندی @${account.username.replaceFirst('@', '')} بپچڕێنرێت؟ ڕیکلامە پێشووەکان دەمێننەوە.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const ProxoText('پاشگەزبوونەوە')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const ProxoText('پچڕاندن'))
                  ])));
      if (confirmed != true || !mounted) return;
      setState(() => _accountsLoading = true);
      try {
        await widget.repository.disconnect(account.id, tiktokDmRequestId());
        if (!mounted || widget.repository.ownerId != _owner) return;
        final thumbnails = _videoCache['$_owner:${account.id}']
                ?.$2
                .videos
                .map((video) => video.thumbnailUrl)
                .whereType<String>()
                .toSet() ??
            <String>{};
        clearTikTokDmCache(_owner, accountId: account.id);
        for (final url in thumbnails) {
          unawaited(CachedNetworkImage.evictFromCache(url));
        }
        if (account.id == _accountId) _selectAccount(null);
        if (account.profileImageUrl != null) {
          unawaited(
              CachedNetworkImage.evictFromCache(account.profileImageUrl!));
        }
        await _loadAccounts();
      } catch (error) {
        if (mounted) {
          setState(() {
            _accountsError = _failure(error);
            _accountsLoading = false;
          });
        }
      }
    } finally {
      _disconnecting = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdFormSection(
            title: 'هەژماری تیک تۆک',
            subtitle:
                'ئەو هەژمارە هەڵبژێرە کە دەتەوێت نامەکانت تێیدا وەربگریت. ڤیدیۆی ڕیکلام و هەژماری وەرگرتنی نامە دەبێت هەمان هەژمار بن.',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_accountsLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (_accountsError != null)
                    _feedback(_accountsError!.message, _loadAccounts),
                  LayoutBuilder(builder: (context, constraints) {
                    final painter = TextPainter(
                        text: TextSpan(
                            text: 'پەیوەستکردنی هەژماری تیک تۆک',
                            style: AdUi.text(context)),
                        textDirection: TextDirection.rtl,
                        textScaler: MediaQuery.textScalerOf(context))
                      ..layout(
                          maxWidth: math.max(32, constraints.maxWidth - 112));
                    final height = math.max(72.0, painter.height + 32);
                    painter.dispose();
                    return Column(children: [
                      for (final account in _accounts) ...[
                        _capsule(height, account: account),
                        if (!account.selectable)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ProxoText(
                                  tiktokDmMessage(account.errorCode ??
                                      (account.status == 'CONNECTED'
                                          ? 'DM_NOT_ELIGIBLE'
                                          : account.status)),
                                  style: AdUi.text(context,
                                      color: AdUi.secondary))),
                        const SizedBox(height: 10),
                      ],
                      _capsule(height),
                    ]);
                  }),
                  const SizedBox(height: 8),
                  Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                    if (_pending != null && !_pending!.terminal)
                      TextButton(
                          onPressed: widget.enabled
                              ? () => _connect(pending: _pending)
                              : null,
                          child:
                              const ProxoText('بەردەوامبوون لە پەیوەستکردن')),
                    TextButton.icon(
                        onPressed: _accountsLoading || !widget.enabled
                            ? null
                            : _loadAccounts,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const ProxoText('نوێکردنەوە')),
                  ]),
                ])),
        if (_selectedAccount != null && _accountsError == null) ...[
          const SizedBox(height: AdUi.sectionGap),
          AdFormSection(
              title: 'ڤیدیۆی تیک تۆک',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_accounts
                            .where((account) => account.selectable)
                            .length >
                        1) ...[
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final account
                            in _accounts.where((account) => account.selectable))
                          AdChoice(
                              label:
                                  '@${account.username.replaceFirst('@', '')}',
                              selected: account.id == _accountId,
                              onTap: widget.enabled
                                  ? () => _selectAccount(account.id)
                                  : null),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    if (_videosError != null)
                      _feedback(_videosError!.message, _loadVideos)
                    else if (_videosLoading && _videos.isEmpty)
                      _videoStrip(context, skeleton: true)
                    else if (_videos.isEmpty)
                      _feedback('هیچ ڤیدیۆیەک نییە', _loadVideos)
                    else
                      _videoStrip(context),
                    if (_videosLoading && _videos.isNotEmpty)
                      const LinearProgressIndicator(minHeight: 2),
                    Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                      if (_videos.isNotEmpty)
                        TextButton(
                            onPressed: widget.enabled ? _seeAll : null,
                            child: const ProxoText('بینینی هەموو')),
                      TextButton.icon(
                          onPressed: _videosLoading || !widget.enabled
                              ? null
                              : _loadVideos,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const ProxoText('نوێکردنەوە')),
                    ]),
                  ])),
        ],
      ]);

  Widget _feedback(String message, VoidCallback refresh) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ProxoText(message, style: AdUi.text(context, color: AdUi.secondary)),
        Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
                onPressed: widget.enabled ? refresh : null,
                child: const ProxoText('دووبارە هەوڵ بدەوە'))),
      ]));
  Widget _capsule(double height, {TikTokDmAccount? account}) {
    final selected = account?.id == _accountId;
    return SizedBox(
        key: ValueKey(account == null
            ? 'tiktok-add-account'
            : 'tiktok-account-${account.id}'),
        height: height,
        child: CustomPaint(
            foregroundPainter: account == null ? const _DashedBorder() : null,
            child: Material(
                color: selected ? const Color(0xFFEEF4FF) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: AdUi.controlRadius,
                    side: account == null
                        ? BorderSide.none
                        : BorderSide(
                            color: selected
                                ? AdUi.selectedLine
                                : AdUi.controlLine)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: !widget.enabled || _accountsLoading
                        ? null
                        : account == null
                            ? () => _connect()
                            : account.selectable
                                ? () => _selectAccount(account.id)
                                : () => _connect(account: account),
                    child: Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: 16, end: 4),
                        child: Row(children: [
                          if (account == null)
                            const AdBrandLogo('tiktok', size: 32)
                          else
                            ClipOval(
                                child: SizedBox.square(
                                    dimension: 32,
                                    child: account.profileImageUrl == null
                                        ? const Icon(Icons.person_outline,
                                            color: AdUi.secondary)
                                        : CachedNetworkImage(
                                            imageUrl: account.profileImageUrl!,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 96,
                                            placeholder: (_, __) =>
                                                const ColoredBox(
                                                    color: AdUi.controlLine),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(Icons.person_outline,
                                                    color: AdUi.secondary)))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: account == null
                                  ? ProxoText('پەیوەستکردنی هەژماری تیک تۆک',
                                      style: AdUi.text(context))
                                  : Row(children: [
                                      Flexible(
                                          child: ProxoText(
                                              '@${account.username.replaceFirst('@', '')}',
                                              textAlign: TextAlign.right,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AdUi.text(context,
                                                  color: account.selectable
                                                      ? AdUi.ink
                                                      : AdUi.secondary))),
                                      if (selected || !account.selectable) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                            selected
                                                ? Icons.check
                                                : Icons.info_outline,
                                            size: 20,
                                            color: selected
                                                ? AdUi.blue
                                                : AdUi.secondary),
                                      ],
                                    ])),
                          if (account == null)
                            const SizedBox(
                                width: 48,
                                height: 48,
                                child:
                                    Icon(Icons.add, size: 22, color: AdUi.blue))
                          else
                            IconButton(
                                tooltip: 'پچڕاندنی پەیوەندی',
                                onPressed: widget.enabled && !_accountsLoading
                                    ? () => _disconnect(account)
                                    : null,
                                icon: const Icon(Icons.delete_outline,
                                    size: 22, color: AdUi.secondary)),
                        ]))))));
  }

  Widget _videoStrip(BuildContext context, {bool skeleton = false}) {
    final height = 128 +
        MediaQuery.textScalerOf(context)
                .scale(AdUi.text(context).fontSize ?? 14) *
            4.5;
    final content = SizedBox(
        height: height,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: skeleton ? 3 : _videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
                width: 148,
                child:
                    skeleton ? _videoCard(null) : _videoCard(_videos[index]))));
    return skeleton && !MediaQuery.disableAnimationsOf(context)
        ? Shimmer.fromColors(
            baseColor: AdUi.controlLine,
            highlightColor: AdUi.controlSurface,
            direction: ShimmerDirection.rtl,
            child: content)
        : content;
  }

  Future<void> _seeAll() async {
    if (_browsing || !widget.enabled || !_fresh || _selectedAccount == null) {
      return;
    }
    _browsing = true;
    try {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          builder: (sheetContext) => ValueListenableBuilder<int>(
              valueListenable: _videoUpdates,
              builder: (context, _, child) => Theme(
                  data: AdUi.theme(context),
                  child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: SafeArea(
                          top: false,
                          child: SizedBox(
                              height: MediaQuery.sizeOf(context).height * .8,
                              child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(children: [
                                    Row(children: [
                                      Expanded(
                                          child: ProxoText('ڤیدیۆی تیک تۆک',
                                              style: AdUi.heading(context))),
                                      IconButton(
                                          tooltip: 'داخستن',
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          icon: const Icon(Icons.close))
                                    ]),
                                    const SizedBox(height: 12),
                                    if (_videosError != null)
                                      Expanded(
                                          child: Center(
                                              child: ProxoText(
                                                  _videosError!.message)))
                                    else
                                      Expanded(
                                          child: LayoutBuilder(
                                              builder: (context, constraints) => GridView.builder(
                                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: math.max(
                                                          1,
                                                          (constraints.maxWidth / 158)
                                                              .floor()),
                                                      crossAxisSpacing: 10,
                                                      mainAxisSpacing: 10,
                                                      mainAxisExtent: 128 +
                                                          MediaQuery.textScalerOf(context).scale(AdUi.text(context).fontSize ?? 14) *
                                                              4.5),
                                                  itemCount: _videos.length,
                                                  itemBuilder: (_, index) =>
                                                      _videoCard(_videos[index],
                                                          afterSelection: () =>
                                                              Navigator.pop(sheetContext))))),
                                    if (_nextCursor != null)
                                      TextButton(
                                          onPressed: _videosLoading
                                              ? null
                                              : () async {
                                                  await _loadVideos(more: true);
                                                },
                                          child: _videosLoading
                                              ? const SizedBox.square(
                                                  dimension: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : const ProxoText('زیاتر')),
                                  ]))))))));
    } finally {
      _browsing = false;
    }
  }

  Widget _videoCard(TikTokDmVideo? video, {VoidCallback? afterSelection}) =>
      Material(
          key: video == null ? null : ValueKey('tiktok-video-${video.itemId}'),
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: AdUi.controlRadius,
              side: BorderSide(
                  color: video != null && _selectedItem == video.itemId
                      ? AdUi.blue
                      : AdUi.controlLine)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: video != null && _fresh && widget.enabled
                  ? () {
                      _chooseVideo(video);
                      afterSelection?.call();
                    }
                  : null,
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                            height: 96,
                            child: Stack(fit: StackFit.expand, children: [
                              if (video?.thumbnailUrl != null)
                                CachedNetworkImage(
                                    imageUrl: video!.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 320,
                                    placeholder: (_, __) => const ColoredBox(
                                        color: AdUi.controlLine),
                                    errorWidget: (_, __, ___) =>
                                        const Center(child: ProxoText('Proxo')))
                              else
                                const ColoredBox(color: AdUi.controlLine),
                              if (video != null &&
                                  _selectedItem == video.itemId)
                                const Align(
                                    alignment: AlignmentDirectional.topEnd,
                                    child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.check_circle,
                                            color: AdUi.blue, size: 24))),
                            ])),
                        const SizedBox(height: 8),
                        if (video == null)
                          const Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                ColoredBox(
                                    color: AdUi.controlLine,
                                    child: SizedBox(height: 16)),
                                SizedBox(height: 6),
                                ColoredBox(
                                    color: AdUi.controlLine,
                                    child: SizedBox(height: 16)),
                              ]))
                        else
                          Expanded(
                              child: ProxoText(
                                  video.caption.isEmpty
                                      ? 'ڤیدیۆی تیک تۆک'
                                      : video.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AdUi.text(context))),
                        const SizedBox(height: 6),
                        if (video == null)
                          ColoredBox(
                              color: AdUi.controlLine,
                              child: SizedBox(
                                  height: MediaQuery.textScalerOf(context)
                                          .scale(AdUi.text(context).fontSize ??
                                              14) *
                                      1.5))
                        else
                          ProxoText(
                              video.publishedAt == null
                                  ? ' '
                                  : '${video.publishedAt!.year}/${video.publishedAt!.month}/${video.publishedAt!.day}',
                              maxLines: 1,
                              style: AdUi.text(context, color: AdUi.secondary)),
                      ]))));
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(14)));
    final paint = Paint()
      ..color = AdUi.controlLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(
            metric.extractPath(d, math.min(d + 5, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}

class TikTokDmConnectSheet extends StatefulWidget {
  final TikTokDmRepository repository;
  final String? initialUsername;
  final TikTokDmConnection? initialConnection;
  const TikTokDmConnectSheet(
      {super.key,
      required this.repository,
      this.initialUsername,
      this.initialConnection});
  @override
  State<TikTokDmConnectSheet> createState() => _TikTokDmConnectSheetState();
}

class _TikTokDmConnectSheetState extends State<TikTokDmConnectSheet>
    with WidgetsBindingObserver {
  late final TextEditingController _username = TextEditingController(
      text: widget.initialConnection?.requestedUsername ??
          widget.initialUsername ??
          '');
  TikTokDmConnection? _connection;
  TikTokDmFailure? _error;
  Timer? _timer;
  bool _busy = false, _active = true;
  int _polls = 0, _revision = 0;
  String? _requestId;
  late final String _owner = widget.repository.ownerId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connection = widget.initialConnection;
    _schedulePoll();
  }

  @override
  void dispose() {
    _revision++;
    _timer?.cancel();
    _username.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (_active) unawaited(_check());
  }

  bool get _validOwner => mounted && _owner == widget.repository.ownerId;
  bool _expireIfNeeded() {
    final connection = _connection;
    if (connection == null ||
        connection.terminal ||
        connection.expiresAt == null ||
        connection.expiresAt!.isAfter(DateTime.now())) {
      return false;
    }
    _timer?.cancel();
    setState(() => _connection = TikTokDmConnection(
        id: connection.id,
        requestedUsername: connection.requestedUsername,
        status: 'EXPIRED',
        expiresAt: connection.expiresAt));
    return true;
  }

  void _schedulePoll() {
    _timer?.cancel();
    if (!_active || _connection == null || _connection!.terminal) return;
    if (_expireIfNeeded()) return;
    var delay = math.min(20, 3 + _polls * 2) * 1000;
    final expiresAt = _connection!.expiresAt;
    if (expiresAt != null) {
      delay = math.min(delay,
          math.max(1, expiresAt.difference(DateTime.now()).inMilliseconds));
    }
    _timer = Timer(Duration(milliseconds: delay), () => unawaited(_check()));
  }

  Future<void> _start({bool regenerate = false}) async {
    if (_busy || !_validOwner) return;
    if (!validTikTokUsername(_username.text)) {
      setState(() => _error = const TikTokDmFailure('INVALID_USERNAME'));
      return;
    }
    if (regenerate) _requestId = null;
    _requestId ??= tiktokDmRequestId();
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await widget.repository.startConnection(_username.text, _requestId!);
      if (!_validOwner || revision != _revision) return;
      setState(() {
        _connection = result;
        _polls = 0;
      });
    } catch (error) {
      if (_validOwner && revision == _revision) {
        setState(() => _error = error is TikTokDmFailure
            ? error
            : const TikTokDmFailure('NETWORK'));
      }
    } finally {
      if (_validOwner && revision == _revision) {
        setState(() => _busy = false);
        _schedulePoll();
      }
    }
  }

  Future<void> _check() async {
    if (_busy ||
        !_validOwner ||
        _connection == null ||
        _connection!.terminal ||
        !_active) {
      return;
    }
    if (_expireIfNeeded()) return;
    final revision = _revision, id = _connection!.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.connectionStatus(id);
      if (!mounted ||
          !_validOwner ||
          revision != _revision ||
          id != _connection?.id) {
        return;
      }
      final prior = _connection!;
      setState(() {
        _connection = TikTokDmConnection(
            id: result.id.isEmpty ? prior.id : result.id,
            requestedUsername: result.requestedUsername.isEmpty
                ? prior.requestedUsername
                : result.requestedUsername,
            status: result.status,
            authorizationUrl: result.authorizationUrl ?? prior.authorizationUrl,
            authorizedUsername: result.authorizedUsername,
            errorCode: result.errorCode,
            expiresAt: result.expiresAt ?? prior.expiresAt);
        _polls++;
      });
      if (result.status == 'CONNECTED') {
        Navigator.of(context).pop();
        return;
      }
    } catch (error) {
      if (_validOwner && revision == _revision) {
        setState(() {
          _error = error is TikTokDmFailure
              ? error
              : const TikTokDmFailure('NETWORK');
          _polls++;
        });
      }
    } finally {
      if (_validOwner && revision == _revision) {
        setState(() => _busy = false);
        _schedulePoll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    final url = connection?.authorizationUrl;
    final uri = Uri.tryParse(url ?? '');
    // Never render a URL supplied by a caller as an arbitrary QR destination.
    final official = uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        (uri.host == 'tiktok.com' || uri.host.endsWith('.tiktok.com'));
    qr.QrImage? matrix;
    if (official && url!.length <= 2048 && connection?.terminal != true) {
      try {
        matrix = qr.QrImage(qr.QrCode.fromData(
            data: url, errorCorrectLevel: qr.QrErrorCorrectLevel.M));
      } catch (_) {}
    }
    return Theme(
        data: AdUi.theme(context),
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
                top: false,
                child: Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom),
                    child: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const AdBrandLogo('tiktok', size: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: ProxoText(
                                            'پەیوەستکردنی هەژماری تیک تۆک',
                                            style: AdUi.heading(context))),
                                    IconButton(
                                        tooltip: 'داخستن',
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.close))
                                  ]),
                                  const SizedBox(height: 16),
                                  if (connection == null) ...[
                                    TextField(
                                        controller: _username,
                                        enabled: !_busy,
                                        textDirection: TextDirection.ltr,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        maxLength: 25,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'ناوی بەکارهێنەری تیک تۆک',
                                            hintText: '@username'),
                                        onChanged: (_) => _requestId = null),
                                    const SizedBox(height: 16),
                                  ] else ...[
                                    ProxoText(
                                        '@${connection.requestedUsername.replaceFirst('@', '')}',
                                        textAlign: TextAlign.center,
                                        style: AdUi.heading(context)),
                                    const SizedBox(height: 8),
                                    ProxoText(
                                        'بە هەمان هەژماری تیک تۆک کە لەسەرەوەیە سکەن بکە.',
                                        textAlign: TextAlign.center,
                                        style: AdUi.text(context)),
                                    const SizedBox(height: 16),
                                    if (matrix != null)
                                      Center(
                                          child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 248),
                                              child: AspectRatio(
                                                  aspectRatio: 1,
                                                  child: Semantics(
                                                      label:
                                                          'کۆدی QR بۆ پەیوەستکردنی هەژماری تیک تۆک',
                                                      child: CustomPaint(
                                                          key: const ValueKey(
                                                              'tiktok-official-qr'),
                                                          painter: _QrPainter(
                                                              matrix))))))
                                    else if (!connection.terminal)
                                      ProxoText(
                                          'لینکی پەیوەستکردن پشتڕاست نەکرایەوە؛ دووبارە پشکنین بکە.',
                                          style: AdUi.text(context,
                                              color: AdUi.secondary)),
                                    const SizedBox(height: 16),
                                    const TikTokQrTutorial(),
                                    const SizedBox(height: 12),
                                    ProxoText(
                                        connection.status ==
                                                    'WAITING_FOR_SCAN' ||
                                                connection.status ==
                                                    'AUTHORIZATION_CREATED'
                                            ? 'چاوەڕوانی سکەنکردن و ڕەزامەندییە'
                                            : connection.status == 'VERIFYING'
                                                ? 'هەژمار و مۆڵەتەکان پشکنین دەکرێن'
                                                : tiktokDmMessage(
                                                    connection.errorCode ??
                                                        connection.status),
                                        textAlign: TextAlign.center,
                                        style: AdUi.text(context,
                                            color: AdUi.secondary)),
                                    if (connection.status ==
                                            'USERNAME_MISMATCH' &&
                                        connection.authorizedUsername != null)
                                      ProxoText(
                                          '@${connection.authorizedUsername!.replaceFirst('@', '')}',
                                          textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_error != null) ...[
                                    ProxoText(_error!.message,
                                        style: AdUi.text(context,
                                            color: AdUi.secondary)),
                                    const SizedBox(height: 12)
                                  ],
                                  FilledButton(
                                      key: const ValueKey(
                                          'tiktok-connect-action'),
                                      onPressed: _busy
                                          ? null
                                          : connection == null
                                              ? _start
                                              : connection.terminal
                                                  ? () =>
                                                      _start(regenerate: true)
                                                  : _check,
                                      child: _busy
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : ProxoText(connection == null
                                              ? 'بەردەوامبوون'
                                              : connection.terminal
                                                  ? 'QR ـی نوێ دروست بکە'
                                                  : 'پشکنینی پەیوەندی')),
                                ])))))));
  }
}

class _QrPainter extends CustomPainter {
  final qr.QrImage image;
  _QrPainter(this.image);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final unit = size.shortestSide / (image.moduleCount + 8);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        if (image.isDark(row, column)) {
          canvas.drawRect(
              Rect.fromLTWH((column + 4) * unit, (row + 4) * unit, unit, unit),
              paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
