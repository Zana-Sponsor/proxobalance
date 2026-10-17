import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const adminId = '11111111-1111-4111-8111-111111111111';
const userId = '22222222-2222-4222-8222-222222222222';
const orderId = '33333333-3333-4333-8333-333333333333';
const requestKey = '44444444-4444-4444-8444-444444444444';
const caseId = '55555555-5555-4555-8555-555555555555';
const legacyReference = 'fixture-payout-proof-001';
const validPayload = {
  order_id: orderId,
  amount_iqd: 150,
  request_key: requestKey,
  expected_refunded_iqd: 0,
  reason: 'The recipient received 150 IQD less than the agreed payout.',
  confirmed_shortfall: true
};
const savedCase = {
  id: caseId, order_id: orderId, user_id: userId, amount_iqd: 150,
  expected_iqd: 9800, admin_id: adminId, refunded_before_iqd: 0, refunded_after_iqd: 150,
  balance_before_iqd: 1000, balance_after_iqd: 1150,
  reason: validPayload.reason, created_at: '2026-10-17T17:00:00Z'
};

function application(options = {}) {
  const calls = [];
  const profile = {
    id: adminId, is_admin: true, is_banned: false, role: 'admin',
    staff_permissions: ['view', 'refunds'], ...options.profile
  };
  const order = {
    id: orderId, user_id: userId, order_code: 'P123456789AB', amount: 10000,
    total: 9800, fee: 200, status: 'پەسەندکرا',
    from_method: 'FastPay', to_method: 'FIB', receipt_url: 'https://example.invalid/receipt.jpg',
    balance_refunded_at: null, shortfall_refunded_iqd: 0, ...options.order
  };
  const db = {
    auth: { getUser: async token => {
      calls.push({ auth: token });
      return options.authError
        ? { data: null, error: { message: 'Expired session' } }
        : { data: { user: { id: adminId, user_metadata: { is_admin: true } } }, error: null };
    } },
    rpc: async (name, args) => {
      calls.push({ rpc: name, args: JSON.parse(JSON.stringify(args)) });
      if (name === 'ex_admin_balance_reconcile') return { data: { unbalanced_journals: 0 }, error: null };
      return options.rpcResult || { data: savedCase, error: null };
    },
    from(table) {
      const query = { table, filters: [] };
      const resolve = single => {
        calls.push({ read: { ...query, filters: [...query.filters] } });
        if (options.readErrorTable === table) return { data: null, error: { message: 'Fixture read failure' } };
        if (table === 'ex_profiles') {
          return { data: single && query.filters.some(f => f[1] === 'id' && f[2] === adminId)
            ? profile : single ? { id: userId, full_name: 'Fixture Customer' }
              : [{ id: userId, full_name: 'Fixture Customer' }, { id: adminId, full_name: 'Fixture Admin' }], error: null };
        }
        if (table === 'ex_orders') return { data: options.orderMissing ? single ? null : [] : single ? order : [order], error: null };
        if (table === 'ex_customer_balances') {
          const balances = options.balances || [{ user_id: userId, available_iqd: 1000, held_iqd: 50 }];
          return { data: single ? balances[0] || null : balances, error: null };
        }
        if (table === 'ex_refund_cases') return { data: single ? options.fullRefund || null : options.fullRefund ? [options.fullRefund] : [], error: null };
        if (table === 'ex_order_shortfall_refunds') return { data: single ? options.shortfalls?.[0] || null : options.shortfalls || [], error: null };
        if (table === 'ex_balance_config') return { data: { payouts_enabled: false }, error: null };
        return { data: single ? null : [], error: null };
      };
      const q = {
        select(columns) { query.columns = columns; return q; },
        eq(column, value) { query.filters.push(['eq', column, value]); return q; },
        in(column, value) { query.filters.push(['in', column, Array.from(value)]); return q; },
        is(column, value) { query.filters.push(['is', column, value]); return q; },
        or(value) { query.or = value; return q; },
        order(column, value) { query.order = [column, value]; return q; },
        limit(value) { query.limit = value; return q; },
        insert(value) { calls.push({ write: table, value }); return q; },
        update(value) { calls.push({ write: table, value }); return q; },
        single: async () => resolve(true),
        maybeSingle: async () => resolve(true),
        then(yes, no) { return Promise.resolve(resolve(false)).then(yes, no); }
      };
      return q;
    }
  };
  const source = readFileSync(new URL('../api/admin.js', import.meta.url), 'utf8')
    .replace("import { createClient } from '@supabase/supabase-js';", 'const createClient=globalThis.createClient;')
    .replace('export default async function handler', 'async function handler')
    .replace('export function assertStaffAction', 'function assertStaffAction');
  const context = vm.createContext({
    createClient: () => db,
    process: { env: { SUPABASE_SERVICE_ROLE_KEY: 'fixture-only-service-key' } },
    console: { error() {} }, URL, Date
  });
  vm.runInContext(source + '\nglobalThis.handler=handler;', context);
  return { calls, profile, async request(action = 'balance_credit_shortfall', payload = validPayload, authorized = true) {
    let status, data;
    const headers = {};
    const res = {
      status(value) { status = value; return res; },
      setHeader(name, value) { headers[name] = value; return res; },
      send(value) { data = JSON.parse(value); return res; }
    };
    await context.handler({ method: 'POST', headers: authorized ? { authorization: 'Bearer fixture-token' } : {},
      body: { action, payload } }, res);
    return { status, data, headers };
  } };
}

