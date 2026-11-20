/* Admin pause switches, customer side (table ex_site_controls).
   Reads ex_site_status — only the paused sections, each with the admin's
   message — when the app opens, every minute while it is on screen, when the
   page comes back, and whenever a request answers 423 SECTION_PAUSED.
   The server and the database refuse a paused action anyway; this tells the
   customer before they fill in a form.

     site                one screen over everything
     a screen            its header stays, the rest becomes one centred paused state
     support             only the new-case form is replaced
     balance             paying with the balance: the exchange send button stops
     signup / login      a notice on the step, its button stops
     rating / correction / whatsapp   the action answers with a short notice
   Reads the app's globals: SB_URL, SB_KEY, ROUTES, navigate, showToast. */
(function () {
  'use strict';
  var TITLES = {
    site: 'ماڵپەڕەکە بۆ ماوەیەک ڕاگیراوە',
    home: 'سەرەکی بۆ ماوەیەک ڕاگیراوە',
    exchange: 'ئاڵوگۆڕ بۆ ماوەیەک ڕاگیراوە',
    transactions: 'مامەڵەکان بۆ ماوەیەک ڕاگیراون',
    correction: 'ڕاستکردنەوەی مامەڵە بۆ ماوەیەک ڕاگیراوە',
    rating: 'هەڵسەنگاندنی مامەڵە بۆ ماوەیەک ڕاگیراوە',
    balance: 'ناردنی باڵانس بۆ ماوەیەک ڕاگیراوە',
    balance_history: 'مێژووی باڵانس بۆ ماوەیەک ڕاگیراوە',
    support: 'پشتگیری بۆ ماوەیەک ڕاگیراوە',
    verify: 'پشتڕاستکردنەوەی ناسنامە بۆ ماوەیەک ڕاگیراوە',
    whatsapp: 'ئاگاداری واتسئاپ بۆ ماوەیەک ڕاگیراوە',
    changes: 'گۆڕانکاری نرخەکان بۆ ماوەیەک ڕاگیراوە',
    rules: 'یاساکان بۆ ماوەیەک ڕاگیراون',
    profile: 'پڕۆفایل بۆ ماوەیەک ڕاگیراوە',
    signup: 'دروستکردنی هەژماری نوێ بۆ ماوەیەک ڕاگیراوە',
    login: 'چوونەژوورەوە بۆ ماوەیەک ڕاگیراوە',
    name: 'گۆڕینی ناو بۆ ماوەیەک ڕاگیراوە',
    phone: 'گۆڕینی ژمارەی مۆبایل بۆ ماوەیەک ڕاگیراوە',
    email: 'گۆڕینی ئیمەیڵ بۆ ماوەیەک ڕاگیراوە',
    password: 'گۆڕینی وشەی نهێنی بۆ ماوەیەک ڕاگیراوە',
    delete: 'سڕینەوەی هەژمار بۆ ماوەیەک ڕاگیراوە'
  };
  var LATER = 'تکایە دواتر هەوڵ بدەرەوە.';
  // screen → section; "form" screens keep the rest and hide only the form
  var PAGES = {
    home: { key: 'home' },
    exchange: { key: 'exchange' },
    transactions: { key: 'transactions' }, summary: { key: 'transactions' },
    support: { key: 'support', form: true },
    verify: { key: 'verify' },
    balance: { key: 'balance_history' },
    changes: { key: 'changes' }, rules: { key: 'rules' }, profile: { key: 'profile' },
    'account-name': { key: 'name' }, 'change-phone': { key: 'phone' }, 'change-email': { key: 'email' },
    'change-password': { key: 'password' }, 'delete-account': { key: 'delete' }
  };
  var AUTH = [
    { id: 'authStepEmail', key: 'login', buttons: ['authBtn'] },
    { id: 'forgotStep', key: 'login', buttons: ['forgotSendBtn', 'fpVerifyBtn', 'fpSaveBtn'] },
    { id: 'authStepName', key: 'signup', buttons: ['signupSubmitBtn'] }
  ];
  // actions without a screen of their own: the app function answers with a notice instead
  var ACTIONS = {
    rating: ['openFeedbackSheet', 'submitOrderFeedback', 'submitSummaryFeedback'],
    correction: ['openOrderCorrection', 'submitOrderCorrection'],
    whatsapp: ['toggleWhatsappNotify', 'openWhatsappSheet', 'submitWhatsappSheet']
  };
  var state = {};
  var nativeFetch = window.fetch;

  function sbUrl() { try { return SB_URL; } catch (_) { return ''; } }
  function sbKey() { try { return SB_KEY; } catch (_) { return ''; } }
  function pageEl(route) { try { return document.getElementById(ROUTES[route]); } catch (_) { return null; } }

  function load() {
    if (!sbUrl() || !nativeFetch) return Promise.resolve();
    return nativeFetch.call(window, sbUrl() + '/rest/v1/rpc/ex_site_status', {
      method: 'POST',
      headers: { apikey: sbKey(), Authorization: 'Bearer ' + sbKey(), 'Content-Type': 'application/json' },
      body: '{}'
    }).then(function (res) { return res.ok ? res.json() : null; })
      .then(function (data) {
        if (data && typeof data === 'object' && !Array.isArray(data)) { state = data; apply(); }
      })
      .catch(function () {});
  }

  // one card: a tile with two bars, the title and the admin's message; on a paused
  // screen it also offers "check again" and the way home (site-pause.css)
  function makeNote() {
    var box = document.createElement('div');
    box.className = 'svc-note';
    box.setAttribute('role', 'status');
    box.innerHTML = '<span class="svc-note-mark" aria-hidden="true"><i></i><i></i></span>'
      + '<div class="svc-note-body"><b></b><p></p></div>'
      + '<div class="svc-note-actions">'
      + '<button type="button" class="svc-note-btn is-soft" data-act="check">دووبارە پشکنین</button>'
      + '<button type="button" class="svc-note-btn" data-act="home">سەرەکی</button></div>';
    box.querySelector('[data-act="check"]').addEventListener('click', function () {
      var btn = this;
      btn.disabled = true; btn.textContent = 'پشکنین...';
      load().then(function () { setTimeout(function () { btn.disabled = false; btn.textContent = 'دووبارە پشکنین'; }, 600); });
    });
    box.querySelector('[data-act="home"]').addEventListener('click', function () {
      if (typeof window.navigate === 'function') window.navigate('home');
    });
    return box;
  }
  function fill(box, key) {
    box.dataset.svc = key;
    box.querySelector('b').textContent = TITLES[key] || TITLES.site;
    box.querySelector('p').textContent = (state[key] && state[key].message) || LATER;
  }
  function lock(ids, on) {
    ids.forEach(function (id) {
      var btn = document.getElementById(id);
      if (!btn) return;
      if (on && !btn.disabled) { btn.disabled = true; btn.dataset.svcLocked = '1'; }
      if (!on && btn.dataset.svcLocked) { btn.disabled = false; delete btn.dataset.svcLocked; }
    });
  }
  // one notice in `host`, right after `anchor` (or at the top); key null removes it
  function paint(host, anchor, key) {
    if (!host) return;
    var box = host.querySelector(':scope > .svc-note');
    if (!key) { if (box) box.remove(); return; }
    if (!box) {
      box = makeNote();
      host.insertBefore(box, anchor ? anchor.nextSibling : host.firstChild);
    }
    fill(box, key);
  }

  function site() {
    var on = !!state.site, el = document.getElementById('svcSite');
    if (!on) { if (el) el.remove(); document.documentElement.classList.remove('svc-site-on'); return; }
    if (!el) {
      el = document.createElement('div');
      el.id = 'svcSite';
      el.className = 'svc-site';
      el.setAttribute('role', 'alertdialog');
      el.setAttribute('aria-modal', 'true');
      el.setAttribute('aria-labelledby', 'svcSiteTitle');
      el.innerHTML = '<img class="svc-site-logo" src="/assets/images/auth/proxo-logo.webp" alt="Proxo">'
        + '<div class="svc-site-box"><div class="svc-site-mark" aria-hidden="true"><i></i><i></i></div>'
        + '<h1 id="svcSiteTitle"></h1><p id="svcSiteText"></p>'
        + '<div class="svc-site-actions"><button type="button" class="svc-site-btn" id="svcSiteBtn">دووبارە هەوڵبدەرەوە</button>'
        + '<a class="svc-site-btn is-ghost" href="https://t.me/proxo_exchange" target="_blank" rel="noopener">پەیوەندی بە پشتگیری</a></div></div>';
      document.body.appendChild(el);
      el.querySelector('#svcSiteBtn').addEventListener('click', function () {
        var btn = this;
        btn.disabled = true; btn.textContent = 'پشکنین...';
        load().then(function () { setTimeout(function () { btn.disabled = false; btn.textContent = 'دووبارە هەوڵبدەرەوە'; }, 600); });
      });
    }
    document.documentElement.classList.add('svc-site-on');
    el.querySelector('#svcSiteTitle').textContent = TITLES.site;
    el.querySelector('#svcSiteText').textContent = (state.site && state.site.message) || 'تکایە دواتر سەردان بکەرەوە.';
  }

  function apply() {
    site();
    AUTH.forEach(function (a) {
      var host = document.getElementById(a.id), key = state[a.key] ? a.key : null;
      paint(host, null, key);
      lock(a.buttons, !!key);
    });
    var prompt = document.getElementById('homeFeedbackPrompt');
    if (prompt && paused('rating')) prompt.hidden = true;
    Object.keys(PAGES).forEach(function (route) {
      var cfg = PAGES[route], page = pageEl(route);
      if (!page) return;
      var key = state[cfg.key] ? cfg.key : null;
      // paying with the balance: the exchange screen stays, its send button stops
      var balance = route === 'exchange' && !key && state.balance && (document.getElementById('from') || {}).value === 'AccountBalance';
      var head = page.querySelector(':scope > .pfx-bar, :scope > .page-head');
      paint(page, head, key || (balance ? 'balance' : null));
      page.classList.toggle(cfg.form ? 'svc-paused-form' : 'svc-paused', !!key);
      if (route === 'exchange') lock(['submitBtn'], !!(key || balance));
    });
  }

  function paused(key) { return !!(state.site || state[key]); }
  function tell(key) {
    var k = state.site ? 'site' : key;
    if (typeof window.showToast === 'function') window.showToast((state[k] && state[k].message) || LATER, 'warning', TITLES[k] || TITLES.site);
  }
  function guardActions() {
    Object.keys(ACTIONS).forEach(function (key) {
      ACTIONS[key].forEach(function (name) {
        var fn = window[name];
        if (typeof fn !== 'function' || fn.__svc) return;
        var guarded = function () {
          if (paused(key)) { tell(key); return; }
          return fn.apply(this, arguments);
        };
        guarded.__svc = true;
        window[name] = guarded;
      });
    });
    // the dashboard's "rate your exchange" card waits while ratings are paused
    ['renderHomeFeedbackPrompt', 'maybePromptHomeFeedback'].forEach(function (name) {
      var fn = window[name];
      if (typeof fn !== 'function' || fn.__svc) return;
      var guarded = function () { if (paused('rating')) return; return fn.apply(this, arguments); };
      guarded.__svc = true;
      window[name] = guarded;
    });
  }

  // a request refused because a section is paused: show it now, then re-read
  if (nativeFetch) {
    window.fetch = function (input) {
      return nativeFetch.apply(window, arguments).then(function (res) {
        try {
          var url = typeof input === 'string' ? input : (input && input.url) || '';
          if (res && res.status === 423 && url.indexOf('/api/') !== -1) {
            res.clone().json().then(function (body) {
              if (body && body.code === 'SECTION_PAUSED' && TITLES[body.section]) {
                state[body.section] = { message: body.message || null };
                apply();
                if (ACTIONS[body.section]) tell(body.section);
                load();
              }
            }).catch(function () {});
          }
        } catch (_) {}
        return res;
      });
    };
  }
  // screens change: the notice follows at once
  if (typeof window.navigate === 'function') {
    var nav = window.navigate;
    window.navigate = function () { var r = nav.apply(this, arguments); try { apply(); } catch (_) {} return r; };
  }
  document.addEventListener('change', function (ev) { if (ev.target && ev.target.id === 'from') apply(); });
  document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'visible') load(); });
  setInterval(function () { if (document.visibilityState === 'visible') load(); }, 60 * 1000);
  // the app re-enables buttons and switches the sending wallet by itself; keep up with it
  setInterval(function () { if (Object.keys(state).length || document.querySelector('.svc-note')) apply(); }, 1500);
  window.pxSitePause = { load: load, apply: apply, paused: paused, state: function () { return state; } };
  // the app's own scripts after this one (WhatsApp settings) are wrapped once they exist
  guardActions();
  document.addEventListener('DOMContentLoaded', guardActions);
  window.addEventListener('load', guardActions);
  load();
})();
