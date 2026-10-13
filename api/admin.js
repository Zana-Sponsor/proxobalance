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
const STATUS_NEEDS_CORRECTION = 'پێویستی بە ڕاستکردنەوەیە';
const STATUS_CORRECTED = 'ڕاستکراوەتەوە';
const REVIEWABLE_ORDER_STATUSES = new Set([STATUS_PENDING, STATUS_CORRECTED]);
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
  async account_balances({user_ids}) {
    if (!Array.isArray(user_ids) || user_ids.length > 200 ||
        user_ids.some(id => typeof id !== 'string' ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)))
      throw {status:400,code:'bad_users',message:'Provide up to 200 valid user IDs'};
    const ids = [...new Set(user_ids.map(id => id.toLowerCase()))];
    if (!ids.length) return [];
    const {data,error} = await db.from('ex_customer_balances')
      .select('user_id,available_iqd,held_iqd,updated_at').in('user_id',ids);
    if (error) throw {status:500,code:'db_error',message:error.message};
    const balances = new Map((data || []).map(row => [row.user_id,row]));
    return ids.map(user_id => balances.get(user_id) ||
      {user_id,available_iqd:0,held_iqd:0,updated_at:null});
  },

  // Refund credits and wallet payouts are committed atomically by service-only
  // PostgreSQL RPCs. A browser never chooses a balance delta.
  async balance_dashboard(_payload,_ctx) {
    const [balances,refunds,payouts,alerts,config] = await Promise.all([
      db.from('ex_customer_balances').select('*').or('available_iqd.gt.0,held_iqd.gt.0').order('updated_at',{ascending:false}).limit(150),
      db.from('ex_refund_cases').select('*').order('created_at',{ascending:false}).limit(150),
      db.from('ex_payout_requests').select('*').order('created_at',{ascending:false}).limit(150),
      db.from('ex_balance_risk_alerts').select('*').eq('status','open').order('created_at',{ascending:false}).limit(100),
      db.from('ex_balance_config').select('*').eq('id',true).single()
    ]);
    for(const r of [balances,refunds,payouts,alerts,config]) if(r.error)throw r.error;
    const ids=[...new Set([...(balances.data||[]),...(refunds.data||[]),
      ...(payouts.data||[]),...(alerts.data||[])].map(x=>x.user_id).filter(Boolean))];
    const names=ids.length?await db.from('ex_profiles').select('id,full_name,username,email').in('id',ids):{data:[],error:null};
    if(names.error)throw names.error;
    const reconciliation=await db.rpc('ex_admin_balance_reconcile',{p_admin_id:_ctx.user.id});
    if(reconciliation.error)throw reconciliation.error;
    const profiles=Object.fromEntries((names.data||[]).map(p=>[p.id,p]));
    return {balances:balances.data||[],refunds:refunds.data||[],
      payouts:payouts.data||[],alerts:alerts.data||[],config:config.data,profiles,
      reconciliation:reconciliation.data};
  },

  async balance_lookup_order({search},_ctx){
    const q=String(search||'').trim();
    if(!/^(?:[0-9a-f-]{36}|P[A-Z0-9]{11})$/i.test(q))
      throw {status:400,code:'invalid_order',message:'Enter an exact order code or UUID'};
    let query=db.from('ex_orders')
      .select('id,order_code,user_id,amount,total,fee,from_method,to_method,receipt_url,receipt_hash,payout_receipt_url,status,created_at,decided_at,balance_refunded_at')
      .limit(1);
    query=/^[0-9a-f-]{36}$/i.test(q)?query.eq('id',q):query.eq('order_code',q.toUpperCase());
    const {data:order,error}=await query.maybeSingle();
    if(error)throw error;
    if(!order)throw {status:404,code:'order_not_found',message:'Order not found'};
    const [p,r]=await Promise.all([
      db.from('ex_profiles').select('id,full_name,username,email').eq('id',order.user_id).maybeSingle(),
      db.from('ex_refund_cases').select('id,status,amount_iqd,created_at,bank_verification_reference')
        .eq('order_id',order.id).maybeSingle()
    ]);
    if(p.error)throw p.error;if(r.error)throw r.error;
    return {order,profile:p.data,refund:r.data};
  },

  async balance_credit_refund({order_id,verification_reference,reason,failure_reason,
    confirmed_received},ctx){
    if(confirmed_received!==true)
      throw {status:400,code:'confirmation_required',message:'Confirm that customer funds were received'};
    const {data,error}=await db.rpc('ex_admin_reject_and_refund',{
      p_order_id:order_id,p_admin_id:ctx.user.id,
      p_verification_reference:String(verification_reference||'').trim().slice(0,160),
      p_reason:String(reason||failure_reason||'').trim().slice(0,2000),
      p_confirmed_received:true
    });
    if(error){
      if(['23505','23514'].includes(error.code)){
        const order=await db.from('ex_orders').select('user_id').eq('id',order_id).maybeSingle();
        await db.from('ex_balance_risk_alerts').insert({
          user_id:order.data?.user_id||null,kind:'duplicate_or_ineligible_refund',
          reference_id:order_id,details:{code:error.code,actor:ctx.user.id}
        });
      }
      throw {status:409,code:error.code||'refund_failed',message:error.message};
    }
    return data;
  },

  async balance_claim_payout({payout_id,verification},ctx){
    const {data,error}=await db.rpc('ex_balance_claim_payout',{
      p_payout_id:payout_id,p_admin_id:ctx.user.id,
      p_verification:String(verification||'').trim().slice(0,160)
    });
    if(error)throw {status:409,code:error.code||'claim_failed',message:error.message};
    return data;
  },

  async balance_abort_processing({payout_id,reason,bank_reference,confirmed_unpaid},ctx){
    if(confirmed_unpaid!==true)
      throw {status:400,code:'proof_required',message:'Bank confirmation of nonpayment required'};
    const {data,error}=await db.rpc('ex_balance_abort_processing',{
      p_payout_id:payout_id,p_admin_id:ctx.user.id,
      p_reason:String(reason||'').trim().slice(0,500),
      p_bank_reference:String(bank_reference||'').trim().slice(0,160),
      p_confirmed_unpaid:true
    });
    if(error)throw {status:409,code:error.code||'abort_failed',message:error.message};
    return data;
  },

  async balance_cancel_payout({payout_id,reason},ctx){
    const {data,error}=await db.rpc('ex_balance_cancel_payout',{
      p_payout_id:payout_id,p_actor:ctx.user.id,
      p_reason:String(reason||'Cancelled by admin').slice(0,500)
    });
    if(error)throw {status:409,code:error.code||'cancel_failed',message:error.message};
    await audit(ctx.user.id,'balance_payout_cancelled',data.user_id,String(data.id));
    return data;
  },

  async balance_mark_payout_paid({payout_id,transfer_reference,
    destination_verification,receipt_url,note,confirmed},ctx){
    if(confirmed!==true)
      throw {status:400,code:'confirmation_required',message:'Actual external transfer must be verified'};
    const {data,error}=await db.rpc('ex_balance_mark_payout_paid',{
      p_payout_id:payout_id,p_admin_id:ctx.user.id,
      p_reference:String(transfer_reference||'').trim().slice(0,160),
      p_verification_reference:String(destination_verification||'').trim().slice(0,160),
      p_receipt_url:String(receipt_url||'').trim().slice(0,2000),
      p_note:String(note||'').trim().slice(0,500)
    });
    if(error)throw {status:409,code:error.code||'payout_failed',message:error.message};
    return data;
  },

  async balance_resolve_risk({id,status},ctx){
    if(!['reviewed','dismissed'].includes(status))
      throw {status:400,code:'bad_status',message:'Invalid resolution'};
    const {data,error}=await db.from('ex_balance_risk_alerts').update({
      status,resolved_at:new Date().toISOString(),resolved_by:ctx.user.id
    }).eq('id',id).eq('status','open').select().maybeSingle();
    if(error)throw error;
    if(data)await audit(ctx.user.id,'balance_risk_'+status,data.user_id,String(id));
    return {updated:!!data};
  },

  async ping(_payload, ctx) {
    return { pong: true, admin: ctx.profile.email };
  },

  async approve_order({ order_id, payout_receipt_url, admin_note }, ctx) {
    if (!order_id) throw { status: 400, code: 'bad_input', message: 'order_id is required' };

    const { data: order, error: e1 } = await db
      .from('ex_orders').select('*').eq('id', order_id).single();
    if (e1 || !order) throw { status: 404, code: 'not_found', message: 'Order not found' };
    if (order.balance_refunded_at || !REVIEWABLE_ORDER_STATUSES.has(order.status)) {
      throw { status: 409, code: 'already_decided', message: 'Order is not ready for review' };
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
    if (order.balance_refunded_at || !REVIEWABLE_ORDER_STATUSES.has(order.status)) {
      throw { status: 409, code: 'already_decided', message: 'Order is not ready for review' };
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

  async request_order_correction({ order_id, reason }, ctx) {
    if (!order_id) throw { status: 400, code: 'bad_input', message: 'order_id is required' };
    const correctionRequest = String(reason == null ? '' : reason).trim().slice(0, 2000);
    if (correctionRequest.length < 5) {
      throw { status: 422, code: 'correction_required', message: 'Correction request must be at least 5 characters' };
    }

    const { data: order, error: findError } = await db
      .from('ex_orders').select('*').eq('id', order_id).single();
    if (findError || !order) throw { status: 404, code: 'not_found', message: 'Order not found' };
    if (![STATUS_PENDING, STATUS_CORRECTED, STATUS_NEEDS_CORRECTION].includes(order.status)) {
      throw { status: 409, code: 'already_decided', message: 'A decided order cannot be corrected' };
    }

    const now = new Date().toISOString();
    const { data, error } = await db.from('ex_orders').update({
      status: STATUS_NEEDS_CORRECTION,
      correction_request: correctionRequest,
      correction_requested_at: now,
      correction_requested_by: ctx.user.id,
      correction_response: null,
      correction_responded_at: null,
      correction_count: Number(order.correction_count || 0) + 1,
      decided_at: null,
      updated_at: now
    }).eq('id', order_id).in('status', [STATUS_PENDING, STATUS_CORRECTED, STATUS_NEEDS_CORRECTION]).select().maybeSingle();
    if (error) throw { status: 500, code: 'db_error', message: error.message };
    if (!data) throw { status: 409, code: 'state_changed', message: 'Order state changed; please refresh' };

    let notificationSent = false;
    try {
      const code = data.order_code || String(data.order_number || '');
      const { error: notificationError } = await db.from('ex_notifications').insert({
        user_id: data.user_id,
        type: 'order_status',
        title: `داوای ڕاستکردنەوەی مامەڵەی ${code}`,
        message: correctionRequest,
        order_id: data.id
      });
      notificationSent = !notificationError;
    } catch { /* notification failure must not undo the order update */ }

    await audit(ctx.user.id, 'request_order_correction', data.user_id, `${data.order_code || data.order_number}: ${correctionRequest}`);
    return { ...data, notification_sent: notificationSent };
  },

  async list_order_correction_history({ order_id }, _ctx) {
    if (!order_id) throw { status: 400, code: 'bad_input', message: 'order_id is required' };

    const { data: order, error: orderError } = await db
      .from('ex_orders').select('id').eq('id', order_id).maybeSingle();
    if (orderError) throw { status: 500, code: 'db_error', message: orderError.message };
    if (!order) throw { status: 404, code: 'not_found', message: 'Order not found' };

    const { data, error } = await db
      .from('ex_order_correction_history')
      .select('id,order_id,correction_number,request,requested_at,old_data,new_data,customer_response,responded_at')
      .eq('order_id', order_id)
      .order('correction_number', { ascending: false });
    if (error) throw { status: 500, code: 'db_error', message: error.message };
    return data || [];
  },

  // All reward writes are server-only, after requireAdmin() verifies the JWT
  // and ex_profiles.is_admin. Never accept reward values from the customer UI.
  async list_rewards({ limit = 100 }, _ctx) {
    const count = Number.isInteger(Number(limit)) ? Math.min(200, Math.max(1, Number(limit))) : 100;
    const db = getDb();
    const { data, error } = await db.from('ex_user_rewards').select('*')
      .order('created_at', { ascending: false }).limit(count);
    if (error) throw error;
    const ids = [...new Set((data || []).map(r => r.user_id))];
    let profiles = [];
    if (ids.length) {
      const result = await db.from('ex_profiles').select('id,full_name,username,email').in('id', ids);
      if (result.error) throw result.error;
      profiles = result.data || [];
    }
    const names = new Map(profiles.map(p => [p.id, p]));
    return (data || []).map(r => ({ ...r, profile: names.get(r.user_id) || null }));
  },

  async grant_reward({ user_id, kind, discount_percent, max_uses, max_amount_iqd, reward_scope = 'wallets', valid_until, note }, ctx) {
    if (!/^[0-9a-f-]{36}$/i.test(String(user_id || '')))
      throw { status: 400, code: 'bad_user', message: 'A valid user is required' };
    if (!['free_transactions', 'fee_discount'].includes(kind))
      throw { status: 400, code: 'bad_kind', message: 'Invalid reward type' };
    if (!['wallets','korek','asiacell'].includes(reward_scope))
      throw {status:400,code:'bad_scope',message:'Choose wallets, Korek or Asiacell'};
    const percent = kind === 'free_transactions' ? 100 : Number(discount_percent);
    if (!Number.isFinite(percent) || percent <= 0 || percent > 100)
      throw { status: 400, code: 'bad_discount', message: 'Discount must be between 0 and 100%' };
    const uses = max_uses == null || max_uses === '' ? null : Number(max_uses);
    if ((uses === null && kind === 'free_transactions') ||
        (uses !== null && (!Number.isInteger(uses) || uses < 1 || uses > 1000)))
      throw { status: 400, code: 'bad_uses', message: 'Free transactions need a valid use limit (1–1000)' };
    const cap = max_amount_iqd == null || max_amount_iqd === '' ? null : Number(max_amount_iqd);
    if (cap !== null && (!Number.isSafeInteger(cap) || cap < 1 || cap > 1000000000))
      throw { status: 400, code: 'bad_amount_cap', message: 'Reward amount cap must be 1–1,000,000,000 IQD' };
    const expiry = valid_until ? new Date(valid_until) : null;
    if (expiry && (!Number.isFinite(expiry.getTime()) || expiry.getTime() <= Date.now()))
      throw { status: 400, code: 'bad_expiry', message: 'Expiration must be in the future' };
    const db = getDb();
    const { data: profile, error: profileError } = await db.from('ex_profiles')
      .select('id,is_banned').eq('id', user_id).maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_banned)
      throw { status: 400, code: 'invalid_recipient', message: 'Recipient is missing or banned' };
    const { data, error } = await db.from('ex_user_rewards').insert({
      user_id, kind, discount_percent: percent, max_uses: uses, max_amount_iqd: cap, reward_scope,
      valid_until: expiry ? expiry.toISOString() : null,
      note: String(note || '').trim().slice(0, 200) || null,
      created_by: ctx.user.id
    }).select().single();
    if (error) throw error;
    await audit(ctx.user.id, 'grant_reward', user_id, data.id + ' ' + kind + ' ' + percent + '% / ' + (uses ?? 'unlimited') + ' cap_iqd:' + (cap ?? 'unlimited')+' scope:'+reward_scope);
    // A failed notification must never undo an already committed reward.
    try {
      await db.from('ex_notifications').insert({
        user_id, type: 'admin', title: 'پاداشتێکت پێدرا',
        message: (kind === 'free_transactions'
          ? 'ژمارەی ' + uses + ' مامەڵەی بێ لێبڕینت پێدرا.'
          : 'داشکاندنی ' + percent + '% لە لێبڕینت پێدرا.') +
          (cap !== null ? ' پاداشت تا بڕی ' + cap.toLocaleString('en-US') + ' دینار بۆ هەر مامەڵەیەکە؛ بڕی زیادە بە لێبڕینی ئاسایی هەژمار دەکرێت.' : '')+
          ' تایبەت بە '+({wallets:'جزدانەکان',korek:'کۆڕەک',asiacell:'ئاسیاسێڵ'})[reward_scope]+'.'
      });
    } catch (_) { /* reward is already saved */ }
    return data;
  },

  async revoke_reward({ id }, ctx) {
    if (!/^[0-9a-f-]{36}$/i.test(String(id || '')))
      throw { status: 400, code: 'bad_reward', message: 'Valid reward ID required' };
    const { data, error } = await getDb().from('ex_user_rewards')
      .update({ active: false, updated_at: new Date().toISOString() })
      .eq('id', id).eq('active', true).select().maybeSingle();
    if (error) throw error;
    if (data) await audit(ctx.user.id, 'revoke_reward', data.user_id, data.id);
    return { revoked: !!data };
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
