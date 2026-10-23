import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/tiktok_dm_accounts.dart';
import 'package:proxo_app/widgets/tiktok_dm_account_picker.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'ad_creation_flow_test.dart' show AdPaintBinding, capturePng;

class FakeTikTokDmRepository extends TikTokDmRepository {
  @override
  String ownerId = 'owner-one';
  @override
  Stream<bool> offlineChanges = const Stream.empty();
  List<TikTokDmAccount> connected = const [
    TikTokDmAccount(id: 'a', username: 'store_a', dmReady: true)
  ];
  Future<TikTokDmVideoPage> Function(String)? loadVideos;
  Future<TikTokDmConnection> Function()? check;
  var starts = 0, checks = 0, disconnects = 0;
  String? requested;
  @override
  Future<TikTokDmAccounts> accounts() async => TikTokDmAccounts(connected);
  @override
  Future<TikTokDmConnection> startConnection(
      String username, String requestId) async {
    starts++;
    requested = username;
    return TikTokDmConnection(
        id: requestId,
        requestedUsername: normalizeTikTokUsername(username),
        status: 'WAITING_FOR_SCAN',
        authorizationUrl: 'https://business.tiktok.com/authorize?state=test');
  }

  @override
  Future<TikTokDmConnection> connectionStatus(String requestId) async {
    checks++;
    if (check != null) return check!();
    return const TikTokDmConnection(
        id: '', requestedUsername: '', status: 'WAITING_FOR_SCAN');
  }

  @override
  Future<TikTokDmVideoPage> videos(String accountId, {String? cursor}) async =>
      loadVideos != null
          ? loadVideos!(accountId)
          : TikTokDmVideoPage([
              TikTokDmVideo(
                  accountId: accountId,
                  itemId: '$accountId-public',
                  caption: 'Public video',
                  isPublic: true,
                  eligible: true),
              TikTokDmVideo(
                  accountId: accountId,
                  itemId: '$accountId-private',
                  caption: 'Private video',
                  isPublic: false,
                  eligible: true),
            ]);
  @override
  Future<void> disconnect(String accountId, String requestId) async {
    disconnects++;
  }
}

