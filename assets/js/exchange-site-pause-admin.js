// Admin: pause the whole site or one section, and turn it back on.
// Data: /api/admin (site_controls, site_control_set), super admin only.
// The switch is on while the section works for customers.
(function(){
  'use strict';
  // every section of the customer site, in the order a customer meets them
  const GROUPS = [
    ['سەرەکی و ئاڵوگۆڕ', [
      ['home', 'سەرەکی', 'داشبۆرد'],
      ['exchange', 'ئاڵوگۆڕ', 'داواکاریی نوێی ئاڵوگۆڕ'],
      ['transactions', 'مامەڵەکان', 'لیستی مامەڵەکان و وردەکاری مامەڵە'],
      ['correction', 'ڕاستکردنەوەی مامەڵە', 'ناردنەوەی پسوولە بۆ مامەڵەی ڕەتکراوە'],
      ['rating', 'هەڵسەنگاندنی مامەڵە', 'ئەستێرە و کۆمێنت'],
      ['changes', 'گۆڕانکاری نرخ', '']
    ]],
    ['باڵانس', [
      ['balance', 'ناردنی باڵانس', 'ناردنی باڵانس و پارەدان بە باڵانس'],
      ['balance_history', 'مێژووی باڵانس', '']
    ]],
    ['هەژمار', [
      ['signup', 'دروستکردنی هەژمار', ''],
      ['login', 'چوونەژوورەوە', 'لەگەڵ وشەی نهێنیی لەبیرچوو'],
      ['profile', 'پڕۆفایل', ''],
      ['name', 'گۆڕینی ناو', ''],
      ['phone', 'گۆڕینی ژمارەی مۆبایل', ''],
      ['email', 'گۆڕینی ئیمەیڵ', ''],
      ['password', 'گۆڕینی وشەی نهێنی', ''],
      ['delete', 'سڕینەوەی هەژمار', ''],
      ['verify', 'پشتڕاستکردنەوەی ناسنامە', 'ناردنی بەڵگەنامە'],
      ['whatsapp', 'ئاگاداری واتسئاپ', 'چالاککردن و ناچالاککردن لەلایەن کڕیار']
    ]],
    ['پشتگیری و زانیاری', [
      ['support', 'پشتگیری', 'کەیسی نوێ'],
      ['rules', 'یاساکان', '']
    ]]
  ];
  const SECTIONS = GROUPS.flatMap(g => g[1]);
  const NAMES = Object.fromEntries([['site', 'هەموو ماڵپەڕەکە'], ...SECTIONS.map(s => [s[0], s[1]])]);
  let data = null, pending = null, busy = false;

  const e = (v) => (typeof esc === 'function' ? esc(v) : String(v == null ? '' : v));
  const when = (t) => (t ? (typeof fmtDateTime === 'function' ? fmtDateTime(t) : new Date(t).toLocaleString('en-GB')) : '');
  const toast = (m, k) => { if (typeof showToast === 'function') showToast(m, k); };
  const row = (key) => (data && data.controls || []).find(r => r.key === key) || { key, paused: false };

  async function load(){
    try {
      data = await adminApiRequest('site_controls', {});
      render();
    } catch (err) {
      const wrap = document.getElementById('psSections');
      if (wrap) wrap.innerHTML = '<div class="empty"><p>' + e(err && err.message) + '</p></div>';
    }
  }

  function stateHTML(r){
    if (!r.paused) return '<span class="ps-state on">کارایە</span>';
    return '<span class="ps-state off">ڕاگیراوە' + (r.updated_at ? ' · ' + e(when(r.updated_at)) : '') + '</span>'
      + (r.message ? '<span class="ps-msg">' + e(r.message) + '</span>' : '')
      + '<button type="button" class="ps-link" onclick="openSitePause(\'' + r.key + '\', true)">گۆڕینی پەیام</button>';
  }
  function rowHTML(key, name, what){
    const r = row(key);
    return '<div class="ps-row' + (r.paused ? ' is-off' : '') + '">'
      + '<div class="ps-main"><b>' + e(name) + '</b>' + (what ? '<small>' + e(what) + '</small>' : '') + '<div class="ps-status">' + stateHTML(r) + '</div></div>'
      + '<label class="mswitch" title="' + (r.paused ? 'ڕاگیراوە' : 'کارایە') + '"><input type="checkbox" aria-label="' + e(name) + '"' + (r.paused ? '' : ' checked') + (busy ? ' disabled' : '') + ' onchange="toggleSitePause(\'' + key + '\', this)"><span class="track"></span></label>'
      + '</div>';
  }
  function render(){
    const site = document.getElementById('psSite'), list = document.getElementById('psSections'), log = document.getElementById('psLog');
    if (site) { site.innerHTML = rowHTML('site', NAMES.site, 'هەموو بەشەکان بۆ کڕیار'); site.classList.toggle('is-off', !!row('site').paused); }
    if (list) list.innerHTML = GROUPS.map(g => '<div class="ps-group"><h4>' + e(g[0]) + '</h4>' + g[1].map(s => rowHTML(s[0], s[1], s[2])).join('') + '</div>').join('');
    if (log) {
      const items = (data && data.log) || [];
      log.innerHTML = items.length
        ? items.map(x => '<div class="ps-log-row"><span><b>' + e(NAMES[x.key] || x.key) + '</b> ' + (x.paused ? 'ڕاگیرا' : 'کارپێکرایەوە') + (x.message ? ' · ' + e(x.message) : '') + '</span><small>' + e([x.changed_by_name, when(x.changed_at)].filter(Boolean).join(' · ')) + '</small></div>').join('')
        : '<div class="ps-empty">هێشتا هیچ گۆڕانکارییەک نییە</div>';
    }
    const paused = (data && data.controls || []).filter(r => r.paused).length;
    const badge = document.getElementById('sbPaused');
    if (badge) { badge.textContent = paused; badge.style.display = paused ? '' : 'none'; }
  }

  async function send(key, paused, message){
    busy = true; render();
    try {
      await adminApiRequest('site_control_set', { key, paused, message: message || null });
      toast(NAMES[key] + (paused ? ' ڕاگیرا' : ' کارپێکرایەوە'), 'gr');
      if (typeof closeMo === 'function') closeMo('moSitePause');
    } catch (err) {
      toast(err && err.message ? err.message : 'نەگۆڕدرا', 'rd');
    } finally { busy = false; await load(); }
  }

  // switch moved: off → ask for the optional message; on → confirm
  window.toggleSitePause = function(key, input){
    const paused = !input.checked;
    input.checked = !row(key).paused;      // the switch shows the saved state until the change is saved
    if (paused) { window.openSitePause(key, false); return; }
    confirm2('کارپێکردنەوەی ' + NAMES[key], NAMES[key] + ' بۆ کڕیار دەکرێتەوە', 'fas fa-play', 'var(--gr)', () => send(key, false, null));
  };
  window.openSitePause = function(key, editing){
    pending = key;
    const r = row(key);
    document.getElementById('psModalTitle').textContent = (editing ? 'پەیامی ڕاگرتنی ' : 'ڕاگرتنی ') + NAMES[key];
    const text = document.getElementById('psMessage');
    text.value = r.paused ? (r.message || '') : '';
    document.getElementById('psCount').textContent = text.value.length + '/300';
    document.getElementById('psSaveBtn').textContent = editing ? 'پاشەکەوتکردن' : 'ڕاگرتن';
    if (typeof openMo === 'function') openMo('moSitePause');
    setTimeout(() => text.focus(), 50);
  };
  window.saveSitePause = function(){
    if (!pending || busy) return;
    send(pending, true, document.getElementById('psMessage').value.trim());
  };
  window.countSitePause = function(el){ document.getElementById('psCount').textContent = el.value.length + '/300'; };
  window.loadSitePause = load;

  if (typeof pageConfig === 'object' && pageConfig) {
    pageConfig.pause = { title: 'ڕاگرتنی بەشەکان', sub: 'ڕاگرتن و کارپێکردنەوەی ماڵپەڕ و هەر بەشێک بۆ کڕیار', load: () => load() };
  }
  // the sidebar shows how many are paused, for super admins
  window.addEventListener('load', () => {
    setTimeout(() => {
      if (typeof isSuperAdmin === 'function' && isSuperAdmin() && typeof adminApiRequest === 'function') load().catch(() => {});
    }, 3500);
  });
})();
