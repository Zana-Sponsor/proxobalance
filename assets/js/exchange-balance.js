// Customer refund balance is visible ONLY in the Send section.
// Actual payouts are manual, gated in the database and reviewed by an admin.
let _myBalanceData=null,_balanceRequestKey=null;
function balanceIqd(n){return Number(n||0).toLocaleString('en-US')+' د.ع';}
function balanceTime(iso){return iso?new Date(iso).toLocaleString('en-GB'):'—';}
async function balanceApi(method,body){
  const session=await getOrderSession();
  const response=await fetch('/api/balance',{
    method,headers:{'Authorization':'Bearer '+session.access_token,
      ...(method==='POST'?{'Content-Type':'application/json'}:{})},
    ...(body?{body:JSON.stringify(body)}:{})
  });
  let result={};
  try{result=await response.json();}catch(_){}
  if(!response.ok||!result.ok){
    const e=new Error(result.error||'نەتوانرا زانیاریی باڵانس بار بکرێت');
    e.status=response.status;throw e;
  }
  return result;
}
async function loadMyBalance(){
  const wrap=document.getElementById('balanceSendSection');
  if(!wrap||!curUser)return;
  wrap.hidden=false;
  const note=document.getElementById('balanceStatusMessage');
  try{
    _myBalanceData=await balanceApi('GET');
    document.getElementById('balanceAvailable').textContent=balanceIqd(_myBalanceData.balance.available_iqd);
    document.getElementById('balanceHeld').textContent=balanceIqd(_myBalanceData.balance.held_iqd);
    const enabled=_myBalanceData.payouts_enabled===true;
    const available=Number(_myBalanceData.balance.available_iqd||0);
    const btn=document.getElementById('balancePayoutToggle');
    btn.disabled=!enabled||available<10000;
    note.textContent=!enabled?'داواکاری ناردنی باڵانس تا تەواوبوونی پشکنینە یاساییەکان ناچالاکە.':
      available<10000?'کەمترین بڕی ناردن 10,000 دینارە.':
      'ناردن پاش پشتڕاستکردنەوەی بەڕێوەبەر جێبەجێ دەکرێت.';
    const select=document.getElementById('balanceDestWallet');
    const previous=select.value;
    select.textContent='';
    (_myBalanceData.wallets||[]).forEach(w=>{
      const option=document.createElement('option');
      option.value=w.key;option.textContent=w.name||w.key;select.appendChild(option);
    });
    if((_myBalanceData.wallets||[]).some(w=>w.key===previous))select.value=previous;
    document.getElementById('balancePayoutAmount').max=String(Math.min(available,
      Number(_myBalanceData.max_single_payout_iqd||1000000)));
    if(!enabled)document.getElementById('balancePayoutForm').hidden=true;
    renderBalanceHistory();
  }catch(e){note.textContent='کێشە لە بارکردنی باڵانس: '+e.message;}
}
function toggleBalancePayout(){
  const form=document.getElementById('balancePayoutForm');
  if(!_myBalanceData?.payouts_enabled||Number(_myBalanceData.balance.available_iqd||0)<10000)return;
  form.hidden=!form.hidden;
  if(!form.hidden)document.getElementById('balancePayoutAmount').focus();
}
function toggleBalanceHistory(){
  const el=document.getElementById('balanceHistoryList');el.hidden=!el.hidden;
  if(!el.hidden)renderBalanceHistory();
}
function renderBalanceHistory(){
  const el=document.getElementById('balanceHistoryList');
  if(!el||!_myBalanceData)return;
  const kinds={verified_refund:'گەڕاندنەوەی پارە',payout_hold:'داواکاری ناردن',
    payout_cancel:'هەڵوەشاندنەوەی ناردن',payout_paid:'ناردنی سەرکەوتوو'};
  const journal=(_myBalanceData.journal||[]).slice(0,20);
  let html=journal.map(j=>{
    const available=(j.ex_balance_entries||[]).find(x=>x.account==='customer_available');
    const held=(j.ex_balance_entries||[]).find(x=>x.account==='customer_held');
    const amount=Number(available?.delta_iqd||held?.delta_iqd||0);
    return '<div class="pb-history-row"><div><b>'+escHtml(kinds[j.kind]||j.kind)+'</b>'+
      '<small>'+escHtml(balanceTime(j.created_at))+'</small>'+
      (j.order_id?'<small dir="ltr">ID: '+escHtml(j.order_id)+'</small>':'')+
      '<small>'+escHtml(j.note||'')+'</small></div>'+
      '<b dir="ltr">'+(amount>0?'+':'')+balanceIqd(amount)+'</b></div>';
  }).join('');
  const requests=(_myBalanceData.payouts||[]).filter(p=>['pending','processing'].includes(p.status)).slice(0,5);
  html+=requests.map(p=>'<div class="pb-history-row"><div><b>'+(p.status==='processing'?'داواکاری لەژێر پشکنینە':'داواکاری چاوەڕوانە')+'</b>'+
    '<small>'+escHtml(p.destination_wallet)+' / '+escHtml(p.destination_number)+'</small>'+
    '<small>'+escHtml(balanceTime(p.created_at))+'</small></div>'+
    (p.status==='pending'?'<button type="button" class="pb-btn pb-secondary" onclick="cancelMyBalancePayout(\''+
       escHtml(p.id)+'\')">هەڵوەشاندنەوە</button>':'<small>هەڵوەشاندنەوە لەم قۆناغەدا ڕێگەپێدراو نییە</small>')+'</div>').join('');
  el.innerHTML=html||'<p class="pb-message">هێشتا هیچ جوڵەیەکی باڵانس نییە.</p>';
}
document.getElementById('balancePayoutForm')?.addEventListener('input',()=>{
  _balanceRequestKey=null;
});
async function requestBalancePayout(event){
  event.preventDefault();
  const btn=document.getElementById('balancePayoutSubmit');
  if(btn.disabled||!_myBalanceData?.payouts_enabled)return;
  const amount=Number(document.getElementById('balancePayoutAmount').value);
  const wallet=document.getElementById('balanceDestWallet').value;
  const number=document.getElementById('balanceDestNumber').value.trim().replace(/\s/g,'');
  if(!Number.isSafeInteger(amount)||amount<10000||
     amount>Number(_myBalanceData.balance.available_iqd||0)||
     amount>Number(_myBalanceData.max_single_payout_iqd||0)||
     !/^[0-9]{6,32}$/.test(number)){
    showToast('بڕ و ژمارەی جزدان بە دروستی دیاری بکە','error');return;
  }
  if(!confirm('داواکاری ناردنی '+balanceIqd(amount)+' بۆ '+wallet+' بنێردرێت؟'))return;
  _balanceRequestKey=_balanceRequestKey||crypto.randomUUID();
  btn.disabled=true;
  try{
    await balanceApi('POST',{action:'request_payout',request_key:_balanceRequestKey,
      amount_iqd:amount,destination_wallet:wallet,destination_number:number});
    _balanceRequestKey=null;
    document.getElementById('balancePayoutForm').reset();
    document.getElementById('balancePayoutForm').hidden=true;
    showToast('داواکاری نێردرا؛ باڵانس تا پەسەندکردن گیراوە','success');
    await loadMyBalance();
  }catch(e){showToast(e.message,'error');}finally{btn.disabled=false;}
}
async function cancelMyBalancePayout(id){
  if(!confirm('داواکاری هەڵبوەشێتەوە و پارەکە بگەڕێتەوە بۆ باڵانسی بەردەست؟'))return;
  try{await balanceApi('POST',{action:'cancel_payout',payout_id:id});
    showToast('باڵانس بۆ هەژمارەکەت گەڕێندرایەوە','success');
    await loadMyBalance();
  }catch(e){showToast(e.message,'error');}
}
