import {
  trackedContext, recordContactEvent, actionUrl
} from './_lib/proxolink-track.js';
import { renderedPage, publicPage, unavailable } from './_lib/proxolink.js';

export default async function handler(req,res) {
  if(req.method!=='GET')return unavailable(res);
  try {
    const token=typeof req.query?.token==='string'?req.query.token:'';
    const {link,card}=await trackedContext(token);
    const action=typeof req.query?.action==='string'?req.query.action:null;
    if(action) {
      const url=actionUrl(card,action);
      await recordContactEvent(req,link.id,'button_click',action);
      res.statusCode=302;
      res.setHeader('Cache-Control','no-store');
      res.setHeader('Location',url);
      return res.end();
    }
    const html=await renderedPage(card,{adToken:token});
    await recordContactEvent(req,link.id,'page_view');
    return publicPage(res,html);
  } catch {
    // No guessed ad identity, no fallback to another user's card.
    return unavailable(res);
  }
}
