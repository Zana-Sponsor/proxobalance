import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { Buffer } from 'node:buffer';
import vm from 'node:vm';
import { payoutPlan } from '../api/_lib/payout-rounding.js';

const NOW = Date.parse('2026-10-17T12:00:00.000Z');
const SNAPSHOT = new Date(NOW).toISOString();
const id = n => '00000000-0000-4000-8000-' + String(n).padStart(12, '0');
const adminId = id(1), userId = id(2), fullActorId = id(3), partialActorId = id(4);

function fullRefund(n = 1, created_at = new Date(NOW - 60000 - Math.floor(n / 3) * 1000).toISOString()) {
  return { id: id(1000 + n), order_id: id(10000 + n), user_id: userId, amount_iqd: 10000,
    status: 'credited', refund_kind: 'admin_rejection', bank_verification_reference: 'receipt-' + n,
    failure_reason: 'The order was rejected and its principal returned.', verified_by: fullActorId,
    confirmed_funds_received: true, confirmed_payout_failed: false, journal_id: id(20000 + n), created_at };
}

function shortfall(n = 1, created_at = new Date(NOW - 60000 - Math.floor(n / 3) * 1000).toISOString()) {
  return { id: id(30000 + n), order_id: id(40000 + n), order_code: 'P' + String(n).padStart(11, '0'),
    user_id: userId, customer_phone: 'fixture-phone', admin_id: partialActorId, amount_iqd: 150,
    expected_iqd: 9800, refunded_before_iqd: 50, refunded_after_iqd: 200,
    balance_before_iqd: 1000, balance_after_iqd: 1150, journal_id: id(50000 + n), request_key: id(60000 + n),
    reason: 'The recipient received 150 IQD less than the agreed payout.',
    verification_reference: 'shortfall:' + id(60000 + n), refund_source: 'manual_shortfall', created_at };
}

