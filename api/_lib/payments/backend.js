import { fail } from './fastpay.js';

const uuid = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
export function paymentBackend({ env = process.env, fetchImpl = fetch } = {}) {
  const base = String(env.PROXO_SUPABASE_URL || '').replace(/\/$/, ''), key = env.PROXO_SUPABASE_SERVICE_ROLE_KEY;
  if (!/^https:\/\/[a-z0-9.-]+$/.test(base) || !key) fail('AD_PAYMENT_BACKEND_NOT_CONFIGURED', { status: 503 });
  const tokenFor = req => {
    const match = String(req.headers?.authorization || '').match(/^Bearer\s+(\S+)$/i);
    if (!match) fail('UNAUTHORIZED', { status: 401 });
    return match[1];
  };
  const rpc = async (name, payload, token = key) => {
    let response, result;
    try {
      response = await fetchImpl(`${base}/rest/v1/rpc/${name}`, { method: 'POST', redirect: 'error', signal: AbortSignal.timeout(12000),
        headers: { apikey: key, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      result = await response.json();
    } catch { fail('AD_PAYMENT_BACKEND_UNAVAILABLE', { uncertain: true, retryable: true, status: 503 }); }
    if (!response.ok || result?.ok === false) {
      // Only the RPC's explicit business rejection proves no mutation occurred.
      // PostgREST/network errors and unknown envelopes never become definite 409s.
      const rejected = response.ok && result?.ok === false && /^[A-Z][A-Z0-9_]{2,100}$/.test(result?.code || '');
      fail(rejected ? result.code : 'AD_PAYMENT_BACKEND_UNAVAILABLE', {
        status: rejected ? 409 : 503, uncertain: !rejected, retryable: !rejected });
    }
    if (!(result === null && name === 'pa_ad_payment_service' && payload.p_action === 'claim_reconcile') &&
        (!result || typeof result !== 'object' || Array.isArray(result) || result.ok !== true))
      fail('AD_PAYMENT_BACKEND_UNAVAILABLE', { uncertain: true, retryable: true, status: 503 });
    return result;
  };
  return {
    async authenticate(req) {
      const token = tokenFor(req);
      let response, user;
      try {
        response = await fetchImpl(`${base}/auth/v1/user`, { redirect: 'error', signal: AbortSignal.timeout(10000), headers: { apikey: key, Authorization: `Bearer ${token}` } });
        user = await response.json();
      } catch { fail('AD_PAYMENT_AUTH_UNAVAILABLE', { uncertain: true, retryable: true, status: 503 }); }
      if (response.status >= 500 || response.status === 429) fail('AD_PAYMENT_AUTH_UNAVAILABLE', { uncertain: true, retryable: true, status: 503 });
      if (!response.ok || !uuid(user?.id)) fail('UNAUTHORIZED', { status: 401 });
      return user;
    },
    user: (req, name, payload) => rpc(name, payload, tokenFor(req)),
    service: (action, { attemptId = null, payload = {} } = {}) => rpc('pa_ad_payment_service', { p_action: action, p_attempt_id: attemptId, p_payload: payload }),
  };
}
