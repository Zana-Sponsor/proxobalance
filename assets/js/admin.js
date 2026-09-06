// ── Original admin module 1 ──
// ══════════════════════════════════════════════════════════════
// ═══ CONFIG (same Exchange Supabase project + Firebase as exchange.html) ═
// ══════════════════════════════════════════════════════════════
const SB_URL='https://pycxuugoblkslvwebxuu.supabase.co';
const SB_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5Y3h1dWdvYmxrc2x2d2VieHV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMTk3OTksImV4cCI6MjEwMTc5NTc5OX0.VRRwxnnuLs_WORuVUO3oX3CLxrPtgG_uewIJaGrzn_s';
const firebaseConfig = { apiKey: "AIzaSyB056_g2Y3AJjtjG9715FgtXIhtjFcMPPU", authDomain: "zana-exchange.firebaseapp.com", databaseURL: "https://zana-exchange-default-rtdb.firebaseio.com", projectId: "zana-exchange" };
firebase.initializeApp(firebaseConfig);
const fbdb = firebase.database();

const METHOD_META = {
  FastPay:  { label:'FastPay',  color:'#7c3aed' },
  FIB:      { label:'FIB Bank', color:'#0ea5a4' },
  QiCard:   { label:'Qi Card',  color:'#2563eb' },
  Asiacell: { label:'Asiacell', color:'#e11d48' },
  Korek:    { label:'Korek',    color:'#f59e0b' },
  USDT:     { label:'USDT ($)', color:'#26a17b' }
};
const ALL_METHODS = ['FastPay','FIB','QiCard','Asiacell','Korek','USDT'];
const RECEIVE_METHODS = ['FastPay','FIB','QiCard'];
const STATUS_PENDING='چاوەڕوانە', STATUS_APPROVED='پەسەندکرا', STATUS_REJECTED='ڕەتکرا';

let sb, adminUser=null, adminName='ئادمین';
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
async function verifyAdmin(uid, email){
  // Admin rights live in ex_profiles.is_admin — the same column the panel's
  // "کردن بە ئادمین" button writes and the database's is_ex_admin() RLS
  // helper reads. (The old security_admins table does not exist.)
  try{
    const {data:prof, error} = await sb
      .from('ex_profiles')
      .select('full_name,email,is_admin,is_banned')
      .eq('id', uid)
      .maybeSingle();
    if(error || !prof || !prof.is_admin || prof.is_banned) return false;
    adminName = prof.full_name || email.split('@')[0];
    return true;
  }catch(e){ return false; }
}

