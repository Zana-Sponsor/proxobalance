// Admin: pause the whole site or one section, and turn it back on.
// Data: /api/admin (site_controls, site_control_set, site_schedule_save,
// site_schedule_delete), super admin only.
// The switch is on while the section works for customers.
// Working hours open and close a switch by themselves (Asia/Baghdad, checked every minute).
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
  let data = null, pending = null, busy = false, hoursKey = null;
  // days as extract(dow): 0 = Sunday; shown from Saturday
  const DAYS = [[6, 'شەممە'], [0, 'یەکشەممە'], [1, 'دووشەممە'], [2, 'سێشەممە'], [3, 'چوارشەممە'], [4, 'پێنجشەممە'], [5, 'هەینی']];

  const e = (v) => (typeof esc === 'function' ? esc(v) : String(v == null ? '' : v));
  const when = (t) => (t ? (typeof fmtDateTime === 'function' ? fmtDateTime(t) : new Date(t).toLocaleString('en-GB')) : '');
  const toast = (m, k) => { if (typeof showToast === 'function') showToast(m, k); };
  const row = (key) => (data && data.controls || []).find(r => r.key === key) || { key, paused: false };
  const hours = () => (data && data.schedules) || [];
  const hm = (t) => String(t || '').slice(0, 5);
  function daysText(days){
    const set = new Set((days || []).map(Number));
    if (set.size === 7) return 'هەموو ڕۆژێک';
    if (set.size === 6) return 'جگە لە ' + DAYS.find(d => !set.has(d[0]))[1];
    return DAYS.filter(d => set.has(d[0])).map(d => d[1]).join('، ');
  }
  // the same words customers read while it is closed (ex_site_schedule_text)
  function autoText(open, close, days){
    const set = new Set(days);
    return 'کاتی کار: ' + (set.size === 7 ? '' : daysText(days) + '، ') + open + ' تا ' + close;
  }

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
    if (r.paused_source === 'schedule') return '<span class="ps-state off">داخراوە بەپێی کاتژمێری کار</span>';
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
  function hoursHTML(h){
    const state = !h.is_active ? '<span class="ps-state">ناچالاکە</span>'
      : h.last_state === 'closed' ? '<span class="ps-state off">دەرەوەی کاتی کار</span>'
      : h.last_state === 'open' ? '<span class="ps-state on">لە کاتی کاردایە</span>' : '';
    return '<div class="ps-row ph-row' + (h.is_active ? '' : ' is-idle') + '">'
      + '<div class="ps-main"><b>' + e(NAMES[h.key] || h.key) + '</b>'
      + '<small>' + e(hm(h.open_at) + ' تا ' + hm(h.close_at)) + ' · ' + e(daysText(h.days)) + '</small>'
      + (state ? '<div class="ps-status">' + state + '</div>' : '') + '</div>'
      + '<button type="button" class="act-btn dark" onclick="openSiteHours(\'' + h.key + '\')">دەستکاری</button>'
      + '</div>';
  }
  function render(){
    const site = document.getElementById('psSite'), list = document.getElementById('psSections'), log = document.getElementById('psLog');
    const hoursWrap = document.getElementById('psHours');
    if (hoursWrap) {
      const order = ['site', ...SECTIONS.map(x => x[0])];
      const items = hours().slice().sort((a, b) => order.indexOf(a.key) - order.indexOf(b.key));
      hoursWrap.innerHTML = items.length ? items.map(hoursHTML).join('') : '<div class="ps-empty">هیچ کاتژمێرێک دانەنراوە</div>';
    }
    if (site) { site.innerHTML = rowHTML('site', NAMES.site, 'هەموو بەشەکان بۆ کڕیار'); site.classList.toggle('is-off', !!row('site').paused); }
    if (list) list.innerHTML = GROUPS.map(g => '<div class="ps-group"><h4>' + e(g[0]) + '</h4>' + g[1].map(s => rowHTML(s[0], s[1], s[2])).join('') + '</div>').join('');
    if (log) {
      const items = (data && data.log) || [];
      log.innerHTML = items.length
        ? items.map(x => '<div class="ps-log-row"><span><b>' + e(NAMES[x.key] || x.key) + '</b> ' + (x.paused ? 'ڕاگیرا' : 'کارپێکرایەوە') + (x.message ? ' · ' + e(x.message) : '') + '</span><small>' + e([x.source === 'schedule' ? 'کاتژمێری کار' : x.changed_by_name, when(x.changed_at)].filter(Boolean).join(' · ')) + '</small></div>').join('')
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

  // ── working hours ──
  const $ = (id) => document.getElementById(id);
  const pickedDays = () => [...document.querySelectorAll('#phDays input:checked')].map(i => Number(i.value));
  function hoursError(text){ const box = $('phErr'); if (box) box.textContent = text || ''; }
  window.previewSiteHours = function(){
    const open = $('phOpen').value, close = $('phClose').value, days = pickedDays();
    $('phMessage').placeholder = open && close && days.length ? autoText(open, close, days) : '';
    $('phCount').textContent = $('phMessage').value.length + '/300';
    hoursError('');
  };
  window.openSiteHours = function(key){
    const h = key ? hours().find(x => x.key === key) : null;
    hoursKey = h ? h.key : null;
    const taken = new Set(hours().map(x => x.key));
    const choices = [['site', NAMES.site], ...SECTIONS.map(x => [x[0], x[1]])].filter(c => h ? c[0] === h.key : !taken.has(c[0]));
    if (!choices.length) { toast('هەموو بەشەکان کاتژمێریان هەیە', 'rd'); return; }
    $('phTitle').textContent = h ? 'کاتژمێری کار · ' + NAMES[h.key] : 'کاتژمێری کار';
    $('phKey').innerHTML = choices.map(c => '<option value="' + c[0] + '">' + e(c[1]) + '</option>').join('');
    $('phKey').disabled = !!h;
    $('phOpen').value = h ? hm(h.open_at) : '09:00';
    $('phClose').value = h ? hm(h.close_at) : '00:00';
    const on = new Set(h ? h.days.map(Number) : [0, 1, 2, 3, 4, 5, 6]);
    $('phDays').innerHTML = DAYS.map(d => '<label class="bn-place"><input type="checkbox" value="' + d[0] + '"' + (on.has(d[0]) ? ' checked' : '') + ' onchange="previewSiteHours()">' + e(d[1]) + '</label>').join('');
    $('phMessage').value = h && h.message ? h.message : '';
    $('phActive').checked = h ? !!h.is_active : true;
    $('phDelete').hidden = !h;
    $('phSave').disabled = false;
    window.previewSiteHours();
    if (typeof openMo === 'function') openMo('moSiteHours');
  };
  window.saveSiteHours = async function(){
    if (busy) return;
    const body = {
      key: hoursKey || $('phKey').value,
      open_at: $('phOpen').value, close_at: $('phClose').value, days: pickedDays(),
      message: $('phMessage').value.trim() || null, is_active: $('phActive').checked
    };
    if (!body.open_at || !body.close_at) return hoursError('کاتی کردنەوە و داخستن دیاری بکە');
    if (body.open_at === body.close_at) return hoursError('کاتی کردنەوە و داخستن نابێت یەک بن');
    if (!body.days.length) return hoursError('لانیکەم یەک ڕۆژ هەڵبژێرە');
    busy = true; $('phSave').disabled = true;
    try {
      await adminApiRequest('site_schedule_save', body);
      toast('کاتژمێری کار پاشەکەوت کرا', 'gr');
      if (typeof closeMo === 'function') closeMo('moSiteHours');
    } catch (err) {
      hoursError(err && err.message ? err.message : 'پاشەکەوت نەکرا');
    } finally { busy = false; $('phSave').disabled = false; await load(); }
  };
  window.deleteSiteHours = function(){
    const key = hoursKey;
    if (!key || busy) return;
    if (typeof closeMo === 'function') closeMo('moSiteHours');
    confirm2('سڕینەوەی کاتژمێری کار', NAMES[key] + ' چیتر بەخۆی ناکرێتەوە و داناخرێت', 'fas fa-trash', '#dc2626', async () => {
      busy = true;
      try {
        await adminApiRequest('site_schedule_delete', { key });
        toast('کاتژمێری کار سڕایەوە', 'gr');
      } catch (err) {
        toast(err && err.message ? err.message : 'نەسڕایەوە', 'rd');
      } finally { busy = false; await load(); }
    });
  };
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
