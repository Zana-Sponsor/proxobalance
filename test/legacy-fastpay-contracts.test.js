import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { legacyProviderContract } from '../integrations/legacy-fastpay/contracts.mjs';

const contract = legacyProviderContract();
const expected = { orderId: 'PX123456789', amountIqd: 10000, currency: 'IQD', baseUrl: 'https://staging-qr.fast-pay.iq' };
const receipt = { merchant_order_id: expected.orderId, gw_transaction_id: 'gw-verified-001', received_amount: '10000.000', currency: 'IQD', status: 'success' };
const response = data => ({ statusCode: 200, body: JSON.stringify({ code: 200, errors: [], data }) });
const paidStatus = changes => response({ ...receipt, payment_status: 'PAID', ...changes });
const rpcBody = { ok: true, duplicate: false, status: 'approved', gateway_status: 'PAID', transaction_id: 'transaction-001', user_id: 'owner-001' };
const creditExpected = { ...expected, transactionId: rpcBody.transaction_id, userId: rpcBody.user_id };

test('all provider methods require an exact successful full HTTP response and envelope', () => {
  for (const method of ['qr', 'status', 'validate']) {
    for (const bad of [null, {}, { statusCode: 200 }, { body: {} },
      ...[201, 204, 302, 400, 500, '200'].map(statusCode => ({ ...paidStatus(), statusCode })),
      { statusCode: 200, body: '<html>error</html>' }, { statusCode: 200, body: '{"code":200,"errors":[] "data":{}}' },
      { statusCode: 200, body: 'x'.repeat(65537) }, { statusCode: 200, body: [] },
      ...[{ code: '200', errors: [], data: receipt }, { code: 200, data: receipt }, { code: 200, errors: ['failure'], data: receipt },
        { code: 200, errors: [], data: [] }].map(body => ({ statusCode: 200, body }))]) {
      assert.throws(() => contract[method](bad, expected), /FASTPAY_RESPONSE_INVALID/);
    }
  }
});

test('status binds exact order/status and supplies no invented amount or currency', () => {
  for (const paymentStatus of ['UNPAID', 'DECLINED']) {
    assert.deepEqual(contract.status(response({ merchant_order_id: expected.orderId, payment_status: paymentStatus }), expected),
      { ok: true, orderId: expected.orderId, paymentStatus });
  }
  assert.deepEqual(contract.status(response({ merchant_order_id: expected.orderId, payment_status: 'PAID', gw_transaction_id: receipt.gw_transaction_id }), expected),
    { ok: true, orderId: expected.orderId, paymentStatus: 'PAID', gwTransactionId: receipt.gw_transaction_id });
  for (const bad of [{ merchant_order_id: 'PXother0000' }, { merchant_order_id: undefined, order_id: expected.orderId },
    { order_id: 'PXother0000' }, { payment_status: 'paid' }, { payment_status: 'APPROVED' },
    { payment_status: undefined, paymentStatus: 'PAID' }, { gw_transaction_id: null }, { gw_transaction_id: 'bad\nreference' },
    { received_amount: 10001 }, { received_amount: null }, { currency: null }, { currency: 'iqd' }]) {
    assert.throws(() => contract.status(paidStatus(bad), expected), /FASTPAY_VERIFICATION_MISMATCH/);
  }
});

test('validation uses provider fields only and binds the independent status transaction', () => {
  const provider = response({ ...receipt, customer_name: 'private', customer_mobile_number: 'private', arbitrary: 'ignored' });
  const result = contract.validate(provider, { ...expected, gwTransactionId: receipt.gw_transaction_id });
  assert.deepEqual(result, { ok: true, verified: true, orderId: expected.orderId, paymentStatus: 'PAID',
    gwTransactionId: receipt.gw_transaction_id, receivedAmount: 10000, currency: 'IQD' });
  assert.equal(Object.hasOwn(result, 'data'), false);
  assert.throws(() => contract.validate(provider, { ...expected, gwTransactionId: 'different-receipt' }), /FASTPAY_VERIFICATION_MISMATCH/);
  for (const bad of [{ merchant_order_id: 'PXother0000' }, { merchant_order_id: undefined }, { order_id: 'PXother0000' },
    { status: 'PAID' }, { status: 'approved' }, { received_amount: undefined }, { received_amount: 9999 },
    { received_amount: '1e4' }, { received_amount: ' 10000 ' }, { received_amount: true }, { received_amount: Infinity },
    { currency: undefined }, { currency: 'iqd' }, { gw_transaction_id: undefined }, { gw_transaction_id: '' }]) {
    assert.throws(() => contract.validate(response({ ...receipt, ...bad }), expected), /FASTPAY_VERIFICATION_MISMATCH/);
  }
});

