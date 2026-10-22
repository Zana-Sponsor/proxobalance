import 'package:proxo_app/widgets/ad_validation_notifications.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/auth/auth_models.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';
import 'package:proxo_app/widgets/auth/auth_header.dart';
import 'package:proxo_app/widgets/proxo_error_stack.dart';
import 'package:proxo_app/widgets/proxo_notice.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import 'package:proxo_app/theme/app_theme.dart';

class RefinementBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  RefinementBinding();
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
  });
  test(
      'phone input accepts Kurdish/Arabic digits and international paste without moving mid-edit caret',
      () {
    const f = IraqPhoneInputFormatter();
    for (final raw in [
      '٠٧٥٠١٢٣٤٥٦٧',
      '۰۷۵۰۱۲۳۴۵۶۷',
      '+964 750 123 4567',
      '00964 7501234567'
    ]) {
      final v = f.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
              text: raw,
              selection: TextSelection.collapsed(offset: raw.length)));
      expect(v.text, '7501234567');
      expect(v.selection.baseOffset, 10);
      expect(IraqPhone.isValid(raw), isTrue);
    }
    const old = TextEditingValue(
        text: '7501234567', selection: TextSelection.collapsed(offset: 4));
    final edit = f.formatEditUpdate(
        old,
        const TextEditingValue(
            text: '7509234567', selection: TextSelection.collapsed(offset: 4)));
    expect(edit.selection.baseOffset, 4);
    expect(f.formatEditUpdate(old, const TextEditingValue(text: '75012345678')),
        old);
  });
  testWidgets(
      'empty phone field shows country code; ordinary fields do not add decorative symbols',
      (t) async {
    final c = TextEditingController();
    await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: AuthTextField(
                    controller: c,
                    label: 'Phone',
                    hint: '7XX XXX XXXX',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    forceLtr: true,
                    ltr: true,
                    prefix: const Text('+964'),
                    inputFormatters: const [IraqPhoneInputFormatter()])))));
    expect(find.text('+964'), findsOneWidget);
    expect(t.getSize(find.text('+964')).width, greaterThan(0));
    expect(find.byType(ProxoSymbol), findsNothing);
    await t.enterText(find.byType(TextField), '٠٧٥٠١٢٣٤٥٦٧');
    expect(c.text, '7501234567');
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'narrow large text keeps Auth words and phone hint on complete lines',
      (t) async {
    t.view.physicalSize = const Size(280, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const AuthTitle('چوونەژوورەوە'),
                  AuthSegmentedControl(
                      labels: const ['رقم الهاتف', 'البريد الإلكتروني'],
                      index: 1,
                      onChanged: (_) {}),
                  AuthTextField(
                      controller: controller,
                      label: 'ژمارەی مۆبایل',
                      hint: '7XX XXX XXXX',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      ltr: true,
                      forceLtr: true,
                      prefix: const Text('+964')),
                ])))));
    final title = t.renderObject<RenderParagraph>(find
        .descendant(of: find.byType(AuthTitle), matching: find.byType(RichText))
        .first);
    final lines = title.getBoxesForSelection(TextSelection(
        baseOffset: 0, extentOffset: title.text.toPlainText().length));
    expect(lines.map((b) => b.top).toSet().length, 1);
    expect(
        title.textScaler.scale(title.text.style!.fontSize!), greaterThan(26));
    final email = t.renderObject<RenderParagraph>(find
        .descendant(
            of: find.text('البريد الإلكتروني'), matching: find.byType(RichText))
        .first);
    final wordStart = email.text.toPlainText().indexOf('الإلكتروني');
    final wordBoxes = email.getBoxesForSelection(TextSelection(
        baseOffset: wordStart, extentOffset: wordStart + 'الإلكتروني'.length));
    expect(wordBoxes.map((b) => b.top).toSet().length, 1);
    expect(
        email.textScaler.scale(email.text.style!.fontSize!), greaterThan(14));
    final hint = t.renderObject<RenderParagraph>(find
        .descendant(of: find.byType(FittedBox), matching: find.byType(RichText))
        .first);
    expect(hint.maxLines, 1);
    expect(t.getSize(find.byType(TextField)).height, lessThan(100));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final width in [280.0, 393.0]) {
    testWidgets(
        'one compact notice stays readable without a modal touch layer at $width',
        (t) async {
      t.view.physicalSize = Size(width, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      late BuildContext screen;
      await t.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  fontFamily: kAppFont,
                  scaffoldBackgroundColor: const Color(0xFFF8FAFC)),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(width == 280 ? 2 : 1),
                      accessibleNavigation: true),
                  child: child!),
              home: Builder(builder: (context) {
                screen = context;
                return const Scaffold();
              }))));
      for (final message in [
        'تکایە ناوی ڕیکلام بنووسە',
        'بڕی پارەکە پشکنین بکە',
        'پەیوەندی ئینتەرنێت بپشکنە و دووبارە هەوڵ بدەرەوە'
      ]) {
        ProxoErrorStack.show(screen, message);
        await t.pump(const Duration(milliseconds: 500));
      }
      await t.pumpAndSettle();
      expect(find.byType(ProxoNoticeCard), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
      final front = t.getRect(find.byType(ProxoNoticeCard));
      expect(front.width, lessThanOrEqualTo(width - 32));
      expect(front.height, lessThan(341));
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final dir = Directory('build/polish-evidence/refinement')
          ..createSync(recursive: true);
        final b = boundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${dir.path}/error-stack-${width.toInt()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(find.text('بڕی پارەکە پشکنین بکە'), findsNothing);
      // Replacements never leave a hidden queue behind.
      for (var i = 0; i < 6; i++) {
        ProxoErrorStack.show(screen, 'Queued error $i');
        await t.pump();
      }
      ProxoErrorStack.clear();
      await t.pumpAndSettle();
      expect(find.byType(ProxoNoticeCard), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Create Ad validation shares one content-sized notification',
      (t) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final controller = AdValidationController();
    final boundary = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: Scaffold(
                body: Padding(
                    padding: const EdgeInsets.all(16),
                    child:
                        AdValidationNotifications(controller: controller))))));
    controller.show({
      'name': 'تکایە ناوی ڕیکلام بنووسە',
      'budget': 'بڕی پارەکە پشکنین بکە',
      'link': 'لینکی ڤیدیۆ بنووسە'
    });
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    final total = t.getSize(find.byType(AdValidationNotifications));
    expect(total.height, lessThan(150));
    expect(t.takeException(), isNull);
    await t.runAsync(() async {
      final dir = Directory('build/polish-evidence/refinement')
        ..createSync(recursive: true);
      final b =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final im = await b.toImage(pixelRatio: 2);
      final png = await im.toByteData(format: ui.ImageByteFormat.png);
      await File('${dir.path}/ad-validation-stack.png')
          .writeAsBytes(png!.buffer.asUint8List());
      im.dispose();
    });
    await t.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
