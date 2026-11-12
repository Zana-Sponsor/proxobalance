import { realClientIp, requestContext } from './security.js';
import { randomUUID, createHmac } from 'node:crypto';
import {
  proxoRows, proxoWrite, cardById, contactDestination, normalizedPlatforms
} from './proxolink.js';

const TOKEN_PATTERN=/^[A-Za-z0-9_-]{20,128}$/;
export const PLATFORM_TYPE={
  wa:'whatsapp',vb:'viber',tg:'telegram',talabat:'talabat',lezzoo:'lezzoo',toters:'toters',wade:'wade',app_store:'app_store',google_play:'google_play',
  ig:'instagram',ph:'phone',as:'phone',tt:'tiktok'
};
export async function trackedContext(token) {
  if(!TOKEN_PATTERN.test(String(token||'')))throw Error('invalid_token');
  const links=await proxoRows('pa_ad_contact_links',
    '&public_token=eq.'+encodeURIComponent(token)+'&is_current=eq.true&status=eq.active&limit=1',
    'id,ad_id,card_id,owner_user_id,public_token');
  if(links.length!==1)throw Error('link_not_found');
  const link=links[0];
  const ads=await proxoRows('pa_ads','&id=eq.'+link.ad_id+'&limit=1',
    'id,user_id,asset_id,card_id,goal,status');
  if(ads.length!==1)throw Error('ad_not_found');
  const ad=ads[0], card=await cardById(link.card_id);
  if(ad.id!==link.ad_id || (ad.asset_id||ad.card_id)!==link.card_id
    || ad.user_id!==link.owner_user_id
    || card.id!==link.card_id || card.user_id!==link.owner_user_id
    || card.status!=='active' || card.publish_status!=='ready')
    throw Error('invalid_link_relationship');
  if(['completed','rejected','cancelled','canceled','failed','inactive','paused'].includes(ad.status))
    throw Error('ad_unavailable');
  return {link,ad,card};
}
export async function recordContactEvent(req,res,linkId,type,platformId=null) {
  if(!['page_view','button_click'].includes(type)
    || (type==='button_click'&&!PLATFORM_TYPE[platformId]))
    throw Error('invalid_event');
  const ip=realClientIp(req,{proxyMode:process.env.VERCEL?'vercel':'direct'});
  const context=requestContext(req);
  const cookie=String(req.headers?.cookie||'').match(/(?:^|;\s*)proxo_contact_session=([0-9a-f-]{36})(?:;|$)/i)?.[1];
  const sessionId=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(cookie||'')?cookie:randomUUID();
  if(cookie!==sessionId)res.setHeader('Set-Cookie','proxo_contact_session='+sessionId+'; Path=/a/; Max-Age=2592000; HttpOnly; Secure; SameSite=Lax');
  const salt=process.env.PROXO_ANALYTICS_HASH_SECRET||'';
  const ipHash=ip&&salt.length>=32?createHmac('sha256',salt).update(ip).digest('hex'):null;
  const record={
    ad_contact_link_id:linkId,
    event_type:type,
    button_type:type==='button_click'?PLATFORM_TYPE[platformId]:null,
    ip_address:null,ip_hash:ipHash,session_id:sessionId,
    device_type:context.device,browser:context.browser,os:context.os,
    user_agent:String(req.headers?.['user-agent']||'').slice(0,800),
    referrer:(()=>{try{return new URL(req.headers?.referer||'').origin;}catch{return null;}})(),
    // Store only the validated attribution route. Caller-supplied query
    // strings may contain visitor details and must not enter retained history.
    request_path:TOKEN_PATTERN.test(req.query?.token||'')
      ?'/a/'+req.query.token+(type==='button_click'?'/action/'+platformId:'')
      :null
  };
  await proxoWrite('pa_contact_events','POST',record,'','return=minimal');
}
export function actionUrl(card,id) {
  if(id==='tt'&&(card.template_version>=1000?/^[a-zA-Z0-9._@-]{1,100}$/:/^[a-zA-Z0-9._]{1,40}$/).test(card.tt||card.tiktok||''))
    return 'https://www.tiktok.com/@'+encodeURIComponent(card.tt||card.tiktok);
  const platforms=normalizedPlatforms(card.platforms,{historical:true});
  if(!Object.prototype.hasOwnProperty.call(PLATFORM_TYPE,id)
    || !Object.prototype.hasOwnProperty.call(platforms,id))
    throw Error('invalid_button');
  // The destination is always constructed server-side from trusted card data.
  const destination=contactDestination(id,platforms[id]);
  // WhatsApp's universal link opens the app when installed and provides the
  // supported web fallback otherwise. It retains the validated phone number.
  return destination;
}
