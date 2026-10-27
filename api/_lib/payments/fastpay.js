import { createHash } from 'node:crypto';
import { MetaError, fail, fingerprint } from '../meta/contract.js';

export { MetaError as PaymentError, fail };
export const FASTPAY_BASES = Object.freeze({ sandbox: 'https://staging-qr.fast-pay.iq', production: 'https://qr.fast-pay.iq' });
export const validOrderId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,32}$/.test(value);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const sha256 = value => createHash('sha256').update(value).digest('hex');
const safeReference = value => typeof value === 'string' && /^[A-Za-z0-9_.:-]{1,128}$/.test(value);
const positiveIqd = value => ['string', 'number'].includes(typeof value) && /^\d+(?:\.0{1,6})?$/.test(String(value)) && Number.isSafeInteger(Number(value)) && Number(value) >= 1000;

function httpsUrl(value, originOnly = false) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || url.port ||
        !/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$/i.test(url.hostname) ||
        /\.(?:localhost|local|internal|invalid|test)$/i.test(url.hostname) ||
        originOnly && url.href !== `${url.origin}/`) return null;
    return url;
  } catch { return null; }
}

export function fastpayConfiguration(environment, { env = process.env, forCreate = false } = {}) {
  if (!Object.hasOwn(FASTPAY_BASES, environment) || forCreate && environment !== (env.FASTPAY_AD_ENVIRONMENT || 'sandbox')) fail('FASTPAY_ENVIRONMENT_MISMATCH', { status: 503 });
  if (forCreate && env.FASTPAY_AD_CREATE_ENABLED !== 'true') fail('FASTPAY_AD_CREATION_DISABLED', { status: 503 });
  if (forCreate && environment === 'production' && env.FASTPAY_AD_PRODUCTION_ENABLED !== 'true') fail('FASTPAY_AD_PRODUCTION_DISABLED', { status: 503 });
  const prefix = `FASTPAY_AD_${environment.toUpperCase()}`;
  const storeId = env[`${prefix}_STORE_ID`], storePassword = env[`${prefix}_STORE_PASSWORD`];
  if (!safeReference(storeId) || typeof storePassword !== 'string' || storePassword.length < 8 || storePassword.length > 256 || /[\r\n\x00]/.test(storePassword)) fail('FASTPAY_MERCHANT_NOT_CONFIGURED', { status: 503 });
  const config = { environment, base: FASTPAY_BASES[environment], storeId, storePassword };
  if (forCreate) {
    const origin = httpsUrl(env.PROXO_AD_PAYMENTS_BACKEND_ORIGIN, true);
    const callback = httpsUrl(env.FASTPAY_AD_CALLBACK_URL);
    if (!origin || !callback || callback.origin !== origin.origin || callback.pathname !== '/api/meta-ads' ||
        callback.searchParams.get('platform') !== 'payments' || callback.searchParams.get('op') !== 'callback' ||
        [...callback.searchParams.keys()].sort().join(',') !== 'op,platform' || callback.hash) fail('FASTPAY_CALLBACK_NOT_CONFIGURED', { status: 503 });
    config.callbackUrl = callback.href;
    for (const [key, name] of [['successUrl', 'FASTPAY_AD_SUCCESS_URL'], ['cancelUrl', 'FASTPAY_AD_CANCEL_URL']]) {
      if (env[name]) {
        const target = httpsUrl(env[name]);
        if (!target || target.origin !== origin.origin || target.hash) fail('FASTPAY_RETURN_URL_INVALID', { status: 503 });
        config[key] = target.href;
      }
    }
  }
  if (forCreate) {
    const extraOrigins = String(env.FASTPAY_AD_QR_ORIGINS || '').split(',').filter(Boolean).map(value => httpsUrl(value.trim(), true));
    if (extraOrigins.some(value => !value)) fail('FASTPAY_QR_ORIGINS_INVALID', { status: 503 });
    config.qrOrigins = [config.base, ...extraOrigins.map(value => value.origin)];
  }
  return config;
}

function boundAttempt(attempt, config) {
  if (!validOrderId(attempt?.order_id) || attempt.environment !== config.environment || attempt.merchant_reference !== config.storeId ||
      attempt.currency !== 'IQD' || !positiveIqd(attempt.amount_iqd)) fail('FASTPAY_ATTEMPT_MISMATCH', { status: 409 });
}

