/** Builds a manual-only n8n harness. Its generated workflow has no network or
 * credential nodes and never contacts a provider, database or app backend. */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { legacyCheckoutContract } from './checkout-contract.mjs';
import { legacyProviderContract } from './contracts.mjs';

const embeddedNodes = [
  'FastPay Config', 'Legacy Dispatch Verified', 'Legacy Restore Dispatch',
  'Parse QR Response', 'Legacy Saved Checkout', 'Normalize App Payment',
  'Compare & Decide', 'Parse Status Response', 'Parse FastPay App Status',
  'Legacy Poll Validation', 'Legacy App Validation',
  'Legacy IPN Credit Confirmed', 'Legacy Poll Credit Confirmed', 'Legacy App Credit Confirmed',
  'Legacy App Decline Confirmed', 'Legacy Poll Binding',
];
const embeddedExpressions = [
  ['dispatchGate', 'Legacy Dispatch Allowed?', 'condition'],
  ['createBody', 'Generate QR', 'jsonBody'],
  ['declineResponse', 'Respond App Payment Declined', 'responseBody'],
  ['storedFinal', 'App Payment Final?', 'condition'],
];

// This function is embedded verbatim. Only standard ECMAScript is used: no
// require/import, eval, Function, VM, fetch, filesystem or n8n credentials.
export function runRuntimeCases(nodes, expressions, checkout, provider, provenance) {
  const checks = [];
  const check = (name, fn) => {
    try { fn(); checks.push(name); }
    catch (error) { throw new Error('FASTPAY_RUNTIME_CHECK_FAILED: ' + name + ': ' + error.message); }
  };
  const equal = (actual, expected) => {
    if (actual !== expected) throw new Error('Expected ' + JSON.stringify(expected) + ', got ' + JSON.stringify(actual));
  };
  const rejects = (fn, expectedCode) => {
    let rejected = false;
    try { fn(); } catch (error) {
      rejected = true;
      if (expectedCode && error.message !== expectedCode) throw error;
    }
    if (!rejected) throw new Error('Invalid synthetic input was accepted');
  };
  const owner = '11111111-1111-4111-8111-111111111111';
  const transactionId = '22222222-2222-4222-8222-222222222222';
  const vars = {
    PROXO_LEGACY_FASTPAY_ENVIRONMENT: 'production',
    PROXO_LEGACY_FASTPAY_SUPABASE_URL: 'https://abcdefghijklmnopqrst.supabase.co',
    PROXO_LEGACY_FASTPAY_PUBLIC_ORIGIN: 'https://email.proxopages.com',
    PROXO_LEGACY_FASTPAY_MERCHANT_REFERENCE: 'synthetic-runtime-store',
  };
  const input = { orderId: 'PXRUNTIME0001', userId: owner, billAmount: 10000, currency: 'IQD',
    purpose: 'wallet_deposit', note: 'Synthetic runtime fixture; never dispatched', expiresIn: 10 };
  const response = body => ({ statusCode: 200, body: JSON.stringify(body) });
  const providerResponse = data => response({ code: 200, errors: [], data });
  const run = (name, value, refs = {}, selectedVars = vars) => {
    const lookup = key => {
      if (!Object.prototype.hasOwnProperty.call(refs, key)) throw new Error('Unexpected node reference: ' + key);
      return { item: { json: refs[key] } };
    };
    const output = nodes[name]({ item: { json: value }, all: () => [{ json: value }] }, lookup, selectedVars);
    if (!Array.isArray(output) || output.length !== 1 || !output[0].json) throw new Error('Unexpected Code node item shape');
    return output[0].json;
  };
  const config = run('FastPay Config', {}, { 'Resolve Checkout Amount': input });
  const receipt = { ok: true, create_authorized: true, must_reconcile: false, transaction_id: transactionId,
    user_id: owner, order_id: input.orderId, amount_iqd: 10000, currency: 'IQD', wallet_credited: false,
    status: 'pending', gateway_status: 'CREATED', journaled: true, environment: 'sandbox',
    merchant_reference: 'synthetic-runtime-store', request_hash: 'a'.repeat(64), qr_url: null, qr_text: null,
    expires_at: '2099-01-01T00:00:00.000Z' };
  const dispatch = changes => run('Legacy Dispatch Verified', response({ ...receipt, ...changes }), { 'FastPay Config': config });
  const expected = { ...config, orderId: input.orderId, userId: owner, transactionId, amountIqd: 10000, currency: 'IQD' };
  const paidReceipt = { merchant_order_id: input.orderId, gw_transaction_id: 'synthetic-gw-001',
    received_amount: '10000.000', currency: 'IQD', status: 'success' };
  const paidStatus = changes => providerResponse({ ...paidReceipt, payment_status: 'PAID', ...changes });
  const credit = { ok: true, duplicate: false, transaction_id: transactionId, user_id: owner,
    status: 'approved', gateway_status: 'PAID', amount_iqd: 10000, currency: 'IQD', wallet_credited: true };

  check('sandbox environment overrides a production variable', () => equal(config.environment, 'sandbox'));
  check('main Supabase project is rejected before any request', () => rejects(() => run('FastPay Config', {},
    { 'Resolve Checkout Amount': input }, { ...vars, PROXO_LEGACY_FASTPAY_SUPABASE_URL: 'https://cojchkwssmasiejcgvbk.supabase.co' }), 'LEGACY_FASTPAY_ISOLATED_TARGET_REQUIRED'));
  check('missing merchant binding is rejected', () => rejects(() => checkout.config({ ...vars, PROXO_LEGACY_FASTPAY_MERCHANT_REFERENCE: '' }, true), 'LEGACY_FASTPAY_MERCHANT_REQUIRED'));
  check('reservation retains the exact owner, order and money', () => {
    equal(config.request.p_user_id, owner); equal(config.request.p_order_id, input.orderId);
    equal(config.request.p_payload.amount_iqd, 10000); equal(config.request.p_payload.currency, 'IQD');
  });
  check('immutable AP namespace cannot enter legacy checkout', () => rejects(() => checkout.preparePayload({ ...input, orderId: 'AP' + 'a'.repeat(28) }, config), 'LEGACY_FASTPAY_CHECKOUT_INVALID'));
  check('first authorization alone crosses the generated dispatch gate', () => {
    const values = [dispatch({}), dispatch({ create_authorized: false, must_reconcile: true })];
    equal(values.filter(value => expressions.dispatchGate(value)).length, 1);
    equal(values[1].orderId, input.orderId);
  });
  check('recovery input cannot execute the generated dispatch node', () => rejects(() =>
    run('Legacy Restore Dispatch', dispatch({ create_authorized: false, must_reconcile: true })), 'LEGACY_FASTPAY_DISPATCH_REQUIRED'));
  for (const [label, change] of [
    ['owner', { user_id: transactionId }], ['money', { amount_iqd: 20000 }],
    ['merchant', { merchant_reference: 'other-store' }], ['environment', { environment: 'production' }],
    ['journal', { journaled: false }], ['hash', { request_hash: null }],
    ['expiry', { expires_at: '2000-01-01T00:00:00.000Z' }], ['existing QR', { qr_text: 'already-created' }],
  ]) check('dispatch rejects changed ' + label, () => rejects(() => dispatch(change)));
  check('non-200 reservation cannot authorize dispatch', () => rejects(() => run('Legacy Dispatch Verified',
    { ...response(receipt), statusCode: 500 }, { 'FastPay Config': config }), 'LEGACY_FASTPAY_RPC_UNAVAILABLE'));
  const authorized = dispatch({});
  check('generated provider body uses frozen identity and sandbox callback', () => {
    const value = expressions.createBody(run('Legacy Restore Dispatch', authorized));
    equal(value.orderId, input.orderId); equal(value.billAmount, 10000);
    equal(value.callbackUrl, 'https://email.proxopages.com/webhook/proxo-fastpay-staging/ipn');
  });
  const qr = { qrUrl: 'https://staging-qr.fast-pay.iq/qr/synthetic', qrText: 'synthetic-qr-not-payable' };
  check('generated QR parser accepts the reviewed sandbox origin', () => equal(run('Parse QR Response', providerResponse(qr),
    { 'Legacy Dispatch Verified': authorized }).ok, true));
  for (const [label, value] of [
    ['production QR origin', providerResponse({ ...qr, qrUrl: 'https://qr.fast-pay.iq/qr/synthetic' })],
    ['malformed JSON', { statusCode: 200, body: '{not-json' }],
    ['HTTP failure', { ...providerResponse(qr), statusCode: 503 }],
    ['wrong order', providerResponse({ ...qr, merchant_order_id: 'PXRUNTIME9999' })],
  ]) check('generated QR parser rejects ' + label, () => equal(run('Parse QR Response', value,
    { 'Legacy Dispatch Verified': authorized }).ok, false));
  check('provider factory rejects an IPN body as validation evidence', () => rejects(() => provider.validate(paidReceipt, expected), 'FASTPAY_RESPONSE_INVALID'));
  check('generated IPN code ignores forged callback receipt fields', () => {
    const result = run('Compare & Decide', { ...paidReceipt, received_amount: 1, currency: 'USD', gw_transaction_id: 'forged' },
      { 'Legacy IPN Binding': expected, 'Validate Payment': providerResponse(paidReceipt) });
    equal(result.match, true); equal(result.receivedAmount, 10000); equal(result.currency, 'IQD');
    equal(result.gwTransactionId, 'synthetic-gw-001');
  });
  check('generated IPN code rejects non-200 independent evidence', () => equal(run('Compare & Decide', paidReceipt,
    { 'Legacy IPN Binding': expected, 'Validate Payment': { ...providerResponse(paidReceipt), statusCode: 500 } }).match, false));
  for (const [key, statusNode, bindingNode] of [['Poll', 'Parse Status Response', 'Legacy Poll Binding'], ['App', 'Parse FastPay App Status', 'Normalize App Payment']]) {
    const refs = { [bindingNode]: expected };
    const status = run(statusNode, paidStatus({}), refs);
    check(key + ' status requires the expected paid transaction', () => { equal(status.ok, true); equal(status.gwTransactionId, 'synthetic-gw-001'); });
    check(key + ' status rejects a different order', () => equal(run(statusNode, paidStatus({ merchant_order_id: 'PXRUNTIME9999' }), refs).ok, false));
    check(key + ' status rejects HTTP failure', () => equal(run(statusNode, { ...paidStatus({}), statusCode: 500 }, refs).ok, false));
    const validationRefs = { ...refs, [statusNode]: status };
    check(key + ' validation accepts matching independent evidence', () => equal(run('Legacy ' + key + ' Validation', providerResponse(paidReceipt), validationRefs).verified, true));
    for (const [label, change] of [['transaction', { gw_transaction_id: 'different-receipt' }], ['amount', { received_amount: 9999 }], ['currency', { currency: undefined }]])
      check(key + ' validation rejects changed ' + label, () => equal(run('Legacy ' + key + ' Validation', providerResponse({ ...paidReceipt, ...change }), validationRefs).verified, false));
  }
  for (const [key, bindingNode] of [['IPN', 'Legacy IPN Binding'], ['Poll', 'Legacy Poll Binding'], ['App', 'Normalize App Payment']]) {
    const refs = { [bindingNode]: expected };
    check(key + ' credit requires an approved matching ledger result', () => equal(run('Legacy ' + key + ' Credit Confirmed', response(credit), refs).creditConfirmed, true));
    check(key + ' duplicate credit preserves the original receipt', () => {
      const result = run('Legacy ' + key + ' Credit Confirmed', response({ ...credit, duplicate: true }), refs);
      equal(result.creditConfirmed, true); equal(result.duplicate, true); equal(result.transactionId, transactionId);
    });
    check(key + ' credit rejects a different owner', () => equal(run('Legacy ' + key + ' Credit Confirmed', response({ ...credit, user_id: transactionId }), refs).creditConfirmed, false));
    check(key + ' credit rejects HTTP failure even with success JSON', () => equal(run('Legacy ' + key + ' Credit Confirmed', { ...response(credit), statusCode: 500 }, refs).creditConfirmed, false));
  }
  check('a verified decline response remains nonterminal', () => {
    const value = run('Legacy App Decline Confirmed', response({ ok: true, transaction_id: transactionId, gateway_status: 'DECLINED' }), { 'Normalize App Payment': expected });
    const publicResult = expressions.declineResponse(value);
    equal(publicResult.paid, false); equal(publicResult.terminal, false);
  });
  check('expired and declined stored receipts remain eligible for reconciliation', () => {
    for (const gateway_status of ['EXPIRED', 'DECLINED']) equal(expressions.storedFinal({ tx: { status: 'rejected', gateway_status, wallet_credited: false } }), false);
    equal(expressions.storedFinal({ tx: { status: 'approved', gateway_status: 'PAID', wallet_credited: true } }), true);
  });
  check('historical unjournaled rows cannot acquire current merchant credentials', () => rejects(() => run('Normalize App Payment',
    response({ ...receipt, create_authorized: false, must_reconcile: true, journaled: false, environment: null, merchant_reference: null, request_hash: null }),
    { 'Verify Status User': { id: owner }, 'Validate Status Request': { orderId: input.orderId } }), 'LEGACY_FASTPAY_BINDING_REQUIRED'));
  check('failed poll binding returns recovery rather than provider authority', () => equal(run('Legacy Poll Binding', { error: 'synthetic timeout' },
    { 'Loop Orders': { user_id: owner, fastpay_order_id: input.orderId, id: transactionId, gateway_amount: 10000 } }).found, false));
  check('saved QR keeps the original receipt and immutable request hash', () => {
    const value = run('Legacy Saved Checkout', response({ ...receipt, create_authorized: false, must_reconcile: true, qr_url: qr.qrUrl, qr_text: qr.qrText }),
      { 'Legacy Dispatch Verified': authorized });
    equal(value.transactionId, transactionId); equal(value.requestHash, 'a'.repeat(64)); equal(value.paid, false);
  });
  return [{ json: { result: 'PASS', purpose: 'Synthetic n8n Code and expression runtime acceptance',
    passedChecks: checks.length, checks, syntheticOnly: true, providerRequests: 0, ledgerWrites: 0,
    livePaymentAccepted: false, provenance } }];
}

