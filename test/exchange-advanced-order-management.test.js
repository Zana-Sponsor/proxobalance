import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const read=path=>readFileSync(new URL(path,import.meta.url),'utf8');
const hideMigration=read('../SUPABASE_EXCHANGE_CUSTOMER_ORDER_HIDES.sql');
const customer=read('../assets/js/app.js');
const admin=read('../assets/js/admin.js');
const adminApi=read('../api/admin.js');
const adminHtml=read('../exchange-admin.html');

test('customer quote reads live fee_brackets with inclusive thresholds and open-ended final rate',()=>{
  const context=vm.createContext({});
  vm.runInContext(read('../assets/js/exchange-reward-pricing.js'),context);
  const pricing=context.ProxoRewardPricing;
  const rate={type:'fee_percent',value:4,fee_brackets:[
    {max_iqd:1000,fee_percent:3},{max_iqd:500000,fee_percent:2},{max_iqd:null,fee_percent:1}
  ]};
  for(const [amount,percent,total] of [[1000,3,970],[1001,2,980],[500000,2,490000],[500001,1,495000]]){
    const effective=pricing.effectiveRate(rate,amount);
    assert.equal(effective.value,percent);
    assert.equal(pricing.quote(amount,effective,null).total,total);
  }
  const malformed={...rate,fee_brackets:[{max_iqd:1000,fee_percent:2},{max_iqd:null,fee_percent:101}]};
  assert.equal(pricing.tierPercent(malformed,1),null);
});

test('customer transaction hiding is per-user, reversible, and does not delete orders',()=>{
  assert.match(customer,/ex_order_user_hides/);
  assert.match(customer,/async function hideMyOrder/);
  assert.match(customer,/async function restoreMyOrder/);
  assert.match(hideMigration,/user_id=auth\.uid\(\)/);
  assert.match(hideMigration,/o\.id=order_id AND o\.user_id=auth\.uid\(\)/);
  assert.match(hideMigration,/order_id uuid NOT NULL REFERENCES public\.ex_orders\(id\) ON DELETE CASCADE/i);
  assert.doesNotMatch(customer,/from\(['"]ex_orders['"]\)\.delete\(/);
});

test('admin edits use deployed RPCs and status notification choice is explicit',()=>{
  assert.match(admin,/function saveOrderEdit\(/);
  assert.match(admin,/set_order_status/);
  assert.match(admin,/notify_user:!!document\.getElementById\('oeNotifyUser'\)/);
  assert.match(adminApi,/set_order_status:'approve_orders'/);
  assert.match(adminApi,/db\.rpc\('ex_admin_order_update'/);
  assert.match(adminApi,/p_fields:changes/);
  assert.match(adminApi,/db\.rpc\('ex_admin_order_set_status'/);
  assert.match(adminApi,/p_notify:notify_user/);
  assert.match(adminHtml,/id="rateFeeTiers"/);
});

test('permanent delete verifies the order code and calls the live guarded delete RPC',()=>{
  assert.match(admin,/deleteOrderPermanently\(/);
  assert.match(admin,/typed\.trim\(\)!==orderCodeOf\(order\)/);
  assert.match(adminApi,/confirm_order_code\.trim\(\)\.toUpperCase\(\)/);
  assert.match(adminApi,/db\.rpc\('ex_admin_order_delete'/);
  assert.match(adminApi,/p_mode:'permanent'/);
  assert.match(adminApi,/ORDER_HAS_FINANCIAL_RECORDS/);
  assert.match(adminApi,/error\.code==='23503'/);
});
