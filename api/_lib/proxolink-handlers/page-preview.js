import { json, readJson, withSecurity } from '../security.js';
import { authenticatedUser, cardById, renderedPage, publicPage, unavailable, avatarBytes } from '../proxolink.js';
import { validatePage, assertAvatar, UUID } from '../proxolink-pages.js';
import { makeFormToken, formTokenData } from '../proxolink-preview.js';
export const createFormPreview=withSecurity(async(req,res,{user})=>{
  try {
    const body=await readJson(req,65536);
    if(!body||typeof body!=='object'||Array.isArray(body))return json(res,422,{ok:false,error:'invalid_request'});
    const {card_id,...fields}=body;
    let old=null;
    if(card_id!==undefined){
      if(!UUID.test(card_id))return json(res,422,{ok:false,error:'invalid_request'});
      old=await cardById(card_id);
      if(old.user_id!==user.id||old.archived_at)return json(res,404,{ok:false,error:'not_found'});
    }
    const card=validatePage(fields,user.id,{old,allowEmpty:true});
    card.id??='00000000-0000-4000-8000-000000000001';
    return json(res,200,{ok:true,preview_path:'/page-preview?token='+makeFormToken(card),expires_in:300});
  }catch(error){
    const allowed=['invalid_request','invalid_page_type','invalid_page_settings','invalid_provider_destination',
      'invalid_card_name','invalid_bio','invalid_avatar'];
    return json(res,allowed.includes(error.code)?422:503,{ok:false,error:allowed.includes(error.code)?error.code:'preview_unavailable'});
  }
},{auth:'required',methods:['POST'],autoLog:false,resolveUser:authenticatedUser});
export async function renderFormPreview(req,res) {
  if(req.method!=='GET')return unavailable(res);
  const data=formTokenData(req.query?.token);if(!data)return unavailable(res);
  try {
    const html=await renderedPage({...data.card,demo:true},{preview:true,
      publicAvatarUrl:data.card.avatar_path?'/page-preview-avatar?token='+req.query.token:null});
    return publicPage(res,html);
  }catch{return unavailable(res);}
}
export async function formPreviewAvatar(req,res) {
  if(req.method!=='GET')return unavailable(res);
  const data=formTokenData(req.query?.token);if(!data)return unavailable(res);
  try {
    assertAvatar(data.card);
    const {data:bytes,mime}=await avatarBytes(data.card.avatar_path);
    res.statusCode=200;res.setHeader('Content-Type',mime);res.setHeader('Cache-Control','no-store');
    res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
    return res.end(Buffer.from(bytes));
  }catch{return unavailable(res);}
}
