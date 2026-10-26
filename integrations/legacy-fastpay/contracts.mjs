/** Pure, self-contained checks embedded in the reviewed n8n patch with
 * legacyProviderContract.toString(). No network, credentials or ledger writes.
 * A callback is only an order hint: never pass its receipt fields as evidence.
 */
export function legacyProviderContract() {
  const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const fail = code => { const error = new Error(code); error.code = code; throw error; };
  const reference = value => typeof value === 'string' && /^[A-Za-z0-9_.:-]{1,128}$/.test(value);
  const order = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,32}$/.test(value) && !/^AP[0-9a-f]{28}$/i.test(value);
  const iqd = value => ['string', 'number'].includes(typeof value) && /^\d+(?:\.0{1,6})?$/.test(String(value)) && Number.isSafeInteger(Number(value)) && Number(value) >= 1000;
  const bases = ['https://qr.fast-pay.iq', 'https://staging-qr.fast-pay.iq'];
  function expectedPayment(expected, provider = true) {
    if (!object(expected) || !order(expected.orderId) || !iqd(expected.amountIqd) || expected.currency !== 'IQD' ||
        (provider || expected.baseUrl !== undefined) && !bases.includes(expected.baseUrl)) fail('FASTPAY_EXPECTED_PAYMENT_INVALID');
    return expected;
  }
  function decoded(response) {
    if (!object(response) || response.statusCode !== 200 || !Object.prototype.hasOwnProperty.call(response, 'body')) fail('FASTPAY_RESPONSE_INVALID');
    let body = response.body;
    if (typeof body === 'string') {
      if (body.length > 65536) fail('FASTPAY_RESPONSE_INVALID');
      try { body = JSON.parse(body); } catch { fail('FASTPAY_RESPONSE_INVALID'); }
    }
    if (!object(body)) fail('FASTPAY_RESPONSE_INVALID');
    return body;
  }
  function providerData(response) {
    const body = decoded(response);
    if (body.code !== 200 || !Array.isArray(body.errors) || body.errors.length !== 0 || !object(body.data)) fail('FASTPAY_RESPONSE_INVALID');
    return body.data;
  }
  function boundOrder(data, expected) {
    if (data.merchant_order_id !== expected.orderId || data.order_id != null && data.order_id !== expected.orderId) fail('FASTPAY_VERIFICATION_MISMATCH');
  }
  function amountCurrency(data, expected, required) {
    if ((required || data.received_amount !== undefined) && (!iqd(data.received_amount) || Number(data.received_amount) !== Number(expected.amountIqd)) ||
        (required || data.currency !== undefined) && data.currency !== expected.currency) fail('FASTPAY_VERIFICATION_MISMATCH');
  }
  function https(value, originOnly = false) {
    if (typeof value !== 'string' || !value || value.length > 4096 || /[\x00-\x20\x7f\\]/.test(value)) return null;
    // A deliberately narrow HTTPS form avoids Node-only imports or assuming
    // that the Code sandbox exposes the global URL constructor. No credentials,
    // ports, encoded hostnames, fragments, IP literals or backslashes qualify.
    const match = /^https:\/\/([^/?#]+)([/?][^#]*)?$/.exec(value);
    if (!match || !/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$/i.test(match[1]) ||
        /\.(?:localhost|local|internal|invalid|test)$/i.test(match[1])) return null;
    const suffix = match[2] || '/';
    if (originOnly && suffix !== '/') return null;
    const origin = 'https://' + match[1].toLowerCase();
    return { origin, href: origin + (suffix.startsWith('?') ? '/' : '') + suffix };
  }
  function qr(response, expected) {
    expectedPayment(expected);
    const data = providerData(response);
    // Allowed origins are reviewed workflow configuration, never webhook input.
    const origins = expected.qrOrigins === undefined ? [expected.baseUrl] : expected.qrOrigins;
    if (!Array.isArray(origins) || !origins.length) fail('FASTPAY_QR_INVALID');
    const allowed = origins.map(value => https(value, true));
    const url = https(data.qrUrl);
    if (allowed.some(value => !value) || !url || !allowed.some(value => value.origin === url.origin) ||
        typeof data.qrText !== 'string' || !data.qrText.trim() || data.qrText.length > 4096 || /[\x00-\x1f\x7f]/.test(data.qrText)) fail('FASTPAY_QR_INVALID');
    if (data.merchant_order_id != null && data.merchant_order_id !== expected.orderId || data.order_id != null && data.order_id !== expected.orderId) fail('FASTPAY_VERIFICATION_MISMATCH');
    return { ok: true, orderId: expected.orderId, qrUrl: url.href, qrText: data.qrText };
  }
  function status(response, expected) {
    expectedPayment(expected);
    const data = providerData(response);
    boundOrder(data, expected);
    if (!['PAID', 'UNPAID', 'DECLINED'].includes(data.payment_status)) fail('FASTPAY_VERIFICATION_MISMATCH');
    amountCurrency(data, expected, false);
    if (data.payment_status === 'PAID' && !reference(data.gw_transaction_id) ||
        data.gw_transaction_id !== undefined && data.gw_transaction_id !== null && !reference(data.gw_transaction_id)) fail('FASTPAY_VERIFICATION_MISMATCH');
    return { ok: true, orderId: data.merchant_order_id, paymentStatus: data.payment_status,
      ...(data.gw_transaction_id != null ? { gwTransactionId: data.gw_transaction_id } : {}),
      ...(data.received_amount !== undefined ? { receivedAmount: Number(data.received_amount) } : {}),
      ...(data.currency !== undefined ? { currency: data.currency } : {}) };
  }
  function validate(response, expected) {
    expectedPayment(expected);
    const data = providerData(response);
    boundOrder(data, expected);
    amountCurrency(data, expected, true);
    if (data.status !== 'success' || !reference(data.gw_transaction_id) ||
        expected.gwTransactionId !== undefined && (!reference(expected.gwTransactionId) || data.gw_transaction_id !== expected.gwTransactionId)) fail('FASTPAY_VERIFICATION_MISMATCH');
    return { ok: true, verified: true, orderId: data.merchant_order_id, paymentStatus: 'PAID',
      gwTransactionId: data.gw_transaction_id, receivedAmount: Number(data.received_amount), currency: data.currency };
  }
  function credited(response, expected) {
    expectedPayment(expected, false);
    if (!reference(expected.transactionId) || !reference(expected.userId)) fail('FASTPAY_EXPECTED_PAYMENT_INVALID');
    const body = decoded(response);
    if (body.ok !== true || body.status !== 'approved' || body.gateway_status !== 'PAID' ||
        body.transaction_id !== expected.transactionId || body.user_id !== expected.userId ||
        typeof body.duplicate !== 'boolean' || body.order_id !== undefined && body.order_id !== expected.orderId ||
        body.amount_iqd !== undefined && (!iqd(body.amount_iqd) || Number(body.amount_iqd) !== Number(expected.amountIqd)) ||
        body.currency !== undefined && body.currency !== expected.currency ||
        body.wallet_credited !== undefined && body.wallet_credited !== true) fail('FASTPAY_CREDIT_NOT_CONFIRMED');
    return { ok: true, paid: true, terminal: true, orderId: expected.orderId, transactionId: body.transaction_id,
      userId: body.user_id, status: body.status, gatewayStatus: body.gateway_status, duplicate: body.duplicate };
  }
  return { qr, status, validate, credited };
}
