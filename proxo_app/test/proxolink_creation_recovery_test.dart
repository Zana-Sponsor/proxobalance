import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/controllers/proxolink_pages_controller.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_theme.dart';

import 'proxolink_page_management_test.dart' show page;
import 'proxolink_tools_create_test.dart'
    show ToolsRepository, host, tap, size, field, png;
import 'support/session_fixture.dart';

class RecoveryRepository extends ToolsRepository
    implements ProxoLinkAuthoringAvailability {
  RecoveryRepository(super.rows);
  @override
  bool? pageCreationEnabled = true;
  String? nextFailure;
  bool priorRequestFinishesLate = false;
  int providerReads = 0;
  @override
  Future<List<ProxoProvider>> providers() async {
    providerReads++;
    return super.providers();
  }

  final attempts = <Map<String, dynamic>>[];
  @override
  Future<ProxoCard> save(Map<String, dynamic> data,
      {ProxoCard? existing}) async {
    attempts.add(jsonDecode(jsonEncode(data)) as Map<String, dynamic>);
    final error = nextFailure;
    nextFailure = null;
    if (priorRequestFinishesLate) {
      rows = [
        ProxoCard.fromJson({
          ...page(1).toJson(),
          'client_request_id': data['client_request_id'],
          'name': 'Previously saved'
        })
      ];
    }
    if (error != null) throw ProxoLinkFailure(error);
    return super.save(data, existing: existing);
  }
}

