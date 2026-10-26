/** Self-contained n8n checkout checks; no credentials or gateway authority. */
export function legacyCheckoutContract() {
  const fail = code => { throw new Error(code); };
  const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
  const uuid = v => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);
  const order = v => typeof v === 'string' && /^[A-Za-z0-9_-]{8,32}$/.test(v) && !/^AP[0-9a-f]{28}$/i.test(v);
  const iqd = v => ['number','string'].includes(typeof v) && /^\d+$/.test(String(v)) && Number.isSafeInteger(Number(v)) && Number(v) >= 1000;
  function origin(value) {
    if (typeof value !== 'string' || !/^https:\/\/(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$/i.test(value) || /\.(?:local|internal|invalid|test)$/i.test(value)) fail('LEGACY_FASTPAY_ORIGIN_INVALID');
    return value;
  }
  function config(vars, sandboxOnly = false) {
    const environment = sandboxOnly ? 'sandbox' : vars.PROXO_LEGACY_FASTPAY_ENVIRONMENT;
    if (!['sandbox','production'].includes(environment)) fail('LEGACY_FASTPAY_ENVIRONMENT_REQUIRED');
    const baseUrl = environment === 'sandbox' ? 'https://staging-qr.fast-pay.iq' : 'https://qr.fast-pay.iq';
    const supabaseUrl = origin(vars.PROXO_LEGACY_FASTPAY_SUPABASE_URL);
    const publicOrigin = origin(vars.PROXO_LEGACY_FASTPAY_PUBLIC_ORIGIN);
    const merchant = vars.PROXO_LEGACY_FASTPAY_MERCHANT_REFERENCE;
    if (typeof merchant !== 'string' || !merchant.trim() || merchant.length > 200 || merchant !== merchant.trim()) fail('LEGACY_FASTPAY_MERCHANT_REQUIRED');
    if (sandboxOnly && (!/^https:\/\/[a-z0-9]{20}\.supabase\.co$/.test(supabaseUrl) || supabaseUrl === 'https://cojchkwssmasiejcgvbk.supabase.co' ||
        publicOrigin !== 'https://email.proxopages.com')) fail('LEGACY_FASTPAY_ISOLATED_TARGET_REQUIRED');
    return { environment, baseUrl, supabaseUrl, publicOrigin, merchantReference: merchant,
      successUrl: publicOrigin + (sandboxOnly ? '/webhook/proxo-fastpay-staging/success' : '/payment/fastpay/success'),
      cancelUrl: publicOrigin + (sandboxOnly ? '/webhook/proxo-fastpay-staging/cancel' : '/payment/fastpay/cancel'),
      callbackUrl: publicOrigin + '/webhook/' + (sandboxOnly ? 'proxo-fastpay-staging' : 'fastpay') + '/ipn' };
  }
  function decoded(response) {
    if (!object(response) || response.statusCode !== 200) fail('LEGACY_FASTPAY_RPC_UNAVAILABLE');
    let body = response.body;
    if (typeof body === 'string') { if (body.length > 65536) fail('LEGACY_FASTPAY_RPC_UNAVAILABLE'); try { body=JSON.parse(body); } catch { fail('LEGACY_FASTPAY_RPC_UNAVAILABLE'); } }
    if (!object(body) || body.ok !== true) fail('LEGACY_FASTPAY_RPC_REJECTED');
    return body;
  }
  function binding(response, expected, cfg, requireJournal = true) {
    const r = decoded(response);
    if (!order(expected.orderId) || !uuid(expected.userId) || r.order_id !== expected.orderId || r.user_id !== expected.userId ||
        !uuid(r.transaction_id) || !iqd(r.amount_iqd) || r.currency !== 'IQD' || typeof r.wallet_credited !== 'boolean' ||
        expected.amountIqd !== undefined && Number(r.amount_iqd) !== Number(expected.amountIqd) ||
        expected.transactionId !== undefined && r.transaction_id !== expected.transactionId ||
        typeof r.create_authorized !== 'boolean' || typeof r.must_reconcile !== 'boolean') fail('LEGACY_FASTPAY_RECEIPT_MISMATCH');
    // Historical rows have no frozen merchant. Never silently select current
    // credentials for them; preserve the identity for explicit reconciliation.
    const paid = r.status === 'approved' && r.gateway_status === 'PAID' && r.wallet_credited === true;
    if ((requireJournal || !paid) && (r.journaled !== true || r.environment !== cfg.environment ||
        r.merchant_reference !== cfg.merchantReference || !/^[0-9a-f]{64}$/.test(r.request_hash || ''))) fail('LEGACY_FASTPAY_BINDING_REQUIRED');
    return { ...cfg, orderId:r.order_id,userId:r.user_id,transactionId:r.transaction_id,amountIqd:Number(r.amount_iqd),
      currency:r.currency,requestHash:r.request_hash,paid,tx:r,found:true };
  }
  function preparePayload(checkout, cfg) {
    if (!object(checkout) || !order(checkout.orderId) || !uuid(checkout.userId) || !iqd(checkout.billAmount) || checkout.currency !== 'IQD' ||
        !['wallet_deposit','ad_checkout'].includes(checkout.purpose) || !Number.isInteger(checkout.expiresIn) || checkout.expiresIn < 3 || checkout.expiresIn > 15 ||
        typeof checkout.note !== 'string' || checkout.note.length > 300) fail('LEGACY_FASTPAY_CHECKOUT_INVALID');
    return { p_action:'prepare',p_user_id:checkout.userId,p_order_id:checkout.orderId,p_payload:{ amount_iqd:checkout.billAmount,
      currency:'IQD',environment:cfg.environment,merchant_reference:cfg.merchantReference,expires_in:checkout.expiresIn,
      success_url:cfg.successUrl,cancel_url:cfg.cancelUrl,callback_url:cfg.callbackUrl,purpose:checkout.purpose,note:checkout.note } };
  }
  function dispatch(response, checkout, cfg) {
    const b = binding(response,{orderId:checkout.orderId,userId:checkout.userId,amountIqd:checkout.billAmount},cfg,false);
    if (b.tx.create_authorized === true && (b.tx.journaled !== true || b.tx.must_reconcile !== false || b.tx.wallet_credited ||
        b.tx.status !== 'pending' || b.tx.gateway_status !== 'CREATED' || b.tx.qr_url != null || b.tx.qr_text != null ||
        !Number.isFinite(Date.parse(b.tx.expires_at)) || Date.parse(b.tx.expires_at) <= Date.now())) fail('LEGACY_FASTPAY_DISPATCH_INVALID');
    return {...b,createAuthorized:b.tx.create_authorized,purpose:checkout.purpose,expiresIn:checkout.expiresIn};
  }
  function publicResult(b) {
    return { success:true,orderId:b.orderId,transactionId:b.transactionId,amountIqd:b.amountIqd,
      status:b.tx.status,gatewayStatus:b.tx.gateway_status,paid:b.paid,terminal:b.paid,
      recoveryRequired:!b.paid,qrUrl:b.tx.qr_url,qrText:b.tx.qr_text,expiresAt:b.tx.expires_at };
  }
  return {origin,config,decoded,binding,preparePayload,dispatch,publicResult};
}
