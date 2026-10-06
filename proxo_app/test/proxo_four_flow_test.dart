import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_template_meta.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_theme.dart';

class FakePages extends ProxoLinkRepository {
  List<ProxoCard> rows = [];
  Map<String, dynamic>? submitted;
  final previews = <String>[];
  @override
  Future<List<ProxoCard>> cards() async => rows;
  @override
  Future<List<ProxoTemplate>> templates() async => [
    for (final key in proxoTemplateKeys)
      ProxoTemplate(key: key, label: key, previewPath: '/contact-preview?token=test', version: 3, requiresAvatar: false),
  ];
  @override
  Future<Uri> templatePreview(String key, int version, {
    String theme = 'purple', String language = 'ku', String pageType = 'contact',
  }) async {
    previews.add('$key/$version/$pageType/$language');
    throw const ProxoLinkFailure('network_error');
  }
  @override
  Future<Uri> preview(String id) async => publicUrl(id);
  @override
  Future<String> uploadAvatar(String id, Uint8List bytes) async => '$id/avatar.png';
  @override
  Uri publicUrl(String id) => Uri.parse('https://www.proxobalance.app/contact/$id');
  @override
  Future<void> action(String id, String action) async {}
  @override
  Future<ProxoCard> save(Map<String, dynamic> data, {ProxoCard? existing}) async {
    submitted = data;
    final card = ProxoCard.fromJson({...data,
      'id': data['client_request_id'], 'user_id': '11111111-1111-4111-8111-111111111111',
      'status': 'active', 'publish_status': 'ready', 'card_number': 1,
      'created_at': '2026-10-06T00:00:00Z', 'updated_at': '2026-10-06T00:00:00Z',
    });
    rows = [card];
    return card;
  }
}
Finder field(String label) => find.byKey(ValueKey('proxo-field-$label'));
Future<void> openForm(WidgetTester t, FakePages repo) async {
  await t.pumpWidget(MaterialApp(theme: buildAppTheme(), home: ToolsScreen(initialCreate: true, repository: repo)));
  await t.pumpAndSettle();
}
Future<void> fill(WidgetTester t, String label, String value) async {
  await t.ensureVisible(field(label));
  await t.enterText(field(label), value);
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('exactly four styles, three page purposes and all requested providers', () {
    expect(proxoTemplateKeys, ['pill', 'pill-mint', 'pill-dark', 'pill-white']);
    expect(proxoPageTypes.keys, ['contact', 'food', 'download']);
    expect(kPlatformBtns.map((p) => p.id), containsAll(['wa','tg','vb','ph','as','talabat','lezzoo','wade','toters','app_store','google_play']));
  });
  test('valid contact, restaurant and store destinations open with safe URI rules', () {
    expect(proxoDestination('wa', '٠٧٥٠١٢٣٤٥٦٧').toString(), 'https://wa.me/9647501234567');
    expect(proxoDestination('tg', '@proxo_iq').toString(), 'https://t.me/proxo_iq');
    expect(proxoDestination('ph', '07501234567').toString(), 'tel:+9647501234567');
    for(final entry in {
      'vb':'07501234567', 'as':'07701234567',
      'talabat':'https://www.talabat.com/iraq/restaurant/123',
      'lezzoo':'https://lezzoo.com/restaurant/123', 'wade':'https://wadedelivery.com/restaurant/123',
      'toters':'https://totersapp.com/restaurant/123',
      'app_store':'https://apps.apple.com/app/id123456789',
      'google_play':'https://play.google.com/store/apps/details?id=com.proxo.app',
    }.entries) expect(allowedProxoExternal(proxoDestination(entry.key, entry.value)!), isTrue, reason: entry.key);
    for(final raw in ['javascript:alert(1)','https://talabat.com.evil.example/','https://evil.example/','file:///etc/passwd']) {
      expect(proxoDestination('talabat',raw), isNull);
      expect(allowedProxoExternal(Uri.parse(raw)), isFalse);
    }
    expect(proxoDestination('app_store','https://apps.apple.com/'), isNull);
    expect(proxoDestination('google_play','https://play.google.com/store/apps/details'), isNull);
  });
  for(final width in [320.0,393.0,768.0]) {
    testWidgets('purpose and four-theme controls fit width $width with larger text', (t) async {
      t.view.physicalSize=Size(width,1100);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      final repo=FakePages();
      await t.pumpWidget(MaterialApp(theme:buildAppTheme(),builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(2)),child:child!),home:ToolsScreen(initialCreate:true,repository:repo)));
      await t.pumpAndSettle();
      expect(find.text('داواکردنی خواردن'), findsOneWidget);
      for(final key in proxoTemplateKeys) expect(find.text(key),findsOneWidget);
      expect(t.takeException(),isNull);
    });
  }
  testWidgets('food page saves merchant links and remains selectable for an ad', (t) async {
    final repo=FakePages();await openForm(t,repo);
    await t.tap(find.text('داواکردنی خواردن'));await t.pumpAndSettle();
    expect(repo.previews.last,'pill-white/2/food/ku');
    expect(find.byType(SwitchListTile),findsNWidgets(4));
    await fill(t,'ناو','ڕیستۆرانتی Proxo');
    final toggle=find.widgetWithText(SwitchListTile,'تەڵەبات');
    await t.ensureVisible(toggle);await t.tap(toggle);await t.pumpAndSettle();
    await fill(t,'https://www.talabat.com/…','https://www.talabat.com/iraq/restaurant/123');
    final save=find.text('دروستکردن');await t.ensureVisible(save);await t.tap(save);await t.pumpAndSettle();
    expect(repo.submitted?['page_type'],'food');expect(repo.submitted?['template_version'],3);
    expect(repo.submitted?['platforms'],{'talabat':'https://www.talabat.com/iraq/restaurant/123'});
    expect(find.text('ڕیکلام'),findsOneWidget);expect(t.takeException(),isNull);
  });
  testWidgets('download type offers only the two stores and rejects a malformed app link', (t) async {
    final repo=FakePages();await openForm(t,repo);
    await t.tap(find.text('دابەزاندنی ئەپ'));await t.pumpAndSettle();
    expect(repo.previews.last,'pill-white/2/download/ku');expect(find.byType(SwitchListTile),findsNWidgets(2));
    await fill(t,'ناو','Proxo');
    final toggle=find.widgetWithText(SwitchListTile,'Google Play');await t.ensureVisible(toggle);await t.tap(toggle);await t.pumpAndSettle();
    await fill(t,'https://play.google.com/store/apps/details?id=…','https://evil.example/app');
    final save=find.text('دروستکردن');await t.ensureVisible(save);await t.tap(save);await t.pumpAndSettle();expect(repo.submitted,isNull);
    await fill(t,'https://play.google.com/store/apps/details?id=…','https://play.google.com/store/apps/details?id=com.proxo.app');
    await t.ensureVisible(save);await t.tap(save);await t.pumpAndSettle();expect(repo.submitted?['page_type'],'download');
  });
  testWidgets('changing a theme and purpose preserves profile input', (t) async {
    final repo=FakePages();await openForm(t,repo);await fill(t,'ناو','Proxo 2026');
    await t.ensureVisible(find.text('pill-dark'));await t.tap(find.text('pill-dark'));await t.pumpAndSettle();
    await t.ensureVisible(find.text('داواکردنی خواردن'));await t.tap(find.text('داواکردنی خواردن'));await t.pumpAndSettle();
    expect(repo.previews.last,'pill-dark/2/food/ku');expect(t.widget<TextFormField>(field('ناو')).controller!.text,'Proxo 2026');
    expect(t.takeException(),isNull);
  });
}
