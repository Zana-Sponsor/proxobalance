import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/services/fastpay_pending_checkout.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/fastpay_checkout_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ad_repository_test.dart' show mockTransport, jsonResponse;
import 'support/session_fixture.dart';

const order = 'PX-FICTIONAL-ORDER-01';
Map<String, dynamic> created([String id = order]) => {
      'success': true, 'orderId': id, 'qrText': 'fictional-qr-token'
    };
Map<String, dynamic> credited() => {
      'status': 'approved', 'gateway_status': 'PAID', 'wallet_credited': true,
      'public_transaction_id': 'TX-FICTIONAL', 'gateway_amount': 10000,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late Future<http.Response> Function(http.Request) database;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ProxoLocale.current.value = const Locale('ckb');
    database = (_) async => throw StateError('Unexpected database request');
    client = SupabaseClient('https://wallet-fixture.invalid', 'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: mockTransport((request) => database(request)));
    app.supabase = client;
    await restoreFixture(client);
  });
  tearDown(() async => client.dispose());

  test('wallet success requires the committed credited ledger, not PAID alone', () {
    expect(FastPayService.walletCredited(credited(), amountIqd: 10000), isTrue);
    for (final change in [
      {'wallet_credited': false}, {'wallet_credited': null},
      {'status': 'pending'}, {'gateway_status': 'CREATED'}, {'gateway_amount': 9000},
    ]) {
      expect(FastPayService.walletCredited({...credited(), ...change}, amountIqd: 10000), isFalse);
    }
  });

  test('checkout binds successful HTTP response to the original order', () async {
    final requests = <http.Request>[];
    final gateway = mockTransport((request) async {
      requests.add(request);
      expect(request.url.path, '/webhook/fastpay/order-create');
      expect(request.headers['authorization'], startsWith('Bearer '));
      expect(jsonDecode(request.body), {
        'purpose': 'wallet_deposit', 'orderId': order,
        'billAmount': 10000, 'currency': 'IQD',
      });
      return jsonResponse(created());
    });
    final result = await http.runWithClient(() => FastPayService.createOrder(
        orderId: order, billAmountIqd: 10000, expectedUserId: userA), () => gateway);
    expect(result.orderId, order);
    expect(requests, hasLength(1));
  });

  test('HTTP error, another order and unsafe QR cannot open a checkout', () async {
    final responses = [
      http.Response(jsonEncode(created()), 503),
      jsonResponse(created('PX-ANOTHER-ORDER')),
      jsonResponse({...created(), 'qrUrl': 'javascript:alert(1)'}),
      jsonResponse({...created(), 'qrUrl': 'https://attacker.example/pay'}),
      jsonResponse({...created(), 'qrUrl': 'https://user:password@example.com/pay'}),
      jsonResponse({...created(), 'qrText': null}),
    ];
    for (final response in responses) {
      await expectLater(http.runWithClient(() => FastPayService.createOrder(
          orderId: order, billAmountIqd: 10000, expectedUserId: userA),
          () => mockTransport((_) async => response)), throwsA(isA<FastPayException>()));
    }
  });

  test('wrong owner and reserved immutable IDs never call the legacy gateway', () async {
    var calls = 0;
    final gateway = mockTransport((_) async { calls++; return jsonResponse(created()); });
    for (final details in [
      (userB, order, 10000), (userA, 'AP${'a' * 28}', 10000),
      (userA, order, 4999),
    ]) {
      await expectLater(http.runWithClient(() => FastPayService.createOrder(
          orderId: details.$2, billAmountIqd: details.$3, expectedUserId: details.$1),
          () => gateway), throwsA(isA<FastPayException>()));
    }
    expect(calls, 0);
  });

  test('owner switch while creating discards the previous owner QR', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final result = http.runWithClient(() => FastPayService.createOrder(
        orderId: order, billAmountIqd: 10000, expectedUserId: userA),
        () => mockTransport((_) { started.complete(); return response.future; }));
    final assertion = expectLater(result, throwsA(isA<FastPayException>()));
    await started.future;
    await restoreFixture(client, userB);
    response.complete(jsonResponse(created()));
    await assertion;
  });

  test('status reconciliation cannot substitute its paid flag for the ledger', () async {
    var reconciled = false;
    database = (request) async {
      expect(reconciled, isTrue);
      expect(request.url.queryParameters['user_id'], 'eq.$userA');
      expect(request.url.queryParameters['fastpay_order_id'], 'eq.$order');
      expect(request.url.queryParameters['select'], contains('wallet_credited'));
      return jsonResponse({'status': 'pending', 'gateway_status': 'PAID', 'wallet_credited': false});
    };
    final row = await http.runWithClient(() => FastPayService.fetchRow(order, expectedUserId: userA),
        () => mockTransport((request) async {
          expect(request.url.path, '/webhook/fastpay/order-status');
          expect(jsonDecode(request.body), {'orderId': order});
          expect(request.headers['authorization'], startsWith('Bearer '));
          reconciled = true;
          return jsonResponse({'success': true, 'paid': true, 'terminal': true});
        }));
    expect(FastPayService.walletCredited(row!, amountIqd: 10000), isFalse);
  });

  test('lost reconciliation response still reads a committed wallet credit', () async {
    database = (_) async => jsonResponse(credited());
    final row = await http.runWithClient(() => FastPayService.fetchRow(order, expectedUserId: userA),
        () => mockTransport((_) async => throw http.ClientException('response lost')));
    expect(FastPayService.walletCredited(row!, amountIqd: 10000), isTrue);
  });

  test('owner switch during reconciliation prevents a new-owner ledger read', () async {
    var reads = 0;
    database = (_) async { reads++; return jsonResponse(credited()); };
    await expectLater(http.runWithClient(() => FastPayService.fetchRow(order, expectedUserId: userA),
        () => mockTransport((_) async {
          await restoreFixture(client, userB);
          return jsonResponse({'success': true});
        })), throwsA(isA<FastPayException>()));
    expect(reads, 0);
  });

  Future<void> mount(WidgetTester tester, {int amount = 10000, String? note}) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FastPayCheckoutSheet(
        amountIqd: amount, userId: userA, note: note))));
    await tester.pumpAndSettle();
  }
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 20)); }
  }

  testWidgets('polling coalesces and a cancelled checkout ignores late paid state', (tester) async {
    final read = Completer<http.Response>();
    var reads = 0, statuses = 0;
    database = (_) { reads++; return read.future; };
    final gateway = mockTransport((request) async {
      final id = jsonDecode(request.body)['orderId'] as String;
      if (request.url.path.endsWith('/order-create')) return jsonResponse(created(id));
      expect(request.url.path, endsWith('/order-status'));
      statuses++;
      return jsonResponse({'success': true});
    });
    await http.runWithClient(() async {
      await mount(tester);
      await tester.ensureVisible(find.text('بەردەوامبە'));
      await tester.tap(find.text('بەردەوامبە'));
      await flush(tester);
      expect(reads, 1);
      await tester.pump(const Duration(seconds: 9));
      expect(reads, 1);
      expect(statuses, 1);
      await tester.ensureVisible(find.text('پاشگەزبوونەوە'));
      await tester.tap(find.text('پاشگەزبوونەوە'));
      await tester.pump();
      read.complete(jsonResponse(credited()));
      await flush(tester);
      expect(find.text('سەرکەوتوو بوو'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, () => gateway);
  });

  testWidgets('reopening after a lost response resumes the original amount, note and order', (tester) async {
    final creates = <Map<String, dynamic>>[];
    database = (_) async => http.Response('null', 200,
        headers: {'content-type': 'application/json'});
    final gateway = mockTransport((request) async {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      if (request.url.path.endsWith('/order-status')) return jsonResponse({'success': false});
      expect(request.url.path, endsWith('/order-create'));
      creates.add(body);
      final saved = (await const FastPayPendingCheckoutStore().read(userA))!;
      expect(saved.orderId, body['orderId']);
      expect(saved.dispatched, isTrue);
      if (creates.length == 1) throw http.ClientException('response lost');
      return jsonResponse(created(body['orderId'] as String));
    });
    await http.runWithClient(() async {
      await mount(tester, note: 'original note');
      await tester.ensureVisible(find.text('بەردەوامبە'));
      await tester.tap(find.text('بەردەوامبە'));
      await flush(tester);
      expect(creates, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await mount(tester, amount: 25000, note: 'edited note');
      expect(find.text('10,000 د.ع'), findsOneWidget);
      expect(find.text('25,000 د.ع'), findsNothing);
      await tester.ensureVisible(find.text('بەردەوامبە'));
      await tester.tap(find.text('بەردەوامبە'));
      await flush(tester);
      expect(creates, hasLength(1));
      final restored = (await const FastPayPendingCheckoutStore().read(userA))!;
      expect(restored.orderId, creates.single['orderId']);
      expect(restored.amountIqd, 10000);
      expect(restored.note, 'original note');
      expect(restored.dispatched, isTrue);
      await tester.pumpWidget(const SizedBox());
    }, () => gateway);
  });

  testWidgets('reopening a credited checkout resolves it without a new QR request', (tester) async {
    await const FastPayPendingCheckoutStore().claim(userA,
        const FastPayPendingCheckout(orderId: order, amountIqd: 10000));
    database = (_) async => jsonResponse(credited());
    var statusReads = 0;
    await http.runWithClient(() async {
      await mount(tester, amount: 25000);
      await tester.ensureVisible(find.text('بەردەوامبە'));
      await tester.tap(find.text('بەردەوامبە'));
      await flush(tester);
      expect(find.text('سەرکەوتوو بوو'), findsOneWidget);
      expect(statusReads, 1);
      expect(await const FastPayPendingCheckoutStore().read(userA), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => mockTransport((request) async {
      expect(request.url.path, endsWith('/order-status'));
      statusReads++;
      return jsonResponse({'success': true});
    }));
  });

  testWidgets('late ledger QR becomes available without replaying create', (tester) async {
    await const FastPayPendingCheckoutStore().claim(userA,
        const FastPayPendingCheckout(orderId: order, amountIqd: 10000));
    await const FastPayPendingCheckoutStore().markDispatched(userA, order);
    var rowAvailable = false;
    database = (_) async => rowAvailable
        ? jsonResponse({'gateway_status': 'CREATED', 'gateway_amount': 10000,
            'qr_text': 'late-provider-token'})
        : http.Response('null', 200, headers: {'content-type': 'application/json'});
    await http.runWithClient(() async {
      await mount(tester);
      await tester.ensureVisible(find.text('بەردەوامبە'));
      await tester.tap(find.text('بەردەوامبە'));
      await flush(tester);
      expect(find.text('لینکی پارەدان بەردەست نییە'), findsNothing);
      rowAvailable = true;
      await tester.pump(const Duration(seconds: 3));
      await flush(tester);
      await tester.ensureVisible(find.text('کردنەوەی فاستپەی دووبارە'));
      await tester.tap(find.text('کردنەوەی فاستپەی دووبارە'));
      await flush(tester);
      // No launcher is installed in this fixture. Reaching the fallback proves
      // the original late QR was hydrated instead of leaving a no-op button.
      expect(find.text('لینکی پارەدان بەردەست نییە'), findsOneWidget);
      expect((await const FastPayPendingCheckoutStore().read(userA))!.orderId, order);
      await tester.pumpWidget(const SizedBox());
    }, () => mockTransport((request) async {
      expect(request.url.path, endsWith('/order-status'));
      return jsonResponse({'success': true});
    }));
  });

  testWidgets('legacy local expiry retains the original payment identity', (tester) async {
    await const FastPayPendingCheckoutStore().claim(userA,
        const FastPayPendingCheckout(orderId: order, amountIqd: 10000));
    await const FastPayPendingCheckoutStore().markDispatched(userA, order);
    database = (_) async => jsonResponse({'status': 'rejected',
        'gateway_status': 'EXPIRED', 'wallet_credited': false, 'gateway_amount': 10000});
    await http.runWithClient(() async {
      await mount(tester);
      await tester.ensureVisible(find.text('بەردەوامبە'));
      await tester.tap(find.text('بەردەوامبە'));
      await flush(tester);
      await tester.ensureVisible(find.text('پشتڕاستکردنەوەی پارەدان'));
      await tester.tap(find.text('پشتڕاستکردنەوەی پارەدان'));
      await flush(tester);
      expect((await const FastPayPendingCheckoutStore().read(userA))!.orderId, order);
      expect(find.text(order), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => mockTransport((request) async {
      expect(request.url.path, endsWith('/order-status'));
      return jsonResponse({'success': true});
    }));
  });

  testWidgets('switching accounts hides the previous checkout and stops polling', (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await mount(tester);
      expect(find.byKey(const ValueKey('fastpay-reference')), findsOneWidget);
      await restoreFixture(client, userB);
      await flush(tester);
      expect(find.byKey(const ValueKey('fastpay-reference')), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
    }, () => mockTransport((_) async { calls++; throw StateError('Unexpected request'); }));
  });
}
