import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/tx_strings.dart';
import 'package:proxo_app/widgets/receipt/tx_history_layout.dart';

import 'receipt_test_helpers.dart' show receiptPaintedRect;

class HistoryPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const captureKey = ValueKey('history-capture');
const firstCardKey = ValueKey('first-transaction');

Widget historyHost({
  double scale = 1,
  Locale locale = const Locale('ckb'),
  bool refreshing = false,
  bool skeleton = false,
  String amount = '-0 د.ع',
  EdgeInsets padding = const EdgeInsets.only(top: 24, bottom: 16),
  VoidCallback? onBack,
  VoidCallback? onRefresh,
  VoidCallback? onOpen,
}) {
  final l = TxStrings.of(locale);
  return MaterialApp(
    home: Builder(
      builder: (context) => RepaintBoundary(
        key: captureKey,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: padding,
            viewPadding: padding,
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: TxHistoryLayout(
              title: l.historyTitle,
              backLabel: l.back,
              refreshLabel: l.refresh,
              onBack: onBack ?? () {},
              onRefresh: refreshing ? null : (onRefresh ?? () {}),
              refreshing: refreshing,
              body: skeleton
                  ? const TxHistorySkeletonList()
                  : ListView.separated(
                      padding: const EdgeInsets.all(TxHistoryTokens.gutter),
                      itemCount: 2,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: TxHistoryCard.gap),
                      itemBuilder: (_, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: TxHistoryTokens.contentMaxWidth,
                          ),
                          child: TxHistoryCard(
                            key: index == 0 ? firstCardKey : null,
                            date: '22/09/2026',
                            time: '03:26 PM',
                            amount: amount,
                            amountColor: TxHistoryTokens.negative,
                            onTap: onOpen ?? () {},
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  HistoryPaintBinding();
  setUpAll(() async {
    await (FontLoader(TxHistoryTokens.fontFamily)
          ..addFont(rootBundle.load(TxHistoryTokens.fontAsset)))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final width in <double>[280, 393, 430, 768]) {
    for (final scale in <double>[1, 1.3]) {
      testWidgets('LTR history fits $width dp at $scale text scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 852);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(historyHost(scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
            isNull);
        final l = TxStrings.of(const Locale('ckb'));
        final title = find.text(l.historyTitle);
        final back = find.byTooltip(l.back);
        final refresh = find.byTooltip(l.refresh);
        expect(Directionality.of(tester.element(back)), TextDirection.ltr);
        expect(tester.widget<Text>(title).textDirection, TextDirection.rtl);
        expect(tester.getCenter(back).dx, lessThan(width / 2));
        expect(tester.getCenter(refresh).dx, greaterThan(width / 2));
        expect(tester.getCenter(title).dx, closeTo(width / 2, 0.01));
        expect(tester.getSize(back), const Size(48, 48));
        expect(tester.getSize(refresh), const Size(48, 48));
        expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            TxHistoryTokens.page);
        final card = find.byKey(firstCardKey);
        final texts = find.descendant(
            of: card,
            matching: find.byWidgetPredicate((widget) => widget is Text));
        expect(texts, findsNWidgets(3));
        final bounds = [
          for (var i = 0; i < 3; i++) receiptPaintedRect(tester, texts.at(i)),
        ];
        expect(bounds[0].bottom, lessThan(bounds[1].top));
        expect(bounds[1].right, lessThan(bounds[2].left));
        expect(bounds[1].center.dy, closeTo(bounds[2].center.dy, 0.01));
        for (final finder in [
          title,
          ...[texts.at(0), texts.at(1), texts.at(2)]
        ]) {
          final style = tester.widget<Text>(finder).style!;
          expect(style.fontFamily, TxHistoryTokens.fontFamily);
          expect(style.fontWeight, FontWeight.w400);
        }
        expect(tester.widget<Text>(texts.at(0)).style!.fontSize, 20);
        expect(tester.widget<Text>(texts.at(1)).style!.fontSize, 13);
        expect(tester.widget<Text>(texts.at(2)).style!.fontSize, 14);
      });
    }
  }

  testWidgets('back, refresh and card taps reach their handlers',
      (tester) async {
    var back = 0;
    var refresh = 0;
    var open = 0;
    final l = TxStrings.of(const Locale('ckb'));
    await tester.pumpWidget(historyHost(
      onBack: () => back++,
      onRefresh: () => refresh++,
      onOpen: () => open++,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.back));
    await tester.tap(find.byTooltip(l.refresh));
    await tester.tap(find.byKey(firstCardKey));
    expect([back, refresh, open], [1, 1, 1]);
    await tester.pumpWidget(historyHost(refreshing: true));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == l.refresh,
          ))
          .onPressed,
      isNull,
    );
  });

  testWidgets('long amount and skeleton fit a narrow screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(historyHost(scale: 1.3, amount: '-999,999,999 د.ع'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('-999,999,999 د.ع'), findsNWidgets(2));
    await tester.pumpWidget(historyHost(skeleton: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic title keeps the same LTR controls', (tester) async {
    final l = TxStrings.of(const Locale('ar'));
    await tester.pumpWidget(historyHost(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text(l.historyTitle), findsOneWidget);
    expect(Directionality.of(tester.element(find.byTooltip(l.back))),
        TextDirection.ltr);
  });

  testWidgets('history error and empty states retain their design and retry',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l = TxStrings.of(const Locale('ckb'));
    var retries = 0;
    Widget stateHost({bool failed = true}) => MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: TxHistoryStateView(
                title: failed ? l.loadErrorTitle : l.emptyTitle,
                message: failed ? l.loadErrorBody : l.emptyBody,
                actionLabel: failed ? l.retry : null,
                onAction: failed ? () => retries++ : null,
              ),
            ),
          ),
        );
    await tester.pumpWidget(stateHost());
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text(l.loadErrorTitle));
    final message = tester.widget<Text>(find.text(l.loadErrorBody));
    expect(title.style!.fontFamily, 'RabarAuthRegular');
    expect(title.style!.fontSize, 16);
    expect(message.style!.fontSize, 14);
    final action = find.byType(InkWell);
    expect(tester.getRect(action).left, 20);
    expect(tester.getSize(action), const Size(280, 48));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(stateHost(failed: false));
    await tester.pumpAndSettle();
    expect(find.text(l.emptyTitle), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('render the redesigned history screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(historyHost());
    await tester.pumpAndSettle();
    const output = String.fromEnvironment('TX_HISTORY_PREVIEW');
    if (output.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
