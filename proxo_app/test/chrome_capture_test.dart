import 'package:proxo_app/widgets/proxo_text.dart';
// Real production surfaces, deterministic read-only data, before/after evidence.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/top_bar.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

const baseline = bool.fromEnvironment('CHROME_BASELINE');
class ChromeBinding extends AutomatedTestWidgetsFlutterBinding {
  @override bool get disableShadows => false;
}
void main() {
  ChromeBinding();
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fonts = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) { loader.addFont(rootBundle.load(file['asset'] as String)); }
      await loader.load();
    }
    await backend.initialize();
  });
  tearDownAll(backend.dispose);
  for (final config in [(280.0,1.0,1.0),(393.0,1.0,3.0),(393.0,2.0,2.0),(280.0,2.0,2.0),(768.0,1.0,2.0)]) {
    for (final section in ['sidebar','profile','edit','chrome']) {
      testWidgets('$section $config', (t) async {
        final (width, scale, dpr) = config;
        t.view.devicePixelRatio = dpr;
        t.view.physicalSize = Size(width*dpr,852*dpr);
        addTearDown(t.view.resetDevicePixelRatio); addTearDown(t.view.resetPhysicalSize);
        final key = GlobalKey();
        final taps = <String>[];
        Widget surface;
        if (section == 'sidebar') {
          surface = Scaffold(body: Align(alignment: Alignment.centerRight,
            child: ProxoSidebar(onClose: () => taps.add('close'), onNavigate: taps.add)));
        } else if (section == 'profile') {
          surface = ProfileScreen(onBottomNavTap: (i) => taps.add('tab-$i'));
        } else if (section == 'edit') {
          surface = const EditProfileScreen(initialFullName: 'تاقیکردنەوە Proxo', initialEmail: 'fixture@example.invalid', initialPhone: '+9647500000000');
        } else {
          surface = Scaffold(appBar: ProxoTopBar(onMenuTap: () => taps.add('menu'),
            onNotificationTap: () => taps.add('notifications'), onSearchTap: () => taps.add('search')),
            bottomNavigationBar: ProxoBottomNav(currentIndex: 0, onTap: (i) => taps.add('tab-$i')));
        }
        await t.pumpWidget(MaterialApp(navigatorKey: app.navigatorKey,
          locale: const Locale('ar'), supportedLocales: const [Locale('ar'),Locale('en')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
          theme: ThemeData(fontFamily: kAppFont, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent)),
          builder: (context, child) => ProxoLocaleScope(child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale),disableAnimations: true),
            child: RepaintBoundary(key: key, child: child!),)),home: surface));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        Future<void> shot(String suffix) async {
          await t.runAsync(() async {
            for (final element in find.byType(Image).evaluate().toList()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await t.pumpAndSettle();
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final path='build/chrome-evidence/$section-${width.toInt()}-s$scale-d$dpr$suffix';
          await t.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: dpr);
            final data = await image.toByteData(format: ui.ImageByteFormat.png); image.dispose();
            await File('$path.png').parent.create(recursive:true);
            await File('$path.png').writeAsBytes(data!.buffer.asUint8List());
          });
          expect(t.takeException(), isNull);
        }
        await shot('');
        if (section == 'profile' || section == 'sidebar' || section == 'edit') {
          final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
          scroll.position.jumpTo(scroll.position.maxScrollExtent); await t.pumpAndSettle();
          await shot('-bottom');
        }
        if (!baseline && section == 'chrome') {
          for (final pair in [('مێنیو','menu'),('گەڕان','search')]) {
            final button=find.byTooltip(pair.$1); expect(t.getSize(button).shortestSide,greaterThanOrEqualTo(48));
            await t.tap(button); expect(taps,contains(pair.$2));
          }
          for (final i in [0,1,2,3,4]) {
            final tab=find.byKey(ValueKey('bottom-nav-$i'));
            await t.ensureVisible(tab); await t.pumpAndSettle();
            expect(t.getSize(tab).shortestSide,greaterThanOrEqualTo(48));
            await t.tap(tab); expect(taps,contains('tab-$i'));
          }
          // SVG's renderer legitimately fits its vector canvas. Application text
          // must never be shrunk to make navigation fit.
          for (final box in find.byType(FittedBox).evaluate()) {
            expect(find.descendant(of: find.byWidget(box.widget), matching: find.byType(Text)), findsNothing);
            expect(find.descendant(of: find.byWidget(box.widget), matching: find.byType(ProxoText)), findsNothing);
          }
        }
        if (!baseline && section == 'profile') {
          final profileContext=t.element(find.text('باڵانسی ڕیکلام'));
          expect(MediaQuery.textScalerOf(profileContext).scale(14),closeTo(14*scale,.001));
          await t.drag(find.byType(Scrollable).first,const Offset(0,2000)); await t.pumpAndSettle();
          final eye=find.byTooltip('شاردنەوەی باڵانس');
          await t.ensureVisible(eye); await t.pumpAndSettle(); await t.tap(eye); await t.pump();
          expect(find.byTooltip('پیشاندانی باڵانس'),findsOneWidget);
        }
        if (!baseline && section == 'sidebar') {
          await t.drag(find.byType(Scrollable).first,const Offset(0,2000)); await t.pumpAndSettle();
          await t.tap(find.text('سەرەکی')); expect(taps,contains('home'));
          expect(backend.reads['pa_user_points']??0,0);
          expect(backend.reads['pa_levels']??0,0);
        }
        await t.runAsync(() => File('build/chrome-evidence/$section-${width.toInt()}-s$scale-d$dpr.json').writeAsString(jsonEncode({
          'baseline':baseline,'section':section,'logical_width':width,'dpr':dpr,'text_scale':scale,'callbacks':taps,'fixture_reads':backend.reads,
        })));
        await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
      });
    }
  }
}
