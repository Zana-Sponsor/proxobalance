import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const read = p => readFileSync(new URL(p, import.meta.url), 'utf8');
const app = read('../assets/js/app.js');
const html = read('../index.html');
const admin = read('../exchange-admin.html');
const access = read('../assets/js/receipt-access.js');
const notify = read('../api-handlers/notify-order.js');
const auth = read('../api-handlers/auth.js');

test('both customer and admin pages load the signed-receipt helper', () => {
  assert.match(html, /<script src="\/assets\/js\/receipt-access\.js\?v=\d+"><\/script>/);
  assert.match(admin, /<script src="assets\/js\/receipt-access\.js\?v=\d+"><\/script>/);
});

test('receipt links are signed for one hour and unsafe unsigned images stay hidden', () => {
  assert.match(access, /createSignedUrl\(path, TTL\)/);
  assert.match(access, /var TTL = 3600/);
  assert.match(access, /img\[src\*="' \+ MARK \+ '"\],img\[data-receipt-loading\]\{visibility:hidden\}/);
  assert.match(notify, /\/storage\/v1\/object\/sign\/receipts\//);
  assert.match(notify, /photo: receiptLink/);
});

test('password reset verifies a one-time grant before completing', () => {
  assert.match(auth, /reset_verify/);
  assert.match(auth, /reset_finish/);
  assert.match(app, /pxAuthApi\('reset_verify',\{identifier:_fpPhone\|\|_fpEmail,code\}\)/);
  assert.match(app, /pxAuthApi\('reset_finish',\{identifier:id,grant:_fpGrant,password:np\}\)/);
});

test('public endpoint response stays free of customer phone and order identifiers', () => {
  const pub = read('../api-handlers/public.js');
  assert.doesNotMatch(pub, /select=[^'`]*(phone|order_code)/);
  assert.doesNotMatch(pub, /\bphone\s*:|order_code\s*:|row\.order_code|row\.phone/);
});
