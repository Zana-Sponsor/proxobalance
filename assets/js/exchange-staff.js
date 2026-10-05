/* Staff UI mirrors database/server permissions; it is not the authorization gate. */
'use strict';
let adminStaffPermissions=null;
const STAFF_PERMISSION_LABELS={
 view:'بینینی زانیاری و ڕاپۆرت',approve_orders:'پەسەندکردن و ڕەتکردنەوەی مامەڵە',
 refunds:'گەڕاندنەوەی پارە بۆ باڵانس',manage_fees:'جزدان، نیشانەکان و حمولە',manage_rewards:'پاداشت و داشکاندن'
};
function staffCan(permission){
 return isSuperAdmin()||adminStaffPermissions==null||adminStaffPermissions.includes(permission);
}
function staffFullAdmin(){return isSuperAdmin()||adminStaffPermissions==null;}
function staffPageAllowed(page){
 if(staffFullAdmin())return true;
 const permission={dashboard:'view',orders:'view',accounts:'view',statistics:'view',profit:'view',
  balance:'view',wallets:'manage_fees',rates:'manage_fees',rewards:'manage_rewards'}[page];
 return !!permission&&staffCan(permission);
}
function applyStaffUI(){
 document.querySelectorAll('[data-super-admin-only]').forEach(el=>el.hidden=!isSuperAdmin());
 document.querySelectorAll('.sb-item[onclick]').forEach(el=>{
  const page=el.getAttribute('onclick').match(/goPage\('([^']+)'\)/)?.[1];
  if(page)el.hidden=!staffPageAllowed(page);
 });
 const actions={
  approveOrder:'approve_orders',showRejectReason:'approve_orders',confirmRejectOrder:'approve_orders',
  openOrderCorrectionRequest:'approve_orders',confirmOrderCorrectionRequest:'approve_orders',
  openOrderRefund:'refunds',creditVerifiedRefund:'refunds',cancelBalancePayout:'refunds',
  abortProcessingPayout:'refunds',claimBalancePayout:'approve_orders',reviewBalancePayout:'approve_orders',
  startBalancePayout:'approve_orders',completeBalancePayout:'approve_orders',saveUserReward:'manage_rewards',revokeUserReward:'manage_rewards',
  openWalletModal:'manage_fees',openWalletBadge:'manage_fees',saveWallet:'manage_fees',deleteWallet:'manage_fees',
  openRateModal:'manage_fees',saveRate:'manage_fees',deleteRate:'manage_fees',
  toggleBan:'full',openSetPasswordModal:'full',openCreateUserModal:'full',saveOrderNote:'approve_orders',
  sendNotification:'full',resolveBalanceRisk:'full'
 };
 document.querySelectorAll('[onclick]').forEach(el=>{
  const fn=el.getAttribute('onclick').match(/^\s*([A-Za-z_]\w*)\(/)?.[1],required=actions[fn];
  if(!required)return;
  const denied=required==='full'?!staffFullAdmin():!staffCan(required);
  el.classList.toggle('staff-action-denied',denied);
  if(denied){el.setAttribute('aria-disabled','true');el.setAttribute('title','مۆڵەتی ئەم کارەت نییە');}
 });
 document.querySelectorAll('input[onchange*="uploadPayoutReceiptDirect"]').forEach(input=>{
  input.disabled=!staffCan('approve_orders');
  input.closest('label')?.classList.toggle('staff-action-denied',input.disabled);
 });
}
function staffPermissionButton(a){
 if(!isSuperAdmin()||!a.is_admin||a.role==='super_admin'||a.id===adminUser?.id)return '';
 return '<button type="button" class="act-btn dark" onclick="openStaffPermissions(\''+esc(a.id)+'\')"><i class="fas fa-key"></i> دەسەڵاتەکان</button>';
}
async function openStaffDirectory(){
 if(!isSuperAdmin())return;
 if(!allAccounts.length)await loadAccounts();
 const candidates=allAccounts.filter(a=>a.is_admin&&a.role!=='super_admin'&&a.id!==adminUser?.id);
 document.getElementById('staffDirectoryList').innerHTML=candidates.length?candidates.map(a=>
  '<div class="staff-directory-row"><span>'+esc(a.full_name||a.email)+'</span>'+staffPermissionButton(a)+'</div>').join(''):
  '<p class="feature-help">هێشتا کارمەندی ئادمین نییە. لە هەژمارەکان، بۆ کەسێکی دیاریکراو «کردن بە ئادمین» هەڵبژێرە؛ پاشان دەتوانیت دەسەڵاتەکانی دیاری بکەیت.</p>';
 openMo('moStaffDirectory');
}
async function openStaffPermissions(id){
 if(!isSuperAdmin())return;
 const {data,error}=await sb.from('ex_profiles').select('id,full_name,email,role,is_admin,staff_permissions').eq('id',id).maybeSingle();
 if(error||!data||!data.is_admin||data.role==='super_admin'){showToast('نەتوانرا کارمەند بخوێندرێتەوە','rd');return;}
 closeMo('moStaffDirectory');document.getElementById('staffTarget').value=id;
 document.getElementById('staffTargetName').textContent=data.full_name||data.email;
 document.getElementById('staffFullAccess').checked=data.staff_permissions==null;
 document.getElementById('staffPermissionOptions').innerHTML=Object.entries(STAFF_PERMISSION_LABELS).map(([key,label])=>
  '<label class="staff-permission-row"><input type="checkbox" data-staff-permission="'+key+'" '+
  (data.staff_permissions?.includes(key)?'checked':'')+'> '+esc(label)+'</label>').join('');
 document.getElementById('staffPermissionError').textContent='';updateStaffPermissionForm();openMo('moStaffPermissions');
}
function updateStaffPermissionForm(){
 const full=document.getElementById('staffFullAccess').checked;
 document.querySelectorAll('[data-staff-permission]').forEach(input=>input.disabled=full);
}
async function saveStaffPermissions(){
 if(!isSuperAdmin())return;
 const id=document.getElementById('staffTarget').value,full=document.getElementById('staffFullAccess').checked;
 const selected=Array.from(document.querySelectorAll('[data-staff-permission]:checked'),el=>el.dataset.staffPermission);
 if(selected.length&&!selected.includes('view'))selected.unshift('view');
 const button=document.getElementById('staffPermissionSave');button.disabled=true;
 const {error}=await sb.rpc('ex_staff_set_permissions',{p_user_id:id,p_permissions:full?null:selected});
 button.disabled=false;
 if(error){document.getElementById('staffPermissionError').textContent=adminDbMessage(error);return;}
 showToast('دەسەڵاتەکان پاشەکەوتکران','gr');closeMo('moStaffPermissions');loadAccounts();
}
document.addEventListener('DOMContentLoaded',()=>{
 new MutationObserver(()=>applyStaffUI()).observe(document.body,{childList:true,subtree:true});
});
