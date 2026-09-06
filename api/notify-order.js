import { json, readJson, serviceFetch, withSecurity } from './_lib/security.js';

const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));

const fmt = value => {
  const n = Number(value);
  return Number.isFinite(n) ? n.toLocaleString('en-US') : String(value ?? '');
};

// Telegram answers 200 with {"ok":false,"description":"..."} for some failures,
// so the HTTP status alone is not enough to know whether it was delivered.
async function telegram(method, payload) {
  try {
    const response = await fetch(
      `https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/${method}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      }
    );
    let data = null;
    try { data = await response.json(); } catch { /* non-JSON body */ }
    return { ok: response.ok && data?.ok === true, description: data?.description || null };
  } catch (error) {
    return { ok: false, description: error.message };
  }
}

export default withSecurity(async (req, res, { user }) => {
  if (!process.env.TELEGRAM_BOT_TOKEN || !process.env.TELEGRAM_CHAT_ID) {
    return json(res, 202, { ok: true, delivered: false, reason: 'not_configured' });
  }

  const body = await readJson(req, 8 * 1024);
  const orderId = String(body.order_id || '').slice(0, 80);

  // receipt_url added — without it there was nothing to attach.
  const rows = await serviceFetch(
    `/rest/v1/ex_orders?id=eq.${encodeURIComponent(orderId)}&user_id=eq.${encodeURIComponent(user.id)}` +
    `&select=id,order_code,from_method,to_method,amount,total,phone,status,receipt_url&limit=1`
  );
  const order = rows?.[0];
  if (!order) return json(res, 404, { error: 'Not Found' });

  const caption = [
    '<b>New Exchange Order</b>',
    `ID: <code>${esc(order.order_code || order.id)}</code>`,
    `Route: ${esc(order.from_method)} → ${esc(order.to_method)}`,
    `Amount: ${esc(fmt(order.amount))} IQD`,
    `Total: ${esc(fmt(order.total))} IQD`,
    `Phone: <code>${esc(order.phone)}</code>`,
    `Status: ${esc(order.status)}`
  ].join('\n');

  const threadId = process.env.TELEGRAM_THREAD_ID
    ? Number(process.env.TELEGRAM_THREAD_ID)
    : undefined;

  // Preferred path: the receipt itself, with the details as its caption.
  // Telegram fetches the URL server-side, which works because the receipts
  // bucket is public. Captions cap at 1024 characters — this is far under.
  if (order.receipt_url) {
    const photo = await telegram('sendPhoto', {
      chat_id: process.env.TELEGRAM_CHAT_ID,
      message_thread_id: threadId,
      photo: order.receipt_url,
      caption,
      parse_mode: 'HTML'
    });
    if (photo.ok) {
      return json(res, 200, { ok: true, delivered: true, with_photo: true });
    }
    // Telegram could not fetch or render the file (oversized, unreachable,
    // unsupported format). Do not lose the order — fall through to text and
    // include the link so the receipt is still one tap away.
  }

  const text = order.receipt_url
    ? `${caption}\n\n<a href="${esc(order.receipt_url)}">وەسڵ / Receipt</a>`
    : caption;

  const sent = await telegram('sendMessage', {
    chat_id: process.env.TELEGRAM_CHAT_ID,
    message_thread_id: threadId,
    text,
    parse_mode: 'HTML',
    disable_web_page_preview: false
  });

  if (!sent.ok) {
    return json(res, 502, { error: 'Notification delivery failed', detail: sent.description });
  }
  return json(res, 200, { ok: true, delivered: true, with_photo: false });
}, { auth: 'required', methods: ['POST'] });
