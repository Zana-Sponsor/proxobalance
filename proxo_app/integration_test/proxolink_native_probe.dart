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
const _widths = <int>[320, 375, 393, 430, 768];
const _failureChecks = <String, String>{
  'Rendered page checks failed': 'rendered_page_checks',
  'Animation did not advance': 'animation_motion',
  'Contact confirmation failed': 'contact_confirmation',
  'Cancel failed': 'contact_cancel',
  'Confirm failed': 'contact_confirm',
  'Demo TikTok action is not inert': 'inert_tiktok',
  'Preview URL changed': 'preview_url',
  'Navigation escaped preview': 'navigation_boundary',
  'Fresh comparison frame unavailable': 'fresh_frame',
  'Comparison requires density 160': 'pixel_density',
  'Screenshot evidence missing': 'screenshot_ack',
};

Directory get _files => Directory('${Directory.systemTemp.parent.path}/files');
File get _configuration => File('${_files.path}/proxolink-verification.json');
late Map<String, dynamic> _runtime;

Future<Map<String, dynamic>> _readConfiguration() async =>
    Map<String, dynamic>.from(jsonDecode(await _configuration.readAsString()) as Map);

Future<Map<String, dynamic>> _readMap(WebViewController controller, String script) async {
  final raw = await controller.runJavaScriptReturningResult(script);
  dynamic decoded = raw is String ? jsonDecode(raw) : raw;
  if (decoded is String) decoded = jsonDecode(decoded);
  return Map<String, dynamic>.from(decoded as Map);
}

Future<Map<String, dynamic>> _pageState(WebViewController controller) => _readMap(controller, r'''
    JSON.stringify({
      ready: document.readyState === 'complete',
      language: document.documentElement.lang,
      width: window.innerWidth,
      scroll: document.documentElement.scrollWidth,
      images: Array.from(document.images).every(i => i.complete && i.naturalWidth > 0),
      fonts: Array.from(document.fonts).some(f => ['R','Rabar','Rabar_021'].includes(f.family.replaceAll("'",'')) && f.status === 'loaded'),
      fontApplied: /\bR\b|Rabar/.test(getComputedStyle(document.body).fontFamily),
      icons: !!document.querySelector('.fa,.fab,.fas') && Array.from(document.fonts).some(f => /Awesome/.test(f.family) && f.status === 'loaded') && Array.from(document.querySelectorAll('.fa,.fab,.fas')).every(e => /Awesome/.test(getComputedStyle(e).fontFamily)),
      contact: !!document.getElementById('wa') && !!document.getElementById('ig') &&
         !document.getElementById('tg') && !document.querySelector('.fa-telegram'),
      sourcePlaceholders: document.body.textContent.includes('{{HANDLERS}}'),
      pixel: typeof window.ttq !== 'undefined',
      animations: document.getAnimations().filter(a => a.playState === 'running').map(a => ({name:a.animationName || '', time:a.currentTime}))
    })
  ''');

