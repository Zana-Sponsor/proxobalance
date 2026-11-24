// ── Original admin module 1 ──
// ══════════════════════════════════════════════════════════════
// ═══ CONFIG (same Exchange Supabase project as the customer site) ═
// ══════════════════════════════════════════════════════════════
const SB_URL='https://pycxuugoblkslvwebxuu.supabase.co';
const SB_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5Y3h1dWdvYmxrc2x2d2VieHV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMTk3OTksImV4cCI6MjEwMTc5NTc5OX0.VRRwxnnuLs_WORuVUO3oX3CLxrPtgG_uewIJaGrzn_s';

// Wallets live only in ex_wallets: names, logos and rules come from there
// (loadWalletMeta at start, refreshed whenever the wallets page saves).
const METHOD_META = {};
const WALLET_PALETTE = ['#7c3aed','#0ea5a4','#2563eb','#e11d48','#f59e0b','#26a17b','#0891b2','#db2777','#65a30d','#9333ea'];
function walletColor(key){ let h=0; for(const ch of String(key||'')) h=(h*31+ch.charCodeAt(0))>>>0; return WALLET_PALETTE[h%WALLET_PALETTE.length]; }
function syncMethodMeta(rows){
  Object.keys(METHOD_META).forEach(k=>delete METHOD_META[k]);
  (rows||[]).forEach(w=>{ if(w&&w.key) METHOD_META[w.key]={label:w.name||w.key,color:walletColor(w.key),img:w.image_url||null}; });
}
async function loadWalletMeta(){
  try{
    const {data,error}=await sb.from('ex_wallets').select('*').order('sort_order',{ascending:true});
    if(error) throw error;
    if(!allWallets.length) allWallets=data||[];
    syncMethodMeta(data);
    if(_curPage==='orders' && allOrders.length) renderOrders(orderQuery());
  }catch(_){}
}
const STATUS_PENDING='چاوەڕوانە', STATUS_APPROVED='پەسەندکرا', STATUS_REJECTED='ڕەتکرا';
const STATUS_NEEDS_CORRECTION='پێویستی بە ڕاستکردنەوەیە', STATUS_CORRECTED='ڕاستکراوەتەوە';
const STATUS_REVIEW='لەژێر پێداچوونەوەدایە', STATUS_CANCELLED='هەڵوەشێنرایەوە';
const REVIEWABLE_ORDER_STATUSES=new Set([STATUS_PENDING,STATUS_CORRECTED,STATUS_REVIEW]);
const CORRECTABLE_ORDER_STATUSES=new Set([STATUS_PENDING,STATUS_CORRECTED,STATUS_NEEDS_CORRECTION,STATUS_REVIEW]);
// waiting orders an admin can take into review (the customer can no longer cancel them)
const REVIEW_START_STATUSES=new Set([STATUS_PENDING,STATUS_CORRECTED]);

let sb, adminUser=null, adminName='ئادمین', adminRole='admin';
let allOrders=[], allAccounts=[], allRates=[], allNotifs=[];
let orderFilter='all', accFilter='all';
let _notifTarget='all', _notifSelectedUser=null;
let _profMap={};

// Routes every security call straight to the is_ex_admin()-guarded RPCs that
// actually exist in the database (ex_admin_*), instead of the /api/security-admin
// endpoint, which was written against an older schema (security_check_request,
// security_alerts, security_admins — none of which exist here).
// The response shape is kept identical so no call site had to change.
async function securityRequest(view, options={}){
  if(!isSuperAdmin())throw new Error('SUPER_ADMIN_REQUIRED');
  const {data:{session}}=await sb.auth.getSession();
  if(!session) throw new Error('تکایە دووبارە بچۆ ژوورەوە');

  const q   = new URLSearchParams(options.query||'');
  const num = (k,d)=>{ const v=parseInt(q.get(k),10); return Number.isFinite(v)?v:d; };
  const call= async (fn,args)=>{
    const {data,error}=await sb.rpc(fn,args);
    if(error) throw new Error(error.message||'هەڵەی پەیوەندی بە سیستەمی ئاسایش');
    return data;
  };

  if((options.method||'GET')==='GET'){
    switch(view){
      case 'dashboard': {
        const limit=num('limit',200);
        const [stats,bans,logs]=await Promise.all([
          call('ex_admin_ip_stats',{}),
          call('ex_admin_list_bans',{p_active_only:false,p_limit:limit}),
          call('ex_admin_list_events',{p_limit:limit,p_ip:null,p_user_id:null,p_type:null})
        ]);
        return { stats:stats||{}, bans:bans||[], logs:logs||[] };
      }
      case 'alerts':
        return { alerts: (await call('ex_admin_pending_alerts',{p_limit:num('limit',20)}))||[] };
      case 'bans':
        return { bans: (await call('ex_admin_list_bans',{p_active_only:false,p_limit:num('limit',200)}))||[] };
      case 'account-ip-summary':
        return { accounts: (await call('ex_admin_accounts_ip_summary',{}))||[] };
      case 'user-ips':
        return { ips: (await call('ex_admin_user_ips',{p_user_id:q.get('user_id'),p_limit:num('limit',50)}))||[] };
      case 'ip-accounts':
        return { accounts: (await call('ex_admin_ip_accounts',{p_ip:q.get('ip')}))||[] };
      default:
        throw new Error('داواکاری نەناسراو: '+view);
    }
  }

  const b=options.body||{};
  switch(b.action){
    case 'ban':
      return { id: await call('ex_admin_ban_ip',{
        p_ip:b.ip, p_reason:b.reason||null,
        p_hours:(b.hours===undefined?null:b.hours),
        p_user_id:b.user_id||null, p_notes:b.notes||null }) };
    case 'unban':
      return { ok: await call('ex_admin_unban_ip',{p_id:b.id}) };
    case 'extend':
      return { ok: await call('ex_admin_extend_ban',{p_id:b.id,p_hours:(b.hours===undefined?null:b.hours)}) };
    case 'resolve':
      return { count: await call('ex_admin_resolve_alert',{
        p_id:b.id, p_status:b.status||'dismissed', p_all_for_ip:!!b.all_for_ip }) };
    case 'ban_from_alert':
      return { id: await call('ex_admin_ban_from_alert',{
        p_id:b.alert_id, p_hours:(b.hours===undefined?null:b.hours) }) };
    default:
      throw new Error('کرداری نەناسراو: '+(b.action||''));
  }
}

async function adminApiRequest(action, payload={}){
  const {data:{session}}=await sb.auth.getSession();
  if(!session) throw new Error('تکایە دووبارە بچۆ ژوورەوە');
  const response=await fetch('/api/admin',{
    method:'POST',
    headers:{'Content-Type':'application/json','Authorization':'Bearer '+session.access_token},
    body:JSON.stringify({action,payload})
  });
  let body={};
  try{ body=await response.json(); }catch(_){}
  if(!response.ok || !body.ok){
    const error=new Error(body.error||'هەڵەی پەیوەندی بە سێرڤەر');
    error.code=body.code;error.status=response.status;throw error;
  }
  return body.data;
}

// ══════════════════════════════════════════════════════════════
// ═══ SIDEBAR ═════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
function openSidebar(){ document.getElementById('sidebar').classList.add('show'); document.getElementById('sidebarOverlay').classList.add('show'); }
function closeSidebar(){ document.getElementById('sidebar').classList.remove('show'); document.getElementById('sidebarOverlay').classList.remove('show'); }

// ══════════════════════════════════════════════════════════════
// ═══ INIT ════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', ()=>{
  sb = window.supabase.createClient(SB_URL, SB_KEY, { auth:{ persistSession:true, autoRefreshToken:true, storageKey:'zex_admin_sb_session' } });
  updateClock(); setInterval(updateClock, 60000);
  sb.auth.getSession().then(async ({data:{session}})=>{
    if(session?.user){
      adminUser = session.user;
      const ok = await verifyAdmin(adminUser.id, adminUser.email);
      if(ok) showApp(); else { await sb.auth.signOut(); }
    }
  });
  document.querySelectorAll('.overlay').forEach(o=>{
    o.addEventListener('click', e=>{ if(e.target===o) closeMo(o.id); });
  });
});

function updateClock(){ document.getElementById('currentTime').textContent = new Date().toLocaleTimeString('ku',{hour:'2-digit',minute:'2-digit'}); }

// ══════════════════════════════════════════════════════════════
// ═══ AUTH ════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
async function verifyAdmin(uid, email, {strict=false}={}){
  // Admin rights live in ex_profiles.is_admin — the same column the panel's
  // "کردن بە ئادمین" button writes and the database's is_ex_admin() RLS
  // helper reads. (The old security_admins table does not exist.)
  try{
    const {data:prof, error} = await sb
      .from('ex_profiles')
      .select('full_name,email,is_admin,is_banned,role,username,staff_permissions')
      .eq('id', uid)
      .maybeSingle();
    if(error){if(strict)throw error;return false;}
    if(!prof || !prof.is_admin || prof.is_banned) return false;
    adminName = prof.full_name || email.split('@')[0];
    adminRole = prof.role || 'admin';
    adminStaffPermissions=prof.staff_permissions??null;
    if(!staffCan('view'))return false;
    return true;
  }catch(e){if(strict)throw e;return false;}
}

async function doLogin(){
  const email=document.getElementById('loginEmail').value.trim();
  const pass=document.getElementById('loginPass').value;
  const btn=document.getElementById('loginBtn');
  if(!email||!pass){ showAuthErr('ئیمەیل و پاسۆرد پڕ بکەرەوە'); return; }
  btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    if(window.ProxoAccess && !await ProxoAccess.check())return;
    await window.trackAuthAttempt?.(email,'admin');
    const {data,error} = await sb.auth.signInWithPassword({email,password:pass});
    if(error)window.trackEvent?.('login_failed',email);
    if(error){ showAuthErr('ئیمەیل یان پاسۆرد هەڵەیە'); return; }
    adminUser = data.user;
    const ok = await verifyAdmin(adminUser.id, adminUser.email);
    if(!ok){
      await sb.auth.signOut();
      showAuthErr('تۆ مافی دەستگەیشتن بە پانێڵی ئادمین نییەت');
      return;
    }
    document.getElementById('authErr').style.display='none';
    showApp();
  }catch(e){
    showAuthErr('هەڵەی پەیوەندی: '+e.message);
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-arrow-left"></i> چوونەژوورەوە';
  }
}
function showAuthErr(msg){
  const el=document.getElementById('authErr');
  el.textContent=msg; el.style.display='block';
}
async function doLogout(){
  try{ await sb.auth.signOut(); }catch(_){}
  location.reload();
}
function showApp(){
  document.getElementById('authWrap').style.display='none';
  document.getElementById('main').classList.add('show');
  document.getElementById('sbAv').textContent = (adminName||'A')[0].toUpperCase();
  document.getElementById('sbAdminName').textContent = adminName;
  const roleEl=document.getElementById('sbAdminRole');
  if(roleEl) roleEl.textContent = isSuperAdmin() ? 'سوپەر ئادمین' : staffFullAdmin()?'ئادمین':'کارمەند';
  applyStaffUI();
  recordAdminVisit();
  notePageDefaults();
  loadWalletMeta();
  goPage('dashboard');
  openOrderFromLink();
  subscribeOrdersAdmin();
  startAdminLive();
  if(staffFullAdmin()){
    subscribeAlerts();startErrorLogMonitor();startSupportCaseMonitor();startKycMonitor();
  }
}
function isSuperAdmin(){ return adminRole==='super_admin'; }

// The admin page does not load the public assets/js/track.js file. Record its
// authenticated visit here so administrator accounts also get an IP history.
async function recordAdminVisit(){
  try{
    const {data:{session}}=await sb.auth.getSession();
    if(!session) return;
    await fetch('/api/track', {
      method:'POST',
      headers:{
        'Content-Type':'application/json',
        'Authorization':'Bearer '+session.access_token
      },
      body:JSON.stringify({type:'admin_login',detail:location.pathname}),
      keepalive:true
    });
  }catch(_){ /* telemetry must never break the admin panel */ }
}

// ══════════════════════════════════════════════════════════════
// ═══ PAGE ROUTING ════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
const pageConfig = {
  dashboard:{ title:'داشبۆرد', sub:'دیمەنی گشتی سیستەم', load: ()=>loadDashboard() },
  orders:{ title:'ئۆردەرەکان', sub:'پەسەندکردن و ڕەتکردنەوەی داواکارییە گۆڕینەوەکان', load: ()=>openOrdersPage() },
  accounts:{ title:'هەژمارەکان', sub:'بەڕێوەبردنی هەژمارەکانی بەکارهێنەران', load: ()=>openAccountsPage() },
  kyc:{ title:'پشتڕاستکردنەوەی ناسنامە', sub:'داواکردن، پشکنین و پەسەندکردنی بەڵگەنامەی ناسنامە', load: ()=>loadKycAdmin() },
  wallets:{ title:'واڵێتەکان', sub:'زیادکردن، قوفڵکردن و دەستکاریکردنی واڵێتەکانی وەرگرتنی پارە', load: ()=>loadWalletsAdmin() },
  balance:{title:'پوختەی باڵانس',sub:'کۆی باڵانس، هاوتایی حسابداری و باڵانسی هەژمارەکان',load:()=>loadBalanceAdmin()},
  balanceRefunds:{title:'ڕیفاوند و بڕی کەم نێردراو',sub:'گەڕانی ئۆردەر، گەڕاندنەوە و مێژووی ڕیفاوند',load:()=>loadBalanceAdmin()},
  balancePayouts:{title:'داواکاری ناردنی باڵانس',sub:'خوێندنەوە و پێداچوونەوەی داواکارییەکانی ناردن',load:()=>loadBalanceAdmin()},
  balanceManual:{title:'دەستکاریی دەستیی باڵانس',sub:'زیادکردن، گەڕاندنەوە و کەمکردنەوە لەگەڵ تۆمار',load:()=>loadBalanceAdmin()},
  balanceRisk:{title:'ئاگاداریی مەترسی',sub:'پشکنین و چارەسەرکردنی ئاگادارییە دارایییەکان',load:()=>loadBalanceAdmin()},
  rates:{ title:'نرخ و کرێ', sub:'ڕێکخستنی نرخی گۆڕینەوە و کرێی هەر ڕێگایەک', load: ()=>loadRates() },
  contracts:{ title:'گرێبەست', sub:'گرێبەستی بەکرێدان و واژووی هەردوو لایەن', load: ()=>loadContracts() },
  notifications:{ title:'ئاگادارییەکان', sub:'ناردنی ئاگاداری و بینینی مێژوو', load: ()=>loadNotifPage() },
  cases:{ title:'کەیسەکانی کڕیار', sub:'وێنە، وردەکاری و چارەسەرکردنی کێشەکانی کڕیار', load: ()=>loadSupportCasesAdmin() },

  security:{ title:'ئاسایش و IP', sub:'ڕووداوە گومانلێکراوەکان و بلۆککردنی IP و پەڕەی ئاگادارکردنەوە', load: ()=>loadSecurity() },
  errors:{ title:'لۆگی هەڵەکان', sub:'هەڵەکانی ماڵپەڕی بەکارهێنەر و سێرڤەر', load: ()=>loadErrorLogs() },
};
let _curPage='dashboard';
// Leaving a section resets it: searches are emptied, every filter row goes back to
// the choice it starts with, the orders and accounts lists are dropped, and coming
// back reads fresh data. The starting choice of each filter row is noted once.
function notePageDefaults(){
  document.querySelectorAll('.pg .chip.on, .pg .lv-tab.on').forEach(c=>{ c.dataset.defaultOn='1'; });
}
function resetPage(p){
  const pg=document.getElementById('pg'+p.charAt(0).toUpperCase()+p.slice(1));
  if(!pg) return;
  const ownList=p==='orders'||p==='accounts';
  if(p==='orders'){ orderFilter='all'; _ordShown=LIST_STEP; allOrders=[]; _ordLoadedAt=0; const w=document.getElementById('ordersTableWrap'); if(w) w.innerHTML=''; }
  if(p==='accounts'){ accFilter='all'; _accShown=LIST_STEP; allAccounts=[]; _accLoadedAt=0; const w=document.getElementById('accountsTableWrap'); if(w) w.innerHTML=''; }
  pg.querySelectorAll('input.tbl-search, input.lv-search').forEach(i=>{
    if(!i.value) return;
    i.value='';
    if(!ownList) i.dispatchEvent(new Event('input'));
  });
  pg.querySelectorAll('[data-default-on]').forEach(first=>{
    if(first.classList.contains('on')) return;
    const row=[...first.parentElement.children].filter(c=>c.classList.contains('chip')||c.classList.contains('lv-tab'));
    if(ownList||!first.getAttribute('onclick')) row.forEach(c=>c.classList.toggle('on',c===first));
    else first.click();
  });
  pg.querySelectorAll('details.lv-more[open]').forEach(d=>d.removeAttribute('open'));
  if(typeof pageConfig[p]?.reset==='function') pageConfig[p].reset();
}
function goPage(p){
  if(typeof staffPageAllowed==='function'&&!staffPageAllowed(p)){showToast('مۆڵەتی ئەم بەشەت نییە','rd');return;}
  if(_curPage&&_curPage!==p) resetPage(_curPage);
  _curPage=p;
  try{ window.scrollTo(0,0); document.getElementById('main')?.scrollTo?.(0,0); }catch(_){}
  document.querySelectorAll('.pg').forEach(x=>x.classList.remove('on'));
  document.querySelectorAll('.sb-item').forEach(x=>x.classList.remove('active'));
  const pg=document.getElementById('pg'+p.charAt(0).toUpperCase()+p.slice(1));
  if(pg) pg.classList.add('on');
  const sbItem=document.querySelector(`.sb-item[onclick="goPage('${p}')"]`);
  if(sbItem) sbItem.classList.add('active');
  const cfg=pageConfig[p];
  if(cfg){
    document.getElementById('pageTitle').textContent=cfg.title;
    document.getElementById('pageSubtitle').textContent=cfg.sub;
    if(cfg.load) cfg.load();
  }
  closeSidebar();
}

// ══════════════════════════════════════════════════════════════
// ═══ CUSTOMER SUPPORT CASES ═══════════════════════════════════
// Cases and private image URLs are served through /api/admin. The browser
// never receives the service-role key and signed image URLs expire quickly.
// ══════════════════════════════════════════════════════════════
let _supportCasesAdmin=[];
let _supportCaseFilter='unresolved';
let _supportCasePoll=null;
let _lastSupportCaseCount=null;

function supportCaseNumber(row){
  const value=Number(row?.case_number);
  return Number.isInteger(value) ? String(value).padStart(6,'0') : '—';
}
function supportCaseStatusLabel(status){
  return status==='open'?'نوێ':status==='in_progress'?'لەژێر پشکنینە':status==='resolved'?'چارەسەرکرا':'داخراوە';
}
function supportCaseStatusClass(status){
  return status==='resolved'?'approved':status==='closed'?'rejected':status==='in_progress'?'pending':'order_status';
}
function supportCaseCategoryLabel(category){
  return category==='order'?'کێشەی داواکاری':category==='payment'?'کێشەی پارەدان':category==='account'?'کێشەی هەژمار':category==='technical'?'کێشەی تەکنیکی':'کێشەی تر';
}

async function loadSupportCaseSummary(notify=true){
  try{
    const stats=await adminApiRequest('support_case_summary');
    const unresolved=Number(stats?.unresolved||0);
    const badge=document.getElementById('sbCaseCount');
    if(badge){
      badge.textContent=unresolved>99?'99+':String(unresolved);
      badge.style.display=unresolved?'inline-flex':'none';
    }
    const set=(id,value)=>{ const el=document.getElementById(id); if(el) el.textContent=formatNum(value||0); };
    set('caseOpenCount',stats?.open);
    set('caseProgressCount',stats?.in_progress);
    set('caseResolvedCount',stats?.resolved);
    set('caseTodayCount',stats?.today);
    if(notify && unresolved>0 && (_lastSupportCaseCount===null || unresolved>_lastSupportCaseCount)){
      const added=_lastSupportCaseCount===null?unresolved:unresolved-_lastSupportCaseCount;
      showToast(added+' کەیسی نوێی کڕیار هەیە','bl');
    }
    _lastSupportCaseCount=unresolved;
    return stats;
  }catch(_){ return null; }
}

function startSupportCaseMonitor(){
  loadSupportCaseSummary(true);
  clearInterval(_supportCasePoll);
  _supportCasePoll=setInterval(()=>{
    if(document.visibilityState==='visible') loadSupportCaseSummary(true);
  },30000);
}

async function loadSupportCasesAdmin(){
  const wrap=document.getElementById('supportCasesAdminWrap');
  if(wrap) wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const [rows]=await Promise.all([
      adminApiRequest('list_support_cases',{status:_supportCaseFilter,limit:300}),
      loadSupportCaseSummary(false)
    ]);
    _supportCasesAdmin=Array.isArray(rows)?rows:[];
    renderSupportCasesAdmin();
  }catch(e){
    if(wrap) wrap.innerHTML='<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: '+esc(e.message)+'</p></div>';
  }
}

function setSupportCaseFilter(filter,el){
  _supportCaseFilter=filter;
  document.querySelectorAll('[data-casef]').forEach(x=>x.classList.remove('on'));
  if(el) el.classList.add('on');
  loadSupportCasesAdmin();
}

function renderSupportCasesAdmin(){
  const wrap=document.getElementById('supportCasesAdminWrap');
  if(!wrap) return;
  const search=(document.getElementById('caseAdminSearch')?.value||'').trim().toLowerCase();
  const rows=_supportCasesAdmin.filter(row=>{
    if(!search) return true;
    return [supportCaseNumber(row),row.profile?.full_name,row.profile?.email,row.profile?.phone,row.order_code,row.description,row.admin_note]
      .some(value=>String(value||'').toLowerCase().includes(search));
  });
  if(!rows.length){
    wrap.innerHTML='<div class="empty"><i class="fas fa-headset"></i><p>هیچ کەیسێک نییە</p></div>';
    return;
  }

  wrap.innerHTML='<div class="support-admin-list">'+rows.map(row=>{
    const id=String(row.id||'');
    const profile=row.profile||{};
    return `<article class="support-admin-card ${esc(row.status)}">
      <div class="support-admin-head">
        <div><b class="support-case-number">${esc(supportCaseNumber(row))}</b><small>${esc(fmtDateTime(row.created_at))}</small></div>
        <span class="badge ${supportCaseStatusClass(row.status)}">${esc(supportCaseStatusLabel(row.status))}</span>
      </div>
      <div class="support-admin-facts">
        <span><i class="fas fa-user"></i><b>${esc(profile.full_name||'بێ ناو')}</b><small>${esc(profile.email||'—')}</small></span>
        <span><i class="fas fa-phone"></i><b dir="ltr">${esc(profile.phone||'—')}</b><small>${esc(supportCaseCategoryLabel(row.category))}</small></span>
      </div>
      ${supportCaseOrderHTML(row)}
      <div class="support-admin-description">${esc(row.description)}</div>
      ${row.image_url?`<button type="button" class="support-image-btn" onclick='showImg(${safeAttr(row.image_url)})'><i class="fas fa-image"></i> بینینی وێنەی کێشە</button>`:''}
      <div class="support-admin-controls">
        <label><span>دۆخی کەیس</span><select class="minp" id="caseStatus-${esc(id)}">
          <option value="open" ${row.status==='open'?'selected':''}>نوێ</option>
          <option value="in_progress" ${row.status==='in_progress'?'selected':''}>لەژێر پشکنینە</option>
          <option value="resolved" ${row.status==='resolved'?'selected':''}>چارەسەرکرا</option>
          <option value="closed" ${row.status==='closed'?'selected':''}>داخراوە</option>
        </select></label>
        <label class="support-note-field"><span>وەڵام/تێبینی بۆ کڕیار</span><textarea class="minp mta" id="caseNote-${esc(id)}" maxlength="2000" placeholder="چارەسەر یان زانیاری پێویست بۆ کڕیار بنووسە...">${esc(row.admin_note||'')}</textarea></label>
        <div class="support-admin-actions">
          <button type="button" class="modal-btn cy support-save-btn" id="caseSave-${esc(id)}" onclick="saveSupportCaseAdmin('${esc(id)}')"><i class="fas fa-check"></i> پاشەکەوت و ئاگادارکردنەوەی کڕیار</button>
        </div>
      </div>
    </article>`;
  }).join('')+'</div>';
}

// the transaction a case is about (the customer chose it from their own): route, state, amount,
// code and date; one tap opens it in the order window, with its actions
function supportCaseOrderHTML(row){
  if(!row.order_code) return '';
  const o=row.order;
  if(!o){
    const why=row.order_state==='other_customer'?'ئەم مامەڵەیە هی کڕیارێکی ترە':'ئەم مامەڵەیە نەدۆزرایەوە';
    return `<div class="support-admin-order is-missing"><i class="fas fa-triangle-exclamation" aria-hidden="true"></i><b dir="ltr">${esc(row.order_code)}</b><small>${why}</small></div>`;
  }
  const amount=formatNum(o.amount)+(o.from_method==='USDT'?' $':' IQD');
  return `<button type="button" class="support-admin-order" onclick="showSupportCaseOrder('${esc(String(row.id))}')"
      aria-label="${esc('بینینی مامەڵەی '+(o.order_code||'')+': '+walletName(o.from_method)+' بۆ '+walletName(o.to_method)+'، '+amount)}">
    <span class="sao-top">
      <span class="sao-route"><span class="lv-w">${walletMark(o.from_method)}<span>${esc(walletName(o.from_method))}</span></span><i class="fas fa-arrow-left lv-arrow" aria-hidden="true"></i><span class="lv-w">${walletMark(o.to_method)}<span>${esc(walletName(o.to_method))}</span></span></span>
      ${orderBadgeHTML(o)}
    </span>
    <span class="sao-meta"><b dir="ltr">${esc(amount)}</b><span dir="ltr">${esc(o.order_code||'')}</span><span>${esc(fmtDateTime(o.created_at))}</span></span>
    <span class="sao-open">بینینی مامەڵە<i class="fas fa-arrow-left" aria-hidden="true"></i></span>
  </button>`;
}
async function showSupportCaseOrder(caseId){
  const row=_supportCasesAdmin.find(r=>String(r.id)===String(caseId));
  const o=row?.order; if(!o) return;
  // the order window reads allOrders: put this one there, with the customer's full profile
  let profile=row.profile||null;
  try{ profile=(await loadProfilesFor([o.user_id]))[o.user_id]||profile; }catch(_){}
  const order={...o,profile};
  const i=allOrders.findIndex(x=>String(x.id)===String(o.id));
  if(i>-1) allOrders[i]={...allOrders[i],...order}; else allOrders.push(order);
  showOrderDetail(o.id);
}

async function saveSupportCaseAdmin(id){
  const statusEl=document.getElementById('caseStatus-'+id);
  const status=statusEl?.value;
  const adminNote=document.getElementById('caseNote-'+id)?.value||'';
  const btn=document.getElementById('caseSave-'+id);
  if(btn){ btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i> پاشەکەوتکردن...'; }
  try{
    const updated=await adminApiRequest('update_support_case',{id,status,admin_note:adminNote});
    showToast(updated?.notification_sent
        ? 'کەیسەکە نوێکرایەوە و کڕیار ئاگادارکرایەوە'
      : 'کەیسەکە نوێکرایەوە','gr');
    await loadSupportCasesAdmin();
  }catch(e){
    showToast(e.message||'نەتوانرا کەیسەکە نوێ بکرێتەوە','rd');
    if(btn){ btn.disabled=false; btn.innerHTML='<i class="fas fa-check"></i> پاشەکەوت و ئاگادارکردنەوەی کڕیار'; }
  }
}

// ══════════════════════════════════════════════════════════════
// ═══ APPLICATION ERROR LOGS ═══════════════════════════════════
// Data is read through /api/admin; the service-role-only table is never
// exposed directly to the browser.
// ══════════════════════════════════════════════════════════════
let _errorLogs=[];
let _errorFilter='unresolved';
let _errorPoll=null;
let _lastErrorCount=null;

// What each row means, in plain words. operation / code come from the API
// (auth.js, admin.js, notify-order.js), the database (WhatsApp worker) and
// the customer app (reportAppError).
const ERROR_TITLES={
  whatsapp_code:'کۆدی دڵنیایی بە واتسئاپ نەنێردرا',
  email_code:'کۆدی دڵنیایی بە ئیمەیڵ نەنێردرا',
  whatsapp_notification:'ئاگاداری واتسئاپی داواکاری نەگەیشتە کڕیار',
  whatsapp_queue:'نامەکانی واتسئاپ لە نۆبەدا ماونەتەوە (n8n نایاننێرێت)',
  telegram_notify:'ئاگاداری داواکاری نوێ بۆ تێلێگرام نەنێردرا',
  auth_session:'چوونەژوورەوە لە سێرڤەردا سەرکەوتوو نەبوو',
  auth_signup:'دروستکردنی هەژمار سەرکەوتوو نەبوو',
  auth_phone_change:'گۆڕینی ژمارەی مۆبایل سەرکەوتوو نەبوو',
  auth_email_change:'گۆڕینی ئیمەیڵ سەرکەوتوو نەبوو',
  auth_password_change:'گۆڕینی وشەی نهێنی سەرکەوتوو نەبوو',
  auth_server:'هەڵەی سێرڤەری چوونەژوورەوە',
  order_submission:'ناردنی داواکاری سەرنەکەوت',
  order_correction:'ڕاستکردنەوەی داواکاری سەرنەکەوت',
  kyc_submit:'ناردنی ناسنامە سەرنەکەوت',
  kyc_status:'بارکردنی دۆخی ناسنامە سەرنەکەوت',
  support_case_submission:'ناردنی کەیسی پشتگیری سەرنەکەوت',
  support_cases_load:'بارکردنی کەیسەکانی پشتگیری سەرنەکەوت',
  client_runtime:'هەڵەی JavaScript لە وێبگەڕی کڕیار'
};
const ERROR_WHEN_CODE={WHATSAPP_NOT_CONFIGURED:'ناردنی کۆدی واتسئاپ ڕێکنەخراوە (کلیلی Wevlix نییە)'};
const ERROR_ACTIONS={signup_start:'خۆتۆمارکردن',login_start:'چوونەژوورەوە',reset_start:'وشەی نهێنیی لەبیرچوو',phone_change_start:'گۆڕینی ژمارە',email_change_start:'گۆڕینی ئیمەیڵ',signup_finish:'خۆتۆمارکردن',login_finish:'چوونەژوورەوە'};
const ERROR_CATEGORIES={all:'هەموو',codes:'کۆدی دڵنیایی',whatsapp:'واتسئاپ و تێلێگرام',requests:'ناردنی داواکاری',server:'سێرڤەر',client:'وێبگەڕ'};
function errorCategory(row){
  const op=String(row.operation||'');
  if(/^(whatsapp_code|email_code|auth_)/.test(op)) return 'codes';
  if(row.source==='whatsapp'||/^(whatsapp_|telegram_)/.test(op)) return 'whatsapp';
  if(/^(order_|kyc_submit|support_case_submission)/.test(op)||/\/api\/(orders|support-cases)/.test(op)) return 'requests';
  if(row.source==='server') return 'server';
  return 'client';
}
function errorTitle(row){
  const op=String(row.operation||'');
  if(ERROR_WHEN_CODE[row.error_code]) return ERROR_WHEN_CODE[row.error_code];
  if(ERROR_TITLES[op]) return ERROR_TITLES[op];
  if(op.startsWith('admin:')) return 'هەڵەی پانێڵ: '+op.slice(6);
  if(row.source==='server') return 'هەڵەی سێرڤەر: '+op;
  return op||'هەڵە';
}
function errorSourceLabel(source){ return source==='server'?'سێرڤەر':source==='whatsapp'?'واتسئاپ (n8n)':'وێبگەڕی کڕیار'; }
function errorSeverityLabel(severity){ return severity==='critical'?'گرنگ':severity==='warning'?'ئاگاداری':'هەڵە'; }
function errorWhen(value){ return value?fmtDateTime(value):'—'; }
// Wevlix / n8n answers arrive as JSON text: show the readable part
function errorReason(row){
  const raw=String(row.message||'');
  try{
    const j=JSON.parse(raw);
    const details=Array.isArray(j.details)?j.details.map(d=>(d.field?d.field+': ':'')+(d.constraints||[]).join(', ')).join(' · '):'';
    return [j.code,j.message,j.error,details].filter(v=>typeof v==='string'&&v).join(' — ')||raw;
  }catch(_){ return raw; }
}
function errorMetaText(row){
  const meta=row.metadata&&typeof row.metadata==='object'?row.metadata:{};
  const parts=[];
  if(meta.action&&ERROR_ACTIONS[meta.action]) parts.push(ERROR_ACTIONS[meta.action]);
  if(meta.target) parts.push('بۆ '+meta.target);
  if(meta.provider_status) parts.push('وەڵامی دابینکەر: '+meta.provider_status);
  if(meta.order_code) parts.push('داواکاری '+meta.order_code);
  if(meta.attempts) parts.push(meta.attempts+' هەوڵ');
  if(meta.waiting) parts.push(meta.waiting+' نامە چاوەڕێن');
  if(meta.stage) parts.push('قۆناغ: '+meta.stage);
  if(meta.from_method||meta.to_method) parts.push((meta.from_method||'—')+' ← '+(meta.to_method||'—'));
  if(meta.online===false) parts.push('ئۆفلاین');
  if(row.http_status) parts.push('HTTP '+row.http_status);
  return parts.join(' · ');
}
function errorWho(row){
  if(row.user_name||row.user_email||row.user_phone) return {name:row.user_name||row.user_email||'—',sub:[row.user_phone,row.user_name?row.user_email:null].filter(Boolean).join(' · ')};
  const target=row.metadata?.target;
  return {name:target?'بێ هەژمار':'—',sub:target||''};
}

async function loadErrorLogSummary(notify=true){
  try{
    const stats=await adminApiRequest('error_log_summary');
    const unresolved=Number(stats?.unresolved||0);
    const badge=document.getElementById('sbErrorCount');
    if(badge){
      badge.textContent=unresolved>99?'99+':unresolved;
      badge.style.display=unresolved?'inline-flex':'none';
    }
    const set=(id,value)=>{ const el=document.getElementById(id); if(el) el.textContent=formatNum(value||0); };
    set('errUnresolved',unresolved); set('errLast24h',stats?.last_24h); set('errCritical',stats?.critical);
    if(notify && unresolved>0 && (_lastErrorCount===null || unresolved>_lastErrorCount)){
      const added=_lastErrorCount===null?unresolved:unresolved-_lastErrorCount;
      showToast(added+' لۆگی هەڵەی نوێ هەیە','rd');
    }
    _lastErrorCount=unresolved;
    return stats;
  }catch(_){ return null; }
}

function startErrorLogMonitor(){
  loadErrorLogSummary(true);
  clearInterval(_errorPoll);
  _errorPoll=setInterval(()=>{
    if(document.visibilityState==='visible') loadErrorLogSummary(true);
  },30000);
}

async function loadErrorLogs(){
  const wrap=document.getElementById('errorLogsWrap');
  if(wrap) wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const [logs]=await Promise.all([
      adminApiRequest('list_error_logs',{status:_errorFilter,limit:300}),
      loadErrorLogSummary(false)
    ]);
    _errorLogs=Array.isArray(logs)?logs:[];
    renderErrorLogs();
  }catch(e){
    if(wrap) wrap.innerHTML='<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: '+esc(e.message)+'</p></div>';
  }
}

function setErrorLogFilter(filter,el){
  _errorFilter=filter;
  document.querySelectorAll('[data-errf]').forEach(x=>x.classList.remove('on'));
  if(el) el.classList.add('on');
  loadErrorLogs();
}
let _errorCat='all', _errorWarnings=false;
function setErrorCategory(cat,el){
  _errorCat=cat;
  document.querySelectorAll('[data-errc]').forEach(x=>x.classList.toggle('on',x===el));
  renderErrorLogs();
}
function toggleErrorWarnings(el){
  _errorWarnings=!_errorWarnings;
  if(el) el.classList.toggle('on',_errorWarnings);
  renderErrorLogs();
}

