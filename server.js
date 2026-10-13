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
import proxolinkHandler from './api/proxolink.js';
import formsHandler from './api/forms.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = Number(process.env.PORT || 3000);

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
app.all('/api/balance', balanceHandler);
app.all('/api/public', publicHandler);
app.all('/api/security-admin', securityAdminHandler);
app.all('/api/track', trackHandler);

// Keep the same public URLs as Vercel's consolidated function rewrites.
const proxoRoute=(op,parameters=()=>({}))=>(req,res)=>{
  Object.defineProperty(req,'query',{value:{...req.query,...parameters(req),op},configurable:true});
  return proxolinkHandler(req,res);
};
app.all('/api/proxolink',proxolinkHandler);
app.all('/api/forms',formsHandler);
for(const op of ['cards','card-action','preview-token','ad-links','templates'])
  app.all('/api/contact-'+op,proxoRoute(op));
app.get('/contact-preview',proxoRoute('template-preview'));
for(const kind of ['contact','order','download']) {
  app.get('/'+kind+'/:id/avatar',proxoRoute(kind==='contact'?'avatar':kind+'-avatar',req=>({id:req.params.id})));
  app.get('/'+kind+'/:id',proxoRoute(kind,req=>({id:req.params.id})));
}
app.get('/a/:token/avatar',proxoRoute('ad-avatar',req=>({token:req.params.token})));
app.get('/api/page-providers',proxoRoute('providers'));
app.post('/api/page-preview-token',proxoRoute('form-preview-token'));
app.get('/page-preview',proxoRoute('form-preview'));
app.get('/page-preview-avatar',proxoRoute('form-preview-avatar'));
app.get('/a/:token/action/:action',proxoRoute('ad',req=>({...req.params})));
app.get('/a/:token',proxoRoute('ad',req=>({token:req.params.token})));

// Never expose repository files, Flutter source or server code through static serving.
app.use(express.static(path.join(__dirname,'public'), { extensions: ['html'] }));
app.get(/\.html$/, (req,res,next)=>{
  const name=path.basename(req.path);
  if(req.path==='/'+name) return res.sendFile(path.join(__dirname,name),error=>{if(error)next();});
  next();
});

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
