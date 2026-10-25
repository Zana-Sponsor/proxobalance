/* Proxo Balance admin contracts: acceptance, signatures and super-admin management. */
'use strict';

let _adminContracts=[];
let _contractAdmins=[];
let _contractChannel=null;
let _contractPadDirty=false;
let _contractPadDrawing=false;
let _contractPadCtx=null;
let _contractPadDpr=1;
let _contractExistingSignature=null;

const DEFAULT_CONTRACT_TERMS=[
  'ئەم گرێبەستە تایبەتە بە بەکرێدانی بەکارهێنانی ماڵپەڕی «پڕۆکسۆ باڵانس» بۆ ماوەی دیاریکراو.',
  'کرێ و ماوەی گرێبەست بەپێی زانیارییە تۆمارکراوەکانی سەرەوە دەبن.',
  'ماف و خاوەندارێتی ناوی ماڵپەڕ، دۆمەین، کۆد، داتابەیس و هەژمارە سەرەکییەکان لە لای خاوەنەکە دەمێنێتەوە، مەگەر بە نووسین بە شێوەیەکی تر ڕێککەوتبێت.',
  'بەکرێگر مافی فرۆشتن، گواستنەوە، سپاردنی دەستڕاگەیشتن یان گۆڕینی زانیارییە گرنگەکانی خاوەندارێتی بە کەسێکی سێیەم نییە بێ ڕەزامەندی نووسراوی خاوەن.',
  'بەکرێگر بەرپرسی بەکارهێنانی یاسایی و پاراستنی وشەی نهێنی و دەستڕاگەیشتنەکانی خۆیە.',
  'هەر گۆڕانکارییەکی مەترسیدار لە سیستەم، داتابەیس یان ڕێکخستنە سەرەکییەکان پێویستی بە ئاگادارکردنەوە و ڕەزامەندی خاوەن هەیە.',
  'لە کۆتایی ماوەکەدا، ئەگەر گرێبەست نوێ نەکرێتەوە، دەستڕاگەیشتنی بەکرێگر دەتوانرێت لەلایەن خاوەنەوە کۆتایی پێ بێت.',
  'نووسینی ناوی تەواو، واژوو و پەسەندکردنی «ڕازیم بە هەموو مەرج و ڕێساکان» لەلایەن هەر لایەنێکەوە واتای پەسەندکردنی ئەم گرێبەستەیە.',
  'ئەگەر ناوەڕۆکی گرێبەست دوای واژوو دەستکاری بکرێت، پەسەندکردن و واژووە پێشووەکان پووچەڵ دەبن و هەردوو لایەن دەبێت دووبارە پەسەندی بکەن.',
  'ئەم گرێبەستە خۆی بەڵگەی پارەدان نییە؛ تۆماری پارەدان، ئەگەر هەبێت، بەڵگەی جیاوازە.'
];

