import { createHash } from 'node:crypto';
import { verifyBearer } from './security.js';
import sharp from 'sharp';

const URL_BASE = (process.env.PROXO_SUPABASE_URL || '').replace(/\/$/, '');
const SERVICE_KEY = process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY || '';
const STYLES = new Set(['dark','light','classic','pill','card','neon','zoom','banner']);
const THEMES = {
  purple:['#5b1fa8','#c855e0'], blue:['#1e3a8a','#2563eb'],
  green:['#14532d','#16a34a'], red:['#7f1d1d','#dc2626'],
  yellow:['#78350f','#d97706'], cyan:['#164e63','#0891b2'],
  pink:['#831843','#be185d'], dark:['#0d1021','#1c2333']
};
const IDS = ['wa','vb','ig','ph','as'];
const PLATFORM_ALIASES={
  wa:'wa',whatsapp:'wa', vb:'vb',viber:'vb',
  tg:'tg',telegram:'tg', ig:'ig',instagram:'ig',
  ph:'ph',phone:'ph',korek:'ph', as:'as',asya:'as',asiacell:'as'
};
export function normalizedPlatforms(platforms,{historical=false}={}) {
  if(!platforms || typeof platforms!=='object' || Array.isArray(platforms))
    throw err(422,'invalid_platform_value');
  const normalized={};
  for(const [key,value] of Object.entries(platforms)) {
    const id=PLATFORM_ALIASES[key.toLowerCase()];
    if(!id || (id==='tg' && !historical))throw err(422,'invalid_platform_value');
    if(value==null||value==='')continue;
    if(typeof value!=='string'||value.length>100)throw err(422,'invalid_platform_value');
    if(normalized[id]!==undefined && normalized[id]!==value)
      throw err(422,'invalid_platform_value');
    normalized[id]=String(value).trim();
  }
  return normalized;
}

const TYPES = {wa:'whatsapp',vb:'viber',ig:'instagram',ph:'phone',as:'asya'};
const LABELS = {
  wa:['واتسئاپ','واتساب'], vb:['ڤایبەر','فايبر'],
  ig:['ئینستاگرام','إنستغرام'],
  ph:['کۆرەک','كورك'], as:['ئاسیا سێڵ','آسيا سيل']
};
const ICON = {wa:'fa-whatsapp',vb:'fa-viber',
  ig:'fa-instagram',ph:'fa-phone-alt',as:'fa-phone-alt'};
const ICON_SIZE = {wa:25,vb:22,ig:22,ph:20,as:20};
const BACKGROUND = {
  wa:'linear-gradient(to left,#128c7e,#25d366)',
  vb:'linear-gradient(to left,#5c4fd6,#7360f2)',
  ig:'linear-gradient(to left,#833ab4,#fd1d1d,#f09433)',
  ph:'linear-gradient(to left,#1d4ed8,#2563eb)',
  as:'linear-gradient(to left,#b91c1c,#dc2626)'
};
const SHADOW = {wa:'rgba(37,211,102,.42)',vb:'rgba(115,96,242,.42)',
  ig:'rgba(220,39,67,.42)',
  ph:'rgba(37,99,235,.42)',as:'rgba(220,38,38,.42)'};