function application(options = {}) {
  const calls = [];
  const profile = { id: adminId, is_admin: true, is_banned: false, role: 'admin',
    staff_permissions: ['refunds'], ...options.profile };
  const refunds = options.refunds || [fullRefund()];
  const shortfalls = options.shortfalls || [shortfall()];
  const tables = {
    ex_refund_cases: refunds,
    ex_order_shortfall_refunds: shortfalls,
    ex_orders: [...refunds, ...shortfalls].map((row, index) => ({ id: row.order_id,
      order_code: 'P' + String(index).padStart(11, '0'), user_id: userId, amount: 10000, total: 9800,
      from_method: 'FastPay', to_method: 'FIB', status: 'fixture-status', balance_refunded_at: null,
      receipt_url: 'must-not-be-exported', admin_note: 'must-not-be-exported' })),
    ex_profiles: [
      { id: userId, full_name: 'Fixture Customer', username: 'customer', email: 'must-not-be-exported' },
      { id: fullActorId, full_name: 'Full Refund Admin', username: 'full-admin' },
      { id: partialActorId, full_name: 'Shortfall Admin', username: 'shortfall-admin' },
      { id: id(99), full_name: 'Unrelated Profile' }
    ]
  };
  const db = {
    auth: { getUser: async token => {
      calls.push({ auth: token });
      return options.authError ? { data: null, error: { message: 'Expired' } }
        : { data: { user: { id: adminId, user_metadata: { role: 'super_admin' } } }, error: null };
    } },
    from(table) {
      const query = { table, filters: [], ordering: [] };
      function resolve() {
        calls.push({ read: { ...query, filters: [...query.filters], ordering: [...query.ordering] } });
        if (query.single && table === 'ex_profiles') return { data: profile, error: null };
        if (options.errorTable === table) return { data: null, error: { code: 'XX000', message: 'Fixture read failure' } };
        if (options.errorRelationId && query.filters.some(f => f[0] === 'in' && f[2].includes(options.errorRelationId)))
          return { data: null, error: { code: 'XX000', message: 'Fixture relation batch failure' } };
        if (options.invalidTable === table) return { data: null, error: null };
        let data = [...(tables[table] || [])];
        for (const [op, field, value] of query.filters) {
          data = data.filter(row => op === 'eq' ? row[field] === value
            : op === 'in' ? value.includes(row[field])
              : op === 'gte' ? Date.parse(row[field]) >= Date.parse(value)
                : op === 'lte' ? Date.parse(row[field]) <= Date.parse(value)
                  : Date.parse(row[field]) < Date.parse(value));
        }
        data.sort((left, right) => {
          for (const [field, ascending] of query.ordering) {
            const compared = String(left[field]).localeCompare(String(right[field]));
            if (compared) return ascending ? compared : -compared;
          }
          return 0;
        });
        if (query.range) data = data.slice(query.range[0], query.range[1] + 1);
        if (query.columns) data = data.map(row => Object.fromEntries(query.columns.split(',')
          .filter(field => Object.hasOwn(row, field)).map(field => [field, row[field]])));
        return { data, error: null };
      }
      const q = {
        select(columns) { query.columns = columns; return q; },
        eq(field, value) { query.filters.push(['eq', field, value]); return q; },
        in(field, value) { query.filters.push(['in', field, Array.from(value)]); return q; },
        gte(field, value) { query.filters.push(['gte', field, value]); return q; },
        lte(field, value) { query.filters.push(['lte', field, value]); return q; },
        lt(field, value) { query.filters.push(['lt', field, value]); return q; },
        order(field, options) { query.ordering.push([field, options.ascending]); return q; },
        range(start, end) { query.range = [start, end]; return q; },
        single: async () => { query.single = true; return resolve(); },
        then(yes, no) { return Promise.resolve().then(resolve).then(yes, no); },
        insert() { calls.push({ write: table }); throw new Error('Report attempted an insert'); },
        update() { calls.push({ write: table }); throw new Error('Report attempted an update'); },
        delete() { calls.push({ write: table }); throw new Error('Report attempted a delete'); }
      };
      return q;
    },
    rpc(name) { calls.push({ rpc: name }); throw new Error('Report attempted an RPC'); }
  };
  class FixtureDate extends Date {
    constructor(...args) { super(...(args.length ? args : [NOW])); }
    static now() { return NOW; }
  }
  const source = readFileSync(new URL('../api/admin.js', import.meta.url), 'utf8')
    .replace("import { createClient } from '@supabase/supabase-js';", 'const createClient=globalThis.createClient;')
    .replace("import { payoutPlan } from './_lib/payout-rounding.js';", 'const payoutPlan=globalThis.payoutPlan;')
    .replace('export default async function handler', 'async function handler')
    .replace('export function assertStaffAction', 'function assertStaffAction');
  const context = vm.createContext({ createClient: () => db, payoutPlan, Date: FixtureDate, URL, Buffer,
    process: { env: { SUPABASE_SERVICE_ROLE_KEY: 'fixture-only-service-key' } }, console: { error() {} } });
  vm.runInContext(source + '\nglobalThis.handler=handler;', context);
  return { calls, profile, tables, async request(payload = {}, authorized = true) {
    let status, body;
    const headers = {};
    const res = {
      status(value) { status = value; return res; },
      setHeader(name, value) { headers[name] = value; return res; },
      send(value) { body = JSON.parse(value); return res; }
    };
    await context.handler({ method: 'POST', headers: authorized ? { authorization: 'Bearer fixture-token' } : {},
      body: { action: 'balance_refund_report', payload } }, res);
    return { status, body, headers };
  } };
}

