import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const api=readFileSync(new URL('../api-handlers/admin.js',import.meta.url),'utf8');
const sql=readFileSync(new URL('../supabase/migrations/20261123010000_atomic_admin_order_amount_correction.sql',import.meta.url),'utf8');

test('order_update is explicitly restricted to active super_admins and validates retry/revision inputs',()=>{
  assert.match(api,/\['set_ban','account_set_password','account_contact_update','order_update'\][\s\S]*profile\.role!=='super_admin'/);
  assert.match(api,/ctx\.profile\?\.role!=='super_admin'/);
  assert.match(api,/isUuid\(request_key\)/);
  assert.match(api,/validApprovalTimestamp\(expected_updated_at\)/);
  assert.match(api,/ex_admin_order_update_atomic/);
});
test('amount correction uses old minus new: reductions credit; increases debit',()=>{
  assert.match(sql,/v_delta\s*:=\s*o\.amount::bigint\s*-\s*\(p_fields->>'amount'\)::bigint/);
  assert.match(sql,/case when v_delta>0 then 'admin_refund' else 'admin_debit' end/);
  assert.match(sql,/ex_balance_post\(o\.user_id,v_delta,0/);
  assert.match(sql,/select available_iqd into v_balance/);
  assert.match(sql,/balance_after_iqd/);
});
test('same request key is payload-bound; stale revisions and protected financial states reject',()=>{
  assert.match(sql,/v_prior\.payload is distinct from v_payload/);
  assert.match(sql,/request_key uuid not null unique/);
  assert.match(sql,/o\.updated_at is distinct from p_expected_updated_at/);
  assert.match(sql,/balance_refunded_at is not null/);
  assert.match(sql,/ex_order_shortfall_refunds/);
  assert.match(sql,/payout_settlement_id is not null/);
  assert.match(sql,/EXTERNAL_ORDER_FINANCIAL_EDIT_DENIED/);
});
test('migration compensates by append-only posting and contains one transactional function body',()=>{
  assert.match(sql,/ex_balance_deny_journal_mutation\(\)/);
  assert.match(sql,/create or replace function public\.ex_admin_order_update_atomic/);
  assert.match(sql,/insert into public\.ex_order_amount_corrections/);
  assert.match(sql,/insert into public\.ex_order_admin_actions/);
  assert.match(sql,/insert into public\.ex_admin_audit_log/);
  assert.match(sql,/revoke all on function public\.ex_admin_order_update_atomic[\s\S]*grant execute[\s\S]*to service_role/);
  assert.doesNotMatch(sql,/update\s+public\.ex_balance_journal|delete\s+from\s+public\.ex_balance_journal/i);
});

test('live AccountBalance guard remains intact except for order/actor-bound active super-admin corrections',()=>{
  assert.match(sql,/create or replace function public\.ex_balance_order_guard\(\)/);
  assert.match(sql,/ex_balance\.order_authorized/);
  assert.match(sql,/ex_order_correction\.order_id/);
  assert.match(sql,/ex_order_correction\.admin_id/);
  assert.match(sql,/p\.role='super_admin' and p\.is_admin and not coalesce\(p\.is_banned,false\)/);
  assert.match(sql,/BALANCE_ORDER_FINANCIALS_IMMUTABLE/);
});
