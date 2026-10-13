// Authenticated self-service balance queries and manually reviewed payout requests.
// No service-role credentials ever reach the client.
import { json, readJson, rpc, serviceFetch, withSecurity } from './_lib/security.js';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STATUS = { disabled:'Payout requests are not enabled yet' };

async function ownBalance(userId) {
  const id=encodeURIComponent(userId);
  const [balances,journal,payouts,config,wallets] = await Promise.all([
    serviceFetch('/rest/v1/ex_customer_balances?user_id=eq.'+id+'&select=available_iqd,held_iqd,updated_at&limit=1'),
    serviceFetch('/rest/v1/ex_balance_journal?user_id=eq.'+id+
      '&select=id,kind,order_id,payout_id,note,evidence_ref,created_at,ex_balance_entries(account,delta_iqd,balance_after_iqd)'+
      '&order=created_at.desc&limit=50'),
    serviceFetch('/rest/v1/ex_payout_requests?user_id=eq.'+id+
      '&select=id,amount_iqd,destination_wallet,destination_number,status,transfer_reference,payout_receipt_url,created_at,updated_at'+
      '&order=created_at.desc&limit=25'),
    serviceFetch('/rest/v1/ex_balance_config?id=eq.true&select=payouts_enabled,max_single_payout_iqd&limit=1'),
    serviceFetch('/rest/v1/ex_wallets?allow_receive=eq.true&is_locked=eq.false&select=key,name&order=sort_order.asc')
  ]);
  return { balance:balances?.[0]||{available_iqd:0,held_iqd:0},
    journal:journal||[],payouts:payouts||[],
    payouts_enabled:config?.[0]?.payouts_enabled===true,
    max_single_payout_iqd:Number(config?.[0]?.max_single_payout_iqd||1000000),
    wallets:wallets||[] };
}
async function risk(user,context,kind,details){
  try{
    await serviceFetch('/rest/v1/ex_balance_risk_alerts',{
      method:'POST',headers:{Prefer:'return=minimal'},
      body:JSON.stringify({user_id:user.id,kind,ip_address:context.ip||null,details})
    });
  }catch(_){ /* Do not turn a rejected debit into a successful debit. */ }
}

export default withSecurity(async(req,res,{user,context})=>{
  if(req.method==='GET') return json(res,200,{ok:true,...await ownBalance(user.id)});
  const body=await readJson(req);
  const action=String(body.action||'');
  if(action==='cancel_payout'){
    if(!uuid.test(String(body.payout_id||'')))return json(res,422,{error:'Valid payout ID required'});
    try{
      const row=await rpc('ex_balance_cancel_payout',{
        p_payout_id:body.payout_id,p_actor:user.id,p_reason:'Cancelled by customer'
      });
      return json(res,200,{ok:true,payout:row});
    }catch(e){return json(res,409,{error:e.message||'Payout could not be cancelled'});}
  }
  if(action!=='request_payout')return json(res,422,{error:'Unknown balance action'});
  const key=String(body.request_key||'');
  const amount=Number(body.amount_iqd);
  const wallet=String(body.destination_wallet||'').trim().slice(0,40);
  const number=String(body.destination_number||'').replace(/\s/g,'').slice(0,32);
  if(!uuid.test(key)||!Number.isSafeInteger(amount)||amount<10000||amount>1000000000||
     !wallet||!/^\d{6,32}$/.test(number))
    return json(res,422,{error:'Invalid payout request'});
  // A retried request uses the same idempotency key; do not rate-limit the retry.
  const old=await serviceFetch('/rest/v1/ex_payout_requests?user_id=eq.'+
    encodeURIComponent(user.id)+'&request_key=eq.'+encodeURIComponent(key)+'&select=*&limit=1');
  if(old?.[0])return json(res,200,{ok:true,payout:old[0],already_exists:true});
  const recent=await serviceFetch('/rest/v1/ex_payout_requests?user_id=eq.'+
    encodeURIComponent(user.id)+'&created_at=gte.'+
    encodeURIComponent(new Date(Date.now()-15*60*1000).toISOString())+'&select=id&limit=4');
  if((recent||[]).length>=3){
    await risk(user,context,'high_frequency_payout_requests',{count:recent.length,period_minutes:15});
    return json(res,429,{error:'Too many payout requests; contact support'});
  }
  try{
    const payout=await rpc('ex_balance_request_payout',{
      p_user_id:user.id,p_request_key:key,p_amount_iqd:amount,
      p_wallet:wallet,p_number:number
    });
    return json(res,201,{ok:true,payout});
  }catch(e){
    const message=String(e.message||'Payout request failed');
    if(/INSUFFICIENT_BALANCE/i.test(message)){
      await risk(user,context,'insufficient_balance_attempt',{amount_iqd:amount});
    }
    return json(res,/PAYOUTS_NOT_ENABLED/.test(message)?403:409,{
      error:/PAYOUTS_NOT_ENABLED/.test(message)?STATUS.disabled:message
    });
  }
},{auth:'required',methods:['GET','POST']});