function contractEsc(value){
  const s=String(value??'');
  if(typeof esc==='function')return esc(s);
  return s.replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
}
function contractWhen(value){
  if(!value)return '—';
  try{
    return new Date(value).toLocaleString('ku-IQ',{
      timeZone:'Asia/Baghdad',year:'numeric',month:'2-digit',day:'2-digit',
      hour:'2-digit',minute:'2-digit'
    });
  }catch(_){return new Date(value).toLocaleString();}
}
function contractMoney(value){
  const n=Number(value);
  return (Number.isFinite(n)?Math.trunc(n).toLocaleString('en-US'):String(value||'—'))+' د.ع';
}
function contractComplete(row){
  return !!(row?.owner_signature_data&&row?.renter_signature_data&&
    row?.owner_terms_accepted&&row?.renter_terms_accepted);
}
function contractRow(label,value,ltr=false){
  return '<div class="pb-c-row"><span class="pb-c-key">'+contractEsc(label)+'</span>'+
    '<span class="pb-c-val"'+(ltr?' dir="ltr"':'')+'>'+contractEsc(value)+'</span></div>';
}
function contractRoleLabel(role){
  return role==='super_admin'?'سوپەر ئادمین':'ئادمین';
}
function contractAdminOption(a){
  const label=(a.full_name||a.email||'—')+' — '+contractRoleLabel(a.role);
  return '<option value="'+contractEsc(a.id)+'">'+contractEsc(label)+'</option>';
}
function contractLocalInput(value){
  const d=value?new Date(value):new Date();
  if(Number.isNaN(d.getTime()))return '';
  try{return d.toLocaleString('sv-SE',{timeZone:'Asia/Baghdad',hour12:false}).replace(' ','T').slice(0,16);}
  catch(_){return d.toISOString().slice(0,16);}
}
function contractNewNumber(){
  const d=new Date(),p=n=>String(n).padStart(2,'0');
  return 'PB-'+d.getFullYear()+p(d.getMonth()+1)+p(d.getDate())+'-'+p(d.getHours())+p(d.getMinutes())+p(d.getSeconds());
}
function contractPartyCard(row,side){
  const owner=side==='owner';
  const name=owner?row.owner_full_name:row.renter_full_name;
  const role=owner?'خاوەن ماڵپەڕ':'بەکرێگر';
  const sig=owner?row.owner_signature_data:row.renter_signature_data;
  const signedAt=owner?row.owner_signed_at:row.renter_signed_at;
  const accepted=owner?row.owner_terms_accepted:row.renter_terms_accepted;
  const acceptedAt=owner?row.owner_terms_accepted_at:row.renter_terms_accepted_at;
  const acceptedName=owner?row.owner_accepted_name:row.renter_accepted_name;
  const ownId=owner?row.owner_admin_id:row.renter_admin_id;
  const isMine=String(adminUser?.id||'')===String(ownId||'');
  let action='';
  if(isMine&&!accepted){
    action='<button type="button" class="act-btn dark pb-c-sign-action" onclick="openContractSignature(\''+
      contractEsc(row.id)+'\',\''+side+'\')"><i class="fas fa-signature"></i> '+
      (sig?'تەواوکردنی ڕازیبوون':'ناو، واژوو و ڕازیبوون')+'</button>';
  }
  const acceptance=accepted
    ?'<div class="pb-c-accepted"><i class="fas fa-circle-check"></i> ڕازیم بە هەموو مەرج و ڕێساکان</div>'
    :'<div class="pb-c-waiting"><i class="fas fa-clock"></i> چاوەڕوانی ڕازیبوون</div>';
  return '<div class="pb-c-sign-card">'+
    '<div class="pb-c-sign-role">'+role+'</div>'+
    '<div class="pb-c-sign-name">'+contractEsc(name)+'</div>'+
    (sig?'<img class="pb-c-sign-img" alt="واژوو" src="'+sig+'">':'<div class="pb-c-sign-empty">هێشتا واژوو نەکراوە</div>')+
    (acceptedName?'<div class="pb-c-written-name">ناوی نووسراو: <strong>'+contractEsc(acceptedName)+'</strong></div>':'')+
    acceptance+
    '<div class="pb-c-sign-time">'+(signedAt?'کاتی واژوو: '+contractWhen(signedAt):'')+
      (acceptedAt?'<br>کاتی ڕازیبوون: '+contractWhen(acceptedAt):'')+'</div>'+
    action+
  '</div>';
}
function contractDocument(row){
  const terms=Array.isArray(row.terms)?row.terms:[];
  const done=contractComplete(row);
  const superTools=(typeof isSuperAdmin==='function'&&isSuperAdmin())
    ?'<button type="button" class="act-btn dark" onclick="openContractEditor(\''+contractEsc(row.id)+'\')"><i class="fas fa-pen"></i> دەستکاری</button>'
    :'';
  const download=done
    ?'<button type="button" class="act-btn cy" onclick="downloadAdminContractPdf(\''+contractEsc(row.id)+'\')"><i class="fas fa-download"></i> داگرتنی PDF</button>'
    :'';
  return '<section class="contract-shell" data-contract-shell="'+contractEsc(row.id)+'">'+
    '<div class="contract-shell-top">'+
      '<span class="contract-status '+(done?'done':'pending')+'"><i class="fas '+(done?'fa-circle-check':'fa-clock')+'"></i> '+
        (done?'پەسەند و واژووی هەردوو لایەن تەواوە':'چاوەڕوانی ناو، واژوو و ڕازیبوون')+'</span>'+
      '<div class="contract-toolbar">'+download+
        '<button type="button" class="act-btn" onclick="printAdminContract(\''+contractEsc(row.id)+'\')"><i class="fas fa-print"></i> چاپ</button>'+
        superTools+
        '<button type="button" class="act-btn dark" onclick="loadContracts()"><i class="fas fa-rotate"></i> نوێکردنەوە</button>'+
      '</div>'+
    '</div>'+
    '<article class="pb-contract-print" id="contractDoc-'+contractEsc(row.id)+'">'+
      '<header class="pb-c-head"><h2>'+contractEsc(row.title)+'</h2><strong dir="ltr">Proxo</strong></header>'+
      '<section class="pb-c-section"><h3>زانیاری گرێبەست</h3>'+
        contractRow('ژمارەی گرێبەست',row.contract_number,true)+
        contractRow('ناوی ماڵپەڕ',row.website_name)+
        contractRow('کرێی مانگانە',contractMoney(row.monthly_rent),true)+
        contractRow('دەستپێکی ماوە',contractWhen(row.starts_at))+
        contractRow('کۆتایی ماوە',contractWhen(row.ends_at))+
        (row.completed_at?contractRow('کاتی تەواوبوونی گرێبەست',contractWhen(row.completed_at)):'')+
      '</section>'+
      '<section class="pb-c-section"><h3>لایەنەکانی گرێبەست</h3>'+
        contractRow('خاوەن',row.owner_full_name)+
        contractRow('بەکرێگر',row.renter_full_name)+
      '</section>'+
      '<section class="pb-c-section"><h3>خاڵ و مەرجەکان</h3><ol class="pb-c-terms">'+
        terms.map(t=>'<li>'+contractEsc(t)+'</li>').join('')+
      '</ol></section>'+
      '<section class="pb-c-section"><h3>ناو، واژوو و ڕازیبوونی لایەنەکان</h3><div class="pb-c-signatures">'+
        contractPartyCard(row,'owner')+contractPartyCard(row,'renter')+
      '</div></section>'+
      '<p class="pb-c-footer">ئەم بەڵگەنامەیە لە سیستەمی پڕۆکسۆ باڵانس تۆمار کراوە. ناو، واژوو، ڕازیبوون و کاتەکان لە داتابەیس پارێزراون. هەر گۆڕانکارییەک لە ناوەڕۆکی گرێبەست پێویستی بە پەسەندکردنەوەی نوێی هەردوو لایەن هەیە.</p>'+
    '</article>'+
  '</section>';
}

