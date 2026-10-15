// Shared by the importable n8n Code nodes and the offline contract tests.
export const templates = Object.freeze({
  otp: 'fcb360b0-6bee-499c-990b-8fc181dccfbd',
  account: 'c81050e6-f9af-42ae-90bf-b43b41469b61',
});
export function failure(error, status = 502, retryAfter) {
  return { proceed: false, httpStatus: status, response: {
    success: false, error,
    ...(retryAfter ? { retryAfterSeconds: Math.min(3600, Math.max(1, retryAfter)) } : {}),
  } };
}
export function normalizePhone(raw) {
  if (typeof raw !== 'string' || raw.length > 64) return null;
  let value = raw.replace(/[٠-٩۰-۹]/g, digit => String(
    digit.charCodeAt(0) >= 0x6f0 ? digit.charCodeAt(0) - 0x6f0 : digit.charCodeAt(0) - 0x660));
  if (!/^[+\d\s()-]+$/.test(value)) return null;
  value = value.replace(/\D/g, '').replace(/^00/, '').replace(/^964/, '').replace(/^0/, '');
  return /^7\d{9}$/.test(value) ? '+964' + value : null;
}
export function sendInput(body) {
  const phone = normalizePhone(body?.phone);
  const purpose = body?.purpose ?? 'login';
  if (!phone || !['signup', 'login', 'reset_password'].includes(purpose)) return failure('bad_request', 400);
  return { proceed: true, phone, purpose };
}
export function reservation(raw, request) {
  const data = raw?.body;
  if (raw?.statusCode !== 200 || !data || data.success !== true) {
    if (raw?.statusCode === 200 && ['rate_limited', 'otp_locked'].includes(data?.error)) {
      return failure(data.error, 429, Number(data.retry_after_seconds) || 60);
    }
    return failure('otp_unavailable', 503);
  }
  if (!/^\d{6}$/.test(data.code) || !/^[0-9a-f-]{36}$/.test(data.otp_id) ||
      !Number.isInteger(data.send_count) || data.send_count < 1 ||
      !Number.isFinite(Date.parse(data.expires_at)) ||
      data.client_message_id !== `proxo-otp-${data.otp_id}-${data.send_count}`) return failure('otp_unavailable', 503);
  return { proceed: true, phone: request.phone, otpId: data.otp_id,
    sendCount: data.send_count, reused: data.reused === true, expiresAt: data.expires_at,
    payload: {
      to: request.phone, templateId: templates.otp, clientMessageId: data.client_message_id,
      components: [
        { type: 'body', parameters: [{ type: 'text', text: data.code }] },
        { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: data.code }] },
      ],
    },
  };
}
export function providerResult(raw) {
  const envelope = raw?.body;
  const data = envelope?.data ?? envelope;
  if (![200, 202].includes(raw?.statusCode) || envelope?.success === false ||
      typeof data?.messageId !== 'string' || !/^[\w-]{8,200}$/.test(data.messageId) ||
      ['failed', 'rejected', 'cancelled'].includes(data.status)) return failure('delivery_unavailable', 502);
  return { proceed: true, messageId: data.messageId,
    status: ['sent', 'delivered', 'read'].includes(data.status) ? data.status : 'queued' };
}
export function sendResult(raw, prepared, sent) {
  if (raw?.statusCode !== 200 || raw?.body?.success !== true) return failure('delivery_record_failed', 503);
  return { httpStatus: 200, response: { success: true, messageId: sent.messageId,
    status: sent.status, expiresAt: prepared.expiresAt, reused: prepared.reused } };
}
export function statusInput(query) {
  const messageId = query?.messageId;
  return typeof messageId === 'string' && /^[\w-]{8,200}$/.test(messageId)
    ? { proceed: true, messageId } : failure('bad_request', 400);
}
export function statusResult(raw) {
  const envelope = raw?.body;
  const data = envelope?.data ?? envelope;
  const states = ['queued', 'pending', 'sent', 'delivered', 'read', 'failed', 'rejected', 'cancelled'];
  if (raw?.statusCode !== 200 || envelope?.success === false || !states.includes(data?.status)) {
    return failure('status_unavailable', 502);
  }
  return { httpStatus: 200, response: { success: true, status: data.status } };
}
export function verifyInput(body) {
  const request = sendInput(body);
  if (!request.proceed || typeof body.code !== 'string' || !/^\d{6}$/.test(body.code)) return failure('bad_request', 400);
  return { ...request, code: body.code };
}
export function verifyResult(raw) {
  const verified = raw?.statusCode === 200 && raw?.body?.data?.verified === true;
  return { httpStatus: verified ? 200 : 401, response: { success: verified, verified } };
}
export function accountInput(body) {
  // Trusted server caller only; a Utility confirmation must be a real signup
  // event with its own requested-message evidence, never a marketing blast.
  if (body?.event !== 'account_created' || body?.confirmationRequested !== true ||
      typeof body?.userId !== 'string' || !/^[0-9a-f-]{36}$/.test(body.userId)) return failure('bad_request', 400);
  return { proceed: true, userId: body.userId };
}
export function accountPayload(raw, request, now = Date.now()) {
  const user = raw?.body?.user ?? raw?.body;
  const phone = normalizePhone(user?.phone);
  const created = Date.parse(user?.created_at);
  const name = user?.user_metadata?.full_name;
  if (raw?.statusCode !== 200 || user?.id !== request.userId || !user?.phone_confirmed_at ||
      !phone || !Number.isFinite(created) || now - created > 15 * 60 * 1000 || created > now ||
      typeof name !== 'string' || name.trim().length < 3 || name.length > 200) return failure('invalid_account_event', 400);
  return { proceed: true, payload: { to: phone, templateId: templates.account,
    clientMessageId: `proxo-account-created-${request.userId}`,
    components: [{ type: 'body', parameters: [
      { type: 'text', parameter_name: 'customer_name', text: name.trim() },
    ] }],
  } };
}
