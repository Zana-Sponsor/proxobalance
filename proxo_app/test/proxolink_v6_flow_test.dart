import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'proxolink_flow_test.dart' show FakeProxoLink;
void main(){
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('page type maps independent UUID to typed URL, retains Telegram, and excludes owner UUID',(){
  for(final type in ProxoPageType.values){
   final page=ProxoCard.fromJson({'id':'22222222-2222-4222-8222-222222222222','user_id':'11111111-1111-4111-8111-111111111111',
    'name':'Proxo','page_kind':type.key,'template_key':'pill-white','template_version':6,'created_at':'2026-10-06T00:00:00Z',
    'platforms':{'tg':'https://t.me/proxo_iq'}});
   expect(page.publicPath,'/${type.key}/${page.id}');expect(page.publicPath.contains(page.userId),false);
   expect(page.platforms['tg'],'https://t.me/proxo_iq');
  }
 });
 for(final width in [320.0,375.0,393.0,430.0,768.0])for(final type in ProxoPageType.values)for(final direction in TextDirection.values){
  testWidgets('${type.key} form $width $direction at 1.6 text scale has correct labels/providers, four designs and no overflow',(tester)async{
   tester.view.physicalSize=Size(width,1100);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   final repository=FakeProxoLink([]);
   await tester.pumpWidget(MaterialApp(theme:buildAppTheme(),builder:(context,child)=>MediaQuery(
    data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.6)),
    child:Directionality(textDirection:direction,child:child!)),home:ToolsScreen(initialCreate:true,repository:repository)));
   await tester.pumpAndSettle();await tester.tap(find.text(type.label).first);await tester.pumpAndSettle();
   final fields=find.byType(TextFormField);
   await tester.ensureVisible(fields.first);await tester.enterText(fields.first,'پڕۆکسۆ Proxo '+ 'Long '.padRight(140,'x'));await tester.pump(const Duration(milliseconds:600));
   expect(find.text(type.imageLabel),findsOneWidget);expect(find.text(type.nameLabel),findsOneWidget);expect(find.text('بایۆ'),findsOneWidget);
   final switches=tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
   expect(switches.length,type==ProxoPageType.contact?6:2);
   final labels=switches.map((s)=>(s.title as Text).data).toList();
   if(type==ProxoPageType.contact){expect(labels,containsAll(['telegram','korek','asiacell']));expect(labels, isNot(contains('phone')));}
   if(type==ProxoPageType.order)expect(labels,containsAll(['talabat','toters']));
   if(type==ProxoPageType.download)expect(labels,containsAll(['google_play','app_store']));
   for(final key in ['pill','pill-mint','pill-dark','pill-white'])expect(find.text(key),findsOneWidget);
   expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());await tester.pump();
  });
 }
}
