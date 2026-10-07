/* Proxo Balance admin contracts: two-party, database-backed signature workflow. */
'use strict';
let _adminContracts=[];
let _contractChannel=null;
let _contractPadDirty=false;
let _contractPadDrawing=false;
let _contractPadCtx=null;
let _contractPadDpr=1;

function contractEsc(value){
  const s=String(value??'');
  if(typeof esc==='function') return esc(s);
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
function contractStatus(row){
  return row.owner_signature_data&&row.renter_signature_data?'done':'pending';
}
function contractRow(label,value,ltr=false){
  return '<div class="pb-c-row"><span class="pb-c-key">'+contractEsc(label)+'</span>'+
    '<span class="pb-c-val"'+(ltr?' dir="ltr"':'')+'>'+contractEsc(value)+'</span></div>';
}
function contractPartyCard(row,side){
  const owner=side==='owner';
  const name=owner?row.owner_full_name:row.renter_full_name;
  const role=owner?'خاوەن ماڵپەڕ':'بەکرێگر';
  const sig=owner?row.owner_signature_data:row.renter_signature_data;
  const signedAt=owner?row.owner_signed_at:row.renter_signed_at;
  const ownId=owner?row.owner_admin_id:row.renter_admin_id;
  const otherSig=owner?row.renter_signature_data:row.owner_signature_data;
  const isMine=String(adminUser?.id||'')===String(ownId||'');
  const locked=!!(row.owner_signature_data&&row.renter_signature_data);
  let action='';
  if(isMine&&!locked){
    const label=sig?'گۆڕینی واژوو':'واژوو بکە';
    action='<button type="button" class="act-btn dark pb-c-sign-action" onclick="openContractSignature(\''+
      contractEsc(row.id)+'\',\''+side+'\')"><i class="fas fa-signature"></i> '+label+'</button>';
  }
  return '<div class="pb-c-sign-card">'+
    '<div class="pb-c-sign-role">'+role+'</div>'+
    '<div class="pb-c-sign-name">'+contractEsc(name)+'</div>'+
    (sig?'<img class="pb-c-sign-img" alt="واژوو" src="'+sig+'">':'<div class="pb-c-sign-empty">هێشتا واژوو نەکراوە</div>')+
    '<div class="pb-c-sign-time">'+(signedAt?'واژوو کرا: '+contractWhen(signedAt):(isMine?'واژووی تۆ چاوەڕوانە':'چاوەڕوانی واژوو'))+'</div>'+
    action+
  '</div>';
}
function contractDocument(row){
  const terms=Array.isArray(row.terms)?row.terms:[];
  const done=contractStatus(row)==='done';
  return '<section class="contract-shell" data-contract-shell="'+contractEsc(row.id)+'">'+
    '<div class="contract-shell-top">'+
      '<span class="contract-status '+(done?'done':'pending')+'"><i class="fas '+(done?'fa-circle-check':'fa-clock')+'"></i> '+(done?'واژووی هەردوو لایەن تەواوە':'چاوەڕوانی واژوو')+'</span>'+
      '<div class="contract-toolbar">'+
        '<button type="button" class="act-btn cy" onclick="printAdminContract(\''+contractEsc(row.id)+'\')"><i class="fas fa-file-pdf"></i> چاپ / PDF</button>'+
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
      '</section>'+
      '<section class="pb-c-section"><h3>لایەنەکانی گرێبەست</h3>'+
        contractRow('خاوەن',row.owner_full_name)+
        contractRow('بەکرێگر',row.renter_full_name)+
      '</section>'+
      '<section class="pb-c-section"><h3>خاڵ و مەرجەکان</h3><ol class="pb-c-terms">'+
        terms.map(t=>'<li>'+contractEsc(t)+'</li>').join('')+
      '</ol></section>'+
      '<section class="pb-c-section"><h3>واژووی لایەنەکان</h3><div class="pb-c-signatures">'+
        contractPartyCard(row,'owner')+contractPartyCard(row,'renter')+
      '</div></section>'+
      '<p class="pb-c-footer">ئەم بەڵگەنامەیە لە سیستەمی پڕۆکسۆ باڵانس تۆمار کراوە. کات و واژووەکان لە داتابەیس پارێزراون و دوای واژووی هەردوو لایەن گرێبەست قوفڵ دەبێت.</p>'+
    '</article>'+
  '</section>';
}

async function loadContracts(){
  const wrap=document.getElementById('contractsWrap');
  if(!wrap||!sb||!adminUser)return;
  wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
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
    .on('postgres_changes',{event:'UPDATE',schema:'public',table:'ex_admin_contracts'},()=>{
      if(typeof _curPage!=='undefined'&&_curPage==='contracts')loadContracts();
    })
    .subscribe();
}
function getContractById(id){return _adminContracts.find(x=>String(x.id)===String(id));}

function openContractSignature(id,side){
  const row=getContractById(id);
  if(!row)return showToast('گرێبەستەکە نەدۆزرایەوە','rd');
  if(row.owner_signature_data&&row.renter_signature_data)return showToast('گرێبەستەکە قوفڵ کراوە','rd');
  const expected=side==='owner'?row.owner_admin_id:row.renter_admin_id;
  if(String(expected)!==String(adminUser?.id||''))return showToast('تەنها واژووی خۆت دەتوانیت تۆمار بکەیت','rd');
  document.getElementById('contractSignId').value=id;
  document.getElementById('contractSignSide').value=side;
  document.getElementById('contractSignName').textContent=side==='owner'?row.owner_full_name:row.renter_full_name;
  document.getElementById('contractSignError').textContent='';
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
  canvas.addEventListener('pointerup',end);canvas.addEventListener('pointercancel',end);canvas.addEventListener('pointerleave',e=>{if(e.buttons===0)_contractPadDrawing=false;});
}
async function saveContractSignature(){
  const id=document.getElementById('contractSignId').value;
  const side=document.getElementById('contractSignSide').value;
  const err=document.getElementById('contractSignError');
  if(!_contractPadDirty){err.textContent='تکایە سەرەتا واژوو بکە.';return;}
  const canvas=document.getElementById('contractSignatureCanvas');
  const data=canvas.toDataURL('image/png');
  if(data.length>340000){err.textContent='واژووەکە زۆر گەورەیە؛ تکایە پاکی بکەرەوە و دووبارە واژوو بکە.';return;}
  const btn=document.getElementById('contractSignSave');
  btn.disabled=true;err.textContent='';
  try{
    const payload=side==='owner'?{owner_signature_data:data}:{renter_signature_data:data};
    const {error}=await sb.from('ex_admin_contracts').update(payload).eq('id',id);
    if(error)throw error;
    closeMo('moContractSignature');
    showToast('واژووەکەت بە سەرکەوتوویی تۆمار کرا','gr');
    await loadContracts();
  }catch(e){
    console.error('Contract signature error',e);
    const msg=String(e.message||e);
    err.textContent=msg.includes('CONTRACT_LOCKED')?'گرێبەستەکە قوفڵ کراوە.':
      msg.includes('CANNOT_SIGN_FOR_OTHER_PARTY')?'ناتوانیت بۆ لایەنی تر واژوو بکەیت.':'هەڵەی تۆمارکردنی واژوو.';
  }finally{btn.disabled=false;}
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
    '<link rel="stylesheet" href="/assets/css/admin-contracts.css?v=1"></head>'+
    '<body class="contract-print-page">'+doc.outerHTML+
    '<script>window.addEventListener("load",function(){setTimeout(function(){window.focus();window.print();},180)});<\/script></body></html>');
  win.document.close();
}

document.addEventListener('DOMContentLoaded',()=>initContractPad());
