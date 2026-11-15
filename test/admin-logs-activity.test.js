import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

// v51: a real error log, user activity, WhatsApp notifications for admins.
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const sql = read('supabase/migrations/20261115050000_real_logs_activity_whatsapp_admin.sql');
const tracker = read('assets/js/activity-tracker.js');
const index = read('index.html');
const adminHtml = read('exchange-admin.html');
const adminJs = read('assets/js/admin.js');

process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-test-key';
const rows = [];
globalThis.fetch = async (url, options = {}) => {
  const u = String(url);
  const reply = (status, body) => new Response(body === undefined ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
  if (u.endsWith('/auth/v1/user')) return reply(200, { id: '44444444-4444-4444-8444-444444444444', email: 'c@gmail.com' });
  if (u.includes('/rpc/')) return reply(200, [{ banned: false }]);
  if (u.includes('/rest/v1/ex_error_logs')) {
    if (options.method === 'POST') { rows.push(JSON.parse(options.body)); return reply(201, [{ id: 'e' + rows.length }]); }
    return reply(200, []);
  }
  return reply(200, null);
};
const { default: errorLog } = await import('../api-handlers/error-log.js');
async function report(body) {
  const res = { statusCode: 0, headers: {}, setHeader(k, v) { this.headers[k] = v; }, end(text) { this.body = text ? JSON.parse(text) : null; } };
  await errorLog({ method: 'POST', url: '/api/error-log', headers: { authorization: 'Bearer t', 'user-agent': 'test' }, body, socket: { remoteAddress: '1.2.3.4' } }, res);
  return { status: res.statusCode, ...res.body };
}

test('browser noise is dropped; the visitor\'s own connection and refused requests are warnings, not errors', async () => {
  for (const message of ['Script error.', 'Error invoking postMessage: Java object is gone', "Can't find variable: SCDynimacBridge"]) {
    const r = await report({ operation: 'client_runtime', message, code: message });
    assert.equal(r.status, 202); assert.equal(r.ignored, true, message);
  }
  assert.equal(rows.length, 0);
  await report({ operation: 'kyc_status', message: 'TypeError: Failed to fetch', code: 'TypeError: Failed to fetch' });
  await report({ operation: 'order_submission', message: 'This receipt was already used', code: 'RECEIPT_ALREADY_USED', status: 409 });
  await report({ operation: 'order_submission', message: 'Cannot read properties of null', code: 'TypeError' });
  assert.deepEqual(rows.map(r => r.severity), ['warning', 'warning', 'error']);
});

test('database: WhatsApp failures become log rows, a stuck queue is critical, activity is capped and private', () => {
  assert.match(sql, /check \(source in \('client', 'server', 'whatsapp'\)\)/);
  assert.match(sql, /after insert or update of status on public\.ex_whatsapp_messages/);
  assert.match(sql, /'wa:' \|\| new\.id::text, 'whatsapp', 'error', 'whatsapp_notification', 'WHATSAPP_NOT_DELIVERED'/);
  assert.match(sql, /update public\.ex_error_logs set resolved_at = now\(\)\s+where dedupe_key = 'wa:' \|\| new\.id::text/);
  assert.match(sql, /'wa-queue-stuck', 'whatsapp', 'critical', 'whatsapp_queue', 'WHATSAPP_QUEUE_STUCK'/);
  assert.match(sql, /cron\.schedule\('ex-whatsapp-queue-watch', '\*\/10 \* \* \* \*'/);
  // seconds can never run ahead of the clock
  assert.match(sql, /v_sec\s+integer := greatest\(0, least\(coalesce\(p_seconds, 0\), 120\)\);/);
  assert.match(sql, /v_sec := least\(v_sec, greatest\(0, ceil\(extract\(epoch from now\(\) - v_prev\.last_seen_at\)\)::integer \+ 5\)\);/);
  // only the ping is callable from the browser; tables are closed
  assert.match(sql, /grant execute on function public\.ex_activity_ping\(uuid, text, integer, text\) to authenticated, service_role;/);
  for (const fn of ['ex_admin_activity_overview\\(integer\\)', 'ex_admin_activity_user\\(uuid, integer\\)', 'ex_admin_whatsapp_subscribers\\(\\)', 'ex_admin_whatsapp_set\\(uuid, boolean, uuid\\)'])
    assert.match(sql, new RegExp(`revoke all on function public\\.${fn} from public, anon, authenticated;`), fn);
  assert.match(sql, /alter table public\.ex_user_activity enable row level security;/);
  assert.match(sql, /revoke all on public\.ex_user_activity, public\.ex_user_presence from anon, authenticated;/);
  assert.match(sql, /delete from public\.ex_user_activity where day < \(now\(\) at time zone 'Asia\/Baghdad'\)::date - 90/);
  // WhatsApp on again only with a verified number; who changed it is kept
  assert.match(sql, /if p_enabled and v_phone is null then raise exception 'phone_not_verified'/);
  assert.match(sql, /insert into public\.ex_whatsapp_consent_log \(user_id, enabled, phone, changed_by\)/);
});

test('the customer app counts only visible time, at most one call every 30 seconds', () => {
  assert.match(index, /<script src="\/assets\/js\/app\.js\?v=\d+"><\/script>\n<script src="\/assets\/js\/activity-tracker\.js\?v=1"><\/script>/);
  assert.match(tracker, /\/rest\/v1\/rpc\/ex_activity_ping/);
  assert.match(tracker, /var BEAT_MS = 30 \* 1000;/);
  assert.match(tracker, /if \(visible\(\) && Date\.now\(\) - lastBeat >= BEAT_MS\) flush\(false\);/);
  assert.match(tracker, /flush\(true\);\s+\/\/ leaving: send while the page can still talk/);
  assert.match(tracker, /keepalive: !!keepalive/);
});

test('panel: titles in plain words, categories, activity page and WhatsApp on/off', () => {
  assert.match(adminJs, /whatsapp_code:'کۆدی دڵنیایی بە واتسئاپ نەنێردرا'/);
  assert.match(adminJs, /email_code:'کۆدی دڵنیایی بە ئیمەیڵ نەنێردرا'/);
  assert.match(adminJs, /whatsapp_notification:'ئاگاداری واتسئاپی داواکاری نەگەیشتە کڕیار'/);
  assert.match(adminHtml, /onclick="setErrorCategory\('codes',this\)">کۆدی دڵنیایی</);
  assert.match(adminHtml, /<div class="pg" id="pgActivity">/);
  assert.match(adminHtml, /onclick="goPage\('activity'\)"/);
  assert.match(adminHtml, /<div data-super-admin-only>\s*<div class="sec-hdr wa-subs-note">/);
  assert.match(adminHtml, /assets\/js\/exchange-activity-admin\.js\?v=1/);
  assert.match(read('assets/js/exchange-whatsapp-admin.js'), /adminApiRequest\('whatsapp_set', \{ user_id: userId, enabled \}\)/);
});
