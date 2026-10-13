// ─────────────────────────────────────────────────────────────
// /api/public  —  approved-order counter + recent transactions feed
//
// PRIVACY BOUNDARY
// The masking is done by the database functions ex_public_feed() /
// ex_mask_phone(), not here. That means the raw phone number is never
// selected into this Node process, never serialised into a response, and
// cannot appear in a network payload or in browser devtools.
//
// Those functions are EXECUTE-revoked from anon/authenticated and granted
// only to service_role, so the anon key that ships inside index.html
// cannot call them directly and bypass the mask.
//
// No authentication required: this is deliberately public data.
// ─────────────────────────────────────────────────────────────
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY;

const db = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
});

function json(res, status, body, cacheSeconds) {
  res.status(status);
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  // Cached at the edge so a burst of visitors costs one database round-trip.
  res.setHeader('Cache-Control', cacheSeconds
    ? `public, s-maxage=${cacheSeconds}, stale-while-revalidate=120`
    : 'no-store');
  return res.send(JSON.stringify(body));
}

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return json(res, 405, { ok: false, error: 'Method not allowed', code: 'method_not_allowed' });
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return json(res, 500, { ok: false, error: 'Server is not configured', code: 'missing_env' });
  }

  try {
    const url   = new URL(req.url, `https://${req.headers.host}`);
    const limit = Math.min(Math.max(parseInt(url.searchParams.get('limit') || '8', 10) || 8, 1), 25);

    const [statsRes, feedRes] = await Promise.all([
      db.rpc('ex_public_stats'),
      db.rpc('ex_public_feed', { lim: limit })
    ]);

    if (statsRes.error) throw statsRes.error;
    if (feedRes.error)  throw feedRes.error;

    // Whitelist the fields that leave the server. Even if the function were
    // changed later to return more columns, nothing extra ships by accident.
    const feed = (feedRes.data || []).map(r => ({
      id:      r.order_code,
      from:    r.from_method,
      to:      r.to_method,
      amount:  Number(r.amount) || 0,
      total:   Number(r.total)  || 0,
      at:      r.created_at,
      phone:   r.phone_masked          // already masked in SQL
    }));

    return json(res, 200, {
      ok: true,
      data: { stats: statsRes.data, feed }
    }, 30);

  } catch (err) {
    console.error('[api/public]', err);
    return json(res, 500, { ok: false, error: 'Internal server error', code: 'server_error' });
  }
}