test('refund reports expose recorded amounts and only related order and actor details', async () => {
  const app = application();
  const result = await app.request({ user_id: id(99), admin_id: id(99) });
  assert.equal(result.status, 200);
  assert.equal(result.headers['Cache-Control'], 'no-store');
  const report = result.body.data;
  assert.equal(report.snapshot, SNAPSHOT);
  assert.equal(report.page, 0);
  assert.equal(report.next_page, null);
  assert.equal(report.has_more, false);
  assert.deepEqual(report.refunds, [fullRefund()]);
  assert.deepEqual(report.shortfalls, [shortfall()]);
  assert.equal(report.refunds[0].amount_iqd, 10000);
  assert.equal(report.refunds[0].confirmed_payout_failed, false);
  assert.equal(report.orders[fullRefund().order_id].total, 9800);
  assert.equal(report.shortfalls[0].refunded_after_iqd, 200);
  assert.deepEqual(Object.keys(report.profiles).sort(), [userId, fullActorId, partialActorId].sort());
  assert.equal(report.profiles[fullActorId].full_name, 'Full Refund Admin');
  assert.equal(report.profiles[partialActorId].full_name, 'Shortfall Admin');
  assert.equal(Object.hasOwn(report.profiles[userId], 'email'), false);
  assert.equal(Object.hasOwn(report.orders[fullRefund().order_id], 'receipt_url'), false);
  assert.equal(Object.hasOwn(report.orders[fullRefund().order_id], 'admin_note'), false);
  assert.equal(app.calls.some(call => call.rpc || call.write), false);
});

test('reports preserve automatic rounding source and the matching order settlement amounts',async()=>{
  const automatic = {...shortfall(),amount_iqd:800,refunded_before_iqd:0,refunded_after_iqd:800,
    refund_source:'payout_rounding'};
  const app = application({shortfalls:[automatic]});
  const related = app.tables.ex_orders.find(order=>order.id===automatic.order_id);
  Object.assign(related,{payout_iqd:9000,payout_rounding_iqd:800,payout_settlement_id:id(80000)});
  const result = await app.request();
  assert.equal(result.status,200);
  assert.equal(result.body.data.shortfalls[0].refund_source,'payout_rounding');
  assert.equal(result.body.data.orders[automatic.order_id].payout_iqd,9000);
  assert.equal(result.body.data.orders[automatic.order_id].payout_rounding_iqd,800);
  assert.equal(result.body.data.orders[automatic.order_id].payout_settlement_id,id(80000));
});

test('pagination exports more than 150 records with deterministic ties and one shared cutoff', async () => {
  const app = application({ refunds: Array.from({ length: 251 }, (_, i) => fullRefund(i + 1)),
    shortfalls: Array.from({ length: 172 }, (_, i) => shortfall(i + 1)) });
  const refunds = [], shortfalls = [], lengths = [];
  let page = 0, snapshot;
  do {
    const result = await app.request({ page, snapshot });
    assert.equal(result.status, 200);
    const report = result.body.data;
    snapshot ||= report.snapshot;
    assert.equal(report.snapshot, snapshot);
    assert.equal(report.page, page);
    assert.equal(report.has_more, report.next_page !== null);
    lengths.push([report.refunds.length, report.shortfalls.length]);
    refunds.push(...report.refunds); shortfalls.push(...report.shortfalls);
    if (page === 0) {
      app.tables.ex_refund_cases.push(fullRefund(999, new Date(NOW + 1).toISOString()));
      app.tables.ex_order_shortfall_refunds.push(shortfall(999, new Date(NOW + 1).toISOString()));
    }
    page = report.next_page;
  } while (page !== null);
  assert.deepEqual(lengths, [[100, 100], [100, 72], [51, 0]]);
  assert.equal(new Set(refunds.map(row => row.id)).size, 251);
  assert.equal(new Set(shortfalls.map(row => row.id)).size, 172);
  const sorted = rows => [...rows].sort((a, b) => b.created_at.localeCompare(a.created_at) || b.id.localeCompare(a.id));
  assert.deepEqual(refunds, sorted(refunds));
  assert.deepEqual(shortfalls, sorted(shortfalls));
  for (const query of app.calls.filter(call => ['ex_refund_cases', 'ex_order_shortfall_refunds'].includes(call.read?.table)).map(call => call.read)) {
    assert.deepEqual(query.ordering, [['created_at', false], ['id', false]]);
    assert.ok(query.filters.some(filter => filter[0] === 'lte' && filter[1] === 'created_at' && filter[2] === SNAPSHOT));
    assert.equal(query.range[1] - query.range[0], 100, 'Fetch one lookahead row beyond the 100 returned rows');
  }
  assert.equal(app.calls.some(call => call.rpc || call.write), false);
});

