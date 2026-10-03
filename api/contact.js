import { validPreviewToken } from './_lib/proxolink-preview.js';
import { cardById, renderedPage, publicPage, unavailable } from './_lib/proxolink.js';

export default async function handler(req,res) {
  if(req.method!=='GET') return unavailable(res);
  try {
    const id=typeof req.query?.id==='string'?req.query.id:'';
    const card=await cardById(id);
    const preview=validPreviewToken(req.query?.preview_token,card);
    if(!preview&&(card.status!=='active'||card.publish_status!=='ready'))
      return unavailable(res);
    if(card.publish_status!=='ready')return unavailable(res);
    const html=await renderedPage(card,{preview});
    return publicPage(res,html);
  } catch {
    // Public responses never disclose owner identity, storage paths or errors.
    return unavailable(res);
  }
}
