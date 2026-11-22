import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const read=path=>readFileSync(new URL(path,import.meta.url),'utf8');
const customer=read('../assets/js/app.js');
const admin=read('../assets/js/admin.js');
const adminApi=read('../api-handlers/admin.js');
const adminHtml=read('../exchange-admin.html');

test('customer quote reads the live tier shape with inclusive thresholds and an open-ended final bracket',()=>{
  const context=vm.createContext({});
  vm.runInContext(read('../assets/js/exchange-pricing.js'),context);
  const pricing=context.ProxoPricing;
  const rate={type:'fee_percent',value:4,tier:{brackets:[
    {upTo:1000,percent:3},{upTo:500000,percent:2},{upTo:null,percent:1}
  ]}};
  for(const [amount,percent,total] of [[1000,3,970],[1001,2,980],[500000,2,490000],[500001,1,495000]]){
    const effective=pricing.effectiveRate(rate,amount);
    assert.equal(effective.value,percent);
    assert.equal(pricing.quote(amount,effective).total,total);
  }
  const malformed={type:'fee_percent',value:4,tier:{brackets:[{upTo:1000,percent:101},{upTo:null,percent:1}]}};
  assert.throws(()=>pricing.quote(1,pricing.effectiveRate(malformed,1)),/Invalid fee percent/);
});

test('customer order history never directly deletes orders; admin deletion uses the guarded server action',()=>{
  assert.doesNotMatch(customer,/from\(['"]ex_orders['"]\)\.delete\(/);
  assert.match(adminApi,/async order_delete\(/);
  assert.match(adminApi,/db\.rpc\('ex_admin_order_delete'/);
});

test('admin edits use the server-side action and status notification choice is explicit',()=>{
  assert.match(read('../assets/js/exchange-order-manual.js'),/run\('order_update',/);
  assert.match(read('../assets/js/exchange-order-manual.js'),/id="omNotify"/);
  assert.match(read('../assets/js/exchange-order-manual.js'),/notify:notify/);
  assert.match(adminApi,/order_update/);
  assert.match(adminApi,/db\.rpc\('ex_admin_order_update_atomic'/);
  assert.match(adminApi,/p_fields:clean/);
  assert.match(adminApi,/db\.rpc\('ex_admin_order_set_status'/);
});

test('permanent delete requires typing the order code in the UI and calls the guarded delete RPC',()=>{
  const editor=read('../assets/js/exchange-order-manual.js');
  assert.match(editor,/saveDelete\(/);
  assert.match(editor,/omConfirmCode/);
  assert.match(editor,/orderCodeOf\(o\)/);
  assert.match(adminApi,/db\.rpc\('ex_admin_order_delete'/);
  assert.match(adminApi,/ORDER_HAS_FINANCIAL_RECORDS/);
});
