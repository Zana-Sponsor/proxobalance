// Authoritative V6 contract. It contains metadata/validators, never customer links.
export const PAGE_TYPES = ['contact', 'order', 'download'];
export const PREPARED_DESIGNS = ['pill', 'pill-mint', 'pill-dark', 'pill-white'];
export const PREPARED_VERSION = 6;
export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const pageError = code => Object.assign(new Error(code), {code, status:422});
export const AUTHORING_PROVIDERS = Object.freeze({
  contact:['whatsapp','viber','instagram','telegram','korek','asiacell'],
  order:['talabat','toters'], download:['google_play','app_store'],
});
const provider = (pageType, label, icon, inputKind, hosts=[]) =>
  Object.freeze({page_type:pageType,label,icon,input_kind:inputKind,hosts,enabled:true});
export const PROVIDER_REGISTRY = Object.freeze({
  whatsapp:provider('contact','WhatsApp','whatsapp','phone',['wa.me','api.whatsapp.com']),
  viber:provider('contact','Viber','viber','phone'),
  instagram:provider('contact','Instagram','instagram','handle',['instagram.com','www.instagram.com']),
  telegram:provider('contact','Telegram','telegram','handle',['t.me','telegram.me']),
  korek:provider('contact','Korek','korek','phone'),
  asiacell:provider('contact','Asiacell','asiacell','phone'),
  talabat:provider('order','Talabat','talabat','url',['talabat.com']),
  toters:provider('order','Toters','toters','url',['totersapp.com','toters.com']),
  // Already supported in the four prepared designs; adding another provider
  // requires this registry, a reviewed asset and server validation together.
  lezzoo:provider('order','Lezzoo','lezzoo','url',['lezzoo.com','lezzoodevs.com']),
  wade:provider('order','WADE','wade','url',['wadedelivery.com','trytiptop.com']),
  google_play:provider('download','Google Play','google_play','url',['play.google.com']),
  app_store:provider('download','Apple App Store','app_store','url',['apps.apple.com']),
});
export const LEGACY_PROVIDER_IDS={whatsapp:'wa',viber:'vb',instagram:'ig',telegram:'tg',korek:'ph',asiacell:'as',talabat:'talabat',toters:'toters',lezzoo:'lezzoo',wade:'wade',google_play:'google_play',app_store:'app_store'};
export const DESIGN_ALIASES={dark:'pill-dark',light:'pill-white',classic:'pill-white',card:'pill-white',neon:'pill-mint',zoom:'pill',banner:'pill'};
export const pageKind = card => card.page_kind || 'contact'; // Explicit legacy route adapter.
export const publicPath = card => '/'+pageKind(card)+'/'+card.id;
export function registryMetadata() {
  return Object.entries(PROVIDER_REGISTRY).filter(([key,p])=>AUTHORING_PROVIDERS[p.page_type].includes(key))
    .map(([key,p])=>({provider_key:key,...p}));
}
function phone(raw) {
  let value=raw.replace(/[٠-٩۰-۹]/g,c=>String(c.charCodeAt(0)-(c<='٩'?1632:1776)))
    .replace(/^tel:/,'').replace(/[\s()-]/g,'');
  if(/^07\d{9}$/.test(value))value='+964'+value.slice(1);
  if(!/^\+?[1-9]\d{7,14}$/.test(value))throw pageError('invalid_provider_destination');
  return value.replace(/^\+/,'');
}
export function providerDestination(key,raw) {
  const p=PROVIDER_REGISTRY[key];
  if(!p?.enabled||typeof raw!=='string'||!raw.trim()||raw.length>2048
    ||/[\x00-\x1f\x7f<>\\]/.test(raw))throw pageError('invalid_provider_destination');
  const value=raw.trim();
  if(p.input_kind==='phone'&&!value.includes('://')) {
    const n=phone(value);
    if(key==='whatsapp')return 'https://wa.me/'+n;
    if(key==='viber')return 'viber://chat?number='+encodeURIComponent('+'+n);
    return 'tel:+'+n;
  }
  if(p.input_kind==='handle'&&!value.includes('://')) {
    const handle=value.replace(/^@/,'');
    const pattern=key==='telegram'?/^[A-Za-z][A-Za-z0-9_]{3,31}$/:/^[A-Za-z0-9._]{1,30}$/;
    if(!pattern.test(handle))throw pageError('invalid_provider_destination');
    return (key==='telegram'?'https://t.me/':'https://www.instagram.com/')+handle;
  }
  let url;try{url=new URL(value);}catch{throw pageError('invalid_provider_destination');}
  if(key==='viber'&&url.protocol==='viber:'&&url.hostname==='chat'&&!url.pathname
    &&!url.hash&&!url.username&&!url.password&&[...url.searchParams.keys()].length===1
    &&url.searchParams.has('number'))return 'viber://chat?number='+encodeURIComponent('+'+phone(url.searchParams.get('number')));
  if(url.protocol!=='https:'||url.username||url.password||url.hash||(url.port&&url.port!=='443')
    ||!p.hosts.some(host=>url.hostname===host||(p.page_type==='order'&&url.hostname.endsWith('.'+host)))
    ||/%(?:00|0a|0d|3c|3e|5c)/i.test(value))throw pageError('invalid_provider_destination');
  if(key==='whatsapp') {
    if(url.hostname==='wa.me'&&/^\/[1-9]\d{7,14}\/?$/.test(url.pathname)
      &&[...url.searchParams.keys()].every(k=>k==='text'))return url.href;
    if(url.hostname==='api.whatsapp.com'&&url.pathname==='/send'
      &&[...url.searchParams.keys()].every(k=>['phone','text'].includes(k)))
      return 'https://wa.me/'+phone(url.searchParams.get('phone')||'')+(url.searchParams.has('text')?'?text='+encodeURIComponent(url.searchParams.get('text')):'');
    throw pageError('invalid_provider_destination');
  }
  if(key==='telegram'||key==='instagram') {
    if(url.search||!/^\/[A-Za-z0-9._]+\/?$/.test(url.pathname))throw pageError('invalid_provider_destination');
    return providerDestination(key,url.pathname.replaceAll('/',''));
  }
  if(key==='google_play'){
    const id=url.searchParams.get('id');
    if(!/^\/store\/apps\/details\/?$/.test(url.pathname)
      ||! /^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$/.test(id||'')
      ||[...url.searchParams.keys()].some(k=>!['id','hl','gl'].includes(k))
      ||new Set(url.searchParams.keys()).size!==[...url.searchParams.keys()].length)throw pageError('invalid_provider_destination');
    const canonical=new URL('https://play.google.com/store/apps/details');canonical.searchParams.set('id',id);
    for(const key of ['hl','gl'])if(url.searchParams.has(key)){
      const value=url.searchParams.get(key);if(!/^[A-Za-z_-]{2,20}$/.test(value))throw pageError('invalid_provider_destination');canonical.searchParams.set(key,value);
    }
    return canonical.href;
  }
  if(key==='app_store'){
    if(!/^\/(?:[a-z]{2}\/)?app\/(?:[^/]+\/)?id[1-9]\d*\/?$/.test(url.pathname)
      ||[...url.searchParams.keys()].some(k=>!['mt','l','platform','ct','pt'].includes(k))
      ||new Set(url.searchParams.keys()).size!==[...url.searchParams.keys()].length)throw pageError('invalid_provider_destination');
    for(const value of url.searchParams.values())if(!/^[A-Za-z0-9_%.-]+$/.test(value))throw pageError('invalid_provider_destination');
  }
  if(p.page_type==='order'&&url.pathname==='/')throw pageError('invalid_provider_destination');
  return url.href;
}
export function normalizeSettings(kind,settings,{allowEmpty=false,allowStoredProviders=false,legacyProviders=[]}={}) {
  if(!PAGE_TYPES.includes(kind)||!settings||typeof settings!=='object'||Array.isArray(settings)
    ||Object.keys(settings).some(k=>k!=='providers')||!Array.isArray(settings.providers)
    ||settings.providers.length>12)throw pageError('invalid_page_settings');
  const seen=new Set(),orders=new Set();
  const providers=settings.providers.map(item=>{
    if(!item||typeof item!=='object'||Array.isArray(item)
      ||Object.keys(item).some(k=>!['provider_key','destination_url','enabled','sort_order'].includes(k))
      ||!Object.hasOwn(PROVIDER_REGISTRY,item.provider_key)||PROVIDER_REGISTRY[item.provider_key].page_type!==kind
      ||(!AUTHORING_PROVIDERS[kind].includes(item.provider_key) && !allowStoredProviders &&
        !legacyProviders.some(old=>old.provider_key===item.provider_key &&
          old.destination_url===item.destination_url && old.enabled===item.enabled && old.sort_order===item.sort_order))
      ||seen.has(item.provider_key)||typeof item.enabled!=='boolean'||!Number.isInteger(item.sort_order)
      ||item.sort_order<0||item.sort_order>100||orders.has(item.sort_order))throw pageError('invalid_page_settings');
    seen.add(item.provider_key);orders.add(item.sort_order);
    return {provider_key:item.provider_key,destination_url:providerDestination(item.provider_key,item.destination_url),
      enabled:item.enabled,sort_order:item.sort_order};
  }).sort((a,b)=>a.sort_order-b.sort_order);
  if(!allowEmpty&&!providers.some(p=>p.enabled))throw pageError('provider_required');
  return {providers};
}
export function assertAvatar(card) {
  if(!card.avatar_path)return;
  const namespaces=[card.id,card.page_kind?card.client_request_id:null].filter(id=>UUID.test(id||''));
  if(typeof card.avatar_path!=='string'||!namespaces.some(id=>{
    const prefix=card.user_id+'/'+id+'/';
    return card.avatar_path.startsWith(prefix)&&/^[a-zA-Z0-9_-]+\.(webp|jpe?g|png)$/i.test(card.avatar_path.slice(prefix.length));
  }))throw pageError('invalid_avatar');
}
export function validatePage(body,owner,{old=null,allowEmpty=false}={}) {
  if(!body||typeof body!=='object'||Array.isArray(body)||Object.keys(body).some(k=>!['client_request_id','page_kind','name','bio','template_key','template_version','color_theme','card_language','avatar_path','settings','expected_updated_at'].includes(k)))throw pageError('invalid_request');
  const kind=body.page_kind??old?.page_kind;
  if(!PAGE_TYPES.includes(kind)||(old&&kind!==old.page_kind))throw pageError('invalid_page_type');
  const card={id:old?.id,user_id:owner,page_kind:kind,
    client_request_id:old?.client_request_id??body.client_request_id,
    name:body.name??old?.name,bio:body.bio??old?.bio??'',tt:'',
    template_key:body.template_key??old?.template_key,template_version:body.template_version??old?.template_version??6,
    color_theme:body.color_theme??old?.color_theme??'purple',card_language:body.card_language??old?.card_language??'ku',
    avatar_path:body.avatar_path===undefined?old?.avatar_path??null:body.avatar_path,
    settings:normalizeSettings(kind,body.settings??old?.settings,{allowEmpty,
      legacyProviders:old?.settings?.providers||[]})};
  if(!UUID.test(card.client_request_id||'')||card.client_request_id===owner)throw pageError('invalid_request');
  if(typeof card.name!=='string'||!card.name.trim()||card.name.length>160)throw pageError('invalid_card_name');
  if(typeof card.bio!=='string'||card.bio.length>2000)throw pageError('invalid_bio');
  if(!PREPARED_DESIGNS.includes(card.template_key)||card.template_version!==PREPARED_VERSION
    ||!['ku','ar','en'].includes(card.card_language)||!['purple','blue','green','red','yellow','cyan','pink','dark'].includes(card.color_theme))throw pageError('invalid_request');
  card.name=card.name.trim();card.bio=card.bio.trim();
  card.platforms=Object.fromEntries(card.settings.providers.filter(p=>p.enabled).map(p=>[LEGACY_PROVIDER_IDS[p.provider_key],p.destination_url]));
  assertAvatar(card);return card;
}
// A feature preview must never write into the production Supabase project.
// Production activation requires a separate approved release removing this gate.
export function assertIsolatedWrites() {
  const url=process.env.PROXO_SUPABASE_URL||'';
  if(process.env.PROXO_V6_WRITE_MODE!=='isolated'||!/^(https:\/\/|http:\/\/127\.0\.0\.1:)/.test(url)
    ||new URL(url).hostname==='cojchkwssmasiejcgvbk.supabase.co')
    throw Object.assign(pageError('isolated_staging_required'),{status:503});
}
