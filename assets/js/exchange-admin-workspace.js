/* Focused wallet editor, route search and authenticated personal activity. */
'use strict';
function switchWalletSection(section){
 document.querySelectorAll('[data-wallet-section]').forEach(el=>el.hidden=el.dataset.walletSection!==section);
 document.querySelectorAll('[data-wallet-tab]').forEach(el=>{const selected=el.dataset.walletTab===section;el.classList.toggle('on',selected);el.setAttribute('aria-selected',String(selected));});
}
function openWalletRoutes(id){
 const row=allWallets.find(w=>w.id===id);if(!row)return;
 openWalletModal(row);switchWalletSection('routes');
}
function filteredAdminRates(){
 const needle=(document.getElementById('adminRateSearch')?.value||'').trim().toLowerCase();
 const state=document.getElementById('adminRateState')?.value||'all';
 return allRates.filter(r=>(state==='all'||r.is_active===(state==='active'))&&
  (!needle||[r.from_method,r.to_method,methodLabel(r.from_method),methodLabel(r.to_method)].join(' ').toLowerCase().includes(needle)));
}
function methodLabel(key){return allWallets.find(w=>w.key===key)?.name||METHOD_META[key]?.label||key;}
function filterAdminRates(){renderRates();if(typeof exRenderRateCards==='function')exRenderRateCards();}
function updateAdminRatePreview(){
 const el=document.getElementById('adminRatePreview');if(!el)return;
 const value=Number(document.getElementById('rateValue').value),type=document.getElementById('rateType').value;
 const amount=Number(document.getElementById('adminRateExample').value);
 if(!Number.isFinite(value)||value<0||!Number.isFinite(amount)||amount<=0){el.textContent='بەهای دروست بنووسە';return;}
 const receive=type==='fee_percent'?amount*(1-value/100):type==='fee_fixed'?amount-value:amount*value;
 el.textContent=methodLabel(document.getElementById('rateFrom').value)+' → '+methodLabel(document.getElementById('rateTo').value)+' : '+formatNum(amount)+' → '+formatNum(receive);
}
let monthlyActivityOwner=null;
async function loadMyMonthlyActivity(){
 const owner=adminUser?.id,el=document.getElementById('myMonthlyActivity');if(!owner||!el)return;
 monthlyActivityOwner=owner;
 try{
  const {data,error}=await sb.rpc('ex_staff_monthly_activity');if(error)throw error;
  if(adminUser?.id!==owner||monthlyActivityOwner!==owner)return;
  const cards=[['مامەڵە جێبەجێکراوەکانی من',data.handled_orders],['پەسەندکراوی من',data.approved_orders],['ڕەتکراوی من',data.rejected_orders],['قازانجی لێبڕینی من',formatNum(data.deduction_iqd)+' د.ع']];
  el.innerHTML=cards.map(([label,value])=>'<article class="my-activity-card"><span>'+esc(label)+'</span><b dir="ltr">'+esc(value)+'</b></article>').join('');
  document.getElementById('myMonthlyNote').textContent='ئەم مانگە بە کاتی بەغدا؛ تەنها مامەڵەی تۆمارکراو بە ناوی تۆ. قازانج = لێبڕینی مامەڵە پەسەندکراوەکان.'+(data.unrecorded_fees?' '+data.unrecorded_fees+' مامەڵەی دراوی جیاواز لە کۆی دیناردا نییە.':'');
 }catch(e){el.textContent=adminDbMessage(e);}
}
