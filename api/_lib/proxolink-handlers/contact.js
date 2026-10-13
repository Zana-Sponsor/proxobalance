import { pageKind, PAGE_TYPES } from '../proxolink-pages.js';
import { validPreviewToken } from '../proxolink-preview.js';
import { cardById, renderedPage, publicPage, unavailable } from '../proxolink.js';

export default async function handler(req,res) {
  if(req.method!=='GET') return unavailable(res);
  try {
    const id=typeof req.query?.id==='string'?req.query.id:'';
    const card=await cardById(id);
    const route=req.query?.page_type||'contact';
    if(!PAGE_TYPES.includes(route)||pageKind(card)!==route||card.archived_at)return unavailable(res);
    const preview=validPreviewToken(req.query?.preview_token,card);
    if(!preview&&(card.status!=='active'||card.publish_status!=='ready'))
      return unavailable(res);
    if(card.publish_status!=='ready')return unavailable(res);
    const html=await renderedPage(card,{preview,previewToken:preview?req.query.preview_token:null});
    return publicPage(res,html);
  } catch {
    // Public responses never disclose owner identity, storage paths or errors.
    return unavailable(res);
  }
}
