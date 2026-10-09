import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/controllers/proxolink_pages_controller.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_theme.dart';

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
  'moderation_status': 'pending',
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
}
