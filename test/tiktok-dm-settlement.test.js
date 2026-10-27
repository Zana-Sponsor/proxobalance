import test from 'node:test';
import assert from 'node:assert/strict';
import { collectOfflineSpendCandidate } from '../api/_lib/tiktok/settlement.js';
import { fingerprint } from '../api/_lib/tiktok/contract.js';

const now = Date.parse('2026-10-25T14:00:00Z');
const job = () => ({
  account: { advertiser_id: '111', capabilities: {} },
  evidence: { identity: { advertiser_id: '111' }, advertiser_timezone: 'Asia/Baghdad' },
  provider_ids: { adgroup: '222' },
  start_at: '2026-10-22T22:00:00Z', completed_at: '2026-10-24T10:00:00Z',
  refund_eligible_at: '2026-10-24T12:00:00Z',
});
const row = (spend = '0.1', day = '2026-10-23', adType = 'Non-Search') => ({
  dimensions: { adgroup_id: '222', ad_type: adType, stat_time_day: `${day} 00:00:00` }, metrics: { spend },
});
function fixture(rows = [row()], { calls = [], alterReport, advertiser = { advertiser_id: '111', currency: 'USD', display_timezone: 'Asia/Baghdad' } } = {}) {
  return async (path, params, method) => {
    calls.push({ path, params: structuredClone(params), method });
    assert.equal(method, 'GET');
    if (path === 'advertiser/info/') return { list: [advertiser] };
    assert.equal(path, 'report/integrated/get/');
    const result = {
      list: structuredClone(rows.slice((params.page - 1) * params.page_size, params.page * params.page_size)),
      page_info: { page: params.page, page_size: params.page_size, total_number: rows.length, total_page: Math.ceil(rows.length / params.page_size) },
    };
    return alterReport ? alterReport(result, params) : result;
  };
}

test('collects exact account-local scope, every ad type and decimal spend while retaining safe audit evidence', async () => {
  const calls = [];
  const first = row('0.100001');
  first.metrics.private_token = 'must-not-persist'; first.private = 'must-not-persist';
  const candidate = await collectOfflineSpendCandidate(fixture([first, row('0.2', '2026-10-23', 'Search'), row(1, '2026-10-24')], { calls }), job(), { now });
  assert.equal(candidate.spend_usd, '1.300001');
  assert.deepEqual(candidate.scope, { start_date: '2026-10-23', end_date: '2026-10-24', timezone: 'Asia/Baghdad' });
  assert.deepEqual(candidate.unreported_dates, []);
  assert.equal(candidate.earliest_candidate_at, '2026-10-25T13:00:00.000Z');
  assert.equal(candidate.provider_published_at, null);
  assert.equal(candidate.captured_at, new Date(now).toISOString());
  assert.equal(candidate.api_version, 'v1.3');
  assert.equal(candidate.pagination_complete, true);
  assert.equal(candidate.completeness_verified, false);
  assert.equal(candidate.settlement_verified, false);
  assert.equal(candidate.refund_authorized, false);
  assert(!JSON.stringify(candidate).includes('must-not-persist'));
  const { evidence_hash, ...evidence } = candidate;
  assert.equal(evidence_hash, fingerprint(evidence));
  assert.notEqual(evidence_hash, fingerprint({ ...evidence, spend_usd: '0' }));
  const query = calls.find(call => call.path === 'report/integrated/get/').params;
  assert.deepEqual(query.dimensions, ['adgroup_id', 'ad_type', 'stat_time_day']);
  assert.deepEqual(query.metrics, ['spend']);
  assert.equal(query.query_lifetime, false);
  assert.deepEqual(query.filtering, [
    { field_name: 'adgroup_ids', filter_type: 'IN', filter_value: '["222"]' },
    { field_name: 'adgroup_status', filter_type: 'IN', filter_value: '["STATUS_ALL"]' },
  ]);
  assert.equal(query.advertiser_id, '111');
  assert.equal(query.data_level, 'AUCTION_ADGROUP');
});

