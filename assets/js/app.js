// ══════════════════════════════════════════════════════════════
// ═══ ICONS (used for dynamically-injected UI) ═══════════════════
// ══════════════════════════════════════════════════════════════
const ICON = {
  spin: '<span class="icn icn-spin icon--solar icon--solar--refresh-linear" aria-hidden="true"></span>',
  arrowLeft: '<span class="icn icon--solar icon--solar--arrow-left-linear" aria-hidden="true"></span>',
  check: '<span class="icn icon--solar icon--solar--check-circle-linear" aria-hidden="true"></span>',
  send: '<span class="icn icon--solar icon--solar--plain-2-linear" aria-hidden="true"></span>',
  lock: '<span class="icn icon--solar icon--solar--lock-linear" aria-hidden="true"></span>',
  eye: '<svg viewBox="0 -960 960 960" fill="currentColor" aria-hidden="true"><path d="M480-320q75 0 127.5-52.5T660-500q0-75-52.5-127.5T480-680q-75 0-127.5 52.5T300-500q0 75 52.5 127.5T480-320Zm0-72q-45 0-76.5-31.5T372-500q0-45 31.5-76.5T480-608q45 0 76.5 31.5T588-500q0 45-31.5 76.5T480-392Zm0 192q-134 0-244.5-72T61-462q-5-9-7.5-18.5T51-500q0-10 2.5-19.5T61-538q64-118 174.5-190T480-800q134 0 244.5 72T899-538q5 9 7.5 18.5T909-500q0 10-2.5 19.5T899-462q-64 118-174.5 190T480-200Zm0-300Zm0 220q113 0 207.5-59.5T832-500q-50-101-144.5-160.5T480-720q-113 0-207.5 59.5T128-500q50 101 144.5 160.5T480-280Z"/></svg>',
  eyeOff: '<svg viewBox="0 -960 960 960" fill="currentColor" aria-hidden="true"><path d="M607-627q29 29 42.5 66t9.5 76q0 15-11 25.5T622-449q-15 0-25.5-10.5T586-485q5-26-3-50t-25-41q-17-17-41-26t-51-4q-15 0-25.5-11T430-643q0-15 10.5-25.5T466-679q38-4 75 9.5t66 42.5Zm-127-93q-19 0-37 1.5t-36 5.5q-17 3-30.5-5T358-742q-5-16 3.5-31t24.5-18q23-5 46.5-7t47.5-2q137 0 250.5 72T904-534q4 8 6 16.5t2 17.5q0 9-1.5 17.5T905-466q-18 40-44.5 75T802-327q-12 11-28 9t-26-16q-10-14-8.5-30.5T753-392q24-23 44-50t35-58q-50-101-144.5-160.5T480-720Zm0 520q-134 0-245-72.5T60-463q-5-8-7.5-17.5T50-500q0-10 2-19t7-18q20-40 46.5-76.5T166-680l-83-84q-11-12-10.5-28.5T84-820q11-11 28-11t28 11l680 680q11 11 11.5 27.5T820-84q-11 11-28 11t-28-11L624-222q-35 11-71 16.5t-73 5.5ZM222-624q-29 26-53 57t-41 67q50 101 144.5 160.5T480-280q20 0 39-2.5t39-5.5l-36-38q-11 3-21 4.5t-21 1.5q-75 0-127.5-52.5T300-500q0-11 1.5-21t4.5-21l-84-82Zm319 93Zm-151 75Z"/></svg>',
  sun: '<span class="icn icon--solar icon--solar--sun-linear" aria-hidden="true"></span>',
  moon: '<span class="icn icon--solar icon--solar--moon-linear" aria-hidden="true"></span>',
  swap: '<span class="icn icn-sm icon--solar icon--solar--transfer-horizontal-linear" aria-hidden="true"></span>',
  coins: '<span class="icn icn-sm icon--solar icon--solar--banknote-2-linear" aria-hidden="true"></span>',
  checkDouble: '<span class="icn icn-sm icon--solar icon--solar--check-read-linear" aria-hidden="true"></span>',
  phone: '<span class="icn icn-sm icon--solar icon--solar--phone-linear" aria-hidden="true"></span>',
  clock: '<span class="icn icn-sm icon--solar icon--solar--clock-circle-linear" aria-hidden="true"></span>',
  message: '<span class="icn icn-sm icon--solar icon--solar--chat-round-dots-linear" aria-hidden="true"></span>',
  warn: '<span class="icon--solar icon--solar--danger-triangle-linear" aria-hidden="true"></span>',
  cross: '<span class="icon--solar icon--solar--close-circle-linear" aria-hidden="true"></span>',
  info: '<span class="icon--solar icon--solar--info-circle-linear" aria-hidden="true"></span>',
  wifiOff: '<span class="icon--solar icon--solar--wi-fi-router-minimalistic-linear" aria-hidden="true"></span>',
  telegram: '<span class="icon--solar icon--solar--plain-2-linear" aria-hidden="true"></span>',
  whatsapp: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M12 2.2a9.8 9.8 0 0 0-8.4 14.8L2.2 21.8l4.9-1.3A9.8 9.8 0 1 0 12 2.2zm0 1.8a8 8 0 0 1 6.9 12l-.2.4.9 3.1-3.2-.9-.4.2a8 8 0 1 1-4-14.8zm-3.5 4.1c-.2 0-.5 0-.7.3-.2.3-.9.8-.9 2s.9 2.4 1 2.6c.1.2 1.8 2.9 4.5 4 2.2.9 2.7.7 3.2.6.5 0 1.6-.6 1.8-1.2.2-.6.2-1.2.2-1.3-.1-.1-.3-.2-.6-.4-.3-.1-1.6-.8-1.9-.9-.2-.1-.4-.1-.6.1-.2.3-.7.9-.9 1.1-.2.2-.3.2-.6.1-.3-.2-1.2-.5-2.3-1.5-.9-.7-1.4-1.7-1.6-2-.2-.3 0-.5.1-.6l.4-.5c.1-.2.2-.3.3-.5.1-.2 0-.4 0-.5C9.6 9 9 7.7 8.7 7.2c-.2-.5-.4-.4-.6-.5h-.5z"/></svg>',
  receive: '<span class="icn icn-sm icon--solar icon--solar--download-minimalistic-linear" aria-hidden="true"></span>',
  image: '<span class="icn icon--solar icon--solar--gallery-linear" aria-hidden="true"></span>',
  banknote: '<span class="icn icn-sm icon--solar icon--solar--banknote-linear" aria-hidden="true"></span>',
  wallet: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M4 5h14v3M4 5a2 2 0 0 0-2 2v12h20V8H4a1.5 1.5 0 0 1 0-3Z"/><path d="M22 12h-6v4h6"/><circle cx="18" cy="14" r=".7"/></svg>'
};


// ══════════════════════════════════════════════════════════════
// ═══ PAYMENT METHOD META (drives pickers, wallet row, icons) ═══
// ══════════════════════════════════════════════════════════════
// Wallets exist ONLY in the ex_wallets table (name, logo, rules). No wallet is
// named in this file; a wallet without a logo gets a colour and a plain glyph.
let METHOD_META = {};
let FROM_OPTIONS = [];
let RECEIVE_OPTIONS = [];
// 'loading' until ex_wallets answers, then 'ready' or 'error'
let WALLETS_STATE = 'loading';
// skeleton bar helper (assets/js/skeletons.js) — empty string if that file is missing
const _skb=(w,h,round)=>(window.PXS?window.PXS.bar(w,h,round):'');
// Palette + helpers so any wallet added later in the admin panel (with no
// hardcoded icon) still gets a distinct color and a sensible fallback icon.
const WALLET_PALETTE = ['#7c3aed','#0ea5a4','#2563eb','#e11d48','#f59e0b','#26a17b','#0891b2','#db2777','#65a30d','#9333ea'];
function colorForWalletKey(key){
  let h=0; for(let i=0;i<key.length;i++){ h=(h*31+key.charCodeAt(i))>>>0; }
  return WALLET_PALETTE[h % WALLET_PALETTE.length];
}
function escHtml(s){ return String(s==null?'':s).replace(/[&<>"']/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function safeWalletImageSrc(value){
  const raw=String(value||'').trim();
  if(!raw) return '';
  if(/^data:image\/(?:png|jpe?g|webp);base64,[A-Za-z0-9+/=\s]+$/i.test(raw)) return raw;
  try{
    if(raw.startsWith('/')) return new URL(raw, location.origin).href;
    const url=new URL(raw);
    return url.protocol==='https:' ? url.href : '';
  }catch(_){ return ''; }
}
// Rebuilds METHOD_META / FROM_OPTIONS / RECEIVE_OPTIONS from whatever rows
// currently exist in ex_wallets, so wallets added/edited/removed in the
// admin panel show up here immediately (via subscribeWalletsUser) without
// needing a code change or page reload.
function rebuildWalletOptions(){
  const rows = Object.keys(WALLET_DATA).map(k=>({ key:k, ...WALLET_DATA[k] })).filter(w=>w.key);
  rows.sort((a,b)=>(a.sort_order??0)-(b.sort_order??0));
  // An empty table means no wallets — never fall back to a built-in list.
  const newMeta = {};
  rows.forEach(w=>{
    newMeta[w.key] = {
      label: w.name || w.key,
      color: colorForWalletKey(w.key),
      icon: ICON.wallet,
      img: w.image_url || null
    };
  });
  METHOD_META = newMeta;
  FROM_OPTIONS = rows.filter(w=>w.allow_from!==false).map(w=>w.key);
  RECEIVE_OPTIONS = rows.filter(w=>w.allow_receive&&w.key!=='AccountBalance').map(w=>w.key);
  syncNativeSelect('from', FROM_OPTIONS);
  syncNativeSelect('receiveVia', RECEIVE_OPTIONS);
}
function syncNativeSelect(id, opts){
  const sel = document.getElementById(id); if(!sel) return;
  const cur = sel.value;
  sel.innerHTML = opts.map(k=>`<option value="${escHtml(k)}">${escHtml(METHOD_META[k].label)}</option>`).join('');
  sel.value = opts.includes(cur) ? cur : (opts[0]||'');
}

function methodIconHTML(key, sizeClass, forceId){
  const m = METHOD_META[key]; if(!m) return '';
  const imageSrc=safeWalletImageSrc(m.img);
  const cls = 'method-icon'+(sizeClass?' '+sizeClass:'')+(imageSrc?' has-img':'');
  const idAttr = forceId ? ' id="'+escHtml(forceId)+'"' : '';
  const color=/^#[0-9a-f]{3,8}$/i.test(String(m.color||'')) ? String(m.color) : '#2563eb';
  const bgAttr = imageSrc ? '' : ' style="background:'+color+'"';
  const inner = imageSrc
    ? '<img src="'+escHtml(imageSrc)+'" alt="'+escHtml(m.label)+'">'
    : m.icon;
  return '<span class="'+cls+'"'+idAttr+bgAttr+'>'+inner+'</span>';
}
function refreshTrigger(which){
  const selId = which==='from' ? 'from' : 'receiveVia';
  const val = document.getElementById(selId).value;
  const m = METHOD_META[val];
  if(!m){
    const icon=document.getElementById(which+'TriggerIcon');
    const loading=WALLETS_STATE==='loading';
    if(icon) icon.outerHTML='<span class="method-icon'+(loading?' is-skel-ico':'')+'" id="'+which+'TriggerIcon"></span>';
    const lbl=document.getElementById(which+'TriggerLabel');
    if(lbl){ if(loading) lbl.innerHTML=_skb(76,12); else lbl.textContent='هیچ واڵێتێک بەردەست نییە'; }
    return;
  }
  document.getElementById(which+'TriggerIcon').outerHTML = methodIconHTML(val, '', which+'TriggerIcon');
  document.getElementById(which+'TriggerLabel').textContent = m.label;
}

// ══════════════════════════════════════════════════════════════
// ═══ SHEET OPEN/CLOSE HELPERS (fast, smooth, reliable transitions) ═
// ══════════════════════════════════════════════════════════════
const _sheetCloseTimers = new WeakMap();
function openSheet(overlay){
  const oldTimer=_sheetCloseTimers.get(overlay);
  if(oldTimer) clearTimeout(oldTimer);
  overlay.style.display='flex';
  overlay.setAttribute('aria-hidden','false');
  requestAnimationFrame(()=>overlay.classList.add('open'));
  document.body.style.overflow='hidden';
}
function closeSheet(overlay){
  overlay.classList.remove('open');
  overlay.setAttribute('aria-hidden','true');
  document.body.style.overflow='';
  const timer=setTimeout(()=>{
    if(!overlay.classList.contains('open')) overlay.style.display='none';
    _sheetCloseTimers.delete(overlay);
  },200);
  _sheetCloseTimers.set(overlay,timer);
}

// ══════════════════════════════════════════════════════════════
// ═══ METHOD PICKER SHEET ═══════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let _pickerContext=null;
function openPicker(which){
  _pickerContext = which;
  // The receive list holds only the destinations the admin has opened for the
  // wallet currently selected as the source. A closed direction is not offered.
  const fromVal = document.getElementById('from').value;
  const curVal = document.getElementById(which==='from'?'from':'receiveVia').value;
  // Show every wallet enabled for this direction. Availability is displayed
  // inside the sheet instead of silently removing wallets from the list.
  // This keeps the list complete and lets the user scroll through all entries.
  const opts = which==='from' ? FROM_OPTIONS : RECEIVE_OPTIONS;
  document.getElementById('pickerSheetTitle').textContent = which==='from' ? 'لە کوێوە دەنێریت' : 'وەرگرتن لە';
  const body = document.getElementById('pickerSheetBody');
  if(!opts.length){
    body.innerHTML = '<div class="picker-empty">هیچ واڵێتێک بۆ ئەم بەشە زیاد نەکراوە.</div>';
    openSheet(document.getElementById('pickerSheet'));
    return;
  }
  body.innerHTML = opts.map(key=>{
    const m = METHOD_META[key]; if(!m) return '';
    const sel = key===curVal;
    const walletLocked = getWalletInfo(key).locked;
    const sameWallet = which!=='from' && key===fromVal;
    const routeClosed = which!=='from' && !sameWallet && !routeAllowed(fromVal,key);
    const unavailable = walletLocked || sameWallet || routeClosed;
    const reason = walletLocked ? 'بەردەست نییە'
      : sameWallet ? 'هەمان واڵێت هەڵبژێردراوە'
      : routeClosed ? 'ئەم ڕێڕەوە داخراوە' : '';
    return '<button type="button" class="sheet-option'+(sel?' selected':'')+(unavailable?' locked-option':'')+'"'
      + (unavailable ? ' disabled' : ' onclick="selectPickerOption(\''+key+'\')"')
      + (which==='from' && key==='AccountBalance'?' id="accountBalanceSourceOption"':'')+'>'
      + methodIconHTML(key)
      + '<span class="sheet-option-text"><span class="sheet-option-name">'+escHtml(m.label)+'</span>'
      + (typeof walletBadgeHTML==='function'?walletBadgeHTML(key):'')
      + (key==='AccountBalance'?'<span class="sheet-option-sub">'+escHtml(document.getElementById('balanceAvailable')?.textContent||'—')+'</span>':reason?'<span class="sheet-option-sub">'+reason+'</span>':'')+'</span>'
      + '<span class="sheet-option-check"><span class="icn icn-sm icon--solar icon--solar--check-circle-linear" aria-hidden="true"></span></span>'
      + '</button>';
  }).join('');
  openSheet(document.getElementById('pickerSheet'));
  if(typeof observeWalletBadges==='function')observeWalletBadges();
}
function closePicker(){
  closeSheet(document.getElementById('pickerSheet'));
}
function selectPickerOption(value){
  const which=_pickerContext; if(!which) return;
  const selId = which==='from' ? 'from' : 'receiveVia';
  if(which==='from'||which==='receiveVia')_balanceOrderKey=null;
  document.getElementById(selId).value = value;
  refreshTrigger(which);
  closePicker();
  if(which==='from'){ updateWallet(); } else { updatePlaceholder(); calc(); }
}

// ══════════════════════════════════════════════════════════════
// ═══ TOASTS — showToast()/hideToast() live in /assets/js/proxo-toast.js
// ═══ (loaded before this file). Same call: showToast(message, type, title, opts)
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
// ═══ RESULT MODAL (success / error / warning — replaces alert()) ═
// ══════════════════════════════════════════════════════════════
function showResultModal(opts){
  const { tone='success', title='', message='', orderNumber=null, orderCode=null, primaryText='باشە', onPrimary=null, secondaryText=null, onSecondary=null } = opts;
  const icoMap = { success:ICON.check, error:ICON.cross, warning:ICON.warn };
  document.getElementById('resultIcoWrap').className = 'modal-ico-wrap '+tone;
  document.getElementById('resultIcoWrap').innerHTML = '<span class="icn icn-xl">'+(icoMap[tone]||ICON.info)+'</span>';
  document.getElementById('resultTitle').textContent = title;
  document.getElementById('resultMsg').textContent = message;
  const chip = document.getElementById('resultOrderChip');
  const shownCode = orderCode || (orderNumber!=null ? fmtOrderNo(orderNumber) : null);
  if(shownCode){ chip.style.display='inline-flex'; document.getElementById('resultOrderNum').textContent = fmtCode(shownCode); }
  else chip.style.display='none';
  const pBtn = document.getElementById('resultPrimaryBtn');
  pBtn.textContent = primaryText;
  pBtn.onclick = ()=>{ closeResultModal(); if(onPrimary) onPrimary(); };
  const sBtn = document.getElementById('resultSecondaryBtn');
  if(secondaryText){ sBtn.style.display='inline-flex'; sBtn.textContent=secondaryText; sBtn.onclick=()=>{ closeResultModal(); if(onSecondary) onSecondary(); }; }
  else sBtn.style.display='none';
  document.getElementById('resultModal').style.display='flex';
}
function closeResultModal(){ document.getElementById('resultModal').style.display='none'; }

// ══════════════════════════════════════════════════════════════
// ═══ INLINE FIELD ERRORS ════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
function setFieldError(inputId, msg){
  const inp=document.getElementById(inputId); const err=document.getElementById(inputId+'Error');
  if(inp) inp.classList.add('has-error');
  if(err){ err.innerHTML='<i class="fe-ico" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 7v6.2"/><path d="M12 17.2h.01"/></svg></i><span class="fe-txt">'+msg+'</span>'; err.setAttribute('role','alert'); err.classList.add('show'); }
}
function clearFieldError(inputId){
  const inp=document.getElementById(inputId); const err=document.getElementById(inputId+'Error');
  if(inp) inp.classList.remove('has-error');
  if(err){ err.classList.remove('show'); }
}
function clearAllOrderFieldErrors(){ ['amt','userSenderName','userSenderPhone','userPhone','fileInput'].forEach(clearFieldError); }

let _receiptFileSnapshot=null;
let _receiptFileSnapshotPromise=null;
let _receiptFileSnapshotToken=0;

async function readSelectedFileSnapshot(file){
  if(!file) throw new Error('FILE_READ_PERMISSION');
  try{
    // Read while the picker permission is fresh. Android document providers
    // can revoke the original File handle after the change event.
    const bytes=await file.arrayBuffer();
    if(file.size>0 && bytes.byteLength!==file.size) throw new Error('Incomplete file read');
    return {
      bytes,
      name:String(file.name||'receipt.jpg'),
      type:String(file.type||'image/jpeg'),
      size:Number(file.size||bytes.byteLength)
    };
  }catch(cause){
    const error=new Error('FILE_READ_PERMISSION');
    error.cause=cause;
    throw error;
  }
}

function onFileSelected(input){
  clearFieldError('fileInput');
  const file=input && input.files && input.files[0];
  const token=++_receiptFileSnapshotToken;
  _receiptFileSnapshot=null;
  _receiptFileSnapshotPromise=null;
  const name=document.getElementById('filePickerName');
  const meta=document.getElementById('filePickerMeta');
  const picker=document.querySelector('label[for="fileInput"].file-picker');
  if(!name || !meta || !picker) return;
  picker.classList.toggle('selected', !!file);
  name.textContent=file ? file.name : 'وێنەی پسووڵە هەڵبژێرە';
  meta.textContent=file ? ((file.size/1024/1024).toFixed(file.size>=1048576?1:2)+' MB') : 'JPG، PNG یان WEBP';
  if(file){
    _receiptFileSnapshotPromise=readSelectedFileSnapshot(file).then(snapshot=>{
      if(token!==_receiptFileSnapshotToken) return null;
      _receiptFileSnapshot=snapshot;
      return snapshot;
    }).catch(()=>{
      if(token===_receiptFileSnapshotToken){
        _receiptFileSnapshot=null;
        if(input) input.value='';
        picker.classList.remove('selected');
        name.textContent='وێنەی پسووڵە دووبارە هەڵبژێرە';
        meta.textContent='دەستگەیشتن بە وێنەکە نەکرا';
        setFieldError('fileInput','نەتوانرا وێنەکە بخوێندرێتەوە؛ تکایە لە Gallery یان Files دووبارە هەڵیبژێرە');
      }
      return null;
    });
  }
}

// ══════════════════════════════════════════════════════════════
// ═══ NOTIFICATIONS (ex_notifications table — bell / panel / bar) ═
// ══════════════════════════════════════════════════════════════
let _notifChannel=null, _notifItems=[];
function _notifKind(type){
  if(type==='order_approved') return 'ok';
  if(type==='order_rejected') return 'no';
  if(type==='order_status')   return 'upd';
  if(type==='support_case')   return 'upd';
  if(type==='kyc')            return 'upd';
  return 'msg';
}
function _notifIcon(type){
  const sv=inner=>'<svg class="pxi" viewBox="0 0 24 24" aria-hidden="true" focusable="false">'+inner+'</svg>';
  if(type==='order_approved') return sv('<circle cx="12" cy="12" r="9"/><path d="m8 12.5 2.8 2.8L16 9.5"/>');
  if(type==='order_rejected') return sv('<circle cx="12" cy="12" r="9"/><path d="m9 9 6 6m0-6-6 6"/>');
  if(type==='order_status')   return sv('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>');
  if(type==='support_case')   return sv('<path d="M21 12a9 9 0 0 1-13.2 8L3 21l1.1-4.6A9 9 0 1 1 21 12Z"/><path d="M8.5 12h.01M12 12h.01M15.5 12h.01"/>');
  if(type==='kyc')            return sv('<rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M6.2 15a3 3 0 0 1 5.6 0M15 10h3M15 14h3"/>');
  return sv('<path d="M10.3 21a2 2 0 0 0 3.4 0"/><path d="M3.3 15.3A1 1 0 0 0 4 17h16a1 1 0 0 0 .7-1.7C19.4 14 18 12.5 18 8A6 6 0 0 0 6 8c0 4.5-1.4 6-2.7 7.3"/>');
}
function _notifColor(type){
  const k=_notifKind(type);
  if(k==='ok')  return 'var(--success)';
  if(k==='no')  return 'var(--error)';
  if(k==='upd') return 'var(--info)';
  return 'var(--secondary)';
}
// "5 خولەک لەمەوپێش" — short, human, and much easier to scan than a full date
function timeAgo(iso){
  const t=new Date(iso).getTime(); if(!t) return '';
  const s=Math.max(1, Math.floor((Date.now()-t)/1000));
  if(s<60)    return 'ئێستا';
  const m=Math.floor(s/60);   if(m<60) return m+' خولەک لەمەوپێش';
  const h=Math.floor(m/60);   if(h<24) return h+' کاتژمێر لەمەوپێش';
  const d=Math.floor(h/24);   if(d<7)  return d+' ڕۆژ لەمەوپێش';
  return new Date(iso).toLocaleDateString('ku-IQ');
}
function dayKey(iso){ const d=new Date(iso); return d.getFullYear()+'-'+d.getMonth()+'-'+d.getDate(); }
function dayLabel(iso){
  const d=new Date(iso), now=new Date();
  const k=dayKey(iso), kNow=dayKey(now.toISOString());
  const y=new Date(now.getTime()-86400000);
  if(k===kNow) return 'ئەمڕۆ';
  if(k===dayKey(y.toISOString())) return 'دوێنێ';
  return d.toLocaleDateString('ku-IQ', {day:'numeric', month:'long'});
}

let _notifLoaded=false, _notifRetryTimer=null;
async function loadNotifications(){
  try{
    const {data,error}=await sb.from('ex_notifications').select('*').eq('user_id',curUser.id).order('created_at',{ascending:false}).limit(30);
    if(error || !Array.isArray(data)) throw error||new Error('NOTIFICATIONS_LOAD_FAILED');
    _notifItems = data;
    _notifLoaded = true;
  }catch(_){
    // keep the skeleton (or the last list) and try again shortly
    if(!_notifRetryTimer) _notifRetryTimer=setTimeout(()=>{ _notifRetryTimer=null; if(curUser) loadNotifications(); }, 8000);
    renderNotifPanel();
    return;
  }
  renderNotifPanel();
  updateNotifBadge();
  const latestUnread = _notifItems.find(n=>!n.is_read);
  if(latestUnread) showNotifBar(latestUnread); else hideNotifBar();

  if(_notifChannel){ try{ sb.removeChannel(_notifChannel); }catch(_){} }
  _notifChannel = sb.channel('ex_notifications_'+curUser.id)
    .on('postgres_changes',{event:'INSERT',schema:'public',table:'ex_notifications',filter:'user_id=eq.'+curUser.id}, (payload)=>{
      _notifItems.unshift(payload.new);
      renderNotifPanel(); updateNotifBadge(); showNotifBar(payload.new);
      // An admin requested / approved / rejected verification: refresh the badge live.
      if(payload.new && payload.new.type==='kyc') loadKycStatus(true);
    })
    .subscribe();
}

function updateNotifBadge(){
  const unread = _notifItems.filter(n=>!n.is_read).length;
  const b=document.getElementById('notifBadge');
  if(unread>0){ b.style.display='flex'; b.textContent = unread>9?'9+':String(unread); }
  else b.style.display='none';
  const head=document.getElementById('notifHeadCount');
  if(head){ head.style.display = unread>0 ? 'inline-flex' : 'none'; head.textContent = String(unread); }
}

// Titles/messages come from the database and may carry emoji or a long order code.
// notifClean() drops emoji, notifRich() puts order codes in their own left-to-right box so
// they do not scramble the Kurdish sentence around them, and notifSplit() pulls a
// «هۆکار: …» (reason) out of a message so it can be shown on its own line.
function notifClean(s){
  return String(s==null?'':s).replace(/[\p{Extended_Pictographic}\uFE0F\u200D]/gu,'').replace(/[ \t]{2,}/g,' ').trim();
}
function notifRich(s){
  return escHtml(notifClean(s)).replace(/\b[A-Z0-9]{8,}\b/g,'<bdi class="notif-code" dir="ltr">$&</bdi>').replace(/<\/bdi>\s+[-–—]\s+/g,'</bdi>: ');   // «CODE - status» -> «CODE: status»
}
function notifSplit(msg){
  const t=notifClean(msg);
  const m=t.match(/^([\s\S]*?)[\s.،؛:-]*هۆکار\s*:\s*([\s\S]+)$/);
  return m ? {main:m[1].trim(), reason:m[2].trim()} : {main:t, reason:''};
}

function renderNotifPanel(){
  const body=document.getElementById('notifPanelBody');
  if(!body) return;
  if(!_notifLoaded && !_notifItems.length){ body.innerHTML=window.PXS?PXS.notifItems(4):''; body.setAttribute('aria-busy','true'); return; }
  body.removeAttribute('aria-busy');
  if(!_notifItems.length){
    body.innerHTML='<div class="notif-empty">'
      + '<span class="icn">'+ICON.bellOff+'</span>'
      + 'هێشتا هیچ ئاگادارییەکت نییە<br>کاتێک دۆخی داواکارییەکەت بگۆڕێت لێرە دەریدەکەوێت'
      + '</div>';
    return;
  }
  let html='', lastDay='';
  _notifItems.forEach(n=>{
    const dk=dayKey(n.created_at);
    if(dk!==lastDay){ lastDay=dk; html += '<div class="notif-day">'+dayLabel(n.created_at)+'</div>'; }
    const k=_notifKind(n.type);
    const msg=notifSplit(n.message);
    html += '<button type="button" class="notif-item '+k+(n.is_read?'':' unread')+'" onclick="openNotifItem(\''+n.id+'\')">'
      + '<span class="notif-item-ico '+k+'">'+_notifIcon(n.type)+(n.is_read?'':'<span class="notif-unread-dot" aria-label="نەخوێندراوە"></span>')+'</span>'
      + '<span class="notif-item-text">'
        + '<span class="notif-item-title">'+notifRich(n.title)+'</span>'
        + (msg.main?'<span class="notif-item-msg">'+notifRich(msg.main)+'</span>':'')
        + (msg.reason?'<span class="notif-reason"><b>هۆکار</b><span>'+notifRich(msg.reason)+'</span></span>':'')
        + '<span class="notif-item-time">'+timeAgo(n.created_at)+'</span>'
      + '</span>'
      + '</button>';
  });
  body.innerHTML=html;
}

function positionNotifPanel(){
  const panel=document.getElementById('notifPanel');
  const bell=document.getElementById('notifBellBtn');
  if(!panel || !bell) return;
  panel.style.removeProperty('left');
  panel.style.removeProperty('right');
  panel.style.removeProperty('top');
  if(!window.matchMedia('(min-width:640px)').matches) return;
  const r=bell.getBoundingClientRect();
  const width=Math.min(390, window.innerWidth-32);
  const left=Math.max(16, Math.min(window.innerWidth-width-16, r.right-width));
  panel.style.left=left+'px';
  panel.style.right='auto';
  panel.style.top=Math.min(window.innerHeight-120, r.bottom+8)+'px';
}

function openNotifPanel(){
  const panel=document.getElementById('notifPanel');
  const bell=document.getElementById('notifBellBtn');
  if(!panel || panel.classList.contains('open')) return;
  positionNotifPanel();
  panel.classList.add('open');
  panel.setAttribute('aria-hidden','false');
  if(bell) bell.setAttribute('aria-expanded','true');
  const bd=document.getElementById('notifBackdrop'); if(bd) bd.classList.add('open');
  if(bd) bd.setAttribute('aria-hidden','false');
  if(window.matchMedia('(max-width:639px)').matches) document.body.style.overflow='hidden';
}
function closeNotifPanel(){
  const p=document.getElementById('notifPanel'); if(p) p.classList.remove('open');
  if(p) p.setAttribute('aria-hidden','true');
  const bell=document.getElementById('notifBellBtn'); if(bell) bell.setAttribute('aria-expanded','false');
  const bd=document.getElementById('notifBackdrop'); if(bd) bd.classList.remove('open');
  if(bd) bd.setAttribute('aria-hidden','true');
  document.body.style.overflow='';
}
function toggleNotifPanel(){
  const p=document.getElementById('notifPanel');
  if(p.classList.contains('open')) closeNotifPanel(); else openNotifPanel();
}
// Tapping a notification opens the order it belongs to, already filtered by its ID
async function openNotifItem(id){
  const item=_notifItems.find(n=>n.id===id);
  await markNotifRead(id);
  if(item && item.type==='kyc'){
    closeNotifPanel();
    navigate('profile');
    await loadKycStatus(true);
    return;
  }
  if(item && item.type==='support_case'){
    closeNotifPanel();
    navigate('support');
    await loadSupportCases();
    return;
  }
  if(item && item.order_id){
    const o=_orders.find(x=>x.id===item.order_id);
    if(o){
      closeNotifPanel();
      const box=document.getElementById('txSearch');
      _txQuery=orderCodeOf(o).toLowerCase(); if(box) box.value=orderCodeOf(o);
      const clr=document.getElementById('txSearchClear'); if(clr) clr.classList.add('show');
      navigate('transactions');
      if(o.status==='پێویستی بە ڕاستکردنەوەیە') openOrderCorrection(o.id);
      return;
    }
  }
  closeNotifPanel();
}
document.addEventListener('click',(e)=>{
  const panel=document.getElementById('notifPanel'); const bell=document.getElementById('notifBellBtn');
  if(!panel || !panel.classList.contains('open')) return;
  if(panel.contains(e.target) || (bell && bell.contains(e.target))) return;
  closeNotifPanel();
});
window.addEventListener('resize',()=>{
  const panel=document.getElementById('notifPanel');
  if(panel && panel.classList.contains('open')) positionNotifPanel();
},{passive:true});

async function markNotifRead(id){
  const item=_notifItems.find(n=>n.id===id); if(!item || item.is_read) return;
  item.is_read=true; renderNotifPanel(); updateNotifBadge();
  const bar=document.getElementById('notifBar');
  if(bar.dataset.id===id) hideNotifBar();
  try{ await sb.from('ex_notifications').update({is_read:true}).eq('id',id); }catch(_){}
}
async function markAllNotifsRead(){
  const unreadIds=_notifItems.filter(n=>!n.is_read).map(n=>n.id);
  if(!unreadIds.length) return;
  _notifItems.forEach(n=>n.is_read=true);
  renderNotifPanel(); updateNotifBadge(); hideNotifBar();
  try{ await sb.from('ex_notifications').update({is_read:true}).eq('user_id',curUser.id).eq('is_read',false); }catch(_){}
}

function showNotifBar(n){
  const bar=document.getElementById('notifBar');
  const kind=_notifKind(n.type);
  const ico=document.getElementById('notifBarIco');
  ico.className='notif-bar-ico '+kind;
  ico.style.background='';
  ico.innerHTML = _notifIcon(n.type);
  document.getElementById('notifBarTitle').textContent = notifClean(n.title);
  document.getElementById('notifBarMsg').textContent = notifClean(n.message);
  bar.className='notif-bar '+n.type;
  bar.style.display='flex';
  bar.dataset.id = n.id;
}
function hideNotifBar(){ const bar=document.getElementById('notifBar'); bar.style.display='none'; delete bar.dataset.id; }
async function dismissNotifBar(){
  const bar=document.getElementById('notifBar'); const id=bar.dataset.id;
  hideNotifBar();
  if(id) await markNotifRead(id);
}

// ══════════════════════════════════════════════════════════════
// ═══ THEME ═══════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
// The interface follows the phone's system setting (light / dark) and changes live when it does.
const _darkMQ = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
function applyTheme(){
  const dark = !!(_darkMQ && _darkMQ.matches);
  const root = document.documentElement;
  root.setAttribute('data-theme', dark ? 'dark' : 'light');
  root.style.colorScheme = dark ? 'dark' : 'light';
  const meta = document.getElementById('themeColorMeta');
  if(meta) meta.setAttribute('content', dark ? '#0b1220' : '#fafafa');
}
function toggleTheme(){ applyTheme(); }
if(_darkMQ){
  if(_darkMQ.addEventListener) _darkMQ.addEventListener('change', applyTheme);
  else if(_darkMQ.addListener) _darkMQ.addListener(applyTheme);
}

// ══════════════════════════════════════════════════════════════
// ═══ SUPABASE ════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════

// PROXO BALANCE now runs on its own dedicated Supabase project — fully separate
// auth.users from Proxo/other apps (no shared identity, no shared tables).
const SB_URL=atob('aHR0cHM6Ly9weWN4dXVnb2Jsa3NsdndlYnh1dS5zdXBhYmFzZS5jbw==');
const SB_KEY=atob('ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnBjM01pT2lKemRYQmhZbUZ6WlNJc0luSmxaaUk2SW5CNVkzaDFkV2R2WW14cmMyeDJkMlZpZUhWMUlpd2ljbTlzWlNJNkltRnViMjRpTENKcFlYUWlPakUzT0RZeU1UazNPVGtzSW1WNGNDSTZNakV3TVRjNU5UYzVPWDAuVlJSd3hubnVMc19XT1J1VlVPM29YM0NMeHJQdGdHX3Vld0lKYUdyem5fcw==');
let sb, curUser=null, curProfile=null, activeSession=null, RATES={};

// The text announcement banner (Firebase "announcement") was replaced in v53 by image
// banners from Supabase: assets/js/banners.js.

// One-time codes are sent and checked only by the server (/api/auth); the page never
// reads or checks a code itself.
let _otpEmail='', _otpPendingData=null, _otpTimer=null, _otpPurpose='login';

function togglePass(inputId,btn){
  const inp=document.getElementById(inputId); if(!inp||!btn) return;
  const show=inp.type==='password'; inp.type=show?'text':'password';
  const ic=btn.querySelector('.pass-eye-ico'); if(ic) ic.innerHTML=show?ICON.eyeOff:ICON.eye;
  btn.setAttribute('aria-pressed',String(show));
  btn.setAttribute('aria-label',show?'شاردنەوەی وشەی نهێنی':'پیشاندانی وشەی نهێنی');
}

// ══════════════════════════════════════════════════════════════
// ═══ AUTH STEP NAVIGATION ═══════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let authCurrentStep='email', _authEmail='', _authName='', _authIsNewUser=false;
let _authStepBusy=false, _authSubmitting=false, _authSignupChecking=false;
const AUTH_ROUTE_SET=new Set(['login','login/otp','signup','signup/otp','forgetpassword','forgetpassword/otp','newpassword']);

function blurAuthInput(){
  const active=document.activeElement,root=document.getElementById('authWrap');
  if(active&&root?.contains(active)&&/^(INPUT|TEXTAREA|SELECT)$/.test(active.tagName)) active.blur();
}
function _showStepMsg(id,text,type){ const el=document.getElementById(id); if(!el) return; el.textContent=text; el.className='amsg '+type; el.style.display='block'; }
let authRoute='login';
let _authRouteStack=[];
function authRouteFromLocation(){
  const relative=location.pathname.startsWith(BASE_PATH)?location.pathname.slice(BASE_PATH.length):location.pathname.replace(/^\/+/, '');
  const route=relative.replace(/^\/+|\/+$/g,'');
  return AUTH_ROUTE_SET.has(route)?route:null;
}
function authHref(route){ return BASE_PATH+route; }
function setAuthRoute(route,push=true,replace=false){
  if(!AUTH_ROUTE_SET.has(route)) route='login';
  const previous=authRoute;
  blurAuthInput();
  if((previous==='login/otp'||previous==='signup/otp')&&route!==previous){ clearInterval(_otpTimer); _otpPendingData=null; }
  if(previous==='forgetpassword/otp'&&route==='forgetpassword') clearInterval(_fpTimer);
  authRoute=route; authCurrentStep=route;
  if(route==='signup'||route==='signup/otp') _authIsNewUser=true;
  else if(route==='login'||route==='login/otp') _authIsNewUser=false;
  ['authStepEmail','authStepName','authStepPass','otpStep','forgotStep'].forEach(id=>{ const el=document.getElementById(id); if(el) el.style.display='none'; });
  const fpA=document.getElementById('fpStepA'),fpB=document.getElementById('fpStepB'),fpC=document.getElementById('fpStepC');
  if(fpA) fpA.style.display='none'; if(fpB) fpB.style.display='none'; if(fpC) fpC.style.display='none';
  let active=null;
  if(route==='login'){ active=document.getElementById('authStepEmail'); }
  else if(route==='signup'){ active=document.getElementById('authStepName'); }
  else if(route==='login/otp'||route==='signup/otp'){ active=document.getElementById('otpStep'); }
  else if(route==='forgetpassword'||route==='forgetpassword/otp'||route==='newpassword'){
    document.getElementById('forgotStep').style.display='block';
    active=route==='forgetpassword'?fpA:route==='forgetpassword/otp'?fpB:fpC;
  }
  if(active){ active.style.display='block'; active.classList.remove('auth-route-enter'); void active.offsetWidth; active.classList.add('auth-route-enter'); }
  const back=document.getElementById('authHeaderBack'); if(back) back.hidden=route==='login';
  const titles={login:'چوونەژوورەوە',signup:'دروستکردنی هەژمار','login/otp':'کۆدی چوونەژوورەوە','signup/otp':'کۆدی تۆمارکردن',forgetpassword:'گەڕاندنەوەی هەژمار','forgetpassword/otp':'کۆدی گەڕاندنەوە',newpassword:'وشەی نهێنیی نوێ'};
  document.title=(titles[route]||'چوونەژوورەوە')+' — Proxo';
  if(push){
    if(!_authRouteStack.length||_authRouteStack[_authRouteStack.length-1]!==previous) _authRouteStack=[previous];
    _authRouteStack.push(route);
    try{ history.pushState({authFlow:true,authRoute:route,authPreviousRoute:previous},'',authHref(route)); }catch(_){}
  }
  else if(replace){
    _authRouteStack=[route];
    try{ history.replaceState({authFlow:true,authRoute:route,authPreviousRoute:null},'',authHref(route)); }catch(_){}
  }
  else{
    const stackIndex=_authRouteStack.lastIndexOf(route);
    if(stackIndex>=0) _authRouteStack=_authRouteStack.slice(0,stackIndex+1);
    else{
      const state=history.state;
      const parent=state?.authFlow&&state.authRoute===route?state.authPreviousRoute:null;
      _authRouteStack=parent?[parent,route]:[route];
    }
  }
  syncAuthHeaderBack();
}
function authBackTo(route){
  const state=history.state;
  const hasKnownAuthParent=_authRouteStack.length>1&&_authRouteStack[_authRouteStack.length-2]===route;
  if(hasKnownAuthParent&&history.length>1&&state?.authFlow&&state.authRoute===authRoute&&state.authPreviousRoute===route){ history.back(); return; }
  setAuthRoute(route,false,true);
}
function goAuthStep(step){ setAuthRoute(step==='name'?'signup':'login',true); }
function showAmsg(t,c){
  const id=authRoute==='signup'?'authMsgSignup':'authMsg';
  const el=document.getElementById(id)||document.getElementById('authMsg');
  if(!el) return; el.textContent=t; el.className='amsg '+c; el.style.display='block';
}
function _authEmailOk(email){ return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email||'').trim()); }
function restoreAuthButton(buttonId){
  const btn=document.getElementById(buttonId); if(!btn) return;
  btn.disabled=false;
  if(buttonId==='signupSubmitBtn') btn.innerHTML='<span>دروستکردنی هەژمار</span> '+ICON.arrowLeft;
  else btn.innerHTML='<span id="authBtnTxt">چوونەژوورەوە</span> '+ICON.arrowLeft;
}
// ── Sign-in through /api/auth (e-mail or Iraqi number; password + code; remembered devices) ──
function pxIraqiPhone(value){
  let d=String(value??'').replace(/[٠-٩]/g,ch=>String(ch.charCodeAt(0)-1632)).replace(/[۰-۹]/g,ch=>String(ch.charCodeAt(0)-1776)).replace(/\D/g,'');
  if(d.startsWith('00964')) d=d.slice(5); else if(d.startsWith('964')) d=d.slice(3); else if(d.startsWith('0')) d=d.slice(1);
  return /^7[3-9]\d{8}$/.test(d)?'+964'+d:null;
}
// What the person typed → the key their remembered device is stored under.
function pxIdentifierKey(value){
  const raw=String(value||'').trim();
  return raw.includes('@')?raw.toLowerCase():(pxIraqiPhone(raw)||raw);
}
const PX_DEVICE_STORE='px_trusted_devices_v1';
function pxDeviceToken(identifier){
  try{ return (JSON.parse(localStorage.getItem(PX_DEVICE_STORE)||'{}'))[pxIdentifierKey(identifier)]||''; }catch(_){ return ''; }
}
function pxRememberDevice(identifier,token){
  if(!token) return;
  try{ const all=JSON.parse(localStorage.getItem(PX_DEVICE_STORE)||'{}'); all[pxIdentifierKey(identifier)]=token; localStorage.setItem(PX_DEVICE_STORE,JSON.stringify(all)); }catch(_){}
}
async function pxAuthApi(action,payload,withSession=false){
  try{
    const headers={'Content-Type':'application/json','Accept':'application/json'};
    if(withSession&&sb){ const {data}=await sb.auth.getSession(); if(data?.session?.access_token) headers.Authorization='Bearer '+data.session.access_token; }
    const res=await fetch('/api/auth',{method:'POST',headers,body:JSON.stringify({action,...payload})});
    const body=await res.json().catch(()=>({}));
    return {ok:res.ok&&body.ok!==false,status:res.status,...body};
  }catch(e){ return {ok:false,status:0,error:'هەڵەی تۆڕ، دووبارە هەوڵ بدەرەوە'}; }
}
// Error text for the person, with the remaining tries or the end of a 24-hour block.
function pxAuthError(r){
  if(r.code==='LOCKED'||r.status===423){
    let when='';
    try{ if(r.locked_until) when=' تا '+new Date(r.locked_until).toLocaleString('en-GB',{hour:'2-digit',minute:'2-digit',day:'2-digit',month:'2-digit'}); }catch(_){}
    return 'بەهۆی 3 هەوڵی هەڵە، ئەم هەژمارە بۆ 24 کاتژمێر بلۆک کراوە'+when+'.';
  }
  let text=r.error||'هەڵەیەک ڕووی دا، دووبارە هەوڵ بدەرەوە';
  if(Number.isInteger(r.attempts_left)&&r.attempts_left>0) text+=' ('+r.attempts_left+' هەوڵ ماوە)';
  return text;
}
async function pxSignedIn(r,identifier,remember){
  if(remember&&r.device_token) pxRememberDevice(identifier,r.device_token);
  const {data,error}=await sb.auth.setSession({access_token:r.session.access_token,refresh_token:r.session.refresh_token});
  if(error||!data?.user) throw new Error('چوونەژوورەوەی هەژمار سەرکەوتوو نەبوو؛ تکایە دووبارە هەوڵ بدەرەوە');
  return data.user;
}
let _authFlow=null;
// ── Login / reset: "number" or "Gmail" option; the number field shows 🇮🇶 +964 ──
const PX_GMAIL_RE=/^[a-z0-9._%+-]+@gmail\.com$/i;
function pxIsGmail(value){ return PX_GMAIL_RE.test(String(value||'').trim()); }
function pxPhoneInput(el){
  if(!el) return;
  let d=String(el.value||'').replace(/[٠-٩]/g,ch=>String(ch.charCodeAt(0)-1632)).replace(/[۰-۹]/g,ch=>String(ch.charCodeAt(0)-1776)).replace(/\D/g,'');
  if(d.startsWith('00964')) d=d.slice(5); else if(d.startsWith('964')) d=d.slice(3);
  d=d.slice(0,d.startsWith('0')?11:10);
  if(el.value!==d) el.value=d;
}
function pxSetMethod(prefix,method){
  const phone=method!=='email';
  const tabs={phone:document.getElementById(prefix+'TabPhone'),email:document.getElementById(prefix+'TabEmail')};
  const fields={phone:document.getElementById(prefix+'PhoneField'),email:document.getElementById(prefix+'EmailField')};
  if(tabs.phone){ tabs.phone.classList.toggle('is-on',phone); tabs.phone.setAttribute('aria-selected',String(phone)); }
  if(tabs.email){ tabs.email.classList.toggle('is-on',!phone); tabs.email.setAttribute('aria-selected',String(!phone)); }
  if(fields.phone) fields.phone.hidden=!phone;
  if(fields.email) fields.email.hidden=phone;
  return phone?'phone':'email';
}
let _loginMethod='phone', _forgotMethod='phone';
function setLoginMethod(method){
  _loginMethod=pxSetMethod('auth',method);
  try{ localStorage.setItem('px_login_method',_loginMethod); }catch(_){}
  const msg=document.getElementById('authMsg'); if(msg) msg.style.display='none';
}
function setForgotMethod(method){
  _forgotMethod=pxSetMethod('fp',method);
  const msg=document.getElementById('fpMsgA'); if(msg) msg.style.display='none';
}
try{ if(localStorage.getItem('px_login_method')==='email') document.addEventListener('DOMContentLoaded',()=>setLoginMethod('email')); }catch(_){}
// E-mail for e-mail accounts; the 07… number for number accounts (their Auth address is internal).
function pxAccountLabel(){
  const email=String(curUser?.email||'');
  if(email.endsWith('@phone.proxobalance.app')) return curProfile?.phone||('0'+email.slice(4,14));
  return email;
}   // {kind:'login'|'signup', identifier|phone, password, name, remember, channel, target}

async function submitLogin(){
  if(_authSubmitting||_authStepBusy) return;
  const password=document.getElementById('authPass').value;
  const remember=!!document.getElementById('authRemember')?.checked;
  let identifier;
  if(_loginMethod==='email'){
    identifier=document.getElementById('authEmail').value.trim().toLowerCase();
    if(!identifier){ showAmsg('ئیمەیڵەکەت بنووسە','err'); return; }
    if(!pxIsGmail(identifier)){ showAmsg('ئیمەیڵەکە دروست نییە','err'); return; }
  } else {
    const raw=document.getElementById('authPhone').value.trim();
    if(!raw){ showAmsg('ژمارەی مۆبایلەکەت بنووسە','err'); return; }
    identifier=pxIraqiPhone(raw);
    if(!identifier){ showAmsg('ژمارەی مۆبایلەکە دروست نییە','err'); return; }
  }
  if(!password){ showAmsg('وشەی نهێنی بنووسە','err'); return; }
  _authSubmitting=true; _authIsNewUser=false;
  const btn=document.getElementById('authBtn'); if(btn){btn.disabled=true;btn.innerHTML=ICON.spin+' پشکنین...';}
  try{
    if(window.ProxoAccess&&!await ProxoAccess.check()) return;
    await window.trackAuthAttempt?.(identifier,'login');
    const r=await pxAuthApi('login_start',{identifier,password,device_token:pxDeviceToken(identifier)});
    if(!r.ok){ window.trackEvent?.('login_failed',identifier); showAmsg(pxAuthError(r),'err'); return; }
    if(r.session){                                   // remembered device: no code needed
      const user=await pxSignedIn(r,identifier,false);
      window.trackEvent?.('login'); await startApp(user); return;
    }
    _authFlow={kind:'login',identifier,password,remember,channel:r.channel,target:r.target};
    _otpPurpose='login';
    showOtpStep(r.target,r.channel,r.expires_at,r.already_sent);
  }catch(e){ showAmsg(kuErr(e?.message)||'هەڵەیەک ڕووی دا','err'); }
  finally{ restoreAuthButton('authBtn'); _authSubmitting=false; }
}
async function submitSignup(){
  if(_authSignupChecking||_authSubmitting) return;
  const name=document.getElementById('authName').value.trim();
  const phoneRaw=document.getElementById('signupPhone').value.trim();
  const password=document.getElementById('signupPass').value;
  const confirm=document.getElementById('signupConfirmPass').value;
  const remember=!!document.getElementById('signupRemember')?.checked;
  if(name.length<3){showAmsg('ناوی تەواوت بنووسە','err');return;}
  const phone=pxIraqiPhone(phoneRaw);
  if(!phone){showAmsg('ژمارەی مۆبایلەکە دروست نییە','err');return;}
  if(password.length<8){showAmsg('وشەی نهێنی دەبێت کەمترین 8 پیت بێت','err');return;}
  if(password!==confirm){showAmsg('وشە نهێنییەکان یەکسان نین','err');return;}
  _authSignupChecking=true; _authIsNewUser=true;
  const btn=document.getElementById('signupSubmitBtn'); if(btn){btn.disabled=true;btn.innerHTML=ICON.spin+' کۆد دەنێردرێت...';}
  try{
    if(window.ProxoAccess&&!await ProxoAccess.check()) return;
    await window.trackAuthAttempt?.(phone,'signup');
    const r=await pxAuthApi('signup_start',{phone,name,password});
    if(!r.ok){ showAmsg(pxAuthError(r),'err'); return; }
    _authFlow={kind:'signup',phone,name,password,remember,channel:r.channel,target:r.target};
    _otpPurpose='signup';
    showOtpStep(r.target,r.channel,r.expires_at,r.already_sent);
  }catch(e){ showAmsg(kuErr(e?.message)||'هەڵەی تۆڕ، دووبارە هەوڵ بدەرەوە','err'); }
  finally{ _authSignupChecking=false; restoreAuthButton('signupSubmitBtn'); }
}

// ══ OTP STEP ══
// Seconds until a code expires (the server sends expires_at); fallback for older servers.
function pxSecondsLeft(iso,fallback){
  const t=Date.parse(iso||''); if(!Number.isFinite(t)) return fallback;
  return Math.max(0,Math.ceil((t-Date.now())/1000));
}
function showOtpStep(target,channel,expiresAt,alreadySent){
  blurAuthInput();
  _otpEmail=String(target||'');
  setAuthRoute(_otpPurpose==='signup'?'signup/otp':'login/otp',true);
  otpSentLabel('otpEmailLbl',channel,_otpEmail);
  ['otp1','otp2','otp3','otp4','otp5','otp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  document.getElementById('otpMsg').style.display='none';
  startOtpTimer(pxSecondsLeft(expiresAt,channel==='whatsapp'?300:600));
  if(alreadySent) showOtpMsg('کۆدی پێشوو هێشتا کاردەکات','ok');
}
// "The code was sent to" + the masked number / address on its own line.
function otpSentLabel(id,channel,target){
  const lbl=document.getElementById(id); if(!lbl) return;
  lbl.textContent=channel==='whatsapp'?'کۆدەکە لە واتسئاپ نێردرا بۆ':'کۆدەکە نێردرا بۆ';
  const b=document.createElement('b'); b.dir='ltr'; b.textContent=String(target||''); lbl.appendChild(b);
}
// Under a code: a countdown while it is valid; the "send again" button only once it expired.
function otpAgainState(prefix,state){            // prefix 'otp' | 'fp'; state 'wait' | 'ready' | 'off'
  const wait=document.getElementById(prefix+'TimerWrap'), btn=document.getElementById(prefix+'ResendBtn');
  if(wait) wait.hidden=state!=='wait';
  if(btn){ btn.hidden=state!=='ready'; btn.disabled=false; }
}
function otpCountdown(prefix,seconds){
  const until=Date.now()+Math.max(0,seconds||0)*1000;
  const val=document.getElementById(prefix+'TimerVal');
  let id=null;
  const tick=()=>{
    const left=Math.ceil((until-Date.now())/1000);
    if(left<=0){ if(id) clearInterval(id); otpAgainState(prefix,'ready'); return false; }
    if(val) val.textContent=Math.floor(left/60)+':'+String(left%60).padStart(2,'0');
    otpAgainState(prefix,'wait'); return true;
  };
  if(!tick()) return null;
  id=setInterval(tick,1000); return id;
}
function cancelOtp(){ clearInterval(_otpTimer); const target=_otpPurpose==='signup'?'signup':'login'; _otpPendingData=null; _authFlow=null; authBackTo(target); }
// A fresh code: the confirm button is ready again (never left on "checking…").
function otpVerifyIdle(id){ const b=document.getElementById(id); if(b){ b.disabled=false; b.textContent='پشتڕاستکردنەوە'; } }
function startOtpTimer(seconds){ clearInterval(_otpTimer); otpVerifyIdle('otpVerifyBtn'); _otpTimer=otpCountdown('otp',seconds); }
function normalizeOtpDigits(value){
  return String(value||'').replace(/[٠-٩]/g,ch=>String(ch.charCodeAt(0)-1632))
    .replace(/[۰-۹]/g,ch=>String(ch.charCodeAt(0)-1776)).replace(/[^0-9]/g,'').slice(0,6);
}
function otpInputs(prefix){return Array.from({length:6},(_,i)=>document.getElementById(prefix+(i+1))).filter(Boolean);}
function setOtpCode(prefix,value){
  const digits=normalizeOtpDigits(value),inputs=otpInputs(prefix);
  inputs.forEach((input,i)=>{input.value=digits[i]||'';});
  const focusIndex=digits.length>=6?5:Math.min(digits.length,inputs.length-1);
  inputs[focusIndex]?.focus();
  if(digits.length===6){
    if(prefix==='fp')doForgotVerifyOtp();else verifyOtp();
  }
}
function pasteOtpCode(event,prefix){
  if(!event.clipboardData)return;
  event.preventDefault();
  const digits=normalizeOtpDigits(event.clipboardData.getData('text'));
  if(!digits){
    if(prefix==='fp')fpShowMsg('B','لە کلیپبۆرددا ژمارەیەکی دروست نەدۆزرایەوە','err');
    else showOtpMsg('لە کلیپبۆرددا ژمارەیەکی دروست نەدۆزرایەوە','err');
    return;
  }
  setOtpCode(prefix,digits);
}
function otpMove(el,prevId,nextId){
  const prefix=String(el?.id||'').startsWith('fp')?'fp':'otp';
  const digits=normalizeOtpDigits(el?.value);
  if(digits.length>1){setOtpCode(prefix,digits);return;}
  el.value=digits;
  if(el.value&&nextId)document.getElementById(nextId)?.focus();
  const code=otpInputs(prefix).map(input=>input.value||'').join('');
  if(code.length===6){if(prefix==='fp')doForgotVerifyOtp();else verifyOtp();}
}
function otpBack(e,el,prevId){ if(e.key==='Backspace'&&!el.value&&prevId) document.getElementById(prevId)?.focus(); }
function showOtpMsg(t,c){ const el=document.getElementById('otpMsg'); el.textContent=t; el.className='amsg '+c; el.style.display='block'; }

let _otpVerifying=false;
async function verifyOtp(){
  if(_otpVerifying||!_authFlow) return;
  _otpVerifying=true;
  const btn=document.getElementById('otpVerifyBtn');
  const unlock=()=>{ if(btn){ btn.disabled=false; btn.innerHTML='پشتڕاستکردنەوە'; } };
  try{
    if(window.ProxoAccess && !await ProxoAccess.check()) return;
    const code=['otp1','otp2','otp3','otp4','otp5','otp6'].map(id=>document.getElementById(id)?.value||'').join('');
    if(code.length<6){ showOtpMsg('کۆدەکە تەواو بنووسە','err'); return; }
    if(btn){ btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...'; }
    const f=_authFlow;
    const r=f.kind==='signup'
      ? await pxAuthApi('signup_finish',{phone:f.phone,name:f.name,password:f.password,code,remember:f.remember})
      : await pxAuthApi('login_finish',{identifier:f.identifier,password:f.password,code,remember:f.remember});
    if(!r.ok){
      showOtpMsg(pxAuthError(r),'err');
      if(r.code==='LOCKED'||r.status===423){ clearInterval(_otpTimer); otpAgainState('otp','off'); if(btn) btn.disabled=true; return; }
      ['otp1','otp2','otp3','otp4','otp5','otp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
      document.getElementById('otp1')?.focus();
      if(r.code==='CODE_EXPIRED'){ clearInterval(_otpTimer); otpAgainState('otp','ready'); }
      unlock(); return;
    }
    clearInterval(_otpTimer);
    showOtpMsg(f.kind==='signup'?'هەژمارەکەت دروستکرا!':'سەرکەوتوو بوو!','ok');
    const user=await pxSignedIn(r,f.kind==='signup'?f.phone:f.identifier,f.remember);
    _authFlow=null;
    // track.js owns the server-side IP capture; the new session lets it attach this IP to the account.
    if(typeof window.trackEvent==='function') window.trackEvent(f.kind==='signup'?'signup':'login');
    await startApp(user);
  }catch(e){
    showOtpMsg(kuErr(e?.message)||'هەڵەیەک ڕووی دا','err'); unlock();
  }finally{
    _otpVerifying=false;
  }
}

let _otpResending=false;
async function resendOtp(){
  if(_otpResending||!_authFlow) return;
  const btn=document.getElementById('otpResendBtn');
  if(!btn||btn.disabled||btn.hidden) return;        // only after the code expired
  _otpResending=true; btn.disabled=true;
  showOtpMsg('ناردن...','ok');
  try{
    const f=_authFlow;
    const r=f.kind==='signup'
      ? await pxAuthApi('signup_start',{phone:f.phone,name:f.name,password:f.password})
      : await pxAuthApi('login_start',{identifier:f.identifier,password:f.password});
    if(r.ok&&r.otp_required){
      showOtpMsg(r.already_sent?'کۆدی پێشوو هێشتا کاردەکات':'کۆدی نوێ نێردرا','ok');
      ['otp1','otp2','otp3','otp4','otp5','otp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
      startOtpTimer(pxSecondsLeft(r.expires_at,r.channel==='whatsapp'?300:600));
    } else { showOtpMsg(pxAuthError(r),'err'); otpAgainState('otp',(r.code==='LOCKED'||r.status===423)?'off':'ready'); }
  }catch(e){ showOtpMsg(kuErr(e?.message)||'هەڵەی ناردنی کۆد','err'); otpAgainState('otp','ready'); }
  finally{ _otpResending=false; btn.disabled=false; }
}

// ══════════════════════════════════════════════════════════════
// ═══ FORGOT PASSWORD ═══════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let _fpTimer=null, _fpEmail='', _fpVerified=false, _fpCode='', _fpPhone='', _fpGrant='';
function showForgotStep(){
  blurAuthInput();
  setAuthRoute('forgetpassword',true);
  setForgotMethod(_loginMethod);
  document.getElementById('forgotEmail').value=_fpEmail||document.getElementById('authEmail')?.value.trim()||'';
  document.getElementById('forgotPhone').value=document.getElementById('authPhone')?.value.trim()||'';
  document.getElementById('fpMsgA').style.display='none';
}
function cancelForgotStep(){ clearInterval(_fpTimer); _fpVerified=false; _fpCode=''; _fpEmail=''; _fpPhone=''; _fpGrant=''; authBackTo('login'); }
function fpBackToA(){ blurAuthInput(); clearInterval(_fpTimer); _fpVerified=false; _fpCode=''; _fpGrant=''; authBackTo('forgetpassword'); }
function authHeaderBack(){
  if(_authStepBusy||_authSubmitting||_authSignupChecking||_otpVerifying||_otpResending||_fpResending||_fpSending||_fpVerifying||_fpSaving) return;
  const target={'signup':'login','login/otp':'login','signup/otp':'signup',forgetpassword:'login','forgetpassword/otp':'forgetpassword',newpassword:'forgetpassword/otp'}[authRoute];
  if(!target) return;
  if(authRoute==='login/otp'||authRoute==='signup/otp') return cancelOtp();
  if(authRoute==='forgetpassword') return cancelForgotStep();
  if(authRoute==='forgetpassword/otp') return fpBackToA();
  authBackTo(target);
}
function refreshAuthPage(){
  const safeRoute={
    'login/otp':_authIsNewUser?'signup':'login',
    'signup/otp':'signup',
    'forgetpassword/otp':'forgetpassword',
    newpassword:'forgetpassword'
  }[authRoute];
  if(safeRoute){ location.replace(authHref(safeRoute)); return; }
  location.reload();
}
function syncAuthHeaderBack(){
  const button=document.getElementById('authHeaderBack');
  if(!button) return;
  button.hidden=authRoute==='login';
}
(()=>{
  const root=document.getElementById('authWrap');
  if(!root) return;
  new MutationObserver(syncAuthHeaderBack).observe(root,{subtree:true,attributes:true,attributeFilter:['style']});
  syncAuthHeaderBack();
})();
function fpShowMsg(step,t,c){ const el=document.getElementById('fpMsg'+step); el.textContent=t; el.className='amsg '+c; el.style.display='block'; }
function fpStartTimer(sec){ clearInterval(_fpTimer); otpVerifyIdle('fpVerifyBtn'); _fpTimer=otpCountdown('fp',sec); }
function fpOtpMove(el,prevId,nextId){
  otpMove(el,prevId,nextId);
}
function fpOtpBack(e,el,prevId){ if(e.key==='Backspace'&&!el.value&&prevId) document.getElementById(prevId)?.focus(); }

let _fpResending=false, _fpSending=false, _fpVerifying=false, _fpSaving=false;
async function fpResendOtp(){
  if(_fpResending) return;
  const btn=document.getElementById('fpResendBtn');
  if(!btn||btn.disabled||btn.hidden) return;        // only after the code expired
  // number or e-mail: both go through /api/auth, for every account
  _fpResending=true; btn.disabled=true;
  fpShowMsg('B','ناردن...','ok');
  try{
    const r=await pxAuthApi('reset_start',{identifier:_fpPhone||_fpEmail});
    if(r.ok){ fpShowMsg('B',r.already_sent?'کۆدی پێشوو هێشتا کاردەکات':'کۆدی نوێ نێردرا','ok'); ['fp1','fp2','fp3','fp4','fp5','fp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; }); fpStartTimer(pxSecondsLeft(r.expires_at,_fpPhone?300:600)); }
    else { fpShowMsg('B',pxAuthError(r),'err'); otpAgainState('fp',r.status===423?'off':'ready'); }
  }catch(e){ fpShowMsg('B',kuErr(e?.message)||'هەڵەی ناردنی کۆد','err'); otpAgainState('fp','ready'); }
  finally{ _fpResending=false; btn.disabled=false; }
}

async function doForgotSendOtp(){
  if(_fpSending) return;
  const byPhone=_forgotMethod!=='email';
  const email=byPhone?'':document.getElementById('forgotEmail').value.trim().toLowerCase();
  const phone=byPhone?pxIraqiPhone(document.getElementById('forgotPhone').value):null;
  if(byPhone&&!document.getElementById('forgotPhone').value.trim()){ fpShowMsg('A','ژمارەی مۆبایلەکەت بنووسە','err'); return; }
  if(byPhone&&!phone){ fpShowMsg('A','ژمارەی مۆبایلەکە دروست نییە','err'); return; }
  if(!byPhone&&!email){ fpShowMsg('A','ئیمەیڵەکەت بنووسە','err'); return; }
  if(!byPhone&&!pxIsGmail(email)){ fpShowMsg('A','ئیمەیڵەکە دروست نییە','err'); return; }
  const btn=document.getElementById('forgotSendBtn');
  if(!btn||btn.disabled) return;
  _fpSending=true;
  btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...';
  try{
    if(phone){
      const r=await pxAuthApi('reset_start',{phone});
      if(!r.ok){ fpShowMsg('A',pxAuthError(r),'err'); return; }
      _fpPhone=phone; _fpEmail=''; _fpGrant=''; _fpVerified=false;
      otpSentLabel('fpOtpLbl','whatsapp',r.target||'');
      ['fp1','fp2','fp3','fp4','fp5','fp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
      document.getElementById('fpMsgB').style.display='none';
      blurAuthInput();
      setAuthRoute('forgetpassword/otp',true);
      fpStartTimer(pxSecondsLeft(r.expires_at,300));
      if(r.already_sent) fpShowMsg('B','کۆدی پێشوو هێشتا کاردەکات','ok');
      return;
    }
    // e-mail: any account with this verified Gmail address (also number accounts)
    btn.innerHTML=ICON.spin+' دەنێردرێت...';
    const r=await pxAuthApi('reset_start',{identifier:email});
    if(!r.ok){ fpShowMsg('A',pxAuthError(r),'err'); return; }
    _fpPhone=''; _fpEmail=email; _fpGrant=''; _fpVerified=false;
    otpSentLabel('fpOtpLbl','email',r.target||email);
    ['fp1','fp2','fp3','fp4','fp5','fp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
    document.getElementById('fpMsgB').style.display='none';
    blurAuthInput();
    setAuthRoute('forgetpassword/otp',true);
    fpStartTimer(pxSecondsLeft(r.expires_at,600));
    if(r.already_sent) fpShowMsg('B','کۆدی پێشوو هێشتا کاردەکات','ok');
  }catch(e){
    fpShowMsg('A',e.message||'هەڵەی پشکنین','err');
  }finally{
    _fpSending=false;
    btn.disabled=false; btn.innerHTML=ICON.send+' ناردنی کۆد';
  }
}

async function doForgotVerifyOtp(){
  if(_fpVerifying) return;
  _fpVerifying=true;
  const btn=document.getElementById('fpVerifyBtn');
  try{
    const code=['fp1','fp2','fp3','fp4','fp5','fp6'].map(id=>document.getElementById(id)?.value||'').join('');
    if(code.length<6){ fpShowMsg('B','کۆدەکە تەواو بنووسە','err'); return; }
    {
      btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...';
      const r=await pxAuthApi('reset_verify',{identifier:_fpPhone||_fpEmail,code});
      if(!r.ok){
        fpShowMsg('B',pxAuthError(r),'err');
        if(r.status===423){ clearInterval(_fpTimer); otpAgainState('fp','off'); return; }
        ['fp1','fp2','fp3','fp4','fp5','fp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
        if(r.code==='CODE_EXPIRED'){ clearInterval(_fpTimer); otpAgainState('fp','ready'); }
        btn.disabled=false; btn.innerHTML='پشتڕاستکردنەوە'; return;
      }
      clearInterval(_fpTimer); blurAuthInput();
      _fpVerified=true; _fpGrant=r.grant||'';
      setAuthRoute('newpassword',true);
      document.getElementById('fpNewPass').value=''; document.getElementById('fpConfirmPass').value='';
      document.getElementById('fpMsgC').style.display='none';
      btn.disabled=false; btn.innerHTML='پشتڕاستکردنەوە';
    }
  }catch(e){
    fpShowMsg('B',kuErr(e?.message)||'هەڵەی دڵنیاکردنەوە','err');
    if(btn){ btn.disabled=false; btn.innerHTML='پشتڕاستکردنەوە'; }
  }finally{ _fpVerifying=false; }
}

async function doForgotSavePass(){
  if(_fpSaving) return;
  _fpSaving=true;
  try{
    const np=document.getElementById('fpNewPass').value, cp=document.getElementById('fpConfirmPass').value;
    if(!np||np.length<8){ fpShowMsg('C','وشەی نهێنی دەبێت کەمترین 8 پیت بێت','err'); return; }
    if(np!==cp){ fpShowMsg('C','وشەی نهێنیەکان یەکسان نین','err'); return; }
    const btn=document.getElementById('fpSaveBtn'); if(!btn||btn.disabled) return;
    btn.disabled=true; btn.innerHTML=ICON.spin+' گۆڕین...';
    try{
      const id=_fpPhone||_fpEmail;
      const r=await pxAuthApi('reset_finish',{identifier:id,grant:_fpGrant,password:np});
      if(!r.ok){ fpShowMsg('C',pxAuthError(r),'err'); return; }
      fpShowMsg('C','وشەی نهێنیەکە گۆڕدرا، چوونەژوورەوە...','ok');
      const user=await pxSignedIn(r,id,false);
      clearInterval(_fpTimer); _fpVerified=false; _fpGrant=''; _fpPhone=''; _fpEmail=''; _fpCode='';
      document.getElementById('forgotStep').style.display='none';
      window.trackEvent?.('login');
      await startApp(user);
    }catch(e){ fpShowMsg('C',kuErr(e.message)||'هەڵەی تۆڕ','err'); }
    finally{ btn.disabled=false; btn.innerHTML=ICON.lock+' پاشەکەوتکردن'; }
  }finally{ _fpSaving=false; }
}

function kuErr(msg){
  const m={
    'Invalid login credentials':'ئیمەیل یان وشەی نهێنی هەڵەیە',
    'User already registered':'ئەم ئیمەیلە پێشتر تۆمارکراوە',
    'Password should be at least 6 characters':'وشەی نهێنی دەبێت کەمترین 6 پیت بێت',
    'Unable to validate email address: invalid format':'فۆرماتی ئیمەیل هەڵەیە',
    'Too many requests':'زۆر جار هەوڵت دا، کەمێک چاوەڕوان بە',
    'Network request failed':'کێشەی تۆڕ، دووبارە هەوڵ بدەرەوە',
    'Failed to fetch':'پەیوەندی بە سێرڤەر نەکرا؛ داتای مۆبایل یان Wi‑Fi بپشکنە و دووبارە هەوڵ بدەرەوە',
    'RECEIPT_UPLOAD_NETWORK':'ناردنی وێنەکە بەهۆی کێشەی تۆڕەوە سەرکەوتوو نەبوو؛ پەیوەندییەکەت بپشکنە و دووبارە هەوڵ بدەرەوە',
    'RECEIPT_UPLOAD_FAILED':'نەتوانرا وێنەی پسووڵەکە باربکرێت؛ تکایە وێنەکە دووبارە هەڵبژێرە',
    'FILE_READ_PERMISSION':'براوزەر نەتوانی وێنەکە بخوێنێتەوە؛ تکایە مۆڵەتی وێنە/فایل بدە و لە Gallery یان Files دووبارە هەڵیبژێرە',
    'SESSION_NETWORK_ERROR':'نەتوانرا هەژمارەکەت پشتڕاست بکرێتەوە؛ پەیوەندییەکەت بپشکنە یان دووبارە بچۆ ژوورەوە',
    'ORDER_NETWORK_ERROR':'داواکارییەکە نەگەیشتە سێرڤەر؛ پەیوەندییەکەت بپشکنە و دووبارە هەوڵ بدەرەوە',
    'Email rate limit exceeded':'زۆر جار ئیمەیل نێردرا، کەمێک چاوەڕوان بە',
    'Auth session missing':'تکایە دووبارە بچۆ ژوورەوە',
    'PROFILE_UPDATE_COOLDOWN':'ناو و ژمارەی مۆبایل تا تەواوبوونی 7 ڕۆژەکە قوفڵن',
    'PROFILE_NAME_LOCKED_BY_KYC':'ناوەکەت بە ناسنامە پشتڕاستکراوەتەوە و ناتوانرێت بگۆڕدرێت',
    'KYC_REQUIRED_FOR_EXCHANGE':'پێش ئەنجامدانی ئاڵوگۆڕ، پێویستە ناسنامەکەت پشتڕاست بکرێتەوە.',
    'SENDER_PHONE_REQUIRED':'ژمارەی مۆبایلی نێرەر پێویستە',
    'SENDER_PHONE_INVALID':'ژمارەی نێرەر دەبێت بە 07 دەست پێبکات و 11 ژمارە بێت',
    'Invalid sender number':'ژمارەی نێرەر دەبێت بە 07 دەست پێبکات و 11 ژمارە بێت',
  };
  if(m[msg]) return m[msg];
  if(/requested file could not be read|notreadableerror|permission problems.*reference to a file/i.test(String(msg||''))) return m.FILE_READ_PERMISSION;
  if(/failed to fetch|networkerror|network request failed|load failed/i.test(String(msg||''))) return m['Failed to fetch'];
  return msg;
}

// ═══ APPLICATION ERROR REPORTING ════════════════════════════════
// Reports sanitized failures to the server. Network failures are queued
// locally and retried after connectivity/session returns.
const CLIENT_ERROR_QUEUE_KEY='zex_pending_error_logs_v1';
const _recentClientErrors=new Map();

function queuedErrorLogs(){
  try{
    const value=JSON.parse(localStorage.getItem(CLIENT_ERROR_QUEUE_KEY)||'[]');
    return Array.isArray(value)?value.slice(-20):[];
  }catch(_){ return []; }
}
function saveQueuedErrorLogs(rows){
  try{ localStorage.setItem(CLIENT_ERROR_QUEUE_KEY,JSON.stringify((rows||[]).slice(-20))); }catch(_){}
}
function queueErrorLog(payload){
  const rows=queuedErrorLogs();
  if(!rows.some(row=>row.client_key===payload.client_key)) rows.push(payload);
  saveQueuedErrorLogs(rows);
}
async function sendErrorLog(payload){
  const token=activeSession?.access_token;
  if(!token) throw new Error('NO_ERROR_LOG_SESSION');
  const res=await fetch('/api/error-log',{
    method:'POST',
    headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},
    body:JSON.stringify(payload),
    keepalive:true
  });
  if(!res.ok) throw new Error('ERROR_LOG_HTTP_'+res.status);
}
async function reportAppError(error, details={}){
  const rawMessage=String(error?.message||error||'Unknown client error').replace(/[\r\n\t]+/g,' ').slice(0,2000);
  const operation=String(details.operation||'client_runtime').slice(0,100);
  const stage=String(details.stage||'unknown').slice(0,200);
  const code=String(error?.code||rawMessage).slice(0,120);
  const clientKey=[operation,stage,code,safeAppTelemetryPath()].join('|');
  const last=_recentClientErrors.get(clientKey)||0;
  if(Date.now()-last<60000) return;
  _recentClientErrors.set(clientKey,Date.now());

  const payload={
    client_key:clientKey,
    operation,
    severity:details.severity||'error',
    code,
    status:Number(error?.status)||null,
    message:rawMessage,
    path:safeAppTelemetryPath(),
    metadata:{
      stage,
      online:navigator.onLine,
      visibility:document.visibilityState,
      from_method:details.from_method||null,
      to_method:details.to_method||null,
      file_size:Number(details.file_size)||null,
      file_type:details.file_type||null,
      filename:details.filename||null,
      line:Number(details.line)||null,
      column:Number(details.column)||null
    }
  };
  try{ await sendErrorLog(payload); }
  catch(_){ queueErrorLog(payload); }
}
async function flushQueuedErrorLogs(){
  if(!activeSession?.access_token || !navigator.onLine) return;
  const rows=queuedErrorLogs();
  if(!rows.length) return;
  const remaining=[];
  for(const row of rows){
    try{ await sendErrorLog(row); }
    catch(_){ remaining.push(row); }
  }
  saveQueuedErrorLogs(remaining);
}

// ══════════════════════════════════════════════════════════════
// ═══ START APP (after successful auth) ══════════════════════════
// ══════════════════════════════════════════════════════════════
// ── a banned account: one full screen (layout shared with the paused-site screen,
// assets/css/site-pause.css). It also appears at once if the admin bans while the
// app is open (ex_profiles change, assets/js/exchange-customer-features.js).
function showBannedScreen(profile){
  let el=document.getElementById('pxBanned');
  if(!el){
    el=document.createElement('div');
    el.id='pxBanned'; el.className='svc-site is-ban';
    el.setAttribute('role','alertdialog'); el.setAttribute('aria-modal','true'); el.setAttribute('aria-labelledby','pxBannedTitle');
    document.body.appendChild(el);
  }
  const reason=String(profile?.ban_reason||'').trim();
  const when=profile?.banned_at?new Date(profile.banned_at):null;
  const date=when&&!isNaN(when)?when.getFullYear()+'/'+String(when.getMonth()+1).padStart(2,'0')+'/'+String(when.getDate()).padStart(2,'0'):'';
  el.innerHTML='<img class="svc-site-logo" src="/assets/images/auth/proxo-logo.webp" alt="Proxo">'
    +'<div class="svc-site-box"><div class="svc-site-mark" aria-hidden="true"><svg viewBox="0 0 24 24"><rect x="5" y="10.5" width="14" height="9.5" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/><path d="M12 14.5v2"/></svg></div>'
    +'<h1 id="pxBannedTitle">هەژمارەکەت باندکراوە</h1>'
    +'<p>ئەم هەژمارە ناتوانێت ئاڵوگۆڕ بکات. ئەگەر پێتوایە هەڵەیەک ڕوویداوە، پەیوەندی بە پشتگیری بکە.</p>'
    +((reason||date)?'<dl class="svc-site-info">'
      +(reason?'<div><dt>هۆکار</dt><dd>'+escHtml(reason)+'</dd></div>':'')
      +(date?'<div><dt>بەروار</dt><dd dir="ltr" style="text-align:right">'+date+'</dd></div>':'')+'</dl>':'')
    +'<div class="svc-site-actions"><a class="svc-site-btn" href="https://t.me/proxo_exchange" target="_blank" rel="noopener">پەیوەندی بە پشتگیری</a>'
    +'<button type="button" class="svc-site-btn is-ghost" id="pxBannedOut">دەرچوون</button></div></div>';
  el.querySelector('#pxBannedOut').addEventListener('click',async function(){
    this.disabled=true;
    try{ await sb.auth.signOut(); }catch(_){}
    try{ location.replace(BASE_PATH); }catch(_){ location.reload(); }
  });
  document.documentElement.classList.add('svc-site-on');
}
window.showBannedScreen=showBannedScreen;
async function checkBanState(){
  if(!curUser) return;
  const {data}=await sb.from('ex_profiles').select('is_banned,ban_reason,banned_at').eq('id',curUser.id).maybeSingle();
  if(data&&data.is_banned) showBannedScreen(data);
}
window.checkBanState=checkBanState;

async function ensureExProfile(user){
  const {data:existing}=await sb.from('ex_profiles').select('*').eq('id',user.id).maybeSingle();
  if(existing) return existing;
  const fullName=user.user_metadata?.full_name || user.email.split('@')[0];
  const {data:created,error}=await sb.from('ex_profiles').insert({id:user.id,email:user.email,full_name:fullName}).select().single();
  if(error){ const {data:retry}=await sb.from('ex_profiles').select('*').eq('id',user.id).maybeSingle(); return retry; }
  return created;
}

// ── app shell while a saved session is still loading ─────────────
// With a saved session the person is signed in; on a slow connection the
// profile can take a while. Instead of the login screen they see the app
// with skeletons (not tappable) until startApp() hands over.
function pxPaintSkeletons(){
  if(!window.PXS) return;
  const fill=(id,html)=>{ const el=document.getElementById(id); if(el){ el.innerHTML=html; } };
  fill('historyPreview', PXS.dbRows ? PXS.dbRows(4) : PXS.txItems(3));
  if(!_ordersLoaded) fill('txList', PXS.txItems(4));
  fill('supportCasesList', PXS.supportCases(2));
  fill('ratesNow', PXS.rateCards(3));
  fill('changesList', PXS.changeItems(3));
  fill('bhList', PXS.balHist(3));
  if(!_notifLoaded) fill('notifPanelBody', PXS.notifItems(4));
  fill('kycBanner', PXS.kycBanner());
  fill('txScreenBody', PXS.summary());
}
function pxBootShell(route){
  if(!ROUTES[route]) route='home';
  document.body.classList.add('app-booting');
  pxPaintSkeletons();
  Object.keys(ROUTES).forEach(r=>{ const el=document.getElementById(ROUTES[r]); if(el) el.classList.toggle('active', r===route); });
  const navRoute = navRouteOf(route);
  document.querySelectorAll('.bn-item, .hdr-nav-link, .pxn-item, .pxh-link, .pxn-fab').forEach(b=>b.classList.toggle('on', b.dataset.route===navRoute));
}
function pxBootEnd(){ document.body.classList.remove('app-booting'); }

async function startApp(user){
  curUser=user;
  if(typeof resetCustomerConveniences==='function')resetCustomerConveniences();
  flushQueuedErrorLogs();
  curProfile=await ensureExProfile(user);
  if(curProfile?.is_banned){ pxBootEnd(); showBannedScreen(curProfile); return; }
  // asked to delete the account: a new sign-in reactivates it, an older session is signed out
  const deletionState=await checkAccountDeletion();
  if(deletionState==='pending') return;
  document.getElementById('authWrap').style.display='none';
  document.getElementById('mainApp').style.display='block';
  pxBootEnd();
  if(deletionState==='reactivated') setTimeout(()=>{ try{ showToast('دووبارە بەخێربێیتەوە. هەژمارەکەت چالاک کرایەوە و سڕینەوەکە هەڵوەشایەوە.','success'); }catch(_){} },400);
  document.body.classList.add('has-nav');
  applyProfileToUI();
  fillProfileForm();
  try{ renderDashboard(); }catch(_){}
  loadKycStatus(true);
  document.getElementById('adminBtn').style.display=curProfile?.is_admin?'flex':'none';
  if(curProfile?.phone){
    const _ph=document.getElementById('userPhone');
    if(_ph && !_ph.value) _ph.value=curProfile.phone;
  }
  if(authRouteFromLocation()){ try{history.replaceState({},'',BASE_PATH);}catch(_){} }
  // a transaction link opened before signing in
  try{
    const pending=sessionStorage.getItem('px_pending_summary');
    if(pending){ sessionStorage.removeItem('px_pending_summary'); if(TX_TOKEN_RE.test(pending)) history.replaceState({route:'summary'},'',BASE_PATH+'summarytransaction/'+encodeURIComponent(pending)); }
  }catch(_){}
  if(isTransactionSummaryRoute()){ _txScreenPushed=false; _txReturnRoute='transactions'; }
  navigate(routeFromLocation(), false);
  if(typeof window.__dismissAppSplash==='function') window.__dismissAppSplash();
  refreshFormHints();
  clearInterval(_proofTimer);                  // the public feed is gone from the signed-in app
  await Promise.all([loadWallets(),loadRates(),
    ...(typeof loadCustomerConveniences==='function'?[loadCustomerConveniences()]:[])]);
  pickInitialWallets();
  refreshTrigger('from');
  refreshTrigger('receiveVia');
  updateWallet();
  updatePlaceholder();
  if(typeof renderSavedRecipients==='function')renderSavedRecipients();
  subscribeWalletsUser();
  subscribeRatesUser();
  await Promise.all([loadHistory(),loadNotifications()]);
  if(typeof pxBannersStart==='function') pxBannersStart();
  // The Telegram promo is disabled in index.html (hidden attribute); setting
  // style.display here used to override that and cover the whole app.
  setTimeout(()=>{ const tg=document.getElementById('tgModal'); if(tg && !tg.hasAttribute('hidden')) tg.style.display='flex'; },1000);
}

async function logout(){
  try{ await sb.auth.signOut(); }catch(_){}
  // A signed-out visitor should never be left sitting on /profile or
  // /transactions — send them back to the domain root.
  try{ location.replace(BASE_PATH); }catch(_){ location.reload(); }
}

// ══════════════════════════════════════════════════════════════
// ═══ EXCHANGE CALCULATOR (rates come from ex_rates) ═════════════
// ══════════════════════════════════════════════════════════════
// Wallet numbers come only from ex_wallets.wallet_number (admin panel).
// ═══ LIVE WALLET DATA (numbers + lock state come from ex_wallets, admin panel) ═══
let WALLET_DATA = {};
let _walletsChannel = null;
function getWalletInfo(key){
  const w = WALLET_DATA[key];
  return { number: (w && w.number) || null, locked: !!(w && w.locked) };
}
async function loadWallets(){
  try{
    const {data,error} = await sb.from('ex_wallets').select('id,key,name,image_url,wallet_number,is_locked,allow_from,allow_receive,sort_order,badge,badge_version,recipient_format,sender_phone_required').order('sort_order',{ascending:true});
    if(error) throw error;
    if(data){
      WALLET_DATA = {};
      data.forEach(w=>{ if(w.key) WALLET_DATA[w.key] = { id:w.id,badge:w.badge,badge_version:w.badge_version,number: w.wallet_number || null, locked: !!w.is_locked, name:w.name, image_url:w.image_url, allow_from: w.allow_from!==false, allow_receive:!!w.allow_receive, sort_order:w.sort_order, recipient_format:w.recipient_format==='card'?'card':'phone', sender_phone_required:w.sender_phone_required===true }; });
      rebuildWalletOptions();
      WALLETS_STATE = 'ready';
    }
  }catch(e){
    // Unreachable database → show no wallets rather than guessed ones.
    WALLET_DATA = {};
    rebuildWalletOptions();
    WALLETS_STATE = 'error';
  }
}
function hasWallets(){ return FROM_OPTIONS.length>0 && RECEIVE_OPTIONS.length>0; }
function subscribeWalletsUser(){if(typeof startCustomerLive==='function')startCustomerLive();}
function subscribeRatesUser(){if(typeof startCustomerLive==='function')startCustomerLive();}
// Rates exist ONLY in ex_rates: only the routes the admin switched on exist and
// anything not in RATES is closed (no guessed rate). If the database cannot be
// reached the routes stay closed and loading is tried again a few seconds later.
let RATES_STRICT=false;
// An enabled amount tier of an ex_rates row, or null. Disabled tiers leave the route's stored rate exactly as it is.
function rateTierFromRow(r){
  if(!r)return null;
  if(Array.isArray(r.fee_brackets)&&r.fee_brackets.length>=2){
    return {brackets:r.fee_brackets.map(b=>({upTo:b.up_to==null?null:Number(b.up_to),percent:Number(b.percent)}))};
  }
  if(!r.fee_tier_enabled||r.fee_tier_low_percent==null||r.fee_tier_high_percent==null||!(Number(r.fee_tier_limit_iqd)>0))return null;
  return {limit:Number(r.fee_tier_limit_iqd),low:Number(r.fee_tier_low_percent),high:Number(r.fee_tier_high_percent)};
}
function tierHintText(t){
  if(t&&Array.isArray(t.brackets)&&t.brackets.length>=2){
    return t.brackets.map((b,i)=>i<t.brackets.length-1?('تا '+formatNum(b.upTo)+' IQD: '+fmtPct(b.percent)+'%'):('لە سەروو: '+fmtPct(b.percent)+'%')).join(' · ');
  }
  return 'تا '+formatNum(t.limit)+' IQD: '+fmtPct(t.low)+'% · لە سەروو: '+fmtPct(t.high)+'%';
}
async function loadRates(){
  RATES={}; RATES_STRICT=false;
  try{
    const {data,error}=await sb.from('ex_rates').select('*').eq('is_active',true);
    if(!error && data){
      data.forEach(r=>{ RATES[r.from_method+'>'+r.to_method]={type:r.rate_type,value:Number(r.rate_value),tier:rateTierFromRow(r)}; });
      RATES_STRICT=true;
    }
  }catch(e){}
  if(!RATES_STRICT){
    clearTimeout(_ratesRetry);
    _ratesRetryDelay=Math.min((_ratesRetryDelay||2000)*2,30000);
    _ratesRetry=setTimeout(()=>{ loadRates().then(()=>{ try{ if(RATES_STRICT){ updateWallet(); calc(); } }catch(_){} }); },_ratesRetryDelay);
  }else _ratesRetryDelay=0;
}
let _ratesRetry=null,_ratesRetryDelay=0;
// Smallest amount any exchange is accepted for, in IQD.
const MIN_AMOUNT = 10000;
// a wallet's rules come from ex_wallets: the sender's phone (carrier credit) and a card number as the recipient
function needsSenderPhone(method){ return !!(WALLET_DATA[method] && WALLET_DATA[method].sender_phone_required); }
function recipientIsCard(method){ return !!(WALLET_DATA[method] && WALLET_DATA[method].recipient_format==='card'); }
window.recipientIsCard=recipientIsCard;
function routeAllowed(from,to){
  if(!from || !to || from===to) return false;
  return !!RATES[from+'>'+to];
}
function allowedReceiveOptions(from){
  return RECEIVE_OPTIONS.filter(k=>routeAllowed(from,k));
}
// ── Opening state: never start with the same wallet on both sides ──
// The first entry of both lists is often the same wallet, so the
// page used to open on "هەمان واڵێت نابێت" with a dead submit button. This runs
// ONLY when the page opens — a same-wallet or closed pair the user picks
// themselves is still shown as blocked and is never auto-switched.
function pickInitialWallets(){
  const fromSel = document.getElementById('from');
  const toSel   = document.getElementById('receiveVia');
  if(!fromSel || !toSel) return;
  const free = k => !!k && !getWalletInfo(k).locked && (k!=='AccountBalance'||Number(_myBalanceData?.balance?.available_iqd||0)>=MIN_AMOUNT);
  const targetsFor = f => allowedReceiveOptions(f).filter(t => t!==f && free(t));

  let from = FROM_OPTIONS.includes(fromSel.value) ? fromSel.value : (FROM_OPTIONS[0]||'');
  let targets = targetsFor(from);

  // first send-wallet is locked or has no open route out → start on one that works
  if(!free(from) || !targets.length){
    const alt = FROM_OPTIONS.find(k => free(k) && targetsFor(k).length);
    if(alt){ from = alt; targets = targetsFor(from); }
  }
  // nothing open anywhere: leave the blocked state visible rather than fake a pair
  if(!targets.length) return;

  fromSel.value = from;
  toSel.value = targets.includes(toSel.value) ? toSel.value : targets[0];
}
// 0.85 → "15", 0.825 → "17.5" (no trailing zeros)
function fmtPct(n){ return String(Math.round(n*100)/100); }
function formatNum(num){ return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ","); }
function fmtOrderNo(n){ return '\u2068#P-'+String(n).padStart(6,'0')+'\u2069'; }
function closeModal(){ document.getElementById('tgModal').style.display='none'; }
function updateWallet(){
  const key = document.getElementById('from').value;
  const internal=key==='AccountBalance';
  const info = getWalletInfo(key);
  const numEl = document.getElementById('myNum');
  const copyBtn = document.querySelector('.wallet-row .copy-btn');
  if(!internal && WALLETS_STATE==='loading' && !info.number){
    numEl.innerHTML=_skb(116,13);
    numEl.classList.remove('locked-text');
  } else if(internal){
    numEl.textContent='باڵانسی بەردەست: '+(document.getElementById('balanceAvailable')?.textContent||'—');
    numEl.classList.remove('locked-text');
    if(copyBtn)copyBtn.style.display='none';
  } else if(info.locked){
    numEl.innerHTML = ICON.lock + '<span>ئەم شێوازە لەئێستادا بەردەست نییە</span>';
    numEl.classList.add('locked-text');
    if(copyBtn) copyBtn.style.display = 'none';
  } else if(!info.number){
    numEl.textContent = key ? 'ژمارە دیاری نەکراوە' : '—';
    numEl.classList.add('locked-text');
    if(copyBtn) copyBtn.style.display = 'none';
  } else {
    numEl.textContent = info.number;
    numEl.classList.remove('locked-text');
    if(copyBtn) copyBtn.style.display = '';
  }
  const proof=document.getElementById('grpProof');if(proof)proof.hidden=internal;
  if(internal && typeof loadMyBalance==='function')loadMyBalance();
  updateSenderIdentityFields();
  refreshTrigger('from');
  calc();
}

function updateSenderIdentityFields(){
  const from=document.getElementById('from')?.value||'';
  const carrier=needsSenderPhone(from),internal=from==='AccountBalance';
  const nameField=document.getElementById('senderNameField');
  const phoneField=document.getElementById('senderPhoneField');
  const senderName=document.getElementById('userSenderName');
  const senderPhone=document.getElementById('userSenderPhone');

  if(nameField) nameField.style.display=(carrier||internal)?'none':'';
  if(phoneField) phoneField.style.display=carrier?'':'none';
  if(senderName) senderName.disabled=carrier||internal;
  if(senderPhone){
    senderPhone.disabled=!carrier;
    if(!carrier) senderPhone.value='';
  }
  clearFieldError(carrier?'userSenderName':'userSenderPhone');
}
function updatePlaceholder(){
  refreshTrigger('receiveVia');
  // A card wallet (ex_wallets.recipient_format = 'card') takes a card number,
  // not a 07-prefixed 11-digit Iraqi mobile number.
  const to = document.getElementById('receiveVia').value;
  const inp = document.getElementById('userPhone');
  if(inp) inp.placeholder = recipientIsCard(to) ? 'ژمارەی کارتی '+((METHOD_META[to]&&METHOD_META[to].label)||to) : 'ژمارەی وەرگرە';
}

function setQuickAmount(val){
  document.getElementById('amt').value = formatNum(String(val));
  clearFieldError('amt');
  calc();
}

function getAmtRaw(){
  return document.getElementById('amt').value.replace(/,/g,'');
}

function formatAmtField(el){
  const cursorFromEnd = el.value.length - el.selectionEnd;
  let raw = el.value.replace(/[^\d.]/g,'');
  const firstDot = raw.indexOf('.');
  if(firstDot !== -1){ raw = raw.slice(0, firstDot+1) + raw.slice(firstDot+1).replace(/\./g,''); }
  let [intPart, decPart] = raw.split('.');
  const formattedInt = intPart ? formatNum(intPart) : '';
  const formatted = decPart !== undefined ? formattedInt+'.'+decPart : formattedInt;
  el.value = formatted;
  const newPos = Math.max(formatted.length - cursorFromEnd, 0);
  el.setSelectionRange(newPos, newPos);
}

function updateSubmitState(from,to){
  const btn=document.getElementById('submitBtn');
  if(!btn || btn.dataset.submitting==='1') return;
  if(kycExchangeBlocked()){
    btn.disabled=true;
    btn.innerHTML='پشتڕاستکردنەوەی ناسنامە پێویستە';
    return;
  }
  if(!hasWallets()){
    btn.disabled=true;
    btn.innerHTML = WALLETS_STATE==='loading' ? 'بارکردنی واڵێتەکان…' : 'هیچ واڵێتێک بەردەست نییە';
    return;
  }
  const anyLocked = getWalletInfo(from).locked || getWalletInfo(to).locked;
  const same = from===to;
  const closed = !same && !routeAllowed(from,to);
  const amt = parseFloat(getAmtRaw())||0;
  const tooSmall = amt>0 && amt<MIN_AMOUNT;
  const fractionalIqd=amt>0&&from!=='USDT'&&!Number.isSafeInteger(amt);
  btn.disabled = anyLocked || same || closed || tooSmall || fractionalIqd;
  btn.innerHTML = anyLocked ? 'ئەم شێوازە لەئێستادا بەردەست نییە'
    : same ? 'هەمان واڵێت نابێت'
    : closed ? 'ئەم گۆڕینەوەیە داخراوە'
    : tooSmall ? 'کەمترین بڕ '+formatNum(MIN_AMOUNT)+' دینارە'
    : fractionalIqd ? 'بڕەکە دەبێت دیناری تەواو بێت'
    : 'ناردنی داواکاری';
}
function calc(){
  const val=getAmtRaw();
  const amt=parseFloat(val)||0;
  const from=document.getElementById('from').value;
  const to=document.getElementById('receiveVia').value;
  refreshFormHints();
  updateSubmitState(from,to);
  document.getElementById('formattedHint').innerText=formatNum(val)+(from==='USDT'?' $':' IQD');
  const totalEl=document.getElementById('totalDisplay');
  for(const id of ['bdPayoutRow','bdRoundingRow','payoutRoundingNote']){
    const node=document.getElementById(id);if(node)node.hidden=true;
  }
  document.getElementById('xcSumResult')?.classList.remove('has-payout');
  const feeEl=document.getElementById('feeDisplay');
  feeEl.hidden=true;
  const bdRate=document.getElementById('bdRate');
  const bdFee=document.getElementById('bdFee');
  const bdSent=document.getElementById('bdSent');
  const setBd=(r,f)=>{ if(bdRate) bdRate.textContent=r; if(bdFee) bdFee.textContent=f; };
  // A rate line only means something when the two sides are different
  // currencies; IQD → IQD is a fee, so the row is hidden instead of
  // printing "1 = 1".
  const showRate=(on)=>{ const row=document.getElementById('bdRateRow'); if(row) row.hidden=!on; };
  const showFee=(on)=>{ const row=document.getElementById('bdFeeRow'); if(row) row.hidden=!on; };
  const isUsdt = from==='USDT' || to==='USDT';
  if(bdSent) bdSent.textContent = amt>0 ? (formatNum(from==='USDT'?amt:Math.floor(amt))+(from==='USDT'?' $':' IQD')) : '—';
  const sentRow=document.getElementById('bdSentRow');
  if(sentRow) sentRow.hidden = !(amt>0);
  showRate(isUsdt);
  showFee(true);
  updateHeaderRate();

  if(from===to){ totalEl.innerText='هەمان واڵێت نابێت'; totalEl.classList.add('warn-text'); feeEl.innerText=''; setBd('—','—'); showRate(false); showFee(false); return; }
  const rawRate=RATES[from+'>'+to];
  const r=rawRate&&!isUsdt?ProxoPricing.effectiveRate(rawRate,amt):rawRate;
  const tierRow=document.getElementById('bdTierRow'),tierHint=document.getElementById('bdTierHint');
  if(tierRow)tierRow.hidden=true;if(tierHint)tierHint.hidden=true;
  // Closed direction: show it as closed. Never fall back to a guessed rate and
  // never quietly move the order to a different wallet.
  if(!routeAllowed(from,to)){
    totalEl.innerText='ئەم گۆڕینەوەیە داخراوە';
    totalEl.classList.add('warn-text');
    const toLbl=(METHOD_META[to]&&METHOD_META[to].label)||to;
    feeEl.innerText = getWalletInfo(to).locked ? '' : ('گۆڕینەوە بۆ '+toLbl+' لە ئێستادا بەردەست نییە');
    feeEl.hidden=!feeEl.innerText;
    setBd('داخراوە','—');
    showRate(false); showFee(false);
    return;
  }
  totalEl.classList.remove('warn-text');

  // rate line — the exact multiplier or fee the order will be settled at
  if(r.type==='multiplier')      setBd('1 = '+fmtPct(r.value), '—');
  else if(r.type==='fee_percent')setBd('—', fmtPct(r.value)+'%');
  else                           setBd('—', formatNum(r.value)+' IQD');
  // Amount-tiered fee: say which percentage this amount gets and where the tier changes.
  if(rawRate&&rawRate.tier&&!isUsdt&&amt>0){
    const pct=ProxoPricing.tierPercent(rawRate,amt);
    const pctEl=document.getElementById('bdTierPct');
    if(tierRow&&pctEl&&pct!==null){pctEl.textContent=fmtPct(pct)+'%';tierRow.hidden=false;}
    if(tierHint){tierHint.textContent=tierHintText(rawRate.tier);tierHint.hidden=false;}
  }

  if(amt>0 && amt<MIN_AMOUNT){
    totalEl.innerText='کەمترین بڕ '+formatNum(MIN_AMOUNT)+' دینارە';
    totalEl.classList.add('warn-text');
    feeEl.innerText='';
    return;
  }
  if(amt>0&&from!=='USDT'&&!Number.isSafeInteger(amt)){
    totalEl.innerText='بڕەکە دەبێت دیناری تەواو بێت';totalEl.classList.add('warn-text');feeEl.innerText='';return;
  }
  let final=0, feeTxt='', feeVal=0,displayFee=0;
  if(r.type==='fee_percent'){
    feeVal=amt*r.value/100; final=amt-feeVal;
    if(bdFee) bdFee.textContent = amt>0 ? (formatNum(Math.floor(feeVal))+' IQD ('+fmtPct(r.value)+'%)') : (fmtPct(r.value)+'%');
  }else if(r.type==='fee_fixed'){
    feeVal=r.value; final=Math.max(0, amt-feeVal);
    if(bdFee) bdFee.textContent = formatNum(Math.floor(feeVal))+' IQD';
  }else{
    final=amt*r.value;
    // A multiplier under 1 (carrier credit transfers) is a straight cut off
    // the amount, so it reads as a rate — "کرێ: 15%" — rather than an amount.
    if(r.value<1){
      feeVal=amt-final;
      if(bdFee) bdFee.textContent = amt>0
        ? (formatNum(Math.floor(feeVal))+' IQD ('+fmtPct(100-r.value*100)+'%)')
        : (fmtPct(100-r.value*100)+'%');
    }else{ showFee(false); if(bdFee) bdFee.textContent='بێ کرێ'; }
  }
  // Same decimal calculation as the database (ex_order_quote).
  const baseQuote=isUsdt?null:ProxoPricing.quote(amt,r);
  const basePayout=baseQuote?baseQuote.total:Math.floor(final);
  displayFee=baseQuote?baseQuote.fee:Math.max(0,amt-basePayout);
  if(baseQuote){final=baseQuote.total;if(bdFee&&amt>0)bdFee.textContent=formatNum(baseQuote.fee)+' IQD';}
  const expected=baseQuote?final:Math.floor(final);
  totalEl.innerText=formatNum(expected)+(to==='USDT'?' $':' IQD');
  feeEl.innerText=amt>0 && !isUsdt ? 'حمولە: '+formatNum(displayFee)+' IQD' : '';
  const payout=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.plan(expected,to):null;
  const expectedLabel=document.getElementById('bdExpectedLabel');
  if(expectedLabel)expectedLabel.textContent=payout?.applies?'بڕ دوای لێبڕین':'بڕی وەرگیراو';
  const resultBox=document.getElementById('xcSumResult');
  if(amt>0&&payout?.applies){
    const payoutRow=document.getElementById('bdPayoutRow'),creditRow=document.getElementById('bdRoundingRow');
    const payoutValue=document.getElementById('payoutDisplay'),creditValue=document.getElementById('roundingDisplay');
    const note=document.getElementById('payoutRoundingNote');
    if(payoutRow)payoutRow.hidden=false;
    if(payoutValue)payoutValue.textContent=payout.valid?formatNum(payout.payout_iqd)+' IQD':'—';
    if(creditRow)creditRow.hidden=!payout.valid||payout.remainder_iqd===0;
    if(creditValue)creditValue.textContent=payout.valid?formatNum(payout.remainder_iqd)+' IQD':'—';
    if(note){
      note.hidden=false;
      note.textContent=!payout.valid?'بڕی کۆتایی دەبێت دیناری تەواو بێت؛ بڕ یان ڕێگای مامەڵەکە بگۆڕە.':
        payout.payout_iqd===0?(payout.remainder_iqd>0?
          'هیچ بڕێک بۆ وەرگر نانێردرێت؛ دوای پەسەندکردن هەموو بڕی ماوە بۆ باڵانسی هەژمارەکەت دەگەڕێتەوە.':
          'بڕی کۆتایی سفرە؛ هیچ ناردنێک یان زیادکردنێک بۆ باڵانس ئەنجام نادرێت.'):
          'ناردنی دینار بە هەزار ئەنجام دەدرێت.'+(payout.remainder_iqd>0?' بڕی ماوە دوای پەسەندکردن خۆکارانە بۆ باڵانسی هەژمارەکەت دەگەڕێتەوە.':'');
    }
    if(!payout.valid){const btn=document.getElementById('submitBtn');if(btn)btn.disabled=true;}
  }
  // when the payout row is shown it is the final line; otherwise «بڕی وەرگیراو» is
  if(resultBox)resultBox.classList.toggle('has-payout',!!(amt>0&&payout?.applies));
  return payout;
}

function _validateOrderFields(){
  clearAllOrderFieldErrors();
  const senderName=document.getElementById('userSenderName')?.value||'';
  const senderPhone=document.getElementById('userSenderPhone')?.value||'';
  const profileName=(curProfile&&curProfile.full_name)||'';
  const phone=document.getElementById('userPhone').value;
  const file=document.getElementById('fileInput').files[0];
  const amtValue=getAmtRaw();
  const from=document.getElementById('from').value, to=document.getElementById('receiveVia').value;
  const payout=calc();
  const carrierSender=needsSenderPhone(from);
  let ok=true;
  if(carrierSender && !/^07\d{9}$/.test(senderPhone)){
    setFieldError('userSenderPhone','ژمارەی نێرەر دەبێت بە 07 دەست پێبکات و 11 ژمارە بێت');
    ok=false;
  }else if(from!=='AccountBalance' && !carrierSender && (!profileName || normalizePersonName(senderName)!==normalizePersonName(profileName))){
    setFieldError('userSenderName','ناوی خاوەنی هەژماری نێرەر دەبێت لەگەڵ ناوی پڕۆفایلی Proxo یەکسان بێت');
    ok=false;
  }
  if(!amtValue || parseFloat(amtValue)<=0){ setFieldError('amt','بڕی پارە داخڵ بکە'); ok=false; }
  else if(parseFloat(amtValue)<MIN_AMOUNT){ setFieldError('amt','کەمترین بڕی مامەڵە '+formatNum(MIN_AMOUNT)+' دینارە'); ok=false; }
  else if(from!=='USDT'&&!Number.isSafeInteger(Number(amtValue))){setFieldError('amt','بڕەکە دەبێت دیناری تەواو بێت');ok=false;}
  if(to!=='USDT'&&to!=='AccountBalance'&&(!payout||!payout.valid)){
    setFieldError('amt','نەتوانرا بڕی ناردن و گەڕاندنەوە دیاری بکرێت؛ بڕ یان ڕێگاکە بپشکنە.');ok=false;
  }
  if(recipientIsCard(to)){
    if(!/^\d{6,32}$/.test(phone)){ setFieldError('userPhone','ژمارەی کارت دەبێت تەنها ژمارە بێت'); ok=false; }
  } else if(!phone.startsWith("07")||phone.length!==11){ setFieldError('userPhone','تەنها ژمارەی عێراقی (07) بە 11 ژمارە داخڵ بکە'); ok=false; }
  if(from==='AccountBalance' && (!Number.isSafeInteger(Number(amtValue)) ||
      Number(amtValue)>Number(_myBalanceData?.balance?.available_iqd||0))){
    setFieldError('amt','بڕەکە دەبێت دیناری تەواو بێت و لە باڵانسی بەردەست زیاتر نەبێت');ok=false;
  }
  if(from!=='AccountBalance' && !file){ setFieldError('fileInput','وێنەی پسووڵەی پارەدان زیاد بکە'); ok=false; }
  else if(from!=='AccountBalance' && file?.size>10*1024*1024){ setFieldError('fileInput','قەبارەی وێنەکە دەبێت لە 10 MB کەمتر بێت'); ok=false; }
  if(from===to){ showToast('لە هەمان واڵێت وەرناگیرێت — ڕێگایەکی جیاواز هەڵبژێرە بۆ وەرگرتن','warning','هەمان واڵێت هەڵبژێردراوە'); ok=false; }
  if(getWalletInfo(from).locked){ showToast('ئەم شێوازە لەئێستادا بەردەست نییە بۆ ناردن','error','بەردەست نییە'); ok=false; }
  if(getWalletInfo(to).locked){ showToast('ئەم شێوازە لەئێستادا بەردەست نییە بۆ وەرگرتن','error','بەردەست نییە'); ok=false; }
  else if(from!==to && !getWalletInfo(from).locked && !routeAllowed(from,to)){
    showToast('گۆڕینەوە لەم واڵێتەوە بۆ ئەوی تر داخراوە — واڵێتێکی تر بۆ وەرگرتن هەڵبژێرە','error','گۆڕینەوە داخراوە'); ok=false;
  }
  if(!ok) showToast('تکایە خانە پێویستەکان پڕ بکەرەوە','error');
  return ok;
}

async function openOrderConfirm(){
  if(document.getElementById('from').value==='AccountBalance')await loadMyBalance();
  if(kycExchangeBlocked()){ showKycExchangeBlocked(); return; }
  if(!_validateOrderFields()) return;
  const senderName=document.getElementById('userSenderName').value;
  const senderPhone=document.getElementById('userSenderPhone').value;
  const phone=document.getElementById('userPhone').value;
  const amtValue=getAmtRaw();
  const from=document.getElementById('from').value, to=document.getElementById('receiveVia').value;
  const senderIdentityRow=from==='AccountBalance' ? '' : needsSenderPhone(from)
    ? '<div class="confirm-row"><span class="confirm-row-label">ژمارەی نێرەر</span><span class="confirm-row-value" dir="ltr">'+escHtml(senderPhone)+'</span></div>'
    : '<div class="confirm-row"><span class="confirm-row-label">ناوی نێرەر</span><span class="confirm-row-value">'+escHtml(senderName)+'</span></div>';
  const payout=calc();
  const totalTxt=document.getElementById('totalDisplay').innerText;
  const payoutRows=payout?.applies&&payout.valid?
    '<div class="confirm-row"><span class="confirm-row-label">بڕ دوای لێبڕین</span><span class="confirm-row-value" dir="ltr">'+escHtml(totalTxt)+'</span></div>'+
    '<div class="confirm-row"><span class="confirm-row-label">بڕی ناردن بۆ وەرگر</span><span class="confirm-row-value accent" dir="ltr">'+formatNum(payout.payout_iqd)+' IQD</span></div>'+
    '<div class="confirm-row"><span class="confirm-row-label">بڕی باڵانسی نەنێردراو</span><span class="confirm-row-value" dir="ltr">'+formatNum(payout.remainder_iqd)+' IQD</span></div>'+
    '<p class="payout-rounding-note">'+(payout.payout_iqd===0?'هیچ ناردنێکی دەرەکی ئەنجام نادرێت. ':'')+
      (payout.remainder_iqd>0?'بڕی ماوە دوای پەسەندکردنی ئادمین بۆ باڵانسی هەژماری تۆ دەگەڕێتەوە.':'بڕێک بۆ گەڕاندنەوە نەماوەتەوە.')+'</p>':
    '<div class="confirm-row"><span class="confirm-row-label">بڕی وەرگیراو</span><span class="confirm-row-value accent" dir="ltr">'+escHtml(totalTxt)+'</span></div>';
  const displayAmt=(from==='USDT')?`${formatNum(amtValue)}$`:`${formatNum(amtValue)} IQD`;
  document.getElementById('confirmSummary').innerHTML =
    '<div class="confirm-row"><span class="confirm-row-label">'+methodIconHTML(from,'sz-sm')+' لە</span><span class="confirm-row-value">'+escHtml(METHOD_META[from].label)+'</span></div>'
    + '<div class="confirm-row"><span class="confirm-row-label">'+methodIconHTML(to,'sz-sm')+' بۆ</span><span class="confirm-row-value">'+escHtml(METHOD_META[to].label)+'</span></div>'
    + '<div class="confirm-row"><span class="confirm-row-label">بڕی پارە</span><span class="confirm-row-value" dir="ltr">'+displayAmt+'</span></div>'
    + payoutRows
    + senderIdentityRow
    + '<div class="confirm-row"><span class="confirm-row-label">ژمارەی وەرگر</span><span class="confirm-row-value" dir="ltr">'+escHtml(phone)+'</span></div>';
  const overlay=document.getElementById('confirmSheet');
  openSheet(overlay);
}
// «بڕی باڵانسی نەنێردراو» — the (i) next to it opens a bottom sheet that explains why.
function openRoundingInfo(){
  const sheet=document.getElementById('roundingInfoSheet');
  if(sheet) openSheet(sheet);
}
function closeRoundingInfo(){
  const sheet=document.getElementById('roundingInfoSheet');
  if(sheet) closeSheet(sheet);
}
function closeOrderConfirm(){
  closeSheet(document.getElementById('confirmSheet'));
}
async function confirmAndSubmitOrder(){
  closeOrderConfirm();
  await processOrder();
}

function waitForNetworkRetry(ms){
  return new Promise(resolve=>setTimeout(resolve,ms));
}

function isTransientNetworkError(error){
  const status=Number(error?.statusCode||error?.status||0);
  const message=String(error?.message||error||'');
  return status===408 || status===429 || status>=500 || /failed to fetch|networkerror|network request failed|load failed|timeout/i.test(message);
}

async function getOrderSession(){
  try{
    const {data,error}=await sb.auth.getSession();
    if(error) throw error;
    if(data?.session){ activeSession=data.session; return data.session; }
  }catch(error){
    const validUntil=Number(activeSession?.expires_at||0)*1000;
    if(activeSession?.access_token && validUntil>Date.now()+30000) return activeSession;
    throw new Error(isTransientNetworkError(error)?'SESSION_NETWORK_ERROR':(error?.message||'Auth session missing'));
  }
  const validUntil=Number(activeSession?.expires_at||0)*1000;
  if(activeSession?.access_token && validUntil>Date.now()+30000) return activeSession;
  throw new Error('Auth session missing');
}

async function uploadReceiptWithRetry(fileData,ext,contentType='image/jpeg'){
  let lastError=null;
  for(let attempt=0;attempt<3;attempt++){
    const path=`${curUser.id}/${Date.now()}_${Math.random().toString(36).slice(2,8)}.${ext}`;
    try{
      const {error}=await sb.storage.from('receipts').upload(path,fileData,{ upsert:false, contentType:contentType||'image/jpeg' });
      if(error) throw error;
      const publicUrl=sb.storage.from('receipts').getPublicUrl(path).data.publicUrl;
      if(!publicUrl) throw new Error('RECEIPT_UPLOAD_FAILED');
      return publicUrl;
    }catch(error){
      lastError=error;
      if(!isTransientNetworkError(error) || attempt===2) break;
      await waitForNetworkRetry(700*(attempt+1));
    }
  }
  throw new Error(isTransientNetworkError(lastError)?'RECEIPT_UPLOAD_NETWORK':'RECEIPT_UPLOAD_FAILED');
}

let _balanceOrderKey=null;
for(const id of ['from','receiveVia','amt','userPhone'])document.getElementById(id)?.addEventListener('input',()=>{_balanceOrderKey=null;});
async function processOrder(){
  if(!_validateOrderFields()) return;

  if(honeypotTripped()){
    // Silent drop: the bot sees a normal success screen and learns nothing.
    reportEvent('honeypot', 'خانەی شاراوە پڕکرایەوە', { from:document.getElementById('from').value });
    showResultModal({ tone:'success', title:'داواکاریەکەت نێردرا',
      message:'داواکارییەکەت وەرگیرا و لە چاوەڕوانیدایە.' });
    return;
  }
  const senderName=document.getElementById('userSenderName').value;
  const senderPhone=document.getElementById('userSenderPhone').value;
  const phone=document.getElementById('userPhone').value;
  const selectedFile=document.getElementById('from').value==='AccountBalance'?null:document.getElementById('fileInput').files[0];
  const amtValue=getAmtRaw();
  const from=document.getElementById('from').value, to=document.getElementById('receiveVia').value;

  const btn=document.getElementById('submitBtn'); btn.dataset.submitting='1'; btn.disabled=true; btn.innerHTML=ICON.spin+' ناردن...';
  let orderStage='prepare';
  try{
    // Fresh check against the database before anything is uploaded: an admin
    // may have requested verification after this page was opened.
    orderStage='kyc_gate';
    const kycNow=await loadKycStatus(true);
    if(kycNow && kycNow.exchange_blocked){
      throw Object.assign(new Error('KYC_REQUIRED_FOR_EXCHANGE'),{code:'KYC_REQUIRED_FOR_EXCHANGE'});
    }
    let receiptUrl=null, receiptHash=null;
    if(selectedFile){
      orderStage='receipt_read';
      const file=_receiptFileSnapshot || await _receiptFileSnapshotPromise;
      if(!file) throw new Error('FILE_READ_PERMISSION');
      orderStage='receipt_hash';
      const digest=await crypto.subtle.digest('SHA-256',file.bytes);
      receiptHash=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
      const ext=(file.name.split('.').pop()||'jpg').toLowerCase().replace(/[^a-z0-9]/g,'').slice(0,5)||'jpg';
      orderStage='receipt_upload';
      receiptUrl=await uploadReceiptWithRetry(file.bytes,ext,file.type);
    }

    orderStage='session';
    const _orderSession=await getOrderSession();
    let orderResponse;
    try{
      orderStage='order_request';
      orderResponse=await fetch('/api/orders',{
        method:'POST',
        headers:{'Content-Type':'application/json','Authorization':'Bearer '+_orderSession.access_token},
        body:JSON.stringify({
          from_method:from,to_method:to,amount:parseFloat(amtValue),phone,
          sender_name:needsSenderPhone(from)?null:senderName,
          sender_phone:needsSenderPhone(from)?senderPhone:null,
          receipt_url:receiptUrl,receipt_hash:receiptHash,contact_reference:'',
          request_key:from==='AccountBalance'?(_balanceOrderKey=_balanceOrderKey||crypto.randomUUID()):undefined
        })
      });
    }catch(_){ throw new Error('ORDER_NETWORK_ERROR'); }
    orderStage='order_response';
    let orderPayload={};
    try{ orderPayload=await orderResponse.json(); }catch(_){}
    if(!orderResponse.ok || !orderPayload.order){
      const responseError=new Error(orderPayload.error||'نەتوانرا داواکارییەکە تۆمار بکرێت');
      responseError.status=orderResponse.status;
      responseError.code=orderPayload.code||('ORDER_HTTP_'+orderResponse.status);
      throw responseError;
    }
    const orderRow=orderPayload.order;_balanceOrderKey=null;
    if(from==='AccountBalance')await loadMyBalance();

    // The Telegram alert is sent by /api/notify-order. The bot token lives in a
    // Vercel environment variable, so it never reaches the browser, and the
    // caption is rebuilt server-side from the saved row (amounts can't be faked).
    try{
      if(_orderSession){
        await fetch('/api/notify-order', {
          method:'POST',
          headers:{ 'Content-Type':'application/json', 'Authorization':'Bearer '+_orderSession.access_token },
          body: JSON.stringify({ order_id: orderRow.id })
        });
      }
    }catch(_){ /* the order is already saved — never block the user on this */ }

    showResultModal({
      tone:'success',
      title:'داواکارییەکەت نێردرا',
      message:'داواکارییەکەت بە سەرکەوتوویی تۆمارکرا و بەم زووانە پێداچوونەوەی بۆ دەکرێت.',
      orderCode: orderCodeOf(orderRow),
      primaryText:'تەواو'
    });
    document.getElementById('fileInput').value='';
    onFileSelected(document.getElementById('fileInput'));
    document.getElementById('userPhone').value='';
    document.getElementById('userSenderPhone').value='';
    document.getElementById('amt').value='';
    clearAllOrderFieldErrors();
    calc();
  }catch(e){
    if(e && (e.code==='KYC_REQUIRED_FOR_EXCHANGE' || /KYC_REQUIRED_FOR_EXCHANGE/.test(String(e.message||'')))){
      // Expected business rule, not an application error.
      await loadKycStatus(true);
      showKycExchangeBlocked();
      return;
    }
    reportAppError(e,{
      operation:'order_submission', stage:orderStage,
      from_method:from, to_method:to,
      file_size:_receiptFileSnapshot?.size||selectedFile?.size||null,
      file_type:_receiptFileSnapshot?.type||selectedFile?.type||null
    });
    showResultModal({
      tone:'error',
      title:'هەڵەیەک ڕووی دا',
      message: (e && e.message) ? (kuErr(e.message)||e.message) : 'نەتوانرا داواکارییەکە بنێردرێت. تکایە دووبارە هەوڵ بدەرەوە.',
      primaryText:'باشە'
    });
  }
  finally{ btn.dataset.submitting='0'; btn.disabled=false; btn.innerHTML='ناردنی داواکاری'; updateSubmitState(from,to); }
}

let _historyChannel=null;
let _ordersLoaded=false, _historyRetryTimer=null, _historyRetryDelay=3000;
function scheduleHistoryRetry(){
  if(_historyRetryTimer) return;
  _historyRetryTimer=setTimeout(()=>{ _historyRetryTimer=null; if(curUser) loadHistory(); }, _historyRetryDelay);
  _historyRetryDelay=Math.min(_historyRetryDelay*2, 30000);
}
async function loadHistory(){
  let data, error;
  try{ ({data,error}=await sb.from('ex_orders').select('*').eq('user_id',curUser.id).order('created_at',{ascending:false})); }
  catch(e){ error=e; }
  // a slow or failed connection never shows "no transactions": the skeleton (or the last list) stays and we retry
  if(error || !Array.isArray(data)){ scheduleHistoryRetry(); return; }
  _historyRetryDelay=3000;
  const {data:feedbackRows}=await sb.from('ex_order_feedback').select('order_id,rating,comment,created_at').eq('user_id',curUser.id);
  const feedbackByOrder=new Map((feedbackRows||[]).map(row=>[String(row.order_id),row]));
  renderHistory((data||[]).map(order=>({...order,feedback:feedbackByOrder.get(String(order.id))||null})));
  if(_historyChannel){ try{ sb.removeChannel(_historyChannel); }catch(_){} }
  _historyChannel=sb.channel('ex_orders_'+curUser.id)
    .on('postgres_changes',{event:'*',schema:'public',table:'ex_orders',filter:'user_id=eq.'+curUser.id}, ()=>{ loadHistory(); })
    .subscribe();
}
// ══════════════════════════════════════════════════════════════
// ═══ ORDERS — one shared list feeding the home preview and the
// ═══ /transactions page (search by ID, status + time filters)
// ══════════════════════════════════════════════════════════════
let _orders = [];
let _txStatus = 'all', _txTime = 'all', _txQuery = '';

// Every order carries a 12-character public ID: "P" + 11 chars, made by the
// database itself (ex_gen_order_code). order_number is the old numeric ID and
// is only used as a fallback for rows created before the change.
function orderCodeOf(o){
  if(o && o.order_code) return o.order_code;
  return 'P' + String((o && o.order_number) || 0).padStart(11,'0');
}
function fmtCode(code){ return '\u2068' + code + '\u2069'; }
// ── copy ───────────────────────────────────────────────────────
// "Copied" is shown on the button itself (a check mark + «کۆپی کرا» for 1.6 s),
// not in a toast. A toast is only used when the copy really failed.
async function copyText(text){
  try{ if(navigator.clipboard && navigator.clipboard.writeText){ await navigator.clipboard.writeText(text); return true; } }catch(_){}
  try{
    const ta=document.createElement('textarea');
    ta.value=text; ta.setAttribute('readonly',''); ta.style.cssText='position:fixed;top:-1000px;opacity:0';
    document.body.appendChild(ta); ta.select();
    const ok=document.execCommand('copy'); ta.remove(); return ok;
  }catch(_){ return false; }
}
function flashCopied(btn){
  if(!btn) return;
  if(btn._copyTimer) clearTimeout(btn._copyTimer);
  else{ btn._copyHTML=btn.innerHTML; btn.style.minWidth=btn.offsetWidth+'px'; }
  btn.classList.add('is-copied');
  btn.innerHTML='<svg class="pxi pxi-copied" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M20 6 9 17l-5-5"/></svg><span>کۆپی کرا</span>';
  btn._copyTimer=setTimeout(()=>{
    btn.innerHTML=btn._copyHTML; btn.classList.remove('is-copied'); btn.style.minWidth='';
    btn._copyTimer=null; btn._copyHTML=null;
  },1600);
}
async function copyWithFeedback(text, btn){
  if(await copyText(text)) flashCopied(btn);
  else showToast('نەتوانرا کۆپی بکرێت','error');
}
function copyOrderCode(code, ev){
  if(ev){ ev.stopPropagation(); }
  const btn=ev && ev.currentTarget;      // read before the first await: currentTarget is cleared afterwards
  copyWithFeedback(code, btn);
}

// The list remains compact; saved fees, receipts and notes are in the detail sheet.
const TX_STATE = {
  'پەسەندکرا':               { key:'done',     cls:'status-success'    },
  'ڕەتکرا':                  { key:'rejected', cls:'status-danger'     },
  'پێویستی بە ڕاستکردنەوەیە':{ key:'action',   cls:'status-correction' },
  'ڕاستکراوەتەوە':           { key:'pending',  cls:'status-corrected'  },
  'لەژێر پێداچوونەوەدایە':   { key:'pending',  cls:'status-review'     },
  'چاوەڕوانە':               { key:'pending',  cls:''                  },
  'هەڵوەشێنرایەوە':          { key:'cancelled',cls:'status-cancelled'  }
};
const TX_CANCELLED='هەڵوەشێنرایەوە';
function txStateOf(o){
  if(o?.status===TX_CANCELLED) return TX_STATE[TX_CANCELLED];
  return o?.balance_refunded_at ? {key:'done',cls:'status-success'} : (TX_STATE[o && o.status] || {key:'pending',cls:''});
}
// Labels shown to the customer. The stored status values stay as they are.
const TX_LABEL = { 'ڕەتکرا':'ڕەتکرایەوە', 'چاوەڕوانە':'چاوەڕوانی', 'لەژێر پێداچوونەوەدایە':'لەژێر پێداچوونەوە' };
function txLabelOf(o){
  if(o?.status===TX_CANCELLED) return TX_CANCELLED;
  if(o?.balance_refunded_at) return 'پارە گەڕێندرایەوە';
  const s=o?.status||'';
  return TX_LABEL[s]||s;
}
function txAmount(value, method){
  if(value===null||value===undefined||value===''||!['number','string'].includes(typeof value)||
    (typeof value==='string'&&!/^\d+(?:\.\d+)?$/.test(value))||!Number.isFinite(Number(value))||Number(value)<0)return '—';
  return formatNum(Number(value)) + (method==='USDT' ? ' $' : ' IQD');
}
// Date as «DD - MM - YYYY — HH:mm». txWhen() is plain text; txWhenHTML() wraps it in a
// right-to-left isolate so day, month, year and time keep their order inside any container.
function txWhen(iso, withTime){
  if(!iso) return '—';
  const d=new Date(iso); if(isNaN(d)) return '—';
  const p=n=>String(n).padStart(2,'0');
  const date=p(d.getDate())+' - '+p(d.getMonth()+1)+' - '+d.getFullYear();
  return withTime ? date+' — '+p(d.getHours())+':'+p(d.getMinutes()) : date;
}
function txWhenHTML(iso, withTime){ return '<bdi class="tx-date" dir="rtl">'+escHtml(txWhen(iso,withTime))+'</bdi>'; }

// Direction: always «from → to», left to right, so Latin wallet names
// read in the order they are sent. The arrow points the way the money goes.
const TX_ARROW='<span class="tx-route-arrow" aria-hidden="true"><svg class="pxi" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span>';
function txRouteInner(from,to){ return '<span class="tx-route-end">'+escHtml(methodLabel(from))+'</span>'+TX_ARROW+'<span class="tx-route-end">'+escHtml(methodLabel(to))+'</span>'; }
// Flat building blocks shared by the transaction list, the details sheet and the
// standalone summary page (/summarytransaction/…). One visual language, no receipts.
const TF_ICONS={
  ok:'<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>',
  bad:'<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M7 7l10 10M17 7 7 17"/></svg>',
  wait:'<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>',
  warn:'<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 7v6.5"/><path d="M12 17h.01"/></svg>',
  info:'<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/></svg>'
};
const TF_COPY='<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><rect x="8" y="8" width="12" height="12" rx="2.5"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/></svg>';
function tfToneOf(o){
  if(o?.balance_refunded_at||o?.balance_refund_case_id) return 'info';
  const k=txStateOf(o).key;
  return k==='done'?'ok':k==='rejected'?'bad':k==='action'?'warn':k==='cancelled'?'info':'wait';
}
function tfStatusHTML(o){
  return '<span class="tf-status is-'+tfToneOf(o)+'"><i aria-hidden="true"></i>'+escHtml(txLabelOf(o))+'</span>';
}
function tfHeroHTML(o,opts){
  const tone=tfToneOf(o);
  return '<section class="tf-hero is-'+tone+'">'
    + '<span class="tf-hero-ico" aria-hidden="true">'+TF_ICONS[tone]+'</span>'
    + '<small class="tf-hero-label">'+escHtml(opts.label)+'</small>'
    + '<strong class="tf-hero-amount" dir="ltr">'+escHtml(opts.amount)+'</strong>'
    + tfStatusHTML(o)
    + '</section>';
}
// «ژمارەی مامەڵە» row value: the code with a copy button.
function tfCodeHTML(o){
  const code=orderCodeOf(o);
  return '<button type="button" class="tf-copy" onclick="copyOrderCode(\''+escHtml(code)+'\', event)" aria-label="کۆپیکردنی ژمارەی مامەڵە">'
    + '<span dir="ltr">'+escHtml(code)+'</span>'+TF_COPY+'</button>';
}
function tfRouteHTML(o,to){ return '<span class="tf-route" dir="ltr">'+txRouteInner(o.from_method,to||o.to_method)+'</span>'; }
// How the total after the fee is split: whole thousands go to the recipient, the rest
// (under 1,000 IQD) goes back to the customer's account balance.
//   settled order  → the saved settlement (payout_iqd / payout_rounding_iqd)
//   pending order  → the planned split, shown as «will be …»
//   older order    → the total went to the recipient as it was
function tfSplitOf(o){
  const n=v=>{const x=Number(v);return Number.isFinite(x)&&x>=0?x:0;};
  const p=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(o):null;
  if(o?.balance_refunded_at||o?.balance_refund_case_id) return {recipient:0,returned:n(o.refund_case_amount_iqd??o.amount),pending:false,refunded:true};
  if(p&&p.has_settlement&&p.settled) return {recipient:n(p.payout_iqd),returned:n(p.remainder_iqd),pending:false};
  if(p&&p.planned&&p.valid) return {recipient:n(p.payout_iqd),returned:n(p.remainder_iqd),pending:true};
  if(o?.status==='پەسەندکرا') return {recipient:n(o.total),returned:n(o.shortfall_refunded_iqd)||n(o.payout_rounding_iqd),pending:false};
  if(o?.status===TX_CANCELLED) return {recipient:0,returned:n(o.amount),pending:true,cancelled:true};
  return {recipient:0,returned:0,pending:o?.status!=='ڕەتکرا',rejected:o?.status==='ڕەتکرا'};
}
function tfSplitRows(o,split){
  const to=o.to_method;
  if(split.refunded) return '';
  if(split.rejected) return tfRow('بڕی نێردراو بۆ وەرگر',txAmount(0,to),{ltr:true})+tfRow('بڕی گەڕاوە بۆ باڵانس',txAmount(0,'IQD'),{ltr:true,info:true});
  if(split.cancelled) return tfRow('بڕی نێردراو بۆ وەرگر',txAmount(0,to),{ltr:true})+tfRow('بڕی دەگەڕێتەوە بۆ باڵانس',txAmount(split.returned,o.from_method),{ltr:true,info:true});
  return tfRow(split.pending?'بڕی دەنێردرێت بۆ وەرگر':'بڕی نێردراو بۆ وەرگر',txAmount(split.recipient,to),{ltr:true,cls:'is-strong'})
    + tfRow(split.pending?'بڕی دەگەڕێتەوە بۆ باڵانس':'بڕی گەڕاوە بۆ باڵانس',txAmount(split.returned,'IQD'),{ltr:true,info:true,cls:split.returned>0?'is-good':''});
}
function tfRow(label,value,opts){
  if(value===null||value===undefined||value==='') return '';
  const o=opts||{};
  return '<div class="tf-row'+(o.row?' '+o.row:'')+'"><span class="tf-k">'+escHtml(label)
    + (o.info?'<button class="tf-info" type="button" onclick="openSummaryInfo()" aria-label="زانیاری لەسەر ئەم بڕە">i</button>':'')+'</span>'
    + '<span class="tf-v'+(o.cls?' '+o.cls:'')+'"'+(o.ltr?' dir="ltr"':'')+'>'+(o.html?value:escHtml(String(value)))+'</span></div>';
}
function tfSection(title,inner){
  return inner ? '<section class="tf-sec"><h3 class="tf-sec-title">'+escHtml(title)+'</h3><div class="tf-rows">'+inner+'</div></section>' : '';
}
function tfNote(title,text,tone,extra){
  return '<section class="tf-note'+(tone?' is-'+tone:'')+'"><h3 class="tf-sec-title">'+escHtml(title)+'</h3>'
    + (text?'<p>'+escHtml(text)+'</p>':'')+(extra||'')+'</section>';
}

// Short status words for the narrow list column; the full wording stays in the details.
function txShortLabelOf(o){
  if(o?.status===TX_CANCELLED) return 'هەڵوەشاوە';
  if(o?.status==='لەژێر پێداچوونەوەدایە') return 'پێداچوونەوە';
  if(o?.balance_refunded_at) return 'گەڕێندرایەوە';
  if(o?.status==='پێویستی بە ڕاستکردنەوەیە') return 'ڕاستکردنەوە';
  return txLabelOf(o);
}
// One transaction in a list: status icon · route and date · amount and status.
function orderCardHTML(o){
  const tone=tfToneOf(o);
  const refunded=!!o.balance_refunded_at;
  const needsAction=!refunded && o.status==='پێویستی بە ڕاستکردنەوەیە';
  const payout=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(o):null;
  const received=payout?payout.display_amount:o.total;
  const amount=refunded?txAmount(o.amount,'AccountBalance'):txAmount(received,o.to_method);
  const id=escHtml(String(o.id));
  return '<article class="tx-item is-'+tone+'" tabindex="0" role="button"'
    + ' aria-label="'+escHtml(methodLabel(o.from_method)+' بۆ '+methodLabel(refunded?'AccountBalance':o.to_method)+'، '+amount+'، '+txLabelOf(o))+'"'
    + ' onclick="openTxDetail(\''+id+'\')"'
    + ' onkeydown="if(event.key===\'Enter\'||event.key===\' \'){event.preventDefault();openTxDetail(\''+id+'\');}">'
    + '<span class="tx-item-ico" aria-hidden="true">'+TF_ICONS[tone]+'</span>'
    + '<span class="tx-item-main">'
      + '<span class="tx-item-route" dir="ltr">'+txRouteInner(o.from_method,refunded?'AccountBalance':o.to_method)+'</span>'
      + '<span class="tx-item-when">'+txWhenHTML(o.created_at,true)+'</span>'
    + '</span>'
    + '<span class="tx-item-end">'
      + '<strong class="tx-item-amount" dir="ltr">'+escHtml(amount)+'</strong>'
      + '<span class="tx-item-status">'+escHtml(txShortLabelOf(o))+'</span>'
    + '</span>'
    + (needsAction?'<span class="tx-item-hint">پێویستە زانیارییەکانی ئەم مامەڵەیە ڕاست بکەیتەوە</span>':'')
    + '</article>';
}

// ── transaction details ────────────────────────────────────────
let _txSheetId=null;
let _feedbackDraftRating=0;
let _homeFeedbackPromptShownThisSession=false;
let _homeFeedbackPromptQueued=false;
const FEEDBACK_LABELS=['زۆر خراپ','خراپ','ئاسایی','باش','نایاب'];
const FB_STAR='<svg class="fb-star-svg" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3.2l2.6 5.4 5.9.8-4.3 4.1 1.1 5.9L12 16.6 6.7 19.4l1.1-5.9L3.5 9.4l5.9-.8L12 3.2z"/></svg>';

function feedbackOrderSnapshot(order){
  const payout=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(order):null;
  const received=payout?payout.display_amount:order.total;
  const line=(k,v)=>'<div class="fb-line"><span class="fb-k">'+k+'</span><i class="fb-dots" aria-hidden="true"></i><b class="fb-v" dir="ltr">'+escHtml(v)+'</b></div>';
  return '<div class="fb-order" aria-label="پوختەی مامەڵە">'+
    '<div class="fb-order-top"><span class="fb-chip">مامەڵەی پەسەندکراو</span><b class="fb-code" dir="ltr">'+escHtml(orderCodeOf(order))+'</b></div>'+
    '<div class="fb-route" dir="ltr">'+txRouteInner(order.from_method,order.to_method)+'</div>'+
    '<div class="fb-lines">'+line('ناردراو',txAmount(order.amount,order.from_method))+line('وەرگیراو',txAmount(received,order.to_method))+'</div>'+
    '<div class="fb-date">'+txWhenHTML(order.decided_at||order.created_at,true)+'</div></div>';
}
// Feedback = stars + an optional comment. Nothing else.
function fbFlatHTML(order,cfg){
  if(!order||order.status!=='پەسەندکرا') return '';
  const f=order.feedback;
  const head=cfg.title?'<h3 class="tf-sec-title">'+(f?'هەڵسەنگاندنی تۆ':'هەڵسەنگاندنی مامەڵە')+'</h3>':'';
  if(f){
    const r=Math.max(0,Math.min(5,Number(f.rating)||0));
    return '<section class="tf-sec tf-fb is-done">'+head
      + '<div class="fb-stars tf-stars is-readonly" role="img" aria-label="'+r+' لە 5 ئەستێرە">'
      + Array.from({length:5},(_,i)=>'<span class="fb-star tf-star'+(i<r?' selected':'')+'" aria-hidden="true">'+FB_STAR+'</span>').join('')+'</div>'
      + (f.comment?'<p class="tf-fb-comment">'+escHtml(f.comment)+'</p>':'')
      + '</section>';
  }
  return '<section class="tf-sec tf-fb">'+head
    + '<div class="fb-stars tf-stars feedback-star-picker" role="radiogroup" aria-label="هەڵبژاردنی ژمارەی ئەستێرە">'
    + Array.from({length:5},(_,i)=>'<button type="button" class="fb-star feedback-star tf-star" data-rating="'+(i+1)+'" role="radio" aria-checked="false" aria-label="'+(i+1)+' ئەستێرە" onclick="'+cfg.onSelect+'('+(i+1)+')">'+FB_STAR+'</button>').join('')+'</div>'
    + '<textarea id="'+cfg.ids.comment+'" class="tf-input" maxlength="1000" rows="3" placeholder="تێبینییەکەت بنووسە (ئارەزوومەندانە)" aria-label="تێبینی"></textarea>'
    + '<button type="button" class="tf-btn" id="'+cfg.ids.submit+'" onclick="'+cfg.onSubmit+'">ناردنی هەڵسەنگاندن</button>'
    + '<div class="fb-error tf-err" id="'+cfg.ids.error+'" role="alert"></div>'
    + '</section>';
}
function renderOrderFeedback(order,opts){
  opts=opts||{};
  return fbFlatHTML(order,{
    title:!opts.sheet,
    ids:{comment:'orderFeedbackComment',submit:'orderFeedbackSubmit',error:'orderFeedbackError'},
    onSelect:'selectOrderFeedbackRating',
    onSubmit:'submitOrderFeedback(\''+escHtml(String(order.id))+'\')'
  });
}
let _summaryOrder=null;
let _summaryFeedbackDraftRating=0;
let _summaryInfoPreviousOverflow='';
function summaryDetailRow(label,value,opts){
  const o=opts||{};
  const rendered=o.html?String(value??''):escHtml(value===null||value===undefined?'—':String(value));
  return '<div class="ts-row"><span class="ts-label">'+escHtml(label)+(o.info?'<button class="ts-info" type="button" onclick="openSummaryInfo()" aria-label="زانیاری لەسەر بڕی گەڕاوە">i</button>':'')+'</span>'+
    '<span class="ts-value'+(o.cls?' '+o.cls:'')+'"'+(o.ltr?' dir="ltr"':'')+'>'+rendered+'</span></div>';
}
function summaryStatusCopy(order){
  if(order.balance_refunded_at||order.balance_refund_case_id)
    return {tone:'success',title:'پارەکەت گەڕێندرایەوە',message:'بڕی گەڕاوە لە باڵانسی هەژمارەکەتدا تۆمارکراوە.'};
  if(order.status==='پەسەندکرا')
    return {tone:'success',title:'مامەڵەکە پەسەندکرا',message:'مامەڵەکە بە سەرکەوتوویی تەواو کرا و بڕی نێردراو بۆ وەرگر تۆمارکرا.'};
  if(order.status==='ڕەتکرا')
    return {tone:'error',title:'مامەڵەکە ڕەتکرایەوە',message:order.admin_note||'داواکارییەکە پەسەند نەکرا.'};
  if(order.status==='پێویستی بە ڕاستکردنەوەیە')
    return {tone:'warn',title:'پێویستی بە ڕاستکردنەوە هەیە',message:order.correction_note||'تکایە زانیارییە داواکراوەکان ڕاست بکەرەوە.'};
  if(order.status==='ڕاستکراوەتەوە')
    return {tone:'warn',title:'زانیارییەکان ڕاستکرانەوە',message:'داواکارییەکەت دووبارە لە چاوەڕوانی پێداچوونەوەدایە.'};
  return {tone:'warn',title:txLabelOf(order)||'چاوەڕوانی',message:'داواکارییەکەت لە چاوەڕوانی پێداچوونەوەدایە.'};
}
function renderSummaryStatus(order){
  const box=document.getElementById('summaryStatus'),icon=document.getElementById('summaryStatusIcon');
  if(!box||!icon)return;
  const state=summaryStatusCopy(order);
  box.className='ts-status'+(state.tone==='warn'?' is-warn':state.tone==='error'?' is-error':'');
  icon.innerHTML=state.tone==='success'
    ?'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>'
    :state.tone==='error'
      ?'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 7 10 10M17 7 7 17"/></svg>'
      :'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 8v5m0 4h.01"/><circle cx="12" cy="12" r="9"/></svg>';
  document.getElementById('summaryStatusTitle').textContent=state.title;
  document.getElementById('summaryStatusMessage').textContent=state.message;
}
function renderSummaryAdditional(order){
  const box=document.getElementById('summaryAdditional');
  if(!box)return;
  const notes=[];
  if(order.admin_note) notes.push(tfNote(order.status==='ڕەتکرا'?'هۆکاری ڕەتکردنەوە':'تێبینی بەڕێوەبەر',order.admin_note,order.status==='ڕەتکرا'?'bad':''));
  if(order.status==='پێویستی بە ڕاستکردنەوەیە'&&order.correction_note) notes.push(tfNote('پێویستی بە ڕاستکردنەوە هەیە',order.correction_note,'warn'));
  if(order.extra_info) notes.push(tfNote('زانیاری زیاتر',order.extra_info));
  box.innerHTML=notes.join('');
  box.hidden=!notes.length;
}
function renderSummaryFeedback(order){
  const box=document.getElementById('summaryFeedback');
  if(!box)return;
  box.innerHTML=fbFlatHTML(order,{
    title:true,
    ids:{comment:'summaryFeedbackComment',submit:'summaryFeedbackSubmit',error:'summaryFeedbackError'},
    onSelect:'selectSummaryFeedbackRating',
    onSubmit:'submitSummaryFeedback()'
  });
  _summaryFeedbackDraftRating=0;
}
function selectSummaryFeedbackRating(rating){
  _summaryFeedbackDraftRating=Math.max(1,Math.min(5,Number(rating)||0));
  document.querySelectorAll('#summaryFeedback .feedback-star').forEach((button,index)=>{
    const selected=index<_summaryFeedbackDraftRating;
    button.classList.toggle('selected',selected);
    button.setAttribute('aria-checked',String(Number(button.dataset.rating)===_summaryFeedbackDraftRating));
  });
  const label=document.getElementById('summaryFbRatingLabel');
  if(label){label.textContent=FEEDBACK_LABELS[_summaryFeedbackDraftRating-1]||'';label.classList.add('is-set');}
  const error=document.getElementById('summaryFeedbackError');if(error)error.textContent='';
}
async function submitSummaryFeedback(){
  const order=_summaryOrder,error=document.getElementById('summaryFeedbackError'),button=document.getElementById('summaryFeedbackSubmit');
  if(!order||order.status!=='پەسەندکرا'||order.feedback)return;
  if(!_summaryFeedbackDraftRating){if(error)error.textContent='تکایە ژمارەی ئەستێرە دیاری بکە.';return;}
  if(!curUser?.id){if(error)error.textContent='بۆ ناردنی هەڵسەنگاندن بچۆ ژوورەوە.';return;}
  const comment=(document.getElementById('summaryFeedbackComment')?.value||'').trim();
  if(comment.length>1000){if(error)error.textContent='تێبینی نابێت لە 1000 پیت زیاتر بێت.';return;}
  if(button){button.disabled=true;button.textContent='دەنێردرێت...';}
  try{
    const {data,error:insertError}=await sb.from('ex_order_feedback').insert({order_id:order.id,user_id:curUser.id,rating:_summaryFeedbackDraftRating,comment}).select('order_id,rating,comment,created_at').single();
    if(insertError)throw insertError;
    order.feedback=data;_summaryFeedbackDraftRating=0;
    renderSummaryFeedback(order);
    showToast('سوپاس بۆ هەڵسەنگاندنەکەت.','success');
  }catch(err){
    if(error)error.textContent=err.code==='23505'?'هەڵسەنگاندنی ئەم داواکارییە پێشتر تۆمار کراوە.':'نەتوانرا هەڵسەنگاندنەکەت تۆمار بکرێت؛ تکایە دووبارە هەوڵ بدەرەوە.';
    if(button){button.disabled=false;button.textContent='ناردنی هەڵسەنگاندن';}
  }
}
function renderTransactionSummary(order){
  if(!order)return;
  _summaryOrder=order;
  const payout=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(order):null;
  const financial=typeof ProxoTransactionSummaryFinancials==='object'
    ?ProxoTransactionSummaryFinancials.breakdown(order,payout)
    :{sourceAmount:Number(order.amount),total:Number(order.total),netFee:Number(order.fee),recipientAmount:payout?.settled?Number(payout.payout_iqd):Number(order.total),returnedAmount:0,sameIqd:order.from_method!=='USDT'&&order.to_method!=='USDT'};
  const split=tfSplitOf(order);
  if(!split.refunded&&!split.pending&&!split.rejected&&order.status==='پەسەندکرا'){
    // a settled order: trust the server breakdown when it carries more detail
    if(Number(financial.recipientAmount)>=0&&financial.recipientAmount!==null) split.recipient=Number(financial.recipientAmount);
    if(Number(financial.returnedAmount)>0) split.returned=Number(financial.returnedAmount);
  }
  const hero=split.refunded
    ? {label:'بڕی گەڕاوە بۆ باڵانس',amount:txAmount(split.returned,'IQD'),to:'AccountBalance'}
    : split.rejected
      ? {label:'بڕی داواکراو',amount:txAmount(financial.total,order.to_method)}
      : {label:split.pending?'بڕی دەنێردرێت بۆ وەرگر':'بڕی گەیشتوو بە وەرگر',amount:txAmount(split.recipient,order.to_method)};
  const rows=
      tfRow('بڕی نێردراو',txAmount(financial.sourceAmount,order.from_method),{ltr:true})
    + tfRow('کرێی خزمەتگوزاری',financial.sameIqd&&financial.netFee!==null?txAmount(financial.netFee,'IQD'):'—',{ltr:true})
    + tfRow('کۆی گشتی دوای کرێ',txAmount(financial.total,order.to_method),{ltr:true,row:'is-total'});
  const splitRows=tfSplitRows(order,split);
  const info=
      tfRow('ژمارەی مامەڵە',tfCodeHTML(order),{html:true})
    + tfRow('ڕێگای گواستنەوە',tfRouteHTML(order,split.refunded?'AccountBalance':order.to_method),{html:true})
    + tfRow('بەرواری ناردن',txWhenHTML(order.created_at,true),{html:true})
    + tfRow('بەرواری نوێکردنەوەی دۆخ',txWhenHTML(order.status_updated_at||order.decided_at||order.updated_at||order.created_at,true),{html:true})
    + (order.balance_refunded_at?tfRow('بەرواری گەڕاندنەوە',txWhenHTML(order.balance_refunded_at,true),{html:true}):'');
  document.getElementById('summaryHero').innerHTML=tfHeroHTML(order,hero);
  document.getElementById('summaryDetails').innerHTML=tfSection('وردەکاری بڕ',rows)+tfSection('دابەشکردنی بڕ',splitRows)+tfSection('زانیاری مامەڵە',info);
  renderSummaryStatus(order);
  renderSummaryAdditional(order);
  renderSummaryFeedback(order);
  const receipt=document.getElementById('summaryPayoutReceipt');
  if(receipt){
    receipt.replaceChildren();
    if(order.payout_receipt_url){
      try{
        const url=new URL(order.payout_receipt_url,location.origin);
        if(url.protocol==='https:'||url.origin===location.origin){
          const title=document.createElement('h3');title.className='tf-sec-title';title.textContent='پسووڵەی گەیاندن';
          const image=document.createElement('img');image.src=url.href;image.alt='پسووڵەی گەیاندن';image.loading='lazy';
          image.addEventListener('click',()=>{if(typeof openReceiptFull==='function')openReceiptFull(url.href);});
          receipt.append(title,image);receipt.hidden=false;
        }else receipt.hidden=true;
      }catch(_){receipt.hidden=true;}
    }else receipt.hidden=true;
  }
  document.getElementById('summaryReceiptButton').hidden=false;
  document.getElementById('summaryLoading').hidden=true;
  document.getElementById('summaryError').hidden=true;
  document.getElementById('summaryContent').hidden=false;
  document.title='پوختەی مامەڵە | Proxo';
}
function openSummaryInfo(){
  const backdrop=document.getElementById('summaryInfoBackdrop');if(!backdrop)return;
  _summaryInfoPreviousOverflow=document.body.style.overflow||'';
  backdrop.hidden=false;document.body.style.overflow='hidden';
  requestAnimationFrame(()=>backdrop.classList.add('is-open'));
}
function closeSummaryInfo(){
  const backdrop=document.getElementById('summaryInfoBackdrop');if(!backdrop||backdrop.hidden)return;
  backdrop.classList.remove('is-open');document.body.style.overflow=_summaryInfoPreviousOverflow;
  setTimeout(()=>{if(!backdrop.classList.contains('is-open'))backdrop.hidden=true;},240);
}
function closeTransactionSummary(){location.replace('/');}
function showTransactionSummaryError(message,actionLabel,action){
  const loading=document.getElementById('summaryLoading'),content=document.getElementById('summaryContent'),error=document.getElementById('summaryError');
  if(loading)loading.hidden=true;if(content)content.hidden=true;if(!error)return;
  error.hidden=false;
  const title=document.getElementById('summaryErrorTitle');if(title)title.textContent='نەتوانرا مامەڵەکە پیشان بدرێت';
  const text=document.getElementById('summaryErrorMessage');if(text)text.textContent=message;
  const button=document.getElementById('summaryErrorAction');
  if(button){button.hidden=typeof action!=='function';button.textContent=actionLabel||'';button.onclick=action||null;}
}
function retryTransactionSummary(){
  getOrderSession().then(loadTransactionSummaryPage).catch(()=>showTransactionSummaryError('تکایە بچۆ ژوورەوە و دووبارە هەوڵ بدەرەوە.','چوونە ژوورەوە',closeTransactionSummary));
}
async function loadTransactionSummaryPage(session){
  const token=summaryTokenFromPath();
  const tokenPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if(!token||!tokenPattern.test(token)){
    showTransactionSummaryError('لینکی مامەڵەکە دروست نییە یان تەواو نییە.','گەڕانەوە بۆ سەرەتا',closeTransactionSummary);return;
  }
  if(!session?.access_token){
    showTransactionSummaryError('بۆ بینینی وردەکاری مامەڵەکە سەرەتا بچۆ ژوورەوە، پاشان لینکەکە دووبارە بکەرەوە.','چوونە ژوورەوە',closeTransactionSummary);return;
  }
  document.getElementById('summaryLoading').hidden=false;
  document.getElementById('summaryError').hidden=true;
  document.getElementById('summaryContent').hidden=true;
  try{
    const response=await fetch('/api/transaction-summary',{method:'POST',credentials:'same-origin',cache:'no-store',headers:{'Content-Type':'application/json','Authorization':'Bearer '+session.access_token},body:JSON.stringify({secure_token:token})});
    let payload={};try{payload=await response.json();}catch(_){}
    if(response.status===401){showTransactionSummaryError('چوونەژوورەوەکەت بەسەرچووە. تکایە بچۆ ژوورەوە و لینکەکە دووبارە بکەرەوە.','چوونە ژوورەوە',closeTransactionSummary);return;}
    if(response.status===404){showTransactionSummaryError('مامەڵەکە نەدۆزرایەوە. دڵنیابە بە هەمان هەژمار چوویتە ژوورەوە.','گەڕانەوە بۆ سەرەتا',closeTransactionSummary);return;}
    if(response.status===400){showTransactionSummaryError('لینکی مامەڵەکە دروست نییە.','گەڕانەوە بۆ سەرەتا',closeTransactionSummary);return;}
    if(!response.ok||!payload.order)throw new Error('SUMMARY_LOAD_FAILED');
    _summaryOrder=payload.order;_orders=[payload.order];
    renderTransactionSummary(payload.order);
  }catch(_){
    showTransactionSummaryError('کێشەیەک لە پەیوەندی ڕوویدا. تکایە دووبارە هەوڵ بدەرەوە.','دووبارە هەوڵدانەوە',retryTransactionSummary);
  }
}
function downloadSummaryReceipt(){
  if(!_summaryOrder)return;
  _orders=[_summaryOrder];
  if(typeof downloadTransactionReceipt==='function')downloadTransactionReceipt(_summaryOrder.id);
}

/* Feedback on the home page is a bottom sheet of its own (not the transaction details). */
let _feedbackSheetId=null;
function openFeedbackSheet(orderId){
  const order=_orders.find(row=>String(row.id)===String(orderId));
  const sheet=document.getElementById('feedbackSheet'), body=document.getElementById('feedbackSheetBody');
  if(!order||order.status!=='پەسەندکرا'||order.feedback||!sheet||!body) return;
  _feedbackSheetId=String(order.id);
  _feedbackDraftRating=0;
  body.innerHTML=fbSheetHTML(order);
  body.scrollTop=0;
  openSheet(sheet);
}
// Rating sheet: order summary (from · to · amount) → one question → five stars → optional note → «ناردن».
// After sending: a check, one short line and «باشە». Nothing else.
const FB_STAR_SVG='<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 2.9l2.75 5.6 6.15.9-4.45 4.33 1.05 6.12L12 16.97l-5.5 2.88 1.05-6.12L3.1 9.4l6.15-.9z"/></svg>';
function fbSheetHTML(order){
  const id=escHtml(String(order.id));
  return '<div class="fbx">'
    + '<div class="fbx-sum">'
      + '<span class="dbr-pair fbx-pair" aria-hidden="true">'+dbLogoHTML(order.from_method)+dbLogoHTML(order.to_method)+'</span>'
      + '<span class="fbx-route" dir="ltr">'+txRouteInner(order.from_method,order.to_method)+'</span>'
      + '<b class="fbx-amt" dir="ltr">'+escHtml(txAmount(order.amount,order.from_method))+'</b>'
    + '</div>'
    + '<h4 class="fbx-q" id="fbxTitle">چۆن بوو ئەم مامەڵەیە؟</h4>'
    + '<div class="fb-stars fbx-stars" role="radiogroup" aria-labelledby="fbxTitle">'
      + Array.from({length:5},(_,i)=>'<button type="button" class="fb-star fbx-star" data-rating="'+(i+1)+'" role="radio" aria-checked="false" aria-label="'+(i+1)+' ئەستێرە" onclick="selectOrderFeedbackRating('+(i+1)+')">'+FB_STAR_SVG+'</button>').join('')
    + '</div>'
    + '<textarea id="orderFeedbackComment" class="fbx-note" maxlength="1000" rows="2" placeholder="تێبینی (ئارەزوومەندانە)" aria-label="تێبینی"></textarea>'
    + '<div class="fb-error fbx-err" id="orderFeedbackError" role="alert"></div>'
    + '<button type="button" class="fbx-send" id="orderFeedbackSubmit" disabled onclick="submitOrderFeedback(\''+id+'\')"><span class="fbx-spin" aria-hidden="true"></span><span class="fbx-send-lbl">ناردن</span></button>'
    + '</div>';
}
function fbThanksHTML(){
  return '<div class="fbx fbx-thanks" role="status">'
    + '<span class="fbx-done-ico" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="m6 12.5 4 4L18.5 8"/></svg></span>'
    + '<h4>سوپاس بۆ هەڵسەنگاندنەکەت</h4>'
    + '<button type="button" class="fbx-send" onclick="closeFeedbackSheet()"><span class="fbx-send-lbl">باشە</span></button>'
    + '</div>';
}
function fbEnableSend(){ const b=document.getElementById('orderFeedbackSubmit'); if(b && !b.classList.contains('is-loading')) b.disabled=false; }
function closeFeedbackSheet(){
  const sheet=document.getElementById('feedbackSheet');
  _feedbackSheetId=null;
  if(sheet) closeSheet(sheet);
}
function selectOrderFeedbackRating(rating){
  _feedbackDraftRating=Math.max(1,Math.min(5,Number(rating)||0));
  document.querySelectorAll('.fb-stars .fb-star').forEach((button,index)=>{
    const selected=index<_feedbackDraftRating;button.classList.toggle('selected',selected);button.setAttribute('aria-checked',String(Number(button.dataset.rating)===_feedbackDraftRating));
  });
  const label=document.getElementById('fbRatingLabel');
  if(label){ label.textContent=FEEDBACK_LABELS[_feedbackDraftRating-1]||''; label.classList.add('is-set'); label.dataset.rating=String(_feedbackDraftRating); }
  if(typeof fbEnableSend==='function') fbEnableSend();
  const err=document.getElementById('orderFeedbackError'); if(err) err.textContent='';
}
async function submitOrderFeedback(orderId){
  const order=_orders.find(row=>String(row.id)===String(orderId));
  const errorEl=document.getElementById('orderFeedbackError'),button=document.getElementById('orderFeedbackSubmit');
  const fromSheet=String(order?.id)===String(_feedbackSheetId);
  if(!order||(String(order.id)!==String(_txSheetId)&&!fromSheet)||order.status!=='پەسەندکرا'||order.feedback)return;
  if(!_feedbackDraftRating){if(errorEl)errorEl.textContent='تکایە ژمارەی ئەستێرە دیاری بکە.';return;}
  if(!curUser?.id){if(errorEl)errorEl.textContent='بۆ ناردنی هەڵسەنگاندن بچۆ ژوورەوە.';return;}
  const comment=(document.getElementById('orderFeedbackComment')?.value||'').trim();
  if(comment.length>1000){if(errorEl)errorEl.textContent='تێبینی نابێت لە 1000 پیت زیاتر بێت.';return;}
  if(errorEl)errorEl.textContent='';
  if(button){ button.disabled=true; if(fromSheet){ button.classList.add('is-loading'); button.setAttribute('aria-busy','true'); } else button.textContent='دەنێردرێت...'; }
  try{
    const {data,error}=await sb.from('ex_order_feedback').insert({order_id:order.id,user_id:curUser.id,rating:_feedbackDraftRating,comment}).select('order_id,rating,comment,created_at').single();
    if(error)throw error;
    order.feedback=data;_feedbackDraftRating=0;renderHomeFeedbackPrompt();
    if(fromSheet){ const body=document.getElementById('feedbackSheetBody'); if(body){ body.innerHTML=fbThanksHTML(); body.scrollTop=0; } else closeFeedbackSheet(); return; }
    else if(_route==='summary'){ renderTxScreen(); }
    else { navigate('home',true); }
    showToast('سوپاس بۆ هەڵسەنگاندنەکەت.','success');
  }catch(error){
    if(errorEl)errorEl.textContent=error.code==='23505'?'هەڵسەنگاندنی ئەم داواکارییە پێشتر تۆمار کراوە.':'نەتوانرا هەڵسەنگاندنەکەت تۆمار بکرێت؛ تکایە دووبارە هەوڵ بدەرەوە.';
    if(button){ button.disabled=false; if(fromSheet){ button.classList.remove('is-loading'); button.removeAttribute('aria-busy'); } else button.textContent='ناردنی هەڵسەنگاندن'; }
  }
}
function txRow(label, value, opts){
  if(value===null || value===undefined || value==='') return '';
  const o=opts||{};
  return '<div class="tx-drow"><span class="tx-dlbl">'+escHtml(label)+'</span>'
    + '<span class="tx-dval'+(o.cls?' '+o.cls:'')+'"'+(o.ltr?' dir="ltr"':'')+'>'+(o.html?value:escHtml(String(value)))+'</span></div>';
}
function transactionSummaryUrlForOrder(order){
  if(order?.status!=='پەسەندکرا') return '';
  const token=typeof order.secure_token==='string'?order.secure_token.trim():'';
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(token)) return '';
  return '/summarytransaction/'+encodeURIComponent(token);
}
// ── Transaction summary: ONE shared in-app screen (route "summary") ──
// /summarytransaction/<secure_token> opens inside the app shell, both from the
// transaction list and from links (WhatsApp, notifications). No bottom sheet.
const TX_TOKEN_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let _txScreenToken='', _txScreenPushed=false, _txReturnRoute='transactions', _txScreenLoadId=0, _txScreenMissing='';
function openTxDetail(id){
  const o=_orders.find(row=>String(row.id)===String(id));
  if(!o) return;
  const nextId=String(id);
  if(_txSheetId!==nextId)_feedbackDraftRating=0;
  _txSheetId=nextId;
  const token=typeof o.secure_token==='string'?o.secure_token.trim():'';
  _txScreenToken=TX_TOKEN_RE.test(token)?token:'';
  if(_route==='summary'){
    if(_txScreenToken && summaryTokenFromPath()!==_txScreenToken){ try{history.replaceState({route:'summary'},'',urlFor('summary'));}catch(_){} }
    renderTxScreen();
    return;
  }
  _txReturnRoute=_route||'transactions';
  _txScreenPushed=!!_txScreenToken;
  navigate('summary', true);
}
function resetTxScreenState(){ _txSheetId=null; _txScreenPushed=false; _txScreenLoadId++; }
function txScreenMessage(title,text,actionLabel,action){
  return '<div class="ts-error"><b>'+escHtml(title)+'</b><p>'+escHtml(text)+'</p>'
    +(actionLabel?'<button type="button" onclick="'+action+'">'+escHtml(actionLabel)+'</button>':'')+'</div>';
}
function renderTxScreen(){
  const body=document.getElementById('txScreenBody');
  if(!body) return;
  const pathToken=summaryTokenFromPath();
  if(pathToken) _txScreenToken=pathToken;
  let o=null;
  if(_txScreenToken) o=_orders.find(r=>String(r.secure_token||'')===_txScreenToken);
  if(!o && _txSheetId && !pathToken) o=_orders.find(r=>String(r.id)===String(_txSheetId));
  if(o){
    if(_txSheetId!==String(o.id))_feedbackDraftRating=0;
    _txSheetId=String(o.id);
    body.innerHTML=txDetailHTML(o);
    document.title='پوختەی مامەڵە '+orderCodeOf(o)+' — Proxo';
    return;
  }
  if(!_txScreenToken || !TX_TOKEN_RE.test(_txScreenToken)){
    _txSheetId=null;
    body.innerHTML=txScreenMessage('نەتوانرا مامەڵەکە پیشان بدرێت','لینکی مامەڵەکە دروست نییە یان تەواو نییە.','گەڕانەوە بۆ مامەڵەکان',"navigate('transactions')");
    return;
  }
  if(_txScreenMissing===_txScreenToken){
    _txSheetId=null;
    body.innerHTML=txScreenMessage('مامەڵەکە نەدۆزرایەوە','ئەم مامەڵەیە سەر بە ئەم هەژمارە نییە. دڵنیابە بە هەمان هەژمار چوویتە ژوورەوە.','گەڕانەوە بۆ مامەڵەکان',"navigate('transactions')");
    return;
  }
  body.innerHTML=window.PXS?PXS.summary():'<div class="ts-loading"><span class="ts-spinner"></span><span>زانیارییەکانی مامەڵە بار دەکرێن...</span></div>';
  fetchTxScreenOrder(_txScreenToken);
}
async function fetchTxScreenOrder(token){
  const loadId=++_txScreenLoadId;
  try{
    const session=await getOrderSession();
    const response=await fetch('/api/transaction-summary',{method:'POST',credentials:'same-origin',cache:'no-store',headers:{'Content-Type':'application/json','Authorization':'Bearer '+session.access_token},body:JSON.stringify({secure_token:token})});
    let payload={};try{payload=await response.json();}catch(_){}
    if(loadId!==_txScreenLoadId||_route!=='summary'||_txScreenToken!==token) return;
    if(_orders.some(r=>String(r.secure_token||'')===token)){ renderTxScreen(); return; }
    if(response.status===404||response.status===400){ _txScreenMissing=token; renderTxScreen(); return; }
    if(!response.ok||!payload.order) throw new Error('SUMMARY_LOAD_FAILED');
    const order=payload.order; order.secure_token=token;
    if(!_orders.some(r=>String(r.id)===String(order.id))) _orders.push(order);
    renderTxScreen();
  }catch(_){
    if(loadId!==_txScreenLoadId||_route!=='summary') return;
    const body=document.getElementById('txScreenBody');
    if(body) body.innerHTML=txScreenMessage('نەتوانرا مامەڵەکە پیشان بدرێت','کێشەیەک لە پەیوەندی ڕوویدا. تکایە دووبارە هەوڵ بدەرەوە.','دووبارە هەوڵدانەوە','renderTxScreen()');
  }
}
function txDetailHTML(o){
  const st=txStateOf(o);
  const code=orderCodeOf(o);
  const rate=Number(o.amount)>0 ? (Number(o.total)/Number(o.amount)) : 0;
  const isUsdt=o.from_method==='USDT';
  const fee=!isUsdt && o.to_method!=='USDT' && Number(o.amount)>Number(o.total) ? Math.floor(Number(o.amount)-Number(o.total)) : 0;
  const payout=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(o):null;
  const rounded=!o.balance_refunded_at&&payout&&(payout.planned||payout.has_settlement);
  const received=payout?payout.display_amount:o.total;
  const refundedSheet=!!o.balance_refunded_at;
  const split=tfSplitOf(o);
  const hero=refundedSheet
    ? {label:'بڕی گەڕاوە بۆ باڵانس',amount:txAmount(o.amount,'AccountBalance'),to:'AccountBalance'}
    : (split.rejected||split.cancelled)
      ? {label:'بڕی داواکراو',amount:txAmount(o.total,o.to_method)}
      : {label:split.pending?'بڕی دەنێردرێت بۆ وەرگر':'بڕی گەیشتوو بە وەرگر',amount:txAmount(split.recipient,o.to_method)};
  const iqdRoute=!isUsdt && o.to_method!=='USDT';
  const rows=
      tfRow('بڕی نێردراو',txAmount(o.amount,o.from_method),{ltr:true})
    // A rate only means something across currencies; IQD → IQD is a fee.
    + (isUsdt && rate ? tfRow('نرخی ئاڵوگۆڕ','1 $ = '+formatNum(Math.round(rate))+' IQD',{ltr:true}) : '')
    + (!refundedSheet && iqdRoute ? tfRow('کرێی خزمەتگوزاری',formatNum(fee)+' IQD',{ltr:true}) : '')
    + (!refundedSheet ? tfRow('کۆی گشتی دوای کرێ',txAmount(o.total,o.to_method),{ltr:true,row:'is-total'}) : '');
  const splitRows=tfSplitRows(o,split)
    + (!refundedSheet&&payout&&payout.valid&&(payout.planned||payout.has_settlement)&&payout.payout_iqd===0?tfRow('ناردنی دەرەکی','هیچ بڕێک بۆ وەرگر نانێردرێت'):'');
  const info=
      tfRow('ژمارەی مامەڵە',tfCodeHTML(o),{html:true})
    + tfRow('ڕێگای گواستنەوە',tfRouteHTML(o,refundedSheet?'AccountBalance':o.to_method),{html:true})
    + tfRow('ژمارەی وەرگر',o.phone,{ltr:true})
    + (o.sender_phone ? tfRow('ژمارەی نێرەر',o.sender_phone,{ltr:true}) : '')
    + tfRow('بەرواری ناردن',txWhenHTML(o.created_at,true),{html:true})
    + ((o.status==='پەسەندکرا'||o.status==='ڕەتکرا') && o.decided_at ? tfRow('بەرواری بڕیار',txWhenHTML(o.decided_at,true),{html:true}) : '')
    + (refundedSheet ? tfRow('بەرواری گەڕاندنەوە',txWhenHTML(o.balance_refunded_at,true),{html:true}) : '');
  let html='<div class="tf-flow">'+tfHeroHTML(o,hero)+tfSection('وردەکاری بڕ',rows)+tfSection('دابەشکردنی بڕ',splitRows)+tfSection('زانیاری مامەڵە',info);
  if(o.admin_note){
    html+=tfNote(o.status==='ڕەتکرا'?'هۆکاری ڕەتکردنەوە':'تێبینی بەڕێوەبەر',o.admin_note,o.status==='ڕەتکرا'?'bad':'');
  }
  if(o.extra_info) html+=tfNote('زانیاری زیاتر',o.extra_info);
  if(o.status==='ڕەتکرا'){
    html+=tfNote('دووبارە ناردنەوە','دەتوانیت هەمان داواکاری بە هەمان زانیاری و پسووڵە دووبارە بنێریتەوە. ئەگەر هۆکاری ڕەتکردنەوە پەیوەندی بە پسووڵەکەوە هەبێت، سەرەتا پسووڵەیەکی دروست ئامادە بکە.','',
      '<button type="button" class="tf-btn" onclick="confirmRejectedOrderRetry(\''+escHtml(String(o.id))+'\')">دووبارە ناردنەوەی داواکاری</button>');
  }
  if(o.correction_request && !o.balance_refunded_at){
    html+=tfNote('داواکاریی ڕاستکردنەوە',o.correction_request,'warn',
      o.status==='پێویستی بە ڕاستکردنەوەیە'
        ? '<button type="button" class="tf-btn" onclick="closeTxDetail(); openOrderCorrection(\''+escHtml(String(o.id))+'\')">ڕاستکردنەوەی مامەڵە</button>'
        : '');
  }
  if(o.correction_response) html+=tfNote('وەڵامی تۆ',o.correction_response);
  html+=renderOrderFeedback(o);
  if(o.payout_receipt_url){
    html+='<section class="tf-sec tf-media"><h3 class="tf-sec-title">پسووڵەی گەیاندن</h3>'
      + '<img src="'+escHtml(o.payout_receipt_url)+'" alt="پسووڵەی گەیاندن" loading="lazy" onclick="openReceiptFull(\''+escHtml(o.payout_receipt_url)+'\')">'
      + '</section>';
  }
  const oid=escHtml(String(o.id));
  html+='<div class="tf-actions">';
  // the same wallets, amount and recipient, ready to change before sending
  html+='<button type="button" class="tf-ghost" onclick="repeatOrder(\''+oid+'\')">'
    + '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 12a8 8 0 0 1 13.7-5.6L20 8.5"/><path d="M20 4v4.5h-4.5"/><path d="M20 12a8 8 0 0 1-13.7 5.6L4 15.5"/><path d="M4 20v-4.5h4.5"/></svg>'
    + '<span>دووبارەکردنەوەی ئاڵوگۆڕ</span></button>';
  // A signed-in customer can download their own saved transaction as a Kurdish PDF.
  html+='<button type="button" class="tf-ghost" onclick="downloadTransactionReceipt(\''+oid+'\')">'
    + '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3v12m-4-4 4 4 4-4M5 18v3h14v-3"/></svg>'
    + '<span>داگرتنی پسووڵە</span></button>';
  if(orderCancellable(o)) html+='<button type="button" class="tf-ghost is-danger" onclick="confirmCancelOrder(\''+oid+'\')">'
    + '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M7 7l10 10M17 7 7 17"/></svg>'
    + '<span>هەڵوەشاندنەوەی داواکاری</span></button>';
  html+='</div></div>';
  return html;
}
// Back from the summary screen: return to wherever the customer came from.
function closeTxDetail(){
  if(_route!=='summary'){ _txSheetId=null; return; }
  if(_txScreenPushed){ _txScreenPushed=false; try{ history.back(); return; }catch(_){} }
  navigate(_txReturnRoute&&_txReturnRoute!=='summary'?_txReturnRoute:'transactions', true);
}
// ── cancel a waiting order (not while an admin reviews it) ──
const TX_CANCELLABLE=['چاوەڕوانە','پێویستی بە ڕاستکردنەوەیە','ڕاستکراوەتەوە'];
function orderCancellable(o){
  return !!o && !o.balance_refunded_at && !o.balance_refund_case_id && TX_CANCELLABLE.includes(o.status)
    && o.from_method!=='USDT' && o.to_method!=='USDT' && (o.from_method==='AccountBalance' || !!o.receipt_url);
}
let _cancelOrderBusy=false;
function confirmCancelOrder(orderId){
  const o=_orders.find(x=>String(x.id)===String(orderId));
  if(!orderCancellable(o)){ showToast('ئەم داواکارییە ناتوانرێت هەڵبوەشێنرێتەوە','error'); return; }
  const amount=formatNum(Math.floor(Number(o.amount)||0))+' IQD';
  showResultModal({
    tone:'warning',
    title:'داواکارییەکە هەڵدەوەشێنیتەوە؟',
    message:o.from_method==='AccountBalance'
      ? 'بڕی '+amount+' یەکسەر دەگەڕێتەوە بۆ باڵانسەکەت.'
      : 'دوای پشکنینی پسوولەکە، بڕی '+amount+' دەخرێتە سەر باڵانسەکەت.',
    primaryText:'هەڵوەشاندنەوە',
    secondaryText:'پاشگەزبوونەوە',
    onPrimary:()=>cancelOrder(orderId)
  });
}
async function cancelOrder(orderId){
  if(_cancelOrderBusy) return;
  _cancelOrderBusy=true;
  try{
    const {data,error}=await sb.rpc('ex_order_cancel',{p_order:String(orderId)});
    if(error) throw error;
    const o=_orders.find(x=>String(x.id)===String(orderId));
    if(o){ o.status=TX_CANCELLED; o.cancelled_at=new Date().toISOString(); if(data&&data.refunded) o.balance_refunded_at=o.cancelled_at; }
    showToast(data&&data.refunded?'هەڵوەشێنرایەوە و بڕەکە گەڕایەوە بۆ باڵانسەکەت':'داواکارییەکە هەڵوەشێنرایەوە','success');
    if(_route==='summary') renderTxScreen();
    renderTxPage(); updateNavBadge();
    if(data&&data.refunded&&typeof loadMyBalance==='function') loadMyBalance();
    loadHistory();
  }catch(e){
    const m=String(e&&(e.message||e.details)||'');
    const text=/ORDER_UNDER_REVIEW/.test(m)?'داواکارییەکە لەژێر پێداچوونەوەدایە و ناتوانرێت هەڵبوەشێنرێتەوە.'
      :/SECTION_PAUSED/.test(m)?'ئەم بەشە بۆ ماوەیەک ڕاگیراوە.'
      :/ORDER_NOT_CANCELLABLE|ORDER_NOT_FOUND/.test(m)?'ئەم داواکارییە ئیتر ناتوانرێت هەڵبوەشێنرێتەوە.'
      :'هەڵوەشاندنەوە سەرنەکەوت؛ دووبارە هەوڵ بدەرەوە.';
    showResultModal({tone:'error',title:'هەڵنەوەشێنرایەوە',message:text});
    loadHistory();
  }finally{ _cancelOrderBusy=false; }
}
// ── repeat: fill the exchange form from an earlier order; everything stays editable ──
function repeatOrder(orderId){
  const o=_orders.find(x=>String(x.id)===String(orderId));
  if(!o) return;
  const fill=()=>{
    const fromSel=document.getElementById('from'), toSel=document.getElementById('receiveVia');
    if(!fromSel||!toSel) return false;
    const has=(sel,v)=>[...sel.options].some(op=>op.value===v);
    if(!has(fromSel,o.from_method)) return false;
    _balanceOrderKey=null;
    if(!getWalletInfo(o.from_method).locked){ fromSel.value=o.from_method; updateWallet(); }
    if(has(toSel,o.to_method) && routeAllowed(fromSel.value,o.to_method) && !getWalletInfo(o.to_method).locked){ toSel.value=o.to_method; refreshTrigger('receiveVia'); updatePlaceholder(); }
    const amt=document.getElementById('amt');
    if(amt && Number(o.amount)>0){ amt.value=formatNum(String(o.amount)); clearFieldError('amt'); }
    const phone=document.getElementById('userPhone');
    if(phone && o.phone){ phone.value=String(o.phone); clearFieldError('userPhone'); }
    const senderPhone=document.getElementById('userSenderPhone');
    if(senderPhone && needsSenderPhone(fromSel.value) && o.sender_phone){ senderPhone.value=String(o.sender_phone); }
    calc();
    return true;
  };
  navigate('exchange');
  if(fill()) return;
  let tries=0;
  const wait=setInterval(()=>{ if(fill()||++tries>20) clearInterval(wait); },250);
}
let _rejectedOrderRetryBusy=false;
function confirmRejectedOrderRetry(orderId){
  const order=_orders.find(item=>String(item.id)===String(orderId));
  if(!order||order.status!=='ڕەتکرا'){
    showResultModal({tone:'warning',title:'داواکاری نەدۆزرایەوە',message:'لیستی مامەڵەکان نوێ بکەرەوە و دووبارە هەوڵ بدەرەوە.'});
    return;
  }
  showResultModal({
    tone:'warning',
    title:'داواکارییەکی نوێ بنێرەوە؟',
    message:'داواکارییەکی نوێ بە هەمان بڕ، ڕێگا، ژمارە و پسووڵە دروست دەکرێت؛ نرخ و کرێ بە نرخی ئێستا حیساب دەکرێت. داواکاریی کۆنەکە هەروا ڕەتکراو دەمێنێتەوە.',
    primaryText:'بەڵێ، دووبارە بنێرەوە',
    secondaryText:'پاشگەزبوونەوە',
    onPrimary:()=>resubmitRejectedOrder(orderId)
  });
}
async function resubmitRejectedOrder(orderId){
  if(_rejectedOrderRetryBusy) return;
  const sourceOrder=_orders.find(item=>String(item.id)===String(orderId));
  if(!sourceOrder||sourceOrder.status!=='ڕەتکرا'){
    showResultModal({tone:'warning',title:'داواکاری نەدۆزرایەوە',message:'لیستی مامەڵەکان نوێ بکەرەوە و دووبارە هەوڵ بدەرەوە.'});
    return;
  }
  _rejectedOrderRetryBusy=true;
  try{
    const session=await getOrderSession();
    const response=await fetch('/api/orders',{
      method:'POST',
      headers:{'Content-Type':'application/json','Authorization':'Bearer '+session.access_token},
      body:JSON.stringify({retry_rejected_order_id:String(sourceOrder.id)})
    });
    let payload={};
    try{payload=await response.json();}catch(_){}
    if(!response.ok||!payload.order){
      const error=new Error(payload.error||'نەتوانرا داواکارییەکە دووبارە بنێردرێتەوە');
      error.code=payload.code||'ORDER_RETRY_FAILED';
      throw error;
    }
    const newOrder=payload.order;
    closeTxDetail();
    await Promise.allSettled([
      loadHistory(),
      sourceOrder.from_method==='AccountBalance'?loadMyBalance():Promise.resolve()
    ]);
    try{
      await fetch('/api/notify-order',{
        method:'POST',
        headers:{'Content-Type':'application/json','Authorization':'Bearer '+session.access_token},
        body:JSON.stringify({order_id:newOrder.id})
      });
    }catch(_){}
    showResultModal({
      tone:'success',
      title:'داواکاریی نوێ نێردرا',
      message:'داواکارییەکی نوێ بە سەرکەوتوویی تۆمارکرا و لە چاوەڕوانی پێداچوونەوەدایە.',
      orderCode:orderCodeOf(newOrder),
      primaryText:'بینینی مامەڵەکان',
      onPrimary:()=>navigate('transactions',true)
    });
  }catch(error){
    const message=error.code==='RECEIPT_ALREADY_USED'
      ? 'ئەم پسووڵەیە لە داواکارییەکی تر کە هێشتا لە چاوەڕوانی یان پەسەندکراوە بەکارهاتووە. بەشی مامەڵەکان نوێ بکەرەوە بۆ پشکنینی دۆخەکە.'
      : error.code==='RETRY_ORDER_REFUNDED'
        ? 'ئەم داواکارییە پێشتر گەڕاندراوەتەوە؛ تکایە بۆ داواکاریی نوێ پشتگیری پەیوەندی پێوە بکە.'
        : error.code==='RETRY_ORDER_NOT_REJECTED'
          ? 'دۆخی ئەم داواکارییە گۆڕاوە و چیتر ڕەتکراو نییە. مامەڵەکان نوێ بکەرەوە.'
          : error.message||'هەڵەیەک ڕوویدا؛ تکایە دووبارە هەوڵ بدەرەوە.';
    showResultModal({tone:'error',title:'ناردنەوە سەرکەوتوو نەبوو',message});
  }finally{
    _rejectedOrderRetryBusy=false;
  }
}
function openReceiptFull(url){
  const modal=document.getElementById('supportImageModal');
  const image=document.getElementById('supportImageModalImg');
  if(modal && image){ image.src=url; modal.style.display='flex'; document.body.style.overflow='hidden'; }
}

let _orderCorrectionReceiptSnapshot=null;
let _orderCorrectionReceiptPromise=null;
let _orderCorrectionReceiptToken=0;
let _orderCorrectionPreviewUrl=null;

function clearOrderCorrectionReceiptPreview(){
  if(_orderCorrectionPreviewUrl){ URL.revokeObjectURL(_orderCorrectionPreviewUrl); _orderCorrectionPreviewUrl=null; }
  const preview=document.getElementById('orderCorrectionReceiptPreview');
  const image=document.getElementById('orderCorrectionReceiptPreviewImg');
  if(preview) preview.style.display='none';
  if(image) image.removeAttribute('src');
}

function removeOrderCorrectionReceipt(){
  _orderCorrectionReceiptToken++;
  _orderCorrectionReceiptSnapshot=null;
  _orderCorrectionReceiptPromise=null;
  const input=document.getElementById('orderCorrectionReceiptInput'); if(input) input.value='';
  const name=document.getElementById('orderCorrectionReceiptName'); if(name) name.textContent='گۆڕینی پسووڵە';
  const meta=document.getElementById('orderCorrectionReceiptMeta'); if(meta) meta.textContent='JPG، PNG یان WEBP';
  document.getElementById('orderCorrectionReceiptPicker')?.classList.remove('selected');
  clearOrderCorrectionReceiptPreview();
  clearFieldError('orderCorrectionReceipt');
}

function onOrderCorrectionReceiptSelected(input){
  clearFieldError('orderCorrectionReceipt');
  const file=input?.files?.[0]||null;
  if(!file){ removeOrderCorrectionReceipt(); return; }
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)){
    removeOrderCorrectionReceipt();
    setFieldError('orderCorrectionReceipt','تەنها JPG، PNG یان WEBP قبوڵ دەکرێت');
    return;
  }
  if(file.size>10*1024*1024){
    removeOrderCorrectionReceipt();
    setFieldError('orderCorrectionReceipt','قەبارەی وێنە نابێت لە 10MB زیاتر بێت');
    return;
  }
  const token=++_orderCorrectionReceiptToken;
  _orderCorrectionReceiptSnapshot=null;
  document.getElementById('orderCorrectionReceiptName').textContent=file.name;
  document.getElementById('orderCorrectionReceiptMeta').textContent='ئامادەکردنی وێنە...';
  document.getElementById('orderCorrectionReceiptPicker')?.classList.add('selected');
  clearOrderCorrectionReceiptPreview();
  _orderCorrectionReceiptPromise=readSelectedFileSnapshot(file).then(snapshot=>{
    if(token!==_orderCorrectionReceiptToken) return null;
    _orderCorrectionReceiptSnapshot=snapshot;
    document.getElementById('orderCorrectionReceiptMeta').textContent=(snapshot.size/1024/1024).toFixed(2)+' MB';
    _orderCorrectionPreviewUrl=URL.createObjectURL(new Blob([snapshot.bytes],{type:snapshot.type}));
    const image=document.getElementById('orderCorrectionReceiptPreviewImg'); if(image) image.src=_orderCorrectionPreviewUrl;
    const preview=document.getElementById('orderCorrectionReceiptPreview'); if(preview) preview.style.display='block';
    return snapshot;
  }).catch(()=>{
    if(token===_orderCorrectionReceiptToken){
      _orderCorrectionReceiptSnapshot=null;
      if(input) input.value='';
      document.getElementById('orderCorrectionReceiptPicker')?.classList.remove('selected');
      document.getElementById('orderCorrectionReceiptName').textContent='پسووڵە دووبارە هەڵبژێرە';
      document.getElementById('orderCorrectionReceiptMeta').textContent='دەستگەیشتن بە وێنەکە نەکرا';
      setFieldError('orderCorrectionReceipt','نەتوانرا وێنەکە بخوێندرێتەوە؛ تکایە دووبارە هەڵیبژێرە');
    }
    return null;
  });
}

function openOrderCorrection(id){
  const order=_orders.find(row=>String(row.id)===String(id));
  if(!order || order.status!=='پێویستی بە ڕاستکردنەوەیە'){
    showToast('ئەم مامەڵەیە چاوەڕوانی ڕاستکردنەوە نییە','error');
    return;
  }
  removeOrderCorrectionReceipt();
  document.getElementById('orderCorrectionId').value=order.id;
  document.getElementById('orderCorrectionCode').textContent=orderCodeOf(order);
  document.getElementById('orderCorrectionRequestText').textContent=order.correction_request||'تکایە زانیارییەکانی مامەڵەکەت ڕاست بکەرەوە.';
  document.getElementById('orderCorrectionPhone').value=order.phone||'';
  document.getElementById('orderCorrectionSenderPhone').value=order.sender_phone||'';
  document.getElementById('orderCorrectionSenderWrap').style.display=needsSenderPhone(order.from_method)?'block':'none';
  document.getElementById('orderCorrectionResponse').value='';
  ['orderCorrectionPhone','orderCorrectionSenderPhone','orderCorrectionResponse'].forEach(clearFieldError);
  document.getElementById('orderCorrectionCurrentReceipt').style.display=order.receipt_url?'flex':'none';
  document.getElementById('orderCorrectionModal').style.display='flex';
  document.body.style.overflow='hidden';
}

function closeOrderCorrection(){
  const modal=document.getElementById('orderCorrectionModal'); if(modal) modal.style.display='none';
  removeOrderCorrectionReceipt();
  document.body.style.overflow='';
}

function openOrderCorrectionReceipt(){
  const id=document.getElementById('orderCorrectionId')?.value||'';
  const order=_orders.find(row=>String(row.id)===String(id));
  if(!order?.receipt_url){ showToast('پسووڵەکە بەردەست نییە','error'); return; }
  const modal=document.getElementById('supportImageModal');
  const image=document.getElementById('supportImageModalImg');
  if(modal && image){ image.src=order.receipt_url; modal.style.display='flex'; document.body.style.overflow='hidden'; }
}

async function submitOrderCorrection(){
  if(!curUser || !activeSession?.access_token){ showToast('تکایە دووبارە بچۆ ژوورەوە','error'); return; }
  const id=document.getElementById('orderCorrectionId')?.value||'';
  const order=_orders.find(row=>String(row.id)===String(id));
  if(!order || order.status!=='پێویستی بە ڕاستکردنەوەیە'){
    showToast('دۆخی مامەڵەکە گۆڕاوە؛ پەڕەکە نوێ بکەرەوە','error'); return;
  }
  const phone=(document.getElementById('orderCorrectionPhone')?.value||'').replace(/\s+/g,'');
  const senderPhone=(document.getElementById('orderCorrectionSenderPhone')?.value||'').replace(/[^0-9]/g,'');
  const responseText=(document.getElementById('orderCorrectionResponse')?.value||'').trim();
  ['orderCorrectionPhone','orderCorrectionSenderPhone','orderCorrectionResponse','orderCorrectionReceipt'].forEach(clearFieldError);
  let valid=true;
  if(recipientIsCard(order.to_method) ? phone.length<6 : !/^07\d{9}$/.test(phone)){
    setFieldError('orderCorrectionPhone','ژمارەی وەرگر دروست نییە'); valid=false;
  }
  if(needsSenderPhone(order.from_method) && !/^07\d{9}$/.test(senderPhone)){
    setFieldError('orderCorrectionSenderPhone','ژمارەی نێرەر دەبێت بە 07 دەست پێبکات و 11 ژمارە بێت'); valid=false;
  }
  if(responseText.length<5){ setFieldError('orderCorrectionResponse','تکایە بنووسە چی ڕاستکرایەوە'); valid=false; }
  if(!valid) return;

  const btn=document.getElementById('orderCorrectionSubmitBtn');
  const defaultButton=btn.innerHTML; btn.disabled=true; btn.innerHTML=ICON.spin+' ناردن...';
  let stage='correction_submit';
  try{
    const payload={id,phone,sender_phone:needsSenderPhone(order.from_method)?senderPhone:null,customer_response:responseText};
    if(_orderCorrectionReceiptSnapshot || _orderCorrectionReceiptPromise){
      stage='receipt_read';
      const receipt=_orderCorrectionReceiptSnapshot || await _orderCorrectionReceiptPromise;
      if(!receipt) throw new Error('FILE_READ_PERMISSION');
      stage='receipt_hash';
      const digest=await crypto.subtle.digest('SHA-256',receipt.bytes);
      payload.receipt_hash=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
      const ext=(receipt.name.split('.').pop()||'jpg').toLowerCase().replace(/[^a-z0-9]/g,'').slice(0,5)||'jpg';
      stage='receipt_upload';
      payload.receipt_url=await uploadReceiptWithRetry(receipt.bytes,ext,receipt.type);
    }
    stage='correction_submit';
    const session=await getOrderSession();
    const result=await fetch('/api/orders',{
      method:'PATCH',
      headers:{'Content-Type':'application/json','Authorization':'Bearer '+session.access_token},
      body:JSON.stringify(payload)
    });
    let data={}; try{ data=await result.json(); }catch(_){}
    if(!result.ok || !data.order){ const error=new Error(data.error||'Order correction failed'); error.status=result.status; throw error; }
    closeOrderCorrection();
    showToast('مامەڵەکەت ڕاستکرایەوە و بۆ ئادمین نێردرایەوە','success');
    await loadHistory();
  }catch(error){
    reportAppError(error,{operation:'order_correction',stage,order_id:id,file_size:_orderCorrectionReceiptSnapshot?.size||null});
    const message=error?.status===409?'دۆخی مامەڵەکە گۆڕاوە یان ئەم پسووڵەیە پێشتر بەکارهاتووە'
      :error?.message==='FILE_READ_PERMISSION'?kuErr('FILE_READ_PERMISSION')
      :stage==='receipt_upload'?'پسووڵەکە بارنەکرا؛ تکایە دووبارە هەوڵبدەوە'
      :'نەتوانرا ڕاستکردنەوەکە بنێردرێت';
    showToast(message,'error');
  }finally{ btn.disabled=false; btn.innerHTML=defaultButton; }
}

function methodLabel(key){
  return (METHOD_META[key] && METHOD_META[key].label) || key || '—';
}

function renderHistory(rows){
  _orders = rows || [];
  _ordersLoaded = true;
  // an open detail sheet follows realtime status changes
  if(_route==='summary') renderTxScreen();
  renderHomePreview();
  renderDashboard();
  renderHomeFeedbackPrompt();
  maybePromptHomeFeedback();
  renderTxPage();
  updateNavBadge();
}

function pendingHomeFeedbackOrder(){
  return _orders.find(order=>order && order.status==='پەسەندکرا' && !order.feedback) || null;
}
function feedbackReadKey(orderId){ return 'proxo_feedback_read:'+String(orderId); }
function isFeedbackRead(orderId){
  try{return localStorage.getItem(feedbackReadKey(orderId))==='1';}catch(_){return false;}
}
function markFeedbackRead(orderId){
  try{localStorage.setItem(feedbackReadKey(orderId),'1');}catch(_){/* private browsing */}
}
function renderHomeFeedbackPrompt(){
  const el=document.getElementById('homeFeedbackPrompt');
  if(!el)return;
  const order=pendingHomeFeedbackOrder();
  if(!order||isFeedbackRead(order.id)){el.hidden=true;el.innerHTML='';return;}
  el.hidden=false;
  el.innerHTML='<span class="home-feedback-icon" aria-hidden="true"><span class="icn icon--solar icon--solar--star-linear"></span></span>'+
    '<span class="home-feedback-copy"><b>چۆن بوو ئەم مامەڵەیە؟</b><span>هەڵسەنگاندنەکەت یارمەتیمان دەدات.</span></span>'+
    '<button type="button" class="home-feedback-action" onclick="openHomePendingFeedback()">هەڵسەنگاندن</button>';
}
function openHomePendingFeedback(){
  const order=pendingHomeFeedbackOrder();
  if(!order)return;
  markFeedbackRead(order.id);
  _homeFeedbackPromptShownThisSession=true;
  _homeFeedbackPromptQueued=false;
  if(_route!=='home') navigate('home');
  openFeedbackSheet(order.id);
}
function maybePromptHomeFeedback(){
  if(_homeFeedbackPromptShownThisSession||_homeFeedbackPromptQueued||!curUser||_route!=='home'||_txSheetId)return;
  const order=pendingHomeFeedbackOrder();
  if(!order)return;
  _homeFeedbackPromptQueued=true;
  const orderId=String(order.id);
  setTimeout(()=>{
    _homeFeedbackPromptQueued=false;
    if(!curUser||_route!=='home'||_txSheetId||_feedbackSheetId)return;
    const stillPending=_orders.find(row=>String(row.id)===orderId && row.status==='پەسەندکرا' && !row.feedback);
    if(!stillPending||isFeedbackRead(orderId))return;
    markFeedbackRead(orderId);
    _homeFeedbackPromptShownThisSession=true;
    openFeedbackSheet(stillPending.id);
  },850);
}
function renderHomePreview(){
  const el=document.getElementById('historyPreview');
  if(!el) return;
  const rows=_orders.slice(0,4);
  el.innerHTML = rows.length ? '<div class="dbr-list">'+rows.map(dbRowHTML).join('')+'</div>'
    : '<div class="db-empty"><span class="db-empty-ico"><svg class="pxi" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M8 3 4 7l4 4"/><path d="M4 7h16"/><path d="m16 21 4-4-4-4"/><path d="M20 17H4"/></svg></span>'
      + '<b>هێشتا هیچ ئاڵوگۆڕێکت نییە</b><small>یەکەم ئاڵوگۆڕەکەت لە چەند هەنگاوێکدا بکە.</small>'
      + '<button type="button" onclick="navigate(\'exchange\')"><svg class="pxi" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 5v14"/><path d="M5 12h14"/></svg>ئاڵوگۆڕی نوێ</button></div>';
}

// ── dashboard: one row of "latest exchanges" — wallet pair · route + time · amount + status ──
function dbLogoHTML(key){
  const html=methodIconHTML(key,'');
  if(html) return html;
  const label=String(methodLabel(key)||'?').trim();
  return '<span class="method-icon dbr-fb">'+escHtml(label.charAt(0).toUpperCase()||'?')+'</span>';
}
function dbRowHTML(o){
  const refunded=!!o.balance_refunded_at;
  const to=refunded?'AccountBalance':o.to_method;
  const payout=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(o):null;
  const received=payout?payout.display_amount:o.total;
  const amount=refunded?txAmount(o.amount,'AccountBalance'):txAmount(received,o.to_method);
  const tone=tfToneOf(o), id=escHtml(String(o.id));
  return '<button type="button" class="dbr is-'+tone+'" onclick="openTxDetail(\''+id+'\')"'
    + ' aria-label="'+escHtml(methodLabel(o.from_method)+' بۆ '+methodLabel(to)+'، '+amount+'، '+txShortLabelOf(o))+'">'
    + '<span class="dbr-pair" aria-hidden="true">'+dbLogoHTML(o.from_method)+dbLogoHTML(to)+'</span>'
    + '<span class="dbr-main"><span class="dbr-title" dir="ltr">'+txRouteInner(o.from_method,to)+'</span>'
    + '<span class="dbr-sub">'+escHtml(timeAgo(o.created_at))+'</span></span>'
    + '<span class="dbr-end"><b class="dbr-amt" dir="ltr">'+escHtml(amount)+'</b>'
    + '<span class="dbr-st"><i aria-hidden="true"></i>'+escHtml(txShortLabelOf(o))+'</span></span>'
    + '</button>';
}

// ── dashboard (home): approved count + the three other states + greeting ──
function renderDashboard(){
  const num=document.getElementById('dbApproved'); if(!num) return;
  const nameEl=document.getElementById('dbName');
  if(nameEl && curProfile){
    const full=String(curProfile.full_name||curProfile.username||'').trim() || pxAccountLabel() || '—';
    nameEl.textContent=full;
    const av=document.getElementById('dbAvatar');
    if(av && typeof setAvatar==='function') setAvatar(av, full);
  }
  const greet=document.getElementById('dbGreet');
  if(greet){ const h=new Date().getHours(); greet.textContent = h<12 ? 'بەیانیت باش' : h<18 ? 'ڕۆژت باش' : 'ئێوارەت باش'; }
  if(!_ordersLoaded) return;                                   // skeletons stay until the first load
  const c={done:0,pending:0,action:0,rejected:0};
  for(const o of _orders){ const k=txStateOf(o).key; if(k in c) c[k]++; }
  const total=_orders.length;
  const fmt=n=>Number(n).toLocaleString('en-US');
  num.textContent=fmt(c.done);
  const tot=document.getElementById('dbTotal');
  if(tot) tot.textContent = total ? ('کۆی گشتی '+fmt(total)) : 'هێشتا هیچ داواکارییەک نییە';
  const set=(id,n)=>{ const el=document.getElementById(id); if(el){ el.textContent=fmt(n); el.closest('.dbo-row')?.classList.toggle('is-zero',!n); } };
  set('dbApprovedRow',c.done); set('dbPending',c.pending); set('dbAction',c.action); set('dbRejected',c.rejected);
  // status ring: one arc per state, in the legend's order, with a small gap between arcs
  const ring=document.getElementById('dbRing');
  if(ring){
    const C=2*Math.PI*50, parts=[['done','is-ok'],['pending','is-wait'],['action','is-fix'],['rejected','is-bad']].filter(([k])=>c[k]>0);
    const gap=parts.length>1?4:0; let at=0, html='';
    for(const [k,cls] of parts){
      const len=Math.max(c[k]/total*C-gap,1.5);
      html+='<circle class="dbo-arc '+cls+'" cx="60" cy="60" r="50" stroke-dasharray="'+len.toFixed(2)+' '+C.toFixed(2)+'" stroke-dashoffset="'+(-at).toFixed(2)+'"/>';
      at+=c[k]/total*C;
    }
    ring.innerHTML=html;
  }
}
// a status tile opens /transactions already filtered to that status
function dbOpenStatus(key){
  navigate('transactions');
  const chip=document.querySelector('#txStatusFilters .filter-chip[data-status="'+key+'"]');
  if(typeof setTxStatus==='function') setTxStatus(key, chip);
}

function updateNavBadge(){
  const dot=document.getElementById('bnTxDot');
  if(!dot) return;
  const pending=_orders.filter(o=>!o.balance_refunded_at && ['چاوەڕوانە','لەژێر پێداچوونەوەدایە','پێویستی بە ڕاستکردنەوەیە','ڕاستکراوەتەوە'].includes(o.status)).length;
  if(pending>0){ dot.style.display='flex'; dot.textContent=String(pending); }
  else dot.style.display='none';
}

// ── /transactions ───────────────────────────────────────────────
function setTxStatus(v, el){
  _txStatus=v;
  document.querySelectorAll('#txStatusFilters .filter-chip').forEach(c=>c.classList.remove('on'));
  if(el) el.classList.add('on');
  renderTxList();
}
function setTxTime(v, el){
  _txTime=v;
  document.querySelectorAll('#txTimeFilters .filter-chip').forEach(c=>c.classList.remove('on'));
  if(el) el.classList.add('on');
  renderTxList();
}
function onTxSearch(v){
  _txQuery=(v||'').trim().toLowerCase();
  const clr=document.getElementById('txSearchClear');
  if(clr) clr.classList.toggle('show', !!_txQuery);
  renderTxList();
}
function clearTxSearch(){
  const box=document.getElementById('txSearch'); if(box) box.value='';
  onTxSearch('');
}

function txTimeOk(o){
  if(_txTime==='all') return true;
  const t=new Date(o.created_at).getTime();
  if(_txTime==='today'){
    const d=new Date(); d.setHours(0,0,0,0);
    return t>=d.getTime();
  }
  const days=Number(_txTime)||0;
  return t >= Date.now() - days*86400000;
}
function txMatches(o){
  if(_txStatus!=='all' && txStateOf(o).key!==_txStatus) return false;
  if(!txTimeOk(o)) return false;
  if(!_txQuery) return true;
  const q=_txQuery.replace(/[\s#-]/g,'');
  const hay=[
    orderCodeOf(o).toLowerCase(),
    String(o.order_number||''),
    String(o.phone||''),
    methodLabel(o.from_method).toLowerCase(),
    methodLabel(o.to_method).toLowerCase(),
    String(Math.floor(o.amount||0)),
    String(Math.floor(o.total||0)),
    String(o.status||'')
  ].join(' ');
  return hay.replace(/[\s#-]/g,'').includes(q) || hay.includes(_txQuery);
}

function renderTxPage(){
  if(!document.getElementById('txList')) return;
  const counts={done:0,pending:0,action:0,rejected:0,cancelled:0};
  for(const order of _orders)counts[txStateOf(order).key]++;
  // a count of zero is noise on a filter nobody can use
  const count=(id,n)=>{ const el=document.getElementById(id); if(el) el.textContent = n>0 ? String(n) : ''; };
  count('fcAll', _orders.length);
  count('fcWait', counts.pending);
  count('fcCorrection', counts.action);
  count('fcOk', counts.done);
  count('fcNo', counts.rejected);
  count('fcCancel', counts.cancelled);

  renderTxList();
}

function renderTxList(){
  const el=document.getElementById('txList'); if(!el) return;
  const list=_orders.filter(txMatches);
  const cnt=document.getElementById('txResultCount');
  const narrowed = !!_txQuery || _txStatus!=='all' || _txTime!=='all';
  if(!_ordersLoaded){ if(cnt) cnt.textContent=''; el.innerHTML=window.PXS?PXS.txItems(4):''; el.setAttribute('aria-busy','true'); return; }
  el.removeAttribute('aria-busy');
  if(cnt) cnt.textContent = (narrowed && _orders.length) ? (list.length+' لە '+_orders.length+' مامەڵە') : '';
  if(!list.length){
    el.innerHTML = '<div class="empty-state">'
      + (_txQuery ? 'هیچ مامەڵەیەک بەم ئایدییە نەدۆزرایەوە' : 'هیچ مامەڵەیەک نییە بەم فلتەرە')
      + '</div>';
    return;
  }
  el.innerHTML = list.map(orderCardHTML).join('');
}
function copyNum(btn){
  const num=(document.getElementById('myNum').innerText||'').trim();
  if(!num || num==='---') return;
  copyWithFeedback(num, btn);
}

// Admin panel now lives in its own page — see exchange-admin.html


// ══════════════════════════════════════════════════════════════
// ═══ EXTRA ICONS (used by the router pages + notifications) ════
// ══════════════════════════════════════════════════════════════
Object.assign(ICON, {
  // Notification icons — clean, well-formed 24px outline SVGs
  badgeCheck:'<span class="icn icon--solar icon--solar--verified-check-linear" aria-hidden="true"></span>',
  xCircle:'<span class="icn icon--solar icon--solar--close-circle-linear" aria-hidden="true"></span>',
  refresh:'<span class="icn icon--solar icon--solar--refresh-linear" aria-hidden="true"></span>',
  megaphone:'<span class="icn icon--solar icon--solar--bell-linear" aria-hidden="true"></span>',
  bellOff:'<span class="icn icon--solar icon--solar--bell-off-linear" aria-hidden="true"></span>',
  copy:'<span class="icn icon--solar icon--solar--copy-linear" aria-hidden="true"></span>',
  trendUp:'<span class="icn icon--solar icon--solar--graph-up-linear" aria-hidden="true"></span>',
  trendDown:'<span class="icn icon--solar icon--solar--graph-down-linear" aria-hidden="true"></span>',
  lockClosed:'<span class="icn icon--solar icon--solar--lock-linear" aria-hidden="true"></span>',
  lockOpen:'<span class="icn icon--solar icon--solar--lock-unlocked-linear" aria-hidden="true"></span>',
  sparkles:'<span class="icn icon--solar icon--solar--magic-stick-3-linear" aria-hidden="true"></span>',
  equals:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9h14M5 15h14"/></svg>',
  arrowLeftLong:'<span class="icn icon--solar icon--solar--arrow-left-linear" aria-hidden="true"></span>',
  user:'<span class="icn icon--solar icon--solar--user-rounded-linear" aria-hidden="true"></span>',
  sliders:'<span class="icn icon--solar icon--solar--tuning-2-linear" aria-hidden="true"></span>'
});

// ══════════════════════════════════════════════════════════════
// ═══ ROUTER — /, /transactions, /changes, /rules, /profile, /support ═════
// ══════════════════════════════════════════════════════════════
// ROUTE_MODE:
//   'path' → clean URLs (www.domain.com/profile). The server must serve
//            index.html for those paths (see the redirect snippets shipped
//            with this file); otherwise a hard refresh on /profile 404s.
//   'hash' → www.domain.com/#/profile. Works on ANY static host with no
//            server config at all. Switch to this if you cannot add rewrites.
const ROUTE_MODE = 'path';
const ROUTES = { home:'pageDash', exchange:'pageHome', transactions:'pageTx', changes:'pageChanges', rules:'pageRules', profile:'pageProfile', support:'pageSupport', verify:'pageVerify', balance:'pageBalance', 'delete-account':'pageDeleteAccount', 'account-name':'pageAccountName', 'change-phone':'pageChangePhone', 'change-email':'pageChangeEmail', 'change-password':'pageChangePassword', summary:'pageSummary' };
const ROUTE_TITLES = {
  home:'Proxo — ئاڵوگۆڕی دراو',
  exchange:'ئاڵوگۆڕی نوێ — Proxo',
  transactions:'مامەڵەکان — Proxo',
  changes:'گۆڕانکاری نرخەکان — Proxo',
  rules:'یاساکانی ئەپ — Proxo',
  profile:'پڕۆفایل — Proxo',
  support:'پشتگیری — Proxo',
  verify:'پشتڕاستکردنەوەی ناسنامە — Proxo',
  balance:'مێژووی مامەڵەکان — Proxo',
  summary:'پوختەی مامەڵە — Proxo',
  'delete-account':'سڕینەوەی هەژمار — Proxo',
  'account-name':'ناوی هەژمار — Proxo',
  'change-phone':'ژمارەی مۆبایل — Proxo',
  'change-email':'ئیمەیڵ — Proxo',
  'change-password':'وشەی نهێنی — Proxo'
};
// Everything before the route segment, so the app works at the domain root
// (/profile) and inside a sub-folder (/exchange/profile) with no edits.
const BASE_PATH = (function(){
  let p = location.pathname.replace(/[^\/]*\.html?$/i, '');
  const parts = p.split('/').filter(Boolean);
  const lastTwo=parts.slice(-2).join('/');
  if(parts.length>1 && parts[parts.length-2]==='summarytransaction') parts.splice(-2);
  else if(parts.length>1 && AUTH_ROUTE_SET.has(lastTwo)) parts.splice(-2);
  else if(parts.length && (ROUTES[parts[parts.length-1]]||AUTH_ROUTE_SET.has(parts[parts.length-1]))) parts.pop();
  return '/' + (parts.length ? parts.join('/') + '/' : '');
})();
let _route='home';

function routeFromLocation(){
  if(location.hash && location.hash.indexOf('#/')===0){
    const r=location.hash.slice(2).split(/[?&]/)[0];
    if(ROUTES[r]) return r;
  }
  if(isTransactionSummaryRoute()) return 'summary';
  const seg=location.pathname.replace(/\/+$/,'').split('/').pop();
  return (ROUTES[seg] && seg!=='summary') ? seg : 'home';
}
function urlFor(route){
  if(route==='home') return BASE_PATH;
  if(route==='summary') return _txScreenToken ? BASE_PATH+'summarytransaction/'+encodeURIComponent(_txScreenToken) : location.pathname;
  return ROUTE_MODE==='hash' ? BASE_PATH+'#/'+route : BASE_PATH+route;
}
function navigate(route, push){
  if(push===undefined) push=true;
  if(!ROUTES[route]) route='home';
  const _prevRoute=_route;
  _route=route;
  // leaving a section: whatever was typed, picked or filtered there starts fresh next time
  // opening/closing a transaction keeps the list's search and filters as they were
  if(_prevRoute && _prevRoute!==route && route!=='summary' && _prevRoute!=='summary'){ try{ resetSection(_prevRoute); }catch(_){} }
  if(route!=='summary' && typeof resetTxScreenState==='function') resetTxScreenState();
  Object.keys(ROUTES).forEach(r=>{
    const el=document.getElementById(ROUTES[r]);
    if(el) el.classList.toggle('active', r===route);
  });
  // /changes lives under the profile tab
  const navRoute = navRouteOf(route);
  document.querySelectorAll('.bn-item, .hdr-nav-link, .pxn-item, .pxh-link, .pxn-fab').forEach(b=>b.classList.toggle('on', b.dataset.route===navRoute));
  if(push && location.pathname+location.hash!==urlFor(route)){ try{ history.pushState({route:route}, '', urlFor(route)); }catch(_){} }
  document.title = ROUTE_TITLES[route] || 'Proxo';
  closeNotifPanel();
  window.scrollTo({ top:0, behavior: route==='summary' ? 'auto' : 'smooth' });
  if(route==='summary') renderTxScreen();
  if(route==='transactions') renderTxPage();
  if(route==='home'){
    renderHomeFeedbackPrompt();
    maybePromptHomeFeedback();
    if(typeof renderDashboard==='function') renderDashboard();
  }
  if(route==='exchange'){
    if(curUser && typeof loadMyBalance==='function')loadMyBalance();
  }
  if(route==='changes')      loadChangeLog();
  if(route==='profile')    { fillProfileForm(); loadKycStatus(true); if(typeof loadWhatsappSettings==='function')loadWhatsappSettings(); if(curUser && typeof loadMyBalance==='function')loadMyBalance(); pxBalanceLoad(); }
  if(route==='balance')    pxBalHistLoad(true);
  if(route==='verify')     { renderVerifyPage(); loadKycStatus(true); }
  if(route==='support')      loadSupportCases();
  if(route==='delete-account') loadAccountDeletionInfo();
  if(route==='account-name')    openAccountNameScreen();
  if(route==='change-phone')    openChangePhoneScreen();
  if(route==='change-email')    openChangeEmailScreen();
  if(route==='change-password') openPasswordScreen();
}
// Which bottom-bar tab a screen belongs to. The new-order screen (/exchange) opens from the dashboard.
function navRouteOf(route){
  if(['changes','support','verify','balance','delete-account','account-name','change-phone','change-email','change-password'].includes(route)) return 'profile';
  if(route==='summary') return 'transactions';
  if(route==='exchange') return 'home';
  return route;
}
// ══════════════════════════════════════════════════════════════
// ═══ SECTION LIFECYCLE
// ═══  • leaving a section resets its fields, picked files and filters
// ═══  • tapping the active bottom-nav tab twice refreshes that section
// ══════════════════════════════════════════════════════════════
function resetHomeForm(){
  const sub=document.getElementById('submitBtn');
  if(sub && sub.dataset.submitting==='1') return;           // never wipe an order that is being sent
  ['amt','userPhone','userSenderPhone'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  const file=document.getElementById('fileInput');
  if(file){ file.value=''; try{ onFileSelected(file); }catch(_){} }
  clearAllOrderFieldErrors();
  try{ closeRoundingInfo(); }catch(_){}
  try{ closeFeedbackSheet(); }catch(_){}
  calc();
}
function resetTxFilters(){
  _txStatus='all'; _txTime='all'; _txQuery='';
  const box=document.getElementById('txSearch'); if(box) box.value='';
  const clr=document.getElementById('txSearchClear'); if(clr) clr.classList.remove('show');
  ['txStatusFilters','txTimeFilters'].forEach(id=>{
    document.querySelectorAll('#'+id+' .filter-chip').forEach(c=>c.classList.toggle('on', /'all'/.test(c.getAttribute('onclick')||'')));
  });
}
function resetProfileForms(){
  try{ closeUsernameSheet(); }catch(_){}
  try{ fillProfileForm(); }catch(_){}
  const form=document.getElementById('balancePayoutForm');
  if(form){ try{ form.reset(); }catch(_){} form.hidden=true; }
  const hist=document.getElementById('balanceHistoryList'); if(hist) hist.hidden=true;
}
function resetSupportForm(){
  const cat=document.getElementById('supportCategory'); if(cat) cat.selectedIndex=0;
  try{ syncSupportCategoryChips(); }catch(_){}
  ['supportOrderCode','supportDescription'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  clearFieldError('supportDescription');
  try{ updateSupportDescriptionCount(); }catch(_){}
  try{ removeSupportImage(); }catch(_){}
}
function resetSection(route){
  if(route==='exchange')     resetHomeForm();
  else if(route==='transactions') { resetTxFilters(); renderTxPage(); }
  else if(route==='profile') resetProfileForms();
  else if(route==='verify')  { if(!_kycSubmitting) kycResetForm(); }
  else if(route==='support') resetSupportForm();
  else if(route==='balance') pxBalHistReset();
  else if(route==='delete-account') daxReset();
  else if(route==='account-name') anReset();
  else if(route==='change-phone') cpReset();
  else if(route==='change-email') ceReset();
  else if(route==='change-password') pwReset();
}

let _refreshing=false;
/* Refreshes only the data of one screen (used by pull-to-refresh). Never reloads the page. */
async function refreshSection(route, opts){
  opts=opts||{};
  if(_refreshing || !curUser) return false;
  _refreshing=true;
  try{
    if(!opts.keepForms) resetSection(route);
    const legacy=()=>{ try{ return typeof loadMyBalance==='function' ? Promise.resolve(loadMyBalance()).catch(()=>{}) : null; }catch(_){ return null; } };
    const jobs=[];
    if(route==='home')              jobs.push(loadHistory());
    else if(route==='exchange')     jobs.push(loadRates(), loadWallets(), legacy());
    else if(route==='transactions') jobs.push(loadHistory());
    else if(route==='profile')      jobs.push(loadKycStatus(true), pxBalanceLoad(true), legacy(), (typeof loadWhatsappSettings==='function'?loadWhatsappSettings():null));
    else if(route==='balance')      jobs.push(pxBalHistLoad(true), pxBalanceLoad(true));
    else if(route==='changes')      jobs.push(loadChangeLog(true));
    else if(route==='support')      jobs.push(loadSupportCases());
    else if(route==='verify')       jobs.push(loadKycStatus(true));
    const out=await Promise.all(jobs);
    if(out.some(v=>v===false)) return false;
    if(route==='exchange'){ try{ calc(); }catch(_){} }
    return true;
  }catch(e){
    return false;
  }finally{
    _refreshing=false;
  }
}
window.refreshSection=refreshSection;

// ══════════════════════════════════════════════════════════════
// ═══ ACCOUNT BALANCE CARD + HISTORY SCREEN (Supabase: Exchange)
// ═══  card   → ex_customer_balances (own row, RLS)
// ═══  screen → ex_my_balance_activity(): only balance added by an admin + refunds
// ══════════════════════════════════════════════════════════════
const BAL_HIST_PAGE=20;
let _balAt=0, _balBusy=null;
let _bhRows=[], _bhDone=false, _bhBusy=false, _bhError=false;
function pxIqd(n){ return Number(n||0).toLocaleString('en-US')+' IQD'; }
// Balance card: the number is large, the currency is a quiet unit next to it.
function pxBalanceShow(el, n){ el.innerHTML='<bdi class="bx-num">'+Number(n||0).toLocaleString('en-US')+'</bdi><small class="bx-cur">IQD</small>'; }
function pxBalanceLoad(force){
  if(!curUser || typeof sb==='undefined' || !sb) return Promise.resolve(true);
  if(_balBusy) return _balBusy;
  if(!force && Date.now()-_balAt<10000) return Promise.resolve(true);
  const btn=document.getElementById('bxRefreshBtn'), out=document.getElementById('bxAmount');
  if(btn){ btn.classList.add('is-loading'); btn.disabled=true; }
  const started=Date.now();
  _balBusy=(async()=>{
    let ok=true;
    try{
      const {data,error}=await sb.from('ex_customer_balances').select('available_iqd').eq('user_id',curUser.id).maybeSingle();
      if(error) throw error;
      if(out){ pxBalanceShow(out, data ? data.available_iqd : 0); out.classList.remove('is-error'); }
      _balAt=Date.now();
    }catch(e){
      ok=false;
      if(out && !/\d/.test(out.textContent||'')){ out.textContent='—'; }
    }
    const wait=Math.max(0, 650-(Date.now()-started));        // let the icon turn at least once
    if(wait) await new Promise(r=>setTimeout(r,wait));
    if(btn){ btn.classList.remove('is-loading'); btn.disabled=false; }
    _balBusy=null;
    return ok;
  })();
  return _balBusy;
}
async function pxBalanceRefresh(){
  const ok=await pxBalanceLoad(true);
  if(!ok) showToast('نەتوانرا باڵانس نوێ بکرێتەوە، دووبارە هەوڵبدەوە','error','هەڵە',{id:'bal-refresh',duration:3200});
}
function pxBalHistReset(){ _bhRows=[]; _bhDone=false; _bhError=false; const l=document.getElementById('bhList'); if(l) l.innerHTML=''; const m=document.getElementById('bhMore'); if(m) m.hidden=true; }
const BH_ICONS={
  added:'<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="12" r="9"/><path d="M12 8v8"/><path d="M8 12h8"/></svg>',
  refund:'<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/></svg>'
};
const BH_LABEL={ added:'زیادکردنی باڵانس', refund:'گەڕاندنەوەی باڵانس' };
function bhDateTime(iso){
  const d=new Date(iso); if(isNaN(d)) return '';
  const p=n=>String(n).padStart(2,'0');
  return d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate())+'  '+p(d.getHours())+':'+p(d.getMinutes());
}
function renderBalHist(){
  const list=document.getElementById('bhList'), more=document.getElementById('bhMore'); if(!list) return;
  if(_bhError && !_bhRows.length){
    list.innerHTML='<div class="bh-state"><b>نەتوانرا مێژووەکە بار بکرێت</b><button type="button" onclick="pxBalHistLoad(true)">دووبارە هەوڵبدەرەوە</button></div>';
  }else if(_bhBusy && !_bhRows.length){
    list.innerHTML=window.PXS?PXS.balHist(3):'<div class="bh-skel"></div><div class="bh-skel"></div><div class="bh-skel"></div>';
  }else if(!_bhRows.length){
    list.innerHTML='<div class="bh-state"><b>هێشتا هیچ مامەڵەیەک نییە</b></div>';
  }else{
    list.innerHTML=_bhRows.map(r=>{
      const k=r.kind==='refund'?'refund':'added';
      const sub=[r.order_code?('مامەڵە '+r.order_code):'', r.note||''].filter(Boolean).join(' · ');
      return '<article class="bh-item is-'+k+'">'
        +'<span class="bh-ico">'+BH_ICONS[k]+'</span>'
        +'<div class="bh-main"><b>'+BH_LABEL[k]+'</b>'
        +(sub?'<small>'+escHtml(sub)+'</small>':'')
        +'<time dir="ltr">'+escHtml(bhDateTime(r.created_at))+'</time></div>'
        +'<strong class="bh-amt" dir="ltr">+'+escHtml(pxIqd(r.delta_iqd))+'</strong>'
        +'</article>';
    }).join('');
  }
  if(more){ more.hidden=_bhDone || !_bhRows.length; more.disabled=_bhBusy; }
}
async function pxBalHistLoad(reset){
  if(!curUser || typeof sb==='undefined' || !sb) return true;
  if(_bhBusy) return true;
  if(reset){ _bhRows=[]; _bhDone=false; }
  _bhBusy=true; _bhError=false; renderBalHist();
  let ok=true;
  try{
    const before=_bhRows.length ? _bhRows[_bhRows.length-1].created_at : null;
    const {data,error}=await sb.rpc('ex_my_balance_activity',{p_limit:BAL_HIST_PAGE,p_before:before});
    if(error) throw error;
    const rows=Array.isArray(data)?data:[];
    _bhRows=_bhRows.concat(rows);
    if(rows.length<BAL_HIST_PAGE) _bhDone=true;
  }catch(e){ ok=false; _bhError=true; }
  _bhBusy=false; renderBalHist();
  return ok;
}
function pxBalHistMore(){ return pxBalHistLoad(false); }

window.addEventListener('popstate', function(){
  const requested=authRouteFromLocation();
  if(!curUser){
    let route=requested||'login';
    if((route==='login/otp'||route==='signup/otp')&&!_otpPendingData) route=route.split('/')[0];
    if(route==='forgetpassword/otp'&&!_fpEmail) route='forgetpassword';
    if(route==='newpassword'&&!_fpVerified) route='forgetpassword';
    setAuthRoute(route,false,!requested||route!==requested);
    return;
  }
  if(requested){ try{history.replaceState({},'',BASE_PATH);}catch(_){} }
  navigate(routeFromLocation(), false);
});

// ══════════════════════════════════════════════════════════════
// ═══ CHANGE LOG (ex_change_log — filled by database triggers) ══
// ══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
// ═══ RATE BOARD + CHANGE LOG  (route "/changes")
// ═══ Two halves: what the rate IS right now, and how it moved.
// ══════════════════════════════════════════════════════════════
const SAMPLE_IQD = 100000;   // "for every 100,000 you send, you receive …"

const CHG_FIELD_LABEL = {
  multiplier:'ڕێژەی گۆڕین', fee_percent:'ڕێژەی لێبڕین', fee_fixed:'لێبڕینی جێگیر',
  new_route:'ڕێگایەکی نوێ', is_active:'دۆخی ڕێگا', fee_tier_config:'پلەی لێبڕین', new_wallet:'واڵێتێکی نوێ',
  fee:'لێبڕین', price:'نرخ', is_locked:'دۆخی واڵێت', allow_receive:'وەرگرتن', allow_from:'ناردن'
};

// What a change MEANS for the customer — not just whether the number went up.
// A bigger multiplier is good news; a bigger fee is not.
function chgTone(r){
  const up = r.direction==='up';
  if(r.field==='multiplier') return up ? 'good' : 'bad';
  if(r.field==='fee_percent' || r.field==='fee_fixed' || r.field==='fee') return up ? 'bad' : 'good';
  if(r.field==='is_active' || r.field==='allow_from' || r.field==='allow_receive') return r.new_value==='true' ? 'good' : 'bad';
  if(r.field==='is_locked') return r.new_value==='true' ? 'bad' : 'good';
  return 'neutral';
}
function chgHeadline(r){
  const up = r.direction==='up';
  switch(r.field){
    case 'multiplier':  return up ? 'ڕێژەی گۆڕین بەرزبووەوە' : 'ڕێژەی گۆڕین نزم بووەوە';
    case 'fee_percent':
    case 'fee_fixed':
    case 'fee':         return up ? 'لێبڕین زیادی کرد' : 'لێبڕین کەمی کرد';
    case 'is_active':   return r.new_value==='true' ? 'ئەم ڕێگایە کرایەوە' : 'ئەم ڕێگایە داخرا';
    case 'is_locked':   return r.new_value==='true' ? 'واڵێت داخرا' : 'واڵێت کرایەوە';
    case 'allow_receive': return r.new_value==='true' ? 'وەرگرتن کرایەوە' : 'وەرگرتن داخرا';
    case 'allow_from':    return r.new_value==='true' ? 'ناردن کرایەوە' : 'ناردن داخرا';
    case 'fee_tier_config': {
      let on=false;try{on=!!JSON.parse(r.new_value||'{}').enabled;}catch(e){}
      return on?'پلەی لێبڕین بەپێی بڕ دانرا':'پلەی لێبڕین لابرا';
    }
    case 'new_route':   return 'ڕێگایەکی نوێ زیادکرا';
    case 'new_wallet':  return 'واڵێتێکی نوێ زیادکرا';
    default: return escHtml(CHG_FIELD_LABEL[r.field] || r.field);
  }
}
// One plain sentence so nobody has to decode the numbers themselves
function chgMeaning(r){
  if(r.field==='multiplier' || r.field==='fee_percent' || r.field==='fee_fixed' || r.field==='fee'){
    return chgTone(r)==='good' ? 'ئێستا زیاتر وەردەگریت' : 'ئێستا کەمتر وەردەگریت';
  }
  return '';
}
function chgIcon(r){
  const t=chgTone(r);
  if(r.field==='is_locked' || r.field==='is_active' || r.field==='allow_from' || r.field==='allow_receive')
    return t==='good' ? ICON.lockOpen : ICON.lockClosed;
  if(r.field==='new_route' || r.field==='new_wallet' || r.field==='fee_tier_config') return ICON.sparkles;
  return r.direction==='up' ? ICON.trendUp : ICON.trendDown;
}
function chgValueText(field, v){
  if(v===null || v===undefined || v==='') return '—';
  if(field==='fee_tier_config'){
    try{
      const t=JSON.parse(v);
      if(!t||!t.enabled) return 'نییە';
      if(Array.isArray(t.brackets)&&t.brackets.length>=2)return tierHintText({brackets:t.brackets.map(b=>({upTo:b.up_to==null?null:Number(b.up_to),percent:Number(b.percent)}))});
      return tierHintText({limit:Number(t.limit_iqd),low:Number(t.low_percent),high:Number(t.high_percent)});
    }catch(e){ return '—'; }
  }
  if(field==='is_active' || field==='allow_from' || field==='allow_receive') return v==='true' ? 'کراوە' : 'داخراوە';
  if(field==='is_locked') return v==='true' ? 'داخراوە' : 'کراوە';
  const n=Number(v);
  if(!isNaN(n)) return (field==='fee_percent'||field==='fee') ? (fmtPct(n)+'%') : formatNum(n);
  return escHtml(String(v));
}
function chgDelta(r){
  const a=Number(r.old_value), b=Number(r.new_value);
  if(isNaN(a) || isNaN(b) || a===0) return '';
  const d=((b-a)/a)*100;
  if(!isFinite(d) || Math.abs(d)<0.01) return '';
  return (d>0?'+':'') + fmtPct(d) + '%';
}
function chgRouteHTML(r){
  if(r.kind==='rate'){
    return '<span class="chg-route">'
      + methodIconHTML(r.from_method,'sz-xs') + '<b>' + escHtml(methodLabel(r.from_method)) + '</b>'
      + '<span class="chg-arrow">' + ICON.arrowLeftLong + '</span>'
      + methodIconHTML(r.to_method,'sz-xs') + '<b>' + escHtml(methodLabel(r.to_method)) + '</b>'
      + '</span>';
  }
  return '<span class="chg-route">'
    + methodIconHTML(r.wallet_key,'sz-xs') + '<b>' + escHtml(methodLabel(r.wallet_key) || r.label || '—') + '</b>'
    + '</span>';
}

// ── the "what you get right now" board ───────────────────────
function rateOutcome(amount, r){
  const tier=rateTierFromRow(r);
  const eff=tier&&(r.rate_type==='fee_percent'||r.rate_type==='multiplier')
    ?ProxoPricing.effectiveRate({type:r.rate_type,value:Number(r.rate_value),tier:tier},amount):null;
  const v=Number(eff?eff.value:r.rate_value)||0;
  if(r.rate_type==='fee_percent') return { out: amount - (amount*v/100), fee: v>0 ? ('لێبڕین '+fmtPct(v)+'%') : 'بێ لێبڕین' };
  if(r.rate_type==='fee_fixed')   return { out: Math.max(0, amount-v),   fee: v>0 ? ('لێبڕین '+formatNum(v)+' IQD') : 'بێ لێبڕین' };
  return { out: amount*v, fee: v<1 ? ('لێبڕین '+fmtPct(100-v*100)+'%') : '' };
}
function renderRatesNow(rows){
  const el=document.getElementById('ratesNow'); if(!el) return;
  const pos=k=>{ const i=FROM_OPTIONS.indexOf(k); return i<0 ? 99 : i; };
  const list=(rows||[])
    .filter(r=>!getWalletInfo(r.from_method).locked && !getWalletInfo(r.to_method).locked)
    .sort((a,b)=> (pos(a.from_method)-pos(b.from_method)) || (pos(a.to_method)-pos(b.to_method)));

  if(!list.length){ el.innerHTML='<div class="pfs-empty"><b>هیچ ڕێگایەکی کراوە نییە</b></div>'; return; }

  el.innerHTML = list.map(function(r){
    const isUsdt = r.from_method==='USDT';
    const amount = isUsdt ? 1 : SAMPLE_IQD;
    const o = rateOutcome(amount, r);
    const inTxt  = isUsdt ? '1 $' : formatNum(amount)+' IQD';
    const outTxt = formatNum(Math.floor(o.out))+' IQD';
    return '<div class="rate-card">'
      + '<div class="rate-route">'
        + '<span class="rate-w">'+methodIconHTML(r.from_method,'sz-xs')+escHtml(methodLabel(r.from_method))+'</span>'
        + '<span class="rate-arrow">'+ICON.arrowLeftLong+'</span>'
        + '<span class="rate-w">'+methodIconHTML(r.to_method,'sz-xs')+escHtml(methodLabel(r.to_method))+'</span>'
      + '</div>'
      + '<div class="rate-eq">'
        + '<span class="rate-in">'+inTxt+'</span>'
        + '<span class="rate-eqico">'+ICON.equals+'</span>'
        + '<span class="rate-out">'+outTxt+'</span>'
      + '</div>'
      + (o.fee ? '<div class="rate-fee">'+o.fee+'</div>' : '')
      + (rateTierFromRow(r) ? '<div class="rate-fee rate-tier">'+tierHintText(rateTierFromRow(r))+'</div>' : '')
      + '</div>';
  }).join('');
}

let _changesLoaded=false;
async function loadChangeLog(force){
  const el=document.getElementById('changesList'); if(!el) return;
  if(_changesLoaded && !force) return;
  if(window.PXS){
    el.innerHTML=PXS.changeItems(3);
    const now=document.getElementById('ratesNow'); if(now && !now.querySelector('.rate-card:not(.is-skel)')) now.innerHTML=PXS.rateCards(3);
  }else el.innerHTML='<div class="pfs-empty"><b>بارکردن...</b></div>';
  try{
    const res = await Promise.all([
      sb.from('ex_change_log').select('*').order('created_at',{ascending:false}).limit(60),
      sb.from('ex_rates').select('*').eq('is_active',true)
    ]);
    _changesLoaded=true;
    renderRatesNow((res[1] && res[1].data) || []);
    renderChangeLog((res[0] && res[0].data) || []);
  }catch(e){
    const now=document.getElementById('ratesNow'); if(now && now.querySelector('.is-skel')) now.innerHTML='';
    el.innerHTML='<div class="pfs-empty"><b>نەتوانرا گۆڕانکارییەکان باربکرێن</b></div>';
  }
}

function renderChangeLog(rows){
  const el=document.getElementById('changesList'); if(!el) return;
  if(!rows.length){ el.innerHTML='<div class="pfs-empty"><b>هێشتا هیچ گۆڕانکارییەک نییە</b></div>'; return; }
  let html='', lastDay='';
  rows.forEach(function(r){
    const dk=dayKey(r.created_at);
    if(dk!==lastDay){ lastDay=dk; html += '<div class="notif-day">'+dayLabel(r.created_at)+'</div>'; }
    const tone=chgTone(r);
    const isNew=(r.field==='new_route' || r.field==='new_wallet');
    const delta=isNew ? '' : chgDelta(r);
    const meaning=isNew ? '' : chgMeaning(r);
    const vals = isNew
      ? ''
      : '<div class="chg-vals">'
        + '<span class="chg-old">'+chgValueText(r.field, r.old_value)+'</span>'
        + '<span class="chg-to">'+ICON.arrowLeftLong+'</span>'
        + '<span class="chg-new">'+chgValueText(r.field, r.new_value)+'</span>'
        + (delta ? '<span class="chg-delta '+tone+'">'+delta+'</span>' : '')
        + '</div>';
    html += '<div class="chg-item '+tone+'">'
      + '<span class="chg-ico '+tone+'">'+chgIcon(r)+'</span>'
      + '<div class="chg-body">'
        + '<div class="chg-head">'
          + '<span class="chg-headline">'+chgHeadline(r)+'</span>'
          + '<span class="chg-time">'+timeAgo(r.created_at)+'</span>'
        + '</div>'
        + chgRouteHTML(r)
        + vals
        + (meaning ? '<div class="chg-meaning '+tone+'">'+meaning+'</div>' : '')
      + '</div>'
      + '</div>';
  });
  el.innerHTML=html;
}

// ══════════════════════════════════════════════════════════════
// ═══ PROFILE — name + phone, saved to ex_profiles ══════════════
// ══════════════════════════════════════════════════════════════
function initialOf(s){ const t=(s||'').trim(); return t ? t.charAt(0).toUpperCase() : '؟'; }
function normalizePersonName(s){ return String(s||'').trim().replace(/\s+/g,' ').toLocaleLowerCase(); }

function syncSenderIdentity(){
  const el=document.getElementById('userSenderName');
  if(el) el.value=(curProfile&&curProfile.full_name)||'';
}

// ══════════════════════════════════════════════════════════════
// ═══ ACCOUNT — name, mobile number and password, each on its own screen
// ═══   /account-name     once every 30 days; fixed after identity verification
// ═══   /change-phone     WhatsApp code to the NEW number; once every 30 days;
// ═══                     a verified number belongs to one account only
// ═══   /change-password  current password; other devices are signed out
// ═══ The database and /api/auth enforce every rule; these screens explain them.
// ══════════════════════════════════════════════════════════════
const ACCOUNT_CHANGE_DAYS=30, DAY_MS=24*60*60*1000;
// When the next change is allowed (ms), or null when it is allowed now.
function acxNextChange(stamp){
  if(!stamp) return null;
  const at=new Date(stamp).getTime()+ACCOUNT_CHANGE_DAYS*DAY_MS;
  return Number.isFinite(at) && at>Date.now() ? at : null;
}
function acxDay(ms){ return String(kycFmtDate(new Date(ms).toISOString())); }
function acxDaysLeft(ms){ return Math.max(1, Math.ceil((ms-Date.now())/DAY_MS)); }
// A calm notice instead of an error: why it can't be done now, and when it can.
// Every text here is our own copy (no user input).
function acxNote(id, opts){
  const el=document.getElementById(id); if(!el) return;
  if(!opts){ el.hidden=true; el.innerHTML=''; el.removeAttribute('data-tone'); return; }
  let meter='';
  if(opts.until){
    const left=acxDaysLeft(opts.until);
    const pct=Math.min(100,Math.max(4,Math.round(100*(ACCOUNT_CHANGE_DAYS-left)/ACCOUNT_CHANGE_DAYS)));
    meter='<div class="acx-meter" role="img" aria-label="'+String(left)+' ڕۆژی ماوە"><span style="width:'+pct+'%"></span></div>'
         +'<small class="acx-meter-txt">'+String(left)+' ڕۆژی ماوە</small>';
  }
  el.dataset.tone=opts.tone;
  el.innerHTML='<div class="acx-note-body"><b>'+opts.title+'</b><p>'+opts.text+'</p>'+meter+'</div>';
  el.hidden=false;
}
function acxErr(id,text){ const el=document.getElementById(id); if(el) el.textContent=text||''; }
function acxBusy(id,on){
  const b=document.getElementById(id); if(!b) return;
  b.classList.toggle('is-loading',!!on); if(on) b.disabled=true;
}
function acxEye(btn){
  const input=btn && btn.parentElement && btn.parentElement.querySelector('input'); if(!input) return;
  const show=input.type==='password';
  input.type=show?'text':'password';
  btn.classList.toggle('is-on',show);
  btn.setAttribute('aria-label',show?'شاردنەوەی وشەی نهێنی':'پیشاندانی وشەی نهێنی');
}
// Six code boxes, the same as the sign-in code screen. The hidden #cpCode /
// #ceCode keeps the whole code, so the rest of the flow reads one value.
function acxCodeBoxes(id){ const host=document.querySelector('.acx-otp[data-code="'+id+'"]'); return host?[...host.querySelectorAll('.acx-digit')]:[]; }
function acxDigits(v){ return String(v||'').replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-1632)).replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-1776)).replace(/\D/g,''); }
function acxCodeRead(id){ const v=acxCodeBoxes(id).map(b=>b.value||'').join(''); const h=document.getElementById(id); if(h) h.value=v; return v; }
function acxCodeSet(id,digits){
  const d=acxDigits(digits).slice(0,6);
  acxCodeBoxes(id).forEach((b,i)=>{ b.value=d[i]||''; });
  const h=document.getElementById(id); if(h) h.value=d;
  return d;
}
function acxCodeFocus(id,index){ const b=acxCodeBoxes(id); const el=b[Math.max(0,Math.min(b.length-1,index||0))]; try{ el && el.focus({preventScroll:true}); }catch(_){} }
function acxCodeChanged(host,id){
  const sync=host.dataset.sync; if(sync && typeof window[sync]==='function') window[sync]();
  if(acxCodeRead(id).length===6){ const f=host.closest('form'); if(f && typeof f.requestSubmit==='function') f.requestSubmit(); }
}
function acxCodeInput(el){
  const host=el.closest('.acx-otp'); if(!host) return;
  const id=host.dataset.code, boxes=acxCodeBoxes(id), i=boxes.indexOf(el);
  const d=acxDigits(el.value);
  if(d.length>1){                                   // pasted or filled by the phone
    const code=acxCodeSet(id, boxes.slice(0,i).map(b=>b.value||'').join('')+d);
    acxCodeFocus(id, code.length);
  }else{
    el.value=d;
    if(d) acxCodeFocus(id, i+1);
  }
  acxCodeChanged(host,id);
}
function acxCodeKey(e,el){
  if(e.key!=='Backspace' || el.value) return;
  const host=el.closest('.acx-otp'); if(!host) return;
  const id=host.dataset.code, boxes=acxCodeBoxes(id), i=boxes.indexOf(el);
  if(i>0){ e.preventDefault(); boxes[i-1].value=''; acxCodeFocus(id,i-1); acxCodeChanged(host,id); }
}
function acxCodePaste(e,el){
  const d=acxDigits(e.clipboardData && e.clipboardData.getData('text'));
  if(!d) return;
  e.preventDefault();
  const host=el.closest('.acx-otp'); if(!host) return;
  const id=host.dataset.code, code=acxCodeSet(id,d);
  acxCodeFocus(id, code.length);
  acxCodeChanged(host,id);
}
async function refreshProfileRow(){
  if(!sb || !curUser) return;
  try{
    const {data}=await sb.from('ex_profiles').select('*').eq('id',curUser.id).maybeSingle();
    if(data){ curProfile=Object.assign({},curProfile||{},data); applyProfileToUI(); renderAccountMenu(); }
  }catch(_){}
}
function accountPhoneVerified(){ return !!(curProfile && curProfile.phone && curProfile.phone_verified_at); }
function accountEmailVerified(){ return !!(curProfile && curProfile.email && curProfile.email_verified_at); }

// ── profile menu rows ─────────────────────────────────────────
function renderAccountMenu(){
  const n=document.getElementById('pfMenuName');
  if(n) n.textContent=(curProfile && curProfile.full_name) || '—';
  const p=document.getElementById('pfMenuPhone');
  if(p){
    p.textContent='';
    const phone=curProfile && curProfile.phone;
    if(phone){
      const num=document.createElement('span'); num.dir='ltr'; num.textContent=phone; p.appendChild(num);
      const tag=document.createElement('span');
      tag.className=accountPhoneVerified()?'acx-ok':'acx-warn';
      tag.textContent=accountPhoneVerified()?'پشتڕاستکراوە':'پشتڕاست نەکراوەتەوە';
      p.appendChild(document.createTextNode(' ')); p.appendChild(tag);
    }else{
      p.textContent='—';
    }
  }
  const m=document.getElementById('pfMenuEmail');
  if(m){
    m.textContent='';
    const email=curProfile && curProfile.email;
    if(email){
      const addr=document.createElement('span'); addr.dir='ltr'; addr.textContent=email; m.appendChild(addr);
      const tag=document.createElement('span');
      tag.className=accountEmailVerified()?'acx-ok':'acx-warn';
      tag.textContent=accountEmailVerified()?'پشتڕاستکراوە':'پشتڕاست نەکراوەتەوە';
      m.appendChild(document.createTextNode(' ')); m.appendChild(tag);
    }else{
      m.textContent='—';
    }
  }
}
// Kept for older call sites (sign-in, KYC refresh, leaving the profile).
function fillProfileForm(){ applyProfileToUI(); renderAccountMenu(); }
function updateProfileCooldownUI(){
  renderAccountMenu();
  if(_route==='account-name') renderAccountNameScreen();
  if(_route==='change-phone') renderChangePhoneScreen();
  if(_route==='change-email') renderChangeEmailScreen();
}

// ── /account-name ─────────────────────────────────────────────
let _anBusy=false;
function anReset(){
  const i=document.getElementById('anInput'); if(i) i.value='';
  acxErr('anErr','');
}
function openAccountNameScreen(){
  anReset();
  renderAccountNameScreen();
  Promise.all([refreshProfileRow(), curUser ? loadKycStatus(true) : null])
    .then(()=>{ if(_route==='account-name') renderAccountNameScreen(); }).catch(()=>{});
}
function renderAccountNameScreen(){
  const cur=document.getElementById('anCurrent');
  if(cur) cur.textContent=(curProfile && curProfile.full_name) || '—';
  let note=null;
  if(kycNameLocked()){
    note={tone:'lock', title:'ناتوانیت ناوی هەژمار بگۆڕیت',
          text:'ناوەکەت بە ناسنامە پشتڕاستکراوەتەوە، بۆیە جێگیر کراوە و هەمیشە وەک ناوی ناو بەڵگەنامەکەت دەمێنێتەوە.'};
  }else{
    const at=(curProfile && !curProfile.is_admin) ? acxNextChange(curProfile.name_changed_at) : null;
    if(at) note={tone:'wait', title:'ئێستا ناتوانیت ناوی هەژمار بگۆڕیت',
                 text:'ناو هەر 30 ڕۆژ جارێک دەگۆڕدرێت. لە '+acxDay(at)+' دەتوانیت دووبارە بیگۆڕیت.', until:at};
  }
  acxNote('anNote',note);
  const form=document.getElementById('anForm'); if(form) form.hidden=!!note;
  anSync(true);
}
function anSync(keepError){
  const v=String(document.getElementById('anInput')?.value||'').trim().replace(/\s+/g,' ');
  const ok=v.length>=3 && v.length<=80 && normalizePersonName(v)!==normalizePersonName(curProfile?.full_name);
  const b=document.getElementById('anBtn'); if(b) b.disabled=!ok || _anBusy;
  if(!keepError) acxErr('anErr','');
}
async function submitAccountName(ev){
  if(ev) ev.preventDefault();
  if(_anBusy || !curUser) return;
  const name=String(document.getElementById('anInput').value||'').trim().replace(/\s+/g,' ');
  if(name.length<3 || name.length>80) return acxErr('anErr','ناو دەبێت لە نێوان 3 بۆ 80 پیت بێت');
  if(normalizePersonName(name)===normalizePersonName(curProfile?.full_name)) return acxErr('anErr','ئەمە هەمان ناوی ئێستای هەژمارەکەتە');
  _anBusy=true; acxBusy('anBtn',true);
  try{
    const {data,error}=await sb.from('ex_profiles').update({full_name:name}).eq('id',curUser.id).select().single();
    if(error) throw error;
    curProfile=Object.assign({},curProfile||{},data||{});
    if(!curProfile.name_changed_at) curProfile.name_changed_at=new Date().toISOString();
    applyProfileToUI(); renderAccountMenu();
    anReset();
    showToast('ناوی هەژمار گۆڕدرا','success','گۆڕدرا');
    navigate('profile');
  }catch(e){
    const msg=String((e && (e.message||e.details))||'');
    if(msg.includes('PROFILE_NAME_COOLDOWN')){
      const until=Date.parse(String(e.details||''));
      if(curProfile && Number.isFinite(until)) curProfile.name_changed_at=new Date(until-ACCOUNT_CHANGE_DAYS*DAY_MS).toISOString();
      else await refreshProfileRow();
      renderAccountNameScreen();                       // the calm notice, not an error
    }else if(msg.includes('PROFILE_NAME_LOCKED_BY_KYC')){
      await loadKycStatus(true);
      if(_kyc && _kyc.data) _kyc.data.name_locked=true;
      renderAccountNameScreen();
    }else if(msg.includes('PROFILE_NAME_INVALID')){
      acxErr('anErr','ناو دەبێت لە نێوان 3 بۆ 80 پیت بێت');
    }else{
      acxErr('anErr','نەتوانرا ناوەکە بگۆڕدرێت. دووبارە هەوڵ بدەرەوە.');
    }
  }finally{
    _anBusy=false; acxBusy('anBtn',false); anSync(true);
  }
}

// ── /change-phone ─────────────────────────────────────────────
const _cp={phone:null,password:'',busy:false,timer:null,resendAt:0};
function cpShowStep(step){
  const s1=document.getElementById('cpStep1'), s2=document.getElementById('cpStep2');
  if(s1) s1.hidden=step!==1;
  if(s2) s2.hidden=step!==2;
}
function cpReset(){
  ['cpPhone','cpPass'].forEach(id=>{ const el=document.getElementById(id); if(el){ el.value=''; if(id==='cpPass') el.type='password'; } });
  acxCodeSet('cpCode','');
  document.querySelectorAll('#pageChangePhone .acx-eye').forEach(b=>b.classList.remove('is-on'));
  acxErr('cpErr',''); acxErr('cpCodeErr','');
  _cp.phone=null; _cp.password=''; _cp.busy=false;
  clearInterval(_cp.timer); _cp.timer=null;
  cpShowStep(1);
}
function openChangePhoneScreen(){
  cpReset();
  renderChangePhoneScreen();
  refreshProfileRow().then(()=>{ if(_route==='change-phone') renderChangePhoneScreen(); });
}
function renderChangePhoneScreen(){
  const phone=curProfile && curProfile.phone, verified=accountPhoneVerified();
  const cur=document.getElementById('cpCurrent'); if(cur) cur.textContent=phone || 'هیچ ژمارەیەک نییە';
  const tag=document.getElementById('cpTag');
  if(tag){
    tag.hidden=!phone;
    tag.dataset.tone=verified?'ok':'warn';
    tag.textContent=verified?'پشتڕاستکراوە':'پشتڕاست نەکراوەتەوە';
  }
  const label=document.querySelector('label[for="cpPhone"]');
  if(label) label.textContent=verified?'ژمارەی نوێ':'ژمارەی مۆبایل';
  const at=acxNextChange(curProfile && curProfile.phone_changed_at);
  if(at){
    acxNote('cpNote',{tone:'wait', title:'ئێستا ناتوانیت ژمارەی مۆبایل بگۆڕیت',
      text:'ژمارەی مۆبایل هەر 30 ڕۆژ جارێک دەگۆڕدرێت. لە '+acxDay(at)+' دەتوانیت دووبارە بیگۆڕیت.', until:at});
    cpShowStep(0);
    return;
  }
  acxNote('cpNote', null);
  if(!_cp.phone) cpShowStep(1);
  const input=document.getElementById('cpPhone');
  if(input && !input.value && phone && !verified) input.value=phone;     // their saved number, ready to verify
  cpSync(true);
}
function cpSync(keepError){
  const send=document.getElementById('cpSendBtn');
  if(send) send.disabled=_cp.busy || !pxIraqiPhone(document.getElementById('cpPhone')?.value) || !document.getElementById('cpPass')?.value;
  const verify=document.getElementById('cpVerifyBtn');
  if(verify) verify.disabled=_cp.busy || String(document.getElementById('cpCode')?.value||'').length!==6;
  if(!keepError){ acxErr('cpErr',''); acxErr('cpCodeErr',''); }
}
function acxClock(sec){ const m=Math.floor(sec/60), s=sec%60; return String(m+':'+(s<10?'0':'')+s); }
function cpStartResend(seconds){
  clearInterval(_cp.timer);
  _cp.resendAt=Date.now()+seconds*1000;
  const tick=()=>{
    const b=document.getElementById('cpResend'); if(!b) return;
    const left=Math.ceil((_cp.resendAt-Date.now())/1000);
    if(left<=0){ clearInterval(_cp.timer); _cp.timer=null; b.disabled=false; b.textContent='دووبارە ناردنەوە'; return; }
    b.disabled=true; b.textContent='دووبارە ناردنەوە لە '+acxClock(left);
  };
  tick(); _cp.timer=setInterval(tick,1000);
}
// Cool-down → the calm notice; anything else → the message under the field.
function cpFail(r, errId){
  if(r.code==='PHONE_COOLDOWN'){
    const until=Date.parse(r.available_at||'');
    if(curProfile && Number.isFinite(until)) curProfile.phone_changed_at=new Date(until-ACCOUNT_CHANGE_DAYS*DAY_MS).toISOString();
    cpReset(); renderChangePhoneScreen(); return;
  }
  acxErr(errId, pxAuthError(r));
}
async function cpSend(ev){
  if(ev) ev.preventDefault();
  if(_cp.busy) return;
  const phone=pxIraqiPhone(document.getElementById('cpPhone').value);
  const password=document.getElementById('cpPass').value;
  if(!phone) return acxErr('cpErr','ژمارەی مۆبایلەکە دروست نییە');
  if(!password) return acxErr('cpErr','وشەی نهێنیی ئێستات بنووسە');
  _cp.busy=true; acxBusy('cpSendBtn',true);
  const r=await pxAuthApi('phone_change_start',{phone,password},true);
  _cp.busy=false; acxBusy('cpSendBtn',false); cpSync(true);
  if(!r.ok) return cpFail(r,'cpErr');
  _cp.phone=phone; _cp.password=password;
  const target=document.getElementById('cpTarget'); if(target) target.textContent='0'+phone.slice(4);
  acxCodeSet('cpCode','');
  cpShowStep(2); cpStartResend(pxSecondsLeft(r.expires_at,300)); cpSync();
  setTimeout(()=>acxCodeFocus('cpCode',0),60);
}
async function cpResend(){
  if(_cp.busy || !_cp.phone || Date.now()<_cp.resendAt) return;
  _cp.busy=true;
  const r=await pxAuthApi('phone_change_start',{phone:_cp.phone,password:_cp.password},true);
  _cp.busy=false; cpSync(true);
  if(!r.ok) return cpFail(r,'cpCodeErr');
  cpStartResend(pxSecondsLeft(r.expires_at,300));
  showToast(r.already_sent?'کۆدی پێشوو هێشتا کاردەکات':'کۆدی نوێ نێردرا','success');
}
function cpBack(){
  const keep=_cp.phone;
  clearInterval(_cp.timer); _cp.timer=null; _cp.phone=null; _cp.password='';
  acxErr('cpCodeErr','');
  const input=document.getElementById('cpPhone'); if(input && keep) input.value='0'+keep.slice(4);
  cpShowStep(1); cpSync();
}
async function cpVerify(ev){
  if(ev) ev.preventDefault();
  if(_cp.busy || !_cp.phone) return;
  const code=String(document.getElementById('cpCode').value||'');
  if(code.length!==6) return acxErr('cpCodeErr','کۆدە 6 ژمارەییەکە بنووسە');
  _cp.busy=true; acxBusy('cpVerifyBtn',true);
  const r=await pxAuthApi('phone_change_finish',{phone:_cp.phone,code},true);
  _cp.busy=false; acxBusy('cpVerifyBtn',false); cpSync(true);
  if(!r.ok) return cpFail(r,'cpCodeErr');
  const oldPhone=curProfile && curProfile.phone;
  curProfile=Object.assign({},curProfile||{},{phone:r.phone, phone_verified_at:new Date().toISOString(), phone_changed_at:r.changed_at||new Date().toISOString()});
  if(r.sign_in_changed){
    // a number account now signs in with the new number: keep this device remembered
    try{
      const all=JSON.parse(localStorage.getItem(PX_DEVICE_STORE)||'{}');
      const from=oldPhone && pxIraqiPhone(oldPhone), to=pxIraqiPhone(r.phone);
      if(from && to && all[from]){ all[to]=all[from]; delete all[from]; localStorage.setItem(PX_DEVICE_STORE,JSON.stringify(all)); }
    }catch(_){}
    try{ const {data}=await sb.auth.refreshSession(); if(data?.user) curUser=data.user; }catch(_){}
  }
  applyProfileToUI(); renderAccountMenu();
  if(typeof loadWhatsappSettings==='function') loadWhatsappSettings();
  cpReset();
  showToast(r.sign_in_changed?'ژمارەی مۆبایل گۆڕدرا':'ژمارەی مۆبایل پشتڕاستکرایەوە','success','پشتڕاستکرایەوە');
  navigate('profile');
}

// ── /change-email ─────────────────────────────────────────────
// A verified Gmail address next to the number: sign in (and reset the password)
// with either one, so a lost SIM never locks anyone out. Code by e-mail (n8n).
const _ce={email:null,password:'',busy:false,timer:null,resendAt:0};
function ceShowStep(step){
  const s1=document.getElementById('ceStep1'), s2=document.getElementById('ceStep2');
  if(s1) s1.hidden=step!==1;
  if(s2) s2.hidden=step!==2;
}
function ceReset(){
  ['ceEmail','cePass'].forEach(id=>{ const el=document.getElementById(id); if(el){ el.value=''; if(id==='cePass') el.type='password'; } });
  acxCodeSet('ceCode','');
  document.querySelectorAll('#pageChangeEmail .acx-eye').forEach(b=>b.classList.remove('is-on'));
  acxErr('ceErr',''); acxErr('ceCodeErr','');
  _ce.email=null; _ce.password=''; _ce.busy=false;
  clearInterval(_ce.timer); _ce.timer=null;
  ceShowStep(1);
}
function openChangeEmailScreen(){
  ceReset();
  renderChangeEmailScreen();
  refreshProfileRow().then(()=>{ if(_route==='change-email') renderChangeEmailScreen(); });
}
function renderChangeEmailScreen(){
  const email=curProfile && curProfile.email;
  const box=document.getElementById('ceCurrentBox'); if(box) box.hidden=!email;
  const cur=document.getElementById('ceCurrent'); if(cur) cur.textContent=email||'—';
  const label=document.querySelector('label[for="ceEmail"]');
  if(label) label.textContent=email?'ئیمەیڵی نوێ':'ئیمەیڵ';
  if(!_ce.email) ceShowStep(1);
  ceSync(true);
}
function ceSync(keepError){
  const send=document.getElementById('ceSendBtn');
  if(send) send.disabled=_ce.busy || !pxIsGmail(document.getElementById('ceEmail')?.value) || !document.getElementById('cePass')?.value;
  const verify=document.getElementById('ceVerifyBtn');
  if(verify) verify.disabled=_ce.busy || String(document.getElementById('ceCode')?.value||'').length!==6;
  if(!keepError){ acxErr('ceErr',''); acxErr('ceCodeErr',''); }
}
function ceStartResend(seconds){
  clearInterval(_ce.timer);
  _ce.resendAt=Date.now()+seconds*1000;
  const tick=()=>{
    const b=document.getElementById('ceResend'); if(!b) return;
    const left=Math.ceil((_ce.resendAt-Date.now())/1000);
    if(left<=0){ clearInterval(_ce.timer); _ce.timer=null; b.disabled=false; b.textContent='دووبارە ناردنەوە'; return; }
    b.disabled=true; b.textContent='دووبارە ناردنەوە لە '+acxClock(left);
  };
  tick(); _ce.timer=setInterval(tick,1000);
}
async function ceSend(ev){
  if(ev) ev.preventDefault();
  if(_ce.busy) return;
  const email=String(document.getElementById('ceEmail').value||'').trim().toLowerCase();
  const password=document.getElementById('cePass').value;
  if(!pxIsGmail(email)) return acxErr('ceErr','ئیمەیڵەکە دروست نییە');
  if(!password) return acxErr('ceErr','وشەی نهێنیی ئێستات بنووسە');
  _ce.busy=true; acxBusy('ceSendBtn',true);
  const r=await pxAuthApi('email_change_start',{email,password},true);
  _ce.busy=false; acxBusy('ceSendBtn',false); ceSync(true);
  if(!r.ok) return acxErr('ceErr',pxAuthError(r));
  _ce.email=email; _ce.password=password;
  const target=document.getElementById('ceTarget'); if(target) target.textContent=email;
  acxCodeSet('ceCode','');
  ceShowStep(2); ceStartResend(pxSecondsLeft(r.expires_at,600)); ceSync();
  setTimeout(()=>acxCodeFocus('ceCode',0),60);
}
async function ceResend(){
  if(_ce.busy || !_ce.email || Date.now()<_ce.resendAt) return;
  _ce.busy=true;
  const r=await pxAuthApi('email_change_start',{email:_ce.email,password:_ce.password},true);
  _ce.busy=false; ceSync(true);
  if(!r.ok) return acxErr('ceCodeErr',pxAuthError(r));
  ceStartResend(pxSecondsLeft(r.expires_at,600));
  showToast(r.already_sent?'کۆدی پێشوو هێشتا کاردەکات':'کۆدی نوێ نێردرا','success');
}
function ceBack(){
  const keep=_ce.email;
  clearInterval(_ce.timer); _ce.timer=null; _ce.email=null; _ce.password='';
  acxErr('ceCodeErr','');
  const input=document.getElementById('ceEmail'); if(input && keep) input.value=keep;
  ceShowStep(1); ceSync();
}
async function ceVerify(ev){
  if(ev) ev.preventDefault();
  if(_ce.busy || !_ce.email) return;
  const code=String(document.getElementById('ceCode').value||'');
  if(code.length!==6) return acxErr('ceCodeErr','کۆدە 6 ژمارەییەکە بنووسە');
  _ce.busy=true; acxBusy('ceVerifyBtn',true);
  const r=await pxAuthApi('email_change_finish',{email:_ce.email,code},true);
  _ce.busy=false; acxBusy('ceVerifyBtn',false); ceSync(true);
  if(!r.ok) return acxErr('ceCodeErr',pxAuthError(r));
  const oldEmail=curProfile && curProfile.email;
  curProfile=Object.assign({},curProfile||{},{email:r.email, email_verified_at:new Date().toISOString()});
  if(r.sign_in_changed){
    // an e-mail account now signs in with the new address: keep this device remembered
    try{
      const all=JSON.parse(localStorage.getItem(PX_DEVICE_STORE)||'{}');
      const from=String(oldEmail||'').toLowerCase(), to=String(r.email||'').toLowerCase();
      if(from && to && all[from]){ all[to]=all[from]; delete all[from]; localStorage.setItem(PX_DEVICE_STORE,JSON.stringify(all)); }
    }catch(_){}
    try{ const {data}=await sb.auth.refreshSession(); if(data?.user) curUser=data.user; }catch(_){}
  }
  applyProfileToUI(); renderAccountMenu();
  ceReset();
  showToast(r.sign_in_changed?'ئیمەیڵ گۆڕدرا':'ئیمەیڵ زیاد کرا','success','پشتڕاستکرایەوە');
  navigate('profile');
}

// ── /change-password ──────────────────────────────────────────
let _pwBusy=false;
function pwReset(){
  ['pwCurrent','pwNew','pwNew2'].forEach(id=>{ const el=document.getElementById(id); if(el){ el.value=''; el.type='password'; } });
  document.querySelectorAll('#pageChangePassword .acx-eye').forEach(b=>b.classList.remove('is-on'));
  acxErr('pwErr','');
}
function openPasswordScreen(){ pwReset(); pwSync(); }
function pwSync(keepError){
  const cur=document.getElementById('pwCurrent')?.value||'', nw=document.getElementById('pwNew')?.value||'', nw2=document.getElementById('pwNew2')?.value||'';
  const b=document.getElementById('pwBtn'); if(b) b.disabled=_pwBusy || !cur || nw.length<8 || !nw2;
  if(!keepError) acxErr('pwErr','');
}
async function submitPasswordChange(ev){
  if(ev) ev.preventDefault();
  if(_pwBusy || !curUser) return;
  const current=document.getElementById('pwCurrent').value, password=document.getElementById('pwNew').value, again=document.getElementById('pwNew2').value;
  if(!current) return acxErr('pwErr','وشەی نهێنیی ئێستات بنووسە');
  if(password.length<8) return acxErr('pwErr','وشەی نهێنیی نوێ دەبێت لانیکەم 8 پیت بێت');
  if(password!==again) return acxErr('pwErr','دوو وشە نهێنییە نوێیەکە وەک یەک نین');
  if(password===current) return acxErr('pwErr','وشەی نهێنیی نوێ دەبێت جیاواز بێت لە وشەی نهێنیی ئێستا');
  _pwBusy=true; acxBusy('pwBtn',true);
  const r=await pxAuthApi('password_change',{current,password},true);
  if(r.ok && r.session){
    try{ await sb.auth.setSession({access_token:r.session.access_token,refresh_token:r.session.refresh_token}); }catch(_){}
  }
  _pwBusy=false; acxBusy('pwBtn',false); pwSync(true);
  if(!r.ok) return acxErr('pwErr',pxAuthError(r));
  pwReset();
  showToast('وشەی نهێنی گۆڕدرا','success','گۆڕدرا');
  navigate('profile');
}

function applyProfileToUI(){
  const name = (curProfile && curProfile.full_name) || pxAccountLabel() || '';
  const nameEl=document.getElementById('userName'); if(nameEl) nameEl.innerText=name;
  setAvatar(document.getElementById('greetAvatar'), name);
  setAvatar(document.getElementById('pfAvatar'), name);
  renderUsernameRow();
  const pfName=document.getElementById('pfNameLbl'); if(pfName) pfName.textContent=name||'—';
  const pfMail=document.getElementById('pfEmailLbl'); if(pfMail) pfMail.textContent=pxAccountLabel()||'—';
  syncSenderIdentity();
  // creation date: a row of the account list, like the phone number (2026/01/02)
  const joined=document.getElementById('pfJoined');
  if(joined && curProfile && curProfile.created_at){
    const d=new Date(curProfile.created_at);
    if(!isNaN(d)) joined.textContent=d.getFullYear()+'/'+String(d.getMonth()+1).padStart(2,'0')+'/'+String(d.getDate()).padStart(2,'0');
  }
  const adminChip=document.getElementById('pfAdminChip');
  if(adminChip) adminChip.style.display = (curProfile && curProfile.is_admin) ? 'inline-flex' : 'none';
  const adminChipText=document.getElementById('pfAdminChipText');
  if(adminChipText) adminChipText.textContent = (curProfile && curProfile.role==='super_admin') ? 'بەڕێوەبەری باڵا' : 'بەڕێوەبەر';
}

// Profile photo when the account has one (e.g. OAuth metadata); otherwise the
// initial letter. The image never replaces the node, so the initial is the fallback.
function profilePhotoUrl(){
  const meta=(curUser && curUser.user_metadata) || {};
  const url=String(meta.avatar_url || meta.picture || '').trim();
  return /^https:\/\//i.test(url) ? url : '';
}
function setAvatar(el, name){
  if(!el) return;
  const url=profilePhotoUrl();
  el.textContent=initialOf(name);
  el.classList.remove('has-photo');
  if(!url) return;
  const img=new Image();
  img.alt=''; img.decoding='async'; img.referrerPolicy='no-referrer';
  img.onload=()=>{ el.textContent=''; el.appendChild(img); el.classList.add('has-photo'); };
  img.src=url;
}
function copyUsername(btn){
  const u=curProfile && curProfile.username;
  if(!u) return;
  if(btn && btn.classList.contains('pfx-item-copy')){
    // the row's copy button is an icon: it turns into a tick for a moment
    copyText('@'+u).then(ok=>{
      if(!ok) return showToast('نەتوانرا کۆپی بکرێت','error');
      if(btn._copyTimer) clearTimeout(btn._copyTimer); else btn._copyHTML=btn.innerHTML;
      btn.classList.add('is-copied');
      btn.innerHTML='<svg class="pxi" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M20 6 9 17l-5-5"/></svg>';
      btn._copyTimer=setTimeout(()=>{ btn.innerHTML=btn._copyHTML; btn.classList.remove('is-copied'); btn._copyTimer=null; },1600);
    });
    return;
  }
  copyWithFeedback('@'+u, btn);
}
function usernameEditable(){ return !!(curProfile && curProfile.username && !curProfile.username_changed_at); }
// username: a row of the account list, like the phone number; "گۆڕین" while it can still be changed once
function renderUsernameRow(){
  const v=document.getElementById('pfMenuUsername');
  if(!v) return;
  v.textContent='';
  const u=curProfile && curProfile.username;
  const at=document.createElement('span'); at.dir='ltr'; at.textContent=u ? '@'+u : '—'; v.appendChild(at);
  if(usernameEditable()){
    const tag=document.createElement('span'); tag.className='acx-edit-tag'; tag.textContent='گۆڕین';
    v.appendChild(document.createTextNode(' ')); v.appendChild(tag);
  }
  const copy=document.getElementById('pfUsernameCopy');
  if(copy) copy.hidden=!u;
}
function usernameRowTap(){
  if(usernameEditable()) return openUsernameSheet();
  copyUsername(document.getElementById('pfUsernameCopy'));
}

/* ── Username change: allowed once per account (enforced by ex_change_username in the database) ── */
const UN_RE=/^[a-z][a-z0-9_]{2,19}$/;
const UN_RESERVED=/^(admin|support|staff|proxo|root|system|moderator|official)/;
const UN_ERRORS={
  USERNAME_ALREADY_CHANGED:'ناوی بەکارهێنەرەکەت پێشتر گۆڕدراوە و جارێکی تر ناگۆڕدرێت.',
  USERNAME_INVALID:'ناوەکە دروست نییە. 3 بۆ 20 پیت، بە پیتی ئینگلیزی دەست پێ بکات و تەنها a-z، 0-9 و _ بێت.',
  USERNAME_RESERVED:'ئەم ناوە پارێزراوە؛ ناوێکی تر هەڵبژێرە.',
  USERNAME_UNCHANGED:'ئەمە هەمان ناوی ئێستای تۆیە.',
  USERNAME_TAKEN:'ئەم ناوە پێشتر بەکارهێنراوە؛ ناوێکی تر تاقی بکەرەوە.',
  ACCOUNT_BANNED:'ئەم هەژمارە ناتوانێت ئەم کردارە ئەنجام بدات.',
  AUTH_REQUIRED:'تکایە دووبارە بچۆ ژوورەوە.',
  PROFILE_NOT_FOUND:'پڕۆفایلەکە نەدۆزرایەوە.'
};
let _unBusy=false;
function usernameValue(){ const el=document.getElementById('unInput'); return el ? String(el.value||'').trim().toLowerCase() : ''; }
function usernameValidate(){
  const el=document.getElementById('unInput'); if(!el) return false;
  const raw=el.value, v=raw.trim().toLowerCase();
  const rules={
    len:v.length>=3 && v.length<=20,
    start:/^[a-z]/.test(v),
    chars:v.length>0 && /^[a-z0-9_]+$/.test(v)
  };
  document.querySelectorAll('#unRules li').forEach(li=>{
    const ok=rules[li.dataset.rule];
    li.classList.toggle('is-ok', !!ok && v.length>0);
    li.classList.toggle('is-bad', !ok && v.length>0);
  });
  const same=!!(curProfile && v===curProfile.username);
  const reserved=UN_RESERVED.test(v);
  const err=document.getElementById('unError');
  if(err){
    err.textContent = (v && UN_RE.test(v) && same) ? UN_ERRORS.USERNAME_UNCHANGED : (v && UN_RE.test(v) && reserved) ? UN_ERRORS.USERNAME_RESERVED : '';
    err.classList.toggle('show', !!err.textContent);
  }
  const field=document.getElementById('unField'); if(field) field.classList.toggle('is-bad', !!(err && err.textContent));
  const valid=UN_RE.test(v) && !same && !reserved;
  const confirmed=!!(document.getElementById('unConfirm') && document.getElementById('unConfirm').checked);
  const btn=document.getElementById('unSubmit'); if(btn) btn.disabled=!(valid && confirmed) || _unBusy;
  return valid;
}
function openUsernameSheet(){
  const sheet=document.getElementById('usernameSheet');
  if(!sheet || !curProfile || curProfile.username_changed_at) return;
  const cur=document.getElementById('unCurrent'); if(cur) cur.textContent='@'+(curProfile.username||'—');
  const input=document.getElementById('unInput'); if(input) input.value='';
  const ok=document.getElementById('unConfirm'); if(ok) ok.checked=false;
  const err=document.getElementById('unError'); if(err){ err.textContent=''; err.classList.remove('show'); }
  usernameValidate();
  openSheet(sheet);
  setTimeout(()=>{ try{ input && input.focus({preventScroll:true}); }catch(_){} }, 320);
}
function closeUsernameSheet(){
  const sheet=document.getElementById('usernameSheet');
  if(sheet && sheet.classList.contains('open')) closeSheet(sheet);
}
async function submitUsernameChange(ev){
  if(ev) ev.preventDefault();
  if(_unBusy || !usernameValidate()) return;
  const v=usernameValue(), btn=document.getElementById('unSubmit'), err=document.getElementById('unError');
  _unBusy=true;
  if(btn){ btn.disabled=true; btn.classList.add('is-busy'); btn.textContent='کەمێک چاوەڕێ بکە...'; }
  try{
    const {data,error}=await sb.rpc('ex_change_username',{p_username:v});
    if(error) throw error;
    const saved=(data && data.username) || v;
    curProfile.username=saved;
    curProfile.username_changed_at=(data && data.changed_at) || new Date().toISOString();
    applyProfileToUI();
    closeUsernameSheet();
    showToast('ناوی بەکارهێنەرەکەت بوو بە @'+saved,'success','گۆڕدرا');
  }catch(e){
    const msg=String((e && (e.message||e.details))||'');
    const code=Object.keys(UN_ERRORS).find(k=>msg.includes(k));
    if(code==='USERNAME_ALREADY_CHANGED' && curProfile){
      curProfile.username_changed_at=curProfile.username_changed_at||new Date().toISOString();
      applyProfileToUI();
    }
    if(err){ err.textContent=code ? UN_ERRORS[code] : 'گۆڕینەکە سەرنەکەوت. دووبارە هەوڵ بدەرەوە.'; err.classList.add('show'); }
    const field=document.getElementById('unField'); if(field) field.classList.add('is-bad');
  }finally{
    _unBusy=false;
    if(btn){ btn.classList.remove('is-busy'); btn.textContent='گۆڕینی ناوی بەکارهێنەر'; }
    usernameValidate();
  }
}


// ═══ CUSTOMER SUPPORT CASES ═══════════════════════════════════
// Images live in a private bucket. The user's JWT and Storage RLS restrict
// both upload and signed-URL creation to this user's own folder.
// ══════════════════════════════════════════════════════════════
const SUPPORT_IMAGE_MAX_BYTES=5*1024*1024;
const SUPPORT_IMAGE_TYPES=new Set(['image/jpeg','image/png','image/webp']);
let _supportImageSnapshot=null;
let _supportImagePromise=null;
let _supportImageToken=0;
let _supportPreviewUrl=null;
let _supportCases=[];

function supportCategoryLabel(category){
  return category==='order'?'کێشەی داواکاری':category==='payment'?'کێشەی پارەدان':category==='account'?'کێشەی هەژمار':category==='technical'?'کێشەی تەکنیکی':'کێشەی تر';
}
function supportStatusLabel(status){
  return status==='open'?'نێردراوە':status==='in_progress'?'لەژێر پشکنینە':status==='resolved'?'چارەسەرکرا':'داخراوە';
}
function supportStatusClass(status){
  return status==='resolved'?'resolved':status==='closed'?'closed':status==='in_progress'?'progress':'open';
}
function supportCaseNumber(row){
  const value=Number(row?.case_number);
  return Number.isInteger(value) ? String(value).padStart(6,'0') : '—';
}

// category chips mirror the (hidden) #supportCategory select, which stays the source of the value
function syncSupportCategoryChips(){
  const sel=document.getElementById('supportCategory'); const value=sel?sel.value:'order';
  document.querySelectorAll('#supportCategoryChips .sc-cat').forEach(b=>{
    const on=b.dataset.value===value; b.classList.toggle('is-on',on); b.setAttribute('aria-checked',on?'true':'false');
  });
}
function setSupportCategory(value){
  const sel=document.getElementById('supportCategory'); if(!sel) return;
  sel.value=value; syncSupportCategoryChips();
}
const SC_ICO={
  order:'<path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z"/><path d="M14 8H8"/><path d="M16 12H8"/>',
  payment:'<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',
  account:'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  technical:'<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
  general:'<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>',
  reply:'<path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"/>',
  image:'<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.09-3.09a2 2 0 0 0-2.82 0L6 21"/>',
  alert:'<circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>'
};
function scIcon(key){ return '<svg class="pxi" viewBox="0 0 24 24" aria-hidden="true" focusable="false">'+(SC_ICO[key]||SC_ICO.general)+'</svg>'; }
function supportEmptyHTML(title,sub,icon){
  return '<div class="sc-empty"><span class="sc-tile">'+scIcon(icon||'general')+'</span><b>'+title+'</b>'+(sub?'<small>'+sub+'</small>':'')+'</div>';
}
function setSupportCasesCount(n){
  const c=document.getElementById('supportCasesCount'); if(!c) return;
  c.textContent=String(n); c.hidden=!n;
}

function updateSupportDescriptionCount(){
  const input=document.getElementById('supportDescription');
  const count=document.getElementById('supportDescriptionCount');
  if(count){ const n=(input?.value||'').length; count.textContent=n+' / 2000'; count.classList.toggle('is-near',n>=1800); }
  if((input?.value||'').trim().length>=10) clearFieldError('supportDescription');
}

function clearSupportImagePreview(){
  if(_supportPreviewUrl){ URL.revokeObjectURL(_supportPreviewUrl); _supportPreviewUrl=null; }
  const preview=document.getElementById('supportImagePreview');
  const image=document.getElementById('supportImagePreviewImg');
  if(preview) preview.style.display='none';
  if(image) image.removeAttribute('src');
}

function removeSupportImage(){
  _supportImageToken++;
  _supportImageSnapshot=null;
  _supportImagePromise=null;
  const input=document.getElementById('supportImageInput'); if(input) input.value='';
  const name=document.getElementById('supportImageName'); if(name) name.textContent='وێنە هەڵبژێرە';
  const meta=document.getElementById('supportImageMeta'); if(meta) meta.textContent='JPG، PNG یان WEBP';
  const picker=document.getElementById('supportImagePicker'); if(picker) picker.classList.remove('selected');
  clearSupportImagePreview();
  clearFieldError('supportImage');
}

function onSupportImageSelected(input){
  clearFieldError('supportImage');
  const file=input?.files?.[0]||null;
  if(!file){ removeSupportImage(); return; }
  if(!SUPPORT_IMAGE_TYPES.has(file.type)){
    removeSupportImage();
    setFieldError('supportImage','تەنها JPG، PNG یان WEBP قبوڵ دەکرێت');
    return;
  }
  if(file.size>SUPPORT_IMAGE_MAX_BYTES){
    removeSupportImage();
    setFieldError('supportImage','قەبارەی وێنە نابێت لە 5MB زیاتر بێت');
    return;
  }
  const token=++_supportImageToken;
  _supportImageSnapshot=null;
  const name=document.getElementById('supportImageName'); if(name) name.textContent=file.name;
  const meta=document.getElementById('supportImageMeta'); if(meta) meta.textContent='ئامادەکردنی وێنە...';
  const picker=document.getElementById('supportImagePicker'); if(picker) picker.classList.add('selected');
  clearSupportImagePreview();
  _supportImagePromise=readSelectedFileSnapshot(file).then(snapshot=>{
    if(token!==_supportImageToken) return null;
    _supportImageSnapshot=snapshot;
    if(meta) meta.textContent=(snapshot.size/1024/1024).toFixed(2)+' MB';
    _supportPreviewUrl=URL.createObjectURL(new Blob([snapshot.bytes],{type:snapshot.type}));
    const preview=document.getElementById('supportImagePreview');
    const image=document.getElementById('supportImagePreviewImg');
    if(image) image.src=_supportPreviewUrl;
    if(preview) preview.style.display='block';
    return snapshot;
  }).catch(()=>{
    if(token===_supportImageToken){
      _supportImageSnapshot=null;
      if(input) input.value='';
      if(picker) picker.classList.remove('selected');
      if(name) name.textContent='وێنە دووبارە هەڵبژێرە';
      if(meta) meta.textContent='دەستگەیشتن بە وێنەکە نەکرا';
      setFieldError('supportImage','نەتوانرا وێنەکە بخوێندرێتەوە؛ تکایە دووبارە هەڵیبژێرە');
    }
    return null;
  });
}

function supportImageExtension(type){
  return type==='image/png'?'png':type==='image/webp'?'webp':'jpg';
}

function openSupportImageById(id){
  const row=_supportCases.find(item=>String(item.id)===String(id));
  if(!row?.image_url){ showToast('وێنەکە بەردەست نییە','error'); return; }
  const modal=document.getElementById('supportImageModal');
  const image=document.getElementById('supportImageModalImg');
  if(!modal || !image) return;
  image.src=row.image_url;
  modal.style.display='flex';
  document.body.style.overflow='hidden';
}

function closeSupportImage(){
  const modal=document.getElementById('supportImageModal');
  const image=document.getElementById('supportImageModalImg');
  if(modal) modal.style.display='none';
  if(image) image.removeAttribute('src');
  const correction=document.getElementById('orderCorrectionModal');
  document.body.style.overflow=correction?.style.display==='flex'?'hidden':'';
}

async function submitSupportCase(){
  if(!curUser || !activeSession?.access_token){ showToast('تکایە دووبارە بچۆ ژوورەوە','error'); return; }
  const category=document.getElementById('supportCategory')?.value||'general';
  const orderCode=(document.getElementById('supportOrderCode')?.value||'').trim().toUpperCase();
  const description=(document.getElementById('supportDescription')?.value||'').trim();
  clearFieldError('supportDescription'); clearFieldError('supportImage');
  if(description.length<10){ setFieldError('supportDescription','تکایە کێشەکە بە لانیکەم 10 پیت ڕوون بکەرەوە'); return; }
  if(orderCode && !/^P[A-Z0-9]{11}$/.test(orderCode)){
    showToast('ئایدی مامەڵە دەبێت بە P دەست پێبکات و 12 پیت بێت','error');
    return;
  }

  const btn=document.getElementById('supportSubmitBtn');
  const defaultButton=btn.innerHTML;
  btn.disabled=true; btn.innerHTML=ICON.spin+' ناردن...';
  let imagePath=null;
  let supportStage='case_create';
  try{
    if(_supportImageSnapshot || _supportImagePromise){
      supportStage='image_read';
      const supportImage=_supportImageSnapshot || await _supportImagePromise;
      if(!supportImage) throw new Error('FILE_READ_PERMISSION');
      supportStage='image_upload';
      const unique=(globalThis.crypto?.randomUUID?.()||String(Date.now())+'-'+Math.random().toString(16).slice(2));
      imagePath=curUser.id+'/'+unique+'.'+supportImageExtension(supportImage.type);
      const {error:uploadError}=await sb.storage.from('support-case-images').upload(imagePath,supportImage.bytes,{
        cacheControl:'3600', contentType:supportImage.type, upsert:false
      });
      if(uploadError){
        const err=new Error(uploadError.message||'Support image upload failed'); err.code='SUPPORT_IMAGE_UPLOAD';
        throw err;
      }
    }

    supportStage='case_create';
    const response=await fetch('/api/support-cases',{
      method:'POST',
      headers:{'Content-Type':'application/json','Authorization':'Bearer '+activeSession.access_token},
      body:JSON.stringify({category,order_code:orderCode||null,description,image_path:imagePath})
    });
    let payload={}; try{ payload=await response.json(); }catch(_){}
    if(!response.ok || !payload.ok){
      const err=new Error(payload.error||'Support case submission failed');
      err.status=response.status; err.code='SUPPORT_CASE_HTTP_'+response.status;
      throw err;
    }

    const row=payload.case||{};
    const success=document.getElementById('supportSuccess');
    const number=document.getElementById('supportSuccessNumber');
    if(number) number.textContent=supportCaseNumber(row);
    if(success) success.style.display='flex';
    document.getElementById('supportDescription').value='';
    document.getElementById('supportOrderCode').value='';
    document.getElementById('supportCategory').value='order';
    syncSupportCategoryChips();
    updateSupportDescriptionCount();
    removeSupportImage();
    showToast('کەیسەکەت بە سەرکەوتوویی نێردرا','success');
    await loadSupportCases();
  }catch(e){
    reportAppError(e,{operation:'support_case_submission',stage:supportStage,file_size:_supportImageSnapshot?.size,file_type:_supportImageSnapshot?.type,filename:_supportImageSnapshot?.name});
    const msg=e?.status===429?'لە کاتژمێرێکدا زۆر کەیست ناردووە؛ تکایە دواتر هەوڵبدەوە'
      :e?.status===409?'تکایە چاوەڕێی وەڵامی کەیسە کراوەکانت بکە'
      :e?.message==='FILE_READ_PERMISSION'?kuErr('FILE_READ_PERMISSION')
      :e?.code==='SUPPORT_IMAGE_UPLOAD'?'وێنەکە بارنەکرا؛ تکایە دووبارە هەوڵبدەوە'
      :'نەتوانرا کەیسەکە بنێردرێت؛ تکایە دووبارە هەوڵبدەوە';
    showToast(msg,'error');
  }finally{
    btn.disabled=false; btn.innerHTML=defaultButton;
  }
}

async function loadSupportCases(){
  const list=document.getElementById('supportCasesList');
  if(!list || !curUser) return;
  if(!list.querySelector('.sc-case:not(.is-skel)')) list.innerHTML=window.PXS?PXS.supportCases(2):'';
  try{
    const {data,error}=await sb.from('ex_support_cases')
      .select('id,case_number,category,order_code,description,image_path,status,admin_note,created_at,updated_at')
      .eq('user_id',curUser.id).order('created_at',{ascending:false}).limit(50);
    if(error) throw error;
    _supportCases=await Promise.all((data||[]).map(async row=>{
      if(!row.image_path) return {...row,image_url:null};
      const {data:signed}=await sb.storage.from('support-case-images').createSignedUrl(row.image_path,600);
      return {...row,image_url:signed?.signedUrl||null};
    }));
    renderSupportCases();
  }catch(e){
    list.innerHTML=supportEmptyHTML('نەتوانرا کەیسەکان باربکرێن','پەیوەندی ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵ بدەرەوە.','alert');
    setSupportCasesCount(0);
    reportAppError(e,{operation:'support_cases_load',stage:'case_list'});
  }
}

function renderSupportCases(){
  const list=document.getElementById('supportCasesList'); if(!list) return;
  setSupportCasesCount(_supportCases.length);
  if(!_supportCases.length){ list.innerHTML=supportEmptyHTML('هێشتا هیچ کەیسێکت نییە','ئەگەر کێشەیەکت هەبوو، لە سەرەوە کەیسێک بنێرە.'); return; }
  list.innerHTML=_supportCases.map(row=>{
    const cat=['order','payment','account','technical'].includes(row.category)?row.category:'general';
    return `<article class="support-case-card sc-case is-${supportStatusClass(row.status)}">
    <div class="sc-case-head">
      <span class="sc-tile sc-case-ico">${scIcon(cat)}</span>
      <div class="sc-case-id"><b>کەیسی <span dir="ltr">#${escHtml(supportCaseNumber(row))}</span></b><small>${escHtml(supportCategoryLabel(row.category))} · ${escHtml(timeAgo(row.created_at))}</small></div>
      <span class="sc-status"><i aria-hidden="true"></i>${escHtml(supportStatusLabel(row.status))}</span>
    </div>
    <p class="sc-case-desc">${escHtml(row.description)}</p>
    ${(row.order_code||row.image_url)?`<div class="sc-case-meta">
      ${row.order_code?`<span class="sc-chip">ئایدی مامەڵە <b dir="ltr">${escHtml(row.order_code)}</b></span>`:''}
      ${row.image_url?`<button type="button" class="sc-chip sc-chip-img" onclick="openSupportImageById('${escHtml(row.id)}')"><img src="${escHtml(row.image_url)}" alt="">بینینی وێنە</button>`:''}
    </div>`:''}
    ${row.admin_note?`<div class="sc-reply"><span class="sc-reply-ico">${scIcon('reply')}</span><div><b>وەڵامی پشتگیری</b><p>${escHtml(row.admin_note)}</p></div></div>`:''}
  </article>`;}).join('');
}

// ══════════════════════════════════════════════════════════════
// ═══ IDENTITY VERIFICATION (KYC) ══════════════════════════════
// Status comes from the ex_kyc_my_status RPC. Images go to the private
// "identity-documents" bucket under {user_id}/{verification_id}/, and the
// ex_kyc_submit RPC only accepts a submission once both files exist in
// Storage. Status changes (approve / reject) are made by admins only —
// the browser has no write access to the verification tables.
// ══════════════════════════════════════════════════════════════
// Customers may start verification without an admin request.
const KYC_SELF_START_ENABLED = true;
const KYC_BUCKET = 'identity-documents';
const KYC_MAX_INPUT_BYTES = 15*1024*1024;   // raw file from the phone
const KYC_MAX_UPLOAD_BYTES = 10*1024*1024;  // bucket limit
const KYC_MAX_IMAGE_SIDE = 2200;            // px — re-encoded above this
// Local clarity check (Canvas only — nothing leaves the device before it passes).
const KYC_MIN_SHORT_SIDE = 480;             // px — below this a card is unreadable
const KYC_MIN_LONG_SIDE = 640;
const KYC_ANALYSIS_SIDE = 640;              // temporary downscaled copy for analysis
// Calibrated on 193 synthetic ID-card photos (12 MP → 0.3 MP, dim/bright,
// WhatsApp-compressed, Gaussian blur, horizontal/vertical/diagonal shake):
// every readable photo scored ≥ 120, every unreadable one ≤ 51.
const KYC_MIN_SHARPNESS = 55;               // weakest-direction 2nd-derivative variance
const KYC_MIN_CONTRAST = 6;                 // luminance std-dev; below = blank/black frame
const KYC_UNCLEAR_MSG = 'وێنەکە ناڕوونە، تکایە وێنەیەکی ڕوونتر بگرە.';
const KYC_DOC_TYPES = {
  national_id:     { label:'کارتی نیشتیمانی', numberLabel:'ژمارەی کارتی نیشتیمانی', numberHint:'A12345678', front:'ڕووی پێشەوەی کارت', back:'ڕووی دواوەی کارت', needsBack:true },
  driving_license: { label:'مۆڵەتی شوفێری', numberLabel:'ژمارەی مۆڵەت', numberHint:'DL-123456', front:'ڕووی پێشەوەی مۆڵەت', back:'ڕووی دواوەی مۆڵەت', needsBack:true }
};
const KYC_STATES = {
  loading:  { label:'دۆخی ناسنامە...',                       icon:'refresh-linear',        spin:true },
  error:    { label:'دۆخی ناسنامە بەردەست نییە',            icon:'danger-triangle-linear' },
  none:     { label:'پشتڕاست نەکراوەتەوە',                    icon:'shield-linear' },
  required: { label:'پشتڕاستکردنەوەی ناسنامە پێویستە',         icon:'shield-warning-linear' },
  pending:  { label:'لە ژێر پشکنینە',                          icon:'clock-circle-linear' },
  approved: { label:'پشتڕاستکراوەتەوە',              icon:'verified-check-linear' },
  rejected: { label:'پێویستی بە دووبارە ناردنەوە هەیە',        icon:'shield-cross-linear' }
};
const KYC_ERRORS = {
  AUTH_REQUIRED:'تکایە دووبارە بچۆ ژوورەوە',
  ACCOUNT_BANNED:'ئەم هەژمارە بۆیکۆتکراوە',
  PROFILE_NOT_FOUND:'پڕۆفایلەکەت نەدۆزرایەوە؛ پەڕەکە نوێ بکەرەوە',
  KYC_ALREADY_PENDING:'داواکارییەکی تۆ پێشتر نێردراوە و لە ژێر پشکنینە',
  KYC_ALREADY_APPROVED:'ناسنامەکەت پێشتر پشتڕاستکراوەتەوە',
  KYC_DUPLICATE_SUBMISSION:'ئەم داواکارییە پێشتر نێردراوە',
  KYC_RATE_LIMIT:'لە 24 کاتژمێردا زۆر داواکاریت ناردووە؛ تکایە دواتر هەوڵبدەوە',
  KYC_DOCUMENT_TYPE_INVALID:'جۆری بەڵگەنامە هەڵبژێرە',
  KYC_NAME_INVALID:'ناوی تەواو بە لانیکەم دوو بەش و بەبێ ژمارە یان هێما بنووسە',
  KYC_DOB_INVALID:'بەرواری لەدایکبوون دروست نییە',
  KYC_NUMBER_INVALID:'ژمارەی بەڵگەنامە دەبێت 4 بۆ 30 پیت/ژمارەی ئینگلیزی بێت',
  KYC_FRONT_PATH_INVALID:'وێنەی ڕووی پێشەوە دروست نییە؛ دووبارە هەڵیبژێرە',
  KYC_BACK_PATH_INVALID:'وێنەی ڕووی دواوە دروست نییە؛ دووبارە هەڵیبژێرە',
  KYC_BACK_REQUIRED:'وێنەی ڕووی دواوەی بەڵگەنامە پێویستە',
  KYC_FRONT_IMAGE_MISSING:'وێنەی ڕووی پێشەوە بارنەکرابوو؛ تکایە دووبارە هەوڵبدەوە',
  KYC_BACK_IMAGE_MISSING:'وێنەی ڕووی دواوە بارنەکرابوو؛ تکایە دووبارە هەوڵبدەوە',
  KYC_UPLOAD_FAILED:'وێنەکە بارنەکرا؛ هیچ داواکارییەک نەنێردرا. تکایە دووبارە هەوڵبدەوە',
  KYC_UPLOAD_NETWORK:'بەهۆی کێشەی تۆڕەوە وێنەکە بارنەکرا؛ پەیوەندییەکەت بپشکنە و دووبارە هەوڵبدەوە',
  KYC_IMAGE_DECODE:'ئەم فایلە وەک وێنە ناخوێندرێتەوە؛ وێنەیەکی تر هەڵبژێرە',
  KYC_IMAGE_TOO_SMALL:KYC_UNCLEAR_MSG,
  KYC_IMAGE_BLURRY:KYC_UNCLEAR_MSG,
  KYC_IMAGE_TOO_LARGE:'قەبارەی وێنەکە زۆر گەورەیە (زیاتر لە 10MB)',
  KYC_IMAGE_TYPE:'تکایە تەنها وێنە هەڵبژێرە (بە کامێرا یان لە گەلەری)',
  KYC_IMAGE_ENCODE:'نەتوانرا وێنەکە ئامادە بکرێت؛ تکایە وێنەیەکی تر بگرە',
  FILE_READ_PERMISSION:'براوزەر نەتوانی وێنەکە بخوێنێتەوە؛ تکایە دووبارە هەڵیبژێرە'
};

let _kyc = { status:'loading', data:null, loadedAt:0 };
let _kycLoadPromise = null;
let _kycDocType = null;
let _kycDraftId = null;          // one storage folder per attempt; reused on retry
let _kycSubmitting = false;
let _kycPrefilledFor = null;
const _kycImages = { front:null, back:null };   // { prepared, url, name, promise, token }
const _kycImageTokens = { front:0, back:0 };

function kycErrorMessage(error){
  const raw=String(error?.message||error?.code||error||'');
  const code=Object.keys(KYC_ERRORS).find(k=>raw.includes(k));
  if(code) return KYC_ERRORS[code];
  if(/row-level security|violates|unauthorized|403/i.test(raw)) return 'مۆڵەتی ناردنی ئەم وێنەیە نییە؛ پەڕەکە نوێ بکەرەوە و دووبارە هەوڵبدەوە';
  if(/mime|content type|invalid_mime/i.test(raw)) return KYC_ERRORS.KYC_IMAGE_TYPE;
  if(/payload too large|maximum allowed size|413/i.test(raw)) return KYC_ERRORS.KYC_IMAGE_TOO_LARGE;
  const translated=kuErr(raw);
  return translated && translated!==raw ? translated : 'هەڵەیەک ڕوویدا؛ تکایە دووبارە هەوڵبدەوە';
}

function kycUuid(){
  if(globalThis.crypto?.randomUUID) return crypto.randomUUID();
  const b=new Uint8Array(16); crypto.getRandomValues(b);
  b[6]=(b[6]&0x0f)|0x40; b[8]=(b[8]&0x3f)|0x80;
  const h=[...b].map(x=>x.toString(16).padStart(2,'0')).join('');
  return h.slice(0,8)+'-'+h.slice(8,12)+'-'+h.slice(12,16)+'-'+h.slice(16,20)+'-'+h.slice(20);
}

// Browsers ship no Sorani month names for 'ku-IQ' (Chrome prints "M09"),
// so dates are composed explicitly.
const KU_MONTHS=['کانوونی دووەم','شوبات','ئازار','نیسان','ئایار','حوزەیران','تەممووز','ئاب','ئەیلوول','تشرینی یەکەم','تشرینی دووەم','کانوونی یەکەم'];
function kycFmtDate(iso, withTime){
  if(!iso) return '—';
  const d=new Date(iso); if(isNaN(d)) return '—';
  const date=d.getDate()+'ی '+KU_MONTHS[d.getMonth()]+' '+d.getFullYear();
  if(!withTime) return date;
  return date+' — '+String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0');
}
function kycSolar(name, extra){
  return '<span class="icn '+(extra||'')+' icon--solar icon--solar--'+name+'" aria-hidden="true"></span>';
}

/* One badge system for every verification state: a shield with a mark.
   ok ✓ verified · warn ! not verified / required · wait ◔ under review · bad ✕ rejected · idle – unknown */
// the verification badge: a rosette (blue with a tick when verified; the other states share its shape)
const KYC_SHIELD_PATH='M12 0.9 12.9 1.3 13.8 2.1 14.4 3 15 3.7 15.7 4 16.7 3.9 17.8 3.7 18.9 3.7 19.8 4.2 20.3 5.1 20.3 6.2 20.1 7.3 20 8.3 20.3 9 21 9.6 21.9 10.2 22.7 11.1 23.1 12 22.7 12.9 21.9 13.8 21 14.4 20.3 15 20 15.7 20.1 16.7 20.3 17.8 20.3 18.9 19.8 19.8 18.9 20.3 17.8 20.3 16.7 20.1 15.7 20 15 20.3 14.4 21 13.8 21.9 12.9 22.7 12 23.1 11.1 22.7 10.2 21.9 9.6 21 9 20.3 8.3 20 7.3 20.1 6.2 20.3 5.1 20.3 4.2 19.8 3.7 18.9 3.7 17.8 3.9 16.7 4 15.7 3.7 15 3 14.4 2.1 13.8 1.3 12.9 0.9 12 1.3 11.1 2.1 10.2 3 9.6 3.7 9 4 8.3 3.9 7.3 3.7 6.2 3.7 5.1 4.2 4.2 5.1 3.7 6.2 3.7 7.3 3.9 8.3 4 9 3.7 9.6 3 10.2 2.1 11.1 1.3Z';
const KYC_GLYPH={ ok:'M8.2 12.3l2.6 2.6 5-5.4', warn:'M12 7.6v5M12 16.2h.01', wait:'M12 7.6v4.6l3 1.8', bad:'M9.3 9.3l5.4 5.4M14.7 9.3l-5.4 5.4', idle:'M9 12h6' };
function kycTone(status){
  return status==='approved' ? 'ok'
    : (status==='none'||status==='required') ? 'warn'
    : status==='pending' ? 'wait'
    : status==='rejected' ? 'bad' : 'idle';
}
function kycBadgeSvg(status){
  return '<svg class="kyc-shield" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path class="ks-bg" d="'+KYC_SHIELD_PATH+'"/><path class="ks-glyph" d="'+KYC_GLYPH[kycTone(status)]+'"/></svg>';
}
function kycIco(status, cls){
  return '<span class="kyc-ico'+(cls?' '+cls:'')+'" data-tone="'+kycTone(status)+'">'+kycBadgeSvg(status)+'</span>';
}

async function loadKycStatus(silent){
  if(!sb || !curUser) return null;
  if(_kycLoadPromise) return _kycLoadPromise;
  if(!silent || !_kyc.data){ _kyc.status=_kyc.data?_kyc.status:'loading'; renderKycProfile(); }
  _kycLoadPromise=(async()=>{
    try{
      const {data,error}=await sb.rpc('ex_kyc_my_status');
      if(error) throw error;
      const info=data||{};
      // Fallback for a site deployed before the database migration: derive the
      // exchange gate and the name lock from the data we already have, using
      // the same rule as the database (an active admin request blocks).
      if(typeof info.exchange_blocked!=='boolean'){
        info.exchange_blocked=!!(info.request && (info.request.status==='open' || info.request.status==='submitted'));
      }
      if(typeof info.name_locked!=='boolean'){
        info.name_locked=!!(info.verification && info.verification.status==='approved');
      }
      _kyc={ status:info.status||'none', data:info, loadedAt:Date.now() };
      if(curProfile && data?.username && curProfile.username!==data.username){
        curProfile.username=data.username;
        applyProfileToUI();
      }
      // An approval makes the verified legal name the account name.
      if(curProfile && typeof data?.account_name==='string' && curProfile.full_name!==data.account_name){
        curProfile.full_name=data.account_name;
        applyProfileToUI();
      }
      updateProfileCooldownUI();
    }catch(e){
      if(!_kyc.data) _kyc.status='error';
      reportAppError(e,{operation:'kyc_status',stage:'rpc'});
    }finally{
      _kycLoadPromise=null;
    }
    renderKycProfile();
    if(_route==='verify') renderVerifyPage();
    return _kyc.data;
  })();
  return _kycLoadPromise;
}

function openVerifyPage(){
  navigate('verify');
}

function renderKycProfile(){
  const status=_kyc.status||'loading';
  const meta=KYC_STATES[status]||KYC_STATES.none;
  const badge=document.getElementById('pfKycBadge');
  if(badge){
    badge.dataset.state=status;
    const ico=document.getElementById('pfKycBadgeIco');
    if(ico) ico.innerHTML = status==='loading' ? _skb(16,16,true) : kycBadgeSvg(status);
    const txt=document.getElementById('pfKycBadgeText');
    if(txt){ if(status==='loading') txt.innerHTML=_skb(92,10); else txt.textContent=meta.label; }
  }
  const dot=document.getElementById('pfVerifiedDot');
  if(dot){
    dot.hidden = status==='loading' || status==='error';
    dot.dataset.tone = kycTone(status);
    dot.title = meta.label;
    dot.innerHTML = kycBadgeSvg(status);
  }
  const sub=document.getElementById('pfMenuKycSub');
  if(sub) sub.textContent = status==='loading'||status==='error' ? 'کارتی نیشتیمانی یان مۆڵەتی شوفێری' : meta.label;
  // Profile tab shows the verification state: approved / pending / not verified.
  const bn=document.getElementById('bnProfileDot');
  if(bn){
    const dotKind = status==='approved' ? 'ok' : status==='pending' ? 'wait' : (status==='none'||status==='required'||status==='rejected') ? 'warn' : '';
    const dotGlyph = { ok:'<path d="m5.5 12.5 4.2 4.2L18.5 8"/>', wait:'<path d="M12 6.5V12l3.5 2"/>', warn:'<path d="M12 6.5v6.5M12 17.4h.01"/>' };
    if(dotKind){
      bn.dataset.state=dotKind;
      bn.setAttribute('aria-label', meta.label);
      bn.innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true">'+dotGlyph[dotKind]+'</svg>';
      bn.style.display='flex';
    }else{
      bn.style.display='none';
    }
  }
  renderExchangeGate();

  const card=document.getElementById('pfKycCard');
  if(!card) return;
  card.dataset.state=status;
  const d=_kyc.data||{};
  const v=d.verification||null;
  const req=d.request||null;
  const docLabel=v && KYC_DOC_TYPES[v.document_type] ? KYC_DOC_TYPES[v.document_type].label : '';
  let html='';
  if(status==='loading' || status==='error'){
    card.hidden = status==='loading';
    if(status==='error'){
      html=`<div class="kyc-card-head">${kycIco('error','kyc-card-ico')}
        <div><b>نەتوانرا دۆخی ناسنامە باربکرێت</b><small>پەیوەندییەکەت بپشکنە و دووبارە هەوڵبدەوە.</small></div></div>
        <button type="button" class="btn btn-ghost btn-block kyc-card-btn" onclick="loadKycStatus()">${kycSolar('refresh-linear')} دووبارە هەوڵدانەوە</button>`;
    }
    card.innerHTML=html;
    return;
  }
  card.hidden=false;
  if(status==='required'){
    html=`<div class="kyc-card-head">${kycIco('required','kyc-card-ico')}
      <div><b>پشتڕاستکردنەوەی ناسنامە پێویستە</b><small>تیمی پڕۆکسۆ داوای پشتڕاستکردنەوەی ناسنامەکەتی کردووە${req?.created_at?' — '+escHtml(kycFmtDate(req.created_at)):''}.</small></div></div>
      ${req?.reason?`<div class="kyc-note"><b>تێبینی ئادمین</b><p>${escHtml(req.reason)}</p></div>`:''}
      <button type="button" class="btn btn-primary btn-block kyc-card-btn" onclick="openVerifyPage()">${kycSolar('user-id-linear')} دەستپێکردنی پشتڕاستکردنەوە</button>`;
  }else if(status==='rejected'){
    html=`<div class="kyc-card-head">${kycIco('rejected','kyc-card-ico')}
      <div><b>پشتڕاستکردنەوەکەت ڕەتکرایەوە</b><small>زانیاری یان وێنەکان ڕاست بکەرەوە و دووبارە بینێرە.</small></div></div>
      <div class="kyc-note danger"><b>هۆکاری ڕەتکردنەوە</b><p>${escHtml(v?.rejection_reason||'—')}</p></div>
      ${req?.reason?`<div class="kyc-note"><b>تێبینی ئادمین</b><p>${escHtml(req.reason)}</p></div>`:''}
      <button type="button" class="btn btn-primary btn-block kyc-card-btn" onclick="openVerifyPage()">${kycSolar('refresh-linear')} ڕاستکردنەوە و دووبارە ناردن</button>`;
  }else if(status==='pending'){
    html=`<div class="kyc-card-head">${kycIco('pending','kyc-card-ico')}
      <div><b>داواکارییەکەت نێردرا و لە ژێر پشکنینە</b><small>ئەنجامەکەت بە ئاگادارییەک پێ ڕادەگەیەنین.</small></div></div>
      <div class="kyc-facts">
        <span><small>جۆری بەڵگەنامە</small><b>${escHtml(docLabel||'—')}</b></span>
        <span><small>کاتی ناردن</small><b>${escHtml(kycFmtDate(v?.submitted_at,true))}</b></span>
      </div>`;
  }else if(status==='approved'){
    html=`<div class="kyc-card-head">${kycIco('approved','kyc-card-ico')}
      <div><b>ناسنامە پشتڕاستکراوەتەوە</b><small>هەژمارەکەت بە بەڵگەنامەی فەرمی پشتڕاستکراوەتەوە.</small></div></div>
      <div class="kyc-facts">
        <span><small>جۆری بەڵگەنامە</small><b>${escHtml(docLabel||'—')}</b></span>
        <span><small>بەرواری پشتڕاستکردنەوە</small><b>${escHtml(kycFmtDate(v?.reviewed_at))}</b></span>
      </div>`;
  }else{ // none
    if(!KYC_SELF_START_ENABLED){ card.hidden=true; card.innerHTML=''; return; }
    html=`<div class="kyc-card-head">${kycIco('none','kyc-card-ico')}
      <div><b>ناسنامەکەت پشتڕاست بکەرەوە</b><small>بە کارتی نیشتیمانی یان مۆڵەتی شوفێری، هەژمارەکەت پارێزراوتر و متمانەپێکراوتر دەبێت.</small></div></div>
      <button type="button" class="btn btn-ghost btn-block kyc-card-btn" onclick="openVerifyPage()">${kycSolar('shield-check-linear')} دەستپێکردنی پشتڕاستکردنەوە</button>`;
  }
  card.innerHTML=html;
}

function renderVerifyPage(){
  const banner=document.getElementById('kycBanner');
  const form=document.getElementById('kycFormCard');
  const success=document.getElementById('kycSuccess');
  if(!banner || !form) return;
  const status=_kyc.status||'loading';
  const d=_kyc.data||{};
  const v=d.verification||null;
  const req=d.request||null;
  if(success && !success.hidden && status==='pending'){ form.hidden=true; banner.hidden=true; return; }
  if(success) success.hidden=true;
  banner.hidden=false;
  banner.dataset.state=status;

  let canSubmit=!!d.can_submit;
  if(status==='none' && !KYC_SELF_START_ENABLED) canSubmit=false;

  if(status==='loading'){
    banner.innerHTML=window.PXS?`<div aria-hidden="true"><b>${PXS.bar(168,12)}</b><p>${PXS.bar('92%',10)}</p></div>`:'<div><b>بارکردنی دۆخی ناسنامە...</b></div>';
    form.hidden=true; return;
  }
  if(status==='error'){
    banner.innerHTML=`<div><b>نەتوانرا دۆخی ناسنامە باربکرێت</b><p>پەیوەندییەکەت بپشکنە.</p>
      <button type="button" class="kv-mini" onclick="loadKycStatus()">دووبارە هەوڵدانەوە</button></div>`;
    form.hidden=true; return;
  }
  if(status==='pending'){
    banner.innerHTML=`<div><b>داواکارییەکەت نێردرا و لە ژێر پشکنینە</b>
      <p>${escHtml(KYC_DOC_TYPES[v?.document_type]?.label||'')} — ${escHtml(kycFmtDate(v?.submitted_at,true))}</p></div>`;
  }else if(status==='approved'){
    banner.innerHTML=`<div><b>ناسنامە پشتڕاستکراوەتەوە</b>
      <p>پێویست بە هیچ کارێکی تر ناکات. بەرواری پشتڕاستکردنەوە: ${escHtml(kycFmtDate(v?.reviewed_at))}</p></div>`;
  }else if(status==='required'){
    banner.innerHTML=`<div><b>پشتڕاستکردنەوەی ناسنامە پێویستە</b>
      <p>${escHtml(req?.reason||'تکایە بۆ بەردەوامبوون لە بەکارهێنانی خزمەتگوزارییەکان ناسنامەکەت پشتڕاست بکەرەوە.')}</p></div>`;
  }else if(status==='rejected'){
    banner.innerHTML=`<div><b>پێویستی بە دووبارە ناردنەوە هەیە</b>
      <p><strong>هۆکار:</strong> ${escHtml(v?.rejection_reason||'—')}</p></div>`;
  }else{
    banner.innerHTML=`<div><b>پشتڕاست نەکراوەتەوە</b></div>`;
  }
  form.hidden=!canSubmit;
  if(canSubmit){
    const dob=document.getElementById('kycDob');
    if(dob) dob.max=kycToday();
    // A rejected submission is pre-filled so only the wrong part needs fixing.
    if(status==='rejected' && v && _kycPrefilledFor!==v.id){
      _kycPrefilledFor=v.id;
      kycSelectDoc(v.document_type, true);
      const n=document.getElementById('kycName'); if(n && !n.value) n.value=v.full_legal_name||'';
      const b=document.getElementById('kycDob'); if(b && !b.value) b.value=v.date_of_birth||'';
      const num=document.getElementById('kycNumber'); if(num && !num.value) num.value=v.document_number||'';
    }
    const nameEl=document.getElementById('kycName');
    if(nameEl && !nameEl.value && curProfile && curProfile.full_name){
      nameEl.value=String(curProfile.full_name).replace(/\s+/g,' ').trim();
    }
    kycUpdateNameNote();
    kycUpdateSteps();
  }
}

// Local calendar date (YYYY-MM-DD) — date of birth may not be in the future.
function kycToday(){
  const d=new Date();
  return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
}
function kycIsRealDate(value){
  if(!/^\d{4}-\d{2}-\d{2}$/.test(value||'')) return false;
  const [y,m,d]=value.split('-').map(Number);
  const dt=new Date(Date.UTC(y,m-1,d));
  return dt.getUTCFullYear()===y && dt.getUTCMonth()===m-1 && dt.getUTCDate()===d;
}

function kycSelectDoc(type, silent){
  if(!KYC_DOC_TYPES[type]) return;
  _kycDocType=type;
  const cfg=KYC_DOC_TYPES[type];
  document.querySelectorAll('.kv-doc').forEach(b=>{
    const on=b.dataset.doc===type;
    b.classList.toggle('on',on);
    b.setAttribute('aria-checked',on?'true':'false');
  });
  const set=(id,val)=>{ const el=document.getElementById(id); if(el) el.textContent=val; };
  set('kycNumberLabel',cfg.numberLabel);
  set('kycFrontTitle',cfg.front);
  set('kycBackTitle',cfg.back);
  const num=document.getElementById('kycNumber'); if(num) num.placeholder=cfg.numberHint;
  const backBox=document.getElementById('kycBackBox'); if(backBox) backBox.hidden=!cfg.needsBack;
  clearFieldError('kycDocType');
  kycUpdateSteps();
  if(!silent){
    const info=document.getElementById('kycSecInfo');
    if(info && window.matchMedia('(max-width: 640px)').matches) info.scrollIntoView({behavior:'smooth',block:'start'});
  }
}

// Same rules as public.ex_normalize_person_name in the database: only harmless
// differences (NFC, invisible characters, tatweel, spacing, Latin case, and the
// Arabic-keyboard forms ي ى ك ھ) are ignored.
function kycNormName(s){
  const v=String(s??'').normalize('NFC')
    .replace(/[\u200B-\u200F\u202A-\u202E\u2066-\u2069\u0640\uFEFF]/g,'')
    .replace(/[\u00A0\u2000-\u200A\u202F\u205F\u3000]/g,' ')
    .replace(/[\u064A\u0649]/g,'\u06CC').replace(/\u0643/g,'\u06A9').replace(/\u06BE/g,'\u0647')
    .replace(/\s+/g,' ').trim().toLowerCase();
  return v || null;
}
const KYC_AR2LAT = {
  'ا':'a','آ':'a','أ':'a','إ':'a','ء':'','ئ':'','ؤ':'w','ة':'h',
  'ب':'b','پ':'p','ت':'t','ث':'s','ج':'j','چ':'C','ح':'h','خ':'x','د':'d','ذ':'z',
  'ر':'r','ڕ':'r','ز':'z','ژ':'j','س':'s','ش':'S','ص':'s','ض':'z','ط':'t','ظ':'z',
  'ع':'','غ':'g','ف':'f','ڤ':'v','ق':'q','ك':'k','ک':'k','گ':'g','ل':'l','ڵ':'l',
  'م':'m','ن':'n','ه':'h','ھ':'h','ە':'e','و':'w','ۆ':'o','ی':'i','ي':'i','ى':'i','ێ':'e'
};
function kycScriptOf(s){
  const t=String(s||'');
  const ar=/[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/.test(t);
  const la=/[A-Za-z]/.test(t);
  return (ar&&la) ? 'mixed' : ar ? 'arabic' : la ? 'latin' : 'other';
}
function kycSkeleton(token){
  let s=String(token||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  s=s.replace(/[\u0600-\u06FF]/g, ch => (KYC_AR2LAT[ch] !== undefined ? KYC_AR2LAT[ch] : ' '));
  // Latin digraphs collapse to the single letters the Kurdish map produces
  s=s.replace(/tch|ch/g,'C').replace(/sh/g,'S').replace(/kh/g,'x').replace(/zh/g,'j')
     .replace(/gh/g,'g').replace(/th/g,'s').replace(/ph/g,'f').replace(/ck/g,'k');
  s=s.replace(/[^bptsjChxdrzSgfvqklmn]/g,'');   // drop vowels, hamza, punctuation
  return s.replace(/(.)\1+/g,'$1');             // doubled consonants are spelling noise
}
// 'same' | 'same_translit' | 'similar' | 'different_script' | 'different' | 'unknown'
function kycNameRelation(accountName, legalName){
  const a=kycNormName(accountName), b=kycNormName(legalName);
  if(!a || !b) return 'unknown';
  if(a===b) return 'same';
  const sa=kycScriptOf(a), sb=kycScriptOf(b);
  const ta=a.split(' ').map(kycSkeleton), tb=b.split(' ').map(kycSkeleton);
  const enough=ta.join('').length>=4 && tb.join('').length>=4;
  const equal=ta.length===tb.length && ta.every((t,i)=>t && t===tb[i]);
  if(equal && enough) return (sa!==sb) ? 'same_translit' : 'similar';
  return (sa!==sb && sa!=='other' && sb!=='other') ? 'different_script' : 'different';
}

function kycNameLocked(){ return !!(_kyc && _kyc.data && _kyc.data.name_locked); }
function kycExchangeBlocked(){ return !!(_kyc && _kyc.data && _kyc.data.exchange_blocked); }

const KYC_EXCHANGE_MSG='پێش ئەنجامدانی ئاڵوگۆڕ، پێویستە ناسنامەکەت پشتڕاست بکرێتەوە.';
// While an admin-requested verification is not approved, the exchange form
// (including the wallet number to pay into) is replaced by this notice. The
// database and /api/orders enforce the same rule.
function renderExchangeGate(){
  const card=document.getElementById('exchangeCard');
  const gate=document.getElementById('exchangeKycGate');
  if(!card || !gate) return;
  const blocked=kycExchangeBlocked();
  card.classList.toggle('kyc-locked', blocked);
  gate.hidden=!blocked;
  if(blocked){
    const sub=document.getElementById('exchangeKycGateSub');
    const st=_kyc.status;
    if(sub) sub.textContent = st==='pending'
      ? 'بەڵگەنامەکەت نێردراوە و لە ژێر پشکنینە؛ دوای پەسەندکردن ئاڵوگۆڕ دەکرێتەوە.'
      : st==='rejected'
        ? 'پشتڕاستکردنەوەکەت ڕەتکرایەوە؛ تکایە زانیارییەکان ڕاست بکەرەوە و دووبارە بینێرە.'
        : 'تیمی پڕۆکسۆ داوای پشتڕاستکردنەوەی ناسنامەکەتی کردووە.';
    const sheet=document.getElementById('confirmSheet');
    if(sheet && sheet.classList.contains('open')) closeOrderConfirm();
  }
  const from=document.getElementById('from'), to=document.getElementById('receiveVia');
  if(from && to && from.value && to.value) updateSubmitState(from.value,to.value);
}
function showKycExchangeBlocked(){
  renderExchangeGate();
  showResultModal({
    tone:'warning',
    title:'پشتڕاستکردنەوەی ناسنامە پێویستە',
    message:KYC_EXCHANGE_MSG,
    primaryText:'دەستپێکردنی پشتڕاستکردنەوە',
    onPrimary:()=>openVerifyPage(),
    secondaryText:'داخستن'
  });
}

function kycUpdateNameNote(){
  const note=document.getElementById('kycNameNote');
  const input=document.getElementById('kycName');
  if(!note || !input) return;
  const account=(curProfile && curProfile.full_name) || '';
  const typed=input.value||'';
  const rel=kycNameRelation(account, typed);
  if(!account || !kycNormName(typed) || rel==='same' || rel==='unknown'){
    note.hidden=true; note.textContent=''; note.classList.remove('ok'); return;
  }
  note.hidden=false;
  const acc=account.replace(/\s+/g,' ').trim();
  if(rel==='same_translit'){
    // English account name + Kurdish document name (or the reverse) — same name.
    note.classList.add('ok');
    note.textContent='ناوی هەژمارەکەت («'+acc+'») بە ئەلفوبێیەکی جیاوازە بەڵام هەمان ناوە. دوای پەسەندکردن ناوی هەژمارەکەت وەک سەر ناسنامەکە دەنووسرێتەوە.';
  }else{
    note.classList.remove('ok');
    note.textContent='ئەم ناوە جیاوازە لە ناوی هەژمارەکەت («'+acc+'»). ئەگەر پشتڕاستکردنەوەکە پەسەند بکرێت، ناوی هەژمارەکەت دەگۆڕدرێت بۆ ناوی سەر ناسنامەکەت.';
  }
}

function kycFormatNumber(el){
  const v=String(el.value||'')
    .replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-0x660))
    .replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-0x6F0))
    .toUpperCase().replace(/[^A-Z0-9-]/g,'').slice(0,30);
  if(v!==el.value) el.value=v;
}

function kycUpdateSteps(){
  const hasType=!!_kycDocType;
  const name=(document.getElementById('kycName')?.value||'').trim();
  const dob=document.getElementById('kycDob')?.value||'';
  const num=(document.getElementById('kycNumber')?.value||'').trim();
  const infoDone=hasType && name.length>=5 && !!dob && num.length>=4;
  const needsBack=hasType && KYC_DOC_TYPES[_kycDocType].needsBack;
  const imgsDone=!!_kycImages.front?.prepared && (!needsBack || !!_kycImages.back?.prepared);
  const infoSec=document.getElementById('kycSecInfo'); if(infoSec) infoSec.dataset.locked=hasType?'false':'true';
  const imgSec=document.getElementById('kycSecImages'); if(imgSec) imgSec.dataset.locked=hasType?'false':'true';
  const s1=document.getElementById('kycStep1'), s2=document.getElementById('kycStep2'), s3=document.getElementById('kycStep3');
  if(s1){ s1.classList.toggle('done',hasType); s1.classList.toggle('on',!hasType); }
  if(s2){ s2.classList.toggle('done',infoDone); s2.classList.toggle('on',hasType && !infoDone); }
  if(s3){ s3.classList.toggle('done',infoDone && imgsDone); s3.classList.toggle('on',infoDone && !imgsDone); }
}

// Decode → validate → re-encode as JPEG. Re-encoding strips EXIF/GPS data,
// fixes phone orientation and keeps uploads well under the bucket limit.
async function kycDecodeImage(blob){
  if(window.createImageBitmap){
    try{ return await createImageBitmap(blob,{imageOrientation:'from-image'}); }catch(_){}
    try{ return await createImageBitmap(blob); }catch(_){}
  }
  return await new Promise((resolve,reject)=>{
    const url=URL.createObjectURL(blob);
    const img=new Image();
    img.onload=()=>{ URL.revokeObjectURL(url); resolve(img); };
    img.onerror=()=>{ URL.revokeObjectURL(url); reject(Object.assign(new Error('KYC_IMAGE_DECODE'),{code:'KYC_IMAGE_DECODE'})); };
    img.src=url;
  });
}
// Sharpness = variance of the second derivative, measured in four directions
// (horizontal, vertical and both diagonals), per tile, on a small grayscale
// copy. Each direction is scored by the mean of its sharpest 20% of tiles, so
// a card on a plain table is judged by the card and not by the background.
// The weakest direction decides: hand shake smears one direction only, which
// a plain 2-D Laplacian does not notice.
function kycClarityFromGray(gray, w, h){
  const n=w*h;
  let sum=0, sum2=0;
  for(let i=0;i<n;i++){ const v=gray[i]; sum+=v; sum2+=v*v; }
  const mean=sum/n;
  const contrast=Math.sqrt(Math.max(0, sum2/n-mean*mean));
  const tile=Math.max(24, Math.round(Math.max(w,h)/10));
  const dirs=[[],[],[],[]];
  for(let ty=1; ty<h-1; ty+=tile){
    for(let tx=1; tx<w-1; tx+=tile){
      const yEnd=Math.min(h-1, ty+tile), xEnd=Math.min(w-1, tx+tile);
      const s1=[0,0,0,0], s2=[0,0,0,0];
      let c=0;
      for(let y=ty; y<yEnd; y++){
        let i=y*w+tx;
        for(let x=tx; x<xEnd; x++, i++){
          const g2=2*gray[i];
          const a=g2-gray[i-1]-gray[i+1];            // horizontal
          const b=g2-gray[i-w]-gray[i+w];            // vertical
          const d=g2-gray[i-w-1]-gray[i+w+1];        // diagonal ↘
          const e=g2-gray[i-w+1]-gray[i+w-1];        // diagonal ↙
          s1[0]+=a; s2[0]+=a*a; s1[1]+=b; s2[1]+=b*b;
          s1[2]+=d; s2[2]+=d*d; s1[3]+=e; s2[3]+=e*e;
          c++;
        }
      }
      if(c>=64){
        for(let k=0;k<4;k++){ const m=s1[k]/c; dirs[k].push(s2[k]/c-m*m); }
      }
    }
  }
  const topMean=a=>{
    if(!a.length) return 0;
    a.sort((p,q)=>q-p);
    const k=Math.min(a.length, Math.max(3, Math.ceil(a.length*0.2)));
    let t=0; for(let i=0;i<k;i++) t+=a[i];
    return t/k;
  };
  const perDirection=dirs.map(topMean);
  return { sharpness:Math.min(...perDirection), perDirection, contrast };
}
function kycMeasureClarity(bmp, w, h){
  const scale=Math.min(1, KYC_ANALYSIS_SIDE/Math.max(w,h));
  const aw=Math.max(3, Math.round(w*scale)), ah=Math.max(3, Math.round(h*scale));
  const canvas=document.createElement('canvas');
  canvas.width=aw; canvas.height=ah;
  const ctx=canvas.getContext('2d',{willReadFrequently:true});
  ctx.imageSmoothingEnabled=true;
  ctx.imageSmoothingQuality='high';
  ctx.drawImage(bmp,0,0,aw,ah);
  const px=ctx.getImageData(0,0,aw,ah).data;
  const gray=new Float32Array(aw*ah);
  for(let i=0,j=0;i<gray.length;i++,j+=4) gray[i]=0.299*px[j]+0.587*px[j+1]+0.114*px[j+2];
  canvas.width=canvas.height=0;   // release the temporary copy
  return Object.assign(kycClarityFromGray(gray, aw, ah), { width:w, height:h });
}
function kycClarityVerdict(m){
  if(Math.min(m.width,m.height)<KYC_MIN_SHORT_SIDE || Math.max(m.width,m.height)<KYC_MIN_LONG_SIDE) return 'KYC_IMAGE_TOO_SMALL';
  if(m.contrast<KYC_MIN_CONTRAST || m.sharpness<KYC_MIN_SHARPNESS) return 'KYC_IMAGE_BLURRY';
  return null;
}

async function kycPrepareImage(snapshot){
  const source=new Blob([snapshot.bytes],{type:snapshot.type||'image/jpeg'});
  const bmp=await kycDecodeImage(source);
  try{
    const w=bmp.naturalWidth||bmp.width, h=bmp.naturalHeight||bmp.height;
    if(!w || !h) throw Object.assign(new Error('KYC_IMAGE_DECODE'),{code:'KYC_IMAGE_DECODE'});
    // 1) clarity gate — runs before anything can be uploaded
    const clarity=kycMeasureClarity(bmp, w, h);
    const verdict=kycClarityVerdict(clarity);
    if(verdict) throw Object.assign(new Error(verdict),{code:verdict, clarity});
    // 2) re-encode as JPEG: fixes orientation and drops EXIF/GPS metadata.
    //    The original bytes are never uploaded.
    const scale=Math.min(1, KYC_MAX_IMAGE_SIDE/Math.max(w,h));
    const cw=Math.round(w*scale), ch=Math.round(h*scale);
    const canvas=document.createElement('canvas');
    canvas.width=cw; canvas.height=ch;
    const ctx=canvas.getContext('2d');
    ctx.fillStyle='#ffffff'; ctx.fillRect(0,0,cw,ch);
    ctx.drawImage(bmp,0,0,cw,ch);
    for(const quality of [0.9, 0.8, 0.7]){
      const out=await new Promise(res=>canvas.toBlob(res,'image/jpeg',quality));
      if(out && out.size>0 && out.size<=KYC_MAX_UPLOAD_BYTES){
        canvas.width=canvas.height=0;
        return { blob:out, type:'image/jpeg', ext:'jpg', width:cw, height:ch, clarity };
      }
    }
    throw Object.assign(new Error('KYC_IMAGE_ENCODE'),{code:'KYC_IMAGE_ENCODE'});
  }finally{
    try{ bmp.close && bmp.close(); }catch(_){}
  }
}

function kycSideEls(side){
  const S=side==='front'?'Front':'Back';
  return {
    camera:document.getElementById('kyc'+S+'Camera'),
    gallery:document.getElementById('kyc'+S+'Gallery'),
    drop:document.getElementById('kyc'+S+'Drop'),
    preview:document.getElementById('kyc'+S+'Preview'),
    img:document.getElementById('kyc'+S+'Img'),
    meta:document.getElementById('kyc'+S+'Meta'),
    hint:document.getElementById('kyc'+S+'Hint'),
    box:document.getElementById('kyc'+S+'Box'),
    errId:'kyc'+S
  };
}

const KYC_PICK_HINT='';   // the box shows only its title until a photo is being checked
function kycRemoveImage(side){
  _kycImageTokens[side]++;
  const cur=_kycImages[side];
  if(cur?.url) URL.revokeObjectURL(cur.url);
  _kycImages[side]=null;
  const el=kycSideEls(side);
  if(el.camera) el.camera.value='';
  if(el.gallery) el.gallery.value='';
  if(el.preview) el.preview.hidden=true;
  if(el.img) el.img.removeAttribute('src');
  if(el.drop){ el.drop.hidden=false; }
  if(el.hint) el.hint.textContent=KYC_PICK_HINT;
  if(el.box) el.box.classList.remove('ready','busy');
  clearFieldError(el.errId);
  kycUpdateSteps();
}

function kycOnImage(side, input){
  const el=kycSideEls(side);
  clearFieldError(el.errId);
  const file=input?.files?.[0]||null;
  if(!file) return;   // picker cancelled: keep the current image
  if(input) input.value='';   // lets the same photo be chosen again
  if(file.type && !/^image\//i.test(file.type)){
    kycRemoveImage(side);
    setFieldError(el.errId, KYC_ERRORS.KYC_IMAGE_TYPE);
    return;
  }
  if(file.size>KYC_MAX_INPUT_BYTES){
    kycRemoveImage(side);
    setFieldError(el.errId, KYC_ERRORS.KYC_IMAGE_TOO_LARGE);
    return;
  }
  const token=++_kycImageTokens[side];
  if(el.box) el.box.classList.add('busy');
  if(el.hint) el.hint.textContent='پشکنینی ڕوونی وێنە...';
  const promise=readSelectedFileSnapshot(file)
    .then(snapshot=>kycPrepareImage(snapshot))
    .then(prepared=>{
      if(token!==_kycImageTokens[side]) return null;
      const old=_kycImages[side];
      if(old?.url) URL.revokeObjectURL(old.url);
      const url=URL.createObjectURL(prepared.blob);
      _kycImages[side]={ prepared, url, name:file.name, promise:null };
      if(el.img) el.img.src=url;
      if(el.meta) el.meta.textContent=prepared.width+'×'+prepared.height+' • '+(prepared.blob.size/1024/1024).toFixed(2)+' MB';
      if(el.drop) el.drop.hidden=true;
      if(el.preview) el.preview.hidden=false;
      if(el.box){ el.box.classList.remove('busy'); el.box.classList.add('ready'); }
      clearFieldError(el.errId);
      kycUpdateSteps();
      return prepared;
    })
    .catch(err=>{
      if(token!==_kycImageTokens[side]) return null;
      // A rejected photo replaces whatever was there: the side goes back to
      // the Camera / Gallery choice so nothing unclear can be submitted.
      kycRemoveImage(side);
      setFieldError(el.errId, kycErrorMessage(err));
      return null;
    });
  _kycImages[side]=Object.assign(_kycImages[side]||{}, { promise });
}

// The Camera / Gallery choices are <label>s (they open the file inputs
// natively on iOS and Android); make them work from the keyboard too.
document.addEventListener('keydown', e=>{
  if(e.key!=='Enter' && e.key!==' ') return;
  const l=e.target && e.target.closest ? e.target.closest('label.kv-src, label.kv-mini') : null;
  if(!l) return;
  e.preventDefault();
  l.click();
});

async function kycAwaitImage(side){
  const cur=_kycImages[side];
  if(cur?.promise){ await cur.promise; }
  return _kycImages[side]?.prepared||null;
}

function kycSetProgress(pct, text){
  const wrap=document.getElementById('kycProgress');
  const fill=document.getElementById('kycProgressFill');
  const label=document.getElementById('kycProgressText');
  if(!wrap) return;
  if(pct===null){ wrap.hidden=true; return; }
  wrap.hidden=false;
  if(fill) fill.style.width=Math.max(0,Math.min(100,pct))+'%';
  if(label) label.textContent=text||'';
}

async function kycUpload(path, prepared){
  let lastError=null;
  for(let attempt=0;attempt<3;attempt++){
    try{
      const {error}=await sb.storage.from(KYC_BUCKET).upload(path, prepared.blob, {
        contentType:prepared.type, upsert:true, cacheControl:'0'
      });
      if(error) throw error;
      return;
    }catch(error){
      lastError=error;
      if(!isTransientNetworkError(error) || attempt===2) break;
      await waitForNetworkRetry(800*(attempt+1));
    }
  }
  const code=isTransientNetworkError(lastError)?'KYC_UPLOAD_NETWORK':'KYC_UPLOAD_FAILED';
  const err=new Error(code+': '+String(lastError?.message||''));
  err.code=code; err.status=lastError?.statusCode||lastError?.status;
  throw err;
}

function kycShowFormError(msg){
  const box=document.getElementById('kycFormError');
  if(!box) return;
  if(!msg){ box.hidden=true; box.textContent=''; return; }
  box.hidden=false;
  box.textContent=msg;
}

function kycValidate(){
  let ok=true, first=null;
  const fail=(id,msg,focusId)=>{ setFieldError(id,msg); ok=false; if(!first) first=document.getElementById(focusId||id); };
  ['kycDocType','kycName','kycDob','kycNumber','kycFront','kycBack','kycConsent'].forEach(clearFieldError);
  if(!_kycDocType) fail('kycDocType','تکایە جۆری بەڵگەنامە هەڵبژێرە','kycSecType');
  const name=(document.getElementById('kycName').value||'').trim().replace(/\s+/g,' ');
  if(name.length<5 || !name.includes(' ')) fail('kycName','ناوی تەواو بە لانیکەم دوو بەش بنووسە (ناو و ناوی باوک)');
  else if(/[0-9٠-٩۰-۹<>{}\[\]\\\/@#$%^*=+_|~]/.test(name)) fail('kycName','ناو نابێت ژمارە یان هێمای تێدابێت');
  const dob=document.getElementById('kycDob').value;
  if(!dob) fail('kycDob','بەرواری لەدایکبوون دیاری بکە');
  else if(!kycIsRealDate(dob) || dob<'1900-01-01' || dob>kycToday()) fail('kycDob','بەرواری لەدایکبوون دروست نییە');
  const num=(document.getElementById('kycNumber').value||'').trim();
  if(!/^[A-Z0-9-]{4,30}$/.test(num)) fail('kycNumber','ژمارەی بەڵگەنامە دەبێت 4 بۆ 30 پیت/ژمارەی ئینگلیزی بێت');
  if(!_kycImages.front?.prepared && !_kycImages.front?.promise) fail('kycFront','وێنەی ڕووی پێشەوە پێویستە','kycFrontBox');
  if(_kycDocType && KYC_DOC_TYPES[_kycDocType].needsBack && !_kycImages.back?.prepared && !_kycImages.back?.promise)
    fail('kycBack','وێنەی ڕووی دواوە پێویستە','kycBackBox');
  if(!document.getElementById('kycConsent').checked) fail('kycConsent','تکایە ڕاستی زانیارییەکان پشتڕاست بکەرەوە');
  if(first && first.scrollIntoView) first.scrollIntoView({behavior:'smooth',block:'center'});
  return ok ? { name, dob, num } : null;
}

async function submitKyc(){
  if(_kycSubmitting) return;               // double-click guard (DB also enforces it)
  kycShowFormError(null);
  if(!curUser){ showToast('تکایە دووبارە بچۆ ژوورەوە','error'); return; }
  if(!_kyc.data?.can_submit){ showToast(kycErrorMessage(_kyc.status==='pending'?'KYC_ALREADY_PENDING':'KYC_ALREADY_APPROVED'),'warning'); return; }
  const fields=kycValidate();
  if(!fields) return;

  const btn=document.getElementById('kycSubmitBtn');
  const btnHtml=btn.innerHTML;
  _kycSubmitting=true;
  btn.disabled=true; btn.innerHTML=ICON.spin+' ناردن...';
  document.querySelectorAll('#kycFormCard input, #kycFormCard .kv-doc, #kycFormCard .kv-mini').forEach(el=>el.setAttribute('disabled',''));
  let stage='session';
  try{
    kycSetProgress(5,'پشتڕاستکردنەوەی چوونەژوورەوە...');
    await getOrderSession();

    stage='image_prepare';
    kycSetProgress(12,'ئامادەکردنی وێنەکان...');
    const needsBack=KYC_DOC_TYPES[_kycDocType].needsBack;
    const front=await kycAwaitImage('front');
    const back=needsBack ? await kycAwaitImage('back') : null;
    // Defence in depth: only images that passed the local clarity gate exist
    // here, but never upload anything without a passing verdict.
    const cleared=img=>!!(img && img.clarity && !kycClarityVerdict(img.clarity));
    if(front && !cleared(front)){ kycRemoveImage('front'); setFieldError('kycFront',KYC_UNCLEAR_MSG); throw Object.assign(new Error('KYC_IMAGE_BLURRY'),{handled:true}); }
    if(back && !cleared(back)){ kycRemoveImage('back'); setFieldError('kycBack',KYC_UNCLEAR_MSG); throw Object.assign(new Error('KYC_IMAGE_BLURRY'),{handled:true}); }
    if(!front){ setFieldError('kycFront','وێنەی ڕووی پێشەوە ئامادە نییە؛ دووبارە هەڵیبژێرە'); throw Object.assign(new Error('KYC_FRONT_IMAGE_MISSING'),{handled:true}); }
    if(needsBack && !back){ setFieldError('kycBack','وێنەی ڕووی دواوە ئامادە نییە؛ دووبارە هەڵیبژێرە'); throw Object.assign(new Error('KYC_BACK_IMAGE_MISSING'),{handled:true}); }

    const vid=_kycDraftId || (_kycDraftId=kycUuid());
    const base=curUser.id+'/'+vid+'/';
    const frontPath=base+'front.'+front.ext;
    const backPath=back ? base+'back.'+back.ext : null;

    stage='upload_front';
    kycSetProgress(25,'بارکردنی '+KYC_DOC_TYPES[_kycDocType].front+'...');
    await kycUpload(frontPath, front);
    if(back){
      stage='upload_back';
      kycSetProgress(55,'بارکردنی '+KYC_DOC_TYPES[_kycDocType].back+'...');
      await kycUpload(backPath, back);
    }

    // Only after both files are stored is the request created.
    stage='submit';
    kycSetProgress(85,'ناردنی زانیارییەکان...');
    const {error}=await sb.rpc('ex_kyc_submit',{
      p_verification_id:vid,
      p_document_type:_kycDocType,
      p_full_legal_name:fields.name,
      p_date_of_birth:fields.dob,
      p_document_number:fields.num,
      p_front_path:frontPath,
      p_back_path:backPath
    });
    if(error) throw error;

    kycSetProgress(100,'تەواو بوو');
    _kycDraftId=null;
    kycResetForm();
    _kyc.status='pending';
    if(_kyc.data){ _kyc.data.status='pending'; _kyc.data.can_submit=false; }
    renderKycProfile();
    const form=document.getElementById('kycFormCard'); if(form) form.hidden=true;
    const banner=document.getElementById('kycBanner'); if(banner) banner.hidden=true;
    const success=document.getElementById('kycSuccess'); if(success) success.hidden=false;
    window.scrollTo({top:0,behavior:'smooth'});
    showToast('داواکارییەکەت نێردرا و لە ژێر پشکنینە','success');
    loadKycStatus(true);
  }catch(e){
    const raw=String(e?.message||'');
    if(/KYC_DUPLICATE_SUBMISSION/.test(raw)) _kycDraftId=null;
    if(/KYC_ALREADY_PENDING|KYC_ALREADY_APPROVED/.test(raw)) loadKycStatus(true);
    if(!e?.handled){
      // Only codes and sizes are reported — never the name, number or images.
      reportAppError(e,{operation:'kyc_submit',stage,file_size:_kycImages.front?.prepared?.blob?.size,file_type:_kycImages.front?.prepared?.type});
    }
    const msg=kycErrorMessage(e);
    kycShowFormError(msg);
    showToast(msg,'error');
  }finally{
    _kycSubmitting=false;
    btn.disabled=false; btn.innerHTML=btnHtml;
    document.querySelectorAll('#kycFormCard [disabled]').forEach(el=>{ if(el!==btn) el.removeAttribute('disabled'); });
    setTimeout(()=>{ if(!_kycSubmitting) kycSetProgress(null); }, 900);
  }
}

function kycResetForm(){
  kycRemoveImage('front');
  kycRemoveImage('back');
  ['kycName','kycDob','kycNumber'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  const c=document.getElementById('kycConsent'); if(c) c.checked=false;
  _kycDocType=null;
  document.querySelectorAll('.kv-doc').forEach(b=>{ b.classList.remove('on'); b.setAttribute('aria-checked','false'); });
  kycShowFormError(null);
  kycUpdateSteps();
}

// ══════════════════════════════════════════════════════════════
// ═══ HEADER — shadow on scroll + live rate pill + nav state ════
// ══════════════════════════════════════════════════════════════
window.addEventListener('scroll', function(){
  const h=document.getElementById('siteHeader');
  if(h) h.classList.toggle('scrolled', window.scrollY>4);
}, { passive:true });

function focusExchangeForm(){
  navigate('exchange');
  const el=document.getElementById('amt');
  const card=document.getElementById('exchangeCard');
  if(card) card.scrollIntoView({ behavior:'smooth', block:'start' });
  setTimeout(function(){ if(el) el.focus(); }, 320);
}

// Swaps the two selected methods, when that direction is actually open.
function swapMethods(){
  const f=document.getElementById('from'), t=document.getElementById('receiveVia');
  const a=f.value, b=t.value;
  if(!RECEIVE_OPTIONS.includes(a) || !FROM_OPTIONS.includes(b)){
    showToast('ئەم ئاراستەیە بەردەست نییە','error'); return;
  }
  f.value=b; t.value=a;
  updateWallet(); updatePlaceholder(); calc();
  refreshTrigger('from'); refreshTrigger('receiveVia');
}

// ── real-time phone / account validation ─────────────────────
function validatePhoneLive(){
  const el=document.getElementById('userPhone');
  const to=document.getElementById('receiveVia').value;
  const v=(el.value||'').trim();
  const grp=document.getElementById('grpRecv');
  el.classList.remove('ok','bad');
  if(grp) grp.classList.remove('has-error');
  if(!v) return;
  const good = recipientIsCard(to) ? v.length>=6 : (v.startsWith('07') && v.length===11);
  el.classList.add(good ? 'ok' : 'bad');
  if(!good && ((recipientIsCard(to) && v.length>6) || v.length>=11)){
    setFieldError('userPhone', recipientIsCard(to)
      ? 'ژمارەی کارتەکە دروست نییە'
      : 'ژمارە دەبێت بە 07 دەست پێبکات و 11 ژمارە بێت');
    if(grp) grp.classList.add('has-error');
  }
}

// ── contextual micro-copy that follows the selected methods ──
function refreshFormHints(){
  const from=document.getElementById('from').value;
  const to=document.getElementById('receiveVia').value;
  const isUsdt = from==='USDT';

  const sfx=document.getElementById('amtSuffix');
  if(sfx) sfx.textContent = isUsdt ? 'USD' : 'IQD';

  const badge=document.getElementById('sendLimitBadge');
  if(badge) badge.textContent = isUsdt ? 'بە دۆلار' : ('کەمترین '+formatNum(MIN_AMOUNT));

  const hint=document.getElementById('amtHint');
  if(hint){
    hint.querySelector('span').innerHTML = isUsdt
      ? 'بڕەکە بە دۆلار داخڵ بکە. نرخی گۆڕین لە خانەی خوارەوە دەردەکەوێت.'
      : from==='AccountBalance' ? 'بڕەکە لە باڵانسی هەژمارەکەت کەم دەکرێتەوە؛ پسووڵەی پارەدان پێویست نییە.'
      : 'کەمترین بڕ <b>'+formatNum(MIN_AMOUNT)+'</b> دینارە. بڕەکە دەبێت وەک ئەوە بێت کە ناردووتە.';
  }

  const lbl=document.getElementById('phoneLabel');
  const txt=document.getElementById('phoneHintText');
  if(recipientIsCard(to)){
    if(lbl) lbl.textContent='ژمارەی کارتی '+((METHOD_META[to]&&METHOD_META[to].label)||to);
    if(txt) txt.innerHTML='ژمارەی کارتەکە بەبێ بۆشایی بنووسە — لانیکەم <b>6</b> ژمارە.';
    document.getElementById('userPhone').placeholder='ژمارەی کارت';
  }else{
    if(lbl) lbl.textContent='ژمارەی وەرگرە';
    if(txt) txt.innerHTML='ژمارەی عێراقی بە <b>07</b> دەست پێدەکات و <b>11</b> ژمارەیە.';
    document.getElementById('userPhone').placeholder='07xxxxxxxxx';
  }
}

// ── the live rate pill in the header ─────────────────────────
function updateHeaderRate(){
  const el=document.getElementById('hdrRateVal'); if(!el) return;
  const from=document.getElementById('from').value, to=document.getElementById('receiveVia').value;
  const raw=RATES[from+'>'+to];
  if(from===to || !raw || !routeAllowed(from,to)){ el.textContent='—'; return; }
  const typed=parseFloat(typeof getAmtRaw==='function'?getAmtRaw():'')||0;
  const r=raw.tier&&typed>0&&from!=='USDT'&&to!=='USDT'?ProxoPricing.effectiveRate(raw,typed):raw;
  if(r.type==='multiplier')      el.textContent = '1 = '+fmtPct(r.value);
  else if(r.type==='fee_percent')el.textContent = fmtPct(r.value)+'% کرێ';
  else                           el.textContent = formatNum(r.value)+' IQD کرێ';
}

// ══════════════════════════════════════════════════════════════
// ═══ PUBLIC PROOF — approved counter + masked feed ═════════════
// ═══ Data comes from /api/public. Phone masking happens in SQL,
// ═══ so a full number is never present in this payload.
// ══════════════════════════════════════════════════════════════
let _proofTimer=null;

async function loadPublicProof(){
  try{
    const res=await fetch('/api/public?limit=8', { headers:{ 'Accept':'application/json' } });
    if(!res.ok) throw new Error('HTTP '+res.status);
    const body=await res.json();
    if(!body.ok) throw new Error(body.error||'failed');
    renderProofStats(body.data.stats);
    renderPublicFeed(body.data.feed);
  }catch(e){
    const feed=document.getElementById('publicFeed');
    if(feed) feed.innerHTML='<div class="empty-state">لە ئێستادا ناتوانرێت داتاکان باربکرێن</div>';
  }
}

function renderProofStats(s){
  if(!s) return;
  const set=(id,v)=>{ const el=document.getElementById(id); if(el) el.textContent=v; };
  set('proofCount', formatNum(s.approved_count||0));
  set('proof24h',   formatNum(s.approved_24h||0));
  set('proofUsers', formatNum(s.users_count||0));
  set('authProofCount',  formatNum(s.approved_count||0));
  set('authProofVolume', formatNum(Math.round((s.total_volume||0)/1000))+'K');
  set('authProofUsers',  formatNum(s.users_count||0));
}

function renderPublicFeed(rows){
  const el=document.getElementById('publicFeed'); if(!el) return;
  if(!rows || !rows.length){ el.innerHTML='<div class="empty-state">هێشتا هیچ مامەڵەیەکی تەواوبوو نییە</div>'; return; }
  // Markup matches the feed CSS: a main column (id, route, masked phone) and
  // an amount panel (time, received, sent). Rows are right-to-left like the
  // transaction cards, so the route reads source ← destination.
  el.innerHTML = rows.map(function(r){
    const cur = r.from==='USDT' ? ' $' : ' IQD';
    return '<div class="feed-row">'
      + '<div class="feed-main">'
        + '<span class="feed-id">'
          + '<span class="icn icon--solar icon--solar--verified-check-linear" aria-hidden="true"></span>'
          + escHtml(r.id||'') + '</span>'
        + '<span class="feed-route">'
          + methodIconHTML(r.from,'sz-xs') + '<span class="fr-name">'+escHtml(methodLabel(r.from))+'</span>'
          + '<span class="icn fr-arrow icon--solar icon--solar--arrow-left-linear" aria-hidden="true"></span>'
          + methodIconHTML(r.to,'sz-xs') + '<span class="fr-name">'+escHtml(methodLabel(r.to))+'</span>'
        + '</span>'
        + (r.phone ? '<span class="feed-phone">'+escHtml(r.phone)+'</span>' : '')
      + '</div>'
      + '<div class="feed-side">'
        + '<span class="feed-time">'+escHtml(timeAgo(r.at))+'</span>'
        + '<span class="fa-line fa-in"><span class="fa-lbl">وەرگرتن</span>'
          + '<span class="fa-val">+'+formatNum(Math.floor(r.total||0))+' IQD</span></span>'
        + '<span class="fa-line fa-out"><span class="fa-lbl">ناردن</span>'
          + '<span class="fa-val">'+formatNum(Math.floor(r.amount||0))+cur+'</span></span>'
      + '</div>'
      + '</div>';
  }).join('');
}

function startProofPolling(){
  loadPublicProof();
  clearInterval(_proofTimer);
  _proofTimer=setInterval(function(){
    if(document.visibilityState==='visible' && !curUser) loadPublicProof();
  }, 60000);
}


// ══════════════════════════════════════════════════════════════
// ═══ BEHAVIOUR REPORTING ══════════════════════════════════════
// The browser reports only WHAT happened. IP, user-agent and identity are
// read from the request by /api/track, so none of them can be spoofed here.
// ══════════════════════════════════════════════════════════════
function isTransactionSummaryRoute(){return /^\/summarytransaction\/[^/]+\/?$/.test(location.pathname);}
function summaryTokenFromPath(){
  const match=String(location.pathname||'').match(/^\/summarytransaction\/([^/]+)\/?$/);
  if(!match)return '';
  try{return decodeURIComponent(match[1]);}catch(_){return match[1]||'';}
}
function safeAppTelemetryPath(){return summaryTokenFromPath()?'/summarytransaction/:secure_token':location.pathname;}
async function reportEvent(event, detail, meta){
  try{
    const headers={ 'Content-Type':'application/json' };
    const { data:{ session } } = await sb.auth.getSession();
    if(session) headers['Authorization']='Bearer '+session.access_token;
    await fetch('/api/track', {
      method:'POST', headers,
      body: JSON.stringify({ event, detail:detail||null, path:safeAppTelemetryPath(), meta:meta||null }),
      keepalive:true
    });
  }catch(_){ /* never let telemetry break the app */ }
}

// A filled honeypot means a script, not a person. Report it, then behave
// exactly as if the order went through — no hint that anything was noticed.
function honeypotTripped(){
  const hp=document.getElementById('contact_reference');
  return !!(hp && hp.value && hp.value.trim());
}

// ══════════════════════════════════════════════════════════════
// ═══ INIT ═══════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
document.addEventListener('keydown', (e)=>{
  if(e.key!=='Escape') return;
  const summaryInfo=document.getElementById('summaryInfoBackdrop');if(summaryInfo&&!summaryInfo.hidden){closeSummaryInfo();return;}
  if(_route==='summary' && curUser){ const anyOpen=document.querySelector('.sheet-overlay.open'); if(!anyOpen){ closeTxDetail(); return; } }
  const notifP=document.getElementById('notifPanel'); if(notifP && notifP.classList.contains('open')){ closeNotifPanel(); return; }
  const picker=document.getElementById('pickerSheet'); if(picker.classList.contains('open')){ closePicker(); return; }
  const usernameS=document.getElementById('usernameSheet'); if(usernameS && usernameS.classList.contains('open')){ closeUsernameSheet(); return; }
  const feedbackS=document.getElementById('feedbackSheet'); if(feedbackS && feedbackS.classList.contains('open')){ closeFeedbackSheet(); return; }
  const roundingS=document.getElementById('roundingInfoSheet'); if(roundingS && roundingS.classList.contains('open')){ closeRoundingInfo(); return; }
  const confirmS=document.getElementById('confirmSheet'); if(confirmS.classList.contains('open')){ closeOrderConfirm(); return; }
  const result=document.getElementById('resultModal'); if(result.style.display==='flex'){ closeResultModal(); return; }
  const supportImage=document.getElementById('supportImageModal'); if(supportImage?.style.display==='flex'){ closeSupportImage(); return; }
  const orderCorrection=document.getElementById('orderCorrectionModal'); if(orderCorrection?.style.display==='flex'){ closeOrderCorrection(); return; }
});
// One toast with the id "net": «no internet» stays until the connection is back,
// then the SAME card turns green and goes away after a few seconds.
const _showOffline=()=>showToast('پەیوەندیت بە ئینتەرنێت بڕاوە','warning','ئینتەرنێت نییە',{id:'net',sticky:true});
window.addEventListener('offline', _showOffline);
window.addEventListener('online', ()=>{
  showToast('ئینتەرنێت دووبارە کار دەکات','success','پەیوەندی گەڕایەوە',{id:'net',duration:3000});
  flushQueuedErrorLogs();
});
if(typeof navigator!=='undefined' && navigator.onLine===false) _showOffline();
window.addEventListener('error', event=>{
  if(!event?.message) return;
  reportAppError(event.error||new Error(event.message),{
    operation:'client_runtime',stage:'window_error',filename:event.filename||null,line:event.lineno||null,column:event.colno||null
  });
});
window.addEventListener('unhandledrejection', event=>{
  reportAppError(event.reason||new Error('Unhandled promise rejection'),{operation:'client_runtime',stage:'unhandled_rejection'});
});

document.addEventListener('DOMContentLoaded', async ()=>{
  const appSplash=document.getElementById('appSplash');
  const appSplashStartedAt=performance.now();
  let appSplashDismissQueued=false;
  // Short and soft: at least 0.5s (the logo's fade-in), closed as soon as the first screen is ready
  // (startApp calls it right after the app shell is shown — data keeps loading behind it), 2.5s at most.
  const dismissAppSplash=()=>{
    if(!appSplash||appSplashDismissQueued)return;
    appSplashDismissQueued=true;
    const wait=Math.max(0,500-(performance.now()-appSplashStartedAt));
    setTimeout(()=>{
      document.body.classList.add('app-entering');
      appSplash.classList.add('is-hidden');
      setTimeout(()=>document.body.classList.remove('app-entering'),450);
    },wait);
  };
  window.__dismissAppSplash=dismissAppSplash;
  setTimeout(dismissAppSplash,2500);
  applyTheme();
  // Public trust numbers need no session — visitors see them on the login screen.
  loadPublicProof();
  document.querySelectorAll('.pass-eye-ico').forEach(el=>{ el.innerHTML=ICON.eye; });
  refreshTrigger('from');
  refreshTrigger('receiveVia');
  if(!window.supabase){
    showAmsg('هەڵەی بارکردنی سیستەم، پەڕەکە نوێ بکەرەوە','err');
    dismissAppSplash();return;
  }
  sb=window.supabase.createClient(SB_URL,SB_KEY,{ auth:{ persistSession:true, autoRefreshToken:true, storageKey:'zex_sb_session' } });
  pxPaintSkeletons();
  try{ if(localStorage.getItem('zex_sb_session') && !authRouteFromLocation()) pxBootShell(routeFromLocation()); }catch(_){}
  sb.auth.onAuthStateChange((_event,nextSession)=>{
    activeSession=nextSession||null;
    if(_event==='SIGNED_OUT'){
      if(typeof resetMyBalance==='function')resetMyBalance();
      if(typeof resetCustomerConveniences==='function')resetCustomerConveniences();
    }
  });
  let session=null;
  try{
    const result=await sb.auth.getSession();
    if(result.error) throw result.error;
    session=result.data.session;
    activeSession=session||activeSession;
  }catch(error){
    showAmsg(kuErr(error?.message)||'کێشەی تۆڕ، پەڕەکە نوێ بکەرەوە','err');
  }
  if(session?.user){
    try{ await startApp(session.user); }catch(e){ pxBootEnd(); throw e; }
  }else if(isTransactionSummaryRoute()){
    pxBootEnd();
    // remember the transaction, sign in, then open it inside the app
    const pending=summaryTokenFromPath();
    try{ if(TX_TOKEN_RE.test(pending)) sessionStorage.setItem('px_pending_summary',pending); }catch(_){}
    setAuthRoute('login',false,true);
    try{ showAmsg('بۆ بینینی پوختەی مامەڵەکە سەرەتا بچۆ ژوورەوە.','ok'); }catch(_){}
  }else{
    pxBootEnd();
    let route=authRouteFromLocation()||'login';
    if((route==='login/otp'||route==='signup/otp')&&!_otpPendingData) route=route.split('/')[0];
    if(route==='forgetpassword/otp'&&!_fpEmail) route='forgetpassword';
    if(route==='newpassword'&&!_fpVerified) route='forgetpassword';
    setAuthRoute(route,false,true);
    try{ const notice=sessionStorage.getItem('px_auth_notice'); if(notice){ sessionStorage.removeItem('px_auth_notice'); showAmsg(notice,'ok'); } }catch(_){}
  }
  dismissAppSplash();
});

// Auth footer shows the same version line as the profile page — change the version only in #mainApp .pfx-version.
(function syncAuthAppVersion(){
  const run=()=>{try{const v=document.querySelector('#mainApp .pfx-version'),a=document.getElementById('authAppVersion');if(v&&a&&v.textContent.trim())a.textContent=v.textContent.trim();}catch(_){}};
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',run); else run();
})();

// ══════════════════════════════════════════════════════════════
// ═══ ACCOUNT DELETION (route "/delete-account")
// ═══  The account is deleted 7 days after the request. Signing in again
// ═══  before then reactivates it. Server: ex_account_deletion_* (Supabase).
// ══════════════════════════════════════════════════════════════
let _daxBlocked=false, _daxBusy=false;
const DAX_ERRORS={
  ACCOUNT_DELETE_BALANCE:'سەرەتا باڵانسەکەت دەربهێنە، پاشان هەژمارەکەت بسڕەوە.',
  ACCOUNT_DELETE_OPEN_ORDERS:'داواکارییەکی تەواونەبووت هەیە. چاوەڕێ بکە تا تەواو دەبێت.',
  ACCOUNT_DELETE_OPEN_PAYOUTS:'داواکاریی دەرهێنانی پارەت هەیە و هێشتا تەواو نەبووە.',
  ACCOUNT_DELETE_STAFF:'هەژماری ستاف لێرەوە ناسڕدرێتەوە.'
};
function daxDate(iso){
  const d=new Date(iso);
  return isNaN(d)?'':d.toLocaleDateString('en-GB',{day:'2-digit',month:'2-digit',year:'numeric'});
}
function daxSync(){
  const btn=document.getElementById('daxBtn'), pass=document.getElementById('daxPass');
  if(btn&&!_daxBusy) btn.disabled=_daxBlocked||!pass||pass.value.length<6;
}
function daxReset(){
  const pass=document.getElementById('daxPass'), err=document.getElementById('daxErr');
  if(pass) pass.value='';
  if(err) err.textContent='';
  daxSync();
}
async function loadAccountDeletionInfo(){
  const box=document.getElementById('daxBlock');
  _daxBlocked=false;
  if(box){ box.hidden=true; box.textContent=''; }
  daxSync();
  if(!curUser||!sb) return;
  try{
    const {data,error}=await sb.rpc('ex_account_deletion_info');
    if(error||!data) return;
    if(data.blocker){
      _daxBlocked=true;
      const text=DAX_ERRORS['ACCOUNT_DELETE_'+data.blocker]||'';
      if(box&&text){
        box.textContent=text;
        if(data.blocker==='BALANCE'){
          const amt=document.createElement('bdi'); amt.dir='ltr'; amt.textContent=formatNum(Number(data.balance_iqd)||0)+' IQD';
          box.prepend('باڵانسی ئێستات: ',amt,'. ');
        }
        box.hidden=false;
      }
    }
  }catch(_){}
  daxSync();
}
async function submitAccountDeletion(){
  if(_daxBusy||_daxBlocked||!curUser||!sb) return;
  const pass=document.getElementById('daxPass'), err=document.getElementById('daxErr'), btn=document.getElementById('daxBtn');
  const password=String(pass?.value||'');
  if(err) err.textContent='';
  if(password.length<6){ if(err) err.textContent='وشەی نهێنی بنووسە'; return; }
  _daxBusy=true;
  if(btn){ btn.disabled=true; btn.classList.add('is-loading'); btn.setAttribute('aria-busy','true'); }
  try{
    // checked by the server: number accounts keep their password outside Supabase Auth
    const check=await pxAuthApi('verify_password',{password},true);
    if(!check.ok){ if(err) err.textContent=check.error||'وشەی نهێنی هەڵەیە'; return; }
    const {data,error}=await sb.rpc('ex_account_deletion_request',{p_reason:null});
    if(error) throw error;
    const when=daxDate(data?.scheduled_for);
    try{ sessionStorage.setItem('px_auth_notice','داواکارییەکەت وەرگیرا. هەژمارەکەت'+(when?' لە '+when:' دوای 7 ڕۆژ')+' دەسڕدرێتەوە. بۆ هەڵوەشاندنەوە، تەنها بچۆرەوە ژوورەوە.'); }catch(_){}
    try{ await sb.auth.signOut({scope:'local'}); }catch(_){}
    try{ location.replace(BASE_PATH+'login'); }catch(_){ location.reload(); }
  }catch(e){
    const code=Object.keys(DAX_ERRORS).find(k=>String(e?.message||'').includes(k));
    if(code){ _daxBlocked=true; const box=document.getElementById('daxBlock'); if(box){ box.textContent=DAX_ERRORS[code]; box.hidden=false; } }
    else if(err) err.textContent=kuErr(e?.message)||'هەڵەیەک ڕووی دا، دووبارە هەوڵ بدەرەوە.';
  }finally{
    _daxBusy=false;
    if(btn){ btn.classList.remove('is-loading'); btn.removeAttribute('aria-busy'); }
    daxSync();
  }
}
// After sign-in: 'active' | 'reactivated' | 'pending' (an old session → signed out) | 'unknown'
async function checkAccountDeletion(){
  if(!sb) return 'unknown';
  try{
    const {data,error}=await sb.rpc('ex_account_deletion_check');
    if(error||!data) return 'unknown';
    if(data.state==='pending'){
      const when=daxDate(data.scheduled_for);
      try{ sessionStorage.setItem('px_auth_notice','هەژمارەکەت'+(when?' لە '+when:'')+' دەسڕدرێتەوە. بۆ چالاککردنەوەی، دووبارە بچۆرەوە ژوورەوە.'); }catch(_){}
      try{ await sb.auth.signOut({scope:'local'}); }catch(_){}
      try{ location.replace(BASE_PATH+'login'); }catch(_){ location.reload(); }
      return 'pending';
    }
    return data.state||'unknown';
  }catch(_){ return 'unknown'; }
}
