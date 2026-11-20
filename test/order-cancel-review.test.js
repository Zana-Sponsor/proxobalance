import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// v56: the customer cancels a waiting order; "under review" stops that; repeat an exchange;
// the admins get a WhatsApp message when an order waits 15 minutes.
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const sql = read('supabase/migrations/20261116001920_order_cancel_review_alerts.sql');
const REVIEW = 'لەژێر پێداچوونەوەدایە', CANCELLED = 'هەڵوەشێنرایەوە';

test('database: a cancel sends no WhatsApp message; a balance order returns its money at once', () => {
  assert.match(sql, /'چاوەڕوانە', 'لەژێر پێداچوونەوەدایە', 'پێویستی بە ڕاستکردنەوەیە', 'ڕاستکراوەتەوە',\n  'پەسەندکرا', 'ڕەتکرا', 'هەڵوەشێنرایەوە'/);
  // only the owner, never while under review, never twice
  assert.match(sql, /where id = p_order and user_id = v_uid and user_deleted_at is null for update;/);
  assert.match(sql, /if o\.status = 'لەژێر پێداچوونەوەدایە' then raise exception 'ORDER_UNDER_REVIEW'/);
  assert.match(sql, /if o\.status not in \('چاوەڕوانە', 'پێویستی بە ڕاستکردنەوەیە', 'ڕاستکراوەتەوە'\)/);
  // no status notice for the customer's own cancel; WhatsApp is sent only for approved / rejected
  assert.match(sql, /perform set_config\('ex_admin\.silent', o\.id::text, true\);\n  update public\.ex_orders set status = 'هەڵوەشێنرایەوە'/);
  assert.doesNotMatch(sql, /ex_wa_queue_order_approved|order_cancelled/);
  // balance order: the ledger gets the amount back, recorded as a customer cancel
  assert.match(sql, /public\.ex_balance_post\(o\.user_id, v_amt, 0, 'verified_refund', 'refund:' \|\| o\.id::text,/);
  assert.match(sql, /values \(o\.id, o\.user_id, v_amt, null, v_ref, v_note, v_uid, true, false, v_journal, 'customer_cancel'\)/);
  assert.match(sql, /grant execute on function public\.ex_order_cancel\(uuid\) to authenticated, service_role;/);
  // a cancelled wallet order stays cancelled when the admin returns its amount
  assert.match(sql, /if v_order\.status<>'هەڵوەشێنرایەوە' then\n   update public\.ex_orders set status='ڕەتکرا'/);
  assert.doesNotMatch(sql, /ex_rates|rate_value/);
});

test('database: under review only from waiting; approval accepts it; the admin message after 15 minutes', () => {
  assert.match(sql, /if o\.status not in \('چاوەڕوانە', 'ڕاستکراوەتەوە'\) then raise exception 'ORDER_NOT_REVIEWABLE'/);
  assert.match(sql, /v_new constant text := \$q\$if o\.status not in \('چاوەڕوانە','ڕاستکراوەتەوە','لەژێر پێداچوونەوەدایە'\) or o\.status is null\$q\$;/);
  assert.match(sql, /coalesce\(x\.correction_responded_at, x\.created_at\) <= now\(\) - interval '15 minutes'/);
  assert.match(sql, /where x\.status in \('چاوەڕوانە', 'ڕاستکراوەتەوە'\)/);
  assert.match(sql, /not exists \(select 1 from public\.ex_order_admin_alerts a where a\.order_id = x\.id\)/);
  assert.match(sql, /'button', jsonb_build_array\(v_code\), 'order_code', v_code\)/);
  assert.match(sql, /values \('admin_order_waiting', null, 'proxo_admin_order_waiting', false, now\(\)\)/);
  assert.match(sql, /or \(t\.template_id is null and t\.template_name = x\.item ->> 'name'/);
  assert.match(sql, /perform cron\.schedule\('ex-admin-order-alerts', '\* \* \* \* \*', 'select public\.ex_admin_order_alerts_tick\(\)'\);/);
  assert.match(sql, /revoke all on public\.ex_admin_alert_phones from anon, authenticated;/);
});

test('admin API: review, return of a cancelled order and the admin numbers', () => {
  const api = read('api-handlers/admin.js');
  assert.match(api, /const REVIEWABLE_ORDER_STATUSES = new Set\(\[STATUS_PENDING, STATUS_CORRECTED, STATUS_REVIEW\]\);/);
  assert.match(api, /order_review:'approve_orders',order_cancel_refund:'refunds',/);
  assert.match(api, /'admin_alert_phones','admin_alert_phone_save','admin_alert_phone_delete'\]\.includes\(action\)&&profile\.role!=='super_admin'/);
  assert.match(api, /if\(order\.status!==STATUS_CANCELLED\|\|order\.balance_refunded_at\|\|order\.from_method==='AccountBalance'\)/);
  assert.match(api, /p_verification_reference:'cancel:'\+id,/);
  assert.match(api, /if\(!\/\^07\\d\{9\}\$\/\.test\(local\)\)throw \{status:400,code:'phone_invalid'/);
  for (const s of ['چاوەڕوانە', 'ڕاستکراوەتەوە']) assert.match(read('api-handlers/notify-order.js'), new RegExp(s));
  assert.match(read('api-handlers/notify-order.js'), new RegExp("'" + REVIEW + "'"));
});

// the customer app's status words and the cancel rule, run on their own
function customer() {
  const app = read('assets/js/app.js');
  const part = (start, endMark) => { const a = app.indexOf(start); const b = app.indexOf(endMark, a); return app.slice(a, b); };
  const code = part('const TX_STATE = {', '\nfunction txAmount(')
    + '\n' + part('const TX_CANCELLABLE=', '\nlet _cancelOrderBusy');
  const ctx = vm.createContext({});
  vm.runInContext(code + '\nthis.txStateOf=txStateOf;this.txLabelOf=txLabelOf;this.orderCancellable=orderCancellable;', ctx);
  return ctx;
}

test('customer app: who may cancel, and how the new statuses read', () => {
  const { txStateOf, txLabelOf, orderCancellable } = customer();
  const base = { from_method: 'FIB', to_method: 'FastPay', receipt_url: 'https://x/r.jpg' };
  assert.equal(orderCancellable({ ...base, status: 'چاوەڕوانە' }), true);
  assert.equal(orderCancellable({ ...base, status: 'پێویستی بە ڕاستکردنەوەیە' }), true);
  assert.equal(orderCancellable({ ...base, status: REVIEW }), false);
  assert.equal(orderCancellable({ ...base, status: 'پەسەندکرا' }), false);
  assert.equal(orderCancellable({ ...base, status: CANCELLED }), false);
  assert.equal(orderCancellable({ ...base, status: 'چاوەڕوانە', receipt_url: null }), false);
  assert.equal(orderCancellable({ ...base, status: 'چاوەڕوانە', from_method: 'AccountBalance', receipt_url: null }), true);
  assert.equal(orderCancellable({ ...base, status: 'چاوەڕوانە', to_method: 'USDT' }), false);
  assert.equal(txStateOf({ status: REVIEW }).key, 'pending');
  assert.equal(txLabelOf({ status: REVIEW }), 'لەژێر پێداچوونەوە');
  assert.equal(txStateOf({ status: CANCELLED, balance_refunded_at: '2026-11-16' }).key, 'cancelled');
  assert.equal(txLabelOf({ status: CANCELLED, balance_refunded_at: '2026-11-16' }), CANCELLED);
  const app = read('assets/js/app.js');
  assert.match(app, /sb\.rpc\('ex_order_cancel',\{p_order:String\(orderId\)\}\)/);
  assert.match(app, /if\(orderCancellable\(o\)\) html\+='<button type="button" class="tf-ghost is-danger" onclick="confirmCancelOrder/);
  assert.match(app, /onclick="repeatOrder\(\\''\+oid\+'\\'\)"/);
  assert.match(app, /if\(phone && o\.phone\)\{ phone\.value=String\(o\.phone\); clearFieldError\('userPhone'\); \}/);
  assert.match(read('index.html'), /data-status="cancelled" onclick="setTxStatus\('cancelled', this\)">هەڵوەشاوە/);
});

test('panel: under review button, one-click return of a cancelled order, the admin numbers, the order link', () => {
  const admin = read('assets/js/admin.js'), html = read('exchange-admin.html'), wa = read('assets/js/exchange-whatsapp-admin.js');
  assert.match(admin, /const REVIEW_START_STATUSES=new Set\(\[STATUS_PENDING,STATUS_CORRECTED\]\);/);
  assert.match(admin, /await adminApiRequest\('order_review',\{order_id:id,on:on!==false\}\)/);
  assert.match(admin, /await adminApiRequest\('order_cancel_refund',\{order_id:id\}\)/);
  assert.match(admin, /if\(!\/\^P\[A-Z0-9\]\{11\}\$\/\.test\(code\)\) return;/);
  assert.match(admin, /goPage\('dashboard'\);\n  openOrderFromLink\(\);/);
  assert.match(html, /data-of="لەژێر پێداچوونەوەدایە"/);
  assert.match(html, /data-of="هەڵوەشێنرایەوە"/);
  assert.match(html, /<div id="waAlertPhones"><\/div>/);
  assert.match(wa, /await adminApiRequest\('admin_alert_phone_save', body\);/);
  assert.match(read('assets/js/exchange-order-manual.js'), /'لەژێر پێداچوونەوەدایە'/);
});

test('database: a template made again in Wevlix is found by its name; a missing one stops sending', () => {
  const sync = read('supabase/migrations/20261120111111_whatsapp_template_sync_by_name.sql');
  assert.match(sync, /\(select i\.item from items i where i\.item ->> 'id' = t\.template_id limit 1\),/);
  assert.match(sync, /where i\.item ->> 'name' = t\.template_name/);
  assert.match(sync, /if jsonb_array_length\(v_list\) between 1 and 49 then\n    update public\.ex_whatsapp_templates t set\n      active = false, meta_status = null,/);
});
