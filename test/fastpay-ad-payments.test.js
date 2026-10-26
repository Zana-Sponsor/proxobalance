import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fastpayConfiguration, fastpayClient, createQrRequest, verifyFastpayAttempt, PaymentError } from '../api/_lib/payments/fastpay.js';
import { preparePayment, reconcilePayment, runPaymentReconciliation } from '../api/_lib/payments/worker.js';
import { createPaymentHandler, publicPaymentAttempt } from '../api/_lib/payments/handler.js';
import { paymentBackend } from '../api/_lib/payments/backend.js';

const NOW = Date.parse('2026-10-23T12:00:00Z');
const ID = '11111111-1111-4111-8111-111111111111';
const USER = '22222222-2222-4222-8222-222222222222';
const SUBMISSION = '33333333-3333-4333-8333-333333333333';
const QUOTE = '44444444-4444-4444-8444-444444444444';
const env = {
  FASTPAY_AD_ENVIRONMENT: 'sandbox', FASTPAY_AD_CREATE_ENABLED: 'true',
  FASTPAY_AD_SANDBOX_STORE_ID: 'PROXO_SBX_01', FASTPAY_AD_SANDBOX_STORE_PASSWORD: 'mock-private-password',
  FASTPAY_AD_WORKER_SECRET: 'mock-worker-secret-with-at-least-32-characters',
  PROXO_AD_PAYMENTS_BACKEND_ORIGIN: 'https://payments.example',
  FASTPAY_AD_CALLBACK_URL: 'https://payments.example/api/meta-ads?platform=payments&op=callback',
};
const attempt = () => ({ ok: true, attempt_id: ID, order_id: 'AP0123456789012345678901234567', transaction_id: QUOTE,
  environment: 'sandbox', merchant_reference: env.FASTPAY_AD_SANDBOX_STORE_ID, currency: 'IQD', amount_iqd: 14500,
  cost_usd: 10, fx_rate: 1450, status: 'prepared', expires_at: new Date(NOW + 10 * 60000).toISOString(), creation_hash: null,
  qr_url: null, qr_text: null, lease_token: '55555555-5555-4555-8555-555555555555', result: null });
const paid = () => ({ merchant_order_id: attempt().order_id, order_id: attempt().order_id, received_amount: 14500,
  currency: 'IQD', gw_transaction_id: 'GW123456', payment_status: 'PAID', status: 'success' });
const envelope = data => new Response(JSON.stringify({ code: 200, errors: [], data }), { status: 200 });
function ledger(seed = attempt()) {
  let state = structuredClone(seed), funded = 0;
  const calls = [];
  const service = async (action, args = {}) => {
    calls.push({ action, ...structuredClone(args) });
    if (action === 'read' || action === 'claim_reconcile') return structuredClone(state);
    if (action === 'create_intent') {
      if (state.status !== 'prepared') return { ...structuredClone(state), must_reconcile: true };
      state.status = 'creating'; state.creation_hash = args.payload.request_hash;
      return { ...structuredClone(state), create_authorized: true };
    }
    if (action === 'qr_created') { Object.assign(state, args.payload, { status: 'awaiting' }); return structuredClone(state); }
    if (action === 'close_unstarted') {
      if (state.status === 'prepared' && !state.creation_hash && !state.creation_started_at)
        Object.assign(state, { status: 'cancelled', payment_not_started: true });
      return structuredClone(state);
    }
    if (action === 'unknown') { state.status = 'reconcile'; return { ok: true }; }
    if (action === 'observe_status') {
      assert.equal(args.payload.verification_source, 'FASTPAY_STATUS');
      assert(['DECLINED', 'UNPAID'].includes(args.payload.status));
      if (args.payload.status === 'DECLINED' && !['funded', 'compensated'].includes(state.status)) state.status = 'declined';
      return structuredClone(state);
    }
    if (action === 'observe_verified') {
      assert.equal(args.payload.verification_source, 'FASTPAY_VALIDATE');
      assert.equal(args.payload.amount_iqd, 14500);
      assert.equal(args.payload.merchant_reference, env.FASTPAY_AD_SANDBOX_STORE_ID);
      if (state.status !== 'funded') funded++;
      state.status = 'funded'; state.result = { ad_id: QUOTE, receipt_uid: SUBMISSION }; return structuredClone(state);
    }
    if (action === 'finish_reconcile' || action === 'callback_hint') return { ok: true };
    throw new Error(action);
  };
  return { service, calls, get state() { return state; }, get funded() { return funded; } };
}
async function invoke(handler, op, body, authorization = 'Bearer mock-user-token') {
  const req = { method: 'POST', url: `/api/meta-ads?platform=payments&op=${op}`, query: { op }, body,
    headers: authorization ? { authorization } : {} };
  const res = { headers: {}, setHeader(key, value) { this.headers[key] = value; }, end(value) { this.body = JSON.parse(value); } };
  await handler(req, res); return res;
}

