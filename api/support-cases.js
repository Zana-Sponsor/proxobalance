import {
  json, readJson, serviceFetch, withSecurity
} from './_lib/security.js';

const CASE_BUCKET = 'support-case-images';
const CATEGORIES = new Set(['order', 'payment', 'account', 'technical', 'general']);
const MAX_DESCRIPTION = 2000;
const MAX_CASES_PER_HOUR = 5;
const MAX_UNRESOLVED_CASES = 10;

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

export default withSecurity(async (req, res, { user }) => {
  const body = await readJson(req);
  const category = CATEGORIES.has(body.category) ? body.category : 'general';
  const description = cleanDescription(body.description);
  const rawOrderCode = cleanLine(body.order_code, 20).replace(/[\s#-]+/g, '').toUpperCase();
  const orderCode = rawOrderCode || null;
  const suppliedImage = cleanLine(body.image_path, 500);
  const imagePath = suppliedImage ? cleanImagePath(suppliedImage, user.id) : null;

  if (description.length < 10) {
    return json(res, 422, { error: 'Description must be at least 10 characters' });
  }
  if (orderCode && !/^P[A-Z0-9]{11}$/.test(orderCode)) {
    return json(res, 422, { error: 'Invalid order code' });
  }
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
      `&status=in.(open,in_progress)&select=id&limit=${MAX_UNRESOLVED_CASES}`
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

  const rows = await serviceFetch('/rest/v1/ex_support_cases?select=id,case_number,user_id,category,order_code,description,image_path,status,admin_note,created_at,updated_at', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      user_id: user.id,
      category,
      order_code: orderCode,
      description,
      image_path: imagePath
    })
  });

  return json(res, 201, { ok: true, case: rows?.[0] || null });
}, {
  auth: 'required',
  methods: ['POST'],
  event: 'support_case_submission'
});
