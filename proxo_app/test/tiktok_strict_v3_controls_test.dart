import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/theme/tiktok_ad_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildAppTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(child: SizedBox(width: 240, child: child)),
          ),
        ),
      );

  for (final style in [AdChoiceStyle.primary, AdChoiceStyle.secondary]) {
    testWidgets(
      '$style uses its specified colors without moving on selection',
      (tester) async {
        var selected = false;
        late StateSetter change;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return AdChoice(
                  key: const ValueKey('choice'),
                  style: style,
                  label: style == AdChoiceStyle.primary
                      ? 'نامە و پەیوەندی'
                      : 'هەموو پلاتفۆڕمەکان',
                  selected: selected,
                  onTap: () => setState(() => selected = !selected),
                );
              },
            ),
          ),
        );
        final choice = find.byKey(const ValueKey('choice'));
        final container = find.descendant(
          of: choice,
          matching: find.byType(AnimatedContainer),
        );
        final text = find.descendant(
          of: choice,
          matching: find.byType(ProxoText),
        );
        BoxDecoration decoration() =>
            tester.widget<AnimatedContainer>(container).decoration!
                as BoxDecoration;
        final size = tester.getSize(choice);
        final position = tester.getTopLeft(choice);
        final inactive = decoration();
        expect(inactive.color, Colors.white);
        expect(
          tester.widget<ProxoText>(text).style!.color,
          style == AdChoiceStyle.primary
              ? TikTokAdTokens.muted
              : TikTokAdTokens.ink,
        );
        expect((inactive.border! as Border).top.color, const Color(0xFFEEEEEE));
        expect(inactive.borderRadius, TikTokAdTokens.controlRadius);
        final animated = tester.widget<AnimatedContainer>(container);
        expect(animated.duration, const Duration(milliseconds: 180));
        expect(animated.curve, Curves.easeOutCubic);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(tester.getSize(choice), size);
        expect(tester.getTopLeft(choice), position);
        final active = decoration();
        if (style == AdChoiceStyle.primary) {
          expect(active.color, TikTokAdTokens.blue);
          expect(tester.widget<ProxoText>(text).style!.color, Colors.white);
          expect((active.border! as Border).top.color, Colors.transparent);
        } else {
          expect(active.color, isNot(TikTokAdTokens.blue));
          expect(active.color, isNot(Colors.white));
          expect(tester.widget<ProxoText>(text).style!.color,
              TikTokAdTokens.secondaryBlue);
          expect((active.border! as Border).top.color,
              TikTokAdTokens.selectedLine);
        }
        change(() => selected = false);
        await tester.pumpAndSettle();
        expect(decoration().color, Colors.white);
        expect(tester.getSize(choice), size);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'open sections remove wrappers while shared default stays a card',
    (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdFormSection(
                key: ValueKey('flat'),
                title: 'جۆری ڕیکلام',
                style: AdSectionStyle.open,
                child: Text('TikTok'),
              ),
              AdFormSection(
                key: ValueKey('default'),
                title: 'Meta',
                child: Text('Meta default'),
              ),
            ],
          ),
        ),
      );
      Container surface(String key) => tester.widget<Container>(
            find
                .descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(Container),
                )
                .first,
          );
      expect(surface('flat').decoration, isNull);
      expect(surface('flat').padding, EdgeInsets.zero);
      expect(surface('default').decoration, isA<BoxDecoration>());
      expect(
        (surface('default').decoration! as BoxDecoration).boxShadow,
        AdUi.cardShadow,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
