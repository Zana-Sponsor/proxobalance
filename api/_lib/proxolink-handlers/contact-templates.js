import { json, withSecurity } from '../security.js';
import { authenticatedUser, renderedPage, publicPage, unavailable } from '../proxolink.js';
import { makeTemplateToken, templateTokenData } from '../proxolink-preview.js';
import { PREPARED_DESIGNS, PREPARED_VERSION, PAGE_TYPES, PROVIDER_REGISTRY, registryMetadata, assertIsolatedWrites } from '../proxolink-pages.js';
import { preparedMetadata } from '../proxolink-prepared.js';
export default withSecurity(async(req,res,{user})=>{
  try {
    const key=req.query?.template_key,version=req.query?.version;
    const theme=req.query?.theme??'purple',language=req.query?.language??'ku',pageType=req.query?.page_type??'contact';
    const baseline=req.query?.baseline==='true';
    if((key!==undefined&&(!PREPARED_DESIGNS.includes(key)||version!==String(PREPARED_VERSION)))
      ||(key===undefined&&version!==undefined)||!PAGE_TYPES.includes(pageType)
      ||!['purple','blue','green','red','yellow','cyan','pink','dark'].includes(theme)
      ||!['ku','ar','en'].includes(language)||(req.query?.baseline!==undefined&&!['true','false'].includes(req.query.baseline)))
      return json(res,422,{ok:false,error:'invalid_request'});
    const templates=await Promise.all((key?[key]:PREPARED_DESIGNS).map(async key=>{
      const meta=await preparedMetadata(key);
      return {template_key:key,version:meta.version,display_name_ckb:meta.display_name_ckb,
        display_name_en:meta.display_name_en,requires_avatar:meta.requires_avatar,is_active:true,
        preview_path:'/contact-preview?token='+encodeURIComponent(makeTemplateToken(user.id,key,meta.version,{theme,language,pageType,baseline}))};
    }));
    return json(res,200,{ok:true,templates,expires_in:300});
  }catch{return json(res,503,{ok:false,error:'templates_unavailable'});}
},{auth:'required',methods:['GET'],autoLog:false,resolveUser:authenticatedUser});
export const providers=withSecurity(async(req,res)=>{let writes_enabled=false;try{assertIsolatedWrites();writes_enabled=true;}catch{}
  return json(res,200,{ok:true,providers:registryMetadata(),page_types:PAGE_TYPES,writes_enabled});},
  {auth:'required',methods:['GET'],autoLog:false,resolveUser:authenticatedUser});
export async function templatePreview(req,res) {
  if(req.method!=='GET')return unavailable(res);
  const data=templateTokenData(req.query?.token);if(!data)return unavailable(res);
  if(!PREPARED_DESIGNS.includes(data.key)||data.version!==6)return unavailable(res);
  try {
    const destinations={whatsapp:'+9647501234567',viber:'+9647501234567',instagram:'proxo_iq',telegram:'proxo_iq',
      korek:'+9647501234567',asiacell:'+9647701234567',talabat:'https://iraq.talabat.com/iraq/restaurant/proxo',
      toters:'https://www.totersapp.com/restaurant/proxo',lezzoo:'https://www.lezzoo.com/restaurant/proxo',
      wade:'https://wadedelivery.com/restaurant/proxo',google_play:'https://play.google.com/store/apps/details?id=com.proxo.app',
      app_store:'https://apps.apple.com/app/proxo/id123456789'};
    const card={id:'00000000-0000-4000-8000-000000000001',client_request_id:'00000000-0000-4000-8000-000000000002',user_id:data.userId,
      page_kind:data.pageType,name:'Proxo',bio:{ku:'لەڕێگەی دووگمەکانەوە پەیوەندیمان پێوە بکەن.',
        ar:'تواصلوا معنا عبر الأزرار أدناه.',en:'Contact us using the buttons below.'}[data.language],
      template_key:data.key,template_version:6,color_theme:data.theme,card_language:data.language,demo:true,
      settings:{providers:Object.entries(PROVIDER_REGISTRY).filter(([,p])=>p.page_type===data.pageType)
        .map(([provider_key],sort_order)=>({provider_key,destination_url:destinations[provider_key],enabled:true,sort_order}))}};
    return publicPage(res,await renderedPage(card,{preview:true,baseline:data.baseline}));
  }catch{return unavailable(res);}
}