test('official sandbox is pinned; secrets are server-only and production creation defaults off', async () => {
  const config = fastpayConfiguration('sandbox', { env, forCreate: true });
  assert.equal(config.base, 'https://staging-qr.fast-pay.iq');
  assert.throws(() => fastpayConfiguration('sandbox', { env: { ...env, FASTPAY_AD_CREATE_ENABLED: undefined }, forCreate: true }), { code: 'FASTPAY_AD_CREATION_DISABLED' });
  assert.throws(() => fastpayConfiguration('production', { env: { ...env, FASTPAY_AD_ENVIRONMENT: 'production' }, forCreate: true }), { code: 'FASTPAY_AD_PRODUCTION_DISABLED' });
  assert.throws(() => fastpayConfiguration('production', { env, forCreate: true }), { code: 'FASTPAY_ENVIRONMENT_MISMATCH' });
  assert.throws(() => fastpayClient({ ...config, base: 'https://attacker.example' }), { code: 'FASTPAY_ORIGIN_INVALID' });
  assert.throws(() => fastpayConfiguration('sandbox', { env: { ...env, FASTPAY_AD_CALLBACK_URL: 'https://attacker.example/callback' }, forCreate: true }), { code: 'FASTPAY_CALLBACK_NOT_CONFIGURED' });
  const requests = [];
  const api = fastpayClient(config, { fetchImpl: async (url, options) => { requests.push({ url, options }); return envelope(paid()); } });
  await api('status', { orderId: attempt().order_id });
  assert.equal(requests[0].url, 'https://staging-qr.fast-pay.iq/api/v1/public/vending/status');
  assert.equal(requests[0].options.redirect, 'error');
  assert.equal(JSON.parse(requests[0].options.body).storePassword, env.FASTPAY_AD_SANDBOX_STORE_PASSWORD);
  assert(!requests[0].url.includes(env.FASTPAY_AD_SANDBOX_STORE_PASSWORD));
});

test('QR mutation follows durable intent, uses original quote money, and concurrent retries create once', async () => {
  const db = ledger(), calls = [];
  const fetchImpl = async (url, options) => {
    assert.equal(db.state.status, 'creating'); assert(db.state.creation_hash);
    const payload = JSON.parse(options.body); calls.push({ url, payload });
    assert.equal(payload.billAmount, 14500); assert.equal(payload.currency, 'IQD');
    assert.equal(payload.orderId, db.state.order_id); assert(!('orderID' in payload));
    return envelope({ qrUrl: 'https://staging-qr.fast-pay.iq/qr/order.png', qrText: 'mock-payment-qr-text' });
  };
  const options = { service: db.service, env, fetchImpl, now: () => NOW };
  await Promise.all([preparePayment(ID, options), preparePayment(ID, options)]);
  await preparePayment(ID, options);
  assert.equal(calls.length, 1); assert.equal(db.state.status, 'awaiting');
  assert.equal(db.calls.find(call => call.action === 'create_intent').payload.request_hash.length, 64);
  assert.equal(db.funded, 0);
  const publicResult = publicPaymentAttempt(db.state, { now: NOW });
  assert(publicResult.qr_text); assert(!JSON.stringify(publicResult).includes('merchant_reference')); assert(!JSON.stringify(publicResult).includes('lease_token'));
});

test('lost QR reply records uncertainty and all future attempts reconcile without another QR POST', async () => {
  const db = ledger(), calls = [];
  const fetchImpl = async url => {
    calls.push(url);
    if (url.endsWith('/qr')) throw new Error('private gateway transport details');
    return envelope({ merchant_order_id: attempt().order_id, payment_status: 'UNPAID' });
  };
  const options = { service: db.service, env, fetchImpl, now: () => NOW };
  const first = await preparePayment(ID, options);
  assert.equal(first.status, 'reconcile'); assert.equal(first.reconciliation_code, 'FASTPAY_CREATION_OUTCOME_UNKNOWN');
  await preparePayment(ID, options); await runPaymentReconciliation(options);
  assert.equal(calls.filter(url => url.endsWith('/qr')).length, 1);
  assert.equal(calls.filter(url => url.endsWith('/status')).length, 2);
  assert.equal(db.funded, 0);
});

