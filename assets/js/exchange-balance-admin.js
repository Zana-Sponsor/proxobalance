// Exchange balance board. All money-changing actions go through /api/admin.
let _balanceAdminData=null, _balanceChosenOrder=null;
function balanceMoney(n){return Number(n||0).toLocaleString('en-US')+' د.ع';}
function balanceOwner(id){
  const p=(_balanceAdminData&&_balanceAdminData.profiles||{})[id]||{};
  return esc(p.full_name||p.username||p.email||id||'—');
}
function balanceDate(s){return s?esc(new Date(s).toLocaleString('en-GB')):'—';}
function balanceTable(head,rows,cols){
  if(!rows.length)return '<div class="empty">هیچ تۆمارێک نییە</div>';
  return '<table><thead><tr>'+head.map(h=>'<th>'+esc(h)+'</th>').join('')+
    '</tr></thead><tbody>'+rows.map(cols).join('')+'</tbody></table>';
}
async function loadBalanceAdmin(){
  try{
    _balanceAdminData=await adminApiRequest('balance_dashboard');
    const d=_balanceAdminData,balances=d.balances||[],refunds=d.refunds||[],payouts=d.payouts||[],alerts=d.alerts||[];
    const total=balances.reduce((sum,r)=>sum+Number(r.available_iqd||0),0);
    const held=balances.reduce((sum,r)=>sum+Number(r.held_iqd||0),0);
    document.getElementById('balanceAdminStats').innerHTML=
      '<div class="ex-note"><b>باڵانسی بەردەست: '+balanceMoney(total)+'</b></div>'+
      '<div class="ex-note"><b>لە چاوەڕوانیدا: '+balanceMoney(held)+'</b></div>'+
      '<div class="ex-note"><b>ڕیفاوندەکان: '+refunds.length+'</b></div>'+
      '<div class="ex-note"><b>داواکارییە چاوەڕوانەکان: '+payouts.filter(p=>p.status==='pending'||p.status==='processing').length+'</b></div>'+
      '<div class="ex-note"><b>ناردنی باڵانس: '+(d.config?.payouts_enabled?'چالاک (پەسەندکردنی دەستی)':'ناچالاک تا پشکنینی یاسایی')+'</b></div>';
    const rec=d.reconciliation||{};
    const discrepancies=Number(rec.unbalanced_journals||0)+Number(rec.balance_mismatches||0)+
      Number(rec.held_payout_mismatches||0)+Number(rec.unlinked_refunds||0)+
      (rec.clearing_mismatch?1:0);
    document.getElementById('balanceAdminStats').innerHTML+=
      '<div class="ex-note" style="color:'+(discrepancies?'#b91c1c':'#15803d')+'"><b>'+
      (discrepancies?'ئاگاداری: '+discrepancies+' نایەکسانی لە حسابداری هەیە؛ پشکنین پێویستە.':
      'حسابداری و تۆماری جوڵەکان یەکدەگرنەوە.')+'</b></div>';
    document.getElementById('balancePayoutsList').innerHTML=balanceTable(
      ['بەکارهێنەر','بڕ','جزدانی وەرگر','دۆخ','کات','کردار'],payouts,p=>
      '<tr><td>'+balanceOwner(p.user_id)+'</td><td>'+balanceMoney(p.amount_iqd)+'</td>'+
      '<td>'+esc(p.destination_wallet)+' / <span dir="ltr">'+esc(p.destination_number)+'</span><div>'+esc(p.destination_owner)+'</div></td>'+
      '<td>'+esc(p.status)+'</td><td>'+balanceDate(p.created_at)+'</td><td>'+
      (p.status==='pending'?'<button type="button" class="act-btn gr" onclick="startBalancePayout(\''+p.id+'\')">پشکنین</button> '+
        '<button type="button" class="act-btn rd" onclick="cancelBalancePayout(\''+p.id+'\')">هەڵوەشاندنەوە</button>':
        p.status==='processing'?'<button type="button" class="act-btn gr" onclick="reviewBalancePayout(\''+p.id+'\')">تۆمارکردنی ناردن</button> '+
        '<button type="button" class="act-btn rd" onclick="abortProcessingPayout(\''+p.id+'\')">ناردن شکستی هێنا</button>':
        p.payout_receipt_url?'<a class="act-btn dark" href="'+esc(p.payout_receipt_url)+'" target="_blank" rel="noopener noreferrer">پسووڵە</a>':'—')+'</td></tr>');
    document.getElementById('balanceRefundList').innerHTML=balanceTable(
      ['بەکارهێنەر','ئایدی مامەڵە','بڕی ڕیفاوند','ژمارەی بەڵگە','تێبینی','بەروار'],refunds,r=>
      '<tr><td>'+balanceOwner(r.user_id)+'</td><td><span dir="ltr">'+esc(r.order_id)+'</span></td>'+
      '<td>'+balanceMoney(r.amount_iqd)+'</td><td>'+esc(r.bank_verification_reference)+'</td>'+
      '<td>'+esc(r.failure_reason)+'</td><td>'+balanceDate(r.created_at)+'</td></tr>');
    document.getElementById('balanceAccountList').innerHTML=balanceTable(
      ['بەکارهێنەر','باڵانسی بەردەست','پارەی گیراو','دوایین نوێکردنەوە'],balances,r=>
      '<tr><td>'+balanceOwner(r.user_id)+'</td><td>'+balanceMoney(r.available_iqd)+'</td>'+
      '<td>'+balanceMoney(r.held_iqd)+'</td><td>'+balanceDate(r.updated_at)+'</td></tr>');
    document.getElementById('balanceRiskList').innerHTML=balanceTable(
      ['بەکارهێنەر','جۆری ئاگاداری','IP','بەروار','کردار'],alerts,r=>
      '<tr><td>'+balanceOwner(r.user_id)+'</td><td>'+esc(r.kind)+'</td>'+
      '<td><span dir="ltr">'+esc(r.ip_address||'—')+'</span></td><td>'+balanceDate(r.created_at)+'</td>'+
      '<td><button class="act-btn dark" onclick="resolveBalanceRisk(\''+r.id+'\',\'reviewed\')">پشکنرا</button> '+
      '<button class="act-btn rd" onclick="resolveBalanceRisk(\''+r.id+'\',\'dismissed\')">ڕەتکردنەوە</button></td></tr>');
  }catch(e){
    document.getElementById('balanceAdminStats').textContent='هەڵە لە بارکردنی زانیارییەکان: '+e.message;
  }
}
function balanceResetChosen(){
  _balanceChosenOrder=null;
  const btn=document.getElementById('balanceCreditBtn');
  if(btn)btn.disabled=true;
  document.getElementById('balanceFoundOrder').textContent='مامەڵەی پشتڕاستکراوە هەڵنەبژێردراوە';
}
document.getElementById('balanceOrderSearch')?.addEventListener('input',balanceResetChosen);
async function openOrderRefund(id){
  const order=allOrders.find(o=>String(o.id)===String(id));
  closeMo('moOrderDetail');goPage('balance');
  document.getElementById('balanceOrderSearch').value=order?.order_code||id;
  document.getElementById('balanceFundsVerified').checked=false;
  document.getElementById('balanceBankReference').value='';
  document.getElementById('balanceRefundReason').value='';
  await lookupBalanceOrder();
}
async function lookupBalanceOrder(){
  balanceResetChosen();
  const out=document.getElementById('balanceFoundOrder');
  const err=document.getElementById('balanceRefundError');err.textContent='';
  try{
    const result=await adminApiRequest('balance_lookup_order',{
      search:document.getElementById('balanceOrderSearch').value.trim()
    });
    const o=result.order,p=result.profile||{};
    const eligible=!result.refund&&o.status!=='پەسەندکرا'&&!o.payout_receipt_url&&(!!o.receipt_url||!!o.balance_debit_journal_id)&&o.from_method!=='USDT'&&o.to_method!=='USDT';
    out.innerHTML='<div><b>'+esc(o.order_code)+'</b> — '+esc(p.full_name||p.email||o.user_id)+'</div>'+
      '<div>بڕی پارە: <b>'+balanceMoney(o.amount)+'</b> | '+esc(o.from_method)+' → '+esc(o.to_method)+'</div>'+
      '<div>بار: '+esc(o.status)+' | '+balanceDate(o.created_at)+'</div>'+
      '<div>'+(o.receipt_url?'<a target="_blank" rel="noopener noreferrer" href="'+esc(o.receipt_url)+'">بینینی پسووڵەی نێرەر</a>':o.balance_debit_journal_id?'کەمکردنەوە لە باڵانس: '+esc(o.balance_debit_journal_id):'بەبێ پسووڵە')+'</div>'+
      (result.refund?'<b style="color:#b91c1c">ئەم مامەڵەیە پێشتر ڕیفاوند کراوە.</b>':'')+
      (!eligible?'<div style="color:#b91c1c">ئەم مامەڵەیە بۆ گەڕاندنەوە بۆ باڵانس گونجاو نییە.</div>':'');
    _balanceChosenOrder=eligible?o:null;
    if(eligible&&o.balance_debit_journal_id)document.getElementById('balanceBankReference').value='balance-debit:'+o.balance_debit_journal_id;
    document.getElementById('balanceCreditBtn').disabled=!eligible;
  }catch(e){out.textContent='مامەڵە نەدۆزرایەوە';err.textContent=e.message;}
}
async function creditVerifiedRefund(){
  const err=document.getElementById('balanceRefundError');err.textContent='';
  if(!_balanceChosenOrder){err.textContent='سەرەتا مامەڵەیەکی گونجاو هەڵبژێرە';return;}
  const ref=document.getElementById('balanceBankReference').value.trim();
  const reason=document.getElementById('balanceRefundReason').value.trim();
  const confirmed_received=document.getElementById('balanceFundsVerified').checked;
  if(ref.length<6||reason.length<10||!confirmed_received){
    err.textContent='ژمارەی بەڵگە، هۆکاری گەڕاندنەوە و پشتڕاستکردنەوەی وەرگرتنی پارە پێویستن.';return;
  }
  if(!confirm('ئەم مامەڵەیە ڕەت بکرێتەوە و '+balanceMoney(_balanceChosenOrder.amount)+' بگەڕێتەوە بۆ باڵانسی کڕیار؟'))return;
  const btn=document.getElementById('balanceCreditBtn');btn.disabled=true;
  try{
    await adminApiRequest('balance_credit_refund',{
      order_id:_balanceChosenOrder.id,verification_reference:ref,reason,
      confirmed_received
    });
    showToast('ڕیفاوند و تۆماری دارایی بە سەرکەوتوویی ئەنجام درا','gr');
    document.getElementById('balanceBankReference').value='';
    document.getElementById('balanceRefundReason').value='';
    document.getElementById('balanceFundsVerified').checked=false;
    await lookupBalanceOrder();await loadBalanceAdmin();
  }catch(e){err.textContent=e.message;btn.disabled=false;}
}
async function startBalancePayout(id){
  const p=(_balanceAdminData?.payouts||[]).find(x=>x.id===id&&x.status==='pending');
  if(!p)return;
  const verification=prompt('خاوەندارێتی جزدان، ژمارە و ناوی وەرگر پشتڕاست بکەرەوە. ژمارە/تێبینی بەڵگەی پشتڕاستکردنەوە بنووسە:');
  if(!verification||verification.trim().length<10||verification.trim().length>160){showToast('بەڵگەی پشتڕاستکردنەوە پێویستە','rd');return;}
  if(!confirm('داواکاری دەچێتە باری ناردن؛ کڕیار چیتر ناتوانێت هەڵیبوشێنێتەوە. ئایا خاوەندارێتی جزدان پشتڕاست کراوەتەوە؟'))return;
  try{
    await adminApiRequest('balance_claim_payout',{payout_id:id,verification:verification.trim()});
    await loadBalanceAdmin();reviewBalancePayout(id);
  }catch(e){showToast(e.message,'rd');}
}
async function abortProcessingPayout(id){
  const p=(_balanceAdminData?.payouts||[]).find(x=>x.id===id&&x.status==='processing');
  if(!p)return;
  const reason=prompt('هۆکاری شکستی ناردن بنووسە (لانیکەم ١٠ پیت):');
  if(!reason||reason.trim().length<10)return;
  const bank_reference=prompt('ژمارەی پشتڕاستکردنەوەی بانک کە پارە نەگەیشتووە:');
  if(!bank_reference||bank_reference.trim().length<6)return;
  if(!confirm('تەنها ئەگەر بانک پشتڕاستی کردووەتەوە کە پارە نەگوازراوەتەوە، باڵانس بگەڕێنەوە. دڵنیایت؟'))return;
  try{
    await adminApiRequest('balance_abort_processing',{
      payout_id:id,reason:reason.trim(),bank_reference:bank_reference.trim(),confirmed_unpaid:true
    });
    document.getElementById('balancePayReview').hidden=true;
    showToast('پارەی نەنێردراو بۆ باڵانس گەڕێندرایەوە','gr');
    await loadBalanceAdmin();
  }catch(e){showToast(e.message,'rd');}
}
function reviewBalancePayout(id){
  const p=(_balanceAdminData?.payouts||[]).find(x=>x.id===id&&x.status==='processing');
  if(!p)return;
  const panel=document.getElementById('balancePayReview');
  panel.hidden=false;
  document.getElementById('balanceReviewId').value=p.id;
  document.getElementById('balanceReviewLabel').textContent=
    balanceOwner(p.user_id)+' — '+balanceMoney(p.amount_iqd)+' بۆ '+p.destination_wallet+' / '+p.destination_number;
  document.getElementById('balanceTransferReference').value='';
  document.getElementById('balanceDestVerification').value=p.processing_verification||'';
  document.getElementById('balanceDestVerification').readOnly=true;
  document.getElementById('balancePayoutReceipt').value='';
  document.getElementById('balancePayoutNote').value='';
  document.getElementById('balancePayConfirmed').checked=false;
  panel.scrollIntoView({behavior:'smooth',block:'start'});
}
async function completeBalancePayout(){
  const err=document.getElementById('balancePayError');err.textContent='';
  if(!document.getElementById('balancePayConfirmed').checked){
    err.textContent='تەنها دوای ئەنجامدانی ناردنی پارەی ڕاستەقینە پەسەند بکە.';return;
  }
  if(!confirm('پارەکە بەڕاستی نێردراوە و ژمارەی پسووڵە ڕاستە؟'))return;
  try{
    await adminApiRequest('balance_mark_payout_paid',{
      payout_id:document.getElementById('balanceReviewId').value,
      transfer_reference:document.getElementById('balanceTransferReference').value,
      destination_verification:document.getElementById('balanceDestVerification').value,
      receipt_url:document.getElementById('balancePayoutReceipt').value,
      note:document.getElementById('balancePayoutNote').value,confirmed:true
    });
    document.getElementById('balancePayReview').hidden=true;
    showToast('تۆماری ناردن بە سەرکەوتوویی ئەنجام درا','gr');
    await loadBalanceAdmin();
  }catch(e){err.textContent=e.message;}
}
async function cancelBalancePayout(id){
  if(!confirm('داواکاری هەڵبوەشێتەوە و باڵانسی گیراو بگەڕێتەوە؟'))return;
  try{await adminApiRequest('balance_cancel_payout',{payout_id:id,reason:'Cancelled after admin review'});
    showToast('باڵانسی گیراو گەڕێندرایەوە','gr');await loadBalanceAdmin();
  }catch(e){showToast(e.message,'rd');}
}
async function resolveBalanceRisk(id,status){
  try{await adminApiRequest('balance_resolve_risk',{id,status});await loadBalanceAdmin();}
  catch(e){showToast(e.message,'rd');}
}