test('a 150 IQD shortfall uses the atomic RPC and the authenticated admin identity', async () => {
  const app = application();
  const result = await app.request('balance_credit_shortfall', {
    ...validPayload, admin_id: userId, p_admin_id: userId, user_id: adminId,
    available_iqd: 999999999, expected_payout_iqd: 999999999
  });
  assert.equal(result.status, 200);
  assert.equal(result.headers['Cache-Control'], 'no-store');
  assert.deepEqual(result.data.data, savedCase);
  const call = app.calls.find(c => c.rpc);
  assert.equal(call.rpc, 'ex_admin_credit_shortfall');
  assert.deepEqual(call.args, {
    p_order_id: orderId, p_admin_id: adminId, p_amount_iqd: 150,
    p_request_key: requestKey, p_expected_refunded_iqd: 0, p_reason: validPayload.reason,
    p_verification_reference: 'shortfall:' + requestKey, p_confirmed_shortfall: true
  });
  assert.equal(app.calls.filter(c => c.write).length, 0, 'The route must not separately change balance or audit rows');
});

test('replaying a submission forwards the same key and returns the persisted case', async () => {
  const app = application();
  const first = await app.request();
  const retry = await app.request();
  assert.equal(first.status, 200);
  assert.deepEqual(retry.data, first.data);
  assert.deepEqual(app.calls.filter(c => c.rpc).map(c => c.args.p_request_key), [requestKey, requestKey]);
  assert.deepEqual(app.calls.filter(c => c.rpc).map(c => c.args.p_verification_reference),
    ['shortfall:' + requestKey, 'shortfall:' + requestKey]);
  assert.equal(app.calls.filter(c => c.write).length, 0);
});

test('omitted, undefined and null shortfall references produce the same retry payload', async () => {
  const app = application();
  for (const payload of [validPayload, { ...validPayload, verification_reference: undefined },
    { ...validPayload, verification_reference: null }]) {
    const result = await app.request('balance_credit_shortfall', payload);
    assert.equal(result.status, 200);
    assert.deepEqual(result.data.data, savedCase);
  }
  const rpcCalls = app.calls.filter(c => c.rpc);
  assert.equal(rpcCalls.length, 3);
  for (const call of rpcCalls) {
    assert.deepEqual(call.args, rpcCalls[0].args);
    assert.equal(call.args.p_verification_reference, 'shortfall:' + requestKey);
  }
  assert.equal(app.calls.filter(c => c.write).length, 0);
});

