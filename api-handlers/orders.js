import { randomUUID } from 'node:crypto';
import { payoutPlan } from './_lib/payout-rounding.js';
import {
  json, readJson, rpc, serviceFetch, stealth404, withSecurity, config, sectionPaused, pausedBody
} from './_lib/security.js';

const MIN_AMOUNT = 10000;
const STATUS_NEEDS_CORRECTION = 'پێویستی بە ڕاستکردنەوەیە';
const STATUS_CORRECTED = 'ڕاستکراوەتەوە';
const STATUS_REJECTED = 'ڕەتکرا';
const RECEIPT_USED = { code: 'RECEIPT_ALREADY_USED', error: 'This receipt was already used' };

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

// Amount-tiered fees: up to the limit (inclusive) the low percent applies, above it the high percent.
// A route without an enabled tier keeps its stored rate_value exactly as it is.
function effectiveRateValue(rate, amount) {
  // Several brackets: the first bracket whose upper limit is >= the amount applies; the last has no limit.
  if (Array.isArray(rate.fee_brackets) && rate.fee_brackets.length >= 2
      && (rate.rate_type === 'fee_percent' || rate.rate_type === 'multiplier')) {
    let bracketPercent = null;
    for (const bracket of rate.fee_brackets) {
      if (bracket.up_to === null || bracket.up_to === undefined || amount <= Number(bracket.up_to)) {
        bracketPercent = Number(bracket.percent);
        break;
      }
    }
    if (!Number.isFinite(bracketPercent)) throw Object.assign(new Error('Invalid fee tier'), { status: 409 });
    return rate.rate_type === 'fee_percent' ? bracketPercent : Number((1 - bracketPercent / 100).toFixed(10));
  }
  if (!rate.fee_tier_enabled) return Number(rate.rate_value);
  const limit = Number(rate.fee_tier_limit_iqd);
  const low = Number(rate.fee_tier_low_percent);
  const high = Number(rate.fee_tier_high_percent);
  if (![limit, low, high].every(Number.isFinite) || rate.fee_tier_low_percent === null || rate.fee_tier_high_percent === null) {
    throw Object.assign(new Error('Invalid fee tier'), { status: 409 });
  }
  const percent = amount <= limit ? low : high;
  if (rate.rate_type === 'fee_percent') return percent;
  if (rate.rate_type === 'multiplier') return Number((1 - percent / 100).toFixed(10));
  return Number(rate.rate_value);
}

