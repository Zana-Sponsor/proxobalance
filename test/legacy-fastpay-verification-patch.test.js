import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { patchVerification } from '../integrations/legacy-fastpay/verification-patch.mjs';

const edge = node => ({ node, type: 'main', index: 0 });
function fixture() {
  const groups = {
    code: ['Compare & Decide', 'Parse Status Response', 'Parse FastPay App Status', 'Legacy IPN Binding', 'Legacy Poll Binding', 'Normalize App Payment'],
    if: ['Match & Success?', 'Already Processed?', 'Status Call OK?', 'Is PAID?', 'Is DECLINED?', 'FastPay App Paid?', 'FastPay App Declined?', 'App Payment Final?'],
    httpRequest: ['Validate Payment', 'Get Status', 'Check FastPay From App', 'Mark PAID + Credit Wallet + Notify (Supabase)',
      'Mark PAID from Poll (Supabase)', 'Mark PAID From App (Supabase)', 'Mark Declined / Expired (Supabase)',
      'Mark Declined From App (Supabase)', 'Get App Payment (Supabase)'],
    respondToWebhook: ['Ack IPN (Matched)', 'Ack IPN (Not Matched)', 'Ack IPN (Duplicate)', 'Respond App Payment Paid',
      'Respond Stored Payment Status', 'Respond App Payment Declined', 'Respond App Payment Pending'],
    noOp: ['Trigger Fulfillment (dispense / confirm)', 'Loop Orders'],
  };
  const nodes = Object.entries(groups).flatMap(([type, names]) => names.map(name => ({ name, id: 'fixture-' + name,
    type: 'n8n-nodes-base.' + type, typeVersion: 2, position: [10, 20], parameters: type === 'httpRequest'
      ? { url: 'https://fixture.example.com/rpc/unchanged', queryParameters: { parameters: [{ name: 'select', value: 'id,user_id,status,gateway_status,wallet_credited' }] } } : {},
    ...(type === 'httpRequest' ? { credentials: { httpCustomAuth: { id: 'existing-credential-reference', name: 'Existing' } } } : {}) })));
  return { name: 'Synthetic legacy verification', active: false, nodes, connections: {}, settings: { saveDataSuccessExecution: 'none' } };
}
const workflow = () => patchVerification(fixture());
const node = (w, name) => w.nodes.find(item => item.name === name);
const plain = value => JSON.parse(JSON.stringify(value));
const expression = (source, scope) => vm.runInNewContext(`(${source.slice(3, -2).trim()})`, scope);
const evaluate = (w, name, input, refs = {}) => plain(vm.runInNewContext(`(function(){${node(w, name).parameters.jsCode}})()`, {
  $input: { item: { json: input }, all: () => [{ json: input }] },
  $: key => { assert(Object.hasOwn(refs, key), 'Unexpected node dependency ' + key); return { item: { json: refs[key] } }; },
}))[0].json;
const gate = (w, name, json) => expression(node(w, name).parameters.conditions.conditions[0].leftValue, { $json: json });
const expected = { orderId: 'PX123456789', transactionId: 'transaction-001', userId: 'owner-001', amountIqd: 10000, currency: 'IQD', baseUrl: 'https://staging-qr.fast-pay.iq' };
const receipt = { merchant_order_id: expected.orderId, gw_transaction_id: 'gw-verified-001', received_amount: 10000, currency: 'IQD', status: 'success' };
const response = data => ({ statusCode: 200, body: JSON.stringify({ code: 200, errors: [], data }) });
const paid = response({ ...receipt, payment_status: 'PAID' });
const refs = { 'Legacy IPN Binding': expected, 'Legacy Poll Binding': expected, 'Normalize App Payment': expected };
const credit = { statusCode: 200, body: JSON.stringify({ ok: true, duplicate: false, status: 'approved', gateway_status: 'PAID', transaction_id: expected.transactionId, user_id: expected.userId }) };

