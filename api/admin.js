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
import { payoutPlan } from './_lib/payout-rounding.js';

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
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REFUND_REPORT_PAGE_SIZE = 100;
const REFUND_ORDER_FIELDS = 'id,order_code,user_id,amount,total,from_method,to_method,status,balance_refunded_at,payout_iqd,payout_rounding_iqd,payout_settlement_id';
const BAGHDAD_CALENDAR = new Intl.DateTimeFormat('en-US-u-ca-gregory-nu-latn', {
  timeZone:'Asia/Baghdad',year:'numeric',month:'2-digit',day:'2-digit',era:'short'
});

function refundReportDate(value) {
  if(value==null||value==='')return null;
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value)||value.startsWith('0000'))
    throw {status:400,code:'invalid_report_date',message:'Use a valid YYYY-MM-DD report date'};
  const timestamp=Date.parse(value+'T00:00:00.000Z');
  if(!Number.isFinite(timestamp)||new Date(timestamp).toISOString().slice(0,10)!==value)
    throw {status:400,code:'invalid_report_date',message:'Use a valid YYYY-MM-DD report date'};
  return timestamp;
}

// Resolve the start of a Baghdad calendar day with its actual timezone rules.
// Comparing dates also handles historical midnight clock changes correctly.
function baghdadDayStart(timestamp) {
  const targetDate=new Date(timestamp);
  const target=targetDate.getUTCFullYear()*10000+(targetDate.getUTCMonth()+1)*100+targetDate.getUTCDate();
  let low=timestamp-172800000,high=timestamp+172800000;
  while(low<high){
    const middle=Math.floor((low+high)/2);
    const parts=Object.fromEntries(BAGHDAD_CALENDAR.formatToParts(middle).map(p=>[p.type,p.value]));
    const year=parts.era==='BC'?1-Number(parts.year):Number(parts.year);
    const day=year*10000+Number(parts.month)*100+Number(parts.day);
    if(day<target)low=middle+1;else high=middle;
  }
  return new Date(low).toISOString();
}

async function balanceRelationRows(table,fields,ids) {
  const batches=[];
  for(let start=0;start<ids.length;start+=100)
    batches.push(db.from(table).select(fields).in('id',ids.slice(start,start+100)));
  const results=await Promise.all(batches);
  for(const result of results){
    if(result.error)throw result.error;
    if(!Array.isArray(result.data))throw {status:500,code:'refund_details_unavailable',message:'Refund details could not be loaded'};
  }
  return results.flatMap(result=>result.data);
}

async function balanceRefundOrders(rows) {
  const ids=[...new Set(rows.map(row=>row.order_id).filter(Boolean))];
  const data=await balanceRelationRows('ex_orders',REFUND_ORDER_FIELDS,ids);
  return Object.fromEntries(data.map(order=>[order.id,order]));
}

function validApprovalTimestamp(value) {
  if (typeof value !== 'string') return false;
  const match = /^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (!match || match[1].startsWith('0000') || Number(match[2]) > 23 ||
      Number(match[3]) > 59 || Number(match[4]) > 59) return false;
  const day = Date.parse(match[1] + 'T00:00:00.000Z');
  return Number.isFinite(day) && new Date(day).toISOString().slice(0, 10) === match[1] &&
    Number.isFinite(Date.parse(value));
}

