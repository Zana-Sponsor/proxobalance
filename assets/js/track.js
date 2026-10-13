/* assets/js/track.js
 *
 * Tells the server "someone is here" so it can record the real public IP
 * against the account. Standalone on purpose: it reads the Supabase session
 * straight out of localStorage, so it does not need anything from app.js and
 * cannot break it. Load it AFTER app.js.
 *
 * Also exposes window.trackEvent(type, detail) for app.js to call directly,
 * e.g. after a failed login:  trackEvent('login_failed', email)
 */
(function () {
  'use strict';

  var ENDPOINT = '/api/track';
  var POLL_MS = 5000;
  var VIEW_GAP_MS = 10 * 60 * 1000;   // one page_view per 10 minutes per tab

  // The app deliberately uses a custom storageKey. Check it first; looking only
  // for Supabase's default "sb-<ref>-auth-token" name makes every authenticated
  // page view look anonymous to /api/track.
  var SESSION_KEYS = [
    'zex_sb_session',
    'sb-pycxuugoblkslvwebxuu-auth-token'
  ];

  function tokenFromRaw(raw) {
    if (!raw) return null;
    try {
      var v = JSON.parse(raw);
      return v && (
        v.access_token ||
        (v.currentSession && v.currentSession.access_token) ||
        (v.session && v.session.access_token)
      ) || null;
    } catch (e) { return null; }
  }

  function readToken() {
    try {
      for (var i = 0; i < SESSION_KEYS.length; i++) {
        var t = tokenFromRaw(localStorage.getItem(SESSION_KEYS[i]));
        if (t) return t;
      }
    } catch (e) { /* private mode, quota, bad JSON — never throw */ }
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

  function fingerprintOf(t) { return t ? t.slice(-24) : ''; }
  var lastToken = fingerprintOf(readToken());

  // First hit of this tab (rate limited so a reload does not spam the table).
  try {
    var KEY = 'zex_tracked_at';
    var now = Date.now();
    var prev = parseInt(sessionStorage.getItem(KEY) || '0', 10);
    if (!prev || now - prev > VIEW_GAP_MS) {
      sessionStorage.setItem(KEY, String(now));
      send('page_view');
    }
  } catch (e) {
    send('page_view');
  }

  // A token appearing means a sign-in just happened — this is the moment that
  // ties the IP to the account. A token merely rotating (hourly refresh) is
  // recorded quietly as a visit instead.
  setInterval(function () {
    var cur = fingerprintOf(readToken());
    if (cur && !lastToken) send('login');
    else if (cur && cur !== lastToken) send('page_view');
    lastToken = cur;
  }, POLL_MS);

  // Returning from the bfcache counts as a fresh visit.
  window.addEventListener('pageshow', function (e) {
    if (e.persisted) send('page_view');
  });
})();
