import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/models/ad_receipt_data.dart';
import 'package:proxo_app/widgets/receipt/ad_receipt_card.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_receipt_data_test.dart' show freeReceiptFixture;
import 'receipt_test_helpers.dart';

class ReferencePaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  ReferencePaintBinding();
  setUpAll(() async {
    await (FontLoader(ReceiptTokens.fontFamily)
          ..addFont(rootBundle.load(ReceiptTokens.fontAsset)))
        .load();
  });

  testWidgets('matches the supplied 393 by 627 receipt reference',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final strings = AdDetailStrings.of(const Locale('ckb'));
    final data = freeReceiptFixture()
      ..['public_ad_id'] = 'PARZNFHCOKVL'
      ..['title'] = 'New Ad 2021';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ReceiptBody(children: [
            RepaintBoundary(
              key: boundaryKey,
              child: ReceiptSurface(
                child: AdReceiptCard(
                  r: AdReceiptData.from(data, strings),
                  l: strings,
                  onCopy: (_) {},
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() => precacheImage(
          const AssetImage(ReceiptTokens.logoAsset),
          tester.element(find.byType(ReceiptHeader)),
        ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final pngBytes = await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        return png!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    });
    // This golden predates the changes: never regenerate it to accept drift.
    await tester.runAsync(() => expectLater(
        pngBytes!, matchesGoldenFile('../docs/receipt_preview.png')));
    const capturePath = String.fromEnvironment('RECEIPT_REFERENCE_CAPTURE');
    if (capturePath.isNotEmpty) {
      await tester.runAsync(() async {
        await File(capturePath).parent.create(recursive: true);
        await File(capturePath).writeAsBytes(pngBytes!);
      });
    }

    final surface = receiptPaintedRect(tester, find.byType(ReceiptSurface));
    final card = receiptPaintedRect(tester, find.byType(ReceiptCard));
    expect(surface.size, const Size(393, 627));
    expect(card, const Rect.fromLTWH(16, 16, 361, 591));
    final dividers = find.byType(ReceiptDivider);
    const dividerTops = <double>[66, 139, 324, 453, 526];
    expect(dividers, findsNWidgets(dividerTops.length));
    for (var i = 0; i < dividerTops.length; i++) {
      final rule = receiptPaintedRect(
          tester,
          find.descendant(
              of: dividers.at(i), matching: find.byType(ColoredBox)));
      expect(rule, Rect.fromLTWH(40, dividerTops[i], 313, 1));
    }
    final rows = find.byWidgetPredicate(
        (widget) => widget is ReceiptRow || widget is ReceiptIdRow);
    const rowTops = <double>[
      79,
      107,
      180,
      208,
      236,
      264,
      292,
      365,
      393,
      421,
      494,
      539,
      567,
    ];
    expect(rows, findsNWidgets(rowTops.length));
    for (var i = 0; i < rowTops.length; i++) {
      expect(receiptPaintedRect(tester, rows.at(i)),
          Rect.fromLTWH(32, rowTops[i], 329, 20));
    }
    expect(find.byType(IconButton), findsNothing);
    auditReceiptRows(tester);
  });
}