Widget host(Widget child, {double scale = 1}) => RepaintBoundary(
    key: const ValueKey('ad-preview-capture'),
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, navigator) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: navigator!),
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(16), child: child))))));

Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  AdPaintBinding();
  setUpAll(() async {
    await (FontLoader('Rabar')
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader('RabarAuthRegular')
          ..addFont(rootBundle.load('assets/fonts/Rabar_022.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() {
    clearTikTokDmCache('owner-one');
    clearTikTokDmCache('owner-two');
  });
  test('display models require explicit Public and advertising eligibility',
      () {
    final unknown = TikTokDmVideo.fromJson(const {'item_id': '1'}, 'a');
    expect(unknown.selectable, isFalse);
    expect(
        TikTokDmVideo.fromJson(
                const {'item_id': '1', 'public': true, 'ad_eligible': true},
                'a')
            .selectable,
        isTrue);
    expect(
        TikTokDmAccount.fromJson(const {'id': 'a', 'status': 'CONNECTED'})
            .selectable,
        isFalse);
    expect(
        TikTokDmAccount.fromJson(const {
          'id': 'a',
          'status': 'CONNECTED',
          'dm_ready': false,
          'message_ads_eligible': true,
          'can_pull_video': true,
          'can_manage_message': true
        }).selectable,
        isFalse);
    expect(normalizeTikTokUsername('  @Store.Name  '), 'store.name');
    expect(validTikTokUsername('@store'), isTrue);
    expect(validTikTokUsername('store/other'), isFalse);
  });
  testWidgets(
      'video section waits for a connected account and excludes non-public videos',
      (tester) async {
    final repository = FakeTikTokDmRepository()..connected = [];
    final selections = <TikTokDmSelection?>[];
    await tester.pumpWidget(host(TikTokDmAccountPicker(
        repository: repository, onChanged: selections.add)));
    await flush(tester);
    expect(find.text('ڤیدیۆی تیک تۆک'), findsNothing);
    expect(find.byKey(const ValueKey('tiktok-add-account')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repository.connected = const [
      TikTokDmAccount(id: 'a', username: 'store_a', dmReady: true)
    ];
    await tester.pumpWidget(host(TikTokDmAccountPicker(
        repository: repository, onChanged: selections.add)));
    await flush(tester);
    expect(find.byKey(const ValueKey('tiktok-video-a-public')), findsOneWidget);
    expect(find.byKey(const ValueKey('tiktok-video-a-private')), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('tiktok-video-a-public')));
    await tester.tap(find.byKey(const ValueKey('tiktok-video-a-public')));
    expect(selections.last?.accountId, 'a');
    expect(selections.last?.itemId, 'a-public');
  });
  testWidgets('late account A video response cannot replace account B videos',
      (tester) async {
    final a = Completer<TikTokDmVideoPage>(),
        b = Completer<TikTokDmVideoPage>();
    final repository = FakeTikTokDmRepository()
      ..connected = const [
        TikTokDmAccount(id: 'a', username: 'store_a', dmReady: true),
        TikTokDmAccount(id: 'b', username: 'store_b', dmReady: true)
      ]
      ..loadVideos = ((id) => id == 'a' ? a.future : b.future);
    await tester.pumpWidget(
        host(TikTokDmAccountPicker(repository: repository, onChanged: (_) {})));
    await flush(tester);
    await tester.tap(find.byKey(const ValueKey('tiktok-account-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tiktok-account-b')));
    await tester.pump();
    b.complete(const TikTokDmVideoPage([
      TikTokDmVideo(
          accountId: 'b', itemId: 'b-only', isPublic: true, eligible: true)
    ]));
    await flush(tester);
    a.complete(const TikTokDmVideoPage([
      TikTokDmVideo(
          accountId: 'a', itemId: 'a-old', isPublic: true, eligible: true)
    ]));
    await flush(tester);
    expect(find.byKey(const ValueKey('tiktok-video-b-only')), findsOneWidget);
    expect(find.byKey(const ValueKey('tiktok-video-a-old')), findsNothing);
  });
  testWidgets('returning to Direct remembers only the last valid account',
      (tester) async {
    final repository = FakeTikTokDmRepository()
      ..connected = const [
        TikTokDmAccount(id: 'a', username: 'store_a', dmReady: true),
        TikTokDmAccount(id: 'b', username: 'store_b', dmReady: true)
      ];
    TikTokDmSelection? selection;
    Widget picker() => host(TikTokDmAccountPicker(
        repository: repository, onChanged: (value) => selection = value));
    await tester.pumpWidget(picker());
    await flush(tester);
    await tester.tap(find.byKey(const ValueKey('tiktok-account-b')));
    await flush(tester);
    final video = find.byKey(const ValueKey('tiktok-video-b-public'));
    await tester.ensureVisible(video);
    await tester.tap(video);
    expect(selection?.itemId, 'b-public');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(picker());
    await flush(tester);
    expect(find.byKey(const ValueKey('tiktok-video-b-public')), findsOneWidget);
    expect(selection, isNull);
    await tester.pumpWidget(const SizedBox());
    repository.connected = const [
      TikTokDmAccount(id: 'a', username: 'store_a', dmReady: true),
      TikTokDmAccount(id: 'b', username: 'store_b', status: 'DISCONNECTED'),
      TikTokDmAccount(id: 'c', username: 'store_c', dmReady: true)
    ];
    await tester.pumpWidget(picker());
    await flush(tester);
    expect(find.byKey(const ValueKey('tiktok-video-b-public')), findsNothing);
    expect(find.text('ڤیدیۆی تیک تۆک'), findsNothing);
    expect(selection, isNull);
  });
  testWidgets('offline event invalidates an in-flight video response',
      (tester) async {
    final network = StreamController<bool>();
    final response = Completer<TikTokDmVideoPage>();
    final repository = FakeTikTokDmRepository()
      ..offlineChanges = network.stream
      ..loadVideos = ((_) => response.future);
    TikTokDmSelection? selection;
    await tester.pumpWidget(host(TikTokDmAccountPicker(
        repository: repository, onChanged: (value) => selection = value)));
    await flush(tester);
    network.add(true);
    await flush(tester);
    response.complete(const TikTokDmVideoPage([
      TikTokDmVideo(
          accountId: 'a', itemId: 'late', isPublic: true, eligible: true)
    ]));
    await flush(tester);
    expect(find.byKey(const ValueKey('tiktok-video-late')), findsNothing);
    expect(selection, isNull);
    expect(find.text('هێڵەکەت بپشکنە و دووبارە هەوڵ بدەوە.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    unawaited(network.close());
  });
  testWidgets(
      'confirmed offline state hides cached selectable videos and clears selection',
      (tester) async {
    final repository = FakeTikTokDmRepository();
    TikTokDmSelection? selection;
    await tester.pumpWidget(host(TikTokDmAccountPicker(
        repository: repository, onChanged: (value) => selection = value)));
    await flush(tester);
    final video = find.byKey(const ValueKey('tiktok-video-a-public'));
    await tester.ensureVisible(video);
    await tester.tap(video);
    expect(selection, isNotNull);
    repository.loadVideos =
        (_) => Future.error(const TikTokDmFailure('OFFLINE'));
    final refresh = find.widgetWithText(TextButton, 'نوێکردنەوە').last;
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await flush(tester);
    expect(find.text('هێڵەکەت بپشکنە و دووبارە هەوڵ بدەوە.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tiktok-video-a-public')), findsNothing);
    expect(selection, isNull);
  });
  testWidgets(
      'connected and add capsules retain equal geometry at 280px and 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeTikTokDmRepository()
      ..connected = const [
        TikTokDmAccount(
            id: 'a', username: 'very_long_store_username', dmReady: true)
      ];
    await tester.pumpWidget(host(
        TikTokDmAccountPicker(repository: repository, onChanged: (_) {}),
        scale: 2));
    await flush(tester);
    expect(tester.getSize(find.byKey(const ValueKey('tiktok-account-a'))),
        tester.getSize(find.byKey(const ValueKey('tiktok-add-account'))));
    expect(tester.takeException(), isNull);
  });
  testWidgets('disconnect is never sent before explicit confirmation',
      (tester) async {
    final repository = FakeTikTokDmRepository();
    await tester.pumpWidget(
        host(TikTokDmAccountPicker(repository: repository, onChanged: (_) {})));
    await flush(tester);
    await tester.tap(find.byTooltip('پچڕاندنی پەیوەندی'));
    await tester.pumpAndSettle();
    expect(repository.disconnects, 0);
    await tester.tap(find.text('پاشگەزبوونەوە'));
    await tester.pumpAndSettle();
    expect(repository.disconnects, 0);
  });
  testWidgets('offline change immediately replaces open video browser cards',
      (tester) async {
    final network = StreamController<bool>();
    final repository = FakeTikTokDmRepository()
      ..offlineChanges = network.stream;
    await tester.pumpWidget(
        host(TikTokDmAccountPicker(repository: repository, onChanged: (_) {})));
    await flush(tester);
    await tester.ensureVisible(find.text('بینینی هەموو'));
    await tester.tap(find.text('بینینی هەموو'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('tiktok-video-a-public')), findsNWidgets(2));
    network.add(true);
    await flush(tester);
    expect(find.byKey(const ValueKey('tiktok-video-a-public')), findsNothing);
    expect(find.text('هێڵەکەت بپشکنە و دووبارە هەوڵ بدەوە.'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    unawaited(network.close());
  });
  testWidgets('authorization QR rejects unrelated origins', (tester) async {
    final repository = FakeTikTokDmRepository();
    await tester.pumpWidget(host(TikTokDmConnectSheet(
        repository: repository,
        initialConnection: const TikTokDmConnection(
            id: 'request',
            requestedUsername: 'store',
            status: 'WAITING_FOR_SCAN',
            authorizationUrl: 'https://example.invalid/fake'))));
    await tester.pump();
    expect(find.byKey(const ValueKey('tiktok-official-qr')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('expired authorization hides QR and offers regeneration',
      (tester) async {
    final repository = FakeTikTokDmRepository();
    await tester.pumpWidget(host(TikTokDmConnectSheet(
        repository: repository,
        initialConnection: TikTokDmConnection(
            id: 'request',
            requestedUsername: 'store',
            status: 'WAITING_FOR_SCAN',
            authorizationUrl:
                'https://business.tiktok.com/authorize?state=expired',
            expiresAt: DateTime.utc(2000)))));
    await tester.pump();
    expect(find.byKey(const ValueKey('tiktok-official-qr')), findsNothing);
    expect(find.text('QR ـی نوێ دروست بکە'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(repository.checks, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('manual checks coalesce with polling and pause in background',
      (tester) async {
    final response = Completer<TikTokDmConnection>();
    final repository = FakeTikTokDmRepository()
      ..check = (() => response.future);
    await tester.pumpWidget(host(TikTokDmConnectSheet(
        repository: repository,
        initialConnection: const TikTokDmConnection(
            id: 'request',
            requestedUsername: 'store',
            status: 'WAITING_FOR_SCAN',
            authorizationUrl:
                'https://business.tiktok.com/authorize?state=example'))));
    await tester.pump();
    expect(find.byKey(const ValueKey('tiktok-official-qr')), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('tiktok-connect-action')));
    await tester.tap(find.byKey(const ValueKey('tiktok-connect-action')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(repository.checks, 1);
    response.complete(const TikTokDmConnection(
        id: '', requestedUsername: '', status: 'WAITING_FOR_SCAN'));
    await flush(tester);
    expect(find.byKey(const ValueKey('tiktok-official-qr')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(repository.checks, 1);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testWidgets('captures account and QR fixtures with bundled Kurdish fonts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Directory('docs/tiktok_dm_evidence').createSync(recursive: true);
    for (final width in [393.0, 280.0]) {
      tester.view.physicalSize = Size(width, width == 280 ? 1800 : 1100);
      await tester.pumpWidget(host(
          TikTokDmAccountPicker(
              repository: FakeTikTokDmRepository(), onChanged: (_) {}),
          scale: width == 280 ? 2 : 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePng(
          tester, 'docs/tiktok_dm_evidence/accounts_${width.toInt()}.png');
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.physicalSize = const Size(393, 1100);
    await tester.pumpWidget(host(TikTokDmConnectSheet(
        repository: FakeTikTokDmRepository(),
        initialConnection: const TikTokDmConnection(
            id: 'fixture',
            requestedUsername: 'store_a',
            status: 'WAITING_FOR_SCAN',
            authorizationUrl:
                'https://business.tiktok.com/authorize?state=fixture'))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await capturePng(tester, 'docs/tiktok_dm_evidence/qr_fixture_393.png');
    await tester.pumpWidget(const SizedBox());
  });
}
