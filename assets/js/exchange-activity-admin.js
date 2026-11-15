// Admin: user activity — who is on the site now, who was here, which screens
// hold people and for how long. Data: /api/admin (activity_overview,
// activity_user), super admin only. Only visible time on a screen counts.
(function(){
  'use strict';
  let data = null, days = 7, filter = 'all', pollTimer = null, busy = false;

  const e = (v) => (typeof esc === 'function' ? esc(v) : String(v == null ? '' : v));
  const num = (n) => Number(n || 0).toLocaleString('en-US');
  const toast = (m, k) => { if (typeof showToast === 'function') showToast(m, k); };
  const ROUTES = {
    home: 'سەرەکی', exchange: 'ئاڵوگۆڕ', transactions: 'مامەڵەکان', summary: 'وردەکاری مامەڵە',
    changes: 'گۆڕانکاری نرخ', rules: 'یاساکان', profile: 'پڕۆفایل', support: 'پشتگیری',
    verify: 'پشتڕاستکردنەوەی ناسنامە', balance: 'باڵانس', 'delete-account': 'سڕینەوەی هەژمار',
    'account-name': 'ناوی هەژمار', 'change-phone': 'ژمارەی مۆبایل', 'change-email': 'ئیمەیڵ',
    'change-password': 'وشەی نهێنی'
  };
  const DEVICES = { mobile: 'مۆبایل', tablet: 'تابلێت', desktop: 'کۆمپیوتەر' };
  const routeName = (r) => ROUTES[r] || r || '—';
  const NOW_MS = 2 * 60 * 1000;

  // 45 چرکە · 12 خولەک · 1 کاتژمێر و 20 خولەک
  function dur(seconds){
    const s = Math.max(0, Math.round(Number(seconds) || 0));
    if (s < 60) return s + ' چرکە';
    const m = Math.round(s / 60);
    if (m < 60) return m + ' خولەک';
    const h = Math.floor(m / 60), rest = m % 60;
    return h + ' کاتژمێر' + (rest ? ' و ' + rest + ' خولەک' : '');
  }
  // ئێستا · 5 خولەک لەمەوبەر · 3 کاتژمێر لەمەوبەر · بەروار
  function ago(t){
    if (!t) return '—';
    const ms = Date.now() - new Date(t).getTime();
    if (ms < NOW_MS) return 'ئێستا';
    const m = Math.round(ms / 60000);
    if (m < 60) return m + ' خولەک لەمەوبەر';
    const h = Math.round(m / 60);
    if (h < 24) return h + ' کاتژمێر لەمەوبەر';
    return typeof fmtDateTime === 'function' ? fmtDateTime(t) : new Date(t).toLocaleString();
  }
  const durOr = (s) => (Number(s) > 0 ? dur(s) : '—');
  const isNow = (t) => t && Date.now() - new Date(t).getTime() < NOW_MS;
  const phoneText = (p) => (p ? String(p) : '');

  async function load(){
    if (busy) return;
    busy = true;
    try {
      data = await adminApiRequest('activity_overview', { days });
      setStats();
      render();
      renderSections();
    } catch (err) {
      const msg = '<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>' + e(err && err.message) + '</p></div>';
      ['actUsers', 'actSections'].forEach(id => { const el = document.getElementById(id); if (el) el.innerHTML = msg; });
    } finally { busy = false; }
  }

  function setStats(){
    const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
    set('actNow', num(data?.active_now));
    set('actToday', num(data?.active_today));
    set('actTimeToday', dur(data?.seconds_today));
    const badge = document.getElementById('sbActiveNow');
    if (badge) { const n = Number(data?.active_now || 0); badge.textContent = n; badge.style.display = n ? '' : 'none'; }
  }

  function render(){
    const wrap = document.getElementById('actUsers');
    if (!wrap || !data) return;
    const q = (document.getElementById('actSearch')?.value || '').trim().toLowerCase();
    const rows = (data.users || []).filter(u => {
      if (filter === 'now' && !isNow(u.last_seen_at)) return false;
      if (days === 1 && !Number(u.today_seconds) && !isNow(u.last_seen_at)) return false;
      if (!q) return true;
      return [u.full_name, u.email, u.phone].some(v => String(v || '').toLowerCase().includes(q));
    });
    if (!rows.length) { wrap.innerHTML = '<div class="empty"><i class="fas fa-user-clock"></i><p>هیچ بەکارهێنەرێک نییە</p></div>'; return; }
    const windowLabel = days === 1 ? 'ئەمڕۆ' : days + ' ڕۆژ';
    wrap.innerHTML = '<table><thead><tr><th>بەکارهێنەر</th><th>دۆخ</th><th>دوایین بەش</th><th>کاتی ئەمڕۆ</th><th>کاتی ' + e(windowLabel) + '</th><th>سەردان</th><th>ئامێر</th><th></th></tr></thead><tbody>'
      + rows.map(u => '<tr>'
        + '<td class="act-user"><b>' + e(u.full_name || u.email || '—') + '</b><small>' + e([phoneText(u.phone), u.email].filter(Boolean).join(' · ')) + '</small></td>'
        + '<td><span class="act-state"><span class="act-dot' + (isNow(u.last_seen_at) ? ' on' : '') + '"></span>' + e(ago(u.last_seen_at)) + '</span></td>'
        + '<td>' + e(routeName(u.last_route)) + '</td>'
        + '<td class="act-time">' + e(durOr(u.today_seconds)) + '</td>'
        + '<td class="act-time">' + e(durOr(u.window_seconds)) + '</td>'
        + '<td style="text-align:center">' + num(u.sessions) + '</td>'
        + '<td>' + e(DEVICES[u.device] || '—') + '</td>'
        + '<td><div class="act-btn" style="font-size:12px" onclick="openActivityUser(\'' + e(u.user_id) + '\')"><i class="fas fa-chart-bar"></i> وردەکاری</div></td>'
        + '</tr>').join('')
      + '</tbody></table>';
  }

  function renderSections(){
    const wrap = document.getElementById('actSections');
    if (!wrap || !data) return;
    const rows = data.sections || [];
    if (!rows.length) { wrap.innerHTML = '<div class="empty"><i class="fas fa-layer-group"></i><p>هێشتا هیچ چالاکییەک تۆمار نەکراوە</p></div>'; return; }
    const max = Math.max(1, ...rows.map(r => Number(r.seconds) || 0));
    wrap.innerHTML = '<table><thead><tr><th>بەش</th><th>کۆی کات</th><th>بەکارهێنەر</th><th>تێکڕای کات بۆ هەر بەکارهێنەرێک</th></tr></thead><tbody>'
      + rows.map(r => '<tr>'
        + '<td><b>' + e(routeName(r.route)) + '</b><div class="act-bar"><span style="width:' + Math.max(2, Math.round((Number(r.seconds) || 0) / max * 100)) + '%"></span></div></td>'
        + '<td class="act-time">' + e(dur(r.seconds)) + '</td>'
        + '<td style="text-align:center">' + num(r.users) + '</td>'
        + '<td class="act-time">' + e(dur((Number(r.seconds) || 0) / Math.max(1, Number(r.users) || 1))) + '</td>'
        + '</tr>').join('')
      + '</tbody></table>';
  }

  window.openActivityUser = async function(userId){
    const body = document.getElementById('actDetailBody'), title = document.getElementById('actDetailTitle');
    if (body) body.innerHTML = '<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
    if (typeof openMo === 'function') openMo('moActivity');
    else document.getElementById('moActivity')?.classList.add('on');
    try {
      const d = await adminApiRequest('activity_user', { user_id: userId, days: 30 });
      const p = d.profile || {}, pr = d.presence || {};
      if (title) title.textContent = p.full_name || p.email || 'چالاکی';
      const maxS = Math.max(1, ...(d.sections || []).map(s => Number(s.seconds) || 0));
      body.innerHTML =
        '<div class="act-detail-grid">'
        + '<div><b>' + e(ago(pr.last_seen_at)) + '</b><small>دوایین جار · ' + e(routeName(pr.route)) + '</small></div>'
        + '<div><b>' + e(dur(d.total_seconds)) + '</b><small>کۆی کات لە 30 ڕۆژدا</small></div>'
        + '<div><b>' + num((d.sessions || []).length) + '</b><small>سەردان</small></div>'
        + '</div>'
        + '<div class="detail-row"><div class="lbl">ژمارە / ئیمەیڵ</div><div class="val" dir="ltr">' + e([p.phone, p.email].filter(Boolean).join(' · ') || '—') + '</div></div>'
        + '<div class="act-h">کات لە هەر بەشێکدا</div>'
        + ((d.sections || []).length
          ? '<table><tbody>' + d.sections.map(s => '<tr><td><b>' + e(routeName(s.route)) + '</b><div class="act-bar"><span style="width:' + Math.max(2, Math.round((Number(s.seconds) || 0) / maxS * 100)) + '%"></span></div></td><td class="act-time">' + e(dur(s.seconds)) + '</td><td style="font-size:12px;color:var(--mt)">' + num(s.sessions) + ' سەردان</td></tr>').join('') + '</tbody></table>'
          : '<div class="empty"><p>هیچ چالاکییەک نییە</p></div>')
        + '<div class="act-h">دوایین سەردانەکان</div>'
        + '<div class="act-sessions">' + ((d.sessions || []).map(x =>
            '<div class="act-session"><div class="act-session-head"><b>' + e(typeof fmtDateTime === 'function' ? fmtDateTime(x.started_at) : x.started_at) + '</b><span>' + e(dur(x.seconds)) + (x.device ? ' · ' + e(DEVICES[x.device] || x.device) : '') + '</span></div>'
            + '<div class="act-screens">' + (x.screens || []).map(sc => '<span>' + e(routeName(sc.route)) + ' · ' + e(dur(sc.seconds)) + '</span>').join('') + '</div></div>'
          ).join('') || '<div class="empty"><p>هیچ سەردانێک نییە</p></div>') + '</div>';
    } catch (err) {
      body.innerHTML = '<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>' + e(err && err.message) + '</p></div>';
    }
  };

  window.loadActivity = function(){
    load();
    clearInterval(pollTimer);
    pollTimer = setInterval(() => {
      if (typeof _curPage !== 'undefined' && _curPage !== 'activity') { clearInterval(pollTimer); return; }
      if (!document.hidden) load();
    }, 30000);
  };
  window.renderActivity = render;
  window.setActivityDays = function(d, el){
    days = d;
    document.querySelectorAll('[data-actd]').forEach(x => x.classList.toggle('on', x === el));
    load();
  };
  window.setActivityFilter = function(f, el){
    filter = f;
    document.querySelectorAll('[data-actf]').forEach(x => x.classList.toggle('on', x === el));
    render();
  };

  if (typeof pageConfig === 'object' && pageConfig) {
    pageConfig.activity = { title: 'چالاکی بەکارهێنەران', sub: 'کێ لەسەر ماڵپەڕە، چەند ماوەتەوە و چووەتە کام بەش', load: () => window.loadActivity() };
  }
  // the "on the site now" count in the sidebar, for super admins
  window.addEventListener('load', () => {
    setTimeout(() => {
      if (typeof isSuperAdmin === 'function' && isSuperAdmin() && typeof adminApiRequest === 'function') load().catch(() => {});
    }, 3000);
  });
})();
