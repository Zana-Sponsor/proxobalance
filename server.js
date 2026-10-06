import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

import adminHandler from './api/admin.js';
import errorLogHandler from './api/error-log.js';
import supportCasesHandler from './api/support-cases.js';
import notifyOrderHandler from './api/notify-order.js';
import ordersHandler from './api/orders.js';
import balanceHandler from './api/balance.js';
import publicHandler from './api/public.js';
import securityAdminHandler from './api/security-admin.js';
import trackHandler from './api/track.js';
import {stealthBanMiddleware} from './api/_lib/security.js';
import proxoLinkHandler from './api/proxolink.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = Number(process.env.PORT || 3000);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use((req,res,next)=>{
 if(req.path==='/ip-blocked.html'||req.path.startsWith('/assets/'))return next();
 return stealthBanMiddleware(req,res,next);
});

// API route handlers
app.all('/api/admin', adminHandler);
app.all('/api/error-log', errorLogHandler);
app.all('/api/support-cases', supportCasesHandler);
app.all('/api/notify-order', notifyOrderHandler);
app.all('/api/orders', ordersHandler);
app.all('/api/balance', balanceHandler);
app.all('/api/public', publicHandler);
app.all('/api/security-admin', securityAdminHandler);
app.all('/api/track', trackHandler);
app.all('/api/proxolink', proxoLinkHandler);

// Match Vercel rewrites locally so browser checks exercise the real API.
const proxoRoute = (route, op) => app.all(route, (req, res) => {
  Object.defineProperty(req, 'query', { value: {...req.query, ...req.params, op}, configurable: true });
  return proxoLinkHandler(req, res);
});
for(const [path,op] of Object.entries({
  '/api/contact-cards':'cards','/api/contact-card-action':'card-action',
  '/api/contact-preview-token':'preview-token','/api/contact-ad-links':'ad-links',
  '/api/contact-templates':'templates','/contact-preview':'template-preview',
  '/contact/:id/avatar':'avatar','/contact/:id':'contact',
  '/a/:token/avatar':'avatar','/a/:token/action/:action':'ad','/a/:token':'ad'
}))proxoRoute(path,op);

// Static files
app.use(express.static(path.join(__dirname, 'public'), { extensions: ['html'] }));

// SPA fallback for non-file routes
app.use((req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ error: 'Not found' });
  }
  if (path.extname(req.path) || req.path.startsWith('/assets/')) {
    return res.status(404).type('text/plain').send('Not found');
  }
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on http://0.0.0.0:${PORT}`);
});

