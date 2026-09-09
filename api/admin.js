// ─────────────────────────────────────────────────────────────
// /api/admin  —  privileged operations, service-role only
//
// The service-role key NEVER reaches the browser. Every request is
// authenticated with the caller's own Supabase access token, and the
// caller must be an admin in ex_profiles before anything runs.
//
// Request:  POST /api/admin
//           Authorization: Bearer <supabase access_token>
//           { "action": "approve_order", "payload": { ... } }
//
// Response: 200 { ok: true,  data: ... }
//           4xx/5xx { ok: false, error: "...", code: "..." }
// ─────────────────────────────────────────────────────────────
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://pycxuugoblkslvwebxuu.supabase.co';
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

// Lazy initialization so missing environment variables do not crash server boot
let dbClient = null;
function getDb() {
  if (!dbClient) {
    if (!SUPABASE_URL || !SERVICE_KEY) {
      throw Object.assign(new Error('Server is not configured'), { status: 500, code: 'missing_env' });
    }
    dbClient = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    });
  }
  return dbClient;
}

const db = new Proxy({}, {
  get(_, prop) {
    const client = getDb();
    const val = client[prop];
    return typeof val === 'function' ? val.bind(client) : val;
  }
});

const STATUS_PENDING  = 'چاوەڕوانە';
const STATUS_APPROVED = 'پەسەندکرا';
const STATUS_REJECTED = 'ڕەتکرا';
const SUPPORT_STATUSES = new Set(['open', 'in_progress', 'resolved', 'closed']);

function supportStatusLabel(status) {
  return status === 'open' ? 'نوێ'
    : status === 'in_progress' ? 'لەژێر پشکنینە'
    : status === 'resolved' ? 'چارەسەرکرا'
    : 'داخراوە';
}

function json(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  return res.send(JSON.stringify(body));
}
const ok   = (res, data)                 => json(res, 200, { ok: true, data });
const fail = (res, status, error, code)  => json(res, status, { ok: false, error, code });

async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;      // Vercel parsed it
  if (typeof req.body === 'string') { try { return JSON.parse(req.body); } catch { return {}; } }
  const chunks = [];
  for await (const c of req) chunks.push(c);
  if (!chunks.length) return {};
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return {}; }
}

// ── auth gate ────────────────────────────────────────────────
// Returns { user, profile } or throws { status, code, message }
async function requireAdmin(req) {
  const header = req.headers.authorization || req.headers.Authorization || '';
  const token  = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) throw { status: 401, code: 'no_token', message: 'Missing Authorization header' };

  // Verifies the JWT signature + expiry against your Supabase project
  const { data: userData, error: userErr } = await db.auth.getUser(token);
  if (userErr || !userData?.user) {
    throw { status: 401, code: 'invalid_token', message: 'Invalid or expired session' };
  }
  const user = userData.user;

  const { data: profile, error: profErr } = await db
    .from('ex_profiles')
    .select('id, is_admin, is_banned, full_name, email')
    .eq('id', user.id)
    .single();

  if (profErr || !profile) throw { status: 403, code: 'no_profile', message: 'Profile not found' };
  if (profile.is_banned)   throw { status: 403, code: 'banned',     message: 'Account is banned' };
  if (!profile.is_admin)   throw { status: 403, code: 'not_admin',  message: 'Admin privileges required' };

  return { user, profile };
}

async function audit(adminId, action, targetUserId, detail) {
  try {
    await db.from('ex_admin_audit_log').insert({
      admin_id: adminId, action, target_user_id: targetUserId || null, detail: detail || null
    });
  } catch { /* auditing must never break the operation */ }
}