function validSettlementReceipt(order, value) {
  const prefix = SUPABASE_URL + '/storage/v1/object/public/receipts/' + order.user_id + '/';
  return typeof value === 'string' && value.length > prefix.length && value.length <= 2000 &&
    value.startsWith(prefix) && !/[\s\u0000-\u001f\u007f?#\\]/.test(value) && !/\.\.|%2e|%2f|%5c/i.test(value.slice(prefix.length));
}

function settlementError(error) {
  const message = String(error?.message || '');
  if (error?.code === '42501' || message.includes('STAFF_PERMISSION_REQUIRED'))
    return {status:403,code:'staff_permission_required',message:'مۆڵەتی پەسەندکردنی ئەم داواکارییەت نییە'};
  const known = [
    ['ORDER_SETTLEMENT_STALE',409,'approval_stale','داواکارییەکە گۆڕاوە؛ نوێی بکەرەوە و بڕی ناردنەکە دووبارە بپشکنە'],
    ['ORDER_ALREADY_DECIDED',409,'already_decided','ئەم داواکارییە پێشتر بڕیاری لەسەر دراوە'],
    ['SETTLEMENT_REQUEST_KEY_CONFLICT',409,'approval_request_conflict','ئەم داواکارییەی پەسەندکردن پێشتر بە زانیارییەکی جیاواز تۆمار کراوە'],
    ['SETTLEMENT_RECEIPT_LOCKED',409,'settlement_receipt_locked','وەسڵی ئەم داواکارییە ناتوانرێت زیاد بکرێت یان بگۆڕدرێت'],
    ['SETTLEMENT_RECEIPT_CONFLICT',409,'settlement_receipt_conflict','وەسڵێکی جیاواز پێشتر بۆ ئەم داواکارییە تۆمار کراوە'],
    ['ORDER_NOT_FOUND',404,'not_found','Order not found'],
    ['INVALID_PAYOUT_RECEIPT',400,'invalid_receipt','وەسڵی ناردن دروست نییە'],
    ['RECEIPT_HAS_MULTIPLE_ORDERS',409,'receipt_multiple_orders','وەسڵی وەرگرتن لە زیاتر لە داواکارییەک بەکارهاتووە'],
    ['RECEIVED_FUNDS_PROOF_REQUIRED',400,'received_funds_proof_required','وەسڵی پارەی وەرگیراو پێویستە'],
    ['BALANCE_DEBIT_PROOF_REQUIRED',400,'balance_debit_proof_required','تۆماری کەمکردنەوەی باڵانسی سەرچاوە پێویستە'],
    ['PAYOUT_AMOUNT_MISMATCH',400,'payout_amount_mismatch','بڕی ناردن و دۆخی پشتڕاستکردنەوە لەگەڵ داواکارییەکە ناگونجێت'],
    ['ORDER_NOT_ELIGIBLE_FOR_SETTLEMENT',400,'invalid_payout_amount','بڕ یان ڕێڕەوی ئەم داواکارییە بۆ پەسەندکردن دروست نییە'],
    ['INVALID_SETTLEMENT_REQUEST',400,'invalid_approval','زانیارییەکانی پەسەندکردن تەواو نییە']
  ];
  const match = known.find(([name]) => message.includes(name));
  if (match) return {status:match[1],code:match[2],message:match[3]};
  if (['PGRST202','42883','42703','42P01'].includes(error?.code))
    return {status:503,code:'settlement_unavailable',message:'پەسەندکردن کاتییە بەردەست نییە؛ هەمان داواکاری دووبارە بنێرەوە'};
  return {status:500,code:'settlement_result_unknown',message:'ئەنجامی کارەکە پشتڕاست نەکرایەوە؛ هەمان داواکاری دووبارە بنێرەوە'};
}

async function settlementRpc(name, args, record) {
  let result;
  try { result = await db.rpc(name, args); }
  catch (error) { throw settlementError(error); }
  if (result?.error) throw settlementError(result.error);
  // JSON and single-row table encodings are both used by PostgREST versions.
  const data = Array.isArray(result?.data)
    ? result.data.length === 1 ? result.data[0] : null : result?.data;
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      !data.order || Array.isArray(data.order) || data.order.id !== args.p_order_id ||
      !data[record] || Array.isArray(data[record]) || !UUID.test(String(data[record].id || '')))
    throw settlementError(null);
  return data;
}

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

async function readBody(req, maxBytes = 64 * 1024) {
  const rawLength = req.headers?.['content-length'];
  const declared = rawLength == null || rawLength === '' ? 0 : Number(rawLength);
  if (!Number.isFinite(declared) || declared < 0)
    throw { status: 400, code: 'invalid_content_length', message: 'Invalid Content-Length' };
  if (declared > maxBytes)
    throw { status: 413, code: 'payload_too_large', message: 'Payload too large' };

  if (req.body !== undefined && req.body !== null) {
    const raw = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    if (Buffer.byteLength(raw, 'utf8') > maxBytes)
      throw { status: 413, code: 'payload_too_large', message: 'Payload too large' };
    if (typeof req.body === 'object') return req.body;
    try { return JSON.parse(raw || '{}'); }
    catch { throw { status: 400, code: 'invalid_json', message: 'Invalid JSON' }; }
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes)
      throw { status: 413, code: 'payload_too_large', message: 'Payload too large' };
    chunks.push(chunk);
  }
  if (!chunks.length) return {};
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw { status: 400, code: 'invalid_json', message: 'Invalid JSON' }; }
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
    .select('id, is_admin, is_banned, full_name, email, role, staff_permissions')
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

