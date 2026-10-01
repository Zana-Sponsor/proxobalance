import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/auth/auth_otp_field.dart';

/// Lifecycle tests for AuthOtpBoxes — the one widget in the auth module with
/// genuinely tricky ownership: it BORROWS box 0's FocusNode from the screen,
/// owns the other five, owns all six TextEditingControllers, subscribes to an
/// external controller, and runs a ticker.
///
/// These are the assertions a heap snapshot would be making, expressed as
/// something CI can run on every commit instead of something a human runs by
/// hand on a device.
void main() {
  late TextEditingController code;
  late FocusNode firstBox;
  late OtpShakeController shaker;

  setUp(() {
    code = TextEditingController();
    firstBox = FocusNode();
    shaker = OtpShakeController();
  });

  tearDown(() {
    code.dispose();
    firstBox.dispose();
    shaker.dispose();
  });

  Widget host({int length = 6, bool hasError = false}) => MaterialApp(
        home: Scaffold(
          body: AuthOtpBoxes(
            length: length,
            codeController: code,
            firstBoxFocus: firstBox,
            shaker: shaker,
            hasError: hasError,
            onCompleted: (_) {},
          ),
        ),
      );

  testWidgets('renders one box per digit', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('typing syncs into the screen-owned controller', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '2');
    expect(code.text, '12');
  });

  testWidgets('a paste is distributed across the boxes', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    // A paste arrives as one multi-character change on the focused box.
    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.pump();
    expect(code.text, '123456');
  });

  testWidgets('an external clear empties the boxes', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '9');
    expect(code.text, '9');

    // This is what the backend does from _doVerifyOtp and _cancelOtpAndGoBack.
    code.clear();
    await tester.pump();

    final TextField first = tester.widget(find.byType(TextField).at(0));
    expect(first.controller!.text, isEmpty);
  });

  testWidgets('disposes without touching the borrowed focus node',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // Replace the widget entirely — this disposes the boxes' State.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Box 0's node belongs to the screen. If the widget had disposed it, this
    // would throw "A FocusNode was used after being disposed" — and the
    // screen's own dispose() would then throw a second time in production.
    expect(() => firstBox.hasFocus, returnsNormally);
  });

  testWidgets('shake mid-flight then dispose does not strand the future',
      (tester) async {
    await tester.pumpWidget(host(hasError: true));
    await tester.pump();

    // Start the 250ms shake, advance partway, then tear the widget down. With
    // a bare `await controller.forward()` the TickerFuture never completes and
    // the suspended frame retains the State. `.orCancel` is what makes this
    // finish cleanly.
    unawaited(shaker.shakeAndReset());
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });

  testWidgets('changing length rebuilds the box arrays cleanly',
      (tester) async {
    await tester.pumpWidget(host(length: 6));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(6));

    await tester.pumpWidget(host(length: 4));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('six boxes fit a 320dp phone without overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });
}