test('UUID case changes preserve the generated reference and canonical replay key', async () => {
  const app = application();
  const canonicalKey = 'abcdef12-abcd-4abc-8def-abcdef123456';
  for (const request_key of [canonicalKey.toUpperCase(), canonicalKey]) {
    const result = await app.request('balance_credit_shortfall', { ...validPayload, request_key });
    assert.equal(result.status, 200);
  }
  const rpcCalls = app.calls.filter(c => c.rpc);
  assert.equal(rpcCalls.length, 2);
  assert.deepEqual(rpcCalls[0].args, rpcCalls[1].args);
  assert.equal(rpcCalls[0].args.p_request_key, canonicalKey);
  assert.equal(rpcCalls[0].args.p_verification_reference, 'shortfall:' + canonicalKey);
});

test('legacy manual references keep their existing value and persisted record on replay', async () => {
  const legacyCase = { ...savedCase, request_key: requestKey, verification_reference: legacyReference };
  const app = application({ rpcResult: { data: legacyCase, error: null } });
  for (const verification_reference of ['  ' + legacyReference + '  ', legacyReference]) {
    const result = await app.request('balance_credit_shortfall', { ...validPayload, verification_reference });
    assert.equal(result.status, 200);
    assert.deepEqual(result.data.data, legacyCase);
  }
  const rpcCalls = app.calls.filter(c => c.rpc);
  assert.equal(rpcCalls.length, 2);
  assert.deepEqual(rpcCalls[0].args, rpcCalls[1].args);
  assert.equal(rpcCalls[0].args.p_verification_reference, legacyReference);
  assert.equal(app.calls.filter(c => c.write).length, 0);
});

test('a one-row RPC array returns the persisted case directly on the first request and replay', async () => {
  const app = application({ rpcResult: { data: [savedCase], error: null } });
  const first = await app.request();
  const retry = await app.request();
  assert.equal(first.status, 200);
  assert.equal(retry.status, 200);
  assert.deepEqual(first.data.data, savedCase);
  assert.deepEqual(retry.data, first.data);
  assert.deepEqual(app.calls.filter(c => c.rpc).map(c => c.args.p_request_key), [requestKey, requestKey]);
  assert.equal(app.calls.filter(c => c.write).length, 0);
});

test('database replay conflicts and exhausted order caps are rejected without a second write', async () => {
  for (const message of ['IDEMPOTENCY_CONFLICT', 'SHORTFALL_EXCEEDS_REMAINING', 'SHORTFALL_STATE_CHANGED']) {
    const app = application({ rpcResult: { data: null, error: { code: '23514', message } } });
    const result = await app.request();
    assert.equal(result.status, 409);
    assert.equal(result.data.ok, false);
    if (message === 'SHORTFALL_STATE_CHANGED') assert.equal(result.data.code, 'shortfall_stale');
    assert.equal(app.calls.filter(c => c.rpc).length, 1);
    assert.equal(app.calls.filter(c => c.write).length, 0);
  }
});

test('missing, multiple or malformed RPC results remain retryable without a false success', async () => {
  for (const data of [null, undefined, false, 150, 'invalid', {}, { id: 150 }, [],
    [savedCase, savedCase], [null], [undefined], [false], [150], ['invalid'], [{}],
    [{ id: 150 }], [[savedCase]]]) {
    const app = application({ rpcResult: { data, error: null } });
    const result = await app.request();
    assert.equal(result.status, 500, JSON.stringify(data));
    assert.equal(result.data.code, 'shortfall_result_missing');
    assert.match(result.data.error, /retry with the same submission/);
    assert.equal(app.calls.filter(c => c.rpc).length, 1);
    assert.equal(app.calls.filter(c => c.write).length, 0);
  }
});

