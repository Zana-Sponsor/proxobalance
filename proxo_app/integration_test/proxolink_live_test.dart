import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';

// Runtime-only configuration is provisioned onto the disposable emulator.
// No preview token, user session, or protection credential is compiled,
// committed, or uploaded to GitHub. The file is refreshed outside the app.
Future<Map<String, dynamic>>
runtimeConfiguration() async => Map<String, dynamic>.from(
  jsonDecode(
    await File(
      '${Directory.systemTemp.parent.path}/files/proxolink-verification.json',
    ).readAsString(),
  ) as Map,
);

Future<Map<String, dynamic>> pageState(WebViewController controller) async {
  final raw = await controller.runJavaScriptReturningResult('''
    JSON.stringify({
      ready: document.readyState === 'complete',
      language: document.documentElement.lang,
      width: window.innerWidth,
      scroll: document.documentElement.scrollWidth,
      images: Array.from(document.images).every(i => i.complete && i.naturalWidth > 0),
      fonts: Array.from(document.fonts).some(f => ['R','Rabar','Rabar_021'].includes(f.family.replaceAll("'",'')) && f.status === 'loaded'),
      contact: !!document.getElementById('wa'),
      sourcePlaceholders: document.body.textContent.includes('{{HANDLERS}}'),
      pixel: typeof window.ttq !== 'undefined'
    })
  ''');
  dynamic decoded = raw is String ? jsonDecode(raw) : raw;
  if (decoded is String) decoded = jsonDecode(decoded);
  return Map<String, dynamic>.from(decoded as Map);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final results = <String, dynamic>{};
  for (final style in [
    'dark',
    'light',
    'classic',
    'pill',
    'card',
    'neon',
    'zoom',
    'banner',
  ]) {
    testWidgets('live native WebView renders $style securely', (tester) async {
      final configuration = await runtimeConfiguration();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('ProxoLink')),
            body: ProxoLinkPreview(
              key: ValueKey(style),
              requestHeaders: Map<String, String>.from(
                configuration['headers'] as Map,
              ),
              loadUrl: () async {
                final current = await runtimeConfiguration();
                return Uri.parse(current['previews'][style] as String);
              },
            ),
          ),
        ),
      );
      WebViewController? controller;
      Map<String, dynamic>? state;
      for (var attempt = 0; attempt < 90; attempt++) {
        await tester.pump(const Duration(seconds: 1));
        final views = find.byType(WebViewWidget);
        if (views.evaluate().isNotEmpty) {
          controller = tester.widget<WebViewWidget>(views.first).controller;
          try {
            state = await pageState(controller);
            if (state['ready'] == true &&
                state['fonts'] == true &&
                state['images'] == true &&
                state['contact'] == true)
              break;
          } catch (_) {}
        }
      }
      expect(controller, isNotNull);
      expect(state?['ready'], isTrue);
      expect(state?['fonts'], isTrue);
      expect(state?['images'], isTrue);
      expect(state?['contact'], isTrue);
      expect(state?['language'], 'ku');
      expect(state?['scroll'], lessThanOrEqualTo(state?['width'] as num));
      expect(state?['sourcePlaceholders'], isFalse);
      expect(state?['pixel'], isFalse);
      // Exercise the original JavaScript confirmation without launching a
      // real contact app or recording an advertisement event.
      await controller!.runJavaScript("document.getElementById('wa').click()");
      await tester.pump(const Duration(milliseconds: 300));
      final opened = await controller.runJavaScriptReturningResult(
        "Array.from(document.querySelectorAll('[onclick]')).some(e=>/closeMod/.test(e.getAttribute('onclick')) && e.getBoundingClientRect().height>0)",
      );
      expect(opened.toString(), 'true');
      await controller.runJavaScript(
        "Array.from(document.querySelectorAll('[onclick]')).find(e=>/closeMod/.test(e.getAttribute('onclick'))).click()",
      );
      // Same-origin external navigation is rejected by the actual widget's
      // navigation delegate; no unchecked destination replaces the preview.
      await controller.runJavaScript(
        "window.location.href='https://example.invalid/'",
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        await controller.currentUrl(),
        startsWith(configuration['origin'] as String),
      );
      results[style] = {
        'passed': true,
        'width': state!['width'],
        'font_loaded': true,
        'images_loaded': true,
        'confirmation': true,
        'navigation_blocked': true,
      };
      final files = Directory('${Directory.systemTemp.parent.path}/files');
      await File('${files.path}/proxolink-verification-case.json')
          .writeAsString(jsonEncode({'style': style}));
      for (var wait = 0; wait < 40; wait++) {
        final ack = File('${files.path}/proxolink-verification-ack');
        if (await ack.exists() && await ack.readAsString() == style) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
  tearDownAll(() async {
    binding.reportData = {'native_webview': results};
    final directory = Directory('${Directory.systemTemp.parent.path}/files');
    await File('${directory.path}/proxolink-verification-results.json')
        .writeAsString(jsonEncode(results));
  });
}
