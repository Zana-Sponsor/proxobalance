const MAX_IQD = 1_000_000_000;
const UNIT_IQD = 1000;

// Wallet routes are configured in the database. Every nonempty external
// destination other than USDT pays IQD; AccountBalance is a source only.
export function payoutPlan(total, toMethod) {
  const applies = typeof toMethod === 'string' && toMethod !== '' && toMethod.trim() === toMethod &&
    !/[\u0000-\u001f\u007f]/.test(toMethod) &&
    !['USDT', 'AccountBalance'].includes(toMethod);
  const numeric = ['number', 'string'].includes(typeof total) && total !== '' &&
    (typeof total !== 'string' || /^\d+(?:\.\d+)?$/.test(total));
  const value = numeric ? Number(total) : NaN;
  const expected = applies && Number.isSafeInteger(value) && value >= 0 && value <= MAX_IQD
    ? value : null;
  const payout = expected === null ? null : Math.floor(expected / UNIT_IQD) * UNIT_IQD;
  return Object.freeze({
    applies,
    valid: applies && expected !== null,
    expected_iqd: expected,
    payout_iqd: payout,
    remainder_iqd: expected === null ? null : expected - payout,
    requires_payout: payout !== null && payout > 0
  });
}
