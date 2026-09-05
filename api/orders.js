import { randomUUID } from 'node:crypto';
import {
  json, readJson, rpc, serviceFetch, stealth404, withSecurity, config
} from './_lib/security.js';

const METHODS = new Set(['FastPay', 'FIB', 'QiCard', 'Asiacell', 'Korek', 'USDT']);
const MIN_AMOUNT = 10000;

function oneLine(value, max = 200) {
  return String(value || '').replace(/[\r\n\t]+/g, ' ').trim().slice(0, max);
}

function cleanReceiptUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    const allowed = new URL(config.SUPABASE_URL);
    if (url.origin !== allowed.origin || !url.pathname.startsWith('/storage/v1/object/public/receipts/')) return null;
    return url.href.slice(0, 2000);
  } catch { return null; }
}

function calculateTotal(amount, rate) {
  const value = Number(rate.rate_value);
  if (!Number.isFinite(value) || value < 0) throw Object.assign(new Error('Invalid exchange rate'), { status: 409 });
  if (rate.rate_type === 'multiplier') return amount * value;
  if (rate.rate_type === 'fee_percent') return amount - (amount * value / 100);
  if (rate.rate_type === 'fee_fixed') return Math.max(0, amount - value);
  throw Object.assign(new Error('Unsupported exchange rate'), { status: 409 });
}

async function logThreat(action, ctx, user, details = {}) {
  return rpc('security_log_event', {
    p_action_type: action,
    p_ip: ctx.ip,
    p_user_id: user?.id || null,
    p_username: oneLine(user?.user_metadata?.full_name || '', 200),
    p_user_email: oneLine(user?.email || '', 320),
    p_user_agent: ctx.userAgent,
    p_browser: ctx.browser,
    p_os: ctx.os,
    p_device: ctx.device,
    p_fingerprint_hash: ctx.fingerprint,
    p_detail: oneLine(details.detail || '', 1000),
    p_request_path: ctx.path,
    p_payload_summary: details.payload || {}
  });
}

async function findDuplicate(receiptHash, transactionReference) {
  if (receiptHash) {
    const rows = await serviceFetch(`/rest/v1/ex_orders?receipt_hash=eq.${encodeURIComponent(receiptHash)}&select=id&limit=1`);
    if (rows?.length) return 'receipt_hash';
  }
  if (transactionReference) {
    const rows = await serviceFetch(`/rest/v1/ex_orders?transaction_reference=eq.${encodeURIComponent(transactionReference)}&select=id&limit=1`);
    if (rows?.length) return 'transaction_reference';
  }
  return null;
}

