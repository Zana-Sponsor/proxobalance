import { API_VERSION, fail, fingerprint, numeric } from './contract.js';

const HOUR = 3600000;
const DAY = 24 * HOUR;
const PAGE_SIZE = 100;
const MAX_PAGES = 20;
const MAX_MICROS = BigInt(Number.MAX_SAFE_INTEGER);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const invalid = code => fail(code, { status: 503, retryable: true });

function instant(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return NaN;
  const day = value.slice(0, 10), calendarDay = Date.parse(`${day}T00:00:00Z`);
  if (!Number.isFinite(calendarDay) || new Date(calendarDay).toISOString().slice(0, 10) !== day) return NaN;
  return Date.parse(value);
}

function localDateFormatter(timezone) {
  if (typeof timezone !== 'string' || timezone.length > 100) fail('TIKTOK_OFFLINE_REPORT_SCOPE_INVALID');
  let formatter;
  try {
    formatter = new Intl.DateTimeFormat('en-US', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' });
  } catch { fail('TIKTOK_OFFLINE_REPORT_SCOPE_INVALID'); }
  return at => {
    const parts = Object.fromEntries(formatter.formatToParts(at).map(part => [part.type, part.value]));
    return `${parts.year}-${parts.month}-${parts.day}`;
  };
}

function nextLocalDay(at, dateAt) {
  // Find the next account-local date boundary, including DST transitions.
  const current = dateAt(at);
  let low = at, high = at + 2 * DAY;
  while (high - low > 1) {
    const middle = Math.floor((low + high) / 2);
    if (dateAt(middle) === current) low = middle;
    else high = middle;
  }
  return high;
}

function reportDate(value) {
  // The v1.3 response documents a midnight timestamp, not an ISO instant.
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2} 00:00:00$/.test(value)) return null;
  const day = value.slice(0, 10), at = Date.parse(`${day}T00:00:00Z`);
  return Number.isFinite(at) && new Date(at).toISOString().slice(0, 10) === day ? day : null;
}

function micros(value) {
  if (!['string', 'number'].includes(typeof value) || !/^\d{1,16}(?:\.\d{1,6})?$/.test(String(value))) invalid('TIKTOK_OFFLINE_REPORT_SPEND_INVALID');
  const [whole, fraction = ''] = String(value).split('.');
  const amount = BigInt(whole) * 1000000n + BigInt(fraction.padEnd(6, '0'));
  if (amount > MAX_MICROS) invalid('TIKTOK_OFFLINE_REPORT_SPEND_INVALID');
  return amount;
}

const decimal = value => `${value / 1000000n}.${String(value % 1000000n).padStart(6, '0')}`.replace(/\.?0+$/, '');

/**
 * Collect provider-generated offline reporting evidence; this is NOT a
 * settlement verifier. The documented ~16h latency is not a publication SLA.
 * No response field currently proves complete financial settlement, so this
 * function has no path that authorizes a refund, including for a zero report.
 *
 * api is the authenticated v1.3 client: (path, params, 'GET') => response.data.
 * job must be the persisted worker job, never a user-supplied request body.
 * The hash detects evidence changes; it is not a provider signature.
 */
