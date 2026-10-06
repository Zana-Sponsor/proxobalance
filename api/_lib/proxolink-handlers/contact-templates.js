import { json, withSecurity } from '../security.js';
import { authenticatedUser, proxoRows, renderedPage, publicPage, unavailable } from '../proxolink.js';
import { makeTemplateToken, templateTokenData } from '../proxolink-preview.js';

import { TEMPLATE_KEYS,TEMPLATE_VERSION } from '../proxolink-catalog.js';
import { PROVIDERS } from '../proxolink-catalog.js';
const ORDER=TEMPLATE_KEYS;
const THEMES=['purple','blue','green','red','yellow','cyan','pink','dark'];
const LANGUAGES=['ku','ar','en'];
export default withSecurity(async (req, res, {user}) => {
  try {
    const key=req.query?.template_key,version=Number(req.query?.version);
    const selected=key!==undefined||req.query?.version!==undefined;
    const theme=req.query?.theme??'purple',language=req.query?.language??'ku',pageType=req.query?.page_type??'contact';
    if((selected&&!(typeof key==='string'&&ORDER.includes(key)
      &&typeof req.query?.version==='string'&&/^[1-9][0-9]*$/.test(req.query.version)
      &&version===TEMPLATE_VERSION))||!THEMES.includes(theme)||!LANGUAGES.includes(language)||!['contact','food','download'].includes(pageType))
      return json(res,422,{ok:false,error:'invalid_request'});
    const rows=await proxoRows('proxolink_templates','&version=eq.'+TEMPLATE_VERSION+'&is_active=eq.true&order=template_key.asc,version.desc'+(selected?'&template_key=eq.'+key+'&version=eq.'+version:'&is_catalog_visible=eq.true'),
      'template_key,version,display_name_ckb,display_name_en,requires_avatar,is_active');
    const seen=new Set();
    const templates=rows.filter(row=>ORDER.includes(row.template_key)
      &&!seen.has(row.template_key)&&seen.add(row.template_key))
      .sort((a,b)=>ORDER.indexOf(a.template_key)-ORDER.indexOf(b.template_key))
      .map(row=>({template_key:row.template_key,version:row.version,
        display_name_ckb:row.display_name_ckb,display_name_en:row.display_name_en,
        requires_avatar:row.requires_avatar,is_active:row.is_active,
        preview_path:'/contact-preview?token='+encodeURIComponent(
        makeTemplateToken(user.id,row.template_key,row.version,{theme,language,pageType}))}));
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
      name:'Proxo',bio:{ku:'لەڕێگەی دووگمەکانەوە پەیوەندیمان پێوە بکەن.',
        ar:'تواصلوا معنا عبر الأزرار أدناه.',en:'Contact us using the buttons below.'}[data.language],tt:'proxo_iq',
      template_key:data.key,template_version:data.version,color_theme:data.theme,
      card_language:data.language,platforms:{wa:'9647501234567',vb:'9647501234567',
        tg:'proxo_iq',ph:'9647501234567',as:'9647501234567',talabat:'https://www.talabat.com/iraq',lezzoo:'https://lezzoo.com',wade:'https://wadedelivery.com',toters:'https://www.totersapp.com',app_store:'https://apps.apple.com/app/id123456789',google_play:'https://play.google.com/store/apps/details?id=com.example.preview'},demo:true};
    card.page_type=data.pageType;
    card.platforms=Object.fromEntries(Object.entries(card.platforms).filter(([id])=>PROVIDERS[id].group===data.pageType));
    return publicPage(res,await renderedPage(card,{preview:true}));
  } catch {return unavailable(res);}
}