export default withSecurity(async (req, res, { context, user }) => {
  const body = await readJson(req);

  if (oneLine(body.contact_reference, 120)) {
    await logThreat('honeypot', context, user, {
      detail: 'Hidden contact_reference field was filled',
      payload: { from_method: oneLine(body.from_method, 30) }
    });
    // A bot receives a plausible success without learning that it was detected.
    return json(res, 202, { ok: true, order: { id: randomUUID(), order_code: 'P' + Date.now() } });
  }

  const fromMethod = oneLine(body.from_method, 30);
  const toMethod = oneLine(body.to_method, 30);
  const amount = Number(body.amount);
  const phone = oneLine(body.phone, 32).replace(/\s+/g, '');
  const receiptUrl = cleanReceiptUrl(body.receipt_url);
  const receiptHash = /^[a-f0-9]{64}$/i.test(body.receipt_hash || '') ? String(body.receipt_hash).toLowerCase() : null;
  const transactionReference = oneLine(body.transaction_reference, 120) || null;

  if (!METHODS.has(fromMethod) || !METHODS.has(toMethod) || fromMethod === toMethod) {
    return json(res, 422, { error: 'Invalid exchange route' });
  }
  if (!Number.isFinite(amount) || amount < MIN_AMOUNT || amount > 1_000_000_000) {
    return json(res, 422, { error: 'Invalid amount' });
  }
  if (toMethod === 'QiCard' ? phone.length < 6 : !/^07\d{9}$/.test(phone)) {
    return json(res, 422, { error: 'Invalid recipient number' });
  }
  if (!receiptUrl || !receiptHash) return json(res, 422, { error: 'Receipt is required' });

  const profileRows = await serviceFetch(`/rest/v1/ex_profiles?id=eq.${encodeURIComponent(user.id)}&select=id,full_name,email,is_banned&limit=1`);
  const profile = profileRows?.[0];
  if (profile?.is_banned) return stealth404(res);
  const username = oneLine(profile?.full_name || user.user_metadata?.full_name || '', 200);
  const email = oneLine(profile?.email || user.email || '', 320);
  const maskedPhone = phone.length > 4 ? `${phone.slice(0, 3)}••••${phone.slice(-3)}` : '••••';

  const velocity = await rpc('security_record_order_attempt', {
    p_ip: context.ip,
    p_user_id: user.id,
    p_username: username,
    p_user_email: email,
    p_user_agent: context.userAgent,
    p_browser: context.browser,
    p_os: context.os,
    p_device: context.device,
    p_fingerprint_hash: context.fingerprint,
    p_request_path: context.path,
    p_payload_summary: {
      from_method: fromMethod,
      to_method: toMethod,
      amount,
      phone_masked: maskedPhone,
      receipt_hash_prefix: receiptHash.slice(0, 12)
    },
    p_threshold: 3,
    p_auto_ban_threshold: 8
  });
  if (velocity?.banned) return stealth404(res);

  const duplicateKind = await findDuplicate(receiptHash, transactionReference);
  if (duplicateKind) {
    await logThreat('duplicate_transaction_reference', context, user, {
      detail: `Duplicate ${duplicateKind} probe`,
      payload: { duplicate_kind: duplicateKind, from_method: fromMethod, to_method: toMethod }
    });
    return json(res, 409, { error: 'This receipt was already used' });
  }

  const rates = await serviceFetch(
    `/rest/v1/ex_rates?from_method=eq.${encodeURIComponent(fromMethod)}&to_method=eq.${encodeURIComponent(toMethod)}&is_active=eq.true&select=rate_type,rate_value&limit=1`
  );
  const rate = rates?.[0];
  if (!rate) return json(res, 409, { error: 'This exchange route is closed' });

  const wallets = await serviceFetch(`/rest/v1/ex_wallets?key=in.(${encodeURIComponent(fromMethod)},${encodeURIComponent(toMethod)})&select=key,is_locked,allow_from,allow_receive`);
  const source = wallets?.find(w => w.key === fromMethod);
  const target = wallets?.find(w => w.key === toMethod);
  if (source?.is_locked || target?.is_locked || source?.allow_from === false || target?.allow_receive === false) {
    return json(res, 409, { error: 'This wallet is currently unavailable' });
  }

  const total = Math.floor(calculateTotal(amount, rate));
  const payload = {
    user_id: user.id,
    from_method: fromMethod,
    to_method: toMethod,
    amount,
    total,
    phone,
    extra_info: null,
    receipt_url: receiptUrl,
    receipt_hash: receiptHash,
    transaction_reference: transactionReference,
    security_log_id: velocity?.log_id || null
  };

  try {
    const rows = await serviceFetch('/rest/v1/ex_orders?select=*', {
      method: 'POST',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(payload)
    });
    return json(res, 201, {
      ok: true,
      order: rows?.[0],
      security: {
        alert_created: Boolean(velocity?.alert_created),
        frequency_count: Number(velocity?.frequency_count || 1)
      }
    });
  } catch (error) {
    if (error.details?.code === '23505') {
      await logThreat('duplicate_transaction_reference', context, user, {
        detail: 'Unique receipt/reference constraint was triggered',
        payload: { from_method: fromMethod, to_method: toMethod }
      });
      return json(res, 409, { error: 'This receipt was already used' });
    }
    throw error;
  }
}, { auth: 'required', methods: ['POST'] });
