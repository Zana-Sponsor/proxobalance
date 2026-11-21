import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const read = p => readFileSync(new URL(p, import.meta.url), 'utf8');
const app = read('../assets/js/app.js');
const html = read('../index.html');
const adminHtml = read('../exchange-admin.html');
const admin = read('../assets/js/admin.js');
const adminDetailsCss = read('../assets/css/admin-details.css');
const edge = read('../supabase/functions/receipt-read/index.ts');
const oldMigration = read('../supabase/migrations/20261121230833_identity_verification_ocr.sql');
const migration = read('../supabase/migrations/20261121233709_kyc_customer_ocr_drafts.sql');
const nameModule = read('../assets/js/kyc-name.js');
const KycName = runInNewContext(`${nameModule}\nwindow.KycName;`, { window: {} });

test('customer sees issue/expiry fields and a live status, without direct OCR-table access', () => {
  assert.match(html, /id="kycIssueDate"/);
  assert.match(html, /id="kycExpiryDate"/);
  assert.match(html, /id="kycOcrStatus"[^>]*aria-live="polite"/);
  assert.match(app, /sb\.rpc\('ex_kyc_ocr_draft_result'/);
  assert.doesNotMatch(app, /ex_identity_verification_ocr/);
  assert.doesNotMatch(app, /ex_admin_kyc_ocr_result/);
});

test('photos are pre-read before submission, OCR replaces existing fields, and final submission sends dates', () => {
  assert.match(app, /sb\.rpc\('ex_kyc_ocr_draft_start'/);
  assert.match(app, /sb\.rpc\('ex_kyc_ocr_draft_queue'/);
  assert.match(app, /kycApplyOcrResult\(data\)/);
  assert.match(app, /if\(value==null \|\| String\(value\)\.trim\(\)===''\) return;[\s\S]*?input\.value=String\(value\); input\.dataset\.ocrValue=String\(value\);/);
  assert.match(app, /وێنەکان دەخوێنرێنەوە چاوەڕوان بە\.\.\./);
  assert.doesNotMatch(app, /وێنەکان بار دەکرێن و ناسنامەکە بەخۆکار دەخوێندرێتەوە/);
  assert.match(app, /پڕۆسەی خوێندنەوە بەسەرکەوتوویی تەواوبوو، تکایە دووبارە زانیاریەکان بپشکنەوە\./);
  assert.match(app, /kv-ocr-progress[\s\S]*?setAttribute\('role','progressbar'\)[\s\S]*?aria-valuetext/);
  assert.match(app, /aria-busy',currentState==='working'\?'true':'false'/);
  assert.match(html, /kyc-screen\.css\?v=5/);
  assert.match(html, /app\.js\?v=131/);
  assert.match(app, /p_document_issue_date:fields\.issue/);
  assert.match(app, /p_document_expiry_date:fields\.expiry/);
  assert.match(app, /if\(!_kycDraftImagesUploaded\)\{[\s\S]*?await kycUpload\(frontPath, front\)/);
  assert.match(app, /try\{ await _kycOcrPromise; \}/);
  assert.match(app, /ناوی ھەژمار و ناوی سەر ناسنامە ھاوتا نین!/);
  assert.match(app, /const identityName=fields\.name/);
});

test('OCR progress is indeterminate, smooth, and respects reduced motion', () => {
  const css = read('../assets/css/kyc-screen.css');
  assert.match(css, /\.kv-ocr-progress-indicator[^\n]*animation: kv-ocr-sweep/);
  assert.match(css, /@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.kv-ocr-progress-indicator \{ animation: none/);
});

test('full three-part English, Arabic, and Kurdish spellings are accepted; incomplete names are not', () => {
  assert.equal(KycName.validThreePartName('Zana Ahmed Hassan'), true);
  assert.equal(KycName.validThreePartName('زانا ئەحمەد حەسەن'), true);
  assert.equal(KycName.validThreePartName('أحمد علي حسن'), true);
  assert.equal(KycName.validThreePartName('Zana Ahmed'), false);
  assert.equal(KycName.validThreePartName('Zana'), false);
  assert.equal(KycName.relation('Zana Ahmed Hassan', 'زانا ئەحمەد حەسەن'), 'same_translit');
  assert.equal(KycName.relation('Ahmed Ali Hasan', 'أحمد علي حسن'), 'same_translit');
  assert.equal(KycName.relation('Zana Ahmed Hassan', 'زانا سەعید حەسەن'), 'different_script');
});

test('admin review compares submitted and extracted dates and keeps approval/rejection manual', () => {
  assert.match(admin, /submitted_document_issue_date/);
  assert.match(admin, /submitted_document_expiry_date/);
  assert.match(admin, /extracted_document_issue_date/);
  assert.match(admin, /extracted_document_expiry_date/);
  assert.match(admin, /kycOcrDataCard\('submitted'/);
  assert.match(admin, /kycOcrDataCard\('extracted'/);
  assert.match(admin, /p_decision:decision/);
  assert.match(admin, /if\(reasonEl && !reasonEl\.value\.trim\(\) && review\.suggestion\) reasonEl\.value=review\.suggestion/);
  assert.match(admin, /kyc-ocr-card-grid/);
  assert.match(adminDetailsCss, /\.kyc-ocr-card-grid/);
  assert.match(adminHtml, /assets\/js\/kyc-name\.js\?v=1/);
  assert.match(adminHtml, /admin\.js\?v=46/);
});

test('OCR remains private; customer draft RPCs are owner-scoped and storage uploads are draft-aware', () => {
  assert.match(oldMigration, /alter table public\.ex_identity_verification_ocr enable row level security/i);
  assert.match(oldMigration, /revoke all on table public\.ex_identity_verification_ocr from public, anon, authenticated/i);
  assert.match(migration, /revoke all on table public\.ex_identity_verification_ocr_drafts from public, anon, authenticated/i);
  assert.match(migration, /grant all on table public\.ex_identity_verification_ocr_drafts to service_role/i);
  assert.match(migration, /where d\.draft_id=p_draft_id and d\.user_id=auth\.uid\(\)/);
  assert.match(migration, /d\.draft_id=p_folder::uuid and d\.user_id=v_uid and d\.expires_at>now\(\)/);
  assert.match(migration, /ocr_attempts<3/);
  assert.match(migration, /grant execute on function public\.ex_kyc_ocr_draft_result\(uuid\) to authenticated/i);
  assert.match(migration, /revoke all on function public\.ex_admin_kyc_ocr_result\(uuid\) from public,anon/i);
  assert.match(migration, /perform public\.ex_kyc_assert_admin\(\)/);
  assert.doesNotMatch(migration, /grant select on table public\.ex_identity_verification_ocr(?:_drafts)? to authenticated/i);
});

test('draft OCR uses private Edge authentication and reads only validated owner-path files', () => {
  assert.match(migration, /vault\.decrypted_secrets[\s\S]*name='receipt_read_key'/);
  assert.match(migration, /jsonb_build_object\('identity_draft_id',p_draft_id\)/);
  assert.match(edge, /if \(identityDraftId\)[\s\S]*readIdentity\(identityDraftId, true\)/);
  assert.match(edge, /if \(verificationId\)[\s\S]*readIdentity\(verificationId\)/);
  assert.match(edge, /storage\.from\(KYC_BUCKET\)\.download\(path\)/);
  assert.match(edge, /extracted_document_issue_date: validIssueDate/);
  assert.match(edge, /extracted_document_expiry_date: validExpiryDate/);
  assert.match(edge, /issue_date: S, expiry_date: S/);
  assert.doesNotMatch(edge, /console\.(log|info|warn)\([^\n]*(result|text|full_legal_name|document_number)/i);
});

test('final submit requires three name parts and validates dates while preserving pending/manual-review behavior', () => {
  assert.match(migration, /array_length\(regexp_split_to_array\(v_name,' '\),1\)<>3/);
  assert.match(migration, /p_document_issue_date>\(now\(\) at time zone 'Asia\/Baghdad'\)::date/);
  assert.match(migration, /p_document_expiry_date<=p_document_issue_date/);
  assert.match(migration, /values\(p_verification_id,v_uid,v_req_id,p_document_type,v_name,p_date_of_birth,v_number,p_front_path,p_back_path,p_document_issue_date,p_document_expiry_date,'pending',now\(\)\)/);
  assert.match(migration, /grant execute on function public\.ex_kyc_submit\(uuid,text,text,date,text,text,text,date,date\) to authenticated/i);
  assert.match(migration, /ex_identity_ocr_enqueue/);
});
