import { publishAudit } from '../proxolink-audit.js';
import { readJson, json, withSecurity } from '../security.js';
import {
  authenticatedUser, cardById, renderedPage, verifyPublicAvatar,
  activeTemplate, proxoRows, proxoWrite, validUuid
} from '../proxolink.js';

async function renderReady(card) {
  const meta=await activeTemplate(card);
  if(meta.requires_avatar&&!card.avatar_path)
    throw Object.assign(new Error('avatar_required'),{code:'avatar_required'});
  if(card.avatar_path)await verifyPublicAvatar(card.avatar_path);
  await renderedPage(card);
}
async function responseCard(res,id,userId,status=200) {
  const rows=await proxoRows('proxolink_cards',
    '&id=eq.'+id+'&user_id=eq.'+userId+'&limit=1',
    'id,name,status,publish_status');
  const card=rows[0];
  return json(res,status,{ok:true,card:{
    ...card,public_path:card.status==='active'&&card.publish_status==='ready'
      ?'/contact/'+id:null
  }});
}
async function handler(req,res,{user}) {
  if(req.method!=='POST')
    return json(res,405,{ok:false,error:'method_not_allowed'});
  try {
    const body=await readJson(req,4096);
    const id=body?.card_id,action=body?.action;
    if(!validUuid(id)||!['activate','deactivate','retry','delete'].includes(action))
      return json(res,422,{ok:false,error:'invalid_request'});
    const card=await cardById(id);
    if(card.user_id!==user.id)
      return json(res,404,{ok:false,error:'not_found'});
    if(action==='deactivate'||action==='delete') {
      // Conservative: do not break any ad still referring to this card.
      const ads=await proxoRows('pa_ads',
        '&or=(asset_id.eq.'+id+',card_id.eq.'+id+')'+(action==='delete'?'':'&status=not.in.(completed,rejected,cancelled,canceled,failed)')+'&limit=1','id');
      if(ads.length)
        return json(res,409,{ok:false,error:'ad_dependency'});
      if(action==='delete') {
        await proxoWrite('proxolink_cards','DELETE',null,
          'id=eq.'+id+'&user_id=eq.'+user.id,'return=minimal');
        return json(res,200,{ok:true,deleted:id});
      }
      await proxoWrite('proxolink_cards','PATCH',{status:'inactive'},
        'id=eq.'+id+'&user_id=eq.'+user.id,'return=minimal');
      return responseCard(res,id,user.id);
    }
    if(action==='retry'&&card.publish_status==='ready')
      return responseCard(res,id,user.id);
    if(action==='activate'&&card.publish_status==='ready'&&card.status==='active')
      return responseCard(res,id,user.id);
    if(action==='retry'&&card.publish_status!=='failed'
      && !(card.publish_status==='creating'&&Date.now()-Date.parse(card.updated_at)>120000))
      return json(res,409,{ok:false,error:'invalid_status'});
    // Optimistic lease: a concurrent action/edit cannot overwrite this attempt.
    const leased=await proxoWrite('proxolink_cards','PATCH',{publish_status:'creating'},
      'id=eq.'+id+'&user_id=eq.'+user.id+'&updated_at=eq.'+encodeURIComponent(card.updated_at)+'&select=updated_at');
    if(!leased.length)return json(res,409,{ok:false,error:'edit_conflict'});
    const filter='id=eq.'+id+'&user_id=eq.'+user.id+'&updated_at=eq.'+encodeURIComponent(leased[0].updated_at);
    await publishAudit(card,action,'started');
    try {
      await renderReady(card);
      await proxoWrite('proxolink_cards','PATCH',{
        status:'active',publish_status:'ready',
        last_publish_error_code:null,last_publish_error_at:null,
        published_at:card.published_at||new Date().toISOString()
      },filter,'return=minimal');
      await publishAudit(card,action,'success');
      return responseCard(res,id,user.id);
    } catch(error) {
      await proxoWrite('proxolink_cards','PATCH',{
        status:'inactive',publish_status:'failed',
        last_publish_error_code:String(error?.code||'render_failed').slice(0,80),
        last_publish_error_at:new Date().toISOString()
      },filter,'return=minimal');
      await publishAudit(card,action,'failed',error?.code||'render_failed');
      return json(res,422,{ok:false,error:'publish_failed',card_id:id});
    }
  } catch {
    return json(res,503,{ok:false,error:'backend_unavailable'});
  }
}

export default withSecurity(handler, {auth:'required', methods:['POST'],autoLog:false,resolveUser:authenticatedUser});
