import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const app=read('assets/js/app.js');
const html=read('index.html');
const migration=read('supabase/migrations/20261113230300_disable_feedback_and_signup_rewards.sql');
const workflow=read('.github/workflows/exchange-production-smoke.yml');

function sqlFunction(name){
  const start=migration.indexOf(`function public.${name}()`);
  assert.notEqual(start,-1,`${name} is replaced in the migration`);
  const end=migration.indexOf('$function$;',start);
  assert.notEqual(end,-1,`${name} definition terminates`);
  return migration.slice(start,end);
}

test('rating still submits and displays, but no longer promises or grants a reward',()=>{
  assert.match(app,/sb\.from\('ex_order_feedback'\)\.insert\(/);
  assert.match(app,/ناردنی هەڵسەنگاندن/);
  assert.match(app,/سوپاس بۆ هەڵسەنگاندنەکەت/);
  assert.doesNotMatch(app,/FEEDBACK_REWARD|feedbackRewardGranted|feedbackRewardCard|order_feedback_v1:/);
  assert.doesNotMatch(app,/هەڵسەنگاندنەکەت بنێرە و[^'"`]*داشکان/);
  assert.doesNotMatch(app,/داشکاندنی[^'"`]*بۆ مامەڵەی داهاتووت زیادکرا/);
});

test('new-account welcome reward is no longer shown or rendered by the app',()=>{
  assert.doesNotMatch(html,/welcomeReward|welcomeRewardExpiry|پاداشتی هەژماری نوێ/);
  assert.doesNotMatch(app,/renderWelcomeReward|welcome_signup_v1/);
});

test('Supabase feedback trigger only validates ownership and approval; it inserts no reward',()=>{
  const fn=sqlFunction('ex_award_order_feedback_reward');
  assert.match(fn,/from public\.ex_orders/);
  assert.match(fn,/user_id=new\.user_id/);
  assert.match(fn,/status is distinct from 'پەسەندکرا'/);
  assert.match(fn,/return new/);
  assert.doesNotMatch(fn,/insert into public\.ex_user_rewards/i);
});

test('Supabase signup trigger still creates profiles but no longer grants welcome rewards',()=>{
  const fn=sqlFunction('ex_handle_new_user');
  assert.match(fn,/insert into public\.ex_profiles/);
  assert.match(fn,/return new/);
  assert.doesNotMatch(fn,/insert into public\.ex_user_rewards/i);
  assert.doesNotMatch(fn,/ex_notifications/i);
});

test('production smoke tracks the cache-busted customer bundle',()=>{
  assert.match(html,/app\.js\?v=81/);
  assert.match(workflow,/app\.js\?v=81/);
  assert.doesNotMatch(workflow,/app\.js\?v=80/);
});