function renderErrorLogs(){
  const wrap=document.getElementById('errorLogsWrap');
  if(!wrap) return;
  const search=(document.getElementById('errorSearch')?.value||'').trim().toLowerCase();
  const counts={all:0};
  const visible=_errorLogs.filter(row=>_errorWarnings||row.severity!=='warning');
  visible.forEach(row=>{ const c=errorCategory(row); counts[c]=(counts[c]||0)+1; counts.all++; });
  document.querySelectorAll('[data-errc]').forEach(el=>{
    const n=counts[el.dataset.errc]||0;
    el.textContent=ERROR_CATEGORIES[el.dataset.errc]+(n?' ('+formatNum(n)+')':'');
  });
  const rows=visible.filter(row=>{
    if(_errorCat!=='all' && errorCategory(row)!==_errorCat) return false;
    if(!search) return true;
    return [errorTitle(row),row.message,row.error_code,row.operation,row.user_email,row.user_name,row.user_phone,row.ip_address,row.path,row.browser,row.os,row.metadata?.target,row.metadata?.order_code]
      .some(value=>String(value||'').toLowerCase().includes(search));
  });
  if(!rows.length){
    wrap.innerHTML='<div class="empty"><i class="fas fa-circle-check"></i><p>هیچ هەڵەیەک نییە</p></div>';
    return;
  }
  const badge=row=>`<span class="badge ${row.resolved_at?'approved':row.severity==='critical'?'banned':row.severity==='warning'?'pending':'rejected'}">${row.resolved_at?'چارەسەرکرا':esc(errorSeverityLabel(row.severity))}</span>`;
  const reason=row=>{ const r=errorReason(row); return r&&r!==errorTitle(row)?r:''; };

  const table=`<table class="data-table error-log-table"><thead><tr>
    <th>کات</th><th>چی ڕوویدا</th><th>بەکارهێنەر</th><th>ئامێر</th><th>دۆخ</th><th></th>
  </tr></thead><tbody>${rows.map(row=>{ const who=errorWho(row), r=reason(row), meta=errorMetaText(row); return `<tr>
    <td><b>${esc(errorWhen(row.last_seen))}</b><small>${esc(errorSourceLabel(row.source))}</small></td>
    <td class="error-message-cell"><b>${esc(errorTitle(row))}</b>${r?`<small class="error-reason">${esc(r)}</small>`:''}${meta?`<small>${esc(meta)}</small>`:''}</td>
    <td><b>${esc(who.name)}</b>${who.sub?`<small class="mono-ltr">${esc(who.sub)}</small>`:''}</td>
    <td><b>${esc(row.browser||'—')}</b><small>${esc(row.os||'—')}${row.device?' · '+esc(row.device):''}</small></td>
    <td>${badge(row)}<small>${formatNum(row.occurrences||1)} جار${row.occurrences>1?' · یەکەم: '+esc(errorWhen(row.first_seen)):''}</small></td>
    <td>${row.resolved_at?'':`<button class="mini-action success" onclick="resolveErrorLog('${esc(row.id)}')"><i class="fas fa-check"></i> چارەسەرکرا</button>`}</td>
  </tr>`; }).join('')}</tbody></table>`;

  const cards=`<div class="error-log-cards">${rows.map(row=>{ const who=errorWho(row), r=reason(row), meta=errorMetaText(row); return `<article class="error-log-card ${row.resolved_at?'resolved':row.severity==='critical'?'critical':row.severity==='warning'?'warning':''}">
    <div class="error-log-card-head">${badge(row)}<span>${esc(errorWhen(row.last_seen))}</span></div>
    <h4>${esc(errorTitle(row))}</h4>
    ${r?`<div class="error-log-code">${esc(r)}</div>`:''}
    <div class="error-log-facts">
      <span><i class="fas fa-user"></i>${esc(who.name)}${who.sub?' · '+esc(who.sub):''}</span>
      ${meta?`<span><i class="fas fa-circle-info"></i>${esc(meta)}</span>`:''}
      <span><i class="fas fa-globe"></i>${esc(errorSourceLabel(row.source))}</span>
      <span><i class="fas fa-rotate"></i>${formatNum(row.occurrences||1)} جار</span>
    </div>
    ${row.resolved_at?'':`<button class="alert-btn safe" onclick="resolveErrorLog('${esc(row.id)}')"><i class="fas fa-check"></i> دیاریکردن وەک چارەسەرکراو</button>`}
  </article>`; }).join('')}</div>`;
  wrap.innerHTML=table+cards;
}

async function resolveErrorLog(id){
  try{
    await adminApiRequest('resolve_error_log',{id});
    showToast('لۆگەکە وەک چارەسەرکراو دیاری کرا','gr');
    await loadErrorLogs();
  }catch(e){ showToast(e.message||'هەڵە','rd'); }
}

function resolveAllErrorLogs(){
  if(!_lastErrorCount) return showToast('هیچ لۆگێکی چارەسەرنەکراو نییە','gr');
  confirm2('هەموو لۆگەکان چارەسەر کراون؟','هەموو لۆگە چارەسەرنەکراوەکان دەخرێنە دۆخی چارەسەرکراو.','fas fa-check-double','#16a34a',async()=>{
    try{
      const result=await adminApiRequest('resolve_all_error_logs');
      showToast(formatNum(result?.resolved||0)+' لۆگ چارەسەرکرا','gr');
      await loadErrorLogs();
    }catch(e){ showToast(e.message||'هەڵە','rd'); }
  });
}



// ══════════════════════════════════════════════════════════════
// ═══ SPAM & SUSPICIOUS ACTIVITY ALERTS ════════════════════════
// Rows arrive two ways: a Realtime stream from suspicious_events (protected
// by the security-admin RLS policy) and a 30s API poll as a socket fallback.
// All mutations stay on the server and use the service role there only.
// ══════════════════════════════════════════════════════════════
let _alerts = [], _alertChannel = null, _alertPoll = null;

const ALERT_TITLE = {
  suspicious_flooding:'ناردنی زۆری داواکاری لە کاتێکی کورتدا',
  order_flood:   'ناردنی زۆری داواکاری لە کاتێکی کورتدا',
  number_spray:  'پەخشکردنی ژمارەی جیاواز',
  honeypot:      'داوی Honeypot — بۆتێک دۆزرایەوە',
  receipt_probe: 'بەکارهێنانی دووبارەی پسووڵە',
  rapid_submit:  'ناردنی خێراتر لە تواناى مرۆڤ',
  otp_bruteforce:'هەوڵی دووبارەی کۆدی OTP',
  devtools_tamper:'دەستکاریکردنی کلاینت'
};
const ALERT_ICON = {
  suspicious_flooding:'fa-gauge-high',
  order_flood:'fa-gauge-high', number_spray:'fa-shuffle', honeypot:'fa-robot',
  receipt_probe:'fa-clone', rapid_submit:'fa-bolt', otp_bruteforce:'fa-key',
  devtools_tamper:'fa-screwdriver-wrench'
};

function alertAgo(t){
  const s=Math.max(1,Math.floor((Date.now()-new Date(t))/1000));
  if(s<60) return s+' چرکە لەمەوپێش';
  const m=Math.floor(s/60); if(m<60) return m+' خولەک لەمەوپێش';
  const h=Math.floor(m/60); if(h<24) return h+' کاتژمێر لەمەوپێش';
  return new Date(t).toLocaleString('ku-IQ');
}

async function loadAlerts(){
  try{
    const payload=await securityRequest('alerts',{query:'&limit=20'});
    _alerts=payload.alerts||[];
    renderAlerts();
  }catch(e){ /* the dashboard must still render without alerts */ }
}

function renderAlerts(){
  const zone=document.getElementById('alertZone');
  const list=document.getElementById('alertList');
  if(!zone||!list) return;

  if(!_alerts.length){ zone.classList.remove('show'); return; }
  zone.classList.add('show');
  document.getElementById('alertCount').textContent=_alerts.length;

  const sbBadge=document.getElementById('sbAlertCount');
  if(sbBadge){ sbBadge.style.display='inline-block'; sbBadge.textContent=_alerts.length; }

  list.innerHTML=_alerts.map(a=>{
    const sev = a.risk_score>=60 ? 'sev-high' : (a.risk_score>=40 ? '' : 'sev-med');
    const m   = a.meta||{};
    // "Submitted 4 orders in 75 seconds" — the metric that justifies the alert
    const metric = ['order_flood','suspicious_flooding'].includes(a.event_type) && m.orders
        ? `${m.orders} داواکاری لە ${m.seconds} چرکەدا`
        : (a.event_type==='number_spray' && m.distinct_phones
            ? `${m.distinct_phones} ژمارەی جیاواز لە ${m.orders_30m} داواکاریدا`
            : (a.detail||''));

    return `<div class="alert-card ${sev}" id="alert_${a.id}">
      <div class="alert-top">
        <div class="alert-ico"><i class="fas ${ALERT_ICON[a.event_type]||'fa-triangle-exclamation'}"></i></div>
        <div style="flex:1;min-width:0">
          <div class="alert-title">${esc(ALERT_TITLE[a.event_type]||a.event_type)}</div>
          ${metric?`<div class="alert-metric"><i class="fas fa-chart-line" style="margin-left:5px"></i>${esc(metric)}</div>`:''}
        </div>
        <div class="alert-time">${alertAgo(a.created_at)}</div>
      </div>

      <div class="alert-grid">
        <div class="alert-fact">
          <div class="k"><i class="fas fa-user"></i> هەژمار</div>
          <div class="v">${a.account_name?esc(a.account_name):'<span style="color:#6b7280">مێوان (نەچووەتە ژوورەوە)</span>'}</div>
          ${a.account_email?`<div class="sub">${esc(a.account_email)}</div>`:''}
        </div>
        <div class="alert-fact">
          <div class="k"><i class="fas fa-network-wired"></i> IP</div>
          <div class="v mono">${esc(a.ip_address||'—')}</div>
          ${a.ip_is_banned?'<div class="sub" style="color:#dc2626">بلۆککراوە</div>':''}
        </div>
        <div class="alert-fact">
          <div class="k"><i class="fas fa-desktop"></i> وێبگەڕ و ئامێر</div>
          <div class="v">${esc(a.browser||'—')}</div>
          <div class="sub">${esc(a.os||'—')} · ${esc(a.device||'—')}</div>
        </div>
        <div class="alert-fact">
          <div class="k"><i class="fas fa-gauge"></i> خاڵی مەترسی</div>
          <div class="v">${a.risk_score||0}</div>
          <div class="sub">${esc(a.detail||'')}</div>
        </div>
      </div>

      <div class="alert-statement">${esc(a.message||a.detail||`User ${a.account_name||a.account_email||'Guest'} on IP ${a.ip_address||'unknown'} using Browser ${a.browser||'unknown'} is suspected of spamming/flooding orders.`)}</div>

      <div class="alert-acts">
        ${a.ip_is_banned || !a.ip_address
          ? `<span class="alert-banned-tag"><i class="fas fa-ban"></i> ${a.ip_address?'ئەم IPـیە بلۆککراوە':'بێ IP'}</span>`
          : `<button class="alert-btn ban" onclick="banFromAlert('${a.id}')">
               <i class="fas fa-user-secret"></i> بلۆککردنی IP و پەڕەی ئاگادارکردنەوە
             </button>`}
        <button class="alert-btn safe" onclick="dismissAlert('${a.id}')">
          <i class="fas fa-check"></i> سەلامەتە — لابردن
        </button>
        ${a.ip_address?`<button class="alert-btn view" onclick="goPage('security');setTimeout(()=>{const s=document.getElementById('evtSearch');if(s){s.value='${esc(a.ip_address)}';renderEvents();}},250)">
          <i class="fas fa-list"></i> هەموو ڕووداوەکان
        </button>`:''}
      </div>
    </div>`;
  }).join('');
}

async function banFromAlert(id){
  const hrs=prompt('چەند کاتژمێر بلۆک بکرێت؟ (بەتاڵ = هەمیشەیی):','24');
  if(hrs===null) return;
  try{
    await securityRequest('action',{method:'POST',body:{action:'ban_from_alert',alert_id:id,hours:hrs.trim()===''?null:parseInt(hrs,10)}});
    showToast('IP بلۆککرا — ئێستا 404 وەردەگرێت','gr');
    _alerts=_alerts.filter(a=>a.id!==id);
    renderAlerts(); loadAlerts();
  }catch(e){ showToast(e.message||'نەتوانرا بلۆک بکرێت','rd'); }
}

async function dismissAlert(id){
  try{
    await securityRequest('action',{method:'POST',body:{action:'resolve',id,status:'dismissed'}});
    _alerts=_alerts.filter(a=>a.id!==id);
    renderAlerts();
  }catch(e){ showToast(e.message||'هەڵە','rd'); }
}

async function dismissAllAlerts(){
  confirm2('لابردنی هەموو ئاگادارییەکان','هەموو ئاگادارییە چاوەڕوانەکان وەک سەلامەت دەنێردرێن. دڵنیایت؟','fa-check','#16a34a', async ()=>{
    for(const a of [..._alerts]){
      try{ await securityRequest('action',{method:'POST',body:{action:'resolve',id:a.id,status:'dismissed'}}); }catch(_){}
    }
    _alerts=[]; renderAlerts(); showToast('هەموو ئاگادارییەکان لابران','gr');
  });
}

// Realtime: a new high-risk row lands on the dashboard without a refresh.
function subscribeAlerts(){
  if(_alertChannel){ try{ sb.removeChannel(_alertChannel); }catch(_){} }
  _alertChannel = sb.channel('admin_alerts')
    .on('postgres_changes',
        { event:'*', schema:'public', table:'suspicious_events' },
        payload => {
          const row=payload.new||payload.old;
          if(!row) return;
          loadAlerts();   // re-fetch through the RPC so joins/flags stay correct
          try{ showToast('⚠️ چالاکی گومانلێکراو دۆزرایەوە', 'rd'); }catch(_){}
        })
    .subscribe();

  clearInterval(_alertPoll);
  _alertPoll = setInterval(()=>{ if(document.visibilityState==='visible') loadAlerts(); }, 30000);
}

// ══════════════════════════════════════════════════════════════
// ═══ USER ↔ IP HISTORY (users table) ══════════════════════════
// ══════════════════════════════════════════════════════════════
let _accIps = {};   // user_id → { last_ip, ip_count, browser, os, device, last_ip_banned }

async function loadAccountIps(){
  try{
    const {accounts:data}=await securityRequest('account-ip-summary');
    _accIps={};
    (data||[]).forEach(r=>{ _accIps[r.user_id]=r; });
  }catch(_){ _accIps={}; }
}

function accIpCell(userId){
  const r=_accIps[userId];
  if(!r || !r.last_ip) return '<span style="color:var(--mt);font-size:11px">—</span>';
  return `<div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">
      <span class="ip-chip ${r.last_ip_banned?'banned':''}">${esc(r.last_ip)}</span>
      ${r.last_ip_banned
        ? `<button class="ip-ban-btn undo" title="کردنەوە" onclick="unbanIpByAddress('${esc(r.last_ip)}')"><i class="fas fa-lock-open"></i></button>`
        : `<button class="ip-ban-btn" title="بلۆککردنی ئەم IP (404)" onclick="banIpInline('${esc(r.last_ip)}','${esc(userId)}')"><i class="fas fa-ban"></i></button>`}
      ${r.ip_count>1?`<span class="ip-more" onclick="showUserIps('${esc(userId)}')">+${r.ip_count-1} تر</span>`:''}
    </div>
    <div style="font-size:10px;color:var(--mt);margin-top:3px">${esc(r.browser||'')} · ${esc(r.device||'')}</div>`;
}

async function banIpInline(ip, userId){
  const hrs=prompt('بلۆککردنی '+ip+' بۆ چەند کاتژمێر؟ (بەتاڵ = هەمیشەیی):','24');
  if(hrs===null) return;
  try{
    await securityRequest('action',{method:'POST',body:{
      action:'ban',ip,reason:'بلۆککردنی دەستی لە لیستی بەکارهێنەران',
      hours:hrs.trim()===''?null:parseInt(hrs,10),user_id:userId||null
    }});
    showToast('IP بلۆککرا — 404 وەردەگرێت','gr');
    await loadAccountIps(); renderAccounts((document.getElementById('accSearch')?.value||'').toLowerCase());
  }catch(e){ showToast(e.message||'هەڵە','rd'); }
}

async function unbanIpByAddress(ip){
  try{
    const {bans:data}=await securityRequest('bans');
    const row=(data||[]).find(b=>b.ip_address===ip);
    if(!row){ showToast('بلۆکەکە نەدۆزرایەوە','rd'); return; }
    await securityRequest('action',{method:'POST',body:{action:'unban',id:row.id}});
    showToast('IP کرایەوە','gr');
    await loadAccountIps(); renderAccounts((document.getElementById('accSearch')?.value||'').toLowerCase());
  }catch(e){ showToast(e.message||'هەڵە','rd'); }
}

async function showUserIps(userId){
  try{
    const {ips:data}=await securityRequest('user-ips',{query:'&user_id='+encodeURIComponent(userId)});
    if(!data||!data.length){ showToast('هیچ IPـیەک تۆمار نەکراوە','bl'); return; }
    document.getElementById('userIpsBody').innerHTML=`<table><thead><tr>
        <th>IP</th><th>وێبگەڕ / ئامێر</th><th>ڕووداو</th><th>دوایین</th><th>کردار</th>
      </tr></thead><tbody>
      ${data.map(r=>`<tr>
        <td><span class="ip-chip ${r.is_banned?'banned':''}">${esc(r.ip_address)}</span></td>
        <td><div style="font-size:12px">${esc(r.browser||'—')}</div>
            <div style="font-size:10px;color:var(--mt)">${esc(r.os||'')} · ${esc(r.device||'')}</div></td>
        <td>${r.events}</td>
        <td style="font-size:11px;color:var(--mt)">${new Date(r.last_seen).toLocaleString('ku-IQ')}</td>
        <td>${r.is_banned
              ? `<div class="act-btn gr" onclick="unbanIpByAddress('${esc(r.ip_address)}')"><i class="fas fa-lock-open"></i> کردنەوە</div>`
              : `<div class="act-btn rd" onclick="banIpInline('${esc(r.ip_address)}','${esc(userId)}')"><i class="fas fa-ban"></i> بلۆک (404)</div>`}</td>
      </tr>`).join('')}
    </tbody></table>`;
    openMo('moUserIps');
  }catch(e){ showToast(e.message||'هەڵە','rd'); }
}

// ══════════════════════════════════════════════════════════════
// ═══ SECURITY / IP INTELLIGENCE ═══════════════════════════════
// Every call goes through an is_ex_admin()-guarded RPC; the tables
// themselves are unreachable from any browser role.
// ══════════════════════════════════════════════════════════════
let _bans=[], _events=[], _banFilter='all', _evtFilter='all';

const EVT_LABEL = {
  suspicious_flooding:'گومانی Flood/Spam', duplicate_transaction_reference:'پسووڵە/ژمارەی دووبارە',
  account_scanning:'پشکنینی هەژمار', blocked_request:'داواکاری بلۆککراو',
  honeypot:'داوی Honeypot', receipt_probe:'پسووڵەی دووبارە', number_spray:'پەخشکردنی ژمارە',
  rapid_submit:'ناردنی خێرا', otp_bruteforce:'هەوڵی OTP', devtools_tamper:'دەستکاری کلاینت',
  order_submitted:'ناردنی داواکاری', login_failed:'چوونەژوورەوەی هەڵە', page_view:'سەردان',
  login:'چوونەژوورەوە', signup:'خۆتۆمارکردن', logout:'دەرچوون',
  otp_failed:'کۆدی OTPـی هەڵە', api_access:'داواکاری API',
  unauthorized_request:'داواکاری بێ مۆڵەت', order_flood:'زۆری داواکاری لە کاتێکی کورتدا'
};
const evtLabel = t => EVT_LABEL[t] || t;

function riskClass(n){ return n>=60?'rd':(n>=25?'yw':'gr'); }
function fmtWhen(t){ return t ? new Date(t).toLocaleString('ku-IQ') : '—'; }
// Registration timestamps: fixed Gregorian format so it renders the same on
// every device — some browsers have no data for the 'ku' locale and fall back
// to something unreadable.
function fmtDate(t){
  if(!t) return '—';
  const d=new Date(t); if(isNaN(d)) return '—';
  const p=n=>String(n).padStart(2,'0');
  return `${d.getFullYear()}/${p(d.getMonth()+1)}/${p(d.getDate())}`;
}
function fmtTime(t){
  if(!t) return '';
  const d=new Date(t); if(isNaN(d)) return '';
  const p=n=>String(n).padStart(2,'0');
  return `${p(d.getHours())}:${p(d.getMinutes())}`;
}
function fmtDateTime(t){ return t ? fmtDate(t)+' — '+fmtTime(t) : '—'; }
function fmtAgo(t){
  if(!t) return '';
  const s=Math.floor((Date.now()-new Date(t))/1000);
  if(s<0 || isNaN(s)) return '';
  if(s<3600) return Math.max(1,Math.floor(s/60))+' خولەک لەمەوپێش';
  const h=Math.floor(s/3600); if(h<24) return h+' کاتژمێر لەمەوپێش';
  const d=Math.floor(h/24);   if(d<30) return d+' ڕۆژ لەمەوپێش';
  const mo=Math.floor(d/30);  if(mo<12) return mo+' مانگ لەمەوپێش';
  return Math.floor(mo/12)+' ساڵ لەمەوپێش';
}
function fmtLeft(exp){
  if(!exp) return 'هەمیشەیی';
  const ms=new Date(exp)-Date.now();
  if(ms<=0) return 'بەسەرچووە';
  const h=Math.floor(ms/3600000), m=Math.floor(ms%3600000/60000);
  return h>0 ? (h+' کاتژمێر') : (m+' خولەک');
}

async function loadSecurity(){
  document.getElementById('bansTableWrap').innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const payload=await securityRequest('dashboard',{query:'&limit=200'});
    const s=payload.stats||{};
    document.getElementById('secActiveBans').textContent  = formatNum(s.active_bans||0);
    document.getElementById('secEvents24').textContent    = formatNum(s.events_24h||0);
    document.getElementById('secBlockedHits').textContent = formatNum(s.blocked_hits||0);
    document.getElementById('secTopType').textContent     = s.top_type ? evtLabel(s.top_type) : '—';

    _bans   = payload.bans || [];
    _events = payload.logs || [];
    renderBans(); renderEvents();
  }catch(e){
    document.getElementById('bansTableWrap').innerHTML='<div class="empty">نەتوانرا باربکرێت: '+esc(e.message||'')+'</div>';
  }
}

function setBanFilter(f,el){ _banFilter=f; document.querySelectorAll('[data-banf]').forEach(c=>c.classList.remove('on')); if(el) el.classList.add('on'); renderBans(); }
function setEvtFilter(f,el){ _evtFilter=f; document.querySelectorAll('[data-evtf]').forEach(c=>c.classList.remove('on')); if(el) el.classList.add('on'); renderEvents(); }

function renderBans(){
  const q=(document.getElementById('banSearch')?.value||'').toLowerCase();
  let list=_bans.filter(b=>{
    if(_banFilter==='active' && !b.effective_active) return false;
    if(_banFilter==='auto'   && !b.auto_banned) return false;
    if(_banFilter==='manual' &&  b.auto_banned) return false;
    if(!q) return true;
    return [b.ip_address,b.account_name,b.account_email,b.reason,b.browser,b.os]
      .some(v=>String(v||'').toLowerCase().includes(q));
  });

  const wrap=document.getElementById('bansTableWrap');
  if(!list.length){ wrap.innerHTML='<div class="empty">هیچ IPـیەکی بلۆککراو نییە</div>'; return; }

  wrap.innerHTML=`<table><thead><tr>
      <th>IP</th><th>هەژمار</th><th>وێبگەڕ / ئامێر</th><th>هۆکار</th>
      <th>مەترسی</th><th>بەروار</th><th>ماوە</th><th>کردار</th>
    </tr></thead><tbody>
    ${list.map(b=>`<tr${b.effective_active?'':' style="opacity:.5"'}>
      <td><span class="order-code-chip" onclick="copyOrderCode('${esc(b.ip_address)}', event)">${esc(b.ip_address)}</span>
          ${b.hit_count>0?`<div style="font-size:10px;color:var(--mt);margin-top:3px">${formatNum(b.hit_count)} داواکاری ڕێگری‌لێکراو</div>`:''}</td>
      <td>${b.account_name?`<div class="user-cell"><div class="user-nm">${esc(b.account_name)}</div><div class="user-em">${esc(b.account_email||'')}</div></div>`:'<span style="color:var(--mt)">نەناسراو</span>'}</td>
      <td><div style="font-size:12px">${esc(b.browser||'—')}</div>
          <div style="font-size:10px;color:var(--mt)">${esc(b.os||'')} · ${esc(b.device||'')}</div></td>
      <td style="max-width:220px"><div style="font-size:12px;line-height:1.6">${esc(b.reason||'')}</div>
          <span class="chip ${b.auto_banned?'yw':'bl'}" style="font-size:10px;padding:2px 8px;margin-top:4px;display:inline-block">${b.auto_banned?'خۆکار':'دەستی'}</span></td>
      <td><span class="chip ${riskClass(b.risk_score)}" style="font-size:11px">${b.risk_score||0}</span></td>
      <td style="font-size:11px;color:var(--mt)">${fmtWhen(b.banned_at)}</td>
      <td style="font-size:11px">${b.effective_active?fmtLeft(b.expires_at):'کراوەتەوە'}</td>
      <td><div style="display:flex;gap:6px">
        ${b.effective_active
          ? `<div class="act-btn gr" onclick="unbanIp('${b.id}')" title="کردنەوە"><i class="fas fa-lock-open"></i></div>
             <div class="act-btn dark" onclick="extendBan('${b.id}')" title="درێژکردنەوە"><i class="fas fa-clock"></i></div>`
          : `<div class="act-btn rd" onclick="extendBan('${b.id}')" title="دووبارە بلۆک"><i class="fas fa-ban"></i></div>`}
        <div class="act-btn dark" onclick="showIpAccounts('${esc(b.ip_address)}')" title="هەژمارەکانی ئەم IP"><i class="fas fa-users"></i></div>
      </div></td>
    </tr>`).join('')}
  </tbody></table>`;
}

function renderEvents(){
  const q=(document.getElementById('evtSearch')?.value||'').toLowerCase();
  let list=_events.filter(e=>{
    if(_evtFilter==='risk' && (e.risk_score||0)<=0) return false;
    if(_evtFilter!=='all' && _evtFilter!=='risk' && e.event_type!==_evtFilter) return false;
    if(!q) return true;
    return [e.ip_address,e.account_name,e.account_email,e.event_type,e.detail,e.browser]
      .some(v=>String(v||'').toLowerCase().includes(q));
  });

  const wrap=document.getElementById('eventsTableWrap');
  if(!list.length){ wrap.innerHTML='<div class="empty">هیچ ڕووداوێک نییە</div>'; return; }

  wrap.innerHTML=`<table><thead><tr>
      <th>کات</th><th>جۆر</th><th>IP</th><th>هەژمار</th><th>وێبگەڕ / ئامێر</th><th>وردەکاری</th><th>مەترسی</th><th></th>
    </tr></thead><tbody>
    ${list.map(e=>`<tr>
      <td style="font-size:11px;color:var(--mt);white-space:nowrap">${fmtWhen(e.created_at)}</td>
      <td><span class="chip ${riskClass(e.risk_score)}" style="font-size:11px">${esc(evtLabel(e.event_type))}</span></td>
      <td><span style="font-family:monospace;font-size:12px;direction:ltr">${esc(e.ip_address||'—')}</span>
          ${e.ip_is_banned?'<i class="fas fa-ban" style="color:#dc2626;margin-right:5px" title="بلۆککراوە"></i>':''}</td>
      <td>${e.account_name?`<div class="user-cell"><div class="user-nm">${esc(e.account_name)}</div><div class="user-em">${esc(e.account_email||'')}</div></div>`:'<span style="color:var(--mt)">مێوان</span>'}</td>
      <td><div style="font-size:12px">${esc(e.browser||'—')}</div>
          <div style="font-size:10px;color:var(--mt)">${esc(e.os||'')} · ${esc(e.device||'')}</div></td>
      <td style="font-size:11px;max-width:200px">${esc(e.detail||'—')}</td>
      <td><b style="font-size:12px">${e.risk_score||0}</b></td>
      <td>${e.ip_address && !e.ip_is_banned
            ? `<div class="act-btn rd" onclick="quickBan('${esc(e.ip_address)}','${esc(evtLabel(e.event_type))}')" title="بلۆککردن"><i class="fas fa-ban"></i></div>`
            : ''}</td>
    </tr>`).join('')}
  </tbody></table>`;
}

// ── actions ──────────────────────────────────────────────────
function openBanModal(ip='', reason=''){
  const v=prompt('IP بۆ بلۆککردن (1.2.3.4 یان 1.2.3.0/24):', ip);
  if(!v) return;
  const why=prompt('هۆکاری بلۆککردن:', reason||'دەستی لەلایەن ئادمین');
  if(why===null) return;
  const hrs=prompt('چەند کاتژمێر؟ (بەتاڵ = هەمیشەیی):', '24');
  if(hrs===null) return;
  doBan(v.trim(), why, hrs.trim()===''?null:parseInt(hrs,10));
}
function quickBan(ip, reason){ openBanModal(ip, 'ڕووداو: '+reason); }

async function doBan(ip, reason, hours){
  try{
    await securityRequest('action',{method:'POST',body:{action:'ban',ip,reason,hours,user_id:null}});
    showToast('IP بلۆککرا — ئێستا 404 وەردەگرێت','gr');
    loadSecurity();
  }catch(e){ showToast(e.message||'نەتوانرا بلۆک بکرێت','rd'); }
}

function unbanIp(id){
  confirm2('کردنەوەی IP','دڵنیایت لە کردنەوەی ئەم IPـیە؟','fa-lock-open','#16a34a', async ()=>{
    try{
      await securityRequest('action',{method:'POST',body:{action:'unban',id}});
      showToast('IP کرایەوە','gr'); loadSecurity();
    }catch(e){ showToast(e.message||'هەڵە','rd'); }
  });
}

async function extendBan(id){
  const hrs=prompt('درێژکردنەوە بە چەند کاتژمێر؟ (بەتاڵ = هەمیشەیی):','24');
  if(hrs===null) return;
  try{
    await securityRequest('action',{method:'POST',body:{action:'extend',id,hours:hrs.trim()===''?null:parseInt(hrs,10)}});
    showToast('ماوەی بلۆک نوێکرایەوە','gr'); loadSecurity();
  }catch(e){ showToast(e.message||'هەڵە','rd'); }
}

// Which accounts have been seen behind this address — the multi-accounting view
async function showIpAccounts(ip){
  try{
    const {accounts:data}=await securityRequest('ip-accounts',{query:'&ip='+encodeURIComponent(ip)});
    if(!data || !data.length){ showToast('هیچ هەژمارێک بەم IPـیەوە نەبەستراوە','bl'); return; }
    alert('هەژمارەکانی ئەم IP ('+ip+'):\n\n' +
      data.map(a=>'• '+(a.account_name||'—')+'  ('+(a.account_email||'—')+')  — '+a.events+' ڕووداو').join('\n'));
  }catch(e){ showToast(e.message||'هەڵە','rd'); }
}