// ── actions ──────────────────────────────────────────────────
const actions = {
  async ping(_payload, ctx) {
    return { pong: true, admin: ctx.profile.email };
  },

  async approve_order({ order_id, payout_receipt_url, admin_note }, ctx) {
    if (!order_id) throw { status: 400, code: 'bad_input', message: 'order_id is required' };

    const { data: order, error: e1 } = await db
      .from('ex_orders').select('*').eq('id', order_id).single();
    if (e1 || !order) throw { status: 404, code: 'not_found', message: 'Order not found' };
    if (order.status !== STATUS_PENDING) {
      throw { status: 409, code: 'already_decided', message: 'Order is not pending any more' };
    }

    const patch = { status: STATUS_APPROVED, decided_at: new Date().toISOString() };
    if (payout_receipt_url) patch.payout_receipt_url = String(payout_receipt_url).slice(0, 2000);
    if (admin_note)         patch.admin_note         = String(admin_note).slice(0, 500);

    const { data, error } = await db.from('ex_orders').update(patch).eq('id', order_id).select().single();
    if (error) throw { status: 500, code: 'db_error', message: error.message };

    await audit(ctx.user.id, 'approve_order', order.user_id, data.order_code);
    return data;
  },

  async reject_order({ order_id, reason }, ctx) {
    if (!order_id) throw { status: 400, code: 'bad_input', message: 'order_id is required' };

    const { data: order, error: e1 } = await db
      .from('ex_orders').select('*').eq('id', order_id).single();
    if (e1 || !order) throw { status: 404, code: 'not_found', message: 'Order not found' };
    if (order.status !== STATUS_PENDING) {
      throw { status: 409, code: 'already_decided', message: 'Order is not pending any more' };
    }

    const { data, error } = await db.from('ex_orders').update({
      status: STATUS_REJECTED,
      admin_note: reason ? String(reason).slice(0, 500) : null,
      decided_at: new Date().toISOString()
    }).eq('id', order_id).select().single();
    if (error) throw { status: 500, code: 'db_error', message: error.message };

    await audit(ctx.user.id, 'reject_order', order.user_id, data.order_code);
    return data;
  },

  async set_ban({ user_id, banned }, ctx) {
    if (!user_id) throw { status: 400, code: 'bad_input', message: 'user_id is required' };
    if (user_id === ctx.user.id) {
      throw { status: 400, code: 'self_ban', message: 'You cannot ban yourself' };
    }
    const { data, error } = await db.from('ex_profiles')
      .update({ is_banned: !!banned }).eq('id', user_id).select('id, is_banned').single();
    if (error) throw { status: 500, code: 'db_error', message: error.message };

    await audit(ctx.user.id, banned ? 'ban_user' : 'unban_user', user_id, null);
    return data;
  },

  async broadcast({ title, message, deliver_to_new }, ctx) {
    if (!title || !message) throw { status: 400, code: 'bad_input', message: 'title and message are required' };

    const { data: bc, error: e1 } = await db.from('ex_broadcasts').insert({
      title: String(title).slice(0, 200),
      message: String(message).slice(0, 2000),
      created_by: ctx.user.id,
      deliver_to_new: deliver_to_new !== false
    }).select().single();
    if (e1) throw { status: 500, code: 'db_error', message: e1.message };

    const { data: users, error: e2 } = await db.from('ex_profiles').select('id').eq('is_banned', false);
    if (e2) throw { status: 500, code: 'db_error', message: e2.message };

    const rows = (users || []).map(u => ({
      user_id: u.id, type: 'admin', title: bc.title, message: bc.message, broadcast_id: bc.id
    }));
    if (rows.length) {
      const { error: e3 } = await db.from('ex_notifications').insert(rows);
      if (e3) throw { status: 500, code: 'db_error', message: e3.message };
    }

    await audit(ctx.user.id, 'broadcast', null, bc.title);
    return { broadcast_id: bc.id, delivered: rows.length };
  },

  async support_case_summary(_payload, _ctx) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const [openResult, progressResult, resolvedResult, todayResult] = await Promise.all([
      db.from('ex_support_cases').select('id', { count: 'exact', head: true }).eq('status', 'open'),
      db.from('ex_support_cases').select('id', { count: 'exact', head: true }).eq('status', 'in_progress'),
      db.from('ex_support_cases').select('id', { count: 'exact', head: true }).eq('status', 'resolved'),
      db.from('ex_support_cases').select('id', { count: 'exact', head: true }).gte('created_at', today.toISOString())
    ]);
    const failed = [openResult, progressResult, resolvedResult, todayResult].find(result => result.error);
    if (failed) throw { status: 500, code: 'db_error', message: failed.error.message };
    return {
      open: openResult.count || 0,
      in_progress: progressResult.count || 0,
      unresolved: (openResult.count || 0) + (progressResult.count || 0),
      resolved: resolvedResult.count || 0,
      today: todayResult.count || 0
    };
  },

  async list_support_cases({ status = 'unresolved', limit = 200 }, _ctx) {
    const safeLimit = Math.max(1, Math.min(300, Number(limit) || 200));
    const safeStatus = ['unresolved', 'all', ...SUPPORT_STATUSES].includes(status) ? status : 'unresolved';
    let query = db.from('ex_support_cases').select('*').order('created_at', { ascending: false }).limit(safeLimit);
    if (safeStatus === 'unresolved') query = query.in('status', ['open', 'in_progress']);
    else if (safeStatus !== 'all') query = query.eq('status', safeStatus);
    const { data: cases, error } = await query;
    if (error) throw { status: 500, code: 'db_error', message: error.message };

    const userIds = [...new Set((cases || []).map(row => row.user_id).filter(Boolean))];
    let profileMap = {};
    if (userIds.length) {
      const { data: profiles, error: profileError } = await db
        .from('ex_profiles').select('id,full_name,email,phone').in('id', userIds);
      if (profileError) throw { status: 500, code: 'db_error', message: profileError.message };
      profileMap = Object.fromEntries((profiles || []).map(profile => [profile.id, profile]));
    }

    return Promise.all((cases || []).map(async row => {
      let imageUrl = null;
      if (row.image_path) {
        const { data } = await db.storage.from('support-case-images').createSignedUrl(row.image_path, 600);
        imageUrl = data?.signedUrl || null;
      }
      return { ...row, profile: profileMap[row.user_id] || null, image_url: imageUrl };
    }));
  },

  async update_support_case({ id, status, admin_note }, ctx) {
    if (!id || !SUPPORT_STATUSES.has(status)) {
      throw { status: 400, code: 'bad_input', message: 'Valid case id and status are required' };
    }
    const note = String(admin_note == null ? '' : admin_note).trim().slice(0, 2000) || null;
    const { data: existing, error: findError } = await db
      .from('ex_support_cases').select('*').eq('id', id).maybeSingle();
    if (findError) throw { status: 500, code: 'db_error', message: findError.message };
    if (!existing) throw { status: 404, code: 'not_found', message: 'Support case not found' };

    const now = new Date().toISOString();
    const patch = {
      status,
      admin_note: note,
      assigned_admin: ctx.user.id,
      updated_at: now,
      resolved_at: ['resolved', 'closed'].includes(status) ? (existing.resolved_at || now) : null
    };
    const { data, error } = await db.from('ex_support_cases')
      .update(patch).eq('id', id).select().single();
    if (error) throw { status: 500, code: 'db_error', message: error.message };

    let notificationSent = false;
    if (existing.status !== data.status || (existing.admin_note || null) !== note) {
      const caseLabel = String(data.case_number).padStart(6, '0');
      const message = `دۆخ: ${supportStatusLabel(data.status)}` + (note ? ` — ${note}` : '');
      try {
        const { error: notificationError } = await db.from('ex_notifications').insert({
          user_id: data.user_id,
          type: 'support_case',
          title: `کەیسی ${caseLabel} نوێکرایەوە`,
          message: message.slice(0, 2000),
          support_case_id: data.id
        });
        notificationSent = !notificationError;
      } catch { /* a notification failure must not undo the case update */ }
    }

    await audit(ctx.user.id, 'update_support_case', data.user_id, `${String(data.case_number).padStart(6, '0')}: ${data.status}`);
    return { ...data, notification_sent: notificationSent };
  },

  async error_log_summary(_payload, _ctx) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const [unresolvedResult, recentResult, criticalResult] = await Promise.all([
      db.from('ex_error_logs').select('id', { count: 'exact', head: true }).is('resolved_at', null),
      db.from('ex_error_logs').select('id', { count: 'exact', head: true }).gte('last_seen', since),
      db.from('ex_error_logs').select('id', { count: 'exact', head: true }).is('resolved_at', null).eq('severity', 'critical')
    ]);
    const failed = [unresolvedResult, recentResult, criticalResult].find(result => result.error);
    if (failed) throw { status: 500, code: 'db_error', message: failed.error.message };
    return {
      unresolved: unresolvedResult.count || 0,
      last_24h: recentResult.count || 0,
      critical: criticalResult.count || 0
    };
  },

  async list_error_logs({ status = 'unresolved', limit = 200 }, _ctx) {
    const safeLimit = Math.max(1, Math.min(300, Number(limit) || 200));
    const safeStatus = ['unresolved', 'resolved', 'all'].includes(status) ? status : 'unresolved';
    let query = db.from('ex_error_logs').select('*').order('last_seen', { ascending: false }).limit(safeLimit);
    if (safeStatus === 'unresolved') query = query.is('resolved_at', null);
    if (safeStatus === 'resolved') query = query.not('resolved_at', 'is', null);
    const { data, error } = await query;
    if (error) throw { status: 500, code: 'db_error', message: error.message };
    return data || [];
  },

  async resolve_error_log({ id }, ctx) {
    if (!id) throw { status: 400, code: 'bad_input', message: 'id is required' };
    const { data, error } = await db.from('ex_error_logs')
      .update({ resolved_at: new Date().toISOString(), resolved_by: ctx.user.id })
      .eq('id', id).is('resolved_at', null).select('id').maybeSingle();
    if (error) throw { status: 500, code: 'db_error', message: error.message };
    await audit(ctx.user.id, 'resolve_error_log', null, String(id).slice(0, 80));
    return { id, resolved: !!data };
  },

  async resolve_all_error_logs(_payload, ctx) {
    const { data, error } = await db.from('ex_error_logs')
      .update({ resolved_at: new Date().toISOString(), resolved_by: ctx.user.id })
      .is('resolved_at', null).select('id');
    if (error) throw { status: 500, code: 'db_error', message: error.message };
    await audit(ctx.user.id, 'resolve_all_error_logs', null, String((data || []).length));
    return { resolved: (data || []).length };
  }
};

// ── handler ──────────────────────────────────────────────────
export default async function handler(req, res) {
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return fail(res, 405, 'Method not allowed', 'method_not_allowed');
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    // Config problem, not the caller's fault — and never echo the key back.
    return fail(res, 500, 'Server is not configured', 'missing_env');
  }

  try {
    const ctx  = await requireAdmin(req);
    const body = await readBody(req);
    const name = String(body.action || '');
    const run  = actions[name];

    if (!run) return fail(res, 400, 'Unknown action: ' + name, 'unknown_action');

    const data = await run(body.payload || {}, ctx);
    return ok(res, data);

  } catch (err) {
    if (err && err.status) return fail(res, err.status, err.message, err.code);
    console.error('[api/admin]', err);           // full detail stays in Vercel logs
    return fail(res, 500, 'Internal server error', 'server_error');
  }
}
