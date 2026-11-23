import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { assertStaffAction } from '../api-handlers/admin.js';
import {
  compareReceipt,
  extractExpectedReference,
  normalizeReference,
  parseIqdAmount
} from '../api-handlers/_lib/receipt-verification.js';

const BASE = {
  expectedAmount: 50_000,
  expectedReference: 'TX-123 456',
  actualAmount: 50_000,
  currency: 'IQD',
  extractedReference: 'tx123456',
  referenceConfidence: 0.99,
  amountConfidence: 0.99,
  isReceipt: true,
  transferSucceeded: true
};

test('exact amount and matching reference verify without automatic approval data', () => {
  const result = compareReceipt(BASE);
  assert.equal(result.idStatus, 'MATCH');
  assert.equal(result.amountStatus, 'EXACT_MATCH');
  assert.equal(result.actualAmount, 50_000);
  assert.equal(result.difference, 0);
  assert.equal(result.verificationStatus, 'VERIFIED');
});

test('higher and lower IQD amounts keep the signed exact difference', () => {
  const higher = compareReceipt({...BASE, actualAmount: 51_000});
  assert.equal(higher.amountStatus, 'OVERPAID');
  assert.equal(higher.difference, 1_000);
  assert.equal(higher.verificationStatus, 'NEEDS_REVIEW');

  const lower = compareReceipt({...BASE, actualAmount: 48_000});
  assert.equal(lower.amountStatus, 'UNDERPAID');
  assert.equal(lower.difference, -2_000);
  assert.equal(lower.verificationStatus, 'NEEDS_REVIEW');
});

test('a correct amount never compensates for an ID mismatch', () => {
  const result = compareReceipt({...BASE, extractedReference: 'TX-123-457'});
  assert.equal(result.amountStatus, 'EXACT_MATCH');
  assert.equal(result.idStatus, 'MISMATCH');
  assert.equal(result.verificationStatus, 'ID_MISMATCH');
});

test('missing expected or extracted IDs require review and cannot count as a match', () => {
  assert.equal(compareReceipt({...BASE, expectedReference: null}).idStatus, 'NOT_FOUND');
  assert.equal(compareReceipt({...BASE, extractedReference: null}).idStatus, 'NOT_FOUND');
  assert.equal(compareReceipt({...BASE, expectedReference: null}).verificationStatus, 'NEEDS_REVIEW');
});

test('ambiguous or low-confidence IDs are UNCERTAIN, preserving meaningful digits', () => {
  assert.equal(compareReceipt({...BASE, referenceConfidence: 0.55}).idStatus, 'UNCERTAIN');
  assert.equal(compareReceipt({...BASE, expectedReference: 'TX123455'}).idStatus, 'MISMATCH');
  assert.equal(normalizeReference('TX-123 456'), 'TX123456');
  assert.notEqual(normalizeReference('TX-123 456'), normalizeReference('TX-123 457'));
  assert.equal(normalizeReference('١٢-۳٤'), '1234');
});

test('duplicate and unreadable/non-receipt uploads are not verified', () => {
  const duplicate = compareReceipt({...BASE, duplicate: true});
  assert.equal(duplicate.verificationStatus, 'DUPLICATE');
  assert.equal(duplicate.manualReviewRequired, true);
  const unreadable = compareReceipt({...BASE, ocrError: true});
  assert.equal(unreadable.verificationStatus, 'OCR_FAILED');
  assert.equal(unreadable.manualReviewRequired, true);
  assert.equal(compareReceipt({...BASE, isReceipt: false}).verificationStatus, 'OCR_FAILED');
});

test('IQD number formatting is accepted only when unambiguous and safely integral', () => {
  assert.equal(parseIqdAmount('50,000', 'IQD'), 50_000);
  assert.equal(parseIqdAmount('١٠٠٬٠٠٠', 'IQD'), 100_000);
  assert.equal(parseIqdAmount('٥٠٬٠٠٠', 'دينار'), 50_000);
  assert.equal(parseIqdAmount('١٠٠٠٠٠', 'د.ع'), 100_000);
  assert.equal(parseIqdAmount('1.234.000', 'IQD'), 1_234_000);
  assert.equal(parseIqdAmount('50000.00', 'IQD'), 50_000);
  assert.equal(parseIqdAmount('50000.25', 'IQD'), null);
  assert.equal(parseIqdAmount(50_000.5, 'IQD'), null);
  assert.equal(parseIqdAmount('50000', 'USD'), null);
  assert.equal(parseIqdAmount('1000000001', 'IQD'), null);
  assert.equal(parseIqdAmount('9e5', 'IQD'), null);
});

