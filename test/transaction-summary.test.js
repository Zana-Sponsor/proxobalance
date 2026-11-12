import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import summaryApi from '../api-handlers/transaction-summary.js';

await import('../assets/js/transaction-summary-financials.js');
const financials = globalThis.ProxoTransactionSummaryFinancials;
const app = readFileSync(new URL('../assets/js/app.js', import.meta.url), 'utf8');
const api = readFileSync(new URL('../api-handlers/transaction-summary.js', import.meta.url), 'utf8');
const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const css = readFileSync(new URL('../assets/css/transaction-summary.css', import.meta.url), 'utf8');
const vercel = JSON.parse(readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'));
const track = readFileSync(new URL('../assets/js/track.js', import.meta.url), 'utf8');
const routeScript = readFileSync(new URL('../assets/js/transaction-summary-route.js', import.meta.url), 'utf8');

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

test('summary detail card has exactly the eight approved rows in the requested order and no phone row', () => {
  const render = functionBody(app, 'renderTransactionSummary');
  const labels = [
    'جۆری گواستنەوە',
    'کرێی خزمەتگوزاری',
    'بڕی داشکاندن',
    'بڕی باڵانسی گەڕاوە',
    'کۆی گشتی بەڵێبڕینەوە',
    'بڕی نێردراو بۆ وەرگر',
    'بەرواری ناردن',
    'بەرواری نوێکردنەوەی دۆخ'
  ];
  const positions = labels.map(label => render.indexOf(`summaryDetailRow('${label}'`));
  assert.ok(positions.every(position => position >= 0));
  assert.deepEqual(positions, [...positions].sort((a, b) => a - b));
  assert.doesNotMatch(render, /summaryDetailRow\(['"](?:ژمارەی وەرگر|ژمارەی مۆبایل)/);
  assert.match(render, /financial\.total/);
  assert.match(render, /financial\.recipientAmount/);
  assert.match(render, /financial\.returnedAmount/);
  assert.match(render, /txWhenHTML\(order\.created_at,true\)/);
  assert.match(render, /order\.status_updated_at\|\|order\.decided_at\|\|order\.updated_at/);
  assert.match(html, /<small>بڕی وەرگیراو<\/small>/);
  assert.match(html, /<small>بڕی نادراو<\/small>/);
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
  assert.notEqual(result.total + result.returnedAmount, result.total);
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

test('summary preserves secure full-page RTL elements, status, feedback, info, and receipt download', () => {
  assert.match(html, /id="transactionSummaryPage"[^>]*dir="rtl"[^>]*lang="ku"/);
  assert.match(html, /<h1 id="transactionSummaryTitle">پوختەی مامەڵە<\/h1>/);
  assert.match(html, /id="summaryInfoBackdrop"/);
  assert.match(html, /ئەم بڕە بەشێوەیەکی خۆکار گەڕاوەتەوە/);
  assert.match(html, /id="summaryStatus"/);
  assert.match(html, /id="summaryFeedback"/);
  assert.match(html, /summaryReceiptButton/);
  assert.match(html, /src="\/assets\/js\/transaction-summary-financials\.js\?v=1"/);
  assert.match(html, /src="\/assets\/js\/transaction-summary-route\.js\?v=1"/);
  assert.match(app, /function renderSummaryFeedback\(order\)/);
  assert.match(app, /renderSummaryStatus\(order\)/);
  assert.match(app, /function downloadSummaryReceipt\(\)[\s\S]+downloadTransactionReceipt/);
  assert.match(css, /\.ts-amount\.is-received/);
  assert.match(css, /\.ts-info-backdrop/);
  assert.match(css, /@media \(max-width: 380px\)/);
  assert.match(css, /direction: rtl/);
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
  assert.match(routeScript, /transaction-summary-active/);
  assert.doesNotMatch(html, /<script>\s*\(function\(\)\{\s*if\(\^\\\/summarytransaction/);
});
