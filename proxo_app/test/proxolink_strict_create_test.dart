import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';

import 'proxolink_creation_recovery_test.dart'
    show RecoveryRepository, FaultingPendingRequests, fillContact;
import 'proxolink_tools_create_test.dart' show host, size, tap, field;
import 'proxolink_page_management_test.dart' show page;

class FailedPublishRepository extends RecoveryRepository {
  FailedPublishRepository() : super([]);
  int calls = 0;
  ProxoCard? retryExisting;
  @override
  Future<ProxoCard> save(
    Map<String, dynamic> data, {
    ProxoCard? existing,
  }) async {
    calls++;
    if (calls == 1) {
      final failed = ProxoCard.fromJson({
        ...page(1).toJson(),
        'status': 'inactive',
        'publish_status': 'failed',
        'client_request_id': data['client_request_id'],
        'name': data['name'],
      });
      rows = [failed];
      throw ProxoLinkFailure('publish_failed', savedCard: failed);
    }
    retryExisting = existing;
    return ProxoCard.fromJson({
      ...rows.single.toJson(),
      'status': 'active',
      'publish_status': 'ready',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Create Ad requested page type is locked and Back pops only its create route',
    (t) async {
      size(t, 393);
      final repo = RecoveryRepository([]);
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProxoLinkCreatePageScreen(
                      repository: repo,
                      initialType: ProxoPageType.order,
                      lockType: true,
                    ),
                  ),
                ),
                child: const Text('Create from ad'),
              ),
            ),
          ),
        ),
      );
      await tap(t, find.text('Create from ad'));
      expect(find.byKey(const ValueKey('create-type-order')), findsOneWidget);
      expect(find.byKey(const ValueKey('create-type-contact')), findsNothing);
      expect(find.byKey(const ValueKey('create-type-download')), findsNothing);
      expect(find.text('ناوی ڕێستۆرانت'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Create from ad'), findsOneWidget);
      expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
    },
  );
  testWidgets(
    'failed saved publication stays editable; explicit retry updates same page and only then returns',
    (t) async {
      size(t, 393);
      final repo = FailedPublishRepository();
      ProxoCard? returned;
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  returned = await Navigator.of(context).push<ProxoCard>(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProxoLinkCreatePageScreen(repository: repo),
                    ),
                  );
                },
                child: const Text('Create'),
              ),
            ),
          ),
        ),
      );
      await tap(t, find.text('Create'));
      await fillContact(t);
      await tap(t, find.byKey(const ValueKey('create-page-submit')));
      expect(find.byType(ProxoLinkCreatePageScreen), findsOneWidget);
      expect(returned, isNull);
      expect(repo.calls, 1);
      expect(find.text('Proxo fixture page'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('create-page-submit')));
      expect(repo.calls, 2);
      expect(repo.retryExisting?.id, page(1).id);
      expect(returned?.id, page(1).id);
      expect(returned?.available, isTrue);
      expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
    },
  );
  testWidgets('locked route does not recover an old page of another kind', (
    t,
  ) async {
    size(t, 393);
    final old = page(1), repo = RecoveryRepository([page(1)]);
    final pending = FaultingPendingRequests()..request = old.clientRequestId;
    await t.pumpWidget(
      host(
        ProxoLinkCreatePageScreen(
          repository: repo,
          pendingRequests: pending,
          initialType: ProxoPageType.order,
          lockType: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-type-order')), findsOneWidget);
    expect(find.byKey(const ValueKey('create-type-contact')), findsNothing);
    expect(pending.request, isNull);
    expect(repo.rows.single.id, old.id);
  });
  testWidgets(
    'late different-kind idempotency response keeps typed form and renews request',
    (t) async {
      size(t, 393);
      final old = page(1),
          repo = RecoveryRepository([page(1)])
            ..fail = true
            ..nextFailure = 'idempotency_conflict'
            ..includeSavedCard = true;
      final pending = FaultingPendingRequests()..request = old.clientRequestId;
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProxoLinkCreatePageScreen(
                      repository: repo,
                      pendingRequests: pending,
                      initialType: ProxoPageType.order,
                      lockType: true,
                    ),
                  ),
                ),
                child: const Text('Create restaurant'),
              ),
            ),
          ),
        ),
      );
      await tap(t, find.text('Create restaurant'));
      await t.ensureVisible(field(ProxoPageType.order.nameLabel));
      await t.enterText(
        field(ProxoPageType.order.nameLabel),
        'Restaurant draft',
      );
      await t.ensureVisible(field('تەلەبات'));
      await t.enterText(
        field('تەلەبات'),
        'https://talabat.com/restaurant/fixture',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('create-page-submit')));
      expect(find.byType(ProxoLinkCreatePageScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('create-type-order')), findsOneWidget);
      expect(find.text('Restaurant draft'), findsOneWidget);
      expect(repo.attempts.single['client_request_id'], old.clientRequestId);
      expect(pending.request, isNull);
      repo.fail = false;
      await tap(t, find.byKey(const ValueKey('create-page-submit')));
      expect(
        repo.attempts.last['client_request_id'],
        isNot(old.clientRequestId),
      );
      expect(repo.attempts.last['page_kind'], 'order');
    },
  );
}
