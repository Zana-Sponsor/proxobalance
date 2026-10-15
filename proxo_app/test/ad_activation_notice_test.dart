import 'package:proxo_app/theme/app_theme.dart' show buildAppTheme;
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/ad_activation_notice.dart';
import 'package:proxo_app/theme/app_locale.dart';

class NoticePaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override bool get disableShadows => false;
}

void main() {
  NoticePaintBinding();
  setUpAll(() async {
    final fonts = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for(final font in fonts) {
      final loader=FontLoader(font['family'] as String);
      for(final file in font['fonts'] as List) { loader.addFont(rootBundle.load(file['asset'] as String)); }
      await loader.load();
    }
  });
  final now = DateTime.utc(2026,10,14,12);
  const adId = '11111111-2222-4333-8444-555555555555';
  Map<String,dynamic> row({int minutes = 0, String type = 'ad_active', String owner = 'owner'}) => {
    'id':'event', 'user_id':owner, 'type':type, 'meta':{'ad_id':adId},
    'created_at':now.subtract(Duration(minutes:minutes)).toIso8601String(),
  };
  test('only owner activation events from the last five minutes qualify', () {
    expect(AdActivationEvent.parse(row(),userId:'owner',now:now)?.adId,adId);
    expect(AdActivationEvent.parse(row(minutes:5),userId:'owner',now:now),isNotNull);
    for (final invalid in [row(minutes:6),row(minutes:-1),row(type:'ad_metrics'),row(owner:'other')]) {
      expect(AdActivationEvent.parse(invalid,userId:'owner',now:now),isNull);
    }
    expect(AdActivationEvent.parse({...row(),'meta':{'ad_id':'------------------------------------'}},userId:'owner',now:now),isNull);
  });
  for(final config in [(280.0, 2.0), (393.0, 1.0)]) {
  for(final language in ['ckb','ar','kmr']) {
    testWidgets('notice is compact and readable at $config in $language; both actions work', (t) async {
      final (width, scale) = config;
      t.view.physicalSize = Size(width*2,1704); t.view.devicePixelRatio=2;
      addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      ProxoLocale.current.value=Locale(language);
      addTearDown(() => ProxoLocale.current.value=ProxoLocale.kurdishSorani);
      var open=0,close=0;
      final boundaryKey=GlobalKey();
      await t.pumpWidget(MaterialApp(theme: buildAppTheme().copyWith(scaffoldBackgroundColor: Colors.white), home: ProxoLocaleScope(child: MediaQuery(
        data: MediaQueryData(size:Size(width,852),textScaler:TextScaler.linear(scale)),
        child: RepaintBoundary(key:boundaryKey,child:Scaffold(body:Padding(padding:const EdgeInsets.all(12),child:AdActivationNotice(
          adTitle:'Campaign 123', onOpen:()=>open++,onClose:()=>close++))))))));
      await t.pumpAndSettle();
      expect(t.takeException(),isNull);
      expect(t.getSize(find.byType(AdActivationNotice)).height, lessThan(scale > 1 ? 400 : 200));
      await t.runAsync(() async {
        final boundary=boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final shot=await boundary.toImage(pixelRatio:2);
        final data=await shot.toByteData(format:ui.ImageByteFormat.png);
        Directory('build/polish-evidence').createSync(recursive:true);
        await File('build/polish-evidence/activation-$language-${width.toInt()}-s$scale-d2.0.png').writeAsBytes(data!.buffer.asUint8List());shot.dispose();
      });
      final button=find.byType(TextButton), closeButton=find.byType(IconButton);
      expect(t.getSize(button).height,greaterThanOrEqualTo(48));
      expect(t.getSize(closeButton).height,greaterThanOrEqualTo(48));
      await t.tap(button); await t.tap(closeButton);
      expect(open,1);expect(close,1);
    });
  }
}
}
