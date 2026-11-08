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


/* Proxo UI v2 — bottom nav hides while scrolling down and returns smoothly
   on the way back up. Only toggles the `.is-hidden` class; the CSS animates it.
   It is always shown near the top and at the very bottom of the page. */
(function () {
  'use strict';
  var nav = document.getElementById('bottomNav');
  if (!nav) return;
  var DOWN = 14;         // px scrolled down in one go before it hides
  var UP = 8;            // px scrolled up before it returns
  var NEAR_TOP = 24;
  var lastY = Math.max(0, window.scrollY || 0), run = 0, hidden = false, queued = false;

  function set(h) {
    if (h === hidden) return;
    hidden = h;
    nav.classList.toggle('is-hidden', h);
  }

  function update() {
    queued = false;
    var y = Math.max(0, window.scrollY || 0);                    // iOS rubber-band can go negative
    var max = document.documentElement.scrollHeight - window.innerHeight;
    var d = y - lastY;
    lastY = y;
    if (y <= NEAR_TOP || y >= max - 4) { run = 0; set(false); return; }
    if (!d) return;
    run = (d > 0) === (run > 0) ? run + d : d;                    // a change of direction starts a new run
    if (run > DOWN) set(true);
    else if (run < -UP) set(false);
  }

  window.addEventListener('scroll', function () {
    if (queued) return;
    queued = true;
    requestAnimationFrame(update);
  }, { passive: true });
  window.addEventListener('popstate', function () { run = 0; set(false); });
  nav.addEventListener('focusin', function () { set(false); });
})();
