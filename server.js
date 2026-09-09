import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

import adminHandler from './api/admin.js';
import errorLogHandler from './api/error-log.js';
import supportCasesHandler from './api/support-cases.js';
import notifyOrderHandler from './api/notify-order.js';
import ordersHandler from './api/orders.js';
import publicHandler from './api/public.js';
import securityAdminHandler from './api/security-admin.js';
import trackHandler from './api/track.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3000;

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Stealth IP ban middleware is temporarily disabled.
// Existing banned_ips data is preserved in Supabase.

// API route handlers
app.all('/api/admin', adminHandler);
app.all('/api/error-log', errorLogHandler);
app.all('/api/support-cases', supportCasesHandler);
app.all('/api/notify-order', notifyOrderHandler);
app.all('/api/orders', ordersHandler);
app.all('/api/public', publicHandler);
app.all('/api/security-admin', securityAdminHandler);
app.all('/api/track', trackHandler);

// Static files
app.use(express.static(__dirname, { extensions: ['html'] }));

// SPA fallback for non-file routes
app.use((req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ error: 'Not found' });
  }
  if (path.extname(req.path) || req.path.startsWith('/assets/')) {
    return res.status(404).type('text/plain').send('Not found');
  }
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on http://0.0.0.0:${PORT}`);
});
