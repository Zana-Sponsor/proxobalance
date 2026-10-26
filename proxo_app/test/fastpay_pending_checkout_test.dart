import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/fastpay_pending_checkout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = FastPayPendingCheckoutStore();
  const original = FastPayPendingCheckout(orderId: 'PX-ORIGINAL-ORDER', amountIqd: 10000, note: 'original note');
  const edited = FastPayPendingCheckout(orderId: 'PX-NEW-ORDER', amountIqd: 25000, note: 'edited note');
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('concurrent and restarted checkout claims retain the original intent', () async {
    final claims = await Future.wait([store.claim('owner-a', original), store.claim('owner-a', edited)]);
    for (final claim in claims) {
      expect(claim.toJson(), original.toJson());
    }
    final restored = await const FastPayPendingCheckoutStore().read('owner-a');
    expect(restored!.toJson(), original.toJson());
    expect(await store.read('owner-b'), isNull);
    expect((await store.claim('owner-b', edited)).orderId, edited.orderId);
  });
  test('only one caller can dispatch and a restart never replays an uncertain QR', () async {
    await store.claim('owner-a', original);
    expect(await Future.wait([store.markDispatched('owner-a', original.orderId),
        store.markDispatched('owner-a', original.orderId)]), [true, false]);
    expect((await const FastPayPendingCheckoutStore().read('owner-a'))!.dispatched, isTrue);
    expect(await store.markDispatched('owner-a', original.orderId), isFalse);
  });
  test('late completion cannot clear another order or owner', () async {
    await store.claim('owner-a', original);
    await store.claim('owner-b', edited);
    await store.clear('owner-a', edited.orderId);
    expect((await store.read('owner-a'))!.orderId, original.orderId);
    await store.clear('owner-a', original.orderId);
    expect(await store.read('owner-a'), isNull);
    expect((await store.read('owner-b'))!.orderId, edited.orderId);
  });
  test('unresolved records do not expire into a second payment identity', () async {
    await store.claim('owner-a', original);
    expect((await store.claim('owner-a', edited)).toJson(), original.toJson());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(FastPayPendingCheckoutStore.key('owner-a')), isNot(contains('qr')));
  });
  test('corrupt persisted state blocks a new identity rather than overwriting it', () async {
    SharedPreferences.setMockInitialValues({FastPayPendingCheckoutStore.key('owner-a'): '{broken'});
    await expectLater(store.claim('owner-a', edited), throwsFormatException);
    expect((await SharedPreferences.getInstance()).getString(FastPayPendingCheckoutStore.key('owner-a')), '{broken');
  });
  test('invalid new intent never poisons durable recovery', () async {
    for (final invalid in [
      const FastPayPendingCheckout(orderId: 'PX-VALID-ORDER', amountIqd: 4999),
      const FastPayPendingCheckout(orderId: 'invalid', amountIqd: 10000),
      FastPayPendingCheckout(orderId: 'PX-VALID-ORDER', amountIqd: 10000, note: 'x' * 501),
    ]) {
      await expectLater(store.claim('owner-a', invalid), throwsStateError);
      expect(await store.read('owner-a'), isNull);
    }
    expect((await store.claim('owner-a', original)).orderId, original.orderId);
  });
}
