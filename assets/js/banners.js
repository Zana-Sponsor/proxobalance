/* Image banners from the admin panel (table ex_banners, bucket "banners").
     slides   a fixed 12:5 place on the dashboard; several slide by themselves
     screen   one picture over the screen, on the sections the admin chose,
              once per account (ex_banner_seen), closable
   Data: one small call when the app opens (ex_my_banners). The answer is kept
   on the device so the slides are in place at once next time; the pictures
   are small WebP files the browser keeps for a year; a slide's picture loads
   only when it is about to show. A change in the panel reaches open apps at
   once through Realtime (ex_live_versions), the same for the pause switches.
   Reads the app's globals: sb, curUser, SB_URL, navigate, _route. */
(function () {
  'use strict';
  var CACHE_KEY = 'px_banners_v1';
  var SEEN_KEY = 'px_banners_seen_v1';
  var REFRESH_MS = 10 * 60 * 1000;
  var SLIDE_MS = 5000;
  var data = { slides: [], popups: [] };
  var fetchedAt = 0, busy = false;
  var idx = 0, timer = null, hold = false;
  var popupOpen = null, lastFocus = null;
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function uid() { try { return curUser && curUser.id || ''; } catch (_) { return ''; } }
  function routeNow() { try { return _route; } catch (_) { return ''; } }
  function imgUrl(path) { try { return SB_URL + '/storage/v1/object/public/banners/' + path; } catch (_) { return ''; } }
  function store(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {} }
  function read(key) { try { return JSON.parse(localStorage.getItem(key) || 'null'); } catch (_) { return null; } }
  function seenSet() { var s = read(SEEN_KEY); return new Set(s && s.uid === uid() && Array.isArray(s.ids) ? s.ids : []); }
  function clean(list) {
    return (Array.isArray(list) ? list : []).filter(function (b) {
      return b && typeof b.id === 'string' && /^(slides|popups)\/[0-9a-f-]{36}\.webp$/.test(b.img || '');
    });
  }

  // ── what a tap does ────────────────────────────────────────────
  function act(b) {
    if (b.action === 'section' && b.section && typeof navigate === 'function') navigate(b.section);
    else if (b.action === 'url' && /^https:\/\//.test(b.url || '')) window.open(b.url, '_blank', 'noopener');
  }
  function linked(b) { return b.action === 'section' || b.action === 'url'; }

  // ── dashboard slides ───────────────────────────────────────────
  function renderSlides() {
    var box = document.getElementById('dbBanners');
    if (!box) return;
    var slides = data.slides;
    stopAuto();
    if (!slides.length) { box.hidden = true; box.innerHTML = ''; return; }
    if (idx >= slides.length) idx = 0;
    var html = '<div class="dbb-view"><div class="dbb-track" id="dbbTrack">';
    slides.forEach(function (b, i) {
      var tag = linked(b) ? 'button type="button"' : 'div';
      var end = linked(b) ? 'button' : 'div';
      html += '<' + tag + ' class="dbb-slide' + (linked(b) ? ' is-link' : '') + '" data-i="' + i + '"'
        + (slides.length > 1 ? ' aria-roledescription="بانەر" aria-label="بانەری ' + (i + 1) + ' لە ' + slides.length + '"' : ' aria-label="بانەر"')
        + (i === idx ? '' : ' aria-hidden="true" tabindex="-1"') + '>'
        + '<img alt="" width="' + (b.w || 1200) + '" height="' + (b.h || 500) + '" decoding="async" draggable="false"'
        + (i === idx ? ' src="' + imgUrl(b.img) + '" fetchpriority="high"' : ' data-src="' + imgUrl(b.img) + '"') + '>'
        + '</' + end + '>';
    });
    html += '</div></div>';
    if (slides.length > 1) {
      html += '<div class="dbb-dots" role="group" aria-label="بانەرەکان">';
      slides.forEach(function (_, i) {
        html += '<button type="button" class="dbb-dot' + (i === idx ? ' on' : '') + '" data-dot="' + i + '" aria-label="بانەری ' + (i + 1) + '"' + (i === idx ? ' aria-current="true"' : '') + '></button>';
      });
      html += '</div>';
    }
    box.innerHTML = html;
    box.hidden = false;
    show(idx, true);
    startAuto();
  }
  function loadImg(i) {
    var img = document.querySelector('#dbbTrack .dbb-slide[data-i="' + i + '"] img');
    if (img && img.dataset.src) { img.src = img.dataset.src; img.removeAttribute('data-src'); }
  }
  function show(i, instant) {
    var n = data.slides.length, track = document.getElementById('dbbTrack');
    if (!track || !n) return;
    idx = (i + n) % n;
    loadImg(idx);
    if (n > 1) loadImg((idx + 1) % n);          // the next one is ready before it slides in
    if (instant) track.style.transition = 'none';
    track.style.transform = 'translateX(' + (idx * 100) + '%)';     // RTL: the next slide waits on the left
    if (instant) { void track.offsetWidth; track.style.transition = ''; }
    track.querySelectorAll('.dbb-slide').forEach(function (el, k) {
      var on = k === idx;
      if (on) { el.removeAttribute('aria-hidden'); el.removeAttribute('tabindex'); }
      else { el.setAttribute('aria-hidden', 'true'); el.setAttribute('tabindex', '-1'); }
    });
    document.querySelectorAll('#dbBanners .dbb-dot').forEach(function (d, k) {
      d.classList.toggle('on', k === idx);
      if (k === idx) d.setAttribute('aria-current', 'true'); else d.removeAttribute('aria-current');
    });
  }
  function startAuto() {
    stopAuto();
    if (reduceMotion || data.slides.length < 2) return;
    timer = setInterval(function () {
      if (hold || document.hidden || routeNow() !== 'home') return;
      show(idx + 1);
    }, SLIDE_MS);
  }
  function stopAuto() { if (timer) { clearInterval(timer); timer = null; } }

  (function wire() {
    var box = document.getElementById('dbBanners');
    if (!box) return;
    var start = null, moved = false;
    box.addEventListener('click', function (ev) {
      var dot = ev.target.closest('[data-dot]');
      if (dot) { show(Number(dot.dataset.dot)); startAuto(); return; }
      var slide = ev.target.closest('.dbb-slide.is-link');
      if (!slide || moved) return;
      var b = data.slides[Number(slide.dataset.i)];
      if (b) act(b);
    });
    box.addEventListener('pointerdown', function (ev) { start = { x: ev.clientX, y: ev.clientY }; moved = false; hold = true; }, { passive: true });
    box.addEventListener('pointermove', function (ev) {
      if (start && Math.abs(ev.clientX - start.x) > 10 && Math.abs(ev.clientX - start.x) > Math.abs(ev.clientY - start.y)) moved = true;
    }, { passive: true });
    box.addEventListener('pointerup', function (ev) {
      if (start && moved) {
        var dx = ev.clientX - start.x;
        if (Math.abs(dx) > 40) show(idx + (dx > 0 ? 1 : -1));     // RTL: pulling right brings the next one
      }
      start = null; hold = false; startAuto();
    }, { passive: true });
    box.addEventListener('pointercancel', function () { start = null; hold = false; }, { passive: true });
    box.addEventListener('mouseenter', function () { hold = true; });
    box.addEventListener('mouseleave', function () { hold = false; });
    box.addEventListener('keydown', function () { moved = false; });
    box.addEventListener('focusin', function () { hold = true; });
    box.addEventListener('focusout', function () { hold = false; });
  })();

  // ── screen banner ──────────────────────────────────────────────
  function markSeen(b) {
    var s = seenSet();
    s.add(b.id);
    store(SEEN_KEY, { uid: uid(), ids: Array.from(s).slice(-200) });
    data.popups = data.popups.filter(function (p) { return p.id !== b.id; });
    try { if (sb && sb.rpc) sb.rpc('ex_banner_seen_mark', { p_banner: b.id }).then(function () {}, function () {}); } catch (_) {}
  }
  function closePopup(go) {
    var el = document.getElementById('bnpScreen');
    var b = popupOpen;
    popupOpen = null;
    if (el) el.remove();
    document.documentElement.classList.remove('bnp-on');
    document.removeEventListener('keydown', onKey, true);
    if (b) { markSeen(b); if (go) act(b); }
    if (lastFocus && lastFocus.focus) try { lastFocus.focus(); } catch (_) {}
  }
  function onKey(ev) { if (ev.key === 'Escape') { ev.preventDefault(); closePopup(false); } }
  function maybePopup() {
    if (popupOpen || !uid() || document.getElementById('svcSite')) return;
    var route = routeNow();
    var page = document.querySelector('.page.active');
    if (!route || (page && (page.classList.contains('svc-paused')))) return;
    var seen = seenSet();
    var b = data.popups.filter(function (p) { return !seen.has(p.id) && Array.isArray(p.places) && p.places.indexOf(route) !== -1; })[0];
    if (!b) return;
    popupOpen = b;
    var pic = new Image();
    pic.decoding = 'async';
    pic.onload = function () {
      if (popupOpen !== b || routeNow() !== route) { if (popupOpen === b) popupOpen = null; return; }
      lastFocus = document.activeElement;
      var el = document.createElement('div');
      el.className = 'bnp';
      el.id = 'bnpScreen';
      el.setAttribute('role', 'dialog');
      el.setAttribute('aria-modal', 'true');
      el.setAttribute('aria-label', 'بانەر');
      el.innerHTML = '<div class="bnp-box">'
        + (linked(b) ? '<button type="button" class="bnp-img is-link" aria-label="کردنەوە">' : '<div class="bnp-img">')
        + '<img alt="" width="' + (b.w || 720) + '" height="' + (b.h || 900) + '" src="' + pic.src + '">'
        + (linked(b) ? '</button>' : '</div>')
        + '<button type="button" class="bnp-close" aria-label="داخستن"><svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg></button>'
        + '</div>';
      el.addEventListener('click', function (ev) {
        if (ev.target.closest('.bnp-close') || ev.target === el) return closePopup(false);
        if (ev.target.closest('.bnp-img.is-link')) return closePopup(true);
      });
      document.body.appendChild(el);
      document.documentElement.classList.add('bnp-on');
      document.addEventListener('keydown', onKey, true);
      var close = el.querySelector('.bnp-close');
      if (close) close.focus({ preventScroll: true });
    };
    pic.onerror = function () { if (popupOpen === b) popupOpen = null; };
    pic.src = imgUrl(b.img);
  }

  // ── data ───────────────────────────────────────────────────────
  function applyData(next) {
    var before = JSON.stringify(data.slides);
    data = { slides: clean(next && next.slides), popups: clean(next && next.popups) };
    if (JSON.stringify(data.slides) !== before || !document.querySelector('#dbBanners .dbb-view')) renderSlides();
    maybePopup();
  }
  function fetchFresh() {
    if (busy || !uid() || typeof sb === 'undefined' || !sb || !sb.rpc) return;
    busy = true;
    var owner = uid();
    Promise.resolve(sb.rpc('ex_my_banners')).then(function (res) {
      if (owner !== uid() || !res || res.error || !res.data || typeof res.data !== 'object') return;
      fetchedAt = Date.now();
      store(CACHE_KEY, { uid: owner, at: fetchedAt, data: res.data });
      applyData(res.data);
    }, function () {}).then(function () {
      busy = false;
      if (again) { again = false; fetchFresh(); }
    });
  }
  // ── live: the admin changes a banner or a switch → the open app reads it again ──
  // ex_live_versions holds one number per topic (no content); Realtime sends the
  // row when it changes. Several changes close together make one read.
  var live = null, liveTimer = null, again = false;
  function soon() {
    clearTimeout(liveTimer);
    liveTimer = setTimeout(function () {
      if (busy) { again = true; return; }
      fetchFresh();
    }, 600);
  }
  function listen() {
    if (typeof sb === 'undefined' || !sb || !sb.channel) return;
    try { if (live) sb.removeChannel(live); } catch (_) {}
    try {
      live = sb.channel('px_live_' + uid())
        .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'ex_live_versions' }, function (payload) {
          var key = payload && payload.new && payload.new.key;
          if (key === 'banners') soon();
          else if (key === 'site_controls' && window.pxSitePause) window.pxSitePause.load();
        })
        .subscribe();
    } catch (_) { live = null; }
  }

  // after sign-in: what this device saw last time at once, then the fresh answer
  window.pxBannersStart = function () {
    var c = read(CACHE_KEY);
    if (c && c.uid === uid() && c.data) applyData(c.data);
    else applyData({ slides: [], popups: [] });
    fetchFresh();
    listen();
  };
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible' && uid() && Date.now() - fetchedAt > REFRESH_MS) fetchFresh();
  });
  if (typeof window.navigate === 'function') {
    var nav = window.navigate;
    window.navigate = function () { var r = nav.apply(this, arguments); try { if (popupOpen === null) setTimeout(maybePopup, 350); } catch (_) {} return r; };
  }
  window.pxBanners = { data: function () { return data; }, show: show, maybePopup: maybePopup, close: closePopup, refresh: soon };
})();
