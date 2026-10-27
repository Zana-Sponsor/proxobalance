import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Test-only platform fault injection, matching pending_storage_serialization_test.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:proxo_app/services/ad_submission.dart';

import 'ad_repository_test.dart'
    show signedClient, mockTransport, jsonResponse, storageKey;
import 'ad_submission_test.dart' show validDraft;

class _FailedRemovalStore extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};
  bool rejectMarker = false;
  bool rejectInitialWrite = false;
  bool failReadsAfterRemoval = false;
  bool _failReads = false;
  @override
  Future<Map<String, Object>> getAll() async {
    if (_failReads) throw StateError('storage unavailable');
    return Map.of(values);
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (rejectInitialWrite) return false;
    if (rejectMarker && value is String && value.contains('definite_failure')) {
      return false;
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _failReads = failReadsAfterRemoval;
    return false;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  AdPendingSubmission request() => AdPendingSubmission.create(
        validDraft(),
        const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800),
      );

  test(
    'definite failure cannot restore after failed removal and restart',
    () async {
      final store = _FailedRemovalStore();
      SharedPreferencesStorePlatform.instance = store;
      var submissions = 0;
      final client = await signedClient(
        mockTransport((req) async {
          if (req.url.path.endsWith('/pa_ad_submission_status')) {
            return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
          }
          if (req.url.path.endsWith('/pa_submit_ad')) {
            submissions++;
            return jsonResponse(
              submissions == 1
                  ? {'ok': false, 'code': 'INSUFFICIENT_FUNDS'}
                  : {'ok': true, 'ad_id': 'new-deliberate-ad'},
            );
          }
          return jsonResponse({'ok': true});
        }),
      );
      addTearDown(client.dispose);
      final p = ValueNotifier(const AdPaymentProgress());
      addTearDown(p.dispose);
      final original = request();
      await expectLater(
        SupabaseAdCreationRepository(client).submit(original, p),
        throwsA(
          isA<AdSubmissionFailure>().having(
            (e) => e.uncertain,
            'definite',
            false,
          ),
        ),
      );
      final persisted = jsonDecode(
        store.values['flutter.$storageKey']! as String,
      );
      expect(persisted['resolution'], 'definite_failure');
      expect(persisted['id'], original.id);

      // Reload the platform store and construct a new repository, as on reopen.
      await (await SharedPreferences.getInstance()).reload();
      final reopened = SupabaseAdCreationRepository(client);
      expect(await reopened.pending(), isNull);
      expect(await reopened.pending(), isNull);
      expect(submissions, 1); // Reading or reopening never resubmits.
      final next = request();
      expect(next.id, isNot(original.id));
      expect(await reopened.submit(next, p), 'new-deliberate-ad');
      expect(submissions, 2);
    },
  );

  test(
    'failed terminal marker and removal report storage recovery explicitly',
    () async {
      final store = _FailedRemovalStore()..rejectMarker = true;
      SharedPreferencesStorePlatform.instance = store;
      final client = await signedClient(
        mockTransport(
          (req) async => jsonResponse(
            req.url.path.endsWith('/pa_ad_submission_status')
                ? {'ok': false, 'code': 'NOT_FOUND'}
                : {'ok': false, 'code': 'INSUFFICIENT_FUNDS'},
          ),
        ),
      );
      addTearDown(client.dispose);
      final p = ValueNotifier(const AdPaymentProgress());
      addTearDown(p.dispose);
      final original = request();
      final repo = SupabaseAdCreationRepository(client);
      await expectLater(
        repo.submit(original, p),
        throwsA(
          isA<AdSubmissionFailure>()
              .having((e) => e.code, 'storage outcome', 'STORAGE_UNAVAILABLE')
              .having((e) => e.uncertain, 'recovery required', true),
        ),
      );
      expect((await repo.pending())?.id, original.id);
    },
  );

  test('failed initial persistence never exposes an unstarted cached request',
      () async {
    final store = _FailedRemovalStore()..rejectInitialWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    var serverCalls = 0;
    final client = await signedClient(mockTransport((_) async {
      serverCalls++;
      return jsonResponse({});
    }));
    addTearDown(client.dispose);
    final p = ValueNotifier(const AdPaymentProgress());
    addTearDown(p.dispose);
    final repo = SupabaseAdCreationRepository(client);
    await expectLater(
        repo.submit(request(), p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'storage', 'STORAGE_UNAVAILABLE')
            .having((e) => e.uncertain, 'no request sent', false)));
    expect(await repo.pending(), isNull);
    expect(serverCalls, 0);
  });

  test(
      'failed cleanup and reload block a second form from submitting a new identity',
      () async {
    final store = _FailedRemovalStore()
      ..rejectMarker = true
      ..failReadsAfterRemoval = true;
    SharedPreferencesStorePlatform.instance = store;
    var serverCalls = 0;
    final client = await signedClient(mockTransport((req) async {
      serverCalls++;
      return jsonResponse(req.url.path.endsWith('/pa_ad_submission_status')
          ? {'ok': false, 'code': 'NOT_FOUND'}
          : {'ok': false, 'code': 'INSUFFICIENT_FUNDS'});
    }));
    addTearDown(client.dispose);
    final p = ValueNotifier(const AdPaymentProgress());
    addTearDown(p.dispose);
    final repo = SupabaseAdCreationRepository(client);
    await expectLater(
        repo.submit(request(), p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'storage unresolved', true)));
    final reopened = SupabaseAdCreationRepository(client);
    await expectLater(reopened.pending(), throwsStateError);
    await expectLater(reopened.submit(request(), p), throwsStateError);
    expect(serverCalls, 2);
  });

  for (final reply in <Map<String, Object?>>[
    {},
    {'ok': false},
    {'ok': false, 'code': ''},
    {'ok': false, 'code': 'IDEMPOTENCY_CONFLICT'},
    {'ok': false, 'code': 'PROVIDER_OUTCOME_UNKNOWN', 'uncertain': true},
    {'ok': true},
    {'ok': true, 'ad_id': ''},
    {'ok': true, 'ad_id': '   '},
  ]) {
    test('ambiguous submission reply retains identity: $reply', () async {
      final original = request();
      final client = await signedClient(
        mockTransport((req) async {
          if (req.url.path.endsWith('/pa_ad_submission_status')) {
            return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
          }
          expect(req.url.path, endsWith('/pa_submit_ad'));
          return jsonResponse(reply);
        }),
      );
      addTearDown(client.dispose);
      final p = ValueNotifier(const AdPaymentProgress());
      addTearDown(p.dispose);
      final repo = SupabaseAdCreationRepository(client);
      await expectLater(
        repo.submit(original, p),
        throwsA(
          isA<AdSubmissionFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            true,
          ),
        ),
      );
      expect((await repo.pending())?.id, original.id);
      final raw = (await SharedPreferences.getInstance()).getString(
        storageKey,
      )!;
      expect(jsonDecode(raw)['resolution'], isNull);
    });
  }

  test(
    'four typed flows preserve exact backend mappings and local identity',
    () {
      const categories = {
        'contact': 'other',
        'views': 'other',
        'restaurant': 'food_beverage',
        'app_download': 'games_apps',
      };
      for (final entry in categories.entries) {
        final goal = entry.key == 'views' ? 'views' : 'messages';
        final draft = AdDraft.fromJson({
          ...validDraft(goal: goal, asset: 'owned-page').toJson(),
          'tiktok_ad_type': entry.key,
          'category': null,
          'device_type': 'removed-ui-value',
        });
        expect(draft.validate(), isEmpty, reason: entry.key);
        expect(draft.toAd()['goal'], goal);
        expect(draft.toAd()['tiktok_ad_type'], entry.key);
        expect(draft.toAd()['category'], entry.value);
        expect(draft.toAd()['device_type'], 'all');
        expect(draft.toAd()['asset_id'], goal == 'views' ? null : 'owned-page');
        expect(draft.isTikTokDirect, false);
        final restored = AdDraft.fromJson(draft.toJson());
        expect(restored.tiktokAdType, entry.key);
        expect(restored.toAd(), draft.toAd());
      }
    },
  );

  for (final kind in {
    'contact': 'contact',
    'restaurant': 'order',
    'app_download': 'download',
  }.entries) {
    test(
      '${kind.key} rereads owner/type eligibility before submission',
      () async {
        var submissions = 0;
        final client = await signedClient(
          mockTransport((req) async {
            if (req.url.path.endsWith('/pa_ad_submission_status')) {
              return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
            }
            if (req.url.path.endsWith('/proxolink_cards')) {
              expect(req.url.queryParameters['user_id'], startsWith('eq.'));
              expect(req.url.queryParameters['status'], 'eq.active');
              expect(req.url.queryParameters['publish_status'], 'eq.ready');
              if (kind.value == 'contact') {
                expect(
                  req.url.queryParameters['or'],
                  contains('page_kind.eq.contact'),
                );
              } else {
                expect(
                  req.url.queryParameters['page_kind'],
                  'eq.${kind.value}',
                );
              }
              return jsonResponse([]); // Removed/moved/wrong-kind resource.
            }
            submissions++;
            return jsonResponse({'ok': true, 'ad_id': 'must-not-submit'});
          }),
        );
        addTearDown(client.dispose);
        final p = ValueNotifier(const AdPaymentProgress());
        addTearDown(p.dispose);
        final draft = AdDraft.fromJson({
          ...validDraft(goal: 'messages', asset: 'stale-page').toJson(),
          'tiktok_ad_type': kind.key,
        });
        final repo = SupabaseAdCreationRepository(client);
        await expectLater(
          repo.submit(AdPendingSubmission.create(draft, request().quote), p),
          throwsA(
            isA<AdSubmissionFailure>().having(
              (e) => e.code,
              'rejection',
              'INVALID_ASSET',
            ),
          ),
        );
        expect(submissions, 0);
        expect(await repo.pending(), isNull);
      },
    );
  }

  test(
    'unknown types, wrong goals and restaurant direct-message are rejected',
    () {
      for (final patch in [
        {'tiktok_ad_type': 'unsupported'},
        {'tiktok_ad_type': 'restaurant', 'goal': 'views'},
        {'tiktok_ad_type': 'app_download', 'goal': 'views'},
      ]) {
        expect(
          AdDraft.fromJson({...validDraft().toJson(), ...patch}).validate(),
          contains('goal'),
        );
      }
      final bad = AdDraft.fromJson({
        ...validDraft(goal: 'messages', asset: 'page').toJson(),
        'tiktok_ad_type': 'restaurant',
        'message_destination': 'direct_message',
      });
      expect(bad.isTikTokDirect, false);
      expect(bad.validate(), contains('destination'));
    },
  );

  test('legacy frozen attempts keep their category and device contract', () {
    final old = AdDraft.fromJson({
      ...validDraft().toJson(),
      'category': 'cosmetics_beauty',
      'device_type': 'iphone',
    });
    expect(old.tiktokAdType, isNull);
    expect(old.toAd()['category'], 'cosmetics_beauty');
    expect(old.toAd()['device_type'], 'iphone');
  });

  AdPendingSubmission legacyPayment({bool expiredSchedule = false}) =>
      AdPendingSubmission.create(
        AdDraft.fromJson({
          ...validDraft(goal: 'messages', asset: 'original-page').toJson(),
          'tiktok_ad_type': 'restaurant',
          'payment_method': 'fastpay',
          if (expiredSchedule) ...{
            'start_immediately': false,
            'start_date': '2000-01-01',
          },
        }),
        request().quote,
      );

  test(
      'paid manual order reaches authoritative rejection before stale date or page checks',
      () async {
    final original = legacyPayment(expiredSchedule: true);
    var submits = 0;
    final client = await signedClient(
      mockTransport((req) async {
        if (req.url.path.endsWith('/pa_ad_submission_status')) {
          return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
        }
        if (req.url.path.endsWith('/pa_transactions')) {
          expect(
            req.url.queryParameters['fastpay_order_id'],
            'eq.${original.fastPayOrderId}',
          );
          return jsonResponse([
            {
              'id': 'paid-order',
              'status': 'approved',
              'gateway_status': 'PAID',
              'wallet_credited': true,
              'amount': 10,
            },
          ]);
        }
        expect(req.url.path, endsWith('/pa_submit_ad'));
        final body = jsonDecode(req.body);
        expect(body['p_submission_id'], original.id);
        expect(body['p_ad']['payment_transaction_id'], 'paid-order');
        expect(body['p_ad']['asset_id'], 'original-page');
        expect(body['p_ad']['start_date'], '2000-01-01');
        submits++;
        return jsonResponse({'ok': false, 'code': 'INVALID_SCHEDULE'});
      }),
    );
    addTearDown(client.dispose);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    final repo = SupabaseAdCreationRepository(client);
    await expectLater(
      repo.submit(original, progress),
      throwsA(
        isA<AdSubmissionFailure>()
            .having(
              (e) => e.code,
              'authoritative rejection',
              'INVALID_SCHEDULE',
            )
            .having((e) => e.uncertain, 'resolved', false)
            .having(
              (e) => e.paymentCredited,
              'credit preserved in wallet',
              true,
            ),
      ),
    );
    expect(submits, 1);
    expect(await repo.pending(), isNull);
  });

  for (final status in ['EXPIRED', 'DECLINED', 'FAILED', 'CANCELLED']) {
    test(
      'manual $status order retains identity and later paid credit resolves once',
      () async {
        final original = legacyPayment();
        var paid = false, submits = 0;
        final client = await signedClient(
          mockTransport((req) async {
            if (req.url.path.endsWith('/pa_ad_submission_status')) {
              return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
            }
            if (req.url.path.endsWith('/pa_transactions')) {
              expect(
                req.url.queryParameters['fastpay_order_id'],
                'eq.${original.fastPayOrderId}',
              );
              return jsonResponse([
                {
                  'id': 'same-order',
                  'status': paid ? 'approved' : 'pending',
                  'gateway_status': paid ? 'PAID' : status,
                  'wallet_credited': paid,
                  'amount': 10,
                },
              ]);
            }
            if (req.url.path.endsWith('/proxolink_cards')) {
              return jsonResponse([
                {'id': 'original-page'}
              ]);
            }
            if (req.url.path.endsWith('/generate-ad-thumbnail')) {
              return jsonResponse({'ok': true});
            }
            expect(req.url.path, endsWith('/pa_submit_ad'));
            expect(jsonDecode(req.body)['p_submission_id'], original.id);
            submits++;
            return jsonResponse({'ok': true, 'ad_id': 'recovered-paid-ad'});
          }),
        );
        addTearDown(client.dispose);
        final progress = ValueNotifier(const AdPaymentProgress());
        addTearDown(progress.dispose);
        final repo = SupabaseAdCreationRepository(client);
        await expectLater(
          repo.submit(original, progress),
          throwsA(
            isA<AdSubmissionFailure>().having(
              (e) => e.uncertain,
              'late payment remains possible',
              true,
            ),
          ),
        );
        expect((await repo.pending())!.toJson(), original.toJson());
        expect(submits, 0);
        paid = true;
        final reopened = SupabaseAdCreationRepository(client);
        expect(
          await reopened.submit((await reopened.pending())!, progress),
          'recovered-paid-ad',
        );
        expect(submits, 1);
        expect(await reopened.pending(), isNull);
      },
    );
  }

  for (final persisted in [false, true]) {
    test(
      'expired manual schedule ${persisted ? 'retains previously interrupted' : 'clears never-started'} order',
      () async {
        final original = legacyPayment(expiredSchedule: true);
        if (persisted) {
          SharedPreferences.setMockInitialValues({
            storageKey: jsonEncode(original.toJson()),
          });
        }
        final client = await signedClient(
          mockTransport((req) async {
            if (req.url.path.endsWith('/pa_ad_submission_status')) {
              return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
            }
            expect(req.url.path, endsWith('/pa_transactions'));
            return jsonResponse([]);
          }),
        );
        addTearDown(client.dispose);
        final progress = ValueNotifier(const AdPaymentProgress());
        addTearDown(progress.dispose);
        final repo = SupabaseAdCreationRepository(client);
        await expectLater(
          repo.submit(original, progress),
          throwsA(
            isA<AdSubmissionFailure>()
                .having((e) => e.code, 'invalid schedule', 'INVALID_SCHEDULE')
                .having(
                  (e) => e.uncertain,
                  'previous payment might be in flight',
                  persisted,
                ),
          ),
        );
        expect((await repo.pending())?.id, persisted ? original.id : null);
      },
    );
  }

  test(
    'manual order amount mismatch after create retains payment identity',
    () async {
      final original = legacyPayment();
      var creates = 0;
      final transport = mockTransport((req) async {
        if (req.url.path.endsWith('/pa_ad_submission_status')) {
          return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
        }
        if (req.url.path.endsWith('/pa_transactions')) return jsonResponse([]);
        if (req.url.path.endsWith('/proxolink_cards')) {
          return jsonResponse([
            {'id': 'original-page'},
          ]);
        }
        expect(req.url.path, endsWith('/order-create'));
        expect(jsonDecode(req.body)['orderId'], original.fastPayOrderId);
        creates++;
        return jsonResponse({'success': true, 'amountIqd': 1});
      });
      final client = await signedClient(transport);
      addTearDown(client.dispose);
      final progress = ValueNotifier(const AdPaymentProgress());
      addTearDown(progress.dispose);
      final repo = SupabaseAdCreationRepository(client);
      await expectLater(
        http.runWithClient(
          () => repo.submit(original, progress),
          () => transport,
        ),
        throwsA(
          isA<AdSubmissionFailure>()
              .having((e) => e.code, 'quoted amount mismatch', 'PRICE_CHANGED')
              .having((e) => e.uncertain, 'order already created', true),
        ),
      );
      expect(creates, 1);
      expect((await repo.pending())!.toJson(), original.toJson());
    },
  );
}
