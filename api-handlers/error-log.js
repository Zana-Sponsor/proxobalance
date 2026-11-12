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

export default withSecurity(async (req, res, { context, user }) => {
  const body = await readJson(req, 8 * 1024);
  const operation = oneLine(body.operation, 100);
  const message = oneLine(body.message, 2000);
  if (!operation || !message) return json(res, 422, { error: 'operation and message are required' });

  const saved = await recordAppError(context, {
    source: 'client',
    severity: ['warning', 'error', 'critical'].includes(body.severity) ? body.severity : 'error',
    operation,
    code: oneLine(body.code, 120) || null,
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
