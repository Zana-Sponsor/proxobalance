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
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/models/proxolink_template_meta.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/proxolink_page_editor.dart';
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
      moderationStatus: 'pending',
      cardNumber: 22,
      createdAt: DateTime.utc(2026, 10, 3),
      updatedAt: DateTime.utc(2026, 10, 3),
      platforms: const {'wa': '9647501234567'},
    );

class FakeProxoLink extends ProxoLinkRepository {
  List<ProxoCard> rows;
  Map<String, dynamic>? submitted;
  String? actionId, actionName;
  final previewRequests = <String>[];
  FakeProxoLink(this.rows);
  @override
  Future<List<ProxoCard>> cards() async => rows;
  @override
  Future<List<ProxoTemplate>> templates() async => [
    for (final key in ['pill','pill-mint','pill-dark','pill-white'])
      ProxoTemplate(
        key: key,
        label: key,
        previewPath: '/contact-preview?token=signed',
        version: 6,
        requiresAvatar: false,
      ),
  ];
  @override
  Future<List<ProxoProvider>> providers() async => [
    for(final entry in {'contact':['whatsapp','viber','instagram','telegram','korek','asiacell'],
      'order':['talabat','wade','toters','lezzoo'],'download':['google_play','app_store']}.entries)
      for(final key in entry.value) ProxoProvider(key:key,pageType:entry.key,label:key,icon:key,
        inputKind:entry.key=='contact' ? (['instagram','telegram'].contains(key)?'handle':'phone'):'url'),
  ];
  @override
  Future<Uri> formPreview(Map<String,dynamic> data, {ProxoCard? existing}) async {
    previewRequests.add('${data['template_key']}/${data['template_version']}/${data['color_theme']}/${data['card_language']}');
    return Uri.parse('https://www.proxobalance.app/page-preview?token=encrypted');
  }
  @override
  Future<Uri> preview(String id) async => Uri.parse(
    'https://www.proxobalance.app/contact/$id?preview_token=signed',
  );
  @override
  Future<Uri> templatePreview(String key, int version, {
    String theme = 'purple',
    String language = 'ku',
    String pageType = 'contact',
  }) async {
    previewRequests.add('$key/$version/$theme/$language');
    return Uri.parse('https://www.proxobalance.app/contact-preview?token=signed');
  }
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
  Uri publicUrl(String id, {String pageType = 'contact'}) =>
      Uri.parse('https://www.proxobalance.app/$pageType/$id');
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
  testWidgets('theme and language reload one live demo while retaining form input', (tester) async {
    final repo = FakeProxoLink([]);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: SingleChildScrollView(child: ProxoLinkPageEditor(repository: repo, onSaved: (_) async {}))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پەیوەندی').first);
    await tester.pumpAndSettle();
    final nameField = find.byType(TextFormField).first;
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'فرۆشگای Proxo 2026');
    final blue = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'blue',
    );
    await tester.ensureVisible(blue);
    await tester.tap(blue);
    await tester.pumpAndSettle();
    expect(repo.previewRequests.last, 'pill/6/blue/ku');
    final language = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(language);
    await tester.tap(language);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(repo.previewRequests.last, 'pill/6/blue/en');
    expect(find.byType(ProxoLinkPreview), findsOneWidget);
    expect(tester.widget<TextFormField>(nameField).controller!.text,
        'فرۆشگای Proxo 2026');
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
        expect(find.text('چاوەڕوانی'), findsOneWidget);
        expect(find.text('ڕیکلام'), findsNothing);
        expect(tester.takeException(), isNull);
        await captureUi(tester, screenshotKey, 'cards-$width');
      },
    );
  }
  testWidgets('technical failure is still pending moderation, with only delete/preview actions', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: ToolsScreen(repository: FakeProxoLink([card(publish: 'failed')]))));
    await tester.pumpAndSettle();
    expect(find.text('چاوەڕوانی'), findsOneWidget);
    expect(find.text('ڕەتکراوە'), findsNothing);
    expect(find.text('پێشبینین'), findsOneWidget);
    expect(find.text('سڕینەوە'), findsOneWidget);
    expect(find.text('ڕیکلام'), findsNothing);
  });
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
            child: Scaffold(body: SingleChildScrollView(child: ProxoLinkPageEditor(repository: FakeProxoLink([]), onSaved: (_) async {}))),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('پەیوەندی').first);
      await tester.pumpAndSettle();
      expect(find.text('ستایلی کلاسیک'), findsOneWidget);
      expect(find.text('pill'), findsNothing);
      expect(find.text('پێشبینین نەکرایەوە'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, screenshotKey, 'form-$width');
    });
  }
}
