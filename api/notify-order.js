import { json, readJson, serviceFetch, withSecurity } from './_lib/security.js';

const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));

export default withSecurity(async (req, res, { user }) => {
  if (!process.env.TELEGRAM_BOT_TOKEN || !process.env.TELEGRAM_CHAT_ID) {
    return json(res, 202, { ok: true, delivered: false });
  }
  const body = await readJson(req, 8 * 1024);
  const orderId = String(body.order_id || '').slice(0, 80);
  const rows = await serviceFetch(
    `/rest/v1/ex_orders?id=eq.${encodeURIComponent(orderId)}&user_id=eq.${encodeURIComponent(user.id)}&select=id,order_code,from_method,to_method,amount,total,phone,status&limit=1`
  );
  const order = rows?.[0];
  if (!order) return json(res, 404, { error: 'Not Found' });

  const message = [
    '<b>New Exchange Order</b>',
    `ID: <code>${esc(order.order_code || order.id)}</code>`,
    `Route: ${esc(order.from_method)} → ${esc(order.to_method)}`,
    `Amount: ${esc(order.amount)}`,
    `Total: ${esc(order.total)} IQD`,
    `Phone: <code>${esc(order.phone)}</code>`,
    `Status: ${esc(order.status)}`
  ].join('\n');
  const telegram = await fetch(`https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: process.env.TELEGRAM_CHAT_ID,
      message_thread_id: process.env.TELEGRAM_THREAD_ID || undefined,
      text: message,
      parse_mode: 'HTML',
      disable_web_page_preview: true
    })
  });
  if (!telegram.ok) return json(res, 502, { error: 'Notification delivery failed' });
  return json(res, 200, { ok: true, delivered: true });
}, { auth: 'required', methods: ['POST'] });
