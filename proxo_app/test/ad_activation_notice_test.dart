import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/ad_activation_notice.dart';
import 'package:proxo_app/theme/app_locale.dart';

void main() {
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
  for(final language in ['ckb','ar','kmr']) {
    testWidgets('notice is readable at 280dp and 2x in $language; both actions work', (t) async {
      t.view.physicalSize = const Size(560,1704); t.view.devicePixelRatio=2;
      addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      ProxoLocale.current.value=Locale(language);
      addTearDown(() => ProxoLocale.current.value=ProxoLocale.kurdishSorani);
      var open=0,close=0;
      await t.pumpWidget(MaterialApp(home: ProxoLocaleScope(child: MediaQuery(
        data: const MediaQueryData(size:Size(280,852),textScaler:TextScaler.linear(2)),
        child: Scaffold(body:Padding(padding:const EdgeInsets.all(12),child:AdActivationNotice(
          adTitle:'Campaign 123', onOpen:()=>open++,onClose:()=>close++)))))));
      await t.pumpAndSettle();
      expect(t.takeException(),isNull);
      final button=find.byType(TextButton), closeButton=find.byType(IconButton);
      expect(t.getSize(button).height,greaterThanOrEqualTo(48));
      expect(t.getSize(closeButton).height,greaterThanOrEqualTo(48));
      await t.tap(button); await t.tap(closeButton);
      expect(open,1);expect(close,1);
    });
  }
}
