import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';

import 'ad_submission_test.dart' show validDraft;
import 'responsive_ad_ui_test.dart' show expectVisibleTextFits;

class _RejectedRepository extends AdCreationRepository {
  final bool uncertain;
  int submissions = 0;
  _RejectedRepository(this.uncertain);
  @override
  Future<List<Map<String, dynamic>>> loadAssets() async => [];
  @override
  Future<AdPendingSubmission?> pending() async => null;
  @override
  Future<AdQuote> quote(AdDraft draft) async =>
      const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800);
  @override
  Future<String> submit(
    AdPendingSubmission request,
    ValueNotifier<AdPaymentProgress> progress,
  ) async {
    submissions++;
    throw AdSubmissionFailure(
      uncertain ? 'NETWORK' : 'INSUFFICIENT_FUNDS',
      uncertain: uncertain,
    );
  }
}

void main() {
  for (final (platform, type, goal, heading, label) in [
    ('TIKTOK', 'contact', 'messages', 'جۆری ڕیکلام', 'نامە و پەیوەندی'),
    ('TIKTOK', 'views', 'views', 'جۆری ڕیکلام', 'بینینەکان'),
    ('TIKTOK', 'restaurant', 'messages', 'جۆری ڕیکلام', 'خواردنگە'),
    ('TIKTOK', 'app_download', 'messages', 'جۆری ڕیکلام', 'دابەزاندنی ئەپ'),
    ('TIKTOK', null, 'views', 'ئامانج', 'بینین'),
    ('META', null, 'views', 'ئامانج', 'بینین'),
  ]) {
    testWidgets('confirmation preserves the $platform $type customer label',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = AdDraft.fromJson({
        ...validDraft().toJson(),
        'platform': platform,
        'tiktok_ad_type': type,
        'goal': goal,
      });
      final request = AdPendingSubmission.fromJson(
        AdPendingSubmission.create(
          draft,
          const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800),
        ).toJson(),
      );
      final repository = _RejectedRepository(false);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: AdConfirmationScreen(
          request: request,
          repository: repository,
          countdown: const Duration(hours: 1),
        ),
      ));
      await tester.pump();
      final row = find.byWidgetPredicate(
        (widget) => widget is AdValueRow && widget.label == heading,
      );
      expect(row, findsOneWidget);
      expect(tester.widget<AdValueRow>(row).value, label);
      await tester.ensureVisible(row);
      await tester.pump();
      expectVisibleTextFits(tester);
      expect(repository.submissions, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final uncertain in [false, true]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        '${systemBack ? 'system back' : 'cancel'} returns ${uncertain ? 'uncertain' : 'definite'} failure',
        (tester) async {
          final repository = _RejectedRepository(uncertain);
          AdConfirmationResult? result;
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<AdConfirmationResult>(
                        MaterialPageRoute(
                          builder: (_) => AdConfirmationScreen(
                            request: AdPendingSubmission.create(
                              validDraft(),
                              const AdQuote(
                                grossUsd: 10,
                                costUsd: 10,
                                rate: 1800,
                              ),
                            ),
                            repository: repository,
                            countdown: const Duration(seconds: 1),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          expect(repository.submissions, 1);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byKey(const ValueKey('cancel-submission')));
          }
          await tester.pumpAndSettle();
          expect(result, isNotNull);
          expect(result!.definitiveFailure, !uncertain);
          expect(result!.pending, uncertain);
          expect(repository.submissions, 1);
          expect(find.byType(AdConfirmationScreen), findsNothing);
        },
      );
    }
  }
}