async function loadContractAdmins(){
  try{
    const {data,error}=await sb.from('ex_profiles')
      .select('id,full_name,email,role,is_admin,is_banned')
      .eq('is_admin',true)
      .eq('is_banned',false)
      .order('full_name',{ascending:true});
    if(error)throw error;
    _contractAdmins=(data||[]).filter(a=>a.is_admin);
    renderContractAdminRoster();
    return _contractAdmins;
  }catch(e){
    console.error('Contract admin list error',e);
    _contractAdmins=[];
    renderContractAdminRoster();
    return [];
  }
}
function renderContractAdminRoster(){
  const wrap=document.getElementById('contractAdminsWrap');
  if(!wrap)return;
  if(!_contractAdmins.length){
    wrap.innerHTML='<div class="contract-admin-empty">هیچ ئادمینێکی چالاک نەدۆزرایەوە</div>';
    return;
  }
  wrap.innerHTML=_contractAdmins.map(a=>
    '<div class="contract-admin-chip"><span class="contract-admin-avatar">'+contractEsc((a.full_name||a.email||'?')[0])+'</span>'+
    '<span><strong>'+contractEsc(a.full_name||a.email||'—')+'</strong><small>'+contractRoleLabel(a.role)+'</small></span></div>'
  ).join('');
}
async function loadContracts(){
  const wrap=document.getElementById('contractsWrap');
  if(!wrap||!sb||!adminUser)return;
  wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    await loadContractAdmins();
    const {data,error}=await sb.from('ex_admin_contracts').select('*').order('created_at',{ascending:false});
    if(error)throw error;
    _adminContracts=data||[];
    wrap.innerHTML=_adminContracts.length?_adminContracts.map(contractDocument).join(''):
      '<div class="empty"><i class="fas fa-file-signature"></i><p>هیچ گرێبەستێک بۆ ئەم هەژمارەیە نییە</p></div>';
    startContractRealtime();
  }catch(e){
    console.error('Contract load error',e);
    wrap.innerHTML='<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵەی بارکردنی گرێبەست</p></div>';
    showToast('هەڵەی بارکردنی گرێبەست: '+(e.message||e),'rd');
  }
}
function startContractRealtime(){
  if(_contractChannel||!sb)return;
  _contractChannel=sb.channel('ex_admin_contracts_panel')
    .on('postgres_changes',{event:'*',schema:'public',table:'ex_admin_contracts'},()=>{
      if(typeof _curPage!=='undefined'&&_curPage==='contracts')loadContracts();
    })
    .subscribe();
}
function getContractById(id){return _adminContracts.find(x=>String(x.id)===String(id));}

