import 'package:proxo_app/widgets/proxo_png_icon.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/models/receipt_pricing.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/home_quick_actions.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Rabar',
    )..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
  });
  test('historical money never infers units from amount magnitude', () {
    expect(storedTransactionIqd({'amount': 10, 'currency': 'IQD'}), 10);
    expect(storedTransactionUsd({'amount': 900000, 'currency': 'USD'}), 900000);
    expect(storedTransactionIqd({'amount': 900000, 'currency': 'USD'}), isNull);
    expect(
      storedTransactionIqd({'amount': 10, 'currency': 'USD', 'fx_rate': 1800}),
      18000,
    );
    expect(
      storedTransactionUsd({
        'amount': 18000,
        'currency': 'IQD',
        'fx_rate': 1800,
      }),
      10,
    );
    for (final amount in [
      0,
      10,
      500,
      501,
      900000,
      double.nan,
      double.infinity,
    ]) {
      expect(storedTransactionIqd({'amount': amount}), isNull);
      expect(storedTransactionUsd({'amount': amount}), isNull);
    }
  });
  test('wallet snapshot preserves decimals and explicit unit precedence', () {
    expect(
      storedWalletBalanceUsd({
        'type': 'ad_payment',
        'ad_id': 'fixture',
        'balance_after': 10.25,
      }, 'balance_after'),
      10.25,
    );
    expect(
      storedWalletBalanceIqd({
        'balance_currency': 'IQD',
        'balance_after': 18000,
      }, 'balance_after'),
      18000,
    );
    expect(
      storedWalletBalanceIqd({
        'balance_currency': 'USD',
        'balance_after': 10,
      }, 'balance_after'),
      isNull,
    );
    expect(
      storedWalletBalanceUsd({
        'type': 'deposit',
        'balance_after': 10,
      }, 'balance_after'),
      isNull,
    );
    expect(
      storedWalletBalanceUsd({
        'balance_currency': 'USD',
        'balance_after': 10,
      }, 'balance_after'),
      10,
    );
    expect(
      storedWalletBalanceUsd({
        'type': 'ad_payment',
        'ad_id': 'fixture',
        'balance_currency': 'IQD',
        'balance_after': 10,
      }, 'balance_after'),
      isNull,
    );
  });
  for (final width in [280.0, 393.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'three semantic actions fit $width/$scale and keep routes distinct',
        (t) async {
          t.view.physicalSize = Size(width, 1400);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final calls = [0, 0, 0];
          await t.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: HomeQuickActions(
                          onCreateTap: () => calls[0]++,
                          onAddBalanceTap: () => calls[1]++,
                          onCreatePageTap: () => calls[2]++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.byType(Image), findsNothing);
          expect(find.byType(ProxoSymbol), findsNWidgets(3));
          expect(
              t.widgetList<ProxoSymbol>(find.byType(ProxoSymbol))
                  .map((glyph) => glyph.symbol),
              [ProxoSymbolName.ads, ProxoSymbolName.wallet, ProxoSymbolName.tools]);
          // SVG icons scale within their viewBox. Labels must never be
          // scaled down by a FittedBox instead of respecting system text size.
          expect(
            find.ancestor(
              of: find.descendant(
                of: find.byType(HomeQuickActions),
                matching: find.byType(Text),
              ),
              matching: find.byType(FittedBox),
            ),
            findsNothing,
          );
          for (final (index, key) in [
            'home-create-ad',
            'home-add-balance',
            'home-create-page',
          ].indexed) {
            final f = find.byKey(ValueKey(key));
            final rect = t.getRect(f);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            await t.ensureVisible(f);
            await t.tap(f);
            expect(calls[index], 1);
          }
          expect(calls, [1, 1, 1]);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'PNG paint remains centered when its icon well has tight larger constraints',
    (t) async {
      const wellKey = ValueKey('icon-well');
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              key: wellKey,
              dimension: 48,
              child: const ProxoPngIcon(ProxoSymbolName.user, size: 24),
            ),
          ),
        ),
      ));
      final image = find.byType(Image);
      expect(t.getSize(image), const Size(22, 22));
      expect(t.getCenter(image), t.getCenter(find.byKey(wellKey)));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'unavailable quick action uses disabled color and has no tap handler',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: HomeQuickActions()),
          ),
        ),
      );
      final glyph = t.widget<ProxoSymbol>(find.byWidgetPredicate(
          (w) => w is ProxoSymbol && w.symbol == ProxoSymbolName.wallet));
      expect(glyph.color, AdUi.secondary);
      expect(glyph.size, 22);
      final button = find.byKey(const ValueKey('home-add-balance'));
      final ink = t.widget<InkWell>(
        find.descendant(of: button, matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNull);
    },
  );
}