export function buildRuntimeHarness(source) {
  assert.equal(source.active, false, 'The harness must derive from the inactive sandbox export');
  const find = name => {
    const values = source.nodes.filter(node => node.name === name);
    assert.equal(values.length, 1, 'Expected one source node ' + name);
    return values[0];
  };
  const wrappers = embeddedNodes.map(name => {
    const node = find(name);
    assert.equal(node.type, 'n8n-nodes-base.code');
    assert.equal(typeof node.parameters.jsCode, 'string');
    return JSON.stringify(name) + ': function($input, $, $vars) {\n' + node.parameters.jsCode + '\n}';
  });
  const expressions = embeddedExpressions.map(([name, nodeName, field]) => {
    const node = find(nodeName);
    const expression = field === 'condition' ? node.parameters.conditions.conditions[0].leftValue : node.parameters[field];
    assert(expression.startsWith('={{') && expression.endsWith('}}'), 'Expected n8n expression');
    return JSON.stringify(name) + ': function($json) { return (' + expression.slice(3, -2).trim() + '); }';
  });
  const provenance = { source: 'proxo_fastpay_durable_sandbox.json',
    sourceSha256: createHash('sha256').update(JSON.stringify(source)).digest('hex'),
    codeNodes: embeddedNodes, expressionNodes: embeddedExpressions.map(([, name]) => name) };
  const jsCode = '// Synthetic fixtures only. Original Code node snippets and module factories are embedded unchanged.\n' +
    'const nodes = {\n' + wrappers.join(',\n') + '\n};\n' +
    'const expressions = {\n' + expressions.join(',\n') + '\n};\n' +
    'const checkout = (' + legacyCheckoutContract.toString() + ')();\n' +
    'const provider = (' + legacyProviderContract.toString() + ')();\n' +
    'return (' + runRuntimeCases.toString() + ')(nodes, expressions, checkout, provider, ' + JSON.stringify(provenance) + ');\n';
  return {
    name: 'Proxo FastPay runtime contract checks — MANUAL ONLY', active: false,
    settings: { executionOrder: 'v1', saveDataSuccessExecution: 'none', saveDataErrorExecution: 'none',
      saveManualExecutions: false, saveExecutionProgress: false },
    nodes: [
      { id: 'fastpay-runtime-manual', name: 'Run Synthetic Checks', type: 'n8n-nodes-base.manualTrigger', typeVersion: 1, position: [0, 0], parameters: {} },
      { id: 'fastpay-runtime-assertions', name: 'FastPay Runtime Contract Checks', type: 'n8n-nodes-base.code', typeVersion: 2,
        position: [260, 0], parameters: { mode: 'runOnceForAllItems', jsCode } },
    ],
    connections: { 'Run Synthetic Checks': { main: [[{ node: 'FastPay Runtime Contract Checks', type: 'main', index: 0 }]] } },
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  assert.equal(process.argv.length, 2, 'This generator accepts no arguments or live target');
  const source = JSON.parse(await fs.readFile(new URL('./proxo_fastpay_durable_sandbox.json', import.meta.url), 'utf8'));
  const harness = buildRuntimeHarness(source);
  await fs.writeFile(new URL('./proxo_fastpay_runtime_harness.json', import.meta.url), JSON.stringify(harness, null, 2) + '\n');
  console.log('Prepared manual-only FastPay runtime harness; zero external request nodes.');
}
