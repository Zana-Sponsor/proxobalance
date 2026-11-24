import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const admin = read('../assets/js/admin.js');
const nameModule = read('../assets/js/kyc-name.js');
const app = read('../assets/js/app.js');
const KycName = runInNewContext(`${nameModule}\nwindow.KycName;`, { window: {} });

function extractFunction(source, name) {
  const match = source.match(new RegExp(`function ${name}\\([^)]*\\)\\s*\\{[\\s\\S]*?\\n\\}`));
  assert.ok(match, `${name} must be declared before KYC approval can use it`);
  return match[0];
}

test('KYC approval name comparisons use the shared normalizer instead of an undefined helper', () => {
  const helper = extractFunction(admin, 'kycNormName');
  const sandbox = { window: { KycName }, String };
  const normalize = runInNewContext(`${helper}\nkycNormName('  Zana   Ahmed Hassan  ');`, sandbox);
  assert.equal(normalize, KycName.normalize('Zana Ahmed Hassan'));
  assert.match(admin, /kycNormName\(it\.account_name \?\? it\.user\?\.full_name\) !== kycNormName\(it\.full_legal_name\)/);
  assert.match(admin, /const willRename=kycNormName\(account\)!==kycNormName\(it\.full_legal_name\)/);
  assert.match(admin, /p_confirm_name_change: decision==='approve'/);
});

test('customer OCR draft failures expose only known server error codes', () => {
  assert.match(app, /KYC_DRAFT_RATE_LIMIT:/);
  assert.match(app, /KYC_DRAFT_EXISTS:/);
  assert.match(app, /Object\.prototype\.hasOwnProperty\.call\(KYC_ERRORS,rawCode\)/);
  assert.match(app, /error_code:knownCode\|\|'UNKNOWN'/);
});
