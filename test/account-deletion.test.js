import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const read = p => readFileSync(new URL(p, import.meta.url), 'utf8');
const app = read('../assets/js/app.js');
const html = read('../index.html');

test('delete-account is its own screen with a clean route, under the profile tab', () => {
  assert.match(html, /<section class="page" id="pageDeleteAccount" data-route="delete-account">/);
  assert.match(app, /'delete-account':'pageDeleteAccount'/);
  assert.match(app, /\['changes','support','verify','balance','delete-account'[^\]]*\]\.includes\(route\)\) return 'profile'/);
  assert.match(html, /onclick="navigate\('delete-account'\)"/);
});

test('every screen has a path route: balance no longer uses a #/ hash', () => {
  assert.doesNotMatch(app, /#\/balance/);
});

test('bottom nav has four tabs and no (+) button; the dashboard opens /exchange', () => {
  const nav = html.slice(html.indexOf('<nav class="pxn"'), html.indexOf('</nav>', html.indexOf('<nav class="pxn"')));
  assert.equal((nav.match(/class="pxn-item/g) || []).length, 4);
  assert.doesNotMatch(nav, /pxn-fab|pxnFab|navigate\('exchange'\)/);
  assert.match(html, /id="dbNewOrder" onclick="navigate\('exchange'\)"/);
  assert.match(html, /<b>داواکاری نوێ<\/b>/);
});

test('the app confirms the password, asks the server, and signs out', () => {
  const body = app.slice(app.indexOf('async function submitAccountDeletion'), app.indexOf('async function checkAccountDeletion'));
  assert.ok(body.indexOf('signInWithPassword') < body.indexOf("rpc('ex_account_deletion_request'"));
  assert.match(body, /signOut\(\{scope:'local'\}\)/);
  assert.match(app, /const deletionState=await checkAccountDeletion\(\);\n  if\(deletionState==='pending'\) return;/);
});

test('the app requests deletion through the existing authenticated database function', () => {
  assert.match(app, /rpc\('ex_account_deletion_request'/);
  assert.match(app, /rpc\('ex_account_deletion_info'/);
  assert.match(app, /rpc\('ex_account_deletion_check'/);
});
