import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../assets/js/exchange-balance-admin.js', import.meta.url), 'utf8');
const context = vm.createContext({ document: { getElementById: () => null } });
vm.runInContext(source, context);
const amounts = (...args) => ({ ...context.balanceRefundAmounts(...args) });
const orderId = '33333333-3333-4333-8333-333333333333';
const userId = '22222222-2222-4222-8222-222222222222';
const shortfall = (overrides = {}) => ({
  order_id: orderId, user_id: userId, amount_iqd: 150, expected_iqd: 9800,
  refunded_before_iqd: 0, refunded_after_iqd: 150, ...overrides
});
const fullRefund = (overrides = {}) => ({
  order_id: orderId, user_id: userId, amount_iqd: 10000, status: 'credited',
  refund_kind: 'admin_rejection', confirmed_funds_received: true,
  confirmed_payout_failed: false, ...overrides
});
const fullOrder = (overrides = {}) => ({
  id: orderId, user_id: userId, amount: 10000, total: 9800,
  from_method: 'FastPay', to_method: 'FIB', ...overrides
});

test('150 IQD shortfall separates recipient expectation, calculated sent and this credit', () => {
  assert.deepEqual(amounts(shortfall()), { expected: 9800, sent: 9650, unpaid: 150, credited: 150 });
});

test('a second credit uses the immutable cumulative snapshot rather than only its own amount', () => {
  const first = shortfall();
  const second = shortfall({ amount_iqd: 50, refunded_before_iqd: 150, refunded_after_iqd: 200 });
  assert.deepEqual(amounts(second), { expected: 9800, sent: 9600, unpaid: 200, credited: 50 });
  assert.deepEqual(amounts(first), { expected: 9800, sent: 9650, unpaid: 150, credited: 150 });
  assert.equal(amounts(first).credited + amounts(second).credited, 200);
});

test('a fully accumulated shortfall has zero calculated sent and the individual credit stays distinct', () => {
  assert.deepEqual(amounts(shortfall({ amount_iqd: 200, refunded_before_iqd: 9600, refunded_after_iqd: 9800 })),
    { expected: 9800, sent: 0, unpaid: 9800, credited: 200 });
});

test('automatic rounding records exact-thousand payouts and the complete remainder as one balance credit', () => {
  for (const [expected, sent, remainder] of [[10500, 10000, 500], [1600, 1000, 600], [600, 0, 600]]) {
    assert.deepEqual(amounts(shortfall({ refund_source: 'payout_rounding', expected_iqd: expected,
      amount_iqd: remainder, refunded_before_iqd: 0, refunded_after_iqd: remainder })),
      { expected, sent, unpaid: remainder, credited: remainder });
  }
});

test('automatic and later manual credits retain their own snapshots without refunding the same remainder twice', () => {
  const automatic = shortfall({ refund_source: 'payout_rounding', expected_iqd: 10500,
    amount_iqd: 500, refunded_before_iqd: 0, refunded_after_iqd: 500 });
  const later = shortfall({ refund_source: 'manual_shortfall', expected_iqd: 10500,
    amount_iqd: 150, refunded_before_iqd: 500, refunded_after_iqd: 650 });
  assert.deepEqual(amounts(automatic), { expected: 10500, sent: 10000, unpaid: 500, credited: 500 });
  assert.deepEqual(amounts(later), { expected: 10500, sent: 9850, unpaid: 650, credited: 150 });
  assert.equal(amounts(automatic).credited + amounts(later).credited, 650);
});

test('a malformed automatic source cannot assert a rounded payout or reuse a previous manual credit', () => {
  for (const patch of [
    { amount_iqd: 150, refunded_after_iqd: 150 },
    { amount_iqd: 1500, refunded_after_iqd: 1500 },
    { refunded_before_iqd: 100, refunded_after_iqd: 600 },
    { expected_iqd: 10000 },
    { expected_iqd: 0, amount_iqd: 0, refunded_after_iqd: 0 }
  ]) {
    const result = amounts(shortfall({ refund_source: 'payout_rounding', expected_iqd: 10500,
      amount_iqd: 500, refunded_before_iqd: 0, refunded_after_iqd: 500, ...patch }));
    assert.equal(result.sent, null, JSON.stringify(patch));
    assert.equal(result.unpaid, null, JSON.stringify(patch));
  }
});

test('Postgres whole numeric strings are accepted without turning empty or absent fields into zero', () => {
  assert.deepEqual(amounts(shortfall({ amount_iqd: '150', expected_iqd: '9800.00',
    refunded_before_iqd: '0', refunded_after_iqd: '150' })),
    { expected: 9800, sent: 9650, unpaid: 150, credited: 150 });
  for (const empty of [null, undefined, '', ' ', false]) {
    const result = amounts(shortfall({ expected_iqd: empty }));
    assert.equal(result.expected, null);
    assert.equal(result.sent, null);
    assert.equal(result.unpaid, null);
  }
  assert.deepEqual(amounts(null), { expected: null, sent: null, unpaid: null, credited: null });
  assert.deepEqual(amounts(undefined), { expected: null, sent: null, unpaid: null, credited: null });
});

