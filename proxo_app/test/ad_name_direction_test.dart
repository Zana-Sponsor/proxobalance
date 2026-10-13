import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/models/ad_receipt_data.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import 'package:proxo_app/widgets/receipt/ad_receipt_card.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_creation_flow_test.dart' show TestAdRepository, host;
import 'ad_receipt_data_test.dart' show receiptFixture;
import 'ad_submission_test.dart' show validDraft;
import 'text_direction_test.dart'
    show expectLtrBoxes, expectLtrToken, paragraphOf;

const _nameKey = ValueKey('ad-title');
const _names = <(String, TextDirection, List<String>)>[
  ('ڕیکلامی نوێ', TextDirection.rtl, []),
  ('إعلان جديد', TextDirection.rtl, []),
  ('Summer Campaign 2026', TextDirection.ltr, ['Summer Campaign 2026']),
  ('ABC-123', TextDirection.ltr, ['ABC-123']),
  ('2026', TextDirection.ltr, ['2026']),
  ('2026 ڕیکلام', TextDirection.rtl, ['2026']),
  ('ڕیکلام (Proxo-2026), 18-34', TextDirection.rtl, ['Proxo-2026', '18-34']),
  ('إعلان ABC-123: 19/09/2026', TextDirection.rtl, ['ABC-123', '19/09/2026']),
  ('Proxo ڕیکلام 2026!', TextDirection.ltr, ['Proxo', '2026']),
];

Finder _editable() => find.descendant(
      of: find.byKey(_nameKey),
      matching: find.byType(EditableText),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Rabar')
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('actual ad name accepts all languages and keeps native editing', (
    tester,
  ) async {
    final repo = TestAdRepository();
    await tester.pumpWidget(host(AdCreateScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byKey(_nameKey));
    final originalState = tester.state<EditableTextState>(_editable());
    final controller =
        tester.widget<TextField>(find.byKey(_nameKey)).controller!;
    final style = tester.widget<TextField>(find.byKey(_nameKey)).style;

    for (final (name, direction, tokens) in _names) {
      // Exercise the real platform text-input path, including an active IME
      // composition and a cursor inside the text rather than only at its end.
      final value = TextEditingValue(
        text: name,
        selection: const TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: name.length),
      );
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
      final field = tester.widget<TextField>(find.byKey(_nameKey));
      final editable = tester.widget<EditableText>(_editable());
      final state = tester.state<EditableTextState>(_editable());
      expect(field.keyboardType, TextInputType.name);
      expect(field.inputFormatters, isNull);
      expect(field.textAlign, TextAlign.start);
      expect(field.style, style);
      expect(editable.textDirection, direction);
      expect(editable.focusNode.hasFocus, isTrue);
      expect(state, same(originalState));
      expect(field.controller, same(controller));
      expect(controller.value, value);
      for (final token in tokens) {
        expectLtrBoxes(
          state.renderEditable.text!.toPlainText(includeSemanticsLabels: false),
          token,
          state.renderEditable.getBoxesForSelection,
        );
      }
    }
    // Deleting a leading strong letter must immediately change the direction,
    // without introducing hidden marks into the editable or submitted text.
    for (final value in const [
      TextEditingValue(
        text: 'ڕ Proxo 2026',
        selection: TextSelection(baseOffset: 2, extentOffset: 7),
        composing: TextRange(start: 2, end: 7),
      ),
      TextEditingValue(
        text: 'Proxo 2026',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
      TextEditingValue(selection: TextSelection.collapsed(offset: 0)),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
      expect(controller.value, value);
      expect(
        tester.widget<EditableText>(_editable()).textDirection,
        ProxoTextDirection.of(value.text),
      );
      expect(tester.state<EditableTextState>(_editable()), same(originalState));
    }
    expect(repo.submissions, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('direction observer ignores cursor and same-language changes', (
    tester,
  ) async {
    final first = TextEditingController(text: 'Proxo');
    final second = TextEditingController(text: 'إعلان');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var builds = 0;
    Widget input(TextEditingController controller, TextDirection fallback) =>
        MaterialApp(
          home: Directionality(
            textDirection: fallback,
            child: Scaffold(
              body: ProxoDirectionalInput(
                controller: controller,
                keyboardType: TextInputType.name,
                builder: (context, direction) {
                  builds++;
                  return TextField(
                    controller: controller,
                    textDirection: direction,
                  );
                },
              ),
            ),
          ),
        );
    await tester.pumpWidget(input(first, TextDirection.rtl));
    final initialBuilds = builds;
    first.value = const TextEditingValue(
      text: 'Proxo 2026',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 5),
    );
    await tester.pump();
    first.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
    await tester.pump();
    expect(builds, initialBuilds);
    first.text = 'ڕیکلام';
    await tester.pump();
    expect(builds, initialBuilds + 1);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).textDirection,
      TextDirection.rtl,
    );
    await tester.pumpWidget(input(second, TextDirection.rtl));
    final replacementBuilds = builds;
    first.text = 'Detached controller';
    await tester.pump();
    expect(builds, replacementBuilds);
    second.clear();
    await tester.pumpWidget(input(second, TextDirection.ltr));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).textDirection,
      TextDirection.ltr,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    second.text = 'Disposed observer';
    expect(tester.takeException(), isNull);
  });

  for (final (name, direction, tokens) in _names) {
    testWidgets('confirmation and receipt retain direction for "$name"', (
      tester,
    ) async {
      final draft = AdDraft.fromJson({...validDraft().toJson(), 'title': name});
      expect(draft.validate(), isEmpty);
      final request = AdPendingSubmission.create(
        draft,
        const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800),
      );
      final repo = TestAdRepository();
      await tester.pumpWidget(
        host(
          AdConfirmationScreen(
            request: request,
            repository: repo,
            countdown: const Duration(minutes: 1),
          ),
        ),
      );
      await tester.pump();
      final nameText = find.byWidgetPredicate(
        (widget) => widget is ProxoText && widget.data == name,
      );
      expect(nameText, findsOneWidget);
      expect(paragraphOf(tester, nameText).textDirection, direction);
      for (final token in tokens) {
        expectLtrToken(paragraphOf(tester, nameText), token);
      }
      expect(request.draft.title, name);
      expect(request.toJson()['draft'], draft.toJson());
      expect(repo.submissions, 0);

      final strings = AdDetailStrings.of(const Locale('ckb'));
      final receipt = AdReceiptData.from(
        receiptFixture()..['title'] = name,
        strings,
      );
      expect(receipt.adName, name);
      expect(receipt.adNameDir, direction);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SingleChildScrollView(
              child: ReceiptSurface(
                child: AdReceiptCard(r: receipt, l: strings, onCopy: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final receiptName = find.byWidgetPredicate(
        (widget) => widget is ProxoText && widget.data == name,
      );
      expect(receiptName, findsOneWidget);
      expect(paragraphOf(tester, receiptName).textDirection, direction);
      for (final token in tokens) {
        expectLtrToken(paragraphOf(tester, receiptName), token);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
