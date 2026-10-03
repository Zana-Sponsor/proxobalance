import { createHash } from 'node:crypto';

const URL_BASE = (process.env.PROXO_SUPABASE_URL || '').replace(/\/$/, '');
const SERVICE_KEY = process.env.PROXO_SUPABASE_SERVICE_ROLE_KEY || '';
const STYLES = new Set(['dark','light','classic','pill','card','neon','zoom','banner']);
const THEMES = {
  purple:['#5b1fa8','#c855e0'], blue:['#1e3a8a','#2563eb'],
  green:['#14532d','#16a34a'], red:['#7f1d1d','#dc2626'],
  yellow:['#78350f','#d97706'], cyan:['#164e63','#0891b2'],
  pink:['#831843','#be185d'], dark:['#0d1021','#1c2333']
};
const IDS = ['wa','vb','tg','ig','ph','as'];
const TYPES = {wa:'whatsapp',vb:'viber',tg:'telegram',ig:'instagram',ph:'phone',as:'asya'};
const LABELS = {
  wa:['واتسئاپ','واتساب'], vb:['ڤایبەر','فايبر'],
  tg:['تیلیگرام','تيليجرام'], ig:['ئینستاگرام','إنستغرام'],
  ph:['کۆرەک','كورك'], as:['ئاسیا سێڵ','آسيا سيل']
};
const ICON = {wa:'fa-whatsapp',vb:'fa-viber',tg:'fa-telegram',
  ig:'fa-instagram',ph:'fa-phone-alt',as:'fa-phone-alt'};
const ICON_SIZE = {wa:25,vb:22,tg:22,ig:22,ph:20,as:20};
const BACKGROUND = {
  wa:'linear-gradient(to left,#128c7e,#25d366)',
  vb:'linear-gradient(to left,#5c4fd6,#7360f2)',
  tg:'linear-gradient(to left,#229ed9,#2aabee)',
  ig:'linear-gradient(to left,#833ab4,#fd1d1d,#f09433)',
  ph:'linear-gradient(to left,#1d4ed8,#2563eb)',
  as:'linear-gradient(to left,#b91c1c,#dc2626)'
};
const SHADOW = {wa:'rgba(37,211,102,.42)',vb:'rgba(115,96,242,.42)',
  tg:'rgba(42,171,238,.42)',ig:'rgba(220,39,67,.42)',
  ph:'rgba(37,99,235,.42)',as:'rgba(220,38,38,.42)'};
const CLASSIC = {wa:'#25d366',vb:'#7360F2',tg:'#29a8eb',
  ig:'linear-gradient(to right,#8a2387,#e94057,#f27121)',
  ph:'#e03030',as:'#e03030'};