test('malformed partial snapshots never manufacture calculated sent or unpaid amounts', () => {
  const malformed = [
    { refunded_after_iqd: 151 },
    { refunded_before_iqd: 151, refunded_after_iqd: 150 },
    { refunded_before_iqd: 9700, refunded_after_iqd: 9850 },
    { refunded_before_iqd: -1, refunded_after_iqd: 149 },
    { refunded_before_iqd: null },
    { refunded_after_iqd: null },
    { expected_iqd: 0 },
    { expected_iqd: -9800 },
    { expected_iqd: 9800.5 },
    { expected_iqd: 1000000001 },
    { amount_iqd: 0, refunded_after_iqd: 0 },
    { amount_iqd: -150, refunded_after_iqd: -150 },
    { amount_iqd: 150.5, refunded_after_iqd: 150.5 },
    { amount_iqd: null },
    { amount_iqd: true },
    { amount_iqd: Infinity },
    { amount_iqd: '1.5e2' },
    { amount_iqd: '150 IQD' }
  ];
  for (const patch of malformed) {
    const result = amounts(shortfall(patch));
    assert.equal(result.sent, null, JSON.stringify(patch));
    assert.equal(result.unpaid, null, JSON.stringify(patch));
  }
});

test('full admin rejection preserves principal credit but does not assert a bank delivery outcome', () => {
  assert.deepEqual(amounts(fullRefund(), 'full', fullOrder()),
    { expected: 9800, sent: null, unpaid: null, credited: 10000 });
  const observedExample = fullOrder({ total: 9750 });
  assert.deepEqual(amounts(fullRefund(), 'full', observedExample),
    { expected: 9750, sent: null, unpaid: null, credited: 10000 });
});

test('only an explicitly confirmed failed payout can report zero sent and its expected payout unpaid', () => {
  assert.deepEqual(amounts(fullRefund({ refund_kind: 'failed_payout', confirmed_payout_failed: true }),
    'full', fullOrder()), { expected: 9800, sent: 0, unpaid: 9800, credited: 10000 });
  for (const patch of [
    { refund_kind: undefined, confirmed_payout_failed: true },
    { refund_kind: null, confirmed_payout_failed: true },
    { refund_kind: 'legacy', confirmed_payout_failed: true },
    { refund_kind: 'admin_rejection', confirmed_payout_failed: true },
    { refund_kind: 'failed_payout', confirmed_payout_failed: false },
    { refund_kind: 'failed_payout', confirmed_payout_failed: undefined },
    { refund_kind: 'failed_payout', confirmed_payout_failed: 'true' }
  ]) {
    assert.deepEqual(amounts(fullRefund(patch), 'full', fullOrder()),
      { expected: 9800, sent: null, unpaid: null, credited: 10000 }, JSON.stringify(patch));
  }
});

test('full recipient amounts require the matching refund owner and an IQD order', () => {
  const confirmed = fullRefund({ refund_kind: 'failed_payout', confirmed_payout_failed: true });
  const invalidOrders = [
    undefined, null, {},
    fullOrder({ id: 'another-order' }),
    fullOrder({ user_id: 'another-customer' }),
    fullOrder({ from_method: 'USDT' }),
    fullOrder({ to_method: 'USDT' }),
    fullOrder({ from_method: null }),
    fullOrder({ to_method: '' })
  ];
  for (const order of invalidOrders) {
    assert.deepEqual(amounts(confirmed, 'full', order),
      { expected: null, sent: null, unpaid: null, credited: 10000 }, JSON.stringify(order));
  }
  const missingIds = fullRefund({ order_id: undefined, user_id: undefined });
  assert.deepEqual(amounts(missingIds, 'full', fullOrder({ id: undefined, user_id: undefined })),
    { expected: null, sent: null, unpaid: null, credited: 10000 });
});

test('an absent or invalid full order total never becomes an inferred zero payout', () => {
  const confirmed = fullRefund({ refund_kind: 'failed_payout', confirmed_payout_failed: true });
  for (const total of [null, undefined, '', ' ', false, NaN, Infinity, -1, 1000000001, '9800 IQD']) {
    assert.deepEqual(amounts(confirmed, 'full', fullOrder({ total })),
      { expected: null, sent: null, unpaid: null, credited: 10000 }, String(total));
  }
});

test('recorded full order total zero remains meaningful and differs from a missing total', () => {
  const zero = fullOrder({ total: 0 });
  assert.deepEqual(amounts(fullRefund(), 'full', zero),
    { expected: 0, sent: null, unpaid: null, credited: 10000 });
  assert.deepEqual(amounts(fullRefund({ refund_kind: 'failed_payout', confirmed_payout_failed: true }), 'full', zero),
    { expected: 0, sent: 0, unpaid: 0, credited: 10000 });
});

test('full reports preserve a recorded decimal order expectation without rounding its principal credit', () => {
  // Full cases have no whole-total invariant or immutable expected-payout column.
  // Their joined numeric total is presented as recorded, separate from principal.
  const order = fullOrder({ total: '9800.5' });
  assert.deepEqual(amounts(fullRefund(), 'full', order),
    { expected: 9800.5, sent: null, unpaid: null, credited: 10000 });
  assert.deepEqual(amounts(fullRefund({ refund_kind: 'failed_payout', confirmed_payout_failed: true }), 'full', order),
    { expected: 9800.5, sent: 0, unpaid: 9800.5, credited: 10000 });
});