test('paid status requires independent validate with exact order, merchant, amount, currency and transaction', async () => {
  const config = fastpayConfiguration('sandbox', { env });
  const a = { ...attempt(), creation_hash: 'a'.repeat(64) };
  const data = paid(), calls = [];
  const api = fastpayClient(config, { fetchImpl: async url => { calls.push(url); return envelope(data); } });
  const verified = await verifyFastpayAttempt(api, a, config, { now: NOW });
  assert.equal(verified.paid, true); assert.equal(verified.verification.status, 'PAID');
  assert.deepEqual(calls.map(url => url.split('/').at(-1)), ['status', 'validate']);
  assert.match(verified.verification.response_sha256, /^[a-f0-9]{64}$/);
  for (const changes of [
    { merchant_order_id: 'ANOTHER_ORDER' }, { order_id: 'ANOTHER_ORDER' }, { received_amount: 14501 }, { received_amount: '14500.01' },
    { received_amount: null }, { currency: undefined }, { currency: 'USD' }, { gw_transaction_id: '' },
  ]) {
    const wrong = fastpayClient(config, { fetchImpl: async () => envelope({ ...paid(), ...changes }) });
    await assert.rejects(verifyFastpayAttempt(wrong, a, config, { now: NOW }), { code: 'FASTPAY_VERIFICATION_MISMATCH' });
  }
  for (const changes of [{ status: 'approved' }, { gw_transaction_id: 'GW-DIFFERENT' }]) {
    const wrong = fastpayClient(config, { fetchImpl: async url => envelope({ ...paid(), ...(url.endsWith('/validate') ? changes : {}) }) });
    await assert.rejects(verifyFastpayAttempt(wrong, a, config, { now: NOW }), { code: 'FASTPAY_VERIFICATION_MISMATCH' });
  }
  await assert.rejects(verifyFastpayAttempt(api, { ...a, merchant_reference: 'OTHER_STORE' }, config), { code: 'FASTPAY_ATTEMPT_MISMATCH' });
});

test('malformed JSON, HTML, redirects, HTTP errors and uncertain provider replies never authorize funding', async () => {
  const config = fastpayConfiguration('sandbox', { env });
  for (const response of [
    new Response('<html>Gateway unavailable</html>'),
    new Response('{"code":200,"errors":[] "data":{}}'),
    new Response(JSON.stringify({ code: 200, data: paid() })),
    new Response(JSON.stringify({ code: 200, errors: [], data: paid() }), { status: 503 }),
    new Response('', { status: 302, headers: { location: 'https://attacker.example' } }),
  ]) {
    const api = fastpayClient(config, { fetchImpl: async () => response });
    await assert.rejects(verifyFastpayAttempt(api, { ...attempt(), creation_hash: 'a'.repeat(64) }, config), { code: 'FASTPAY_VERIFICATION_UNAVAILABLE' });
  }
  const db = ledger({ ...attempt(), status: 'reconcile', creation_hash: 'a'.repeat(64) });
  const result = await runPaymentReconciliation({ service: db.service, env, now: () => NOW, fetchImpl: async () => { throw new Error('private detail'); } });
  assert.equal(result.status, 'reconcile'); assert.equal(db.funded, 0);
  assert(!JSON.stringify(result).includes('private detail'));
  assert.equal(db.calls.at(-1).action, 'finish_reconcile');
});

test('late paid attempts settle without app or quote revalidation; duplicate checks remain idempotent', async () => {
  const db = ledger({ ...attempt(), status: 'expired', expires_at: new Date(NOW - 60000).toISOString(), creation_hash: 'a'.repeat(64) });
  const options = { service: db.service, env: { ...env, FASTPAY_AD_CREATE_ENABLED: 'false' }, fetchImpl: async () => envelope(paid()), now: () => NOW };
  assert.equal((await runPaymentReconciliation(options)).status, 'funded');
  await reconcilePayment({ ...db.state, status: 'reconcile' }, options);
  assert.equal(db.funded, 1);
  assert(db.calls.every(call => !['create_intent', 'qr_created'].includes(call.action)));
  const result = publicPaymentAttempt(db.state, { now: NOW });
  assert.equal(result.terminal, true); assert.equal(result.result.ad_id, QUOTE); assert.equal(result.qr_url, null);
});

test('callback is an untrusted generic hint and cannot inject verified money, status or identity', async () => {
  const calls = [], handler = createPaymentHandler({ env, db: { service: async (action, args) => { calls.push({ action, args }); return { ok: true }; } } });
  const result = await invoke(handler, 'callback', { merchant_order_id: attempt().order_id, status: 'paid', verified: true, received_amount: 999999, user_id: USER }, null);
  assert.equal(result.statusCode, 200); assert.deepEqual(result.body, { received: true });
  assert.deepEqual(calls, [{ action: 'callback_hint', args: { payload: { order_id: attempt().order_id } } }]);
  const unknown = await invoke(handler, 'callback', { verified: true }, null);
  assert.deepEqual(unknown.body, { received: true }); assert.equal(calls.length, 1);
});

