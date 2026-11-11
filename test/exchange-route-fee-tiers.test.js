import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {effectiveRateValue, calculateTotal} from '../api/orders.js';

const migration=readFileSync(new URL('../SUPABASE_EXCHANGE_ROUTE_FEE_TIERS.sql',import.meta.url),'utf8');

test('an unconfigured route keeps its existing fee unchanged',()=>{
  const route={from_method:'FIB',to_method:'FastPay',rate_type:'fee_percent',rate_value:'2.5',fee_tier_enabled:false};
  assert.equal(effectiveRateValue(route,700000),2.5);
  assert.equal(calculateTotal(700000,route),682500);
});

test('a configured route uses the first tier through the inclusive boundary',()=>{
  const route={from_method:'FIB',to_method:'FastPay',rate_type:'fee_percent',rate_value:'2.5',fee_tier_enabled:true,fee_tier_limit_iqd:'500000',fee_tier_low_percent:'2',fee_tier_high_percent:'1'};
  assert.equal(effectiveRateValue(route,500000),2);
  assert.equal(calculateTotal(500000,route),490000);
  assert.equal(effectiveRateValue(route,500001),1);
  assert.equal(Math.floor(calculateTotal(500001,route)),495000);
});

test('fee-like multiplier routes use tier percentages while retaining their stored multiplier',()=>{
  const route={from_method:'FIB',to_method:'Asiacell',rate_type:'multiplier',rate_value:0.85,fee_tier_enabled:true,fee_tier_limit_iqd:500000,fee_tier_low_percent:2,fee_tier_high_percent:1};
  assert.equal(effectiveRateValue(route,10000),0.98);
  assert.equal(calculateTotal(10000,route),9800);
  assert.equal(route.rate_value,0.85);
});

test('invalid tier settings fail closed',()=>{
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
});

test('Supabase migration adds optional per-route fields without updating current rates',()=>{
  assert.match(migration,/ADD COLUMN IF NOT EXISTS fee_tier_enabled boolean NOT NULL DEFAULT false/i);
  assert.match(migration,/ADD COLUMN IF NOT EXISTS fee_tier_low_percent numeric/i);
  assert.match(migration,/ADD COLUMN IF NOT EXISTS fee_tier_high_percent numeric/i);
  assert.match(migration,/CHECK \(\s*NOT fee_tier_enabled OR/i);
  assert.match(migration,/fee_tier_config/i);
  assert.doesNotMatch(migration,/UPDATE\s+public\.ex_rates\s+SET\s+(?:rate_type|rate_value|fee_tier_enabled)\s*=/i);
});
