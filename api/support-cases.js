import {
  json, readJson, serviceFetch, withSecurity
} from './_lib/security.js';
import { randomInt } from 'node:crypto';

const CASE_BUCKET = 'support-case-images';
const CATEGORIES = new Set(['order', 'payment', 'account', 'technical', 'general']);
const MAX_DESCRIPTION = 2000;
const MAX_CASES_PER_HOUR = 5;
const MAX_UNRESOLVED_CASES = 10;
const CASE_NUMBER_ATTEMPTS = 8;
const ACTIVE_STATUSES = 'open,in_progress,needs_correction,corrected';

function cleanLine(value, max = 200) {
  return String(value == null ? '' : value)
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max);
}

function cleanDescription(value) {
  return String(value == null ? '' : value)
    .replace(/\r\n?/g, '\n')
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '')
    .trim()
    .slice(0, MAX_DESCRIPTION);
}

function cleanImagePath(value, userId) {
  const path = cleanLine(value, 500);
  if (!path || !path.startsWith(`${userId}/`)) return null;
  const filename = path.slice(userId.length + 1);
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,180}\.(?:jpe?g|png|webp)$/i.test(filename)) return null;
  return path;
}

async function imageExists(imagePath, userId) {
  if (!imagePath) return true;
  const filename = imagePath.slice(userId.length + 1);
  const rows = await serviceFetch(`/storage/v1/object/list/${CASE_BUCKET}`, {
    method: 'POST',
    body: JSON.stringify({ prefix: userId, search: filename, limit: 10, offset: 0 })
  });
  return Array.isArray(rows) && rows.some(row => row?.name === filename);
}

function isCaseNumberCollision(error) {
  return Number(error?.status) === 409 && (
    error?.details?.code === '23505' || /duplicate|unique/i.test(String(error?.message || ''))
  );
}

async function insertSupportCase(payload) {
  for (let attempt = 0; attempt < CASE_NUMBER_ATTEMPTS; attempt += 1) {
    const caseNumber = randomInt(100000, 1000000);
    try {
      const rows = await serviceFetch('/rest/v1/ex_support_cases?select=id,case_number,user_id,category,order_code,description,image_path,status,admin_note,correction_request,correction_requested_at,customer_response,customer_responded_at,created_at,updated_at', {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: JSON.stringify({ ...payload, case_number: caseNumber })
      });
      return rows?.[0] || null;
    } catch (error) {
      if (!isCaseNumberCollision(error)) throw error;
    }
  }
  throw Object.assign(new Error('Could not allocate a support case number'), {
    status: 503,
    code: 'SUPPORT_CASE_NUMBER_EXHAUSTED'
  });
}

