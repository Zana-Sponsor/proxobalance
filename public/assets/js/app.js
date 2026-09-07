// ══════════════════════════════════════════════════════════════
// ═══ ICONS (used for dynamically-injected UI) ═══════════════════
// ══════════════════════════════════════════════════════════════
const ICON = {
  spin: '<svg class="icn icn-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 3.6a8.4 8.4 0 1 0 8.4 8.4"/></svg>',
  arrowLeft: '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><path d="M11 6.2 5 12l6 5.8"/></svg>',
  check: '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.8l4.3 4.3L19 7.5"/></svg>',
  send: '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2.5l-9.3 19-3-8.1-8.2-3.1z"/><path d="M12.2 13.5l4-6.8"/></svg>',
  lock: '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="10.5" width="14" height="9" rx="2.2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/></svg>',
  eye: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 12S6 5.8 12 5.8 21.5 12 21.5 12 18 18.2 12 18.2 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.9"/></svg>',
  eyeOff: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 3.5l17 17"/><path d="M10.6 5.7A10.9 10.9 0 0 1 12 5.6c6 0 9.5 6.4 9.5 6.4a15.7 15.7 0 0 1-3.4 4.2M6.5 6.6C3.9 8.4 2.5 12 2.5 12s3.5 6.4 9.5 6.4c1.3 0 2.5-.3 3.6-.7"/><path d="M9.9 10a3 3 0 0 0 4.1 4.1"/></svg>',
  sun: '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4.1"/><path d="M12 2.6v2.3M12 19.1v2.3M4.7 4.7l1.6 1.6M17.7 17.7l1.6 1.6M2.6 12h2.3M19.1 12h2.3M4.7 19.3l1.6-1.6M17.7 6.3l1.6-1.6"/></svg>',
  moon: '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20 14.3A8.4 8.4 0 1 1 9.7 4a7 7 0 0 0 10.3 10.3z"/></svg>',
  swap: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h13.5l-3-3.2"/><path d="M20 16H6.5l3 3.2"/></svg>',
  coins: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="9.3" cy="10" r="5.3"/><path d="M13.2 8a5.3 5.3 0 1 1 0 8.3"/></svg>',
  checkDouble: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2.3 12.5l3.8 3.8L14.5 7.8"/><path d="M9 12.5l3.8 3.8 8.5-8.5"/></svg>',
  phone: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6.6 3.6h3l1.4 4-1.9 1.6a12.2 12.2 0 0 0 5.3 5.3l1.6-1.9 4 1.4v3a1.5 1.5 0 0 1-1.6 1.5A16.7 16.7 0 0 1 4.6 5.2a1.5 1.5 0 0 1 2-1.6z"/></svg>',
  clock: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.3"/><path d="M12 7.6V12l3.1 1.9"/></svg>',
  message: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="5" width="17" height="11" rx="3"/><circle cx="9" cy="10.5" r=".9" fill="currentColor" stroke="none"/><circle cx="12" cy="10.5" r=".9" fill="currentColor" stroke="none"/><circle cx="15" cy="10.5" r=".9" fill="currentColor" stroke="none"/></svg>',
  warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.6 21.5 20H2.5z"/><path d="M12 9.8v4.6"/><circle cx="12" cy="17.3" r=".2" fill="currentColor"/></svg>',
  cross: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.3"/><path d="M12 11v5.2"/><circle cx="12" cy="8" r=".2" fill="currentColor"/></svg>',
  wifiOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 8.8a15.8 15.8 0 0 1 5-3.1M22 8.8a15.8 15.8 0 0 0-7.6-4.1M6.5 12.3a9.8 9.8 0 0 1 4-2M17.5 12.3a9.8 9.8 0 0 0-2.6-1.7M9.7 15.8a5.6 5.6 0 0 1 4.6 0M12 19.3v.1M2 2l20 20"/></svg>',
  telegram: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2.5l-9.3 19-3-8.1-8.2-3.1z"/><path d="M12.2 13.5l4-6.8"/></svg>',
  whatsapp: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M12 2.2a9.8 9.8 0 0 0-8.4 14.8L2.2 21.8l4.9-1.3A9.8 9.8 0 1 0 12 2.2zm0 1.8a8 8 0 0 1 6.9 12l-.2.4.9 3.1-3.2-.9-.4.2a8 8 0 1 1-4-14.8zm-3.5 4.1c-.2 0-.5 0-.7.3-.2.3-.9.8-.9 2s.9 2.4 1 2.6c.1.2 1.8 2.9 4.5 4 2.2.9 2.7.7 3.2.6.5 0 1.6-.6 1.8-1.2.2-.6.2-1.2.2-1.3-.1-.1-.3-.2-.6-.4-.3-.1-1.6-.8-1.9-.9-.2-.1-.4-.1-.6.1-.2.3-.7.9-.9 1.1-.2.2-.3.2-.6.1-.3-.2-1.2-.5-2.3-1.5-.9-.7-1.4-1.7-1.6-2-.2-.3 0-.5.1-.6l.4-.5c.1-.2.2-.3.3-.5.1-.2 0-.4 0-.5C9.6 9 9 7.7 8.7 7.2c-.2-.5-.4-.4-.6-.5h-.5z"/></svg>',
  fastpay: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2.5 4.5 14h6l-1 7.5L18.5 10h-6z"/></svg>',
  fib: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 9.5 12 4l8.5 5.5"/><path d="M5 9.5V19M9 9.5V19M15 9.5V19M19 9.5V19"/><path d="M3.2 19h17.6"/><path d="M3.2 9.5h17.6"/></svg>',
  qicard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2.7" y="5.5" width="18.6" height="13" rx="2.4"/><path d="M2.7 9.8h18.6"/><path d="M6 14.3h5"/></svg>',
  asiacell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20.5v-2.2"/><path d="M8 20.5a5.7 5.7 0 0 1 8 0"/><path d="M4.8 17.3a10.2 10.2 0 0 1 14.4 0"/><path d="M2 14a14.2 14.2 0 0 1 20 0"/></svg>',
  korek: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1.1" fill="currentColor" stroke="none"/><path d="M8.3 15.7a5.2 5.2 0 0 1 7.4 0"/><path d="M5.4 12.8a9.3 9.3 0 0 1 13.2 0"/><path d="M2.6 10a13.4 13.4 0 0 1 18.8 0"/></svg>',
  usdt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.2"/><path d="M8 8.3h8M12 8.3v3M9.3 12.6c0 1.2 1.2 2 2.7 2s2.7-.8 2.7-1.9c0-1-1-1.5-2.7-1.7-1.7-.2-2.7-.7-2.7-1.7 0-1 1.2-1.8 2.7-1.8s2.5.6 2.6 1.5"/><path d="M12 14.6v3.1"/></svg>',
  receive: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.2v10.8"/><path d="M7.3 9.8 12 14.5l4.7-4.7"/><path d="M4 18.3h16"/></svg>',
  image: '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="M21 15.5l-5.5-5.5L5 20"/></svg>',
  banknote: '<svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2.3" y="6.3" width="19.4" height="11.4" rx="2.2"/><circle cx="12" cy="12" r="2.5"/><path d="M5.3 9.3h.01M18.7 14.7h.01"/></svg>'
};

// ══════════════════════════════════════════════════════════════
// ═══ REAL BRAND LOGOS (base64, uniform 220x220) ═════════════════
// ══════════════════════════════════════════════════════════════
const LOGO_B64 = {
  fastpay: "data:image/png;base64,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",
  fib: "data:image/png;base64,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",
  qicard: "data:image/png;base64,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",
  asiacell: "data:image/png;base64,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",
  korek: "data:image/png;base64,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",
};

// ══════════════════════════════════════════════════════════════
// ═══ PAYMENT METHOD META (drives pickers, wallet row, icons) ═══
// ══════════════════════════════════════════════════════════════
let METHOD_META = {
  FastPay:  { label:'FastPay',         color:'#7c3aed', icon:ICON.fastpay,  img:LOGO_B64.fastpay  },
  FIB:      { label:'FIB Bank',        color:'#0ea5a4', icon:ICON.fib,      img:LOGO_B64.fib      },
  QiCard:   { label:'Qi Card',         color:'#2563eb', icon:ICON.qicard,   img:LOGO_B64.qicard   },
  Asiacell: { label:'Asiacell',        color:'#e11d48', icon:ICON.asiacell, img:LOGO_B64.asiacell },
  Korek:    { label:'Korek',           color:'#f59e0b', icon:ICON.korek,    img:LOGO_B64.korek    },
  USDT:     { label:'USDT ($)',        color:'#26a17b', icon:ICON.usdt     }
};
let FROM_OPTIONS = ['FastPay','FIB','QiCard','Asiacell','Korek','USDT'];
let RECEIVE_OPTIONS = ['FastPay','FIB','QiCard'];
// Palette + helpers so any wallet added later in the admin panel (with no
// hardcoded icon) still gets a distinct color and a sensible fallback icon.
const WALLET_PALETTE = ['#7c3aed','#0ea5a4','#2563eb','#e11d48','#f59e0b','#26a17b','#0891b2','#db2777','#65a30d','#9333ea'];
function colorForWalletKey(key){
  let h=0; for(let i=0;i<key.length;i++){ h=(h*31+key.charCodeAt(i))>>>0; }
  return WALLET_PALETTE[h % WALLET_PALETTE.length];
}
function escHtml(s){ return String(s==null?'':s).replace(/[&<>"']/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
// Rebuilds METHOD_META / FROM_OPTIONS / RECEIVE_OPTIONS from whatever rows
// currently exist in ex_wallets, so wallets added/edited/removed in the
// admin panel show up here immediately (via subscribeWalletsUser) without
// needing a code change or page reload.
function rebuildWalletOptions(){
  const rows = Object.keys(WALLET_DATA).map(k=>({ key:k, ...WALLET_DATA[k] })).filter(w=>w.key);
  rows.sort((a,b)=>(a.sort_order??0)-(b.sort_order??0));
  if(!rows.length) return; // keep existing defaults if ex_wallets is empty/unreachable
  const newMeta = {};
  rows.forEach(w=>{
    const known = METHOD_META[w.key];
    newMeta[w.key] = {
      label: w.name || w.key,
      color: (known && known.color) || colorForWalletKey(w.key),
      icon: (known && known.icon) || ICON.coins,
      img: w.image_url || (known && known.img) || null
    };
  });
  METHOD_META = newMeta;
  FROM_OPTIONS = rows.filter(w=>w.allow_from!==false).map(w=>w.key);
  RECEIVE_OPTIONS = rows.filter(w=>w.allow_receive).map(w=>w.key);
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
  const cls = 'method-icon'+(sizeClass?' '+sizeClass:'')+(m.img?' has-img':'');
  const idAttr = forceId ? ' id="'+forceId+'"' : '';
  const bgAttr = m.img ? '' : ' style="background:'+m.color+'"';
  const inner = m.img ? '<img src="'+m.img+'" alt="'+m.label+'">' : m.icon;
  return '<span class="'+cls+'"'+idAttr+bgAttr+'>'+inner+'</span>';
}
function refreshTrigger(which){
  const selId = which==='from' ? 'from' : 'receiveVia';
  const val = document.getElementById(selId).value;
  const m = METHOD_META[val]; if(!m) return;
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
      + '>'
      + methodIconHTML(key)
      + '<span class="sheet-option-text"><span class="sheet-option-name">'+escHtml(m.label)+'</span>'
      + (reason?'<span class="sheet-option-sub">'+reason+'</span>':'')+'</span>'
      + '<span class="sheet-option-check"><svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.8l4.3 4.3L19 7.5"/></svg></span>'
      + '</button>';
  }).join('');
  openSheet(document.getElementById('pickerSheet'));
}
function closePicker(){
  closeSheet(document.getElementById('pickerSheet'));
}
function selectPickerOption(value){
  const which=_pickerContext; if(!which) return;
  const selId = which==='from' ? 'from' : 'receiveVia';
  document.getElementById(selId).value = value;
  refreshTrigger(which);
  closePicker();
  if(which==='from'){ updateWallet(); } else { updatePlaceholder(); calc(); }
}

// ══════════════════════════════════════════════════════════════
// ═══ TOASTS ═════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
const TOAST_ICON = { success:ICON.check, error:ICON.cross, warning:ICON.warn, info:ICON.info };
function showToast(message, type='info', title){
  type = TOAST_ICON[type] ? type : 'info';
  const container = document.getElementById('toastContainer');
  const el = document.createElement('div');
  el.className = 'toast '+type;
  el.innerHTML =
    '<span class="toast-ico">'+TOAST_ICON[type]+'</span>'
    + '<span class="toast-text">'
      + (title?'<div class="toast-title">'+title+'</div>':'')
      + '<div class="toast-msg">'+message+'</div>'
    + '</span>'
    + '<button type="button" class="toast-x" aria-label="داخستن"><svg class="icn icn-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 6l12 12M18 6L6 18"/></svg></button>';
  const remove=()=>{ el.classList.add('leaving'); setTimeout(()=>el.remove(),220); };
  el.querySelector('.toast-x').onclick=remove;
  container.appendChild(el);
  const life = type==='error' ? 5200 : 3800;
  setTimeout(remove, life);
  while(container.children.length>3) container.removeChild(container.firstChild);
}

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
  if(err){ err.innerHTML=ICON.warn+'<span>'+msg+'</span>'; err.classList.add('show'); }
}
function clearFieldError(inputId){
  const inp=document.getElementById(inputId); const err=document.getElementById(inputId+'Error');
  if(inp) inp.classList.remove('has-error');
  if(err){ err.classList.remove('show'); }
}
function clearAllOrderFieldErrors(){ ['amt','userSenderName','userSenderPhone','userPhone','fileInput'].forEach(clearFieldError); }

