import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';

const _styles = <String>[
  'dark',
  'light',
  'classic',
  'pill',
  'card',
  'neon',
  'zoom',
  'banner',
];

Directory get _files => Directory('${Directory.systemTemp.parent.path}/files');
File get _configuration => File('${_files.path}/proxolink-verification.json');
late Map<String, dynamic> _runtime;

Future<Map<String, dynamic>> _readConfiguration() async =>
    Map<String, dynamic>.from(jsonDecode(await _configuration.readAsString()) as Map);

Future<Map<String, dynamic>> _pageState(WebViewController controller) async {
  final raw = await controller.runJavaScriptReturningResult(r'''
    JSON.stringify({
      ready: document.readyState === 'complete',
      language: document.documentElement.lang,
      width: window.innerWidth,
      scroll: document.documentElement.scrollWidth,
      images: Array.from(document.images).every(i => i.complete && i.naturalWidth > 0),
      fonts: Array.from(document.fonts).some(f => ['R','Rabar','Rabar_021'].includes(f.family.replaceAll("'",'')) && f.status === 'loaded'),
      icons: Array.from(document.styleSheets).some(s => /font-awesome/i.test(s.href || '')) || !!document.querySelector('.fa,.fab,.fas'),
      contact: !!document.getElementById('wa'),
      sourcePlaceholders: document.body.textContent.includes('{{HANDLERS}}'),
      pixel: typeof window.ttq !== 'undefined'
    })
  ''');
  dynamic decoded = raw is String ? jsonDecode(raw) : raw;
  if (decoded is String) decoded = jsonDecode(decoded);
  return Map<String, dynamic>.from(decoded as Map);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _runtime = await _readConfiguration();
  runApp(const _NativeProbeApp());
}

class _NativeProbeApp extends StatelessWidget {
  const _NativeProbeApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _NativeProbeScreen(),
      );
}

class _NativeProbeScreen extends StatefulWidget {
  const _NativeProbeScreen();

  @override
  State<_NativeProbeScreen> createState() => _NativeProbeScreenState();
}

class _NativeProbeScreenState extends State<_NativeProbeScreen> {
  final _results = <String, dynamic>{};
  int _index = 0;
  String _status = 'Preparing secure live previews…';
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, _runCurrent);
  }

  Future<void> _write(String name, Object value) async {
    await _files.create(recursive: true);
    await File('${_files.path}/$name').writeAsString(jsonEncode(value));
  }

  Future<void> _runCurrent() async {
    if (_index >= _styles.length) {
      await _write('proxolink-verification-results.json', _results);
      if (mounted) setState(() { _complete = true; _status = '8/8 live previews verified'; });
      return;
    }
    if (mounted) setState(() => _status = 'Loading ${_styles[_index]} (${_index + 1}/8)…');
  }

  Future<void> _verify(String style, WebViewController controller) async {
    try {
      Map<String, dynamic>? state;
      for (var attempt = 0; attempt < 120; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        try {
          state = await _pageState(controller);
          if (state['ready'] == true && state['fonts'] == true &&
              state['images'] == true && state['contact'] == true) break;
        } catch (_) {}
      }
      if (state == null || state['ready'] != true || state['fonts'] != true ||
          state['images'] != true || state['icons'] != true ||
          state['contact'] != true || state['language'] != 'ku' ||
          (state['scroll'] as num) > (state['width'] as num) ||
          state['sourcePlaceholders'] != false || state['pixel'] != false) {
        throw StateError('Rendered page checks failed');
      }

      await controller.runJavaScript("document.getElementById('wa').click()");
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final modal = await controller.runJavaScriptReturningResult(
        "Array.from(document.querySelectorAll('[onclick]')).some(e=>/closeMod/.test(e.getAttribute('onclick')) && e.getBoundingClientRect().height>0)",
      );
      if (modal.toString() != 'true') throw StateError('Confirmation did not open');
      await controller.runJavaScript(
        "Array.from(document.querySelectorAll('[onclick]')).find(e=>/closeMod/.test(e.getAttribute('onclick'))).click()",
      );
      final configuration = await _readConfiguration();
      await controller.runJavaScript("window.location.href='https://example.invalid/'");
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!(await controller.currentUrl())!.startsWith(configuration['origin'] as String)) {
        throw StateError('Navigation escaped the preview origin');
      }

      _results[style] = {
        'passed': true,
        'width': state['width'],
        'font_loaded': true,
        'images_loaded': true,
        'icons_loaded': true,
        'confirmation': true,
        'navigation_blocked': true,
      };
      await _write('proxolink-verification-case.json', {'style': style});
      if (mounted) setState(() => _status = '$style passed; capturing evidence…');
      final ack = File('${_files.path}/proxolink-verification-ack');
      for (var attempt = 0; attempt < 120; attempt++) {
        if (await ack.exists() && (await ack.readAsString()).trim() == style) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (await ack.exists()) await ack.delete();
      if (!mounted) return;
      setState(() => _index++);
      await _runCurrent();
    } catch (error) {
      _results[style] = {'passed': false, 'error': error.runtimeType.toString()};
      await _write('proxolink-verification-results.json', _results);
      if (mounted) setState(() { _complete = true; _status = '$style failed'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _index < _styles.length ? _styles[_index] : _styles.last;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.page,
        appBar: AppBar(title: const Text('ProxoLink')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AdFormSection(
                    title: 'پێشبینینی ڕاستەوخۆ',
                    subtitle: _status,
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.68,
                      child: _complete
                          ? Center(child: Text(_status, style: AdUi.heading(context)))
                          : ProxoLinkPreview(
                              key: ValueKey(style),
                              requestHeaders: Map<String, String>.from(
                                _runtime['headers'] as Map,
                              ),
                              loadUrl: () async {
                                final current = await _readConfiguration();
                                return Uri.parse((current['previews'] as Map)[style] as String);
                              },
                              onControllerCreated: (controller) => _verify(style, controller),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