async function doLogin(){
  const email=document.getElementById('loginEmail').value.trim();
  const pass=document.getElementById('loginPass').value;
  const btn=document.getElementById('loginBtn');
  if(!email||!pass){ showAuthErr('ئیمەیل و پاسۆرد پڕ بکەرەوە'); return; }
  btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    const {data,error} = await sb.auth.signInWithPassword({email,password:pass});
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
  recordAdminVisit();
  goPage('dashboard');
  subscribeOrdersAdmin();
  subscribeAlerts();
}

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
  orders:{ title:'ئۆردەرەکان', sub:'پەسەندکردن و ڕەتکردنەوەی داواکارییە گۆڕینەوەکان', load: ()=>loadOrders() },
  accounts:{ title:'هەژمارەکان', sub:'بەڕێوەبردنی هەژمارەکانی بەکارهێنەران', load: ()=>loadAccounts() },
  wallets:{ title:'واڵێتەکان', sub:'زیادکردن، قوفڵکردن و دەستکاریکردنی واڵێتەکانی وەرگرتنی پارە', load: ()=>loadWalletsAdmin() },
  rates:{ title:'نرخ و کرێ', sub:'ڕێکخستنی نرخی گۆڕینەوە و کرێی هەر ڕێگایەک', load: ()=>loadRates() },
  notifications:{ title:'ئاگادارییەکان', sub:'ناردنی ئاگاداری و بینینی مێژوو', load: ()=>loadNotifPage() },
  announcement:{ title:'بانەری ئاگاداری', sub:'ئاگاداری گشتی سەرەوەی ئەپەکە', load: ()=>loadAnnouncement() },
  otp:{ title:'کۆدەکانی OTP', sub:'بینین و بەڕێوەبردنی کۆدەکانی دڵنیاکردنەوە', load: ()=>loadOtp() },
  security:{ title:'ئاسایش و IP', sub:'ڕووداوە گومانلێکراوەکان و بلۆککردنی نهێنی (404)', load: ()=>loadSecurity() },
};
let _curPage='dashboard';
function goPage(p){
  _curPage=p;
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
               <i class="fas fa-user-secret"></i> بلۆککردنی نهێنی (404)
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
  const v=prompt('IP بۆ بلۆککردن (١.٢.٣.٤ یان ١.٢.٣.٠/٢٤):', ip);
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
  const w=!m && typeof allWallets!=='undefined' ? allWallets.find(x=>x.key===key) : null;
  const label = m ? m.label : (w ? (w.name||key) : (key||'—'));
  const color = m ? m.color : 'var(--mt2)';
  if(!key) return '—';
  return `<span class="method-pill"><span class="method-dot" style="background:${color}"></span>${esc(label)}</span>`;
}
function statusBadgeClass(s){ return s===STATUS_APPROVED?'approved':(s===STATUS_REJECTED?'rejected':'pending'); }
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
  const {data} = await sb.from('ex_profiles').select('id,full_name,email,phone,is_admin,is_banned').in('id',uids);
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
  loadAlerts();
}
async function loadDashboardStats(){
  try{
    const [{count:usersCount}, {count:bannedCount}, {count:pendingCount}, {data:approvedRows}, {count:rejectedCount}] = await Promise.all([
      sb.from('ex_profiles').select('*',{count:'exact',head:true}),
      sb.from('ex_profiles').select('*',{count:'exact',head:true}).eq('is_banned',true),
      sb.from('ex_orders').select('*',{count:'exact',head:true}).eq('status',STATUS_PENDING),
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
    .on('postgres_changes', {event:'UPDATE', schema:'public', table:'ex_orders'}, ()=>{
      refreshOrdersEverywhere();
    })
    .subscribe();
}
async function loadOrders(){
  document.getElementById('ordersTableWrap').innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const {data:orders,error} = await sb.from('ex_orders').select('*').order('created_at',{ascending:false}).limit(300);
    if(error) throw error;
    const profMap = await loadProfilesFor((orders||[]).map(o=>o.user_id));
    _profMap = profMap;
    allOrders = (orders||[]).map(o=>({...o, profile:profMap[o.user_id]||null}));
    renderOrders();
  }catch(e){
    document.getElementById('ordersTableWrap').innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
  }
}
function filterOrders(el){
  if(el){ document.querySelectorAll('[data-of]').forEach(x=>x.classList.remove('on')); el.classList.add('on'); orderFilter=el.dataset.of; }
  renderOrders((document.getElementById('orderSearch')?.value||'').toLowerCase());
}
function renderOrders(q=''){
  let list=allOrders;
  if(orderFilter!=='all') list=list.filter(o=>o.status===orderFilter);
  if(q){
    const qq=q.replace(/[\s#-]/g,'');
    list=list.filter(o=>(o.profile?.full_name||'').toLowerCase().includes(q)
      ||(o.profile?.email||'').toLowerCase().includes(q)
      ||orderCodeOf(o).toLowerCase().includes(qq)
      ||String(o.order_number||'').includes(qq)
      ||(o.phone||'').includes(qq));
  }
  document.getElementById('ordersTableWrap').innerHTML = renderOrdersTable(list) + renderOrdersCards(list);
}
function renderOrdersTable(list){
  if(!list.length) return '<div class="empty"><i class="fas fa-inbox"></i><p>هیچ ئۆردەرێک نییە</p></div>';
  return `<table><thead><tr><th>ئایدی</th><th>بەکارهێنەر</th><th>ڕێگا</th><th>بڕ</th><th>وەرگیراو</th><th>باری</th><th>بەروار</th><th>کردار</th></tr></thead><tbody>
    ${list.map(o=>`<tr style="cursor:pointer" onclick='showOrderDetail(${safeAttr(o.id)})'>
      <td onclick="event.stopPropagation()">${orderCodeChip(o)}</td>
      <td><div class="user-cell"><div class="mini-av">${(o.profile?.full_name||o.profile?.email||'?')[0].toUpperCase()}</div><div><div class="user-cell-name">${esc(o.profile?.full_name||'—')}</div><div class="user-cell-email">${esc(o.profile?.email||'—')}</div></div></div></td>
      <td>${methodPill(o.from_method)} <i class="fas fa-arrow-left" style="font-size:10px;color:var(--mt);margin:0 4px"></i> ${methodPill(o.to_method)}</td>
      <td style="font-family:'Inter';font-weight:700">${formatNum(o.amount)}${o.from_method==='USDT'?'$':''}</td>
      <td style="font-family:'Inter';font-weight:800;color:var(--gr)">${formatNum(o.total)} IQD</td>
      <td><span class="badge ${statusBadgeClass(o.status)}">${esc(o.status)}</span></td>
      <td style="font-size:11px;color:var(--mt)">${fmtDateTime(o.created_at)}</td>
      <td onclick="event.stopPropagation()"><div class="act-grp">
        <div class="act-btn dark" onclick='showOrderDetail(${safeAttr(o.id)})'><i class="fas fa-eye"></i></div>
        ${o.status===STATUS_PENDING?`<div class="act-btn gr" onclick="approveOrder('${o.id}')"><i class="fas fa-check"></i></div><div class="act-btn rd" onclick="showRejectReason('${o.id}')"><i class="fas fa-times"></i></div>`:''}
      </div></td>
    </tr>`).join('')}
  </tbody></table>`;
}
function renderOrdersCards(list){
  if(!list.length) return '';
  return `<div class="rec-cards">${list.map(o=>`
    <div class="rec-card" onclick='showOrderDetail(${safeAttr(o.id)})'>
      <div class="rec-card-top">
        <div class="mini-av">${(o.profile?.full_name||o.profile?.email||'?')[0].toUpperCase()}</div>
        <div class="rec-card-info"><div class="rec-card-name">${esc(o.profile?.full_name||'بێ ناو')}</div><div class="rec-card-sub">${esc(o.profile?.email||'—')}</div></div>
        <span class="badge ${statusBadgeClass(o.status)}">${esc(o.status)}</span>
      </div>
      <div class="rec-card-meta">
        <span style="font-size:12px">${methodPill(o.from_method)} <i class="fas fa-arrow-left" style="font-size:9px;color:var(--mt);margin:0 3px"></i> ${methodPill(o.to_method)}</span>
      </div>
      <div class="rec-card-meta">
        <div class="rec-card-stat gr">${orderCodeChip(o)} • ${formatNum(o.total)} IQD</div>
        <div class="rec-card-date">${fmtDateTime(o.created_at)}</div>
      </div>
      ${o.status===STATUS_PENDING?`<div class="rec-card-actions" onclick="event.stopPropagation()">
        <div class="act-btn gr" onclick="approveOrder('${o.id}')"><i class="fas fa-check"></i> پەسەندکردن</div>
        <div class="act-btn rd" onclick="showRejectReason('${o.id}')"><i class="fas fa-times"></i> ڕەتکردنەوە</div>
      </div>`:`<div class="act-btn dark" style="justify-content:center;padding:8px">${'<i class="fas fa-eye"></i> زانیاری تەواو'}</div>`}
    </div>`).join('')}</div>`;
}

function showOrderDetail(id){
  const order = allOrders.find(x=>String(x.id)===String(id));
  if(!order){ showToast('نەدۆزرایەوە','rd'); return; }
  const displayAmt = formatNum(order.amount)+(order.from_method==='USDT'?' $':' IQD');
  document.getElementById('odTitle').textContent = 'ئۆردەر '+fmtCode(orderCodeOf(order));
  document.getElementById('odContent').innerHTML = `
    <div class="detail-row"><span class="lbl">ئایدی مامەڵە</span><span class="val">${orderCodeChip(order)}</span></div>
    <div class="detail-row"><span class="lbl">بەکارهێنەر</span><span class="val">${esc(order.profile?.full_name||'—')}</span></div>
    <div class="detail-row"><span class="lbl">ئیمەیل</span><span class="val">${esc(order.profile?.email||'—')}</span></div>
    <div class="detail-row"><span class="lbl">لە</span><span class="val">${methodPill(order.from_method)}</span></div>
    <div class="detail-row"><span class="lbl">بۆ</span><span class="val">${methodPill(order.to_method)}</span></div>
    <div class="detail-row"><span class="lbl">بڕی نێردراو</span><span class="val">${displayAmt}</span></div>
    <div class="detail-row"><span class="lbl">بڕی وەرگیراو</span><span class="val" style="color:var(--gr)">${formatNum(order.total)} IQD</span></div>
    <div class="detail-row"><span class="lbl">ژمارەی مۆبایل</span><span class="val">${esc(order.phone||'—')}</span></div>
    ${order.extra_info?`<div class="detail-row"><span class="lbl">زانیاری زیاتر</span><span class="val">${esc(order.extra_info)}</span></div>`:''}
    <div class="detail-row"><span class="lbl">باری</span><span class="val"><span class="badge ${statusBadgeClass(order.status)}">${esc(order.status)}</span></span></div>
    <div class="detail-row"><span class="lbl">بەروار</span><span class="val">${new Date(order.created_at).toLocaleString('ku')}</span></div>
    ${order.receipt_url?`<div style="margin-top:10px"><div style="font-size:11px;color:var(--mt);margin-bottom:8px">وێنەی پسووڵە (لەلایەن کڕیارەوە)</div><img src="${order.receipt_url}" class="rcpt-img" onclick="showImg('${order.receipt_url}')"></div>`:`<div class="fee-toggle-note" style="margin-top:10px"><i class="fas fa-paper-plane" style="margin-left:4px"></i>وێنەی پسووڵە بۆ تیلیگرامی ئەدمین نێردراوە لەکاتی ناردنی داواکارییەکە.</div>`}
    ${order.status===STATUS_APPROVED?`<div style="margin-top:10px">
      <div style="font-size:11px;color:var(--mt);margin-bottom:8px">وێنەی پسووڵەی پارەدان (بۆ کڕیار)</div>
      ${order.payout_receipt_url?`<img src="${order.payout_receipt_url}" class="rcpt-img" onclick="showImg('${order.payout_receipt_url}')">`:''}
      <label class="act-btn cy" style="cursor:pointer;display:inline-flex;margin-top:8px" id="podUploadLbl">
        <i class="fas fa-upload"></i> ${order.payout_receipt_url?'گۆڕینی وێنە':'ناردنی وێنەی پسووڵە بۆ کڕیار'}
        <input type="file" accept="image/*" style="display:none" onchange="uploadPayoutReceiptDirect(this,'${order.id}')">
      </label>
    </div>`:''}
    <label class="modal-lbl">تێبینی ئەدمین</label>
    <textarea class="minp mta" id="odNote">${esc(order.admin_note||'')}</textarea>
    <div class="act-grp" style="margin-top:12px">
      <div class="act-btn dark" onclick="saveOrderNote('${order.id}')"><i class="fas fa-floppy-disk"></i> پاشەکەوتی تێبینی</div>
    </div>
    ${order.status===STATUS_PENDING?`<div class="act-grp" style="margin-top:12px">
      <div class="act-btn gr" style="flex:1;justify-content:center" onclick="approveOrder('${order.id}');closeMo('moOrderDetail')"><i class="fas fa-check"></i> پەسەندکردن</div>
      <div class="act-btn rd" style="flex:1;justify-content:center" onclick="showRejectReason('${order.id}');closeMo('moOrderDetail')"><i class="fas fa-times"></i> ڕەتکردنەوە</div>
    </div>`:''}
  `;
  openMo('moOrderDetail');
}

let _apFile=null;
function approveOrder(id){
  const order = allOrders.find(x=>String(x.id)===String(id));
  document.getElementById('apOrderId').value = id;
  document.getElementById('apOrderTitle').textContent = 'پەسەندکردنی ئۆردەر' + (order?' '+fmtCode(orderCodeOf(order)):'');
  document.getElementById('apReceiptFile').value = '';
  document.getElementById('apReceiptPreview').innerHTML = '<i class="fas fa-receipt"></i>';
  document.getElementById('apReceiptNote').textContent = 'هیچ وێنەیەک هەڵنەبژێردراوە';
  _apFile = null;
  openMo('moApproveOrder');
}
function onApReceiptFile(input){
  const file = input.files[0]; if(!file) return;
  if(file.size > 5*1024*1024){ showToast('وێنەکە زۆر گەورەیە (زۆرترین 5MB)','rd'); input.value=''; return; }
  _apFile = file;
  const reader = new FileReader();
  reader.onload = () => { document.getElementById('apReceiptPreview').innerHTML = `<img src="${reader.result}" style="width:100%;height:100%;object-fit:cover">`; };
  reader.readAsDataURL(file);
  document.getElementById('apReceiptNote').textContent = file.name;
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
  const id = document.getElementById('apOrderId').value;
  const order = allOrders.find(x=>String(x.id)===String(id));
  const btn = document.getElementById('apConfirmBtn');
  btn.style.pointerEvents='none'; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    let payout_receipt_url = order?.payout_receipt_url || null;
    if(_apFile){
      payout_receipt_url = await uploadReceiptFile(_apFile, order.user_id, 'payout');
    }
    const {error} = await sb.from('ex_orders').update({status:STATUS_APPROVED, decided_at:new Date().toISOString(), payout_receipt_url}).eq('id',id);
    if(error) throw error;
    closeMo('moApproveOrder'); closeMo('moOrderDetail');
    showToast('✅ ئۆردەرەکە پەسەندکرا','gr');
    refreshOrdersEverywhere();
  }catch(e){
    showToast('هەڵە: '+e.message,'rd');
  }finally{
    btn.style.pointerEvents='auto'; btn.innerHTML='<i class="fas fa-check"></i> پەسەندکردن';
  }
}
async function uploadPayoutReceiptDirect(input, id){
  const file = input.files[0]; if(!file) return;
  if(file.size > 5*1024*1024){ showToast('وێنەکە زۆر گەورەیە (زۆرترین 5MB)','rd'); input.value=''; return; }
  const order = allOrders.find(x=>String(x.id)===String(id));
  const lbl = document.getElementById('podUploadLbl');
  if(lbl) lbl.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i> بارکردن...';
  try{
    const url = await uploadReceiptFile(file, order.user_id, 'payout');
    const {error} = await sb.from('ex_orders').update({payout_receipt_url:url}).eq('id',id);
    if(error) throw error;
    showToast('وێنەی پسووڵە نێردرا بۆ کڕیار','gr');
    refreshOrdersEverywhere();
    showOrderDetail(id);
  }catch(e){
    showToast('هەڵە: '+e.message,'rd');
    if(lbl) lbl.innerHTML = '<i class="fas fa-upload"></i> ناردنی وێنەی پسووڵە بۆ کڕیار';
  }
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
  const {error} = await sb.from('ex_orders').update({status:STATUS_REJECTED, admin_note: reason || null, decided_at:new Date().toISOString()}).eq('id',id);
  btn.disabled=false;
  if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
  showToast('ئۆردەرەکە ڕەتکرایەوە','rd');
  closeMo('moRejectReason'); closeMo('moOrderDetail');
  refreshOrdersEverywhere();
}
async function saveOrderNote(id){
  const note=document.getElementById('odNote').value.trim();
  const {error} = await sb.from('ex_orders').update({admin_note: note || null}).eq('id',id);
  if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
  showToast('تێبینی پاشەکەوتکرا','gr');
  refreshOrdersEverywhere();
}
function refreshOrdersEverywhere(){
  loadDashboardStats();
  if(_curPage==='orders') loadOrders(); else loadDashOrders();
}

// ── Original admin module 3 ──
// ══════════════════════════════════════════════════════════════
// ═══ ACCOUNTS ════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
async function loadAccounts(){
  document.getElementById('accountsTableWrap').innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const {data,error} = await sb.from('ex_profiles').select('*').order('created_at',{ascending:false}).limit(300);
    if(error) throw error;
    allAccounts = data||[];
    await loadAccountIps();     // one round-trip for every account's last IP
    renderAccounts();
  }catch(e){
    document.getElementById('accountsTableWrap').innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
  }
}
function filterAccounts(el){
  if(el){ document.querySelectorAll('[data-af]').forEach(x=>x.classList.remove('on')); el.classList.add('on'); accFilter=el.dataset.af; }
  renderAccounts((document.getElementById('accSearch')?.value||'').toLowerCase());
}
function renderAccounts(q=''){
  let list=allAccounts;
  if(accFilter==='banned') list=list.filter(a=>a.is_banned);
  if(accFilter==='admin') list=list.filter(a=>a.is_admin);
  if(q) list=list.filter(a=>(a.full_name||'').toLowerCase().includes(q)||(a.email||'').toLowerCase().includes(q));
  document.getElementById('accountsTableWrap').innerHTML = renderAccTable(list) + renderAccCards(list);
}
function accBadges(a){
  let b='';
  b += a.is_banned ? '<span class="badge banned">بۆیکۆتکراو</span>' : '<span class="badge active">چالاک</span>';
  if(a.is_admin) b += ' <span class="badge admin">ئادمین</span>';
  return b;
}
function renderAccTable(list){
  if(!list.length) return '<div class="empty"><i class="fas fa-user-slash"></i><p>هیچ هەژمارێک نییە</p></div>';
  return `<table><thead><tr><th>بەکارهێنەر</th><th>مۆبایل</th><th>IP و ئامێر</th><th>باری</th><th>بەرواری تۆمارکردن</th><th>کردار</th></tr></thead><tbody>
    ${list.map(a=>`<tr>
      <td><div class="user-cell"><div class="mini-av">${(a.full_name||a.email||'?')[0].toUpperCase()}</div><div><div class="user-cell-name">${esc(a.full_name||'—')}</div><div class="user-cell-email">${esc(a.email||'—')}</div></div></div></td>
      <td style="direction:ltr;font-size:12px">${esc(a.phone||'—')}</td>
      <td>${accIpCell(a.id)}</td>
      <td>${accBadges(a)}</td>
      <td class="ai-when"><b dir="ltr">${fmtDate(a.created_at)}</b><span dir="ltr">${fmtTime(a.created_at)}</span><div>${fmtAgo(a.created_at)}</div></td>
      <td><div class="act-grp">
        <div class="act-btn bl" onclick="openAccountInfo('${a.id}')"><i class="fas fa-circle-info"></i> زانیاری</div>
        <div class="act-btn dark" onclick="openSetPasswordModal('${a.id}','${esc(a.email||'').replace(/'/g,"\\'")}')"><i class="fas fa-key"></i> گۆڕینی وشەی نهێنی</div>
        <div class="act-btn ${a.is_banned?'gr':'rd'}" onclick="toggleBan('${a.id}',${a.is_banned})"><i class="fas fa-${a.is_banned?'user-check':'user-slash'}"></i> ${a.is_banned?'لابردنی بۆیکۆت':'بۆیکۆتکردن'}</div>
        <div class="act-btn ${a.is_admin?'yw':'cy'}" onclick="toggleAdmin('${a.id}',${a.is_admin})"><i class="fas fa-shield"></i> ${a.is_admin?'لابردنی ئادمین':'کردن بە ئادمین'}</div>
      </div></td>
    </tr>`).join('')}
  </tbody></table>`;
}
function renderAccCards(list){
  if(!list.length) return '';
  return `<div class="rec-cards">${list.map(a=>`
    <div class="rec-card" style="cursor:default">
      <div class="rec-card-top">
        <div class="mini-av">${(a.full_name||a.email||'?')[0].toUpperCase()}</div>
        <div class="rec-card-info"><div class="rec-card-name">${esc(a.full_name||'بێ ناو')}</div><div class="rec-card-sub">${esc(a.email||'—')}</div></div>
      </div>
      <div class="rec-card-meta">${accBadges(a)}<div class="rec-card-date" dir="ltr">${fmtDateTime(a.created_at)}</div></div>
      <div class="rec-card-actions g3">
        <div class="act-btn bl" onclick="openAccountInfo('${a.id}')"><i class="fas fa-circle-info"></i> زانیاری</div>
        <div class="act-btn dark" onclick="openSetPasswordModal('${a.id}','${esc(a.email||'').replace(/'/g,"\\'")}')"><i class="fas fa-key"></i> وشەی نهێنی</div>
        <div class="act-btn ${a.is_banned?'gr':'rd'}" onclick="toggleBan('${a.id}',${a.is_banned})"><i class="fas fa-${a.is_banned?'user-check':'user-slash'}"></i> ${a.is_banned?'لابردنی بۆیکۆت':'بۆیکۆت'}</div>
        <div class="act-btn ${a.is_admin?'yw':'cy'}" onclick="toggleAdmin('${a.id}',${a.is_admin})"><i class="fas fa-shield"></i> ${a.is_admin?'لابردنی ئادمین':'کردن بە ئادمین'}</div>
      </div>
    </div>`).join('')}</div>`;
}

