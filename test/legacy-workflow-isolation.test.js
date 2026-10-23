import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { FASTPAY_ROUTES, GUARD_ASSERTION, prepareFastPayPatch, prepareBudgetPatch, applyReviewedPatch } from '../integrations/legacy-isolation/prepare-patches.mjs';

const edge = node => ({ node, type: 'main', index: 0 });
function fastpayFixture() {
  const nodes = new Map(), connections = {};
  for (const route of FASTPAY_ROUTES) {
    for (const name of [route.source, route.target, route.orderNode]) nodes.set(name, { id: `fixture-${name}`, name, type: 'n8n-nodes-base.code', typeVersion: 2, parameters: {}, position: [0, 0], credentials: { httpCustomAuth: { id: 'live-id-must-not-export', name: 'live-name-must-not-export' } } });
    connections[route.source] = { main: Array.from({ length: route.output + 1 }, () => []) };
    connections[route.source].main[route.output] = [edge(route.target)];
  }
  return { name: 'Synthetic legacy FastPay', active: true, nodes: [...nodes.values()], connections, meta: { secret: 'must-not-export' } };
}
function budgetFixture() {
  return { name: 'Synthetic legacy budget', active: true, nodes: [
    { id: 'read', name: 'Get Active Ads', type: 'n8n-nodes-base.supabase', parameters: { operation: 'getAll', tableId: 'pa_ads', filterType: 'string', filterString: 'or=(status.eq.active,status.eq.completed)' } },
    ...['Update Spend', 'Update Spend Only', 'Mark Completed'].map(name => ({ id: name, name, type: 'n8n-nodes-base.supabase', parameters: { operation: 'update', tableId: 'pa_ads', matchType: 'allFilters', filters: { conditions: [{ keyName: 'id', condition: 'eq', keyValue: '={{ $json.id }}' }] }, fieldsUi: { fieldValues: [{ fieldId: 'unchanged', fieldValue: 'preserved' }] } } })),
  ], connections: {} };
}
const execute = (code, json, additional = {}) => vm.runInNewContext(`(function () { ${code} })()`, { $input: { item: { json } }, ...additional });
const expression = (value, scope) => vm.runInNewContext(`(${value.slice(3, -2).trim()})`, scope);

test('all five routes use explicit server permission and preserve original nodes/activation', () => {
  const original = fastpayFixture(), patch = prepareFastPayPatch(original), updated = applyReviewedPatch(original, patch);
  assert.equal(updated.active, true);
  assert.deepEqual(updated.nodes.slice(0, original.nodes.length), original.nodes);
  assert.equal(updated.nodes.length - original.nodes.length, 20);
  for (const route of FASTPAY_ROUTES) {
    const stem = `Legacy ${route.key}`;
    assert.deepEqual(updated.connections[route.source].main[route.output], [edge(`${stem} Order Guard`)]);
    assert.deepEqual(updated.connections[`${stem} Order Guard`].main[0], [edge(`${stem} Guard Valid`)]);
    assert.deepEqual(updated.connections[`${stem} Guard Valid`].main[0], [edge(`${stem} Allowed?`)]);
    assert.deepEqual(updated.connections[`${stem} Allowed?`].main[1], [edge(route.loop ? 'Loop Orders' : `${stem} Immutable Order`)]);
    const guard = updated.nodes.find(node => node.name === `${stem} Order Guard`);
    assert.equal(guard.retryOnFail, false); assert.equal(guard.onError, 'stopWorkflow');
    assert.equal(guard.parameters.options.response.response.neverError, false);
    assert.deepEqual(guard.credentials, { httpCustomAuth: { name: 'Proxo Supabase service role' } });
    assert.equal(guard.parameters.method, 'POST');
    assert.equal(expression(guard.parameters.url, { $env: { PROXO_SUPABASE_URL: 'https://fixture.supabase.co/' } }), 'https://fixture.supabase.co/rest/v1/rpc/pa_legacy_fastpay_guard');
  }
  const exported = JSON.stringify(patch);
  for (const secret of ['live-id-must-not-export', 'live-name-must-not-export', 'must-not-export']) assert(!exported.includes(secret));
});

test('guard rejects malformed/unavailable responses instead of treating errors as legacy approval', () => {
  for (const bad of [null, {}, { ok: false }, { ok: true, legacy_allowed: 'true' },
    { ok: true, legacy_allowed: true, immutable_ad_payment: true, code: 'LEGACY_ALLOWED' },
    { ok: true, legacy_allowed: true, immutable_ad_payment: false, code: 'UNKNOWN' }]) assert.throws(() => execute(GUARD_ASSERTION, bad), /LEGACY_FASTPAY_GUARD_UNAVAILABLE/);
  for (const allowed of [true, false]) {
    const input = { ok: true, legacy_allowed: allowed, immutable_ad_payment: !allowed, code: allowed ? 'LEGACY_ALLOWED' : 'AD_PAYMENT_IMMUTABLE' };
    assert.equal(execute(GUARD_ASSERTION, input)[0].json, input);
  }
});