test('an IPN body cannot replace a successful validation response', () => {
  const forged = { ...receipt, gw_transaction_id: 'attacker-receipt', received_amount: 1, currency: 'USD' };
  assert.throws(() => contract.validate(forged, expected), /FASTPAY_RESPONSE_INVALID/);
  const verified = contract.validate(response(receipt), expected);
  assert.equal(verified.gwTransactionId, receipt.gw_transaction_id);
  assert.equal(verified.receivedAmount, expected.amountIqd);
  assert.equal(verified.currency, 'IQD');
});

test('QR requires explicit reviewed HTTPS origins and a bounded nonempty token', () => {
  const qr = { qrUrl: expected.baseUrl + '/qr/fixture', qrText: 'opaque-provider-token' };
  assert.deepEqual(contract.qr(response(qr), expected), { ok: true, orderId: expected.orderId, ...qr });
  assert.equal(contract.qr(response({ ...qr, qrUrl: 'https://reviewed.example.com/image' }),
    { ...expected, qrOrigins: [expected.baseUrl, 'https://reviewed.example.com'] }).qrUrl, 'https://reviewed.example.com/image');
  for (const qrUrl of ['http://staging-qr.fast-pay.iq/qr', 'https://unreviewed.example.com/qr',
    'https://qr.fast-pay.iq/qr', 'https://user@staging-qr.fast-pay.iq/qr', expected.baseUrl + ':444/qr', expected.baseUrl + '/qr#fragment',
    'https://staging-qr.fast-pay.iq\\@unreviewed.example.com/qr', ' ' + qr.qrUrl]) {
    assert.throws(() => contract.qr(response({ ...qr, qrUrl }), expected), /FASTPAY_QR_INVALID/);
  }
  for (const qrText of ['', ' ', null, 'token\nmore', 'x'.repeat(4097)]) assert.throws(() => contract.qr(response({ ...qr, qrText }), expected), /FASTPAY_QR_INVALID/);
  assert.throws(() => contract.qr(response(qr), { ...expected, qrOrigins: ['https://example.test'] }), /FASTPAY_QR_INVALID/);
  assert.throws(() => contract.qr(response({ ...qr, merchant_order_id: 'PXother0000' }), expected), /FASTPAY_VERIFICATION_MISMATCH/);
});

test('credit confirmation requires the known owner, transaction and approved PAID ledger result', () => {
  for (const duplicate of [false, true]) {
    const result = contract.credited({ statusCode: 200, body: { ...rpcBody, duplicate, balance_after: 99 } }, creditExpected);
    assert.equal(result.paid, true); assert.equal(result.duplicate, duplicate); assert.equal(result.transactionId, rpcBody.transaction_id);
    assert.equal(Object.hasOwn(result, 'balance_after'), false);
  }
  for (const bad of [{ ok: false }, { status: undefined }, { status: 'pending' }, { gateway_status: undefined }, { gateway_status: 'CREATED' },
    { transaction_id: 'other' }, { user_id: 'other' }, { duplicate: 'true' }, { order_id: 'PXother0000' },
    { amount_iqd: 9999 }, { currency: null }, { wallet_credited: false }]) {
    assert.throws(() => contract.credited({ statusCode: 200, body: { ...rpcBody, ...bad } }, creditExpected), /FASTPAY_CREDIT_NOT_CONFIRMED/);
  }
  assert.throws(() => contract.credited({ statusCode: 500, body: rpcBody }, creditExpected), /FASTPAY_RESPONSE_INVALID/);
  assert.throws(() => contract.credited({ statusCode: 200, body: rpcBody }, { ...creditExpected, userId: undefined }), /FASTPAY_EXPECTED_PAYMENT_INVALID/);
});

test('all checks reject malformed expected identities and reserved immutable orders', () => {
  for (const change of [{ orderId: 'AP' + 'a'.repeat(28) }, { orderId: ' invalid ' }, { amountIqd: 0 }, { amountIqd: 1e100 },
    { amountIqd: '10000.1' }, { currency: 'USD' }, { baseUrl: 'https://arbitrary.example.com' }]) {
    for (const method of ['qr', 'status', 'validate', 'credited']) assert.throws(() =>
      contract[method](paidStatus(), { ...creditExpected, ...change }), /FASTPAY_EXPECTED_PAYMENT_INVALID/);
  }
});

test('factory is self-contained when embedded in a separate n8n-style VM', () => {
  const code = `const contract = (${legacyProviderContract.toString()})(); return contract.validate(response, expected);`;
  const result = vm.runInNewContext(`(function(){${code}})()`, { response: response(receipt), expected });
  assert.deepEqual(JSON.parse(JSON.stringify(result)), contract.validate(response(receipt), expected));
  const qrResult = vm.runInNewContext(`(${legacyProviderContract.toString()})().qr(response, expected)`,
    { response: response({ qrUrl: expected.baseUrl + '/qr/fixture', qrText: 'opaque' }), expected });
  assert.equal(qrResult.qrText, 'opaque');
});
