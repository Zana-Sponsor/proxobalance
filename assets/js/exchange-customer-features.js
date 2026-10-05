/* Private customer conveniences; price/order submission remains in app.js. */
'use strict';
let _customerFeatureOwner=null,_customerFeatureLoad=0,_savedRecipients=[];
let _walletBadgeSeen=new Set(),_walletBadgeObserver=null,_recipientEditing=null;
function resetCustomerConveniences(){
 ++_customerFeatureLoad;_customerFeatureOwner=null;_savedRecipients=[];_walletBadgeSeen.clear();
 _walletBadgeObserver?.disconnect();_walletBadgeObserver=null;_recipientEditing=null;
 const list=document.getElementById('savedRecipientList');if(list)list.innerHTML='';
 const sheet=document.getElementById('recipientSheet');if(sheet)closeSheet(sheet);
}
async function loadCustomerConveniences(){
 const owner=curUser?.id,generation=++_customerFeatureLoad;
 if(!owner||!sb){resetCustomerConveniences();return;}
 if(_customerFeatureOwner!==owner){_savedRecipients=[];_walletBadgeSeen=new Set();}
 _customerFeatureOwner=owner;
 const results=await Promise.allSettled([
  sb.from('ex_wallet_badge_views').select('wallet_id,badge_version').eq('user_id',owner),
  sb.from('ex_saved_recipients').select('id,label,wallet_key,phone').eq('user_id',owner).order('label')
 ]);
 if(curUser?.id!==owner||generation!==_customerFeatureLoad)return;
 const views=results[0],recipients=results[1];
 if(views.status==='fulfilled'&&!views.value.error)
  _walletBadgeSeen=new Set((views.value.data||[]).map(v=>v.wallet_id+':'+v.badge_version));
 if(recipients.status==='fulfilled'&&!recipients.value.error)_savedRecipients=recipients.value.data||[];
 renderSavedRecipients();
}
function walletBadgeHTML(key){
 const w=WALLET_DATA[key];if(!w)return '';
 const labels={popular:'باو',most_popular:'باوترین',new:'نوێ'},label=labels[w.badge];
 if(!label||(w.badge==='new'&&(!curUser||_walletBadgeSeen.has(w.id+':'+w.badge_version))))return '';
 return '<span class="wallet-feature-badge badge-'+w.badge+'"'+
  (w.badge==='new'?' data-new-wallet="'+escHtml(key)+'"':'')+'>'+label+'</span>';
}
function observeWalletBadges(){
 _walletBadgeObserver?.disconnect();
 const owner=curUser?.id;if(!owner||typeof IntersectionObserver==='undefined')return;
 _walletBadgeObserver=new IntersectionObserver(entries=>{
  for(const entry of entries){
   if(!entry.isIntersecting||entry.intersectionRatio<.5||curUser?.id!==owner)continue;
   _walletBadgeObserver.unobserve(entry.target);
   markWalletBadgeSeen(entry.target.dataset.newWallet,owner);
  }
 },{root:document.getElementById('pickerSheetBody'),threshold:.5});
 document.querySelectorAll('#pickerSheetBody [data-new-wallet]').forEach(el=>_walletBadgeObserver.observe(el));
}
async function markWalletBadgeSeen(key,owner=curUser?.id){
 const w=WALLET_DATA[key];if(!w||w.badge!=='new'||!owner||curUser?.id!==owner)return;
 const seenKey=w.id+':'+w.badge_version;
 if(_walletBadgeSeen.has(seenKey))return;
 _walletBadgeSeen.add(seenKey);
 try{
  const {error}=await sb.from('ex_wallet_badge_views').insert({user_id:owner,wallet_id:w.id,badge_version:w.badge_version});
  if(error&&error.code!=='23505')throw error;
 }catch(_){if(curUser?.id===owner)_walletBadgeSeen.delete(seenKey);}
 // Keep the badge visible during this visit; the next picker opening omits it.
}
async function refreshRewardAlerts(){
 if(!curUser||!sb)return;
 try{await sb.rpc('ex_refresh_reward_alerts');}catch(_){}
}
function openSavedRecipients(){
 if(!curUser)return;
 _recipientEditing=null;
 document.getElementById('recipientLabel').value='';
 document.getElementById('recipientWallet').value=document.getElementById('receiveVia').value;
 document.getElementById('recipientPhone').value=document.getElementById('userPhone').value;
 document.getElementById('recipientError').textContent='';
 renderRecipientWallets();renderSavedRecipients();
 openSheet(document.getElementById('recipientSheet'));
 loadCustomerConveniences();
}
function renderRecipientWallets(){
 const select=document.getElementById('recipientWallet');if(!select)return;
 const value=select.value||document.getElementById('receiveVia')?.value;
 select.innerHTML=RECEIVE_OPTIONS.map(key=>'<option value="'+escHtml(key)+'">'+escHtml(METHOD_META[key]?.label||key)+'</option>').join('');
 if(RECEIVE_OPTIONS.includes(value))select.value=value;
}
function recipientAvailable(r){
 const from=document.getElementById('from')?.value;
 return RECEIVE_OPTIONS.includes(r.wallet_key)&&!getWalletInfo(r.wallet_key).locked&&
  r.wallet_key!==from&&routeAllowed(from,r.wallet_key);
}
function renderSavedRecipients(){
 const list=document.getElementById('savedRecipientList');if(!list)return;
 if(_customerFeatureOwner!==curUser?.id){list.innerHTML='';return;}
 list.innerHTML=_savedRecipients.length?_savedRecipients.map(r=>
  '<article class="saved-recipient"><button type="button" class="recipient-select" onclick="chooseSavedRecipient(\''+escHtml(r.id)+'\')"'+
  (recipientAvailable(r)?'':' disabled')+'><strong>'+escHtml(r.label)+'</strong><span>'+
  escHtml(METHOD_META[r.wallet_key]?.label||r.wallet_key)+' · <b dir="ltr">'+escHtml(r.phone)+'</b></span>'+
  (recipientAvailable(r)?'':'<small>ئەم ڕێڕەوە ئێستا بەردەست نییە</small>')+'</button>'+
  '<div class="recipient-actions"><button type="button" onclick="editSavedRecipient(\''+escHtml(r.id)+'\')">دەستکاری</button>'+
  '<button type="button" onclick="deleteSavedRecipient(\''+escHtml(r.id)+'\')">سڕینەوە</button></div></article>'
 ).join(''):'<p class="xc-hint">هێشتا وەرگرێکت پاشەکەوت نەکردووە.</p>';
}
function chooseSavedRecipient(id){
 const r=_savedRecipients.find(r=>r.id===id);
 if(!r||!recipientAvailable(r)){showToast('ئەم ڕێڕەوە بەردەست نییە','warning');return;}
 document.getElementById('receiveVia').value=r.wallet_key;
 document.getElementById('userPhone').value=r.phone;
 _balanceOrderKey=null;clearFieldError('userPhone');updatePlaceholder();calc();
 closeSheet(document.getElementById('recipientSheet'));
}
function editSavedRecipient(id){
 const r=_savedRecipients.find(r=>r.id===id);if(!r)return;
 _recipientEditing=r.id;renderRecipientWallets();
 document.getElementById('recipientLabel').value=r.label;
 document.getElementById('recipientWallet').value=r.wallet_key;
 document.getElementById('recipientPhone').value=r.phone;
 document.getElementById('recipientLabel').focus();
}
async function saveRecipient(){
 const owner=curUser?.id;if(!owner)return;
 const label=document.getElementById('recipientLabel').value.trim();
 const wallet_key=document.getElementById('recipientWallet').value;
 const phone=document.getElementById('recipientPhone').value.replace(/\s+/g,'');
 const error=document.getElementById('recipientError');error.textContent='';
 if(!label||label.length>60||!RECEIVE_OPTIONS.includes(wallet_key)||
  !(wallet_key==='QiCard'?/^\d{6,32}$/:/^07\d{9}$/).test(phone)){
  error.textContent='ناو، جزدان و ژمارەی دروست بنووسە';return;
 }
 const button=document.getElementById('recipientSave');button.disabled=true;
 try{
  const existing=_recipientEditing||_savedRecipients.find(r=>r.wallet_key===wallet_key&&r.phone===phone)?.id;
  const query=existing?sb.from('ex_saved_recipients').update({label,wallet_key,phone}).eq('id',existing).eq('user_id',owner):
   sb.from('ex_saved_recipients').insert({user_id:owner,label,wallet_key,phone});
  const {error:dbError}=await query;if(dbError)throw dbError;
  if(curUser?.id!==owner)return;
  _recipientEditing=null;document.getElementById('recipientLabel').value='';
  await loadCustomerConveniences();showToast('وەرگر پاشەکەوتکرا','success');
 }catch(e){if(curUser?.id===owner)error.textContent=e.code==='23505'?'ئەم وەرگرە پێشتر پاشەکەوتکراوە':e.message;}
 finally{button.disabled=false;}
}
async function deleteSavedRecipient(id){
 const owner=curUser?.id;if(!owner||!_savedRecipients.some(r=>r.id===id))return;
 if(!window.confirm('ئایا ئەم وەرگرە پاشەکەوتکراوە دەسڕیتەوە؟'))return;
 const {error}=await sb.from('ex_saved_recipients').delete().eq('id',id).eq('user_id',owner);
 if(curUser?.id!==owner)return;
 if(error){showToast('نەتوانرا وەرگر بسڕدرێتەوە','error');return;}
 await loadCustomerConveniences();
}
