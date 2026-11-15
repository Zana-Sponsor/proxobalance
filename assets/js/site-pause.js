/* Admin pause switches, customer side (table ex_site_controls).
   Reads ex_site_status — only the paused sections, each with the admin's
   message — when the app opens, every minute while it is on screen, when the
   page comes back, and whenever a request answers 423 SECTION_PAUSED.
   The server and the database refuse a paused action anyway; this tells the
   customer before they fill in a form.

     site       one screen over everything
     exchange   the new-request screen      balance   paying with the balance
     support    the new-case form           verify    the identity form
     signup     the sign-up step            login     sign-in and "forgot password"
     account    name, number, e-mail, password and delete screens
   Reads the app's globals: SB_URL, SB_KEY, ROUTES, navigate. */
(function () {
  'use strict';
  var TITLES = {
    site: 'ماڵپەڕەکە بۆ ماوەیەک ڕاگیراوە',
    exchange: 'ئاڵوگۆڕ بۆ ماوەیەک ڕاگیراوە',
    balance: 'باڵانس بۆ ماوەیەک ڕاگیراوە',
    support: 'پشتگیری بۆ ماوەیەک ڕاگیراوە',
    verify: 'پشتڕاستکردنەوەی ناسنامە بۆ ماوەیەک ڕاگیراوە',
    signup: 'دروستکردنی هەژماری نوێ بۆ ماوەیەک ڕاگیراوە',
    login: 'چوونەژوورەوە بۆ ماوەیەک ڕاگیراوە',
    account: 'گۆڕینی زانیاری هەژمار بۆ ماوەیەک ڕاگیراوە'
  };
  var LATER = 'تکایە دواتر هەوڵ بدەرەوە.';
  // screen → section; "form" pages keep the rest of the screen and hide only the form
  var PAGES = {
    exchange: { key: 'exchange' },
    support: { key: 'support', form: true },
    verify: { key: 'verify' },
    'account-name': { key: 'account' }, 'change-phone': { key: 'account' }, 'change-email': { key: 'account' },
    'change-password': { key: 'account' }, 'delete-account': { key: 'account' }
  };
  var AUTH = [
    { id: 'authStepEmail', key: 'login', buttons: ['authBtn'] },
    { id: 'forgotStep', key: 'login', buttons: ['forgotSendBtn', 'fpVerifyBtn', 'fpSaveBtn'] },
    { id: 'authStepName', key: 'signup', buttons: ['signupSubmitBtn'] }
  ];
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

  function makeNote() {
    var box = document.createElement('div');
    box.className = 'svc-note';
    box.setAttribute('role', 'status');
    box.appendChild(document.createElement('b'));
    box.appendChild(document.createElement('p'));
    return box;
  }
  function fill(box, key) {
    box.dataset.svc = key;
    box.firstChild.textContent = TITLES[key] || TITLES.site;
    box.lastChild.textContent = (state[key] && state[key].message) || LATER;
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
      el.innerHTML = '<div class="svc-site-box"><img class="svc-site-logo" src="/assets/images/auth/proxo-logo.webp" alt="Proxo">'
        + '<h1 id="svcSiteTitle"></h1><p id="svcSiteText"></p>'
        + '<button type="button" class="svc-site-btn" id="svcSiteBtn">دووبارە هەوڵبدەرەوە</button></div>';
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
                apply(); load();
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
  window.pxSitePause = { load: load, apply: apply, state: function () { return state; } };
  load();
})();
