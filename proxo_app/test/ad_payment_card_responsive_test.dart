import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/ad_payment_card.dart';
import 'responsive_ad_ui_test.dart' show expectVisibleTextFits;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Rabar')
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
  });

  for (final scenario in [(240.0, 3.0), (393.0, 1.0)]) {
    testWidgets('payment card stays balanced at ${scenario.$1}/${scenario.$2}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(scenario.$1, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Size? previous;
      for (final method in ['app_balance', 'fastpay']) {
        await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scenario.$2)),
                child: child!),
            home: Scaffold(
                body: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: AdPaymentCard(
                            value: method, onChanged: (_) {}))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectVisibleTextFits(tester);
        final card =
            tester.getRect(find.byKey(const ValueKey('selected-payment-card')));
        final change =
            tester.getRect(find.byKey(const ValueKey('change-payment')));
        expect(card.contains(change.topLeft), isTrue);
        expect(card.contains(change.bottomRight), isTrue);
        if (previous != null) expect(card.size, previous);
        previous = card.size;
        if (scenario.$2 == 1) expect(card.height, 72);
      }
    });
  }
}
