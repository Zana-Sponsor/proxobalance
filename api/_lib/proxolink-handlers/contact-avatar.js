import { validPreviewToken } from '../proxolink-preview.js';
import { avatarBytes, cardById, unavailable } from '../proxolink.js';
import { trackedContext } from '../proxolink-track.js';

export default async function handler(req,res) {
  if(req.method!=='GET')return unavailable(res);
  try {
    const token=typeof req.query?.token==='string'?req.query.token:null;
    const card=token?(await trackedContext(token)).card
      :await cardById(typeof req.query?.id==='string'?req.query.id:'');
    const preview=!token&&validPreviewToken(req.query?.preview_token,card);
    if(card.publish_status!=='ready'||(!preview&&card.status!=='active'))
      return unavailable(res);
    const prefix=card.user_id+'/'+card.id+'/';
    if(typeof card.avatar_path!=='string'||!card.avatar_path.startsWith(prefix)
      ||!/^[a-zA-Z0-9_-]+\.(webp|jpe?g|png)$/i.test(card.avatar_path.slice(prefix.length)))
      return unavailable(res);
    const {data,mime}=await avatarBytes(card.avatar_path);
    res.statusCode=200;
    res.setHeader('Content-Type',mime);
    res.setHeader('Cache-Control','no-store');
    res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('Referrer-Policy','no-referrer');
    // Reading an avatar never records a page view or button event.
    return res.end(Buffer.from(data));
  } catch {return unavailable(res);}
}