test('verification patch is deterministic, offline and preserves existing credential references', () => {
  const a = workflow(), b = workflow();
  assert.deepEqual(a, b); assert.equal(a.active, false);
  assert.equal(new Set(a.nodes.map(item => item.name)).size, a.nodes.length);
  for (const original of fixture().nodes.filter(item => item.credentials)) assert.deepEqual(node(a, original.name).credentials, original.credentials);
  for (const name of ['Legacy Poll Validate Payment', 'Legacy App Validate Payment']) {
    const request = node(a, name);
    assert.deepEqual(request.credentials, { httpCustomAuth: { id: null, name: 'UNCONFIGURED — Proxo FastPay validation' } });
  }
  const configured = ['Validate Payment', 'Get Status', 'Check FastPay From App', 'Legacy Poll Validate Payment', 'Legacy App Validate Payment',
    'Mark PAID + Credit Wallet + Notify (Supabase)', 'Mark PAID from Poll (Supabase)', 'Mark PAID From App (Supabase)',
    'Mark Declined / Expired (Supabase)', 'Mark Declined From App (Supabase)'];
  for (const name of configured) {
    const request = node(a, name);
    assert.equal(request.retryOnFail, false); assert.equal(request.onError, 'continueRegularOutput');
    assert.equal(request.parameters.options.timeout, 15000);
    assert.equal(request.parameters.options.redirect.redirect.followRedirects, false);
    assert.deepEqual(request.parameters.options.response.response, { fullResponse: true, neverError: true, responseFormat: 'text' });
  }
  for (const [from, links] of Object.entries(a.connections)) {
    assert(node(a, from));
    for (const output of links.main) for (const next of output) assert(node(a, next.node), 'Missing node ' + next.node);
  }
  assert.throws(() => patchVerification(a), /Already patched/);
});

test('IPN settlement fields come only from bound validation and never from callback input', () => {
  const w = workflow();
  const forged = { merchant_order_id: expected.orderId, gw_transaction_id: 'attacker', received_amount: 1, currency: 'USD' };
  const result = evaluate(w, 'Compare & Decide', forged, { ...refs, 'Validate Payment': response(receipt) });
  assert.equal(result.match, true); assert.equal(result.gwTransactionId, receipt.gw_transaction_id);
  assert.equal(result.receivedAmount, 10000); assert.equal(result.currency, 'IQD');
  const body = expression(node(w, 'Mark PAID + Credit Wallet + Notify (Supabase)').parameters.jsonBody,
    { $json: result, $: key => ({ item: { json: refs[key] } }) });
  assert.equal(body.p_gw_transaction_id, receipt.gw_transaction_id); assert.equal(body.p_received_amount, 10000);
  assert.equal(JSON.stringify(body).includes('attacker'), false);
  for (const invalid of [{ ...response(receipt), statusCode: 500 }, response({ ...receipt, merchant_order_id: 'PXother0000' }),
    { statusCode: 200, body: '{"code":200,"errors":[] "data":{}}' }]) {
    const result = evaluate(w, 'Compare & Decide', forged, { ...refs, 'Validate Payment': invalid });
    assert.equal(result.match, false); assert.equal(gate(w, 'Match & Success?', result), false);
  }
  assert.deepEqual(w.connections['Match & Success?'].main[1], [edge('Ack IPN (Not Matched)')]);
  for (const name of ['Ack IPN (Matched)', 'Ack IPN (Not Matched)', 'Ack IPN (Duplicate)']) {
    assert.deepEqual(plain(expression(node(w, name).parameters.responseBody, {})), { received: true });
  }
});

test('poll and app paid paths require exact status followed by matching independent validation', () => {
  const w = workflow();
  for (const [key, parse, paidIf, expectedNode, creditNode] of [
    ['Poll', 'Parse Status Response', 'Is PAID?', 'Legacy Poll Binding', 'Mark PAID from Poll (Supabase)'],
    ['App', 'Parse FastPay App Status', 'FastPay App Paid?', 'Normalize App Payment', 'Mark PAID From App (Supabase)'],
  ]) {
    const observed = evaluate(w, parse, paid, refs);
    assert.equal(gate(w, paidIf, observed), true);
    assert.deepEqual(w.connections[paidIf].main[0], [edge(`Legacy ${key} Validate Payment`)]);
    const valid = evaluate(w, `Legacy ${key} Validation`, response(receipt), { ...refs, [parse]: observed });
    assert.equal(valid.verified, true); assert.equal(gate(w, `Legacy ${key} Validation OK?`, valid), true);
    assert.deepEqual(w.connections[`Legacy ${key} Validation OK?`].main[0], [edge(creditNode)]);
    for (const invalid of [response({ ...receipt, gw_transaction_id: 'other-gateway-id' }), response({ ...receipt, received_amount: 1 }),
      response({ ...receipt, currency: undefined }), { statusCode: 503, body: response(receipt).body }]) {
      const failed = evaluate(w, `Legacy ${key} Validation`, invalid, { ...refs, [parse]: observed });
      assert.equal(failed.verified, false); assert.equal(gate(w, `Legacy ${key} Validation OK?`, failed), false);
    }
    for (const invalid of [{ ...paid, statusCode: 500 }, response({ ...receipt, payment_status: 'APPROVED' }),
      response({ ...receipt, merchant_order_id: 'PXother0000', payment_status: 'PAID' })]) {
      const failed = evaluate(w, parse, invalid, { [expectedNode]: expected });
      assert.equal(failed.ok, false); assert.equal(gate(w, paidIf, failed), false);
    }
  }
});