test('non-success transfers and low-confidence amounts require manual review', () => {
  assert.equal(compareReceipt({...BASE, transferSucceeded: false}).verificationStatus, 'NEEDS_REVIEW');
  assert.equal(compareReceipt({...BASE, amountConfidence: 0.2}).amountStatus, 'AMOUNT_NOT_FOUND');
});

test('expected transfer ID is read only from an unambiguous labelled admin note', () => {
  assert.equal(extractExpectedReference('Transaction ID: ABC-123'), 'ABC-123');
  assert.equal(extractExpectedReference('تێبینی\nژمارەی مامەڵە: ١٢٣٤٥٦'), '١٢٣٤٥٦');
  assert.equal(extractExpectedReference('رقم العملية: REF-2026'), 'REF-2026');
  assert.equal(extractExpectedReference('customer reference: incoming-22'), 'incoming-22');
  assert.equal(extractExpectedReference('some free text 123456'), null);
  assert.equal(extractExpectedReference('Reference: A123\nTXID: B456'), null, 'multiple IDs are ambiguous');
});

test('staff permissions protect verification start and manual review; view-only staff cannot mutate', () => {
  const viewer = { role: 'admin', staff_permissions: ['view'] };
  assert.throws(() => assertStaffAction(viewer, 'payout_receipt_verify_start'), error => error.status === 403);
  assert.throws(() => assertStaffAction(viewer, 'payout_receipt_verify_review'), error => error.status === 403);
  assert.doesNotThrow(() => assertStaffAction(viewer, 'payout_receipt_verify_get'));
  const approver = { role: 'admin', staff_permissions: ['view', 'approve_orders'] };
  assert.doesNotThrow(() => assertStaffAction(approver, 'payout_receipt_verify_start'));
  assert.doesNotThrow(() => assertStaffAction(approver, 'payout_receipt_verify_review'));
});

test('approval UI stays separate from OCR, requires verified or documented same-admin review, and never waives ID mismatch', () => {
  const ui = readFileSync(new URL('../assets/js/admin.js', import.meta.url), 'utf8');
  const html = readFileSync(new URL('../exchange-admin.html', import.meta.url), 'utf8');
  assert.match(html, /id="apSmartReceipt"/);
  assert.match(html, /startPayoutReceiptVerification\(\)/);
  assert.match(html, /recordPayoutReceiptManualReview\(\)/);
  assert.match(ui, /result\.id_status==='MISMATCH'\)return \{ok:false/);
  assert.match(ui, /result\.verification_status==='VERIFIED'\)return \{ok:true\}/);
  assert.match(ui, /result\.manual_review_by===draft\.admin_id/);
  assert.match(ui, /const receiptGate=approvalReceiptGate\(payload\);[\s\S]{0,120}if\(!receiptGate\.ok\)throw Error/);
  assert.match(ui, /payout_receipt_verify_get/);
});

test('database guard covers both approval routes and keeps payout OCR out of incoming receipt reads', () => {
  const sql = readFileSync(new URL('../supabase/migrations/20261124010000_smart_receipt_verification.sql', import.meta.url), 'utf8');
  const edge = readFileSync(new URL('../supabase/functions/receipt-read/index.ts', import.meta.url), 'utf8');
  assert.match(sql, /create table if not exists public\.ex_payout_receipt_verifications/);
  assert.match(sql, /create trigger trg_ex_payout_receipt_approval_guard[\s\S]*?before update of status,payout_receipt_url,payout_iqd,admin_note on public\.ex_orders/);
  assert.match(sql, /SMART_RECEIPT_ID_MISMATCH/);
  assert.match(sql, /SMART_RECEIPT_MANUAL_REVIEW_REQUIRED/);
  assert.match(edge, /async function readPayoutReceipt/);
  assert.match(edge, /ex_payout_receipt_ocr_save/);
  assert.match(edge, /payout_verification_id/);
  assert.doesNotMatch(edge, /ex_receipt_read_save[\s\S]{0,120}readPayoutReceipt/);
});
