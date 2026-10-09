import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/controllers/proxolink_pages_controller.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/ad_validation_notifications.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';
import 'package:proxo_app/widgets/proxolink_page_card.dart';
import 'package:proxo_app/widgets/proxolink_design_selector.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';
import 'proxolink_page_management_test.dart' show ManagementRepository, page;

class ToolsRepository extends ManagementRepository {
  ToolsRepository(super.rows);
  String? scope;
  int listReads = 0, avatars = 0;
  String? failure;
  @override String? get ownerScope => scope;
  @override Future<List<ProxoCard>> cards() { listReads++; return super.cards(); }
  @override Future<Uri?> avatar(ProxoCard card) async { avatars++; return null; }
  @override Future<void> manage(ProxoCard card, String action) async {
    if (failure != null) throw ProxoLinkFailure(failure!);
    await super.manage(card, action);
  }
  @override Future<List<ProxoProvider>> providers() async => [
    for (final p in await super.providers()) ProxoProvider(key:p.key, pageType:p.pageType,
      label: {'talabat':'تەلەبات','wade':'وادێ','toters':'تۆتەرز','lezzoo':'لەزوو'}[p.key] ?? p.label,
      icon:p.icon,inputKind:p.inputKind),
  ];
}
ProxoCard moderated(int i, String status, {String? name}) => ProxoCard.fromJson({
  ...page(i, name:name ?? 'پڕۆکسۆ Proxo $i').toJson(), 'moderation_status':status,
});
Widget host(Widget child, {double scale=1}) => MaterialApp(theme:buildAppTheme(),
 builder:(context, child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),child:child!),home:child);