// ══════════════════════════════════════════════════════════════
// ═══ ACCOUNT INFO ════════════════════════════════════════════════
// Injected from JS so no change to exchange-admin.html is needed.
// ══════════════════════════════════════════════════════════════
function ensureAccountInfoModal(){
  if(document.getElementById('moAccountInfo')) return;
  const o=document.createElement('div');
  o.className='overlay'; o.id='moAccountInfo';
  o.innerHTML=`<div class="modal" style="max-width:560px">
      <div class="modal-hdr">
        <h3 id="aiTitle">زانیاری هەژمار</h3>
        <div class="modal-close" onclick="closeMo('moAccountInfo')"><i class="fas fa-xmark"></i></div>
      </div>
      <div id="aiBody"></div>
    </div>`;
  document.body.appendChild(o);
  o.addEventListener('click', e=>{ if(e.target===o) closeMo('moAccountInfo'); });
}

async function openAccountInfo(id){
  const a=allAccounts.find(x=>x.id===id);
  if(!a){ showToast('هەژمارەکە نەدۆزرایەوە','rd'); return; }
  ensureAccountInfoModal();
  document.getElementById('aiTitle').textContent=a.full_name||a.email||'زانیاری هەژمار';

  const base=`
    <div class="ai-sec">زانیاری بنەڕەتی</div>
    <div class="detail-row"><div class="lbl">ناوی تەواو</div><div class="val" dir="rtl">${esc(a.full_name||'—')}</div></div>
    <div class="detail-row"><div class="lbl">ئیمەیل</div><div class="val">${esc(a.email||'—')}</div></div>
    <div class="detail-row"><div class="lbl">ژمارەی مۆبایل</div><div class="val">${esc(a.phone||'—')}</div></div>
    <div class="detail-row"><div class="lbl">باری هەژمار</div><div class="val" dir="rtl">${accBadges(a)}</div></div>
    <div class="detail-row"><div class="lbl">بەرواری تۆمارکردن</div><div class="val">${fmtDate(a.created_at)}</div></div>
    <div class="detail-row"><div class="lbl">کاتی تۆمارکردن</div><div class="val">${fmtTime(a.created_at)||'—'}</div></div>
    <div class="detail-row"><div class="lbl">تەمەنی هەژمار</div><div class="val" dir="rtl">${fmtAgo(a.created_at)||'—'}</div></div>
    <div class="detail-row"><div class="lbl">ئایدی بەکارهێنەر</div><div class="val" style="font-size:11px">${esc(a.id)}</div></div>`;

  document.getElementById('aiBody').innerHTML = base +
    `<div class="ai-sec">چالاکی</div><div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>`;
  openMo('moAccountInfo');

  const [ordersRes, ipsRes] = await Promise.all([
    sb.from('ex_orders').select('status,total,created_at').eq('user_id',id).order('created_at',{ascending:false}),
    securityRequest('user-ips',{query:'&user_id='+encodeURIComponent(id)+'&limit=5'}).catch(()=>({ips:[]}))
  ]);

  const orders = ordersRes.data||[];
  const n  = s => orders.filter(o=>o.status===s).length;
  const volume = orders.filter(o=>o.status===STATUS_APPROVED)
                       .reduce((s,o)=>s+(parseFloat(o.total)||0),0);
  const last = orders[0];

  let html = base + `
    <div class="ai-sec">چالاکی داواکارییەکان</div>
    <div class="ai-stats">
      <div class="ai-stat"><b>${formatNum(orders.length)}</b><span>کۆی داواکاری</span></div>
      <div class="ai-stat yw"><b>${formatNum(n(STATUS_PENDING))}</b><span>چاوەڕوان</span></div>
      <div class="ai-stat gr"><b>${formatNum(n(STATUS_APPROVED))}</b><span>پەسەندکراو</span></div>
      <div class="ai-stat rd"><b>${formatNum(n(STATUS_REJECTED))}</b><span>ڕەتکراو</span></div>
    </div>
    <div class="detail-row" style="margin-top:10px"><div class="lbl">کۆی گۆڕینەوەی پەسەندکراو</div><div class="val">${formatNum(volume)} IQD</div></div>
    <div class="detail-row"><div class="lbl">دوایین داواکاری</div><div class="val">${last?fmtDateTime(last.created_at):'—'}</div></div>`;

  const ips = ipsRes.ips||[];
  html += `<div class="ai-sec">IP و ئامێر</div>`;
  if(!ips.length){
    html += `<div class="fee-toggle-note">هیچ IPـیەک بۆ ئەم هەژمارە تۆمار نەکراوە.</div>`;
  }else{
    html += ips.map(r=>`
      <div class="detail-row">
        <div class="lbl" style="flex:1;min-width:0">
          <span class="ip-chip ${r.is_banned?'banned':''}">${esc(r.ip_address)}</span>
          <div style="font-size:10.5px;margin-top:4px">${esc(r.browser||'—')} · ${esc(r.os||'')} · ${esc(r.device||'')}</div>
        </div>
        <div class="val" style="font-size:11px">${r.events} ڕووداو<br>${fmtDateTime(r.last_seen)}</div>
      </div>`).join('');
  }

  document.getElementById('aiBody').innerHTML = html;
}
function toggleBan(id, current){
  const next=!current;
  confirm2(next?'بۆیکۆتکردنی هەژمار':'لابردنی بۆیکۆت', next?'ئایا دڵنیایت لە بۆیکۆتکردنی ئەم هەژمارە؟ ناتوانێت بچێتە ژوورەوە.':'ئایا دڵنیایت لە لابردنی بۆیکۆت؟',
    'fas fa-user-slash','var(--rd)', async()=>{
    const {error} = await sb.from('ex_profiles').update({is_banned:next}).eq('id',id);
    if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
    showToast(next?'هەژمار بۆیکۆتکرا':'بۆیکۆت لابرا', next?'rd':'gr');
    loadAccounts(); loadDashboardStats();
  });
}
function toggleAdmin(id, current){
  const next=!current;
  const selfWarn = (adminUser && id===adminUser.id && !next) ? ' — ئاگاداری: ئەمە هەژماری خۆتە!' : '';
  confirm2(next?'کردن بە ئادمین':'لابردنی ئادمین', (next?'ئایا دەتەوێت مافی ئادمین بدەیت بەم هەژمارە؟':'ئایا دەتەوێت مافی ئادمین لاببەیت؟')+selfWarn,
    'fas fa-shield-halved','var(--cy)', async()=>{
    const {error} = await sb.from('ex_profiles').update({is_admin:next}).eq('id',id);
    if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
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
  password_too_short:    'وشەی نهێنی دەبێت لانیکەم ٨ پیت/ژمارە بێت',
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
    if(e.name === 'AbortError') throw new Error('سێرڤەر وەڵامی نەدایەوە (٢٥ چرکە) — دووبارە هەوڵبدەوە');
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
  document.getElementById('spUserId').value = userId;
  document.getElementById('spUserLabel').textContent = email || '—';
  document.getElementById('spNewPass').value = '';
  document.getElementById('spNewPass2').value = '';
  document.getElementById('spErr').style.display='none';
  setSpVisibility(false);
  openMo('moSetPassword');
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
  errEl.style.display='none';
  const userId = document.getElementById('spUserId').value;
  const pass = document.getElementById('spNewPass').value;
  const pass2 = document.getElementById('spNewPass2').value;
  if(!userId){ errEl.textContent='بەکارهێنەر دیاری نەکراوە — پەنجەرەکە دابخە و دووبارە هەوڵبدەوە'; errEl.style.display='block'; return; }
  if(pass.length < 8){ errEl.textContent='وشەی نهێنی دەبێت لانیکەم ٨ پیت/ژمارە بێت'; errEl.style.display='block'; return; }
  if(pass !== pass2){ errEl.textContent='وشەکانی نهێنی وەک یەک نین'; errEl.style.display='block'; return; }
  const btn = document.getElementById('spSaveBtn');
  btn.disabled = true; btn.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    const data = await callAdminFn('admin-set-password', { target_user_id:userId, new_password:pass });
    closeMo('moSetPassword');
    let msg = '✅ وشەی نهێنی گۆڕدرا';
    if(data.sessions_revoked > 0) msg += ' — '+data.sessions_revoked+' ئامێری چوونەژوورەوە بڕدرایەوە';
    showToast(msg,'gr');
    if(data.warning) console.warn('admin-set-password warning:', data.warning);
  }catch(e){
    errEl.textContent = e.message; errEl.style.display='block';
    console.error('admin-set-password failed:', e);
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-check"></i> پاشەکەوتکردن';
  }
}

// ══════════════════════════════════════════════════════════════
// ═══ ADMIN: CREATE USER (via secure Edge Function) ══════════════
// ══════════════════════════════════════════════════════════════
function openCreateUserModal(){
  document.getElementById('cuName').value = '';
  document.getElementById('cuEmail').value = '';
  document.getElementById('cuPhone').value = '';
  document.getElementById('cuPass').value = '';
  document.getElementById('cuIsAdmin').checked = false;
  document.getElementById('cuErr').style.display='none';
  openMo('moCreateUser');
}
async function submitCreateUser(){
  const errEl = document.getElementById('cuErr');
  errEl.style.display='none';
  const full_name = document.getElementById('cuName').value.trim();
  const email = document.getElementById('cuEmail').value.trim();
  const phone = document.getElementById('cuPhone').value.trim();
  const password = document.getElementById('cuPass').value;
  const is_admin = document.getElementById('cuIsAdmin').checked;
  if(!email || !email.includes('@')){ errEl.textContent='ئیمەیلێکی دروست بنووسە'; errEl.style.display='block'; return; }
  if(password.length < 8){ errEl.textContent='وشەی نهێنی دەبێت لانیکەم ٨ پیت/ژمارە بێت'; errEl.style.display='block'; return; }
  const btn = document.getElementById('cuSaveBtn');
  btn.disabled = true; btn.innerHTML = '<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    await callAdminFn('admin-create-user', { email, password, full_name, phone, is_admin });
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
    const {data,error} = await sb.from('ex_rates').select('*').order('from_method').order('to_method');
    if(error) throw error;
    allRates = data||[];
    renderRates();
  }catch(e){
    document.getElementById('ratesTableWrap').innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
  }
  subscribeRatesAdmin();
}
function subscribeRatesAdmin(){
  if(_ratesAdminChannel) return;
  _ratesAdminChannel = sb.channel('ex_rates_admin')
    .on('postgres_changes', {event:'*',schema:'public',table:'ex_rates'}, ()=>{ if(_curPage==='rates') loadRates(); })
    .subscribe();
}
// Method options for the rate From/To selects: the original fixed methods (kept so
// existing rates like Korek/USDT — which have no ex_wallets row — still edit correctly)
// merged live with whatever wallets exist in ex_wallets, so a newly-added wallet shows
// up here automatically without any code change.
function buildMethodLabelMap(){
  const map=new Map();
  ALL_METHODS.forEach(k=>map.set(k, (METHOD_META[k]&&METHOD_META[k].label)||k));
  allWallets.forEach(w=>{ if(w.key) map.set(w.key, w.name||w.key); });
  return map;
}
function buildFromMethodKeys(){
  const set=new Set(ALL_METHODS);
  allWallets.forEach(w=>{ if(w.key && w.allow_from!==false) set.add(w.key); });
  return [...set];
}
function buildToMethodKeys(){
  const set=new Set(RECEIVE_METHODS);
  allWallets.forEach(w=>{ if(w.key && w.allow_receive===true) set.add(w.key); });
  return [...set];
}
function rateTypeLabel(t){ return t==='fee_percent' ? 'حمولە %' : t==='fee_fixed' ? 'حمولەی جێگیر' : 'مەزراپ'; }
function renderRates(){
  if(!allRates.length){ document.getElementById('ratesTableWrap').innerHTML='<div class="empty"><i class="fas fa-percent"></i><p>هیچ ڕێگایەک زیاد نەکراوە</p></div>'; return; }
  document.getElementById('ratesTableWrap').innerHTML = `<table><thead><tr><th>لە</th><th>بۆ</th><th>جۆر</th><th>بەها</th><th>چالاک</th><th>کردار</th></tr></thead><tbody>
    ${allRates.map(r=>`<tr>
      <td>${methodPill(r.from_method)}</td>
      <td>${methodPill(r.to_method)}</td>
      <td style="font-size:12px">${rateTypeLabel(r.rate_type)}</td>
      <td style="font-family:'Inter';font-weight:800;direction:ltr;text-align:right">${r.rate_type==='multiplier' && Number(r.rate_value)<1
        ? `×${esc(r.rate_value)} <span style="font-family:'R';font-size:10.5px;font-weight:700;color:var(--mt2)">(${esc(fmtPairValue(r.rate_type,r.rate_value))})</span>`
        : esc(fmtPairValue(r.rate_type,r.rate_value))}</td>
      <td><label class="mswitch"><input type="checkbox" ${r.is_active?'checked':''} onchange="toggleRateActive('${r.id}',this.checked)"><span class="track"></span></label></td>
      <td><div class="act-grp">
        <div class="act-btn dark" onclick='openRateModal(${safeAttr(r)})'><i class="fas fa-pen"></i></div>
        <div class="act-btn rd" onclick="deleteRate('${r.id}')"><i class="fas fa-trash"></i></div>
      </div></td>
    </tr>`).join('')}
  </tbody></table>`;
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
    document.getElementById('rateType').value='multiplier';
    document.getElementById('rateValue').value='';
    document.getElementById('rateActive').checked=true;
  }
  updateRateValueHint();
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
  const from=document.getElementById('rateFrom').value, to=document.getElementById('rateTo').value;
  const rate_type=document.getElementById('rateType').value;
  const rate_value=parseFloat(document.getElementById('rateValue').value);
  const is_active=document.getElementById('rateActive').checked;
  if(from===to){ showToast('نابێت لە و بۆ یەکسان بن','rd'); return; }
  if(isNaN(rate_value)){ showToast('بەهای دروست بنووسە','rd'); return; }
  const btn=document.getElementById('rateSaveBtn'); btn.disabled=true;
  let error;
  if(id){
    ({error} = await sb.from('ex_rates').update({from_method:from,to_method:to,rate_type,rate_value,is_active}).eq('id',id));
  }else{
    ({error} = await sb.from('ex_rates').insert({from_method:from,to_method:to,rate_type,rate_value,is_active}));
  }
  btn.disabled=false;
  if(error){ await handleDbWriteError(error); return; }
  showToast('پاشەکەوتکرا','gr');
  closeMo('moRate');
  loadRates();
}

