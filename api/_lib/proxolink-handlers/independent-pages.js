import { createHash } from 'node:crypto';
import { json } from '../security.js';
import { cardById, cardRows, proxoWrite, renderedPage, verifyPublicAvatar } from '../proxolink.js';
import { validatePage, assertIsolatedWrites, publicPath } from '../proxolink-pages.js';
import { publishAudit } from '../proxolink-audit.js';
const managementColumns='id,user_id,name,bio,tt,page_kind,client_request_id,settings,platforms,template_key,template_version,color_theme,card_language,avatar_path,status,publish_status,moderation_status,card_number,created_at,updated_at';
// Authenticated owner response only; never returned by a public renderer.
const safeCard=card=>({...Object.fromEntries(managementColumns.split(',').map(key=>[key,card[key]])),
  public_path:!card.archived_at&&card.status==='active'&&card.publish_status==='ready'?publicPath(card):null});
async function ready(card) {
  if(card.avatar_path)await verifyPublicAvatar(card.avatar_path);
  await renderedPage(card);
}
export async function createPage(res,owner,body) {
  const data=validatePage(body,owner);
  assertIsolatedWrites();
  const hash=createHash('sha256').update(JSON.stringify(data)).digest('hex');
  const filter='&user_id=eq.'+owner+'&client_request_id=eq.'+data.client_request_id+'&limit=1';
  const find=()=>cardRows(filter,managementColumns+',creation_request_hash');
  const reused=rows=>rows[0].creation_request_hash===hash
    ?json(res,200,{ok:true,card:safeCard(rows[0]),reused:true})
    :json(res,409,{ok:false,error:'idempotency_conflict'});
  const previous=await find();if(previous.length)return reused(previous);
  let inserted;
  try {
    // id is omitted: the database generates a fresh page UUID. The separate
    // request UUID is only an owner-scoped idempotency key / upload namespace.
    const {id,...fields}=data;
    inserted=(await proxoWrite('proxolink_cards','POST',{
      ...fields,page_type:data.page_kind==='order'?'food':data.page_kind,
      style:data.template_key,tiktok:data.tt,status:'inactive',publish_status:'creating',creation_request_hash:hash,
    },'select=id,user_id,name,page_kind,status,publish_status,updated_at'))[0];
    if(!inserted?.id||inserted.id===owner||inserted.id===data.client_request_id)throw Error('invalid_generated_id');
  } catch(error) {
    if(error.databaseCode==='23505') {
      const duplicate=await find();if(duplicate.length)return reused(duplicate);
    }
    throw error;
  }
  const card={...data,...inserted};
  const filterWrite='id=eq.'+card.id+'&user_id=eq.'+owner+'&updated_at=eq.'+encodeURIComponent(card.updated_at);
  await publishAudit(card,'create','started');
  try {
    await ready(card);
    const published=await proxoWrite('proxolink_cards','PATCH',{
      publish_status:'ready',status:'active',last_publish_error_code:null,last_publish_error_at:null,
      published_at:new Date().toISOString(),updated_at:new Date().toISOString(),
    },filterWrite+'&select='+managementColumns);
    if(!published.length)return json(res,409,{ok:false,error:'edit_conflict'});
    await publishAudit(card,'create','success');
    return json(res,201,{ok:true,card:safeCard(published[0])});
  } catch(error) {
    const failed=await proxoWrite('proxolink_cards','PATCH',{
      publish_status:'failed',status:'inactive',last_publish_error_code:'render_failed',last_publish_error_at:new Date().toISOString(),
    },filterWrite+'&select='+managementColumns);
    await publishAudit(card,'create','failed','render_failed');
    return json(res,422,{ok:false,error:'publish_failed',card:safeCard(failed[0]||card)});
  }
}
export async function editPage(res,owner,body,current) {
  if(current.user_id!==owner)return json(res,404,{ok:false,error:'not_found'});
  if(current.archived_at)return json(res,409,{ok:false,error:'page_archived'});
  const data=validatePage(body,owner,{old:current});
  assertIsolatedWrites();
  if(!Number.isFinite(Date.parse(body.expected_updated_at))
    ||Date.parse(body.expected_updated_at)!==Date.parse(current.updated_at))return json(res,409,{ok:false,error:'edit_conflict'});
  await ready(data); // Preserve a currently published document on failure.
  const {id,user_id,page_kind,client_request_id,...fields}=data;
  const updated=await proxoWrite('proxolink_cards','PATCH',{
    ...fields,style:data.template_key,publish_status:'ready',last_publish_error_code:null,
    last_publish_error_at:null,updated_at:new Date().toISOString(),
  },'id=eq.'+id+'&user_id=eq.'+owner+'&updated_at=eq.'+encodeURIComponent(current.updated_at)
    +'&select='+managementColumns);
  if(!updated.length)return json(res,409,{ok:false,error:'edit_conflict'});
  await publishAudit(data,'edit_publish','success');
  return json(res,200,{ok:true,card:safeCard(updated[0])});
}
export async function deletePage(res,owner,card) {
  assertIsolatedWrites();
  const rows=await proxoWrite('proxolink_cards','DELETE',null,
    'id=eq.'+card.id+'&user_id=eq.'+owner+'&updated_at=eq.'+encodeURIComponent(card.updated_at)+'&select=id');
  if(!rows.length)return json(res,409,{ok:false,error:'edit_conflict'});
  return json(res,200,{ok:true,deleted:card.id});
}
