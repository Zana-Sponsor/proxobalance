import { cardById, renderedPage, publicPage, unavailable } from './_lib/proxolink.js';

export default async function handler(req,res) {
  if(req.method!=='GET') return unavailable(res);
  try {
    const id=typeof req.query?.id==='string'?req.query.id:'';
    const card=await cardById(id);
    if(card.status!=='active'||card.publish_status!=='ready')
      return unavailable(res);
    const html=await renderedPage(card);
    return publicPage(res,html);
  } catch {
    // Public responses never disclose owner identity, storage paths or errors.
    return unavailable(res);
  }
}
