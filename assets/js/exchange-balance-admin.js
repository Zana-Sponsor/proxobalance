// Exchange balance board. All money-changing actions go through /api/admin.
let _balanceAdminData=null, _balanceChosenOrder=null, _balanceLookupResult=null;
let _balanceLookupSequence=0, _balanceLookupPending=false, _balanceRefundBusy=false;
let _balanceShortfallBusy=false, _balanceShortfallRequest=null, _balanceShortfallDraftOrderId=null;
let _balanceShortfallNeedsRefresh=false, _balanceShortfallRecoveryError='';
let _balanceShortfallDraftAdminId=null;
function balanceMoney(n){return Number(n||0).toLocaleString('en-US')+' د.ع';}
function balanceOwner(id){
  const p=(_balanceAdminData&&_balanceAdminData.profiles||{})[id]||
    _balanceLookupResult?.profiles?.[id]||
    (_balanceLookupResult?.order?.user_id===id?_balanceLookupResult.profile:null)||{};
  return esc(p.full_name||p.username||p.email||id||'—');
}
function balanceDate(s){return s?esc(new Date(s).toLocaleString('en-GB')):'—';}
function balanceTable(head,rows,cols,className=''){
  if(!rows.length)return '<div class="empty">هیچ تۆمارێک نییە</div>';
  return '<table'+(className?' class="'+esc(className)+'"':'')+'><thead><tr>'+head.map(h=>'<th>'+esc(h)+'</th>').join('')+
    '</tr></thead><tbody>'+rows.map(cols).join('')+'</tbody></table>';
}
function balanceCanRefund(){return typeof staffCan!=='function'||staffCan('refunds');}
function balanceWholeIqd(value){
  const text=String(value??'').trim().replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-0x660))
    .replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-0x6f0));
  if(!/^(?:\d+|\d{1,3}(?:[,٬]\d{3})+)$/.test(text))return null;
  const amount=Number(text.replace(/[,٬]/g,''));
  return Number.isSafeInteger(amount)&&amount>0&&amount<=1000000000?amount:null;
}
function balanceShortfallState(){
  const result=_balanceLookupResult,summary=result?.shortfall_summary,balance=result?.balance;
  if(!summary||!balance)return null;
  const expected=Number(summary.expected_iqd),refunded=Number(summary.refunded_iqd);
  const remaining=Number(summary.remaining_iqd),available=Number(balance.available_iqd);
  if(![expected,refunded,remaining,available].every(n=>Number.isSafeInteger(n)&&n>=0))return null;
  return {expected,refunded,remaining,available,eligible:summary.eligible===true};
}
function balanceShortfallFormPayload(){
  return {order_id:_balanceLookupResult?.order?.id,
    amount_iqd:balanceWholeIqd(document.getElementById('balanceShortfallAmount')?.value),
    reason:(document.getElementById('balanceShortfallReason')?.value||'').trim(),
    confirmed_shortfall:true};
}
function balanceShortfallAdminId(){return typeof adminUser!=='undefined'?adminUser?.id:null;}
function balanceShortfallStorageKey(orderId,owner=balanceShortfallAdminId()){
  if(!owner||!orderId)throw Error('سەرەتا بە هەژماری ئادمین بچۆ ژوورەوە و مامەڵەکە بدۆزەرەوە.');
  return 'proxo:shortfall:pending:v1:'+owner+':'+orderId;
}
function balanceShortfallStorageError(){
  return 'هەڵگرتنی داواکاری لەم پەڕەیە بەردەست نییە. ڕێگە بە هەڵگرتنی داتای ماڵپەڕ بدە و «دۆزینەوە» دابگرە.';
}
function balanceShortfallHasPending(){
  return !!_balanceShortfallRequest&&_balanceShortfallRequest.admin_id===balanceShortfallAdminId()&&
    _balanceShortfallRequest.payload.order_id===_balanceLookupResult?.order?.id;
}
function balanceShortfallIsRetry(){
  return balanceShortfallHasPending()&&_balanceShortfallRequest.fingerprint===JSON.stringify(balanceShortfallFormPayload());
}
function balanceRestoreShortfallRequest(orderId){
  const owner=balanceShortfallAdminId(),remembered=balanceShortfallHasPending();
  try{
    const raw=sessionStorage.getItem(balanceShortfallStorageKey(orderId,owner));
    if(raw&&!remembered){
      const saved=JSON.parse(raw),p=saved?.payload;
      if(saved?.version!==1||saved.admin_id!==owner||p?.order_id!==orderId||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(p.request_key)||
        !Number.isSafeInteger(p.amount_iqd)||balanceWholeIqd(p.amount_iqd)!==p.amount_iqd||
        !Number.isSafeInteger(p.expected_refunded_iqd)||p.expected_refunded_iqd<0||p.expected_refunded_iqd>1000000000||
        typeof p.reason!=='string'||p.reason!==p.reason.trim()||p.reason.length<10||p.reason.length>2000||
        p.confirmed_shortfall!==true)throw Error('INVALID_PENDING_SHORTFALL');
      const form={order_id:p.order_id,amount_iqd:p.amount_iqd,reason:p.reason,confirmed_shortfall:true};
      _balanceShortfallRequest={admin_id:owner,fingerprint:JSON.stringify(form),
        payload:{...form,expected_refunded_iqd:p.expected_refunded_iqd,request_key:p.request_key}};
    }
    if(balanceShortfallHasPending()){
      const p=_balanceShortfallRequest.payload;
      document.getElementById('balanceShortfallAmount').value=String(p.amount_iqd);
      document.getElementById('balanceShortfallReason').value=p.reason;
      if(!remembered)document.getElementById('balanceShortfallConfirmed').checked=false;
    }
  }catch(e){
    _balanceShortfallRecoveryError=e.message==='INVALID_PENDING_SHORTFALL'||e instanceof SyntaxError?
      'داواکارییەکی پێشوو هەیە کە نەتوانرا بخوێندرێتەوە؛ پێش گەڕاندنەوەیەکی نوێ پێویستی بە پشکنین هەیە.':balanceShortfallStorageError();
    document.getElementById('balanceShortfallError').textContent=_balanceShortfallRecoveryError;
  }
}
function balanceSaveShortfallRequest(request){
  sessionStorage.setItem(balanceShortfallStorageKey(request.payload.order_id,request.admin_id),
    JSON.stringify({version:1,admin_id:request.admin_id,payload:request.payload}));
}
function balanceForgetShortfallRequest(){
  if(!_balanceShortfallRequest)return true;
  try{
    sessionStorage.removeItem(balanceShortfallStorageKey(_balanceShortfallRequest.payload.order_id,_balanceShortfallRequest.admin_id));
    _balanceShortfallRequest=null;return true;
  }catch{
    _balanceShortfallRecoveryError=balanceShortfallStorageError();
    document.getElementById('balanceShortfallError').textContent=_balanceShortfallRecoveryError;return false;
  }
}
function balanceSetControls(){
  const busy=_balanceShortfallBusy||_balanceRefundBusy,allowed=balanceCanRefund();
  const state=balanceShortfallState();
  const pending=balanceShortfallHasPending(),retry=balanceShortfallIsRetry();
  const shortfallDisabled=busy||_balanceLookupPending||!allowed||(!state?.eligible&&!retry)||_balanceShortfallNeedsRefresh||
    !!_balanceShortfallRecoveryError||_balanceShortfallDraftAdminId!==balanceShortfallAdminId()||(pending&&!retry);
  const fields=document.getElementById('balanceShortfallFields');if(fields)fields.disabled=shortfallDisabled;
  for(const id of ['balanceShortfallAmount','balanceShortfallReason']){
    const input=document.getElementById(id);if(input)input.readOnly=pending;
  }
  const shortfallBtn=document.getElementById('balanceShortfallBtn');
  if(shortfallBtn){
    shortfallBtn.disabled=shortfallDisabled;
    shortfallBtn.textContent=_balanceShortfallBusy?'گەڕاندنەوەکە تۆمار دەکرێت...':
      retry?'پشکنینەوەی هەمان داواکاری':'گەڕاندنەوەی بڕی کەم نێردراو بۆ باڵانس';
  }
  const fullBtn=document.getElementById('balanceCreditBtn');
  if(fullBtn)fullBtn.disabled=busy||_balanceLookupPending||!allowed||!_balanceChosenOrder;
  const search=document.getElementById('balanceOrderSearch');if(search)search.disabled=busy;
  const lookup=document.getElementById('balanceOrderLookupBtn');if(lookup)lookup.disabled=busy||_balanceLookupPending;
  document.getElementById('balanceShortfallForm')?.setAttribute('aria-busy',String(_balanceShortfallBusy));
}
function balanceClearShortfallDraft(){
  // Searching another order clears its display, never an unresolved saved request.
  _balanceShortfallRequest=null;_balanceShortfallNeedsRefresh=false;_balanceShortfallRecoveryError='';
  for(const id of ['balanceShortfallAmount','balanceShortfallReason']){
    const el=document.getElementById(id);if(el)el.value='';
  }
  const confirmed=document.getElementById('balanceShortfallConfirmed');if(confirmed)confirmed.checked=false;
  for(const id of ['balanceShortfallError','balanceShortfallSuccess']){
    const el=document.getElementById(id);if(el)el.textContent='';
  }
}
function renderBalanceShortfallPreview(){
  const out=document.getElementById('balanceShortfallPreview');if(!out)return;
  const state=balanceShortfallState();
  if(!state){out.innerHTML='';return;}
  const amount=balanceWholeIqd(document.getElementById('balanceShortfallAmount')?.value);
  const valid=amount!==null&&amount<=state.remaining&&Number.isSafeInteger(state.available+amount);
  const card=(label,value,highlight=false)=>'<div'+(highlight?' class="balance-credit-highlight"':'')+'><span>'+esc(label)+
    '</span><strong>'+esc(value)+'</strong></div>';
  out.innerHTML=card('بڕی پێویستی ناردن بۆ کڕیار',balanceMoney(state.expected))+
    card('پێشتر بۆ باڵانس گەڕاوەتەوە',balanceMoney(state.refunded))+
    card('ماوەی گەڕاندنەوە',balanceMoney(state.remaining))+
    card('بڕی ئەم گەڕاندنەوەیە',valid?balanceMoney(amount):'—',true)+
    card('باڵانسی بەردەستی ئێستا',balanceMoney(state.available))+
    card('باڵانس دوای گەڕاندنەوە',valid?balanceMoney(state.available+amount):'—',true)+
    '<p class="balance-credit-preview-note">'+
    (valid?'بڕی پێویستی ناردن دوای کەمکردنەوەی کۆی گەڕاوەکان: '+balanceMoney(state.remaining-amount)+' · ':'')+
    'پێشبینینە؛ باڵانسی کۆتایی لە کاتی تۆمارکردندا دیاری دەکرێت.</p>';
}
function balanceAuditTime(iso){
  if(!iso||!Number.isFinite(new Date(iso).getTime()))return '—';
  return esc(new Date(iso).toLocaleString('en-GB',{timeZone:'Asia/Baghdad'}))+' (بەغدا)';
}
function balanceShortfallTable(rows){
  const legacyReference=r=>r.verification_reference&&String(r.verification_reference).toLowerCase()!=='shortfall:'+String(r.request_key).toLowerCase()?
    '<small>بەڵگەی پێشوو: '+esc(r.verification_reference)+'</small>':'';
  return balanceTable(['مامەڵە / کڕیار','بڕی گەڕاوە','کۆی گەڕاوەکان','باڵانسی بەردەست','هۆکار','ئادمین / بەروار'],rows,r=>
    '<tr><td><b dir="ltr">'+esc(r.order_code||r.order_id)+'</b><small>'+balanceOwner(r.user_id)+'</small>'+
      '<details><summary>ناسنامەی تۆمارەکان</summary><small>مامەڵە: <span dir="ltr">'+esc(r.order_id)+'</span></small>'+
      '<small>گەڕاندنەوە: <span dir="ltr">'+esc(r.id)+'</span></small>'+
      '<small>تۆماری دارایی: <span dir="ltr">'+esc(r.journal_id)+'</span></small>'+
      '<small>داواکاری: <span dir="ltr">'+esc(r.request_key)+'</span></small></details></td>'+
    '<td><span class="balance-shortfall-amount">+'+balanceMoney(r.amount_iqd)+'</span>'+
      '<small>بڕی پێویستی ناردن: '+balanceMoney(r.expected_iqd)+'</small>'+
      '<small>دوای کەمکردنەوەی کۆی گەڕاوەکان: '+balanceMoney(Number(r.expected_iqd)-Number(r.refunded_after_iqd))+'</small></td>'+
    '<td><small>پێش: '+balanceMoney(r.refunded_before_iqd)+'</small><b>دوای: '+balanceMoney(r.refunded_after_iqd)+'</b></td>'+
    '<td><small>پێش: '+balanceMoney(r.balance_before_iqd)+'</small><b>دوای: '+balanceMoney(r.balance_after_iqd)+'</b></td>'+
    '<td><div class="balance-shortfall-note">'+esc(r.reason)+'</div>'+legacyReference(r)+'</td>'+
    '<td>'+balanceOwner(r.admin_id)+'<small dir="ltr">'+esc(r.admin_id)+'</small><small>'+balanceAuditTime(r.created_at)+'</small></td></tr>',
    'balance-shortfall-table');
}
function renderBalanceOrderShortfalls(rows){
  const details=document.getElementById('balanceShortfallOrderDetails');
  const out=document.getElementById('balanceShortfallOrderHistory');
  if(details)details.hidden=rows.length===0;
  if(out)out.innerHTML=balanceShortfallTable(rows);
}
function renderBalanceShortfallSuccess(refund){
  const out=document.getElementById('balanceShortfallSuccess');if(!out)return;
  if(!refund||typeof refund!=='object'){out.textContent='گەڕاندنەوەکە تۆمار کرا؛ وردەکاری لە مێژوودا بەردەستە.';return;}
  out.innerHTML='<b>'+balanceMoney(refund.amount_iqd)+' بۆ باڵانسی کڕیار گەڕێندرایەوە.</b>'+
    '<div>مامەڵە: <span dir="ltr">'+esc(refund.order_code||refund.order_id)+'</span></div>'+
    '<div>باڵانس پێش تۆمارکردن: '+balanceMoney(refund.balance_before_iqd)+' · دوای: '+balanceMoney(refund.balance_after_iqd)+'</div>'+
    '<div>کۆی گەڕاوەکانی مامەڵە: '+balanceMoney(refund.refunded_after_iqd)+'</div>'+
    '<div>تۆماری دارایی: <span dir="ltr">'+esc(refund.journal_id)+'</span></div>'+
    '<div>'+balanceAuditTime(refund.created_at)+'</div>';
}
async function loadBalanceAdmin(){
  try{
    _balanceAdminData=await adminApiRequest('balance_dashboard');
    const d=_balanceAdminData,balances=d.balances||[],refunds=d.refunds||[],shortfalls=d.shortfalls||[],payouts=d.payouts||[],alerts=d.alerts||[];
    const total=balances.reduce((sum,r)=>sum+Number(r.available_iqd||0),0);
    const held=balances.reduce((sum,r)=>sum+Number(r.held_iqd||0),0);
    document.getElementById('balanceAdminStats').innerHTML=
      '<div class="ex-note"><b>باڵانسی بەردەست: '+balanceMoney(total)+'</b></div>'+
      '<div class="ex-note"><b>لە چاوەڕوانیدا: '+balanceMoney(held)+'</b></div>'+
      '<div class="ex-note"><b>ڕیفاوندەکان: '+refunds.length+'</b></div>'+
      '<div class="ex-note"><b>تۆماری کەم نێردراوی پیشاندراو: '+shortfalls.length+'</b></div>'+
      '<div class="ex-note"><b>داواکارییە چاوەڕوانەکان: '+payouts.filter(p=>p.status==='pending'||p.status==='processing').length+'</b></div>'+
      '<div class="ex-note"><b>ناردنی باڵانس: '+(d.config?.payouts_enabled?'چالاک (پەسەندکردنی دەستی)':'ناچالاک تا پشکنینی یاسایی')+'</b></div>';
    const rec=d.reconciliation||{};
    const discrepancies=Number(rec.unbalanced_journals||0)+Number(rec.balance_mismatches||0)+
      Number(rec.held_payout_mismatches||0)+Number(rec.unlinked_refunds||0)+
      Number(rec.unlinked_shortfalls||0)+Number(rec.shortfall_amount_mismatches||0)+
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
    const shortfallList=document.getElementById('balanceShortfallList');
    if(shortfallList)shortfallList.innerHTML=balanceShortfallTable(shortfalls);
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
  ++_balanceLookupSequence;_balanceLookupPending=false;
  _balanceChosenOrder=null;_balanceLookupResult=null;
  document.getElementById('balanceFoundOrder').textContent='مامەڵەی پشتڕاستکراوە هەڵنەبژێردراوە';
  const eligibility=document.getElementById('balanceShortfallEligibility');
  if(eligibility)eligibility.textContent='سەرەتا مامەڵەیەکی پەسەندکراو هەڵبژێرە.';
  const details=document.getElementById('balanceShortfallOrderDetails');if(details)details.hidden=true;
  const history=document.getElementById('balanceShortfallOrderHistory');if(history)history.textContent='';
  renderBalanceShortfallPreview();balanceSetControls();
}
document.getElementById('balanceOrderSearch')?.addEventListener('input',()=>{
  if(_balanceShortfallBusy||_balanceRefundBusy)return;
  balanceClearShortfallDraft();balanceResetChosen();
});
document.getElementById('balanceOrderSearch')?.addEventListener('keydown',event=>{
  if(event.key==='Enter'){event.preventDefault();lookupBalanceOrder();}
});
document.getElementById('balanceShortfallForm')?.addEventListener('input',()=>{
  if(_balanceShortfallBusy)return;
  document.getElementById('balanceShortfallError').textContent='';
  document.getElementById('balanceShortfallSuccess').textContent='';
  renderBalanceShortfallPreview();balanceSetControls();
});
async function openOrderRefund(id){
  if(_balanceShortfallBusy||_balanceRefundBusy)return;
  const order=allOrders.find(o=>String(o.id)===String(id));
  closeMo('moOrderDetail');goPage('balance');
  balanceClearShortfallDraft();
  document.getElementById('balanceOrderSearch').value=order?.order_code||id;
  document.getElementById('balanceFundsVerified').checked=false;
  document.getElementById('balanceBankReference').value='';
  document.getElementById('balanceRefundReason').value='';
  await lookupBalanceOrder();
}
async function openOrderShortfall(id){
  if(_balanceShortfallBusy||_balanceRefundBusy)return;
  if(!balanceCanRefund()){showToast('مۆڵەتی گەڕاندنەوەی پارەت نییە','rd');return;}
  const order=allOrders.find(o=>String(o.id)===String(id));
  closeMo('moOrderDetail');goPage('balance');
  balanceClearShortfallDraft();
  document.getElementById('balanceOrderSearch').value=order?.order_code||id;
  await lookupBalanceOrder();
  document.getElementById('balanceShortfallPanel')?.scrollIntoView({behavior:'smooth',block:'start'});
  if(balanceShortfallState()?.eligible)document.getElementById('balanceShortfallAmount')?.focus({preventScroll:true});
}
async function lookupBalanceOrder(allowDuringCredit=false){
  if((_balanceShortfallBusy||_balanceRefundBusy)&&allowDuringCredit!==true)return;
  balanceResetChosen();
  const sequence=_balanceLookupSequence;
  const out=document.getElementById('balanceFoundOrder');
  const err=document.getElementById('balanceRefundError');err.textContent='';
  const search=document.getElementById('balanceOrderSearch').value.trim();
  if(!search){err.textContent='ئایدی یان کۆدی مامەڵە بنووسە.';return;}
  _balanceLookupPending=true;balanceSetControls();out.textContent='مامەڵە بار دەکرێت...';
  try{
    const result=await adminApiRequest('balance_lookup_order',{search});
    if(sequence!==_balanceLookupSequence)return;
    const o=result.order,p=result.profile||{},owner=balanceShortfallAdminId();
    if(_balanceShortfallDraftOrderId!==o.id||_balanceShortfallDraftAdminId!==owner)balanceClearShortfallDraft();
    _balanceShortfallDraftOrderId=o.id;_balanceShortfallDraftAdminId=owner;
    _balanceShortfallNeedsRefresh=false;_balanceShortfallRecoveryError='';_balanceLookupResult=result;
    balanceRestoreShortfallRequest(o.id);
    const shortfall=balanceShortfallState();
    const eligible=!result.refund&&!(result.shortfalls||[]).length&&o.status!=='پەسەندکرا'&&!o.payout_receipt_url&&(!!o.receipt_url||!!o.balance_debit_journal_id)&&o.from_method!=='USDT'&&o.to_method!=='USDT';
    out.innerHTML='<div><b>'+esc(o.order_code||o.id)+'</b> — '+esc(p.full_name||p.email||o.user_id)+'</div>'+
      '<div>بڕی سەرەتایی: <b>'+balanceMoney(o.amount)+'</b> | '+esc(o.from_method)+' → '+esc(o.to_method)+'</div>'+
      '<div>بڕی پێویستی ناردن بۆ کڕیار: <b>'+balanceMoney(o.total)+'</b></div>'+
      '<div>بار: '+esc(o.status)+' | '+balanceDate(o.created_at)+'</div>'+
      '<div>'+(o.receipt_url?'<a target="_blank" rel="noopener noreferrer" href="'+esc(o.receipt_url)+'">بینینی پسووڵەی نێرەر</a>':o.balance_debit_journal_id?'کەمکردنەوە لە باڵانس: '+esc(o.balance_debit_journal_id):'بەبێ پسووڵە')+'</div>'+
      (result.refund?'<b style="color:#b91c1c">ئەم مامەڵەیە پێشتر ڕیفاوند کراوە.</b>':'')+
      (!eligible&&!shortfall?.eligible?'<div style="color:#b91c1c">ئەم مامەڵەیە ئێستا بۆ گەڕاندنەوەی پارە گونجاو نییە.</div>':'');
    _balanceChosenOrder=eligible?o:null;
    if(eligible&&o.balance_debit_journal_id)document.getElementById('balanceBankReference').value='balance-debit:'+o.balance_debit_journal_id;
    const eligibility=document.getElementById('balanceShortfallEligibility');
    if(eligibility)eligibility.textContent=!balanceCanRefund()?'مۆڵەتی گەڕاندنەوەی پارەت نییە.':
      shortfall?.eligible?'زۆرترین بڕی گەڕاندنەوەی ماوە: '+balanceMoney(shortfall.remaining)+'؛ مامەڵەکە پەسەندکراو دەمێنێتەوە.':
      shortfall?.remaining===0&&shortfall?.refunded>0?'هەموو بڕی پێویستی ناردن پێشتر بۆ باڵانس گەڕاوەتەوە.':
      o.status!=='پەسەندکرا'?'ئەم کردارە بۆ مامەڵەی پەسەندکراوە.':
      o.from_method==='USDT'||o.to_method==='USDT'?'گەڕاندنەوەی بڕی کەم نێردراو تەنها بۆ مامەڵەکانی دینار بەردەستە.':
      'ئەم مامەڵەیە بۆ گەڕاندنەوەی بڕی کەم نێردراو گونجاو نییە؛ زانیارییەکان نوێ بکەرەوە.';
    const posted=(result.shortfalls||[]).find(r=>r.request_key===_balanceShortfallRequest?.payload.request_key);
    if(posted&&balanceShortfallHasPending()){
      if(balanceForgetShortfallRequest())balanceClearShortfallDraft();
      renderBalanceShortfallSuccess(posted);
    }else if(balanceShortfallHasPending()&&!_balanceShortfallRecoveryError){
      document.getElementById('balanceShortfallError').textContent='داواکارییەکی پێشوو هەیە کە ئەنجامەکەی دڵنیا نییە. هەمان بڕ و هۆکار پارێزراون؛ پشتڕاست بکەرەوە و هەمان داواکاری بپشکنەرەوە.';
    }
    renderBalanceShortfallPreview();renderBalanceOrderShortfalls(result.shortfalls||[]);
  }catch(e){
    if(sequence!==_balanceLookupSequence)return;
    out.textContent='نەتوانرا مامەڵەکە بار بکرێت';err.textContent=e.message;
  }finally{
    if(sequence===_balanceLookupSequence){_balanceLookupPending=false;balanceSetControls();}
  }
}
async function creditVerifiedRefund(){
  if(_balanceShortfallBusy||_balanceRefundBusy)return;
  const err=document.getElementById('balanceRefundError');err.textContent='';
  if(!_balanceChosenOrder){err.textContent='سەرەتا مامەڵەیەکی گونجاو هەڵبژێرە';return;}
  const ref=document.getElementById('balanceBankReference').value.trim();
  const reason=document.getElementById('balanceRefundReason').value.trim();
  const confirmed_received=document.getElementById('balanceFundsVerified').checked;
  if(ref.length<6||reason.length<10||!confirmed_received){
    err.textContent='ژمارەی بەڵگە، هۆکاری گەڕاندنەوە و پشتڕاستکردنەوەی وەرگرتنی پارە پێویستن.';return;
  }
  if(!confirm('ئەم مامەڵەیە ڕەت بکرێتەوە و '+balanceMoney(_balanceChosenOrder.amount)+' بگەڕێتەوە بۆ باڵانسی کڕیار؟'))return;
  const orderId=_balanceChosenOrder.id;
  _balanceRefundBusy=true;balanceSetControls();
  try{
    await adminApiRequest('balance_credit_refund',{
      order_id:orderId,verification_reference:ref,reason,
      confirmed_received
    });
    showToast('ڕیفاوند و تۆماری دارایی بە سەرکەوتوویی ئەنجام درا','gr');
    document.getElementById('balanceBankReference').value='';
    document.getElementById('balanceRefundReason').value='';
    document.getElementById('balanceFundsVerified').checked=false;
    await lookupBalanceOrder(true);await loadBalanceAdmin();
  }catch(e){err.textContent=e.message;}
  finally{_balanceRefundBusy=false;balanceSetControls();}
}
async function creditOrderShortfall(event){
  event?.preventDefault();
  if(_balanceShortfallBusy||_balanceRefundBusy||_balanceLookupPending)return;
  const err=document.getElementById('balanceShortfallError');err.textContent='';
  const state=balanceShortfallState(),order=_balanceLookupResult?.order;
  if(!balanceCanRefund()){err.textContent='مۆڵەتی گەڕاندنەوەی پارەت نییە.';return;}
  if(_balanceShortfallRecoveryError){err.textContent=_balanceShortfallRecoveryError;return;}
  if(_balanceShortfallNeedsRefresh){err.textContent='سەرەتا «دۆزینەوە» دابگرە بۆ نوێکردنەوەی زانیاریی مامەڵە.';return;}
  const retry=balanceShortfallIsRetry();
  if(!state||!order||!balanceShortfallAdminId()||_balanceShortfallDraftAdminId!==balanceShortfallAdminId()||(!state.eligible&&!retry)){
    err.textContent='سەرەتا مامەڵەیەکی پەسەندکراو و گونجاو هەڵبژێرە.';return;
  }
  if(balanceShortfallHasPending()&&!retry){
    err.textContent='سەرەتا «دۆزینەوە» دابگرە و ئەنجامی هەمان داواکاریی پێشوو بپشکنە؛ بڕ و هۆکاری داواکاریی تەواونەکراو ناگۆڕدرێن.';return;
  }
  const amount=balanceWholeIqd(document.getElementById('balanceShortfallAmount').value);
  if(amount===null||(!retry&&amount>state.remaining)||!Number.isSafeInteger(state.available+amount)){
    err.textContent='بڕێکی تەواوی دینار بنووسە، لە 1 تا '+balanceMoney(Math.min(state.remaining,1000000000))+'.';return;
  }
  const reason=document.getElementById('balanceShortfallReason').value.trim();
  if(reason.length<10||reason.length>2000){err.textContent='هۆکاری ڕوون بنووسە (لە 10 تا 2,000 پیت).';return;}
  if(!document.getElementById('balanceShortfallConfirmed').checked){err.textContent='نەگەیشتنی ئەم بڕە بە کڕیار پشتڕاست بکەرەوە.';return;}
  const payload=balanceShortfallFormPayload();
  const fingerprint=JSON.stringify(payload);
  const p=_balanceLookupResult.profile||{};
  if(!confirm((retry?'هەمان داواکاری پێشوو دووبارە دەپشکنرێت؛ ئەگەر تۆمار کرابێت دووبارە باڵانس زیاد ناکرێت.\n':'')+
    'بۆ مامەڵەی '+(order.order_code||order.id)+'\n'+
    'کڕیار: '+(p.full_name||p.email||order.user_id)+'\n'+
    'بڕی گەڕاندنەوە: '+balanceMoney(amount)+'\n'+
    'کۆی گەڕاوەکان دوای ئەم کردارە: '+balanceMoney((retry?_balanceShortfallRequest.payload.expected_refunded_iqd:state.refunded)+amount)+'\n'+
    'باڵانسی ئێستا: '+balanceMoney(state.available)+'\n'+
    (retry?'':'باڵانسی پێشبینیکراو: '+balanceMoney(state.available+amount)+'\n')+
    'باری مامەڵە پەسەندکراو دەمێنێتەوە. گەڕاندنەوەکە تۆمار بکرێت؟'))return;
  const request=retry?_balanceShortfallRequest:{admin_id:balanceShortfallAdminId(),fingerprint,
    payload:{...payload,expected_refunded_iqd:state.refunded,request_key:crypto.randomUUID()}};
  try{
    // Save before sending: a reload must recover the same UUID and original baseline.
    balanceSaveShortfallRequest(request);_balanceShortfallRequest=request;
  }catch{
    _balanceShortfallRecoveryError=balanceShortfallStorageError();
    err.textContent=_balanceShortfallRecoveryError;balanceSetControls();return;
  }
  _balanceShortfallBusy=true;balanceSetControls();
  document.getElementById('balanceShortfallSuccess').textContent='';
  try{
    const refund=await adminApiRequest('balance_credit_shortfall',_balanceShortfallRequest.payload);
    if(balanceForgetShortfallRequest())balanceClearShortfallDraft();
    await lookupBalanceOrder(true);await loadBalanceAdmin();
    showToast('بڕی کەم نێردراو بۆ باڵانسی کڕیار گەڕێندرایەوە و تۆمار کرا','gr');
    renderBalanceShortfallSuccess(refund);
  }catch(e){
    if(e.status===409&&e.code==='shortfall_stale'){
      _balanceShortfallNeedsRefresh=true;balanceForgetShortfallRequest();
      document.getElementById('balanceShortfallConfirmed').checked=false;
      err.textContent='زانیاریی گەڕاندنەوەی ئەم مامەڵەیە گۆڕاوە. «دۆزینەوە» دابگرە، بڕە نوێیەکان بپشکنە و دووبارە پشتڕاست بکەرەوە.';
    }else if(!retry&&e.status===400&&['invalid_order','invalid_request_key','invalid_amount','invalid_refund_snapshot',
      'confirmation_required','invalid_reason','invalid_evidence'].includes(e.code)){
      // A first-attempt API rejection cannot have credited funds. A retry may
      // follow an earlier committed request, so keep its frozen payload instead.
      balanceForgetShortfallRequest();
      document.getElementById('balanceShortfallConfirmed').checked=false;
      err.textContent=e.message;
    }else{
      err.textContent=e.message||'نەتوانرا گەڕاندنەوەکە تۆمار بکرێت.';
      if(!e.status||e.status>=500)err.textContent+=' بۆ دووبارە هەوڵدان، هەمان زانیاری بەکاربهێنە.';
    }
  }finally{_balanceShortfallBusy=false;balanceSetControls();}
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
