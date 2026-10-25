import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/ad_submission.dart';

import 'ad_repository_test.dart'
    show signedClient, mockTransport, jsonResponse, userId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in ['contact', 'order', 'download']) {
    test(
      'resource request filters stored $kind type and owner before return',
      () async {
        var calls = 0;
        final client = await signedClient(
          mockTransport((request) async {
            calls++;
            expect(request.url.path, '/rest/v1/proxolink_cards');
            final q = request.url.queryParameters;
            expect(q['user_id'], 'eq.$userId');
            expect(q['status'], 'eq.active');
            expect(q['publish_status'], 'eq.ready');
            expect(q['archived_at'], 'is.null');
            if (kind == 'contact') {
              expect(q['or'], '(page_kind.eq.contact,page_kind.is.null)');
            } else {
              expect(q['page_kind'], 'eq.$kind');
              expect(q.containsKey('or'), isFalse);
            }
            expect(q['select'], contains('page_kind'));
            expect(q['select'], contains('moderation_status'));
            return jsonResponse([
              {
                'id': 'page-id',
                'name': 'Owner page',
                'page_kind': kind,
                'status': 'active',
                'publish_status': 'ready',
                'avatar_path': null,
              },
            ]);
          }),
        );
        addTearDown(client.dispose);
        final rows = await SupabaseAdCreationRepository(client)
            .loadAssetsForType(kind);
        expect(rows.single['page_kind'], kind);
        expect(calls, 1);
      },
    );
  }
  test(
    'unknown resource type is rejected before any network request',
    () async {
      final client = await signedClient(
        mockTransport((_) async => throw StateError('Unexpected request')),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseAdCreationRepository(client).loadAssetsForType('contact,order'),
        throwsA(isA<AdSubmissionFailure>()),
      );
    },
  );
}
