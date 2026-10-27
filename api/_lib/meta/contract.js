import { createHash } from 'node:crypto';
export const API_VERSION = 'v26.0';
export class MetaError extends Error {
  constructor(code, { uncertain = false, retryable = false, status = 422 } = {}) {
    super(code); this.code = code; this.uncertain = uncertain; this.retryable = retryable; this.status = status;
  }
}
export const fail = (code, options) => { throw new MetaError(code, options); };
const object = value => value && typeof value === 'object' && !Array.isArray(value);
const exact = (value, allowed, code) => { if (!object(value) || Object.keys(value).some(k => !allowed.includes(k))) fail(code); };
const integer = (v, min, max, code) => { if (!Number.isSafeInteger(v) || v < min || v > max) fail(code); return v; };
function set(values, choices, code, min = 1) {
  if (!Array.isArray(values) || values.length < min || values.length > choices.length ||
      new Set(values).size !== values.length || values.some(v => !choices.includes(v))) fail(code);
  return [...values].sort();
}
const fbHosts = ['facebook.com','www.facebook.com','m.facebook.com','web.facebook.com','fb.watch'];
const igHosts = ['instagram.com','www.instagram.com'];
export function normalizeUrl(input, kind = 'post') {
  if (typeof input !== 'string' || input.trim().length > 2048 || /\s/.test(input.trim())) fail(kind === 'page' ? 'PAGE_UNRESOLVED' : 'POST_UNRESOLVED');
  let url; try { url = new URL(input.trim()); } catch { fail(kind === 'page' ? 'PAGE_UNRESOLVED' : 'POST_UNRESOLVED'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.port ||
      ![...fbHosts,...igHosts].includes(url.hostname)) fail('UNSUPPORTED_URL');
  const instagram = igHosts.includes(url.hostname);
  if (kind === 'page' && (instagram || url.hostname === 'fb.watch' || /\/(posts|videos|reel|share)\//.test(url.pathname))) fail('PAGE_UNRESOLVED');
  if (instagram && !/^\/(p|reel|tv)\/[^/]+/.test(url.pathname)) fail('POST_UNRESOLVED');
  if (!url.pathname || url.pathname === '/') fail(kind === 'page' ? 'PAGE_UNRESOLVED' : 'POST_UNRESOLVED');
  url.hostname = instagram ? 'www.instagram.com' : url.hostname === 'fb.watch' ? 'fb.watch' : 'www.facebook.com';
  for (const key of [...url.searchParams.keys()]) if (/^(utm_|mibextid$|fbclid$|igsh$)/.test(key)) url.searchParams.delete(key);
  url.searchParams.sort(); url.hash = ''; url.pathname = url.pathname.replace(/\/+$/, '');
  return url.href;
}
export function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (object(value)) return Object.fromEntries(Object.keys(value).sort().map(k => [k,canonical(value[k])]));
  return value;
}
export const fingerprint = value => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
export const destinationType = destinations => {
  const key = [...destinations].sort().join(',');
  const map = {
    'WHATSAPP':'WHATSAPP','MESSENGER':'MESSENGER','INSTAGRAM_DIRECT':'INSTAGRAM_DIRECT',
    'INSTAGRAM_DIRECT,MESSENGER':'MESSAGING_INSTAGRAM_DIRECT_MESSENGER',
    'INSTAGRAM_DIRECT,WHATSAPP':'MESSAGING_INSTAGRAM_DIRECT_WHATSAPP',
    'MESSENGER,WHATSAPP':'MESSAGING_MESSENGER_WHATSAPP',
    'INSTAGRAM_DIRECT,MESSENGER,WHATSAPP':'MESSAGING_INSTAGRAM_DIRECT_MESSENGER_WHATSAPP',
  }; if (!map[key]) fail('INVALID_DESTINATIONS'); return map[key];
};
export function normalizeConfiguration(input, { now = Date.now(), recovering = false } = {}) {
  exact(input,['schema_version','platform','ad_name','objective','page_url','post_url','placements','destinations','currency','budget_daily','duration_days','payment_method','schedule','targeting'],'INVALID_INPUT');
  if (input.schema_version !== 3 || input.platform !== 'META') fail('SCHEMA_VERSION_REQUIRED');
  if (!['MESSAGES','VIDEO_VIEWS','VIDEO_ENGAGEMENT'].includes(input.objective)) fail('INVALID_OBJECTIVE');
  if (typeof input.ad_name !== 'string' || input.ad_name.trim().length < 1 || [...input.ad_name.trim()].length > 120) fail('INVALID_NAME');
  const placements = set(input.placements,['facebook','instagram'],'INVALID_PLACEMENTS');
  let destinations;
  if (input.objective === 'MESSAGES') {
    destinations = set(input.destinations,['WHATSAPP','MESSENGER','INSTAGRAM_DIRECT'],'INVALID_DESTINATIONS');
    if (destinations.includes('MESSENGER') && !placements.includes('facebook') || destinations.includes('INSTAGRAM_DIRECT') && !placements.includes('instagram')) fail('INCOMPATIBLE_DESTINATIONS');
  } else if ('destinations' in input) fail('UNEXPECTED_DESTINATIONS');
  if (input.currency !== 'USD') fail('UNSUPPORTED_CURRENCY');
  const daily = input.budget_daily;
  if (typeof daily !== 'number' || !Number.isFinite(daily) || daily < 2 || daily > 1000 || Math.abs(daily * 100 - Math.round(daily * 100)) > 1e-7) fail('INVALID_BUDGET');
  const duration = integer(input.duration_days,1,7,'INVALID_DURATION');
  if (!['WALLET','FASTPAY'].includes(input.payment_method)) fail('UNSUPPORTED_PAYMENT_METHOD');
  exact(input.schedule,['mode','timezone','start_at'],'INVALID_SCHEDULE');
  const schedule = {mode:input.schedule.mode,timezone:'Asia/Baghdad'};
  if (input.schedule.timezone !== schedule.timezone || !['IMMEDIATE','SCHEDULED'].includes(schedule.mode)) fail('INVALID_SCHEDULE');
  if (schedule.mode === 'SCHEDULED') {
    // Date.parse normalizes impossible calendar dates such as November 31.
    // Validate the original calendar and offset before converting to an instant.
    const parts = typeof input.schedule.start_at === 'string' && /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|([+-])(\d{2}):(\d{2}))$/.exec(input.schedule.start_at);
    if (!parts) fail('INVALID_SCHEDULE');
    const [,y,m,d,h,min,sec,zone,,oh,om] = parts;
    if (+y < 2000 || +m < 1 || +m > 12 || +d < 1 || +d > new Date(Date.UTC(+y,+m,0)).getUTCDate() ||
        +h > 23 || +min > 59 || +sec > 59 || zone !== 'Z' && (+oh > 14 || +om > 59 || +oh === 14 && +om !== 0)) fail('INVALID_SCHEDULE');
    const t = Date.parse(input.schedule.start_at);
    if (!Number.isFinite(t) || !recovering && (t <= now || t > now+90*86400000)) fail('INVALID_SCHEDULE');
    schedule.start_at = new Date(t).toISOString();
  } else if ('start_at' in input.schedule) fail('INVALID_SCHEDULE');
  exact(input.targeting,['location','gender','age_min','age_max'],'INVALID_TARGETING');
  const target = input.targeting;
  if (!['all','erbil','sulaymaniyah','duhok','baghdad'].includes(target.location) || !['ALL','MALE','FEMALE'].includes(target.gender)) fail('INVALID_TARGETING');
  integer(target.age_min,18,65,'INVALID_AGE'); integer(target.age_max,target.age_min,65,'INVALID_AGE');
  return canonical({schema_version:3,platform:'META',ad_name:input.ad_name.trim(),objective:input.objective,
    page_url:normalizeUrl(input.page_url,'page'),post_url:normalizeUrl(input.post_url),placements,
    ...(destinations ? {destinations} : {}),currency:'USD',budget_daily:Math.round(daily*100)/100,
    duration_days:duration,payment_method:input.payment_method,schedule,targeting:{...target}});
}
export function pricing(configuration) {
  const daily = Math.round(configuration.budget_daily * 100);
  const total = daily * configuration.duration_days;
  return {daily_budget_minor:daily,duration_days:configuration.duration_days,media_budget_minor:total,adjustments:[],payable_minor:total};
}
export const unavailableForecast = () => ({status:'UNAVAILABLE',reason_code:'SUPPORTED_ESTIMATE_NOT_AVAILABLE',
  source:null,metric:null,unit:null,horizon:'CAMPAIGN',lower_bound:null,upper_bound:null,generated_at:null});
export function legacyDestinations(record) {
  if ('destination' in record && 'destinations' in record) fail('AMBIGUOUS_LEGACY_DESTINATION');
  if (record.schema_version === 1 && typeof record.destination === 'string') return set([record.destination],['WHATSAPP','MESSENGER','INSTAGRAM_DIRECT'],'INVALID_DESTINATIONS');
  if ([2,3].includes(record.schema_version)) return record.objective === 'MESSAGES' ? set(record.destinations,['WHATSAPP','MESSENGER','INSTAGRAM_DIRECT'],'INVALID_DESTINATIONS') : [];
  fail('LEGACY_CONNECTION_MIGRATION_REQUIRED');
}