export function fastpayClient(config, { fetchImpl = fetch, timeoutMs = 12000 } = {}) {
  if (config.base !== FASTPAY_BASES[config.environment]) fail('FASTPAY_ORIGIN_INVALID', { status: 503 });
  return async (operation, parameters) => {
    if (!['qr', 'validate', 'status'].includes(operation)) fail('FASTPAY_OPERATION_INVALID');
    const uncertain = operation === 'qr';
    const error = () => fail(uncertain ? 'FASTPAY_CREATION_OUTCOME_UNKNOWN' : 'FASTPAY_VERIFICATION_UNAVAILABLE', { status: 503, retryable: !uncertain, uncertain });
    let response, raw;
    try {
      response = await fetchImpl(`${config.base}/api/v1/public/vending/${operation}`, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(timeoutMs),
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...parameters, storeId: config.storeId, storePassword: config.storePassword }),
      });
      if (Number(response.headers?.get('content-length')) > 65536) error();
      raw = await response.text();
    } catch { error(); }
    if (!response.ok || typeof raw !== 'string' || Buffer.byteLength(raw) > 65536) error();
    let body;
    // The published sample has JSON typos. Do not repair financial responses,
    // default missing currency, or accept an HTML/error response as evidence.
    try { body = JSON.parse(raw); } catch { error(); }
    if (!object(body) || body.code !== 200 || !Array.isArray(body.errors) || body.errors.length || !object(body.data)) error();
    return { data: body.data, response_sha256: sha256(raw) };
  };
}

export function createQrRequest(attempt, config, { now = Date.now() } = {}) {
  boundAttempt(attempt, config);
  const expiresIn = Math.ceil((Date.parse(attempt.expires_at) - now) / 60000);
  if (!Number.isInteger(expiresIn) || expiresIn < 3 || expiresIn > 15 || !config.callbackUrl) fail('FASTPAY_QR_WINDOW_ELAPSED', { status: 409 });
  const parameters = {
    orderId: attempt.order_id, billAmount: Number(attempt.amount_iqd), currency: 'IQD', expiresIn,
    callbackUrl: config.callbackUrl,
    ...(config.successUrl ? { successUrl: config.successUrl } : {}), ...(config.cancelUrl ? { cancelUrl: config.cancelUrl } : {}),
  };
  return { parameters, request_hash: fingerprint({ environment: config.environment, merchant_reference: config.storeId, parameters }) };
}

export async function createQr(api, request, config) {
  const { data } = await api('qr', request.parameters);
  const url = httpsUrl(data.qrUrl);
  if (!url || !config.qrOrigins.includes(url.origin) || url.hash || typeof data.qrText !== 'string' || !data.qrText.trim() ||
      data.qrText.length > 4096 || /[\x00-\x1f\x7f]/.test(data.qrText) ||
      data.qrText.includes(config.storePassword) || data.qrUrl.includes(config.storePassword)) {
    fail('FASTPAY_CREATION_OUTCOME_UNKNOWN', { uncertain: true, status: 503 });
  }
  return { qr_url: url.href, qr_text: data.qrText, request_hash: request.request_hash };
}

function paidData(data, attempt) {
  if (data.merchant_order_id !== attempt.order_id || data.order_id != null && data.order_id !== attempt.order_id ||
      data.currency !== 'IQD' || !positiveIqd(data.received_amount) || Number(data.received_amount) !== Number(attempt.amount_iqd) ||
      !safeReference(data.gw_transaction_id)) fail('FASTPAY_VERIFICATION_MISMATCH', { status: 409 });
  return data.gw_transaction_id;
}

export async function verifyFastpayAttempt(api, attempt, config, { now = Date.now() } = {}) {
  boundAttempt(attempt, config);
  const status = await api('status', { orderId: attempt.order_id });
  if (status.data.merchant_order_id !== attempt.order_id || status.data.order_id != null && status.data.order_id !== attempt.order_id ||
      !['PAID', 'UNPAID', 'DECLINED'].includes(status.data.payment_status)) fail('FASTPAY_VERIFICATION_MISMATCH', { status: 409 });
  if (status.data.payment_status !== 'PAID') return { paid: false, gateway_status: status.data.payment_status, observation: {
    order_id: attempt.order_id, environment: config.environment, merchant_reference: config.storeId,
    status: status.data.payment_status, amount_iqd: Number(attempt.amount_iqd), currency: 'IQD',
    verified_at: new Date(now).toISOString(), response_sha256: status.response_sha256, verification_source: 'FASTPAY_STATUS',
  } };
  const transactionId = paidData(status.data, attempt);
  const validation = await api('validate', { orderId: attempt.order_id });
  if (validation.data.status !== 'success' || paidData(validation.data, attempt) !== transactionId) fail('FASTPAY_VERIFICATION_MISMATCH', { status: 409 });
  return { paid: true, verification: {
    order_id: attempt.order_id, environment: config.environment, merchant_reference: config.storeId,
    status: 'PAID', gateway_transaction_id: transactionId, amount_iqd: Number(attempt.amount_iqd), currency: 'IQD',
    verified_at: new Date(now).toISOString(), response_sha256: validation.response_sha256, verification_source: 'FASTPAY_VALIDATE',
  } };
}
