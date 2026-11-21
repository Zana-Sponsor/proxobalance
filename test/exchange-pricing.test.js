import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Customer fee preview — the same decimal math as the database (ex_order_quote).
// There is no discount input: quote(amount, rate) only ever charges the configured fee.
const pricing = readFileSync(new URL('../assets/js/exchange-pricing.js', import.meta.url), 'utf8');
const context = vm.createContext({});
vm.runInContext(pricing, context);
const P = context.ProxoPricing;

test('the pricing module exposes no discount API', () => {
  assert.deepEqual(Object.keys(P).sort(), ['effectiveRate', 'quote', 'tierOf', 'tierPercent']);
  assert.equal(context.ProxoRewardPricing, undefined);
  assert.doesNotMatch(pricing, /reward|discount/i);
});

const cases = [
  ['2% fee', 60000, 'fee_percent', 2, 58800, 1200],
  ['decimal 2.2 percent', 60000, 'fee_percent', 2.2, 58680, 1320],
  ['carrier multiplier', 60000, 'multiplier', 0.86, 51600, 8400],
  ['fixed fee', 60000, 'fee_fixed', 1000, 59000, 1000],
  ['fractional fixed fee floors the payout once', 60000, 'fee_fixed', 123.5, 59876, 124],
  ['fractional IQD input keeps the same decimal math', 60000.5, 'fee_percent', 2, 58800, 1200.5],
  ['zero fee', 50000, 'fee_percent', 0, 50000, 0]
];
for (const [name, amount, type, value, total, fee] of cases) {
  test(name, () => {
    const result = P.quote(amount, { type, value });
    assert.equal(result.total, total);
    assert.equal(result.fee, fee);
    assert.equal(result.total + result.fee, amount);
    assert.equal('discount_iqd' in result, false);
  });
}

test('a third argument (an old reward object) is ignored', () => {
  const r = P.quote(60000, { type: 'fee_percent', value: 2 }, { kind: 'free_transactions', discount_percent: 100, max_amount_iqd: 50000 });
  assert.equal(r.total, 58800);
  assert.equal(r.fee, 1200);
});

test('the customer calculation charges the full configured fee and shows no discount', () => {
  const app = readFileSync(new URL('../assets/js/app.js', import.meta.url), 'utf8');
  assert.doesNotMatch(app, /MY_REWARDS|availableFeeReward|rewardBanner|bdDiscountRow|ProxoRewardPricing|loadMyRewards|welcomeReward/);
  const elements = new Map();
  const element = id => {
    if (!elements.has(id)) elements.set(id, { value: '', innerText: '', textContent: '', hidden: false, classList: { add() {}, remove() {}, toggle() {} } });
    return elements.get(id);
  };
  element('from').value = 'FastPay'; element('receiveVia').value = 'FIB';
  const c = vm.createContext({
    document: { getElementById: element }, amount: '60000', curUser: { id: 'fixture' },
    RATES: { 'FastPay>FIB': { type: 'fee_percent', value: 2 } }, MIN_AMOUNT: 10000,
    formatNum: v => Number(v).toLocaleString('en-US'), fmtPct: String,
    refreshFormHints() {}, updateSubmitState() {}, refreshTrigger() {}, updateHeaderRate() {},
    routeAllowed: () => true, METHOD_META: {}, getWalletInfo: () => ({ locked: false })
  });
  vm.runInContext(pricing, c);
  vm.runInContext('function getAmtRaw(){return amount;}', c);
  const start = app.indexOf('function calc(){'), end = app.indexOf('function _validateOrderFields()', start);
  assert.ok(start >= 0 && end > start);
  vm.runInContext(app.slice(start, end), c);
  c.calc();
  assert.equal(element('bdFee').textContent, '1,200 د.ع');
  assert.equal(element('totalDisplay').innerText, '58,800 د.ع');
  c.RATES['Korek>FIB'] = { type: 'fee_percent', value: 20 };
  element('from').value = 'Korek'; c.calc();
  assert.equal(element('bdFee').textContent, '12,000 د.ع');
  assert.equal(element('totalDisplay').innerText, '48,000 د.ع');
});
