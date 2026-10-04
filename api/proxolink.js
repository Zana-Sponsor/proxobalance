// One deployment function keeps ProxoLink within the Vercel Hobby limit.
import cards from './_lib/proxolink-handlers/contact-cards.js';
import action from './_lib/proxolink-handlers/contact-card-action.js';
import preview from './_lib/proxolink-handlers/contact-preview-token.js';
import links from './_lib/proxolink-handlers/contact-ad-links.js';
import contact from './_lib/proxolink-handlers/contact.js';
import ad from './_lib/proxolink-handlers/contact-ad.js';
import templates, { templatePreview } from './_lib/proxolink-handlers/contact-templates.js';
import { json } from './_lib/security.js';

const handlers = { cards, 'card-action': action, 'preview-token': preview,
  'ad-links': links, contact, ad, templates, 'template-preview': templatePreview };
export default async function handler(req, res) {
  const op = typeof req.query?.op === 'string' ? req.query.op : '';
  const selected = Object.hasOwn(handlers, op) && handlers[op];
  if (!selected) return json(res, 404, { ok: false, error: 'not_found' });
  return selected(req, res);
}
