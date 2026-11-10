import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {effectiveRate, calculateTotal} from '../api/orders.js';

const migration=readFileSync(new URL('../SUPABASE_EXCHANGE_ROUTE_FEE_TIERS.sql',import.meta.url),'utf8');

test('an unconfigured route keeps its existing fee unchanged',()=>{
  const existing={rate_type:'fee_percent',rate_value:'2.5',fee_tier_enabled:false};
  assert.equal(effectiveRate(700000,existing,'FIB'),existing);
  assert.equal(calculateTotal(700000,effectiveRate(700000,existing,'FIB')),682500);
});

test('a configured route uses the first tier through the inclusive boundary',()=>{
  const route={rate_type:'fee_percent',rate_value:'2.5',fee_tier_enabled:true,fee_tier_limit_iqd:'500000',fee_tier_low_percent:'2',fee_tier_high_percent:'1'};
  const atBoundary=effectiveRate(500000,route,'FIB');
  assert.equal(atBoundary.rate_value,2);
  assert.equal(calculateTotal(500000,atBoundary),490000);
  assert.equal(effectiveRate(500001,route,'FIB').rate_value,1);
  assert.equal(Math.floor(calculateTotal(500001,effectiveRate(500001,route,'FIB'))),495000);
});

test('fee-like multiplier routes use tier percentages while retaining their stored multiplier',()=>{
  const route={rate_type:'multiplier',rate_value:0.85,fee_tier_enabled:true,fee_tier_limit_iqd:500000,fee_tier_low_percent:2,fee_tier_high_percent:1};
  const calculated=effectiveRate(10000,route,'Asiacell');
  assert.equal(calculated.rate_type,'fee_percent');
  assert.equal(calculated.rate_value,2);
  assert.equal(calculateTotal(10000,calculated),9800);
  assert.equal(route.rate_value,0.85);
});

test('tier configuration is rejected for invalid percentages, limits, or non-IQD route types',()=>{
  const base={rate_type:'fee_percent',fee_tier_enabled:true,fee_tier_limit_iqd:500000,fee_tier_low_percent:2,fee_tier_high_percent:1};
  for(const [rate,from] of [
    [{...base,fee_tier_low_percent:101},'FIB'],
    [{...base,fee_tier_limit_iqd:0},'FIB'],
    [{...base,rate_type:'multiplier',rate_value:1.01},'FIB'],
    [base,'USDT'],
    [base,'AccountBalance']
  ]) assert.throws(()=>effectiveRate(10000,rate,from),{status:409});
});

test('Supabase migration adds optional per-route fields without updating current rates',()=>{
  assert.match(migration,/ADD COLUMN IF NOT EXISTS fee_tier_enabled boolean NOT NULL DEFAULT false/i);
  assert.match(migration,/ADD COLUMN IF NOT EXISTS fee_tier_low_percent numeric/i);
  assert.match(migration,/ADD COLUMN IF NOT EXISTS fee_tier_high_percent numeric/i);
  assert.match(migration,/CHECK \(\s*NOT fee_tier_enabled OR/i);
  assert.match(migration,/fee_tier_config/i);
  assert.doesNotMatch(migration,/UPDATE\s+public\.ex_rates\s+SET\s+(?:rate_type|rate_value|fee_tier_enabled)\s*=/i);
});
