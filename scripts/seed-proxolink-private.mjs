// Secure one-time upload. Never add the private template directory to Git.
import { readFile, access } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';

const KEYS=['dark','light','classic','pill','card','neon','zoom','banner'];
const LABELS={
  dark:['تاریک','Dark'], light:['ڕووناک','Light'],
  classic:['کلاسیک','Classic'],pill:['پیل گرادیەنت','Pill'],
  card:['کارد ئاکسنت','Card'],neon:['نیۆن ئاوتلاین','Neon'],
  zoom:['زووم','Zoom'],banner:['بانەر','Banner']
};
const root=path.resolve(process.argv[2]||'');
const apply=process.argv.includes('--apply');
if(!process.argv[2]||process.argv[2].startsWith('-'))
  throw Error('Usage: node scripts/seed-proxolink-private.mjs /absolute/private/extracted/folder [--apply]');
const entries=JSON.parse(await readFile(path.join(root,'manifest.json'),'utf8'));
if(!Array.isArray(entries)||entries.length!==8)throw Error('Expected exactly eight private templates');
const base=String(process.env.PROXO_SUPABASE_URL||'').replace(/\/$/,'');
const key=process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY||'';
if(apply && (!base.startsWith('https://')||!key))
  throw Error('Set PROXO_SUPABASE_URL and PROXO_SUPABASE_SERVICE_ROLE_KEY securely');

async function api(pathname,method,body,headers={}) {
  const response=await fetch(base+pathname,{
    method,headers:{apikey:key,Authorization:'Bearer '+key,...headers},
    body
  });
  if(!response.ok)throw Error('Private seed API failed: HTTP '+response.status);
  return response;
}
for(const entry of entries) {
  const {template_key:k,version,storage_path:p,checksum_sha256:expected,requires_avatar}=entry;
  if(!KEYS.includes(k)||![1,2].includes(version)||p!==k+'/v'+version+'/template.html'
    ||typeof expected!=='string'||!/^[a-f0-9]{64}$/.test(expected))
    throw Error('Unsafe template metadata');
  const filepath=path.resolve(root,p);
  if(!filepath.startsWith(root+path.sep))throw Error('Unsafe source path');
  await access(filepath);
  const data=await readFile(filepath);
  const hash=createHash('sha256').update(data).digest('hex');
  if(hash!==expected||!data.includes(Buffer.from('{{NAME}}'))
    ||!data.includes(Buffer.from('{{BIO}}')))
    throw Error('Private template verification failed: '+k);
  if(!apply) {
    process.stdout.write('DRY RUN OK: '+k+' v'+version+', verified SHA-256\n');
    continue;
  }
  const objectPath='/storage/v1/object/proxolink-templates/'
    +p.split('/').map(encodeURIComponent).join('/');
  const existing=await fetch(base+objectPath,{headers:{
    apikey:key,Authorization:'Bearer '+key
  }});
  if(existing.ok) {
    const actual=createHash('sha256').update(
      Buffer.from(await existing.arrayBuffer())
    ).digest('hex');
    if(actual!==expected)throw Error('Existing private object differs: '+k);
  } else if(existing.status===404) {
    await api(objectPath,'POST',data,{
      'Content-Type':'text/html; charset=utf-8',
      'x-upsert':'false'
    });
  } else throw Error('Cannot verify private object: '+k);
  const downloaded=await api(objectPath,'GET');
  const downloadedHash=createHash('sha256').update(
    Buffer.from(await downloaded.arrayBuffer())
  ).digest('hex');
  if(downloadedHash!==expected)throw Error('Uploaded private object checksum mismatch: '+k);
  await api('/rest/v1/proxolink_templates?on_conflict=template_key,version',
    'POST',JSON.stringify({
      template_key:k,version,
      display_name_ckb:LABELS[k][0],display_name_en:LABELS[k][1],
      storage_path:p,checksum_sha256:expected,
      requires_avatar:requires_avatar===true,
      is_active:version===1?true:entry.is_active===true,
      is_catalog_visible:version===1?true:entry.is_catalog_visible===true
    }),{
      'Content-Type':'application/json',
      Prefer:'resolution=merge-duplicates,return=minimal'
    });
  process.stdout.write('PRIVATE UPLOAD VERIFIED: '+k+' v'+version+'\n');
}
process.stdout.write(apply?'Private seeding completed.\n':'Dry run completed: no upload performed.\n');