// Fresh database profile rights, never browser/JWT user_metadata claims.
export function assertStaffAction(profile,action){
  if(action==='set_ban' && profile.role!=='super_admin')throw {status:403,code:'super_admin_required',message:'SUPER_ADMIN_REQUIRED'};
  if(['error_log_summary','list_error_logs','resolve_error_log','resolve_all_error_logs'].includes(action)&&profile.role!=='super_admin')throw {status:403,code:'super_admin_required',message:'SUPER_ADMIN_REQUIRED'};
  if(profile.role==='super_admin' || profile.staff_permissions==null)return;
  const permissions={
    ping:'view',account_balances:'view',balance_dashboard:'view',balance_lookup_order:'view',
    list_order_correction_history:'view',list_rewards:'view',
    approve_order:'approve_orders',reject_order:'approve_orders',request_order_correction:'approve_orders',
    save_order_note:'approve_orders',save_payout_receipt:'approve_orders',
    balance_credit_refund:'refunds',balance_credit_shortfall:'refunds',balance_refund_report:'refunds',
    balance_cancel_payout:'refunds',balance_abort_processing:'refunds',
    balance_claim_payout:'approve_orders',balance_mark_payout_paid:'approve_orders',
    grant_reward:'manage_rewards',revoke_reward:'manage_rewards'
  };
  const required=permissions[action];
  if(!required || !profile.staff_permissions.includes(required))
    throw {status:403,code:'staff_permission_required',message:'مۆڵەتی ئەنجامدانی ئەم کارەت نییە'};
}

