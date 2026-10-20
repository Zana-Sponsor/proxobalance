// Test-only platform fakes use the interfaces bundled with the app plugins.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/proxo_error_stack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

const _uid = '11111111-1111-4111-8111-111111111111';
const _tx = 'DEMO-DEPOSIT-20261020';
const _sender = 'هەژماری تاقیکردنەوە';
const _note = 'Synthetic receipt fixture only';

// Keep serialization inside the test isolate so HTTP completion is controlled
// by the same fake-async clock as the widget and no background worker leaks.
class _InlineJson implements YAJsonIsolate {
  @override
  String? get debugName => 'deposit-fixture-json';
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<String> encode(Object? value) async => jsonEncode(value);
  @override
  Future<dynamic> decode(String value) async => jsonDecode(value);
}

class _ReceiptPicker extends ImagePickerPlatform {
  _ReceiptPicker(this.bytes);
  final Uint8List bytes;
  int picks = 0;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    picks++;
    expect(source, ImageSource.gallery);
    return XFile.fromData(bytes, mimeType: 'image/png', name: 'fixture.png');
  }
}

class _DepositBackend {
  final events = <String>[];
  final inserts = <Map<String, dynamic>>[];
  final responses = <Completer<http.Response>>[];
  final mirrored = <String, Map<Object?, Object?>>{};
  late final SupabaseClient client;
  var notified = Completer<void>();

  Future<void> initialize() async {
    client = SupabaseClient('https://fixture.invalid', 'fixture-only',
        isolate: _InlineJson(),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/rest/v1/pa_transactions') {
        events.add('canonical-insert');
        inserts.add(Map<String, dynamic>.from(jsonDecode(request.body)));
        final response = Completer<http.Response>();
        responses.add(response);
        final resolved = await response.future;
        return http.Response(resolved.body, resolved.statusCode,
            request: request, headers: resolved.headers);
      }
      if (request.url.path == '/functions/v1/notify-deposit-request') {
        events.add('notification');
        notified.complete();
        expect(jsonDecode(request.body)['transaction_id'], _tx);
        return _response({'ok': true}, 200);
      }
      throw StateError(
          'Unexpected fixture HTTP: ${request.method} ${request.url}');
    }));
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${part({'alg': 'HS256'})}.${part({
          'sub': _uid,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })}.fixture';
    await client.auth.recoverSession(jsonEncode(Session(
            accessToken: token,
            tokenType: 'bearer',
            user: User(
                id: _uid,
                appMetadata: const {},
                userMetadata: const {},
                email: 'demo@example.invalid',
                aud: 'authenticated',
                createdAt: '2026-01-01T00:00:00Z'))
        .toJson()));
    app.supabase = client;
  }

  Future<Object?> firebase(MethodCall call) async {
    expect(call.method, 'DatabaseReference#set');
    final arguments = Map<Object?, Object?>.from(call.arguments as Map);
    final path = arguments['path'] as String;
    events.add('mirror:$path');
    mirrored[path] = Map<Object?, Object?>.from(arguments['value'] as Map);
    return null;
  }

  void succeed() {
    events.add('canonical-committed');
    responses.last.complete(_response({'public_transaction_id': _tx}, 201));
  }

  void fail() {
    events.add('canonical-failed');
    responses.last.complete(_response({
      'code': 'P0001',
      'message': 'Synthetic rejection',
      'details': null,
      'hint': null
    }, 400));
  }

  static http.Response _response(Object body, int status) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
}

