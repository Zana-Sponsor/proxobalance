import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';

import 'ad_submission_test.dart' show validDraft;

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
