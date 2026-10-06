import { randomBytes } from 'node:crypto';
import { readJson, json, withSecurity } from '../security.js';
import { authenticatedUser, validUuid, proxoWrite } from '../proxolink.js';

async function handler(req,res,{user}) {
  if(req.method!=='POST')
    return json(res,405,{ok:false,error:'method_not_allowed'});
  try {
    const body=await readJson(req,1024);
    if(!validUuid(body?.ad_id))
      return json(res,422,{ok:false,error:'invalid_ad'});
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