bool _visibleWebView(BuildContext context) {
  var found = false;
  void visit(Element element) {
    if (element.widget is WebViewWidget) found = true;
    element.visitChildElements(visit);
  }
  context.visitChildElements(visit);
  return found;
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
  final _viewportKey = GlobalKey();
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
    if (_index >= _styles.length * _widths.length) {
      await _write('proxolink-verification-results.json', _results);
      if (mounted) setState(() { _complete = true; _status = '40/40 live preview cases completed'; });
      return;
    }
    final style = _styles[_index ~/ _widths.length];
    final width = _widths[_index % _widths.length];
    if (mounted) setState(() => _status = 'Loading $style at $width dp (${_index + 1}/40)…');
  }

  Future<void> _verify(String style, int width, WebViewController controller) async {
    final caseId = '$style-$width';
    Map<String, dynamic>? state;
    try {
      for (var attempt = 0; attempt < 120; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        try {
          state = await _pageState(controller);
          if (state['ready'] == true && state['fonts'] == true &&
              state['images'] == true && state['contact'] == true) break;
        } catch (_) {}
      }
      if (state == null || state['ready'] != true || state['fonts'] != true || state['fontApplied'] != true ||
          state['images'] != true || state['icons'] != true ||
          state['contact'] != true || state['language'] != 'ku' ||
          (state['scroll'] as num) > (state['width'] as num) + 1 ||
          ((state['width'] as num) - width).abs() > 1 ||
          !mounted || !_visibleWebView(context) ||
          state['sourcePlaceholders'] != false || state['pixel'] != false) {
        throw StateError('Rendered page checks failed');
      }

      final animations = state['animations'] as List;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final after = (await _pageState(controller))['animations'] as List;
      final moving = animations.any((a) => after.any((b) =>
          a['name'] == b['name'] && a['time'] is num && b['time'] is num &&
          (b['time'] as num) > (a['time'] as num) + 100));
      if (animations.isEmpty || !moving) throw StateError('Animation did not advance');

      // Observe original handlers and suppress window.open only in this probe.
      // Original modal visuals/functions remain in place; no real call/message
      // is sent from demo previews and no advertisement is created or visited.
      await controller.runJavaScript(r'''
        window.__proxoProbe = {args:null,opened:null,ask:window.askConfirm,open:window.open};
        window.askConfirm = function(type,url,label) {
          window.__proxoProbe.args = {type,url};
          return window.__proxoProbe.ask(type,url,label);
        };
        window.open = function(url) { window.__proxoProbe.opened = url; return null; };
      ''');
      // Demo destinations are inert; backend tests verify real destinations.
      const destinations = {
        'wa': ['whatsapp', '#'],
        'vb': ['viber', '#'],
        'ig': ['instagram', '#'],
        'ph': ['phone', '#'],
        'as': ['asya', '#'],
      };
      const cancel = "Array.from(document.querySelectorAll('[onclick]')).find(e=>/closeMod/.test(e.getAttribute('onclick')) && e.getBoundingClientRect().height>0)";
      const confirm = "Array.from(document.querySelectorAll('[onclick]')).find(e=>e.getAttribute('onclick')==='goLink()' && e.getBoundingClientRect().height>0)";
      for (final entry in destinations.entries) {
        await controller.runJavaScript("document.getElementById('${entry.key}').click()");
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final opened = await _readMap(controller, '''
          JSON.stringify({modal:!!($cancel),confirm:!!($confirm),
            destination:window.__proxoProbe.args.url===${jsonEncode(entry.value[1])},
            type:window.__proxoProbe.args.type===${jsonEncode(entry.value[0])}})
        ''');
        if (opened.values.any((value) => value != true)) throw StateError('Contact confirmation failed');
        await controller.runJavaScript('($cancel).click()');
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final canceled = await _readMap(controller, 'JSON.stringify({closed:!($cancel),unlaunched:window.__proxoProbe.opened===null})');
        if (canceled.values.any((value) => value != true)) throw StateError('Cancel failed');
        await controller.runJavaScript("document.getElementById('${entry.key}').click()");
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await controller.runJavaScript('($confirm).click()');
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final confirmed = await _readMap(controller, '''JSON.stringify({closed:!($cancel),
          destination:window.__proxoProbe.opened===null || window.__proxoProbe.opened===${jsonEncode(entry.value[1])}})''');
        if (confirmed.values.any((value) => value != true)) throw StateError('Confirm failed');
        await controller.runJavaScript('window.__proxoProbe.opened=null');
      }
      final tiktok = await controller.runJavaScriptReturningResult(
          "Array.from(document.links).some(a=>a.textContent.includes('@proxo_iq') && a.getAttribute('href')==='#')");
      if (tiktok.toString() != 'true') throw StateError('Demo TikTok action is not inert');
      await controller.runJavaScript('window.askConfirm=window.__proxoProbe.ask;window.open=window.__proxoProbe.open;delete window.__proxoProbe');
      final configuration = await _readConfiguration();
      final expected = await controller.currentUrl();
      final actual = expected == null ? null : Uri.tryParse(expected);
      if (actual == null || actual.origin != configuration['origin'] ||
          actual.path != '/contact-preview' || !actual.queryParameters.containsKey('token')) {
        throw StateError('Preview URL changed');
      }
      for (final destination in ['https://example.invalid/',
        '${configuration['origin']}/api/contact-templates',
        '${configuration['origin']}/contact-preview?token=invalid',
        'file:///etc/passwd']) {
        await controller.runJavaScript('window.location.href=${jsonEncode(destination)}');
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (await controller.currentUrl() != expected) throw StateError('Navigation escaped preview');
      }

      // Reload after modal checks: the original modal scripts suspend some
      // decorations. Compare fresh documents in identical initial states.
      await controller.reload();
      var fresh = false;
      for (var attempt = 0; attempt < 90; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final page = await _pageState(controller);
        if (page['ready'] == true && page['fonts'] == true &&
            page['images'] == true && page['icons'] == true &&
            await controller.currentUrl() == expected) { fresh = true; break; }
      }
      if (!fresh) throw StateError('Fresh comparison frame unavailable');
      await controller.runJavaScript('window.scrollTo(0,0);document.getAnimations().forEach(a=>{a.pause();a.currentTime=0;});');
      if (mounted) setState(() => _status = '$caseId passed; comparing pixels…');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final box = _viewportKey.currentContext!.findRenderObject()! as RenderBox;
      final origin = box.localToGlobal(Offset.zero);
      if (MediaQuery.devicePixelRatioOf(context) != 1) throw StateError('Comparison requires density 160');
      final crop = <String, int>{
        // Android positions its platform view at integer coordinates. At an
        // odd centered width, rounding .5 clipped one real column and included
        // a Flutter-white column in the executed comparison. Truncate the
        // positive screen origin to the actual native surface boundary.
        'left': origin.dx.floor(), 'top': origin.dy.floor(),
        'width': box.size.width.round(), 'height': box.size.height.round(),
        'css_height': box.size.height.round(),
      };
      _results[caseId] = {
        'passed': true,
        'width': state['width'],
        'font_loaded': true,
        'images_loaded': true,
        'icons_loaded': true,
        'animation_checked': true,
        'animation_count': animations.length,
        'contact_destinations': true,
        'confirmation': true,
        'navigation_blocked': true,
      };
      await _write('proxolink-verification-case.json', {'style': style, 'width': width, 'viewport': crop});
      final ack = File('${_files.path}/proxolink-verification-ack');
      var acknowledged = false;
      for (var attempt = 0; attempt < 120; attempt++) {
        if (await ack.exists() && (await ack.readAsString()).trim() == caseId) { acknowledged = true; break; }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!acknowledged) throw StateError('Screenshot evidence missing');
      if (await ack.exists()) await ack.delete();
      if (!mounted) return;
      setState(() => _index++);
      await _runCurrent();
    } catch (error) {
      final failure = error is StateError
          ? _failureChecks[error.message] ?? 'unclassified_native_check'
          : 'unclassified_native_check';
      // Fixed identifiers and observed booleans/numbers only, never raw
      // platform errors, capabilities, credentials or page text.
      _results[caseId] = {
        'passed': false, 'failed_check': failure,
        'width': state?['width'],
        'font_loaded': state?['fonts'],
        'font_applied': state?['fontApplied'],
        'images_loaded': state?['images'],
        'icons_loaded': state?['icons'],
      };
      // One failed case must not prevent the other requested cases from
      // executing. The existing final native/pixel gate still rejects it.
      if (!mounted) return;
      setState(() => _index++);
      await _runCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _styles.length * _widths.length;
    final current = _index < total ? _index : total - 1;
    final style = _styles[current ~/ _widths.length];
    final width = _widths[current % _widths.length];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.page,
        appBar: AppBar(title: const Text('ProxoLink')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: (width + 72).toDouble()),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AdFormSection(
                    title: 'پێشبینینی ڕاستەوخۆ',
                    subtitle: _status,
                    child: SizedBox(
                      key: _viewportKey,
                      height: MediaQuery.sizeOf(context).height * 0.68,
                      child: _complete
                          ? Center(child: Text(_status, style: AdUi.heading(context)))
                          : ProxoLinkPreview(
                              key: ValueKey('$style-$width'),
                              requestHeaders: Map<String, String>.from(
                                _runtime['headers'] as Map,
                              ),
                              loadUrl: () async {
                                final current = await _readConfiguration();
                                return Uri.parse((current['previews'] as Map)[style] as String);
                              },
                              onControllerCreated: (controller) => _verify(style, width, controller),
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