function onFileSelected(input){
  clearFieldError('fileInput');
  const file=input && input.files && input.files[0];
  const name=document.getElementById('filePickerName');
  const meta=document.getElementById('filePickerMeta');
  const picker=document.querySelector('label[for="fileInput"].file-picker');
  if(!name || !meta || !picker) return;
  picker.classList.toggle('selected', !!file);
  name.textContent=file ? file.name : 'وێنەی پسووڵە هەڵبژێرە';
  meta.textContent=file ? ((file.size/1024/1024).toFixed(file.size>=1048576?1:2)+' MB') : 'JPG، PNG یان WEBP';
}

// ══════════════════════════════════════════════════════════════
// ═══ NOTIFICATIONS (ex_notifications table — bell / panel / bar) ═
// ══════════════════════════════════════════════════════════════
let _notifChannel=null, _notifItems=[];
function _notifKind(type){
  if(type==='order_approved') return 'ok';
  if(type==='order_rejected') return 'no';
  if(type==='order_status')   return 'upd';
  return 'msg';
}
function _notifIcon(type){
  const k=_notifKind(type);
  if(k==='ok')  return ICON.badgeCheck;
  if(k==='no')  return ICON.xCircle;
  if(k==='upd') return ICON.refresh;
  return ICON.megaphone;
}
function _notifColor(type){
  const k=_notifKind(type);
  if(k==='ok')  return 'var(--success)';
  if(k==='no')  return 'var(--error)';
  if(k==='upd') return 'var(--info)';
  return 'var(--secondary)';
}
// "٥ خولەک لەمەوپێش" — short, human, and much easier to scan than a full date
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