test('fetches every page and rejects truncated, changing, missing or inconsistent pagination', async () => {
  const rows = Array.from({ length: 101 }, (_, index) => row('0.01', '2026-10-23', `ProviderType${index}`));
  const calls = [];
  const result = await collectOfflineSpendCandidate(fixture(rows, { calls }), job(), { now });
  assert.equal(result.spend_usd, '1.01');
  assert.equal(result.records.length, 101);
  assert.deepEqual(result.pages.map(page => page.page), [1, 2]);
  assert.deepEqual(calls.filter(call => call.path === 'report/integrated/get/').map(call => call.params.page), [1, 2]);
  const badReports = [
    result => ({ ...result, page_info: undefined }),
    result => ({ ...result, page_info: { ...result.page_info, page: 2 } }),
    result => ({ ...result, page_info: { ...result.page_info, total_page: 1 } }),
    result => ({ ...result, page_info: { ...result.page_info, total_page: 21, total_number: 2001 } }),
    result => ({ ...result, list: result.list.slice(1) }),
    (result, params) => params.page === 2 ? { ...result, page_info: { ...result.page_info, total_number: 102 } } : result,
  ];
  for (const alterReport of badReports) {
    await assert.rejects(collectOfflineSpendCandidate(fixture(rows, { alterReport }), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_PAGINATION_INVALID' });
  }
  const droppedSecondPage = fixture(rows, { alterReport: (result, params) => params.page === 2 ? { ...result, list: [] } : result });
  await assert.rejects(collectOfflineSpendCandidate(droppedSecondPage, job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_EMPTY' });
});

test('will not call the provider before the conservative collection time or with untrusted scope', async () => {
  const calls = [], api = fixture([row()], { calls });
  await assert.rejects(collectOfflineSpendCandidate(api, job(), { now: Date.parse('2026-10-25T12:59:59Z') }), { code: 'TIKTOK_OFFLINE_REPORT_NOT_DUE' });
  assert.equal(calls.length, 0);
  for (const change of [
    { account: { advertiser_id: '999' } },
    { provider_ids: { adgroup: 'not-an-id' } },
    { completed_at: '2026-10-26T00:00:00Z' },
    { completed_at: null },
    { start_at: '2026-02-30T00:00:00Z' },
    { refund_eligible_at: '2026-10-24T11:59:59Z' },
    { start_at: '2026-09-01T00:00:00Z' },
    { start_at: '2026-10-24T11:00:00Z' },
    { evidence: { identity: { advertiser_id: '111' }, advertiser_timezone: 'Not/A-Timezone' } },
  ]) await assert.rejects(collectOfflineSpendCandidate(api, { ...job(), ...change }, { now }), { code: 'TIKTOK_OFFLINE_REPORT_SCOPE_INVALID' });
  assert.equal(calls.length, 0);
});

test('account-local day boundary includes DST and still preserves a full eighteen-hour minimum', async () => {
  const j = job();
  j.start_at = '2026-10-31T04:00:00Z';
  j.completed_at = '2026-11-01T05:30:00Z';
  j.refund_eligible_at = '2026-11-01T07:30:00Z';
  j.evidence.advertiser_timezone = 'America/New_York';
  const calls = [];
  const api = fixture([row('1', '2026-11-01')], { calls, advertiser: { advertiser_id: '111', currency: 'USD', display_timezone: 'America/New_York' } });
  await assert.rejects(collectOfflineSpendCandidate(api, j, { now: Date.parse('2026-11-02T20:59:59Z') }), { code: 'TIKTOK_OFFLINE_REPORT_NOT_DUE' });
  assert.equal(calls.length, 0);
  const result = await collectOfflineSpendCandidate(api, j, { now: Date.parse('2026-11-02T21:00:00Z') });
  assert.equal(result.earliest_candidate_at, '2026-11-02T21:00:00.000Z');
  assert.equal(result.scope.start_date, '2026-10-31');
  assert.equal(result.scope.end_date, '2026-11-01');
  assert.equal(result.refund_authorized, false);
});

test('live advertiser mismatch blocks reports and never assumes USD or a configured timezone', async () => {
  for (const change of [{ currency: 'IQD' }, { advertiser_id: '999' }, { display_timezone: 'UTC' }]) {
    const calls = [];
    const advertiser = { advertiser_id: '111', currency: 'USD', display_timezone: 'Asia/Baghdad', ...change };
    await assert.rejects(collectOfflineSpendCandidate(fixture([row()], { calls, advertiser }), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_ADVERTISER_MISMATCH' });
    assert.deepEqual(calls.map(call => call.path), ['advertiser/info/']);
  }
});

test('rejects foreign IDs, extra/missing dimensions, duplicate rows and out-of-scope or malformed day values', async () => {
  for (const dimensions of [
    { ...row().dimensions, adgroup_id: '999' },
    { ...row().dimensions, advertiser_id: '999' },
    { adgroup_id: '222', stat_time_day: '2026-10-23 00:00:00' },
    { ...row().dimensions, ad_type: '' },
  ]) await assert.rejects(collectOfflineSpendCandidate(fixture([{ dimensions, metrics: { spend: '1' } }]), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_DIMENSIONS_INVALID' });
  for (const day of ['2026-10-22 00:00:00', '2026-10-26 00:00:00', '2026-02-30 00:00:00', '2026-10-23', '2026-10-23 01:00:00']) {
    const record = row(); record.dimensions.stat_time_day = day;
    await assert.rejects(collectOfflineSpendCandidate(fixture([record]), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_DATE_INVALID' });
  }
  await assert.rejects(collectOfflineSpendCandidate(fixture([row(), row()]), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_DUPLICATE_ROW' });
});

test('rejects absent, negative, non-finite, rounded, malformed or overflowing spend', async () => {
  for (const spend of [undefined, null, true, {}, '-0.01', '-0', '1e3', ' 1.00', '1.0000001', 'NaN', NaN, Infinity, '9999999999999999']) {
    const record = row(); record.metrics.spend = spend;
    await assert.rejects(collectOfflineSpendCandidate(fixture([record]), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_SPEND_INVALID' });
  }
  await assert.rejects(collectOfflineSpendCandidate(fixture([row('9007199254.740991'), row('0.000001', '2026-10-24')]), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_SPEND_INVALID' });
});

test('empty reports never become zero; explicit zero and missing dates remain nonfinal even with fake attestation or stable reads', async () => {
  await assert.rejects(collectOfflineSpendCandidate(fixture([]), job(), { now }), { code: 'TIKTOK_OFFLINE_REPORT_EMPTY' });
  const j = job();
  j.account.capabilities.settled_reports = [{ verified: true, source: 'PROVIDER_SETTLEMENT_EXPORT', final_spend_usd: 0 }];
  j.account.capabilities.completeness_verified = true;
  const api = fixture([row('0')], { alterReport: result => ({ ...result, settled: true, published_at: '2099-01-01T00:00:00Z' }) });
  const first = await collectOfflineSpendCandidate(api, j, { now });
  const second = await collectOfflineSpendCandidate(api, j, { now: now + 60 * 60000 });
  for (const candidate of [first, second]) {
    assert.equal(candidate.spend_usd, '0');
    assert.deepEqual(candidate.unreported_dates, ['2026-10-24']);
    assert.equal(candidate.completeness_verified, false);
    assert.equal(candidate.settlement_verified, false);
    assert.equal(candidate.refund_authorized, false);
    assert.equal(candidate.provider_published_at, null);
    assert.equal(candidate.finality_blocker, 'PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE');
  }
});

test('provider failure aborts collection instead of accepting a partial total', async () => {
  const rows = Array.from({ length: 101 }, (_, index) => row('1', '2026-10-23', `ProviderType${index}`));
  const api = fixture(rows, { alterReport: (result, params) => {
    if (params.page === 2) throw new Error('provider unavailable');
    return result;
  } });
  await assert.rejects(collectOfflineSpendCandidate(api, job(), { now }), /provider unavailable/);
});