function openContractSignature(id,side){
  const row=getContractById(id);
  if(!row)return showToast('گرێبەستەکە نەدۆزرایەوە','rd');
  const owner=side==='owner';
  const expected=owner?row.owner_admin_id:row.renter_admin_id;
  const accepted=owner?row.owner_terms_accepted:row.renter_terms_accepted;
  const sig=owner?row.owner_signature_data:row.renter_signature_data;
  if(String(expected)!==String(adminUser?.id||''))return showToast('تەنها پەسەندکردنی خۆت دەتوانیت تۆمار بکەیت','rd');
  if(accepted)return showToast('تۆ پێشتر ئەم گرێبەستەت پەسەند کردووە','gr');

  document.getElementById('contractSignId').value=id;
  document.getElementById('contractSignSide').value=side;
  document.getElementById('contractSignName').textContent=owner?row.owner_full_name:row.renter_full_name;
  document.getElementById('contractSignerTypedName').value='';
  document.getElementById('contractTermsAccepted').checked=false;
  document.getElementById('contractSignError').textContent='';
  _contractExistingSignature=sig||null;

  const existingWrap=document.getElementById('contractExistingSignatureWrap');
  const existingImg=document.getElementById('contractExistingSignatureImg');
  if(existingWrap&&existingImg){
    existingWrap.hidden=!sig;
    if(sig)existingImg.src=sig;else existingImg.removeAttribute('src');
  }
  const hint=document.getElementById('contractSignatureHint');
  if(hint)hint.textContent=sig
    ?'واژووی پێشووت پارێزراوە. تەنها ناوی تەواوت بنووسە و ڕازیبوون پەسەند بکە؛ یان لە خوارەوە واژووی نوێ بکە.'
    :'بە پەنجە یان ماوس واژووت بکە، ناوی تەواوت بنووسە و ڕازیبوون پەسەند بکە.';
  openMo('moContractSignature');
  requestAnimationFrame(()=>resetContractPad());
}
function resetContractPad(){
  const canvas=document.getElementById('contractSignatureCanvas');
  if(!canvas)return;
  const rect=canvas.getBoundingClientRect();
  _contractPadDpr=Math.max(1,Math.min(2,window.devicePixelRatio||1));
  canvas.width=Math.max(1,Math.round(rect.width*_contractPadDpr));
  canvas.height=Math.max(1,Math.round(rect.height*_contractPadDpr));
  _contractPadCtx=canvas.getContext('2d');
  _contractPadCtx.setTransform(_contractPadDpr,0,0,_contractPadDpr,0,0);
  _contractPadCtx.clearRect(0,0,rect.width,rect.height);
  _contractPadCtx.strokeStyle='#111827';
  _contractPadCtx.lineWidth=2.3;
  _contractPadCtx.lineCap='round';
  _contractPadCtx.lineJoin='round';
  _contractPadDirty=false;
}
function contractPadPoint(event){
  const canvas=document.getElementById('contractSignatureCanvas');
  const rect=canvas.getBoundingClientRect();
  return {x:event.clientX-rect.left,y:event.clientY-rect.top};
}
function initContractPad(){
  const canvas=document.getElementById('contractSignatureCanvas');
  if(!canvas||canvas.dataset.bound)return;
  canvas.dataset.bound='1';
  canvas.addEventListener('pointerdown',e=>{
    e.preventDefault();canvas.setPointerCapture?.(e.pointerId);
    _contractPadDrawing=true;_contractPadDirty=true;
    const p=contractPadPoint(e);_contractPadCtx.beginPath();_contractPadCtx.moveTo(p.x,p.y);
  });
  canvas.addEventListener('pointermove',e=>{
    if(!_contractPadDrawing||!_contractPadCtx)return;
    e.preventDefault();const p=contractPadPoint(e);_contractPadCtx.lineTo(p.x,p.y);_contractPadCtx.stroke();
  });
  const end=e=>{if(!_contractPadDrawing)return;e.preventDefault();_contractPadDrawing=false;_contractPadCtx?.closePath();};
  canvas.addEventListener('pointerup',end);
  canvas.addEventListener('pointercancel',end);
  canvas.addEventListener('pointerleave',e=>{if(e.buttons===0)_contractPadDrawing=false;});
}
async function saveContractSignature(){
  const id=document.getElementById('contractSignId').value;
  const side=document.getElementById('contractSignSide').value;
  const typedName=document.getElementById('contractSignerTypedName').value.trim();
  const accepted=document.getElementById('contractTermsAccepted').checked;
  const err=document.getElementById('contractSignError');
  if(!typedName){err.textContent='تکایە ناوی تەواوی خۆت بنووسە.';return;}
  if(!accepted){err.textContent='پێویستە «ڕازیم بە هەموو مەرج و ڕێساکان» پەسەند بکەیت.';return;}
  if(!_contractPadDirty&&!_contractExistingSignature){err.textContent='تکایە واژوو بکە.';return;}

  const canvas=document.getElementById('contractSignatureCanvas');
  const signature=_contractPadDirty?canvas.toDataURL('image/png'):_contractExistingSignature;
  if(!signature||signature.length>340000){err.textContent='واژووەکە گونجاو نییە؛ تکایە دووبارە واژوو بکە.';return;}

  const btn=document.getElementById('contractSignSave');
  btn.disabled=true;err.textContent='';
  try{
    const payload=side==='owner'
      ?{owner_signature_data:signature,owner_accepted_name:typedName,owner_terms_accepted:true}
      :{renter_signature_data:signature,renter_accepted_name:typedName,renter_terms_accepted:true};
    const {error}=await sb.from('ex_admin_contracts').update(payload).eq('id',id);
    if(error)throw error;
    closeMo('moContractSignature');
    _contractExistingSignature=null;
    showToast('ناو، واژوو و ڕازیبوونەکەت تۆمار کرا','gr');
    await loadContracts();
  }catch(e){
    console.error('Contract acceptance error',e);
    const msg=String(e.message||e);
    err.textContent=msg.includes('SIGNER_NAME_MISMATCH')?'ناوی نووسراو دەبێت هەمان ناوی تەواوی هەژمارەکەت بێت.':
      msg.includes('PARTY_ALREADY_ACCEPTED')?'تۆ پێشتر ئەم گرێبەستەت پەسەند کردووە.':
      msg.includes('CANNOT_SIGN_FOR_OTHER_PARTY')?'ناتوانیت بۆ لایەنی تر واژوو یان ڕازیبوون تۆمار بکەیت.':
      msg.includes('TERMS_ACCEPTANCE_REQUIRED')?'پێویستە هەموو مەرج و ڕێساکان پەسەند بکەیت.':
      msg.includes('INVALID_SIGNATURE')?'واژووەکە گونجاو نییە.':'هەڵەی تۆمارکردنی گرێبەست.';
  }finally{btn.disabled=false;}
}

