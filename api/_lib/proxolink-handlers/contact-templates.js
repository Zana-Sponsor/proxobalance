import { json, withSecurity } from '../security.js';
import { authenticatedUser, proxoRows, renderedPage, publicPage, unavailable } from '../proxolink.js';
import { makeTemplateToken, templateTokenData } from '../proxolink-preview.js';

export default withSecurity(async (req, res, {user}) => {
  try {
    const key=req.query?.template_key,version=Number(req.query?.version);
    const selected=typeof key==='string'&&['dark','light','classic','pill','card','neon','zoom','banner'].includes(key)&&Number.isInteger(version)&&version>0;
    const rows=await proxoRows('proxolink_templates','&is_active=eq.true&order=template_key.asc,version.desc'+(selected?'&template_key=eq.'+key+'&version=eq.'+version:'&is_catalog_visible=eq.true'),
      'template_key,version,display_name_ckb,display_name_en,requires_avatar,is_active');
    const seen=new Set();
    const templates=rows.filter(row=>!seen.has(row.template_key)&&seen.add(row.template_key))
      .map(row=>({template_key:row.template_key,version:row.version,
        display_name_ckb:row.display_name_ckb,display_name_en:row.display_name_en,
        requires_avatar:row.requires_avatar,is_active:row.is_active,
        preview_path:'/contact-preview?token='+encodeURIComponent(
        makeTemplateToken(user.id,row.template_key,row.version))}));
    return json(res,200,{ok:true,templates,expires_in:300});
  } catch {return json(res,503,{ok:false,error:'templates_unavailable'});}
}, {auth:'required',methods:['GET'],autoLog:false,resolveUser:authenticatedUser});

export async function templatePreview(req,res) {
  if(req.method!=='GET')return unavailable(res);
  const data=templateTokenData(req.query?.token);
  if(!data)return unavailable(res);
  try {
    // A selected real private template, rendered with controlled sample data.
    // This never inserts a card, publishes a link, or writes analytics.
    const card={id:'00000000-0000-4000-8000-000000000001',user_id:data.userId,
      name:'Proxo',bio:'لەڕێگەی دووگمەکانەوە پەیوەندیمان پێوە بکەن.',tt:'proxo_iq',
      template_key:data.key,template_version:data.version,color_theme:'purple',
      card_language:'ku',platforms:{wa:'9647501234567',vb:'9647501234567',
        ig:'proxo_iq',ph:'9647501234567',as:'9647501234567'},demo:true};
    return publicPage(res,await renderedPage(card,{preview:true}));
  } catch {return unavailable(res);}
}
