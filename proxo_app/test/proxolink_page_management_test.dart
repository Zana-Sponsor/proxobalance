import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/controllers/proxolink_pages_controller.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/proxolink_page_details_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';
import 'package:proxo_app/widgets/proxolink_page_card.dart';
import 'package:proxo_app/widgets/home_quick_actions.dart';

import 'proxolink_flow_test.dart' show FakeProxoLink;

ProxoCard page(
  int i, {
  String name = 'Page',
  String type = 'contact',
  String status = 'active',
}) => ProxoCard.fromJson({
  'id': '33333333-3333-4333-8333-${i.toString().padLeft(12, '0')}',
  'user_id': '11111111-1111-4111-8111-111111111111',
  'name': name,
  'bio': 'بایۆ Proxo 2026',
  'page_kind': type,
  'template_key': 'pill',
  'template_version': 6,
  'client_request_id':
      '44444444-4444-4444-8444-${i.toString().padLeft(12, '0')}',
  'created_at': '2026-10-08T00:00:00Z',
  'updated_at': '2026-10-08T00:00:01Z',
  'status': status,
  'publish_status': 'ready',
  'settings': {
    'providers': [
      {
        'provider_key': type == 'contact'
            ? 'telegram'
            : type == 'order'
            ? 'talabat'
            : 'app_store',
        'destination_url': type == 'contact'
            ? 'proxo_iq'
            : type == 'order'
            ? 'https://talabat.com/restaurant/test'
            : 'https://apps.apple.com/app/proxo/id123456789',
        'enabled': true,
        'sort_order': 0,
      },
    ],
  },
});

