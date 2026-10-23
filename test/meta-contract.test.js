import test from 'node:test';
import assert from 'node:assert/strict';
import {
  API_VERSION, MetaError, destinationType, fingerprint, legacyDestinations,
  normalizeConfiguration, normalizeUrl, pricing, unavailableForecast,
} from '../api/_lib/meta/contract.js';

// Synthetic identifiers and a frozen instant; no account access or provider calls.
const NOW = Date.parse('2026-10-23T12:00:00Z');
const page = 'https://www.facebook.com/100000000000001';
const post = `${page}/posts/pfbidSyntheticOpaqueToken/`;
const draft = (overrides = {}) => ({
  schema_version: 3, platform: 'META', ad_name: '  تاقیکردنەوە  ',
  objective: 'MESSAGES', page_url: page, post_url: post,
  placements: ['facebook', 'instagram'],
  destinations: ['WHATSAPP', 'MESSENGER', 'INSTAGRAM_DIRECT'],
  currency: 'USD', budget_daily: 5, duration_days: 3, payment_method: 'WALLET',
  schedule: { mode: 'IMMEDIATE', timezone: 'Asia/Baghdad' },
  targeting: { location: 'all', gender: 'ALL', age_min: 18, age_max: 65 },
  ...overrides,
});
const normalize = value => normalizeConfiguration(value, { now: NOW });
const rejects = (value, code) => assert.throws(() => normalize(value),
  error => error instanceof MetaError && (!code || error.code === code));
const video = objective => {
  const value = draft({ objective }); delete value.destinations; return value;
};

const destinations = [
  [['MESSENGER'], 'MESSENGER'],
  [['INSTAGRAM_DIRECT'], 'INSTAGRAM_DIRECT'],
  [['WHATSAPP'], 'WHATSAPP'],
  [['MESSENGER', 'INSTAGRAM_DIRECT'], 'MESSAGING_INSTAGRAM_DIRECT_MESSENGER'],
  [['INSTAGRAM_DIRECT', 'WHATSAPP'], 'MESSAGING_INSTAGRAM_DIRECT_WHATSAPP'],
  [['WHATSAPP', 'MESSENGER'], 'MESSAGING_MESSENGER_WHATSAPP'],
  [['WHATSAPP', 'MESSENGER', 'INSTAGRAM_DIRECT'], 'MESSAGING_INSTAGRAM_DIRECT_MESSENGER_WHATSAPP'],
];
for (const [selected, native] of destinations) {
  test(`the whole destination set maps once: ${native}`, () => {
    const configuration = normalize(draft({ destinations: selected }));
    assert.equal(destinationType(configuration.destinations), native);
    assert.deepEqual(configuration.destinations, [...selected].sort());
    assert.equal(pricing(configuration).payable_minor, 1500);
    assert.equal(pricing(configuration).media_budget_minor, 1500);
  });
}

for (const placements of [['facebook'], ['instagram'], ['facebook', 'instagram']]) {
  test(`all destination subsets obey the product matrix: ${placements.join('+')}`, () => {
    for (const [selected] of destinations) {
      const permitted = (!selected.includes('MESSENGER') || placements.includes('facebook')) &&
        (!selected.includes('INSTAGRAM_DIRECT') || placements.includes('instagram'));
      if (permitted) assert.equal(normalize(draft({ placements, destinations: selected })).placements.length, placements.length);
      else rejects(draft({ placements, destinations: selected }), 'INCOMPATIBLE_DESTINATIONS');
    }
  });
}

test('only the three approved Meta objectives are accepted', () => {
  assert.equal(normalize(draft()).objective, 'MESSAGES');
  for (const objective of ['VIDEO_VIEWS', 'VIDEO_ENGAGEMENT']) {
    assert.equal(normalize(video(objective)).objective, objective);
  }
  for (const objective of ['PAGE_LIKES', 'SALES', 'INSTAGRAM_PROFILE_VISITS', 'messages', '', null]) {
    rejects(draft({ objective }), 'INVALID_OBJECTIVE');
  }
});

test('video objectives exclude inactive messaging fields, even empty ones', () => {
  for (const objective of ['VIDEO_VIEWS', 'VIDEO_ENGAGEMENT']) {
    for (const value of [[], ['WHATSAPP'], null]) rejects(draft({ objective, destinations: value }), 'UNEXPECTED_DESTINATIONS');
    rejects({ ...video(objective), destination: 'WHATSAPP' }, 'INVALID_INPUT');
    assert.equal('destinations' in normalize(video(objective)), false);
  }
});