test('credit guards prevent unsuccessful RPC responses from reaching paid or fulfillment results', () => {
  const w = workflow();
  for (const key of ['IPN', 'Poll', 'App']) {
    const valid = evaluate(w, `Legacy ${key} Credit Confirmed`, credit, refs);
    assert.equal(valid.creditConfirmed, true); assert.equal(gate(w, `Legacy ${key} Credit OK?`, valid), true);
    for (const body of [{ ok: false }, { ok: true, status: 'approved', gateway_status: 'PAID' },
      { ...JSON.parse(credit.body), user_id: 'different-owner' }]) {
      const bad = evaluate(w, `Legacy ${key} Credit Confirmed`, { statusCode: 200, body }, refs);
      assert.equal(bad.creditConfirmed, false); assert.equal(gate(w, `Legacy ${key} Credit OK?`, bad), false);
    }
    const badHttp = evaluate(w, `Legacy ${key} Credit Confirmed`, { ...credit, statusCode: 500 }, refs);
    assert.equal(badHttp.creditConfirmed, false);
  }
  assert.deepEqual(w.connections['Legacy IPN Credit OK?'].main[1], [edge('Ack IPN (Not Matched)')]);
  assert.deepEqual(w.connections['Legacy App Credit OK?'].main[1], [edge('Legacy App Payment Unavailable')]);
  const unavailable = node(w, 'Legacy App Payment Unavailable');
  assert.equal(unavailable.parameters.options.responseCode, 503);
  assert.deepEqual(plain(expression(unavailable.parameters.responseBody, {})), { success: false, paid: false, terminal: false, code: 'FASTPAY_RECONCILIATION_UNAVAILABLE' });
});

test('declines require an authenticated exact observation and never assert terminal payment finality', () => {
  const w = workflow();
  for (const name of ['Is DECLINED?', 'FastPay App Declined?']) {
    assert.equal(gate(w, name, { ok: true, paymentStatus: 'DECLINED' }), true);
    for (const bad of [{ ok: false, paymentStatus: 'DECLINED' }, { ok: true, paymentStatus: 'FAILED' }, { ok: true, paymentStatus: 'EXPIRED' }]) assert.equal(gate(w, name, bad), false);
  }
  const result = evaluate(w, 'Legacy App Decline Confirmed', { statusCode: 200, body: { ok: true, transaction_id: expected.transactionId, gateway_status: 'EXPIRED' } }, refs);
  assert.equal(result.ok, true);
  const response = plain(expression(node(w, 'Respond App Payment Declined').parameters.responseBody, { $json: result }));
  assert.equal(response.paid, false); assert.equal(response.terminal, false); assert.equal(Object.hasOwn(response, 'status'), false);
  assert.equal(evaluate(w, 'Legacy App Decline Confirmed', { statusCode: 200, body: { ok: false } }, refs).ok, false);
});

test('expired, declined and inconsistent stored receipts remain eligible for reconciliation', () => {
  const w = workflow();
  for (const gateway_status of ['EXPIRED', 'DECLINED', 'FAILED', 'FRAUD_SUSPECT', 'REFUND_FAILED']) {
    assert.equal(gate(w, 'App Payment Final?', { tx: { status: 'rejected', gateway_status, wallet_credited: false } }), false);
  }
  assert.equal(gate(w, 'App Payment Final?', { tx: { status: 'approved', gateway_status: 'PAID', wallet_credited: false } }), false);
  assert.equal(gate(w, 'App Payment Final?', { tx: { status: 'approved', gateway_status: 'PAID', wallet_credited: true } }), true);
  const journalBinding = { ...expected, tx: { transaction_id: expected.transactionId, status: 'approved', gateway_status: 'PAID', wallet_credited: true } };
  const stored = plain(expression(node(w, 'Respond Stored Payment Status').parameters.responseBody, { $json: journalBinding }));
  assert.equal(stored.transactionId, expected.transactionId); assert.equal(stored.paid, true);
  assert.equal(gate(w, 'App Payment Final?', { tx: { status: 'refunded', gateway_status: 'REFUNDED', wallet_debited: true } }), true);
  assert.equal(gate(w, 'App Payment Final?', { tx: { status: 'refunded', gateway_status: 'REFUNDED', wallet_debited: false } }), false);
  const changed = fixture(); node(changed, 'Get App Payment (Supabase)').parameters = { method: 'POST', url: 'https://fixture.example.com/rpc/journal_read' };
  assert.doesNotThrow(() => patchVerification(changed));
});
