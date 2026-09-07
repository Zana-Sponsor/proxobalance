import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

import adminHandler from './api/admin.js';
import notifyOrderHandler from './api/notify-order.js';
import ordersHandler from './api/orders.js';
import publicHandler from './api/public.js';
import securityAdminHandler from './api/security-admin.js';
import trackHandler from './api/track.js';
import { stealthBanMiddleware } from './api/_lib/security.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3000;

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Stealth ban middleware
app.use(stealthBanMiddleware);

// API route handlers
app.all('/api/admin', adminHandler);
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
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on http://0.0.0.0:${PORT}`);
});
