import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL =
  process.env.PROXO_SUPABASE_URL ||
  'https://cojchkwssmasiejcgvbk.supabase.co';

const PUBLISHABLE_KEY =
  process.env.PROXO_SUPABASE_PUBLISHABLE_KEY ||
  'sb_publishable_JanNTCMM7FLh6NQbod-Qlw_Xk0aL76M';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const MAX_BODY_BYTES = 32 * 1024;
const MAX_ANSWER_KEYS = 20;
const MAX_ATTRIBUTION_KEYS = 10;

function requestError(message, status = 400) {
  return Object.assign(new Error(message), { status });
}

async function readJsonLimited(req, maxBytes = MAX_BODY_BYTES) {
  const rawLength = req.headers?.['content-length'];
  const declared = rawLength == null || rawLength === '' ? 0 : Number(rawLength);
  if (!Number.isFinite(declared) || declared < 0) throw requestError('Invalid Content-Length', 400);
  if (declared > maxBytes) throw requestError('Payload too large', 413);

  if (req.body !== undefined && req.body !== null) {
    const raw = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    if (Buffer.byteLength(raw, 'utf8') > maxBytes) throw requestError('Payload too large', 413);
    if (typeof req.body !== 'string') return req.body;
    try { return JSON.parse(raw || '{}'); }
    catch { throw requestError('Invalid JSON', 400); }
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw requestError('Payload too large', 413);
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8');
  try { return raw ? JSON.parse(raw) : {}; }
  catch { throw requestError('Invalid JSON', 400); }
}

function flatInputObject(value, maxKeys, maxValueChars) {
  if (value == null) return {};
  if (typeof value !== 'object' || Array.isArray(value)) return null;
  const entries = Object.entries(value);
  if (entries.length > maxKeys) return null;
  const out = {};
  for (const [key, item] of entries) {
    if (typeof key !== 'string' || key.length > 80) return null;
    if (item === null || typeof item === 'boolean' || typeof item === 'number') {
      if (typeof item === 'number' && !Number.isFinite(item)) return null;
      out[key] = item;
      continue;
    }
    if (typeof item !== 'string' || item.length > maxValueChars) return null;
    out[key] = item;
  }
  return out;
}

const db = createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false
  }
});

function reply(res, status, body) {
  res.status(status);
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  return res.send(JSON.stringify(body));
}

function cleanString(value, max = 500) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

function statusForCode(code) {
  if (code === 'FORM_NOT_FOUND') return 404;
  if (code === 'INVALID_FIELD') return 422;
  if (code === 'FORM_AD_MISMATCH' || code === 'INVALID_INPUT') return 400;
  return 400;
}

async function handleGet(req, res) {
  const url = new URL(req.url, 'https://' + req.headers.host);
  const formId = cleanString(url.searchParams.get('form_id'), 64);

  if (!UUID_RE.test(formId)) {
    return reply(res, 400, {
      ok: false,
      code: 'invalid_form_id',
      message: 'لینکی فۆڕمەکە دروست نییە.'
    });
  }

  const { data, error } = await db.rpc('pa_get_public_form', {
    p_form_id: formId
  });

  if (error) throw error;

  if (!data?.ok) {
    return reply(res, statusForCode(data?.code), {
      ok: false,
      code: String(data?.code || 'form_not_found').toLowerCase(),
      message: 'فۆڕمەکە نەدۆزرایەوە یان ناچالاکە.'
    });
  }

  return reply(res, 200, {
    ok: true,
    data: {
      form: data.form,
      fields: Array.isArray(data.fields) ? data.fields : []
    }
  });
}

async function handlePost(req, res) {
  const body = await readJsonLimited(req);
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return reply(res, 400, {
      ok: false,
      code: 'invalid_input',
      message: 'زانیارییە نێردراوەکان دروست نین.'
    });
  }

  const formId = cleanString(body.form_id, 64);
  const adId = body.ad_id == null ? '' : cleanString(body.ad_id, 64);

  if (!UUID_RE.test(formId)) {
    return reply(res, 400, {
      ok: false,
      code: 'invalid_form_id',
      message: 'لینکی فۆڕمەکە دروست نییە.'
    });
  }

  if (adId && !UUID_RE.test(adId)) {
    return reply(res, 400, {
      ok: false,
      code: 'invalid_ad_id',
      message: 'لینکی ڕیکلامەکە دروست نییە.'
    });
  }

  const answers = flatInputObject(body.answers, MAX_ANSWER_KEYS, 2000);
  const attribution = flatInputObject(body.attribution, MAX_ATTRIBUTION_KEYS, 500);
  if (!answers || !attribution) {
    return reply(res, 400, {
      ok: false,
      code: 'invalid_input',
      message: 'زانیارییە نێردراوەکان دروست نین.'
    });
  }

  const { data, error } = await db.rpc('pa_submit_public_form', {
    p_form_id: formId,
    p_ad_id: adId || null,
    p_answers: answers,
    p_attribution: attribution
  });

  if (error) throw error;

  if (!data?.ok) {
    const code = String(data?.code || 'INVALID_INPUT');
    const fallback =
      code === 'FORM_AD_MISMATCH'
        ? 'ئەم فۆڕمە بەو ڕیکلامەوە پەیوەست نییە.'
        : code === 'FORM_NOT_FOUND'
          ? 'فۆڕمەکە نەدۆزرایەوە یان ناچالاکە.'
          : 'زانیارییەکان دروست نین.';

    return reply(res, statusForCode(code), {
      ok: false,
      code: code.toLowerCase(),
      field: data?.field || null,
      message: data?.message || fallback
    });
  }

  return reply(res, 201, {
    ok: true,
    data: {
      submission_id: data.submission_id
    }
  });
}

export default async function handler(req, res) {
  try {
    if (req.method === 'GET') return await handleGet(req, res);
    if (req.method === 'POST') return await handlePost(req, res);

    res.setHeader('Allow', 'GET, POST');
    return reply(res, 405, {
      ok: false,
      code: 'method_not_allowed',
      message: 'Method not allowed.'
    });
  } catch (error) {
    const status = Number(error?.status) || 500;
    if (status === 413) {
      return reply(res, 413, {
        ok: false,
        code: 'payload_too_large',
        message: 'قەبارەی زانیارییە نێردراوەکان زۆر گەورەیە.'
      });
    }
    if (status === 400 || error instanceof SyntaxError) {
      return reply(res, 400, {
        ok: false,
        code: 'invalid_json',
        message: 'زانیارییە نێردراوەکان دروست نین.'
      });
    }
    console.error('[api/forms]', error);
    return reply(res, 500, {
      ok: false,
      code: 'server_error',
      message: 'هەڵەیەک ڕوویدا. تکایە دواتر هەوڵ بدەرەوە.'
    });
  }
}
