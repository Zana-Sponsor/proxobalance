import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

// v37+: the discount / reward system is gone everywhere (UI, API, database).
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const app=read('assets/js/app.js');
const html=read('index.html');
const admin=read('exchange-admin.html');
const workflow=read('.github/workflows/exchange-production-smoke.yml');

test('rating still submits and displays, but no longer promises or grants a reward',()=>{
  assert.match(app,/sb\.from\('ex_order_feedback'\)\.insert\(/);
  assert.match(app,/چۆن بوو ئەم مامەڵەیە؟/);
  assert.match(app,/سوپاس بۆ هەڵسەنگاندنەکەت/);
  assert.doesNotMatch(app,/FEEDBACK_REWARD|feedbackRewardGranted|feedbackRewardCard|order_feedback_v1:|MY_REWARDS|loadMyRewards/);
});

test('no reward or discount UI in the customer app or the admin panel',()=>{
  assert.doesNotMatch(html,/welcomeReward|rewardBanner|bdDiscountRow|exchange-reward-pricing/);
  assert.doesNotMatch(admin,/pgRewards|rewardAmountCap|rewardScope|پاداشت و داشکاندن/);
  assert.match(html,/\/assets\/js\/exchange-pricing\.js\?v=\d+/);
});

test('production smoke tracks the current customer bundle',()=>{
  const version=html.match(/\/assets\/js\/app\.js\?v=(\d+)/)?.[1];
  assert.ok(version);
  assert.match(workflow,new RegExp('app\\.js\\?v='+version));
  assert.doesNotMatch(workflow,/app\.js\?v=82/);
  assert.match(workflow,/for bad in [^\n]*id="rewardBanner"/);   // the check fails if the old UI comes back
});