Future<void> _fill(WidgetTester tester) async {
  await tester.tap(find.text('Open fixture'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('25,000'));
  await tester.tap(find.text('FIB'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('deposit-name')));
  await tester.enterText(find.byKey(const ValueKey('deposit-name')), _sender);
  await tester.enterText(find.byKey(const ValueKey('deposit-note')), _note);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('هەڵبژاردنی وێنە'));
  await tester.tap(find.text('هەڵبژاردنی وێنە'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('گەلەری'));
  await tester.pumpAndSettle();
  expect(find.text('وەسڵەکە دانرا'), findsOneWidget);
  await tester.ensureVisible(find.byKey(const ValueKey('deposit-submit')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = _DepositBackend();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await backend.initialize();
  });
  tearDownAll(() => backend.client.dispose());
  setUp(() {
    backend.events.clear();
    backend.inserts.clear();
    backend.responses.clear();
    backend.mirrored.clear();
    backend.notified = Completer<void>();
  });

  for (final failFirst in [false, true]) {
    testWidgets(
        failFirst
            ? 'failed canonical deposit retains fields and proof, retry succeeds'
            : 'repeated submit commits once, mirrors after commit, returns success',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = MockClient.pngResponse().bodyBytes;
      final oldPicker = ImagePickerPlatform.instance;
      final picker = _ReceiptPicker(bytes);
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = oldPicker);
      const database = MethodChannel('plugins.flutter.io/firebase_database');
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(database, backend.firebase);
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(database, null));
      bool? returned;
      await tester.pumpWidget(MaterialApp(
          theme: buildProxoTheme(),
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      child: const Text('Open fixture'),
                      onPressed: () async {
                        returned = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => const DepositScreen(
                                        recipientNumberOverrides: {
                                          'fib': '0000000000'
                                        })));
                      })))));
      await _fill(tester);
      final submit = find.byKey(const ValueKey('deposit-submit'));
      // Two taps before a frame rebuild must still produce only one request.
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(backend.inserts, hasLength(1));
      expect(backend.events, ['canonical-insert']);
      expect(returned, isNull);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      final sent = backend.inserts.single;
      expect(sent['user_id'], _uid);
      expect(sent['amount'], 25000 / app.kIqdRate);
      expect(sent['method'], 'fib');
      expect(sent['status'], 'pending');
      expect(sent['type'], 'deposit');
      expect(sent['receipt_b64'], base64Encode(bytes));
      expect(sent['note'], contains(_sender));
      expect(sent['note'], contains(_note));
      expect(sent, isNot(contains('public_transaction_id')));

      if (failFirst) {
        backend.fail();
        await tester.pumpAndSettle();
        expect(find.byType(DepositScreen), findsOneWidget);
        expect(returned, isNull);
        expect(backend.mirrored, isEmpty);
        expect(backend.events, ['canonical-insert', 'canonical-failed']);
        expect(
            tester
                .widget<TextFormField>(
                    find.byKey(const ValueKey('deposit-amount')))
                .controller!
                .text,
            '25000');
        expect(
            tester
                .widget<TextFormField>(
                    find.byKey(const ValueKey('deposit-name')))
                .controller!
                .text,
            _sender);
        expect(
            tester
                .widget<TextFormField>(
                    find.byKey(const ValueKey('deposit-note')))
                .controller!
                .text,
            _note);
        expect(find.text('وەسڵەکە دانرا'), findsOneWidget);
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pump();
        expect(backend.inserts, hasLength(2));
        expect(backend.inserts.last, sent);
      }
      backend.succeed();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(returned, true);
      expect(find.byType(DepositScreen), findsNothing);
      expect(picker.picks, 1);
      expect(backend.inserts, hasLength(failFirst ? 2 : 1));
      expect(backend.notified.isCompleted, true);
      final committed = backend.events.indexOf('canonical-committed');
      final sideEffects = backend.events.skip(committed + 1).toList();
      expect(
          sideEffects,
          unorderedEquals([
            'mirror:requests/$_uid/$_tx',
            'mirror:allRequests/$_tx',
            'notification'
          ]));
      expect(backend.mirrored['allRequests/$_tx']!['reqId'], _tx);
      expect(backend.mirrored['requests/$_uid/$_tx']!['status'], 'pending');
      expect(tester.takeException(), isNull);
      // Dispose the global toast queue before test teardown.
      ProxoErrorStack.clear();
      await tester.pumpAndSettle();
    });
  }
}