class ManagementRepository extends FakeProxoLink {
  ManagementRepository(super.rows);
  final reads = <Completer<List<ProxoCard>>>[];
  bool defer = false, fail = false, saving = false;
  int saves = 0;
  Completer<ProxoCard>? saveGate;
  @override
  Future<List<ProxoCard>> cards() {
    if (fail) throw const ProxoLinkFailure('network_error');
    if (!defer) return Future.value(List.of(rows));
    final read = Completer<List<ProxoCard>>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<ProxoCard> save(
    Map<String, dynamic> data, {
    ProxoCard? existing,
  }) async {
    saves++;
    submitted = data;
    final saved = saveGate == null
        ? ProxoCard.fromJson({
            ...page(rows.length + 1).toJson(),
            ...data,
            'id': existing?.id ?? page(rows.length + 1).id,
            'created_at':
                existing?.createdAt.toIso8601String() ??
                page(1).createdAt.toIso8601String(),
            'updated_at': '2026-10-08T00:00:02Z',
          })
        : await saveGate!.future;
    rows = [saved, ...rows.where((p) => p.id != saved.id)];
    return saved;
  }

  @override
  Future<void> action(String id, String action) async {
    actionId = id;
    actionName = action;
    rows = action == 'delete'
        ? rows.where((p) => p.id != id).toList()
        : rows
              .map(
                (p) => p.id == id
                    ? ProxoCard.fromJson({
                        ...p.toJson(),
                        'status': action == 'deactivate'
                            ? 'inactive'
                            : 'active',
                        'updated_at': '2026-10-08T00:00:03Z',
                      })
                    : p,
              )
              .toList();
  }
}

Widget host(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);
Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      kAppFont,
    )..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'latest request wins; older owner list cannot replace refreshed cards',
    () async {
      final repo = ManagementRepository([])..defer = true,
          state = ProxoLinkPagesController(ManagementRepository([]));
      state.dispose();
      final controller = ProxoLinkPagesController(repo);
      final first = controller.refresh(), second = controller.refresh();
      repo.reads[1].complete([page(2)]);
      await second;
      repo.reads[0].complete([page(1)]);
      await first;
      expect(controller.pages.single.id, page(2).id);
      controller.dispose();
    },
  );
  test(
    'newly saved UUID is immediately upserted once and invalidates old GET',
    () async {
      final repo = ManagementRepository([])..defer = true;
      final controller = ProxoLinkPagesController(repo),
          read = controller.refresh();
      controller.upsert(page(3));
      controller.upsert(page(3));
      repo.reads.single.complete([]);
      await read;
      expect(controller.pages.map((p) => p.id), [page(3).id]);
      controller.dispose();
    },
  );
  test('list deduplicates and retains newest updated record', () async {
    final original = page(1),
        updated = ProxoCard.fromJson({
          ...original.toJson(),
          'name': 'Updated',
          'updated_at': '2026-10-08T00:00:02Z',
        });
    final controller = ProxoLinkPagesController(
      ManagementRepository([updated, original, page(2)]),
    );
    await controller.refresh();
    expect(controller.pages.length, 2);
    expect(
      controller.pages.firstWhere((p) => p.id == original.id).name,
      'Updated',
    );
    controller.dispose();
  });
  test('late responses after disposal do not notify or throw', () async {
    final repo = ManagementRepository([])..defer = true,
        controller = ProxoLinkPagesController(ManagementRepository([]));
    controller.dispose();
    final state = ProxoLinkPagesController(repo), request = state.refresh();
    state.dispose();
    repo.reads.single.complete([page(1)]);
    await request;
  });
  testWidgets(
    'My Pages has skeleton, safe retry and empty state without any WebView',
    (t) async {
      final repo = ManagementRepository([])..defer = true;
      await t.pumpWidget(host(ToolsScreen(repository: repo)));
      await t.pump();
      expect(find.byType(ProxoLinkPageSkeleton), findsWidgets);
      expect(find.byType(ProxoLinkPreview), findsNothing);
      repo.reads.single.completeError(const ProxoLinkFailure('network_error'));
      await t.pumpAndSettle();
      expect(find.text('دووبارە هەوڵبدەرەوە'), findsOneWidget);
      repo.defer = false;
      await tap(t, find.text('دووبارە هەوڵبدەرەوە'));
      expect(find.text('پەڕەیەکت نییە'), findsOneWidget);
    },
  );
  testWidgets(
    'real Home destinations include separate My Pages and Create Page actions',
    (t) async {
      var create = 0, manage = 0;
      await t.pumpWidget(
        host(
          Scaffold(
            body: HomeQuickActions(
              onToolsTap: () => manage++,
              onCreatePageTap: () => create++,
            ),
          ),
        ),
      );
      await tap(t, find.byKey(const ValueKey('home-contact-tools')));
      await tap(t, find.byKey(const ValueKey('home-create-page')));
      expect(create, 1);
      expect(manage, 1);
    },
  );
  for (final type in ['contact', 'order', 'download']) {
    testWidgets(
      '$type owner card opens details, edits and returns same UUID/URL',
      (t) async {
        t.view.physicalSize = const Size(393, 1100);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final original = page(1, type: type),
            repo = ManagementRepository([original, page(2, type: type)]);
        await t.pumpWidget(host(ToolsScreen(repository: repo)));
        await t.pumpAndSettle();
        expect(find.byType(ProxoLinkPreview), findsNothing);
        await tap(t, find.byKey(ValueKey('proxolink-page-${original.id}')));
        expect(find.byType(ProxoLinkPageDetailsScreen), findsOneWidget);
        expect(find.text(original.id), findsOneWidget);
        await tap(t, find.text('دەستکاریکردن'));
        final name = find.byType(TextFormField).first;
        await t.ensureVisible(name);
        await t.enterText(name, 'Edited');
        await tap(t, find.text('پاشەکەوتکردن'));
        expect(find.byType(ProxoLinkPageDetailsScreen), findsOneWidget);
        expect(repo.rows.first.id, original.id);
        expect(repo.rows.first.publicPath, original.publicPath);
        expect(repo.rows.first.pageKind, original.pageKind);
        expect(repo.rows.first.userId, original.userId);
        expect(repo.rows.length, 2);
      },
    );
  }
  testWidgets(
    'owner details copies stable URL and deactivates/archives through repository',
    (t) async {
      t.view.physicalSize = const Size(393, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = ManagementRepository([page(1)]);
      await t.pumpWidget(host(ToolsScreen(repository: repo)));
      await t.pumpAndSettle();
      await tap(t, find.byKey(ValueKey('proxolink-page-${page(1).id}')));
      await tap(t, find.text('کۆپی لینک'));
      expect(copied, 'https://www.proxobalance.app/contact/${page(1).id}');
      await tap(t, find.text('ناچالاککردن'));
      await tap(t, find.text('بەردەوامبوون'));
      expect(repo.rows.single.status, 'inactive');
      expect(find.text('ناچالاکە'), findsOneWidget);
      await tap(t, find.text('ئەرشیفکردن'));
      await tap(t, find.text('بەردەوامبوون'));
      expect(repo.rows, isEmpty);
      expect(find.text('پەڕەیەکت نییە'), findsOneWidget);
    },
  );
  testWidgets('unsaved changes require confirmation before leaving editor', (
    t,
  ) async {
    final repo = ManagementRepository([]);
    await t.pumpWidget(
      host(ToolsScreen(repository: repo, initialCreate: true)),
    );
    await t.pumpAndSettle();
    await tap(t, find.text('پەیوەندی').first);
    await t.ensureVisible(find.byType(TextFormField).first);
    await t.enterText(find.byType(TextFormField).first, 'Unsaved');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('پاشگەزبوونەوە لە دەستکاری؟'), findsOneWidget);
    await tap(t, find.text('بەردەوامبوون'));
    expect(find.byType(TextFormField), findsWidgets);
    expect(repo.saves, 0);
  });
  for (final width in [320.0, 375.0, 393.0, 430.0, 768.0])
    for (final direction in TextDirection.values) {
      testWidgets(
        'management list/details at $width $direction with long copy and 1.6 text scale',
        (t) async {
          t.view.physicalSize = Size(width, 1100);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final p = page(
                1,
                name: 'پڕۆکسۆ Proxo ' + List.filled(20, 'Long').join(' '),
              ),
              repo = ManagementRepository([p]);
          await t.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: Directionality(textDirection: direction, child: child!),
              ),
              home: ToolsScreen(repository: repo),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await tap(t, find.byKey(ValueKey('proxolink-page-${p.id}')));
          expect(find.byType(ProxoLinkPageDetailsScreen), findsOneWidget);
          await t.ensureVisible(find.text('بەستەری هەمیشەیی'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        },
      );
    }
}