// ── actions ──────────────────────────────────────────────────
const actions = {
  async save_order_note({order_id,admin_note},ctx){
    const note=String(admin_note||'').trim();
    if(!order_id||note.length>500)throw {status:400,code:'bad_note',message:'Invalid order note'};
    const {data,error}=await db.from('ex_orders').update({admin_note:note||null}).eq('id',order_id).select().single();
    if(error||!data)throw {status:404,code:'not_found',message:'Order not found'};
    await audit(ctx.user.id,'save_order_note',data.user_id,data.order_code);
    return data;
  },
  async save_payout_receipt({order_id,payout_receipt_url},ctx){
    if(typeof order_id!=='string'||!UUID.test(order_id))
      throw {status:400,code:'bad_input',message:'A valid order_id is required'};
    order_id=order_id.toLowerCase();
    const {data:order,error:readError}=await db.from('ex_orders').select('id,user_id,balance_refunded_at,payout_settlement_id').eq('id',order_id).single();
    if(readError||!order)throw {status:404,code:'not_found',message:'Order not found'};
    if(order.balance_refunded_at)throw {status:409,code:'already_refunded',message:'Order was already refunded'};
    if(order.payout_settlement_id){
      const receipt=typeof payout_receipt_url==='string'?payout_receipt_url.trim():null;
      if(!validSettlementReceipt(order,receipt))
        throw {status:400,code:'invalid_receipt',message:'Invalid payout receipt'};
      const data=await settlementRpc('ex_admin_attach_settlement_receipt',{
        p_order_id:order_id,p_admin_id:ctx.user.id,p_payout_receipt_url:receipt
      },'receipt');
      return data.order;
    }
    const prefix=SUPABASE_URL+'/storage/v1/object/public/receipts/'+order.user_id+'/';
    if(typeof payout_receipt_url!=='string'||!payout_receipt_url.startsWith(prefix)||payout_receipt_url.length>2000)
      throw {status:400,code:'invalid_receipt',message:'Invalid payout receipt'};
    const {data,error}=await db.from('ex_orders').update({payout_receipt_url}).eq('id',order_id).is('balance_refunded_at',null).select().single();
    if(error||!data)throw {status:409,code:'receipt_not_saved',message:'Receipt could not be saved'};
    await audit(ctx.user.id,'save_payout_receipt',order.user_id,data.order_code);
    return data;
  },
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
  // PostgreSQL RPCs. The database validates the order and any shortfall amount;
  // a browser never chooses the credited account or its resulting balance.
  async balance_dashboard(_payload,_ctx) {
    const [balances,refunds,shortfalls,payouts,alerts,config] = await Promise.all([
      db.from('ex_customer_balances').select('*').or('available_iqd.gt.0,held_iqd.gt.0').order('updated_at',{ascending:false}).limit(150),
      db.from('ex_refund_cases').select('*').order('created_at',{ascending:false}).limit(150),
      db.from('ex_order_shortfall_refunds').select('*').order('created_at',{ascending:false}).limit(150),
      db.from('ex_payout_requests').select('*').order('created_at',{ascending:false}).limit(150),
      db.from('ex_balance_risk_alerts').select('*').eq('status','open').order('created_at',{ascending:false}).limit(100),
      db.from('ex_balance_config').select('*').eq('id',true).single()
    ]);
    for(const r of [balances,refunds,shortfalls,payouts,alerts,config]) if(r.error)throw r.error;
    const ids=[...new Set([...(balances.data||[]),...(refunds.data||[]),
      ...(shortfalls.data||[]),...(payouts.data||[]),...(alerts.data||[])]
      .flatMap(x=>[x.user_id,x.admin_id,x.verified_by]).filter(Boolean))];
    const [names,orders]=await Promise.all([
      balanceRelationRows('ex_profiles','id,full_name,username,email',ids),
      balanceRefundOrders([...(refunds.data||[]),...(shortfalls.data||[])])
    ]);
    const reconciliation=await db.rpc('ex_admin_balance_reconcile',{p_admin_id:_ctx.user.id});
    if(reconciliation.error)throw reconciliation.error;
    const profiles=Object.fromEntries(names.map(p=>[p.id,p]));
    return {balances:balances.data||[],refunds:refunds.data||[],shortfalls:shortfalls.data||[],
      payouts:payouts.data||[],alerts:alerts.data||[],config:config.data,profiles,orders,
      reconciliation:reconciliation.data};
  },

  async balance_refund_report({date_from,date_to,page=0,snapshot},_ctx){
    if(!Number.isSafeInteger(page)||page<0||!Number.isSafeInteger(page*REFUND_REPORT_PAGE_SIZE+REFUND_REPORT_PAGE_SIZE))
      throw {status:400,code:'invalid_report_page',message:'Use a nonnegative report page number'};
    const from=refundReportDate(date_from),to=refundReportDate(date_to);
    if(from!==null&&to!==null&&from>to)
      throw {status:400,code:'invalid_report_range',message:'The report start date must not follow its end date'};
    if(snapshot==null){
      if(page>0)throw {status:400,code:'report_snapshot_required',message:'Continue with the snapshot returned by the first report page'};
      snapshot=new Date().toISOString();
    }else{
      const timestamp=typeof snapshot==='string'?Date.parse(snapshot):NaN;
      if(!Number.isFinite(timestamp)||new Date(timestamp).toISOString()!==snapshot||timestamp>Date.now())
        throw {status:400,code:'invalid_report_snapshot',message:'Use the UTC snapshot returned by the first report page'};
    }
    const lower=from===null?null:baghdadDayStart(from);
    const upper=to===null?null:baghdadDayStart(to+86400000);
    const start=page*REFUND_REPORT_PAGE_SIZE;
    function reportQuery(table,fields){
      let query=db.from(table).select(fields).lte('created_at',snapshot);
      if(table==='ex_refund_cases')query=query.eq('status','credited');
      if(lower!==null)query=query.gte('created_at',lower);
      if(upper!==null)query=query.lt('created_at',upper);
      return query.order('created_at',{ascending:false}).order('id',{ascending:false})
        .range(start,start+REFUND_REPORT_PAGE_SIZE);
    }
    const [full,partial]=await Promise.all([
      reportQuery('ex_refund_cases','id,order_id,user_id,amount_iqd,status,refund_kind,bank_verification_reference,failure_reason,verified_by,confirmed_funds_received,confirmed_payout_failed,journal_id,created_at'),
      reportQuery('ex_order_shortfall_refunds','id,order_id,order_code,user_id,customer_phone,admin_id,amount_iqd,expected_iqd,refunded_before_iqd,refunded_after_iqd,balance_before_iqd,balance_after_iqd,journal_id,request_key,reason,verification_reference,refund_source,created_at')
    ]);
    for(const result of [full,partial]){
      if(result.error)throw result.error;
      if(!Array.isArray(result.data))throw {status:500,code:'refund_report_unavailable',message:'Refund report records could not be loaded'};
    }
    const has_more=full.data.length>REFUND_REPORT_PAGE_SIZE||partial.data.length>REFUND_REPORT_PAGE_SIZE;
    const refunds=full.data.slice(0,REFUND_REPORT_PAGE_SIZE),shortfalls=partial.data.slice(0,REFUND_REPORT_PAGE_SIZE);
    const rows=[...refunds,...shortfalls];
    const ids=[...new Set(rows.flatMap(row=>[row.user_id,row.verified_by,row.admin_id]).filter(Boolean))];
    const [orders,names]=await Promise.all([
      balanceRefundOrders(rows),
      balanceRelationRows('ex_profiles','id,full_name,username',ids)
    ]);
    const profiles=Object.fromEntries(names.map(profile=>[profile.id,profile]));
    return {refunds,shortfalls,orders,profiles,page,next_page:has_more?page+1:null,has_more,snapshot};
  },

  async balance_lookup_order({search},_ctx){
    const q=String(search||'').trim();
    if(!/^(?:[0-9a-f-]{36}|P[A-Z0-9]{11})$/i.test(q))
      throw {status:400,code:'invalid_order',message:'Enter an exact order code or UUID'};
    let query=db.from('ex_orders')
      .select('id,order_code,user_id,amount,total,fee,from_method,to_method,receipt_url,receipt_hash,payout_receipt_url,status,created_at,updated_at,decided_at,balance_refunded_at,balance_debit_journal_id,shortfall_refunded_iqd,payout_iqd,payout_rounding_iqd,payout_settlement_id')
      .limit(1);
    query=/^[0-9a-f-]{36}$/i.test(q)?query.eq('id',q):query.eq('order_code',q.toUpperCase());
    const {data:order,error}=await query.maybeSingle();
    if(error)throw error;
    if(!order)throw {status:404,code:'order_not_found',message:'Order not found'};
    const [p,r,s,b]=await Promise.all([
      db.from('ex_profiles').select('id,full_name,username,email').eq('id',order.user_id).maybeSingle(),
      db.from('ex_refund_cases').select('id,status,amount_iqd,created_at,bank_verification_reference')
        .eq('order_id',order.id).maybeSingle(),
      db.from('ex_order_shortfall_refunds').select('*').eq('order_id',order.id)
        .order('created_at',{ascending:false}).limit(150),
      db.from('ex_customer_balances').select('user_id,available_iqd,held_iqd,updated_at')
        .eq('user_id',order.user_id).maybeSingle()
    ]);
    for(const result of [p,r,s,b])if(result.error)throw result.error;
    const adminIds=[...new Set((s.data||[]).map(row=>row.admin_id).filter(Boolean))];
    const actors=adminIds.length?await db.from('ex_profiles').select('id,full_name,username,email')
      .in('id',adminIds):{data:[],error:null};
    if(actors.error)throw actors.error;
    const profiles=Object.fromEntries([...(p.data?[p.data]:[]),...(actors.data||[])].map(row=>[row.id,row]));
    const expected=Number(order.total),refunded=Number(order.shortfall_refunded_iqd||0);
    let code=null;
    if(order.balance_refunded_at||r.data)code='already_refunded';
    else if(order.status!==STATUS_APPROVED)code='order_not_approved';
    else if(order.from_method==='USDT'||order.to_method==='USDT')code='iqd_orders_only';
    else if(!order.receipt_url&&!order.balance_debit_journal_id)code='original_funds_proof_required';
    else if(!Number.isSafeInteger(expected)||expected<=0||!Number.isSafeInteger(refunded)||refunded<0)
      code='invalid_payout_amount';
    else if(refunded>=expected)code='no_remaining_shortfall';
    return {order,profile:p.data,profiles,refund:r.data,shortfalls:s.data||[],
      balance:b.data||{user_id:order.user_id,available_iqd:0,held_iqd:0,updated_at:null},
      shortfall_summary:{eligible:code===null,code,expected_iqd:expected,
        refunded_iqd:refunded,remaining_iqd:Math.max(0,expected-refunded)}};
  },

  async balance_credit_refund({order_id,verification_reference,reason,failure_reason,
    confirmed_received},ctx){
    if(confirmed_received!==true)
      throw {status:400,code:'confirmation_required',message:'Confirm that customer funds were received'};
    const existing=await db.from('ex_orders').select('id,shortfall_refunded_iqd')
      .eq('id',order_id).maybeSingle();
    if(existing.error)throw existing.error;
    if(Number(existing.data?.shortfall_refunded_iqd||0)>0)
      throw {status:409,code:'partially_refunded',message:'An order with a shortfall credit cannot receive a full refund'};
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

  async balance_credit_shortfall({order_id,amount_iqd,request_key,expected_refunded_iqd,reason,
    verification_reference,confirmed_shortfall},ctx){
    if(typeof order_id!=='string'||!UUID.test(order_id))
      throw {status:400,code:'invalid_order',message:'A valid order ID is required'};
    if(typeof request_key!=='string'||!UUID.test(request_key))
      throw {status:400,code:'invalid_request_key',message:'A valid submission key is required'};
    if(typeof amount_iqd!=='number'||!Number.isSafeInteger(amount_iqd)||amount_iqd<=0||amount_iqd>1000000000)
      throw {status:400,code:'invalid_amount',message:'Enter a positive whole number of IQD'};
    if(typeof expected_refunded_iqd!=='number'||!Number.isSafeInteger(expected_refunded_iqd)||
      expected_refunded_iqd<0||expected_refunded_iqd>1000000000)
      throw {status:400,code:'invalid_refund_snapshot',message:'Refresh the order before recording its shortfall'};
    if(confirmed_shortfall!==true)
      throw {status:400,code:'confirmation_required',message:'Confirm the actual unpaid shortfall'};
    const normalizedRequestKey=request_key.toLowerCase();
    const note=typeof reason==='string'?reason.trim():'';
    // New forms omit the manual reference. Derive its audit value from the same
    // canonical key on every retry; preserve references submitted by older tabs.
    const evidence=verification_reference==null?`shortfall:${normalizedRequestKey}`:
      typeof verification_reference==='string'?verification_reference.trim():'';
    if(note.length<10||note.length>2000)
      throw {status:400,code:'invalid_reason',message:'Explain the shortfall in 10 to 2000 characters'};
    if(evidence.length<6||evidence.length>160)
      throw {status:400,code:'invalid_evidence',message:'Provide a verification reference of 6 to 160 characters'};
    // Never generate a new request key on retry. The atomic RPC checks replay
    // equality, locks the order, caps credits at the net payout and records its
    // financial case, journal, balance change, audit and notification together.
    const {data,error}=await db.rpc('ex_admin_credit_shortfall',{
      p_order_id:order_id.toLowerCase(),p_admin_id:ctx.user.id,p_amount_iqd:amount_iqd,
      p_request_key:normalizedRequestKey,p_expected_refunded_iqd:expected_refunded_iqd,p_reason:note,
      p_verification_reference:evidence,p_confirmed_shortfall:true
    });
    if(error){
      const stale=/SHORTFALL_STATE_CHANGED/.test(error.message||'');
      const status=stale?409:error.code==='42501'?403:error.code==='22023'?400:
        error.code==='P0002'?404:['23505','23514','P0001'].includes(error.code)?409:500;
      const code=stale?'shortfall_stale':error.code||'shortfall_failed';
      throw {status,code,
        message:status===500?'The shortfall could not be saved; retry with the same submission':error.message};
    }
    // PostgREST may serialize the composite result as a row or a one-row array.
    const refund=Array.isArray(data)?(data.length===1?data[0]:null):data;
    if(!refund||typeof refund!=='object'||Array.isArray(refund)||typeof refund.id!=='string')
      throw {status:500,code:'shortfall_result_missing',message:'No credit result was returned; retry with the same submission'};
    return refund;
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

  async approve_order({ order_id, payout_receipt_url, admin_note, request_key,
    expected_updated_at, expected_total, confirmed_payout_iqd, confirmed_received, confirmed_paid }, ctx) {
    if (typeof order_id !== 'string' || !UUID.test(order_id))
      throw { status: 400, code: 'bad_input', message: 'A valid order_id is required' };
    order_id = order_id.toLowerCase();

    const { data: order, error: e1 } = await db
      .from('ex_orders').select('*').eq('id', order_id).single();
    if (e1 || !order) throw { status: 404, code: 'not_found', message: 'Order not found' };
    const plan = payoutPlan(expected_total, order.to_method);
    if (plan.applies) {
      if (typeof request_key !== 'string' || !UUID.test(request_key) ||
          !validApprovalTimestamp(expected_updated_at) || !plan.valid || confirmed_payout_iqd == null)
        throw {status:400,code:'approval_refresh_required',message:'نوێی بکەرەوە و بڕی ناردنەکە پێش پەسەندکردن پشتڕاست بکەرەوە'};
      const confirmed = payoutPlan(confirmed_payout_iqd, order.to_method);
      if (!confirmed.valid || confirmed.expected_iqd !== plan.payout_iqd)
        throw {status:400,code:'payout_amount_mismatch',message:'بڕی ناردن دەبێت لەگەڵ بڕی پیشاندراو یەک بێت'};
      if (confirmed_received !== true || confirmed_paid !== plan.requires_payout)
        throw {status:400,code:'confirmation_required',message:'وەرگرتنی پارە و دۆخی ناردنی بڕی پیشاندراو پشتڕاست بکەرەوە'};
      if (order.from_method !== 'USDT' &&
          (!payoutPlan(order.amount, order.to_method).valid || Number(order.amount) <= 0))
        throw {status:400,code:'invalid_payout_amount',message:'بڕی سەرچاوەی دینار دەبێت ژمارەیەکی تەواو بێت'};
      if ((admin_note != null && typeof admin_note !== 'string') || String(admin_note || '').trim().length > 500)
        throw {status:400,code:'bad_note',message:'Invalid order note'};
      const receipt = payout_receipt_url == null || payout_receipt_url === '' ? null
        : typeof payout_receipt_url === 'string' ? payout_receipt_url.trim() || null : false;
      if (receipt === false || (receipt !== null && (!plan.requires_payout || !validSettlementReceipt(order, receipt))))
        throw {status:400,code:'invalid_receipt',message:'Invalid payout receipt'};
      // The RPC checks exact-key replays before order state/stale checks. Do not
      // preclude a retry merely because the first approval already committed.
      const data = await settlementRpc('ex_admin_approve_order_settlement', {
        p_order_id:order_id,p_admin_id:ctx.user.id,p_request_key:request_key.toLowerCase(),
        // Preserve Postgres microseconds; a JS Date round-trip loses precision.
        p_expected_updated_at:expected_updated_at,p_expected_total:plan.expected_iqd,
        p_confirmed_payout_iqd:confirmed.expected_iqd,p_confirmed_received:confirmed_received,
        p_confirmed_paid:confirmed_paid,p_payout_receipt_url:receipt,p_admin_note:admin_note?.trim() || null
      }, 'settlement');
      return {...data.order,settlement:data.settlement,refund:data.refund || null};
    }
    if (order.to_method !== 'USDT')
      throw {status:400,code:'invalid_payout_route',message:'This order has no external payout destination'};
    if ([request_key,expected_updated_at,expected_total,confirmed_payout_iqd,confirmed_received,confirmed_paid]
        .some(value => value !== undefined))
      throw {status:409,code:'approval_stale',message:'ڕێڕەوی داواکارییەکە گۆڕاوە؛ نوێی بکەرەوە و دووبارە بپشکنە'};
    if (order.balance_refunded_at || !REVIEWABLE_ORDER_STATUSES.has(order.status)) {
      throw { status: 409, code: 'already_decided', message: 'Order is not ready for review' };
    }

    const patch = { status: STATUS_APPROVED, decided_at: new Date().toISOString(), handled_by:ctx.user.id };
    if (payout_receipt_url) patch.payout_receipt_url = String(payout_receipt_url).slice(0, 2000);
    if (admin_note)         patch.admin_note         = String(admin_note).slice(0, 500);

    const { data, error } = await db.from('ex_orders').update(patch).eq('id', order_id).in('status',[...REVIEWABLE_ORDER_STATUSES]).is('balance_refunded_at',null).select().single();
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
      status: STATUS_REJECTED, handled_by:ctx.user.id,
      admin_note: reason ? String(reason).slice(0, 500) : null,
      decided_at: new Date().toISOString()
    }).eq('id', order_id).in('status',[...REVIEWABLE_ORDER_STATUSES]).is('balance_refunded_at',null).select().single();
    if (error) throw { status:error.code==='PGRST116'?409:500, code:'db_error',message:error.message };

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

    assertStaffAction(ctx.profile,name);

    const data = await run(body.payload || {}, ctx);
    return ok(res, data);

  } catch (err) {
    if (err && err.status) return fail(res, err.status, err.message, err.code);
    console.error('[api/admin]', err);           // full detail stays in Vercel logs
    return fail(res, 500, 'Internal server error', 'server_error');
  }
}

