import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
const migration = read('../supabase/migrations/20261124020000_customer_receipt_preflight.sql');
const edge = read('../supabase/functions/receipt-read/index.ts');
const orders = read('../api-handlers/orders.js');
const app = read('../assets/js/app.js');
const html = read('../index.html');
const formCss = read('../assets/css/exchange-form.css');

test('preflight stores server-owned route, amount, and configured recipient and validates the uploaded owner file', () => {
  assert.match(migration, /v_uid uuid:=auth\.uid\(\)/);
  assert.match(migration, /expected_receiver_account,receipt_url,receipt_hash/);
  assert.match(migration, /v_target\.wallet_number/);
  assert.match(migration, /o\.owner_id=v_uid::text or o\.owner=v_uid/);
  assert.match(migration, /p_receipt_url is null or p_receipt_hash is null/);
  assert.match(migration, /pg_advisory_xact_lock/);
});

test('OCR result accepts only confident complete fields and compares amount/currency and exact normalized destination', () => {
  assert.match(edge, /amount_confidence/);
  assert.match(edge, /receiver_account_confidence/);
  assert.match(edge, /amountConfidence >= 0\.8 && amountConfidence <= 1/);
  assert.match(edge, /receiverConfidence >= 0\.8 && receiverConfidence <= 1/);
  assert.match(migration, /v_amount_matches:=case when d\.expected_currency='USDT'/);
  assert.match(migration, /v_receiver_matches:=v_expected=v_receiver/);
  assert.match(migration, /left\(v_receiver,3\)='964'/);
  assert.match(migration, /length\(v_receiver\)=13/);
  assert.match(migration, /length\(v_receiver\)=10/);
  assert.match(migration, /v_amount_conf>1/);
  assert.match(migration, /v_receiver_conf>1/);
});