test('an exact 100-row final page does not require an empty extra page', async () => {
  const result = await application({ refunds: Array.from({ length: 100 }, (_, i) => fullRefund(i + 1)), shortfalls: [] }).request();
  assert.equal(result.status, 200);
  assert.equal(result.body.data.refunds.length, 100);
  assert.equal(result.body.data.has_more, false);
  assert.equal(result.body.data.next_page, null);
});

test('varied-owner pages batch relation URLs and reject failure of any later batch', async () => {
  const options = {
    refunds: Array.from({ length: 100 }, (_, n) => ({ ...fullRefund(n + 1), user_id: id(100000 + n), verified_by: id(200000 + n) })),
    shortfalls: Array.from({ length: 100 }, (_, n) => ({ ...shortfall(n + 1), user_id: id(300000 + n), admin_id: id(400000 + n) }))
  };
  const app = application(options);
  const profileIds = [...options.refunds.flatMap(row => [row.user_id, row.verified_by]),
    ...options.shortfalls.flatMap(row => [row.user_id, row.admin_id])];
  app.tables.ex_profiles = profileIds.map(id => ({ id, full_name: 'Fixture ' + id }));
  const result = await app.request();
  assert.equal(result.status, 200);
  assert.equal(Object.keys(result.body.data.orders).length, 200);
  assert.equal(Object.keys(result.body.data.profiles).length, 400);
  const relationReads = app.calls.filter(call => call.read?.filters.some(f => f[0] === 'in')).map(call => call.read);
  assert.equal(relationReads.filter(read => read.table === 'ex_orders').length, 2);
  assert.equal(relationReads.filter(read => read.table === 'ex_profiles').length, 4);
  assert.ok(relationReads.every(read => read.filters.find(f => f[0] === 'in')[2].length <= 100));
  // Case ownership selects the profiles, even though this fixture's joined
  // orders deliberately retain a different user_id.
  assert.equal(Object.hasOwn(result.body.data.profiles, userId), false);
  options.errorRelationId = profileIds.at(-1);
  const failed = await app.request();
  assert.equal(failed.status, 500);
  assert.equal(Object.hasOwn(failed.body, 'data'), false);
});

test('date filters include the whole Baghdad calendar day and exclude uncredited full cases', async () => {
  const timestamps = ['2026-10-14T20:59:59.999Z', '2026-10-14T21:00:00.000Z',
    '2026-10-15T20:59:59.999Z', '2026-10-15T21:00:00.000Z'];
  const app = application({ refunds: [...timestamps.map((date, i) => fullRefund(i + 1, date)),
    { ...fullRefund(9, timestamps[1]), status: 'pending' }],
    shortfalls: timestamps.map((date, i) => shortfall(i + 1, date)) });
  const result = await app.request({ date_from: '2026-10-15', date_to: '2026-10-15' });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.data.refunds.map(row => row.id), [fullRefund(3).id, fullRefund(2).id]);
  assert.deepEqual(result.body.data.shortfalls.map(row => row.id), [shortfall(3).id, shortfall(2).id]);
  for (const { read } of app.calls.filter(call => ['ex_refund_cases', 'ex_order_shortfall_refunds'].includes(call.read?.table))) {
    assert.ok(read.filters.some(f => f[0] === 'gte' && f[2] === '2026-10-14T21:00:00.000Z'));
    assert.ok(read.filters.some(f => f[0] === 'lt' && f[2] === '2026-10-15T21:00:00.000Z'));
    if (read.table === 'ex_refund_cases') assert.ok(read.filters.some(f => f[0] === 'eq' && f[1] === 'status' && f[2] === 'credited'));
  }
});

