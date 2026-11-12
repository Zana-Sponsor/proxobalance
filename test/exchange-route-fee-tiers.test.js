import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {effectiveRateValue, calculateTotal} from '../api-handlers/orders.js';

const legacyMigration=readFileSync(new URL('../SUPABASE_EXCHANGE_ROUTE_FEE_TIERS.sql',import.meta.url),'utf8');
const hideMigration=readFileSync(new URL('../SUPABASE_EXCHANGE_CUSTOMER_ORDER_HIDES.sql',import.meta.url),'utf8');
const ordersApi=readFileSync(new URL('../api-handlers/orders.js',import.meta.url),'utf8');

test('an unconfigured route keeps its existing fee unchanged',()=>{
  const route={from_method:'FIB',to_method:'FastPay',rate_type:'fee_percent',rate_value:'2.5',fee_tier_enabled:false};
  assert.equal(effectiveRateValue(route,700000),2.5);
  assert.equal(calculateTotal(700000,route),682500);
});

test('a configured legacy route uses the first tier through the inclusive boundary',()=>{
  const route={from_method:'FIB',to_method:'FastPay',rate_type:'fee_percent',rate_value:'2.5',fee_tier_enabled:true,fee_tier_limit_iqd:'500000',fee_tier_low_percent:'2',fee_tier_high_percent:'1'};
  assert.equal(effectiveRateValue(route,500000),2);
  assert.equal(calculateTotal(500000,route),490000);
  assert.equal(effectiveRateValue(route,500001),1);
  assert.equal(Math.floor(calculateTotal(500001,route)),495000);
});

test('live fee_brackets supports multiple inclusive ranges and an open-ended final range',()=>{
  const route={from_method:'FIB',to_method:'FastPay',rate_type:'fee_percent',rate_value:4,fee_brackets:[
    {max_iqd:1000,fee_percent:3},{max_iqd:500000,fee_percent:2},{max_iqd:null,fee_percent:1}
  ]};
  assert.equal(effectiveRateValue(route,1000),3);
  assert.equal(effectiveRateValue(route,1001),2);
  assert.equal(effectiveRateValue(route,500000),2);
  assert.equal(effectiveRateValue(route,500001),1);
  assert.equal(calculateTotal(1000,route),970);
  assert.equal(calculateTotal(500001,route),495000.99);
  assert.match(ordersApi,/select=from_method,to_method,rate_type,rate_value,fee_brackets,/);
});

test('fee-like multiplier routes use tier percentages without changing stored multiplier',()=>{
  const route={from_method:'FIB',to_method:'Asiacell',rate_type:'multiplier',rate_value:0.85,fee_tier_enabled:true,fee_tier_limit_iqd:500000,fee_tier_low_percent:2,fee_tier_high_percent:1};
  assert.equal(effectiveRateValue(route,10000),0.98);
  assert.equal(calculateTotal(10000,route),9800);
  assert.equal(route.rate_value,0.85);
});

test('invalid fee configuration fails closed, including malformed later brackets',()=>{
  const base={rate_type:'fee_percent',fee_tier_enabled:true,fee_tier_limit_iqd:500000,fee_tier_low_percent:2,fee_tier_high_percent:1};
  for(const route of [
    {...base,fee_tier_low_percent:101},
    {...base,fee_tier_limit_iqd:0},
    {...base,fee_tier_high_percent:null},
    {...base,rate_type:'fee_fixed',rate_value:500},
    {...base,from_method:'USDT',to_method:'FIB'},
    {...base,from_method:'FIB',to_method:'AccountBalance'},
    {...base,rate_type:'multiplier',rate_value:1.01}
  ]) assert.throws(()=>effectiveRateValue(route,10000));
  for(const fee_brackets of [
    [{max_iqd:500000,fee_percent:2},{max_iqd:1000,fee_percent:1},{max_iqd:null,fee_percent:0}],
    [{max_iqd:1000,fee_percent:2},{max_iqd:null,fee_percent:101}],
    [{max_iqd:1000000001,fee_percent:2},{max_iqd:null,fee_percent:1}],
    [{max_iqd:1000,fee_percent:2},{max_iqd:2000,fee_percent:1}]
  ]) assert.throws(()=>effectiveRateValue({from_method:'FIB',to_method:'FastPay',rate_type:'fee_percent',rate_value:2,fee_brackets},1));
});

test('legacy rate migration preserves stored route values and customer hide table is owner-scoped',()=>{
  assert.match(legacyMigration,/ADD COLUMN IF NOT EXISTS fee_tier_enabled boolean NOT NULL DEFAULT false/i);
  assert.match(legacyMigration,/ADD COLUMN IF NOT EXISTS fee_tier_low_percent numeric/i);
  assert.match(legacyMigration,/ADD COLUMN IF NOT EXISTS fee_tier_high_percent numeric/i);
  assert.doesNotMatch(legacyMigration,/UPDATE\s+public\.ex_rates\s+SET\s+(?:rate_type|rate_value|fee_tier_enabled)\s*=/i);
  assert.match(hideMigration,/CREATE TABLE IF NOT EXISTS public\.ex_order_user_hides/i);
  assert.match(hideMigration,/user_id=auth\.uid\(\)/);
  assert.match(hideMigration,/o\.id=order_id AND o\.user_id=auth\.uid\(\)/);
  assert.match(hideMigration,/REFERENCES public\.ex_orders\(id\) ON DELETE CASCADE/i);
  assert.doesNotMatch(hideMigration,/UPDATE\s+public\.ex_rates/i);
});