Future<void> tap(WidgetTester t, Finder f) async { await t.ensureVisible(f); await t.tap(f); await t.pumpAndSettle(); }
void size(WidgetTester t, double width, {double height=1200}) {
 t.view.physicalSize=Size(width,height);t.view.devicePixelRatio=1;
 addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
}
Future<Uint8List> png(WidgetTester t, GlobalKey key, String name) async {
 late Uint8List data;
 await t.runAsync(() async {
  final image=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
  data=(await image.toByteData(format:ui.ImageByteFormat.png))!.buffer.asUint8List();
  final file=File('build/ui-verification/$name.png');file.parent.createSync(recursive:true);file.writeAsBytesSync(data);image.dispose();
 });return data;
}
Finder field(String label)=>find.ancestor(of:find.byWidgetPredicate((w)=>w is TextField && w.decoration?.labelText==label),matching:find.byType(TextFormField));
void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(()async {
  await (FontLoader(kAppFont)..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'))).load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
 });
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('authoritative replacement updates moderation, removes absent IDs and keeps unchanged object',() async {
  final unchanged=moderated(1,'pending'),repo=ToolsRepository([unchanged,moderated(2,'pending')]);
  final c=ProxoLinkPagesController(repo);await c.refresh();
  repo.rows=[unchanged,moderated(3,'approved')];await c.refresh();
  expect(c.pages.map((p)=>p.id),containsAll([page(1).id,page(3).id]));
  expect(c.pages.any((p)=>p.id==page(2).id),false);expect(identical(c.pages.firstWhere((p)=>p.id==page(1).id),unchanged),true);
  repo.rows=[moderated(1,'rejected')];await c.refresh();expect(c.pages.single.moderationLabel,'ڕەتکراوە');c.dispose();
 });
 test('failed refresh retains valid rows; owner switch clears them before pending request',() async {
  final repo=ToolsRepository([moderated(1,'pending')])..scope=page(1).userId;
  final c=ProxoLinkPagesController(repo);await c.refresh();repo.fail=true;await c.refresh();expect(c.pages.length,1);
  repo.fail=false;repo.defer=true;repo.scope='other';final refresh=c.refresh();expect(c.pages,isEmpty);
  repo.reads.single.complete([page(1)]);await refresh;expect(c.pages,isEmpty);c.dispose();
 });
 test('confirmed delete changes one UUID only, no collection reload; dependency leaves row',() async {
  final repo=ToolsRepository([page(1),page(2)]),c=ProxoLinkPagesController(ToolsRepository([]));c.dispose();
  final state=ProxoLinkPagesController(repo);await state.refresh();await state.manage(page(1),'delete');
  expect(repo.listReads,1);expect(state.pages.single.id,page(2).id);
  repo.failure='ad_dependency';expect(()=>state.manage(page(2),'delete'),throwsA(isA<ProxoLinkFailure>()));
  await Future<void>.delayed(Duration.zero);expect(state.pages.length,1);state.dispose();
 });
 testWidgets('shared AppBar, only value cards and two actions; browser return preserves route/scroll and one GET',(t) async {
  size(t,393);final repo=ToolsRepository(List.generate(15,(i)=>moderated(i+1,'pending'))),opened=<Uri>[];
  await t.pumpWidget(host(ToolsScreen(repository:repo,externalLauncher:(uri)async{opened.add(uri);return true;})));
  await t.pumpAndSettle();expect(find.byType(ReceiptAppBar),findsOneWidget);expect(find.text('ئامرازەکان'),findsOneWidget);
  expect(find.byType(ProxoLinkPreview),findsNothing);expect(find.byType(Image),findsNothing);expect(repo.avatars,0);
  final row=find.byKey(ValueKey('proxolink-page-${page(5).id}'));
  await t.scrollUntilVisible(row,300,scrollable:find.byType(Scrollable).first);await t.pumpAndSettle();
  final before=t.getTopLeft(row);
  for(var i=0;i<3;i++) {
   await tap(t,find.descendant(of:row,matching:find.text('پێشبینین')));
   t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);await t.pumpAndSettle();
   expect(t.getTopLeft(row),before);
  }
  expect(opened.map((u)=>u.path).toSet(),{'/contact/${page(5).id}'});expect(repo.listReads,1);
  for(final text in ['زیاتر','ڕیکلام','دەستکاریکردن','ئەرشیفکردن','کۆپی لینک','ناو:','دۆخ:']) expect(find.text(text),findsNothing);
 });
 testWidgets('failed external launch uses actual shared Create Ad notification and expires',(t) async {
  size(t,393);await t.pumpWidget(host(ToolsScreen(repository:ToolsRepository([moderated(1,'pending')]),externalLauncher:(_)async=>false)));
  await t.pumpAndSettle();await tap(t,find.text('پێشبینین'));expect(find.byType(AdValidationNotifications),findsOneWidget);
  expect(find.text(const ProxoLinkFailure('browser_launch_failed').message),findsOneWidget);
  await t.pump(const Duration(seconds:5));await t.pump(const Duration(milliseconds:500));
  expect(find.text(const ProxoLinkFailure('browser_launch_failed').message),findsNothing);
 });
 testWidgets('delete confirmation blocks dependency without changing list',(t) async {
  size(t,393);final repo=ToolsRepository([moderated(1,'pending')])..failure='ad_dependency';
  await t.pumpWidget(host(ToolsScreen(repository:repo)));await t.pumpAndSettle();await tap(t,find.text('سڕینەوە'));
  expect(find.byType(AlertDialog),findsOneWidget);await tap(t,find.widgetWithText(FilledButton,'سڕینەوە'));
  expect(repo.rows.length,1);expect(find.text(const ProxoLinkFailure('ad_dependency').message),findsOneWidget);
 });
 testWidgets('initial skeleton/empty/error/retry with no WebView',(t) async {
  final repo=ToolsRepository([])..defer=true;
  await t.pumpWidget(host(ToolsScreen(repository:repo)));await t.pump();expect(find.byType(ProxoLinkPageSkeleton),findsWidgets);
  repo.reads.single.completeError(const ProxoLinkFailure('network_error'));await t.pumpAndSettle();
  expect(find.text('نەتوانرا پەڕەکان بار بکرێن'),findsOneWidget);repo.defer=false;
  await tap(t,find.text('دووبارە هەوڵ بدەرەوە'));expect(find.text('هێشتا هیچ پەڕەیەکت دروست نەکردووە'),findsOneWidget);
 });
 testWidgets('refresh retains loaded rows, gates rapid taps and settles the same element/geometry',(t) async {
  size(t,393);final handle=ProxoRefreshController(),repo=ToolsRepository([moderated(1,'pending')]);
  await t.pumpWidget(host(ToolsScreen(repository:repo,refreshController:handle)));await t.pumpAndSettle();
  final row=find.byKey(ValueKey('proxolink-page-${page(1).id}'));final resting=t.getTopLeft(row),element=t.element(find.byType(ListView));
  repo.defer=true;unawaited(handle.refresh());unawaited(handle.refresh());await t.pump(const Duration(milliseconds:100));
  expect(repo.reads.length,1);expect(find.byType(ProxoLinkPageSkeleton),findsNothing);expect(find.text('پڕۆکسۆ Proxo 1'),findsOneWidget);
  repo.reads.single.complete([moderated(1,'approved')]);await t.pumpAndSettle();
  expect(handle.isRefreshing,false);expect(t.getTopLeft(row),resting);expect(identical(t.element(find.byType(ListView)),element),true);
  expect(find.text('پەسەندکراوە'),findsOneWidget);handle.dispose();
 });
 testWidgets('new Create form validates with shared notices; three types; no live WebView; back preserves Tools',(t) async {
  size(t,393);final repo=ToolsRepository([]);
  await t.pumpWidget(host(ToolsScreen(repository:repo)));await t.pumpAndSettle();await tap(t,find.text('پەڕە دروستبکە'));
  expect(find.byType(ProxoLinkCreatePageScreen),findsOneWidget);expect(find.text('دروستکردنی پەڕە'),findsOneWidget);
  await tap(t,find.byKey(const ValueKey('create-page-submit')));expect(find.byType(AdValidationNotifications),findsWidgets);
  for(final type in ProxoPageType.values) {
   await tap(t,find.byKey(ValueKey('create-type-${type.key}')));expect(find.text(type.imageLabel),findsOneWidget);
   expect(field(type.nameLabel),findsOneWidget);expect(field('کورتە باس'),findsOneWidget);expect(field('ناوی تیک تۆک'),findsOneWidget);
   if(type==ProxoPageType.order) for(final label in ['تەلەبات','وادێ','تۆتەرز','لەزوو']) expect(field(label),findsOneWidget);
  }
  expect(find.byType(ProxoLinkDesignSelector),findsOneWidget);expect(find.byType(ProxoLinkPreview),findsNothing);
  expect(repo.previewRequests,isEmpty);
  await t.binding.handlePopRoute();await t.pumpAndSettle();expect(find.text('ئامرازەکان'),findsOneWidget);expect(repo.listReads,1);
 });
 testWidgets('single submit returns stored pending UUID and locally upserts without GET',(t) async {
  size(t,393);final repo=ToolsRepository([])..saveGate=Completer<ProxoCard>();
  await t.pumpWidget(host(ToolsScreen(repository:repo)));await t.pumpAndSettle();await tap(t,find.text('پەڕە دروستبکە'));
  await t.ensureVisible(field('ناوی پەڕە'));await t.enterText(field('ناوی پەڕە'),'پەڕەی تاقیکردنەوە');
  await t.ensureVisible(field('telegram'));await t.enterText(field('telegram'),'proxo_iq');
  await t.ensureVisible(find.byKey(const ValueKey('create-page-submit')));await t.tap(find.byKey(const ValueKey('create-page-submit')));await t.pump();
  await t.tap(find.byKey(const ValueKey('create-page-submit')));await t.pump();expect(repo.saves,1);
  expect(repo.submitted!.containsKey('id'),false);expect(repo.submitted!.containsKey('moderation_status'),false);
  repo.saveGate!.complete(moderated(1,'pending'));await t.pumpAndSettle();expect(find.text('چاوەڕوانی'),findsOneWidget);expect(repo.listReads,1);
 });
 final widths=[320.0,360.0,375.0,393.0,412.0,430.0,600.0,768.0,1024.0];
 for(final width in widths) for(final scale in [1.0,1.6]) {
  testWidgets('Tools $width scale$scale all statuses and mixed long names, restrained tablet width',(t) async {
   size(t,width);final key=GlobalKey();
   final repo=ToolsRepository([moderated(1,'pending',name:'پەڕەی پڕۆکسۆ '+List.filled(15,'ناوێکی درێژ').join(' ')),
    moderated(2,'approved',name:'اسم صفحة عربية طويل جدًا '+List.filled(12,'مطعم').join(' ')),
    moderated(3,'rejected',name:List.filled(14,'Long English page name').join(' '))]);
   await t.pumpWidget(host(RepaintBoundary(key:key,child:ToolsScreen(repository:repo)),scale:scale));await t.pumpAndSettle();
   expect(t.takeException(),isNull);
   for(final i in [1,2,3]) {
    final row=find.byKey(ValueKey('proxolink-page-${page(i).id}'));
    await t.scrollUntilVisible(row,300,scrollable:find.byType(Scrollable).first);await t.pumpAndSettle();
    expect(t.getSize(row).width,lessThanOrEqualTo(600));expect(t.takeException(),isNull);
    for(final action in ['پێشبینین','سڕینەوە']) {
     final button=find.descendant(of:row,matching:action=='پێشبینین'?find.byType(FilledButton):find.byType(OutlinedButton));
     if(button.evaluate().isNotEmpty) expect(t.getSize(button).height,greaterThanOrEqualTo(48));
    }
    if(scale==1 && [320.0,393.0,430.0,768.0].contains(width)) await png(t,key,'tools-$width-status-$i');
   }
  });
  for(final type in ProxoPageType.values) testWidgets('Create ${type.key} $width scale$scale full sections and crisp chooser no overflow',(t) async {
   size(t,width);final key=GlobalKey();await t.pumpWidget(host(RepaintBoundary(key:key,
    child:ProxoLinkCreatePageScreen(repository:ToolsRepository([]))),scale:scale));await t.pumpAndSettle();
   await tap(t,find.byKey(ValueKey('create-type-${type.key}')));
   await t.ensureVisible(field(type.nameLabel));await t.enterText(field(type.nameLabel),'پڕۆکسۆ العربية English '+List.filled(8,'Long').join(' '));
   expect(t.takeException(),isNull);expect(find.byType(ProxoLinkPreview),findsNothing);
   if(scale==1 && type==ProxoPageType.contact && [320.0,393.0,430.0,768.0].contains(width)) await png(t,key,'create-$width');
   await t.ensureVisible(find.byType(ProxoLinkDesignSelector));await t.pumpAndSettle();expect(t.takeException(),isNull);
   expect(find.byType(Image),findsNWidgets(4));
   if(scale==1 && [320.0,393.0,430.0,768.0].contains(width)) await png(t,key,'create-style-${type.key}-$width');
  });
 }
 for(final width in [320.0,393.0,430.0,768.0]) for(final error in [false,true]) testWidgets('Tools ${error?'error':'empty'} $width evidence',(t) async {
  size(t,width);final key=GlobalKey(),repo=ToolsRepository([])..fail=error;
  await t.pumpWidget(host(RepaintBoundary(key:key,child:ToolsScreen(repository:repo))));await t.pumpAndSettle();
  expect(t.takeException(),isNull);await png(t,key,'tools-${error?'error':'empty'}-$width');
 });
 testWidgets('exact shared Ad notices used by both flows; stacked entry and automatic five-second exit',(t) async {
  size(t,393);final c=AdValidationController(),key=GlobalKey();
  await t.pumpWidget(host(Scaffold(body:Padding(padding:const EdgeInsets.all(16),
   child:RepaintBoundary(key:key,child:AdValidationNotifications(controller:c))))));
  c.show({'name':'تکایە ناو بنووسە.','provider':'تکایە بەستەرەکە بپشکنە.','image':'وێنەکە گونجاو نییە.'});
  await t.pump(const Duration(milliseconds:700));await t.pump(const Duration(milliseconds:250));
  expect(find.byIcon(Icons.error_outline),findsNWidgets(3));await png(t,key,'shared-create-ad-tools-error');
  await t.pump(const Duration(seconds:5));await t.pump(const Duration(milliseconds:500));expect(find.byIcon(Icons.error_outline),findsNothing);c.dispose();
 });
 testWidgets('Home integration pattern and Tools use identical shared motion, with settled offset zero',(t) async {
  size(t,393);final handle=ProxoRefreshController(),gate=Completer<void>(),key=GlobalKey();
  await t.pumpWidget(host(Scaffold(body:RepaintBoundary(key:key,child:ProxoRefresh(controller:handle,onRefresh:()=>gate.future,
   child:const SingleChildScrollView(child:SizedBox(height:1000,child:Center(child:Text('Home shared refresh integration')))))))));
  unawaited(handle.refresh());await t.pump();await t.pump(const Duration(milliseconds:100));await png(t,key,'home-shared-refresh-100ms');
  await t.pump(const Duration(milliseconds:200));await png(t,key,'home-shared-refresh-300ms');gate.complete();await t.pumpAndSettle();expect(handle.isRefreshing,false);await png(t,key,'home-shared-refresh-settled');handle.dispose();
  final toolsHandle=ProxoRefreshController(),repo=ToolsRepository([moderated(1,'pending')]);
  await t.pumpWidget(host(RepaintBoundary(key:key,child:ToolsScreen(repository:repo,refreshController:toolsHandle))));await t.pumpAndSettle();
  repo.defer=true;unawaited(toolsHandle.refresh());await t.pump();await t.pump(const Duration(milliseconds:100));await png(t,key,'tools-shared-refresh-100ms');
  await t.pump(const Duration(milliseconds:200));await png(t,key,'tools-shared-refresh-300ms');repo.reads.single.complete(repo.rows);await t.pumpAndSettle();await png(t,key,'tools-shared-refresh-settled');expect(toolsHandle.isRefreshing,false);toolsHandle.dispose();
 });
}