function calculateTotal(amount, rate) {
  const value = effectiveRateValue(rate, amount);
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

// A receipt counts as used unless the only orders holding it are this same
// user's rejected orders. That lets a customer resubmit the same transfer
// after a rejection, while another account can never reuse the receipt.
async function findDuplicate(receiptHash, transactionReference, { userId, excludeId = null } = {}) {
  if (!userId) throw new Error('findDuplicate requires userId');
  const exclude = excludeId ? `&id=neq.${encodeURIComponent(excludeId)}` : '';
  const blocking = `&or=(status.neq.${encodeURIComponent(STATUS_REJECTED)},user_id.neq.${encodeURIComponent(userId)})`;
  if (receiptHash) {
    const rows = await serviceFetch(`/rest/v1/ex_orders?receipt_hash=eq.${encodeURIComponent(receiptHash)}${exclude}${blocking}&select=id&limit=1`);
    if (rows?.length) return 'receipt_hash';
  }
  if (transactionReference) {
    const rows = await serviceFetch(`/rest/v1/ex_orders?transaction_reference=eq.${encodeURIComponent(transactionReference)}${exclude}${blocking}&select=id&limit=1`);
    if (rows?.length) return 'transaction_reference';
  }
  return null;
}

// Wallets live only in ex_wallets: whether a wallet takes a card number and whether it
// needs the sender's phone are columns there (set in the admin panel), never names in code.
const WALLET_FIELDS = 'key,is_locked,allow_from,allow_receive,recipient_format,sender_phone_required';
async function loadWallets(keys) {
  const list = [...new Set(keys.filter(Boolean))].map(encodeURIComponent);
  if (!list.length) return {};
  const rows = await serviceFetch(`/rest/v1/ex_wallets?key=in.(${list.join(',')})&select=${WALLET_FIELDS}`);
  return Object.fromEntries((Array.isArray(rows) ? rows : []).map(row => [row.key, row]));
}
function validRecipient(wallet, phone) {
  // Recipient identifiers are data, never markup. A card wallet accepts digits only;
  // phone wallets keep the strict 07 + 9 digits format.
  return wallet?.recipient_format === 'card' ? /^\d{6,32}$/.test(phone) : /^07\d{9}$/.test(phone);
}

async function submitOrderCorrection(res, body, user) {
  const id = oneLine(body.id, 64);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
    return json(res, 422, { error: 'Invalid order id' });
  }

  const existingRows = await serviceFetch(
    `/rest/v1/ex_orders?id=eq.${encodeURIComponent(id)}&user_id=eq.${encodeURIComponent(user.id)}&select=*&limit=1`
  );
  const order = Array.isArray(existingRows) ? existingRows[0] : null;
  if (!order) return json(res, 404, { error: 'Order not found' });
  if (order.status !== STATUS_NEEDS_CORRECTION) {
    return json(res, 409, { error: 'This order is not waiting for a correction' });
  }

  const phone = oneLine(body.phone, 32).replace(/\s+/g, '');
  const orderWallets = await loadWallets([order.from_method, order.to_method]);
  const carrierSender = orderWallets[order.from_method]?.sender_phone_required === true;
  const senderPhone = carrierSender
    ? oneLine(body.sender_phone, 32).replace(/[^0-9]/g, '')
    : null;
  const customerResponse = oneLine(body.customer_response, 2000);
  if (!validRecipient(orderWallets[order.to_method], phone)) {
    return json(res, 422, { error: 'Invalid recipient number' });
  }
  if (carrierSender && !/^07\d{9}$/.test(senderPhone)) {
    return json(res, 422, { error: 'Invalid sender number' });
  }
  if (customerResponse.length < 5) {
    return json(res, 422, { error: 'Correction response must be at least 5 characters' });
  }

  const hasReplacementReceipt = Object.prototype.hasOwnProperty.call(body, 'receipt_url');
  let receiptUrl = order.receipt_url;
  let receiptHash = order.receipt_hash;
  if (hasReplacementReceipt) {
    receiptUrl = cleanReceiptUrl(body.receipt_url);
    receiptHash = /^[a-f0-9]{64}$/i.test(body.receipt_hash || '')
      ? String(body.receipt_hash).toLowerCase()
      : null;
    if (!receiptUrl || !receiptHash) return json(res, 422, { error: 'Invalid replacement receipt' });
    const duplicateKind = await findDuplicate(receiptHash, null, { userId: user.id, excludeId: id });
    if (duplicateKind) return json(res, 409, RECEIPT_USED);
  }

  const now = new Date().toISOString();
  const rows = await serviceFetch(
    `/rest/v1/ex_orders?id=eq.${encodeURIComponent(id)}` +
    `&user_id=eq.${encodeURIComponent(user.id)}` +
    `&status=eq.${encodeURIComponent(STATUS_NEEDS_CORRECTION)}&select=*`,
    {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify({
        phone,
        sender_phone: senderPhone,
        receipt_url: receiptUrl,
        receipt_hash: receiptHash,
        correction_response: customerResponse,
        correction_responded_at: now,
        status: STATUS_CORRECTED,
        decided_at: null,
        updated_at: now
      })
    }
  );
  const updated = Array.isArray(rows) ? rows[0] : null;
  if (!updated) return json(res, 409, { error: 'Order state changed; please refresh' });
  return json(res, 200, { ok: true, order: {...updated, payout_plan:payoutPlan(updated.total, updated.to_method)} });
}

