import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const read = p => readFileSync(new URL(p, import.meta.url), 'utf8');

test('both customer and admin pages sign receipt links before rendering', () => {
  assert.match(read('../index.html'), /<script src="\/assets\/js\/receipt-access\.js\?v=\d+"><\/script>/);
  assert.match(read('../exchange-admin.html'), /<script src="assets\/js\/receipt-access\.js\?v=\d+"><\/script>/);
  assert.match(read('../assets/js/receipt-access.js'), /createSignedUrl\(path, TTL\)/);
});

test('order notifications use a signed receipt link for Telegram', () => {
  const notify = read('../api-handlers/notify-order.js');
  assert.match(notify, /\/storage\/v1\/object\/sign\/receipts\//);
  assert.match(notify, /photo: receiptLink/);
});

test('the public endpoint returns no order codes or phone numbers', () => {
  const pub = read('../api-handlers/public.js');
  assert.doesNotMatch(pub, /select=[^'`]*(phone|order_code)/);
  assert.doesNotMatch(pub, /\bphone\s*:|order_code\s*:|row\.order_code|row\.phone/);
});

test('the receipts-private migration changes only the existing receipts bucket', () => {
  const sql = read('../supabase/migrations/20261114191000_receipts_private_bucket.sql');
  assert.match(sql, /set public = false where id = 'receipts'/);
});