test('new requests never silently pick between legacy singular and plural destinations', () => {
  rejects({ ...draft(), destination: 'MESSENGER' }, 'INVALID_INPUT');
  const single = draft(); delete single.destinations; single.destination = 'WHATSAPP';
  rejects(single, 'INVALID_INPUT');
});

test('empty, unknown, repeated and scalar placement/destination values are rejected', () => {
  for (const value of [[], ['facebook', 'facebook'], ['Facebook'], ['messenger'], 'facebook', null]) {
    rejects(draft({ placements: value }), 'INVALID_PLACEMENTS');
  }
  for (const value of [[], ['WHATSAPP', 'WHATSAPP'], ['SMS'], ['whatsapp'], 'WHATSAPP', null]) {
    rejects(draft({ destinations: value }), 'INVALID_DESTINATIONS');
  }
});

test('field whitelisting rejects forged authorization, accounting and resolved-asset claims', () => {
  for (const [key, value] of Object.entries({ user_id: 'another-user', ad_account_id: 'act_other',
    is_admin: true, paid: true, total_amount: 1, resolved_assets: { page_id: 'other' } })) {
    rejects({ ...draft(), [key]: value }, 'INVALID_INPUT');
  }
  rejects(draft({ targeting: { ...draft().targeting, city_key: '2420605' } }), 'INVALID_TARGETING');
  rejects(draft({ schedule: { ...draft().schedule, end_at: '2030-01-01T00:00:00Z' } }), 'INVALID_SCHEDULE');
});

test('version and platform boundaries are explicit', () => {
  for (const schema_version of [undefined, 1, 2, '3', 4]) rejects(draft({ schema_version }), 'SCHEMA_VERSION_REQUIRED');
  for (const platform of ['TIKTOK', 'facebook', undefined]) rejects(draft({ platform }), 'SCHEMA_VERSION_REQUIRED');
  for (const input of [null, [], 'META']) rejects(input, 'INVALID_INPUT');
});

test('ad names are trimmed and bounded without requiring uniqueness', () => {
  assert.equal(normalize(draft()).ad_name, 'تاقیکردنەوە');
  assert.equal(normalize(draft({ ad_name: 'a'.repeat(120) })).ad_name.length, 120);
  for (const ad_name of ['', ' \t\n ', 'a'.repeat(121), null, 12]) rejects(draft({ ad_name }), 'INVALID_NAME');
  assert.equal(fingerprint(normalize(draft())), fingerprint(normalize(draft())));
});

test('pfbid is accepted as an opaque resolver input, never fabricated into an object ID', () => {
  const raw = `${post}?mibextid=CDWPTG&utm_campaign=fixture#ignored`;
  const value = normalize(draft({ post_url: raw }));
  assert.equal(value.post_url, post.slice(0, -1));
  assert.match(value.post_url, /pfbidSyntheticOpaqueToken$/);
  assert.equal('post_id' in value, false);
  assert.equal('page_id' in value, false);
});

test('normalization removes tracking but preserves identity-bearing query parameters', () => {
  const value = normalizeUrl('https://m.facebook.com/story.php?story_fbid=456&id=123&mibextid=x&fbclid=y&utm_source=z');
  assert.equal(value, 'https://www.facebook.com/story.php?id=123&story_fbid=456');
  assert.equal(normalizeUrl('https://web.facebook.com/watch/?v=456&mibextid=x'), 'https://www.facebook.com/watch?v=456');
  assert.equal(normalizeUrl(`  ${page}/  `, 'page'), page);
});

test('URL input validation rejects credential-bearing, insecure and unrelated hosts', () => {
  for (const value of ['http://www.facebook.com/a/posts/123', 'javascript:alert(1)',
    'https://user:secret@www.facebook.com/a/posts/123', 'https://facebook.com.evil.invalid/a',
    'https://127.0.0.1/a', 'https://localhost/a', 'https://www.facebook.com:8443/a',
    'https://www.facebook.com/', 'https://www.instagram.com/', 'not a URL', 'https://www.facebook.com/a b']) {
    assert.throws(() => normalizeUrl(value), MetaError);
  }
});