export const validUuid = value =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value||''));
const err = (status, code) => Object.assign(new Error(code), {status, code});
export function safeHtml(value) {
  return String(value ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;')
    .replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');
}
function safeJs(value) {
  // The string is embedded in a single-quoted inline JS literal.
  return String(value).replaceAll('\\','\\\\').replaceAll("'", "\\'")
    .replaceAll('<','\\x3c').replaceAll('>','\\x3e')
    .replaceAll('\r',' ').replaceAll('\n',' ')
    .replace(/\u2028|\u2029/g,' ');
}
function digits(value) {
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
    case 'tg': return 'https://t.me/'+handle(raw);
    case 'ig': return 'https://instagram.com/'+handle(raw);
    case 'ph': case 'as': return 'tel:'+digits(raw);
    default: throw err(422,'invalid_platform_value');
  }
}
export function validateCardData(card) {
  if (!STYLES.has(card.template_key || card.style)) throw err(422,'template_not_found');
  if (typeof card.name !== 'string' || !card.name.trim() || card.name.length > 160)
    throw err(422,'invalid_card_name');
  if (String(card.bio||'').length > 2000) throw err(422,'invalid_bio');
  const platform = card.platforms;
  if (!platform || typeof platform !== 'object' || Array.isArray(platform))
    throw err(422,'invalid_platform_value');
  const keys = Object.keys(platform);
  if (!keys.length || keys.some(id=>!IDS.includes(id))) throw err(422,'invalid_platform_value');
  for (const id of keys) contactDestination(id,platform[id]);
  if (card.tt || card.tiktok) handle(card.tt || card.tiktok);
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
  const response=await fetch(c.base+path,{...options,headers});
  if (!response.ok) throw err(response.status===404?404:503,'backend_unavailable');
  return response;
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
  return res.status===204?[]:res.json();
}
export async function authenticatedUser(req) {
  const token=String(req.headers?.authorization||'').match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw err(401,'unauthorized');
  const c=configuration();
  const response=await fetch(c.base+'/auth/v1/user',{
    headers:{apikey:c.key,Authorization:'Bearer '+token}
  });
  if(!response.ok) throw err(401,'unauthorized');
  const user=await response.json();
  if(!validUuid(user?.id)) throw err(401,'unauthorized');
  return user;
}
export async function cardById(id) {
  if(!validUuid(id)) throw err(404,'card_not_found');
  const cols='id,user_id,name,bio,tt,tiktok,platforms,style,color_theme,template_key,template_version,card_language,avatar_path,status,publish_status';
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
    'template_key,version,storage_path,checksum_sha256,requires_avatar');
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
function avatarHtml(card) {
  if(card.avatar_path) {
    const prefix=card.user_id+'/'+card.id+'/';
    if(!String(card.avatar_path).startsWith(prefix)) throw err(422,'invalid_avatar');
    const path=String(card.avatar_path).split('/').map(encodeURIComponent).join('/');
    const url=configuration().base+'/storage/v1/object/public/proxolink-assets/'+path;
    return '<img src="'+safeHtml(url)+'" style="width:100%;height:100%;object-fit:cover;border-radius:50%">';
  }
  // Preserve the existing visual fallback.
  return '<span style="font-size:26px;font-weight:800;color:#fff;line-height:1">'
    +safeHtml(Array.from(card.name)[0]?.toUpperCase()||'P')+'</span>';
}
function selectedPlatforms(card) {
  return IDS.filter(id=>card.platforms[id]).map(id=>({
    id, label:LABELS[id][card.card_language==='ar'?1:0],
    type:TYPES[id],value:card.platforms[id],
    url:contactDestination(id,card.platforms[id])
  }));
}
function iconClass(id) {return id==='ph'||id==='as'?'fas':'fab';}
function gridButton(p,shine) {
  return '<a id="'+p.id+'" class="btn'+(shine?' shine-active':'')+'">'
    +'<i class="'+iconClass(p.id)+' '+ICON[p.id]+'" style="font-size:'+ICON_SIZE[p.id]+'px"></i>'
    +'<span>'+safeHtml(p.label)+'</span></a>';
}
function badgeUrl(tt) {return 'https://www.tiktok.com/@'+encodeURIComponent(tt);}
function darkLight(parts,tt) {
  const btns=[...parts], idx=btns.findIndex(p=>p.id==='wa');
  if(idx===0 && btns.length>=2) [btns[0],btns[1]]=[btns[1],btns[0]];
  else if(idx>1) btns.splice(1,0,btns.splice(idx,1)[0]);
  const ttUrl=safeHtml(badgeUrl(tt)), label=safeHtml(tt);
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
    +'<span class="pl-lbl">'+safeHtml(p.label)+'</span>'
    +'<i class="'+iconClass(p.id)+' '+ICON[p.id]+'"'
    +' style="font-size:'+ICON_SIZE[p.id]+'px;width:44px;flex-shrink:0;text-align:center;"></i></a>';
}
function contactButtons(style,parts,tt) {
  if(style==='dark'||style==='light')return {...darkLight(parts,tt),ttInline:''};
  const ttUrl=safeHtml(badgeUrl(tt)), label=safeHtml(tt);
  let ttBadge=tt?'<div class="tt-wrap"><a href="'+ttUrl
    +'" target="_blank" class="tt-sm"><span dir="ltr">@'+label
    +'</span><i class="fab fa-tiktok" style="font-size:18px"></i></a></div>':'';
  let ttInline='';
  if(style==='banner') {
    ttBadge='';
    if(tt)ttInline='<div style="display:inline-flex;align-items:center;gap:5px;background:rgba(0,0,0,.28);'
      +'padding:4px 12px;border-radius:20px;color:rgba(255,255,255,.92);font-size:12px;margin-top:6px;">'
      +'<span dir="ltr">@'+label+'</span><i class="fab fa-tiktok"></i></div>';
  }
  if(style==='classic') {
    return {
      buttons:parts.map((p,i)=>'<a id="'+p.id+'" class="btn-classic'+(i===0?' shine-active':'')
      +'" style="background:'+CLASSIC[p.id]+'"><div class="ic-spacer"></div>'
      +'<span>'+safeHtml(p.label)+'</span><div class="ic-wrap"><i class="'
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
export function renderTemplate(template,card,{adToken=null}={}) {
  validateCardData(card);
  const style=card.template_key||card.style;
  const colors=THEMES[card.color_theme]||THEMES.purple;
  const tt=card.tt||card.tiktok?handle(card.tt||card.tiktok):'';
  const parts=selectedPlatforms(card);
  const pieces=contactButtons(style,parts,tt);
  // In tracked mode a link-scoped URL is the only source of attribution.
  const handlers=parts.map(p=>{
    const url=adToken
      ?'/a/'+encodeURIComponent(adToken)+'/action/'+p.id
      :p.url;
    return "document.getElementById('"+p.id+"').onclick=function(){"
      +"askConfirm('"+p.type+"','"+safeJs(url)+"','"+safeJs(p.label)+"');};";
  }).join('\n  ');
  const placeholders={
    NAME:safeHtml(card.name),BIO:safeHtml(card.bio||''),
    AVATAR:avatarHtml(card),GRAD:'linear-gradient(to right,'+colors[0]+','+colors[1]+')',
    BUTTONS:pieces.buttons,TT_BADGE:pieces.ttBadge,TT_INLINE:pieces.ttInline,
    THEME_FROM:colors[0],THEME_TO:colors[1],HANDLERS:handlers
  };
  const html=template.replace(/\{\{([A-Z_]+)\}\}/g,(_,k)=>{
    if(!Object.prototype.hasOwnProperty.call(placeholders,k))throw err(503,'template_invalid');
    return placeholders[k];
  });
  if(/\{\{[A-Z_]+\}\}/.test(html))throw err(503,'template_invalid');
  return html;
}
export async function renderedPage(card,{adToken=null}={}) {
  validateCardData(card);
  const meta=await activeTemplate(card);
  if(meta.requires_avatar && !card.avatar_path) throw err(422,'avatar_required');
  const template=await privateTemplate(meta);
  return renderTemplate(template,card,{adToken});
}
export function publicPage(res,html) {
  res.statusCode=200;
  res.setHeader('Content-Type','text/html; charset=utf-8');
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Referrer-Policy','strict-origin-when-cross-origin');
  res.end(html);
}
export function unavailable(res) {
  res.statusCode=404;
  res.setHeader('Content-Type','text/html; charset=utf-8');
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.end('<!doctype html><html lang="ku" dir="rtl"><meta charset="utf-8"><title>Proxo</title><body><p>ئەم پەڕەیە ئێستا بەردەست نییە.</p></body></html>');
}
