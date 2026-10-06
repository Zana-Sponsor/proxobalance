// One deployment function keeps ProxoLink within the Vercel Hobby limit.
import cards from './_lib/proxolink-handlers/contact-cards.js';
import action from './_lib/proxolink-handlers/contact-card-action.js';
import preview from './_lib/proxolink-handlers/contact-preview-token.js';
import links from './_lib/proxolink-handlers/contact-ad-links.js';
import contact from './_lib/proxolink-handlers/contact.js';
import ad from './_lib/proxolink-handlers/contact-ad.js';
import avatar from './_lib/proxolink-handlers/contact-avatar.js';
import templates, { templatePreview, providers } from './_lib/proxolink-handlers/contact-templates.js';
import { createFormPreview, renderFormPreview, formPreviewAvatar } from './_lib/proxolink-handlers/page-preview.js';
import { json } from './_lib/security.js';

const handlers = { cards, 'card-action': action, 'preview-token': preview,
  'ad-links': links, contact, order:contact, download:contact, ad, avatar, templates, providers,
  'form-preview-token':createFormPreview, 'form-preview':renderFormPreview, 'form-preview-avatar':formPreviewAvatar, 'template-preview': templatePreview, providers };
export default async function handler(req, res) {
  const op = typeof req.query?.op === 'string' ? req.query.op : '';
  const selected = Object.hasOwn(handlers, op) && handlers[op];
  if (!selected) return json(res, 404, { ok: false, error: 'not_found' });
  if(['contact','order','download'].includes(op))req.query.page_type=op;
  return selected(req, res);
}
