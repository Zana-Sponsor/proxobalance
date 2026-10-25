import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/services/app_update_service.dart';
import 'package:proxo_app/widgets/app_update_host.dart';
import 'package:proxo_app/theme/app_theme.dart';

Map<String, Object?> policy(
        {bool required = false, int latest = 12, int revision = 1}) =>
    {
      'enabled': true,
      'release_verified': true,
      'published_at': '2020-01-01T00:00:00Z',
      'latest_build': latest,
      'minimum_build': 11,
      'latest_version': '1.0.12',
      'revision': revision,
      'required_enabled': required,
      'update_url':
          'https://play.google.com/store/apps/details?id=com.proxo.proxoapp',
      'message': 'وەشانی نوێ بەردەستە.',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  var clock = DateTime.utc(2026, 10, 26);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime.utc(2026, 10, 26);
  });
  test(
      'unverified, future, inconsistent and unsafe destinations cannot gate users',
      () {
    for (final raw in [
      {...policy(), 'enabled': false},
      {...policy(), 'release_verified': false},
      {...policy(), 'published_at': '2099-01-01T00:00:00Z'},
      {...policy(), 'message': 'x' * 601},
      {...policy(), 'message': 7},
      {...policy(), 'minimum_build': 13},
      {...policy(), 'latest_build': '12'},
      for (final url in [
        'javascript:alert(1)',
        'http://www.proxobalance.app/downloads/a.apk',
        'https://www.proxobalance.app.evil.invalid/downloads/a.apk',
        'https://evil@www.proxobalance.app/downloads/a.apk',
        'https://play.google.com/store/apps/details?id=another.app'
      ])
        {...policy(), 'update_url': url},
    ]) {
      expect(AppUpdatePolicy.parse(raw), isNull);
    }
    final current = AppUpdatePolicy.parse(policy(required: true))!;
    expect(current.isRequired(10), isTrue);
    expect(current.isRequired(11), isFalse);
    expect(current.isAvailable(12), isFalse);
    expect(current.isAvailable(13), isFalse);
  });
  test(
      'Later persists per installed build and revision, required overrides deferral',
      () async {
    final service = AppUpdateService(
        fetch: (_, __) async => policy(), preferences: prefs, now: () => clock);
    final release = (await service.load('android', 'stable'))!;
    await service.defer(release, 'android', 'stable', 10);
    expect(service.shouldOffer(release, 'android', 'stable', 10), isFalse);
    expect(service.shouldOffer(release, 'android', 'beta', 10), isTrue);
    expect(
        service.shouldOffer(AppUpdatePolicy.parse(policy(revision: 2))!,
            'android', 'stable', 10),
        isTrue);
    expect(
        service.shouldOffer(AppUpdatePolicy.parse(policy(required: true))!,
            'android', 'stable', 10),
        isTrue);
    clock = clock.add(const Duration(hours: 24));
    expect(service.shouldOffer(release, 'android', 'stable', 10), isTrue);
  });
  test(
      'verified cache handles outage, expires, and authoritative withdrawal clears it',
      () async {
    Object? response = policy(required: true);
    var fail = false;
    final service = AppUpdateService(
        preferences: prefs,
        now: () => clock,
        fetch: (_, __) async {
          if (fail) throw Exception('offline');
          return response;
        });
    expect(await service.load('android', 'stable'), isNotNull);
    fail = true;
    expect(await service.load('android', 'stable'), isNotNull);
    expect(await service.load('ios', 'stable'), isNull);
    clock = clock.add(const Duration(hours: 25));
    expect(await service.load('android', 'stable'), isNull);
    fail = false;
    response = null;
    expect(await service.load('android', 'stable'), isNull);
    fail = true;
    expect(await service.load('android', 'stable'), isNull);
  });
  testWidgets(
      'optional Later releases the form; required cannot be bypassed and withdrawn policy releases it',
      (t) async {
    final client = (await t.runAsync(() async => SupabaseClient(
        'https://update-fixture.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    Object? response = policy();
    final service =
        AppUpdateService(fetch: (_, __) async => response, preferences: prefs);
    var taps = 0;
    Widget host(Key key) => MaterialApp(
        theme: buildAppTheme(),
        builder: (_, child) => AppUpdateHost(
            key: key,
            client: client,
            service: service,
            installedBuild: 10,
            platform: 'android',
            launch: (_) async => false,
            child: child!),
        home: Scaffold(
            body: TextButton(
                onPressed: () => taps++,
                child: const Text('Application action'))));
    await t.pumpWidget(host(const ValueKey('optional')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('optional-update')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('update-later')));
    await t.pumpAndSettle();
    await t.tap(find.text('Application action'));
    expect(taps, 1);
    response = policy(required: true);
    await t.pumpWidget(host(const ValueKey('required')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('required-update')), findsOneWidget);
    expect(find.byKey(const ValueKey('update-later')), findsNothing);
    expect(find.text('Application action'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('required-update')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('update-now')));
    await t.pumpAndSettle();
    expect(find.text('بەستەرەکە نەکرایەوە. تکایە دووبارە هەوڵ بدەرەوە.'),
        findsOneWidget);
    response = null;
    await t.tap(find.byKey(const ValueKey('update-check-again')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('required-update')), findsNothing);
    expect(find.text('Application action'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(() async => client.dispose());
  });
}