// ══════════════════════════════════════════════════════════════
// ═══ HELPERS ═════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
function formatNum(n){ n=Math.round(parseFloat(n)||0); return n.toLocaleString(); }
function fmtOrderNo(n){ return '\u2068P'+String(n).padStart(11,'0')+'\u2069'; }
// Public transaction ID: 12 uppercase characters, always starting with "P".
// Generated by the database (ex_gen_order_code) and never editable afterwards.
function orderCodeOf(o){ return (o && o.order_code) ? o.order_code : ('P'+String((o&&o.order_number)||0).padStart(11,'0')); }
function fmtCode(c){ return '\u2068'+c+'\u2069'; }
function copyOrderCode(code, ev){
  if(ev) ev.stopPropagation();
  try{ navigator.clipboard.writeText(code); showToast('ئایدی مامەڵە کۆپی کرا','gr'); }catch(_){ }
}
function orderCodeChip(o){
  const c=orderCodeOf(o);
  return '<span class="order-code-chip" onclick="copyOrderCode(\''+c+'\', event)" title="کۆپیکردنی ئایدی">'+fmtCode(c)+'</span>';
}
function methodPill(key){
  const m=METHOD_META[key];
  const label = m ? m.label : (key||'—');
  const color = m ? m.color : 'var(--mt2)';
  if(!key) return '—';
  return `<span class="method-pill"><span class="method-dot" style="background:${color}"></span>${esc(label)}</span>`;
}
// a wallet's own logo from ex_wallets, or its first letter on its colour
function walletMark(key){
  const m=METHOD_META[key];
  const label=m?m.label:(key||'?');
  if(m&&m.img&&/^(data:image\/(png|jpe?g|webp);base64,|https:\/\/)/i.test(m.img)) return `<img class="wl-mark" src="${esc(m.img)}" alt="" loading="lazy">`;
  return `<span class="wl-mark" style="background:${m?m.color:'#94a3b8'}">${esc(String(label).trim().charAt(0).toUpperCase())}</span>`;
}
function walletName(key){ const m=METHOD_META[key]; return m?m.label:(key||'—'); }
if(typeof document!=='undefined'&&document.addEventListener) document.addEventListener('click',e=>{
  document.querySelectorAll('details.lv-more[open]').forEach(d=>{ if(!d.contains(e.target)) d.removeAttribute('open'); });
});
function walletNeedsSenderPhone(key){ const w=allWallets.find(x=>x.key===key); return !!(w&&w.sender_phone_required); }
// a calm placeholder while a list loads (no spinner)
function listSkeleton(rows=6){
  return '<div class="lv-list lv-skel" aria-busy="true">'+Array.from({length:rows},()=>'<div class="lv-row"><i></i><i></i><i></i></div>').join('')+'</div>';
}
function statusBadgeClass(s){
  return s===STATUS_APPROVED?'approved':s===STATUS_REJECTED?'rejected':s===STATUS_NEEDS_CORRECTION?'needs-correction':s===STATUS_CORRECTED?'corrected':s===STATUS_REVIEW?'review':s===STATUS_CANCELLED?'cancelled':'pending';
}
// a cancelled wallet order waits until an admin returns its amount to the customer's balance
function cancelWaitsRefund(o){ return !!o && o.status===STATUS_CANCELLED && !o.balance_refunded_at && o.from_method!=='AccountBalance'; }
function orderBadgeHTML(o){
  if(o.status===STATUS_CANCELLED)
    return `<span class="badge cancelled">${o.balance_refunded_at?'هەڵوەشاوە · گەڕێندرایەوە':o.from_method==='AccountBalance'?'هەڵوەشاوە':'هەڵوەشاوە · چاوەڕێی گەڕاندنەوە'}</span>`;
  if(o.balance_refunded_at) return `<span class="badge approved">ڕیفاوندکرا</span>`;
  return `<span class="badge ${statusBadgeClass(o.status)}">${esc(o.status===STATUS_REVIEW?'لەژێر پێداچوونەوە':o.status)}</span>`;
}
function esc(s){ return String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function safeAttr(obj){ return JSON.stringify(obj).replace(/'/g,'&#39;'); }

function isAuthDbError(error){
  return !!error && (error.code==='42501' || /row-level security/i.test(error.message||''));
}
async function handleDbWriteError(error){
  if(isAuthDbError(error)){
    showToast('دەستگەیشتنی ئادمینت نەماوە یان چوونەژوورەوەکەت بەسەرچووە — دووبارە بچۆرەوە ژوورەوە','rd');
    setTimeout(async ()=>{ try{ await sb.auth.signOut(); }catch(_){ } location.reload(); }, 1800);
    return;
  }
  showToast('هەڵە: '+(error.code==='23505'?'ئەم کلیلە پێشتر بەکارهاتووە':error.message),'rd');
}

function openMo(id){ document.getElementById(id).classList.add('on'); }
function closeMo(id){ document.getElementById(id).classList.remove('on'); }
function showImg(src){ if(!src) return; document.getElementById('imgViewSrc').src=src; openMo('moImgView'); }

function showToast(msg,cls=''){
  const t=document.getElementById('toast');
  t.textContent=msg; t.className='show'+(cls?' '+cls:'');
  clearTimeout(t._t); t._t=setTimeout(()=>{ t.classList.remove('show'); },3000);
}
function confirm2(title,msg,icoClass,icoColor,onOk){
  document.getElementById('confirmTitle').textContent=title;
  document.getElementById('confirmMsg').textContent=msg;
  const ico=document.getElementById('confirmIco');
  ico.innerHTML=`<i class="${icoClass}"></i>`;
  ico.style.background=icoColor+'22'; ico.style.color=icoColor;
  const btn=document.getElementById('confirmOkBtn');
  btn.style.background=icoColor;
  btn.onclick=async()=>{ closeMo('moConfirm'); await onOk(); };
  openMo('moConfirm');
}

async function loadProfilesFor(userIds){
  const uids=[...new Set(userIds.filter(Boolean))];
  if(!uids.length) return {};
  const {data} = await sb.from('ex_profiles').select('id,full_name,email,phone,is_admin,is_banned,username,role').in('id',uids);
  const map={}; (data||[]).forEach(p=>{ map[p.id]=p; });
  return map;
}

// ── Original admin module 2 ──
// ══════════════════════════════════════════════════════════════
// ═══ DASHBOARD ═══════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
async function loadDashboard(){
  loadDashboardStats();
  loadDashOrders();
  if(isSuperAdmin())loadAlerts();
  loadMyMonthlyActivity();
}
async function loadDashboardStats(){
  try{
    const [{count:usersCount}, {count:bannedCount}, {count:pendingCount}, {data:approvedRows}, {count:rejectedCount}] = await Promise.all([
      sb.from('ex_profiles').select('*',{count:'exact',head:true}),
      sb.from('ex_profiles').select('*',{count:'exact',head:true}).eq('is_banned',true),
      sb.from('ex_orders').select('*',{count:'exact',head:true}).in('status',[STATUS_PENDING,STATUS_CORRECTED,STATUS_REVIEW]).is('balance_refunded_at',null),
      sb.from('ex_orders').select('total').eq('status',STATUS_APPROVED),
      sb.from('ex_orders').select('*',{count:'exact',head:true}).eq('status',STATUS_REJECTED),
    ]);
    document.getElementById('stUsers').textContent = usersCount ?? '—';
    document.getElementById('stBanned').textContent = bannedCount ?? '—';
    document.getElementById('stPending').textContent = pendingCount ?? '—';
    document.getElementById('stRejected').textContent = rejectedCount ?? '—';
    const approvedCount = (approvedRows||[]).length;
    const volume = (approvedRows||[]).reduce((s,r)=>s+(parseFloat(r.total)||0),0);
    document.getElementById('stApproved').textContent = approvedCount;
    document.getElementById('stVolume').textContent = formatNum(volume);
    const badge=document.getElementById('sbOrdersCount');
    if(pendingCount>0){ badge.style.display='inline-flex'; badge.textContent=pendingCount; }
    else badge.style.display='none';
  }catch(e){ showToast('هەڵەی بارکردنی ئامار: '+e.message,'rd'); }
}
async function loadDashOrders(){
  try{
    const {data:orders} = await sb.from('ex_orders').select('*').order('created_at',{ascending:false}).limit(8);
    const profMap = await loadProfilesFor((orders||[]).map(o=>o.user_id));
    const list=(orders||[]).map(o=>({...o, profile:profMap[o.user_id]||null}));
    // merge into the shared cache so showOrderDetail/approve/reject work even before the Orders page has loaded
    list.forEach(o=>{
      const idx=allOrders.findIndex(x=>x.id===o.id);
      if(idx>-1) allOrders[idx]=o; else allOrders.push(o);
    });
    document.getElementById('dashOrdersWrap').innerHTML = renderOrdersTable(list);
  }catch(e){ document.getElementById('dashOrdersWrap').innerHTML='<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵەی بارکردن</p></div>'; }
}

// ══════════════════════════════════════════════════════════════
// ═══ ORDERS ══════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let _ordersAdminChannel=null;
function subscribeOrdersAdmin(){
  if(_ordersAdminChannel) return;
  _ordersAdminChannel = sb.channel('ex_orders_admin')
    .on('postgres_changes', {event:'INSERT', schema:'public', table:'ex_orders'}, (payload)=>{
      showToast('📥 داواکاریەکی نوێ هات '+fmtCode(orderCodeOf(payload.new)), 'bl');
      refreshOrdersEverywhere();
    })
    .on('postgres_changes', {event:'UPDATE', schema:'public', table:'ex_orders'}, payload=>{
      if(payload.new?.status===STATUS_CORRECTED && payload.old?.status!==STATUS_CORRECTED){
        showToast('کڕیار مامەڵەی '+fmtCode(orderCodeOf(payload.new))+' ڕاست کردەوە','cy');
      }
      refreshOrdersEverywhere();
    })
    .subscribe();
}
let _ordShown=50, _ordLoadedAt=0, _ordLoading=null;
function orderQuery(){ return (document.getElementById('orderSearch')?.value||'').toLowerCase(); }
// Entering the page always reads the orders again (leaving it reset the page).
function openOrdersPage(){
  allOrders=[]; _ordLoadedAt=0; _ordShown=LIST_STEP;
  loadOrders();
}
function showMoreOrders(){ _ordShown+=LIST_STEP; renderOrders(orderQuery()); }
function loadOrders(){
  if(_ordLoading) return _ordLoading;
  const wrap=document.getElementById('ordersTableWrap');
  if(!allOrders.length) wrap.innerHTML=listSkeleton();
  _ordLoading=(async()=>{
    try{
      const {data:orders,error} = await sb.from('ex_orders').select('*').order('created_at',{ascending:false}).limit(300);
      if(error) throw error;
      const profMap = await loadProfilesFor((orders||[]).map(o=>o.user_id));
      _profMap = profMap;
      allOrders = (orders||[]).map(o=>({...o, profile:profMap[o.user_id]||null}));
      _ordLoadedAt=Date.now();
      if(_curPage==='orders') renderOrders((document.getElementById('orderSearch')?.value||'').toLowerCase());
    }catch(e){
      if(!allOrders.length) wrap.innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
      else showToast('نوێکردنەوەی ئۆردەرەکان سەرکەوتوو نەبوو','rd');
    }finally{ _ordLoading=null; }
  })();
  return _ordLoading;
}
let _ordSearchTimer=null;
function filterOrders(el,typing){
  if(el){ document.querySelectorAll('[data-of]').forEach(x=>x.classList.remove('on')); el.classList.add('on'); orderFilter=el.dataset.of; }
  _ordShown=LIST_STEP;
  const run=()=>renderOrders((document.getElementById('orderSearch')?.value||'').toLowerCase());
  // typing waits a moment so every key does not redraw the list
  if(typing){ clearTimeout(_ordSearchTimer); _ordSearchTimer=setTimeout(run,150); } else run();
}
function orderMatches(o,f){
  if(f==='all') return true;
  if(f==='refunded') return !!o.balance_refunded_at&&o.status!==STATUS_CANCELLED;
  return o.status===f&&(f===STATUS_CANCELLED||!o.balance_refunded_at);
}
function renderOrders(q=''){
  let list=allOrders.filter(o=>orderMatches(o,orderFilter));
  if(q){
    const qq=q.replace(/[\s#-]/g,'');
    list=list.filter(o=>(o.profile?.full_name||'').toLowerCase().includes(q)
      ||(o.profile?.email||'').toLowerCase().includes(q)
      ||orderCodeOf(o).toLowerCase().includes(qq)
      ||String(o.order_number||'').includes(qq)
      ||(o.phone||'').includes(qq));
  }
  // every tab shows how many orders it holds
  document.querySelectorAll('[data-of]').forEach(tab=>{
    const n=tab.querySelector('.lv-n'); if(!n) return;
    const count=allOrders.filter(o=>orderMatches(o,tab.dataset.of)).length;
    n.textContent=count?formatNum(count):'';
  });
  const page=list.slice(0,_ordShown);
  document.getElementById('ordersTableWrap').innerHTML = (_wideList.matches ? renderOrdersTable(page) : (page.length ? renderOrdersCards(page) : renderOrdersTable(page)))
    + listMoreHTML(page.length,list.length,'showMoreOrders');
}
function adminOrderPayoutHTML(order){
  if(order.balance_refunded_at)return '<span>'+formatNum(order.amount)+' IQD</span><small class="order-payout-credit">گەڕاوە بۆ باڵانس</small>';
  const p=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(order):null;
  const rounded=p&&(p.planned||p.has_settlement),value=p?p.display_amount:order.total;
  const display=value===null||value===undefined?'—':formatNum(value)+(order.to_method==='USDT'?' $':' IQD');
  return '<span dir="ltr">'+display+'</span>'+(rounded&&p.valid&&p.remainder_iqd>0?
    '<small class="order-payout-credit">'+(p.settled?'گەڕاوە بۆ باڵانس: ':'بۆ باڵانس دوای پەسەندکردن: ')+formatNum(p.remainder_iqd)+' IQD</small>':'');
}
function adminOrderRoundingRows(order){
  const p=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(order):null;
  if(!p||(!p.planned&&!p.has_settlement)||order.balance_refunded_at)return '';
  const money=n=>n===null?'—':formatNum(n)+' IQD';
  return '<div class="detail-row"><span class="lbl">بڕی ناردنی دیاریکراو بۆ وەرگر</span><span class="val" dir="ltr">'+money(p.payout_iqd)+'</span></div>'+
    '<div class="detail-row"><span class="lbl">'+(p.settled?'گەڕاندنەوەی خۆکار بۆ باڵانس':'گەڕاندنەوەی خۆکار دوای پەسەندکردن')+'</span><span class="val" dir="ltr">'+money(p.remainder_iqd)+'</span></div>'+
    (p.valid&&p.payout_iqd===0?'<p class="payout-rounding-note">هیچ ناردنێکی دەرەکی ئەنجام نادرێت.'+(p.remainder_iqd>0?' بڕی ماوە بۆ باڵانسی خاوەنی داواکاری دەگەڕێتەوە.':'')+'</p>':'');
}
// ── one order per row: code and time · customer · route · amount · status · actions.
// The same markup serves every width; assets/css/admin-lists.css lays it out.
function orderTone(o){
  if(o.status===STATUS_CANCELLED) return 'cancelled';
  if(o.balance_refunded_at) return 'refunded';
  return statusBadgeClass(o.status);
}
function orderActionsHTML(o){
  const id=esc(String(o.id));
  let h='';
  if(!o.balance_refunded_at && REVIEW_START_STATUSES.has(o.status))
    h+=`<button type="button" class="lv-btn" onclick="event.stopPropagation();setOrderReview('${id}',true)">پێداچوونەوە</button>`;
  if(!o.balance_refunded_at && REVIEWABLE_ORDER_STATUSES.has(o.status))
    h+=`<button type="button" class="lv-btn is-ok" onclick="event.stopPropagation();approveOrder('${id}')">پەسەندکردن</button>`
      +`<button type="button" class="lv-btn is-no" onclick="event.stopPropagation();showRejectReason('${id}')">ڕەتکردنەوە</button>`;
  if(cancelWaitsRefund(o))
    h+=`<button type="button" class="lv-btn is-ok" onclick="event.stopPropagation();refundCancelledOrder('${id}')">گەڕاندنەوە بۆ باڵانس</button>`;
  return h;
}
function orderRowHTML(o){
  const id=esc(String(o.id));
  const name=o.profile?.full_name||o.profile?.email||'بێ ناو';
  const contact=o.profile?.phone||o.profile?.email||'';
  const sent=formatNum(o.amount)+(o.from_method==='USDT'?' $':' IQD');
  return `<article class="lv-row tone-${orderTone(o)}" tabindex="0" onclick="showOrderDetail('${id}')" onkeydown="if(event.key==='Enter'&&event.target===this)showOrderDetail('${id}')">
    <div class="lv-c lv-id"><b dir="ltr">${esc(orderCodeOf(o))}</b><small dir="ltr">${esc(fmtDateTime(o.created_at))}</small></div>
    <div class="lv-c lv-who"><b>${esc(name)}</b>${contact?`<small dir="ltr">${esc(contact)}</small>`:''}</div>
    <div class="lv-c lv-route"><span class="lv-w">${walletMark(o.from_method)}<span>${esc(walletName(o.from_method))}</span></span><i class="fas fa-arrow-left lv-arrow" aria-hidden="true"></i><span class="lv-w">${walletMark(o.to_method)}<span>${esc(walletName(o.to_method))}</span></span></div>
    <div class="lv-c lv-amt"><b dir="ltr">${sent}</b><div class="lv-pay order-payout-cell"><small>بۆ وەرگر</small>${adminOrderPayoutHTML(o)}</div></div>
    <div class="lv-end"><div class="lv-c lv-state">${orderBadgeHTML(o)}${o.user_deleted_at?'<span class="badge om-hidden-badge" title="لای بەکارھێنەر شاردراوە">شاراوە</span>':''}</div>
    <div class="lv-c lv-act">${orderActionsHTML(o)}</div></div>
  </article>`;
}
function renderOrdersTable(list){
  if(!list.length) return '<div class="lv-empty">هیچ داواکارییەک نییە</div>';
  return '<div class="lv-list lv-orders">'+list.map(orderRowHTML).join('')+'</div>';
}
function renderOrdersCards(list){ return renderOrdersTable(list); }

// "Under review": the customer can no longer cancel. on:false puts the order back to waiting.
async function setOrderReview(id,on){
  try{
    const row=await adminApiRequest('order_review',{order_id:id,on:on!==false});
    const o=allOrders.find(x=>String(x.id)===String(id));
    if(o&&row&&row.id) Object.assign(o,row,{profile:o.profile});
    showToast(on!==false?'داواکارییەکە خرایە ژێر پێداچوونەوە':'داواکارییەکە گەڕایەوە بۆ چاوەڕوان','gr');
    if(_curPage==='orders') renderOrders(orderQuery());
    if(document.getElementById('moOrderDetail')?.classList.contains('on')) showOrderDetail(id);
    loadDashboardStats();
  }catch(e){ showToast(e&&e.message?e.message:'نەگۆڕدرا','rd'); }
}
// A wallet order the customer cancelled: after the receipt is checked, one click returns the amount to the balance.
function refundCancelledOrder(id){
  const o=allOrders.find(x=>String(x.id)===String(id));
  if(!cancelWaitsRefund(o)) return;
  confirm2('گەڕاندنەوە بۆ باڵانس','بڕی '+formatNum(o.amount)+' IQD دەخرێتە سەر باڵانسی کڕیار. تەنها دوای ئەوەی پسوولەکەت پشکنی و پارەکە گەیشتووە.','fas fa-wallet','var(--gr)',async()=>{
    try{
      await adminApiRequest('order_cancel_refund',{order_id:id});
      o.balance_refunded_at=new Date().toISOString();
      showToast('بڕەکە گەڕێندرایەوە بۆ باڵانسی کڕیار','gr');
      closeMo('moOrderDetail');
      loadOrders();
    }catch(e){ showToast(e&&e.message?e.message:'گەڕاندنەوەکە ئەنجام نەدرا','rd'); }
  });
}
// ?order=PXXXXXXXXXXX (the button in the admin WhatsApp message) opens that order
function openOrderFromLink(){
  let code='';
  try{ code=(new URLSearchParams(location.search).get('order')||'').trim().toUpperCase(); }catch(_){}
  if(!/^P[A-Z0-9]{11}$/.test(code)) return;
  try{ history.replaceState(null,'',location.pathname); }catch(_){}
  goPage('orders');
  Promise.resolve(loadOrders()).then(()=>{
    const o=allOrders.find(x=>String(orderCodeOf(x)).toUpperCase()===code);
    if(o) showOrderDetail(o.id); else showToast('ئەم داواکارییە نەدۆزرایەوە','rd');
  });
}

// Order details: one language with the lists and the ban window (assets/css/admin-details.css).
// A summary card (amount, route, state), then titled groups of rows, the receipts,
// the admin's note, and the decisions last.
function showOrderDetail(id){
  const order = allOrders.find(x=>String(x.id)===String(id));
  if(!order){ showToast('نەدۆزرایەوە','rd'); return; }
  if(_payoutReceiptUploads.get(order.id)?.url===order.payout_receipt_url)_payoutReceiptUploads.delete(order.id);
  const oid=esc(String(order.id));
  const displayAmt = formatNum(order.amount)+(order.from_method==='USDT'?' $':' IQD');
  const toUnit = order.to_method==='USDT'?'$':'IQD';
  const row=(label,value,attrs='')=>`<div class="detail-row"><span class="lbl">${label}</span><span class="val"${attrs}>${value}</span></div>`;
  const profileMail=order.profile?.email&&!/@phone\.proxobalance\.app$/i.test(order.profile.email)?order.profile.email:'';
  const refunded=!!order.balance_refunded_at;
  document.getElementById('odTitle').textContent = 'وردەکاری مامەڵە';

  const head=`<div class="dx-head dx-head-order">
      <div class="dx-head-main"><b dir="ltr">${esc(displayAmt)}</b>
        <span class="dx-route"><span class="lv-w">${walletMark(order.from_method)}<span>${esc(walletName(order.from_method))}</span></span><i class="fas fa-arrow-left lv-arrow" aria-hidden="true"></i><span class="lv-w">${walletMark(order.to_method)}<span>${esc(walletName(order.to_method))}</span></span></span>
      </div>
      <div class="dx-head-end">${orderBadgeHTML(order)}</div>
    </div>`;

  const money=row('بڕی نێردراو',esc(displayAmt),' dir="ltr"')+
    row('بڕی سەرەکی دوای لێبڕین',esc(formatNum(order.total)+' '+toUnit),' dir="ltr"')+
    adminOrderRoundingRows(order)+
    (Number(order.shortfall_refunded_iqd||0)>0?
      row('کۆی گەڕاوەکان بۆ باڵانس',esc(formatNum(order.shortfall_refunded_iqd)+' IQD'),' dir="ltr" data-tone="ok"')+
      row('نێردراو بە حسابی کۆی گەڕاوەکان',esc(formatNum(Number(order.total)-Number(order.shortfall_refunded_iqd))+' IQD'),' dir="ltr"'):'');
  const sender=row('بەکارهێنەر',esc(order.profile?.full_name||'—'),' dir="rtl"')+
    (order.profile?.phone?row('ژمارەی هەژمار',esc(order.profile.phone),' dir="ltr"'):'')+
    (profileMail?row('ئیمەیڵ',esc(profileMail),' dir="ltr"'):'')+
    ((order.sender_phone||walletNeedsSenderPhone(order.from_method))
      ? row('ژمارەی نێرەر',esc(order.sender_phone||'—'),' dir="ltr"')
      : row('ناوی هەژماری نێرەر',esc(order.sender_name||order.profile?.full_name||'—'),' dir="rtl"'));
  const receiver=row('ژمارەی وەرگر',esc(order.phone||'—'),' dir="ltr"')+
    (order.extra_info?row('زانیاری زیاتر',esc(order.extra_info),' dir="rtl"'):'');
  const facts=row('ئایدی مامەڵە',orderCodeChip(order))+
    row('بەروار',esc(fmtDateTime(order.created_at)),' dir="ltr"')+
    (order.balance_debit_journal_id?row('تۆماری کەمکردنەوە لە باڵانس',esc(order.balance_debit_journal_id),' dir="ltr" data-small="1"'):'');

  // receipts: the customer's, and on an approved order the one sent to the customer
  const shot=(label,url)=>`<figure class="dx-fig"><button type="button" class="dx-shot" data-url="${esc(url)}" onclick="showImg(this.dataset.url)" aria-label="${esc(label)}"><img src="${esc(url)}" alt="" loading="lazy"></button><figcaption>${esc(label)}</figcaption></figure>`;
  const shots=[];
  if(!order.balance_debit_journal_id && order.receipt_url) shots.push(shot('پسووڵەی کڕیار',order.receipt_url));
  if(order.status===STATUS_APPROVED && order.payout_receipt_url) shots.push(shot('پسووڵەی پارەدان بۆ کڕیار',order.payout_receipt_url));
  const canAttach=order.status===STATUS_APPROVED&&typeof ProxoPayoutRounding==='object'&&ProxoPayoutRounding.canAttachReceipt(order);
  const attach=!canAttach?'':_payoutReceiptUploads.has(order.id)?
    `<button type="button" class="act-btn cy" id="podUploadLbl" onclick="uploadPayoutReceiptDirect(null,'${oid}')">پشکنینەوەی هەمان پسووڵەی پێشوو</button>`:
    `<label class="act-btn cy dx-file" id="podUploadLbl">${order.payout_receipt_url?'گۆڕینی پسووڵەی پارەدان':'ناردنی پسووڵەی پارەدان بۆ کڕیار'}<input type="file" accept="image/*" hidden onchange="uploadPayoutReceiptDirect(this,'${oid}')"></label>`;
  // what the receipt reader (Supabase + Gemini) found on the customer's receipt
  const readBox=!order.balance_debit_journal_id&&order.receipt_url?'<div class="rr-box" id="odReceiptRead" aria-live="polite"><p class="rr-wait">خوێندنەوەی پسووڵە بار دەکرێت...</p></div>':'';
  const receipts=(shots.length?`<div class="dx-shots">${shots.join('')}</div>`:'')+readBox+
    (!order.balance_debit_journal_id&&!order.receipt_url?'<p class="dx-quiet">پسووڵەی کڕیار بۆ تیلیگرامی ئادمین نێردراوە.</p>':'')+
    (attach?`<div class="dx-attach">${attach}</div>`:'');

  // what can be done now; the decision is the last row
  const acts=[];
  if(!refunded && CORRECTABLE_ORDER_STATUSES.has(order.status)) acts.push(`<button type="button" class="act-btn" onclick="openOrderCorrectionRequest('${oid}')">داوای ڕاستکردنەوە</button>`);
  if(!refunded && REVIEW_START_STATUSES.has(order.status)) acts.push(`<button type="button" class="act-btn" onclick="setOrderReview('${oid}',true)">لەژێر پێداچوونەوە</button>`);
  if(order.status===STATUS_REVIEW) acts.push(`<button type="button" class="act-btn" onclick="setOrderReview('${oid}',false)">گەڕاندنەوە بۆ چاوەڕوان</button>`);
  if(cancelWaitsRefund(order)) acts.push(`<button type="button" class="act-btn gr" onclick="refundCancelledOrder('${oid}')">گەڕاندنەوە بۆ باڵانس</button>`);
  if(!refunded && order.status===STATUS_APPROVED && order.from_method!=='USDT' && order.to_method!=='USDT') acts.push(`<button type="button" class="act-btn" onclick="openOrderShortfall('${oid}')">گەڕاندنەوەی بڕی کەم نێردراو بۆ باڵانس</button>`);
  if(!refunded && order.status!==STATUS_APPROVED && order.status!==STATUS_CANCELLED && !order.payout_receipt_url && order.from_method!=='USDT' && order.to_method!=='USDT') acts.push(`<button type="button" class="act-btn rd" onclick="openOrderRefund('${oid}')">ڕەتکردنەوە و گەڕاندنەوە بۆ باڵانس</button>`);
  const decide=!refunded && REVIEWABLE_ORDER_STATUSES.has(order.status)?
    `<div class="dx-decide"><button type="button" class="act-btn gr" onclick="approveOrder('${oid}');closeMo('moOrderDetail')">پەسەندکردن</button><button type="button" class="act-btn rd" onclick="showRejectReason('${oid}');closeMo('moOrderDetail')">ڕەتکردنەوە</button></div>`:'';

  document.getElementById('odContent').innerHTML = head+
    dxGroup('بڕ',money)+dxGroup('نێرەر',sender)+dxGroup('وەرگر',receiver)+dxGroup('مامەڵە',facts)+
    (receipts?`<section class="dx-group"><h4 class="dx-h">پسووڵە</h4>${receipts}</section>`:'')+
    (order.correction_request?`<div class="order-admin-correction request"><b>داوای ڕاستکردنەوەی ئادمین</b><p>${esc(order.correction_request)}</p><small dir="ltr">${order.correction_requested_at?esc(fmtDateTime(order.correction_requested_at)):''}</small></div>`:'')+
    (order.correction_response?`<div class="order-admin-correction response"><b>وەڵامی کڕیار</b><p>${esc(order.correction_response)}</p><small dir="ltr">${order.correction_responded_at?esc(fmtDateTime(order.correction_responded_at)):''}</small></div>`:'')+
    `<div id="odCorrectionHistory" class="order-correction-history-loading"><i class="fas fa-circle-notch fa-spin"></i> مێژووی ڕاستکردنەوە بار دەکرێت...</div>`+
    (order.status===STATUS_APPROVED?`<section class="dx-group"><h4 class="dx-h">هەڵسەنگاندنی کڕیار</h4><div class="admin-order-feedback" id="adminOrderFeedback"><p>هەڵسەنگاندن بار دەکرێت...</p></div></section>`:'')+
    `<section class="dx-group dx-notebox"><h4 class="dx-h"><label for="odNote">تێبینی ئادمین</label></h4>
      <textarea class="minp mta" id="odNote" rows="3">${esc(order.admin_note||'')}</textarea>
      <div class="dx-note-save"><button type="button" class="act-btn" onclick="saveOrderNote('${oid}')">پاشەکەوتی تێبینی</button></div></section>`+
    (acts.length?`<div class="dx-acts">${acts.join('')}</div>`:'')+
    decide+
    (typeof ProxoOrderManual==='object'?ProxoOrderManual.buttonsHTML(order):'');
  openMo('moOrderDetail');
  if(typeof ProxoOrderManual==='object') ProxoOrderManual.loadHistory(order.id);
  loadOrderCorrectionHistory(order.id);
  if(order.status===STATUS_APPROVED) loadAdminOrderFeedback(order.id);
  if(readBox) loadReceiptRead(order);
}

// ── receipt reading (Supabase Edge Function receipt-read with Gemini; table ex_receipt_reads) ──
// It only helps: the amount on the receipt against the order, another order with the same
// transaction number, a receipt that does not show success. The admin still decides.
// The app named on the receipt against the order's method, by the method's key and the first
// word of its name in the wallets table, and by the initials of the receipt's name
// ("First Iraqi Bank" → fib). Only Latin letters are compared: a name printed in Kurdish or
// Arabic is never flagged, and neither is USDT, whose receipts name an exchange.
function receiptWalletDiffers(method, wallet){
  const norm=t=>String(t||'').toLowerCase().replace(/[^a-z0-9]/g,'');
  const w=norm(wallet); if(!method||method==='USDT'||w.length<2) return false;
  const keys=[norm(method),norm(String(walletName(method)).split(/\s+/)[0])].filter(k=>k.length>=2);
  const initials=String(wallet).split(/[^A-Za-z0-9]+/).filter(Boolean).map(x=>x[0]).join('').toLowerCase();
  return !!keys.length&&!keys.some(k=>w.includes(k)||k.includes(w)||(initials.length>=2&&k===initials));
}
function receiptReadHTML(order, info){
  const read=info&&info.read, configured=!!(info&&info.configured);
  const oid=esc(String(order.id));
  const again=configured?`<button type="button" class="act-btn rr-again" onclick="runReceiptRead('${oid}')">${read?'دووبارە خوێندنەوە':'خوێندنەوەی پسووڵە'}</button>`:'';
  if(!read){
    if(!configured) return '';
    return `<div class="rr-head"><b>خوێندنەوەی پسووڵە</b></div><p class="rr-line">هێشتا نەخوێندراوەتەوە.</p><div class="rr-foot">${again}</div>`;
  }
  const unit=order.from_method==='USDT'?' $':' IQD';
  const ltr=t=>'<bdi dir="ltr">'+esc(t)+'</bdi>';
  const flags=[];   // [tone, html]: every value inside is escaped
  const busy=/^gemini_(429|50\d)/.test(read.error||'');
  // a later reading failed, the earlier good reading is kept (ex_receipt_read_save)
  if(read.status!=='error'&&read.error) flags.push(['warn','دوایین هەوڵی خوێندنەوە سەرنەکەوت؛ ئەمەی خوارەوە خوێندنەوەی پێشووە.']);
  if(read.status==='error') flags.push(['bad',/^gemini_key_missing/.test(read.error||'')?'کلیلی Gemini لە Supabase دانەنراوە (Edge Functions → Secrets → GEMINI_API_KEY).':
    busy?'Gemini ئێستا قەرەباڵغە؛ چەند خولەکێکی تر دووبارە بیخوێنەرەوە.':'نەتوانرا پسووڵەکە بخوێندرێتەوە.']);
  else if(read.status==='not_receipt') flags.push(['bad','ئەم وێنەیە وەک پسووڵەی پارەدان نەناسرایەوە.']);
  else{
    if(info.duplicate) flags.push(['bad','ئەم ژمارەی مامەڵەیە پێشتر لە داواکاری '+ltr(info.duplicate.order_code||'')+' بەکارهاتووە.']);
    else if(read.duplicate_order_id) flags.push(['bad','ئەم ژمارەی مامەڵەیە پێشتر لە داواکارییەکی تردا بەکارهاتووە.']);
    if(read.amount_matches===true) flags.push(['ok','بڕ یەک دەگرێتەوە: '+ltr(formatNum(read.amount)+unit)]);
    else if(read.amount_matches===false) flags.push(['bad','بڕ یەک ناگرێتەوە: پسووڵە '+ltr(formatNum(read.amount)+(read.currency?' '+read.currency:''))+'، داواکاری '+ltr(formatNum(order.amount)+unit)]);
    else flags.push(['warn','بڕ لە پسووڵەکەدا نەدۆزرایەوە.']);
    if(read.success===false) flags.push(['bad','پسووڵەکە سەرکەوتوو نیشان نادات'+(read.status_text?': '+esc(read.status_text):'.')]);
    if(receiptWalletDiffers(order.from_method,read.wallet)) flags.push(['warn','پسووڵەکە هی '+ltr(read.wallet)+' دیارە، بەڵام داواکارییەکە بە '+ltr(walletName(order.from_method))+' تۆمارکراوە.']);
    if(read.notes) flags.push(['warn',esc(read.notes)]);
  }
  const when=read.paid_at&&!isNaN(Date.parse(read.paid_at))?fmtDateTime(read.paid_at):read.paid_at;
  const row=(label,value,dir)=>value?`<div class="detail-row"><span class="lbl">${label}</span><span class="val"${dir?` dir="${dir}"`:''}>${esc(value)}</span></div>`:'';
  const person=(name,account)=>[name,account].filter(Boolean).join(' · ');
  const rows=read.status==='ok'?row('ژمارەی مامەڵە',read.reference,'ltr')+row('کات',when,'ltr')+row('ئەپ',read.wallet,'auto')+
    row('نێرەر',person(read.sender_name,read.sender_account),'auto')+row('وەرگر',person(read.receiver_name,read.receiver_account),'auto'):'';
  const dupBtn=info.duplicate&&allOrders.some(x=>String(x.id)===String(info.duplicate.id))?
    `<button type="button" class="act-btn" onclick="showOrderDetail('${esc(String(info.duplicate.id))}')">بینینی ${esc(info.duplicate.order_code||'داواکارییەکەی تر')}</button>`:'';
  return `<div class="rr-head"><b>خوێندنەوەی پسووڵە</b><small dir="ltr">${esc(fmtDateTime(read.read_at))}</small></div>`+
    flags.map(([tone,html])=>`<p class="rr-flag is-${tone}">${html}</p>`).join('')+
    (rows?`<div class="dx-card rr-card">${rows}</div>`:'')+
    `<div class="rr-foot">${dupBtn}${again}</div>`;
}
async function loadReceiptRead(order){
  const box=document.getElementById('odReceiptRead'); if(!box) return null;
  try{
    const info=await adminApiRequest('receipt_read_get',{order_id:order.id});
    const target=document.getElementById('odReceiptRead'); if(!target) return info;
    const html=receiptReadHTML(order,info);
    if(!html){ target.remove(); return info; }
    target.innerHTML=html;
    return info;
  }catch(e){
    const target=document.getElementById('odReceiptRead');
    if(target) target.innerHTML='<p class="rr-line">خوێندنەوەی پسووڵە بار نەکرا: '+esc(e.message)+'</p>';
    return null;
  }
}
async function runReceiptRead(id){
  const order=allOrders.find(x=>String(x.id)===String(id)); if(!order) return;
  const box=document.getElementById('odReceiptRead');
  const btn=box&&box.querySelector('.rr-again'); if(btn){ btn.disabled=true; btn.textContent='دەخوێندرێتەوە...'; }
  try{
    const current=await adminApiRequest('receipt_read_get',{order_id:order.id});
    // a new reading changes read_at; a failure over a good reading only changes attempts
    const mark=r=>r?String(r.read_at)+'|'+String(r.attempts):null;
    const last=mark(current?.read);
    await adminApiRequest('receipt_read_run',{order_id:order.id});
    // the reading arrives a few seconds later (when Gemini is busy, up to two minutes); look again until it changes
    for(let i=0;i<45;i++){
      await new Promise(r=>setTimeout(r,3000));
      if(!document.getElementById('odReceiptRead')) return;
      const info=await adminApiRequest('receipt_read_get',{order_id:order.id});
      if(info?.read && mark(info.read)!==last){ document.getElementById('odReceiptRead').innerHTML=receiptReadHTML(order,info); return; }
    }
    showToast('خوێندنەوەکە هێشتا تەواو نەبووە؛ دواتر سەیری بکەرەوە');
  }catch(e){ showToast(e.message||'هەڵەیەک ڕوویدا','rd'); }
  const b=document.getElementById('odReceiptRead')?.querySelector('.rr-again'); if(b){ b.disabled=false; b.textContent='دووبارە خوێندنەوە'; }
}

async function loadAdminOrderFeedback(orderId){
  const panel=document.getElementById('adminOrderFeedback');if(!panel)return;
  try{
    const {data,error}=await sb.from('ex_order_feedback').select('rating,comment,created_at').eq('order_id',orderId).maybeSingle();
    if(error)throw error;
    if(!data){panel.innerHTML='<p>هێشتا هەڵسەنگاندنی بۆ ئەم داواکارییە تۆمار نەکراوە.</p>';return;}
    const stars=Array.from({length:5},(_,index)=>`<span class="${index<Number(data.rating)?'filled':''}" aria-hidden="true">★</span>`).join('');
    panel.innerHTML=`<div class="feedback-stars" aria-label="${Number(data.rating)} لە 5 ئەستێرە">${stars}</div>${data.comment?`<p class="feedback-comment">${esc(data.comment)}</p>`:'<p>تەنها ئەستێرە هەڵبژێردراوە.</p>'}<small>${data.created_at?esc(fmtDateTime(data.created_at)):''}</small>`;
  }catch(error){panel.innerHTML='<p>نەتوانرا هەڵسەنگاندن باربکرێت.</p>';}
}

function correctionHistoryValue(value){
  return value===null || value===undefined || value==='' ? '—' : String(value);
}
function correctionHistoryField(label, oldValue, newValue, isReceipt=false){
  const oldText=correctionHistoryValue(oldValue), newText=correctionHistoryValue(newValue);
  const changed=oldText!==newText;
  const renderValue=(value)=>isReceipt && value!=='—'
    ? `<button type="button" class="correction-history-image" data-url="${esc(value)}" onclick="showImg(this.dataset.url)"><i class="fas fa-image"></i> بینینی وێنە</button>`
    : `<span dir="ltr">${esc(value)}</span>`;
  return `<div class="correction-history-field ${changed?'changed':'same'}">
    <b>${esc(label)}</b>
    <div><small>کۆن</small>${renderValue(oldText)}</div>
    <i class="fas fa-arrow-left"></i>
    <div><small>نوێ</small>${renderValue(newText)}</div>
  </div>`;
}
function renderOrderCorrectionHistory(rows){
  if(!rows.length) return '';
  return `<section class="order-correction-history">
    <h4><i class="fas fa-clock-rotate-left"></i> مێژووی ڕاستکردنەوە</h4>
    ${rows.map(row=>{
      const before=row.old_data||{}, after=row.new_data||null;
      return `<article class="correction-history-entry ${after?'done':'waiting'}">
        <div class="correction-history-head"><b>ڕاستکردنەوەی ژمارە ${formatNum(row.correction_number)}</b><span>${after?'کڕیار نوێی کردەوە':'چاوەڕوانی کڕیار'}</span></div>
        <p class="correction-history-request"><b>داواکاری ئادمین:</b> ${esc(row.request||'—')}</p>
        ${after?`
          ${correctionHistoryField('ژمارەی وەرگر',before.phone,after.phone)}
          ${correctionHistoryField('ژمارەی نێرەر',before.sender_phone,after.sender_phone)}
          ${correctionHistoryField('پسووڵە',before.receipt_url,after.receipt_url,true)}
          ${row.customer_response?`<p class="correction-history-response"><b>وەڵامی کڕیار:</b> ${esc(row.customer_response)}</p>`:''}
        `:`<div class="correction-history-pending"><i class="fas fa-hourglass-half"></i> زانیارییە کۆنەکان پارێزراون؛ هێشتا وەڵامی کڕیار نەهاتووە.</div>`}
        <time>${esc(fmtDateTime(after?(row.responded_at||row.requested_at):row.requested_at))}</time>
      </article>`;
    }).join('')}
  </section>`;
}
async function loadOrderCorrectionHistory(orderId){
  const target=document.getElementById('odCorrectionHistory');
  if(!target) return;
  try{
    const rows=await adminApiRequest('list_order_correction_history',{order_id:orderId});
    if(!document.getElementById('odCorrectionHistory')) return;
    target.className='';
    target.innerHTML=renderOrderCorrectionHistory(Array.isArray(rows)?rows:[]);
    if(!target.innerHTML) target.style.display='none';
  }catch(e){
    target.className='order-correction-history-error';
    target.textContent='مێژووی ڕاستکردنەوە بار نەکرا: '+e.message;
  }
}

let _apFile=null,_apBusy=false,_apDraft=null,_apPending=null,_apNeedsReview=false,_apRecoveryError='';
let _apSmartReceipt=null,_apSmartReceiptBusy=false,_apSmartReceiptError='';
const APPROVAL_REFUND_MAX=1000000000, APPROVAL_REFUND_UNIT=1000;
const _payoutReceiptUploads=new Map();
function smartReceiptStatusLabel(status){return ({VERIFIED:'پشتڕاستکراو',ID_MISMATCH:'ژمارەکان ناگونجاون',DUPLICATE:'پسووڵە دووبارەیە',NEEDS_REVIEW:'پێویستی بە پشکنینی دەستییە',OCR_FAILED:'خوێندنەوە سەرنەکەوت',queued:'چاوەڕوانی خوێندنەوە',processing:'خوێندنەوە بەردەوامە'})[status]||'پشکنین نەکراوە';}
function smartReceiptTone(status){return status==='VERIFIED'?'tone-ok':['ID_MISMATCH','DUPLICATE'].includes(status)?'tone-bad':status==='NEEDS_REVIEW'?'tone-warn':'tone-neutral';}
function smartReceiptFact(label,value,tone='',ltr=false){return `<div class="smart-receipt-fact ${tone}"><small>${esc(label)}</small><b${ltr?' dir="ltr"':''}>${esc(value||'—')}</b></div>`;}
function activeApprovalReceiptUrl(){return _apDraft?.uploadedReceipt||_apDraft?.order?.payout_receipt_url||null;}
function renderApSmartReceipt(){
  const box=document.getElementById('apSmartReceipt');if(!box)return;
  const draft=_apDraft;
  const shown=!!draft&&draft.plan.applies&&draft.plan.requires_payout&&!!(_apFile||activeApprovalReceiptUrl());
  box.hidden=!shown;if(!shown)return;
  const data=_apSmartReceipt, status=data?.verification_status||(data?.ocr_status==='queued'?'queued':data?.ocr_status==='processing'?'processing':null);
  const badge=document.getElementById('apSmartReceiptBadge');
  const insufficient=status==='NEEDS_REVIEW'&&(
    ['NOT_FOUND','UNCERTAIN'].includes(data?.id_status)||data?.amount_status==='AMOUNT_NOT_FOUND');
  badge.className='smart-receipt-badge '+(insufficient?'tone-neutral':smartReceiptTone(status));
  badge.textContent=status?smartReceiptStatusLabel(status):(_apSmartReceiptBusy?'خوێندنەوە دەستپێدەکات':'پشکنین نەکراوە');
  const body=document.getElementById('apSmartReceiptBody');
  const money=value=>value!==null&&value!==undefined&&value!==''&&Number.isSafeInteger(Number(value))?formatNum(Number(value))+' IQD':'نەخوێندراوەتەوە';
  const idLabel=({MATCH:'هاوتایە',MISMATCH:'ناگونجێت',NOT_FOUND:'نەدۆزرایەوە',UNCERTAIN:'دڵنیا نییە'})[data?.id_status]||'هێشتا پشکنین نەکراوە';
  const amountLabel=({EXACT_MATCH:'یەکسانە',OVERPAID:'زیاترە',UNDERPAID:'کەمترە',AMOUNT_NOT_FOUND:'بڕ/دراو نەدۆزرایەوە'})[data?.amount_status]||'هێشتا پشکنین نەکراوە';
  const idTone=data?.id_status==='MATCH'?'is-ok':data?.id_status==='MISMATCH'?'is-bad':'';
  const amountTone=data?.amount_status==='EXACT_MATCH'?'is-ok':['OVERPAID','UNDERPAID'].includes(data?.amount_status)?'is-warn':'';
  const expectedId=data?.expected_reference||'IDی ناونیشاندار لە تێبینی بانکی نییە';
  const actualId=data?.extracted_reference||'لە پسووڵەدا نەخوێندراوەتەوە';
  let message=_apSmartReceiptError;
  if(!message){
    if(!data)message='پسووڵەکە بخوێنەوە؛ ئەمە خۆکارانە ئۆردەر پەسەند ناکات.';
    else if(data.verification_status==='VERIFIED')message='بڕی IQD، ژمارەی مامەڵە و دۆخی سەرکەوتن لەسەر وێنەکە هاوتان. هێشتا تۆ پەسەندکردنی کۆتایی ئەنجام دەدەیت.';
    else if(data.id_status==='MISMATCH')message='ژمارەی پسووڵە لەگەڵ IDی بانکی ناگونجێت؛ ئەم دەرئەنجامە بە پشکنینی دەستی ناتوانرێت لاببرێت.';
    else if(data.verification_status==='DUPLICATE')message='پسووڵەکە دووبارەی پسووڵەی مامەڵەیەکی تر دیاریکراوە.';
    else if(data.verification_status==='OCR_FAILED')message='OCR نەتوانی زانیارییەکان بخوێنێتەوە؛ وێنەکە و زانیاریی بانکی بە دەست پشکنە.';
    else if(data.manual_review_by)message='پشکنینی دەستی تۆمارکرا؛ ئێستا ئادمین دەتوانێت بڕیاری کۆتایی بدات.';
    else message='ئەم دەرئەنجامە پێش پەسەندکردن پێویستی بە پشکنینی دەستی و هۆکاری تۆمارکراوە.';
  }
  const messageTone=data?.verification_status==='VERIFIED'?'tone-ok':['ID_MISMATCH','DUPLICATE'].includes(data?.verification_status)?'tone-bad':data?.verification_status==='NEEDS_REVIEW'&&!insufficient?'tone-warn':'';
  body.innerHTML=(data?[
    smartReceiptFact('بانک / واڵێت',data.bank_name||data.wallet),
    smartReceiptFact('دۆخی پسووڵە',data.status_text||(data.success===true?'سەرکەوتوو':data.success===false?'سەرنەکەوتوو':'دیار نییە')),
    smartReceiptFact('جۆری وێنە',data.is_receipt===true?'پسووڵەی گواستنەوەیە':data.is_receipt===false?'پسووڵە نییە':'دڵنیا نییە'),
    smartReceiptFact('دراوی چاپکراو',data.currency||'نەخوێندراوەتەوە'),
    smartReceiptFact('بڕی چاوەڕوانکراو',money(data.expected_amount_iqd)),
    smartReceiptFact('بڕی خوێندراو',money(data.actual_amount_iqd),amountTone),
    smartReceiptFact('جیاوازی (خوێندراو − چاوەڕوانکراو)',data.difference_iqd==null?'—':formatNum(Number(data.difference_iqd))+' IQD',amountTone),
    smartReceiptFact('بارودۆخی بڕ',amountLabel,amountTone),
    smartReceiptFact('دڵنیاییی خوێندنەوەی بڕ',data.amount_confidence==null?'دیار نییە':Math.round(Number(data.amount_confidence)*100)+'%'),
    smartReceiptFact('IDی تێبینی بانکی',expectedId,'',true),
    smartReceiptFact('IDی خوێندراو لە پسووڵە',actualId,idTone,true),
    smartReceiptFact('بارودۆخی ID',idLabel,idTone),
    smartReceiptFact('دڵنیاییی خوێندنەوەی ID',data.reference_confidence==null?'دیار نییە':Math.round(Number(data.reference_confidence)*100)+'%'),
    smartReceiptFact('نێرەر',data.sender_name||data.sender_account||'—'),
    smartReceiptFact('وەرگر',data.receiver_name||data.receiver_account||'—'),
    smartReceiptFact('بەروار و کات',data.paid_at||'—'),
    data.description?`<p class="smart-receipt-message">${esc(data.description)}</p>`:'',
    data.notes?`<p class="smart-receipt-message tone-warn">${esc(data.notes)}</p>`:'',
    data.duplicate_order?`<p class="smart-receipt-message tone-bad">پیشتر لە ئۆردەری <bdi dir="ltr">${esc(data.duplicate_order.order_code||data.duplicate_order.id)}</bdi> بینراوە.</p>`:'',
    data.manual_review_by?`<p class="smart-receipt-message">پشکنینی دەستی لەلایەن ئادمینەوە تۆمارکرا · ${esc(data.manual_review_at?new Date(data.manual_review_at).toLocaleString('ku'):'')}</p>`:''
  ].filter(Boolean).join(''):'')+`<p class="smart-receipt-message ${messageTone}">${esc(message)}</p>`;
  const review=document.getElementById('apSmartReceiptReview');
  const canReview=data&&['complete','error'].includes(data.ocr_status)&&data.verification_status!=='VERIFIED'&&data.id_status!=='MISMATCH'&&!data.manual_review_by;
  review.hidden=!canReview;
  const scan=document.getElementById('apSmartReceiptScan');
  scan.disabled=_apSmartReceiptBusy||_apBusy||_apDraft.admin_id!==adminUser?.id;
  scan.innerHTML=_apSmartReceiptBusy?'<i class="fas fa-circle-notch fa-spin"></i> پشکنین بەردەوامە...':'<i class="fas fa-magnifying-glass"></i> '+(data?.ocr_status==='error'?'دووبارە خوێندنەوە':'دەستپێکردنی پشکنین');
  document.getElementById('apSmartReceiptReviewBtn').disabled=_apSmartReceiptBusy||_apBusy||_apDraft.admin_id!==adminUser?.id;
}
async function startPayoutReceiptVerification(){
  if(_apSmartReceiptBusy||!_apDraft||_apDraft.admin_id!==adminUser?.id)return;
  _apSmartReceiptBusy=true;_apSmartReceiptError='';renderApSmartReceipt();approvalSetControls();
  try{
    const draft=_apDraft,order=draft.order;
    let url=activeApprovalReceiptUrl();
    if(_apFile){url=await uploadReceiptFile(_apFile,order.user_id,'payout');draft.uploadedReceipt=url;_apFile=null;}
    if(!url)throw Error('سەرەتا وێنەی پسووڵە هەڵبژێرە.');
    const refund=Number(document.getElementById('apRefundAmount').value||0);
    if(!Number.isSafeInteger(refund)||refund<0||refund>APPROVAL_REFUND_MAX||refund%APPROVAL_REFUND_UNIT!==0||refund>=draft.plan.payout_iqd)
      throw Error('بڕی ڕیفاوند دروست نییە؛ بڕی ناردن دەبێت لەگەڵ پسووڵەکە بگونجێت.');
    const started=await adminApiRequest('payout_receipt_verify_start',{order_id:order.id,payout_receipt_url:url,approval_refund_iqd:refund});
    if(!started?.verification_id)throw Error('ناسنامەی پشکنینی پسووڵە وەرنەگیرا.');
    _apSmartReceipt={id:started.verification_id,order_id:order.id,payout_receipt_url:url,
      expected_amount_iqd:started.expected_amount_iqd,expected_reference:started.expected_reference,
      ocr_status:started.ocr_status||'queued',verification_status:null};
    renderApSmartReceipt();
    for(let attempt=0;attempt<120;attempt++){
      if(attempt)await new Promise(resolve=>setTimeout(resolve,1500));
      const response=await adminApiRequest('payout_receipt_verify_get',{order_id:order.id,verification_id:started.verification_id});
      if(response?.verification){_apSmartReceipt={...response.verification,duplicate_order:response.duplicate_order};renderApSmartReceipt();
        if(['complete','error'].includes(response.verification.ocr_status))break;}
    }
    _apSmartReceiptError='';
  }catch(error){_apSmartReceiptError=error.message||'پشکنینی پسووڵە سەرکەوتوو نەبوو.';}
  finally{_apSmartReceiptBusy=false;renderApSmartReceipt();approvalSetControls();}
}
async function recordPayoutReceiptManualReview(){
  const data=_apSmartReceipt;if(!data?.id||data.id_status==='MISMATCH'||data.verification_status==='VERIFIED')return;
  const reason=document.getElementById('apSmartReceiptReason').value.trim();
  if(reason.length<10||reason.length>300){showToast('هۆکاری پشکنینی دەستی لە ١٠ تا ٣٠٠ پیت بنووسە','rd');return;}
  _apSmartReceiptBusy=true;_apSmartReceiptError='';renderApSmartReceipt();approvalSetControls();
  try{
    await adminApiRequest('payout_receipt_verify_review',{verification_id:data.id,reason});
    const response=await adminApiRequest('payout_receipt_verify_get',{order_id:data.order_id,verification_id:data.id});
    if(response?.verification)_apSmartReceipt={...response.verification,duplicate_order:response.duplicate_order};
    document.getElementById('apSmartReceiptReason').value='';
    showToast('پشکنینی دەستی تۆمارکرا؛ پەسەندکردن هێشتا پێویستی بە کلیکی کۆتایی تۆیە.','gr');
  }catch(error){_apSmartReceiptError=error.message||'پشکنینی دەستی تۆمار نەکرا.';}
  finally{_apSmartReceiptBusy=false;renderApSmartReceipt();approvalSetControls();}
}
function approvalRefundChanged(){_apSmartReceipt=null;_apSmartReceiptError='';renderApSmartReceipt();approvalSetControls();}
function approvalStorageKey(orderId,owner=adminUser?.id){
  if(!owner||!orderId)throw Error('تکایە بە هەژماری ئادمین بچۆ ژوورەوە.');
  return 'proxo:approval:pending:v1:'+owner+':'+orderId;
}
function approvalCloneOrder(order){return Object.freeze(JSON.parse(JSON.stringify(order)));}
function approvalRestore(orderId){
  const raw=sessionStorage.getItem(approvalStorageKey(orderId));
  if(!raw)return null;
  const saved=JSON.parse(raw),payload=saved?.payload,order=saved?.order;
  const plan=ProxoPayoutRounding.plan(order?.total,order?.to_method);
  if(saved?.version!==1||saved.admin_id!==adminUser.id||order?.id!==orderId||payload?.order_id!==orderId||
    !plan.valid||!order.user_id||typeof order.updated_at!=='string'||!Number.isFinite(Date.parse(order.updated_at))||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payload.request_key)||
    payload.expected_updated_at!==order.updated_at||payload.expected_total!==plan.expected_iqd||
    !Number.isSafeInteger(Number(payload.approval_refund_iqd||0))||Number(payload.approval_refund_iqd||0)<0||
    Number(payload.approval_refund_iqd||0)>APPROVAL_REFUND_MAX||Number(payload.approval_refund_iqd||0)%APPROVAL_REFUND_UNIT!==0||
    !(payload.approval_refund_note===null||typeof payload.approval_refund_note==='string')||
    payload.confirmed_received!==true||!(payload.confirmed_paid===true||payload.confirmed_paid===false)||
    !(payload.payout_receipt_url===null||typeof payload.payout_receipt_url==='string')||
    !(payload.admin_note===null||typeof payload.admin_note==='string'))throw Error('INVALID_PENDING_APPROVAL');
  return {admin_id:saved.admin_id,order:approvalCloneOrder(order),payload:Object.freeze({...payload})};
}
function approvalPersist(pending){
  const value=JSON.stringify({version:1,admin_id:pending.admin_id,order:pending.order,payload:pending.payload});
  const key=approvalStorageKey(pending.payload.order_id,pending.admin_id);
  sessionStorage.setItem(key,value);
  if(sessionStorage.getItem(key)!==value)throw Error('APPROVAL_STORAGE_UNAVAILABLE');
}
function approvalForget(){
  if(!_apPending)return;
  sessionStorage.removeItem(approvalStorageKey(_apPending.payload.order_id,_apPending.admin_id));
  _apPending=null;
}
function approvalButtonText(){
  if(_apBusy)return 'پەسەندکردن و تۆمارکردن...';
  if(_apNeedsReview)return 'سەرەتا مامەڵەکە دووبارە بپشکنە';
  if(!_apDraft)return 'پەسەندکردن';
  const p=_apDraft.plan;
  if(_apPending)return 'پشکنینەوە و تەواوکردنی هەمان پەسەندکردن';
  if(!p.applies)return 'پارەدانەکە پشتڕاست دەکەم و پەسەند دەکەم';
  return p.payout_iqd>0?'پارەکە وەرگیراوە و '+formatNum(p.payout_iqd)+' دینار نێردراوە؛ پەسەند دەکەم':
    'پارەکە وەرگیراوە؛ بێ ناردنی دەرەکی پەسەند دەکەم';
}
function approvalReceiptGate(payload=null){
  const draft=_apDraft;if(!draft?.plan.applies||!draft.plan.requires_payout)return {ok:true};
  const url=payload?payload.payout_receipt_url:(draft.uploadedReceipt||draft.order.payout_receipt_url||(_apFile?'__selected_file__':null));
  if(!url)return {ok:true};
  const refund=Number(payload?.approval_refund_iqd??document.getElementById('apRefundAmount').value??0);
  const result=_apSmartReceipt;
  if(!result||url==='__selected_file__'||result.payout_receipt_url!==url||Number(result.expected_amount_iqd)!==draft.plan.payout_iqd-refund)
    return {ok:false,message:'پسووڵەکە بۆ ئەم بڕە نوێیە پشکنین نەکراوە؛ «دەستپێکردنی پشکنین» بکە.'};
  if(!['complete','error'].includes(result.ocr_status))return {ok:false,message:'چاوەڕوانی تەواوبوونی خوێندنەوەی پسووڵە بکە.'};
  if(result.id_status==='MISMATCH')return {ok:false,message:'IDی مامەڵە ناگونجێت؛ پەسەندکردن ڕێگەی پێ نادرێت.'};
  if(result.verification_status==='VERIFIED')return {ok:true};
  if(result.manual_review_by===draft.admin_id&&String(result.manual_review_reason||'').trim().length>=10)return {ok:true};
  return {ok:false,message:'ئەم دەرئەنجامە پێویستی بە پشکنینی دەستی و هۆکاری تۆمارکراو هەیە.'};
}
function approvalSetControls(){
  const receiptGate=approvalReceiptGate(_apPending?.payload||null);
  const disabled=_apBusy||_apNeedsReview||!!_apRecoveryError||!_apDraft||
    (_apDraft.plan.applies&&!_apDraft.plan.valid)||_apDraft.admin_id!==adminUser?.id||!receiptGate.ok;
  const btn=document.getElementById('apConfirmBtn');
  btn.disabled=disabled;btn.textContent=approvalButtonText();
  document.getElementById('apReceiptFile').disabled=disabled||!!_apPending||
    (_apDraft?.plan.applies&&!_apDraft.plan.requires_payout);
  document.getElementById('apRefundAmount').disabled=!!_apPending||!_apDraft?.plan.requires_payout;
  document.getElementById('apRefundNote').disabled=!!_apPending||!_apDraft?.plan.requires_payout;
  document.getElementById('moApproveOrder').setAttribute('aria-busy',String(_apBusy));
}
function renderApprovalReview(){
  if(!_apDraft){document.getElementById('apReview').innerHTML='';document.getElementById('apActionNote').textContent='';document.getElementById('apReceiptWrap').hidden=true;renderApSmartReceipt();approvalSetControls();return;}
  const o=_apDraft.order,p=_apDraft.plan;
  const row=(label,value)=>'<div class="detail-row"><span class="lbl">'+esc(label)+'</span><span class="val">'+value+'</span></div>';
  const money=n=>n===null?'—':'<bdi>'+formatNum(n)+' IQD</bdi>';
  document.getElementById('apOrderTitle').textContent='پەسەندکردنی ئۆردەر '+fmtCode(orderCodeOf(o));
  document.getElementById('apReview').innerHTML=
    row('خاوەنی داواکاری',esc(o.profile?.full_name||o.user_id))+
    row('پارەی هاتوو',esc(formatNum(o.amount)+(o.from_method==='USDT'?' $':' IQD'))+' · '+methodPill(o.from_method))+
    row('ڕێگای وەرگر',methodPill(o.to_method))+
    row('ژمارەی وەرگر','<bdi>'+esc(o.phone||'—')+'</bdi>')+
    row('بڕی سەرەکی دوای لێبڕین',p.applies?money(p.expected_iqd):esc(formatNum(o.total)+(o.to_method==='USDT'?' $':' IQD')))+
    (p.applies?row('بڕی ناردنی دەرەکی',money(p.payout_iqd))+
      row('گەڕاندنەوەی خۆکار بۆ باڵانسی خاوەنی داواکاری',money(p.remainder_iqd)):'')+
    (o.balance_debit_journal_id?row('پارەدان لە باڵانس','کەمکراوەتەوە لە باڵانسی هەژمار'):
      o.receipt_url?'<button type="button" class="act-btn cy" data-url="'+esc(o.receipt_url)+'" onclick="showImg(this.dataset.url)">بینینی پسووڵەی پارەی هاتوو</button>':'');
  document.getElementById('apActionNote').textContent=_apPending?
    'وەڵامی هەوڵی پێشوو دیار نییە. هەمان ژمارە، بڕ و پسووڵە دووبارە دەپشکنرێن؛ پارەکە دووبارە مەنیەرە.':
    p.applies?(p.requires_payout?
      'تەنها دوای دڵنیابوون لە وەرگرتنی پارە و ناردنی بڕی دیاریکراو بۆ ئەم وەرگرە پەسەند بکە.':
      'پارەی هاتوو پشتڕاست بکەرەوە. هیچ ناردنێکی دەرەکی ئەنجام مەدە؛ بڕی ماوە بۆ باڵانسی خاوەنی داواکاری دەگەڕێتەوە.')+
      (p.remainder_iqd>0?' گەڕاندنەوە لەگەڵ پەسەندکردن خۆکارانە تۆمار دەکرێت.':''):
      'تەنها دوای پشتڕاستکردنەوەی پارەدان پەسەند بکە. پسووڵەی ناردن ئارەزوومەندانەیە.';
  document.getElementById('apReceiptWrap').hidden=p.applies&&!p.requires_payout;
  renderApSmartReceipt();
  approvalSetControls();
}
function approveOrder(id){
  if(_apBusy)return;
  id=String(id);
  const order=allOrders.find(x=>String(x.id)===id);
  _apDraft=null;_apPending=null;_apNeedsReview=false;_apRecoveryError='';_apFile=null;_apSmartReceipt=null;_apSmartReceiptBusy=false;_apSmartReceiptError='';
  document.getElementById('apOrderId').value=id;
  document.getElementById('apError').textContent='';
  document.getElementById('apReceiptFile').value = '';
  document.getElementById('apReceiptPreview').innerHTML = '<i class="fas fa-receipt"></i>';
  document.getElementById('apReceiptNote').textContent = 'پسووڵەی ناردن ئارەزوومەندانەیە';
  document.getElementById('apRefundAmount').value = '';
  document.getElementById('apRefundNote').value = '';
  try{
    if(typeof ProxoPayoutRounding!=='object')throw Error('پەڕەکە نوێ بکەرەوە؛ حسابی بڕی ناردن بار نەکراوە.');
    _apPending=approvalRestore(id);
    const frozen=_apPending?.order||(order?approvalCloneOrder(order):null);
    if(!frozen||(!_apPending&&(frozen.balance_refunded_at||!REVIEWABLE_ORDER_STATUSES.has(frozen.status))))throw Error('ئەم مامەڵەیە ئێستا ناتوانرێت پەسەند بکرێت؛ لیستەکە نوێ بکەرەوە.');
    const plan=ProxoPayoutRounding.plan(frozen.total,frozen.to_method);
    if(!plan.applies&&!['USDT','AccountBalance'].includes(frozen.to_method))throw Error('ڕێگای وەرگر دروست نییە؛ سەرەتا مامەڵەکە بپشکنە.');
    if(plan.applies&&(!plan.valid||typeof frozen.updated_at!=='string'||!Number.isFinite(Date.parse(frozen.updated_at))))throw Error('زانیاری بڕ یان بەرواری مامەڵە تەواو نییە؛ لیستەکە نوێ بکەرەوە.');
    if(plan.applies&&!plan.requires_payout&&frozen.payout_receipt_url)throw Error('بڕی ناردن سفرە بەڵام پسووڵەی ناردن هەیە؛ مامەڵەکە پێویستی بە پشکنین هەیە.');
    _apDraft={order:frozen,plan,admin_id:adminUser.id,uploadedReceipt:_apPending?.payload.payout_receipt_url||null};
    document.getElementById('apRefundAmount').value=String(_apPending?.payload.approval_refund_iqd||'');
    document.getElementById('apRefundNote').value=_apPending?.payload.approval_refund_note||'';
    if(_apPending?.payload.payout_receipt_url){
      document.getElementById('apReceiptPreview').innerHTML='<img src="'+esc(_apPending.payload.payout_receipt_url)+'" alt="پسووڵەی هەمان پەسەندکردن">';
      document.getElementById('apReceiptNote').textContent='پسووڵەی هەمان داواکاری هەڵگیراوە';
    }
  }catch(e){
    _apRecoveryError=e.message==='INVALID_PENDING_APPROVAL'||e instanceof SyntaxError?
      'پەسەندکردنێکی پێشوو هەیە کە نەتوانرا بخوێندرێتەوە؛ پێش هەوڵێکی نوێ پێویستی بە پشکنین هەیە.':
      e.message;
    document.getElementById('apError').textContent=_apRecoveryError;
  }
  renderApprovalReview();
  openMo('moApproveOrder');
}
function onApReceiptFile(input){
  if(_apBusy||_apPending||!_apDraft||(_apDraft.plan.applies&&!_apDraft.plan.requires_payout)){input.value='';return;}
  const file = input.files[0]; if(!file) return;
  if(file.size > 5*1024*1024){ showToast('وێنەکە زۆر گەورەیە (زۆرترین 5MB)','rd'); input.value=''; return; }
  _apFile = file;
  _apDraft.uploadedReceipt=null;
  _apSmartReceipt=null;_apSmartReceiptError='';
  const reader = new FileReader();
  reader.onload = () => { document.getElementById('apReceiptPreview').innerHTML = `<img src="${reader.result}" style="width:100%;height:100%;object-fit:cover">`; };
  reader.readAsDataURL(file);
  document.getElementById('apReceiptNote').textContent = file.name;
  renderApSmartReceipt();approvalSetControls();
}
async function uploadReceiptFile(file, userId, tag){
  const ext = ((file.name||'').split('.').pop()||'jpg').toLowerCase().replace(/[^a-z0-9]/g,'') || 'jpg';
  const path = `${userId}/${tag}_${Date.now()}_${Math.random().toString(36).slice(2,8)}.${ext}`;
  const {error:upErr} = await sb.storage.from('receipts').upload(path, file, { cacheControl:'3600', upsert:false, contentType:file.type||'image/jpeg' });
  if(upErr) throw upErr;
  const {data:pub} = sb.storage.from('receipts').getPublicUrl(path);
  return pub.publicUrl;
}
async function confirmApproveOrder(){
  if(_apBusy||!_apDraft||_apNeedsReview||_apRecoveryError||_apDraft.admin_id!==adminUser?.id)return;
  const draft=_apDraft,order=draft.order,p=draft.plan,retry=!!_apPending;
  if(p.applies&&!p.valid)return;
  _apBusy=true;approvalSetControls();document.getElementById('apError').textContent='';
  try{
    let payload=_apPending?.payload;
    if(!payload){
      let payout_receipt_url=draft.uploadedReceipt||order.payout_receipt_url||null;
      if(_apFile&&!draft.uploadedReceipt){
        payout_receipt_url=await uploadReceiptFile(_apFile,order.user_id,'payout');
        draft.uploadedReceipt=payout_receipt_url;
      }
      const refund=Number(document.getElementById('apRefundAmount').value||0);
      const refundNote=document.getElementById('apRefundNote').value.trim();
      if(!Number.isSafeInteger(refund)||refund<0||refund>APPROVAL_REFUND_MAX||refund%APPROVAL_REFUND_UNIT!==0)throw Error('بڕی ڕیفاوند دەبێت بە هەزارەها بێت.');
      if(refund>0&&!refundNote)throw Error('تکایە هۆکاری ڕیفاوند بنووسە.');
      if(refund===0&&refundNote)throw Error('هۆکار تەنها لەگەڵ بڕی ڕیفاوند بنووسە.');
      if(refundNote.length>300)throw Error('هۆکاری ڕیفاوند زۆر درێژە.');
      payload={order_id:order.id,payout_receipt_url,admin_note:order.admin_note||null,approval_refund_iqd:refund,approval_refund_note:refundNote||null};
      if(p.applies){
        if(!globalThis.crypto?.randomUUID)throw Error('پەڕەکە لە پەیوەندی پارێزراو بکەرەوە و دووبارە هەوڵبدەوە.');
        if(refund>p.payout_iqd)throw Error('بڕی ڕیفاوند لە بڕی شیاوی ناردن زیاترە.');
        payload={...payload,request_key:crypto.randomUUID(),expected_updated_at:order.updated_at,
          expected_total:p.expected_iqd,confirmed_payout_iqd:p.payout_iqd-refund,confirmed_received:true,confirmed_paid:p.payout_iqd-refund>0};
        _apPending={admin_id:draft.admin_id,order,payload:Object.freeze(payload)};
      }
    }
    const receiptGate=approvalReceiptGate(payload);
    if(!receiptGate.ok)throw Error(receiptGate.message);
    if(draft.admin_id!==adminUser?.id)throw Error('هەژماری ئادمین گۆڕاوە؛ پەسەندکردن نەنێردرا.');
    if(p.applies){
      try{approvalPersist(_apPending);}catch{throw Error('نەتوانرا داواکاری بە پارێزراوی هەڵبگیرێت؛ هیچ پەسەندکردنێک نەنێردرا. ڕێگە بە هەڵگرتنی داتای ماڵپەڕ بدە و دووبارە هەوڵبدەوە.');}
    }
    let saved,refundAmount=Number(payload.approval_refund_iqd||0);
    if(refundAmount>0){
      const {data:{user}}=await sb.auth.getUser();if(!user)throw Error('تکایە دووبارە بچۆ ژوورەوە');
      const {data:result,error}=await sb.functions.invoke('admin-approve-order-refund',{body:{
        p_order_id:order.id,p_admin_id:user.id,p_request_key:payload.request_key,
        p_expected_updated_at:payload.expected_updated_at,p_expected_total:payload.expected_total,
        p_confirmed_payout_iqd:payload.confirmed_payout_iqd,p_confirmed_received:true,
        p_confirmed_paid:payload.confirmed_paid,p_payout_receipt_url:payload.payout_receipt_url,
        p_admin_note:payload.admin_note,p_approval_refund_iqd:refundAmount,p_approval_refund_note:payload.approval_refund_note
      }});if(error)throw error;saved=result?.order;
      if(!saved||saved.id!==order.id||saved.status!==STATUS_APPROVED||Number(saved.payout_iqd)!==p.payout_iqd-refundAmount||Number(saved.shortfall_refunded_iqd)!==p.remainder_iqd+refundAmount)throw Error('وەڵامی ڕیفاوند تەواو نەگەیشت؛ هەمان داواکاری دووبارە بپشکنە.');
    }else{
      saved=await adminApiRequest('approve_order',payload);
      const settled=p.applies?ProxoPayoutRounding.forOrder(saved):null;
      if(saved?.id!==order.id||saved.status!==STATUS_APPROVED||
        (p.applies&&(!settled.settled||settled.expected_iqd!==p.expected_iqd||settled.payout_iqd!==p.payout_iqd)))throw Error('وەڵامی پەسەندکردن تەواو نەگەیشت؛ هەمان داواکاری دووبارە بپشکنە.');
    }
    if(_apPending){try{approvalForget();}catch{/* A saved retry can only replay this confirmed settlement. */}}
    const index=allOrders.findIndex(o=>o.id===saved.id);if(index>=0)allOrders[index]={...allOrders[index],...saved};
    closeMo('moApproveOrder'); closeMo('moOrderDetail');
    showToast('ئۆردەرەکە پەسەندکرا'+(Number(payload.approval_refund_iqd||0)>0?'؛ '+formatNum(Number(payload.approval_refund_iqd))+' دینار ڕیفاوند کرا بۆ باڵانسی کڕیار.':(p.applies&&p.remainder_iqd>0?'؛ '+formatNum(p.remainder_iqd)+' دینار گەڕایەوە بۆ باڵانسی کڕیار.':'')),'gr');
    _apDraft=null;_apPending=null;_apFile=null;
    refreshOrdersEverywhere();
  }catch(e){
    if(e.status===409&&['approval_stale','already_decided'].includes(e.code)){
      try{approvalForget();}catch{_apRecoveryError='نەتوانرا هەوڵی کۆن بسڕدرێتەوە؛ هەمان داواکاری پارێزراوە.';}
      _apNeedsReview=true;
      document.getElementById('apError').textContent='مامەڵەکە گۆڕاوە. ئەم پەنجەرەیە دابخە، لیستەکە نوێ بکەرەوە و ژمارە و پسووڵە و بڕە نوێیەکان دووبارە بپشکنە.';
      refreshOrdersEverywhere();
    }else{
      if(!retry&&e.status===400&&['approval_refresh_required','confirmation_required'].includes(e.code)){
        try{approvalForget();}catch{_apRecoveryError='نەتوانرا هەوڵی کۆن بسڕدرێتەوە؛ سەرەتا پەڕەکە بپشکنە.';}
        _apNeedsReview=true;
      }
      document.getElementById('apError').textContent=e.message+(_apPending?' هەمان داواکاری پارێزراوە؛ پارەکە دووبارە مەنیەرە.':'');
    }
    showToast('هەڵە: '+e.message,'rd');
  }finally{
    _apBusy=false;approvalSetControls();
  }
}
async function uploadPayoutReceiptDirect(input, id){
  const file=input?.files?.[0],prior=_payoutReceiptUploads.get(id);
  if(!file&&!prior?.url)return;
  if(file?.size > 5*1024*1024){ showToast('وێنەکە زۆر گەورەیە (زۆرترین 5MB)','rd'); if(input)input.value=''; return; }
  const order = allOrders.find(x=>String(x.id)===String(id));
  if(!order||typeof ProxoPayoutRounding!=='object'||!ProxoPayoutRounding.canAttachReceipt(order)){
    if(input)input.value='';showToast('ناردن یان گۆڕینی ئەم پسووڵەیە بەردەست نییە؛ مامەڵەکە نوێ بکەرەوە.','rd');return;
  }
  if(prior?.busy)return;
  const attempt=prior||{busy:false,url:null};attempt.busy=true;_payoutReceiptUploads.set(id,attempt);
  const lbl = document.getElementById('podUploadLbl');
  const previousLabel=lbl?.innerHTML;
  if(lbl) lbl.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i> بارکردن...';
  try{
    const url = attempt.url||await uploadReceiptFile(file, order.user_id, 'payout');attempt.url=url;
    const saved=await adminApiRequest('save_payout_receipt',{order_id:id,payout_receipt_url:url});
    if(saved?.id!==order.id||saved.payout_receipt_url!==url)throw Error('وەڵامی ناردنی پسووڵە تەواو نەگەیشت؛ دووبارە هەمان پسووڵە بپشکنە.');
    const index=allOrders.findIndex(o=>o.id===saved.id);if(index>=0)allOrders[index]={...allOrders[index],...saved};
    _payoutReceiptUploads.delete(id);
    showToast('وێنەی پسووڵە نێردرا بۆ کڕیار','gr');
    refreshOrdersEverywhere();
    showOrderDetail(id);
  }catch(e){
    showToast('هەڵە: '+e.message,'rd');
    if(attempt.url){
      if(lbl)lbl.outerHTML='<button type="button" class="act-btn cy" id="podUploadLbl" onclick="uploadPayoutReceiptDirect(null,\''+esc(id)+'\')">پشکنینەوەی هەمان پسووڵەی پێشوو</button>';
    }else{
      _payoutReceiptUploads.delete(id);if(lbl)lbl.innerHTML=previousLabel;
    }
  }finally{attempt.busy=false;if(input)input.value='';}
}
function showRejectReason(id){
  document.getElementById('rejectTargetId').value=id;
  document.getElementById('rejectReasonTxt').value='';
  openMo('moRejectReason');
}
async function confirmRejectOrder(){
  const id=document.getElementById('rejectTargetId').value;
  const reason=document.getElementById('rejectReasonTxt').value.trim();
  const btn=document.getElementById('rejectSubmitBtn'); btn.disabled=true;
  try{
    await adminApiRequest('reject_order',{order_id:id,reason:reason||null});
    showToast('ئۆردەرەکە ڕەتکرایەوە','rd');
    closeMo('moRejectReason'); closeMo('moOrderDetail');
    refreshOrdersEverywhere();
  }catch(error){ showToast('هەڵە: '+error.message,'rd'); }
  finally{ btn.disabled=false; }
}

function openOrderCorrectionRequest(id){
  const order=allOrders.find(row=>String(row.id)===String(id));
  if(!order){ showToast('مامەڵەکە نەدۆزرایەوە','rd'); return; }
  document.getElementById('orderCorrectionTargetId').value=order.id;
  document.getElementById('orderCorrectionAdminTitle').textContent='داوای ڕاستکردنەوەی '+fmtCode(orderCodeOf(order));
  document.getElementById('orderCorrectionAdminReason').value=order.correction_request||'';
  openMo('moOrderCorrectionRequest');
  setTimeout(()=>document.getElementById('orderCorrectionAdminReason')?.focus(),80);
}

async function confirmOrderCorrectionRequest(){
  const id=document.getElementById('orderCorrectionTargetId').value;
  const reason=document.getElementById('orderCorrectionAdminReason').value.trim();
  if(reason.length<5){ showToast('تکایە بە ڕوونی بنووسە کڕیار چی ڕاست بکاتەوە','rd'); return; }
  const btn=document.getElementById('orderCorrectionAdminSubmit');
  btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i> ناردن...';
  try{
    const updated=await adminApiRequest('request_order_correction',{order_id:id,reason});
    showToast(updated?.notification_sent?'داواکاری ڕاستکردنەوە نێردرا و کڕیار ئاگادارکرایەوە':'داواکاری ڕاستکردنەوە نێردرا','gr');
    closeMo('moOrderCorrectionRequest'); closeMo('moOrderDetail');
    refreshOrdersEverywhere();
  }catch(error){ showToast('هەڵە: '+error.message,'rd'); }
  finally{ btn.disabled=false; btn.innerHTML='<i class="fas fa-paper-plane"></i> ناردن بۆ کڕیار'; }
}
async function saveOrderNote(id){
  const note=document.getElementById('odNote').value.trim();
  try{await adminApiRequest('save_order_note',{order_id:id,admin_note:note});}
  catch(error){showToast('هەڵە: '+error.message,'rd');return;}
  showToast('تێبینی پاشەکەوتکرا','gr');
  refreshOrdersEverywhere();
}
// many changes arrive together (live updates): one refresh for all of them
let _ordRefreshTimer=null;
function refreshOrdersEverywhere(){
  clearTimeout(_ordRefreshTimer);
  _ordRefreshTimer=setTimeout(()=>{
    loadDashboardStats();
    if(_curPage==='orders') loadOrders(); else { _ordLoadedAt=0; loadDashOrders(); }
  },400);
}

// ── Original admin module 3 ──
// ══════════════════════════════════════════════════════════════
// ═══ ACCOUNTS ════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let _accountBalances = Object.create(null);
// ── light lists: accounts and orders ────────────────────────────
// What was loaded stays in memory: opening the page again shows it at once
// and refreshes quietly behind it. Only 50 rows are drawn at a time (more on
// request), and only the table on wide screens or the cards on narrow ones.
const LIST_STEP=50;
const _wideList=typeof window!=='undefined'&&window.matchMedia?window.matchMedia('(min-width:901px)'):{matches:true};
let _accShown=LIST_STEP, _accLoadedAt=0, _accLoading=null;
function listMoreHTML(shown,total,fn){
  if(shown>=total) return '';
  return `<div class="list-more"><span>${formatNum(shown)} لە ${formatNum(total)}</span><button type="button" class="act-btn dark" onclick="${fn}()">پیشاندانی ${formatNum(Math.min(LIST_STEP,total-shown))}ی تر</button></div>`;
}
function onWideListChange(){
  if(_curPage==='orders'&&allOrders.length) renderOrders((document.getElementById('orderSearch')?.value||'').toLowerCase());
  if(_curPage==='accounts'&&allAccounts.length) renderAccounts((document.getElementById('accSearch')?.value||'').toLowerCase());
}
if(_wideList.addEventListener) _wideList.addEventListener('change',onWideListChange);
async function loadAccountBalances(userIds){
  const balances=Object.create(null), parts=[];
  for(let from=0;from<userIds.length;from+=200) parts.push(userIds.slice(from,from+200));
  const answers=await Promise.all(parts.map(ids=>adminApiRequest('account_balances',{user_ids:ids})));
  answers.forEach(rows=>(rows||[]).forEach(row=>{balances[row.user_id]=row;}));
  _accountBalances=balances;
}
function accountBalanceValue(row){
  return row ? formatNum(row.available_iqd)+' دینار' : '—';
}
function accountBalanceCell(id){
  const row=_accountBalances[id];
  return '<div>'+accountBalanceValue(row)+'</div>'+
    (row&&Number(row.held_iqd)>0?'<div class="rec-card-sub">پارەی گیراو: '+formatNum(row.held_iqd)+' دینار</div>':'');
}
function accountBalanceDetails(row){
  return dxGroup('باڵانسی هەژمار',
    '<div class="detail-row"><span class="lbl">باڵانسی بەردەست</span><span class="val" dir="ltr">'+accountBalanceValue(row)+'</span></div>'+
    '<div class="detail-row"><span class="lbl">پارەی گیراو</span><span class="val" dir="ltr">'+(row?formatNum(row.held_iqd)+' دینار':'—')+'</span></div>'+
    '<div class="detail-row"><span class="lbl">دوایین نوێکردنەوە</span><span class="val" dir="ltr">'+(row?.updated_at?fmtDateTime(row.updated_at):'—')+'</span></div>');
}
// Entering the page always reads the accounts again (leaving it reset the page).
function openAccountsPage(){
  allAccounts=[]; _accLoadedAt=0; _accShown=LIST_STEP;
  loadAccounts();
}
function showMoreAccounts(){ _accShown+=LIST_STEP; renderAccounts((document.getElementById('accSearch')?.value||'').toLowerCase()); }
// The list shows as soon as the accounts arrive; balances and IPs fill in after.
function loadAccounts(){
  if(_accLoading) return _accLoading;
  const wrap=document.getElementById('accountsTableWrap');
  if(!allAccounts.length) wrap.innerHTML=typeof listSkeleton==='function'?listSkeleton():'';
  const redraw=()=>{ if(_curPage==='accounts') renderAccounts((document.getElementById('accSearch')?.value||'').toLowerCase()); };
  _accLoading=(async()=>{
    try{
      allAccounts = await fetchAllProfiles();
      _accLoadedAt=Date.now();
      redraw();
      await Promise.all([(typeof staffFullAdmin!=='function'||staffFullAdmin())?loadAccountIps():Promise.resolve(),loadAccountBalances(allAccounts.map(a=>a.id))]);
      redraw();
    }catch(e){
      if(!allAccounts.length) wrap.innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
      else showToast('نوێکردنەوەی هەژمارەکان سەرکەوتوو نەبوو','rd');
    }finally{ _accLoading=null; }
  })();
  return _accLoading;
}
// Loads EVERY account. A single request is capped by the API (at most 1000
// rows, and the old .limit(300) hid the oldest accounts), so read page by
// page until an empty page comes back — this works whatever the server cap is.
async function fetchAllProfiles(){
  const PAGE=1000, rows=[], seen=new Set();
  for(let from=0, guard=0; guard<200; guard++){
    const {data,error}=await sb.from('ex_profiles').select('*')
      .order('created_at',{ascending:false}).order('id',{ascending:true})
      .range(from, from+PAGE-1);
    if(error) throw error;
    if(!data || !data.length) break;
    for(const r of data){ if(!seen.has(r.id)){ seen.add(r.id); rows.push(r); } }
    from+=data.length;
  }
  return rows;
}
let _accSearchTimer=null;
function filterAccounts(el,typing){
  if(el){ document.querySelectorAll('[data-af]').forEach(x=>x.classList.remove('on')); el.classList.add('on'); accFilter=el.dataset.af; }
  _accShown=LIST_STEP;
  const run=()=>renderAccounts((document.getElementById('accSearch')?.value||'').toLowerCase());
  // typing waits a moment so every key does not redraw the list
  if(typing){ clearTimeout(_accSearchTimer); _accSearchTimer=setTimeout(run,150); } else run();
}
function accMatches(a,f){
  return f==='banned'?!!a.is_banned:f==='admin'?!!a.is_admin:f==='active'?!a.is_banned:true;
}
function renderAccounts(q=''){
  let list=allAccounts.filter(a=>accMatches(a,accFilter));
  if(q){
    const h=q.replace(/^@/,'');
    list=list.filter(a=>(a.full_name||'').toLowerCase().includes(q)||(a.email||'').toLowerCase().includes(q)
      ||(a.username||'').toLowerCase().includes(h)||String(a.id||'')===q);
  }
  if(typeof document.querySelectorAll==='function') document.querySelectorAll('[data-af]').forEach(tab=>{
    const n=tab.querySelector('.lv-n'); if(!n) return;
    const count=allAccounts.filter(a=>accMatches(a,tab.dataset.af)).length;
    n.textContent=count?formatNum(count):'';
  });
  const countEl=document.getElementById('accCount');
  if(countEl){
    const total=formatNum(allAccounts.length);
    countEl.textContent = list.length===allAccounts.length ? total+' هەژمار' : formatNum(list.length)+' لە '+total;
  }
  const page=list.slice(0,_accShown);
  document.getElementById('accountsTableWrap').innerHTML = (_wideList.matches ? renderAccTable(page) : (page.length ? renderAccCards(page) : renderAccTable(page)))
    + listMoreHTML(page.length,list.length,'showMoreAccounts');
}
function accBadges(a){
  let b='';
  b += a.is_banned ? '<span class="badge banned">باندکراو</span>' : '<span class="badge active">چالاک</span>';
  if(a.role==='super_admin') b += ' <span class="badge super">سوپەر ئادمین</span>';
  else if(a.is_admin) b += ' <span class="badge admin">ئادمین</span>';
  return b;
}
// ── one account per row: person · contact · balance · device · joined · status · actions.
function accRowHTML(a){
  const name=a.full_name||a.email||'بێ ناو';
  const tone=a.is_banned?'banned':(a.is_admin?'admin':'active');
  return `<article class="lv-row lv-acc tone-${tone}">
    <div class="lv-c lv-person"><span class="lv-av">${esc(String(name).trim().charAt(0).toUpperCase()||'?')}</span><div><b>${esc(name)}</b>${a.username?`<small dir="ltr">@${esc(a.username)}</small>`:''}</div></div>
    <div class="lv-c lv-contact"><span dir="ltr">${esc(a.phone||'—')}</span>${a.email?`<small dir="ltr">${esc(a.email)}</small>`:''}</div>
    <div class="lv-c lv-bal"><small>باڵانسی بەردەست</small>${accountBalanceCell(a.id)}</div>
    <div class="lv-c lv-ip">${accIpCell(a.id)}</div>
    <div class="lv-c lv-when"><span dir="ltr">${fmtDate(a.created_at)}</span><small>${fmtAgo(a.created_at)}</small></div>
    <div class="lv-end"><div class="lv-c lv-state">${accBadges(a)}</div>
    <div class="lv-c lv-act"><button type="button" class="lv-btn" onclick="openAccountInfo('${a.id}')">زانیاری</button>${accountAdminActionsHTML(a)}</div></div>
  </article>`;
}
function renderAccTable(list){
  if(!list.length) return '<div class="lv-empty">هیچ هەژمارێک نییە</div>';
  return '<div class="lv-list lv-accounts">'+list.map(accRowHTML).join('')+'</div>';
}
function renderAccCards(list){ return renderAccTable(list); }

// ══════════════════════════════════════════════════════════════
// ═══ ACCOUNT INFO ════════════════════════════════════════════════
// Injected from JS so no change to exchange-admin.html is needed.
// ══════════════════════════════════════════════════════════════
let _accountInfoLoad=0;
// ── detail windows (order, account, identity) share one language with the lists and
// the ban window: a summary card first, then titled groups of label/value rows.
// assets/css/admin-details.css lays them out.
function dxGroup(title, rows, cls){
  return '<section class="dx-group'+(cls?' '+cls:'')+'">'+(title?'<h4 class="dx-h">'+esc(title)+'</h4>':'')+'<div class="dx-card">'+rows+'</div></section>';
}
function dxPersonHead(name, sub, end, tone){
  const n=String(name||'').trim();
  return '<div class="dx-head'+(tone?' tone-'+tone:'')+'"><span class="lv-av">'+esc(n.charAt(0).toUpperCase()||'?')+'</span>'+
    '<div class="dx-head-main"><b>'+esc(n||'بێ ناو')+'</b>'+(sub?'<small dir="ltr">'+esc(sub)+'</small>':'')+'</div>'+
    (end?'<div class="dx-head-end">'+end+'</div>':'')+'</div>';
}
function ensureAccountInfoModal(){
  if(document.getElementById('moAccountInfo')) return;
  const o=document.createElement('div');
  o.className='overlay'; o.id='moAccountInfo';
  o.innerHTML=`<div class="modal dx-modal" role="dialog" aria-modal="true" aria-labelledby="aiTitle">
      <div class="modal-hdr">
        <h3>زانیاری هەژمار</h3>
        <div class="modal-close" onclick="closeMo('moAccountInfo')"><i class="fas fa-xmark"></i></div>
      </div>
      <div class="dx-head" id="aiHead"><span class="lv-av" id="aiAv"></span><div class="dx-head-main"><b id="aiTitle"></b><small id="aiSub" dir="ltr"></small></div><div class="dx-head-end" id="aiBadges"></div></div>
      <div id="aiBody"></div>
    </div>`;
  document.body.appendChild(o);
  o.addEventListener('click', e=>{ if(e.target===o) closeMo('moAccountInfo'); });
}

function contactCell(value, verified){
  if(!value) return '—';
  return esc(value)+(verified?' <span class="ct-ver is-ok">پشتڕاستکراوە</span>':' <span class="ct-ver">پشتڕاست نەکراوە</span>');
}
async function openAccountInfo(id){
  const a=allAccounts.find(x=>x.id===id);
  if(!a){ showToast('هەژمارەکە نەدۆزرایەوە','rd'); return; }
  ensureAccountInfoModal();
  const loadId=++_accountInfoLoad;
  const name=a.full_name||a.email||'زانیاری هەژمار';
  document.getElementById('aiTitle').textContent=name;
  document.getElementById('aiAv').textContent=String(name).trim().charAt(0).toUpperCase()||'?';
  document.getElementById('aiSub').textContent=[a.username?'@'+a.username:'',a.phone||a.email||''].filter(Boolean).join('  ·  ');
  document.getElementById('aiBadges').innerHTML=accBadges(a);
  const head=document.getElementById('aiHead');
  if(head) head.className='dx-head tone-'+(a.is_banned?'banned':a.is_admin?'admin':'active');
  const row=(label,value,attrs='')=>'<div class="detail-row"><span class="lbl">'+label+'</span><span class="val"'+attrs+'>'+value+'</span></div>';

  const base=dxGroup('زانیاری بنەڕەتی',
    row('ناوی تەواو',esc(a.full_name||'—'),' dir="rtl"')+
    row('ناوی بەکارهێنەر',a.username?'@'+esc(a.username):'—',' dir="ltr"')+
    row('ژمارەی مۆبایل',contactCell(a.phone, !!a.phone_verified_at),' dir="ltr"')+
    row('ئیمەیڵ',contactCell(a.email, !!a.email_verified_at),' dir="ltr"')+
    row('ڕۆڵ',a.role==='super_admin'?'سوپەر ئادمین':a.role==='admin'?'ئادمین':'بەکارهێنەر',' dir="rtl"')+
    row('بەرواری تۆمارکردن',esc(fmtDate(a.created_at)+(fmtTime(a.created_at)?' — '+fmtTime(a.created_at):'')),' dir="ltr"')+
    row('تەمەنی هەژمار',esc(fmtAgo(a.created_at)||'—'),' dir="rtl"')+
    row('ئایدی بەکارهێنەر',esc(a.id),' dir="ltr" data-small="1"'));

  document.getElementById('aiBody').innerHTML = base + accountBalanceDetails(null) +
    `<section class="dx-group"><h4 class="dx-h">داواکارییەکان</h4><div class="dx-card dx-wait"><i class="fas fa-circle-notch fa-spin"></i></div></section>`;
  openMo('moAccountInfo');

  const [ordersRes, ipsRes, balanceRes] = await Promise.all([
    sb.from('ex_orders').select('status,total,created_at').eq('user_id',id).order('created_at',{ascending:false}),
    securityRequest('user-ips',{query:'&user_id='+encodeURIComponent(id)+'&limit=5'}).catch(()=>({ips:[]})),
    adminApiRequest('account_balances',{user_ids:[id]}).then(data=>({data})).catch(error=>({error}))
  ]);

  if(loadId!==_accountInfoLoad)return;
  if(!balanceRes.error){
    _accountBalances[id]=balanceRes.data[0];
    if(_curPage==='accounts')filterAccounts();
  }
  const balanceHtml=balanceRes.error
    ? '<section class="dx-group"><h4 class="dx-h">باڵانسی هەژمار</h4><p class="dx-quiet is-bad">نەتوانرا باڵانس بخوێندرێتەوە: '+esc(balanceRes.error.message)+'</p></section>'
    : accountBalanceDetails(balanceRes.data[0]);

  const orders = ordersRes.data||[];
  const n  = s => orders.filter(o=>o.status===s).length;
  const volume = orders.filter(o=>o.status===STATUS_APPROVED)
                       .reduce((s,o)=>s+(parseFloat(o.total)||0),0);
  const last = orders[0];

  let html = base + balanceHtml + `
    <section class="dx-group"><h4 class="dx-h">داواکارییەکان</h4>
    <div class="dx-card dx-stats">
      <div class="dx-stat"><b>${formatNum(orders.length)}</b><span>کۆی داواکاری</span></div>
      <div class="dx-stat tone-wait"><b>${formatNum(n(STATUS_PENDING))}</b><span>چاوەڕوان</span></div>
      <div class="dx-stat tone-ok"><b>${formatNum(n(STATUS_APPROVED))}</b><span>پەسەندکراو</span></div>
      <div class="dx-stat tone-no"><b>${formatNum(n(STATUS_REJECTED))}</b><span>ڕەتکراو</span></div>
    </div>
    <div class="dx-card">${row('کۆی گۆڕینەوەی پەسەندکراو',esc(formatNum(volume)+' IQD'),' dir="ltr"')}${row('دوایین داواکاری',last?esc(fmtDateTime(last.created_at)):'—',' dir="ltr"')}</div>
    </section>`;

  const ips = ipsRes.ips||[];
  html += `<section class="dx-group"><h4 class="dx-h">پشتڕاستکردنەوەی ناسنامە</h4>
    <div class="dx-card">${row('دۆخ','<i class="fas fa-circle-notch fa-spin"></i>',' dir="rtl" id="aiKycStatus"')}</div>
    <div class="dx-acts">
      <button type="button" class="act-btn" onclick="openKycRequestById('${esc(a.id)}')">داواکردنی پشتڕاستکردنەوە</button>
      <button type="button" class="act-btn" onclick="closeMo('moAccountInfo');goPage('kyc');setTimeout(()=>{const s=document.getElementById('kycListSearch'); if(s){ s.value='${esc(a.username||'')}'; setKycFilter('all'); }},50)">مێژووی پشتڕاستکردنەوە</button>
    </div></section>`;
  html += ips.length ? dxGroup('IP و ئامێر', ips.map(r=>`
      <div class="detail-row dx-ip">
        <span class="lbl"><span class="ip-chip ${r.is_banned?'banned':''}" dir="ltr">${esc(r.ip_address)}</span><small>${esc([r.browser,r.os,r.device].filter(Boolean).join(' · ')||'—')}</small></span>
        <span class="val" dir="rtl">${formatNum(r.events)} ڕووداو<small dir="ltr">${esc(fmtDateTime(r.last_seen))}</small></span>
      </div>`).join(''))
    : '<section class="dx-group"><h4 class="dx-h">IP و ئامێر</h4><p class="dx-quiet">هیچ IPـیەک بۆ ئەم هەژمارە تۆمار نەکراوە.</p></section>';

  document.getElementById('aiBody').innerHTML = html;
  try{
    const rows=await sb.rpc('ex_admin_kyc_search_users',{p_query:id,p_limit:1});
    if(loadId!==_accountInfoLoad)return;
    const st=rows.data?.[0]?.kyc_status||'none';
    const el=document.getElementById('aiKycStatus');
    if(el) el.innerHTML=kycBadgeHTML(st);
  }catch(_){}
}
function accountAdminActionsHTML(a){
  if(typeof isSuperAdmin!=='function' || !isSuperAdmin()) return '';
  // the rarely used actions sit in one menu so the row stays calm
  return `<button type="button" class="lv-btn ${a.is_banned?'is-ok':'is-no'}" onclick="toggleBan('${a.id}',${!!a.is_banned})">${a.is_banned?'لابردنی باند':'باندکردن'}</button>
    <details class="lv-more"><summary aria-label="کردارەکانی تر">زیاتر</summary><div class="lv-menu">
    <div class="act-btn cy" onclick="openContactModal('${a.id}')">ئیمەیڵ و ژمارە</div>
    <div class="act-btn dark" onclick="openSetPasswordModal('${a.id}','${esc(a.email||'').replace(/'/g,"\\'")}')">گۆڕینی وشەی نهێنی</div>
    <div class="act-btn cy" onclick="openKycRequestById('${a.id}')">پشتڕاستکردنەوە</div>
    ${roleButtonHTML(a)}</div></details>`;
}
// Ban / unban: one dialog with the person, an optional reason the customer sees
// on their banned screen, and the date it started.
const BAN_REASONS=['پسوولەی ساختە','هەوڵی فێڵکردن','بەکارهێنانی هەژماری کەسێکی تر','بە داوای خاوەنی هەژمار'];
let _banTarget=null;
function ensureBanModal(){
  if(document.getElementById('moBan')) return;
  const o=document.createElement('div');
  o.className='overlay'; o.id='moBan';
  o.innerHTML=`<div class="modal ban-modal" role="dialog" aria-modal="true" aria-labelledby="banTitle">
      <div class="modal-hdr"><h3 id="banTitle"></h3><div class="modal-close" onclick="closeMo('moBan')"><i class="fas fa-xmark"></i></div></div>
      <div class="ban-person" id="banPerson"></div>
      <div id="banBody"></div>
      <div class="ban-err" id="banErr" role="alert"></div>
      <div class="ban-btns">
        <button type="button" class="modal-btn ban-cancel" onclick="closeMo('moBan')">پاشگەزبوونەوە</button>
        <button type="button" class="modal-btn" id="banGo" onclick="submitBan()"></button>
      </div>
    </div>`;
  document.body.appendChild(o);
  o.addEventListener('click', e=>{ if(e.target===o) closeMo('moBan'); });
}
function toggleBan(id, current){
  if(!isSuperAdmin())return;
  ensureBanModal();
  const next=!current;
  const a=(allAccounts||[]).find(x=>x.id===id)||(typeof _staffDirectoryRows!=='undefined'?(_staffDirectoryRows||[]).find(x=>x.id===id):null)||{id};
  _banTarget={id,next};
  const name=a.full_name||a.email||'هەژمار';
  document.getElementById('banTitle').textContent=next?'باندکردنی هەژمار':'لابردنی باند';
  document.getElementById('banPerson').innerHTML=`<span class="lv-av">${esc(String(name).trim().charAt(0).toUpperCase()||'?')}</span><div><b>${esc(name)}</b><small dir="ltr">${esc(a.phone||a.email||'')}</small></div>`;
  if(next){
    document.getElementById('banBody').innerHTML=`<label class="modal-lbl" for="banReason">هۆکار <span class="ban-hint">کڕیار دەیبینێت</span></label>
      <div class="ban-chips">${BAN_REASONS.map(r=>`<button type="button" class="ban-chip" onclick="pickBanReason(this)">${esc(r)}</button>`).join('')}</div>
      <textarea class="minp mta" id="banReason" maxlength="300" rows="3" placeholder="ئارەزوومەندانە" oninput="document.getElementById('banCount').textContent=this.value.length+'/300'"></textarea>
      <div class="ban-count" id="banCount" dir="ltr">0/300</div>`;
  }else{
    const when=a.banned_at?fmtDateTime(a.banned_at):'';
    document.getElementById('banBody').innerHTML=(a.ban_reason||when)?`<dl class="ban-facts">${a.ban_reason?`<div><dt>هۆکار</dt><dd>${esc(a.ban_reason)}</dd></div>`:''}${when?`<div><dt>لە</dt><dd dir="ltr">${esc(when)}</dd></div>`:''}</dl>`:'';
  }
  const go=document.getElementById('banGo');
  go.textContent=next?'باندکردن':'لابردنی باند';
  go.className='modal-btn '+(next?'ban-go-no':'ban-go-ok');
  go.disabled=false;
  document.getElementById('banErr').textContent='';
  openMo('moBan');
}
function pickBanReason(btn){
  const box=document.getElementById('banReason'); if(!box) return;
  box.value=btn.textContent; box.dispatchEvent(new Event('input'));
  document.querySelectorAll('.ban-chip').forEach(x=>x.classList.toggle('on',x===btn));
}
async function submitBan(){
  if(!_banTarget||!isSuperAdmin()) return;
  const {id,next}=_banTarget;
  const go=document.getElementById('banGo'); if(go.disabled) return; go.disabled=true;
  const reason=next?(document.getElementById('banReason')?.value||'').trim().slice(0,300):null;
  try{
    await adminApiRequest('set_ban',{user_id:id,banned:next,reason});
    closeMo('moBan');
    showToast(next?'هەژمارەکە باندکرا':'باندەکە لابرا', next?'rd':'gr');
    loadAccounts(); loadDashboardStats();
  }catch(e){
    document.getElementById('banErr').textContent=adminDbMessage(e);
    go.disabled=false;
  }
}
// Role changes are super-admin only and go through ex_admin_set_role; the
// database rejects them for everyone else, this only hides the button.
function roleButtonHTML(a){
  if(!isSuperAdmin() || (adminUser && a.id===adminUser.id) || a.role==='super_admin') return '';
  return `<div class="act-btn ${a.is_admin?'yw':'pu'}" onclick="toggleAdmin('${a.id}',${!!a.is_admin})"><i class="fas fa-shield"></i> ${a.is_admin?'لابردنی ئادمین':'کردن بە ئادمین'}</div>`+
    (typeof staffPermissionButton==='function'?staffPermissionButton(a):'');
}
function toggleAdmin(id, current){
  if(!isSuperAdmin()){ showToast('تەنها سوپەر ئادمین دەتوانێت ڕۆڵ بگۆڕێت','rd'); return; }
  const next=!current;
  confirm2(next?'کردن بە ئادمین':'لابردنی ئادمین', next?'ئایا دەتەوێت مافی ئادمین بدەیت بەم هەژمارە؟':'ئایا دەتەوێت مافی ئادمین لاببەیت؟',
    'fas fa-shield-halved','var(--cy)', async()=>{
    const {error} = await sb.rpc('ex_admin_set_role',{p_user_id:id, p_role: next?'admin':'user'});
    if(error){ showToast(adminDbMessage(error),'rd'); return; }
    showToast(next?'کرا بە ئادمین':'مافی ئادمین لابرا','gr');
    loadAccounts();
  });
}

// ══════════════════════════════════════════════════════════════
// ═══ ADMIN: SET USER PASSWORD (via secure Edge Function) ════════
// The actual password write happens server-side in the
// "admin-set-password" Edge Function using the service-role key.
// That key is never present in this admin panel's code — only a
// server-side function may hold it. This client just calls that
// function with the admin's own session token.
// ══════════════════════════════════════════════════════════════

// Shared caller for the admin Edge Functions.
// The old code did `await res.json()` straight away — when the function
// returned a non-JSON body (platform 404/401/5xx, cold-start timeout, CORS
// block) that threw "Unexpected token" or "Failed to fetch" and the panel
// showed a meaningless error. This reads the body as text first, parses it
// only if it IS JSON, and always ends up with a message that says which
// step actually failed.
const ADMIN_FN_ERRORS = {
  missing_authorization: 'تۆکنی چوونەژوورەوە نەنێردرا — دووبارە بچۆرەوە ژوورەوە',
  invalid_session:       'چوونەژوورەوەت بەسەرچووە — دووبارە بچۆرەوە ژوورەوە',
  forbidden:             'ئەم هەژمارە مافی ئادمینی نییە',
  profile_lookup_failed: 'نەتوانرا پرۆفایلی ئادمین بخوێندرێتەوە',
  user_not_found:        'ئەم بەکارهێنەرە لە سیستەمدا نەدۆزرایەوە',
  password_too_short:    'وشەی نهێنی دەبێت لانیکەم 8 پیت/ژمارە بێت',
  update_failed:         'سێرڤەر نەیتوانی وشەی نهێنی نوێ بکاتەوە',
  create_failed:         'دروستکردنی هەژمار سەرکەوتوو نەبوو',
  missing_env:           'کلیلی service-role لە سێرڤەردا دانەنراوە',
  unhandled_exception:   'هەڵەیەکی چاوەڕوان‌نەکراو لە سێرڤەر',
};

async function callAdminFn(fnName, payload){
  const {data:{session}, error:sessErr} = await sb.auth.getSession();
  if(sessErr || !session?.access_token){
    throw new Error('چوونەژوورەوەت بەسەرچووە — دووبارە بچۆرەوە ژوورەوە');
  }

  const ctrl = new AbortController();
  const timer = setTimeout(()=>ctrl.abort(), 25000);
  let res;
  try{
    res = await fetch(SB_URL + '/functions/v1/' + fnName, {
      method:'POST',
      headers:{
        'Content-Type':'application/json',
        'Authorization':'Bearer '+session.access_token,
        'apikey': SB_KEY
      },
      body: JSON.stringify(payload),
      signal: ctrl.signal
    });
  }catch(e){
    if(e.name === 'AbortError') throw new Error('سێرڤەر وەڵامی نەدایەوە (25 چرکە) — دووبارە هەوڵبدەوە');
    throw new Error('نەگەیشتە سێرڤەر — ئینتەرنێت یان CORS بلۆکی کردووە ['+fnName+']');
  }finally{ clearTimeout(timer); }

  const raw = await res.text();
  let data = null;
  try{ data = raw ? JSON.parse(raw) : null; }catch(_){ /* not JSON */ }

  if(!res.ok || !data || data.success !== true){
    if(res.status === 404 && !data?.error){
      throw new Error('فەنکشنی «'+fnName+'» لە Supabase دانەمەزراوە (404)');
    }
    const code = data?.error || '';
    const base = data?.message || ADMIN_FN_ERRORS[code] || (raw ? raw.slice(0,160) : '') || 'هەڵەی سێرڤەر';
    const tag  = [code || ('HTTP '+res.status), data?.stage].filter(Boolean).join('/');
    const err  = new Error(base + ' [' + tag + ']');
    err.code = code; err.httpStatus = res.status;
    throw err;
  }
  return data;
}

function openSetPasswordModal(userId, email){
  if(!isSuperAdmin()){showToast('تەنها سوپەر ئادمین دەتوانێت وشەی نهێنی بگۆڕێت','rd');return;}
  document.getElementById('spUserId').value = userId;
  document.getElementById('spUserLabel').textContent = email || '—';
  document.getElementById('spNewPass').value = '';
  document.getElementById('spNewPass2').value = '';
  document.getElementById('spErr').style.display='none';
  setSpVisibility(false);
  openMo('moSetPassword');
}
// ── account e-mail / number ─────────────────────────────────
function openContactModal(userId){
  if(!isSuperAdmin()){ showToast('تەنها سوپەر ئادمین دەتوانێت ئیمەیڵ و ژمارە بگۆڕێت','rd'); return; }
  const a=allAccounts.find(x=>x.id===userId);
  if(!a){ showToast('هەژمارەکە نەدۆزرایەوە','rd'); return; }
  document.getElementById('ctUserId').value=userId;
  document.getElementById('ctUserLabel').textContent=a.full_name||a.username||'—';
  document.getElementById('ctCurEmail').innerHTML=contactCell(a.email, !!a.email_verified_at);
  document.getElementById('ctCurPhone').innerHTML=contactCell(a.phone, !!a.phone_verified_at);
  document.getElementById('ctEmail').value='';
  document.getElementById('ctPhone').value='';
  document.getElementById('ctErr').style.display='none';
  openMo('moContact');
}
function contactLocalPhone(raw){
  let d=String(raw||'').replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-1632)).replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-1776)).replace(/\D/g,'');
  if(d.startsWith('00964')) d=d.slice(5); else if(d.startsWith('964')) d=d.slice(3);
  if(d && !d.startsWith('0')) d='0'+d;
  return d;
}
async function submitContact(){
  const errEl=document.getElementById('ctErr');
  const fail=t=>{ errEl.textContent=t; errEl.style.display='block'; };
  errEl.style.display='none';
  if(!isSuperAdmin()) return fail('تەنها سوپەر ئادمین دەتوانێت ئیمەیڵ و ژمارە بگۆڕێت');
  const userId=document.getElementById('ctUserId').value;
  const email=document.getElementById('ctEmail').value.trim().toLowerCase();
  const phone=contactLocalPhone(document.getElementById('ctPhone').value);
  if(!email && !phone) return fail('ئیمەیڵ یان ژمارەیەکی نوێ بنووسە');
  if(email && !/^[a-z0-9._%+-]+@gmail\.com$/.test(email)) return fail('ئیمەیڵەکە دروست نییە');
  if(phone && !/^07[3-9]\d{8}$/.test(phone)) return fail('ژمارەی مۆبایلەکە دروست نییە');
  const btn=document.getElementById('ctSaveBtn');
  btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    const data=await adminApiRequest('account_contact_update',{user_id:userId,email:email||null,phone:phone||null});
    const a=allAccounts.find(x=>x.id===userId);
    if(a){
      const now=new Date().toISOString();
      if(email){ a.email=data.email||email; a.email_verified_at=now; }
      if(phone){ a.phone=data.phone||phone; a.phone_verified_at=now; }
    }
    closeMo('moContact');
    showToast('✅ زانیارییەکانی پەیوەندی گۆڕدران','gr');
    if(typeof filterAccounts==='function') filterAccounts();
  }catch(e){
    fail(e && e.code ? e.message : adminDbMessage(e));     // the server already explains in Kurdish
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-check"></i> پاشەکەوتکردن';
  }
}
function setSpVisibility(show){
  ['spNewPass','spNewPass2'].forEach(id=>{ document.getElementById(id).type = show ? 'text' : 'password'; });
  document.getElementById('spEyeIco').className = show ? 'fas fa-eye-slash' : 'fas fa-eye';
  document.getElementById('spEyeTxt').textContent = show ? 'شاردنەوەی وشەی نهێنی' : 'پیشاندانی وشەی نهێنی';
}
function toggleSpVisibility(){
  setSpVisibility(document.getElementById('spNewPass').type === 'password');
}
async function submitSetPassword(){
  const errEl = document.getElementById('spErr');
  if(!isSuperAdmin()){errEl.textContent='تەنها سوپەر ئادمین مافی گۆڕینی وشەی نهێنی هەیە';errEl.style.display='block';return;}
  errEl.style.display='none';
  const userId = document.getElementById('spUserId').value;
  const pass = document.getElementById('spNewPass').value;
  const pass2 = document.getElementById('spNewPass2').value;
  if(!userId){ errEl.textContent='بەکارهێنەر دیاری نەکراوە — پەنجەرەکە دابخە و دووبارە هەوڵبدەوە'; errEl.style.display='block'; return; }
  if(pass.length < 8){ errEl.textContent='وشەی نهێنی دەبێت لانیکەم 8 پیت/ژمارە بێت'; errEl.style.display='block'; return; }
  if(pass !== pass2){ errEl.textContent='وشەکانی نهێنی وەک یەک نین'; errEl.style.display='block'; return; }
  const btn = document.getElementById('spSaveBtn');
  btn.disabled = true; btn.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    // /api/admin sets it where this account keeps it (number accounts: their own hash,
    // e-mail accounts: Supabase Auth) and signs the customer out on every device.
    await adminApiRequest('account_set_password', { user_id:userId, password:pass });
    closeMo('moSetPassword');
    showToast('✅ وشەی نهێنی گۆڕدرا — بەکارهێنەر لە هەموو ئامێرەکان چووە دەرەوە','gr');
  }catch(e){
    errEl.textContent = e && e.code ? e.message : adminDbMessage(e); errEl.style.display='block';
    console.error('account_set_password failed:', e);
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-check"></i> پاشەکەوتکردن';
  }
}

