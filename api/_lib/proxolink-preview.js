import { createHmac, timingSafeEqual, createHash, randomBytes, createCipheriv, createDecipheriv } from 'node:crypto';
import { deflateRawSync, inflateRawSync } from 'node:zlib';
import { validUuid } from './proxolink.js';
import { PAGE_TYPES, pageKind } from './proxolink-pages.js';
function secret() {
  const value=process.env.PROXO_PREVIEW_SIGNING_SECRET||'';
  if(value.length<32)throw Error('preview_not_configured');
  return value;
}
function signature(payload) {
  return createHmac('sha256',secret()).update(payload).digest('base64url');
}
export function makePreviewToken(card) {
  if(!validUuid(card.id)||!validUuid(card.user_id))throw Error('invalid_card');
  const expires=Math.floor(Date.now()/1000)+5*60;
  const payload=Buffer.from(JSON.stringify([
    card.id,card.user_id,expires,...(card.page_kind?[card.page_kind]:[])
  ])).toString('base64url');
  return payload+'.'+signature(payload);
}

const THEMES=new Set(['purple','blue','green','red','yellow','cyan','pink','dark']);
const LANGUAGES=new Set(['ku','ar','en']);
export function makeTemplateToken(userId, key, version, {theme='purple',language='ku',pageType='contact',baseline=false}={}) {
  if(!validUuid(userId)||!/^[a-z][a-z0-9_-]{0,39}$/.test(key)
    ||!Number.isInteger(version)||version<1||!THEMES.has(theme)
    ||!LANGUAGES.has(language)||!PAGE_TYPES.includes(pageType)||typeof baseline!=='boolean')throw Error('invalid_template');
  const payload=Buffer.from(JSON.stringify({kind:'template',userId,key,version,
    theme,language,pageType,baseline,
    expires:Math.floor(Date.now()/1000)+300})).toString('base64url');
  return payload+'.'+signature(payload);
}

export function templateTokenData(token) {
  try {
    if(typeof token!=='string'||token.length>512)return null;
    const [payload,mac,extra]=token.split('.');
    if(!payload||!mac||extra!==undefined)return null;
    const expected=Buffer.from(signature(payload)),actual=Buffer.from(mac);
    if(expected.length!==actual.length||!timingSafeEqual(expected,actual))return null;
    const data=JSON.parse(Buffer.from(payload,'base64url').toString('utf8'));
    if(data.kind!=='template'||!validUuid(data.userId)
      ||!/^[a-z][a-z0-9_-]{0,39}$/.test(data.key)
      ||!Number.isInteger(data.version)||data.version<1
      ||!Number.isInteger(data.expires)||data.expires<Math.floor(Date.now()/1000))return null;
    // Previously issued five-minute capabilities keep their original defaults.
    data.theme??='purple'; data.language??='ku';
    data.pageType??='contact';data.baseline??=false;
    if(!THEMES.has(data.theme)||!LANGUAGES.has(data.language)||!PAGE_TYPES.includes(data.pageType)
      ||typeof data.baseline!=='boolean'||data.expires>Math.floor(Date.now()/1000)+300)return null;
    return data;
  } catch {return null;}
}
export function validPreviewToken(token,card) {
  try {
    if(typeof token!=='string'||token.length>512)return false;
    const [payload,mac,extra]=token.split('.');
    if(!payload||!mac||extra!==undefined)return false;
    const expected=Buffer.from(signature(payload)),actual=Buffer.from(mac);
    if(expected.length!==actual.length||!timingSafeEqual(expected,actual))
      return false;
    const [cardId,userId,expires,type]=JSON.parse(
      Buffer.from(payload,'base64url').toString('utf8')
    );
    return cardId===card.id&&userId===card.user_id
      &&(card.page_kind?type===pageKind(card):type===undefined)
      &&Number.isInteger(expires)&&expires>=Math.floor(Date.now()/1000)
      &&expires<=Math.floor(Date.now()/1000)+300;
  } catch {return false;}
}

// Encrypted bounded form capabilities keep owner/storage paths and unsaved
// customer input out of readable URL payloads. They neither publish nor persist a page.
function formKey(){return createHash('sha256').update('proxolink-v6-form:'+secret()).digest();}
export function makeFormToken(card) {
  const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',formKey(),iv);
  const bytes=deflateRawSync(Buffer.from(JSON.stringify({kind:'form',card,expires:Math.floor(Date.now()/1000)+300})));
  if(bytes.length>40000)throw Error('preview_too_large');
  const encrypted=Buffer.concat([cipher.update(bytes),cipher.final()]);
  return Buffer.concat([iv,cipher.getAuthTag(),encrypted]).toString('base64url');
}
export function formTokenData(token) {
  try {
    if(typeof token!=='string'||token.length>54000||!/^[A-Za-z0-9_-]+$/.test(token))return null;
    const bytes=Buffer.from(token,'base64url');if(bytes.length<29)return null;
    const decipher=createDecipheriv('aes-256-gcm',formKey(),bytes.subarray(0,12));
    decipher.setAuthTag(bytes.subarray(12,28));
    const compressed=Buffer.concat([decipher.update(bytes.subarray(28)),decipher.final()]);
    const data=JSON.parse(inflateRawSync(compressed,{maxOutputLength:65536}).toString('utf8'));
    const now=Math.floor(Date.now()/1000);
    if(data.kind!=='form'||!validUuid(data.card?.user_id)||!PAGE_TYPES.includes(data.card?.page_kind)
      ||!Number.isInteger(data.expires)||data.expires<now||data.expires>now+300)return null;
    return data;
  }catch{return null;}
}
