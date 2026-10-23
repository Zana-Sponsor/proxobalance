import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/widgets/ad_help_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Object? response;
  final platforms = <String>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://help-fixtures.invalid',
        anonKey: 'fictional-publishable-key',
        debug: false,
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(),
              'https://help-fixtures.invalid/rest/v1/rpc/pa_ad_help');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys, ['p_platform']);
          platforms.add(body['p_platform'] as String);
          return http.Response(jsonEncode(response), 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()));
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    response = null;
    platforms.clear();
  });

  Widget host(String platform) => MaterialApp(
      home: Scaffold(body: AdHelpNotice(key: UniqueKey(), platform: platform)));

  Future<void> settleRead(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('canonical SQL help message and video appear for either platform',
      (tester) async {
    for (final platform in ['META', 'TIKTOK']) {
      response = {
        'scope': platform.toLowerCase(),
        'active': true,
        'message': 'Admin configured help',
        'video_url': 'https://example.com/tutorial'
      };
      await tester.pumpWidget(host(platform));
      await settleRead(tester);
      expect(platforms.last, platform);
      expect(find.text('Admin configured help'), findsOneWidget);
      expect(find.text('بینینی فێرکاری'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(platforms, ['META', 'TIKTOK']);
  });

  testWidgets('disabled, empty and malformed responses leave no notice',
      (tester) async {
    for (final value in [
      null,
      {'active': false, 'message': 'Hidden help'},
      {'active': true, 'message': '  '},
      {'active': true, 'message': 42},
      {'enabled': true, 'body_ku': 'Unsupported contract'},
    ]) {
      response = value;
      await tester.pumpWidget(host('TIKTOK'));
      await settleRead(tester);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(Container), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('invalid video URL keeps the message without a tutorial action',
      (tester) async {
    response = {
      'scope': 'all',
      'active': true,
      'message': 'Shared help',
      'video_url': 'javascript:alert(1)'
    };
    await tester.pumpWidget(host('META'));
    await settleRead(tester);
    expect(find.text('Shared help'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
