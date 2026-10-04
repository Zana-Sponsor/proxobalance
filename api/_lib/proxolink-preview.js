import { createHmac, timingSafeEqual } from 'node:crypto';
import { validUuid } from './proxolink.js';
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
    card.id,card.user_id,expires
  ])).toString('base64url');
  return payload+'.'+signature(payload);
}

export function makeTemplateToken(userId, key, version) {
  if(!validUuid(userId)||!/^[a-z][a-z0-9_-]{0,39}$/.test(key)
    ||!Number.isInteger(version)||version<1)throw Error('invalid_template');
  const payload=Buffer.from(JSON.stringify({kind:'template',userId,key,version,
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
    const [cardId,userId,expires]=JSON.parse(
      Buffer.from(payload,'base64url').toString('utf8')
    );
    return cardId===card.id&&userId===card.user_id
      &&Number.isInteger(expires)&&expires>=Math.floor(Date.now()/1000);
  } catch {return false;}
}
