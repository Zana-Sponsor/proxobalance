import { randomBytes } from 'node:crypto';
import { readJson, json, withSecurity } from '../security.js';
import { authenticatedUser, validUuid, proxoRows, proxoWrite, cardById } from '../proxolink.js';
import { publicPath } from '../proxolink-pages.js';

async function handler(req,res,{user}) {
  if(req.method!=='POST')
    return json(res,405,{ok:false,error:'method_not_allowed'});
  try {
    const body=await readJson(req,1024);
    if(!validUuid(body?.ad_id))
      return json(res,422,{ok:false,error:'invalid_ad'});
    const ads=await proxoRows('pa_ads','&id=eq.'+body.ad_id+'&user_id=eq.'+user.id+'&limit=1',
      'id,user_id,asset_id,card_id,status');
    if(ads.length!==1||ads[0].user_id!==user.id)throw Error('ad_unavailable');
    const ad=ads[0],pageId=ad.asset_id||ad.card_id;
    if(!validUuid(pageId))throw Error('page_unavailable');
    const card=await cardById(pageId);
    if(card.user_id!==user.id)throw Error('page_unavailable');
    if(card.page_kind){
      if(card.archived_at||card.status!=='active'||card.publish_status!=='ready'
        ||['completed','rejected','cancelled','canceled','failed','inactive','paused'].includes(ad.status))
        throw Error('page_unavailable');
      const path=publicPath(card);
      // Keep the response compatible with existing ad consumers, while V6
      // uses the ordinary page URL without issuing an attribution token.
      return json(res,200,{ok:true,ad_id:ad.id,card_id:card.id,
        public_path:path,tracked_path:path,tracked:false,version:null});
    }
    const rows=await proxoWrite('rpc/proxolink_issue_ad_link','POST',{
      p_ad_id:body.ad_id,
      p_owner_user_id:user.id,
      p_public_token:randomBytes(24).toString('base64url')
    });
    if(!Array.isArray(rows)||rows.length!==1||!rows[0].link_public_token)
      throw Error('missing_link');
    return json(res,200,{
      ok:true,ad_id:rows[0].link_ad_id,card_id:rows[0].link_card_id,
      tracked_path:'/a/'+rows[0].link_public_token,
      version:rows[0].link_version
    });
  } catch {
    return json(res,422,{ok:false,error:'ad_link_unavailable'});
  }
}

export default withSecurity(handler, {auth:'required', methods:['POST'],autoLog:false,resolveUser:authenticatedUser});
