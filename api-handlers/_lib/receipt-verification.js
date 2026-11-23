const MAX_IQD = 1_000_000_000;
const CONFIDENCE_FLOOR = 0.8;
const DIGIT_MAP = new Map([
  ...Array.from('٠١٢٣٤٥٦٧٨٩', (digit, index) => [digit, String(index)]),
  ...Array.from('۰۱۲۳۴۵۶۷۸۹', (digit, index) => [digit, String(index)])
]);

function westernDigits(value) {
  return Array.from(String(value ?? ''), char => DIGIT_MAP.get(char) ?? char).join('');
}

// Strip only separators that are harmless in a transfer reference. Letters and every
// digit are preserved; in particular, this does not treat two IDs with different digits as equal.
export function normalizeReference(value) {
  const normalized = westernDigits(value)
    .normalize('NFKC')
    .toLocaleUpperCase('en-US')
    .replace(/[\s\u00a0\-_‐‑‒–—:./]+/gu, '');
  return normalized || null;
}

const EXPECTED_REFERENCE_LABEL = /(?:\btransaction\s*(?:id|reference|ref)\b|\btransfer\s*(?:id|reference)\b|\btx\s*id\b|\btxid\b|\breference\b|\bref\b|ژمارەی?\s*(?:مامەڵە|گواستنەوە)|کۆدی?\s*مامەڵە|ناسنامەی?\s*مامەڵە|رقم\s*(?:العملية|المعاملة|المرجع)|معرف\s*(?:العملية|المعاملة))/giu;

// The expected outbound ID is stored in the admin's transfer note, not the customer's
// transaction_reference field. Multiple labelled candidates are ambiguous and fail closed.
export function extractExpectedReference(adminNote) {
  const note = String(adminNote ?? '').slice(0, 500);
  const values = [];
  for (const line of note.split(/\r?\n/)) {
    EXPECTED_REFERENCE_LABEL.lastIndex = 0;
    const label = EXPECTED_REFERENCE_LABEL.exec(line);
    if (!label) continue;
    const tail = line.slice(label.index + label[0].length);
    const value = tail.replace(/^\s*[:=＃#–—-]\s*/, '').split(/[;,|]/, 1)[0].trim();
    if (value) values.push(value);
  }
  return values.length === 1 ? values[0] : null;
}

function normalizeCurrency(value) {
  return westernDigits(value)
    .normalize('NFKC')
    .toLocaleLowerCase('en-US')
    .replace(/[.\s\u00a0]/gu, '');
}

const IQD_CURRENCIES = new Set([
  'iqd', 'دع', 'دينار', 'دینار', 'دينارعراقي', 'دینارعراقی', 'عراقيدينار', 'عراقدينار', 'عراقیدینار'
]);

/** Parse an IQD amount without floating-point arithmetic. Formatting separators are accepted
 * only when unambiguous; fractional IQD, unknown currency, malformed values and unsafe sizes fail closed. */
export function parseIqdAmount(value, currency) {
  if (!IQD_CURRENCIES.has(normalizeCurrency(currency))) return null;
  let digits;
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) return null;
    digits = String(value);
  } else if (typeof value === 'string') {
    let text = westernDigits(value).normalize('NFKC').trim()
      .replace(/[\s\u00a0]/gu, '').replace(/٬/gu, ',').replace(/٫/gu, '.');
    text = text.replace(/(?:IQD|د\.ع\.?|دينار(?:عراقي)?|دینار(?:عراقی)?)/giu, '');
    if (!text || !/^\d[\d.,]*$/.test(text)) return null;

    // Repeated three-digit groups are thousands separators (e.g. 1.234.567).
    if (/^\d{1,3}(?:[.,]\d{3})+$/.test(text)) text = text.replace(/[.,]/g, '');
    // A single 3-digit suffix is a thousands group only when the leading group has 1–3 digits.
    else if (/^\d{1,3}[.,]\d{3}$/.test(text)) text = text.replace(/[.,]/g, '');
    // A decimal marker is accepted only when its fractional part is zero, since IQD is integral.
    else if (/^\d+[.,]\d+$/.test(text)) {
      const parts = text.split(/[.,]/);
      if (!/^0+$/.test(parts[1])) return null;
      text = parts[0];
    } else if (/[.,]/.test(text)) return null;
    digits = text;
  } else {
    return null;
  }
  const amount = Number(digits);
  return Number.isSafeInteger(amount) && amount >= 0 && amount <= MAX_IQD ? amount : null;
}

export function compareReceipt({
  expectedAmount,
  expectedReference,
  actualAmount,
  currency,
  extractedReference,
  referenceConfidence,
  amountConfidence,
  isReceipt = true,
  ocrError = false,
  transferSucceeded = null,
  duplicate = false
}) {
  const validExpected = Number.isSafeInteger(expectedAmount) && expectedAmount >= 0 && expectedAmount <= MAX_IQD;
  const parsedActual = parseIqdAmount(actualAmount, currency);
  const expectedRef = normalizeReference(expectedReference);
  const extractedRef = normalizeReference(extractedReference);

  let idStatus = 'NOT_FOUND';
  if (expectedRef && extractedRef) {
    if (expectedRef.length < 4 || extractedRef.length < 4 ||
        !Number.isFinite(referenceConfidence) || referenceConfidence < CONFIDENCE_FLOOR) {
      idStatus = 'UNCERTAIN';
    } else {
      idStatus = expectedRef === extractedRef ? 'MATCH' : 'MISMATCH';
    }
  }

  let amountStatus = 'AMOUNT_NOT_FOUND';
  let difference = null;
  if (validExpected && parsedActual !== null && Number.isFinite(amountConfidence) && amountConfidence >= CONFIDENCE_FLOOR) {
    difference = parsedActual - expectedAmount;
    amountStatus = difference === 0 ? 'EXACT_MATCH' : difference > 0 ? 'OVERPAID' : 'UNDERPAID';
  }

  let verificationStatus;
  if (ocrError || !isReceipt) verificationStatus = 'OCR_FAILED';
  else if (duplicate) verificationStatus = 'DUPLICATE';
  else if (idStatus === 'MISMATCH') verificationStatus = 'ID_MISMATCH';
  else if (idStatus === 'MATCH' && amountStatus === 'EXACT_MATCH' && transferSucceeded === true) verificationStatus = 'VERIFIED';
  else verificationStatus = 'NEEDS_REVIEW';

  return Object.freeze({
    idStatus,
    amountStatus,
    actualAmount: parsedActual,
    difference,
    expectedReference: expectedRef,
    extractedReference: extractedRef,
    verificationStatus,
    manualReviewRequired: verificationStatus !== 'VERIFIED' && verificationStatus !== 'ID_MISMATCH'
  });
}

export const RECEIPT_VERIFICATION_LIMITS = Object.freeze({ MAX_IQD, CONFIDENCE_FLOOR });