function cleanCaseFields(body) {
  const category = CATEGORIES.has(body.category) ? body.category : 'general';
  const description = cleanDescription(body.description);
  const rawOrderCode = cleanLine(body.order_code, 20).replace(/[\s#-]+/g, '').toUpperCase();
  const orderCode = rawOrderCode || null;
  return { category, description, orderCode };
}

function validateCaseFields(res, { description, orderCode }) {
  if (description.length < 10) {
    json(res, 422, { error: 'Description must be at least 10 characters' });
    return false;
  }
  if (orderCode && !/^P[A-Z0-9]{11}$/.test(orderCode)) {
    json(res, 422, { error: 'Invalid order code' });
    return false;
  }
  return true;
}

async function submitCorrection(res, body, user) {
  const id = cleanLine(body.id, 64);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
    return json(res, 422, { error: 'Invalid support case id' });
  }

  const existingRows = await serviceFetch(
    `/rest/v1/ex_support_cases?id=eq.${encodeURIComponent(id)}` +
    `&user_id=eq.${encodeURIComponent(user.id)}&select=*&limit=1`
  );
  const existing = Array.isArray(existingRows) ? existingRows[0] : null;
  if (!existing) return json(res, 404, { error: 'Support case not found' });
  if (existing.status !== 'needs_correction') {
    return json(res, 409, { error: 'This support case is not waiting for a correction' });
  }

  const fields = cleanCaseFields(body);
  if (!validateCaseFields(res, fields)) return;
  const customerResponse = cleanDescription(body.customer_response);
  if (customerResponse.length < 5) {
    return json(res, 422, { error: 'Correction response must be at least 5 characters' });
  }

  const hasImageField = Object.prototype.hasOwnProperty.call(body, 'image_path');
  const suppliedImage = hasImageField ? cleanLine(body.image_path, 500) : '';
  const cleanedImage = suppliedImage ? cleanImagePath(suppliedImage, user.id) : null;
  if (suppliedImage && !cleanedImage) {
    return json(res, 422, { error: 'Invalid support image path' });
  }
  const imagePath = body.remove_image === true
    ? null
    : (hasImageField && suppliedImage ? cleanedImage : existing.image_path);
  if (hasImageField && suppliedImage && !(await imageExists(imagePath, user.id))) {
    return json(res, 422, { error: 'Support image was not found' });
  }

  const now = new Date().toISOString();
  const rows = await serviceFetch(
    `/rest/v1/ex_support_cases?id=eq.${encodeURIComponent(id)}` +
    `&user_id=eq.${encodeURIComponent(user.id)}&status=eq.needs_correction` +
    '&select=id,case_number,user_id,category,order_code,description,image_path,status,admin_note,correction_request,correction_requested_at,customer_response,customer_responded_at,created_at,updated_at',
    {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify({
        category: fields.category,
        order_code: fields.orderCode,
        description: fields.description,
        image_path: imagePath,
        customer_response: customerResponse,
        customer_responded_at: now,
        status: 'corrected',
        resolved_at: null,
        updated_at: now
      })
    }
  );
  const updatedCase = Array.isArray(rows) ? rows[0] : null;
  if (!updatedCase) return json(res, 409, { error: 'Support case state changed; please refresh' });
  return json(res, 200, { ok: true, case: updatedCase });
}

export default withSecurity(async (req, res, { user }) => {
  const body = await readJson(req);
  if (req.method === 'PATCH') return submitCorrection(res, body, user);

  const { category, description, orderCode } = cleanCaseFields(body);
  const suppliedImage = cleanLine(body.image_path, 500);
  const imagePath = suppliedImage ? cleanImagePath(suppliedImage, user.id) : null;

  if (!validateCaseFields(res, { description, orderCode })) return;
  if (suppliedImage && !imagePath) {
    return json(res, 422, { error: 'Invalid support image path' });
  }

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const [recentCases, unresolvedCases] = await Promise.all([
    serviceFetch(
      `/rest/v1/ex_support_cases?user_id=eq.${encodeURIComponent(user.id)}` +
      `&created_at=gte.${encodeURIComponent(oneHourAgo)}&select=id&limit=${MAX_CASES_PER_HOUR}`
    ),
    serviceFetch(
      `/rest/v1/ex_support_cases?user_id=eq.${encodeURIComponent(user.id)}` +
      `&status=in.(${ACTIVE_STATUSES})&select=id&limit=${MAX_UNRESOLVED_CASES}`
    )
  ]);

  if ((recentCases || []).length >= MAX_CASES_PER_HOUR) {
    return json(res, 429, { error: 'Too many support cases. Please try again later.' });
  }
  if ((unresolvedCases || []).length >= MAX_UNRESOLVED_CASES) {
    return json(res, 409, { error: 'Please wait for your open cases to be reviewed.' });
  }
  if (imagePath && !(await imageExists(imagePath, user.id))) {
    return json(res, 422, { error: 'Support image was not found' });
  }

  const createdCase = await insertSupportCase({
    user_id: user.id,
    category,
    order_code: orderCode,
    description,
    image_path: imagePath
  });

  return json(res, 201, { ok: true, case: createdCase });
}, {
  auth: 'required',
  methods: ['POST', 'PATCH'],
  event: 'support_case_submission'
});
