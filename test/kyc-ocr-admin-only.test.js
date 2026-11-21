import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const read = p => readFileSync(new URL(p, import.meta.url), 'utf8');
const app = read('../assets/js/app.js');
const html = read('../index.html');
const admin = read('../assets/js/admin.js');
const edge = read('../supabase/functions/receipt-read/index.ts');
const migration = read('../supabase/migrations/20261121225900_identity_verification_ocr.sql');

test('customer KYC UI contains no account-name comparison note or OCR result call', () => {
  assert.doesNotMatch(html, /kycNameNote|kycUpdateNameNote/);
  assert.doesNotMatch(app, /kycNameNote|kycUpdateNameNote|kycNameRelation|kycOcrResult|ex_admin_kyc_ocr_result/);
  assert.doesNotMatch(app, /ex_identity_verification_ocr/);
});

test('admin KYC review loads OCR through an admin RPC and compares every submitted field', () => {
  assert.match(admin, /sb\.rpc\('ex_admin_kyc_ocr_result',\{p_verification_id:it\.id\}\)/);
  assert.match(admin, /OCR بەرامبەر ناوی هەژمار/);
  assert.match(admin, /OCR بەرامبەر ناوی نووسراو/);
  assert.match(admin, /OCR بەرامبەر بەرواری نووسراو/);
  assert.match(admin, /OCR بەرامبەر ژمارەی نووسراو/);
  assert.match(admin, /تەنها یارمەتیی پشکنینی ئادمینە و خۆکارانە پەسەند یان ڕەت ناکاتەوە/);
});

test('identity OCR table is inaccessible to customers and admin RPC checks administrator status', () => {
  assert.match(migration, /alter table public\.ex_identity_verification_ocr enable row level security/i);
  assert.match(migration, /revoke all on table public\.ex_identity_verification_ocr from public, anon, authenticated/i);
  assert.match(migration, /grant all on table public\.ex_identity_verification_ocr to service_role/i);
  assert.match(migration, /perform public\.ex_kyc_assert_admin\(\)/);
  assert.match(migration, /grant execute on function public\.ex_admin_kyc_ocr_result\(uuid\) to authenticated/i);
  assert.match(migration, /create or replace function public\.ex_admin_kyc_ocr_retry\(p_verification_id uuid\)[\s\S]*?perform public\.ex_kyc_assert_admin\(\)/);
  assert.match(migration, /grant execute on function public\.ex_admin_kyc_ocr_retry\(uuid\) to authenticated/i);
  assert.doesNotMatch(migration, /grant select on table public\.ex_identity_verification_ocr to authenticated/i);
});

test('identity submissions queue the existing receipt-read function using the private Vault key', () => {
  assert.match(migration, /vault\.decrypted_secrets[\s\S]*name = 'receipt_read_key'/);
  assert.match(migration, /functions\/v1\/receipt-read/);
  assert.match(migration, /jsonb_build_object\('verification_id', new\.id\)/);
  assert.match(migration, /after insert on public\.ex_identity_verifications/i);
  assert.match(edge, /if \(verificationId\)[\s\S]*readIdentity\(verificationId\)/);
  assert.match(edge, /if \(!UUID\.test\(orderId\)\)[\s\S]*readReceipt\(key, orderId\)/);
});

test('identity photos are downloaded privately and only structured fields are retained without OCR text logging', () => {
  assert.match(edge, /storage\.from\(KYC_BUCKET\)\.download\(path\)/);
  assert.match(edge, /extracted_full_legal_name/);
  assert.match(edge, /extracted_date_of_birth/);
  assert.match(edge, /extracted_document_number/);
  assert.doesNotMatch(edge, /console\.(log|info|warn)\([^\n]*(result|text|full_legal_name|document_number)/i);
});