test('invalid IQD amounts are rejected before any refund RPC', async () => {
  for (const amount_iqd of [undefined, null, false, '150', '', 0, -150, 150.5, 1000000001, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    const app = application();
    const result = await app.request('balance_credit_shortfall', { ...validPayload, amount_iqd });
    assert.equal(result.status, 400, String(amount_iqd));
    assert.equal(result.data.code, 'invalid_amount');
    assert.equal(app.calls.filter(c => c.rpc || c.write).length, 0);
  }
});

test('valid UUIDs, explicit shortfall confirmation and a detailed reason are required', async () => {
  const invalid = [
    { order_id: 'not-an-order' }, { order_id: null },
    { request_key: 'not-a-key' }, { request_key: undefined },
    { expected_refunded_iqd: undefined }, { expected_refunded_iqd: null },
    { expected_refunded_iqd: '0' }, { expected_refunded_iqd: -1 }, { expected_refunded_iqd: 1.5 },
    { expected_refunded_iqd: 1000000001 },
    { confirmed_shortfall: false }, { confirmed_shortfall: 'true' }, { confirmed_shortfall: undefined },
    { reason: 'too short' }, { reason: null }, { reason: 'x'.repeat(2001) }
  ];
  for (const patch of invalid) {
    const app = application();
    const result = await app.request('balance_credit_shortfall', { ...validPayload, ...patch });
    assert.equal(result.status, 400, JSON.stringify(patch));
    assert.equal(app.calls.filter(c => c.rpc || c.write).length, 0);
  }
});

test('explicit malformed optional references are rejected before the shortfall RPC', async () => {
  for (const verification_reference of ['', '   ', 'short', 'x'.repeat(161), false, 150, {}, []]) {
    const app = application();
    const result = await app.request('balance_credit_shortfall', { ...validPayload, verification_reference });
    assert.equal(result.status, 400, JSON.stringify(verification_reference));
    assert.equal(result.data.code, 'invalid_evidence');
    assert.equal(app.calls.filter(c => c.rpc || c.write).length, 0);
  }
});

test('anonymous, expired, banned, customer and staff without refund permission are blocked', async () => {
  const anonymous = application();
  assert.equal((await anonymous.request('balance_credit_shortfall', validPayload, false)).status, 401);
  assert.equal(anonymous.calls.length, 0);
  for (const [options, expected] of [
    [{ authError: true }, 401], [{ profile: { is_banned: true } }, 403],
    [{ profile: { is_admin: false } }, 403],
    [{ profile: { staff_permissions: ['view'] } }, 403],
    [{ profile: { staff_permissions: ['approve_orders'] } }, 403],
    [{ profile: { staff_permissions: ['manage_rewards'] } }, 403]
  ]) {
    const app = application(options);
    assert.equal((await app.request()).status, expected);
    assert.equal(app.calls.filter(c => c.rpc || c.write).length, 0);
  }
});

test('a permission revoked after the first credit is checked again on replay', async () => {
  const app = application();
  assert.equal((await app.request()).status, 200);
  app.profile.staff_permissions = ['view'];
  assert.equal((await app.request()).status, 403);
  assert.equal(app.calls.filter(c => c.rpc).length, 1);
});

test('a full refund cannot run after a partial shortfall credit', async () => {
  const app = application({ order: { shortfall_refunded_iqd: 150 } });
  const result = await app.request('balance_credit_refund', {
    order_id: orderId, reason: validPayload.reason,
    verification_reference: legacyReference, confirmed_received: true
  });
  assert.equal(result.status, 409);
  assert.equal(result.data.code, 'partially_refunded');
  assert.equal(app.calls.filter(c => c.rpc || c.write).length, 0);
});

test('full refunds never receive an automatically generated shortfall reference', async () => {
  const app = application({ rpcResult: { data: null, error: {
    code: '22023', message: 'VERIFICATION_REFERENCE_REQUIRED'
  } } });
  const result = await app.request('balance_credit_refund', {
    order_id: orderId, reason: validPayload.reason, request_key: requestKey, confirmed_received: true
  });
  assert.equal(result.status, 409);
  assert.equal(result.data.ok, false);
  const call = app.calls.find(c => c.rpc);
  assert.equal(call.rpc, 'ex_admin_reject_and_refund');
  assert.equal(call.args.p_verification_reference, '');
  assert.equal(app.calls.filter(c => c.rpc).length, 1);
});

test('order lookup includes net payout, remaining capacity, fresh balance and shortfall history', async () => {
  const app = application({ order: { shortfall_refunded_iqd: 150 }, shortfalls: [savedCase] });
  const result = await app.request('balance_lookup_order', { search: orderId });
  assert.equal(result.status, 200);
  assert.deepEqual(result.data.data.shortfalls, [savedCase]);
  assert.equal(result.data.data.balance.available_iqd, 1000);
  assert.equal(result.data.data.profiles[adminId].full_name, 'Fixture Admin');
  assert.deepEqual(result.data.data.shortfall_summary, {
    eligible: true, code: null, expected_iqd: 9800, refunded_iqd: 150, remaining_iqd: 9650
  });
  const balanceRead = app.calls.find(c => c.read?.table === 'ex_customer_balances').read;
  assert.ok(balanceRead.filters.some(f => f[0] === 'eq' && f[1] === 'user_id' && f[2] === userId));
});

test('order lookup marks full refunds, unapproved orders and exhausted capacity ineligible', async () => {
  for (const options of [
    { order: { balance_refunded_at: '2026-10-17T16:00:00Z' } },
    { fullRefund: { id: 'full-refund' } },
    { order: { status: 'چاوەڕوانە' } },
    { order: { to_method: 'USDT' } },
    { order: { shortfall_refunded_iqd: 9800 } }
  ]) {
    const result = await application(options).request('balance_lookup_order', { search: orderId });
    assert.equal(result.status, 200);
    assert.equal(result.data.data.shortfall_summary.eligible, false);
    assert.ok(result.data.data.shortfall_summary.code);
  }
});

test('lookup fails closed if its balance or shortfall history cannot be read', async () => {
  for (const readErrorTable of ['ex_customer_balances', 'ex_order_shortfall_refunds']) {
    const result = await application({ readErrorTable }).request('balance_lookup_order', { search: orderId });
    assert.equal(result.status, 500);
    assert.equal(result.data.ok, false);
    assert.equal(Object.hasOwn(result.data, 'data'), false);
  }
});

test('the admin dashboard returns shortfall cases and actor names', async () => {
  const app = application({ shortfalls: [savedCase] });
  const result = await app.request('balance_dashboard', {});
  assert.equal(result.status, 200);
  assert.deepEqual(result.data.data.shortfalls, [savedCase]);
  const names = app.calls.find(c => c.read?.table === 'ex_profiles' && c.read.filters.some(f => f[0] === 'in')).read;
  const ids = names.filters.find(f => f[0] === 'in')[2];
  assert.ok(ids.includes(userId));
  assert.ok(ids.includes(adminId));
  assert.equal(result.data.data.profiles[adminId].full_name, 'Fixture Admin');
  assert.equal(result.data.data.orders[orderId].order_code, 'P123456789AB');
  assert.equal(result.data.data.orders[orderId].total, 9800);
});

test('the dashboard joins full-refund order details and its verified_by actor', async () => {
  const refund = { id: caseId, order_id: orderId, user_id: userId, verified_by: adminId,
    amount_iqd: 10000, status: 'credited', refund_kind: 'admin_rejection', confirmed_payout_failed: false };
  const app = application({ fullRefund: refund });
  const result = await app.request('balance_dashboard', {});
  assert.equal(result.status, 200);
  assert.deepEqual(result.data.data.refunds, [refund]);
  assert.equal(result.data.data.orders[orderId].amount, 10000);
  assert.equal(result.data.data.orders[orderId].total, 9800);
  const profileRead = app.calls.find(c => c.read?.table === 'ex_profiles' && c.read.filters.some(f => f[0] === 'in')).read;
  assert.ok(profileRead.filters.find(f => f[0] === 'in')[2].includes(adminId));
  const orderRead = app.calls.find(c => c.read?.table === 'ex_orders').read;
  assert.deepEqual(orderRead.filters, [['in', 'id', [orderId]]]);
  assert.equal(orderRead.columns.includes('receipt_url'), false);
});

test('the dashboard fails closed when refund order details cannot be read', async () => {
  const app = application({ readErrorTable: 'ex_orders', shortfalls: [savedCase] });
  const result = await app.request('balance_dashboard', {});
  assert.equal(result.status, 500);
  assert.equal(result.data.ok, false);
  assert.equal(Object.hasOwn(result.data, 'data'), false);
});

// Exercise the customer route with its real authentication/security wrapper.
process.env.SUPABASE_SERVICE_ROLE_KEY = 'fixture-only-service-key';
process.env.TRUSTED_PROXY = 'direct';
const { default: balanceHandler } = await import('../api/balance.js');

function apiResponse(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
}

async function customerRequest(authorized = true) {
  let body;
  const res = { statusCode: 0, setHeader() {}, end(value) { body = JSON.parse(String(value)); } };
  await balanceHandler({ method: 'GET', url: '/api/balance?user_id=' + adminId,
    headers: authorized ? { authorization: 'Bearer fixture-customer-token' } : {},
    socket: { remoteAddress: '127.0.0.1' } }, res);
  return { status: res.statusCode, body };
}

test('customer balance history is scoped to the authenticated user despite a forged user_id query', async t => {
  const previous = globalThis.fetch;
  const reads = [];
  const ownCase = { id: caseId, order_id: orderId, journal_id: 'fixture-journal', amount_iqd: 150, reason: validPayload.reason,
    created_at: savedCase.created_at };
  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input));
    if (url.pathname === '/auth/v1/user') return apiResponse({ id: userId });
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return apiResponse([{ banned: false }]);
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return apiResponse(null);
    reads.push(url);
    if (['/rest/v1/ex_customer_balances', '/rest/v1/ex_balance_journal',
      '/rest/v1/ex_order_shortfall_refunds', '/rest/v1/ex_payout_requests'].includes(url.pathname)) {
      assert.equal(options.method || 'GET', 'GET');
      assert.equal(url.searchParams.get('user_id'), 'eq.' + userId);
    }
    if (url.pathname === '/rest/v1/ex_customer_balances') return apiResponse([{ available_iqd: 1150, held_iqd: 0 }]);
    if (url.pathname === '/rest/v1/ex_order_shortfall_refunds') {
      assert.ok(url.searchParams.get('select').split(',').includes('journal_id'));
      return apiResponse([ownCase]);
    }
    if (url.pathname === '/rest/v1/ex_balance_config') return apiResponse([{ payouts_enabled: false }]);
    if (['/rest/v1/ex_balance_journal', '/rest/v1/ex_payout_requests', '/rest/v1/ex_wallets'].includes(url.pathname))
      return apiResponse([]);
    throw new Error('Unexpected fixture request: ' + url.pathname);
  };
  t.after(() => { globalThis.fetch = previous; });
  const result = await customerRequest();
  assert.equal(result.status, 200);
  assert.equal(result.body.balance.available_iqd, 1150);
  assert.deepEqual(result.body.shortfalls, [ownCase]);
  assert.ok(reads.some(url => url.pathname === '/rest/v1/ex_order_shortfall_refunds'));
});

test('anonymous customers cannot read balances or shortfall history', async t => {
  const previous = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async input => {
    const url = new URL(String(input));
    calls.push(url.pathname);
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return apiResponse([{ banned: false }]);
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return apiResponse(null);
    throw new Error('Anonymous request attempted a financial read');
  };
  t.after(() => { globalThis.fetch = previous; });
  assert.equal((await customerRequest(false)).status, 401);
  assert.equal(calls.some(path => /ex_(customer_balances|order_shortfall_refunds|balance_journal)/.test(path)), false);
});
