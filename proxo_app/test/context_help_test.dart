import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/services/context_help_service.dart';
import 'package:proxo_app/widgets/form_help_actions.dart';
import 'package:proxo_app/theme/app_theme.dart';

void main() {
  test('tutorial reads only its admin-configured slot', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://help-fixture.invalid', 'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode({'value': 'https://youtu.be/example'}), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    expect(
        await ContextHelpService(client: client).tutorialFor('ad_video_code'),
        Uri.parse('https://youtu.be/example'));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.queryParameters['key'],
        'eq.tutorial_ad_video_code_url');
    await client.dispose();
  });
  test(
      'tutorial destination rejects unsafe or malformed schemes and credentials',
      () {
    for (final value in [
      null,
      '',
      'javascript:alert(1)',
      'file:///tmp/example',
      'http://example.com',
      'https://user:pass@example.com/video',
      'https://exa mple.com'
    ]) {
      expect(ContextHelpService.validVideoUrl(value), isNull, reason: '$value');
    }
    expect(
        ContextHelpService.validVideoUrl(
            'https://www.youtube.com/shorts/example'),
        isNotNull);
  });
  Widget host(Widget child, {double scale = 1}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(body: SingleChildScrollView(child: child)));
  for (final config in [(393.0, 1.0), (280.0, 2.0)]) {
    testWidgets('example opens locally and preserves the form $config',
        (t) async {
      t.view.physicalSize = Size(config.$1, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final input = TextEditingController(text: 'my retained video link');
      var loads = 0;
      await t.pumpWidget(host(
          Column(children: [
            TextField(controller: input),
            FormHelpActions(
                helpKey: 'ad_video_link',
                exampleAsset: 'assets/images/ad_video_link_example.png',
                exampleCaption:
                    'سکرینشۆتی خانەی بەستەر لە ئەپی Proxo؛ بەستەری ڤیدیۆی خۆت دابنێ',
                sampleValue:
                    'https://www.tiktok.com/@scout2015/video/6718335390845095173',
                loadTutorial: (_) async {
                  loads++;
                  return null;
                })
          ]),
          scale: config.$2));
      await t.runAsync(() => precacheImage(
          ResizeImage.resizeIfNeeded(720, null,
              const AssetImage('assets/images/ad_video_link_example.png')),
          t.element(find.byType(FormHelpActions))));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('help-example-ad_video_link')));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(loads, 0, reason: 'Viewing an example must not wait for Supabase');
      Navigator.of(t.element(find.byType(Dialog))).pop();
      await t.pumpAndSettle();
      expect(input.text, 'my retained video link');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      input.dispose();
    });
  }
  testWidgets('page example uses the bundled page image', (t) async {
    await t.pumpWidget(host(FormHelpActions(
        helpKey: 'page_creation',
        exampleAsset: 'assets/proxolink_thumbnails/contact-pill.png',
        loadTutorial: (_) async => null)));
    await t.tap(find.byKey(const ValueKey('help-example-page_creation')));
    await t.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'tutorial coalesces taps and launches the configured destination once',
      (t) async {
    final pending = Completer<Uri?>();
    var loads = 0;
    final opened = <Uri>[];
    await t.pumpWidget(host(FormHelpActions(
        helpKey: 'ad_video_code',
        loadTutorial: (_) {
          loads++;
          return pending.future;
        },
        openUrl: (uri) async {
          opened.add(uri);
          return true;
        })));
    final button = find.byKey(const ValueKey('help-tutorial-ad_video_code'));
    await t.tap(button);
    await t.tap(button);
    await t.pump();
    expect(loads, 1);
    pending.complete(Uri.parse('https://youtu.be/configured'));
    await t.pumpAndSettle();
    expect(opened, [Uri.parse('https://youtu.be/configured')]);
    expect(t.takeException(), isNull);
  });
  testWidgets('unpublished tutorial does not open a fake video', (t) async {
    var opened = false;
    await t.pumpWidget(host(FormHelpActions(
        helpKey: 'ad_video_code',
        loadTutorial: (_) async => null,
        openUrl: (_) async {
          opened = true;
          return true;
        })));
    await t.tap(find.byKey(const ValueKey('help-tutorial-ad_video_code')));
    await t.pumpAndSettle();
    expect(opened, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
  });
  testWidgets(
      'closing the screen while its tutorial is loading does not launch or update disposed state',
      (t) async {
    final pending = Completer<Uri?>();
    var opened = false;
    await t.pumpWidget(host(FormHelpActions(
        helpKey: 'ad_video_code',
        loadTutorial: (_) => pending.future,
        openUrl: (_) async {
          opened = true;
          return true;
        })));
    await t.tap(find.byKey(const ValueKey('help-tutorial-ad_video_code')));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    pending.complete(Uri.parse('https://youtu.be/example'));
    await t.pump();
    expect(opened, isFalse);
    expect(t.takeException(), isNull);
  });
}
