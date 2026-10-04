import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_template_meta.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';

Future<void> captureUi(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('build/ui-verification')
      ..createSync(recursive: true);
    File('${folder.path}/$name.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });
}

ProxoCard card({String status = 'active', String publish = 'ready'}) =>
    ProxoCard(
      id: '11111111-1111-4111-8111-111111111111',
      userId: '22222222-2222-4222-8222-222222222222',
      name: 'پەڕەی پەیوەندیی فرۆشگای Proxo 2026 بە ناوێکی درێژ',
      templateKey: 'classic',
      status: status,
      publishStatus: publish,
      cardNumber: 22,
      createdAt: DateTime.utc(2026, 10, 3),
      updatedAt: DateTime.utc(2026, 10, 3),
      platforms: const {'wa': '9647501234567'},
    );

class FakeProxoLink extends ProxoLinkRepository {
  List<ProxoCard> rows;
  Map<String, dynamic>? submitted;
  String? actionId, actionName;
  FakeProxoLink(this.rows);
  @override
  Future<List<ProxoCard>> cards() async => rows;
  @override
  Future<List<ProxoTemplate>> templates() async => [
    for (final key in [
      'classic',
      'dark',
      'light',
      'pill',
      'card',
      'neon',
      'zoom',
      'banner',
    ])
      ProxoTemplate(
        key: key,
        label: key,
        previewPath: '/contact-preview?token=signed',
        version: 1,
        requiresAvatar: false,
      ),
  ];
  @override
  Future<Uri> preview(String id) async => Uri.parse(
    'https://www.proxobalance.app/contact/$id?preview_token=signed',
  );
  @override
  Future<Uri> templatePreview(String key, int version) async =>
      Uri.parse('https://www.proxobalance.app/contact-preview?token=signed');
  @override
  Future<ProxoCard> save(
    Map<String, dynamic> data, {
    ProxoCard? existing,
  }) async {
    submitted = data;
    rows = [card()];
    return rows.first;
  }

  @override
  Future<void> action(String id, String action) async {
    actionId = id;
    actionName = action;
  }

  @override
  Future<String> uploadAvatar(String id, Uint8List bytes) async =>
      '$id/avatar.jpg';
  @override
  Uri publicUrl(String id) =>
      Uri.parse('https://www.proxobalance.app/contact/$id');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Rabar')
      ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('ProxoLink offers no Telegram control and hides archived platform data', () {
    expect(kPlatformBtns.map((p) => p.id), ['wa', 'vb', 'ig', 'ph', 'as']);
    expect(kPlatformCardLabels.containsKey('tg'), isFalse);
    expect(kPlatformUrlScheme.containsKey('tg'), isFalse);
    final historical = ProxoCard.fromJson({
      ...card().toJson(),
      'platforms': {'wa': '9647501234567', 'tg': 'archived_account'},
    });
    expect(historical.platforms['wa'], '9647501234567');
    expect(historical.platforms.containsKey('tg'), isFalse);
  });
  testWidgets('a stalled signed-preview request times out and offers retry', (tester) async {
    final pending = Completer<Uri>();
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: ProxoLinkPreview(
        loadTimeout: const Duration(seconds: 2),
        loadUrl: () { requests++; return pending.future; },
      )),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('پێشبینین نەکرایەوە'), findsOneWidget);
    await tester.tap(find.text('دووبارە هەوڵبدەرەوە'));
    await tester.pump();
    expect(requests, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(Uri.parse('https://www.proxobalance.app/contact-preview?token=late'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('a late preview response cannot replace its timeout error state', (tester) async {
    final pending = Completer<Uri>();
    var controllers = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: ProxoLinkPreview(
        loadTimeout: const Duration(seconds: 1),
        loadUrl: () => pending.future,
        onControllerCreated: (_) => controllers++,
      )),
    ));
    await tester.pump(const Duration(seconds: 1));
    pending.complete(Uri.parse('https://www.proxobalance.app/contact-preview?token=late'));
    await tester.pump();
    expect(controllers, 0);
    expect(find.text('پێشبینین نەکرایەوە'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'states gate public sharing, ad selection, preview and same-ID retry',
    () {
      expect(card().available, isTrue);
      expect(card(status: 'inactive').available, isFalse);
      expect(card(status: 'inactive').canPreview, isTrue);
      expect(card(publish: 'failed').available, isFalse);
      expect(card(publish: 'failed').canRetry, isTrue);
      expect(card().publicPath, card(publish: 'failed').publicPath);
      final generated = List.generate(100, (_) => newProxoRequestId());
      expect(generated.toSet().length, 100);
      expect(
        generated.every(
          (id) => RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id),
        ),
        isTrue,
      );
    },
  );
  for (final width in [320.0, 375.0, 393.0, 430.0, 768.0]) {
    testWidgets(
      'long RTL card at width $width has no overflow at enlarged system text',
      (tester) async {
        final screenshotKey = GlobalKey();
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: screenshotKey,
              child: ToolsScreen(repository: FakeProxoLink([card()])),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('چالاکە'), findsOneWidget);
        expect(find.text('ڕیکلام'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureUi(tester, screenshotKey, 'cards-$width');
      },
    );
  }
  testWidgets(
    'failed card offers retry using its existing UUID and hides ad action',
    (tester) async {
      final repo = FakeProxoLink([card(publish: 'failed')]);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ToolsScreen(repository: repo),
        ),
      );
      await tester.pump();
      expect(find.text('ڕیکلام'), findsNothing);
      await tester.tap(find.text('دووبارە هەوڵبدەرەوە'));
      await tester.pump();
      expect(repo.actionId, card().id);
      expect(repo.actionName, 'retry');
    },
  );
  for (final width in [320.0, 393.0, 768.0]) {
    testWidgets('form and real-preview failure recovery fit width $width', (
      tester,
    ) async {
      final screenshotKey = GlobalKey();
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: RepaintBoundary(
            key: screenshotKey,
            child: ToolsScreen(
              initialCreate: true,
              repository: FakeProxoLink([]),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('classic'), findsOneWidget);
      expect(find.text('پێشبینین نەکرایەوە'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, screenshotKey, 'form-$width');
    });
  }
}
