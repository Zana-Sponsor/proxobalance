/* Proxo toast — white 3D cards that stack on top of each other.

   showToast(message, type, title, opts)
     type  : 'success' | 'error' | 'warning' | 'info'
     opts  : { id, sticky, duration }
       id      same id = same card. Calling again updates it in place
               (used for "no internet" -> "internet is back").
       sticky  stays until it is closed or replaced (no countdown).
       duration  ms override for the countdown.
   Returns { dismiss() }.

   • The newest card is in front, older ones sit behind it (max 3 layers shown).
   • Only the front card counts down, so every message is readable.
   • Drag the front card left/right to remove it. Hover or touch pauses the countdown.
   • The same message twice does not stack: it gets a ×N badge and moves to the front.
   • Text is set with textContent, never innerHTML.

   Loaded BEFORE app.js, and app.js no longer defines showToast. */
(function () {
  'use strict';

  var MAX_LAYERS = 3;                 // cards that are visible in the stack
  var LIFE = { success: 3200, info: 4200, warning: 5200, error: 6000 };

  var SVG = 'xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"';
  var ICONS = {
    success: '<svg ' + SVG + '><path d="M20 6 9 17l-5-5"/></svg>',
    error: '<svg ' + SVG + '><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>',
    warning: '<svg ' + SVG + '><path d="M12 8v5"/><path d="M12 17h.01"/></svg>',
    info: '<svg ' + SVG + '><path d="M12 11v5"/><path d="M12 8h.01"/></svg>'
  };
  var CLOSE = '<svg ' + SVG + '><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>';

  var stack = null, moreBtn = null, items = [];          // items[0] = front card
  var reduceMotion = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  function ensureStack() {
    if (stack && document.body.contains(stack)) return stack;
    stack = document.createElement('div');
    stack.className = 'pxt-stack';
    stack.id = 'pxToastStack';
    stack.setAttribute('aria-live', 'polite');
    stack.setAttribute('aria-atomic', 'false');
    moreBtn = document.createElement('button');
    moreBtn.type = 'button';
    moreBtn.className = 'pxt-more';
    moreBtn.hidden = true;
    moreBtn.innerHTML = '<b></b><span>لابردنی هەموو</span>';
    moreBtn.addEventListener('click', dismissAll);
    stack.appendChild(moreBtn);
    document.body.appendChild(stack);
    return stack;
  }

  function lifeFor(t) {
    if (t.sticky) return 0;
    var base = t.duration || LIFE[t.type] || LIFE.info;
    // a long queue goes faster, but never below 2.4 s
    return Math.max(2400, base - Math.max(0, items.length - 1) * 350);
  }

  /* Re-assign every card its place in the stack. CSS does the animating. */
  function layout() {
    items.forEach(function (t, i) {
      var el = t.el;
      el.style.setProperty('--i', Math.min(i, MAX_LAYERS));
      el.style.zIndex = String(100 - i);
      el.classList.toggle('is-front', i === 0);
      el.classList.toggle('is-behind', i > 0);
      el.classList.toggle('is-deep', i >= MAX_LAYERS);
      el.setAttribute('aria-hidden', i >= MAX_LAYERS ? 'true' : 'false');
      el.tabIndex = i === 0 ? 0 : -1;
      var x = el.querySelector('.pxt-x');
      if (x) x.tabIndex = i === 0 ? 0 : -1;
      // the countdown only runs on the front card
      if (i === 0 && !t.sticky) startCountdown(t); else pauseCountdown(t);
    });
    var hidden = Math.max(0, items.length - MAX_LAYERS);
    // the "+N" pill sits under the stack, whatever height the front card has
    if (items[0]) stack.style.setProperty('--front-h', items[0].el.offsetHeight + 'px');
    if (moreBtn) {
      moreBtn.hidden = hidden === 0;
      moreBtn.firstChild.textContent = '+' + hidden;
    }
  }

  function startCountdown(t) {
    var bar = t.el.querySelector('.pxt-bar');
    if (!bar) return;
    if (!t.counting) {
      t.counting = true;
      bar.style.animation = 'none';
      void bar.offsetWidth;                                  // restart from full
      bar.style.animation = '';
      bar.style.animationDuration = lifeFor(t) + 'ms';
    }
    t.el.classList.remove('is-waiting');
  }
  function pauseCountdown(t) {
    t.el.classList.add('is-waiting');                         // animation-play-state: paused (CSS)
    if (t.sticky || t.el.classList.contains('is-front') === false) {
      // a card that goes behind starts over when it comes back to the front
      t.counting = false;
    }
  }

  function remove(t, how) {
    var idx = items.indexOf(t);
    if (idx === -1) return;
    items.splice(idx, 1);
    var el = t.el;
    el.classList.remove('is-front', 'is-behind');
    el.classList.add('is-leaving');
    if (how === 'left' || how === 'right') {
      el.style.setProperty('--dx', (how === 'left' ? -1 : 1) * Math.max(window.innerWidth, 480) + 'px');
      el.style.setProperty('--rz', (how === 'left' ? -14 : 14) + 'deg');
    }
    layout();                                                 // the cards behind move forward right away
    var done = false;
    var fin = function () { if (done) return; done = true; el.remove(); };
    el.addEventListener('transitionend', function (e) { if (e.target === el && e.propertyName === 'opacity') fin(); });
    setTimeout(fin, 520);
  }

  function dismissAll() {
    var all = items.slice();
    all.forEach(function (t, k) { setTimeout(function () { remove(t); }, k * 45); });
  }

  /* ── drag to remove + soft tilt ─────────────────────────────── */
  function wireGestures(t) {
    var el = t.el, startX = 0, startY = 0, lastX = 0, lastT = 0, vx = 0, dragging = false, moved = false;

    el.addEventListener('pointerdown', function (e) {
      if (!el.classList.contains('is-front') || e.button > 0) return;
      if (e.target.closest('.pxt-x')) return;
      startX = lastX = e.clientX; startY = e.clientY; lastT = e.timeStamp; vx = 0;
      dragging = true; moved = false;
      el.classList.add('is-dragging');
      try { el.setPointerCapture(e.pointerId); } catch (_) {}
    });

    el.addEventListener('pointermove', function (e) {
      if (dragging) {
        var dx = e.clientX - startX;
        if (!moved && Math.abs(dx) < 4) return;
        moved = true;
        var dt = Math.max(1, e.timeStamp - lastT);
        vx = (e.clientX - lastX) / dt; lastX = e.clientX; lastT = e.timeStamp;
        var w = el.offsetWidth || 340;
        el.style.setProperty('--dx', dx + 'px');
        el.style.setProperty('--rz', (dx / 22).toFixed(2) + 'deg');
        el.style.setProperty('--fade', String(Math.max(.25, 1 - Math.abs(dx) / (w * 1.15))));
        return;
      }
      // mouse hover: the card leans toward the pointer, the text lags a little (parallax)
      if (e.pointerType !== 'mouse' || reduceMotion || !el.classList.contains('is-front')) return;
      var r = el.getBoundingClientRect();
      var px = (e.clientX - r.left) / r.width - .5, py = (e.clientY - r.top) / r.height - .5;
      el.style.setProperty('--ry', (px * 7).toFixed(2) + 'deg');
      el.style.setProperty('--rx', (-py * 6).toFixed(2) + 'deg');
      el.style.setProperty('--tx', (-px * 5).toFixed(2) + 'px');
      el.style.setProperty('--ty', (-py * 4).toFixed(2) + 'px');
    });

    function release(e) {
      if (!dragging) return;
      dragging = false;
      el.classList.remove('is-dragging');
      try { el.releasePointerCapture(e.pointerId); } catch (_) {}
      var dx = e.clientX - startX, w = el.offsetWidth || 340;
      if (moved && (Math.abs(dx) > w * .32 || (Math.abs(vx) > .6 && Math.abs(dx) > 28))) {   // far enough, or a quick flick
        remove(t, (dx || vx) < 0 ? 'left' : 'right');
      } else {
        el.style.setProperty('--dx', '0px');                  // spring back
        el.style.setProperty('--rz', '0deg');
        el.style.removeProperty('--fade');
      }
    }
    el.addEventListener('pointerup', release);
    el.addEventListener('pointercancel', release);
    el.addEventListener('pointerleave', function (e) {
      if (e.pointerType !== 'mouse' || dragging) return;
      ['--rx', '--ry', '--tx', '--ty'].forEach(function (p) { el.style.removeProperty(p); });
    });
    // Esc / Delete closes the focused front card
    el.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' || e.key === 'Delete') { remove(t); }
    });
  }

  function fill(t) {
    var el = t.el;
    el.className = el.className.replace(/\bpxt-(success|error|warning|info)\b/g, '').trim() + ' pxt-' + t.type;
    el.setAttribute('role', t.type === 'error' ? 'alert' : 'status');
    el.querySelector('.pxt-ico').innerHTML = ICONS[t.type];
    var title = el.querySelector('.pxt-title');
    title.textContent = t.title || '';
    title.hidden = !t.title;
    el.classList.toggle('no-title', !t.title);
    el.querySelector('.pxt-msg').textContent = t.message;
    var n = el.querySelector('.pxt-n');
    n.textContent = t.count > 1 ? '×' + t.count : '';
    n.hidden = t.count < 2;
    el.classList.toggle('is-sticky', !!t.sticky);
  }

  function build(t) {
    var el = document.createElement('div');
    el.className = 'pxt is-entering';
    el.innerHTML =
      '<div class="pxt-body">' +
        '<span class="pxt-ico"></span>' +
        '<span class="pxt-text"><b class="pxt-title"></b><span class="pxt-msg"></span></span>' +
        '<span class="pxt-n" hidden></span>' +
      '</div>' +
      '<button type="button" class="pxt-x" aria-label="داخستن">' + CLOSE + '</button>' +
      '<span class="pxt-bar"></span>';
    t.el = el;
    fill(t);
    el.querySelector('.pxt-x').addEventListener('click', function (e) { e.stopPropagation(); remove(t); });
    var bar = el.querySelector('.pxt-bar');
    bar.addEventListener('animationend', function () { if (!t.sticky && items[0] === t) remove(t); });
    wireGestures(t);
    return el;
  }

  function showToast(message, type, title, opts) {
    opts = opts || {};
    type = ICONS[type] ? type : 'info';
    message = String(message == null ? '' : message);
    ensureStack();

    // same id -> update that card in place
    var t = opts.id ? items.filter(function (x) { return x.id === opts.id; })[0] : null;
    // same text -> do not make a second card, count it
    if (!t) t = items.filter(function (x) { return !x.id && x.type === type && x.message === message && x.title === (title || ''); })[0];

    if (t) {
      var same = t.type === type && t.message === message;
      t.type = type; t.message = message; t.title = title || '';
      t.sticky = !!opts.sticky; t.duration = opts.duration || 0;
      t.count = same && !opts.id ? t.count + 1 : 1;
      fill(t);
      items.splice(items.indexOf(t), 1);                      // bring to the front
      items.unshift(t);
      t.counting = false;
      t.el.classList.remove('is-bump'); void t.el.offsetWidth; t.el.classList.add('is-bump');
      layout();
      return { dismiss: function () { remove(t); } };
    }

    t = { id: opts.id || null, type: type, title: title || '', message: message, count: 1, sticky: !!opts.sticky, duration: opts.duration || 0, counting: false };
    var el = build(t);
    stack.appendChild(el);
    items.unshift(t);
    layout();
    // next frame: take away the "entering" pose so CSS animates it into place
    requestAnimationFrame(function () { requestAnimationFrame(function () { el.classList.remove('is-entering'); }); });
    return { dismiss: function () { remove(t); } };
  }

  window.showToast = showToast;
  window.hideToast = function (id) {
    items.filter(function (x) { return x.id === id; }).forEach(function (t) { remove(t); });
  };
})();