export default withSecurity(async (req, res, { context, user }) => {
  const body = await readJson(req);

  if (req.method === 'PATCH') {
    const pausedFix = await sectionPaused(['correction']);
    if (pausedFix) return json(res, 423, pausedBody(pausedFix));
    return submitOrderCorrection(res, body, user);
  }

  const retryId = oneLine(body.retry_rejected_order_id, 64);
  let retryOrder = null;
  if (retryId) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(retryId)) {
      return json(res, 422, { code: 'INVALID_RETRY_ORDER_ID', error: 'Invalid rejected order id' });
    }
    const retryRows = await serviceFetch(
      `/rest/v1/ex_orders?id=eq.${encodeURIComponent(retryId)}&user_id=eq.${encodeURIComponent(user.id)}` +
      '&select=id,user_id,status,from_method,to_method,amount,phone,sender_phone,receipt_url,receipt_hash,transaction_reference,shortfall_refunded_iqd&limit=1'
    );
    retryOrder = Array.isArray(retryRows) ? retryRows[0] : null;
    if (!retryOrder) return json(res, 404, { code: 'RETRY_ORDER_NOT_FOUND', error: 'Rejected order not found' });
    if (retryOrder.status !== STATUS_REJECTED) {
      return json(res, 409, { code: 'RETRY_ORDER_NOT_REJECTED', error: 'Only rejected orders can be resubmitted' });
    }
    if (Number(retryOrder.shortfall_refunded_iqd || 0) > 0) {
      return json(res, 409, { code: 'RETRY_ORDER_REFUNDED', error: 'This order has already been refunded' });
    }
  }

  if (oneLine(body.contact_reference, 120)) {
    await logThreat('honeypot', context, user, {
      detail: 'Hidden contact_reference field was filled',
      payload: { from_method: oneLine(body.from_method, 30) }
    });
    // A bot receives a plausible success without learning that it was detected.
    return json(res, 202, { ok: true, order: { id: randomUUID(), order_code: 'P' + Date.now() } });
  }

  const fromMethod = oneLine(retryOrder?.from_method || body.from_method, 30);
  const toMethod = oneLine(retryOrder?.to_method || body.to_method, 30);
  const amount = Number(retryOrder?.amount ?? body.amount);
  const phone = oneLine(retryOrder?.phone || body.phone, 32).replace(/\s+/g, '');
  const balanceSource = fromMethod === 'AccountBalance';
  // admin pause: new requests stop (paying from the balance also stops with "balance")
  const paused = await sectionPaused(balanceSource ? ['exchange', 'balance'] : ['exchange']);
  if (paused) return json(res, 423, pausedBody(paused));
  const senderPhone = oneLine(retryOrder?.sender_phone || body.sender_phone, 32).replace(/[^0-9]/g, '');
  const receiptUrl = cleanReceiptUrl(retryOrder?.receipt_url || body.receipt_url);
  const rawReceiptHash = retryOrder?.receipt_hash || body.receipt_hash || '';
  const receiptHash = /^[a-f0-9]{64}$/i.test(rawReceiptHash) ? String(rawReceiptHash).toLowerCase() : null;
  const receiptPreflightId = oneLine(body.receipt_preflight_id, 64);
  const transactionReference = oneLine(retryOrder?.transaction_reference || body.transaction_reference, 120) || null;
  const requestKey = retryOrder?.from_method === 'AccountBalance' ? randomUUID() : body.request_key;

  // Wallets and routes are managed from the admin panel. Keep only structural
  // validation here, then use the live database configuration below.
  if (!fromMethod || !toMethod || fromMethod === toMethod) {
    return json(res, 422, { error: 'Invalid exchange route' });
  }
  if (!Number.isFinite(amount) || amount < MIN_AMOUNT || amount > 1_000_000_000) {
    return json(res, 422, { error: 'Invalid amount' });
  }
  if (fromMethod !== 'USDT' && !Number.isSafeInteger(amount)) {
    return json(res, 422, { error: 'IQD amounts must be whole dinars' });
  }
  if (balanceSource && (!Number.isSafeInteger(amount) || toMethod==='USDT' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(requestKey||''))))
    return json(res,422,{error:'Valid balance request key and whole IQD amount required'});
  if (toMethod==='AccountBalance') return json(res,422,{error:'Account balance is a Send source only'});
  if (!balanceSource && (!receiptUrl || !receiptHash)) return json(res, 422, { error: 'Receipt is required' });

  // checked once the request is well formed: the wallets' own rules from ex_wallets
  const walletRows = await loadWallets([fromMethod, toMethod]);
  const source = walletRows[fromMethod];
  const target = walletRows[toMethod];
  const carrierSender = source?.sender_phone_required === true;
  if (!validRecipient(target, phone)) {
    return json(res, 422, { error: 'Invalid recipient number' });
  }
  if (carrierSender && !/^07\d{9}$/.test(senderPhone)) {
    return json(res, 422, { error: 'Invalid sender number' });
  }

  const rates = await serviceFetch(
    `/rest/v1/ex_rates?from_method=eq.${encodeURIComponent(fromMethod)}&to_method=eq.${encodeURIComponent(toMethod)}&is_active=eq.true&select=rate_type,rate_value,fee_tier_enabled,fee_tier_limit_iqd,fee_tier_low_percent,fee_tier_high_percent,fee_brackets&limit=1`
  );
  const rate = rates?.[0];
  if (!rate) return json(res, 409, { error: 'This exchange route is closed' });

  if (!source || !target || source.is_locked || target.is_locked || source.allow_from === false || target.allow_receive === false) {
    return json(res, 409, { error: 'This wallet is currently unavailable' });
  }

  const profileRows = await serviceFetch(`/rest/v1/ex_profiles?id=eq.${encodeURIComponent(user.id)}&select=id,full_name,email,is_banned&limit=1`);
  const profile = profileRows?.[0];
  if (profile?.is_banned) return stealth404(res);
  const username = oneLine(profile?.full_name || user.user_metadata?.full_name || '', 200);
  const email = oneLine(profile?.email || user.email || '', 320);
  const maskedPhone = phone.length > 4 ? `${phone.slice(0, 3)}••••${phone.slice(-3)}` : '••••';
  const maskedSenderPhone = carrierSender
    ? `${senderPhone.slice(0, 3)}••••${senderPhone.slice(-3)}`
    : null;

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
      sender_phone_masked: maskedSenderPhone,
      receipt_hash_prefix: balanceSource ? null : receiptHash.slice(0, 12)
    },
    p_threshold: 3,
    p_auto_ban_threshold: 8
  });
  if (velocity?.banned) return stealth404(res);

  const duplicateKind = balanceSource ? null : await findDuplicate(receiptHash, transactionReference, { userId: user.id });
  if (duplicateKind) {
    await logThreat('duplicate_transaction_reference', context, user, {
      detail: `Duplicate ${duplicateKind} probe`,
      payload: { duplicate_kind: duplicateKind, from_method: fromMethod, to_method: toMethod }
    });
    return json(res, 409, RECEIPT_USED);
  }

  // New customer receipt-backed orders are accepted only with the one-use OCR
  // result bound to this user, route, amount, uploaded receipt, and wallet target.
  // The rejected-order retry path retains its existing stored receipt behavior.
  if (!balanceSource && !retryOrder) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(receiptPreflightId)) {
      return json(res, 422, { code: 'RECEIPT_PREFLIGHT_REQUIRED', error: 'پێش ناردنی داواکاری پێویستە پسووڵەکە پشتڕاست بکرێتەوە' });
    }
    try {
      await rpc('ex_customer_receipt_preflight_claim', {
        p_check_id: receiptPreflightId,
        p_user_id: user.id,
        p_from_method: fromMethod,
        p_to_method: toMethod,
        p_amount: amount,
        p_receipt_url: receiptUrl,
        p_receipt_hash: receiptHash
      });
    } catch (error) {
      await logThreat('customer_receipt_preflight_rejected', context, user, {
        detail: 'New receipt-backed order was not backed by a valid one-use OCR preflight',
        payload: { from_method: fromMethod, to_method: toMethod, reason: oneLine(error?.message, 120) }
      });
      return json(res, 409, { code: 'RECEIPT_PREFLIGHT_REQUIRED', error: 'پسووڵەکە پشتڕاست نەکراوەتەوە؛ تکایە دووبارە هەوڵ بدەرەوە' });
    }
  }

  const total = Math.floor(calculateTotal(amount, rate));
  const payload = {
    user_id: user.id,
    from_method: fromMethod,
    to_method: toMethod,
    amount,
    total,
    phone,
    sender_phone: carrierSender ? senderPhone : null,
    extra_info: null,
    receipt_url: receiptUrl,
    receipt_hash: receiptHash,
    receipt_preflight_id: !balanceSource && !retryOrder ? receiptPreflightId : null,
    transaction_reference: transactionReference,
    security_log_id: velocity?.log_id || null
  };

  try {
    if (balanceSource) {
      const order = await rpc('ex_balance_create_order', {
        p_user_id:user.id,p_request_key:requestKey,p_to:toMethod,
        p_amount:amount,p_phone:phone,p_security_log_id:velocity?.log_id||null
      });
      return json(res,201,{ok:true,order:{...order,payout_plan:payoutPlan(order?.total,order?.to_method)}});
    }
    const rows = await serviceFetch('/rest/v1/ex_orders?select=*', {
      method: 'POST',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(payload)
    });
    return json(res, 201, {
      ok: true,
      order: rows?.[0] && {...rows[0],payout_plan:payoutPlan(rows[0].total,rows[0].to_method)},
      security: {
        alert_created: Boolean(velocity?.alert_created),
        frequency_count: Number(velocity?.frequency_count || 1)
      }
    });
  } catch (error) {
    if (balanceSource) {
      const message=String(error.message||'Balance order failed');
      return json(res,409,{error:/INSUFFICIENT_BALANCE/.test(message)
        ? 'باڵانسی بەردەست بەشی ئەم بڕە ناکات' : message});
    }
    if (error.details?.code === '23505') {
      await logThreat('duplicate_transaction_reference', context, user, {
        detail: 'Unique receipt/reference constraint was triggered',
        payload: { from_method: fromMethod, to_method: toMethod }
      });
      return json(res, 409, RECEIPT_USED);
    }
    throw error;
  }
}, { auth: 'required', methods: ['POST', 'PATCH'] });
