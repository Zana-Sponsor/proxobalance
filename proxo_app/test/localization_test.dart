import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/l10n/proxo_strings.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

void main() {
  tearDown(() => ProxoLocale.current.value = ProxoLocale.kurdishSorani);
  test('Badini persists and keeps Arabic-script direction', () async {
    SharedPreferences.setMockInitialValues({});
    await ProxoLocale.set(ProxoLocale.kurdishBadini);
    ProxoLocale.current.value = ProxoLocale.arabic;
    await ProxoLocale.load();
    expect(ProxoLocale.current.value, ProxoLocale.kurdishBadini);
    expect(ProxoLocale.directionOf(ProxoLocale.current.value), TextDirection.rtl);
    expect(ProxoStrings.text('دروستکردنی ڕیکلام'), 'چێکرنا ریکلامێ');
  });
  testWidgets('language changes constant labels without translating user data', (t) async {
    await t.pumpWidget(MaterialApp(home: ProxoLocaleScope(child: const Column(children: [
      ProxoText('چوونەژوورەوە', translate: true),
      ProxoText('چوونەژوورەوە', key: ValueKey('user-name')),
    ]))));
    ProxoLocale.current.value = ProxoLocale.arabic; await t.pump();
    expect(find.text('تسجيل الدخول',findRichText:true),findsOneWidget);
    expect(t.widget<ProxoText>(find.byKey(const ValueKey('user-name'))).data,'چوونەژوورەوە');
    ProxoLocale.current.value = ProxoLocale.kurdishBadini; await t.pump();
    expect(find.text('چوونا ژوور',findRichText:true),findsOneWidget);
  });
}
