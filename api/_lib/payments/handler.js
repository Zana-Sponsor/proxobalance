import { timingSafeEqual } from 'node:crypto';
import { readJson, json } from '../security.js';
import { PaymentError, fail, validOrderId } from './fastpay.js';
import { paymentBackend } from './backend.js';
import { preparePayment, reconcilePayment, runPaymentReconciliation } from './worker.js';

const uuid = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
const allowed = (value, keys) => value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).every(key => keys.includes(key));
const terminal = status => ['funded', 'compensated'].includes(status);
// The immutable-attempt RPC recovers an existing submission before these
// checks. Only these explicit business rejections prove no payment attempt was
// created; conflicts, transport failures and provider errors remain uncertain.
const noAttemptRejections = new Set([
  'AD_FASTPAY_UNAVAILABLE', 'META_FASTPAY_UNAVAILABLE', 'TIKTOK_DM_FASTPAY_UNAVAILABLE',
  'QUOTE_NOT_FOUND', 'QUOTE_EXPIRED', 'QUOTE_CHANGED', 'CONNECTION_EXPIRED',
  'TIKTOK_ACCOUNT_UNAVAILABLE', 'PRICE_CHANGED', 'INVALID_PROMO', 'RATE_LIMITED',
]);
function authorizedWorker(req, env) {
  const expected = env.FASTPAY_AD_WORKER_SECRET, supplied = String(req.headers?.authorization || '').match(/^Bearer\s+(\S+)$/i)?.[1];
  if (typeof expected !== 'string' || expected.length < 32) fail('FASTPAY_WORKER_NOT_CONFIGURED', { status: 503 });
  return !!supplied && Buffer.byteLength(supplied) === Buffer.byteLength(expected) && timingSafeEqual(Buffer.from(supplied), Buffer.from(expected));
}

export function publicPaymentAttempt(attempt, { now = Date.now(), cancelled = false } = {}) {
  const keys = ['attempt_id', 'order_id', 'transaction_id', 'environment', 'currency', 'amount_iqd', 'cost_usd', 'fx_rate', 'status', 'expires_at', 'ad_id'];
  const resultKeys = ['ok', 'platform', 'ad_id', 'ad_number', 'public_ad_id', 'status', 'payment_method', 'payment_status', 'payment_transaction_id',
    'receipt_uid', 'charged_usd', 'charged_iqd', 'rate', 'gross_usd', 'balance_after', 'job_id', 'quote_id', 'compensated'];
  const result = attempt?.result && typeof attempt.result === 'object' ? Object.fromEntries(resultKeys.filter(key => Object.hasOwn(attempt.result, key)).map(key => [key, attempt.result[key]])) : null;
  const response = { ok: true, ...Object.fromEntries(keys.filter(key => Object.hasOwn(attempt || {}, key)).map(key => [key, attempt[key]])),
    result, terminal: terminal(attempt?.status), compensated: attempt?.status === 'compensated' || result?.compensated === true,
    uncertain: ['creating', 'reconcile'].includes(attempt?.status), qr_url: null, qr_text: null };
  const cancelRequested = cancelled || attempt?.cancel_requested === true || attempt?.status === 'cancelled';
  if (!response.terminal && !cancelRequested && !['declined', 'expired'].includes(attempt?.status) && Date.parse(attempt?.expires_at) > now) {
    response.qr_url = attempt.qr_url || null; response.qr_text = attempt.qr_text || null;
  }
  if (cancelRequested) response.cancel_requested = true;
  if (['PAID', 'UNPAID', 'DECLINED'].includes(attempt?.gateway_status)) response.gateway_status = attempt.gateway_status;
  if (/^[A-Z][A-Z0-9_]{2,100}$/.test(attempt?.reconciliation_code || '')) {
    response.error_code = attempt.reconciliation_code;
    response.uncertain ||= attempt.reconciliation_code !== 'FASTPAY_CREATION_NOT_STARTED';
  }
  return response;
}

