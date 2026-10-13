// ─────────────────────────────────────────────────────────────
// /api/notify-order  —  sends the "new order" alert to Telegram
//
// Why this exists: index.html currently ships the Telegram bot token to
// every visitor (base64 is not encryption). This moves the token into
// an environment variable and rebuilds the message from the DATABASE row,
// so a caller cannot fake amounts or spam your channel.
//
// Request:  POST /api/notify-order
//           Authorization: Bearer <supabase access_token>
//           { "order_id": "<uuid>" }
// ─────────────────────────────────────────────────────────────
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BOT_TOKEN    = process.env.TELEGRAM_BOT_TOKEN;
const CHAT_ID      = process.env.TELEGRAM_CHAT_ID;

const db = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
});

function json(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  return res.send(JSON.stringify(body));
}

async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string') { try { return JSON.parse(req.body); } catch { return {}; } }
  const chunks = [];
  for await (const c of req) chunks.push(c);
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return {}; }
}

const nf = n => Number(n || 0).toLocaleString('en-US');

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return json(res, 405, { ok: false, error: 'Method not allowed', code: 'method_not_allowed' });
  }
  if (!SUPABASE_URL || !SERVICE_KEY || !BOT_TOKEN || !CHAT_ID) {
    return json(res, 500, { ok: false, error: 'Server is not configured', code: 'missing_env' });
  }

  try {
    const header = req.headers.authorization || '';
    const token  = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
    if (!token) return json(res, 401, { ok: false, error: 'Missing Authorization header', code: 'no_token' });

    const { data: userData, error: userErr } = await db.auth.getUser(token);
    if (userErr || !userData?.user) {
      return json(res, 401, { ok: false, error: 'Invalid or expired session', code: 'invalid_token' });
    }
    const user = userData.user;

    const { order_id } = await readBody(req);
    if (!order_id) return json(res, 400, { ok: false, error: 'order_id is required', code: 'bad_input' });

    const { data: order, error } = await db.from('ex_orders').select('*').eq('id', order_id).single();
    if (error || !order) return json(res, 404, { ok: false, error: 'Order not found', code: 'not_found' });

    // You may only trigger an alert for an order that is yours.
    if (order.user_id !== user.id) {
      return json(res, 403, { ok: false, error: 'Not your order', code: 'forbidden' });
    }

    const { data: profile } = await db.from('ex_profiles')
      .select('full_name, email').eq('id', user.id).single();

    const amount = order.from_method === 'USDT'
      ? `${nf(order.amount)}$`
      : `${nf(order.amount)} IQD`;

    const caption =
      `🚀 ئۆردەر: ${order.order_code}\n` +
      `👤 کڕیار: ${profile?.full_name || profile?.email || user.email}\n` +
      `📥 لە: ${order.from_method}\n` +
      `📤 بۆ: ${order.to_method}\n` +
      `📱 ژمارە: ${order.phone}\n` +
      `💵 بڕ: ${amount}\n` +
      `💰 وەرگرتن: ${nf(Math.floor(order.total))} IQD`;

    // Telegram can fetch the receipt straight from its public storage URL,
    // so the browser never has to upload the image twice.
    const api = `https://api.telegram.org/bot${BOT_TOKEN}/`;
    const tgRes = order.receipt_url
      ? await fetch(api + 'sendPhoto', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ chat_id: CHAT_ID, photo: order.receipt_url, caption })
        })
      : await fetch(api + 'sendMessage', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ chat_id: CHAT_ID, text: caption })
        });

    if (!tgRes.ok) {
      console.error('[notify-order] telegram', tgRes.status, await tgRes.text());
      // The order itself is already saved — never fail the user's flow for this.
      return json(res, 200, { ok: true, data: { sent: false } });
    }

    return json(res, 200, { ok: true, data: { sent: true } });

  } catch (err) {
    console.error('[api/notify-order]', err);
    return json(res, 500, { ok: false, error: 'Internal server error', code: 'server_error' });
  }
}
