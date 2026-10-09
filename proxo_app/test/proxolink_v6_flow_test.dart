import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/models/proxolink_design.dart';
import 'package:proxo_app/widgets/proxolink_design_selector.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'proxolink_flow_test.dart' show FakeProxoLink;
class V6Repository extends FakeProxoLink {
 final drafts=<Map<String,dynamic>>[];
 String? editedId;
 V6Repository():super([]);
 @override
 Future<Uri> formPreview(Map<String,dynamic> data,{ProxoCard? existing})async{
  drafts.add(jsonDecode(jsonEncode(data)) as Map<String,dynamic>);
  return super.formPreview(data,existing:existing);
 }
 @override
 Future<ProxoCard> save(Map<String,dynamic> data,{ProxoCard? existing})async{
  submitted=data;editedId=existing?.id;
  final page=ProxoCard.fromJson({
   ...data,'id':existing?.id??'33333333-3333-4333-8333-333333333333',
   'user_id':'11111111-1111-4111-8111-111111111111',
   'created_at':'2026-10-06T00:00:00Z','updated_at':'2026-10-06T00:00:01Z',
   'publish_status':'ready','status':'active',
  });
  rows=[page];return page;
 }
}
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(()async{
  await (FontLoader(kAppFont)..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'))).load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
 });
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('the four formal Kurdish names preserve authoritative template keys',(){
  expect(ProxoLinkDesign.labels,{
   'pill':'ستایلی کلاسیک','pill-mint':'ستایلی سروشتی',
   'pill-dark':'ستایلی تاریک','pill-white':'ستایلی ڕووناک'});
  expect(()=>ProxoLinkDesign.thumbnail('neon',ProxoPageType.contact),throwsArgumentError);
 });
 testWidgets('all twelve real-renderer thumbnails decode as PNG images',(tester)async{
  await tester.runAsync(()async{
   for(final type in ProxoPageType.values)for(final key in ProxoLinkDesign.labels.keys){
    final bytes=await rootBundle.load(ProxoLinkDesign.thumbnail(key,type));
    expect(bytes.buffer.asUint8List().take(8).toList(),[137,80,78,71,13,10,26,10]);
    final codec=await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame=await codec.getNextFrame();expect(frame.image.width,1179);expect(frame.image.height,3120);
    frame.image.dispose();codec.dispose();
   }
  });
 });
 for(final type in ProxoPageType.values)for(final width in [320.0,375.0,393.0,430.0])for(final direction in TextDirection.values){
  testWidgets('${type.key} thumbnail chooser at $width $direction loads four images, wraps names, selects cards and has no WebView',(tester)async{
   final semantics=tester.ensureSemantics();
   try{
   tester.view.physicalSize=Size(width,1600);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   String selected='pill';final templates=await FakeProxoLink([]).templates();
   final boundary=GlobalKey();
   await tester.pumpWidget(
    MaterialApp(
     theme:buildAppTheme(),
     home:Scaffold(
      body:SingleChildScrollView(
       child:MediaQuery(
        data:const MediaQueryData(textScaler:TextScaler.linear(1.6)),
        child:Directionality(
         textDirection:direction,
         child:Padding(
          padding:const EdgeInsets.all(36),
          child:RepaintBoundary(
           key:boundary,
           child:StatefulBuilder(
            builder:(context,setState)=>ProxoLinkDesignSelector(
             templates:templates,pageType:type,selectedKey:selected,
             onSelected:(template)=>setState(()=>selected=template.key),
            ),
           ),
          ),
         ),
        ),
       ),
      ),
     ),
    ),
   );
   await tester.pumpAndSettle();expect(find.byType(Image),findsNWidgets(4));
   expect(find.byType(ProxoLinkPreview),findsNothing);
   final cardHeights=ProxoLinkDesign.labels.keys.map((key)=>tester.getSize(find.byKey(ValueKey('proxolink-design-$key'))).height).toSet();
   expect(cardHeights,hasLength(1),reason:'All four cards retain equal heights when Kurdish labels wrap.');
   for(final key in ProxoLinkDesign.labels.keys){
    final card=find.byKey(ValueKey('proxolink-design-$key'));
    await tester.ensureVisible(card);await tester.tap(card);await tester.pumpAndSettle();
    expect(selected,key);expect(find.text(ProxoLinkDesign.label(key)),findsOneWidget);
    expect(find.byWidgetPredicate((w)=>w is Semantics&&w.properties.selected==true),findsOneWidget);
    final selectedNode=tester.getSemantics(find.byWidgetPredicate((w)=>w is Semantics&&w.properties.selected==true)).getSemanticsData();
    expect(selectedNode.label,ProxoLinkDesign.label(key));expect(selectedNode.hasAction(ui.SemanticsAction.tap),true);
    expect(tester.takeException(),isNull);
   }
   if(width==393&&direction==TextDirection.rtl){
    await tester.ensureVisible(find.byKey(const ValueKey('proxolink-design-pill')));await tester.pumpAndSettle();
    await tester.runAsync(()async{
     final image=await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
     final png=await image.toByteData(format:ui.ImageByteFormat.png);
     // The existing CI uploads UI evidence from this directory.
     final file=File('build/ui-verification/thumbnails-${type.key}.png');
     file.parent.createSync(recursive:true);file.writeAsBytesSync(png!.buffer.asUint8List());image.dispose();
    });
   }
   await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
   }finally{semantics.dispose();}
  });
 }
 test('page type maps independent UUID to typed URL, retains Telegram, and excludes owner UUID',(){
 }
