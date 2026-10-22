import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/theme/proxo_surface.dart';
import 'package:proxo_app/widgets/proxo_app_bar.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader(ProxoSurface.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/Rabar_022.ttf'));
    await font.load();
  });
  for (final width in [280.0, 320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'secondary title stays fully inside toolbar at $width / $scale',
          (t) async {
        t.view.physicalSize = Size(width, 740);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => ProxoLocaleScope(
            child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 24),
                    textScaler: TextScaler.linear(scale)),
                child: child!),
          ),
          home: Builder(
              builder: (context) => Scaffold(
                    appBar: ProxoAppBar.adaptive(context,
                        title: 'زیادکردنی باڵانس'),
                    body: const SizedBox.expand(key: ValueKey('body')),
                  )),
        ));
        await t.pumpAndSettle();
        final title = find.byKey(const ValueKey('proxo-screen-title'));
        final rich =
            find.descendant(of: title, matching: find.byType(RichText));
        final paragraph = t.renderObject<RenderParagraph>(rich);
        final bounds = t.getRect(rich);
        final body = t.getRect(find.byKey(const ValueKey('body')));
        final style = paragraph.text.style!;
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout(maxWidth: paragraph.size.width);
        expect(style.fontFamily, ProxoSurface.fontFamily);
        expect(paragraph.textScaler.scale(16), closeTo(16 * scale, .01));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, closeTo(painter.height, .01),
            reason:
                'All shaped title lines must be visible, not height-clipped');
        expect(bounds.top, greaterThanOrEqualTo(24));
        expect(bounds.bottom, lessThanOrEqualTo(body.top));
        expect(bounds.center.dx, closeTo(width / 2, .1));
        final header = t.widget<ProxoAppBar>(find.byType(ProxoAppBar));
        expect(header.preferredSize.height, greaterThanOrEqualTo(56));
        if (scale == 1 && width >= 320) {
          expect(header.preferredSize.height, 56);
        }
        expect(t.getSize(find.byType(IconButton)), const Size(48, 48));
        expect(t.takeException(), isNull);
        painter.dispose();
      });
    }
  }
}