async function loadNotifications(){
  try{
    const {data}=await sb.from('ex_notifications').select('*').eq('user_id',curUser.id).order('created_at',{ascending:false}).limit(30);
    _notifItems = data||[];
  }catch(_){ _notifItems=[]; }
  renderNotifPanel();
  updateNotifBadge();
  const latestUnread = _notifItems.find(n=>!n.is_read);
  if(latestUnread) showNotifBar(latestUnread); else hideNotifBar();

  if(_notifChannel){ try{ sb.removeChannel(_notifChannel); }catch(_){} }
  _notifChannel = sb.channel('ex_notifications_'+curUser.id)
    .on('postgres_changes',{event:'INSERT',schema:'public',table:'ex_notifications',filter:'user_id=eq.'+curUser.id}, (payload)=>{
      _notifItems.unshift(payload.new);
      renderNotifPanel(); updateNotifBadge(); showNotifBar(payload.new);
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

function renderNotifPanel(){
  const body=document.getElementById('notifPanelBody');
  if(!body) return;
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
    html += '<button type="button" class="notif-item '+k+(n.is_read?'':' unread')+'" onclick="openNotifItem(\''+n.id+'\')">'
      + '<span class="notif-item-ico '+k+'">'+_notifIcon(n.type)+'</span>'
      + '<span class="notif-item-text">'
        + '<span class="notif-item-title">'+escHtml(n.title||'')+(n.is_read?'':'<span class="notif-unread-dot"></span>')+'</span>'
        + '<span class="notif-item-msg">'+escHtml(n.message||'')+'</span>'
        + '<span class="notif-item-time">'+ICON.clock+timeAgo(n.created_at)+'</span>'
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
  if(item && item.order_id){
    const o=_orders.find(x=>x.id===item.order_id);
    if(o){
      closeNotifPanel();
      const box=document.getElementById('txSearch');
      _txQuery=orderCodeOf(o).toLowerCase(); if(box) box.value=orderCodeOf(o);
      const clr=document.getElementById('txSearchClear'); if(clr) clr.classList.add('show');
      navigate('transactions');
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
  document.getElementById('notifBarTitle').textContent = n.title;
  document.getElementById('notifBarMsg').textContent = n.message;
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
function applyTheme(t){
  document.documentElement.setAttribute('data-theme', t);
  try{ localStorage.setItem('zex_theme', t); }catch(_){}
  document.querySelectorAll('.theme-toggle-ico').forEach(el=>{ el.innerHTML = t==='dark' ? ICON.sun : ICON.moon; });
  const meta=document.getElementById('themeColorMeta');
  if(meta) meta.setAttribute('content', t==='dark' ? '#0b0e14' : '#f2f4f9');
}
function toggleTheme(){
  const cur = document.documentElement.getAttribute('data-theme')==='light' ? 'light':'dark';
  applyTheme(cur==='dark' ? 'light':'dark');
}

// ══════════════════════════════════════════════════════════════
// ═══ SUPABASE + FIREBASE (news only) ═══════════════════════════
// ══════════════════════════════════════════════════════════════
const firebaseConfig = { apiKey: "AIzaSyB056_g2Y3AJjtjG9715FgtXIhtjFcMPPU", authDomain: "zana-exchange.firebaseapp.com", databaseURL: "https://zana-exchange-default-rtdb.firebaseio.com", projectId: "zana-exchange" };
firebase.initializeApp(firebaseConfig);
const db = firebase.database();

// PROXO BALANCE now runs on its own dedicated Supabase project — fully separate
// auth.users from Proxo/other apps (no shared identity, no shared tables).
const SB_URL=atob('aHR0cHM6Ly9weWN4dXVnb2Jsa3NsdndlYnh1dS5zdXBhYmFzZS5jbw==');
const SB_KEY=atob('ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnBjM01pT2lKemRYQmhZbUZ6WlNJc0luSmxaaUk2SW5CNVkzaDFkV2R2WW14cmMyeDJkMlZpZUhWMUlpd2ljbTlzWlNJNkltRnViMjRpTENKcFlYUWlPakUzT0RZeU1UazNPVGtzSW1WNGNDSTZNakV3TVRjNU5UYzVPWDAuVlJSd3hubnVMc19XT1J1VlVPM29YM0NMeHJQdGdHX3Vld0lKYUdyem5fcw==');
let sb, curUser=null, curProfile=null, RATES={};
const N8N_WEBHOOK = 'https://email.proxopages.com/webhook/otp_exchange';

let _newsItems = []; // [{text, action}]
let _newsIdx = 0;
let _newsTimer = null;
function newsCursorFor(item){ return (item && item.action && item.action.type && item.action.type!=='none') ? 'pointer' : 'default'; }
function showNewsItem(i){
    const txt = document.getElementById('newsText');
    txt.style.opacity = '0';
    setTimeout(()=>{
        const item = _newsItems[i] || {};
        txt.innerText = item.text || '';
        txt.style.opacity = '1';
        document.getElementById('newsBanner').style.cursor = newsCursorFor(item);
    }, 250);
}
function startNewsRotation(intervalSec){
    if(_newsTimer){ clearInterval(_newsTimer); _newsTimer=null; }
    if(_newsItems.length <= 1) return; // nothing to slide between
    const ms = Math.max(2, Number(intervalSec)||5) * 1000;
    _newsTimer = setInterval(()=>{
        _newsIdx = (_newsIdx+1) % _newsItems.length;
        showNewsItem(_newsIdx);
    }, ms);
}
function onNewsBannerClick(){
    const item = _newsItems[_newsIdx];
    const action = item && item.action;
    if(!action || action.type==='none') return;
    if(action.type==='url' && action.url){
        window.open(action.url, '_blank', 'noopener');
    }else if(action.type==='wallet' && action.from){
        if(FROM_OPTIONS.includes(action.from)){
            document.getElementById('from').value = action.from;
            updateWallet();
        }
        if(action.to && RECEIVE_OPTIONS.includes(action.to) && routeAllowed(document.getElementById('from').value, action.to)){
            document.getElementById('receiveVia').value = action.to;
            updatePlaceholder();
            calc();
        }
        const trig = document.getElementById('fromTrigger');
        if(trig) trig.scrollIntoView({behavior:'smooth', block:'center'});
    }
}
function listenToNews() {
    db.ref('announcement').on('value', snap => {
        const data = snap.val();
        // supports both the new {items:[{text,action}]} shape and the old single {text} shape
        let items = (data && Array.isArray(data.items)) ? data.items.map(x=>{
            if(typeof x==='string') return {text:x, action:{type:'none'}};
            return {text:(x&&x.text)||'', action:(x&&x.action)||{type:'none'}};
        }).filter(it=>it.text && String(it.text).trim()) : [];
        if(!items.length && data && data.text) items = [{text:data.text, action:{type:'none'}}];
        if(data && data.show && items.length){
            _newsItems = items;
            _newsIdx = 0;
            document.getElementById('newsText').style.opacity = '1';
            document.getElementById('newsText').innerText = _newsItems[0].text;
            document.getElementById('newsBanner').style.cursor = newsCursorFor(_newsItems[0]);
            document.getElementById('newsBanner').style.display = 'flex';
            startNewsRotation(data.interval);
        } else {
            document.getElementById('newsBanner').style.display = 'none';
            if(_newsTimer){ clearInterval(_newsTimer); _newsTimer=null; }
        }
    });
}

// ══════════════════════════════════════════════════════════════
// ═══ OTP SYSTEM (own webhook + own ex_otp_codes table) ═════════
// ══════════════════════════════════════════════════════════════
let _otpEmail='', _otpPendingData=null, _otpTimer=null, _otpPurpose='login';
const OTP_MAX_ATTEMPTS=5, OTP_BAN_MS=10*60*1000, OTP_SEND_MAX=3;
function _rlKey(email){return 'zex_otp_rl_'+btoa(email.toLowerCase().trim());}
function _sendKey(email){return 'zex_otp_send_'+btoa(email.toLowerCase().trim());}

function otpSendCheck(email){
  try{ const raw=localStorage.getItem(_sendKey(email)); if(!raw) return {ok:true};
    const d=JSON.parse(raw); const now=Date.now();
    if(d.banUntil && d.banUntil>now){ const rem=Math.ceil((d.banUntil-now)/1000); const m=Math.floor(rem/60),s=rem%60; return {ok:false,remaining:m+':'+(s<10?'0':'')+s}; }
    if(d.banUntil && d.banUntil<=now) localStorage.removeItem(_sendKey(email));
    return {ok:true};
  }catch(_){ return {ok:true}; }
}
function otpSendRecord(email){
  try{ const now=Date.now(); const raw=localStorage.getItem(_sendKey(email)); let d=raw?JSON.parse(raw):{sends:0};
    if(d.banUntil && d.banUntil>now) return {ok:false};
    d.sends=(d.sends||0)+1; if(d.sends>=OTP_SEND_MAX){ d.banUntil=now+OTP_BAN_MS; d.sends=0; }
    localStorage.setItem(_sendKey(email),JSON.stringify(d)); return {ok:true};
  }catch(_){ return {ok:true}; }
}
function otpSendClear(email){ try{ localStorage.removeItem(_sendKey(email)); }catch(_){} }

function otpRateCheck(email){
  try{ const raw=localStorage.getItem(_rlKey(email)); if(!raw) return {ok:true};
    const d=JSON.parse(raw); const now=Date.now();
    if(d.banUntil && d.banUntil>now){ const rem=Math.ceil((d.banUntil-now)/1000); const m=Math.floor(rem/60),s=rem%60; return {ok:false,remaining:m+':'+(s<10?'0':'')+s}; }
    if(d.banUntil && d.banUntil<=now) localStorage.removeItem(_rlKey(email));
    return {ok:true};
  }catch(_){ return {ok:true}; }
}
function otpRateRecord(email){
  try{ const now=Date.now(); const raw=localStorage.getItem(_rlKey(email)); let d=raw?JSON.parse(raw):{attempts:0};
    if(d.banUntil && d.banUntil>now){ const rem=Math.ceil((d.banUntil-now)/1000); const m=Math.floor(rem/60),s=rem%60; return {ok:false,remaining:m+':'+(s<10?'0':'')+s}; }
    d.attempts=(d.attempts||0)+1;
    if(d.attempts>=OTP_MAX_ATTEMPTS){ d.banUntil=now+OTP_BAN_MS; d.attempts=0; localStorage.setItem(_rlKey(email),JSON.stringify(d)); return {ok:false,remaining:'10:00'}; }
    localStorage.setItem(_rlKey(email),JSON.stringify(d)); return {ok:true,attemptsLeft:OTP_MAX_ATTEMPTS-d.attempts};
  }catch(_){ return {ok:true}; }
}
function otpRateClear(email){ try{ localStorage.removeItem(_rlKey(email)); }catch(_){} }

async function requestOtp(email, purpose='login'){
  const sendChk=otpSendCheck(email);
  if(!sendChk.ok) return {success:false,message:'ناردنی کۆد بۆ ئەم ئیمەیلە قفڵکراوە — تکایە '+sendChk.remaining+' خولەکی تر هەوڵ بدەرەوە'};
  try{
    const res=await fetch(N8N_WEBHOOK,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'request_otp',email,purpose})});
    let data={}; try{ const txt=await res.text(); if(txt.trim()) data=JSON.parse(txt); }catch(_){}
    if(res.ok && data.success!==false){ otpSendRecord(email); return {success:true,message:data.message||'کۆدەکە نێردرا'}; }
    return {success:false,message:data.message||'هەڵەی ناردنی کۆد'};
  }catch(e){ return {success:false,message:'هەڵەی تۆڕ: '+e.message}; }
}

async function verifyOtpCode(email, code, purpose=null){
  try{
    if(!sb) return {success:false,message:'سیستەم ئامادە نییە، دووبارە هەوڵ بدەرەوە'};
    const codeStr=String(code).trim(), emailStr=String(email).trim();
    const {data:ok,error}=await sb.rpc('ex_verify_otp',{p_email:emailStr,p_code:codeStr,p_purpose:purpose});
    if(error) return {success:false,message:'هەڵەی تۆڕ: '+error.message};
    if(!ok) return {success:false,message:'کۆدی هەڵە یان کاتی تێپەڕیوە'};
    otpRateClear(email); otpSendClear(email);
    return {success:true,message:'دڵنیاکراوە'};
  }catch(e){ return {success:false,message:'هەڵەی تۆڕ: '+e.message}; }
}

function togglePass(inputId,btn){
  const inp=document.getElementById(inputId); if(!inp) return;
  const show=inp.type==='password'; inp.type=show?'text':'password';
  const ic=btn.querySelector('.pass-eye-ico'); if(ic) ic.innerHTML=show?ICON.eye:ICON.eyeOff;
}

// ══════════════════════════════════════════════════════════════
// ═══ AUTH STEP NAVIGATION ═══════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let authCurrentStep='email', _authEmail='', _authName='', _authIsNewUser=false;

function _renderStepDots(step){
  const steps=_authIsNewUser?['email','name','pass']:['email','pass'];
  const track=document.getElementById('authStepsTrack'); if(!track) return;
  const idx=steps.indexOf(step);
  track.innerHTML=steps.map((s,i)=>{ let cls='auth-step-dot'; if(i<idx) cls+=' done'; else if(i===idx) cls+=' active'; return '<div class="'+cls+'"></div>'; }).join('');
}
function goAuthStep(step){
  authCurrentStep=step;
  ['authStepEmail','authStepName','authStepPass'].forEach(id=>{ const el=document.getElementById(id); if(el) el.style.display='none'; });
  document.getElementById('otpStep').style.display='none';
  document.getElementById('forgotStep').style.display='none';
  const map={email:'authStepEmail',name:'authStepName',pass:'authStepPass'};
  const el=document.getElementById(map[step]); if(el) el.style.display='block';
  _renderStepDots(step);
  setTimeout(()=>{
    if(step==='email') document.getElementById('authEmail')?.focus();
    else if(step==='name') document.getElementById('authName')?.focus();
    else if(step==='pass') document.getElementById('authPass')?.focus();
  },60);
}
function _showStepMsg(id,text,type){ const el=document.getElementById(id); if(!el) return; el.textContent=text; el.className='amsg '+type; el.style.display='block'; }
function showAmsg(t,c){ const el=document.getElementById('authMsg'); el.textContent=t; el.className='amsg '+c; el.style.display='block'; }

async function nextAuthStep(from){
  ['authMsgEmail','authMsgName','authMsg'].forEach(id=>{ const el=document.getElementById(id); if(el) el.style.display='none'; });
  if(from==='email'){
    const email=document.getElementById('authEmail').value.trim();
    if(!email){ _showStepMsg('authMsgEmail','ئیمەیل بنووسە','err'); return; }
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)){ _showStepMsg('authMsgEmail','فۆرماتی ئیمەیل هەڵەیە','err'); return; }
    const btn=document.getElementById('emailNextBtn');
    btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...';
    try{
      const {data:exists,error}=await sb.rpc('ex_email_exists',{p_email:email});
      if(error) throw error;
      _authEmail=email; _authIsNewUser=!exists;
      if(exists){
        document.getElementById('passStepTitle').textContent='وشەی نهێنی';
        document.getElementById('passStepSub').textContent='وشەی نهێنیت بنووسە بۆ چوونەژوورەوە';
        document.getElementById('authBtnTxt').textContent='چوونەژوورەوە';
        document.getElementById('forgotLinkWrap').style.display='block';
        goAuthStep('pass');
      } else {
        goAuthStep('name');
      }
    }catch(e){
      _showStepMsg('authMsgEmail','هەڵەی تۆڕ، دووبارە هەوڵ بدەرەوە','err');
    }finally{
      btn.disabled=false; btn.innerHTML='<span>دواتر</span> '+ICON.arrowLeft;
    }
  } else if(from==='name'){
    const name=document.getElementById('authName').value.trim();
    if(!name){ _showStepMsg('authMsgName','ناوت بنووسە','err'); return; }
    _authName=name;
    document.getElementById('passStepTitle').textContent='وشەی نهێنیی نوێ';
    document.getElementById('passStepSub').textContent='وشەیەکی نهێنی دابنێ — کەمترین ٦ پیت';
    document.getElementById('authBtnTxt').textContent='تۆمارکردن';
    document.getElementById('forgotLinkWrap').style.display='none';
    goAuthStep('pass');
  } else if(from==='pass'){
    doAuth();
  }
}

async function doAuth(){
  const pass=document.getElementById('authPass').value;
  const btn=document.getElementById('authBtn');
  if(!pass){ showAmsg('وشەی نهێنی بنووسە','err'); return; }
  if(pass.length<6){ showAmsg('وشەی نهێنی دەبێت کەمترین ٦ پیت بێت','err'); return; }
  btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...';
  try{
    if(_authIsNewUser){
      _otpPendingData={pass,name:_authName}; _otpPurpose='signup';
    } else {
      try{ await sb.auth.signOut(); }catch(_){}
      const {error:chkErr}=await sb.auth.signInWithPassword({email:_authEmail,password:pass});
      if(chkErr){ showAmsg('ئیمەیل یان وشەی نهێنی هەڵەیە','err'); return; }
      try{ await sb.auth.signOut(); }catch(_){}
      _otpPendingData={pass}; _otpPurpose='login';
    }
    btn.innerHTML=ICON.spin+' کۆد دەنێردرێت...';
    const result=await requestOtp(_authEmail,_otpPurpose);
    if(!result.success){ showAmsg(result.message||'هەڵەی ناردنی کۆد','err'); return; }
    showOtpStep(_authEmail);
  }catch(e){
    showAmsg(kuErr(e.message)||'هەڵەیەک ڕووی دا','err');
  }finally{
    btn.disabled=false; btn.innerHTML='<span id="authBtnTxt">'+(_authIsNewUser?'تۆمارکردن':'چوونەژوورەوە')+'</span> '+ICON.arrowLeft;
  }
}

// ══ OTP STEP ══
function showOtpStep(email){
  _otpEmail=email;
  document.getElementById('otpEmailLbl').textContent='کۆدی ٦ ژمارە بۆ '+email+' نێردرا';
  ['authStepEmail','authStepName','authStepPass'].forEach(id=>{ const el=document.getElementById(id); if(el) el.style.display='none'; });
  document.getElementById('forgotStep').style.display='none';
  document.getElementById('otpStep').style.display='block';
  ['otp1','otp2','otp3','otp4','otp5','otp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  document.getElementById('otpMsg').style.display='none';
  document.getElementById('otpResendBtn').style.display='none';
  document.getElementById('otp1').focus();
  startOtpTimer(600);
}
function cancelOtp(){ clearInterval(_otpTimer); document.getElementById('otpStep').style.display='none'; goAuthStep('email'); _otpPendingData=null; }
function startOtpTimer(seconds){
  clearInterval(_otpTimer); let remaining=seconds;
  function tick(){
    if(remaining<=0){ clearInterval(_otpTimer); document.getElementById('otpTimerVal').textContent='0:00'; document.getElementById('otpTimerWrap').style.color='var(--err)'; document.getElementById('otpResendBtn').style.display='flex'; return; }
    const m=Math.floor(remaining/60),s=remaining%60; const el=document.getElementById('otpTimerVal'); if(el) el.textContent=m+':'+(s<10?'0':'')+s; remaining--;
  }
  tick(); _otpTimer=setInterval(tick,1000);
}
function otpMove(el,prevId,nextId){
  el.value=el.value.replace(/[^0-9]/g,'').slice(-1);
  if(el.value&&nextId) document.getElementById(nextId)?.focus();
  const code=['otp1','otp2','otp3','otp4','otp5','otp6'].map(id=>document.getElementById(id)?.value||'').join('');
  if(code.length===6) verifyOtp();
}
function otpBack(e,el,prevId){ if(e.key==='Backspace'&&!el.value&&prevId) document.getElementById(prevId)?.focus(); }
function showOtpMsg(t,c){ const el=document.getElementById('otpMsg'); el.textContent=t; el.className='amsg '+c; el.style.display='block'; }

let _banIntervals={};
function startBanCountdown(email,msgElId,resendBtnId){
  if(_banIntervals[msgElId]) clearInterval(_banIntervals[msgElId]);
  const btn=resendBtnId?document.getElementById(resendBtnId):null; if(btn) btn.style.display='none';
  function tick(){
    const c=otpRateCheck(email); const el=document.getElementById(msgElId);
    if(!el){ clearInterval(_banIntervals[msgElId]); return; }
    if(!c.ok){ el.textContent='تکایە '+c.remaining+' خولەکی تر هەوڵ بدەرەوە'; el.className='amsg err'; el.style.display='block'; }
    else { clearInterval(_banIntervals[msgElId]); el.textContent='ئێستا دەتوانیت دووبارە کۆد داوا بکەیت'; el.className='amsg ok'; if(btn) btn.style.display='flex'; }
  }
  tick(); _banIntervals[msgElId]=setInterval(tick,1000);
}

let _otpVerifying=false;
async function verifyOtp(){
  if(_otpVerifying) return;
  const code=['otp1','otp2','otp3','otp4','otp5','otp6'].map(id=>document.getElementById(id)?.value||'').join('');
  if(code.length<6){ showOtpMsg('کۆدەکە تەواو بنووسە','err'); return; }
  const rlChk=otpRateCheck(_otpEmail);
  if(!rlChk.ok){ showOtpMsg('قفڵکراوە — تکایە '+rlChk.remaining+' خولەکی تر هەوڵ بدەرەوە','err'); startBanCountdown(_otpEmail,'otpMsg','otpResendBtn'); return; }
  _otpVerifying=true;
  const btn=document.getElementById('otpVerifyBtn'); btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...';
  const result=await verifyOtpCode(_otpEmail,code,_otpPurpose);
  _otpVerifying=false;
  if(!result.success){
    const rl=otpRateRecord(_otpEmail);
    if(rl && !rl.ok){ showOtpMsg('زۆر جار هەوڵت دا — تکایە '+rl.remaining+' خولەکی تر هەوڵ بدەرەوە','err'); startBanCountdown(_otpEmail,'otpMsg','otpResendBtn'); }
    else showOtpMsg(result.message||'کۆدی هەڵە','err');
    btn.disabled=false; btn.innerHTML=ICON.check+' دڵنیاکردنەوە'; return;
  }
  clearInterval(_otpTimer);
  showOtpMsg('سەرکەوتوو بوو!','ok');
  setTimeout(async()=>{
    try{
      let user;
      if(_authIsNewUser){
        showOtpMsg('هەژمار دروستدەکرێت...','ok');
        const {data,error}=await sb.auth.signUp({ email:_otpEmail, password:_otpPendingData.pass, options:{ data:{ full_name:_otpPendingData.name, source:'exchange' } } });
        if(error) throw error;
        user=data.user;
        if(!data.session){
          const {data:ld,error:le}=await sb.auth.signInWithPassword({email:_otpEmail,password:_otpPendingData.pass});
          if(!le && ld?.user) user=ld.user;
        }
      } else {
        const {data,error}=await sb.auth.signInWithPassword({email:_otpEmail,password:_otpPendingData.pass});
        if(error) throw error;
        user=data.user;
      }
      if(!user) throw new Error('هەڵەیەک ڕووی دا');
      // track.js is loaded after app.js and owns the server-side IP capture.
      // Send immediately while the freshly issued Supabase session is present;
      // its Authorization header lets /api/track attach this IP to the account.
      if(typeof window.trackEvent==='function'){
        window.trackEvent(_authIsNewUser?'signup':'login');
      }
      await startApp(user);
    }catch(e){
      showOtpMsg(kuErr(e.message)||'هەڵەیەک ڕووی دا','err');
      btn.disabled=false; btn.innerHTML=ICON.check+' دڵنیاکردنەوە';
    }
  },800);
}

async function resendOtp(){
  const chk=otpRateCheck(_otpEmail);
  if(!chk.ok){ showOtpMsg('تکایە '+chk.remaining+' خولەکی تر هەوڵ بدەرەوە','err'); startBanCountdown(_otpEmail,'otpMsg','otpResendBtn'); return; }
  document.getElementById('otpResendBtn').style.display='none';
  document.getElementById('otpTimerWrap').style.color='';
  showOtpMsg('ناردن...','ok');
  const result=await requestOtp(_otpEmail,_otpPurpose);
  if(result.success){ showOtpMsg('کۆدی نوێ نێردرا','ok'); ['otp1','otp2','otp3','otp4','otp5','otp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; }); document.getElementById('otp1')?.focus(); startOtpTimer(600); }
  else { showOtpMsg(result.message||'هەڵە','err'); document.getElementById('otpResendBtn').style.display='flex'; }
}

// ══════════════════════════════════════════════════════════════
// ═══ FORGOT PASSWORD ═══════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let _fpTimer=null, _fpEmail='';
function showForgotStep(){
  ['authStepEmail','authStepName','authStepPass'].forEach(id=>{ const el=document.getElementById(id); if(el) el.style.display='none'; });
  document.getElementById('otpStep').style.display='none';
  document.getElementById('forgotStep').style.display='block';
  document.getElementById('fpStepA').style.display='block';
  document.getElementById('fpStepB').style.display='none';
  document.getElementById('fpStepC').style.display='none';
  document.getElementById('forgotEmail').value='';
  document.getElementById('fpMsgA').style.display='none';
  document.getElementById('forgotEmail').focus();
}
function cancelForgotStep(){ clearInterval(_fpTimer); document.getElementById('forgotStep').style.display='none'; goAuthStep('email'); }
function fpBackToA(){ clearInterval(_fpTimer); document.getElementById('fpStepB').style.display='none'; document.getElementById('fpStepA').style.display='block'; document.getElementById('fpMsgA').style.display='none'; }
function fpShowMsg(step,t,c){ const el=document.getElementById('fpMsg'+step); el.textContent=t; el.className='amsg '+c; el.style.display='block'; }
function fpStartTimer(sec){
  clearInterval(_fpTimer); let rem=sec;
  function tick(){
    if(rem<=0){ clearInterval(_fpTimer); document.getElementById('fpTimerVal').textContent='0:00'; document.getElementById('fpTimerWrap').style.color='var(--err)'; document.getElementById('fpResendBtn').style.display='flex'; return; }
    const m=Math.floor(rem/60),s=rem%60; const el=document.getElementById('fpTimerVal'); if(el) el.textContent=m+':'+(s<10?'0':'')+s; rem--;
  }
  tick(); _fpTimer=setInterval(tick,1000);
}
function fpOtpMove(el,prevId,nextId){
  el.value=el.value.replace(/[^0-9]/g,'').slice(-1);
  if(el.value&&nextId) document.getElementById(nextId)?.focus();
  const code=['fp1','fp2','fp3','fp4','fp5','fp6'].map(id=>document.getElementById(id)?.value||'').join('');
  if(code.length===6) doForgotVerifyOtp();
}
function fpOtpBack(e,el,prevId){ if(e.key==='Backspace'&&!el.value&&prevId) document.getElementById(prevId)?.focus(); }

async function fpResendOtp(){
  const chk=otpRateCheck(_fpEmail);
  if(!chk.ok){ fpShowMsg('B','تکایە '+chk.remaining+' خولەکی تر هەوڵ بدەرەوە','err'); startBanCountdown(_fpEmail,'fpMsgB','fpResendBtn'); return; }
  document.getElementById('fpResendBtn').style.display='none';
  document.getElementById('fpTimerWrap').style.color='';
  fpShowMsg('B','ناردن...','ok');
  const result=await requestOtp(_fpEmail,'reset_password');
  if(result.success){ fpShowMsg('B','کۆدی نوێ نێردرا','ok'); ['fp1','fp2','fp3','fp4','fp5','fp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; }); document.getElementById('fp1')?.focus(); fpStartTimer(600); }
  else { fpShowMsg('B',result.message||'هەڵەی ناردن','err'); document.getElementById('fpResendBtn').style.display='flex'; }
}

async function doForgotSendOtp(){
  const email=document.getElementById('forgotEmail').value.trim();
  if(!email){ fpShowMsg('A','ئیمەیلەکەت بنووسە','err'); return; }
  const btn=document.getElementById('forgotSendBtn');
  btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...';
  try{
    const {data:exists,error}=await sb.rpc('ex_email_exists',{p_email:email});
    if(error) throw {message:'هەڵەی پشکنین، دووبارە هەوڵ بدەرەوە'};
    if(!exists){ fpShowMsg('A','ئەم ئیمەیلە تۆمارنەکراوە','err'); btn.disabled=false; btn.innerHTML=ICON.send+' ناردنی کۆد'; return; }
  }catch(e){ fpShowMsg('A',e.message||'هەڵەی پشکنین','err'); btn.disabled=false; btn.innerHTML=ICON.send+' ناردنی کۆد'; return; }
  btn.innerHTML=ICON.spin+' دەنێردرێت...';
  const result=await requestOtp(email,'reset_password');
  btn.disabled=false; btn.innerHTML=ICON.send+' ناردنی کۆد';
  if(!result.success){ fpShowMsg('A',result.message||'هەڵەی ناردنی کۆد','err'); return; }
  _fpEmail=email;
  document.getElementById('fpOtpLbl').textContent='کۆدی ٦ ژمارە بۆ '+email+' نێردرا';
  ['fp1','fp2','fp3','fp4','fp5','fp6'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  document.getElementById('fpMsgB').style.display='none';
  document.getElementById('fpResendBtn').style.display='none';
  document.getElementById('fpTimerWrap').style.color='';
  document.getElementById('fpStepA').style.display='none';
  document.getElementById('fpStepB').style.display='block';
  fpStartTimer(600);
  document.getElementById('fp1')?.focus();
}

let _fpVerifying=false;
async function doForgotVerifyOtp(){
  if(_fpVerifying) return;
  const code=['fp1','fp2','fp3','fp4','fp5','fp6'].map(id=>document.getElementById(id)?.value||'').join('');
  if(code.length<6){ fpShowMsg('B','کۆدەکە تەواو بنووسە','err'); return; }
  const rlChk=otpRateCheck(_fpEmail);
  if(!rlChk.ok){ fpShowMsg('B','قفڵکراوە — تکایە '+rlChk.remaining+' خولەکی تر هەوڵ بدەرەوە','err'); startBanCountdown(_fpEmail,'fpMsgB','fpResendBtn'); return; }
  _fpVerifying=true;
  const btn=document.getElementById('fpVerifyBtn'); btn.disabled=true; btn.innerHTML=ICON.spin+' پشکنین...';
  const result=await verifyOtpCode(_fpEmail,code,'reset_password');
  _fpVerifying=false;
  if(!result.success){
    const rl=otpRateRecord(_fpEmail);
    if(rl && !rl.ok){ fpShowMsg('B','زۆر جار هەوڵت دا — تکایە '+rl.remaining+' خولەکی تر هەوڵ بدەرەوە','err'); startBanCountdown(_fpEmail,'fpMsgB','fpResendBtn'); }
    else fpShowMsg('B',result.message||'کۆدی هەڵە','err');
    btn.disabled=false; btn.innerHTML=ICON.check+' دڵنیاکردنەوە'; return;
  }
  clearInterval(_fpTimer);
  document.getElementById('fpStepB').style.display='none';
  document.getElementById('fpStepC').style.display='block';
  document.getElementById('fpNewPass').value=''; document.getElementById('fpConfirmPass').value='';
  document.getElementById('fpMsgC').style.display='none';
  document.getElementById('fpNewPass').focus();
}

async function doForgotSavePass(){
  const np=document.getElementById('fpNewPass').value, cp=document.getElementById('fpConfirmPass').value;
  if(!np||np.length<6){ fpShowMsg('C','وشەی نهێنی دەبێت کەمترین ٦ پیت بێت','err'); return; }
  if(np!==cp){ fpShowMsg('C','وشەی نهێنیەکان یەکسان نین','err'); return; }
  const btn=document.getElementById('fpSaveBtn'); btn.disabled=true; btn.innerHTML=ICON.spin+' گۆڕین...';
  try{
    const {data:rData,error:rErr}=await sb.rpc('reset_user_password',{ user_email:_fpEmail, new_pass:np });
    if(rErr){ fpShowMsg('C',rErr.message||'هەڵەی گۆڕینی پاسۆرد','err'); return; }
    if(rData && rData.success===false){ fpShowMsg('C',rData.message||'هەڵەیەک ڕووی دا','err'); return; }
    fpShowMsg('C','وشەی نهێنیەکە گۆڕدرا، چوونەژوورەوە...','ok');
    try{ await sb.auth.signOut(); }catch(_){}
    await new Promise(r=>setTimeout(r,900));
    const {data:ld,error:le}=await sb.auth.signInWithPassword({email:_fpEmail,password:np});
    if(!le && ld?.user){
      document.getElementById('forgotStep').style.display='none';
      await startApp(ld.user);
    } else {
      cancelForgotStep();
      _authEmail=_fpEmail; _authIsNewUser=false;
      document.getElementById('authEmail').value=_fpEmail;
      document.getElementById('authPass').value=np;
      document.getElementById('passStepTitle').textContent='وشەی نهێنی';
      document.getElementById('authBtnTxt').textContent='چوونەژوورەوە';
      document.getElementById('forgotLinkWrap').style.display='block';
      goAuthStep('pass');
      setTimeout(()=>showAmsg('وشەی نهێنیەکەت گۆڕدرا — کلیک لە چوونەژوورەوە بکە','ok'),100);
    }
  }catch(e){ fpShowMsg('C',kuErr(e.message)||'هەڵەی تۆڕ','err'); }
  finally{ btn.disabled=false; btn.innerHTML=ICON.lock+' پاشەکەوتکردن'; }
}

function kuErr(msg){
  const m={
    'Invalid login credentials':'ئیمەیل یان وشەی نهێنی هەڵەیە',
    'User already registered':'ئەم ئیمەیلە پێشتر تۆمارکراوە',
    'Password should be at least 6 characters':'وشەی نهێنی دەبێت کەمترین ٦ پیت بێت',
    'Unable to validate email address: invalid format':'فۆرماتی ئیمەیل هەڵەیە',
    'Too many requests':'زۆر جار هەوڵت دا، کەمێک چاوەڕوان بە',
    'Network request failed':'کێشەی تۆڕ، دووبارە هەوڵ بدەرەوە',
    'Email rate limit exceeded':'زۆر جار ئیمەیل نێردرا، کەمێک چاوەڕوان بە',
    'Auth session missing':'تکایە دووبارە بچۆ ژوورەوە',
    'PROFILE_UPDATE_COOLDOWN':'ناو و ژمارەی مۆبایل تا تەواوبوونی ٧ ڕۆژەکە قوفڵن',
    'SENDER_PHONE_REQUIRED':'ژمارەی نێرەر بۆ Korek و Asiacell پێویستە',
    'SENDER_PHONE_INVALID':'ژمارەی نێرەر دەبێت بە 07 دەست پێبکات و ١١ ژمارە بێت',
    'Invalid sender number':'ژمارەی نێرەر دەبێت بە 07 دەست پێبکات و ١١ ژمارە بێت',
  };
  return m[msg]||msg;
}

// ══════════════════════════════════════════════════════════════
// ═══ START APP (after successful auth) ══════════════════════════
// ══════════════════════════════════════════════════════════════
async function ensureExProfile(user){
  const {data:existing}=await sb.from('ex_profiles').select('*').eq('id',user.id).maybeSingle();
  if(existing) return existing;
  const fullName=user.user_metadata?.full_name || user.email.split('@')[0];
  const {data:created,error}=await sb.from('ex_profiles').insert({id:user.id,email:user.email,full_name:fullName}).select().single();
  if(error){ const {data:retry}=await sb.from('ex_profiles').select('*').eq('id',user.id).maybeSingle(); return retry; }
  return created;
}

async function startApp(user){
  curUser=user;
  curProfile=await ensureExProfile(user);
  if(curProfile?.is_banned){
    showResultModal({
      tone:'error',
      title:'هەژمار بۆیکۆتکراوە',
      message:'ئەم هەژمارە بۆیکۆتکراوە. تکایە پەیوەندی بە پشتگیری بکە.',
      primaryText:'باشە',
      onPrimary: async ()=>{ try{ await sb.auth.signOut(); }catch(_){} try{ location.replace(BASE_PATH); }catch(_){ location.reload(); } }
    });
    return;
  }
  document.getElementById('authWrap').style.display='none';
  document.getElementById('mainApp').style.display='block';
  document.body.classList.add('has-nav');
  applyProfileToUI();
  fillProfileForm();
  document.getElementById('adminBtn').style.display=curProfile?.is_admin?'flex':'none';
  if(curProfile?.phone){
    const _ph=document.getElementById('userPhone');
    if(_ph && !_ph.value) _ph.value=curProfile.phone;
  }
  navigate(routeFromLocation(), false);
  refreshFormHints();
  startProofPolling();
  await loadWallets();
  await loadRates();
  pickInitialWallets();
  refreshTrigger('from');
  refreshTrigger('receiveVia');
  updateWallet();
  updatePlaceholder();
  subscribeWalletsUser();
  subscribeRatesUser();
  await loadHistory();
  await loadNotifications();
  listenToNews();
  setTimeout(()=>{ document.getElementById('tgModal').style.display='flex'; },1000);
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
const wallets = { "FastPay": "07510074008", "FIB": "07510074008", "QiCard": "07510074008", "Asiacell": "07758887488", "Korek": "07510074008", "USDT": "TTaNnxWNt2bjgSvpRY7NpvyCHUXDi6wjYc" };
// ═══ LIVE WALLET DATA (numbers + lock state come from ex_wallets, admin panel) ═══
let WALLET_DATA = {};
let _walletsChannel = null;
function getWalletInfo(key){
  const w = WALLET_DATA[key];
  return { number: (w && w.number) || wallets[key] || null, locked: !!(w && w.locked) };
}
async function loadWallets(){
  try{
    const {data,error} = await sb.from('ex_wallets').select('key,name,image_url,wallet_number,is_locked,allow_from,allow_receive,sort_order').order('sort_order',{ascending:true});
    if(!error && data){
      WALLET_DATA = {};
      data.forEach(w=>{ if(w.key) WALLET_DATA[w.key] = { number: w.wallet_number || null, locked: !!w.is_locked, name:w.name, image_url:w.image_url, allow_from: w.allow_from!==false, allow_receive:!!w.allow_receive, sort_order:w.sort_order }; });
      rebuildWalletOptions();
    }
  }catch(e){}
}
function subscribeWalletsUser(){
  if(_walletsChannel) return;
  _walletsChannel = sb.channel('ex_wallets_user')
    .on('postgres_changes', {event:'*',schema:'public',table:'ex_wallets'}, async ()=>{
      await loadWallets();
      refreshTrigger('from');
      refreshTrigger('receiveVia');
      updateWallet();
      updatePlaceholder();
    }).subscribe();
}
let _ratesChannel = null;
function subscribeRatesUser(){
  if(_ratesChannel) return;
  _ratesChannel = sb.channel('ex_rates_user')
    .on('postgres_changes', {event:'*',schema:'public',table:'ex_rates'}, async ()=>{
      await loadRates();
      calc();
      // the rate board is now stale — refresh it if the user is looking at it
      _changesLoaded=false;
      if(_route==='changes') loadChangeLog(true);
    }).subscribe();
}
const FALLBACK_RATES = {
  'Korek>FastPay':{type:'multiplier',value:0.82}, 'Korek>FIB':{type:'multiplier',value:0.825}, 'Korek>QiCard':{type:'multiplier',value:0.81},
  'Asiacell>FastPay':{type:'multiplier',value:0.84}, 'Asiacell>FIB':{type:'multiplier',value:0.82}, 'Asiacell>QiCard':{type:'multiplier',value:0.835},
  'USDT>FastPay':{type:'multiplier',value:1450}, 'USDT>FIB':{type:'multiplier',value:1440}, 'USDT>QiCard':{type:'multiplier',value:1445}
};
// RATES_STRICT means "the admin's route table was reached" — then ONLY the pairs
// the admin switched on exist. Anything not in RATES is closed: no guessed rate,
// no silent swap to another wallet. The old hardcoded table is used only when the
// database itself is unreachable, so a network blip can't close the whole site.
let RATES_STRICT=false;
async function loadRates(){
  RATES={}; RATES_STRICT=false;
  try{
    const {data,error}=await sb.from('ex_rates').select('*').eq('is_active',true);
    if(!error && data){
      data.forEach(r=>{ RATES[r.from_method+'>'+r.to_method]={type:r.rate_type,value:Number(r.rate_value)}; });
      RATES_STRICT=true;
    }
  }catch(e){}
  if(!RATES_STRICT) RATES=Object.assign({},FALLBACK_RATES);
}
// Smallest amount any exchange is accepted for, in IQD.
const MIN_AMOUNT = 10000;
const CARRIER_SENDER_METHODS = new Set(['Korek','Asiacell']);
function needsSenderPhone(method){ return CARRIER_SENDER_METHODS.has(method); }
function routeAllowed(from,to){
  if(!from || !to || from===to) return false;
  if(!RATES_STRICT) return true;
  return !!RATES[from+'>'+to];
}
function allowedReceiveOptions(from){
  return RECEIVE_OPTIONS.filter(k=>routeAllowed(from,k));
}
// ── Opening state: never start with the same wallet on both sides ──
// The first entry of both lists is normally the same wallet (FastPay), so the
// page used to open on "هەمان واڵێت نابێت" with a dead submit button. This runs
// ONLY when the page opens — a same-wallet or closed pair the user picks
// themselves is still shown as blocked and is never auto-switched.
function pickInitialWallets(){
  const fromSel = document.getElementById('from');
  const toSel   = document.getElementById('receiveVia');
  if(!fromSel || !toSel) return;
  const free = k => !!k && !getWalletInfo(k).locked;
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
  const info = getWalletInfo(key);
  const numEl = document.getElementById('myNum');
  const copyBtn = document.querySelector('.wallet-row .copy-btn');
  if(info.locked){
    numEl.innerHTML = ICON.lock + '<span>ئەم شێوازە لەئێستادا بەردەست نییە</span>';
    numEl.classList.add('locked-text');
    if(copyBtn) copyBtn.style.display = 'none';
  } else {
    numEl.textContent = info.number || '---';
    numEl.classList.remove('locked-text');
    if(copyBtn) copyBtn.style.display = '';
  }
  updateSenderIdentityFields();
  refreshTrigger('from');
  calc();
}

function updateSenderIdentityFields(){
  const from=document.getElementById('from')?.value||'';
  const carrier=needsSenderPhone(from);
  const nameField=document.getElementById('senderNameField');
  const phoneField=document.getElementById('senderPhoneField');
  const senderName=document.getElementById('userSenderName');
  const senderPhone=document.getElementById('userSenderPhone');

  if(nameField) nameField.style.display=carrier?'none':'';
  if(phoneField) phoneField.style.display=carrier?'':'none';
  if(senderName) senderName.disabled=carrier;
  if(senderPhone){
    senderPhone.disabled=!carrier;
    if(!carrier) senderPhone.value='';
  }
  clearFieldError(carrier?'userSenderName':'userSenderPhone');
}
function updatePlaceholder(){
  refreshTrigger('receiveVia');
  // QiCard's recipient number isn't a standard 07-prefixed 11-digit Iraqi
  // mobile number, so its input field skips that phone-format restriction.
  const to = document.getElementById('receiveVia').value;
  const inp = document.getElementById('userPhone');
  if(inp) inp.placeholder = (to==='QiCard') ? 'ژمارەی کارتی Qi Card' : 'ژمارەی وەرگرە';
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
  const anyLocked = getWalletInfo(from).locked || getWalletInfo(to).locked;
  const same = from===to;
  const closed = !same && !routeAllowed(from,to);
  const amt = parseFloat(getAmtRaw())||0;
  const tooSmall = amt>0 && amt<MIN_AMOUNT;
  btn.disabled = anyLocked || same || closed || tooSmall;
  btn.innerHTML = anyLocked ? 'ئەم شێوازە لەئێستادا بەردەست نییە'
    : same ? 'هەمان واڵێت نابێت'
    : closed ? 'ئەم گۆڕینەوەیە داخراوە'
    : tooSmall ? 'کەمترین بڕ '+formatNum(MIN_AMOUNT)+' دینارە'
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
  const feeEl=document.getElementById('feeDisplay');
  const bdRate=document.getElementById('bdRate');
  const bdFee=document.getElementById('bdFee');
  const setBd=(r,f)=>{ if(bdRate) bdRate.textContent=r; if(bdFee) bdFee.textContent=f; };
  updateHeaderRate();

  if(from===to){ totalEl.innerText='هەمان واڵێت نابێت'; totalEl.classList.add('warn-text'); feeEl.innerText=''; setBd('—','—'); return; }
  const r=RATES[from+'>'+to];
  // Closed direction: show it as closed. Never fall back to a guessed rate and
  // never quietly move the order to a different wallet.
  if(!routeAllowed(from,to)){
    totalEl.innerText='ئەم گۆڕینەوەیە داخراوە';
    totalEl.classList.add('warn-text');
    const toLbl=(METHOD_META[to]&&METHOD_META[to].label)||to;
    feeEl.innerText = getWalletInfo(to).locked ? '' : ('گۆڕینەوە بۆ '+toLbl+' لە ئێستادا بەردەست نییە');
    setBd('داخراوە','—');
    return;
  }
  totalEl.classList.remove('warn-text');

  // rate line — the exact multiplier or fee the order will be settled at
  if(r.type==='multiplier')      setBd('1 = '+fmtPct(r.value), '—');
  else if(r.type==='fee_percent')setBd('1 = 1', fmtPct(r.value)+'%');
  else                           setBd('1 = 1', formatNum(r.value)+' IQD');

  if(amt>0 && amt<MIN_AMOUNT){
    totalEl.innerText='کەمترین بڕ '+formatNum(MIN_AMOUNT)+' دینارە';
    totalEl.classList.add('warn-text');
    feeEl.innerText='';
    return;
  }
  let final=0, feeTxt='', feeVal=0;
  if(r.type==='fee_percent'){
    feeVal=amt*r.value/100; final=amt-feeVal;
    if(amt>0 && feeVal>0) feeTxt='کرێ: '+formatNum(Math.floor(feeVal))+' IQD';
    if(bdFee) bdFee.textContent = amt>0 ? (formatNum(Math.floor(feeVal))+' IQD ('+fmtPct(r.value)+'%)') : (fmtPct(r.value)+'%');
  }else if(r.type==='fee_fixed'){
    feeVal=r.value; final=Math.max(0, amt-feeVal);
    if(amt>0 && feeVal>0) feeTxt='کرێ: '+formatNum(Math.floor(feeVal))+' IQD';
    if(bdFee) bdFee.textContent = formatNum(Math.floor(feeVal))+' IQD';
  }else{
    final=amt*r.value;
    // A multiplier under 1 (Korek/Asiacell style transfers) is a straight cut off
    // the amount, so it reads as a rate — "کرێ: 15%" — rather than an amount.
    if(r.value<1){
      feeVal=amt-final;
      feeTxt='کرێ: '+fmtPct(100-r.value*100)+'%';
      if(bdFee) bdFee.textContent = amt>0
        ? (formatNum(Math.floor(feeVal))+' IQD ('+fmtPct(100-r.value*100)+'%)')
        : (fmtPct(100-r.value*100)+'%');
    }else if(bdFee) bdFee.textContent='بێ کرێ';
  }
  totalEl.innerText=formatNum(Math.floor(final))+' IQD';
  feeEl.innerText=feeTxt;
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
  const carrierSender=needsSenderPhone(from);
  let ok=true;
  if(carrierSender && !/^07\d{9}$/.test(senderPhone)){
    setFieldError('userSenderPhone','ژمارەی نێرەر دەبێت بە 07 دەست پێبکات و ١١ ژمارە بێت');
    ok=false;
  }else if(!carrierSender && (!profileName || normalizePersonName(senderName)!==normalizePersonName(profileName))){
    setFieldError('userSenderName','ناوی خاوەنی هەژماری نێرەر دەبێت لەگەڵ ناوی پڕۆفایلی Proxo یەکسان بێت');
    ok=false;
  }
  if(!amtValue || parseFloat(amtValue)<=0){ setFieldError('amt','بڕی پارە داخڵ بکە'); ok=false; }
  else if(parseFloat(amtValue)<MIN_AMOUNT){ setFieldError('amt','کەمترین بڕی مامەڵە '+formatNum(MIN_AMOUNT)+' دینارە'); ok=false; }
  if(to==='QiCard'){
    if(!phone || phone.length<6){ setFieldError('userPhone','ژمارەی کارتی Qi Card داخڵ بکە'); ok=false; }
  } else if(!phone.startsWith("07")||phone.length!==11){ setFieldError('userPhone','تەنها ژمارەی عێراقی (07) بە 11 ژمارە داخڵ بکە'); ok=false; }
  if(!file){ setFieldError('fileInput','وێنەی پسووڵەی پارەدان زیاد بکە'); ok=false; }
  if(from===to){ showToast('لە هەمان واڵێت وەرناگیرێت — ڕێگایەکی جیاواز هەڵبژێرە بۆ وەرگرتن','warning','هەمان واڵێت هەڵبژێردراوە'); ok=false; }
  if(getWalletInfo(from).locked){ showToast('ئەم شێوازە لەئێستادا بەردەست نییە بۆ ناردن','error','بەردەست نییە'); ok=false; }
  if(getWalletInfo(to).locked){ showToast('ئەم شێوازە لەئێستادا بەردەست نییە بۆ وەرگرتن','error','بەردەست نییە'); ok=false; }
  else if(from!==to && !getWalletInfo(from).locked && !routeAllowed(from,to)){
    showToast('گۆڕینەوە لەم واڵێتەوە بۆ ئەوی تر داخراوە — واڵێتێکی تر بۆ وەرگرتن هەڵبژێرە','error','گۆڕینەوە داخراوە'); ok=false;
  }
  if(!ok) showToast('تکایە خانە پێویستەکان پڕ بکەرەوە','error');
  return ok;
}

function openOrderConfirm(){
  if(!_validateOrderFields()) return;
  const senderName=document.getElementById('userSenderName').value;
  const senderPhone=document.getElementById('userSenderPhone').value;
  const phone=document.getElementById('userPhone').value;
  const amtValue=getAmtRaw();
  const from=document.getElementById('from').value, to=document.getElementById('receiveVia').value;
  const senderIdentityRow=needsSenderPhone(from)
    ? '<div class="confirm-row"><span class="confirm-row-label">ژمارەی نێرەر</span><span class="confirm-row-value" dir="ltr">'+escHtml(senderPhone)+'</span></div>'
    : '<div class="confirm-row"><span class="confirm-row-label">ناوی نێرەر</span><span class="confirm-row-value">'+escHtml(senderName)+'</span></div>';
  const totalTxt=document.getElementById('totalDisplay').innerText;
  const displayAmt=(from==='USDT')?`${formatNum(amtValue)}$`:`${formatNum(amtValue)} IQD`;
  document.getElementById('confirmSummary').innerHTML =
    '<div class="confirm-row"><span class="confirm-row-label">'+methodIconHTML(from,'sz-sm')+' لە</span><span class="confirm-row-value">'+METHOD_META[from].label+'</span></div>'
    + '<div class="confirm-row"><span class="confirm-row-label">'+methodIconHTML(to,'sz-sm')+' بۆ</span><span class="confirm-row-value">'+METHOD_META[to].label+'</span></div>'
    + '<div class="confirm-row"><span class="confirm-row-label">بڕی پارە</span><span class="confirm-row-value" dir="ltr">'+displayAmt+'</span></div>'
    + '<div class="confirm-row"><span class="confirm-row-label">بڕی وەرگیراو</span><span class="confirm-row-value accent" dir="ltr">'+totalTxt+'</span></div>'
    + senderIdentityRow
    + '<div class="confirm-row"><span class="confirm-row-label">ژمارەی وەرگر</span><span class="confirm-row-value" dir="ltr">'+phone+'</span></div>';
  const overlay=document.getElementById('confirmSheet');
  openSheet(overlay);
}
function closeOrderConfirm(){
  closeSheet(document.getElementById('confirmSheet'));
}
async function confirmAndSubmitOrder(){
  closeOrderConfirm();
  await processOrder();
}

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
  const file=document.getElementById('fileInput').files[0];
  const amtValue=getAmtRaw();
  const from=document.getElementById('from').value, to=document.getElementById('receiveVia').value;

  const btn=document.getElementById('submitBtn'); btn.dataset.submitting='1'; btn.disabled=true; btn.innerHTML=ICON.spin+' ناردن...';
  try{
    let receiptUrl=null, receiptHash=null;
    if(file){
      try{
        const bytes=await file.arrayBuffer();
        const digest=await crypto.subtle.digest('SHA-256',bytes);
        receiptHash=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
        const ext=(file.name.split('.').pop()||'jpg').toLowerCase();
        const path=`${curUser.id}/${Date.now()}_${Math.random().toString(36).slice(2,8)}.${ext}`;
        const {error:upErr}=await sb.storage.from('receipts').upload(path, file, { upsert:false, contentType:file.type||'image/jpeg' });
        if(!upErr){ receiptUrl=sb.storage.from('receipts').getPublicUrl(path).data.publicUrl; }
      }catch(_){}
    }

    const {data:{session:_orderSession}}=await sb.auth.getSession();
    if(!_orderSession) throw new Error('Auth session missing');
    const orderResponse=await fetch('/api/orders',{
      method:'POST',
      headers:{'Content-Type':'application/json','Authorization':'Bearer '+_orderSession.access_token},
      body:JSON.stringify({
        from_method:from,to_method:to,amount:parseFloat(amtValue),phone,
        sender_name:needsSenderPhone(from)?null:senderName,
        sender_phone:needsSenderPhone(from)?senderPhone:null,
        receipt_url:receiptUrl,receipt_hash:receiptHash,contact_reference:''
      })
    });
    let orderPayload={};
    try{ orderPayload=await orderResponse.json(); }catch(_){}
    if(!orderResponse.ok || !orderPayload.order) throw new Error(orderPayload.error||'نەتوانرا داواکارییەکە تۆمار بکرێت');
    const orderRow=orderPayload.order;

    // The Telegram alert is sent by /api/notify-order. The bot token lives in a
    // Vercel environment variable, so it never reaches the browser, and the
    // caption is rebuilt server-side from the saved row (amounts can't be faked).
    try{
      const {data:{session:_s}} = await sb.auth.getSession();
      if(_s){
        await fetch('/api/notify-order', {
          method:'POST',
          headers:{ 'Content-Type':'application/json', 'Authorization':'Bearer '+_s.access_token },
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
async function loadHistory(){
  const {data}=await sb.from('ex_orders').select('*').eq('user_id',curUser.id).order('created_at',{ascending:false});
  renderHistory(data||[]);
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
function copyOrderCode(code, ev){
  if(ev){ ev.stopPropagation(); }
  try{ navigator.clipboard.writeText(code); showToast('ئایدی مامەڵە کۆپی کرا','success'); }
  catch(_){ showToast('نەتوانرا کۆپی بکرێت','error'); }
}

function statusClassOf(status){
  return status==='پەسەندکرا' ? 'status-success' : (status==='ڕەتکرا' ? 'status-danger' : '');
}

function orderCardHTML(o){
  const code = orderCodeOf(o);
  const decidedRow = (o.status==='پەسەندکرا' || o.status==='ڕەتکرا') && o.decided_at
    ? '<div class="detail-item"><span class="detail-ico" style="color:'+(o.status==='پەسەندکرا'?'var(--success)':'var(--error)')+'">'+(o.status==='پەسەندکرا'?ICON.check:ICON.cross)+'</span> '+o.status+': '+new Date(o.decided_at).toLocaleString('ku-IQ')+'</div>'
    : '';
  const hasReceipt = !!o.payout_receipt_url;
  const rcptId = 'rcpt_'+o.id;
  return '<div class="order-card'+(hasReceipt?' has-receipt':'')+'" '+(hasReceipt?'onclick="toggleReceipt(\''+rcptId+'\')"':'')+'>'
    + '<div class="order-header">'
      + '<span class="order-code" onclick="copyOrderCode(\''+code+'\', event)" title="کۆپیکردنی ئایدی">'+fmtCode(code)+ICON.copy+'</span>'
      + '<span class="status-badge '+statusClassOf(o.status)+'">'+escHtml(o.status)+'</span>'
    + '</div>'
    + '<div class="detail-item"><span class="detail-ico">'+ICON.swap+'</span> '+escHtml(methodLabel(o.from_method))+' <span class="inline-route-icon">'+ICON.arrowLeftLong+'</span> '+escHtml(methodLabel(o.to_method))+'</div>'
    + '<div class="detail-item"><span class="detail-ico">'+ICON.banknote+'</span> بڕ: <b>'+formatNum(o.amount)+(o.from_method==='USDT'?'$':' IQD')+'</b></div>'
    + '<div class="detail-item"><span class="detail-ico" style="color:var(--success)">'+ICON.receive+'</span> بڕی وەرگیراو: <b style="color:var(--success)">'+formatNum(Math.floor(o.total))+' IQD</b></div>'
    + '<div class="detail-item"><span class="detail-ico">'+ICON.phone+'</span> ژمارە: '+escHtml(o.phone||'—')+'</div>'
    + (o.extra_info?'<div class="detail-item"><span class="detail-ico">'+ICON.info+'</span> زانیاری زیاتر: '+escHtml(o.extra_info)+'</div>':'')
    + '<div class="detail-item"><span class="detail-ico">'+ICON.send+'</span> ناردرا: '+new Date(o.created_at).toLocaleString('ku-IQ')+'</div>'
    + decidedRow
    + (o.admin_note?'<div class="detail-item"><span class="detail-ico">'+ICON.message+'</span> '+escHtml(o.admin_note)+'</div>':'')
    + (hasReceipt?'<div class="detail-item rcpt-hint"><span class="detail-ico">'+ICON.image+'</span> وێنەی پسووڵە بەردەستە — کلیک بکە بۆ بینین</div>'
        + '<div class="rcpt-wrap" id="'+rcptId+'" style="display:none">'
        + '<img src="'+escHtml(o.payout_receipt_url)+'" class="rcpt-img" onclick="event.stopPropagation(); document.getElementById(\''+rcptId+'\').style.display=\'none\';">'
        + '</div>':'')
    + '</div>';
}

function methodLabel(key){
  return (METHOD_META[key] && METHOD_META[key].label) || key || '—';
}

function renderHistory(rows){
  _orders = rows || [];
  renderHomePreview();
  renderTxPage();
  updateNavBadge();
}

function renderHomePreview(){
  const el=document.getElementById('historyPreview');
  if(!el) return;
  const rows=_orders.slice(0,3);
  el.innerHTML = rows.length ? rows.map(orderCardHTML).join('')
    : '<div class="empty-state">هێشتا هیچ مامەڵەیەکت نییە</div>';
}

function updateNavBadge(){
  const dot=document.getElementById('bnTxDot');
  if(!dot) return;
  const pending=_orders.filter(o=>o.status==='چاوەڕوانە').length;
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
  if(_txStatus!=='all' && o.status!==_txStatus) return false;
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
  const ok    = _orders.filter(o=>o.status==='پەسەندکرا');
  const wait  = _orders.filter(o=>o.status==='چاوەڕوانە');
  const no    = _orders.filter(o=>o.status==='ڕەتکرا');

  // Totals only count completed exchanges. IQD and USDT are kept apart so the
  // number on screen is never a sum of two different currencies.
  const sentIqd  = ok.filter(o=>o.from_method!=='USDT').reduce((s,o)=>s+Number(o.amount||0),0);
  const sentUsdt = ok.filter(o=>o.from_method==='USDT').reduce((s,o)=>s+Number(o.amount||0),0);
  const recvIqd  = ok.reduce((s,o)=>s+Number(o.total||0),0);

  document.getElementById('txTotalSent').textContent = formatNum(Math.floor(sentIqd));
  document.getElementById('txTotalSentSub').textContent = sentUsdt>0 ? ('IQD  +  '+formatNum(sentUsdt)+' $') : 'IQD';
  document.getElementById('txTotalRecv').textContent = formatNum(Math.floor(recvIqd));

  document.getElementById('txCntAll').textContent  = _orders.length;
  document.getElementById('txCntOk').textContent   = ok.length;
  document.getElementById('txCntWait').textContent = wait.length;
  document.getElementById('txCntNo').textContent   = no.length;

  document.getElementById('fcAll').textContent  = _orders.length;
  document.getElementById('fcWait').textContent = wait.length;
  document.getElementById('fcOk').textContent   = ok.length;
  document.getElementById('fcNo').textContent   = no.length;

  renderTxList();
}

function renderTxList(){
  const el=document.getElementById('txList'); if(!el) return;
  const list=_orders.filter(txMatches);
  const cnt=document.getElementById('txResultCount');
  if(cnt) cnt.textContent = _orders.length ? (list.length+' لە '+_orders.length+' مامەڵە') : '';
  if(!list.length){
    el.innerHTML = '<div class="empty-state">'
      + (_txQuery ? 'هیچ مامەڵەیەک بەم ئایدییە نەدۆزرایەوە' : 'هیچ مامەڵەیەک نییە بەم فلتەرە')
      + '</div>';
    return;
  }
  el.innerHTML = list.map(orderCardHTML).join('');
}
function copyNum(){ navigator.clipboard.writeText(document.getElementById('myNum').innerText); showToast('ژمارەکە کۆپی کرا بۆ کلیپبۆرد','success'); }
function toggleReceipt(id){
  const el=document.getElementById(id);
  if(!el) return;
  el.style.display = (el.style.display==='none') ? 'block' : 'none';
}

// Admin panel now lives in its own page — see exchange-admin.html


// ══════════════════════════════════════════════════════════════
// ═══ EXTRA ICONS (used by the router pages + notifications) ════
// ══════════════════════════════════════════════════════════════
Object.assign(ICON, {
  // Notification icons — clean, well-formed 24px outline SVGs
  badgeCheck:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"/><path d="m9 12 2 2 4-4"/></svg>',
  xCircle:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>',
  refresh:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/></svg>',
  megaphone:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 11 18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/></svg>',
  bellOff:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8.7 3A6 6 0 0 1 18 8a21.3 21.3 0 0 0 .6 5"/><path d="M17 17H3s3-2 3-9a4.67 4.67 0 0 1 .3-1.7"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/><path d="m2 2 20 20"/></svg>',
  copy:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>',
  trendUp:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>',
  trendDown:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 17 13.5 8.5 8.5 13.5 2 7"/><polyline points="16 17 22 17 22 11"/></svg>',
  lockClosed:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
  lockOpen:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>',
  sparkles:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3 1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z"/><path d="M18 16.5 18.7 18.3 20.5 19 18.7 19.7 18 21.5 17.3 19.7 15.5 19 17.3 18.3z"/></svg>',
  equals:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9h14M5 15h14"/></svg>',
  arrowLeftLong:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><path d="m11 6-6 6 6 6"/></svg>',
  user:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
  sliders:'<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" x2="4" y1="21" y2="14"/><line x1="4" x2="4" y1="10" y2="3"/><line x1="12" x2="12" y1="21" y2="12"/><line x1="12" x2="12" y1="8" y2="3"/><line x1="20" x2="20" y1="21" y2="16"/><line x1="20" x2="20" y1="12" y2="3"/><line x1="2" x2="6" y1="14" y2="14"/><line x1="10" x2="14" y1="8" y2="8"/><line x1="18" x2="22" y1="16" y2="16"/></svg>'
});

// ══════════════════════════════════════════════════════════════
// ═══ ROUTER — /, /transactions, /changes, /rules, /profile ═════
// ══════════════════════════════════════════════════════════════
// ROUTE_MODE:
//   'path' → clean URLs (www.domain.com/profile). The server must serve
//            index.html for those paths (see the redirect snippets shipped
//            with this file); otherwise a hard refresh on /profile 404s.
//   'hash' → www.domain.com/#/profile. Works on ANY static host with no
//            server config at all. Switch to this if you cannot add rewrites.
const ROUTE_MODE = 'path';
const ROUTES = { home:'pageHome', transactions:'pageTx', changes:'pageChanges', rules:'pageRules', profile:'pageProfile' };
const ROUTE_TITLES = {
  home:'Proxo Balance — ئاڵوگۆڕی دراو',
  transactions:'مامەڵەکان — Proxo Balance',
  changes:'گۆڕانکاری نرخەکان — Proxo Balance',
  rules:'یاساکانی ئەپ — Proxo Balance',
  profile:'پڕۆفایل — Proxo Balance'
};
// Everything before the route segment, so the app works at the domain root
// (/profile) and inside a sub-folder (/exchange/profile) with no edits.
const BASE_PATH = (function(){
  let p = location.pathname.replace(/[^\/]*\.html?$/i, '');
  const parts = p.split('/').filter(Boolean);
  if(parts.length && ROUTES[parts[parts.length-1]]) parts.pop();
  return '/' + (parts.length ? parts.join('/') + '/' : '');
})();
let _route='home';

function routeFromLocation(){
  if(location.hash && location.hash.indexOf('#/')===0){
    const r=location.hash.slice(2).split(/[?&]/)[0];
    if(ROUTES[r]) return r;
  }
  const seg=location.pathname.replace(/\/+$/,'').split('/').pop();
  return ROUTES[seg] ? seg : 'home';
}
function urlFor(route){
  if(route==='home') return BASE_PATH;
  return ROUTE_MODE==='hash' ? BASE_PATH+'#/'+route : BASE_PATH+route;
}
function navigate(route, push){
  if(push===undefined) push=true;
  if(!ROUTES[route]) route='home';
  _route=route;
  Object.keys(ROUTES).forEach(r=>{
    const el=document.getElementById(ROUTES[r]);
    if(el) el.classList.toggle('active', r===route);
  });
  // /changes lives under the profile tab
  const navRoute = (route==='changes') ? 'profile' : route;
  document.querySelectorAll('.bn-item, .hdr-nav-link').forEach(b=>b.classList.toggle('on', b.dataset.route===navRoute));
  if(push){ try{ history.pushState({route:route}, '', urlFor(route)); }catch(_){} }
  document.title = ROUTE_TITLES[route] || 'Proxo Balance';
  closeNotifPanel();
  window.scrollTo({ top:0, behavior:'smooth' });
  if(route==='transactions') renderTxPage();
  if(route==='changes')      loadChangeLog();
  if(route==='profile')      fillProfileForm();
}
window.addEventListener('popstate', function(){ navigate(routeFromLocation(), false); });

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
  new_route:'ڕێگایەکی نوێ', is_active:'دۆخی ڕێگا', new_wallet:'واڵێتێکی نوێ',
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
    case 'new_route':   return 'ڕێگایەکی نوێ زیادکرا';
    case 'new_wallet':  return 'واڵێتێکی نوێ زیادکرا';
    default: return CHG_FIELD_LABEL[r.field] || r.field;
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
  if(r.field==='new_route' || r.field==='new_wallet') return ICON.sparkles;
  return r.direction==='up' ? ICON.trendUp : ICON.trendDown;
}
function chgValueText(field, v){
  if(v===null || v===undefined || v==='') return '—';
  if(field==='is_active' || field==='allow_from' || field==='allow_receive') return v==='true' ? 'کراوە' : 'داخراوە';
  if(field==='is_locked') return v==='true' ? 'داخراوە' : 'کراوە';
  const n=Number(v);
  if(!isNaN(n)) return (field==='fee_percent'||field==='fee') ? (fmtPct(n)+'%') : formatNum(n);
  return String(v);
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
  const v=Number(r.rate_value)||0;
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

  if(!list.length){ el.innerHTML='<div class="empty-state">هیچ ڕێگایەکی کراوە نییە لە ئێستادا</div>'; return; }

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
      + '</div>';
  }).join('');
}

let _changesLoaded=false;
async function loadChangeLog(force){
  const el=document.getElementById('changesList'); if(!el) return;
  if(_changesLoaded && !force) return;
  el.innerHTML='<div class="empty-state">بارکردن...</div>';
  try{
    const res = await Promise.all([
      sb.from('ex_change_log').select('*').order('created_at',{ascending:false}).limit(60),
      sb.from('ex_rates').select('*').eq('is_active',true)
    ]);
    _changesLoaded=true;
    renderRatesNow((res[1] && res[1].data) || []);
    renderChangeLog((res[0] && res[0].data) || []);
  }catch(e){
    el.innerHTML='<div class="empty-state">نەتوانرا گۆڕانکارییەکان باربکرێن</div>';
  }
}

function renderChangeLog(rows){
  const el=document.getElementById('changesList'); if(!el) return;
  if(!rows.length){ el.innerHTML='<div class="empty-state">هێشتا هیچ گۆڕانکارییەک تۆمار نەکراوە</div>'; return; }
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

const PROFILE_CHANGE_COOLDOWN_MS=7*24*60*60*1000;

function profileChangeAvailableAt(){
  if(!curProfile || curProfile.is_admin || !curProfile.identity_updated_at) return null;
  const at=new Date(curProfile.identity_updated_at).getTime()+PROFILE_CHANGE_COOLDOWN_MS;
  return Number.isFinite(at) ? at : null;
}

function syncSenderIdentity(){
  const el=document.getElementById('userSenderName');
  if(el) el.value=(curProfile&&curProfile.full_name)||'';
}

function updateProfileCooldownUI(){
  const nameEl=document.getElementById('pfName');
  const phoneEl=document.getElementById('pfPhone');
  const btn=document.getElementById('pfSaveBtn');
  const hint=document.getElementById('pfCooldownHint');
  const txt=document.getElementById('pfCooldownText');
  const availableAt=profileChangeAvailableAt();
  const locked=!!availableAt && availableAt>Date.now();

  if(nameEl) nameEl.disabled=locked;
  if(phoneEl) phoneEl.disabled=locked;
  if(btn) btn.disabled=locked;
  if(hint) hint.classList.toggle('warn',locked);
  if(txt){
    txt.textContent=locked
      ? 'دەتوانیت لە '+new Date(availableAt).toLocaleString('ku-IQ')+' دووبارە ناو یان ژمارەکەت بگۆڕیت.'
      : 'ئێستا دەتوانیت ناو و ژمارەکەت نوێ بکەیتەوە؛ دوای پاشەکەوتکردن بۆ ٧ ڕۆژ قوفڵ دەبێت.';
  }
  return locked;
}

function applyProfileToUI(){
  const name = (curProfile && curProfile.full_name) || (curUser && curUser.email) || '';
  const nameEl=document.getElementById('userName'); if(nameEl) nameEl.innerText=name;
  const av=document.getElementById('greetAvatar'); if(av) av.textContent=initialOf(name);
  const pfAv=document.getElementById('pfAvatar'); if(pfAv) pfAv.textContent=initialOf(name);
  const pfName=document.getElementById('pfNameLbl'); if(pfName) pfName.textContent=name||'—';
  const pfMail=document.getElementById('pfEmailLbl'); if(pfMail) pfMail.textContent=(curUser&&curUser.email)||'—';
  syncSenderIdentity();
  const joined=document.getElementById('pfJoined');
  if(joined && curProfile && curProfile.created_at){
    joined.textContent='بەشدارە لە '+new Date(curProfile.created_at).toLocaleDateString('ku-IQ',{month:'long', year:'numeric'});
  }
  const adminChip=document.getElementById('pfAdminChip');
  if(adminChip) adminChip.style.display = (curProfile && curProfile.is_admin) ? 'inline-flex' : 'none';
}

function fillProfileForm(){
  const n=document.getElementById('pfName'); if(n) n.value=(curProfile && curProfile.full_name)||'';
  const p=document.getElementById('pfPhone'); if(p) p.value=(curProfile && curProfile.phone)||'';
  applyProfileToUI();
  updateProfileCooldownUI();
}

async function saveProfile(){
  const nameEl=document.getElementById('pfName'), phoneEl=document.getElementById('pfPhone');
  const name=(nameEl.value||'').trim(), phone=(phoneEl.value||'').trim();
  clearFieldError('pfName'); clearFieldError('pfPhone');

  if(updateProfileCooldownUI()){
    showToast('هێشتا ٧ ڕۆژەکە تەواو نەبووە؛ کاتی ڕێگەپێدراو لە خوارەوە نیشان دراوە','warning');
    return;
  }

  if(normalizePersonName(name)===normalizePersonName(curProfile?.full_name)
     && phone===String(curProfile?.phone||'')){
    showToast('هیچ گۆڕانکارییەک نەکراوە','warning');
    return;
  }

  let ok=true;
  if(name.length<3){ setFieldError('pfName','ناو دەبێت لانیکەم ٣ پیت بێت'); ok=false; }
  if(phone && !/^07\d{9}$/.test(phone)){ setFieldError('pfPhone','ژمارە دەبێت بە 07 دەست پێبکات و ١١ ژمارە بێت'); ok=false; }
  if(!ok) return;

  const btn=document.getElementById('pfSaveBtn');
  btn.disabled=true; btn.innerHTML=ICON.spin+' پاشەکەوتکردن...';
  try{
    const {data,error}=await sb.from('ex_profiles')
      .update({ full_name:name, phone: phone || null })
      .eq('id', curUser.id).select().single();
    if(error) throw error;
    curProfile=Object.assign({},curProfile||{},data||{});
    // Lock immediately even if an API/schema cache returns the row without the
    // newly added timestamp column. The database remains the source of truth.
    if(!curProfile.identity_updated_at) curProfile.identity_updated_at=new Date().toISOString();
    applyProfileToUI();
    updateProfileCooldownUI();
    showToast('زانیارییەکانت نوێکرانەوە؛ دوای ٧ ڕۆژ دەتوانیت دووبارە بیانگۆڕیت','success');
    const orderPhone=document.getElementById('userPhone');
    if(orderPhone && !orderPhone.value && phone) orderPhone.value=phone;
  }catch(e){
    const msg=(e&&e.message)||'';
    if(msg.includes('PROFILE_UPDATE_COOLDOWN')){
      // A long-lived tab may still hold the profile from before the last save.
      // Refresh it so both inputs become locked immediately and stay locked.
      try{
        const {data:fresh}=await sb.from('ex_profiles').select('*').eq('id',curUser.id).maybeSingle();
        if(fresh){ curProfile=fresh; fillProfileForm(); }
      }catch(_){}
      const availableAt=profileChangeAvailableAt();
      showToast(availableAt
        ? 'ناو و ژمارەکەت قوفڵن؛ لە '+new Date(availableAt).toLocaleString('ku-IQ')+' دووبارە دەکرێنەوە'
        : 'ناو و ژمارەی مۆبایل تا تەواوبوونی ٧ ڕۆژەکە قوفڵن','error');
    }else if(msg.includes('PROFILE_NAME_INVALID')){
      showToast('ناو دەبێت لانیکەم ٣ پیت بێت','error');
    }else if(msg.includes('PROFILE_PHONE_INVALID')){
      showToast('ژمارەی مۆبایلەکە دروست نییە','error');
    }else{
      showToast(msg||'نەتوانرا پاشەکەوت بکرێت','error');
    }
  }finally{
    btn.innerHTML='پاشەکەوتکردن';
    updateProfileCooldownUI();
  }
}


// ══════════════════════════════════════════════════════════════
// ═══ HEADER — shadow on scroll + live rate pill + nav state ════
// ══════════════════════════════════════════════════════════════
window.addEventListener('scroll', function(){
  const h=document.getElementById('siteHeader');
  if(h) h.classList.toggle('scrolled', window.scrollY>4);
}, { passive:true });

function focusExchangeForm(){
  navigate('home');
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
  const good = to==='QiCard' ? v.length>=6 : (v.startsWith('07') && v.length===11);
  el.classList.add(good ? 'ok' : 'bad');
  if(!good && ((to==='QiCard' && v.length>6) || v.length>=11)){
    setFieldError('userPhone', to==='QiCard'
      ? 'ژمارەی کارتەکە دروست نییە'
      : 'ژمارە دەبێت بە 07 دەست پێبکات و ١١ ژمارە بێت');
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
      : 'کەمترین بڕ <b>'+formatNum(MIN_AMOUNT)+'</b> دینارە. بڕەکە دەبێت وەک ئەوە بێت کە ناردووتە.';
  }

  const lbl=document.getElementById('phoneLabel');
  const txt=document.getElementById('phoneHintText');
  if(to==='QiCard'){
    if(lbl) lbl.textContent='ژمارەی کارتی Qi Card';
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
  const r=RATES[from+'>'+to];
  if(from===to || !r || !routeAllowed(from,to)){ el.textContent='—'; return; }
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
  el.innerHTML = rows.map(function(r){
    return '<div class="feed-row">'
      + '<span class="feed-id">'
        + '<svg class="icn" style="width:12px;height:12px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"/><path d="m9 12 2 2 4-4"/></svg>'
        + escHtml(r.id||'') + '</span>'
      + '<span class="feed-route">'
        + methodIconHTML(r.from,'sz-xs') + escHtml(methodLabel(r.from))
        + '<svg class="icn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 12H5"/><path d="m11 6-6 6 6 6"/></svg>'
        + methodIconHTML(r.to,'sz-xs') + escHtml(methodLabel(r.to))
      + '</span>'
      + '<span class="feed-meta">'
        + '<span class="feed-phone">'+escHtml(r.phone||'')+'</span>'
        + '<span>'+timeAgo(r.at)+'</span>'
      + '</span>'
      + '<span class="feed-amount">'+formatNum(Math.floor(r.total||0))+' IQD<small>لە '+formatNum(Math.floor(r.amount||0))+(r.from==='USDT'?'$':'')+'</small></span>'
      + '</div>';
  }).join('');
}

function startProofPolling(){
  loadPublicProof();
  clearInterval(_proofTimer);
  _proofTimer=setInterval(function(){
    if(document.visibilityState==='visible' && _route==='home') loadPublicProof();
  }, 60000);
}


// ══════════════════════════════════════════════════════════════
// ═══ BEHAVIOUR REPORTING ══════════════════════════════════════
// The browser reports only WHAT happened. IP, user-agent and identity are
// read from the request by /api/track, so none of them can be spoofed here.
// ══════════════════════════════════════════════════════════════
async function reportEvent(event, detail, meta){
  try{
    const headers={ 'Content-Type':'application/json' };
    const { data:{ session } } = await sb.auth.getSession();
    if(session) headers['Authorization']='Bearer '+session.access_token;
    await fetch('/api/track', {
      method:'POST', headers,
      body: JSON.stringify({ event, detail:detail||null, path:location.pathname, meta:meta||null }),
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
  const notifP=document.getElementById('notifPanel'); if(notifP && notifP.classList.contains('open')){ closeNotifPanel(); return; }
  const picker=document.getElementById('pickerSheet'); if(picker.classList.contains('open')){ closePicker(); return; }
  const confirmS=document.getElementById('confirmSheet'); if(confirmS.classList.contains('open')){ closeOrderConfirm(); return; }
  const result=document.getElementById('resultModal'); if(result.style.display==='flex'){ closeResultModal(); return; }
});
window.addEventListener('offline', ()=>showToast('پەیوەندیت بە ئینتەرنێت بڕایەوە','error','کێشەی تۆڕ'));
window.addEventListener('online', ()=>showToast('پەیوەندیت بە ئینتەرنێت گەڕایەوە','success'));

document.addEventListener('DOMContentLoaded', async ()=>{
  applyTheme(document.documentElement.getAttribute('data-theme')||'light');
  // Public trust numbers need no session — visitors see them on the login screen.
  loadPublicProof();
  document.querySelectorAll('.pass-eye-ico').forEach(el=>{ el.innerHTML=ICON.eyeOff; });
  refreshTrigger('from');
  refreshTrigger('receiveVia');
  if(!window.supabase){ showAmsg('هەڵەی بارکردنی سیستەم، پەڕەکە نوێ بکەرەوە','err'); return; }
  sb=window.supabase.createClient(SB_URL,SB_KEY,{ auth:{ persistSession:true, autoRefreshToken:true, storageKey:'zex_sb_session' } });
  const {data:{session}}=await sb.auth.getSession();
  if(session?.user){ await startApp(session.user); }
  else {
    // No session: drop any inner route from the address bar so the login
    // screen is always at the root of the site.
    if(location.pathname.replace(/\/+$/,'') !== BASE_PATH.replace(/\/+$/,'')){
      try{ history.replaceState({}, '', BASE_PATH); }catch(_){}
    }
    goAuthStep('email');
  }
});
