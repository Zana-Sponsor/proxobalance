import { proxoWrite } from './proxolink.js';
// An audit outage must not change an already-committed publication result.
export async function publishAudit(card,operation,result,errorCode=null) {
  try {
    await proxoWrite('proxolink_publish_attempts','POST',{
      card_id:card.id,user_id:card.user_id,operation,result,
      error_code:errorCode?String(errorCode).slice(0,80):null
    },'','return=minimal');
  } catch { console.warn('ProxoLink publication audit unavailable'); }
}
