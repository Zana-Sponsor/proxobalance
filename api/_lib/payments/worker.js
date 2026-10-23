import { PaymentError, fastpayConfiguration, fastpayClient, createQrRequest, createQr, verifyFastpayAttempt } from './fastpay.js';

const done = attempt => ['funded', 'compensated'].includes(attempt?.status);
const safeCode = error => error instanceof PaymentError ? error.code : 'FASTPAY_RECONCILIATION_UNAVAILABLE';
const gateway = (attempt, { env, fetchImpl, clientFactory }, forCreate = false) => {
  const config = fastpayConfiguration(attempt.environment, { env, forCreate });
  return { config, api: clientFactory ? clientFactory(config) : fastpayClient(config, { fetchImpl }) };
};

export async function reconcilePayment(attempt, { service, env = process.env, fetchImpl = fetch, clientFactory, now = Date.now } = {}) {
  if (done(attempt)) return attempt;
  if (!attempt.creation_hash) return { ...attempt, reconciliation_code: 'FASTPAY_CREATION_NOT_STARTED' };
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
  if (done(attempt) || attempt.qr_url && attempt.qr_text) return attempt;
  // No replay of QR creation after a durable intent, timeout or lost reply.
  if (attempt.status !== 'prepared' || attempt.creation_hash) return reconcilePayment(attempt, options);
  const { config, api } = gateway(attempt, { env, fetchImpl, clientFactory }, true);
  const request = createQrRequest(attempt, config, { now: now() });
  const intent = await service('create_intent', { attemptId, payload: { request_hash: request.request_hash } });
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