test('public prepare/status/cancel are owner-authenticated and status recovers by submission only', async () => {
  const db = ledger({ ...attempt(), status: 'awaiting', creation_hash: 'a'.repeat(64) });
  const userCalls = [];
  const backend = { service: db.service, authenticate: async () => ({ id: USER }), user: async (req, name, payload) => { userCalls.push({ name, payload }); return structuredClone(db.state); } };
  const handler = createPaymentHandler({ env, db: backend, now: () => NOW, fetchImpl: async () => envelope(paid()) });
  const result = await invoke(handler, 'status', { submission_id: SUBMISSION });
  assert.equal(result.statusCode, 200); assert.equal(result.body.status, 'funded'); assert.equal(result.body.terminal, true);
  assert.deepEqual(userCalls[0], { name: 'pa_ad_payment_status', payload: { p_submission_id: SUBMISSION } });
  assert(!JSON.stringify(result.body).includes('merchant_reference')); assert(!JSON.stringify(result.body).includes('creation_hash'));
  await invoke(handler, 'cancel', { attempt_id: ID });
  assert.equal(userCalls.at(-1).name, 'pa_ad_payment_cancel');
  const unauthorized = createPaymentHandler({ env, db: { ...backend, authenticate: async () => null } });
  assert.equal((await invoke(unauthorized, 'prepare', {})).statusCode, 401);
  assert.equal((await invoke(handler, 'status', { submission_id: SUBMISSION, verified: true })).statusCode, 422);
});

test('prepare forwards expected totals only to the immutable quote RPC and never accepts caller order or merchant', async () => {
  const db = ledger(), userCalls = [];
  const backend = { service: db.service, authenticate: async () => ({ id: USER }), user: async (req, name, payload) => { userCalls.push({ name, payload }); return structuredClone(db.state); } };
  const handler = createPaymentHandler({ env, db: backend, now: () => NOW, fetchImpl: async () => envelope({ qrUrl: 'https://staging-qr.fast-pay.iq/qr.png', qrText: 'mock-qr-text' }) });
  const body = { submission_id: SUBMISSION, platform: 'TIKTOK', quote_id: QUOTE, expected_cost_usd: 10, expected_amount_iqd: 14500 };
  const response = await invoke(handler, 'prepare', body);
  assert.equal(response.body.status, 'awaiting');
  assert.equal(userCalls[0].name, 'pa_ad_payment_attempt');
  assert.deepEqual(userCalls[0].payload, { p_submission_id: SUBMISSION, p_platform: 'TIKTOK', p_quote_id: QUOTE, p_expected_cost_usd: 10, p_expected_amount_iqd: 14500 });
  assert.equal((await invoke(handler, 'prepare', { ...body, order_id: 'EVIL_ORDER' })).statusCode, 422);
  assert.equal(userCalls.length, 1);
});

test('prepare proves no attempt exists only for explicit pre-attempt business rejections', async () => {
  const body = { submission_id: SUBMISSION, platform: 'TIKTOK', quote_id: QUOTE, expected_cost_usd: 10, expected_amount_iqd: 14500 };
  for (const code of ['AD_FASTPAY_UNAVAILABLE', 'QUOTE_EXPIRED', 'PRICE_CHANGED']) {
    let gatewayCalls = 0, privateCalls = 0;
    const handler = createPaymentHandler({ env,
      db: { authenticate: async () => ({ id: USER }),
        user: async () => { throw new PaymentError(code, { status: 409 }); },
        service: async () => { privateCalls++; throw new Error('must not start payment'); } },
      fetchImpl: async () => { gatewayCalls++; throw new Error('must not call provider'); } });
    const response = await invoke(handler, 'prepare', body);
    assert.equal(response.statusCode, 409);
    assert.equal(response.body.code, code);
    assert.equal(response.body.uncertain, false);
    assert.equal(response.body.attempt_created, false);
    assert.equal(privateCalls, 0); assert.equal(gatewayCalls, 0);
  }
});

