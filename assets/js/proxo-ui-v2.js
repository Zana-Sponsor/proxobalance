/* Proxo UI v2 — bottom-nav indicator.
   The short line on the white card slides to the active tab (translateX with a
   CSS transition) instead of jumping. app.js only toggles `.on` on .pxn-item;
   this file watches that class and moves the line. */
(function () {
  'use strict';
  var card = document.querySelector('#bottomNav .pxn-card');
  if (!card) return;
  var line = card.querySelector('.pxn-line');
  var pill = card.querySelector('.pxn-pill');
  var items = Array.prototype.slice.call(card.querySelectorAll('.pxn-item[data-route]'));
  if (!line || !items.length) return;

  function place() {
    var active = card.querySelector('.pxn-item.on');
    var cardBox = card.getBoundingClientRect();
    if (!active || !cardBox.width) {          // hidden (login screen / desktop) or no tab selected
      card.classList.remove('is-ready');
      return;
    }
    items.forEach(function (el) { if (el === active) el.setAttribute('aria-current', 'page'); else el.removeAttribute('aria-current'); });
    var box = active.getBoundingClientRect();
    var x = box.left - cardBox.left + (box.width - line.offsetWidth) / 2;
    var cap = active.querySelector('.pxn-cap').getBoundingClientRect();
    var first = !card.classList.contains('is-ready');
    if (first) { line.style.transition = 'none'; if (pill) pill.style.transition = 'none'; }   // first placement: no slide-in from the corner
    line.style.transform = 'translate3d(' + Math.round(x * 100) / 100 + 'px,0,0)';
    if (pill) {
      pill.style.width = cap.width + 'px';
      pill.style.height = cap.height + 'px';
      pill.style.transform = 'translate3d(' + Math.round((cap.left - cardBox.left) * 100) / 100 + 'px,' + Math.round((cap.top - cardBox.top) * 100) / 100 + 'px,0)';
    }
    if (first) {
      void line.offsetWidth;                      // flush so the next change animates
      line.style.transition = '';
      if (pill) pill.style.transition = '';
      card.classList.add('is-ready');
    }
  }

  var queued = false;
  function schedule() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(function () { queued = false; place(); });
  }

  items.forEach(function (el) {
    new MutationObserver(schedule).observe(el, { attributes: true, attributeFilter: ['class'] });
  });
  if (window.ResizeObserver) new ResizeObserver(schedule).observe(card);   // also fires when #mainApp becomes visible
  window.addEventListener('resize', schedule, { passive: true });
  window.addEventListener('orientationchange', schedule);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(schedule);
  schedule();
})();


/* Proxo UI v2 — bottom nav hides while scrolling down and comes back as soon as
   the page is scrolled up (not only at the very bottom). It only toggles the
   `.is-hidden` class; the CSS animates it.

   The direction is judged from an "anchor": the furthest point reached in the
   current direction. A phone's address bar and momentum scrolling make
   scrollY jitter by a pixel or two the other way; with an anchor that jitter can
   never cancel a real movement, so scrolling up always shows the bar again. */
(function () {
  'use strict';
  var nav = document.getElementById('bottomNav');
  if (!nav) return;
  var HIDE_AFTER = 12;     // px of real downward scrolling before it hides
  var SHOW_AFTER = 6;      // px of real upward scrolling before it returns
  var NEAR_TOP = 24;
  var hidden = false, queued = false;
  var anchor = Math.max(0, window.scrollY || 0);

  function scrollable() { return document.documentElement.scrollHeight - window.innerHeight > 60; }
  function set(h) {
    anchor = Math.max(0, window.scrollY || 0);
    if (h === hidden) return;
    hidden = h;
    nav.classList.toggle('is-hidden', h);
  }

  function update() {
    queued = false;
    var y = Math.max(0, window.scrollY || 0);                    // iOS rubber-band can go negative
    var max = document.documentElement.scrollHeight - window.innerHeight;
    if (y <= NEAR_TOP || y >= max - 4) { set(false); return; }   // top and bottom of the page: always visible
    if (!hidden) {
      if (y < anchor) anchor = y;                                // follow the page up
      else if (y - anchor > HIDE_AFTER) set(true);
    } else {
      if (y > anchor) anchor = y;                                // follow the page down
      else if (anchor - y > SHOW_AFTER) set(false);
    }
  }

  window.addEventListener('scroll', function () {
    if (queued) return;
    queued = true;
    requestAnimationFrame(update);
  }, { passive: true });

  /* The finger is a second, steadier signal: a finger moving down the screen is
     scrolling the page up, and that must bring the bar back immediately. */
  var fMin = 0, fMax = 0;
  window.addEventListener('touchstart', function (e) {
    if (!e.touches.length) return;
    fMin = fMax = e.touches[0].clientY;
  }, { passive: true });
  window.addEventListener('touchmove', function (e) {
    if (!e.touches.length || !scrollable()) return;
    var y = e.touches[0].clientY, top = (window.scrollY || 0) <= NEAR_TOP;
    if (y < fMin) fMin = y;
    if (y > fMax) fMax = y;
    if (y - fMin > 10) {                                         // finger moved down → page moves up
      if (hidden) set(false);
      fMin = fMax = y;
    } else if (fMax - y > 16 && !top) {                          // finger moved up → page moves down
      if (!hidden) set(true);
      fMin = fMax = y;
    }
  }, { passive: true });

  window.addEventListener('popstate', function () { set(false); });
  nav.addEventListener('focusin', function () { set(false); });
  window.pxShowNav = function () { set(false); };
})();