async function openContractEditor(id=null){
  if(typeof isSuperAdmin!=='function'||!isSuperAdmin())return showToast('تەنها سوپەر ئادمین دەتوانێت گرێبەست دروست یان دەستکاری بکات','rd');
  if(!_contractAdmins.length)await loadContractAdmins();
  if(_contractAdmins.length<2)return showToast('بۆ گرێبەست پێویستە لانیکەم دوو ئادمینی چالاک هەبن','rd');

  const row=id?getContractById(id):null;
  document.getElementById('contractEditId').value=row?.id||'';
  document.getElementById('contractEditorTitle').textContent=row?'دەستکاری گرێبەست':'گرێبەستی نوێ';
  document.getElementById('contractEditNumber').value=row?.contract_number||contractNewNumber();
  document.getElementById('contractEditTitle').value=row?.title||'گرێبەستی بەکرێدانی ماڵپەڕ';
  document.getElementById('contractEditWebsite').value=row?.website_name||'پڕۆکسۆ باڵانس';
  document.getElementById('contractEditRent').value=row?.monthly_rent||50000;

  const start=row?new Date(row.starts_at):new Date();
  const end=row?new Date(row.ends_at):new Date(start);
  if(!row)end.setMonth(end.getMonth()+1);
  document.getElementById('contractEditStart').value=contractLocalInput(start);
  document.getElementById('contractEditEnd').value=contractLocalInput(end);

  const owner=document.getElementById('contractEditOwner');
  const renter=document.getElementById('contractEditRenter');
  const options=_contractAdmins.map(contractAdminOption).join('');
  owner.innerHTML=options;renter.innerHTML=options;
  owner.value=row?.owner_admin_id||String(adminUser?.id||_contractAdmins[0].id);
  const fallbackRenter=_contractAdmins.find(a=>String(a.id)!==String(owner.value))?._id;
  renter.value=row?.renter_admin_id||(_contractAdmins.find(a=>String(a.id)!==String(owner.value))?.id||_contractAdmins[1].id);

  document.getElementById('contractEditTerms').value=(Array.isArray(row?.terms)?row.terms:DEFAULT_CONTRACT_TERMS).join('\n');
  document.getElementById('contractEditorError').textContent='';
  const warning=document.getElementById('contractEditorWarning');
  if(warning){
    warning.hidden=!row||!(row.owner_signature_data||row.renter_signature_data||row.owner_terms_accepted||row.renter_terms_accepted);
  }
  openMo('moContractEditor');
}
async function saveContractEditor(){
  if(typeof isSuperAdmin!=='function'||!isSuperAdmin())return;
  const id=document.getElementById('contractEditId').value;
  const number=document.getElementById('contractEditNumber').value.trim();
  const title=document.getElementById('contractEditTitle').value.trim();
  const website=document.getElementById('contractEditWebsite').value.trim();
  const rent=Number(document.getElementById('contractEditRent').value);
  const start=document.getElementById('contractEditStart').value;
  const end=document.getElementById('contractEditEnd').value;
  const owner=document.getElementById('contractEditOwner').value;
  const renter=document.getElementById('contractEditRenter').value;
  const terms=document.getElementById('contractEditTerms').value.split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
  const err=document.getElementById('contractEditorError');

  if(!number||!title||!website||!start||!end||!owner||!renter){err.textContent='تکایە هەموو خانە پێویستەکان پڕ بکەرەوە.';return;}
  if(owner===renter){err.textContent='خاوەن و بەکرێگر دەبێت دوو ئادمینی جیاواز بن.';return;}
  if(!Number.isFinite(rent)||rent<=0){err.textContent='کرێی مانگانە دەبێت ژمارەیەکی دروست بێت.';return;}
  if(new Date(end)<=new Date(start)){err.textContent='کۆتایی ماوە دەبێت دوای دەستپێک بێت.';return;}
  if(!terms.length){err.textContent='لانیکەم یەک خاڵی گرێبەست بنووسە.';return;}

  const payload={
    contract_number:number,title,website_name:website,monthly_rent:Math.trunc(rent),currency:'IQD',
    starts_at:new Date(start).toISOString(),ends_at:new Date(end).toISOString(),
    owner_admin_id:owner,renter_admin_id:renter,terms
  };
  const btn=document.getElementById('contractEditorSave');
  btn.disabled=true;err.textContent='';
  try{
    const result=id
      ?await sb.from('ex_admin_contracts').update(payload).eq('id',id).select('id').single()
      :await sb.from('ex_admin_contracts').insert(payload).select('id').single();
    if(result.error)throw result.error;
    closeMo('moContractEditor');
    showToast(id?'گرێبەستەکە نوێکرایەوە؛ پێویستە لایەنەکان دووبارە پەسەندی بکەن':'گرێبەستی نوێ دروست کرا','gr');
    await loadContracts();
  }catch(e){
    console.error('Contract editor error',e);
    const msg=String(e.message||e);
    err.textContent=msg.includes('duplicate key')||msg.includes('ex_admin_contracts_contract_number_key')
      ?'ژمارەی ئەم گرێبەستە پێشتر بەکارهاتووە.'
      :msg.includes('CONTRACT_PARTY_ADMIN_INVALID')?'هەردوو لایەن دەبێت ئادمینی چالاک و ناوی تەواویان هەبێت.'
      :msg.includes('SUPER_ADMIN_REQUIRED')?'تەنها سوپەر ئادمین مافی ئەم کارەی هەیە.'
      :'هەڵەی پاشەکەوتکردنی گرێبەست.';
  }finally{btn.disabled=false;}
}

