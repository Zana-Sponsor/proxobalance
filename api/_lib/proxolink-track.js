import { realClientIp } from './security.js';
import {
  proxoRows, proxoWrite, cardById, contactDestination, normalizedPlatforms
} from './proxolink.js';

const TOKEN_PATTERN=/^[A-Za-z0-9_-]{20,128}$/;
export const PLATFORM_TYPE={
  wa:'whatsapp',vb:'viber',tg:'telegram',
  ig:'instagram',ph:'phone',as:'phone'
};
export async function trackedContext(token) {
  if(!TOKEN_PATTERN.test(String(token||'')))throw Error('invalid_token');
  const links=await proxoRows('pa_ad_contact_links',
    '&public_token=eq.'+encodeURIComponent(token)+'&is_current=eq.true&status=eq.active&limit=1',
    'id,ad_id,card_id,owner_user_id,public_token');
  if(links.length!==1)throw Error('link_not_found');
  const link=links[0];
  const ads=await proxoRows('pa_ads','&id=eq.'+link.ad_id+'&limit=1',
    'id,user_id,asset_id,goal,status');
  if(ads.length!==1)throw Error('ad_not_found');
  const ad=ads[0], card=await cardById(link.card_id);
  if(ad.id!==link.ad_id || ad.asset_id!==link.card_id
    || ad.user_id!==link.owner_user_id
    || card.id!==link.card_id || card.user_id!==link.owner_user_id
    || card.status!=='active' || card.publish_status!=='ready')
    throw Error('invalid_link_relationship');
  return {link,ad,card};
}
export async function recordContactEvent(req,linkId,type,platformId=null) {
  if(!['page_view','button_click'].includes(type)
    || (type==='button_click'&&!PLATFORM_TYPE[platformId]))
    throw Error('invalid_event');
  const ip=realClientIp(req);
  const record={
    ad_contact_link_id:linkId,
    event_type:type,
    button_type:type==='button_click'?PLATFORM_TYPE[platformId]:null,
    ip_address:ip,
    user_agent:String(req.headers?.['user-agent']||'').slice(0,800),
    referrer:String(req.headers?.referer||'').slice(0,500),
    request_path:String(req.url||'').slice(0,300)
  };
  await proxoWrite('pa_contact_events','POST',record,'','return=minimal');
}
export function actionUrl(card,id) {
  const platforms=normalizedPlatforms(card.platforms);
  if(!Object.prototype.hasOwnProperty.call(PLATFORM_TYPE,id)
    || !Object.prototype.hasOwnProperty.call(platforms,id))
    throw Error('invalid_button');
  // The destination is always constructed server-side from trusted card data.
  return contactDestination(id,platforms[id]);
}
