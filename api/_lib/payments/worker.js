import { PaymentError, fastpayConfiguration, fastpayClient, createQrRequest, createQr, verifyFastpayAttempt } from './fastpay.js';

const done = attempt => ['funded', 'compensated'].includes(attempt?.status);
const closedUnstarted = attempt => attempt?.payment_not_started === true &&
  ['cancelled', 'expired'].includes(attempt?.status) && !attempt?.creation_hash && !attempt?.creation_started_at;
const safeCode = error => error instanceof PaymentError ? error.code : 'FASTPAY_RECONCILIATION_UNAVAILABLE';
const preCreationFailures = new Set([
  'FASTPAY_ENVIRONMENT_MISMATCH', 'FASTPAY_AD_CREATION_DISABLED', 'FASTPAY_AD_PRODUCTION_DISABLED',
  'FASTPAY_MERCHANT_NOT_CONFIGURED', 'FASTPAY_CALLBACK_NOT_CONFIGURED', 'FASTPAY_RETURN_URL_INVALID',
  'FASTPAY_QR_ORIGINS_INVALID', 'FASTPAY_ATTEMPT_MISMATCH', 'FASTPAY_QR_WINDOW_ELAPSED',
]);
const gateway = (attempt, { env, fetchImpl, clientFactory }, forCreate = false) => {
  const config = fastpayConfiguration(attempt.environment, { env, forCreate });
  return { config, api: clientFactory ? clientFactory(config) : fastpayClient(config, { fetchImpl }) };
};

export async function reconcilePayment(attempt, { service, env = process.env, fetchImpl = fetch, clientFactory, now = Date.now } = {}) {
  if (done(attempt) || closedUnstarted(attempt)) return attempt;
  if (!attempt.creation_hash) {
    if (attempt.status === 'prepared' && Date.parse(attempt.expires_at) <= now())
      return service('close_unstarted', { attemptId: attempt.attempt_id, payload: { error_code: 'FASTPAY_QR_WINDOW_ELAPSED' } });
    return { ...attempt, reconciliation_code: 'FASTPAY_CREATION_NOT_STARTED' };
  }
  const { config, api } = gateway(attempt, { env, fetchImpl, clientFactory });
  const observed = await verifyFastpayAttempt(api, attempt, config, { now: now() });
  if (!observed.paid) {
    const updated = await service('observe_status', { attemptId: attempt.attempt_id, payload: observed.observation });
    return { ...updated, gateway_status: observed.gateway_status };
  }
  return service('observe_verified', { attemptId: attempt.attempt_id, payload: observed.verification });
}

export async function preparePayment(attemptId, options = {}) {
  const { service, env = process.env, fetchImpl = fetch, clientFactory, now = Date.now } = options;
  const attempt = await service('read', { attemptId });
  if (done(attempt) || closedUnstarted(attempt) || attempt.qr_url && attempt.qr_text) return attempt;
  // No replay of QR creation after a durable intent, timeout or lost reply.
  if (attempt.status !== 'prepared' || attempt.creation_hash) return reconcilePayment(attempt, options);
  let config, api, request;
  try {
    ({ config, api } = gateway(attempt, { env, fetchImpl, clientFactory }, true));
    request = createQrRequest(attempt, config, { now: now() });
  } catch (error) {
    if (!(error instanceof PaymentError) || !preCreationFailures.has(error.code)) throw error;
    // The database closes under the same row lock used by create_intent. It
    // returns proof only if no concurrent request has acquired gateway intent.
    // A failed/ambiguous close remains recoverable through the original ID.
    return service('close_unstarted', { attemptId, payload: { error_code: error.code } });
  }
  let intent;
  try {
    intent = await service('create_intent', { attemptId, payload: { request_hash: request.request_hash } });
  } catch (error) {
    if (!(error instanceof PaymentError) || error.code !== 'PAYMENT_ATTEMPT_EXPIRED' || error.uncertain || error.status !== 409) throw error;
    // A database gate can close between configuration validation and intent.
    // Still require the locked closure proof; never infer it from this error.
    return service('close_unstarted', { attemptId, payload: { error_code: 'FASTPAY_CREATION_NOT_STARTED' } });
  }
  if (intent.create_authorized !== true) return intent;
  try {
    const qr = await createQr(api, request, config);
    return await service('qr_created', { attemptId, payload: qr });
  } catch (error) {
    await service('unknown', { attemptId, payload: { error_code: safeCode(error) } }).catch(() => {});
    return { ...attempt, status: 'reconcile', qr_url: null, qr_text: null, reconciliation_code: safeCode(error) };
  }
}

export async function runPaymentReconciliation(options = {}) {
  const { service } = options;
  const attempt = await service('claim_reconcile');
  if (!attempt?.attempt_id) return { ok: true, processed: 0, status: 'idle' };
  let result, errorCode;
  try { result = await reconcilePayment(attempt, options); }
  catch (error) { errorCode = safeCode(error); }
  if (!done(result)) await service('finish_reconcile', { attemptId: attempt.attempt_id,
    payload: { lease_token: attempt.lease_token, error_code: errorCode || result?.reconciliation_code || null } });
  return { ok: true, processed: 1, status: done(result) ? result.status : errorCode ? 'reconcile' : 'pending', ...(errorCode ? { error_code: errorCode } : {}) };
}
