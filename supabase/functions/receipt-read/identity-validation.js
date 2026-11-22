export const KYC_IMAGE_ERRORS = Object.freeze({
  invalid: 'KYC_IDENTITY_IMAGE_INVALID',
  mismatch: 'KYC_IDENTITY_IMAGES_MISMATCH',
  uncertain: 'KYC_IDENTITY_IMAGE_UNCERTAIN'
});

const DOCUMENT_TYPES = new Set(['national_id', 'driving_license']);

/** Validate each OCR image classification against its upload slot and its peers. */
export function validateIdentityImages(result, expectedSides) {
  if (!result || result.is_identity_document !== true) {
    return { isIdentityDocument: false, documentType: null, errorCode: KYC_IMAGE_ERRORS.invalid };
  }

  const checks = result.image_checks;
  if (!Array.isArray(checks) || checks.length !== expectedSides.length || checks.length === 0) {
    return { isIdentityDocument: false, documentType: null, errorCode: KYC_IMAGE_ERRORS.uncertain };
  }

  const normalized = checks.map((check, index) => ({
    documentType: check?.document_type,
    side: check?.side,
    expectedSide: expectedSides[index]
  }));
  if (checks.some(check => check?.is_identity_document !== true) || normalized.some(check => !DOCUMENT_TYPES.has(check.documentType))) {
    return { isIdentityDocument: false, documentType: null, errorCode: KYC_IMAGE_ERRORS.invalid };
  }

  const detectedType = normalized[0].documentType;
  const declaredType = result.document_type;
  const typeMismatch = normalized.some(check => check.documentType !== detectedType) ||
    (DOCUMENT_TYPES.has(declaredType) && declaredType !== detectedType);
  const sideMismatch = normalized.some(check => check.side !== check.expectedSide);
  if (typeMismatch || sideMismatch) {
    return { isIdentityDocument: false, documentType: null, errorCode: KYC_IMAGE_ERRORS.mismatch };
  }

  return { isIdentityDocument: true, documentType: detectedType, errorCode: null };
}
