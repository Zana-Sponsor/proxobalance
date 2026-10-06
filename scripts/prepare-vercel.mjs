// Vercel serves public/ for this static site. Keep the repository root
// index.html and assets/ as the only editable source of the customer UI.
// Copy them into Vercel's public output ONLY during the deployment build.
import { cpSync, copyFileSync, existsSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const sourceIndex = join(root, 'index.html');
const sourceAssets = join(root, 'assets');
const output = join(root, 'public');
const outputIndex = join(output, 'index.html');

if (!existsSync(sourceIndex) || !existsSync(sourceAssets)) {
  throw new Error('Expected root index.html and assets/; refusing to deploy an outdated public copy.');
}

mkdirSync(output, { recursive: true });
// Preserve public-only pages such as form.html and receipt.html, while
// replacing stale copies of files that have an authoritative root version.
cpSync(sourceAssets, join(output, 'assets'), { recursive: true, force: true });
copyFileSync(sourceIndex, outputIndex);
copyFileSync(join(root,'ip-blocked.html'),join(output,'ip-blocked.html'));
// The canonical Exchange admin panel is also edited at the repository root.
// Always copy it into public/ so Vercel does not serve an older admin page.
const sourceAdmin = join(root, 'exchange-admin.html');
if (!existsSync(sourceAdmin)) throw new Error('Missing root Exchange admin panel.');
copyFileSync(sourceAdmin, join(output, 'exchange-admin.html'));

const html = readFileSync(sourceIndex, 'utf8');
if (!html.includes('id="pageHome"') || !html.includes('id="exchangeCard"')) {
  throw new Error('Root index.html is missing the exchange screen.');
}

// Fail the build if the HTML refers to an asset that cannot be served.
const assetRefs = [...html.matchAll(/(?:src|href)=["']\/(assets\/[^"'?#]+)/g)]
  .map(match => match[1]);
for (const asset of new Set(assetRefs)) {
  if (!existsSync(join(output, asset))) {
    throw new Error('Missing deployable asset: /' + asset);
  }
}

console.log('Deployment prepared from ROOT index.html and ROOT assets/.');
console.log('Output: public/index.html; verified ' + new Set(assetRefs).size + ' referenced assets.');

