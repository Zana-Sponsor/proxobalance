import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/fastpay_checkout_sheet.dart';
import 'support/visual_capture.dart';

const screen = DepositScreen(recipientNumberOverrides: {
  'fib': '0000000000',
  'fastpay': '0000000000',
  'kcard': '0000000000',
});

void main() {
  ProxoVisualBinding();
  setUpAll(loadVisualFonts);

  test('Kurdish and Arabic digits normalize without losing amount', () {
    expect(normalizeDepositDigits('٢٥٠٠٠'), '25000');
    expect(normalizeDepositDigits('۲۵۰۰۰'), '25000');
    expect(normalizeDepositDigits('25000'), '25000');
  });

  for (final size in [
    const Size(320, 780),
    const Size(393, 852),
    const Size(430, 932)
  ]) {
    testWidgets('payment flow layout and controls at ${size.width}',
        (tester) async {
      setVisualViewport(tester, size);
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(visualCapture(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildProxoTheme(),
          home: screen)));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/logos/fastpay_official.png'),
          tester.element(find.byType(DepositScreen))));
      await tester.pumpAndSettle();
      expect(find.text('ZainCash'), findsNothing);
      expect(find.text('SuperApp'), findsNothing);
      expect(find.text('کۆپیکردنی ژمارە'), findsNothing);
      expect(find.text('گواستنەوەی دەستی'), findsNWidgets(2));
      await captureVisual(tester, 'add-balance-initial-$dimensions');
      await tester.tap(find.text('25,000'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('deposit-amount')))
              .controller!
              .text,
          '25000');
      await tester.tap(find.text('FIB'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('کۆپیکردنی ژمارە'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('کۆپیکردنی ژمارە'));
      await tester.pumpAndSettle();
      expect(copied, '0000000000');
      // Dismiss the transient clipboard message before screenshot.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('deposit-payment-details'))),
          alignment: .1);
      await tester.pumpAndSettle();
      await captureVisual(tester, 'payment-details-fib-$dimensions');
      await tester.ensureVisible(find.byKey(const ValueKey('deposit-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deposit-submit')));
      await tester.pumpAndSettle();
      expect(find.text('ناوی هەژمار بنووسە'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureVisual(tester, 'add-balance-validation-$dimensions');
      await tester.enterText(find.byKey(const ValueKey('deposit-name')),
          'هەژماری تاقیکردنەوەی ڕووکاری پڕۆکسۆ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('deposit-submit')));
      await tester.pumpAndSettle();
      expect(find.text('ناوی هەژمار بنووسە'), findsNothing);
      await captureVisual(tester, 'add-balance-manual-bottom-$dimensions');
      await tester.ensureVisible(find.text('Qi Card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qi Card'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('کۆپیکردنی ژمارە'));
      await tester.pumpAndSettle();
      copied = null;
      await tester.tap(find.byTooltip('کۆپیکردنی ژمارە'));
      await tester.pumpAndSettle();
      expect(copied, '0000000000');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('deposit-payment-details'))),
          alignment: .1);
      await tester.pumpAndSettle();
      await captureVisual(tester, 'payment-details-qicard-$dimensions');
      await tester.ensureVisible(find.text('FastPay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FastPay'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('deposit-name')), findsNothing);
      expect(find.byKey(const ValueKey('deposit-note')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('deposit-submit')));
      await tester.pumpAndSettle();
      expect(find.text('بەردەوامبە بۆ پارەدان'), findsOneWidget);
      await captureVisual(tester, 'add-balance-fastpay-$dimensions');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('amount validation and Arabic digit entry', (tester) async {
    setVisualViewport(tester, const Size(320, 780));
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildProxoTheme(),
        home: screen));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('deposit-amount')), '٤٩٩٩');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('deposit-submit')));
    await tester.tap(find.byKey(const ValueKey('deposit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('کەمترین بڕ 5,000 دینارە'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 780), const Size(430, 932)]) {
    testWidgets('FastPay confirmation fits ${size.width}', (tester) async {
      setVisualViewport(tester, size);
      await tester.pumpWidget(visualCapture(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildProxoTheme(),
          home: const Scaffold(
              body: Align(
                  alignment: Alignment.bottomCenter,
                  child: FastPayCheckoutSheet(
                      amountIqd: 25000, userId: 'fixture-user'))))));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          const AssetImage(kFastPayLogoAsset),
          tester.element(find.byType(FastPayCheckoutSheet))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureVisual(tester,
          'fastpay-confirmation-${size.width.toInt()}x${size.height.toInt()}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
