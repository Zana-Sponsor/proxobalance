/* Proxo UI v2 — bottom-nav indicator.
   The short line on the white card slides to the active tab (translateX with a
   CSS transition) instead of jumping. app.js only toggles `.on` on .pxn-item;
   this file watches that class and moves the line. */
(function () {
  'use strict';
  var card = document.querySelector('#bottomNav .pxn-card');
  if (!card) return;
  var line = card.querySelector('.pxn-line');
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
    var first = !card.classList.contains('is-ready');
    if (first) line.style.transition = 'none';   // first placement: no slide-in from the corner
    line.style.transform = 'translate3d(' + Math.round(x * 100) / 100 + 'px,0,0)';
    if (first) {
      void line.offsetWidth;                      // flush so the next change animates
      line.style.transition = '';
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