export async function collectOfflineSpendCandidate(api, job, { now = Date.now() } = {}) {
  const advertiserId = job?.evidence?.identity?.advertiser_id;
  const adgroupId = job?.provider_ids?.adgroup;
  const timezone = job?.evidence?.advertiser_timezone;
  const start = instant(job?.start_at), completed = instant(job?.completed_at), eligible = instant(job?.refund_eligible_at);
  if (API_VERSION !== 'v1.3' || typeof api !== 'function' || !Number.isSafeInteger(now) || !Number.isFinite(new Date(now).getTime()) ||
      !numeric(advertiserId) || job?.account?.advertiser_id !== advertiserId || !numeric(adgroupId) ||
      ![start, completed, eligible].every(Number.isFinite) || start > completed || completed > now || eligible < completed + 2 * HOUR) {
    fail('TIKTOK_OFFLINE_REPORT_SCOPE_INVALID');
  }
  const dateAt = localDateFormatter(timezone);
  const startDate = dateAt(start), endDate = dateAt(completed);
  const dateCount = (Date.parse(`${endDate}T00:00:00Z`) - Date.parse(`${startDate}T00:00:00Z`)) / DAY + 1;
  if (!Number.isInteger(dateCount) || dateCount < 1 || dateCount > 30) fail('TIKTOK_OFFLINE_REPORT_SCOPE_INVALID');

  // Collection scheduling only: wait two hours plus the typical offline delay,
  // and until sixteen hours after the last delivery date has closed. This does
  // not convert the provider's typical latency into a finality guarantee.
  const earliest = Math.max(completed + 18 * HOUR, nextLocalDay(completed, dateAt) + 16 * HOUR, eligible);
  if (now < earliest) fail('TIKTOK_OFFLINE_REPORT_NOT_DUE', { status: 409, retryable: true });

  const advertiserResult = await api('advertiser/info/', {
    advertiser_ids: [advertiserId], fields: ['advertiser_id', 'currency', 'display_timezone'],
  }, 'GET');
  const advertiser = advertiserResult?.list;
  if (!Array.isArray(advertiser) || advertiser.length !== 1 || advertiser[0]?.advertiser_id !== advertiserId ||
      advertiser[0].currency !== 'USD' || advertiser[0].display_timezone !== timezone) {
    invalid('TIKTOK_OFFLINE_REPORT_ADVERTISER_MISMATCH');
  }

  const query = {
    advertiser_id: advertiserId, report_type: 'BASIC', data_level: 'AUCTION_ADGROUP',
    dimensions: ['adgroup_id', 'ad_type', 'stat_time_day'], metrics: ['spend'], query_lifetime: false,
    start_date: startDate, end_date: endDate,
    filtering: [
      { field_name: 'adgroup_ids', filter_type: 'IN', filter_value: JSON.stringify([adgroupId]) },
      { field_name: 'adgroup_status', filter_type: 'IN', filter_value: JSON.stringify(['STATUS_ALL']) },
    ], page_size: PAGE_SIZE,
  };
  const records = [], pages = [], seen = new Set(), reportedDates = new Set();
  let totalMicros = 0n, totalPages, totalNumber;
  for (let page = 1; page <= MAX_PAGES; page++) {
    const result = await api('report/integrated/get/', { ...query, page }, 'GET');
    if (!object(result) || !Array.isArray(result.list) || !object(result.page_info)) invalid('TIKTOK_OFFLINE_REPORT_PAGINATION_INVALID');
    const info = result.page_info;
    if (![info.page, info.page_size, info.total_page, info.total_number].every(Number.isSafeInteger) ||
        info.page !== page || info.page_size !== PAGE_SIZE || info.total_page < 1 || info.total_page > MAX_PAGES ||
        info.total_number < 1 || info.total_number > MAX_PAGES * PAGE_SIZE ||
        info.total_page !== Math.ceil(info.total_number / PAGE_SIZE) ||
        page > info.total_page || result.list.length !== Math.min(PAGE_SIZE, info.total_number - (page - 1) * PAGE_SIZE) ||
        totalPages !== undefined && (totalPages !== info.total_page || totalNumber !== info.total_number)) {
      invalid(result.list.length === 0 ? 'TIKTOK_OFFLINE_REPORT_EMPTY' : 'TIKTOK_OFFLINE_REPORT_PAGINATION_INVALID');
    }
    totalPages = info.total_page; totalNumber = info.total_number;
    pages.push({ page, page_size: info.page_size, total_page: info.total_page, total_number: info.total_number });
    for (const row of result.list) {
      const dimensions = row?.dimensions, metrics = row?.metrics;
      if (!object(dimensions) || Object.keys(dimensions).sort().join(',') !== 'ad_type,adgroup_id,stat_time_day' ||
          dimensions.adgroup_id !== adgroupId || typeof dimensions.ad_type !== 'string' ||
          !dimensions.ad_type.trim() || dimensions.ad_type.length > 100 || /[\x00-\x1f\x7f]/.test(dimensions.ad_type) ||
          !object(metrics)) invalid('TIKTOK_OFFLINE_REPORT_DIMENSIONS_INVALID');
      const day = reportDate(dimensions.stat_time_day);
      if (!day || day < startDate || day > endDate || day > dateAt(now)) invalid('TIKTOK_OFFLINE_REPORT_DATE_INVALID');
      const key = JSON.stringify([dimensions.adgroup_id, dimensions.ad_type, day]);
      if (seen.has(key)) invalid('TIKTOK_OFFLINE_REPORT_DUPLICATE_ROW');
      seen.add(key); reportedDates.add(day);
      totalMicros += micros(metrics.spend);
      if (totalMicros > MAX_MICROS) invalid('TIKTOK_OFFLINE_REPORT_SPEND_INVALID');
      // Retain only requested provider dimensions and the actual spend value.
      // Unknown fields, tokens and response text never enter stored evidence.
      records.push({ dimensions: { adgroup_id: dimensions.adgroup_id, ad_type: dimensions.ad_type, stat_time_day: dimensions.stat_time_day }, metrics: { spend: metrics.spend } });
    }
    if (page === totalPages) break;
  }
  if (!records.length || records.length !== totalNumber || pages.length !== totalPages) invalid('TIKTOK_OFFLINE_REPORT_PAGINATION_INVALID');
  const unreportedDates = [];
  for (let day = Date.parse(`${startDate}T00:00:00Z`), i = 0; i < dateCount; i++, day += DAY) {
    const date = new Date(day).toISOString().slice(0, 10);
    if (!reportedDates.has(date)) unreportedDates.push(date);
  }
  const candidate = {
    schema_version: 1, source: 'TIKTOK_OFFLINE_REPORT_CANDIDATE', api_version: 'v1.3',
    advertiser_id: advertiserId, adgroup_id: adgroupId, currency: advertiser[0].currency,
    scope: { start_date: startDate, end_date: endDate, timezone }, query,
    captured_at: new Date(now).toISOString(), provider_published_at: null,
    earliest_candidate_at: new Date(earliest).toISOString(), latency_elapsed: true,
    pagination_complete: true, completeness_verified: false, settlement_verified: false, refund_authorized: false,
    finality_blocker: 'PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE',
    spend_usd: decimal(totalMicros), unreported_dates: unreportedDates, records, pages,
  };
  return { ...candidate, evidence_hash: fingerprint(candidate) };
}