// ══════════════════════════════════════════════════════════════
// ═══ ADMIN: CREATE USER (via secure Edge Function) ══════════════
// ══════════════════════════════════════════════════════════════
let _createUserOtpEmail='';
function openCreateUserModal(){
  if(!isSuperAdmin()){showToast('تەنها سوپەر ئادمین دەتوانێت هەژمار زیاد بکات','rd');return;}
  document.getElementById('cuName').value = '';
  document.getElementById('cuEmail').value = '';
  document.getElementById('cuPhone').value = '';
  document.getElementById('cuPass').value = '';
  document.getElementById('cuOtp').value = '';
  document.getElementById('cuOtpMsg').style.display='none';
  _createUserOtpEmail='';
  document.getElementById('cuIsAdmin').checked = false;
  document.getElementById('cuErr').style.display='none';
  document.getElementById('cuIsAdmin').closest('.mswitch-row').hidden=!isSuperAdmin();
  openMo('moCreateUser');
}
async function requestCreateUserOtp(){
  const errEl=document.getElementById('cuErr');
  const email=document.getElementById('cuEmail').value.trim().toLowerCase();
  const btn=document.getElementById('cuSendOtpBtn');
  if(!isSuperAdmin()){errEl.textContent='تەنها سوپەر ئادمین مافی زیادکردنی هەژمار هەیە';errEl.style.display='block';return;}
  if(!email||!email.includes('@')){errEl.textContent='ئیمەیلێکی دروست بنووسە';errEl.style.display='block';return;}
  errEl.style.display='none';btn.disabled=true;btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    const result=await callAdminFn('admin-create-user',{action:'request_otp',email});
    _createUserOtpEmail=email;
    document.getElementById('cuOtp').value='';
    const msg=document.getElementById('cuOtpMsg');
    msg.textContent=result?.already_sent?'کۆدێکی چالاک هەیە؛ هەمان کۆدەکە بەکاربهێنە.':'کۆدی OTP بۆ ئیمەیڵەکە نێردرا.';
    msg.style.display='block';
  }catch(e){errEl.textContent=e.message;errEl.style.display='block';}
  finally{btn.disabled=false;btn.innerHTML='<i class="fas fa-paper-plane"></i> ناردنی کۆد بۆ ئیمەیڵ';}
}
async function submitCreateUser(){
  const errEl = document.getElementById('cuErr');
  if(!isSuperAdmin()){errEl.textContent='تەنها سوپەر ئادمین مافی زیادکردنی هەژمار هەیە';errEl.style.display='block';return;}
  errEl.style.display='none';
  const full_name = document.getElementById('cuName').value.trim();
  const email = document.getElementById('cuEmail').value.trim();
  const phone = document.getElementById('cuPhone').value.trim();
  const password = document.getElementById('cuPass').value;
  const is_admin = document.getElementById('cuIsAdmin').checked;
  const otp_code = document.getElementById('cuOtp').value.replace(/\D/g,'');
  if(!email || !email.includes('@')){ errEl.textContent='ئیمەیلێکی دروست بنووسە'; errEl.style.display='block'; return; }
  if(password.length < 8){ errEl.textContent='وشەی نهێنی دەبێت لانیکەم 8 پیت/ژمارە بێت'; errEl.style.display='block'; return; }
  if(_createUserOtpEmail!==email.toLowerCase()){errEl.textContent='سەرەتا کۆدی پشتڕاستکردنەوە بۆ ئەم ئیمەیڵە داوا بکە';errEl.style.display='block';return;}
  if(!/^\d{6}$/.test(otp_code)){errEl.textContent='کۆدی 6 ژمارەیی بنووسە';errEl.style.display='block';return;}
  const btn = document.getElementById('cuSaveBtn');
  btn.disabled = true; btn.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    await callAdminFn('admin-create-user', { action:'create', email, password, full_name, phone, is_admin, otp_code });
    closeMo('moCreateUser');
    showToast('✅ هەژمار دروستکرا','gr');
    loadAccounts(); loadDashboardStats();
  }catch(e){
    errEl.textContent = e.message; errEl.style.display='block';
    console.error('admin-create-user failed:', e);
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-check"></i> دروستکردن';
  }
}

