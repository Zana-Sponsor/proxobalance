import { publishAudit } from '../proxolink-audit.js';
import { readJson, json, withSecurity } from '../security.js';
import { createHash } from 'node:crypto';
import {
  authenticatedUser, cardById, activeTemplate, renderedPage,
  validateCardData, normalizedPlatforms, verifyPublicAvatar, proxoRows, proxoWrite, validUuid
} from '../proxolink.js';

const STYLES=new Set(['dark','light','classic','pill','card','neon','zoom','banner']);
const THEMES=new Set(['purple','blue','green','red','yellow','cyan','pink','dark']);
const PLATFORMS=new Set(['wa','vb','tg','ig','ph','as']);
function failure(res,error) {
  if(error?.status===413)return json(res,413,{ok:false,error:'payload_too_large'});
  if(error instanceof SyntaxError)return json(res,422,{ok:false,error:'invalid_request'});
  const code=['unauthorized','invalid_request','invalid_card_name','invalid_bio',
    'invalid_platform_value','invalid_avatar','avatar_required',
    'template_not_found','template_invalid','forbidden'].includes(error?.code)
      ?error.code:'backend_unavailable';
  const status=code==='unauthorized'?401:
    code==='forbidden'?403:
    code==='backend_unavailable'?503:422;
  return json(res,status,{ok:false,error:code});
}
function validatePayload(body,userId,id,old=null) {
  const data={
    id, user_id:userId,
    name:body.name===undefined?old?.name:String(body.name||'').trim(),
    bio:body.bio===undefined?(old?.bio||''):String(body.bio||'').trim(),
    tt:body.tt===undefined?(old?.tt||old?.tiktok||''):
      String(body.tt||'').trim().replace(/^@/,''),
    template_key:body.template_key===undefined
      ?(old?.template_key||old?.style):body.template_key,
    template_version:body.template_version===undefined
      ?(old?.template_version||1):body.template_version,
    color_theme:body.color_theme===undefined?(old?.color_theme||'purple'):body.color_theme,
    card_language:body.card_language===undefined?(old?.card_language||'ku'):body.card_language,
    avatar_path:body.avatar_path===undefined?(old?.avatar_path||null):body.avatar_path,
    platforms:body.platforms===undefined?(old?.platforms||{}):body.platforms
  };
  if(!STYLES.has(data.template_key)
    ||!Number.isInteger(data.template_version)||data.template_version<1
    ||!THEMES.has(data.color_theme)||!['ku','ar','en'].includes(data.card_language))
    throw Object.assign(new Error('invalid_request'),{code:'invalid_request'});
  if(typeof data.tt!=='string')
    throw Object.assign(new Error('invalid_request'),{code:'invalid_request'});
  data.platforms=normalizedPlatforms(data.platforms);
  if(data.avatar_path) {
    const expected=userId+'/'+id+'/';
    if(typeof data.avatar_path!=='string'
      ||!data.avatar_path.startsWith(expected)
      ||!/^[a-zA-Z0-9_-]+\.(webp|jpe?g|png)$/i.test(data.avatar_path.slice(expected.length)))
      throw Object.assign(new Error('invalid_avatar'),{code:'invalid_avatar'});
  }
  validateCardData(data,{legacy:old?.template_version>=1000
    && data.template_key===old.template_key && data.template_version===old.template_version});
  return data;
}
async function readiness(data,{allowLegacy=false}={}) {
  const meta=await activeTemplate(data);
  if(meta.is_catalog_visible===false&&!allowLegacy)throw Object.assign(new Error('invalid_request'),{code:'invalid_request'});
  if(meta.requires_avatar&&!data.avatar_path)
    throw Object.assign(new Error('avatar_required'),{code:'avatar_required'});
  if(data.avatar_path)await verifyPublicAvatar(data.avatar_path);
  await renderedPage(data);
}
const publicCard=(card)=>({
  id:card.id,name:card.name,status:card.status,
  publish_status:card.publish_status,
  public_path:card.status==='active'&&card.publish_status==='ready'
    ?'/contact/'+card.id:null
});
async function create(req,res,userId,body) {
  // One client-generated UUID is also the idempotency key and avatar folder ID.
  // The owner always comes from the verified Proxo JWT, not request JSON.
  const id=body.client_request_id;
  if(!validUuid(id)||body.id && body.id!==id)
    return json(res,422,{ok:false,error:'invalid_request'});
  const data=validatePayload(body,userId,id);
  const hash=createHash('sha256').update(JSON.stringify({...data,
    platforms:Object.fromEntries(Object.entries(data.platforms).sort())})).digest('hex');
  const existing=await proxoRows('proxolink_cards',
    '&id=eq.'+id+'&limit=1',
    'id,user_id,name,status,publish_status,creation_request_hash');
  if(existing.length) {
    if(existing[0].user_id!==userId)
      return json(res,409,{ok:false,error:'invalid_request'});
    if(existing[0].creation_request_hash!==hash)
      return json(res,409,{ok:false,error:'idempotency_conflict'});
    return json(res,200,{ok:true,card:publicCard(existing[0]),reused:true});
  }
  let card;
  try {
    const inserted=await proxoWrite('proxolink_cards','POST',{
      ...data,style:data.template_key,tiktok:data.tt,
      status:'inactive',publish_status:'creating',
      client_request_id:id,creation_request_hash:hash
    },'select=id,user_id,name,status,publish_status,updated_at');
    card=inserted[0];
  } catch(error) {
    // Concurrent duplicate POST: re-read the exact same idempotency key.
    const rows=await proxoRows('proxolink_cards',
      '&id=eq.'+id+'&user_id=eq.'+userId+'&limit=1',
      'id,user_id,name,status,publish_status,creation_request_hash');
    if(rows.length) {
      if(rows[0].creation_request_hash!==hash)
        return json(res,409,{ok:false,error:'idempotency_conflict'});
      return json(res,200,{ok:true,card:publicCard(rows[0]),reused:true});
    }
    throw error;
  }
  await publishAudit(data,'create','started');
  try {
    await readiness(data);
    const updated=await proxoWrite('proxolink_cards','PATCH',{
      publish_status:'ready',status:'active',
      last_publish_error_code:null,last_publish_error_at:null,
      published_at:new Date().toISOString()
    },'id=eq.'+id+'&user_id=eq.'+userId+'&updated_at=eq.'+encodeURIComponent(card.updated_at)+'&select=id,user_id,name,status,publish_status');
    if(!updated.length)return json(res,200,{ok:true,card:publicCard(await cardById(id)),reused:true});
    await publishAudit(data,'create','success');
    return json(res,201,{ok:true,card:publicCard(updated[0])});
  } catch(error) {
    const failed=await proxoWrite('proxolink_cards','PATCH',{
      publish_status:'failed',status:'inactive',
      last_publish_error_code:String(error?.code||'render_failed').slice(0,80),
      last_publish_error_at:new Date().toISOString()
    },'id=eq.'+id+'&user_id=eq.'+userId+'&updated_at=eq.'+encodeURIComponent(card.updated_at)+'&select=id,user_id,name,status,publish_status');
    if(!failed.length)return json(res,200,{ok:true,card:publicCard(await cardById(id)),reused:true});
    await publishAudit(data,'create','failed',error?.code||'render_failed');
    return json(res,422,{ok:false,error:'publish_failed',
      card:publicCard(failed[0])});
  }
}
async function edit(req,res,userId,body,id) {
  if(!validUuid(id))return json(res,422,{ok:false,error:'invalid_request'});
  const current=await cardById(id);
  if(current.user_id!==userId)
    return json(res,403,{ok:false,error:'forbidden'});
  const proposed=validatePayload(body,userId,id,current);
  if(Date.parse(body.expected_updated_at)!==Date.parse(current.updated_at))
    return json(res,409,{ok:false,error:'edit_conflict'});
  // Render in memory BEFORE changing a currently published card.
  await readiness(proposed,{allowLegacy:proposed.template_key===current.template_key&&proposed.template_version===current.template_version});
  const fields={
    name:proposed.name,bio:proposed.bio,tt:proposed.tt,tiktok:proposed.tt,
    style:proposed.template_key,template_key:proposed.template_key,
    template_version:proposed.template_version,
    color_theme:proposed.color_theme,card_language:proposed.card_language,
    avatar_path:proposed.avatar_path,platforms:proposed.platforms,
    publish_status:'ready',last_publish_error_code:null,
    last_publish_error_at:null,updated_at:new Date().toISOString()
  };
  // Keep an intentionally inactive card inactive; editing must not expose it.
  const updated=await proxoWrite('proxolink_cards','PATCH',fields,
    'id=eq.'+id+'&user_id=eq.'+userId+'&updated_at=eq.'+encodeURIComponent(current.updated_at)
      +'&select=id,user_id,name,status,publish_status');
  if(!updated.length)return json(res,409,{ok:false,error:'edit_conflict'});
  await publishAudit(proposed,'edit_publish','success');
  return json(res,200,{ok:true,card:publicCard(updated[0])});
}
async function handler(req,res,{user}) {
  if(!['POST','PATCH','GET'].includes(req.method))
    return json(res,405,{ok:false,error:'method_not_allowed'});
  try {
    if(req.method==='GET') {
      const cards=await proxoRows('proxolink_cards','&user_id=eq.'+user.id+'&order=created_at.desc',
        'id,user_id,name,bio,tt,platforms,template_key,template_version,style,color_theme,card_language,avatar_path,status,publish_status,card_number,created_at,updated_at');
      return json(res,200,{ok:true,cards});
    }
    const body=await readJson(req,64*1024);
    if(!body||typeof body!=='object'||Array.isArray(body))
      return json(res,422,{ok:false,error:'invalid_request'});
    if(req.method==='POST')return await create(req,res,user.id,body);
    return await edit(req,res,user.id,body,
      typeof req.query?.id==='string'?req.query.id:'');
  } catch(error) {return failure(res,error);}
}

export default withSecurity(handler, {auth:'required', methods:['POST','PATCH','GET'],autoLog:false,resolveUser:authenticatedUser});
