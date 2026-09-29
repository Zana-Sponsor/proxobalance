import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.PROXO_SUPABASE_URL;
const SERVICE_KEY = process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const db = SUPABASE_URL && SERVICE_KEY
  ? createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    })
  : null;

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

async function findForm(formId) {
  const { data, error } = await db
    .from('pa_forms')
    .select('id,user_id,title,description,product_image_url,button_text,status')
    .eq('id', formId)
    .eq('status', 'active')
    .maybeSingle();

  if (error) throw error;
  return data || null;
}

async function findFields(formId) {
  const { data, error } = await db
    .from('pa_form_fields')
    .select('id,field_key,label,placeholder,field_type,required,options,sort_order')
    .eq('form_id', formId)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true });

  if (error) throw error;
  return data || [];
}

function validateAnswer(field, raw) {
  const value = cleanString(raw, field.field_type === 'textarea' ? 2000 : 500);

  if (field.required && !value) {
    return { ok: false, message: 'تکایە ئەم خانەیە پڕ بکەرەوە.' };
  }
  if (!value) return { ok: true, value: '' };

  if (field.field_type === 'phone' && !/^[0-9+()\-\s]{6,25}$/.test(value)) {
    return { ok: false, message: 'ژمارەی مۆبایل دروست بنووسە.' };
  }
  if (field.field_type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    return { ok: false, message: 'ئیمەیڵەکە دروست نییە.' };
  }
  if (field.field_type === 'number' && !Number.isFinite(Number(value))) {
    return { ok: false, message: 'تکایە ژمارەیەکی دروست بنووسە.' };
  }
  if (field.field_type === 'select') {
    const options = Array.isArray(field.options) ? field.options.map(String) : [];
    if (options.length && !options.includes(value)) {
      return { ok: false, message: 'هەڵبژاردەکە دروست نییە.' };
    }
  }

  return { ok: true, value };
}

async function handleGet(req, res) {
  const url = new URL(req.url, 'https://' + req.headers.host);
  const formId = cleanString(url.searchParams.get('form_id'), 64);

  if (!UUID_RE.test(formId)) {
    return reply(res, 400, { ok: false, code: 'invalid_form_id', message: 'لینکی فۆڕمەکە دروست نییە.' });
  }

  const form = await findForm(formId);
  if (!form) {
    return reply(res, 404, { ok: false, code: 'form_not_found', message: 'فۆڕمەکە نەدۆزرایەوە یان ناچالاکە.' });
  }

  const fields = await findFields(formId);
  return reply(res, 200, {
    ok: true,
    data: {
      form: {
        id: form.id,
        title: form.title,
        description: form.description,
        product_image_url: form.product_image_url,
        button_text: form.button_text
      },
      fields
    }
  });
}

async function handlePost(req, res) {
  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
  const formId = cleanString(body.form_id, 64);
  const adId = body.ad_id == null ? '' : cleanString(body.ad_id, 64);
  const answers = body.answers && typeof body.answers === 'object' && !Array.isArray(body.answers)
    ? body.answers
    : {};
  const attributionInput = body.attribution && typeof body.attribution === 'object' && !Array.isArray(body.attribution)
    ? body.attribution
    : {};

  if (!UUID_RE.test(formId)) {
    return reply(res, 400, { ok: false, code: 'invalid_form_id', message: 'لینکی فۆڕمەکە دروست نییە.' });
  }
  if (adId && !UUID_RE.test(adId)) {
    return reply(res, 400, { ok: false, code: 'invalid_ad_id', message: 'لینکی ڕیکلامەکە دروست نییە.' });
  }

  const form = await findForm(formId);
  if (!form) {
    return reply(res, 404, { ok: false, code: 'form_not_found', message: 'فۆڕمەکە نەدۆزرایەوە یان ناچالاکە.' });
  }

  const fields = await findFields(formId);
  const cleanedAnswers = {};
  for (const field of fields) {
    const result = validateAnswer(field, answers[field.field_key]);
    if (!result.ok) {
      return reply(res, 422, {
        ok: false,
        code: 'invalid_field',
        field: field.field_key,
        message: result.message
      });
    }
    cleanedAnswers[field.field_key] = result.value;
  }

  let verifiedAdId = null;
  if (adId) {
    const { data: ad, error: adError } = await db
      .from('pa_ads')
      .select('id,user_id,form_id')
      .eq('id', adId)
      .eq('form_id', formId)
      .eq('user_id', form.user_id)
      .maybeSingle();

    if (adError) throw adError;
    if (!ad) {
      return reply(res, 400, {
        ok: false,
        code: 'form_ad_mismatch',
        message: 'ئەم فۆڕمە بەو ڕیکلامەوە پەیوەست نییە.'
      });
    }
    verifiedAdId = ad.id;
  }

  const allowedAttribution = {};
  for (const key of ['ttclid','utm_source','utm_medium','utm_campaign','utm_content','utm_term']) {
    const value = cleanString(attributionInput[key], 500);
    if (value) allowedAttribution[key] = value;
  }

  const { data: submission, error: insertError } = await db
    .from('pa_form_submissions')
    .insert({
      form_id: form.id,
      ad_id: verifiedAdId,
      owner_user_id: form.user_id,
      answers: cleanedAnswers,
      attribution: allowedAttribution
    })
    .select('id,created_at')
    .single();

  if (insertError) throw insertError;

  return reply(res, 201, {
    ok: true,
    data: { submission_id: submission.id, created_at: submission.created_at }
  });
}

export default async function handler(req, res) {
  if (!db) {
    return reply(res, 503, {
      ok: false,
      code: 'forms_not_configured',
      message: 'سیستەمی فۆڕم هێشتا لە سێرڤەر چالاک نەکراوە.'
    });
  }

  try {
    if (req.method === 'GET') return await handleGet(req, res);
    if (req.method === 'POST') return await handlePost(req, res);

    res.setHeader('Allow', 'GET, POST');
    return reply(res, 405, { ok: false, code: 'method_not_allowed', message: 'Method not allowed.' });
  } catch (error) {
    console.error('[api/forms]', error);
    return reply(res, 500, {
      ok: false,
      code: 'server_error',
      message: 'هەڵەیەک ڕوویدا. تکایە دواتر هەوڵ بدەرەوە.'
    });
  }
}
