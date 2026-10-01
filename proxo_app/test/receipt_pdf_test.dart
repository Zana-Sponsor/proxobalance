import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/models/ad_receipt_data.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/receipt/ad_receipt_card.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_receipt_data_test.dart' show receiptFixture, freeReceiptFixture;
import 'receipt_test_helpers.dart';

// Match production paint: the default test binding disables shadow blur.
class ReceiptPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  ReceiptPaintBinding();
  setUpAll(() async {
    final loader = FontLoader(ReceiptTokens.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'));
    await loader.load();
  });
  for (final transaction in [false, true]) {
    for (final narrow in [false, true]) {
      testWidgets(
          'PDF captures full ${transaction ? "transaction" : "ad"} ${narrow ? "narrow" : "standard"} receipt',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(narrow ? 280 : 393, 640);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var key = GlobalKey();
        final originalLocale = ProxoLocale.current.value;
        ProxoLocale.current.value =
            Locale(transaction && narrow ? 'ar' : 'ckb');
        addTearDown(() => ProxoLocale.current.value = originalLocale);
        final l = AdDetailStrings.of(const Locale('ckb'));
        final data = (narrow ? receiptFixture() : freeReceiptFixture())
          ..['public_ad_id'] = 'PARZNFHCOKVL'
          ..['title'] = narrow
              ? 'New Ad 2021 — Long sponsor name / ناوی سپۆنسەرێکی درێژ'
              : 'New Ad 2021';
        final receipt = AdReceiptData.from(data, l);
        Uint8List? pdf;
        String? filename;
        var shares = 0;
        const channel = MethodChannel('net.nfet.printing');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
            (call) async {
          if (call.method == 'sharePdf') {
            final args = call.arguments as Map<dynamic, dynamic>;
            pdf = args['doc'] as Uint8List;
            filename = args['name'] as String;
            shares++;
            return 1;
          }
          return null;
        });
        addTearDown(() => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null));
        const txId = '83062db4-47d0-4ce1-a3b4-33a766783553';
        final txScreen = TransactionDetailScreen(
          data: TxReceiptData(
            kind: TxReceiptKind.adPayment,
            status: 'approved',
            txId: txId,
            uid: '720079a8-9cf7-44de-b3af-f396d1aaf7d8',
            date: DateTime.utc(2026, 9, 29),
            usd: 15,
            amountIqd: 21000,
            balanceBefore: 42000,
            balanceAfter: 21000,
            method: 'FastPay Merchant Online Payment Method',
            gateway: 'fastpay',
            type: 'ad_payment',
            adName: data['title'] as String,
            voucherCode: null,
          ),
        );
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(narrow ? 2 : 1)),
                      child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: transaction
                              ? txScreen
                              : Scaffold(
                                  backgroundColor: Colors.white,
                                  body: ReceiptBody(children: [
                                    RepaintBoundary(
                                        key: key,
                                        child: ReceiptSurface(
                                            child: AdReceiptCard(
                                                r: receipt,
                                                l: l,
                                                onCopy: (_) {}))),
                                    ReceiptWidth(
                                        child: ReceiptPdfButton(
                                            label: l.pdfButton,
                                            onPressed: () async {})),
                                  ]))),
                    ))));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
            scrollable: find.byType(Scrollable));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final rowMeasurements = auditReceiptRows(tester);
        if (transaction) {
          key = tester
              .widget<RepaintBoundary>(find
                  .ancestor(
                    of: find.byType(ReceiptSurface),
                    matching: find.byType(RepaintBoundary),
                  )
                  .first)
              .key! as GlobalKey;
          expect(find.text(txId), findsOneWidget);
        } else {
          expect(find.text(receipt.adId), findsOneWidget);
          expect(find.text(receipt.uid), findsOneWidget);
          expect(tester.getRect(find.text(receipt.uid)).top,
              greaterThan(tester.getRect(find.text(receipt.adName)).bottom));
        }
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final surfaceRect = tester.getRect(find.byType(ReceiptSurface));
        final cardRect = tester.getRect(find.byType(ReceiptCard));
        expect(boundary.size.width, narrow ? 280 : 393);
        expect(cardRect.left - surfaceRect.left, narrow ? 12 : 16);
        expect(cardRect.top - surfaceRect.top, ReceiptTokens.pageTop);
        expect(
            surfaceRect.bottom - cardRect.bottom, ReceiptTokens.cardToButton);
        if (narrow && !transaction) {
          expect(boundary.size.height, greaterThan(640));
        }
        late Future<bool> future;
        await tester.runAsync(() async {
          future = exportReceiptPdf(
              boundaryKey: key,
              title: l.receiptTitle,
              fileStem: transaction ? txId : receipt.adId);
        });
        var completed = false;
        future.then((_) => completed = true);
        for (var frame = 0; frame < 500 && !completed; frame++) {
          await tester.pump();
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)));
        }
        expect(completed, isTrue,
            reason: 'PDF export must finish after assets and frames are ready');
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await tester.runAsync(() async {
          expect(await future, isTrue);
          expect(shares, 1);
          expect(filename,
              transaction ? 'Proxo-$txId.pdf' : 'Proxo-PARZNFHCOKVL.pdf');
          expect(String.fromCharCodes(pdf!.take(5)), '%PDF-');
          const output = String.fromEnvironment('RECEIPT_PDF_CAPTURE');
          if (output.isNotEmpty) {
            final name = transaction
                ? (narrow ? 'transaction_narrow' : 'transaction_standard')
                : (narrow ? 'narrow_paid' : 'standard_free');
            await Directory(output).create(recursive: true);
            await File('$output/$name.pdf').writeAsBytes(pdf!);
            final image = await boundary.toImage(pixelRatio: 4);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('$output/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
            await File('$output/$name.json').writeAsString(jsonEncode({
              'width': boundary.size.width,
              'height': boundary.size.height,
              'card_width': cardRect.width,
              'card_height': cardRect.height,
              'card_left': cardRect.left - surfaceRect.left,
              'card_top': cardRect.top - surfaceRect.top,
              'public_ad_id': receipt.adId,
              'receipt_uuid': receipt.uid,
              'rows': rowMeasurements,
            }));
          }
        });
      });
    }
  }
}
