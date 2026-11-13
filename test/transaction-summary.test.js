import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import summaryApi from '../api-handlers/transaction-summary.js';

await import('../assets/js/transaction-summary-financials.js');
const financials = globalThis.ProxoTransactionSummaryFinancials;
const app = readFileSync(new URL('../assets/js/app.js', import.meta.url), 'utf8');
const api = readFileSync(new URL('../api-handlers/transaction-summary.js', import.meta.url), 'utf8');
const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const css = readFileSync(new URL('../assets/css/transaction-summary.css', import.meta.url), 'utf8');
const vercel = JSON.parse(readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'));
const track = readFileSync(new URL('../assets/js/track.js', import.meta.url), 'utf8');

test('summary endpoint is a POST-only server function', async () => {
  const headers = {};
  const res = { statusCode: 0, setHeader: (key, value) => { headers[key] = value; }, end: value => { res.body = value; } };
  await summaryApi({ method: 'GET', headers: {}, url: '/api/transaction-summary', socket: {} }, res);
  assert.equal(res.statusCode, 405);
  assert.equal(headers.Allow, 'POST');
  assert.equal(headers['Cache-Control'], 'no-store');
  assert.deepEqual(JSON.parse(res.body), { error: 'Method Not Allowed' });
});

function functionBody(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} exists`);
  const next = source.indexOf('\nfunction ', start + 1);
  const nextAsync = source.indexOf('\nasync function ', start + 1);
  const ends = [next, nextAsync].filter(index => index >= 0);
  return source.slice(start, ends.length ? Math.min(...ends) : source.length);
}

test('summary route requires an authenticated owner and only selects the existing secure_token', () => {
  assert.match(api, /auth:\s*'required'/);
  assert.match(api, /secure_token=eq\./);
  assert.match(api, /user_id=eq\./);
  assert.match(api, /&select=\$\{ORDER_FIELDS\}&limit=1/);
  assert.match(api, /ex_refund_cases\?id=eq\./);
  assert.match(api, /&order_id=eq\.\$\{encodeURIComponent\(order\.id\)\}&user_id=eq\./);
  assert.match(api, /if \(!order\) return json\(res, 404/);
  const selectedFields = api.match(/const ORDER_FIELDS = \[([\s\S]*?)\]\.join/)?.[1] || '';
  assert.doesNotMatch(selectedFields, /secure_token/);
  assert.doesNotMatch(selectedFields, /sender_phone/);
  assert.match(selectedFields, /reward_original_fee_iqd/);
  assert.doesNotMatch(api, /gen_random_uuid|randomUUID|set\s+secure_token\s*=/i);
});

test('the summary is one in-app screen, not a separate page or a bottom sheet', () => {
  assert.match(html, /<section class="page" id="pageSummary" data-route="summary"/);
  assert.match(html, /id="txScreenBody"/);
  assert.doesNotMatch(html, /id="transactionSummaryPage"/);
  assert.doesNotMatch(html, /id="txSheet"/);
  assert.doesNotMatch(html, /transaction-summary-route\.js/);
  assert.match(html, /id="summaryInfoBackdrop"/);
  assert.match(html, /src="\/assets\/js\/transaction-summary-financials\.js\?v=1"/);
  assert.doesNotMatch(css, /transaction-summary-active/);
  assert.match(css, /#pageSummary/);
  assert.match(app, /summary:'pageSummary'/);
  assert.match(functionBody(app, 'routeFromLocation'), /if\(isTransactionSummaryRoute\(\)\) return 'summary';/);
  assert.match(functionBody(app, 'urlFor'), /'summarytransaction\/'\+encodeURIComponent\(_txScreenToken\)/);
  assert.match(app, /parts\[parts\.length-2\]==='summarytransaction'/);
  const opener = functionBody(app, 'openTxDetail');
  assert.match(opener, /navigate\('summary', true\)/);
  assert.doesNotMatch(opener, /getElementById\('txSheet/);
  assert.doesNotMatch(opener, /location\.assign/);
});

test('signed-out visitors log in first and then land on the same transaction', () => {
  assert.match(app, /sessionStorage\.setItem\('px_pending_summary',pending\)/);
  assert.match(app, /sessionStorage\.getItem\('px_pending_summary'\)/);
  assert.match(app, /sessionStorage\.removeItem\('px_pending_summary'\)/);
});

test('summary details keep amount, split and transaction sections in order', () => {
  const body = functionBody(app, 'txDetailHTML');
  const rows = ['بڕی نێردراو', 'کرێی خزمەتگوزاری', 'بڕی داشکاندن', 'کۆی گشتی دوای کرێ'];
  const positions = rows.map(label => body.indexOf(`tfRow('${label}'`));
  assert.ok(positions.every(position => position >= 0), 'all amount rows exist');
  assert.deepEqual(positions, [...positions].sort((a, b) => a - b));
  const sections = ["tfSection('وردەکاری بڕ'", "tfSection('دابەشکردنی بڕ'", "tfSection('زانیاری مامەڵە'"].map(s => body.indexOf(s));
  assert.ok(sections.every(position => position >= 0), 'all sections exist');
  assert.deepEqual(sections, [...sections].sort((a, b) => a - b));
  const split = functionBody(app, 'tfSplitRows');
  assert.match(split, /بڕی نێردراو بۆ وەرگر/);
  assert.match(split, /بڕی گەڕاوە بۆ باڵانس/);
  assert.match(body, /renderOrderFeedback\(o\)/);
  assert.match(body, /downloadTransactionReceipt/);
});

test('screenshot transaction total subtracts gross fee and applies discount exactly once', () => {
  const order = {
    from_method: 'FastPay', to_method: 'FIB', amount: '11500', total: '11385', fee: '115',
    reward_original_fee_iqd: '230', reward_discount_iqd: '115', status: 'پەسەندکرا', payout_iqd: 11000,
    payout_rounding_iqd: 385, shortfall_refunded_iqd: 385
  };
  const payout = { settled: true, has_settlement: true, payout_iqd: 11000, remainder_iqd: 385 };
  const result = financials.breakdown(order, payout);
  assert.equal(result.feeBeforeDiscount, 230);
  assert.equal(result.netFee, 115);
  assert.equal(result.discount, 115);
  assert.equal(result.formulaTotal, 11500 - 230 + 115);
  assert.equal(result.total, 11385);
  assert.equal(result.formulaMatchesTotal, true);
  assert.equal(result.recipientAmount, 11000);
  assert.equal(result.returnedAmount, 385);
  assert.equal(result.recipientAmount + result.returnedAmount, result.total);
});

test('AccountBalance example keeps source debit distinct from the recipient-side total', () => {
  const order = {
    from_method: 'AccountBalance', to_method: 'FIB', amount: '11000', total: '10780', fee: '220',
    reward_original_fee_iqd: null, reward_discount_iqd: '0', status: 'پەسەندکرا', payout_iqd: 10000,
    payout_rounding_iqd: 780
  };
  const payout = { settled: true, has_settlement: true, payout_iqd: 10000, remainder_iqd: 780 };
  const result = financials.breakdown(order, payout);
  assert.equal(result.sourceAmount, 11000);
  assert.equal(result.formulaTotal, 10780);
  assert.equal(result.total, 10780);
  assert.equal(result.recipientAmount, 10000);
  assert.equal(result.returnedAmount, 780);
  assert.equal(result.formulaMatchesTotal, true);
});

test('secure summary URLs are built only from valid tokens', () => {
  const urlBody = functionBody(app, 'transactionSummaryUrlForOrder');
  const token = '11111111-1111-4111-8111-111111111111';
  const context = vm.createContext({ encodeURIComponent });
  vm.runInContext(urlBody, context);
  assert.equal(context.transactionSummaryUrlForOrder({ status: 'پەسەندکرا', secure_token: token }), '/summarytransaction/' + token);
  assert.equal(context.transactionSummaryUrlForOrder({ status: 'پەسەندکرا', secure_token: 'invalid' }), '');
});

test('direct route is rewritten securely and its token is redacted from analytics and error logs', () => {
  assert.ok(vercel.rewrites.some(rule => rule.source === '/summarytransaction/:token' && rule.destination === '/index.html'));
  const routeHeaders = vercel.headers.find(rule => rule.source === '/summarytransaction/:token');
  assert.ok(routeHeaders);
  assert.ok(routeHeaders.headers.some(header => header.key === 'Referrer-Policy' && header.value === 'no-referrer'));
  assert.ok(routeHeaders.headers.some(header => header.key === 'Cache-Control' && header.value === 'no-store'));
  assert.match(track, /summarytransaction\\\/\[\^\/\]\+/);
  assert.match(track, /summarytransaction\/:secure_token/);
  assert.match(app, /function safeAppTelemetryPath\(\)\{return summaryTokenFromPath\(\)\?'/);
  assert.match(app, /path:safeAppTelemetryPath\(\)/);
  assert.match(app, /\[operation,stage,code,safeAppTelemetryPath\(\)\]/);
});