test('result and queue RPCs are authenticated owner-scoped and claim is server-only and one-use', () => {
  assert.match(migration, /where id=p_check_id and user_id=v_uid/);
  assert.match(migration, /where id=p_check_id and user_id=auth\.uid\(\)/);
  assert.match(migration, /revoke all on function public\.ex_customer_receipt_preflight_claim\([\s\S]*?from public,anon,authenticated/);
  assert.match(migration, /grant execute on function public\.ex_customer_receipt_preflight_claim[\s\S]*?to service_role/);
  assert.match(migration, /d\.claimed_at is null and d\.linked_order_id is null/);
  assert.match(migration, /d\.status='complete' and d\.is_receipt=true and d\.amount_matches=true and d\.receiver_matches=true/);
  assert.match(orders, /ex_customer_receipt_preflight_claim/);
  assert.match(orders, /p_user_id: user\.id/);
  assert.match(orders, /p_receipt_hash: receiptHash/);
  assert.match(orders, /receipt_preflight_id: !balanceSource && !retryOrder \? receiptPreflightId : null/);
});

test('same receipt OCR is promoted into admin history without invoking Gemini a second time', () => {
  assert.match(edge, /readCustomerReceiptPreflight/);
  assert.match(edge, /db\.rpc\('ex_customer_receipt_preflight_save'/);
  assert.match(migration, /insert into public\.ex_receipt_reads/);
  assert.match(migration, /tg_op='INSERT' and new\.receipt_url is not null and new\.receipt_preflight_id is not null/);
  assert.match(migration, /return null;\s+end if;\s+if new\.receipt_url is not null and \(tg_op='INSERT' or new\.receipt_url is distinct from old\.receipt_url\) then/);
  assert.match(migration, /perform public\.ex_receipt_read_queue\(new\.id\)/);
  assert.match(edge, /body\?\.customer_preflight_id/);
  assert.match(edge, /\[orderId, verificationId, identityDraftId, payoutVerificationId, customerPreflightId\]/);
});

test('customer form checks before order creation and renders both exact Kurdish mismatch messages in existing error styling', () => {
  const preflightAt = app.indexOf('receiptPreflightId=await runCustomerReceiptPreflight');
  const orderRequestAt = app.indexOf("orderResponse=await fetch('/api/orders'", preflightAt);
  assert.ok(preflightAt >= 0 && orderRequestAt > preflightAt);
  assert.match(app, /بڕی ناردراو یەکناگرێتەوە لەگەڵ بڕی نوسراو!/);
  assert.match(app, /باڵانس بۆ ژمارەیەکی ھەڵە نێردراوە!/);
  assert.match(app, /setFieldError\('fileInput',e\.message\)/);
  assert.match(html, /id="fileInputError"/);
  assert.match(formCss, /\.field-error\.show/);
  assert.match(app, /p_to_method:to/);
  assert.doesNotMatch(app, /p_expected_receiver/);
});

test('customer status polling stays owner-scoped and no unauthenticated table select is added to the UI', () => {
  assert.match(app, /ex_customer_receipt_preflight_start/);
  assert.match(app, /ex_customer_receipt_preflight_queue/);
  assert.match(app, /ex_customer_receipt_preflight_result/);
  assert.match(migration, /revoke all on public\.ex_customer_receipt_preflights from public, anon, authenticated/);
  assert.match(migration, /grant all on public\.ex_customer_receipt_preflights to service_role/);
  assert.doesNotMatch(app, /from\('ex_customer_receipt_preflights'\)/);
});

async function callOrders(body, claimResult) {
  process.env.SUPABASE_SERVICE_ROLE_KEY ||= 'test-service-key';
  process.env.SECURITY_FINGERPRINT_SALT ||= 'test-fingerprint-salt';
  process.env.TRUSTED_PROXY ||= 'direct';
  const { default: ordersHandler } = await import('../api-handlers/orders.js');
  const originalFetch = globalThis.fetch;
  const inserted = [];
  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input));
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return new Response(JSON.stringify([{ banned: false }]), { status: 200 });
    if (url.pathname === '/auth/v1/user') return new Response(JSON.stringify({ id: 'preflight-test-user' }), { status: 200 });
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return new Response(null, { status: 200 });
    if (url.pathname === '/rest/v1/rpc/security_log_event') return new Response(null, { status: 200 });
    if (url.pathname === '/rest/v1/ex_wallets') return new Response(JSON.stringify([
      { key: 'NassWallet', is_locked: false, allow_from: true, recipient_format: 'phone', sender_phone_required: false },
      { key: 'FIB', is_locked: false, allow_receive: true, recipient_format: 'phone', sender_phone_required: false }
    ]), { status: 200 });
    if (url.pathname === '/rest/v1/ex_rates') return new Response(JSON.stringify([{ rate_type: 'multiplier', rate_value: 1 }]), { status: 200 });
    if (url.pathname === '/rest/v1/ex_profiles') return new Response(JSON.stringify([{ id: 'preflight-test-user', is_banned: false }]), { status: 200 });
    if (url.pathname === '/rest/v1/rpc/security_record_order_attempt') return new Response(JSON.stringify({ banned: false }), { status: 200 });
    if (url.pathname === '/rest/v1/ex_orders' && (options.method || 'GET') === 'GET') return new Response('[]', { status: 200 });
    if (url.pathname === '/rest/v1/rpc/ex_customer_receipt_preflight_claim') {
      return claimResult === 'error'
        ? new Response(JSON.stringify({ code: 'P0001', message: 'RECEIPT_PREFLIGHT_REQUIRED' }), { status: 400 })
        : new Response('true', { status: 200 });
    }
    if (url.pathname === '/rest/v1/ex_orders' && options.method === 'POST') {
      inserted.push(JSON.parse(options.body));
      return new Response(JSON.stringify([{ id: 'created', ...JSON.parse(options.body) }]), { status: 201 });
    }
    throw new Error(`Unexpected request: ${options.method || 'GET'} ${url.pathname}`);
  };
  try {
    let payload;
    const res = { statusCode: 0, setHeader() {}, end(text = '') { payload = JSON.parse(text); } };
    await ordersHandler({
      method: 'POST', url: '/api/orders', headers: { authorization: 'Bearer fixture', 'user-agent': 'Test Browser' },
      socket: { remoteAddress: '127.0.0.1' }, body: {
        from_method: 'NassWallet', to_method: 'FIB', amount: 10000, phone: '07510070000',
        receipt_url: 'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/preflight-test-user/a.jpg',
        receipt_hash: 'd'.repeat(64), ...body
      }
    }, res);
    return { status: res.statusCode, payload, inserted };
  } finally {
    globalThis.fetch = originalFetch;
  }
}

test('new receipt-backed order is rejected when receipt_preflight_id is omitted', async () => {
  const out = await callOrders({}, true);
  assert.equal(out.status, 422, JSON.stringify(out.payload));
  assert.equal(out.payload.code, 'RECEIPT_PREFLIGHT_REQUIRED');
  assert.equal(out.inserted.length, 0);
});

test('new receipt-backed order is not inserted when atomic one-use claim fails', async () => {
  const out = await callOrders({ receipt_preflight_id: '33333333-3333-4333-8333-333333333333' }, 'error');
  assert.equal(out.status, 409, JSON.stringify(out.payload));
  assert.equal(out.payload.code, 'RECEIPT_PREFLIGHT_REQUIRED');
  assert.equal(out.inserted.length, 0);
});
