import admin from '../api-handlers/admin.js';
import balance from '../api-handlers/balance.js';
import errorLog from '../api-handlers/error-log.js';
import forms from '../api-handlers/forms.js';
import notifyOrder from '../api-handlers/notify-order.js';
import orders from '../api-handlers/orders.js';
import proxolink from '../api-handlers/proxolink.js';
import publicApi from '../api-handlers/public.js';
import securityAdmin from '../api-handlers/security-admin.js';
import supportCases from '../api-handlers/support-cases.js';
import track from '../api-handlers/track.js';
import transactionSummary from '../api-handlers/transaction-summary.js';
import { json } from '../api-handlers/_lib/security.js';

const ROUTE_PARAM = '__pb_api_route';
const handlers = Object.freeze({
  admin,
  balance,
  'error-log': errorLog,
  forms,
  'notify-order': notifyOrder,
  orders,
  proxolink,
  public: publicApi,
  'security-admin': securityAdmin,
  'support-cases': supportCases,
  track,
  'transaction-summary': transactionSummary
});

function first(value) {
  return Array.isArray(value) ? value[0] : value;
}

/**
 * Select a known endpoint, then restore the URL/query shape that its original
 * standalone Vercel Function received. The private routing parameter is never
 * passed through to business handlers or included in their request telemetry.
 */
export function selectApiHandler(req) {
  const url = new URL(req.url || '/', 'http://localhost');
  const query = req.query && typeof req.query === 'object' ? { ...req.query } : {};
  const route = String(first(query[ROUTE_PARAM]) || url.searchParams.get(ROUTE_PARAM) || '');
  const selected = Object.hasOwn(handlers, route) ? handlers[route] : null;
  if (!selected) return null;

  delete query[ROUTE_PARAM];
  url.searchParams.delete(ROUTE_PARAM);
  url.pathname = `/api/${route}`;
  req.url = `${url.pathname}${url.search}`;
  Object.defineProperty(req, 'query', {
    configurable: true,
    enumerable: true,
    writable: true,
    value: query
  });
  return selected;
}

export default async function dispatch(req, res) {
  const selected = selectApiHandler(req);
  if (!selected) return json(res, 404, { ok: false, error: 'not_found' });
  return selected(req, res);
}
