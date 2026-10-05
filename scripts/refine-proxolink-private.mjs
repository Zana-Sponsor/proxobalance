// Creates immutable private v2 copies only. No network, upload, database edit,
// source printing or customer cutover. Upload/activation is a separate gate.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {TEMPLATE_ORDER,refineTemplate} from './proxolink-refinements.mjs';

const [inputArg,outputArg]=process.argv.slice(2);
if(!inputArg||!outputArg)throw Error('Usage: node scripts/refine-proxolink-private.mjs /private/v1-root /private/v2-root');
const input=path.resolve(inputArg),output=path.resolve(outputArg);
if(input===output||output.startsWith(input+path.sep))throw Error('Use a separate private output directory');
const originals=JSON.parse(await readFile(path.join(input,'manifest.json'),'utf8'));
if(!Array.isArray(originals)||originals.length!==8
  ||new Set(originals.map(e=>e.template_key)).size!==8)throw Error('Expected eight original entries');
const refined=[];
for(const key of TEMPLATE_ORDER) {
  const entry=originals.find(e=>e.template_key===key);
  if(entry?.version!==1||entry.storage_path!==key+'/v1/template.html'
    ||!/^[a-f0-9]{64}$/.test(entry.checksum_sha256))throw Error('Invalid v1 manifest');
  const source=await readFile(path.join(input,entry.storage_path),'utf8');
  const sourceHash=createHash('sha256').update(source).digest('hex');
  if(sourceHash!==entry.checksum_sha256)throw Error('Original checksum mismatch: '+key);
  const html=refineTemplate(source,key),storagePath=key+'/v2/template.html';
  const file=path.join(output,storagePath);
  await mkdir(path.dirname(file),{recursive:true,mode:0o700});
  // Refuse overwrites so neither original nor previously reviewed output can
  // silently change after someone has pinned a template version/checksum.
  await writeFile(file,html,{flag:'wx',mode:0o600});
  refined.push({...entry,version:2,storage_path:storagePath,
    source_checksum_sha256:sourceHash,
    checksum_sha256:createHash('sha256').update(html).digest('hex'),
    is_active:false,is_catalog_visible:false});
  console.log('PREPARED: '+key+' v2 (inactive; v1 unchanged)');
}
await writeFile(path.join(output,'manifest.json'),JSON.stringify(refined,null,2)+'\n',{flag:'wx',mode:0o600});
