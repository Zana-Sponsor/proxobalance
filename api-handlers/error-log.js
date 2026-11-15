import { json, readJson, recordAppError, withSecurity } from './_lib/security.js';

function oneLine(value, max = 300) {
  return String(value == null ? '' : value).replace(/[\r\n\t]+/g, ' ').trim().slice(0, max);
}

function safeMetadata(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const allowed = new Set(['stage', 'online', 'visibility', 'from_method', 'to_method', 'file_size', 'file_type', 'filename', 'line', 'column']);
  const result = {};
  for (const [key, item] of Object.entries(value)) {
    if (!allowed.has(key)) continue;
    if (typeof item === 'string') result[key] = oneLine(item, 200);
    else if (typeof item === 'boolean') result[key] = item;
    else if (typeof item === 'number' && Number.isFinite(item)) result[key] = item;
  }
  return result;
}

// Not errors of this site: cross-origin scripts without detail, bridges that
// in-app browsers (Snapchat, Facebook, …) inject, browser extensions.
const NOISE = /^script error\.?$|java object is gone|SCDynimacBridge|ResizeObserver loop|extension:\/\/|webkit-masked-url/i;
// The visitor's own connection dropped: worth seeing, but not a site error.
const NETWORK = /failed to fetch|load failed|networkerror|network request failed|_NETWORK(_ERROR)?\b/i;

export default withSecurity(async (req, res, { context, user }) => {
  const body = await readJson(req, 8 * 1024);
  const operation = oneLine(body.operation, 100);
  const message = oneLine(body.message, 2000);
  if (!operation || !message) return json(res, 422, { error: 'operation and message are required' });
  const code = oneLine(body.code, 120);
  if (NOISE.test(message) || NOISE.test(code)) return json(res, 202, { ok: true, ignored: true });
  const network = NETWORK.test(message) || NETWORK.test(code);
  // 4xx: the request was refused for a reason the customer can fix (receipt already used, bad input)
  const refused = Number(body.status) >= 400 && Number(body.status) < 500 || /RECEIPT_ALREADY_USED|already used/i.test(code + ' ' + message);

  const saved = await recordAppError(context, {
    source: 'client',
    severity: network || refused ? 'warning' : ['warning', 'error', 'critical'].includes(body.severity) ? body.severity : 'error',
    operation,
    code: code || null,
    status: body.status,
    message,
    path: oneLine(body.path, 500) || context.path,
    method: 'CLIENT',
    user,
    metadata: safeMetadata(body.metadata)
  });

  if (!saved) return json(res, 503, { error: 'Error log is temporarily unavailable' });
  return json(res, 202, { ok: true, deduplicated: saved.deduplicated === true });
}, { auth: 'required', methods: ['POST'], autoLog: false });
