import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/widgets/proxolink_design_selector.dart';
import 'proxolink_native_tools_journey.dart';
import 'proxolink_native_actual_screens.dart';

/// Real Android input and real production form. Repository writes are rejected
/// by the read-only fixture. This supplements the unchanged legacy WebView gate.
class NativeProxoLinkCreateChooser extends StatefulWidget {
  final ProxoLinkRepository repository;
  final Future<void> Function(String, Object) write;
  final Future<void> Function() onComplete;
  final int Function() previewRequests;
  const NativeProxoLinkCreateChooser({super.key, required this.repository,
    required this.write, required this.onComplete, required this.previewRequests});
  @override
  State<NativeProxoLinkCreateChooser> createState() => _CreateChooserState();
}

class _CreateChooserState extends State<NativeProxoLinkCreateChooser> {
  final _results = <String, Object>{};
  ProxoPageType _type = ProxoPageType.contact;
  bool _chooserDone = false, _browserDone = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }
  List<Element> _elements(bool Function(Widget) predicate, {Element? root}) {
    final found = <Element>[];
    void visit(Element e) {
      if (predicate(e.widget)) found.add(e);
      e.visitChildren(visit);
    }
    (root ?? context as Element).visitChildren(visit);
    return found;
  }
  Future<Element> _wait(bool Function(Widget) predicate) async {
    for (var i = 0; i < 200; i++) {
      final found = _elements(predicate);
      if (found.length == 1) return found.single;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('create_chooser_element_missing');
  }
  Future<void> _ack(String id) async {
    final file = File('${Directory.systemTemp.parent.path}/files/proxolink-create-chooser-ack');
    for (var i = 0; i < 120; i++) {
      if (await file.exists() && (await file.readAsString()).trim() == id) {
        await file.delete(); return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('create_chooser_ack');
  }
  Future<List<double>> _tap(Element e, String id, String phase) async {
    await Scrollable.ensureVisible(e, alignment: .5);
    await WidgetsBinding.instance.endOfFrame;
    final box = e.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final center = box.localToGlobal(box.size.center(Offset.zero));
    if (box.size.isEmpty || center.dx < 0 || center.dx >= 1200 ||
        center.dy < 0 || center.dy >= 1900 || MediaQuery.devicePixelRatioOf(context) != 1) {
      throw StateError('create_chooser_tap_bounds');
    }
    await widget.write('proxolink-create-chooser-request.json',
      {'id': id, 'phase': phase, 'x': center.dx.round(), 'y': center.dy.round()});
    await _ack(id);
    return [origin.dx, origin.dy, box.size.width, box.size.height];
  }
  Future<void> _run() async {
    for (final type in ProxoPageType.values) {
      if (!mounted) return;
      setState(() => _type = type);
      await WidgetsBinding.instance.endOfFrame;
      Object? setupError;
      try {
        await _wait((w) => w is ProxoLinkDesignSelector && w.templates.length == 4);
        await _tap(await _wait((w) => w.key == ValueKey('create-type-${type.key}')),
          'create-chooser-setup-${type.key}', 'setup');
      } catch (error) { setupError = error; }
      // Always changes initial pill selection; no matching-frame search.
      for (final style in ['pill-mint', 'pill-dark', 'pill-white', 'pill']) {
        final id = 'create-chooser-${type.key}-$style';
        try {
          if (setupError != null) throw StateError('create_chooser_setup');
          final selector = (await _wait((w) => w is ProxoLinkDesignSelector)).widget as ProxoLinkDesignSelector;
          if (selector.pageType != type || selector.selectedKey == style) throw StateError('create_chooser_selection');
          final before = widget.previewRequests();
          final card = await _wait((w) => w.key == ValueKey('proxolink-design-$style'));
          final image = (await _wait((w) => w is Image && w.key == ValueKey('proxolink-thumbnail-${type.key}-$style'))).widget as Image;
          Object? imageError;
          if (!mounted) return;
          await precacheImage(image.image, context, onError: (error, _) => imageError = error);
          if (imageError != null) throw StateError('create_chooser_thumbnail');
          final bounds = await _tap(card, id, 'tap');
          await WidgetsBinding.instance.endOfFrame;
          final selected = (await _wait((w) => w is ProxoLinkDesignSelector)).widget as ProxoLinkDesignSelector;
          final raw = _elements((w) => w is RawImage, root: card);
          if (selected.selectedKey != style || selected.pageType != type) throw StateError('create_chooser_selection');
          if (raw.length != 1 || (raw.single.findRenderObject() as RenderImage).image == null) throw StateError('create_chooser_thumbnail');
          final providers = await widget.repository.providers();
          final labels = _elements((w) => w is TextField).map((e) => (e.widget as TextField).decoration?.labelText).toSet();
          if (!providers.where((p) => p.pageType == type.key).every((p) => labels.contains(p.label)) ||
              providers.where((p) => p.pageType != type.key).any((p) => labels.contains(p.label))) throw StateError('create_chooser_providers');
          if (_elements((w) => w is WebViewWidget).isNotEmpty || widget.previewRequests() != before) throw StateError('create_chooser_preview');
          await widget.write('proxolink-create-chooser-request.json', {'id': id, 'phase': 'capture'});
          await _ack(id);
          _results[id] = {'passed': true, 'form_screen': true, 'type_match': true,
            'thumbnail_decoded': true, 'selection_changed': true, 'selected_state': true,
            'provider_type_match': true, 'no_webview': true, 'no_preview_request': true,
            'native_input': true, 'captured': true, 'width': bounds[2].round(), 'tap_bounds': bounds};
        } catch (error) {
          const allowed = {'create_chooser_setup', 'create_chooser_element_missing', 'create_chooser_ack',
            'create_chooser_tap_bounds', 'create_chooser_selection', 'create_chooser_thumbnail',
            'create_chooser_providers', 'create_chooser_preview'};
          _results[id] = {'passed': false, 'failed_check': error is StateError && allowed.contains(error.message)
            ? error.message : 'create_chooser_unclassified'};
        }
        await widget.write('proxolink-create-chooser-results.json', _results);
      }
    }
    if(mounted)setState(()=>_chooserDone=true);
  }
  @override
  Widget build(BuildContext context) => _browserDone ? NativeActualScreensJourney(write:widget.write,onComplete:widget.onComplete)
    : _chooserDone ? NativeToolsBrowserJourney(write:widget.write,onComplete:()async{if(mounted)setState(()=>_browserDone=true);}) : Center(child: SizedBox(width: 430,
    child: ProxoLinkCreatePageScreen(key: ValueKey('native-create-form-${_type.key}'), repository: widget.repository)));
}
