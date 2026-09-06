/* assets/js/track.js
 *
 * Tells the server "someone is here" so it can record the real public IP
 * against the account. Standalone on purpose: it reads the Supabase session
 * straight out of storage, so it needs nothing from app.js and cannot break it.
 * Load it AFTER app.js.
 *
 * window.trackEvent(type, detail) is available for app.js to call directly,
 * e.g. after a failed sign-in:  trackEvent('login_failed', email)
 */
(function () {
  'use strict';

  var ENDPOINT = '/api/track';
  var POLL_MS = 5000;
  var FIRST_DELAY_MS = 1500;          // let app.js restore the session first
  var VIEW_GAP_MS = 10 * 60 * 1000;   // one page_view per 10 minutes per tab

  /* Finds the Supabase access token WITHOUT knowing the storage key.
   * The previous version only looked at keys containing "auth-token", so a
   * client created with a custom storageKey (the way admin.js uses
   * 'zex_admin_sb_session') was invisible and every event was logged as a
   * guest. This walks every entry in both storages and looks at the VALUE. */
  function pluck(v) {
    if (!v || typeof v !== 'object') return null;
    if (typeof v.access_token === 'string') return v.access_token;
    if (v.currentSession && typeof v.currentSession.access_token === 'string') return v.currentSession.access_token;
    if (v.session && typeof v.session.access_token === 'string') return v.session.access_token;
    if (Array.isArray(v)) {
      for (var i = 0; i < v.length; i++) {
        var t = pluck(v[i]);
        if (t) return t;
      }
    }
    return null;
  }

  function scan(store) {
    if (!store) return null;
    for (var i = 0; i < store.length; i++) {
      var raw;
      try { raw = store.getItem(store.key(i)); } catch (e) { continue; }
      if (!raw || raw.indexOf('access_token') < 0) continue;   // cheap prefilter
      var v;
      try { v = JSON.parse(raw); } catch (e) { continue; }
      var t = pluck(v);
      if (t) return t;
    }
    return null;
  }

  function readToken() {
    try { var a = scan(window.localStorage); if (a) return a; } catch (e) {}
    try { var b = scan(window.sessionStorage); if (b) return b; } catch (e) {}
    // Last resort: app.js can expose its client as window.sb / window.supabaseClient
    try {
      var c = window.sb || window.supabaseClient;
      var s = c && c.auth && c.auth.session && c.auth.session();
      if (s && s.access_token) return s.access_token;
    } catch (e) {}
    return null;
  }

  function send(type, detail) {
    var headers = { 'Content-Type': 'application/json' };
    var token = readToken();
    if (token) headers.Authorization = 'Bearer ' + token;
    try {
      fetch(ENDPOINT, {
        method: 'POST',
        headers: headers,
        keepalive: true,
        body: JSON.stringify({
          type: type || 'page_view',
          detail: detail || location.pathname
        })
      }).catch(function () {});
    } catch (e) { /* tracking must never affect the page */ }
  }

  window.trackEvent = send;

  function idOf(t) { return t ? t.slice(-24) : ''; }
  var lastToken = '';
  var sentFirst = false;

  function firstHit() {
    if (sentFirst) return;
    sentFirst = true;
    lastToken = idOf(readToken());
    try {
      var KEY = 'zex_tracked_at';
      var now = Date.now();
      var prev = parseInt(sessionStorage.getItem(KEY) || '0', 10);
      if (prev && now - prev < VIEW_GAP_MS) return;
      sessionStorage.setItem(KEY, String(now));
    } catch (e) { /* private mode — just send */ }
    send('page_view');
  }

  // Wait for the session to hydrate. If a token shows up sooner, go at once.
  var waited = 0;
  var warmup = setInterval(function () {
    waited += 200;
    if (readToken() || waited >= FIRST_DELAY_MS) {
      clearInterval(warmup);
      firstHit();
    }
  }, 200);

  // A token appearing means a sign-in just happened — this is the moment that
  // ties the IP to the account. A token merely rotating (the hourly refresh)
  // is recorded quietly as a visit instead.
  setInterval(function () {
    var cur = idOf(readToken());
    if (cur && !lastToken && sentFirst) send('login');
    else if (cur && lastToken && cur !== lastToken) send('page_view');
    lastToken = cur;
  }, POLL_MS);

  // Returning from the bfcache counts as a fresh visit.
  window.addEventListener('pageshow', function (e) {
    if (e.persisted) send('page_view');
  });
})();