// ══════════════════════════════════════════════════════════════
// ═══ RATES & FEES ════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let _ratesAdminChannel=null;
async function loadRates(){
  document.getElementById('ratesTableWrap').innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    // wallet names and order for the grouped list (once)
    const wallets = !allWallets.length && typeof loadWalletsAdmin==='function' ? loadWalletsAdmin(true).catch(()=>{}) : null;
    const {data,error} = await sb.from('ex_rates').select('*').order('from_method').order('to_method');
    if(error) throw error;
    allRates = data||[];
    if(wallets) await wallets;
    renderRates();
  }catch(e){
    document.getElementById('ratesTableWrap').innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
  }
  subscribeRatesAdmin();
}
function subscribeRatesAdmin(){if(typeof startAdminLive==='function')startAdminLive();}
// Method options for the rate From/To selects: only the wallets in ex_wallets.
function buildMethodLabelMap(){
  const map=new Map();
  allWallets.forEach(w=>{ if(w.key) map.set(w.key, w.name||w.key); });
  return map;
}
function buildFromMethodKeys(){
  return allWallets.filter(w=>w.key && w.allow_from!==false).map(w=>w.key);
}
function buildToMethodKeys(){
  return allWallets.filter(w=>w.key && w.allow_receive===true).map(w=>w.key);
}
function rateTypeLabel(t){ return t==='fee_percent' ? 'حمولە %' : t==='fee_fixed' ? 'حمولەی جێگیر' : 'مەزراپ'; }
// Routes grouped by the wallet they leave from: destination, fee (or the
// amount steps), on/off, edit, delete.
function rateFeeText(r){
  const b=pairBracketsOfRow(r);
  return b ? feeStepsTextOf(b) : (typeof rateFeeLabel==='function' ? rateFeeLabel(r) : fmtPairValue(r.rate_type,r.rate_value));
}
function feeStepsTextOf(b){
  return typeof feeStepsText==='function' ? feeStepsText(b) : pairTierText({brackets:b});
}
function renderRates(){
  const wrap=document.getElementById('ratesTableWrap');
  if(!wrap) return;
  if(typeof renderFeeTierCard==='function') renderFeeTierCard();
  if(!allRates.length){ wrap.innerHTML='<div class="empty"><i class="fas fa-percent"></i><p>هیچ ڕێگایەک زیاد نەکراوە</p></div>'; return; }
  const list=typeof filteredAdminRates==='function'?filteredAdminRates():allRates;
  if(!list.length){ wrap.innerHTML='<div class="empty"><p>هیچ ڕێگایەک نەدۆزرایەوە</p></div>'; return; }
  const groups=typeof groupRatesByWallet==='function'?groupRatesByWallet(list):[[null,list]];
  wrap.innerHTML='<div class="rl-groups">'+groups.map(([from,rows])=>`<section class="rl-grp">
    ${from!==null?`<header class="rl-h"><b>${esc(walletLabelFor(from)||'—')}</b><small>${rows.length} ڕێگا</small></header>`:''}
    ${rows.map(r=>{const steps=pairBracketsOfRow(r);return `<div class="rl-row${r.is_active?'':' off'}">
      <div class="rl-main"><b>${esc(walletLabelFor(r.to_method)||'—')}</b><span class="rl-fee${steps?' steps':''}">${esc(rateFeeText(r))}</span></div>
      <label class="mswitch" title="${r.is_active?'چالاکە':'ناچالاکە'}"><input type="checkbox" aria-label="چالاک" ${r.is_active?'checked':''} onchange="toggleRateActive('${r.id}',this.checked)"><span class="track"></span></label>
      <div class="rl-act">
        <button type="button" class="act-btn dark" aria-label="دەستکاری" title="دەستکاری" onclick='openRateModal(${safeAttr(r)})'><i class="fas fa-pen"></i></button>
        <button type="button" class="act-btn rd" aria-label="سڕینەوە" title="سڕینەوە" onclick="deleteRate('${r.id}')"><i class="fas fa-trash"></i></button>
      </div>
    </div>`;}).join('')}
  </section>`).join('')+'</div>';
}
async function toggleRateActive(id, val){
  const {error} = await sb.from('ex_rates').update({is_active:val}).eq('id',id);
  if(error){ await handleDbWriteError(error); loadRates(); return; }
  showToast(val?'چالاککرا':'ناچالاککرا','gr');
  const r=allRates.find(x=>x.id===id); if(r) r.is_active=val;
}
function deleteRate(id){
  confirm2('سڕینەوەی ڕێگا','ئایا دڵنیایت لە سڕینەوەی ئەم ڕێگا گۆڕینەوەیە؟','fas fa-trash','var(--rd)', async()=>{
    const {error} = await sb.from('ex_rates').delete().eq('id',id);
    if(error){ await handleDbWriteError(error); return; }
    showToast('ڕێگاکە سڕایەوە','gr');
    loadRates();
  });
}
async function openRateModal(rate){
  if(!allWallets.length) await loadWalletsAdmin();
  const labelMap = buildMethodLabelMap();
  const fromKeys = buildFromMethodKeys(), toKeys = buildToMethodKeys();
  const fromSel=document.getElementById('rateFrom'), toSel=document.getElementById('rateTo');
  fromSel.innerHTML = fromKeys.map(k=>`<option value="${esc(k)}">${esc(labelMap.get(k)||k)}</option>`).join('');
  toSel.innerHTML = toKeys.map(k=>`<option value="${esc(k)}">${esc(labelMap.get(k)||k)}</option>`).join('');
  if(rate){
    document.getElementById('rateModalTitle').textContent='دەستکاریکردنی ڕێگا';
    document.getElementById('rateId').value=rate.id;
    fromSel.value=rate.from_method; toSel.value=rate.to_method;
    document.getElementById('rateType').value=rate.rate_type;
    document.getElementById('rateValue').value=rate.rate_value;
    document.getElementById('rateActive').checked=rate.is_active;
  }else{
    document.getElementById('rateModalTitle').textContent='زیادکردنی ڕێگای نوێ';
    document.getElementById('rateId').value='';
    fromSel.selectedIndex=0; toSel.selectedIndex=0;
    document.getElementById('rateType').value='fee_percent';
    document.getElementById('rateValue').value='';
    document.getElementById('rateActive').checked=true;
  }
  if(typeof ftModalOpen==='function') ftModalOpen(rate||null);
  updateRateValueHint();updateAdminRatePreview();
  openMo('moRate');
}
function updateRateValueHint(){
  const t=document.getElementById('rateType').value;
  document.getElementById('rateValueHint').textContent = t==='fee_percent'
    ? 'بڕی وەرگیراو = بڕی نێردراو − (بڕی نێردراو × ڕێژە ÷ 100)'
    : t==='fee_fixed'
    ? 'بڕی وەرگیراو = بڕی نێردراو − حمولەی جێگیر'
    : 'بڕی وەرگیراو = بڕی نێردراو × ژمارەی مەزراپ';
}
async function saveRate(){
 const id=document.getElementById('rateId').value;
 const from=document.getElementById('rateFrom').value,to=document.getElementById('rateTo').value;
 const rate_type=document.getElementById('rateType').value;
 const rate_value=Number(document.getElementById('rateValue').value),is_active=document.getElementById('rateActive').checked;
 if(from===to||!document.getElementById('rateValue').value.trim()||!Number.isFinite(rate_value)||rate_value<0){showToast('ڕێگا و بەهای دروست هەڵبژێرە','rd');return;}
 const btn=document.getElementById('rateSaveBtn');if(btn.disabled)return;btn.disabled=true;
 try{
  const row={from_method:from,to_method:to,rate_type,rate_value,is_active};
  const prevRate=id?allRates.find(r=>String(r.id)===String(id)):null;
  // amount steps (exchange-fee-tiers.js); a route that cannot take steps has them switched off instead of failing the save
  if(typeof ftModalPatch==='function') Object.assign(row,ftModalPatch(prevRate));
  else if(prevRate&&(prevRate.fee_tier_enabled||prevRate.fee_brackets)&&!(rate_type==='fee_percent'||(rate_type==='multiplier'&&rate_value<=1))){row.fee_tier_enabled=false;row.fee_brackets=null;}
  const query=id?sb.from('ex_rates').update(row).eq('id',id):sb.from('ex_rates').insert(row);
  const {data,error}=await query.select('*').single();if(error)throw error;
  if(!data?.id)throw new Error('پاشەکەوتکردن پشتڕاست نەکرایەوە');
  allRates=allRates.filter(r=>r.id!==data.id).concat(data);filterAdminRates();
  closeMo('moRate');showToast('نرخی ئەم ڕێگایە پاشەکەوتکرا','gr');
 }catch(e){showToast(adminDbMessage(e),'rd');}finally{btn.disabled=false;}
}

