import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL =
  process.env.PROXO_SUPABASE_URL ||
  'https://cojchkwssmasiejcgvbk.supabase.co';

const PUBLISHABLE_KEY =
  process.env.PROXO_SUPABASE_PUBLISHABLE_KEY ||
  'sb_publishable_JanNTCMM7FLh6NQbod-Qlw_Xk0aL76M';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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
  const body =
    typeof req.body === 'string'
      ? JSON.parse(req.body || '{}')
      : (req.body || {});

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

  const answers =
    body.answers && typeof body.answers === 'object' && !Array.isArray(body.answers)
      ? body.answers
      : {};

  const attribution =
    body.attribution &&
    typeof body.attribution === 'object' &&
    !Array.isArray(body.attribution)
      ? body.attribution
      : {};

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
    console.error('[api/forms]', error);
    return reply(res, 500, {
      ok: false,
      code: 'server_error',
      message: 'هەڵەیەک ڕوویدا. تکایە دواتر هەوڵ بدەرەوە.'
    });
  }
}