Future<void> fillContact(WidgetTester tester) async {
  await tester.ensureVisible(field('ناوی پەڕە'));
  await tester.enterText(field('ناوی پەڕە'), 'Proxo fixture page');
  await tester.ensureVisible(field('telegram'));
  await tester.enterText(field('telegram'), 'proxo_iq');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(kAppFont)
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 393.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'empty Tools stays on list at $width / $scale and explicit create opens once',
          (tester) async {
        size(tester, width, height: 900);
        final repo = RecoveryRepository([]);
        final capture = GlobalKey();
        await tester.pumpWidget(host(
            RepaintBoundary(key: capture, child: ToolsScreen(repository: repo)),
            scale: scale));
        await tester.pumpAndSettle();
        expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
        final panel = find.byKey(const ValueKey('tools-empty-state'));
        expect(panel, findsOneWidget);
        expect(tester.getSize(panel).width, lessThanOrEqualTo(600));
        expect(tester.getTopLeft(panel).dx, greaterThanOrEqualTo(20));
        final button = find.byKey(const ValueKey('tools-create-page'));
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await png(tester, capture,
            'tools-balanced-empty-${width.toInt()}-${scale.toInt()}x');
        final action = tester.widget<FilledButton>(button).onPressed!;
        action();
        action();
        await tester.pumpAndSettle();
        expect(find.byType(ProxoLinkCreatePageScreen), findsOneWidget);
        expect(repo.listReads, 1);
      });
    }
  }

  testWidgets(
      'disabled server authoring shows availability and retry without unusable form',
      (tester) async {
    size(tester, 320, height: 900);
    final repo = RecoveryRepository([])..pageCreationEnabled = false;
    await tester.pumpWidget(
        host(ProxoLinkCreatePageScreen(repository: repo), scale: 2));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('create-page-load-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('create-page-submit')), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
    repo.pageCreationEnabled = true;
    final retry = tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'دووبارە هەوڵ بدەرەوە'))
        .onPressed!;
    retry();
    retry();
    await tester.pumpAndSettle();
    expect(repo.providerReads, 2);
    expect(find.byKey(const ValueKey('create-page-load-error')), findsNothing);
    expect(find.byKey(const ValueKey('create-page-submit')), findsOneWidget);
  });

  testWidgets(
      'uncertain save retries the exact request and payload without duplicate page',
      (tester) async {
    size(tester, 393);
    final repo = RecoveryRepository([])..nextFailure = 'network_error';
    await tester.pumpWidget(host(ToolsScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('tools-create-page')));
    await fillContact(tester);
    final submit = find.byKey(const ValueKey('create-page-submit'));
    await tap(tester, submit);
    expect(repo.attempts, hasLength(1));
    expect(tester.widget<TextField>(find.descendant(of: field('ناوی پەڕە'), matching: find.byType(TextField))).readOnly, true);
    expect(tester.widget<TextField>(find.descendant(of: field('telegram'), matching: find.byType(TextField))).readOnly, true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('proxolink-create-request-fixture'),
        repo.attempts.first['client_request_id']);
    await tap(tester, submit);
    expect(repo.attempts, hasLength(2));
    expect(repo.attempts.last, repo.attempts.first);
    expect(repo.rows, hasLength(1));
    expect(prefs.getString('proxolink-create-request-fixture'), isNull);
    expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
  });

  testWidgets(
      'completed save preserves covering dialog and returns only its own route after dismissal',
      (tester) async {
    size(tester, 393);
    final repo = RecoveryRepository([])..saveGate = Completer<ProxoCard>();
    await tester.pumpWidget(host(ToolsScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('tools-create-page')));
    await fillContact(tester);
    final submit = find.byKey(const ValueKey('create-page-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    unawaited(showDialog<void>(
        context: tester.element(find.byType(ProxoLinkCreatePageScreen)),
        builder: (_) => const AlertDialog(content: Text('Covering dialog'))));
    await tester.pump();
    repo.saveGate!.complete(page(1));
    await tester.pumpAndSettle();
    expect(find.text('Covering dialog'), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
    expect(repo.attempts, hasLength(1));
    expect(repo.rows, hasLength(1));
  });

  testWidgets(
      'definite server validation rejection allows correction with the same request',
      (tester) async {
    size(tester, 393);
    final repo = RecoveryRepository([])
      ..nextFailure = 'invalid_provider_destination';
    await tester.pumpWidget(host(ToolsScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('tools-create-page')));
    await fillContact(tester);
    await tap(tester, find.byKey(const ValueKey('create-page-submit')));
    await tester.ensureVisible(field('telegram'));
    await tester.enterText(field('telegram'), 'proxo_corrected');
    await tap(tester, find.byKey(const ValueKey('create-page-submit')));
    expect(repo.attempts.last['client_request_id'],
        repo.attempts.first['client_request_id']);
    final settings = repo.attempts.last['settings'] as Map;
    expect((settings['providers'] as List).single['destination_url'],
        'proxo_corrected');
    expect(repo.rows, hasLength(1));
  });

  testWidgets(
      'idempotency conflict reconciles the owner request saved after the initial lookup',
      (tester) async {
    size(tester, 393);
    final repo = RecoveryRepository([])
      ..scope = userA
      ..nextFailure = 'idempotency_conflict'
      ..priorRequestFinishesLate = true;
    await tester.pumpWidget(host(ToolsScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('tools-create-page')));
    await fillContact(tester);
    await tap(tester, find.byKey(const ValueKey('create-page-submit')));
    expect(repo.attempts, hasLength(1));
    expect(repo.rows, hasLength(1));
    expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
    expect(find.text('Previously saved'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getString('proxolink-create-request-$userA'),
        isNull);
  });

  testWidgets(
      'reopened request recovers saved owner page before checking write availability',
      (tester) async {
    size(tester, 393);
    final saved = page(1);
    SharedPreferences.setMockInitialValues(
        {'proxolink-create-request-$userA': saved.clientRequestId!});
    final repo = RecoveryRepository([saved])
      ..scope = userA
      ..pageCreationEnabled = false;
    await tester
        .pumpWidget(host(ToolsScreen(repository: repo, initialCreate: true)));
    await tester.pumpAndSettle();
    expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
    expect(repo.attempts, isEmpty);
    expect(
        (await SharedPreferences.getInstance())
            .getString('proxolink-create-request-$userA'),
        isNull);
  });

  testWidgets('locally upserted creating page continues polling until ready',
      (tester) async {
    final repo = RecoveryRepository([]);
    final state = ProxoLinkPagesController(repo);
    await state.refresh();
    final creating =
        ProxoCard.fromJson({...page(1).toJson(), 'publish_status': 'creating'});
    state.upsert(creating);
    repo.rows = [page(1)];
    await tester.pump(const Duration(seconds: 5));
    expect(repo.listReads, 2);
    expect(state.pages.single.publishStatus, 'ready');
    state.dispose();
  });

  group('actual service transport', () {
    late SupabaseClient client;
    late ProxoLinkService service;
    final requests = <http.Request>[];
    var providersStatus = 200;
    var providerBody = '';
    var saveStatus = 201;
    var changeOwnerBeforeResponse = false;
    var templateVersion = 5;
    setUp(() async {
      requests.clear();
      providersStatus = 200;
      providerBody =
          jsonEncode({'ok': true, 'writes_enabled': true, 'providers': []});
      saveStatus = 201;
      changeOwnerBeforeResponse = false;
      templateVersion = 5;
      final transport = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/page-providers')
          return http.Response(providerBody, providersStatus);
        if (request.url.path == '/api/contact-templates') {
          return http.Response(
              jsonEncode({
                'ok': true,
                'templates': [
                  for (final key in [
                    'pill',
                    'pill-mint',
                    'pill-dark',
                    'pill-white'
                  ])
                    {
                      'template_key': key,
                      'version': templateVersion,
                      'display_name_ckb': key,
                      'preview_path': '/fixture',
                      'requires_avatar': false
                    }
                ]
              }),
              200);
        }
        if (request.url.path.startsWith('/storage/v1/object/')) {
          return http.Response(
              jsonEncode({'Key': request.url.path.split('/object/').last}),
              200);
        }
        if (request.url.path == '/api/contact-cards') {
          if (changeOwnerBeforeResponse) await restoreFixture(client, userB);
          return http.Response(
              jsonEncode(saveStatus == 201
                  ? {'ok': true, 'card': page(1).toJson()}
                  : {'ok': false, 'error': 'isolated_staging_required'}),
              saveStatus,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        throw StateError('Unexpected fixture request: ${request.url.path}');
      });
      client = SupabaseClient('https://page-fixture.invalid', 'fixture-key',
          httpClient: transport,
          authOptions: const AuthClientOptions(autoRefreshToken: false));
      service = ProxoLinkService(client, httpClient: transport);
      await restoreFixture(client);
    });
    tearDown(() async => client.dispose());

    test(
        'retry reloads an unusable V5 template catalog after V6 becomes available',
        () async {
      expect((await service.templates()).every((t) => t.version == 5), true);
      templateVersion = 6;
      expect((await service.templates()).every((t) => t.version == 6), true);
      expect(requests.where((r) => r.url.path == '/api/contact-templates'),
          hasLength(2));
    });

    test(
        'missing deployed provider rewrite is unavailable rather than invalid JSON/offline',
        () async {
      providersStatus = 404;
      providerBody = 'The page could not be found\nNOT_FOUND';
      await expectLater(
          service.providers(),
          throwsA(isA<ProxoLinkFailure>()
              .having((e) => e.code, 'code', 'page_creation_unavailable')));
    });

    test('write capability false is honored before avatar storage upload',
        () async {
      providerBody =
          jsonEncode({'ok': true, 'writes_enabled': false, 'providers': []});
      await service.providers();
      expect(service.pageCreationEnabled, false);
      await expectLater(
          service.uploadAvatar(newProxoRequestId(),
              Uint8List.fromList([137, 80, 78, 71, ...List.filled(16, 0)])),
          throwsA(isA<ProxoLinkFailure>()
              .having((e) => e.code, 'code', 'isolated_staging_required')));
      expect(requests.every((r) => !r.url.path.startsWith('/storage/')), true);
      providerBody =
          jsonEncode({'ok': true, 'writes_enabled': true, 'providers': []});
      await service.providers();
      expect(service.pageCreationEnabled, true);
    });

    test(
        'valid avatar uses owner and request namespace, then create passes exact provider payload',
        () async {
      final request = newProxoRequestId();
      final bytes = (await rootBundle.load('assets/images/proxo_logo.png'))
          .buffer
          .asUint8List();
      final avatar = await service.uploadAvatar(request, bytes);
      expect(avatar, startsWith('$userA/$request/avatar-'));
      expect(avatar, endsWith('.png'));
      final payload = {
        'client_request_id': request,
        'page_kind': 'contact',
        'name': 'Fixture',
        'template_key': 'pill',
        'template_version': 6,
        'avatar_path': avatar,
        'settings': {
          'providers': [
            {
              'provider_key': 'whatsapp',
              'destination_url': '07501234567',
              'enabled': true,
              'sort_order': 0
            }
          ]
        }
      };
      final saved = await service.save(payload);
      expect(saved.id, page(1).id);
      expect(jsonDecode(requests.last.body), payload);
      expect(requests.last.headers['authorization'], startsWith('Bearer '));
      expect(requests.where((r) => r.url.path.startsWith('/storage/')),
          hasLength(1));
    });

    test(
        'backend rollout refusal remains explicit and creates no fabricated success',
        () async {
      saveStatus = 503;
      await expectLater(
          service.save({'client_request_id': newProxoRequestId()}),
          throwsA(isA<ProxoLinkFailure>()
              .having((e) => e.code, 'code', 'isolated_staging_required')));
    });

    test('account change rejects late create response', () async {
      changeOwnerBeforeResponse = true;
      await expectLater(
          service.save({'client_request_id': newProxoRequestId()}),
          throwsA(isA<ProxoLinkFailure>()
              .having((e) => e.code, 'code', 'unauthorized')));
    });
  });
}