// ── Original admin module 4 ──
// ══════════════════════════════════════════════════════════════
// ═══ WALLETS ═════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let allWallets=[];
let _walletsAdminChannel=null;

async function loadWalletsAdmin(quiet=false){
  if(!quiet)document.getElementById('walletsGridWrap').innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const {data,error} = await sb.from('ex_wallets').select('*').order('sort_order',{ascending:true});
    if(error) throw error;
    allWallets = data||[];
    syncMethodMeta(allWallets);
    await loadPairs();
    renderWalletsGrid();
  }catch(e){
    document.getElementById('walletsGridWrap').innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p><p style="font-size:11px;margin-top:6px">دڵنیابەرەوە خشتەی ex_wallets دروستکراوە (بڕوانە SQL پێشکەشکراو)</p></div>`;
  }
  subscribeWalletsAdmin();
}
function subscribeWalletsAdmin(){if(typeof startAdminLive==='function')startAdminLive();}
function renderWalletsGrid(){
  const wrap=document.getElementById('walletsGridWrap');
  if(!allWallets.length){ wrap.innerHTML='<div class="empty"><i class="fas fa-wallet"></i><p>هیچ واڵێتێک زیاد نەکراوە</p></div>'; return; }
  wrap.innerHTML = allWallets.map(w=>{
    const avatarInner = w.key==='AccountBalance'?'<i class="fas fa-wallet"></i>':w.image_url ? `<img src="${esc(w.image_url)}" alt="">` : `<i class="fas fa-wallet"></i>`;
    const avatarBg = w.image_url ? '' : `background:${esc(w.color||'#1c2333')}`;
    return `<div class="wallet-card ${w.is_locked?'locked':''}">
      <div class="wallet-card-top">
        <div class="wallet-avatar" style="${avatarBg}">${avatarInner}</div>
        <div class="wallet-card-info">
          <div class="wallet-card-name">${esc(w.name)}</div>
          <div class="wallet-card-key">${esc(w.key)}</div>
        </div>
      </div>
      <div class="wallet-card-num">${esc(w.wallet_number||'—')}</div>
      <div class="wallet-card-meta">
        ${w.badge&&w.badge!=='none'?'<span class="wallet-card-badge">'+esc(({popular:'باو',most_popular:'باوترین',new:'نوێ'})[w.badge])+'</span>':''}
        ${w.allow_from!==false?'<span class="wallet-card-badge"><i class="fas fa-arrow-up"></i> ناردن چالاکە</span>':''}
        ${w.allow_receive?'<span class="wallet-card-badge gr"><i class="fas fa-arrow-down"></i> وەرگرتن چالاکە</span>':''}
        ${w.price!=null?`<span class="wallet-card-badge">نرخ: ${esc(w.price)}</span>`:''}
        ${w.fee!=null?`<span class="wallet-card-badge">کرێ: ${esc(w.fee)}${w.fee_type==='percent'?'%':' د.ع'}</span>`:''}
      </div>
      <button type="button" class="act-btn cy" onclick="openWalletRoutes('${w.id}')"><i class="fas fa-percent"></i> حمولە و ڕێگاکان</button>
      <div class="act-grp">
        <button type="button" class="act-btn cy" onclick="openWalletBadge('${w.id}')"><i class="fas fa-tag"></i> نیشانی جزدان</button>
        <div class="act-btn dark" onclick='openWalletModal(${safeAttr(w)})'><i class="fas fa-pen"></i> دەستکاری</div>
        <div class="act-btn rd" onclick="deleteWallet('${w.id}','${esc(w.key)}')"><i class="fas fa-trash"></i></div>
      </div>
      <div class="wallet-lock-row">
        <span><i class="fas ${w.is_locked?'fa-lock':'fa-lock-open'}" style="color:${w.is_locked?'var(--rd)':'var(--gr)'}"></i> ${w.is_locked?'قوفڵکراوە':'کراوەیە'}</span>
        <label class="mswitch"><input type="checkbox" ${w.is_locked?'checked':''} onchange="toggleWalletLock('${w.id}',this.checked)"><span class="track"></span></label>
      </div>
    </div>`;
  }).join('');
}
async function toggleWalletLock(id, locked){
  const {error} = await sb.from('ex_wallets').update({is_locked:locked}).eq('id',id);
  if(error){ await handleDbWriteError(error); loadWalletsAdmin(); return; }
  showToast(locked?'واڵێت قوفڵکرا':'واڵێت کرایەوە','gr');
  const w=allWallets.find(x=>x.id===id); if(w) w.is_locked=locked;
  renderWalletsGrid();
}
function deleteWallet(id, key){
  confirm2('سڕینەوەی واڵێت','ئایا دڵنیایت لە سڕینەوەی ئەم واڵێتە؟ هەموو ڕێگا و حمولەکانیشی دەسڕێنەوە. ئۆردەرە کۆنەکان کاریگەر نابن.','fas fa-trash','var(--rd)', async()=>{
    const {error} = await sb.from('ex_wallets').delete().eq('id',id);
    if(error){ await handleDbWriteError(error); return; }
    if(key){ await sb.from('ex_rates').delete().or(`from_method.eq.${key},to_method.eq.${key}`); }
    showToast('واڵێتەکە سڕایەوە','gr');
    loadWalletsAdmin();
  });
}
function autoFillWalletKey(){
  const keyInp=document.getElementById('walletKey');
  if(keyInp.dataset.touched==='1') return; // don't overwrite once the admin edited it manually
  const name=document.getElementById('walletName').value.trim();
  keyInp.value = name.replace(/[^a-zA-Z0-9]+/g,'');
}
function onWalletImgFile(input){
  const file=input.files[0]; if(!file) return;
  if(file.size > 900*1024){ showToast('وێنەکە زۆر گەورەیە (زۆرترین 900KB)','rd'); input.value=''; return; }
  const reader=new FileReader();
  reader.onload=()=>{
    document.getElementById('walletImageUrl').value = reader.result;
    document.getElementById('walletImgPreview').innerHTML = `<img src="${reader.result}" style="width:100%;height:100%;object-fit:cover">`;
  };
  reader.readAsDataURL(file);
}
function openWalletBadge(id){
  const w=allWallets.find(w=>w.id===id);if(!w)return;
  openWalletModal(w);
  const select=document.getElementById('walletBadge');
  select.scrollIntoView({block:'center'});select.focus();
}
function openWalletModal(w){
  document.getElementById('walletBadge').value=w?(w.badge||'none'):'new';
  document.getElementById('walletKey').readOnly=w?.key==='AccountBalance';
  document.getElementById('walletCanReceive').disabled=w?.key==='AccountBalance';
  document.getElementById('walletKey').dataset.touched='0';
  _walletOldKey = w ? (w.key||'') : '';
  if(w){
    document.getElementById('walletModalTitle').textContent='دەستکاریکردنی واڵێت';
    document.getElementById('walletId').value=w.id;
    document.getElementById('walletName').value=w.name||'';
    document.getElementById('walletKey').value=w.key||'';
    document.getElementById('walletKey').dataset.touched='1';
    document.getElementById('walletNumber').value=w.wallet_number||'';
    document.getElementById('walletImageUrl').value=w.image_url||'';
    document.getElementById('walletImgPreview').innerHTML = w.image_url ? `<img src="${esc(w.image_url)}" style="width:100%;height:100%;object-fit:cover">` : '<i class="fas fa-image"></i>';
    document.getElementById('walletPrice').value=w.price??'';
    document.getElementById('walletFee').value=w.fee??'';
    document.getElementById('walletFeeType').value=w.fee_type||'percent';
    document.getElementById('walletCanSend').checked=w.allow_from!==false;
    document.getElementById('walletCanReceive').checked=!!w.allow_receive;
    document.getElementById('walletLocked').checked=!!w.is_locked;
    document.getElementById('walletRecipientFormat').value=w.recipient_format==='card'?'card':'phone';
    document.getElementById('walletSenderPhone').checked=w.sender_phone_required===true;
  }else{
    document.getElementById('walletModalTitle').textContent='زیادکردنی واڵێتی نوێ';
    document.getElementById('walletId').value='';
    document.getElementById('walletName').value='';
    document.getElementById('walletKey').value='';
    document.getElementById('walletNumber').value='';
    document.getElementById('walletImageUrl').value='';
    document.getElementById('walletImgPreview').innerHTML='<i class="fas fa-image"></i>';
    document.getElementById('walletPrice').value='';
    document.getElementById('walletFee').value='';
    document.getElementById('walletFeeType').value='percent';
    document.getElementById('walletCanSend').checked=true;
    document.getElementById('walletCanReceive').checked=false;
    document.getElementById('walletLocked').checked=false;
    document.getElementById('walletRecipientFormat').value='phone';
    document.getElementById('walletSenderPhone').checked=false;
  }
  document.getElementById('walletImgFile').value='';
  document.getElementById('pairBulkValue').value='';
  buildPairDraft(w);
  switchWalletSection('info');
  openMo('moWallet');
}
async function saveWallet(){
  const id=document.getElementById('walletId').value;
  const name=document.getElementById('walletName').value.trim();
  const key=document.getElementById('walletKey').value.trim();
  const wallet_number=document.getElementById('walletNumber').value.trim();
  const image_url=document.getElementById('walletImageUrl').value.trim()||null;
  const priceRaw=document.getElementById('walletPrice').value;
  const feeRaw=document.getElementById('walletFee').value;
  const price = priceRaw===''?null:parseFloat(priceRaw);
  const fee = feeRaw===''?null:parseFloat(feeRaw);
  const fee_type=document.getElementById('walletFeeType').value;
  const allow_from=document.getElementById('walletCanSend').checked;
  const allow_receive=key==='AccountBalance'?false:document.getElementById('walletCanReceive').checked;
  const is_locked=document.getElementById('walletLocked').checked;
  if(!name){ showToast('ناوی واڵێت بنووسە','rd'); return; }
  if(!key){ showToast('کلیلی واڵێت بنووسە','rd'); return; }
  if(!allow_from && !allow_receive){ showToast('پێویستە لانیکەم یەکێک لە «ناردن» یان «وەرگرتن» چالاک بێت','rd'); return; }
  const btn=document.getElementById('walletSaveBtn');if(btn.disabled)return;btn.disabled=true;
  const previousLabel=btn.innerHTML;btn.textContent='پاشەکەوت دەکرێت…';
  const errorBox=document.getElementById('walletSaveError');errorBox.textContent='';
  const badge=document.getElementById('walletBadge').value;
  const recipient_format=document.getElementById('walletRecipientFormat').value==='card'?'card':'phone';
  const sender_phone_required=document.getElementById('walletSenderPhone').checked;
  const payload={name,key,wallet_number:wallet_number||null,image_url,price,fee,fee_type,allow_from,allow_receive,is_locked,badge,recipient_format,sender_phone_required};
  try{
    if((price!==null&&!Number.isFinite(price))||(fee!==null&&!Number.isFinite(fee)))throw new Error('نرخ و حمولەی دروست بنووسە');
    const routes=walletPairRows(key,id?_walletOldKey:'');
    const {data:saved,error}=await sb.rpc('ex_staff_save_wallet',{p_wallet_id:id||null,p_wallet:payload,p_routes:routes});
    if(error)throw error;
    if(!saved?.id)throw new Error('نەتوانرا پاشەکەوتکردن پشتڕاست بکرێتەوە');
    allWallets=allWallets.filter(w=>w.id!==saved.id);allWallets.push(saved);if(typeof syncMethodMeta==='function')syncMethodMeta(allWallets);
    renderWalletsGrid();closeMo('moWallet');showToast('جزدان و ڕێگاکان پاشەکەوتکران','gr');
    loadWalletsAdmin(true);
  }catch(e){errorBox.textContent=adminDbMessage(e);await handleDbWriteError(e);}
  finally{btn.disabled=false;btn.innerHTML=previousLabel;}

}

// ══════════════════════════════════════════════════════════════
// ═══ PER-PAIR ROUTES & FEES ══════════════════════════════════════
// Every wallet-to-wallet direction is one ex_rates row: is_active is the
// open/closed switch, rate_type + rate_value is that direction's fee.
// A→B and B→A are separate rows, so they open, close and price independently.
// ══════════════════════════════════════════════════════════════
let allPairs=[];                       // every ex_rates row, active and inactive
let _pairDraft={out:{},in:{}};         // unsaved state of the matrix in the modal
let _pairTab='out';
let _pairSelfKey='';
let _walletOldKey='';
const PAIR_TYPES=[['fee_percent','حمولە بە ڕێژە (%)'],['fee_fixed','حمولەی جێگیر (د.ع)'],['multiplier','مەزراپ (×)']];
// 0.85 → "15" (no trailing zeros)
function fmtPct(n){ return String(Math.round(n*100)/100); }
// A multiplier under 1 is a straight cut off the amount, so it's shown to both
// admin and user as a rate — "کرێ 15%" — rather than a raw ×0.85.
function fmtPairValue(t,v){
  const n=Number(v);
  if(t==='fee_percent') return v+'%';
  if(t==='fee_fixed') return v+' د.ع';
  return n<1 ? 'کرێ '+fmtPct(100-n*100)+'%' : '×'+v;
}
// Amount brackets of a stored route as [{up_to,percent}] (last one has up_to:null), or null.
// Old two-step tiers are read as two brackets so every route is handled the same way.
function pairBracketsOfRow(r){
  if(!r)return null;
  if(Array.isArray(r.fee_brackets)&&r.fee_brackets.length>=2)
    return r.fee_brackets.map(b=>({up_to:b.up_to==null?null:Number(b.up_to),percent:Number(b.percent)}));
  if(r.fee_tier_enabled&&r.fee_tier_low_percent!=null&&r.fee_tier_high_percent!=null)
    return [{up_to:Number(r.fee_tier_limit_iqd),percent:Number(r.fee_tier_low_percent)},{up_to:null,percent:Number(r.fee_tier_high_percent)}];
  return null;
}
function pairTierOf(r){ const b=pairBracketsOfRow(r); return b?{brackets:b}:null; }
function pairTierText(t){
  const b=t.brackets;
  return b.map((x,i)=>i<b.length-1?('تا '+Number(x.up_to).toLocaleString('en-US')+' د.ع: '+fmtPct(x.percent)+'%'):('لە سەروو: '+fmtPct(x.percent)+'%')).join(' · ');
}
function fmtPairRow(r){
  const t=pairTierOf(r);
  return t ? t.brackets.map(x=>fmtPct(x.percent)+'%').join(' → ') : fmtPairValue(r.rate_type,r.rate_value);
}
function walletLabelFor(key){
  const w=allWallets.find(x=>x.key===key);
  return w ? (w.name||key) : walletName(key);
}
async function loadPairs(){
  try{
    const {data,error} = await sb.from('ex_rates').select('*');
    allPairs = (!error && data) ? data : [];
  }catch(e){ allPairs=[]; }
}
function walletPairsHTML(w){
  const outs=allPairs.filter(r=>r.from_method===w.key && r.is_active);
  const ins =allPairs.filter(r=>r.to_method===w.key && r.is_active);
  const chips=(arr,pick)=> arr.length
    ? arr.map(r=>{const t=pairTierOf(r);return `<span class="pair-chip${t?' tier':''}"${t?` title="${esc(pairTierText(t))}"`:''}>${esc(walletLabelFor(pick(r)))} · <b>${esc(fmtPairRow(r))}</b>${t?' <i class="fas fa-layer-group"></i>':''}</span>`;}).join('')
    : '<span class="pair-chip mut">هیچ ڕێگایەک کراوە نییە</span>';
  return `<div class="wallet-pairs">
    <div class="wallet-pairs-row"><span class="wallet-pairs-lbl"><i class="fas fa-arrow-left"></i> ناردن بۆ</span>${chips(outs,r=>r.to_method)}</div>
    <div class="wallet-pairs-row"><span class="wallet-pairs-lbl"><i class="fas fa-arrow-right"></i> وەرگرتن لە</span>${chips(ins,r=>r.from_method)}</div>
  </div>`;
}
function pairOtherWallets(){
  const selfId=document.getElementById('walletId').value;
  return allWallets.filter(x=> selfId ? x.id!==selfId : (_pairSelfKey ? x.key!==_pairSelfKey : true));
}
function buildPairDraft(w){
  _pairSelfKey = w ? (w.key||'') : '';
  _pairDraft={out:{},in:{}};
  _pairBulk={rows:pairBlankRows()};
  allWallets.forEach(o=>{
    if(w && o.id===w.id) return;
    const ro = allPairs.find(r=>r.from_method===_pairSelfKey && r.to_method===o.key);
    const ri = allPairs.find(r=>r.from_method===o.key && r.to_method===_pairSelfKey);
    _pairDraft.out[o.key] = ro ? {on:!!ro.is_active, type:ro.rate_type, value:String(ro.rate_value), tier:pairTierDraft(ro)} : {on:false,type:'fee_percent',value:'',tier:pairTierDraft(null)};
    _pairDraft.in[o.key]  = ri ? {on:!!ri.is_active, type:ri.rate_type, value:String(ri.rate_value), tier:pairTierDraft(ri)} : {on:false,type:'fee_percent',value:'',tier:pairTierDraft(null)};
  });
  switchPairTab('out');
}
// Draft of the amount brackets of one route: rows are [{upTo,percent}], the last row is "everything above".
// No suggested numbers: a route without brackets starts with two empty rows.
function pairBlankRows(){ return [{upTo:'',percent:''},{upTo:'',percent:''}]; }
function pairTierDraft(r){
  const b=pairBracketsOfRow(r);
  if(!b)return {on:false,rows:pairBlankRows()};
  return {on:true,rows:b.map((x,i)=>({upTo:i<b.length-1?String(x.up_to):'',percent:String(x.percent)}))};
}
let _pairBulk={rows:pairBlankRows()};
function pairSelfKeyNow(){ return (document.getElementById('walletKey')?.value||_pairSelfKey||'').trim(); }
// Brackets only make sense for a % fee or a multiplier up to 1, never towards USDT and never from USDT / the account balance.
function pairTierAllowed(f,t,st){
  if(f==='USDT'||f==='AccountBalance'||t==='USDT')return false;
  if(st.type==='fee_percent')return true;
  const v=Number(st.value);
  return st.type==='multiplier'&&String(st.value).trim()!==''&&Number.isFinite(v)&&v>=0&&v<=1;
}
function pairEnds(key){ const self=pairSelfKeyNow(); return _pairTab==='out'?[self,key]:[key,self]; }
function pairRowsRef(ctx){
  if(ctx==='__bulk')return _pairBulk;
  const st=_pairDraft[_pairTab][ctx];if(!st)return null;
  return st.tier||(st.tier=pairTierDraft(null));
}
// Validates the rows and returns [{up_to,percent}] for the database; throws a Kurdish message otherwise.
function pairBracketsFromRows(rows,label){
  if(!Array.isArray(rows)||rows.length<2)throw new Error(label+': لانیکەم دوو بڕ پێویستە');
  const out=[];let prev=0;
  rows.forEach((r,i)=>{
    const last=i===rows.length-1;
    const pct=Number(r.percent);
    if(String(r.percent).trim()===''||!Number.isFinite(pct)||pct<0||pct>100)throw new Error(label+': ڕێژەی حمولەی بڕی '+(i+1)+' دەبێت 0 تا 100 بێت');
    if(last){out.push({up_to:null,percent:pct});return;}
    const up=Number(r.upTo);
    if(String(r.upTo).trim()===''||!Number.isInteger(up)||up<1000||up>1000000000)throw new Error(label+': سنووری بڕی '+(i+1)+' دەبێت ژمارەیەکی تەواو لە 1,000 تا 1,000,000,000 بێت');
    if(up<=prev)throw new Error(label+': سنوورەکان دەبێت لە بچووکەوە بۆ گەورە بن (بڕی '+(i+1)+')');
    prev=up;out.push({up_to:up,percent:pct});
  });
  return out;
}
function pairTierSummary(rows){
  try{return pairTierText({brackets:pairBracketsFromRows(rows,'')});}
  catch(e){return 'هەموو خانەکان پڕ بکەرەوە (سنوورەکان لە بچووکەوە بۆ گەورە)';}
}
function pairRowsHTML(ctx,tr){
  const k=esc(ctx),n=tr.rows.length;
  const rows=tr.rows.map((r,i)=>{
    const last=i===n-1;
    const lim=last
      ?`<span class="pair-br-lbl">لە سەروو ئەو بڕەی پێشوو</span>`
      :`<label class="pair-br-lim"><small>تا بڕی (IQD)</small><input class="minp" type="number" dir="ltr" inputmode="numeric" min="1000" step="1" placeholder="بڕی سنوور" value="${esc(r.upTo)}" oninput="setPairBracket('${k}',${i},'upTo',this.value)"></label>`;
    const del=n>2?`<button type="button" class="pair-br-del" title="لابردنی ئەم بڕە" onclick="removePairBracket('${k}',${i})"><i class="fas fa-xmark"></i></button>`:'<span class="pair-br-del ph"></span>';
    return `<div class="pair-br${last?' last':''}">${lim}<label class="pair-br-pct"><small>حمولە %</small><input class="minp" type="number" dir="ltr" inputmode="decimal" min="0" max="100" step="0.0001" placeholder="%" value="${esc(r.percent)}" oninput="setPairBracket('${k}',${i},'percent',this.value)"></label>${del}</div>`;
  }).join('');
  return `<div class="pair-brs">${rows}</div>
    <div class="pair-br-actions"><button type="button" class="act-btn dark" ${n>=10?'disabled':''} onclick="addPairBracket('${k}')"><i class="fas fa-plus"></i> زیادکردنی بڕێک</button>${ctx==='__bulk'?'':`<button type="button" class="act-btn" onclick="copyPairTierToAll('${k}')"><i class="fas fa-copy"></i> ئەمە بۆ هەموو ڕێگاکانی تر</button>`}</div>
    <small class="pair-tier-sum" id="pairTierSum-${k}">${esc(pairTierSummary(tr.rows))}</small>`;
}
function pairTierHTML(key,st){
  const [f,t]=pairEnds(key), tr=st.tier||(st.tier=pairTierDraft(null));
  const ok=pairTierAllowed(f,t,st);
  const k=esc(key);
  const head=`<label class="pair-tier-top"><span><i class="fas fa-layer-group"></i> حمولەی جیاواز بەپێی بڕ (چەند بڕێک)</span><span class="mswitch"><input type="checkbox" ${tr.on&&ok?'checked':''} ${ok?'':'disabled'} onchange="togglePairTier('${k}',this.checked)"><span class="track"></span></span></label>`;
  if(!ok)return `<div class="pair-tier off">${head}<small class="pair-tier-note">تەنها بۆ «حمولە بە ڕێژە (%)» یان مەزراپی 0 تا 1 کاردەکات (نەک بۆ USDT یان باڵانسی هەژمار).</small></div>`;
  if(!tr.on)return `<div class="pair-tier">${head}</div>`;
  return `<div class="pair-tier on">${head}${pairRowsHTML(key,tr)}</div>`;
}
function refreshPairTier(key){
  const st=_pairDraft[_pairTab][key],el=document.getElementById('pairTierWrap-'+key);
  if(st&&el)el.innerHTML=pairTierHTML(key,st);
}
function refreshPairBulkTier(){
  const el=document.getElementById('pairTierBulkRows');if(el)el.innerHTML=pairRowsHTML('__bulk',_pairBulk);
}
function togglePairTier(key,on){
  const st=_pairDraft[_pairTab][key];if(!st)return;
  st.tier=st.tier||pairTierDraft(null);st.tier.on=!!on;
  refreshPairTier(key);
}
function setPairBracket(ctx,i,field,v){
  const tr=pairRowsRef(ctx);if(!tr||!tr.rows[i])return;
  tr.rows[i][field]=v;
  const el=document.getElementById('pairTierSum-'+ctx);if(el)el.textContent=pairTierSummary(tr.rows);
}
function addPairBracket(ctx){
  const tr=pairRowsRef(ctx);if(!tr||tr.rows.length>=10)return;
  tr.rows.splice(tr.rows.length-1,0,{upTo:'',percent:''});
  ctx==='__bulk'?refreshPairBulkTier():refreshPairTier(ctx);
}
function removePairBracket(ctx,i){
  const tr=pairRowsRef(ctx);if(!tr||tr.rows.length<=2)return;
  tr.rows.splice(i,1);
  ctx==='__bulk'?refreshPairBulkTier():refreshPairTier(ctx);
}
function copyPairTierToAll(key){
  const src=pairRowsRef(key);if(!src)return;
  let rows;try{rows=pairBracketsFromRows(src.rows,'بڕەکان');}catch(e){showToast(e.message,'rd');return;}
  let n=0;
  Object.keys(_pairDraft[_pairTab]).forEach(k=>{
    const st=_pairDraft[_pairTab][k],[f,t]=pairEnds(k);
    if(k!==key&&st.on&&pairTierAllowed(f,t,st)){ st.tier={on:true,rows:rows.map((x,i)=>({upTo:i<rows.length-1?String(x.up_to):'',percent:String(x.percent)}))}; n++; }
  });
  renderPairList();
  showToast(n?('بڕەکان بۆ '+n+' ڕێگای تر دانرا — دواتر واڵێتەکە هەڵبگرە'):'هیچ ڕێگایەکی تری کراوە و گونجاو نییە',n?'gr':'rd');
}
function applyPairTierBulk(){
  let rows;
  try{rows=pairBracketsFromRows(_pairBulk.rows,'بڕەکان');}catch(e){showToast(e.message,'rd');return;}
  let n=0,skipped=0;
  Object.keys(_pairDraft[_pairTab]).forEach(k=>{
    const st=_pairDraft[_pairTab][k],[f,t]=pairEnds(k);
    if(st.on&&pairTierAllowed(f,t,st)){ st.tier={on:true,rows:rows.map((x,i)=>({upTo:i<rows.length-1?String(x.up_to):'',percent:String(x.percent)}))}; n++; }
    else if(st.on)skipped++;
  });
  if(!n){ showToast('هیچ ڕێگایەکی کراوە و گونجاو نییە (دەبێت حمولە بە % بێت)','rd'); return; }
  renderPairList();
  showToast('بڕەکان بۆ '+n+' ڕێگا دانران'+(skipped?' و '+skipped+' ڕێگای نەگونجاو بێ گۆڕان مایەوە':'')+' — دواتر واڵێتەکە هەڵبگرە','gr');
}
function clearPairTierBulk(){
  let n=0;
  Object.values(_pairDraft[_pairTab]).forEach(st=>{ if(st.tier&&st.tier.on){ st.tier.on=false; n++; } });
  renderPairList(); showToast(n?('بڕەکان لە '+n+' ڕێگا لابران'):'هیچ ڕێگایەک بڕی چالاکی نەبوو',n?'gr':'rd');
}
function switchPairTab(tab){
  _pairTab=tab;
  document.querySelectorAll('[data-ptab]').forEach(t=>t.classList.toggle('on', t.dataset.ptab===tab));
  renderPairList();
}
function renderPairCounts(){
  const cnt=d=>Object.values(_pairDraft[d]).filter(s=>s.on).length;
  document.getElementById('pairCntOut').textContent=cnt('out');
  document.getElementById('pairCntIn').textContent=cnt('in');
}
function renderPairList(){
  const wrap=document.getElementById('pairListWrap');
  renderPairCounts();
  refreshPairBulkTier();
  const others=pairOtherWallets();
  if(!others.length){
    wrap.innerHTML='<div class="pair-empty">هێشتا واڵێتێکی تر نییە.<br>دوای زیادکردنی واڵێتی دووەم، ڕێگا و حمولەکان لێرە دەردەکەون.</div>';
    return;
  }
  const outMode=_pairTab==='out';
  const canSend=document.getElementById('walletCanSend').checked;
  const canRecv=document.getElementById('walletCanReceive').checked;
  let note='';
  if(outMode && !canSend) note='<div class="pair-note"><i class="fas fa-triangle-exclamation"></i> «ناردن» بۆ ئەم واڵێتە ناچالاکە، بۆیە ئەم ڕێگایانە کار ناکەن تا چالاکی نەکەیت.</div>';
  if(!outMode && !canRecv) note='<div class="pair-note"><i class="fas fa-triangle-exclamation"></i> «وەرگرتن» بۆ ئەم واڵێتە ناچالاکە، بۆیە ئەم ڕێگایانە کار ناکەن تا چالاکی نەکەیت.</div>';
  wrap.innerHTML = note + others.map(o=>{
    const st=_pairDraft[_pairTab][o.key] || (_pairDraft[_pairTab][o.key]={on:false,type:'fee_percent',value:''});
    const av = o.image_url ? `<img src="${esc(o.image_url)}" alt="">` : '<i class="fas fa-wallet"></i>';
    const bg = o.image_url ? '' : `background:${esc(o.color||'#1c2333')}`;
    const dead = outMode ? (o.allow_receive!==true) : (o.allow_from===false);
    const deadTxt = outMode ? 'ئەم واڵێتە وەرگرتنی ناچالاکە' : 'ئەم واڵێتە ناردنی ناچالاکە';
    const dir = outMode ? `لەم واڵێتەوە ← ${esc(o.name||o.key)}` : `${esc(o.name||o.key)} ← بۆ ئەم واڵێتە`;
    return `<div class="pair-item ${st.on?'on':''}">
      <div class="pair-item-top">
        <div class="pair-av" style="${bg}">${av}</div>
        <div class="pair-nm">
          <b>${esc(o.name||o.key)}</b>
          <small class="${dead?'warn':''}">${dir}${dead?' — '+deadTxt:''}</small>
        </div>
        <span class="pair-state ${st.on?'op':'cl'}">${st.on?'کراوە':'داخراوە'}</span>
        <label class="mswitch"><input type="checkbox" ${st.on?'checked':''} onchange="togglePair('${esc(o.key)}',this.checked)"><span class="track"></span></label>
      </div>
      ${st.on?`<div class="pair-ctl">
        <select class="msel" onchange="setPairType('${esc(o.key)}',this.value)">${PAIR_TYPES.map(t=>`<option value="${t[0]}" ${st.type===t[0]?'selected':''}>${t[1]}</option>`).join('')}</select>
        <input class="minp" type="number" step="0.0001" dir="ltr" placeholder="بەهای حمولە" value="${esc(st.value)}" oninput="setPairValue('${esc(o.key)}',this.value)">
      </div><small class="pair-hint" id="pairHint-${esc(o.key)}" style="display:block;font-size:10.5px;color:var(--mt);margin-top:5px">${pairHintText(st)}</small>
      <div class="pair-tier-wrap" id="pairTierWrap-${esc(o.key)}">${pairTierHTML(o.key,st)}</div>`:''}
    </div>`;
  }).join('');
}
function pairHintText(st){
  if(st.type==='multiplier' && st.value!=='' && !isNaN(Number(st.value)) && Number(st.value)<1)
    return 'یەکسانە بە کرێی '+fmtPct(100-Number(st.value)*100)+'% — بەکارهێنەر بەم شێوەیە دەیبینێت';
  return '';
}
function togglePair(key,on){
  const st=_pairDraft[_pairTab][key] || (_pairDraft[_pairTab][key]={type:'fee_percent',value:''});
  st.on=on;
  renderPairList();
}
function setPairType(key,t){ if(_pairDraft[_pairTab][key]){ _pairDraft[_pairTab][key].type=t; refreshPairHint(key); refreshPairTier(key); } }
function setPairValue(key,v){ if(_pairDraft[_pairTab][key]){ _pairDraft[_pairTab][key].value=v; refreshPairHint(key); } renderPairCounts(); }
function refreshPairHint(key){
  const el=document.getElementById('pairHint-'+key);
  if(el) el.textContent = pairHintText(_pairDraft[_pairTab][key]);
}
function applyPairBulk(){
  const t=document.getElementById('pairBulkType').value;
  const v=document.getElementById('pairBulkValue').value;
  if(v===''){ showToast('سەرەتا بەهای حمولە بنووسە','rd'); return; }
  const keys=Object.keys(_pairDraft[_pairTab]);
  if(!keys.length){ showToast('واڵێتی تر نییە','rd'); return; }
  keys.forEach(k=>{ const old=_pairDraft[_pairTab][k]||{}; _pairDraft[_pairTab][k]={on:true,type:t,value:v,tier:old.tier||pairTierDraft(null)}; });
  renderPairList();
  showToast('بۆ هەموو واڵێتەکانی ئەم ئاراستەیە دانرا','gr');
}
// Writes the matrix back to ex_rates. Closed directions keep their row with
// is_active=false so the fee is still there when they're re-opened later.
function walletPairRows(newKey,oldKey){
  const known=allPairs.map(r=>({...r,
    from_method:oldKey&&r.from_method===oldKey?newKey:r.from_method,
    to_method:oldKey&&r.to_method===oldKey?newKey:r.to_method}));
  const rows=[];
  const push=(f,t,st)=>{
    if(!f||!t||f===t)return;
    const prev=known.find(r=>r.from_method===f&&r.to_method===t);
    if(st.on){
      const value=Number(st.value);
      if(String(st.value).trim()===''||!Number.isFinite(value)||value<0)throw new Error('بەهای حمولەی ڕێگای '+f+' ← '+t+' دروست بنووسە');
      const tr=st.tier||pairTierDraft(null);
      const tierOn=!!tr.on&&pairTierAllowed(f,t,st);
      const label='ڕێگای '+f+' ← '+t;
      const brackets=tierOn?pairBracketsFromRows(tr.rows,label):null;
      const prevBr=pairBracketsOfRow(prev);
      const tierChanged=JSON.stringify(brackets)!==JSON.stringify(prevBr);
      if(!prev||prev.is_active!==true||prev.rate_type!==st.type||Number(prev.rate_value)!==value||tierChanged){
        const row={from_method:f,to_method:t,rate_type:st.type,rate_value:value,is_active:true};
        // brackets replace the old two-step tier completely; a route without brackets keeps its plain rate
        if(tierChanged||brackets){row.fee_brackets=brackets;row.fee_tier_enabled=false;}
        rows.push(row);
      }
    }else if(prev&&prev.is_active!==false)rows.push({from_method:f,to_method:t,rate_type:prev.rate_type,rate_value:prev.rate_value,is_active:false});
  };
  Object.keys(_pairDraft.out).forEach(k=>push(newKey,k,_pairDraft.out[k]));
  Object.keys(_pairDraft.in).forEach(k=>push(k,newKey,_pairDraft.in[k]));
  return rows;
}

// ── Original admin module 5 ──
// ══════════════════════════════════════════════════════════════
// ═══ NOTIFICATIONS ═══════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
async function loadNotifPage(){
  loadNotifLog();
  loadBroadcasts();
}
function setNotifTarget(el){
  document.querySelectorAll('[data-nt]').forEach(x=>x.classList.remove('on'));
  el.classList.add('on');
  _notifTarget = el.dataset.nt;
  document.getElementById('notifUserPickWrap').style.display = _notifTarget==='one' ? 'block' : 'none';
  // "keep for future users" only makes sense for a broadcast
  const show = _notifTarget==='all' ? '' : 'none';
  document.getElementById('notifKeepRow').style.display = show;
  document.getElementById('notifKeepNote').style.display = show;
}
let _notifSearchTimer=null;
function searchNotifUser(){
  clearTimeout(_notifSearchTimer);
  const q=document.getElementById('notifUserSearch').value.trim();
  if(!q){ document.getElementById('notifUserResults').innerHTML=''; return; }
  _notifSearchTimer=setTimeout(async()=>{
    const cleanQ=q.replace(/[,()*]/g,' ').trim();
    const handle=cleanQ.replace(/^@/,'');
    const {data} = await sb.from('ex_profiles').select('id,full_name,email,username').or(`full_name.ilike.%${cleanQ}%,email.ilike.%${cleanQ}%,username.ilike.%${handle}%`).limit(6);
    const box=document.getElementById('notifUserResults');
    if(!data || !data.length){ box.innerHTML='<div style="font-size:12px;color:var(--mt);padding:6px 2px">هیچ نەدۆزرایەوە</div>'; return; }
    box.innerHTML = data.map(u=>`<div onclick='pickNotifUser(${safeAttr(u)})' style="cursor:pointer;display:flex;align-items:center;gap:10px;padding:8px 10px;border:1px solid var(--b1);border-radius:10px">
      <div class="mini-av" style="width:28px;height:28px;font-size:11px">${(u.full_name||u.email||'?')[0].toUpperCase()}</div>
      <div style="min-width:0"><div style="font-size:12.5px;font-weight:700;color:var(--dark);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(u.full_name||'—')}</div><div style="font-size:10.5px;color:var(--mt);direction:ltr">${esc(u.email||'')}</div></div>
    </div>`).join('');
  }, 300);
}
function pickNotifUser(u){
  _notifSelectedUser=u;
  document.getElementById('notifUserResults').innerHTML='';
  document.getElementById('notifUserSearch').value='';
  const sel=document.getElementById('notifUserSelected');
  sel.style.display='flex';
  sel.innerHTML=`<div class="mini-av" style="width:28px;height:28px;font-size:11px">${(u.full_name||u.email||'?')[0].toUpperCase()}</div>
    <div style="flex:1;min-width:0"><div style="font-size:12.5px;font-weight:700;color:var(--dark)">${esc(u.full_name||'—')}</div><div style="font-size:10.5px;color:var(--mt);direction:ltr">${esc(u.email||'')}</div></div>
    <div style="cursor:pointer;color:var(--rd);font-size:13px" onclick="clearNotifUser()"><i class="fas fa-xmark"></i></div>`;
}
function clearNotifUser(){ _notifSelectedUser=null; document.getElementById('notifUserSelected').style.display='none'; }

async function sendAdminNotification(){
  const title=document.getElementById('notifTitle').value.trim();
  const body=document.getElementById('notifBody').value.trim();
  if(!title||!body){ showToast('ناونیشان و پەیام پڕ بکەرەوە','rd'); return; }
  if(_notifTarget==='one' && !_notifSelectedUser){ showToast('بەکارهێنەرێک هەڵبژێرە','rd'); return; }
  const btn=document.getElementById('notifSendBtn'); btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    let error;
    if(_notifTarget==='all'){
      const keep = document.getElementById('notifDeliverNew').checked;
      ({error} = await sb.rpc('ex_notify_all', {p_title:title, p_message:body, p_deliver_to_new:keep}));
    }else{
      ({error} = await sb.rpc('ex_notify_user', {p_user_id:_notifSelectedUser.id, p_title:title, p_message:body}));
    }
    if(error) throw error;
    showToast('✅ ئاگادارییەکە نێردرا','gr');
    document.getElementById('notifTitle').value='';
    document.getElementById('notifBody').value='';
    clearNotifUser();
    loadNotifLog();
    loadBroadcasts();
  }catch(e){
    showToast('هەڵە: '+e.message,'rd');
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-paper-plane"></i> ناردن';
  }
}
async function loadNotifLog(){
  const wrap=document.getElementById('notifLogWrap');
  wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const {data,error} = await sb.from('ex_notifications').select('*').order('created_at',{ascending:false}).limit(100);
    if(error) throw error;
    const profMap = await loadProfilesFor((data||[]).map(n=>n.user_id));
    allNotifs = (data||[]).map(n=>({...n, profile:profMap[n.user_id]||null}));
    renderNotifLog();
  }catch(e){
    wrap.innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
  }
}
function renderNotifLog(){
  if(!allNotifs.length){ document.getElementById('notifLogWrap').innerHTML='<div class="empty"><i class="fas fa-bell-slash"></i><p>هیچ ئاگادارییەک نەنێردراوە</p></div>'; return; }
  document.getElementById('notifLogWrap').innerHTML = `<table><thead><tr><th>بەکارهێنەر</th><th>جۆر</th><th>ناونیشان</th><th>پەیام</th><th>خوێندراوە</th><th>بەروار</th></tr></thead><tbody>
    ${allNotifs.map(n=>`<tr>
      <td><div class="user-cell"><div class="mini-av">${(n.profile?.full_name||n.profile?.email||'?')[0].toUpperCase()}</div><div><div class="user-cell-name">${esc(n.profile?.full_name||'—')}</div><div class="user-cell-email">${esc(n.profile?.email||'—')}</div></div></div></td>
      <td><span class="badge ${n.type==='order_approved'?'approved':n.type==='order_rejected'?'rejected':n.type==='order_status'?'order_status':'adminmsg'}">${n.type==='order_approved'?'پەسەندکرا':n.type==='order_rejected'?'ڕەتکرایەوە':n.type==='order_status'?'دۆخی ئۆردەر':'ئادمین'}</span>${n.broadcast_id?' <span class="badge admin">گشتی</span>':''}</td>
      <td style="font-size:12.5px;font-weight:700">${esc(n.title)}</td>
      <td style="font-size:12px;color:var(--mt2);max-width:260px">${esc(n.message)}</td>
      <td>${n.is_read?'<i class="fas fa-check-double" style="color:var(--gr)"></i>':'<i class="fas fa-circle" style="color:var(--yw);font-size:8px"></i>'}</td>
      <td style="font-size:11px;color:var(--mt)">${new Date(n.created_at).toLocaleString('ku')}</td>
    </tr>`).join('')}
  </tbody></table>`;
}

// ══════════════════════════════════════════════════════════════
// ═══ STORED BROADCASTS ═══════════════════════════════════════════
// A broadcast is kept as a template in ex_broadcasts. Existing users
// get their copy the moment it's sent; anyone who signs up later gets
// it automatically from the trg_ex_profiles_broadcasts trigger — so a
// message sent yesterday still reaches a user who registers today.
// ══════════════════════════════════════════════════════════════
let allBroadcasts=[];
async function loadBroadcasts(){
  const wrap=document.getElementById('broadcastWrap');
  wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const {data,error} = await sb.rpc('ex_admin_list_broadcasts');
    if(error) throw error;
    allBroadcasts = data||[];
    renderBroadcasts();
  }catch(e){
    wrap.innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
  }
}
function renderBroadcasts(){
  const wrap=document.getElementById('broadcastWrap');
  if(!allBroadcasts.length){
    wrap.innerHTML='<div class="empty"><i class="fas fa-bullhorn"></i><p>هیچ ئاگادارییەکی گشتی خەزن نەکراوە</p></div>';
    return;
  }
  wrap.innerHTML = `<table><thead><tr><th>ناونیشان</th><th>پەیام</th><th>نێردراو</th><th>خوێندراوە</th><th>چاوەڕوان</th><th>بۆ نوێکان</th><th>بەروار</th><th>کردار</th></tr></thead><tbody>
    ${allBroadcasts.map(b=>`<tr>
      <td style="font-size:12.5px;font-weight:700">${esc(b.title)}</td>
      <td style="font-size:12px;color:var(--mt2);max-width:240px">${esc(b.message)}</td>
      <td style="font-size:12px">${b.delivered_count}</td>
      <td style="font-size:12px">${b.read_count}</td>
      <td>${b.pending_count>0?`<span class="badge banned">${b.pending_count}</span>`:'<span class="badge active">0</span>'}</td>
      <td><label class="mswitch"><input type="checkbox" ${b.deliver_to_new?'checked':''} onchange="toggleBroadcastNew('${b.id}',this.checked)"><span class="track"></span></label></td>
      <td style="font-size:11px;color:var(--mt)">${new Date(b.created_at).toLocaleString('ku')}</td>
      <td><div class="act-grp">
        <div class="act-btn cy" ${b.pending_count>0?'':'style="opacity:.4;pointer-events:none"'} onclick="syncBroadcast('${b.id}')"><i class="fas fa-paper-plane"></i> ناردن بۆ چاوەڕوانەکان</div>
        <div class="act-btn rd" onclick="deleteBroadcast('${b.id}')"><i class="fas fa-trash"></i> سڕینەوە</div>
      </div></td>
    </tr>`).join('')}
  </tbody></table>`;
}
async function toggleBroadcastNew(id, on){
  const {error} = await sb.rpc('ex_admin_set_broadcast_new',{p_id:id, p_deliver:on});
  if(error){ showToast('هەڵە: '+error.message,'rd'); loadBroadcasts(); return; }
  showToast(on?'بۆ بەکارهێنەرانی نوێ دەنێردرێت':'چیتر بۆ بەکارهێنەرانی نوێ نانێردرێت','gr');
  loadBroadcasts();
}
function syncBroadcast(id){
  confirm2('ناردن بۆ چاوەڕوانەکان','ئەم ئاگادارییە دەنێردرێت بۆ هەموو ئەو بەکارهێنەرانەی هێشتا وەریان نەگرتووە. ئایا دڵنیایت؟',
    'fas fa-paper-plane','var(--cy)', async()=>{
    const {data,error} = await sb.rpc('ex_admin_sync_broadcast',{p_id:id});
    if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
    showToast('نێردرا بۆ '+(data||0)+' بەکارهێنەر','gr');
    loadBroadcasts(); loadNotifLog();
  });
}
function deleteBroadcast(id){
  confirm2('سڕینەوەی ئاگاداری گشتی','ئەم ئاگادارییە لە لیستی هەموو بەکارهێنەرەکان دەسڕدرێتەوە و چیتر بۆ بەکارهێنەری نوێش نانێردرێت. ئایا دڵنیایت؟',
    'fas fa-trash','var(--rd)', async()=>{
    const {error} = await sb.rpc('ex_admin_delete_broadcast',{p_id:id, p_purge:true});
    if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
    showToast('سڕدرایەوە','gr');
    loadBroadcasts(); loadNotifLog();
  });
}

// The Firebase text banner page was replaced in v53 by «بانەرەکان» (exchange-banners-admin.js).

// ══════════════════════════════════════════════════════════════
// ═══ IDENTITY VERIFICATION (KYC) MANAGEMENT ═══════════════════
// Every read and write goes through ex_admin_kyc_* RPCs, which check
// the caller's role inside PostgreSQL. Document images are fetched with
// storage.download() (allowed only for admins by Storage RLS) and shown
// as in-memory blob URLs — no shareable link is ever created.
// ══════════════════════════════════════════════════════════════
const KYC_ADMIN_DOC = { national_id:'کارتی نیشتیمانی', driving_license:'مۆڵەتی شوفێری' };
const KYC_ADMIN_STATUS = {
  none:     { label:'پشتڕاست نەکراوەتەوە', cls:'kyc-none' },
  required: { label:'پشتڕاستکردنەوە پێویستە', cls:'pending' },
  pending:  { label:'لە ژێر پشکنینە', cls:'order_status' },
  approved: { label:'پشتڕاستکراوەتەوە ✓', cls:'approved' },
  rejected: { label:'ڕەتکراوەتەوە', cls:'rejected' }
};
const KYC_ADMIN_EVENTS = {
  requested:'ئادمین داوای پشتڕاستکردنەوەی کرد',
  request_cancelled:'داواکاری هەڵوەشێنرایەوە',
  submitted:'بەکارهێنەر بەڵگەنامەی نارد',
  resubmitted:'بەکارهێنەر دووبارە بەڵگەنامەی نارد',
  approved:'پەسەندکرا',
  rejected:'ڕەتکرایەوە',
  name_synced:'ناوی هەژمار بە ناوی ناسنامە نوێکرایەوە'
};
const KYC_ADMIN_ERRORS = {
  ADMIN_REQUIRED:'دەستگەیشتنی ئادمینت نییە',
  SUPER_ADMIN_REQUIRED:'تەنها سوپەر ئادمین دەتوانێت ئەم کارە بکات',
  ROLE_CHANGE_FORBIDDEN:'تەنها سوپەر ئادمین دەتوانێت ڕۆڵ بگۆڕێت',
  ROLE_SELF_CHANGE_FORBIDDEN:'ناتوانیت ڕۆڵی خۆت بگۆڕیت',
  LAST_SUPER_ADMIN:'دوایین سوپەر ئادمین ناتوانرێت لاببرێت',
  ADMIN_BAN_FORBIDDEN:'تەنها سوپەر ئادمین دەتوانێت ئادمینێک بۆیکۆت بکات',
  SELF_BAN_FORBIDDEN:'ناتوانیت هەژماری خۆت بۆیکۆت بکەیت',
  USER_NOT_FOUND:'بەکارهێنەرەکە نەدۆزرایەوە',
  KYC_REQUEST_EXISTS:'ئەم بەکارهێنەرە پێشتر داواکارییەکی چالاکی هەیە',
  KYC_REQUEST_NOT_FOUND:'داواکارییەکە نەدۆزرایەوە',
  KYC_REQUEST_NOT_ACTIVE:'ئەم داواکارییە چیتر چالاک نییە',
  KYC_REASON_TOO_LONG:'دەق نابێت لە 500 پیت زیاتر بێت',
  KYC_REASON_REQUIRED:'بۆ ڕەتکردنەوە هۆکار پێویستە (لانیکەم 3 پیت)',
  KYC_NOT_FOUND:'داواکارییەکە نەدۆزرایەوە',
  KYC_ALREADY_REVIEWED:'ئەم داواکارییە پێشتر لەلایەن ئادمینێکی ترەوە بڕیاری لەسەر دراوە',
  KYC_SELF_REVIEW_FORBIDDEN:'ناتوانیت پشتڕاستکردنەوەی ناسنامەی خۆت پەسەند یان ڕەت بکەیتەوە',
  KYC_DECISION_INVALID:'بڕیارەکە دروست نییە',
  KYC_FILTER_INVALID:'فلتەرەکە دروست نییە',
  KYC_NAME_MISMATCH_CONFIRM_REQUIRED:'ناوی هەژمار گۆڕاوە؛ لیستەکە نوێکرایەوە، تکایە دووبارە بیپشکنە و گۆڕینی ناو پشتڕاست بکەرەوە',
  KYC_NOT_LATEST_APPROVED:'ئەمە دوایین ناسنامەی پەسەندکراوی ئەم بەکارهێنەرە نییە',
  PROFILE_NAME_LOCKED_BY_KYC:'ناوی ئەم هەژمارە بە ناسنامە پشتڕاستکراوەتەوە و تەنها بە ناوی سەر ناسنامە دەگۆڕدرێت'
};
function adminDbMessage(error){
  const raw=String(error?.message||error||'');
  const key=Object.keys(KYC_ADMIN_ERRORS).find(k=>raw.includes(k));
  if(key) return KYC_ADMIN_ERRORS[key];
  if(raw.includes('INVALID_FEE_TIER')) return 'پلەی لێبڕین دروست نییە: بڕ دەبێت لانیکەم 1,000 بێت و ڕێژەکان لە 0 تا 100';
  if(error?.code==='42501' || /permission denied|row-level security/i.test(raw)) return 'مۆڵەتی ئەم کارەت نییە';
  return 'هەڵە: '+raw;
}
function kycBadgeHTML(status){
  const m=KYC_ADMIN_STATUS[status]||KYC_ADMIN_STATUS.none;
  return `<span class="badge ${m.cls}">${esc(m.label)}</span>`;
}
// Shared customer/admin comparator; the exact three-part rule lives in one module.
function kycNameRelation(accountName, legalName){
  return window.KycName ? window.KycName.relation(accountName,legalName) : 'unknown';
}
function kycNormName(value){
  return window.KycName ? window.KycName.normalize(value) : String(value??'').normalize('NFC').replace(/\s+/g,' ').trim().toLowerCase();
}

const KYC_EXCHANGE_BLOCKED_BADGE='<span class="badge banned" title="تا پەسەندکردنی ناسنامە ناتوانێت ئاڵوگۆڕی نوێ بکات">ئاڵوگۆڕ ڕاگیراوە</span>';
function kycNameCompareHTML(it,extractedName=''){
  const account=it.account_name ?? it.user?.full_name ?? '';
  const legal=it.full_legal_name||'';
  const rel=kycNameRelation(account, legal);
  const ocrRel=extractedName?kycNameRelation(account,extractedName):'unknown';
  const typedSame=(rel==='same' || rel==='same_translit');
  const ocrSame=!extractedName || ocrRel==='same' || ocrRel==='same_translit';
  const same=typedSame && ocrSame;
  let note;
  if(rel==='same'){
    note='<p class="kyc-nc-note ok"><i class="fas fa-circle-check"></i> ناوی هەژمار و ناوی تەواوی نووسراو یەکن.</p>';
  }else if(rel==='same_translit'){
    // e.g. account "Zana Ahmed" + document "زانا ئەحمەد"
    note='<p class="kyc-nc-note ok"><i class="fas fa-circle-check"></i> هەموو بەشەکانی ناو یەکن و تەنها بە ئەلفوبێی جیاواز (ئینگلیزی/کوردی) نووسراون.'
      +(it.status==='pending'?' دوای پەسەندکردن ناوی هەژمار وەک سەر ناسنامە دەنووسرێتەوە.':'')+'</p>';
  }else if(rel==='similar'){
    note='<p class="kyc-nc-note warn"><i class="fas fa-circle-info"></i> ناوەکان نزیکن، بەڵام تەواوی وشەکان یەکسان نین؛ تکایە بە دەست بەراوردیان بکە.</p>';
  }else if(rel==='different_script'){
    note='<p class="kyc-nc-note warn"><i class="fas fa-triangle-exclamation"></i> نووسینی ناوەکان جیاوازە و وەک یەک ناناسرێنەوە؛ تکایە ناوی تەواو بە دەست بەراورد بکە.</p>';
  }else if(it.status==='pending'){
    note='<p class="kyc-nc-note bad"><i class="fas fa-triangle-exclamation"></i> ناوی تەواوی هەژمار لەگەڵ ناوی نووسراو ناگونجێت. پێش پەسەندکردن هەموو بەشەکانی ناو بە دەست بپشکنە.</p>';
  }else{
    note='<p class="kyc-nc-note bad"><i class="fas fa-triangle-exclamation"></i> ناوی تەواوی هەژمار لەگەڵ ناوی نووسراوی ئەم داواکارییە جیاوازە.</p>';
  }
  if(extractedName && !ocrSame){
    note+='<p class="kyc-nc-note bad"><i class="fas fa-triangle-exclamation"></i> ناوی تەواوی هەژمار لەگەڵ ناوی خوێندراوەوە لە وێنەکە ناگونجێت یان پێویستی بە پشکنینی مرۆیی هەیە.</p>';
  }
  if(!same && it.status==='approved' && it.is_latest_approved){
    note+='<button type="button" class="act-btn" id="kycSyncNameBtn" onclick="syncKycProfileName()">نوێکردنەوەی ناوی هەژمار بە ناوی سەر ناسنامە</button>';
  }
  return `<section id="kycAccountNameCompare" class="dx-group kyc-name-compare ${same?'ok':'bad'}"><h4 class="dx-h">ناوی تەواوی هەژمار · ناوی سیانی</h4>
    <div class="kyc-account-name-card">
      <div class="kyc-account-name-value"><small>ناوی هەژمار</small><b dir="auto">${esc(account||'—')}</b></div>
      <div class="kyc-account-name-value"><small>ناوی تەواوی نووسراو لە داواکاری</small><b dir="auto">${esc(legal||'—')}</b><span>${kycOcrBadge(rel)}</span></div>
      ${extractedName?`<div class="kyc-account-name-value"><small>ناوی تەواوی خوێندراوەوە لە ناسنامە</small><b dir="auto">${esc(extractedName)}</b><span>${kycOcrBadge(ocrRel)}</span></div>`:''}
      <p class="kyc-full-name-guidance">ناوی هەژمار دەبێت بە هەموو بەشەکان لەگەڵ ناوی ناسنامە بگونجێت؛ نووسینی تەواوی ئینگلیزیی هەمان ناو قبوڵە. ناوی یەکەم یان بەشێکی ناو بە تەنها گونجاو دانانرێت.</p>
    </div>${note}</section>`;
}
function kycOcrBadge(kind){
  if(kind==='same' || kind==='same_translit') return '<span class="badge active">گونجاوە</span>';
  if(kind==='unknown') return '<span class="badge">نەخوێندراوەتەوە</span>';
  if(kind==='similar' || kind==='different_script') return '<span class="badge pending">پێویستی بە پشکنینی مرۆیی هەیە</span>';
  return '<span class="badge banned">ناگونجاوە</span>';
}
function kycOcrNumber(value){
  return String(value||'').replace(/[٠-٩۰-۹]/g,c=>String(c.charCodeAt(0)>=0x6f0?c.charCodeAt(0)-0x6f0:c.charCodeAt(0)-0x660))
    .toUpperCase().replace(/[^A-Z0-9]/g,'');
}
function kycOcrValueRow(label,value,dir='auto'){
  return `<div class="detail-row"><span class="lbl">${esc(label)}</span><span class="val" dir="${dir}">${esc(value||'—')}</span></div>`;
}
function kycOcrMatchResult(extracted,baseline,relation){
  let match='unknown';
  if(relation==='name') match=kycNameRelation(baseline,extracted);
  else if(relation==='date' && extracted && baseline) match=extracted===baseline?'same':'different';
  else if(relation==='number' && extracted && baseline) match=kycOcrNumber(extracted)===kycOcrNumber(baseline)?'same':'different';
  return match;
}
function kycOcrFieldHTML(label,value,dir,match){
  return `<div class="kyc-ocr-field"><small>${esc(label)}</small><div class="kyc-ocr-field-value"><b dir="${dir||'auto'}">${esc(value||'—')}</b>${match?`<span>${kycOcrBadge(match)}</span>`:''}</div></div>`;
}
function kycOcrDataCard(kind,title,subtitle,icon,fields){
  return `<article class="kyc-ocr-data-card ${kind}">
    <header class="kyc-ocr-card-head"><span class="kyc-ocr-card-icon"><i class="fas ${icon}" aria-hidden="true"></i></span><span><b>${esc(title)}</b><small>${esc(subtitle)}</small></span></header>
    <div class="kyc-ocr-card-fields">${fields.map(field=>kycOcrFieldHTML(field.label,field.value,field.dir,field.match)).join('')}</div>
  </article>`;
}
function kycOcrReviewSummary(o,it){
  const name=o.extracted_full_legal_name||'';
  const account=o.account_name||it.account_name||it.user?.full_name||'';
  const typedName=o.submitted_full_legal_name||it.full_legal_name||'';
  const typedDob=o.submitted_date_of_birth||it.date_of_birth||'';
  const typedNumber=o.submitted_document_number||it.document_number||'';
  const comparisons=[
    {key:'account_name',label:'ناو · هەژمار',extracted:name,baseline:account,relation:'name'},
    {key:'submitted_name',label:'ناو · زانیاریی نێردراو',extracted:name,baseline:typedName,relation:'name'},
    {key:'date_of_birth',label:'بەرواری لەدایکبوون',extracted:o.extracted_date_of_birth||'',baseline:typedDob,relation:'date'},
    {key:'document_number',label:'ژمارەی بەڵگەنامە',extracted:o.extracted_document_number||'',baseline:typedNumber,relation:'number'},
    {key:'document_issue_date',label:'بەرواری دەرچوون',extracted:o.extracted_document_issue_date||'',baseline:o.submitted_document_issue_date||it.document_issue_date||'',relation:'date'},
    {key:'document_expiry_date',label:'بەرواری بەسەرچوون',extracted:o.extracted_document_expiry_date||'',baseline:o.submitted_document_expiry_date||it.document_expiry_date||'',relation:'date'}
  ].map(row=>({...row,result:kycOcrMatchResult(row.extracted,row.baseline,row.relation)}));
  const mismatches=comparisons.filter(row=>row.result==='different');
  const uncertain=comparisons.filter(row=>row.result==='similar'||row.result==='different_script');
  const complete=comparisons.filter(row=>row.result!=='unknown').length;
  let summary='OCR و زانیارییە بەراوردکراوەکان ناگونجانی دیاریکراویان نیشان نادەن.';
  if(o.is_identity_document===false) summary='وێنەکە وەک بەڵگەنامەی ناسنامە نەناسێنراوە.';
  else if(mismatches.length) summary='ناگونجانی دیاریکراو: '+[...new Set(mismatches.map(row=>row.label.split(' · ')[0]))].join('، ')+'.';
  else if(uncertain.length) summary='بەراوردی ناو یەکسانی دڵنیا نادات؛ پشکنینی مرۆیی پێویستە.';
  else if(!complete) summary='زانیاریی پێویست بۆ بەراورد تەواو نییە؛ بە دەست پشکنە.';

  const nameAccount=mismatches.some(row=>row.key==='account_name');
  const nameSubmitted=mismatches.some(row=>row.key==='submitted_name');
  const reasonParts=[];
  if(o.is_identity_document===false) reasonParts.push('وێنەی نێردراو ناسنامە نییە');
  if(nameAccount||nameSubmitted){
    const target=nameAccount&&nameSubmitted?'ناوی هەژمار و ناوی نێردراو':nameAccount?'ناوی هەژمار':'ناوی نێردراو';
    reasonParts.push('ناوی ناسنامە لەگەڵ '+target+' ناگونجێت');
  }
  if(mismatches.some(row=>row.key==='date_of_birth')) reasonParts.push('بەرواری لەدایکبوون لەگەڵ زانیاریی نێردراو ناگونجێت');
  if(mismatches.some(row=>row.key==='document_number')) reasonParts.push('ژمارەی بەڵگەنامە لەگەڵ زانیاریی نێردراو ناگونجێت');
  if(mismatches.some(row=>row.key==='document_issue_date')) reasonParts.push('بەرواری دەرچوونی ناسنامە ناگونجێت');
  if(mismatches.some(row=>row.key==='document_expiry_date')) reasonParts.push('بەرواری بەسەرچوونی ناسنامە ناگونجێت');
  const suggestion=reasonParts.length
    ? reasonParts.join('؛ ')+'؛ تکایە زانیارییەکان و وێنەی ناسنامەکەت بپشکنە و دووبارە بنێرە.'
    : '';
  return {comparisons,summary,suggestion,mismatches,uncertain};
}
function refreshKycOcrReview(){ if(_kycReviewItem) loadKycOcrReview(_kycReviewItem); }
async function retryKycOcrReview(){
  const it=_kycReviewItem;
  if(!it || retryKycOcrReview.busy) return;
  retryKycOcrReview.busy=true;
  try{
    const {data,error}=await sb.rpc('ex_admin_kyc_ocr_retry',{p_verification_id:it.id});
    if(error) throw error;
    if(data?.queued) showToast('خوێندنەوەی ناسنامە دووبارە دەستی پێکرد','gr');
    else showToast('نەتوانرا خوێندنەوەی ناسنامە دەستپێبکرێت','rd');
    await loadKycOcrReview(it);
  }catch(e){ showToast(adminDbMessage(e),'rd'); }
  finally{ retryKycOcrReview.busy=false; }
}
async function loadKycOcrReview(it){
  const box=document.getElementById('kycOcrResult');
  if(!box || !it) return;
  box.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  const {data,error}=await sb.rpc('ex_admin_kyc_ocr_result',{p_verification_id:it.id});
  if(error){
    box.innerHTML=`<div class="kyc-empty-line">${esc(adminDbMessage(error))}</div><button type="button" class="act-btn" onclick="refreshKycOcrReview()">نوێکردنەوە</button>`;
    return;
  }
  const o=data||{};
  if(o.status==='not_found'){
    box.innerHTML='<div class="kyc-admin-note">ئەنجامی خوێندنەوەی ناسنامە نەدۆزرایەوە.</div>';
    return;
  }
  if(o.status==='queued' || o.status==='processing'){
    box.innerHTML='<div class="kyc-admin-note">خوێندنەوەی ناسنامە لە پاشبنەما بەردەوامە؛ کاتی تەواوبوون دەتوانیت نوێی بکەیتەوە.</div><button type="button" class="act-btn" onclick="refreshKycOcrReview()">نوێکردنەوە</button>';
    return;
  }
  if(o.status==='not_queued'){
    box.innerHTML='<div class="kyc-admin-note">بۆ ئەم داواکارییەی مێژوویی تا ئێستا خوێندنەوەی ئۆتۆماتیکی ناسنامە دەستپێنەکراوە.</div><button type="button" class="act-btn" onclick="retryKycOcrReview()">دەستپێکردنی خوێندنەوە</button>';
    return;
  }
  if(o.status==='error'){
    const msg=o.error_code==='reader_key_missing'?'کلیلی سیستەمی خوێندنەوەی پسووڵە لە Supabase نییە.':'خوێندنەوەی ئۆتۆماتیکی ئەم ناسنامەیە سەرکەوتوو نەبوو؛ بەڵگەنامەکە بە دەست پشکنە.';
    box.innerHTML=`<div class="kyc-admin-note danger">${esc(msg)}</div><button type="button" class="act-btn" onclick="retryKycOcrReview()">دووبارە خوێندنەوە</button>`;
    return;
  }
  const name=o.extracted_full_legal_name||'';
  const account=o.account_name||it.account_name||it.user?.full_name||'';
  const typedName=o.submitted_full_legal_name||it.full_legal_name||'';
  const typedDob=o.submitted_date_of_birth||it.date_of_birth||'';
  const typedNumber=o.submitted_document_number||it.document_number||'';
  const typedIssue=o.submitted_document_issue_date||it.document_issue_date||'';
  const typedExpiry=o.submitted_document_expiry_date||it.document_expiry_date||'';
  const review=kycOcrReviewSummary(o,it);
  const matchFor=key=>review.comparisons.find(row=>row.key===key)?.result||'unknown';
  const submittedCard=kycOcrDataCard('submitted','زانیاریی نووسراو','ئەو زانیارییانەی بەکارهێنەر ناردوویەتی','fa-keyboard',[
    {label:'ناوی تەواوی یاسایی',value:typedName,dir:'auto',match:matchFor('submitted_name')},
    {label:'بەرواری لەدایکبوون',value:typedDob,dir:'ltr',match:matchFor('date_of_birth')},
    {label:'ژمارەی بەڵگەنامە',value:typedNumber,dir:'ltr',match:matchFor('document_number')},
    {label:'بەرواری دەرچوون',value:typedIssue,dir:'ltr',match:matchFor('document_issue_date')},
    {label:'بەرواری بەسەرچوون',value:typedExpiry,dir:'ltr',match:matchFor('document_expiry_date')},
    {label:'جۆری بەڵگەنامە',value:KYC_ADMIN_DOC[it.document_type]||it.document_type||'—',dir:'auto',match:null}
  ]);
  const ocrCard=kycOcrDataCard('extracted','زانیاریی خوێندراوەوە','ئەوەی OCR لە وێنەی ناسنامە خوێندوویەتی','fa-id-card',[
    {label:'ناوی تەواوی یاسایی',value:o.extracted_full_legal_name,dir:'auto',match:matchFor('submitted_name')},
    {label:'بەرواری لەدایکبوون',value:o.extracted_date_of_birth,dir:'ltr',match:matchFor('date_of_birth')},
    {label:'ژمارەی بەڵگەنامە',value:o.extracted_document_number,dir:'ltr',match:matchFor('document_number')},
    {label:'بەرواری دەرچوون',value:o.extracted_document_issue_date,dir:'ltr',match:matchFor('document_issue_date')},
    {label:'بەرواری بەسەرچوون',value:o.extracted_document_expiry_date,dir:'ltr',match:matchFor('document_expiry_date')},
    {label:'جۆری بەڵگەنامە',value:o.extracted_document_type,dir:'auto',match:null}
  ]);
  const accountCard=document.getElementById('kycAccountNameCompare');
  if(accountCard) accountCard.outerHTML=kycNameCompareHTML({...it,account_name:account,full_legal_name:typedName},o.is_identity_document===false?'':name);
  const reasonEl=document.getElementById('kycRvReason');
  if(reasonEl && !reasonEl.value.trim() && review.suggestion) reasonEl.value=review.suggestion;
  const title=o.is_identity_document===false?'وێنەکە وەک بەڵگەنامەی ناسنامە نەنێردراوەتەوە.':'OCR تەواو بوو؛ ئەمە تەنها یارمەتیی پشکنینی ئادمینە و خۆکارانە پەسەند یان ڕەت ناکاتەوە.';
  box.innerHTML=`<div class="kyc-admin-note ${review.mismatches.length||o.is_identity_document===false?'danger':review.uncertain.length?'':'ok'}"><b>پوختە:</b> ${esc(review.summary)} ${o.model?`<small dir="ltr">${esc(o.model)}</small>`:''}<small>${esc(title)}</small></div>
    <div class="kyc-ocr-card-grid">${submittedCard}${ocrCard}</div>
    ${o.processed_at?kycOcrValueRow('کاتی خوێندنەوە',fmtDateTime(o.processed_at),'ltr'):''}
    ${review.suggestion?'<div class="kyc-admin-note">هۆکاری ڕەتکردنەوە پێشنیار کراوە و لە خانەکەدا پڕکراوەتەوە؛ ئادمین دەتوانێت دەستکاری بکات. بڕیار تەنها بە کلیکی ئادمین دەدرێت.</div>':''}<button type="button" class="act-btn" onclick="retryKycOcrReview()">دووبارە خوێندنەوە</button>`;
}
async function syncKycProfileName(){
  const it=_kycReviewItem;
  if(_kycBusy || !it) return;
  confirm2('نوێکردنەوەی ناوی هەژمار',
    `ناوی هەژمار دەگۆڕدرێت لە «${it.account_name||'—'}» بۆ «${it.full_legal_name}». بەردەوام دەبیت؟`,
    'fas fa-arrows-rotate','var(--cy)', async()=>{
      _kycBusy=true;
      const btn=document.getElementById('kycSyncNameBtn'); if(btn) btn.disabled=true;
      try{
        const {error}=await sb.rpc('ex_admin_kyc_sync_profile_name',{p_verification_id:it.id});
        if(error) throw error;
        showToast('ناوی هەژمار نوێکرایەوە','gr');
        closeKycReview(); loadKycAdmin();
      }catch(e){
        showToast(adminDbMessage(e),'rd');
        if(btn) btn.disabled=false;
      }finally{ _kycBusy=false; }
    });
}
function kycFillReason(id, el){
  const t=document.getElementById(id);
  if(t){ t.value=el.textContent.trim(); t.focus(); }
}

let _kycFilter='pending';
let _kycItems=[];
let _kycPoll=null;
let _kycLastPending=null;
let _kycListTimer=null;
let _kycSearchTimer=null;
let _kycSearchResults=[];
let _kycReqTarget=null;
let _kycReviewItem=null;
let _kycBlobUrls=[];
let _kycBusy=false;

async function loadKycSummary(notify){
  try{
    const {data,error}=await sb.rpc('ex_admin_kyc_summary');
    if(error) throw error;
    const set=(id,v)=>{ const el=document.getElementById(id); if(el) el.textContent=formatNum(v||0); };
    set('kycRequiredCount',data.required); set('kycPendingCount',data.pending);
    set('kycApprovedCount',data.approved); set('kycRejectedCount',data.rejected);
    const pending=Number(data.pending||0);
    const badge=document.getElementById('sbKycCount');
    if(badge){ badge.textContent=pending>99?'99+':String(pending); badge.style.display=pending?'inline-flex':'none'; }
    if(notify && pending>0 && _kycLastPending!==null && pending>_kycLastPending){
      showToast((pending-_kycLastPending)+' داواکاری نوێی پشتڕاستکردنەوەی ناسنامە هەیە','bl');
    }
    _kycLastPending=pending;
    return data;
  }catch(_){ return null; }
}
function startKycMonitor(){
  loadKycSummary(false);
  clearInterval(_kycPoll);
  _kycPoll=setInterval(()=>{ if(document.visibilityState==='visible') loadKycSummary(true); },30000);
}

async function loadKycAdmin(){
  const wrap=document.getElementById('kycListWrap');
  if(wrap) wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  document.querySelectorAll('[data-kycf]').forEach(c=>c.classList.toggle('on', c.dataset.kycf===_kycFilter));
  loadKycSummary(false);
  try{
    const q=(document.getElementById('kycListSearch')?.value||'').trim();
    const {data,error}=await sb.rpc('ex_admin_kyc_list',{p_filter:_kycFilter,p_query:q||null,p_limit:200});
    if(error) throw error;
    _kycItems=(Array.isArray(data)?data:[]).sort((a,b)=>new Date(b.created_at)-new Date(a.created_at));
    renderKycList();
  }catch(e){
    if(wrap) wrap.innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>${esc(adminDbMessage(e))}</p></div>`;
  }
}
function setKycFilter(f){
  _kycFilter=f;
  if(_curPage!=='kyc'){ goPage('kyc'); return; }
  loadKycAdmin();
}
function onKycListSearch(){
  clearTimeout(_kycListTimer);
  _kycListTimer=setTimeout(loadKycAdmin,350);
}