test('conflicts, ambiguous RPC results and errors after durable prepare cannot prove no payment exists', async () => {
  const body = { submission_id: SUBMISSION, platform: 'META', quote_id: QUOTE, expected_cost_usd: 10, expected_amount_iqd: 14500 };
  for (const error of [
    new PaymentError('IDEMPOTENCY_CONFLICT', { status: 409 }),
    new PaymentError('QUOTE_EXPIRED', { status: 503, uncertain: true }),
    new PaymentError('FASTPAY_VERIFICATION_MISMATCH', { status: 409 }),
  ]) {
    const handler = createPaymentHandler({ env, db: { authenticate: async () => ({ id: USER }),
      user: async () => { throw error; } } });
    const response = await invoke(handler, 'prepare', body);
    assert.equal(Object.hasOwn(response.body, 'attempt_created'), false);
  }
  const handler = createPaymentHandler({ env, now: () => NOW,
    db: { authenticate: async () => ({ id: USER }), user: async () => attempt(),
      service: async () => { throw new PaymentError('QUOTE_EXPIRED', { status: 409 }); } } });
  const response = await invoke(handler, 'prepare', body);
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.attempt_id, ID);
  assert.equal(response.body.uncertain, true);
  assert.equal(Object.hasOwn(response.body, 'attempt_created'), false);
});

test('worker requires its dedicated secret, accepts no caller IDs, and never starts prepared QR orders', async () => {
  const db = ledger(); let gatewayCalls = 0;
  const handler = createPaymentHandler({ env, db, now: () => NOW, fetchImpl: async () => { gatewayCalls++; throw new Error('unexpected'); } });
  assert.equal((await invoke(handler, 'worker-reconcile', {}, 'Bearer wrong')).statusCode, 401);
  assert.equal((await invoke(handler, 'worker-reconcile', { attempt_id: ID }, `Bearer ${env.FASTPAY_AD_WORKER_SECRET}`)).statusCode, 422);
  const result = await invoke(handler, 'worker-reconcile', {}, `Bearer ${env.FASTPAY_AD_WORKER_SECRET}`);
  assert.equal(result.body.status, 'pending'); assert.equal(gatewayCalls, 0);
  assert(!db.calls.some(call => call.action === 'create_intent'));
});

test('database adapter authenticates actual user and uses user token for owner RPC, service key only internally', async () => {
  const requests = [], db = paymentBackend({ env: { PROXO_SUPABASE_URL: 'https://project.supabase.co', PROXO_SUPABASE_SERVICE_ROLE_KEY: 'mock-service-key' },
    fetchImpl: async (url, options) => { requests.push({ url, options }); return new Response(JSON.stringify(url.endsWith('/user') ? { id: USER } : { ok: true })); } });
  const req = { headers: { authorization: 'Bearer user-token' } };
  await db.authenticate(req); await db.user(req, 'pa_ad_payment_status', { p_submission_id: SUBMISSION }); await db.service('callback_hint', { payload: { order_id: attempt().order_id } });
  assert.equal(requests[0].options.headers.Authorization, 'Bearer user-token');
  assert.equal(requests[1].options.headers.Authorization, 'Bearer user-token');
  assert.equal(requests[2].options.headers.Authorization, 'Bearer mock-service-key');
  assert.deepEqual(JSON.parse(requests[2].options.body), { p_action: 'callback_hint', p_attempt_id: null, p_payload: { order_id: attempt().order_id } });
  assert.throws(() => createQrRequest({ ...attempt(), amount_iqd: 0 }, fastpayConfiguration('sandbox', { env, forCreate: true }), { now: NOW }), { code: 'FASTPAY_ATTEMPT_MISMATCH' });
});

test('prepare preserves the durable attempt on service and intent failures', async () => {
  const body = { submission_id: SUBMISSION, platform: 'META', quote_id: QUOTE, expected_cost_usd: 10, expected_amount_iqd: 14500 };
  for (const mode of ['read', 'intent']) {
    const db = ledger(); let gatewayCalls = 0;
    const backend = { authenticate: async () => ({ id: USER }), user: async () => attempt(),
      service: async (action, args) => {
        if (action === (mode === 'intent' ? 'create_intent' : mode)) throw new PaymentError('AD_PAYMENT_BACKEND_UNAVAILABLE', { status: 503, uncertain: true });
        return db.service(action, args);
      } };
    const handler = createPaymentHandler({ env: { ...env, FASTPAY_AD_CREATE_ENABLED: mode === 'configuration' ? 'false' : 'true' },
      db: backend, now: () => NOW, fetchImpl: async () => { gatewayCalls++; throw new Error('unexpected'); } });
    const response = await invoke(handler, 'prepare', body);
    assert.equal(response.statusCode, 200); assert.equal(response.body.attempt_id, ID);
    assert.equal(response.body.uncertain, true); assert.equal(response.body.terminal, false);
    assert.equal(gatewayCalls, 0); assert.equal(response.body.qr_text, null);
  }
});

