import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

class ActualScreenPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override bool get disableShadows => false;
}
const permissionChannel=MethodChannel('flutter.baseflow.com/permissions/methods');
void main() {
  ActualScreenPaintBinding();
  final backend=ActualScreenBackend(),measurements=<String,Object>{};
  var permissionRequests=0;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await (FontLoader(kAppFont)..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(permissionChannel,(call)async {
      if(call.method=='checkPermissionStatus') return 1; // Already granted; actual Home must return before Firebase.
      permissionRequests++;
      throw StateError('unexpected_screen_fixture_permission_request');
    });
    await backend.initialize();
  });
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  tearDownAll(()async {
    await backend.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(permissionChannel,null);
    final file=File('build/ui-verification/actual-screen-measurements.json');file.parent.createSync(recursive:true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'evidence_type':'Flutter widget test of actual production screen classes',
      'fictional_backends':true,'native_device':false,'hosted_content':false,'permission_requests':permissionRequests,'cases':measurements}));
  });
  for(final width in [320.0,393.0,430.0,768.0]) {
    testWidgets('actual Home and Tools corresponding refresh phases at $width',(t)async {
      t.view.physicalSize=Size(width,1200);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      final offsets=<String,List<double>>{};
      for(final screen in ['home','tools']) {
        final key=GlobalKey(),handle=ProxoRefreshController(),repo=ActualToolsRepository();
        await t.pumpWidget(MaterialApp(theme:buildAppTheme(),home:RepaintBoundary(key:key,child:screen=='home'
          ?HomeScreen(refreshController:handle):ToolsScreen(repository:repo,refreshController:handle))));
        await t.pumpAndSettle();expect(t.takeException(),isNull);
        final scroll=find.descendant(of:find.byType(ProxoRefresh),matching:screen=='home'?find.byType(SingleChildScrollView):find.byType(ListView)).first;
        final initial=t.getTopLeft(scroll),element=t.element(scroll);
        final gate=Completer<void>();if(screen=='home'){backend.refreshGate=gate;}else{repo.refreshGate=gate;}
        final reads=screen=='home'?backend.reads['pa_ads']!:repo.reads;
        offsets[screen]=[];
        await _png(t,key,'actual-$screen-refresh-initial-${width.toInt()}');
        final refreshing=handle.refresh();unawaited(handle.refresh()); // Same-screen reentry must remain gated.
        await t.pump();
        for(final phase in [100,300]) {
          await t.pump(Duration(milliseconds:phase==100?100:200));
          offsets[screen]!.add(t.getTopLeft(scroll).dy-initial.dy);
          expect(handle.isRefreshing,true);expect(identical(element,t.element(scroll)),true);
          await _png(t,key,'actual-$screen-refresh-${phase}ms-${width.toInt()}');
        }
        // The original opening spring completes before issuing the fetch.
        await t.pump(const Duration(milliseconds:500));
        expect(screen=='home'?backend.reads['pa_ads']!:repo.reads,reads+1);
        gate.complete();await t.pumpAndSettle();await refreshing;
        expect(handle.isRefreshing,false);expect(t.getTopLeft(scroll),initial);expect(identical(element,t.element(scroll)),true);
        expect(t.takeException(),isNull);expect(permissionRequests,0);
        await _png(t,key,'actual-$screen-refresh-settled-${width.toInt()}');
        measurements['$screen-refresh-${width.toInt()}']={'offsets_100_300':offsets[screen]!,'settled_offset':t.getTopLeft(scroll).dy-initial.dy,
          'collection_reads_added':(screen=='home'?backend.reads['pa_ads']!:repo.reads)-reads,'same_scroll_element':true,'spinner_closed':true};
        backend.refreshGate=null;handle.dispose();
        await t.pumpWidget(const SizedBox.shrink());await t.pumpAndSettle();
      }
      expect(offsets['tools'],offsets['home']); // Actual screen integration, identical times and real shared motion.
    });
    testWidgets('actual Create Ad and ProxoLink shared notices and lifecycle at $width',(t)async {
      t.view.physicalSize=Size(width,1200);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      Map<String,Object>? appearance;
      for(final screen in ['ad','proxolink']) {
        final key=GlobalKey();
        await t.pumpWidget(MaterialApp(theme:buildAppTheme(),home:RepaintBoundary(key:key,child:screen=='ad'
          ?AdCreateScreen(repository:ActualAdRepository(),proxoCard:actualInvalidAdDraft())
          :ProxoLinkCreatePageScreen(repository:ActualToolsRepository()))));
        await t.pumpAndSettle();
        final button=find.byKey(ValueKey(screen=='ad'?'review-ad':'create-page-submit'));
        await t.ensureVisible(button);await t.pumpAndSettle();expect(screenNoticeCount(key.currentContext! as Element),0);
        await _png(t,key,'actual-$screen-error-initial-${width.toInt()}');
        await t.tap(button);await t.pump();
        final counts=<String,int>{};var previous=0;
        for(final phase in [100,400,4900,5100,5500]) {
          await t.pump(Duration(milliseconds:phase-previous));previous=phase;
          final root=key.currentContext! as Element;
          counts['${phase}ms']=screenNoticeCount(root);
          if(phase==400) {
            final actual=screenNoticeAppearance(root);
            if(appearance==null){appearance=actual;}else{expect(actual,appearance);}
          }
          if(phase<=4900)expect(counts['${phase}ms'],2);
          if(phase==5500)expect(counts['${phase}ms'],0);
          await _png(t,key,'actual-$screen-error-${phase}ms-${width.toInt()}');
          expect(t.takeException(),isNull);
        }
        measurements['$screen-error-${width.toInt()}']={'notice_counts':counts,'appearance':appearance!,'real_form_validation':true,
          'submit_input':'WidgetTester.tap','automatic_exit':true};
        await t.pumpWidget(const SizedBox.shrink());await t.pumpAndSettle();
      }
    });
  }
}
Future<void> _png(WidgetTester t,GlobalKey key,String name)async {
  await t.runAsync(()async {
    final image=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
    final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!.buffer.asUint8List();
    final file=File('build/ui-verification/$name.png');file.parent.createSync(recursive:true);file.writeAsBytesSync(bytes);image.dispose();
  });
}