function kycUserLine(u){
  u=u||{};
  const n=String(u.full_name||u.email||'?').trim();
  return `<div class="user-cell kyc-person"><span class="lv-av">${esc(n.charAt(0).toUpperCase()||'?')}</span>
    <div style="min-width:0"><div class="user-cell-name">${esc(u.full_name||'بێ ناو')}</div>
    <div class="user-cell-handle" dir="ltr">${u.username?'@'+esc(u.username):'—'}</div>
    ${u.email?`<div class="user-cell-email">${esc(u.email)}</div>`:''}</div></div>`;
}

function renderKycList(){
  const wrap=document.getElementById('kycListWrap');
  if(!wrap) return;
  if(!_kycItems.length){
    wrap.innerHTML='<div class="empty"><i class="fas fa-id-card"></i><p>هیچ داواکارییەک لەم بەشەدا نییە</p></div>';
    return;
  }
  wrap.innerHTML='<div class="kyc-admin-list">'+_kycItems.map((it,i)=>{
    if(it.kind==='request'){
      const r=it.request||{};
      return `<article class="kyc-admin-card required">
        <div class="kyc-admin-head">${kycUserLine(it.user)}<div class="kyc-badges">${kycBadgeHTML('required')}${KYC_EXCHANGE_BLOCKED_BADGE}</div></div>
        <div class="kyc-admin-facts">
          <span><small>داواکراوە لەلایەن</small><b>${esc(r.requested_by||'—')}</b></span>
          <span><small>کاتی داواکاری</small><b dir="ltr">${esc(fmtDateTime(r.created_at))}</b></span>
        </div>
        ${r.reason?`<div class="kyc-admin-note"><b>هۆکار</b><p>${esc(r.reason)}</p></div>`:''}
        <div class="kyc-admin-foot"><small>چاوەڕوانی ناردنی بەڵگەنامە لەلایەن بەکارهێنەر</small>
          <div class="act-btn rd" onclick="cancelKycRequest('${esc(r.id)}')"><i class="fas fa-ban"></i> هەڵوەشاندنەوە</div></div>
      </article>`;
    }
    const st=it.status;
    return `<article class="kyc-admin-card ${esc(st)}">
      <div class="kyc-admin-head">${kycUserLine(it.user)}<div class="kyc-badges">${kycBadgeHTML(st)}${it.exchange_blocked?KYC_EXCHANGE_BLOCKED_BADGE:''}${(kycNameRelation(it.account_name ?? it.user?.full_name, it.full_legal_name)==='same_translit')?'<span class="badge active" title="هەمان ناوە بە ئەلفوبێیەکی جیاواز">ناو: کوردی/ئینگلیزی</span>':''}${(!['same','same_translit','unknown'].includes(kycNameRelation(it.account_name ?? it.user?.full_name, it.full_legal_name)) && (st==='pending' || it.is_latest_approved))?'<span class="badge pending">⚠ ناو جیاوازە</span>':''}</div></div>
      <div class="kyc-admin-facts">
        <span><small>جۆری بەڵگەنامە</small><b>${esc(KYC_ADMIN_DOC[it.document_type]||it.document_type)}</b></span>
        <span class="${!['same','same_translit','unknown'].includes(kycNameRelation(it.account_name ?? it.user?.full_name, it.full_legal_name))?'kyc-fact-bad':''}"><small>ناوی یاسایی</small><b>${esc(it.full_legal_name)}</b></span>
        <span class="${!['same','same_translit','unknown'].includes(kycNameRelation(it.account_name ?? it.user?.full_name, it.full_legal_name))?'kyc-fact-bad':''}"><small>ناوی هەژمار</small><b>${esc(it.account_name ?? it.user?.full_name ?? '—')}</b></span>
        <span><small>بەرواری لەدایکبوون</small><b dir="ltr">${esc(it.date_of_birth||'—')}</b></span>
        <span><small>ژمارەی بەڵگەنامە</small><b dir="ltr">${esc(it.document_number)}</b></span>
        <span><small>کاتی ناردن</small><b dir="ltr">${esc(fmtDateTime(it.submitted_at))}</b></span>
        <span><small>${st==='pending'?'داواکاری ئادمین':'پشکنەر'}</small><b>${esc(st==='pending'?(it.request?'بەڵێ':'نەخێر — خۆی دەستی پێکرد'):(it.reviewer?.full_name||'—'))}</b></span>
      </div>
      ${it.rejection_reason?`<div class="kyc-admin-note danger"><b>هۆکاری ڕەتکردنەوە</b><p>${esc(it.rejection_reason)}</p></div>`:''}
      <div class="kyc-admin-foot">
        <small>${it.reviewed_at?'بڕیار: <span dir="ltr">'+esc(fmtDateTime(it.reviewed_at))+'</span>':'وێنەی پێشەوە و دواوە هەیە'}</small>
        <div class="act-btn ${st==='pending'?'cy':'dark'}" onclick="openKycReview(${i})"><i class="fas fa-${st==='pending'?'magnifying-glass':'eye'}"></i> ${st==='pending'?'پشکنین':'بینین'}</div>
      </div>
    </article>`;
  }).join('')+'</div>';
}