test('lookup forwards exact order identity, rejects canonicalization bypasses, and restores the same poll item', () => {
  const original = fastpayFixture(), patched = applyReviewedPatch(original, prepareFastPayPatch(original));
  for (const route of FASTPAY_ROUTES) {
    const lookup = patched.nodes.find(node => node.name === `Legacy ${route.key} Order Guard`);
    const item = { [route.orderField]: 'AP' + 'A'.repeat(28), id: '11111111-1111-4111-8111-111111111111' };
    const $ = name => { assert.equal(name, route.orderNode); return { item: { json: item } }; };
    const body = expression(lookup.parameters.jsonBody, { $ });
    assert.equal(body.p_order_id, item[route.orderField]);
    assert.equal(body.p_transaction_id, route.loop ? item.id : null);
    for (const bad of [undefined, null, 123, ' AP' + 'A'.repeat(28), 'AP' + 'A'.repeat(28) + ' ']) {
      item[route.orderField] = bad;
      assert.throws(() => expression(lookup.parameters.jsonBody, { $ }), /LEGACY_FASTPAY_ORDER_INVALID/);
    }
  }
  const restore = patched.nodes.find(node => node.name === 'Legacy Poll Restore Item');
  const expected = { fastpay_order_id: 'PX12345678', gateway_amount: 10000 };
  assert.equal(execute(restore.parameters.jsCode, { legacy_allowed: true }, { $: name => { assert.equal(name, 'Loop Orders'); return { item: { json: expected } }; } })[0].json, expected);
});

test('immutable IPN acknowledges only ignoring, refund/create/status deny and polling continues', () => {
  const original = fastpayFixture(), updated = applyReviewedPatch(original, prepareFastPayPatch(original));
  const node = name => updated.nodes.find(node => node.name === name);
  assert.equal(node('Legacy IPN Immutable Order').parameters.options.responseCode, 200);
  const ipn = expression(node('Legacy IPN Immutable Order').parameters.responseBody, {});
  assert.equal(ipn.ignored, true); assert.equal(ipn.code, 'AD_PAYMENT_IMMUTABLE'); assert(!('paid' in ipn));
  for (const route of ['Checkout', 'App Status', 'Refund']) assert.equal(node(`Legacy ${route} Immutable Order`).parameters.options.responseCode, 409);
  assert.deepEqual(updated.connections['Legacy Poll Allowed?'].main[1], [edge('Loop Orders')]);
});

test('budget selection and every write exclude automatic fulfillment without changing amounts or metrics', () => {
  const original = budgetFixture(), patch = prepareBudgetPatch(original), updated = applyReviewedPatch(original, patch);
  assert.equal(updated.nodes[0].parameters.filterString, 'or=(status.eq.active,status.eq.completed)&fulfillment_kind=neq.tiktok_conversation_auto');
  for (let i = 1; i < updated.nodes.length; i++) {
    assert.deepEqual(updated.nodes[i].parameters.fieldsUi, original.nodes[i].parameters.fieldsUi);
    assert.deepEqual(updated.nodes[i].parameters.filters.conditions[0], original.nodes[i].parameters.filters.conditions[0]);
    assert.deepEqual(updated.nodes[i].parameters.filters.conditions[1], { keyName: 'fulfillment_kind', condition: 'neq', keyValue: 'tiktok_conversation_auto' });
  }
  assert.equal(updated.active, true);
});

test('drift, duplicate patching, changed source and unexpected links require new review', () => {
  const original = fastpayFixture(), patch = prepareFastPayPatch(original);
  assert.throws(() => applyReviewedPatch({ ...original, active: false }, patch), /snapshot changed/);
  assert.throws(() => prepareFastPayPatch(applyReviewedPatch(original, patch)), /Unexpected reviewed route/);
  const drifted = fastpayFixture(); drifted.connections['App User Valid?'].main[0].push(edge('FastPay Config2'));
  assert.throws(() => prepareFastPayPatch(drifted), /Unexpected reviewed route/);
  const budget = budgetFixture(); budget.nodes[0].parameters.filterString = 'status=eq.active';
  assert.throws(() => prepareBudgetPatch(budget), /Selection drifted/);
});