test('configuration and elapsed QR window close unstarted attempts without contacting FastPay', async () => {
  const body = { submission_id: SUBMISSION, platform: 'META', quote_id: QUOTE, expected_cost_usd: 10, expected_amount_iqd: 14500 };
  for (const mode of ['configuration', 'expired']) {
    const db = ledger(mode === 'expired' ? { ...attempt(), expires_at: new Date(NOW - 1).toISOString() } : attempt());
    let gatewayCalls = 0;
    const backend = { authenticate: async () => ({ id: USER }), user: async () => structuredClone(db.state), service: db.service };
    const handler = createPaymentHandler({ env: { ...env, FASTPAY_AD_CREATE_ENABLED: mode === 'configuration' ? 'false' : 'true' },
      db: backend, now: () => NOW, fetchImpl: async () => { gatewayCalls++; throw new Error('No gateway intent exists'); } });
    const response = await invoke(handler, 'prepare', body);
    assert.equal(response.statusCode, 200); assert.equal(response.body.status, 'cancelled');
    assert.equal(response.body.payment_not_started, true); assert.equal(response.body.uncertain, false);
    assert.equal(response.body.qr_text, null); assert.equal(gatewayCalls, 0);
    assert.deepEqual(db.calls.map(call => call.action), ['read', 'close_unstarted']);
    const recovered = await invoke(handler, 'status', { submission_id: SUBMISSION });
    assert.equal(recovered.body.payment_not_started, true);
    assert(!db.calls.some(call => call.action === 'create_intent'));
  }
});

test('expired unstarted status closes synchronously without depending on the background worker', async () => {
  const db = ledger({ ...attempt(), expires_at: new Date(NOW - 1).toISOString() });
  const result = await reconcilePayment(db.state, { service: db.service, env, now: () => NOW,
    fetchImpl: async () => { throw new Error('No gateway request may occur'); } });
  assert.equal(result.payment_not_started, true); assert.equal(result.status, 'cancelled');
  assert.deepEqual(db.calls.map(call => call.action), ['close_unstarted']);
});

test('a database gate closing before intent obtains closure proof instead of stranding preparation', async () => {
  const db = ledger();
  const result = await preparePayment(ID, { env, now: () => NOW,
    service: async (action, args) => {
      if (action === 'create_intent') throw new PaymentError('PAYMENT_ATTEMPT_EXPIRED', { status: 409 });
      return db.service(action, args);
    }, fetchImpl: async () => { throw new Error('No gateway request may occur'); } });
  assert.equal(result.payment_not_started, true);
  assert.equal(result.status, 'cancelled');
  assert.equal(db.calls.at(-1).action, 'close_unstarted');
});

test('concurrent gateway intent or lost close response never yields retry permission', async () => {
  const body = { submission_id: SUBMISSION, platform: 'META', quote_id: QUOTE, expected_cost_usd: 10, expected_amount_iqd: 14500 };
  for (const lostReply of [false, true]) {
    const db = ledger();
    const backend = { authenticate: async () => ({ id: USER }), user: async () => structuredClone(db.state),
      service: async (action, args) => {
        if (action === 'close_unstarted') {
          if (lostReply) throw new PaymentError('AD_PAYMENT_BACKEND_UNAVAILABLE', { status: 503, uncertain: true });
          Object.assign(db.state, { status: 'creating', creation_hash: 'a'.repeat(64) });
        }
        return db.service(action, args);
      } };
    const response = await invoke(createPaymentHandler({ env: { ...env, FASTPAY_AD_CREATE_ENABLED: 'false' }, db: backend, now: () => NOW }), 'prepare', body);
    assert.equal(response.body.uncertain, true);
    assert.equal(response.body.payment_not_started, undefined);
    assert.equal(response.body.attempt_id, ID);
  }
  for (const change of [{ status: 'awaiting' }, { creation_hash: 'a'.repeat(64) }, { creation_started_at: new Date(NOW).toISOString() },
    { result: { ad_id: QUOTE } }, { ad_id: QUOTE }]) {
    const response = publicPaymentAttempt({ ...attempt(), status: 'cancelled', payment_not_started: true, ...change });
    assert.equal(response.payment_not_started, undefined);
  }
});

test('status preserves owner-bound recovery when private reads fail and terminal state needs no settings', async () => {
  const backend = { authenticate: async () => ({ id: USER }), user: async () => attempt(),
    service: async () => { throw new PaymentError('AD_PAYMENT_BACKEND_UNAVAILABLE', { status: 503, uncertain: true }); } };
  let handler = createPaymentHandler({ env: {}, db: backend, now: () => NOW });
  let response = await invoke(handler, 'status', { submission_id: SUBMISSION });
  assert.equal(response.statusCode, 200); assert.equal(response.body.attempt_id, ID); assert.equal(response.body.uncertain, true);
  handler = createPaymentHandler({ env: {}, db: { ...backend, user: async () => ({ ...attempt(), status: 'funded', result: { ad_id: QUOTE } }) } });
  response = await invoke(handler, 'status', { submission_id: SUBMISSION });
  assert.equal(response.body.terminal, true); assert.equal(response.body.result.ad_id, QUOTE); assert.equal(response.body.uncertain, false);
});