// ── user search + "request verification" ────────────────────────
function searchKycUsers(){
  clearTimeout(_kycSearchTimer);
  const q=(document.getElementById('kycUserSearch')?.value||'').trim();
  const box=document.getElementById('kycUserResults');
  if(q.length<2){ _kycSearchResults=[]; if(box) box.innerHTML=''; return; }
  _kycSearchTimer=setTimeout(async()=>{
    if(box) box.innerHTML='<div class="loading" style="padding:14px"><i class="fas fa-circle-notch fa-spin"></i></div>';
    const {data,error}=await sb.rpc('ex_admin_kyc_search_users',{p_query:q,p_limit:12});
    if(error){ if(box) box.innerHTML=`<div class="kyc-empty-line">${esc(adminDbMessage(error))}</div>`; return; }
    _kycSearchResults=Array.isArray(data)?data:[];
    renderKycUserResults();
  },300);
}
function renderKycUserResults(){
  const box=document.getElementById('kycUserResults');
  if(!box) return;
  if(!_kycSearchResults.length){ box.innerHTML='<div class="kyc-empty-line">هیچ بەکارهێنەرێک نەدۆزرایەوە</div>'; return; }
  box.innerHTML=_kycSearchResults.map((u,i)=>{
    const active=u.request_status==='open'||u.request_status==='submitted';
    let action;
    if(active){
      action=`<div class="act-btn rd" onclick="cancelKycRequest('${esc(u.request_id)}')"><i class="fas fa-ban"></i> هەڵوەشاندنەوەی داواکاری</div>`;
    }else if(u.kyc_status==='pending'){
      action=`<div class="act-btn dark" onclick="openKycFromUser('${esc(u.username||'')}')"><i class="fas fa-magnifying-glass"></i> پشکنینی بەڵگەنامە</div>`;
    }else{
      action=`<div class="act-btn cy" onclick="openKycRequest(${i})"><i class="fas fa-id-card"></i> داواکردنی پشتڕاستکردنەوە</div>`;
    }
    return `<div class="kyc-user-row">
      ${kycUserLine(u)}
      <div class="kyc-user-side">${kycBadgeHTML(u.kyc_status)}${active?KYC_EXCHANGE_BLOCKED_BADGE:''}${u.is_banned?' <span class="badge banned">بۆیکۆتکراو</span>':''}${action}</div>
    </div>`;
  }).join('');
}
function openKycFromUser(username){
  const s=document.getElementById('kycListSearch');
  if(s) s.value=username;
  _kycFilter='pending';
  loadKycAdmin();
  document.getElementById('kycListWrap')?.scrollIntoView({behavior:'smooth',block:'start'});
}
function openKycRequest(i){
  const u=_kycSearchResults[i];
  if(!u) return;
  showKycRequestModal(u);
}
async function openKycRequestById(userId){
  const {data,error}=await sb.rpc('ex_admin_kyc_search_users',{p_query:userId,p_limit:1});
  if(error){ showToast(adminDbMessage(error),'rd'); return; }
  const u=Array.isArray(data)?data[0]:null;
  if(!u){ showToast('بەکارهێنەرەکە نەدۆزرایەوە','rd'); return; }
  if(u.request_status==='open'||u.request_status==='submitted'){
    showToast('ئەم بەکارهێنەرە پێشتر داواکارییەکی چالاکی هەیە','bl'); return;
  }
  showKycRequestModal(u);
}
function showKycRequestModal(u){
  _kycReqTarget=u;
  document.getElementById('kycReqUser').innerHTML=dxPersonHead(u.full_name||u.username,[u.username?'@'+u.username:'',u.email||''].filter(Boolean).join('  ·  '),kycBadgeHTML(u.kyc_status));
  document.getElementById('kycReqReason').value='';
  const btn=document.getElementById('kycReqSendBtn');
  btn.disabled=false;
  btn.textContent='ناردنی داواکاری';
  openMo('moKycRequest');
}
async function confirmKycRequest(){
  if(_kycBusy || !_kycReqTarget) return;
  const reason=(document.getElementById('kycReqReason').value||'').trim();
  if(reason.length>500){ showToast(KYC_ADMIN_ERRORS.KYC_REASON_TOO_LONG,'rd'); return; }
  const btn=document.getElementById('kycReqSendBtn');
  _kycBusy=true;
  btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i> ناردن...';
  try{
    const {error}=await sb.rpc('ex_admin_kyc_request',{p_user_id:_kycReqTarget.id,p_reason:reason||null});
    if(error) throw error;
    closeMo('moKycRequest');
    showToast('داواکاری پشتڕاستکردنەوە بۆ '+(_kycReqTarget.username?'@'+_kycReqTarget.username:'بەکارهێنەر')+' نێردرا','gr');
    _kycReqTarget=null;
    if(document.getElementById('kycUserSearch')?.value) searchKycUsers();
    if(_curPage==='kyc') loadKycAdmin(); else loadKycSummary(false);
  }catch(e){
    showToast(adminDbMessage(e),'rd');
    btn.disabled=false; btn.textContent='ناردنی داواکاری';
  }finally{ _kycBusy=false; }
}
function cancelKycRequest(requestId){
  if(!requestId) return;
  confirm2('هەڵوەشاندنەوەی داواکاری','ئایا دەتەوێت داواکاری پشتڕاستکردنەوەی ئەم بەکارهێنەرە هەڵبوەشێنیتەوە؟ بەکارهێنەر ئاگادار دەکرێتەوە.',
    'fas fa-ban','var(--rd)', async()=>{
      const {error}=await sb.rpc('ex_admin_kyc_cancel_request',{p_request_id:requestId,p_note:null});
      if(error){ showToast(adminDbMessage(error),'rd'); return; }
      showToast('داواکارییەکە هەڵوەشێنرایەوە','gr');
      if(document.getElementById('kycUserSearch')?.value) searchKycUsers();
      loadKycAdmin();
    });
}

// ── review modal ──────────────────────────────────────────────────
function revokeKycBlobs(){
  _kycBlobUrls.forEach(u=>{ try{ URL.revokeObjectURL(u); }catch(_){} });
  _kycBlobUrls=[];
}
function closeKycReview(){
  closeMo('moKycReview');
  revokeKycBlobs();
  _kycReviewItem=null;
}
async function loadKycImage(path, slotId){
  const slot=document.getElementById(slotId);
  if(!slot) return;
  if(!path){ slot.innerHTML='<div class="kyc-img-empty">وێنە نییە</div>'; return; }
  try{
    const {data,error}=await sb.storage.from('identity-documents').download(path);
    if(error) throw error;
    const url=URL.createObjectURL(data);
    _kycBlobUrls.push(url);
    if(!document.getElementById(slotId)) { URL.revokeObjectURL(url); return; }
    slot.innerHTML=`<img src="${url}" alt="" onclick="showImg('${url}')"><span class="kyc-img-zoom"><i class="fas fa-eye"></i> گەورەکردن</span>`;
  }catch(e){
    slot.innerHTML=`<div class="kyc-img-empty"><i class="fas fa-triangle-exclamation"></i> نەتوانرا وێنەکە باربکرێت</div>`;
  }
}
async function openKycReview(i){
  const it=_kycItems[i];
  if(!it || it.kind!=='verification') return;
  revokeKycBlobs();
  _kycReviewItem=it;
  const u=it.user||{};
  const pending=it.status==='pending';
  const isSelf=adminUser && u.id===adminUser.id;
  document.getElementById('kycRvTitle').textContent=pending?'پشکنینی بەڵگەنامە':'بەڵگەنامەی ناسنامە';
  const r=it.request;
  const row=(label,value,attrs='')=>'<div class="detail-row"><span class="lbl">'+label+'</span><span class="val"'+attrs+'>'+value+'</span></div>';
  const quick=['وێنەی بەڵگەنامەکە ڕوون نییە.','هەموو گۆشەکانی بەڵگەنامەکە دیار نین.','زانیارییەکان لەگەڵ بەڵگەنامەکە ناگونجێن.','بەڵگەنامەکە بەسەرچووە.','The document image is not clear.'];
  document.getElementById('kycRvBody').innerHTML=
    dxPersonHead(u.full_name||u.username,[u.username?'@'+u.username:'',u.email||''].filter(Boolean).join('  ·  '),kycBadgeHTML(it.status))+
    (it.exchange_blocked?'<div class="kyc-admin-note danger"><b>ئاڵوگۆڕ ڕاگیراوە</b><p>تا پەسەندکردنی ناسنامەکەی ناتوانێت ئاڵوگۆڕی نوێ بکات.</p></div>':'')+
    `<section class="dx-group"><h4 class="dx-h">وێنەکان</h4><div class="dx-shots kyc-rv-images">
      <figure class="dx-fig"><div class="kyc-img-slot" id="kycRvFront"><i class="fas fa-circle-notch fa-spin"></i></div><figcaption>ڕووی پێشەوە</figcaption></figure>
      <figure class="dx-fig"><div class="kyc-img-slot" id="kycRvBack"><i class="fas fa-circle-notch fa-spin"></i></div><figcaption>ڕووی دواوە</figcaption></figure>
    </div></section>`+
    `<section class="dx-group"><h4 class="dx-h">خوێندنەوە و بەراوردی ناسنامە (OCR)</h4><div id="kycOcrResult" class="dx-card"><div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div></div></section>`+
    kycNameCompareHTML(it)+
    dxGroup('بەڵگەنامە',
      row('جۆری بەڵگەنامە',esc(KYC_ADMIN_DOC[it.document_type]||it.document_type),' dir="rtl"')+
      row('ناوی تەواوی یاسایی',esc(it.full_legal_name),' dir="auto"')+
      row('بەرواری لەدایکبوون',esc(it.date_of_birth||'—'),' dir="ltr"')+
      row('ژمارەی بەڵگەنامە',esc(it.document_number),' dir="ltr"')+
      row('کاتی ناردن',esc(fmtDateTime(it.submitted_at)),' dir="ltr"')+
      (it.reviewed_at?row('کاتی بڕیار',esc(fmtDateTime(it.reviewed_at)),' dir="ltr"')+
        row('بڕیاردەر',esc(it.reviewer?.full_name||'—')+(it.reviewer?.username?' <span dir="ltr">@'+esc(it.reviewer.username)+'</span>':''),' dir="rtl"'):''))+
    (it.rejection_reason?`<div class="kyc-admin-note danger"><b>هۆکاری ڕەتکردنەوە</b><p>${esc(it.rejection_reason)}</p></div>`:'')+
    (r?`<div class="kyc-admin-note"><b>داواکاری ئادمین · ${esc(r.requested_by||'—')} · <span dir="ltr">${esc(fmtDateTime(r.created_at))}</span></b><p>${esc(r.reason||'بێ هۆکار')}</p></div>`:'')+
    (pending ? (isSelf ? `<div class="kyc-admin-note danger"><b>ئاگاداری</b><p>ناتوانیت بەڵگەنامەی خۆت پەسەند یان ڕەت بکەیتەوە.</p></div>` : `
    <section class="dx-group"><h4 class="dx-h"><label for="kycRvReason">هۆکاری ڕەتکردنەوە</label></h4>
      <textarea class="minp mta" id="kycRvReason" maxlength="500" rows="3" placeholder="تەنها بۆ ڕەتکردنەوە پێویستە"></textarea>
      <div class="kyc-quick">${quick.map(q=>`<button type="button" class="kyc-chip" onclick="kycFillReason('kycRvReason',this)"${/^[A-Za-z]/.test(q)?' dir="ltr"':''}>${esc(q)}</button>`).join('')}</div>
    </section>
    <div class="dx-decide kyc-rv-actions">
      <button type="button" class="act-btn gr" id="kycRvApproveBtn" onclick="reviewKyc('approve')">پەسەندکردن</button>
      <button type="button" class="act-btn rd" id="kycRvRejectBtn" onclick="reviewKyc('reject')">ڕەتکردنەوە</button>
    </div>`) : '')+
    `<section class="dx-group"><h4 class="dx-h">مێژوو</h4><div id="kycRvHistory" class="dx-card kyc-timeline"><div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div></div></section>`;
  openMo('moKycReview');
  loadKycImage(it.front_image_path,'kycRvFront');
  loadKycImage(it.back_image_path,'kycRvBack');
  loadKycOcrReview(it);
  loadKycHistory(u.id);
}
async function loadKycHistory(userId){
  const box=document.getElementById('kycRvHistory');
  if(!box) return;
  const {data,error}=await sb.rpc('ex_admin_kyc_history',{p_user_id:userId,p_limit:50});
  if(error){ box.innerHTML=`<div class="kyc-empty-line">${esc(adminDbMessage(error))}</div>`; return; }
  const rows=Array.isArray(data)?data:[];
  if(!rows.length){ box.innerHTML='<div class="kyc-empty-line">هیچ تۆمارێک نییە</div>'; return; }
  box.innerHTML=rows.map(e=>`<div class="kyc-tl-item ${esc(e.event)}">
    <span class="kyc-tl-dot"></span>
    <div><b>${esc(KYC_ADMIN_EVENTS[e.event]||e.event)}</b>
      <small>${esc(e.actor_name||'—')}${e.actor_username?' <span dir="ltr">@'+esc(e.actor_username)+'</span>':''} · ${esc(e.actor_role==='user'?'بەکارهێنەر':e.actor_role==='super_admin'?'سوپەر ئادمین':e.actor_role==='admin'?'ئادمین':'سیستەم')} · <span dir="ltr">${esc(fmtDateTime(e.created_at))}</span></small>
      ${e.note?`<p>${esc(e.note)}</p>`:''}
    </div></div>`).join('');
}
async function reviewKyc(decision){
  const it=_kycReviewItem;
  if(_kycBusy || !it) return;
  const reasonEl=document.getElementById('kycRvReason');
  const reason=(reasonEl?.value||'').trim();
  if(decision==='reject' && reason.length<3){
    showToast(KYC_ADMIN_ERRORS.KYC_REASON_REQUIRED,'rd');
    reasonEl?.focus();
    return;
  }
  const run=async()=>{
    const aBtn=document.getElementById('kycRvApproveBtn');
    const rBtn=document.getElementById('kycRvRejectBtn');
    const btn=decision==='approve'?aBtn:rBtn;
    const html=btn?.innerHTML;
    _kycBusy=true;
    if(aBtn) aBtn.disabled=true;
    if(rBtn) rBtn.disabled=true;
    if(btn) btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i> ...';
    try{
      const {error}=await sb.rpc('ex_admin_kyc_review',{
        p_verification_id:it.id, p_decision:decision,
        p_reason:decision==='reject'?reason:null,
        p_confirm_name_change: decision==='approve'
          && kycNormName(it.account_name ?? it.user?.full_name) !== kycNormName(it.full_legal_name)
      });
      if(error) throw error;
      showToast(decision==='approve'?'ناسنامەکە پەسەندکرا ✓':'پشتڕاستکردنەوەکە ڕەتکرایەوە و بەکارهێنەر ئاگادارکرایەوە', decision==='approve'?'gr':'rd');
      closeKycReview();
      loadKycAdmin();
    }catch(e){
      const msg=adminDbMessage(e);
      showToast(msg,'rd');
      if(/KYC_ALREADY_REVIEWED|KYC_NAME_MISMATCH_CONFIRM_REQUIRED/.test(String(e?.message||''))){ closeKycReview(); loadKycAdmin(); return; }
      if(aBtn) aBtn.disabled=false;
      if(rBtn) rBtn.disabled=false;
      if(btn) btn.innerHTML=html;
    }finally{ _kycBusy=false; }
  };
  if(decision==='approve'){
    const account=it.account_name ?? it.user?.full_name ?? '';
    const rel=kycNameRelation(account, it.full_legal_name);
    const willRename=kycNormName(account)!==kycNormName(it.full_legal_name);
    let title='پەسەندکردنی ناسنامە', tone='var(--gr)';
    let msg='دڵنیایت کە وێنە و زانیارییەکان دروستن و هی هەمان کەسن؟';
    if(rel==='same_translit'){
      msg=`هەمان ناوە بە ئەلفوبێیەکی جیاواز. دوای پەسەندکردن ناوی هەژمار دەبێت بە «${it.full_legal_name}». بەردەوام دەبیت؟`;
    }else if(willRename){
      title='پەسەندکردن و گۆڕینی ناوی هەژمار'; tone='var(--yw)';
      msg=`⚠ ناوەکان جیاوازن. دوای پەسەندکردن ناوی هەژمار دەگۆڕدرێت لە «${account||'—'}» بۆ «${it.full_legal_name}». دڵنیایت کە هەمان کەسە؟`;
    }
    confirm2(title, msg,'fas fa-circle-check', tone, run);
  }else{
    await run();
  }
}
