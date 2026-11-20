import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const app = read('../assets/js/app.js');
const adminUi = read('../assets/js/admin.js');
const authApi = read('../api-handlers/auth.js');
const edgeCreate = read('../supabase/functions/admin-create-user/index.ts');
const migration = read('../supabase/migrations/20261118150000_harden_otp_registration.sql');
const mobileSignup = read('../proxo_app/supabase/functions/phone-otp-session/index.ts');

test('browser bundles do not call Supabase Auth signup or public email OTP verification RPCs', () => {
  assert.doesNotMatch(app, /auth\.signUp\s*\(/);
  assert.doesNotMatch(app, /sb\.rpc\(['"]ex_verify_otp['"]/);
  assert.match(app, /pxAuthApi\('signup_finish'/);
  assert.match(adminUi, /action:'request_otp'/);
  assert.match(adminUi, /action:'create'.*otp_code/s);
});

test('customer account creation validates a server-side signup OTP before Admin Auth creation', () => {
  const verification = authApi.indexOf("await checkPhoneCode(phone, 'signup'");
  const creation = authApi.indexOf("gotrue('/admin/users'");
  assert.ok(verification >= 0 && creation > verification, 'OTP check must precede the Admin Auth create call');
});

test('admin account creation verifies exact-purpose OTP before calling Supabase Admin createUser', () => {
  const verification = edgeCreate.indexOf('adminClient.rpc("ex_verify_otp"');
  const creation = edgeCreate.indexOf('adminClient.auth.admin.createUser');
  assert.ok(verification >= 0 && creation > verification, 'email OTP must be consumed before createUser');
  assert.match(edgeCreate, /p_purpose:\s*OTP_PURPOSE/);
  assert.match(edgeCreate, /action !== "request_otp" && action !== "create"/);
  assert.doesNotMatch(edgeCreate, /detail:\s*`email=/);
});

test('mobile registration uses the purpose-aware signup OTP RPC before Admin Auth creation', () => {
  const verification = mobileSignup.indexOf('"pa_verify_whatsapp_otp"');
  const creation = mobileSignup.indexOf('admin.auth.admin.createUser');
  assert.ok(verification >= 0 && creation > verification, 'signup OTP must be consumed before createUser');
  assert.match(mobileSignup, /p_purpose:\s*"signup"/);
  assert.doesNotMatch(mobileSignup, /rpc\(\s*"verify_otp_whatsapp"/);
});

test('database hardening serializes issuance, locks verification rows, and denies public OTP verifier execution', () => {
  assert.match(migration, /pg_advisory_xact_lock/);
  assert.match(migration, /limit 1\s+for update/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.ex_verify_otp\(text, text, text\) FROM PUBLIC, anon, authenticated/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.ex_verify_otp\(text, text, text\) TO service_role/i);
  assert.match(migration, /purpose = p_purpose/);
  assert.match(migration, /TOO_MANY_CODES/);
});