test('Instagram media is supported, but profiles cannot replace a media or Facebook Page URL', () => {
  for (const kind of ['p', 'reel', 'tv']) {
    assert.equal(normalizeUrl(`https://instagram.com/${kind}/SyntheticCode/?igsh=x`), `https://www.instagram.com/${kind}/SyntheticCode`);
  }
  for (const value of ['https://instagram.com/profile', 'https://www.instagram.com/profile/']) {
    assert.throws(() => normalizeUrl(value), error => error.code === 'POST_UNRESOLVED');
    assert.throws(() => normalizeUrl(value, 'page'), error => error.code === 'PAGE_UNRESOLVED');
  }
  assert.throws(() => normalizeUrl(post, 'page'), error => error.code === 'PAGE_UNRESOLVED');
});

test('both Page and post inputs are mandatory and independent', () => {
  rejects(draft({ page_url: '' }), 'PAGE_UNRESOLVED');
  rejects(draft({ post_url: '' }), 'POST_UNRESOLVED');
  const first = normalize(draft());
  const pageChanged = normalize(draft({ page_url: 'https://www.facebook.com/100000000000002' }));
  const postChanged = normalize(draft({ post_url: `${page}/posts/pfbidOtherOpaqueToken` }));
  assert.notEqual(fingerprint(first), fingerprint(pageChanged));
  assert.notEqual(fingerprint(first), fingerprint(postChanged));
});

test('the agreed budget examples use exact minor units with no destination multiplier', () => {
  for (const [daily, days, total] of [[5,3,1500],[5,2,1000],[5,4,2000],[2,3,600],[2.37,7,1659]]) {
    const price = pricing(normalize(draft({ budget_daily: daily, duration_days: days })));
    assert.equal(price.payable_minor, total);
    assert.equal(price.media_budget_minor, total);
    assert.deepEqual(price.adjustments, []);
  }
});

test('invalid and fractional-day prices fail before funding', () => {
  for (const budget_daily of [0, -1, 1.99, 1000.01, 2.001, NaN, Infinity, '5', null]) rejects(draft({ budget_daily }), 'INVALID_BUDGET');
  for (const duration_days of [0, -1, 1.5, 8, '3', null, Infinity]) rejects(draft({ duration_days }), 'INVALID_DURATION');
  rejects(draft({ currency: 'IQD' }), 'UNSUPPORTED_CURRENCY');
});

test('scheduled starts compare the complete offset-qualified instant with trusted time', () => {
  const schedule = { mode: 'SCHEDULED', timezone: 'Asia/Baghdad', start_at: '2026-10-23T15:01:00+03:00' };
  assert.equal(normalize(draft({ schedule })).schedule.start_at, '2026-10-23T12:01:00.000Z');
  for (const start_at of ['2026-10-23T14:59:00+03:00','2026-10-23T15:00:00+03:00','2026-10-22T16:00:00+03:00',
    '2026-10-23T16:00:00','invalid','2027-10-23T16:00:00+03:00']) {
    rejects(draft({ schedule: { ...schedule, start_at } }), 'INVALID_SCHEDULE');
  }
  rejects(draft({ schedule: { ...schedule, timezone: 'UTC' } }), 'INVALID_SCHEDULE');
});

test('immediate requests do not freeze the client display time as their accepted start', () => {
  const value = normalize(draft());
  assert.deepEqual(value.schedule, { mode: 'IMMEDIATE', timezone: 'Asia/Baghdad' });
  rejects(draft({ schedule: { ...draft().schedule, start_at: '2026-10-23T12:01:00Z' } }), 'INVALID_SCHEDULE');
});

test('scheduled starts reject impossible calendar dates rather than rolling into another day', () => {
  for (const start_at of ['2026-11-31T10:00:00Z', '2026-10-32T10:00:00Z',
    '2026-11-01T24:00:00Z', '2026-11-01T10:60:00Z', '2026-11-01T10:00:60Z',
    '2026-11-01T10:00:00+25:00', '2026-11-01T10:00:00+03:60']) {
    rejects(draft({ schedule: { mode: 'SCHEDULED', timezone: 'Asia/Baghdad', start_at } }), 'INVALID_SCHEDULE');
  }
  for (const start_at of ['2026-02-29T10:00:00Z', '2025-02-30T10:00:00Z']) {
    assert.throws(() => normalizeConfiguration(draft({ schedule: {
      mode: 'SCHEDULED', timezone: 'Asia/Baghdad', start_at,
    } }), { now: NOW, recovering: true }), error => error.code === 'INVALID_SCHEDULE');
  }
  assert.equal(normalizeConfiguration(draft({ schedule: {
    mode: 'SCHEDULED', timezone: 'Asia/Baghdad', start_at: '2024-02-29T10:00:00Z',
  } }), { now: NOW, recovering: true }).schedule.start_at, '2024-02-29T10:00:00.000Z');
});