async function downloadAdminContractPdf(id){
  const row=getContractById(id);
  if(!row||!contractComplete(row))return showToast('PDF تەنها دوای پەسەند و واژووی هەردوو لایەن دادەگیرێت','rd');
  const source=document.getElementById('contractDoc-'+id);
  if(!source||typeof html2canvas!=='function'||!window.jspdf?.jsPDF)return showToast('ئامرازی PDF ئامادە نییە؛ تکایە پەڕەکە نوێ بکەرەوە','rd');

  const clone=source.cloneNode(true);
  clone.classList.add('contract-export');
  clone.style.width='720px';
  clone.style.maxWidth='720px';
  clone.style.position='fixed';
  clone.style.left='-10000px';
  clone.style.top='0';
  clone.querySelectorAll('.pb-c-sign-action').forEach(el=>el.remove());
  document.body.appendChild(clone);
  try{
    if(document.fonts?.ready)await document.fonts.ready;
    const canvas=await html2canvas(clone,{scale:2,useCORS:true,backgroundColor:'#ffffff',logging:false});
    const img=canvas.toDataURL('image/jpeg',0.96);
    const {jsPDF}=window.jspdf;
    const pdf=new jsPDF({orientation:'portrait',unit:'mm',format:'a4'});
    const margin=10,pageW=210-margin*2,pageH=297-margin*2;
    const imgH=canvas.height*pageW/canvas.width;
    let offset=0,page=0;
    do{
      if(page>0)pdf.addPage();
      pdf.addImage(img,'JPEG',margin,margin-offset,pageW,imgH,undefined,'FAST');
      offset+=pageH;page++;
    }while(offset<imgH);
    const filename='Proxo-Contract-'+String(row.contract_number||row.id).replace(/[^A-Za-z0-9_-]/g,'-')+'.pdf';
    pdf.save(filename);
    showToast('PDF دابەزێنرا','gr');
  }catch(e){
    console.error('Contract PDF error',e);
    showToast('دروستکردنی PDF سەرکەوتوو نەبوو','rd');
  }finally{clone.remove();}
}

function printAdminContract(id){
  const doc=document.getElementById('contractDoc-'+id);
  if(!doc)return;
  const win=window.open('','_blank');
  if(!win){showToast('پەنجەرەی چاپ لەلایەن وێبگەڕەکەت بلۆک کراوە','rd');return;}
  const title=(getContractById(id)?.contract_number||'Proxo-Contract').replace(/[^A-Za-z0-9_-]/g,'-');
  win.document.open();
  win.document.write('<!doctype html><html lang="ku" dir="rtl"><head><meta charset="utf-8">'+
    '<meta name="viewport" content="width=device-width,initial-scale=1"><title>'+contractEsc(title)+'</title>'+
    '<link rel="stylesheet" href="/assets/css/admin-contracts.css?v=2"></head>'+
    '<body class="contract-print-page">'+doc.outerHTML+
    '<script>window.addEventListener("load",function(){setTimeout(function(){window.focus();window.print();},180)});<\/script></body></html>');
  win.document.close();
}

document.addEventListener('DOMContentLoaded',()=>initContractPad());
