import { createHash } from 'node:crypto';
import { verifyBearer } from './security.js';
import sharp from 'sharp';

const URL_BASE = (process.env.PROXO_SUPABASE_URL || '').replace(/\/$/, '');
const SERVICE_KEY = process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY || '';
import { readFile } from 'node:fs/promises';
import { TEMPLATE_KEYS, TEMPLATE_VERSION, PROVIDERS, PLATFORM_ALIASES, LEGACY_TEMPLATE_MAP, destination } from './proxolink-catalog.js';
const STYLES = new Set(TEMPLATE_KEYS);
export function normalizedPlatforms(platforms) {
  if (!platforms || typeof platforms !== 'object' || Array.isArray(platforms)) throw err(422,'invalid_platform_value');
  const result={};
  for (const [key,value] of Object.entries(platforms)) {
    const id=PLATFORM_ALIASES[key.toLowerCase()];
    if(!id)throw err(422,'invalid_platform_value');
    if(value==null||value==='')continue;
    if(typeof value!=='string'||value.length>2048)throw err(422,'invalid_platform_value');
    if(result[id]!==undefined&&result[id]!==value.trim())throw err(422,'invalid_platform_value');
    result[id]=value.trim();
  }
  return result;
}
export const validUuid = value =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value||''));
const err = (status, code) => Object.assign(new Error(code), {status, code});
export function safeHtml(value) {
  return String(value ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;')
    .replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');
}
// Equivalent to the existing Flutter ProxoTextDirection.html policy.
export function safeText(value) {
  const text=String(value??'');
  if(!/[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/u.test(text))return safeHtml(text);
  const run=/[+\-−$#@]{0,2}[A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9][A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9\p{M}_.,:/@+%?=&~\u066A\u066B\u066C\-]*(?:[ \t]+[+\-−$#@]{0,2}[A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9][A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9\p{M}_.,:/@+%?=&~\u066A\u066B\u066C\-]*)*/gu;
  let offset=0,result='';
  for(const match of text.matchAll(run)) {
    result+=safeHtml(text.slice(offset,match.index))+'<bdi dir="ltr">'+safeHtml(match[0])+'</bdi>';
    offset=match.index+match[0].length;
  }
  return result+safeHtml(text.slice(offset));
}
export function contactDestination(id,raw) {
  const url=destination(id,raw);
  if(!url)throw err(422,'invalid_platform_value');
  return url;
}
export function validateCardData(card,{allowEmpty=false}={}) {
  const key=LEGACY_TEMPLATE_MAP[card.template_key||card.style]||card.template_key||card.style;
  if(!STYLES.has(key))throw err(422,'template_not_found');
  if(typeof card.name!=='string'||!card.name.trim()||card.name.length>160)throw err(422,'invalid_card_name');
  if(String(card.bio||'').length>2000)throw err(422,'invalid_bio');
  if(!['contact','food','download'].includes(card.page_type||'contact'))throw err(422,'invalid_request');
  const platforms=normalizedPlatforms(card.platforms);
  if(!allowEmpty&&!Object.keys(platforms).length&&!(card.tt||card.tiktok))throw err(422,'invalid_platform_value');
  for(const [id,value] of Object.entries(platforms))contactDestination(id,value);
  if((card.tt||card.tiktok)&&!/^[a-zA-Z0-9._-]{1,100}$/.test(String(card.tt||card.tiktok).replace(/^@/,'')))throw err(422,'invalid_platform_value');
  return true;
}
function configuration() {
  if (!URL_BASE || !URL_BASE.startsWith('https://') || !SERVICE_KEY)
    throw err(503,'proxolink_server_not_configured');
  return {base:URL_BASE, key:SERVICE_KEY};
}
async function request(path,options={}) {
  const c=configuration();
  const headers = {apikey:c.key,Authorization:'Bearer '+c.key,...options.headers};
  const response=await fetch(c.base+path,{signal:AbortSignal.timeout(10000),...options,headers});
  if (!response.ok) throw err(response.status===404?404:503,'backend_unavailable');
  return response;
}
export async function avatarBytes(path) {
  if(!path)throw err(404,'avatar_not_found');
  const encoded=String(path).split('/').map(encodeURIComponent).join('/');
  const response=await request('/storage/v1/object/proxolink-assets/'+encoded);
  const mime=String(response.headers.get('content-type')||'').split(';')[0].toLowerCase();
  if(!['image/jpeg','image/png','image/webp'].includes(mime))
    throw err(422,'invalid_avatar');
  const data=new Uint8Array(await response.arrayBuffer());
  if(!data.length || data.length>10*1024*1024)throw err(422,'invalid_avatar');
  const jpeg=data[0]===0xff&&data[1]===0xd8&&data[2]===0xff;
  const png=data[0]===0x89&&data[1]===0x50&&data[2]===0x4e&&data[3]===0x47;
  const webp=String.fromCharCode(...data.slice(0,4))==='RIFF'
    &&String.fromCharCode(...data.slice(8,12))==='WEBP';
  if(!((jpeg&&mime==='image/jpeg')||(png&&mime==='image/png')
    ||(webp&&mime==='image/webp')))throw err(422,'invalid_avatar');
  try {
    const decoded=sharp(data,{limitInputPixels:25000000,failOn:'warning'});
    const info=await decoded.metadata();
    if(!info.width||!info.height||info.width>8192||info.height>8192)throw Error();
    await decoded.raw().toBuffer();
  } catch {throw err(422,'invalid_avatar');}
  return {data,mime};
}
export async function verifyPublicAvatar(path) {
  if(!path)return false;
  await avatarBytes(path);
  return true;
}
export async function proxoRows(table,filters='',columns='*') {
  const q='/rest/v1/'+table+'?select='+encodeURIComponent(columns)+filters;
  const res=await request(q,{headers:{Accept:'application/json'}});
  return res.json();
}
export async function proxoWrite(table,method,data,filters='',prefer='return=representation') {
  const res=await request('/rest/v1/'+table+(filters?'?'+filters:''),{
    method,headers:{'Content-Type':'application/json',Prefer:prefer},
    body:JSON.stringify(data)
  });
  // PostgREST returns an empty 201 for INSERT with return=minimal; PATCH
  // and DELETE may return an empty 204. Both are successful writes.
  const body=await res.text();
  return body.trim()?JSON.parse(body):[];
}
export async function authenticatedUser(req) {
  const c=configuration();
  const user=await verifyBearer(req,c);
  if(!validUuid(user?.id)) throw err(401,'unauthorized');
  return user;
}
export async function cardById(id) {
  if(!validUuid(id)) throw err(404,'card_not_found');
  const cols='id,user_id,name,bio,tt,tiktok,platforms,style,color_theme,template_key,template_version,card_language,page_type,avatar_path,avatar_b64,logo_b64,status,publish_status,card_number,created_at,updated_at,published_at';
  const rows=await proxoRows('proxolink_cards','&id=eq.'+id+'&limit=1',cols);
  if(!rows.length) throw err(404,'card_not_found');
  return rows[0];
}
export async function activeTemplate(card) {
  const key=LEGACY_TEMPLATE_MAP[card.template_key||card.style]||card.template_key||card.style;
  if(!STYLES.has(key))throw err(404,'template_not_found');
  const rows=await proxoRows('proxolink_templates',
    '&template_key=eq.'+encodeURIComponent(key)+'&version=eq.'+TEMPLATE_VERSION+'&is_active=eq.true&is_catalog_visible=eq.true&limit=1',
    'template_key,version,storage_path,checksum_sha256,requires_avatar');
  if(rows.length!==1)throw err(404,'template_not_found');
  return rows[0];
}
// Literal paths let Vercel trace these private files without exposing them in public/.
const templateSources={
  pill:()=>readFile(new URL('./proxolink-templates/pill.html',import.meta.url),'utf8'),
  'pill-mint':()=>readFile(new URL('./proxolink-templates/pill-mint.html',import.meta.url),'utf8'),
  'pill-dark':()=>readFile(new URL('./proxolink-templates/pill-dark.html',import.meta.url),'utf8'),
  'pill-white':()=>readFile(new URL('./proxolink-templates/pill-white.html',import.meta.url),'utf8'),
};
export async function privateTemplate(record) {
  if(!STYLES.has(record.template_key)||record.version!==TEMPLATE_VERSION
    ||record.storage_path!==record.template_key+'/v2/template.html')throw err(503,'template_invalid');
  // These four reviewed documents are private server assets, traced into the
  // deployment. Never serve arbitrary customer HTML or resurrect old styles.
  const raw=await templateSources[record.template_key]();
  if(raw.length>1500000||!raw.includes('{{PROXO_CONFIG}}'))throw err(503,'template_invalid');
  const actual=createHash('sha256').update(raw).digest('hex');
  if(!record.checksum_sha256||actual!==record.checksum_sha256)throw err(503,'template_invalid');
  return raw;
}
const encodeConfig=value=>JSON.stringify(value).replaceAll('<','\\u003c').replaceAll('>','\\u003e').replaceAll('&','\\u0026').replace(/\u2028/g,'\\u2028').replace(/\u2029/g,'\\u2029');
const localized={
  tg:['تیلیگرام','تيليجرام','Telegram'],ig:['ئینستاگرام','إنستغرام','Instagram'],
  wa:['واتسئاپ','واتساب','WhatsApp'],vb:['ڤایبەر','فايبر','Viber'],
  ph:['کۆڕەک','كورك','Korek'],as:['ئاسیاسێڵ','آسيا سيل','Asiacell'],
  talabat:['تەڵەبات','طلبات','Talabat'],lezzoo:['لەزوو','ليزو','Lezzoo'],
  wade:['وادێ','وادي','WADE'],toters:['توتەرز','توترز','Toters']
};
export function renderTemplate(template,card,{adToken=null,publicAvatarUrl=null}={}) {
  validateCardData(card,{allowEmpty:true});
  const key=LEGACY_TEMPLATE_MAP[card.template_key||card.style]||card.template_key||card.style;
  const index=card.card_language==='en'?2:card.card_language==='ar'?1:0;
  const tt=String(card.tt||card.tiktok||'').replace(/^@/,'');
  const config={template:key,preview:card.demo===true,name:card.name,bio:card.bio||'',
    lang:card.card_language||'ku',direction:card.card_language==='en'?'ltr':'rtl',
    avatarUrl:publicAvatarUrl||'',tiktokUrl:tt?'https://www.tiktok.com/@'+encodeURIComponent(tt):'',tiktokLabel:tt?'@'+tt:'',
    buttons:Object.entries(normalizedPlatforms(card.platforms)).map(([id,value])=>({
      type:PROVIDERS[id].type,url:contactDestination(id,value),
      ...(localized[id]?{label:localized[id][index]}:{}),enabled:true
    }))};
  let html=template.replace('{{PROXO_CONFIG}}',()=>encodeConfig(config));
  if(html.includes('{{PROXO_CONFIG}}'))throw err(503,'template_invalid');
  if(adToken&&card.demo!==true) {
    if(!/^[A-Za-z0-9_-]{20,128}$/.test(adToken))throw err(422,'invalid_request');
    const map=Object.fromEntries(Object.entries(PROVIDERS).map(([id,p])=>[p.type,id]));map.tiktok='tt';
    // The destination still passes the template allowlist. Attribution goes
    // through the link owned by this ad; the server validates it on each click.
    const bridge='<script>window.__PROXO_INTERCEPT_NAVIGATION__=true;window.addEventListener("proxo:navigate",function(e){const ids='+encodeConfig(map)+';const id=ids[e.detail&&e.detail.provider];if(!id)return;e.preventDefault();location.assign('+encodeConfig('/a/'+adToken+'/action/')+'+id);});</script>';
    html=html.replace('</head>',bridge+'</head>');
  }
  return html;
}
export async function renderedPage(card,{adToken=null,preview=false,previewToken=null}={}) {
  const meta=await activeTemplate(card);
  validateCardData(card,{allowEmpty:true});
  const template=await privateTemplate(meta);
  if(card.avatar_path){
    const prefix=card.user_id+'/'+card.id+'/';
    if(!String(card.avatar_path).startsWith(prefix))throw err(422,'invalid_avatar');
  }
  const publicAvatarUrl=(card.avatar_path||card.avatar_b64||card.logo_b64)
    ?(adToken?'/a/'+encodeURIComponent(adToken)+'/avatar':'/contact/'+encodeURIComponent(card.id)+'/avatar'+(preview&&previewToken?'?preview_token='+encodeURIComponent(previewToken):'')):null;
  let html=renderTemplate(template,{...card,template_key:meta.template_key},{adToken,publicAvatarUrl});
  const pixel=process.env.PROXO_TIKTOK_PIXEL_ID||'';
  if(!preview&&card.demo!==true&&adToken&&/^[A-Za-z0-9]{5,60}$/.test(pixel)) {
    const script='<script>!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=["page","track","identify","instances","debug","on","off","once","ready","alias","group","enableCookie","disableCookie"];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.load=function(e){var s=d.createElement("script");s.type="text/javascript";s.async=true;s.src="https://analytics.tiktok.com/i18n/pixel/events.js?sdkid="+e+"&lib="+t;d.head.appendChild(s)};ttq.load('+encodeConfig(pixel)+');ttq.page()}(window,document,"ttq");</script>';
    html=html.replace('</head>',script+'</head>');
  }
  return html;
}
export async function cardAvatarBytes(card){
  if(card.avatar_path)return avatarBytes(card.avatar_path);
  const raw=String(card.avatar_b64||card.logo_b64||'');
  if(!raw||raw.length>14000000)throw err(404,'avatar_not_found');
  const match=/^(?:data:image\/(png|jpeg|jpg|webp);base64,)?([A-Za-z0-9+/=\s]+)$/.exec(raw);
  if(!match)throw err(422,'invalid_avatar');
  const data=Buffer.from(match[2],'base64');
  try {
    const image=sharp(data,{limitInputPixels:25000000,failOn:'warning'});
    const info=await image.metadata();
    if(!['png','jpeg','webp'].includes(info.format)||!info.width||!info.height||info.width>8192||info.height>8192)throw Error();
    // Re-encode rather than serving bytes containing unknown trailing data.
    return {data:await image.webp({quality:88}).toBuffer(),mime:'image/webp'};
  }catch{throw err(422,'invalid_avatar');}
}
export function publicPage(res,html) {
  res.statusCode=200;
  res.setHeader('Content-Type','text/html; charset=utf-8');
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Referrer-Policy','no-referrer');
  res.setHeader('Permissions-Policy','camera=(), microphone=(), geolocation=()');
  const hashes=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
    .map(m=>"'sha256-"+createHash('sha256').update(m[1]).digest('base64')+"'");
  const eventHashes=[...html.matchAll(/\sonclick="([^"]+)"/g)]
    .filter(m=>['goLink()','closeModal()','closeMod()'].includes(m[1]))
    .map(m=>"'sha256-"+createHash('sha256').update(m[1]).digest('base64')+"'");
  res.setHeader('Content-Security-Policy', "default-src 'none'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; "
    +"script-src 'self' 'unsafe-hashes' "+[...hashes,...eventHashes].join(' ')+" https://analytics.tiktok.com; "
    +"style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://fonts.googleapis.com; "
    +"font-src 'self' data:; img-src 'self' https: data:; "
    +"connect-src 'self' https://analytics.tiktok.com https://*.tiktok.com;");
  res.end(html);
}
export function unavailable(res) {
  res.statusCode=404;
  res.setHeader('Content-Type','text/html; charset=utf-8');
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.end('<!doctype html><html lang="ku" dir="rtl"><meta charset="utf-8"><title>Proxo</title><body><p>ئەم پەڕەیە ئێستا بەردەست نییە.</p></body></html>');
}