// ── Original admin module 4 ──
// ══════════════════════════════════════════════════════════════
// ═══ WALLETS ═════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
let allWallets=[];
let _walletsAdminChannel=null;

async function loadWalletsAdmin(){
  document.getElementById('walletsGridWrap').innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const {data,error} = await sb.from('ex_wallets').select('*').order('sort_order',{ascending:true});
    if(error) throw error;
    allWallets = data||[];
    await loadPairs();
    renderWalletsGrid();
  }catch(e){
    document.getElementById('walletsGridWrap').innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p><p style="font-size:11px;margin-top:6px">دڵنیابەرەوە خشتەی ex_wallets دروستکراوە (بڕوانە SQL پێشکەشکراو)</p></div>`;
  }
  subscribeWalletsAdmin();
}
function subscribeWalletsAdmin(){
  if(_walletsAdminChannel) return;
  const refreshWalletsPage = ()=>{
    if(_curPage!=='wallets') return;
    // don't yank data out from under an admin who is mid-edit
    if(document.getElementById('moWallet').classList.contains('on')) return;
    loadWalletsAdmin();
  };
  _walletsAdminChannel = sb.channel('ex_wallets_admin')
    .on('postgres_changes', {event:'*',schema:'public',table:'ex_wallets'}, refreshWalletsPage)
    .on('postgres_changes', {event:'*',schema:'public',table:'ex_rates'}, refreshWalletsPage)
    .subscribe();
}
function renderWalletsGrid(){
  const wrap=document.getElementById('walletsGridWrap');
  if(!allWallets.length){ wrap.innerHTML='<div class="empty"><i class="fas fa-wallet"></i><p>هیچ واڵێتێک زیاد نەکراوە</p></div>'; return; }
  wrap.innerHTML = allWallets.map(w=>{
    const avatarInner = w.image_url ? `<img src="${esc(w.image_url)}" alt="">` : `<i class="fas fa-wallet"></i>`;
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
        ${w.allow_from!==false?'<span class="wallet-card-badge"><i class="fas fa-arrow-up"></i> ناردن چالاکە</span>':''}
        ${w.allow_receive?'<span class="wallet-card-badge gr"><i class="fas fa-arrow-down"></i> وەرگرتن چالاکە</span>':''}
        ${w.price!=null?`<span class="wallet-card-badge">نرخ: ${esc(w.price)}</span>`:''}
        ${w.fee!=null?`<span class="wallet-card-badge">کرێ: ${esc(w.fee)}${w.fee_type==='percent'?'%':' د.ع'}</span>`:''}
      </div>
      ${walletPairsHTML(w)}
      <div class="act-grp">
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
function openWalletModal(w){
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
  }
  document.getElementById('walletImgFile').value='';
  document.getElementById('pairBulkValue').value='';
  buildPairDraft(w);
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
  const allow_receive=document.getElementById('walletCanReceive').checked;
  const is_locked=document.getElementById('walletLocked').checked;
  if(!name){ showToast('ناوی واڵێت بنووسە','rd'); return; }
  if(!key){ showToast('کلیلی واڵێت بنووسە','rd'); return; }
  if(!allow_from && !allow_receive){ showToast('پێویستە لانیکەم یەکێک لە «ناردن» یان «وەرگرتن» چالاک بێت','rd'); return; }
  const btn=document.getElementById('walletSaveBtn'); btn.disabled=true;
  const payload={ name, key, wallet_number: wallet_number||null, image_url, price, fee, fee_type, allow_from, allow_receive, is_locked };
  let error;
  if(id){
    ({error} = await sb.from('ex_wallets').update(payload).eq('id',id));
  }else{
    payload.sort_order = allWallets.length ? Math.max(...allWallets.map(w=>w.sort_order||0))+1 : 1;
    ({error} = await sb.from('ex_wallets').insert(payload));
  }
  if(error){ btn.disabled=false; await handleDbWriteError(error); return; }
  await syncWalletPairs(key, id ? _walletOldKey : '');
  btn.disabled=false;
  showToast('پاشەکەوتکرا','gr');
  closeMo('moWallet');
  loadWalletsAdmin();
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
function walletLabelFor(key){
  const w=allWallets.find(x=>x.key===key);
  return w ? (w.name||key) : ((METHOD_META[key]&&METHOD_META[key].label)||key);
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
    ? arr.map(r=>`<span class="pair-chip">${esc(walletLabelFor(pick(r)))} · <b>${esc(fmtPairValue(r.rate_type,r.rate_value))}</b></span>`).join('')
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
  allWallets.forEach(o=>{
    if(w && o.id===w.id) return;
    const ro = allPairs.find(r=>r.from_method===_pairSelfKey && r.to_method===o.key);
    const ri = allPairs.find(r=>r.from_method===o.key && r.to_method===_pairSelfKey);
    _pairDraft.out[o.key] = ro ? {on:!!ro.is_active, type:ro.rate_type, value:String(ro.rate_value)} : {on:false,type:'fee_percent',value:''};
    _pairDraft.in[o.key]  = ri ? {on:!!ri.is_active, type:ri.rate_type, value:String(ri.rate_value)} : {on:false,type:'fee_percent',value:''};
  });
  switchPairTab('out');
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
      </div><small class="pair-hint" id="pairHint-${esc(o.key)}" style="display:block;font-size:10.5px;color:var(--mt);margin-top:5px">${pairHintText(st)}</small>`:''}
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
function setPairType(key,t){ if(_pairDraft[_pairTab][key]){ _pairDraft[_pairTab][key].type=t; refreshPairHint(key); } }
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
  keys.forEach(k=>{ _pairDraft[_pairTab][k]={on:true,type:t,value:v}; });
  renderPairList();
  showToast('بۆ هەموو واڵێتەکانی ئەم ئاراستەیە دانرا','gr');
}
// Writes the matrix back to ex_rates. Closed directions keep their row with
// is_active=false so the fee is still there when they're re-opened later.
async function syncWalletPairs(newKey, oldKey){
  if(oldKey && oldKey!==newKey){
    await sb.from('ex_rates').update({from_method:newKey}).eq('from_method',oldKey);
    await sb.from('ex_rates').update({to_method:newKey}).eq('to_method',oldKey);
  }
  const known = allPairs.map(r=>({
    from_method: (oldKey && r.from_method===oldKey) ? newKey : r.from_method,
    to_method:   (oldKey && r.to_method===oldKey)   ? newKey : r.to_method,
    rate_type:r.rate_type, rate_value:r.rate_value
  }));
  const rows=[]; let skipped=0;
  const push=(f,t,st)=>{
    if(!f||!t||f===t) return;
    const prev=known.find(r=>r.from_method===f && r.to_method===t);
    if(st.on){
      const val=parseFloat(st.value);
      if(isNaN(val)){ skipped++; return; }
      rows.push({from_method:f,to_method:t,rate_type:st.type,rate_value:val,is_active:true});
    }else if(prev){
      rows.push({from_method:f,to_method:t,rate_type:prev.rate_type,rate_value:prev.rate_value,is_active:false});
    }
  };
  Object.keys(_pairDraft.out).forEach(k=>push(newKey,k,_pairDraft.out[k]));
  Object.keys(_pairDraft.in).forEach(k=>push(k,newKey,_pairDraft.in[k]));
  if(rows.length){
    const {error} = await sb.from('ex_rates').upsert(rows,{onConflict:'from_method,to_method'});
    if(error){ await handleDbWriteError(error); return false; }
  }
  if(skipped) showToast(skipped+' ڕێگا پاشەکەوت نەکرا — بەهای حمولەی بۆ نەنووسرابوو','rd');
  return true;
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
    const {data} = await sb.from('ex_profiles').select('id,full_name,email').or(`full_name.ilike.%${q}%,email.ilike.%${q}%`).limit(6);
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
      <td>${b.pending_count>0?`<span class="badge banned">${b.pending_count}</span>`:'<span class="badge active">٠</span>'}</td>
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

// ══════════════════════════════════════════════════════════════
// ═══ ANNOUNCEMENT BANNER (Firebase) ═════════════════════════════
// ══════════════════════════════════════════════════════════════
function renderAnnItemRow(item){
  item = item || {};
  const action = item.action || {type:'none'};
  const wrap=document.getElementById('annItemsWrap');
  const labelMap = buildMethodLabelMap();
  const fromKeys = buildFromMethodKeys(), toKeys = buildToMethodKeys();
  const fromOpts = fromKeys.map(k=>`<option value="${esc(k)}" ${action.from===k?'selected':''}>${esc(labelMap.get(k)||k)}</option>`).join('');
  const toOpts = `<option value="">— دیاری مەکە —</option>` + toKeys.map(k=>`<option value="${esc(k)}" ${action.to===k?'selected':''}>${esc(labelMap.get(k)||k)}</option>`).join('');
  const row=document.createElement('div');
  row.className='ann-item-row';
  row.style.cssText='border:1px solid var(--b1);border-radius:12px;padding:12px;margin-bottom:12px';
  row.innerHTML = `
    <div style="display:flex;gap:8px;align-items:flex-start;margin-bottom:10px">
      <textarea class="minp mta ann-item-text" style="flex:1" placeholder="دەقی ئاگادارییەک بنووسە...">${esc(item.text||'')}</textarea>
      <div class="act-btn rd" onclick="this.closest('.ann-item-row').remove()"><i class="fas fa-trash"></i></div>
    </div>
    <label class="modal-lbl" style="margin-top:0">کردار کاتێک بەکارهێنەر کلیکی لێدەکات</label>
    <select class="msel ann-item-action-type" onchange="updateAnnItemActionUI(this)">
      <option value="none" ${action.type==='none'?'selected':''}>هیچ (کلیک ناکات)</option>
      <option value="url" ${action.type==='url'?'selected':''}>کردنەوەی لینک</option>
      <option value="wallet" ${action.type==='wallet'?'selected':''}>دیاریکردنی ناردن/وەرگرتن لە فۆرمی گۆڕینەوە</option>
    </select>
    <div class="ann-item-url-wrap" style="display:${action.type==='url'?'':'none'};margin-top:8px">
      <input class="minp ann-item-url" dir="ltr" placeholder="https://..." value="${esc(action.url||'')}">
    </div>
    <div class="ann-item-wallet-wrap" style="display:${action.type==='wallet'?'':'none'};margin-top:8px">
      <div class="modal-row">
        <div>
          <label class="modal-lbl">ناردن لە (پێویستە)</label>
          <select class="msel ann-item-from">${fromOpts}</select>
        </div>
        <div>
          <label class="modal-lbl">وەرگرتن لە (ئارەزوومەندانە)</label>
          <select class="msel ann-item-to">${toOpts}</select>
        </div>
      </div>
    </div>`;
  wrap.appendChild(row);
}
function updateAnnItemActionUI(sel){
  const row = sel.closest('.ann-item-row');
  row.querySelector('.ann-item-url-wrap').style.display = sel.value==='url' ? '' : 'none';
  row.querySelector('.ann-item-wallet-wrap').style.display = sel.value==='wallet' ? '' : 'none';
}
function addAnnItem(){ renderAnnItemRow({}); }
async function loadAnnouncement(){
  try{
    if(!allWallets.length) await loadWalletsAdmin();
    const snap = await fbdb.ref('announcement').once('value');
    const val = snap.val() || {};
    document.getElementById('annShow').checked = !!val.show;
    document.getElementById('annInterval').value = val.interval || 5;
    const wrap=document.getElementById('annItemsWrap'); wrap.innerHTML='';
    // supports both the new {items:[{text,action}]} shape and the old single {text} shape
    let items = Array.isArray(val.items)
      ? val.items.map(x=> (typeof x==='string') ? {text:x} : {text:(x&&x.text)||'', action:(x&&x.action)||{type:'none'}})
      : (val.text ? [{text:val.text}] : []);
    if(!items.length) items=[{}];
    items.forEach(it=>renderAnnItemRow(it));
  }catch(e){ showToast('هەڵەی بارکردنی بانەر: '+e.message,'rd'); }
}
async function saveAnnouncement(){
  const show=document.getElementById('annShow').checked;
  let interval=parseInt(document.getElementById('annInterval').value,10);
  if(isNaN(interval)||interval<2) interval=5;
  const items=[];
  document.querySelectorAll('.ann-item-row').forEach(row=>{
    const text=row.querySelector('.ann-item-text').value.trim();
    if(!text) return;
    const type=row.querySelector('.ann-item-action-type').value;
    let action={type:'none'};
    if(type==='url'){
      const url=row.querySelector('.ann-item-url').value.trim();
      if(url) action={type:'url', url};
    }else if(type==='wallet'){
      const from=row.querySelector('.ann-item-from').value;
      const to=row.querySelector('.ann-item-to').value;
      if(from){ action={type:'wallet', from}; if(to) action.to=to; }
    }
    items.push({text, action});
  });
  const btn=document.getElementById('annSaveBtn'); btn.disabled=true;
  try{
    await fbdb.ref('announcement').set({show, interval, items});
    showToast('✅ بانەر پاشەکەوتکرا','gr');
  }catch(e){
    showToast('هەڵە: '+e.message,'rd');
  }finally{ btn.disabled=false; }
}

// ── Original admin module 6 ──
// ══════════════════════════════════════════════════════════════
// ═══ OTP CODES (full admin read + edit) ════════════════════════
// All calls go through SECURITY DEFINER RPCs gated by is_ex_admin():
// ex_admin_list_otp / ex_admin_update_otp / ex_admin_create_otp /
// ex_admin_expire_otp / ex_admin_delete_otp. Every write is recorded
// in ex_admin_audit_log.
// ══════════════════════════════════════════════════════════════
let allOtp=[], otpFilter='all';
async function loadOtp(){
  const wrap=document.getElementById('otpTableWrap');
  wrap.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
  try{
    const {data,error} = await sb.rpc('ex_admin_list_otp',{p_limit:300});
    if(error) throw error;
    allOtp = data||[];
    renderOtpTable();
  }catch(e){
    wrap.innerHTML=`<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ${esc(e.message)}</p></div>`;
  }
}
function filterOtp(el){
  if(el){ document.querySelectorAll('[data-otpf]').forEach(x=>x.classList.remove('on')); el.classList.add('on'); otpFilter=el.dataset.otpf; }
  renderOtpTable();
}
function otpStatusBadge(status){
  if(status==='active') return '<span class="badge active">چالاک</span>';
  if(status==='used') return '<span class="badge approved">بەکارهاتووە</span>';
  return '<span class="badge rejected">بەسەرچووە</span>';
}
function otpPurposeLbl(p){
  return { login:'چوونەژوورەوە', signup:'خۆتۆمارکردن', reset_password:'گۆڕینی وشەی نهێنی' }[p] || (p||'—');
}
function copyOtpCode(code){
  const done=()=>showToast('کۆد کۆپی کرا: '+code,'gr');
  if(navigator.clipboard?.writeText){ navigator.clipboard.writeText(code).then(done).catch(()=>done()); }
  else{
    const t=document.createElement('textarea'); t.value=code; document.body.appendChild(t);
    t.select(); try{ document.execCommand('copy'); }catch(_){}
    document.body.removeChild(t); done();
  }
}
function renderOtpTable(){
  const q=(document.getElementById('otpSearch')?.value||'').toLowerCase().trim();
  let list=allOtp;
  if(otpFilter!=='all') list=list.filter(o=>o.status===otpFilter);
  if(q) list=list.filter(o=>(o.email||'').toLowerCase().includes(q)||(o.code||'').includes(q));
  const wrap=document.getElementById('otpTableWrap');
  if(!list.length){ wrap.innerHTML='<div class="empty"><i class="fas fa-key"></i><p>هیچ کۆدێکی OTP نییە</p></div>'; return; }
  wrap.innerHTML = `<table><thead><tr><th>ئیمەیل</th><th>کۆد</th><th>مەبەست</th><th>باری</th><th>دروستکرا</th><th>بەسەردەچێت</th><th>کردار</th></tr></thead><tbody>
    ${list.map(o=>`<tr>
      <td style="direction:ltr;font-size:12px">${esc(o.email||'—')}</td>
      <td><span onclick="copyOtpCode('${esc(o.code||'')}')" title="کلیک بۆ کۆپیکردن" style="direction:ltr;display:inline-block;font-family:monospace;font-size:14px;font-weight:800;letter-spacing:2px;color:var(--dark);background:var(--bg);border:1.5px solid var(--b1);border-radius:8px;padding:4px 10px;cursor:pointer">${esc(o.code||'—')}</span></td>
      <td style="font-size:12px">${otpPurposeLbl(o.purpose)}</td>
      <td>${otpStatusBadge(o.status)}</td>
      <td style="font-size:11px;color:var(--mt)">${new Date(o.created_at).toLocaleString('ku')}</td>
      <td style="font-size:11px;color:var(--mt)">${new Date(o.expires_at).toLocaleString('ku')}</td>
      <td><div class="act-grp">
        <div class="act-btn cy" onclick='openOtpEditModal(${safeAttr(o)})'><i class="fas fa-pen"></i> دەستکاری</div>
        <div class="act-btn yw" ${o.status!=='active'?'style="opacity:.4;pointer-events:none"':''} onclick="otpForceExpire('${o.id}')"><i class="fas fa-hourglass-end"></i> بەسەرببە</div>
        <div class="act-btn rd" onclick="otpDelete('${o.id}')"><i class="fas fa-trash"></i> سڕینەوە</div>
      </div></td>
    </tr>`).join('')}
  </tbody></table>`;
}

// ─── datetime-local <-> ISO helpers (input works in local time) ───
function toLocalInput(iso){
  const d=new Date(iso); if(isNaN(d)) return '';
  const p=n=>String(n).padStart(2,'0');
  return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}
function fromLocalInput(v){ if(!v) return null; const d=new Date(v); return isNaN(d)?null:d.toISOString(); }

function openOtpEditModal(o){
  document.getElementById('oeId').value = o.id;
  document.getElementById('oeEmail').textContent = o.email || '—';
  document.getElementById('oeCode').value = o.code || '';
  const purposeSel=document.getElementById('oePurpose');
  if(o.purpose && !Array.from(purposeSel.options).some(x=>x.value===o.purpose)){
    purposeSel.add(new Option(o.purpose, o.purpose));
  }
  purposeSel.value = o.purpose || 'login';
  document.getElementById('oeExpires').value = toLocalInput(o.expires_at);
  document.getElementById('oeIsUsed').checked = !!o.is_used;
  document.getElementById('oeErr').style.display='none';
  openMo('moOtpEdit');
}
function bumpOtpExpiry(mins){
  const d=new Date(Date.now()+mins*60000);
  document.getElementById('oeExpires').value = toLocalInput(d.toISOString());
  document.getElementById('oeIsUsed').checked = false;
}
async function submitOtpEdit(){
  const errEl=document.getElementById('oeErr'); errEl.style.display='none';
  const id=document.getElementById('oeId').value;
  const code=document.getElementById('oeCode').value.trim();
  const purpose=document.getElementById('oePurpose').value;
  const expires=fromLocalInput(document.getElementById('oeExpires').value);
  const isUsed=document.getElementById('oeIsUsed').checked;
  if(!code){ errEl.textContent='کۆد نابێت بەتاڵ بێت'; errEl.style.display='block'; return; }
  if(!expires){ errEl.textContent='کاتی بەسەرچوون دروست نییە'; errEl.style.display='block'; return; }
  const btn=document.getElementById('oeSaveBtn');
  btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    const {error} = await sb.rpc('ex_admin_update_otp',{
      p_id:id, p_code:code, p_purpose:purpose, p_expires_at:expires, p_is_used:isUsed
    });
    if(error) throw error;
    closeMo('moOtpEdit');
    showToast('کۆدەکە نوێکرایەوە','gr');
    loadOtp();
  }catch(e){
    errEl.textContent='هەڵە: '+e.message; errEl.style.display='block';
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-check"></i> پاشەکەوتکردن';
  }
}