test('pending reconciliation uses its frozen environment after current creation settings change', async () => {
  const db = ledger({ ...attempt(), status: 'reconcile', creation_hash: 'a'.repeat(64) });
  const origins = [];
  const result = await reconcilePayment(db.state, { service: db.service,
    env: { ...env, FASTPAY_AD_ENVIRONMENT: 'production', FASTPAY_AD_CREATE_ENABLED: 'false', FASTPAY_AD_QR_ORIGINS: 'invalid-creation-config' }, now: () => NOW,
    fetchImpl: async url => { origins.push(new URL(url).origin); return envelope(paid()); } });
  assert.equal(result.status, 'funded'); assert.deepEqual(origins, ['https://staging-qr.fast-pay.iq', 'https://staging-qr.fast-pay.iq']);
});

test('provider decline is recorded using status evidence without funding and remains recoverable for late payment', async () => {
  const db = ledger({ ...attempt(), status: 'awaiting', creation_hash: 'a'.repeat(64) });
  const calls = [];
  const declined = await reconcilePayment(db.state, { service: db.service, env, now: () => NOW,
    fetchImpl: async url => { calls.push(url); return envelope({ merchant_order_id: attempt().order_id, payment_status: 'DECLINED' }); } });
  assert.equal(declined.status, 'declined'); assert.equal(db.funded, 0); assert.equal(calls.length, 1);
  assert(calls[0].endsWith('/status')); assert(!db.calls.some(call => call.action === 'observe_verified'));
  const observation = db.calls.find(call => call.action === 'observe_status').payload;
  assert.equal(observation.verification_source, 'FASTPAY_STATUS'); assert.match(observation.response_sha256, /^[a-f0-9]{64}$/);
  assert.equal(publicPaymentAttempt(declined, { now: NOW }).terminal, false);
  const paidLater = await reconcilePayment(db.state, { service: db.service, env, now: () => NOW, fetchImpl: async () => envelope(paid()) });
  assert.equal(paidLater.status, 'funded'); assert.equal(db.funded, 1);
});

test('cancelled or declined attempts never expose a payable QR while late-payment recovery remains nonterminal', async () => {
  for (const extra of [{ cancel_requested: true }, { status: 'cancelled' }, { status: 'declined' }]) {
    const result = publicPaymentAttempt({ ...attempt(), status: 'awaiting', qr_url: 'https://staging-qr.fast-pay.iq/qr.png', qr_text: 'payable', ...extra }, { now: NOW });
    assert.equal(result.qr_url, null); assert.equal(result.qr_text, null); assert.equal(result.terminal, false);
  }
  const immediate = publicPaymentAttempt({ ...attempt(), status: 'awaiting', qr_text: 'payable' }, { now: NOW, cancelled: true });
  assert.equal(immediate.qr_text, null); assert.equal(immediate.cancel_requested, true);
});

test('transport, unknown RPC errors and malformed envelopes remain uncertain; only explicit business rejections are definite', async () => {
  const dbEnv = { PROXO_SUPABASE_URL: 'https://project.supabase.co', PROXO_SUPABASE_SERVICE_ROLE_KEY: 'mock-service-key' };
  const req = { headers: { authorization: 'Bearer mock-user-token' } };
  for (const reply of [
    () => { throw new Error('private transport detail'); },
    () => new Response('not JSON'),
    () => new Response(JSON.stringify({ code: 'P0001', message: 'private database detail' }), { status: 400 }),
    () => new Response(JSON.stringify({ code: 'TIMEOUT' }), { status: 504 }),
    () => new Response(JSON.stringify({ ok: false, code: 'BAD_GATEWAY' }), { status: 502 }),
    () => new Response(JSON.stringify({ message: 'missing result' })),
    () => new Response('null'),
  ]) {
    const db = paymentBackend({ env: dbEnv, fetchImpl: async () => reply() });
    await assert.rejects(db.user(req, 'pa_ad_payment_attempt', {}), { code: 'AD_PAYMENT_BACKEND_UNAVAILABLE', status: 503, uncertain: true });
  }
  const db = paymentBackend({ env: dbEnv, fetchImpl: async () => new Response(JSON.stringify({ ok: false, code: 'QUOTE_EXPIRED' })) });
  await assert.rejects(db.user(req, 'pa_ad_payment_attempt', {}), { code: 'QUOTE_EXPIRED', status: 409, uncertain: false });
});

