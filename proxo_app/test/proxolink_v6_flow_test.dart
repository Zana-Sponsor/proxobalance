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
import 'package:proxo_app/screens/tools_screen.dart';
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
    final frame=await codec.getNextFrame();expect(frame.image.width,240);expect(frame.image.height,635);
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
 for(final type in ProxoPageType.values)testWidgets('${type.key} thumbnail selection preserves draft and updates only the large live preview',(tester)async{
  tester.view.physicalSize=const Size(393,1100);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final repo=V6Repository();await tester.pumpWidget(MaterialApp(theme:buildAppTheme(),home:ToolsScreen(initialCreate:true,repository:repo)));
  await tester.pumpAndSettle();await tester.tap(find.text(type.label).first);await tester.pumpAndSettle();
  final name=find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.labelText==type.nameLabel);
  await tester.ensureVisible(name);await tester.enterText(name,'ناوی پەڕەی تاقیکردنەوە');
  await tester.pump(const Duration(milliseconds:600));await tester.pumpAndSettle();
  for(final key in ProxoLinkDesign.labels.keys){
   final card=find.byKey(ValueKey('proxolink-design-$key'));await tester.ensureVisible(card);await tester.tap(card);await tester.pumpAndSettle();
   expect(tester.widget<ProxoLinkDesignSelector>(find.byType(ProxoLinkDesignSelector)).selectedKey,key);
   expect(repo.drafts.last['template_key'],key);expect(repo.drafts.last['page_kind'],type.key);
   expect(repo.drafts.last['name'],'ناوی پەڕەی تاقیکردنەوە');
   expect(find.byType(ProxoLinkPreview),findsOneWidget);expect(find.text('پێشبینینی تەواو'),findsOneWidget);
   final count=repo.drafts.length;await tester.tap(card);await tester.pumpAndSettle();expect(repo.drafts.length,count);
  }
  expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
 });

 test('page type maps independent UUID to typed URL, retains Telegram, and excludes owner UUID',(){
  for(final type in ProxoPageType.values){
   final page=ProxoCard.fromJson({'id':'22222222-2222-4222-8222-222222222222','user_id':'11111111-1111-4111-8111-111111111111',
    'name':'Proxo','page_kind':type.key,'template_key':'pill-white','template_version':6,'created_at':'2026-10-06T00:00:00Z',
    'platforms':{'tg':'https://t.me/proxo_iq'}});
   expect(page.publicPath,'/${type.key}/${page.id}');expect(page.publicPath.contains(page.userId),false);
   expect(page.platforms['tg'],'https://t.me/proxo_iq');
  }
 });
 for(final type in ProxoPageType.values){
  testWidgets('${type.key} builder submits current providers, copies typed URL, and edits the same page',(tester)async{
   tester.view.physicalSize=const Size(393,1100);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   String? copied;
   tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,(call)async{
    if(call.method=='Clipboard.setData')copied=(call.arguments as Map)['text'] as String;
    return null;
   });
   addTearDown(()=>tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,null));
   final repo=V6Repository();
   await tester.pumpWidget(MaterialApp(theme:buildAppTheme(),home:ToolsScreen(initialCreate:true,repository:repo)));
   await tester.pumpAndSettle();await tester.tap(find.text(type.label).first);await tester.pumpAndSettle();
   Finder field(String label)=>find.ancestor(
    of:find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.labelText==label),matching:find.byType(TextFormField));
   await tester.ensureVisible(field(type.nameLabel));await tester.enterText(field(type.nameLabel),'Proxo '+type.key);
   final provider={ProxoPageType.contact:'telegram',ProxoPageType.order:'talabat',ProxoPageType.download:'app_store'}[type]!;
   final choice=find.byWidgetPredicate((w)=>w is SwitchListTile&&(w.title as Text).data==provider);
   await tester.ensureVisible(choice);await tester.tap(choice);await tester.pumpAndSettle();
   final destination=type==ProxoPageType.contact?'proxo_iq':type==ProxoPageType.order?'https://iraq.talabat.com/iraq/restaurant/proxo':'https://apps.apple.com/us/app/proxo/id123456789';
   final input=field(type==ProxoPageType.contact?'username':'https://…');
   await tester.ensureVisible(input);await tester.enterText(input,destination);
   await tester.pump(const Duration(milliseconds:600));await tester.pumpAndSettle();
   expect(repo.drafts.last['name'],'Proxo '+type.key);
   expect(repo.drafts.last['page_kind'],type.key);
   expect(((repo.drafts.last['settings'] as Map)['providers'] as List).single['provider_key'],provider);
   final create=find.text('دروستکردن');await tester.ensureVisible(create);await tester.tap(create);await tester.pumpAndSettle();
   expect(repo.rows.single.pageKind,type.key);expect(find.text(type.label),findsOneWidget);
   final original=repo.rows.single;expect(original.id,isNot(original.clientRequestId));expect(original.id,isNot(original.userId));
   await tester.tap(find.byTooltip('زیاتر'));await tester.pumpAndSettle();await tester.tap(find.text('کۆپی لینک'));await tester.pumpAndSettle();
   expect(copied,'https://www.proxobalance.app/${type.key}/${original.id}');
   await tester.tap(find.byTooltip('زیاتر'));await tester.pumpAndSettle();await tester.tap(find.text('دەستکاریکردن'));await tester.pumpAndSettle();
   expect(tester.widget<TextFormField>(field(type.nameLabel)).controller!.text,'Proxo '+type.key);
   expect(tester.widget<SwitchListTile>(choice).value,true);
   for(final other in ProxoPageType.values)if(other!=type)expect(find.text(other.label),findsNothing);
   await tester.ensureVisible(field(type.nameLabel));await tester.enterText(field(type.nameLabel),'Edited '+type.key);
   final save=find.text('پاشەکەوتکردن');await tester.ensureVisible(save);await tester.tap(save);await tester.pumpAndSettle();
   expect(repo.editedId,original.id);expect(repo.rows.single.id,original.id);expect(repo.rows.single.publicPath,original.publicPath);
   expect(repo.rows.single.name,'Edited '+type.key);expect(tester.takeException(),isNull);
   await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
 }
 for(final height in [1100.0,240.0])for(final width in [320.0,375.0,393.0,430.0,768.0])for(final type in ProxoPageType.values)for(final direction in TextDirection.values){
  testWidgets('${type.key} form ${width}x$height $direction at 1.6 text scale has correct labels/providers, four designs and no overflow',(tester)async{
   final errorHandler=FlutterError.onError;
   FlutterError.onError=(details){debugPrint(details.toString());errorHandler?.call(details);};
   addTearDown(()=>FlutterError.onError=errorHandler);
   tester.view.physicalSize=Size(width,height);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   final repository=FakeProxoLink([]);
   await tester.pumpWidget(MaterialApp(theme:buildAppTheme(),builder:(context,child)=>MediaQuery(
    data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.6)),
    child:Directionality(textDirection:direction,child:child!)),home:ToolsScreen(initialCreate:true,repository:repository)));
   await tester.pumpAndSettle();await tester.ensureVisible(find.text(type.label).first);await tester.tap(find.text(type.label).first);await tester.pumpAndSettle();
   final fields=find.byType(TextFormField);
   await tester.ensureVisible(fields.first);await tester.enterText(fields.first,'پڕۆکسۆ Proxo '+ 'Long '.padRight(140,'x'));await tester.pump(const Duration(milliseconds:600));
   expect(find.text(type.imageLabel),findsOneWidget);expect(find.text(type.nameLabel),findsOneWidget);expect(find.text('بایۆ'),findsOneWidget);
   final switches=tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
   expect(switches.length,type==ProxoPageType.contact?6:2);
   final labels=switches.map((s)=>(s.title as Text).data).toList();
   if(type==ProxoPageType.contact){expect(labels,containsAll(['telegram','korek','asiacell']));expect(labels, isNot(contains('phone')));}
   if(type==ProxoPageType.order)expect(labels,containsAll(['talabat','toters']));
   if(type==ProxoPageType.download)expect(labels,containsAll(['google_play','app_store']));
   for(final key in ProxoLinkDesign.labels.keys){
    expect(find.text(ProxoLinkDesign.label(key)),findsOneWidget);
    expect(find.text(key),findsNothing);
    expect(find.byKey(ValueKey('proxolink-thumbnail-${type.key}-$key')),findsOneWidget);
   }
   expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
 }
}