function openOtpCreateModal(){
  document.getElementById('ocEmail').value='';
  document.getElementById('ocCode').value='';
  document.getElementById('ocPurpose').value='login';
  document.getElementById('ocMinutes').value=10;
  document.getElementById('ocErr').style.display='none';
  openMo('moOtpCreate');
}
function genOtpCode(){
  document.getElementById('ocCode').value = String(Math.floor(100000+Math.random()*900000));
}
async function submitOtpCreate(){
  const errEl=document.getElementById('ocErr'); errEl.style.display='none';
  const email=document.getElementById('ocEmail').value.trim();
  const code=document.getElementById('ocCode').value.trim();
  const purpose=document.getElementById('ocPurpose').value;
  const mins=parseInt(document.getElementById('ocMinutes').value,10)||10;
  if(!email||!email.includes('@')){ errEl.textContent='ئیمەیلێکی دروست بنووسە'; errEl.style.display='block'; return; }
  if(!code){ errEl.textContent='کۆد بنووسە یان کۆدێکی هەڕەمەکی دروست بکە'; errEl.style.display='block'; return; }
  const btn=document.getElementById('ocSaveBtn');
  btn.disabled=true; btn.innerHTML='<i class="fas fa-circle-notch fa-spin"></i>';
  try{
    const {error} = await sb.rpc('ex_admin_create_otp',{
      p_email:email, p_code:code, p_purpose:purpose, p_minutes:mins
    });
    if(error) throw error;
    closeMo('moOtpCreate');
    showToast('کۆد دروستکرا: '+code,'gr');
    loadOtp();
  }catch(e){
    errEl.textContent='هەڵە: '+e.message; errEl.style.display='block';
  }finally{
    btn.disabled=false; btn.innerHTML='<i class="fas fa-check"></i> دروستکردن';
  }
}

function otpForceExpire(id){
  confirm2('بەسەرخستنی کۆد', 'ئەم کۆدە OTP یە دەبێتە نەچالاک و بەکارهێنەر ناتوانێت بەکاری بهێنێت — دەبێت داوای کۆدێکی نوێ بکات. ئایا دڵنیایت؟',
    'fas fa-hourglass-end','var(--yw)', async()=>{
    const {error} = await sb.rpc('ex_admin_expire_otp',{p_id:id});
    if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
    showToast('کۆدەکە بەسەرخرا','gr');
    loadOtp();
  });
}
function otpDelete(id){
  confirm2('سڕینەوەی کۆد', 'ئەم تۆمارە OTP یە بە تەواوی دەسڕدرێتەوە. ئایا دڵنیایت؟',
    'fas fa-trash','var(--rd)', async()=>{
    const {error} = await sb.rpc('ex_admin_delete_otp',{p_id:id});
    if(error){ showToast('هەڵە: '+error.message,'rd'); return; }
    showToast('تۆمارەکە سڕدرایەوە','gr');
    loadOtp();
  });
}