test('expired accepted configurations can be normalized for recovery without changing their schedule', () => {
  const input = draft({ schedule: { mode: 'SCHEDULED', timezone: 'Asia/Baghdad', start_at: '2026-10-23T11:00:00Z' } });
  rejects(input, 'INVALID_SCHEDULE');
  const recovered = normalizeConfiguration(input, { now: NOW, recovering: true });
  assert.equal(recovered.schedule.start_at, '2026-10-23T11:00:00.000Z');
  assert.equal(pricing(recovered).payable_minor, 1500);
});

test('ages are ordered integer bounds and city identities are internal, never guessed provider keys', () => {
  for (const location of ['all','erbil','sulaymaniyah','duhok','baghdad']) {
    assert.equal(normalize(draft({ targeting: { ...draft().targeting, location } })).targeting.location, location);
  }
  for (const [age_min, age_max] of [[17,65],[18,66],[40,39],[18.5,65],['18',65],[18,null]]) {
    rejects(draft({ targeting: { ...draft().targeting, age_min, age_max } }), 'INVALID_AGE');
  }
  rejects(draft({ targeting: { ...draft().targeting, location: '2420605' } }), 'INVALID_TARGETING');
  rejects(draft({ targeting: { ...draft().targeting, gender: 'MALES' } }), 'INVALID_TARGETING');
});

test('reordering equivalent sets/keys and tracking URLs preserves the normalized fingerprint', () => {
  const first = normalize(draft());
  const second = normalize(draft({ placements: [...draft().placements].reverse(),
    destinations: [...draft().destinations].reverse(),
    post_url: `${post}?mibextid=ignored`,
    targeting: { age_max: 65, age_min: 18, gender: 'ALL', location: 'all' } }));
  assert.equal(fingerprint(first), fingerprint(second));
  for (const value of [draft({ budget_daily: 6 }), draft({ payment_method: 'FASTPAY' }),
    draft({ destinations: ['WHATSAPP'] }), draft({ placements: ['facebook'], destinations: ['WHATSAPP'] }),
    draft({ duration_days: 4 }), draft({ ad_name: 'Different' })]) {
    assert.notEqual(fingerprint(first), fingerprint(normalize(value)));
  }
});

test('unknown checkout methods cannot be accepted as new gateway integrations', () => {
  for (const payment_method of ['CASH', 'CARD', 'app_balance', '', null]) rejects(draft({ payment_method }), 'UNSUPPORTED_PAYMENT_METHOD');
  assert.equal(normalize(draft({ payment_method: 'FASTPAY' })).payment_method, 'FASTPAY');
});

test('historical single destinations remain single and v2 arrays keep their complete meaning', () => {
  assert.deepEqual(legacyDestinations({ schema_version: 1, destination: 'MESSENGER' }), ['MESSENGER']);
  assert.deepEqual(legacyDestinations({ schema_version: 2, objective: 'MESSAGES', destinations: ['WHATSAPP','MESSENGER'] }), ['MESSENGER','WHATSAPP']);
  assert.deepEqual(legacyDestinations({ schema_version: 2, objective: 'VIDEO_VIEWS' }), []);
  assert.throws(() => legacyDestinations({ schema_version: 1, destination: 'WHATSAPP', destinations: ['MESSENGER'] }), error => error.code === 'AMBIGUOUS_LEGACY_DESTINATION');
  assert.throws(() => legacyDestinations({ destination: 'WHATSAPP' }), error => error.code === 'LEGACY_CONNECTION_MIGRATION_REQUIRED');
});

test('unavailable estimates are never represented as zero, fake bounds or financial values', () => {
  const forecast = unavailableForecast();
  assert.equal(forecast.status, 'UNAVAILABLE');
  assert.equal(forecast.lower_bound, null);
  assert.equal(forecast.upper_bound, null);
  assert.equal(forecast.source, null);
  assert.equal(forecast.metric, null);
  assert.equal('price' in forecast, false);
  assert.equal('daily_outcomes_curve' in forecast, false);
  assert.equal('budget_guardrail' in forecast, false);
  assert.equal('estimate_dau' in forecast, false);
  assert.equal(API_VERSION, 'v26.0');
});