const workflow = JSON.parse(readFileSync(new URL('../integrations/fastpay-ad/proxo_fastpay_ad_reconcile.json', import.meta.url), 'utf8'));
function runWorkflow(response, { origin = 'https://payments.example', input = {}, trigger = 'Scheduled poll' } = {}) {
  const seen = new Map(), calls = [], read = name => ({ item: { json: seen.get(name) } });
  let cursor = trigger, value = input;
  try {
    for (let step = 0; step < 10; step++) {
      const node = workflow.nodes.find(entry => entry.name === cursor); assert(node);
      if (node.type === 'n8n-nodes-base.code') value = Function('$json', '$vars', '$', node.parameters.jsCode)(value, { PROXO_AD_PAYMENTS_BACKEND_ORIGIN: origin }, read).json;
      if (node.type === 'n8n-nodes-base.httpRequest') {
        const url = Function('$', `return (${node.parameters.url.slice(3, -2)});`)(read);
        calls.push({ url, method: node.parameters.method, body: JSON.parse(node.parameters.jsonBody) }); value = response;
      }
      seen.set(cursor, value); cursor = workflow.connections[cursor]?.main[0]?.[0]?.node;
      if (!cursor) return { result: value, calls };
    }
    throw new Error('Unexpected workflow cycle');
  } catch (error) { return { error: error.message, calls }; }
}

test('private inactive reconciliation workflow has valid real nodes and cannot create QR, refund or activate', () => {
  assert.equal(workflow.active, false); assert.deepEqual(workflow.pinData, {});
  assert.equal(workflow.settings.saveDataErrorExecution, 'none'); assert.equal(workflow.settings.saveDataSuccessExecution, 'none');
  assert.equal(workflow.settings.saveManualExecutions, false); assert.equal(workflow.settings.saveExecutionProgress, false);
  const names = new Set(workflow.nodes.map(node => node.name)); assert.equal(names.size, workflow.nodes.length);
  for (const [from, connections] of Object.entries(workflow.connections)) {
    assert(names.has(from)); for (const output of connections.main) for (const edge of output) assert(names.has(edge.node));
  }
  const http = workflow.nodes.filter(node => node.type === 'n8n-nodes-base.httpRequest'); assert.equal(http.length, 1);
  assert.deepEqual(http[0].credentials, { httpHeaderAuth: { id: null, name: 'UNCONFIGURED — Proxo FastPay ad worker' } });
  assert.equal(http[0].parameters.options.redirect.redirect.followRedirects, false);
  assert.equal(http[0].parameters.options.response.response.neverError, true); assert.equal(http[0].maxTries, 3);
  assert.doesNotMatch(JSON.stringify(workflow), /storePassword|Bearer\s+[A-Za-z0-9._-]+|worker-activate|vending\/qr/);
  for (const trigger of ['Scheduled poll', 'Controlled manual test']) for (const status of ['idle', 'pending', 'reconcile', 'funded', 'compensated']) {
    const result = runWorkflow({ statusCode: 200, body: JSON.stringify({ ok: true, processed: 1, status, access_token: 'secret', customer_mobile_number: 'private' }) },
      { trigger, input: { verified: true, amount_iqd: 99999, attempt_id: ID } });
    assert.deepEqual(result.result, { ok: true, processed: 1, status });
    assert.deepEqual(result.calls, [{ url: 'https://payments.example/api/meta-ads?platform=payments&op=worker-reconcile', method: 'POST', body: {} }]);
  }
});

test('reconciliation workflow rejects bad origins and sanitizes authentication/provider/backend failures', () => {
  for (const origin of ['', null, 'http://payments.example', 'https://127.0.0.1', 'https://api.internal', 'https://user:secret@payments.example', 'https://payments.example/path']) {
    const result = runWorkflow(null, { origin }); assert.equal(result.error, 'FASTPAY_AD_BACKEND_ORIGIN_NOT_CONFIGURED'); assert.deepEqual(result.calls, []);
  }
  for (const [response, code] of [
    [{ error: 'private detail' }, 'TRANSPORT_UNAVAILABLE'],
    [{ statusCode: 401, body: 'private detail' }, 'AUTHORIZATION_FAILED'],
    [{ statusCode: 503, body: 'private detail' }, 'TEMPORARILY_UNAVAILABLE'],
    [{ statusCode: 409, body: 'private detail' }, 'REQUEST_REJECTED'],
    [{ statusCode: 200, body: 'not JSON' }, 'INVALID_RESPONSE'],
    [{ statusCode: 200, body: { ok: true, processed: 2, status: 'paid' } }, 'INVALID_RESPONSE'],
  ]) assert.equal(runWorkflow(response).error, `FASTPAY_AD_WORKER_${code}`);
});
