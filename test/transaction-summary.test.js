import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import summaryApi from '../api-handlers/transaction-summary.js';

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

test('summary route requires an authenticated owner and matches the existing secure_token only', () => {
  assert.match(api, /auth:\s*'required'/);
  assert.match(api, /secure_token=eq\./);
  assert.match(api, /user_id=eq\./);
  assert.match(api, /&select=\$\{ORDER_FIELDS\}&limit=1/);
  assert.match(api, /ex_refund_cases\?id=eq\./);
  assert.match(api, /&order_id=eq\.\$\{encodeURIComponent\(order\.id\)\}&user_id=eq\./);
  assert.match(api, /if \(!order\) return json\(res, 404/);
  assert.doesNotMatch(api.match(/const ORDER_FIELDS = \[([\s\S]*?)\]\.join/)?.[1] || '', /secure_token/);
  assert.doesNotMatch(api.match(/const ORDER_FIELDS = \[([\s\S]*?)\]\.join/)?.[1] || '', /sender_phone/);
  assert.doesNotMatch(api, /gen_random_uuid|randomUUID|set\s+secure_token\s*=/i);
});

test('transaction detail rows keep the requested Kurdish labels and exact financial order', () => {
  const render = functionBody(app, 'renderTransactionSummary');
  const labels = [
    'جۆری گواستنەوە',
    'کرێی خزمەتگوزاری',
    'بڕی داشکاندن',
    'بڕی باڵانسی گەڕاوە',
    'کۆی گشتی بەڵێبڕینەوە',
    'بڕی نێردراو بۆ وەرگر',
    'ژمارەی وەرگر',
    'بەرواری ناردن',
    'بەرواری نوێکردنەوەی دۆخ'
  ];
  const positions = labels.map(label => render.indexOf(`summaryDetailRow('${label}'`));
  assert.ok(positions.every(position => position >= 0));
  assert.deepEqual(positions, [...positions].sort((a, b) => a - b));
  assert.match(render, /<small>بڕی وەرگیراو<\/small>/);
  assert.match(render, /<small>بڕی نادراو<\/small>/);
  assert.match(render, /const received=.*payout\?\.settled/);
  assert.match(render, /const returned=.*payout\?\.settled/);
  assert.match(render, /refund_case_amount_iqd\?\?order\.amount/);
  assert.match(render, /txAmount\(order\.amount,order\.from_method\)/);
  assert.match(render, /txAmount\(order\.total,order\.to_method\)/);
});

test('summary preserves the reference-page elements and full-page responsive RTL presentation', () => {
  assert.match(html, /id="transactionSummaryPage"[^>]*dir="rtl"[^>]*lang="ku"/);
  assert.match(app, /<h1>پوختەی مامەڵە<\/h1>/);
  assert.match(html, /id="summaryInfoBackdrop"/);
  assert.match(html, /ئەم بڕە بەشێوەیەکی خۆکار گەڕاوەتەوە/);
  assert.match(app, /function renderTransactionSummary/);
  assert.match(app, /renderOrderFeedback\(order\)/);
  assert.match(app, /downloadTransactionReceipt/);
  assert.match(css, /\.ts-amount\.is-received/);
  assert.match(css, /\.ts-info-backdrop/);
  assert.match(css, /@media \(max-width: 380px\)/);
  assert.match(css, /direction: rtl/);
});

test('direct route is rewritten securely and its token is redacted from analytics', () => {
  assert.ok(vercel.rewrites.some(rule => rule.source === '/summarytransaction/:token' && rule.destination === '/index.html'));
  const routeHeaders = vercel.headers.find(rule => rule.source === '/summarytransaction/:token');
  assert.ok(routeHeaders);
  assert.ok(routeHeaders.headers.some(header => header.key === 'Referrer-Policy' && header.value === 'no-referrer'));
  assert.ok(routeHeaders.headers.some(header => header.key === 'Cache-Control' && header.value === 'no-store'));
  assert.match(track, /summarytransaction\\\/\[\^\/\]\+/);
  assert.match(track, /summarytransaction\/:secure_token/);
  assert.match(app, /function safeAppTelemetryPath\(\)\{return summaryTokenFromPath\(\)\?'/);
  assert.match(app, /path:telemetryPath/);
});
