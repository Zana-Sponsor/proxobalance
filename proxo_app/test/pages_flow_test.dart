import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'proxo_four_flow_test.dart' show FakePages, field, fill;

class ControlledPages extends FakePages {
  Completer<List<ProxoCard>>? initial;
  bool fail = false;
  bool failAfterSave = false;
  int reads = 0;
  int saves = 0;
  Completer<void>? saveGate;
  @override
  Future<List<ProxoCard>> cards() async {
    reads++;
    if (reads == 1 && initial != null) return initial!.future;
    if (fail || (failAfterSave && saves > 0)) {
      throw const ProxoLinkFailure('network_error');
    }
    return rows;
  }

  @override
  Future<ProxoCard> save(Map<String, dynamic> data,
      {ProxoCard? existing}) async {
    saves++;
    await saveGate?.future;
    return super.save(data, existing: existing);
  }
}

class FailingDraftCleanup extends ProxoPageDraftStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> clear(String key) async =>
      throw StateError('Device storage unavailable');
}

Future<void> open(WidgetTester t, ControlledPages pages,
    {ProxoPageDraftStorage draftStorage =
        const SharedPreferencesPageDraftStorage()}) async {
  await t.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: ToolsScreen(repository: pages, draftStorage: draftStorage)));
  await t.pumpAndSettle();
}

Future<void> createTikTokPage(WidgetTester t) async {
  await t.tap(find.text('دروستکردنی پەڕە'));
  await t.pumpAndSettle();
  await fill(t, 'ناو', 'پەڕەی Proxo 2026');
  await fill(t, 'ناوی تیکتۆک', '@proxo_iq');
  final submit = find.text('دروستکردن');
  await t.ensureVisible(submit);
  await t.tap(submit);
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 430.0]) {
    testWidgets(
        'first visit shows page list and explicit empty action at $width',
        (t) async {
      t.view.physicalSize = Size(width, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = ControlledPages();
      await open(t, repo);
      expect(find.text('پەڕەکان'), findsOneWidget);
      expect(find.text('هێشتا پەڕەیەکت نییە'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await t.tap(find.text('دروستکردنی پەڕە'));
      await t.pumpAndSettle();
      expect(field('ناو'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('loading and retrieval errors never appear as an empty account',
      (t) async {
    final repo = ControlledPages()..initial = Completer<List<ProxoCard>>();
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: ToolsScreen(repository: repo)));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('هێشتا پەڕەیەکت نییە'), findsNothing);
    repo.initial!.completeError(const ProxoLinkFailure('network_error'));
    await t.pumpAndSettle();
    expect(find.text('نەتوانرا پەڕەکان پیشان بدرێن'), findsOneWidget);
    expect(find.text('دروستکردنی پەڕە'), findsNothing);
    await t.tap(find.text('دووبارە هەوڵبدەرەوە'));
    await t.pumpAndSettle();
    expect(find.text('هێشتا پەڕەیەکت نییە'), findsOneWidget);
  });
  testWidgets('created page remains visible if follow-up refresh fails',
      (t) async {
    final repo = ControlledPages()..failAfterSave = true;
    await open(t, repo);
    await createTikTokPage(t);
    expect(repo.saves, 1);
    expect(repo.submitted?['tt'], 'proxo_iq');
    expect(find.text('پەڕەی Proxo 2026'), findsOneWidget);
    expect(find.text('نەتوانرا پەڕەکان پیشان بدرێن'), findsOneWidget);
    expect(t.takeException(), isNull);
    repo.failAfterSave = false;
    await t.pumpWidget(const SizedBox.shrink());
    await open(t, repo);
    expect(find.text('پەڕەی Proxo 2026'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets(
      'name and TikTok validation prevents submission with invalid values',
      (t) async {
    final repo = ControlledPages();
    await open(t, repo);
    await t.tap(find.text('دروستکردنی پەڕە'));
    await t.pumpAndSettle();
    final submit = find.text('دروستکردن');
    await t.ensureVisible(submit);
    await t.tap(submit);
    await t.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.text('تکایە ئەم خانەیە پڕ بکەرەوە.'), findsOneWidget);
    await fill(t, 'ناو', 'Proxo');
    await fill(t, 'ناوی تیکتۆک', 'https://tiktok.com/@proxo');
    await t.ensureVisible(submit);
    await t.tap(submit);
    await t.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.textContaining('تکایە ناوی تیکتۆک بپشکنە'), findsOneWidget);
  });
  testWidgets('local draft cleanup failure cannot undo a successful page save',
      (t) async {
    final repo = ControlledPages();
    await open(t, repo, draftStorage: FailingDraftCleanup());
    await createTikTokPage(t);
    expect(repo.saves, 1);
    expect(find.text('پەڕەی Proxo 2026'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'back and repeated taps cannot dismiss or duplicate a pending save',
      (t) async {
    final repo = ControlledPages()..saveGate = Completer<void>();
    await open(t, repo);
    await t.tap(find.text('دروستکردنی پەڕە'));
    await t.pumpAndSettle();
    await fill(t, 'ناو', 'پەڕەی Proxo 2026');
    await fill(t, 'ناوی تیکتۆک', '@proxo_iq');
    final submit = find.text('دروستکردن');
    await t.ensureVisible(submit);
    await t.tap(submit);
    await t.pump();
    expect(repo.saves, 1);
    await t.tap(find.text('لە دروستکردندایە...'), warnIfMissed: false);
    await t.pump();
    expect(repo.saves, 1);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(field('ناو'), findsOneWidget);
    expect(find.text('تکایە چاوەڕێ بکە تا پاشەکەوتکردن تەواو دەبێت.'),
        findsOneWidget);
    expect(repo.saves, 1);
    repo.saveGate!.complete();
    await t.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('پەڕەی Proxo 2026'), findsOneWidget);
    expect(repo.saves, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('an inactive kept-alive page form does not intercept parent Back',
      (t) async {
    final repo = ControlledPages();
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    await t.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ValueListenableBuilder<bool>(
                      valueListenable: active,
                      builder: (_, isActive, __) => IndexedStack(
                        index: isActive ? 0 : 1,
                        children: [
                          ToolsScreen(
                              repository: repo,
                              initialCreate: true,
                              isActive: isActive),
                          const Scaffold(body: Text('Other tab')),
                        ],
                      ),
                    ),
                  )),
                  child: const Text('Open shell'),
                ),
              )),
    ));
    await t.tap(find.text('Open shell'));
    await t.pumpAndSettle();
    expect(field('ناو'), findsOneWidget);
    // The active form consumes Back to return to its own list.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('هێشتا پەڕەیەکت نییە'), findsOneWidget);
    await t.tap(find.text('دروستکردنی پەڕە'));
    await t.pumpAndSettle();
    active.value = false;
    await t.pumpAndSettle();
    expect(find.text('Other tab'), findsOneWidget);
    expect(find.byType(ToolsScreen, skipOffstage: false), findsOneWidget);
    // Its offstage PopScope must allow the visible route to pop.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Open shell'), findsOneWidget);
    expect(find.byType(ToolsScreen, skipOffstage: false), findsNothing);
    expect(t.takeException(), isNull);
  });
}
