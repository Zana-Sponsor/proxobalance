import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.join(__dirname, 'public');

// Ensure public directory exists
fs.mkdirSync(publicDir, { recursive: true });

// Sync assets folder
const srcAssets = path.join(__dirname, 'assets');
const dstAssets = path.join(publicDir, 'assets');
if (fs.existsSync(srcAssets)) {
  fs.cpSync(srcAssets, dstAssets, { recursive: true });
}

// Sync root static files
const staticFiles = [
  'index.html',
  'app.css',
  '404.html',
  'exchange-admin.html',
  'exchange-admin1.html'
];

for (const file of staticFiles) {
  const src = path.join(__dirname, file);
  const dst = path.join(publicDir, file);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dst);
  }
}

console.log('Successfully synced static assets to public/');