const CLASSIC = {wa:'#25d366',vb:'#7360F2',
  ig:'linear-gradient(to right,#8a2387,#e94057,#f27121)',
  ph:'#e03030',as:'#e03030'};
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
function safeJs(value) {
  // The string is embedded in a single-quoted inline JS literal.
  return String(value).replaceAll('\\','\\\\').replaceAll("'", "\\'")
    .replaceAll('<','\\x3c').replaceAll('>','\\x3e')
    .replaceAll('\r',' ').replaceAll('\n',' ')
    .replace(/\u2028|\u2029/g,' ');
}
function digits(value) {
  if(typeof value!=='string'||!/^\+?[0-9\s()-]+$/.test(value))throw err(422,'invalid_platform_value');
  const result = String(value ?? '').replace(/[^\d]/g,'');
  if (result.length < 8 || result.length > 15) throw err(422,'invalid_platform_value');
  return result;
}
function handle(value) {
  const result = String(value??'').trim().replace(/^@/,'');
  if (!/^[a-zA-Z0-9._]{1,40}$/.test(result)) throw err(422,'invalid_platform_value');
  return result;
}
export function contactDestination(id, raw) {
  switch(id) {
    case 'wa': return 'whatsapp://send?phone='+digits(raw);
    case 'vb': return 'viber://chat?number='+digits(raw);
    case 'ig': return 'https://instagram.com/'+handle(raw);
    case 'ph': case 'as': return 'tel:'+digits(raw);
    default: throw err(422,'invalid_platform_value');
  }
}
export function validateCardData(card,{legacy=false}={}) {
  if (!STYLES.has(card.template_key || card.style)) throw err(422,'template_not_found');
  if (typeof card.name !== 'string' || !card.name.trim() || card.name.length > 160)
    throw err(422,'invalid_card_name');
  if (String(card.bio||'').length > 2000) throw err(422,'invalid_bio');
  // Historical Telegram fields remain stored but are never actionable.
  const platform=normalizedPlatforms(card.platforms,{historical:true});
  const keys=Object.keys(platform).filter(id=>id!=='tg');
  if(!keys.length && !(card.tt||card.tiktok))
    throw err(422,'invalid_platform_value');
  for(const id of keys) contactDestination(id,platform[id]);
  if (card.tt || card.tiktok) {
    if(legacy) { if(!/^[a-zA-Z0-9._@-]{1,100}$/.test(card.tt||card.tiktok))throw err(422,'invalid_platform_value'); }
    else handle(card.tt || card.tiktok);
  }
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
  const cols='id,user_id,name,bio,tt,tiktok,platforms,style,color_theme,template_key,template_version,card_language,avatar_path,status,publish_status,card_number,created_at,updated_at,published_at';
  const rows=await proxoRows('proxolink_cards','&id=eq.'+id+'&limit=1',cols);
  if(!rows.length) throw err(404,'card_not_found');
  return rows[0];
}
export async function activeTemplate(card) {
  const key=card.template_key || card.style;
  const version=card.template_version||1;
  if(!STYLES.has(key) || !Number.isInteger(version) || version<1)
    throw err(404,'template_not_found');
  const rows=await proxoRows('proxolink_templates',
    '&template_key=eq.'+encodeURIComponent(key)+'&version=eq.'+version+'&is_active=eq.true&limit=1',
    'template_key,version,storage_path,checksum_sha256,requires_avatar,renderer_variant,renderer_options,is_catalog_visible');
  if(rows.length!==1) throw err(404,'template_not_found');
  return rows[0];
}
export async function privateTemplate(record) {
  const expected=record.template_key+'/v'+record.version+'/template.html';
  if(record.storage_path!==expected) throw err(503,'template_invalid');
  const p=expected.split('/').map(encodeURIComponent).join('/');
  const response=await request('/storage/v1/object/proxolink-templates/'+p);
  const raw=await response.text();
  if(raw.length>250000 || !raw.includes('{{NAME}}') || !raw.includes('{{BIO}}'))
    throw err(503,'template_invalid');
  const actual=createHash('sha256').update(raw).digest('hex');
  if(record.checksum_sha256 && actual!==record.checksum_sha256)
    throw err(503,'template_invalid');
  return raw;
}
function avatarHtml(card,publicAvatarUrl) {
  if(card.demo===true) return '<img src="/assets/proxolink-demo-avatar.png" style="width:100%;height:100%;object-fit:cover;border-radius:50%">';
  if(card.avatar_path) {
    const prefix=card.user_id+'/'+card.id+'/';
    if(!String(card.avatar_path).startsWith(prefix)) throw err(422,'invalid_avatar');
    // The public document identifies the card, never its Auth owner or the
    // internal Storage object. The route enforces the same page availability.
    const url=publicAvatarUrl||'/contact/'+encodeURIComponent(card.id)+'/avatar';
    return '<img src="'+safeHtml(url)+'" style="width:100%;height:100%;object-fit:cover;border-radius:50%">';
  }
  // Preserve the existing visual fallback.
  return '<span style="font-size:26px;font-weight:800;color:#fff;line-height:1">'
    +safeHtml(Array.from(card.name)[0]?.toUpperCase()||'P')+'</span>';
}
function selectedPlatforms(card) {
  const platforms=normalizedPlatforms(card.platforms,{historical:true});
  return IDS.filter(id=>platforms[id]).map(id=>({
    id, label:LABELS[id][card.card_language==='ar'?1:0],
    type:TYPES[id],value:platforms[id],
    url:contactDestination(id,platforms[id])
  }));
}
function iconClass(id) {return id==='ph'||id==='as'?'fas':'fab';}
function gridButton(p,shine) {
  return '<a id="'+p.id+'" class="btn'+(shine?' shine-active':'')+'">'
    +'<i class="'+iconClass(p.id)+' '+ICON[p.id]+'" style="font-size:'+ICON_SIZE[p.id]+'px"></i>'
    +'<span dir="auto">'+safeText(p.label)+'</span></a>';
}
function badgeUrl(tt) {return 'https://www.tiktok.com/@'+encodeURIComponent(tt);}
function darkLight(parts,tt,ttHref) {
  const btns=[...parts], idx=btns.findIndex(p=>p.id==='wa');
  if(idx===0 && btns.length>=2) [btns[0],btns[1]]=[btns[1],btns[0]];
  else if(idx>1) btns.splice(1,0,btns.splice(idx,1)[0]);
  if(!tt)return {buttons:btns.map((p,i)=>gridButton(p,i===1)).join(''),ttBadge:''};
  const ttUrl=safeHtml(ttHref||badgeUrl(tt)), label=safeHtml(tt);
  const pill='<a href="'+ttUrl+'" target="_blank" class="tt-pill"><span>@'+label
    +'</span><i class="fab fa-tiktok"></i></a>';
  const badge='<div class="tt-wrap"><a href="'+ttUrl
    +'" target="_blank" class="tt-badge"><span>@'+label
    +'</span><i class="fab fa-tiktok"></i></a></div>';
  if(btns.length===1) return {
    buttons:'',ttBadge:'<div class="three-bottom-row">'+pill+gridButton(btns[0],true)+'</div>'
  };
  if(btns.length===3 || btns.length===5) {
    const last=btns.pop();
    return {
      buttons:btns.map((p,i)=>gridButton(p,i===1)).join(''),
      ttBadge:'<div class="three-bottom-row">'+pill+gridButton(last,false)+'</div>'
    };
  }
  return {buttons:btns.map((p,i)=>gridButton(p,i===1)).join(''),ttBadge:badge};
}
function pillButton(p,shine,shadow) {
  return '<a id="'+p.id+'" class="pl-btn'+(shine?' shine-active':'')+'"'
    +' style="background:'+BACKGROUND[p.id]+';box-shadow:'+shadow+';">'
    +'<span style="width:44px;flex-shrink:0;"></span>'
    +'<span class="pl-lbl" dir="auto">'+safeText(p.label)+'</span>'
    +'<i class="'+iconClass(p.id)+' '+ICON[p.id]+'"'
    +' style="font-size:'+ICON_SIZE[p.id]+'px;width:44px;flex-shrink:0;text-align:center;"></i></a>';
}
function contactButtons(style,parts,tt,ttHref) {
  if(style==='dark'||style==='light')return {...darkLight(parts,tt,ttHref),ttInline:''};
  const ttUrl=safeHtml(ttHref||badgeUrl(tt)), label=safeHtml(tt);
  // Preserve the original generator markup, including its inner .tt-wrap:
  // removing it changes the original templates' visible badge spacing.
  let ttBadge=tt?'<div class="tt-wrap"><a href="'+ttUrl
    +'" target="_blank" class="tt-sm"><span dir="ltr">@'+label
    +'</span><i class="fab fa-tiktok" style="font-size:18px"></i></a></div>':'';
  let ttInline='';
  if(style==='banner') {
    ttBadge='';
    if(tt)ttInline='<a href="'+ttUrl+'" target="_blank" style="display:inline-flex;align-items:center;gap:5px;background:rgba(0,0,0,.28);'
      +'padding:4px 12px;border-radius:20px;color:rgba(255,255,255,.92);font-size:12px;margin-top:6px;text-decoration:none;">'
      +'<span dir="ltr">@'+label+'</span><i class="fab fa-tiktok"></i></a>';
  }
  if(style==='classic') {
    return {
      buttons:parts.map((p,i)=>'<a id="'+p.id+'" class="btn-classic'+(i===0?' shine-active':'')
      +'" style="background:'+CLASSIC[p.id]+'"><div class="ic-spacer"></div>'
      +'<span dir="auto">'+safeText(p.label)+'</span><div class="ic-wrap"><i class="'
      +iconClass(p.id)+' '+ICON[p.id]+'"></i></div></a>').join(''),
      ttBadge:tt?'<a href="'+ttUrl+'" target="_blank" class="tt-classic">'
        +'<span dir="ltr">@'+label+'</span><i class="fab fa-tiktok"></i></a>':'',
      ttInline:''
    };
  }
  const buttons=parts.map((p,i)=>{
    const shadow=style==='neon'
      ?'0 0 28px '+SHADOW[p.id].replace('.42','.6')+',0 5px 16px rgba(0,0,0,.5)'
      :(style==='card'?'0 6px 20px ':'0 5px 18px ')+SHADOW[p.id];
    return pillButton(p,i===0,shadow);
  }).join('');
  return {buttons,ttBadge,ttInline};
}
export function renderTemplate(template,card,{adToken=null,variant='standard',rendererOptions={},publicAvatarUrl=null}={}) {
  const legacy=['legacy_dark_inline','legacy_standard'].includes(variant);
  validateCardData(card,{legacy});
  const style=card.template_key||card.style;
  const colors=THEMES[card.color_theme]||Object.values(THEMES).find(pair=>pair.some(c=>c===String(card.color_theme).toLowerCase()))||THEMES.purple;
  const tt=card.tt||card.tiktok?(legacy?(card.tt||card.tiktok):handle(card.tt||card.tiktok)):'';
  const parts=selectedPlatforms(card);
  const pieces=contactButtons(style,parts,tt,card.demo===true?'#':(adToken?'/a/'+encodeURIComponent(adToken)+'/action/tt':null));
  if(variant==='legacy_dark_inline') {
    const colors={wa:'#25d366',vb:'#7360f2',ig:'#fff',ph:'#fff',as:'#fff'};
    pieces.buttons=parts.map(p=>'<a href="'+safeHtml(card.demo===true?'#':(adToken?'/a/'+encodeURIComponent(adToken)+'/action/'+p.id:p.url))+'" target="_blank" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;padding:14px 8px;border-radius:18px;background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.12);text-decoration:none;color:#fff;font-size:13px;font-weight:600;transition:.15s;flex:1;min-width:calc(50% - 6px)"><i class="'+iconClass(p.id)+' '+ICON[p.id]+'" style="font-size:26px;color:'+colors[p.id]+'"></i>'+safeText(p.label)+'</a>').join('');
    pieces.ttBadge=tt?'<a href="'+safeHtml(card.demo===true?'#':(adToken?'/a/'+encodeURIComponent(adToken)+'/action/tt':badgeUrl(tt)))+'" target="_blank" class="tt-link"><i class="fab fa-tiktok"></i>@'+safeHtml(tt)+'</a>':'';
  }
  if(legacy && rendererOptions.tt_prefix_at===false) {
    pieces.ttBadge=pieces.ttBadge.replace('>@'+safeHtml(tt)+'<','>'+safeHtml(tt)+'<');
    pieces.ttInline=pieces.ttInline.replace('>@'+safeHtml(tt)+'<','>'+safeHtml(tt)+'<');
  }
  // In tracked mode a link-scoped URL is the only source of attribution.
  const handlers=parts.map(p=>{
    const url=card.demo===true?'#':adToken
      ?'/a/'+encodeURIComponent(adToken)+'/action/'+p.id
      :p.url;
    return "document.getElementById('"+p.id+"').onclick=function(){"
      +"askConfirm('"+p.type+"','"+safeJs(url)+"','"+safeJs(p.label)+"');};";
  }).join('\n  ');
  const placeholders={
    NAME:safeText(card.name),BIO:safeText(card.bio||''),
    AVATAR:avatarHtml(card,publicAvatarUrl),GRAD:'linear-gradient(to right,'+colors[0]+','+colors[1]+')',
    BUTTONS:pieces.buttons,TT_BADGE:pieces.ttBadge,TT_INLINE:pieces.ttInline,
    THEME_FROM:colors[0],THEME_TO:colors[1],HANDLERS:handlers
  };
  const html=template.replace(/\{\{([A-Z_]+)\}\}/g,(_,k)=>{
    if(!Object.prototype.hasOwnProperty.call(placeholders,k))throw err(503,'template_invalid');
    return placeholders[k];
  });
  if(/\{\{[A-Z_]+\}\}/.test(html))throw err(503,'template_invalid');
  // A signed template demo can also open in a normal browser, outside Flutter's
  // WebView navigation guard. Keep the original modal/press visuals, but make
  // every demo contact/TikTok destination inert and close confirmations locally.
  const demoGuard=card.demo===true
    ? `<script>window.goLink=function(){if(typeof closeModal==='function')closeModal();else if(typeof closeMod==='function')closeMod();};document.querySelectorAll('a[href="#"]').forEach(function(a){a.addEventListener('click',function(e){e.preventDefault();});});</script>`
    : '';
  const guardedHtml=demoGuard
    ? (/<\/body\s*>/i.test(html)?html.replace(/<\/body\s*>/i,demoGuard+'</body>'):html+demoGuard)
    : html;
  return guardedHtml.replaceAll('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2','/assets/fonts/Rabar_021.woff2')
    .replace('<html dir="rtl" lang="ku">','<html dir="'+(card.card_language==='en'?'ltr':'rtl')+'" lang="'+(card.card_language||'ku')+'">');
}
export async function renderedPage(card,{adToken=null,preview=false,previewToken=null}={}) {
  const meta=await activeTemplate(card);
  validateCardData(card,{legacy:['legacy_dark_inline','legacy_standard'].includes(meta.renderer_variant)});
  if(meta.requires_avatar && !card.avatar_path && card.demo!==true) throw err(422,'avatar_required');
  const template=await privateTemplate(meta);
  const publicAvatarUrl=adToken?'/a/'+encodeURIComponent(adToken)+'/avatar'
    :'/contact/'+encodeURIComponent(card.id)+'/avatar'
      +(preview&&previewToken?'?preview_token='+encodeURIComponent(previewToken):'');
  const html=renderTemplate(template,card,{adToken,publicAvatarUrl,variant:meta.renderer_variant||'standard',rendererOptions:meta.renderer_options||{}});
  if(!preview && /^[A-Za-z0-9]{5,60}$/.test(process.env.PROXO_TIKTOK_PIXEL_ID||''))
    return html.replace(/ttq\.load\(['"][^'"]+['"]\)/g,"ttq.load('"+process.env.PROXO_TIKTOK_PIXEL_ID+"')");
  // Strip the non-visual legacy TikTok Pixel bootstrap in owner preview.
  // All eight v1 templates use this same bootstrap. Contact button script
  // checks window.ttq before tracking, so it safely becomes a no-op.
  return html.replace(
    /!function\s*\(w,\s*d,\s*t\)\s*\{[\s\S]*?\}\(window,\s*document,\s*['"]ttq['"]\);/g,
    ''
  );
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
    +"font-src 'self' https://cdnjs.cloudflare.com https://fonts.gstatic.com; img-src 'self' https: data:; "
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
