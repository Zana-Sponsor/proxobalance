import { json, readJson, serviceFetch, withSecurity } from './_lib/security.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ORDER_FIELDS = [
  'id', 'user_id', 'order_code', 'from_method', 'to_method', 'amount', 'total', 'fee',
  'reward_discount_iqd', 'reward_original_fee_iqd', 'payout_settlement_id', 'payout_iqd', 'payout_rounding_iqd',
  'shortfall_refunded_iqd', 'balance_refund_case_id', 'balance_refunded_at',
  'status', 'phone', 'extra_info', 'admin_note', 'receipt_url', 'payout_receipt_url',
  'created_at', 'updated_at', 'decided_at'
].join(',');

export default withSecurity(async (req, res, { user }) => {
  const body = await readJson(req);
  const token = typeof body?.secure_token === 'string' ? body.secure_token.trim() : '';
  if (!UUID_RE.test(token)) return json(res, 400, { error: 'Invalid transaction link' });

  const rows = await serviceFetch(
    `/rest/v1/ex_orders?secure_token=eq.${encodeURIComponent(token)}` +
    `&user_id=eq.${encodeURIComponent(user.id)}&select=${ORDER_FIELDS}&limit=1`
  );
  const order = Array.isArray(rows) ? rows[0] : null;
  // Missing and non-owned tokens intentionally share the same response.
  if (!order) return json(res, 404, { error: 'Transaction not found' });

  const feedbackRows = await serviceFetch(
    `/rest/v1/ex_order_feedback?order_id=eq.${encodeURIComponent(order.id)}` +
    `&user_id=eq.${encodeURIComponent(user.id)}&select=order_id,rating,comment,created_at&limit=1`
  );
  order.feedback = Array.isArray(feedbackRows) ? (feedbackRows[0] || null) : null;
  if (order.balance_refund_case_id) {
    const refundRows = await serviceFetch(
      `/rest/v1/ex_refund_cases?id=eq.${encodeURIComponent(order.balance_refund_case_id)}` +
      `&order_id=eq.${encodeURIComponent(order.id)}&user_id=eq.${encodeURIComponent(user.id)}` +
      '&select=amount_iqd&limit=1'
    );
    order.refund_case_amount_iqd = Array.isArray(refundRows) ? (refundRows[0]?.amount_iqd ?? null) : null;
  }
  order.status_updated_at = order.decided_at || order.updated_at || order.created_at;
  return json(res, 200, { order });
}, { auth: 'required', methods: ['POST'], event: 'transaction_summary_lookup', autoLog: false });