export function createPaymentHandler({ env = process.env, fetchImpl = fetch, db, now = Date.now, clientFactory, workerImpl = runPaymentReconciliation } = {}) {
  return async function payments(req, res) {
    try {
      if (req.method !== 'POST') { res.setHeader('Allow', 'POST'); return json(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED' }); }
      const op = String(req.query?.op || new URL(req.url, 'https://local.invalid').searchParams.get('op') || '');
      if (!['prepare', 'status', 'cancel', 'callback', 'worker-reconcile'].includes(op)) fail('NOT_FOUND', { status: 404 });
      if (op === 'worker-reconcile' && !authorizedWorker(req, env)) fail('UNAUTHORIZED', { status: 401 });
      const backend = db || paymentBackend({ env, fetchImpl });
      const options = { service: backend.service, env, fetchImpl, now, clientFactory };
      if (op === 'worker-reconcile') {
        const body = await readJson(req, 1024);
        if (!allowed(body, [])) fail('INVALID_INPUT');
        return json(res, 200, await workerImpl(options));
      }
      if (op === 'callback') {
        const body = await readJson(req, 8192);
        // IPN is an unauthenticated hint, never payment or ownership evidence.
        // Unknown orders receive the same acknowledgment; the worker verifies
        // with merchant credentials before any wallet/order mutation.
        if (validOrderId(body?.merchant_order_id)) await backend.service('callback_hint', { payload: { order_id: body.merchant_order_id } });
        return json(res, 200, { received: true });
      }
      const user = await backend.authenticate(req);
      if (!uuid(user?.id)) fail('UNAUTHORIZED', { status: 401 });
      const body = await readJson(req, 4096);
      if (op === 'prepare') {
        if (!allowed(body, ['submission_id', 'platform', 'quote_id', 'expected_cost_usd', 'expected_amount_iqd']) ||
            !uuid(body.submission_id) || !uuid(body.quote_id) || !['META', 'TIKTOK'].includes(body.platform) ||
            typeof body.expected_cost_usd !== 'number' || !Number.isFinite(body.expected_cost_usd) || body.expected_cost_usd <= 0 ||
            !/^\d+(?:\.\d{1,6})?$/.test(String(body.expected_cost_usd)) ||
            !Number.isSafeInteger(body.expected_amount_iqd) || body.expected_amount_iqd < 1000) fail('INVALID_INPUT');
        let attempt;
        try {
          attempt = await backend.user(req, 'pa_ad_payment_attempt', {
            p_submission_id: body.submission_id, p_platform: body.platform, p_quote_id: body.quote_id,
            p_expected_cost_usd: body.expected_cost_usd, p_expected_amount_iqd: body.expected_amount_iqd,
          });
        } catch (error) {
          if (error instanceof PaymentError && error.status === 409 && !error.uncertain && noAttemptRejections.has(error.code))
            error.attemptNotCreated = true;
          throw error;
        }
        let prepared = attempt;
        if (!terminal(attempt.status)) {
          try { prepared = await preparePayment(attempt.attempt_id, options); }
          catch (error) { prepared = { ...attempt, reconciliation_code: error instanceof PaymentError ? error.code : 'FASTPAY_RECONCILIATION_UNAVAILABLE' }; }
        }
        return json(res, 200, publicPaymentAttempt(prepared, { now: now() }));
      }
      if (op === 'cancel') {
        if (!allowed(body, ['attempt_id']) || !uuid(body.attempt_id)) fail('INVALID_INPUT');
        const attempt = await backend.user(req, 'pa_ad_payment_cancel', { p_attempt_id: body.attempt_id });
        return json(res, 200, publicPaymentAttempt(attempt, { now: now(), cancelled: true }));
      }
      if (!allowed(body, ['submission_id']) || !uuid(body.submission_id)) fail('INVALID_INPUT');
      let attempt = await backend.user(req, 'pa_ad_payment_status', { p_submission_id: body.submission_id });
      if (!terminal(attempt.status)) {
        try {
          attempt = await backend.service('read', { attemptId: attempt.attempt_id });
          attempt = await reconcilePayment(attempt, options);
        }
        catch (error) { attempt = { ...attempt, reconciliation_code: error instanceof PaymentError ? error.code : 'FASTPAY_RECONCILIATION_UNAVAILABLE' }; }
      }
      return json(res, 200, publicPaymentAttempt(attempt, { now: now() }));
    } catch (error) {
      const known = error instanceof PaymentError;
      const status = known ? error.status : error.status === 413 ? 413 : error instanceof SyntaxError ? 400 : 503;
      const code = known ? error.code : error.status === 413 ? 'PAYLOAD_TOO_LARGE' : error instanceof SyntaxError ? 'INVALID_INPUT' : 'AD_PAYMENT_BACKEND_UNAVAILABLE';
      return json(res, status, { ok: false, error: code, code, uncertain: status >= 500 || known && error.uncertain, retryable: status >= 500 || known && error.retryable,
        ...(known && error.attemptNotCreated === true ? { attempt_created: false } : {}) });
    }
  };
}

export default createPaymentHandler();
