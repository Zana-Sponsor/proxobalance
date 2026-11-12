import { readJson, json, withSecurity } from '../security.js';
import { authenticatedUser, cardById, validUuid } from '../proxolink.js';
import { makePreviewToken } from '../proxolink-preview.js';
async function handler(req,res,{user}) {
  if(req.method!=='POST')return json(res,405,{ok:false,error:'method_not_allowed'});
  try {
    const body=await readJson(req,1024);
    if(!validUuid(body?.card_id))return json(res,422,{ok:false,error:'invalid_card'});
    const card=await cardById(body.card_id);
    if(card.user_id!==user.id)return json(res,404,{ok:false,error:'not_found'});
    if(card.publish_status!=='ready')
      return json(res,409,{ok:false,error:'card_not_ready'});
    return json(res,200,{
      ok:true,preview_path:'/contact/'+card.id+'?preview_token='
        +encodeURIComponent(makePreviewToken(card))
    });
  } catch {return json(res,503,{ok:false,error:'preview_unavailable'});}
}

export default withSecurity(handler, {auth:'required', methods:['POST'],autoLog:false,resolveUser:authenticatedUser});