/* ── Pull to refresh ─────────────────────────────────────────────
   Pull the active screen down from the very top: it slides down, a pill shows
   «نوێدەکرێتەوە...», only that screen's data is reloaded (refreshSection),
   then «نوێکرایەوە» shows and the screen slides back. The page never reloads. */
(function pullToRefresh(){
  var THRESHOLD = 64, MAX = 120, HOLD = 54;
  var ptr = null, label = null, page = null;
  var startY = 0, startX = 0, dy = 0, tracking = false, pulling = false, busy = false;

  function build(){
    if (ptr) return;
    ptr = document.createElement('div');
    ptr.className = 'px-ptr';
    ptr.setAttribute('role', 'status');
    ptr.setAttribute('aria-live', 'polite');
    ptr.innerHTML = '<span class="px-ptr-pill"><span class="px-ptr-ico">'
      + '<svg class="px-ptr-arrow" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/></svg>'
      + '<svg class="px-ptr-check" viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>'
      + '</span><span class="px-ptr-text"></span></span>';
    document.body.appendChild(ptr);
    label = ptr.querySelector('.px-ptr-text');
  }
  function activePage(){ return document.querySelector('#mainApp .page.active'); }
  function place(offset){
    var hdr = document.getElementById('siteHeader');
    var top = hdr ? Math.max(0, hdr.getBoundingClientRect().bottom) : 0;
    ptr.style.top = (top + Math.max(0, (offset - 38) / 2)) + 'px';
  }
  function setText(t){ if (label.textContent !== t) label.textContent = t; }
  function move(offset){
    page.style.transform = offset > 0 ? 'translate3d(0,' + offset + 'px,0)' : '';
    place(offset);
  }
  function blocked(target){
    if (document.body.style.overflow === 'hidden') return true;                       // a sheet is open
    if (target && target.closest && target.closest('.sheet-overlay, .notif-panel, textarea, [data-no-ptr]')) return true;
    var np = document.getElementById('notifPanel');
    if (np && np.classList.contains('open')) return true;
    return false;
  }
  function scrollTop(){ return window.pageYOffset || document.documentElement.scrollTop || 0; }
  function canRefresh(){ return typeof refreshSection === 'function' && typeof curUser !== 'undefined' && curUser; }

  function reset(animate){
    if (!page) return;
    var p = page;
    if (animate){
      p.classList.add('px-ptr-settle');
      p.style.transform = '';
      setTimeout(function(){ p.classList.remove('px-ptr-settle', 'px-ptr-moving'); }, 360);
    } else {
      p.style.transform = ''; p.classList.remove('px-ptr-settle', 'px-ptr-moving');
    }
    if (ptr){ ptr.classList.remove('is-on'); }
    pulling = false; tracking = false; dy = 0;
  }

  document.addEventListener('touchstart', function(e){
    if (busy || e.touches.length !== 1) return;
    if (scrollTop() > 0 || blocked(e.target) || !canRefresh()) return;
    page = activePage(); if (!page) return;
    startY = e.touches[0].clientY; startX = e.touches[0].clientX; dy = 0; tracking = true; pulling = false;
  }, { passive: true });

  document.addEventListener('touchmove', function(e){
    if (!tracking || busy) return;
    var t = e.touches[0], ddy = t.clientY - startY, ddx = t.clientX - startX;
    if (!pulling){
      if (Math.abs(ddx) > Math.abs(ddy) || ddy < -6){ tracking = false; return; }        // sideways / scrolling up: not ours
      if (ddy < 10) return;
      if (scrollTop() > 0){ tracking = false; return; }
      pulling = true; build();
      page.classList.add('px-ptr-moving');
      ptr.classList.remove('is-loading', 'is-done', 'is-error');
      ptr.classList.add('is-on');
    }
    if (e.cancelable) e.preventDefault();
    dy = Math.min(MAX, (ddy - 10) * 0.55);
    if (dy < 0) dy = 0;
    move(dy);
    setText(dy >= THRESHOLD ? 'ئازادی بکە بۆ نوێکردنەوە' : 'ڕایبکێشە بۆ نوێکردنەوە');
    var arrow = ptr.querySelector('.px-ptr-arrow');
    if (arrow) arrow.style.transform = 'rotate(' + Math.round(Math.min(1, dy / THRESHOLD) * 270) + 'deg)';
  }, { passive: false });

  function release(){
    if (!tracking && !pulling) return;
    tracking = false;
    if (!pulling) return;
    pulling = false;
    var arrow = ptr.querySelector('.px-ptr-arrow'); if (arrow) arrow.style.transform = '';
    if (dy < THRESHOLD){ reset(true); return; }
    run();
  }
  document.addEventListener('touchend', release, { passive: true });
  document.addEventListener('touchcancel', release, { passive: true });

  async function run(){
    busy = true;
    var p = page, route = (typeof _route !== 'undefined') ? _route : 'home';
    p.classList.add('px-ptr-settle');
    move(HOLD);
    ptr.classList.add('is-on', 'is-loading');
    setText('نوێدەکرێتەوە...');
    var t0 = Date.now(), ok = false;
    try { ok = (await refreshSection(route, { keepForms: true })) !== false; } catch (_) { ok = false; }
    var wait = Math.max(0, 700 - (Date.now() - t0));
    if (wait) await new Promise(function(r){ setTimeout(r, wait); });
    ptr.classList.remove('is-loading');
    ptr.classList.add(ok ? 'is-done' : 'is-error');
    setText(ok ? 'نوێکرایەوە' : 'نەتوانرا نوێ بکرێتەوە');
    await new Promise(function(r){ setTimeout(r, ok ? 650 : 1100); });
    reset(true);
    setTimeout(function(){ if (ptr) ptr.classList.remove('is-done', 'is-error'); busy = false; }, 380);
  }
})();