test('valid leap dates and one-sided or omitted date ranges are accepted', async () => {
  for (const payload of [{ date_from: '2024-02-29' }, { date_to: '2026-10-17' },
    { date_from: null, date_to: '' }, { date_from: '2024-02-29', date_to: '2024-02-29' }]) {
    assert.equal((await application().request(payload)).status, 200);
  }
});

test('invalid dates, range, pages and snapshots fail before report reads', async () => {
  const invalid = [
    [{ date_from: '2026-02-29' }, 'invalid_report_date'], [{ date_to: '2026-04-31' }, 'invalid_report_date'],
    [{ date_from: '2026-10-15T00:00:00Z' }, 'invalid_report_date'], [{ date_to: '2026-1-01' }, 'invalid_report_date'],
    [{ date_from: 123 }, 'invalid_report_date'], [{ date_from: '0000-01-01' }, 'invalid_report_date'],
    [{ date_from: '2026-10-16', date_to: '2026-10-15' }, 'invalid_report_range'],
    ...[-1, 1.5, '1', null, Number.MAX_SAFE_INTEGER].map(page => [{ page }, 'invalid_report_page']),
    [{ page: 1 }, 'report_snapshot_required'],
    ...['invalid', '2026-02-30T12:00:00.000Z', '2026-10-17T12:00:00', '2026-10-17T12:00:00.001Z', 123]
      .map(snapshot => [{ snapshot }, 'invalid_report_snapshot'])
  ];
  for (const [payload, code] of invalid) {
    const app = application();
    const result = await app.request(payload);
    assert.equal(result.status, 400, JSON.stringify(payload));
    assert.equal(result.body.code, code);
    assert.equal(app.calls.some(call => call.read && !call.read.single), false);
    assert.equal(app.calls.some(call => call.rpc || call.write), false);
  }
});

test('empty ranges produce a complete empty report without unrelated relation reads', async () => {
  const app = application({ refunds: [], shortfalls: [] });
  const result = await app.request();
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.data, { refunds: [], shortfalls: [], orders: {}, profiles: {},
    page: 0, next_page: null, has_more: false, snapshot: SNAPSHOT });
  assert.equal(app.calls.some(call => call.read?.table === 'ex_orders'), false);
  assert.equal(app.calls.filter(call => call.read?.table === 'ex_profiles').length, 1);
});

test('report access requires fresh admin status and refunds permission', async () => {
  const anonymous = application();
  assert.equal((await anonymous.request({}, false)).status, 401);
  assert.equal(anonymous.calls.length, 0);
  for (const [options, status] of [[{ authError: true }, 401], [{ profile: { is_admin: false } }, 403],
    [{ profile: { is_banned: true } }, 403], [{ profile: { staff_permissions: ['view'] } }, 403],
    [{ profile: { staff_permissions: ['approve_orders'] } }, 403]]) {
    const app = application(options);
    assert.equal((await app.request({ role: 'super_admin', user_id: adminId })).status, status);
    assert.equal(app.calls.some(call => call.read && !call.read.single), false);
  }
  const app = application();
  assert.equal((await app.request()).status, 200);
  app.profile.staff_permissions = ['view'];
  const before = app.calls.filter(call => call.read && !call.read.single).length;
  assert.equal((await app.request({ page: 1, snapshot: SNAPSHOT })).status, 403);
  assert.equal(app.calls.filter(call => call.read && !call.read.single).length, before);
  assert.equal((await application({ profile: { role: 'super_admin', staff_permissions: [] } }).request()).status, 200);
});

test('source and relation failures return no partial report', async () => {
  for (const table of ['ex_refund_cases', 'ex_order_shortfall_refunds', 'ex_orders', 'ex_profiles']) {
    for (const options of [{ errorTable: table }, { invalidTable: table }]) {
      const app = application(options);
      const result = await app.request();
      assert.equal(result.status, 500, JSON.stringify(options));
      assert.equal(result.body.ok, false);
      assert.equal(Object.hasOwn(result.body, 'data'), false);
      assert.equal(app.calls.some(call => call.rpc || call.write), false);
    }
  }
});
