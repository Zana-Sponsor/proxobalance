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
