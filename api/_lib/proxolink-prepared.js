import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { PREPARED_DESIGNS, PREPARED_VERSION, DESIGN_ALIASES, PROVIDER_REGISTRY,
  LEGACY_PROVIDER_IDS, normalizeSettings, providerDestination, pageError } from './proxolink-pages.js';
// Literal paths are traced into the private function bundle by Vercel.
const sources={
  pill:()=>readFile(new URL('./proxolink-templates/pill.html',import.meta.url),'utf8'),
  'pill-mint':()=>readFile(new URL('./proxolink-templates/pill-mint.html',import.meta.url),'utf8'),
  'pill-dark':()=>readFile(new URL('./proxolink-templates/pill-dark.html',import.meta.url),'utf8'),
  'pill-white':()=>readFile(new URL('./proxolink-templates/pill-white.html',import.meta.url),'utf8'),
};
const baselineSources={
  pill:()=>readFile(new URL('./proxolink-native-baseline/pill.html',import.meta.url),'utf8'),
  'pill-mint':()=>readFile(new URL('./proxolink-native-baseline/pill-mint.html',import.meta.url),'utf8'),
  'pill-dark':()=>readFile(new URL('./proxolink-native-baseline/pill-dark.html',import.meta.url),'utf8'),
  'pill-white':()=>readFile(new URL('./proxolink-native-baseline/pill-white.html',import.meta.url),'utf8'),
};
export async function nativeBaselineSource(key) {
  if(!PREPARED_DESIGNS.includes(key))throw pageError('template_not_found');
  const manifest=JSON.parse(await readFile(new URL('./proxolink-native-baseline/manifest.json',import.meta.url),'utf8'));
  const raw=await baselineSources[key]();
  if(createHash('sha256').update(raw).digest('hex')!==manifest.sha256[key])throw pageError('template_invalid');
  return raw;
}
const names=['کەپسول','سەوز','تاریک','سپی'];
export async function preparedMetadata(key) {
  if(!PREPARED_DESIGNS.includes(key))throw pageError('template_not_found');
  const raw=await sources[key]();
  return {template_key:key,version:PREPARED_VERSION,display_name_ckb:names[PREPARED_DESIGNS.indexOf(key)],
    display_name_en:key,storage_path:key+'/v6/template.html',
    checksum_sha256:createHash('sha256').update(raw).digest('hex'),requires_avatar:false,
    is_active:true,is_catalog_visible:true,renderer_variant:'prepared_v6'};
}
export async function preparedSource(meta) {
  if(!PREPARED_DESIGNS.includes(meta.template_key)||meta.version!==6
    ||meta.storage_path!==meta.template_key+'/v6/template.html')throw pageError('template_invalid');
  const raw=await sources[meta.template_key]();
  if(raw.length>1500000||!raw.includes('{{PROXO_CONFIG}}')
    ||createHash('sha256').update(raw).digest('hex')!==meta.checksum_sha256)throw pageError('template_invalid');
  return raw;
}
export const encodeConfig=value=>JSON.stringify(value).replaceAll('<','\\u003c').replaceAll('>','\\u003e')
  .replaceAll('&','\\u0026').replace(/\u2028/g,'\\u2028').replace(/\u2029/g,'\\u2029');
const labels={whatsapp:['واتسئاپ','واتساب','WhatsApp'],viber:['ڤایبەر','فايبر','Viber'],
  instagram:['ئینستاگرام','إنستغرام','Instagram'],telegram:['تیلیگرام','تيليجرام','Telegram'],
  korek:['کۆڕەک','كورك','Korek'],asiacell:['ئاسیاسێڵ','آسيا سيل','Asiacell'],
  talabat:['تەڵەبات','طلبات','Talabat'],toters:['توتەرز','توترز','Toters'],
  lezzoo:['لەزوو','ليزو','Lezzoo'],wade:['وادێ','وادي','WADE']};
export function preparedConfig(card,{preview=false,publicAvatarUrl=null}={}) {
  let providers;
  if(card.page_kind)providers=normalizeSettings(card.page_kind,card.settings,{allowEmpty:preview,allowStoredProviders:true}).providers;
  else providers=Object.entries(card.platforms||{}).flatMap(([id,raw],i)=>{
    const key=Object.keys(LEGACY_PROVIDER_IDS).find(k=>LEGACY_PROVIDER_IDS[k]===id)||id;
    if(!Object.hasOwn(PROVIDER_REGISTRY,key))return [];
    return [{provider_key:key,destination_url:providerDestination(key,raw),enabled:true,sort_order:i}];
  });
  const index=card.card_language==='en'?2:card.card_language==='ar'?1:0;
  const tt=String(card.tt||card.tiktok||'').replace(/^@/,'');
  const config={template:DESIGN_ALIASES[card.template_key||card.style]||card.template_key||card.style,
    preview:preview||card.demo===true,name:card.name,bio:card.bio||'',lang:card.card_language||'ku',
    direction:card.card_language==='en'?'ltr':'rtl',avatarUrl:publicAvatarUrl||'',
    tiktokUrl:!card.page_kind&&/^[A-Za-z0-9._]{1,40}$/.test(tt)?'https://www.tiktok.com/@'+encodeURIComponent(tt):'',
    tiktokLabel:tt?'@'+tt:'',buttons:providers.filter(p=>p.enabled).map(p=>({type:p.provider_key,
      url:p.destination_url,...(labels[p.provider_key]?{label:labels[p.provider_key][index]}:{}),enabled:true}))};
  // Page UUIDs and owner/storage UUIDs are deliberately absent from the public config.
  return config;
}
export function renderPrepared(template,card,options={}) {
  const config=preparedConfig(card,options);
  const result=template.replace('{{PROXO_CONFIG}}',()=>encodeConfig(config));
  if(result.includes('{{PROXO_CONFIG}}'))throw pageError('template_invalid');
  return result;
}
