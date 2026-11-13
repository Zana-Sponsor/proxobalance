// Admin: WhatsApp order-approved notifications — totals, log and manual retry.
// Data comes from Supabase RPCs (ex_admin_whatsapp_stats / _log / _retry); n8n does the sending.
(function(){
  'use strict';
  let rows = [], filter = 'all', searchTimer = null, pollTimer = null, busy = false;

  const STATUS = {
    sent:    ['approved', 'نێردرا'],
    queued:  ['pending',  'لە نۆبەدایە'],
    sending: ['pending',  'دەنێردرێت'],
    failed:  ['rejected', 'سەرنەکەوت']
  };
  const e = (v) => (typeof esc === 'function' ? esc(v) : String(v == null ? '' : v));
  const dt = (t) => (t ? (typeof fmtDateTime === 'function' ? fmtDateTime(t) : new Date(t).toLocaleString()) : '—');
  const num = (n) => Number(n || 0).toLocaleString('en-US');
  const toast = (m, k) => { if (typeof showToast === 'function') showToast(m, k); };

  function badge(status){
    const s = STATUS[status] || ['pending', status || '—'];
    return '<span class="badge ' + s[0] + '">' + e(s[1]) + '</span>';
  }
  const KIND = { order_approved: 'پەسەندکردن', order_rejected: 'ڕەتکردنەوە' };
  function kindBadge(k){
    const tone = k === 'order_rejected' ? 'rejected' : 'approved';
    return '<span class="badge ' + tone + '" style="opacity:.85">' + e(KIND[k] || k || '—') + '</span>';
  }
  function templateLine(list){
    if(!Array.isArray(list) || !list.length) return '';
    return list.map(t => {
      const metaStatus = String(t.status || t.meta_status || '').toUpperCase();
      const state = t.active ? 'چالاکە' : (metaStatus === 'REJECTED' ? 'Meta ڕەتی کردەوە' : 'چاوەڕێی پەسەندکردنی Meta');
      return 'قاڵبی ' + (KIND[t.kind] || t.kind) + ': ' + state;
    }).join(' · ');
  }
  function displayPhone(p){ return /^\+964\d{10}$/.test(p || '') ? '0' + p.slice(4) : (p || '—'); }
  // Wevlix errors arrive as JSON text; show the readable part
  function errorText(raw){
    if(!raw) return '';
    try{
      const j = JSON.parse(raw);
      const details = Array.isArray(j.details) ? j.details.map(d => (d.field ? d.field + ': ' : '') + (d.constraints || []).join(', ')).join(' · ') : '';
      return [j.code, j.message, details].filter(Boolean).join(' — ') || raw;
    }catch(_){ return raw; }
  }

  async function loadStats(){
    const { data, error } = await sb.rpc('ex_admin_whatsapp_stats');
    if(error) throw error;
    const d = data || {};
    const set = (id, v) => { const el = document.getElementById(id); if(el) el.textContent = num(v); };
    set('waStSubs', d.subscribers); set('waStToday', d.sent_today); set('waStTotal', d.sent_total);
    set('waStPending', d.pending); set('waStFailed', d.failed);
    const last = document.getElementById('waStLast');
    if(last) last.textContent = [d.last_sent_at ? 'دوایین ناردن: ' + dt(d.last_sent_at) : '', templateLine(d.templates)].filter(Boolean).join(' — ');
    const sb2 = document.getElementById('sbWaFailed');
    if(sb2){ const f = Number(d.failed || 0); sb2.textContent = f; sb2.style.display = f ? '' : 'none'; }
  }

  async function loadLog(){
    const q = (document.getElementById('waAdminSearch')?.value || '').trim();
    const { data, error } = await sb.rpc('ex_admin_whatsapp_log', { p_status: filter, p_query: q || null, p_limit: 300 });
    if(error) throw error;
    rows = data || [];
    render();
  }

  function render(){
    const wrap = document.getElementById('waAdminTable');
    if(!wrap) return;
    if(!rows.length){
      wrap.innerHTML = '<div class="empty"><i class="fas fa-whatsapp"></i><p>هیچ نامەیەک نییە</p></div>';
      return;
    }
    const canRetry = typeof staffCan !== 'function' || staffCan('approve_orders');
    wrap.innerHTML = '<table><thead><tr><th>کات</th><th>جۆر</th><th>ئۆردەر</th><th>کڕیار</th><th>ژمارەی واتسئاپ</th><th>دۆخ</th><th>هەوڵ</th><th>نێردرا لە</th><th>تێبینی</th><th>کردار</th></tr></thead><tbody>'
      + rows.map(r => {
          const err = errorText(r.last_error);
          return '<tr>'
            + '<td style="font-size:12px;white-space:nowrap">' + e(dt(r.created_at)) + '</td>'
            + '<td>' + kindBadge(r.kind) + '</td>'
            + '<td style="direction:ltr;font-family:monospace;font-weight:700">' + e(r.order_code || '—') + '</td>'
            + '<td style="font-size:13px">' + (r.customer_name ? e(r.customer_name) : '—') + (r.username ? '<div style="font-size:11px;opacity:.7;direction:ltr">@' + e(r.username) + '</div>' : '') + '</td>'
            + '<td style="direction:ltr;font-size:13px;white-space:nowrap">' + e(displayPhone(r.phone)) + '</td>'
            + '<td>' + badge(r.status) + '</td>'
            + '<td style="text-align:center">' + e(r.attempts) + '</td>'
            + '<td style="font-size:12px;white-space:nowrap">' + e(dt(r.sent_at)) + '</td>'
            + '<td class="wa-err" title="' + e(err) + '">' + (err ? e(err.length > 140 ? err.slice(0, 140) + '…' : err) : '—') + '</td>'
            + '<td>' + (r.status === 'failed' && canRetry ? '<div class="act-btn" style="font-size:12px" onclick="retryWhatsappMessage(\'' + e(r.id) + '\')"><i class="fas fa-rotate-right"></i> دووبارە ناردنەوە</div>' : '—') + '</td>'
            + '</tr>';
        }).join('')
      + '</tbody></table>';
  }

  window.loadWhatsappAdmin = async function(){
    if(busy) return;
    busy = true;
    const wrap = document.getElementById('waAdminTable');
    if(wrap && !rows.length) wrap.innerHTML = '<div class="loading"><i class="fas fa-circle-notch fa-spin"></i></div>';
    try{
      await Promise.all([loadStats(), loadLog()]);
    }catch(err){
      if(wrap) wrap.innerHTML = '<div class="empty"><i class="fas fa-triangle-exclamation"></i><p>هەڵە: ' + e(err && err.message) + '</p></div>';
    }finally{ busy = false; }
    // keep the page live while it is open
    clearInterval(pollTimer);
    pollTimer = setInterval(() => {
      if(typeof _curPage !== 'undefined' && _curPage !== 'whatsapp'){ clearInterval(pollTimer); return; }
      if(!document.hidden) Promise.all([loadStats(), loadLog()]).catch(() => {});
    }, 30000);
  };

  window.filterWhatsappAdmin = function(el){
    document.querySelectorAll('[data-waf]').forEach(x => x.classList.remove('on'));
    el.classList.add('on');
    filter = el.dataset.waf || 'all';
    loadLog().catch(err => toast('هەڵە: ' + (err && err.message), 'rd'));
  };
  window.waAdminSearchInput = function(){
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => loadLog().catch(() => {}), 300);
  };
  window.retryWhatsappMessage = async function(id){
    try{
      const { error } = await sb.rpc('ex_admin_whatsapp_retry', { p_id: id });
      if(error) throw error;
      toast('نامەکە گەڕایەوە نۆبە؛ لە ماوەی یەک خولەکدا دەنێردرێتەوە', 'gr');
      await Promise.all([loadStats(), loadLog()]);
    }catch(err){
      toast(/NOT_RETRYABLE/.test(err && err.message) ? 'ئەم نامەیە پێشتر نێردراوە یان لە نۆبەدایە' : 'نەتوانرا: ' + (err && err.message), 'rd');
    }
  };

  // register the page with the admin router
  if(typeof pageConfig === 'object' && pageConfig){
    pageConfig.whatsapp = { title: 'نامەکانی واتسئاپ', sub: 'دۆخ و لۆگی ناردنی ئاگاداری پەسەندکردن و ڕەتکردنەوەی داواکاری بۆ واتسئاپی کڕیار', load: () => window.loadWhatsappAdmin() };
  }
  // failed-count badge in the sidebar once the panel is up
  window.addEventListener('load', () => { setTimeout(() => { if(typeof sb !== 'undefined' && sb) loadStats().catch(() => {}); }, 2500); });
})();
