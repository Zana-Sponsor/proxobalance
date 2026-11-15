/* Activity for the admin panel: which screen a signed-in account is on and
   for how long. Only time while the page is visible counts. One small call
   at most every 30 seconds (and when the screen changes or the page hides)
   to the database function ex_activity_ping, which also caps the seconds.
   Reads the app's own globals: _route, curUser, activeSession, SB_URL, SB_KEY. */
(function () {
  'use strict';
  var SID_KEY = 'px_activity_session';
  var IDLE_MS = 30 * 60 * 1000;      // a new visit after 30 minutes away
  var BEAT_MS = 30 * 1000;
  var current = null;                 // route being timed
  var since = 0;                      // when the visible stretch on it began (ms)
  var carry = 0;                      // seconds not sent yet for `current`
  var lastBeat = 0;

  function signedIn() {
    try { return !!(curUser && activeSession && activeSession.access_token); } catch (_) { return false; }
  }
  function routeNow() {
    try { return typeof _route === 'string' && _route ? _route : 'home'; } catch (_) { return 'home'; }
  }
  function uuid() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      var r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16);
    });
  }
  function sessionId() {
    var now = Date.now(), saved = null;
    try { saved = JSON.parse(sessionStorage.getItem(SID_KEY) || 'null'); } catch (_) {}
    var id = saved && saved.id && now - saved.at < IDLE_MS ? saved.id : uuid();
    try { sessionStorage.setItem(SID_KEY, JSON.stringify({ id: id, at: now })); } catch (_) {}
    return id;
  }
  function device() {
    var ua = navigator.userAgent || '';
    return /iPad|Tablet/i.test(ua) ? 'tablet' : /Mobi|Android|iPhone/i.test(ua) ? 'mobile' : 'desktop';
  }
  function visible() { return document.visibilityState === 'visible'; }

  function send(route, seconds, keepalive) {
    if (!signedIn() || !route) return;
    var body = JSON.stringify({ p_session: sessionId(), p_route: route, p_seconds: Math.max(0, Math.min(120, Math.round(seconds))), p_device: device() });
    try {
      fetch(SB_URL + '/rest/v1/rpc/ex_activity_ping', {
        method: 'POST',
        keepalive: !!keepalive,
        headers: { 'Content-Type': 'application/json', apikey: SB_KEY, Authorization: 'Bearer ' + activeSession.access_token },
        body: body
      }).catch(function () {});
    } catch (_) {}
    lastBeat = Date.now();
  }

  // close the running stretch and send what was gathered for `current`
  function flush(keepalive) {
    if (!current) return;
    if (since) { carry += (Date.now() - since) / 1000; since = visible() ? Date.now() : 0; }
    var seconds = carry; carry = 0;
    send(current, seconds, keepalive);
  }

  function tick() {
    if (!signedIn()) { current = null; since = 0; carry = 0; return; }
    var route = routeNow();
    if (route !== current) {
      flush(false);                    // the old screen gets its time
      current = route; carry = 0; since = visible() ? Date.now() : 0;
      send(current, 0, false);         // "now on this screen"
      return;
    }
    if (visible() && !since) since = Date.now();
    if (visible() && Date.now() - lastBeat >= BEAT_MS) flush(false);
  }

  document.addEventListener('visibilitychange', function () {
    if (!current) return;
    if (visible()) { since = Date.now(); return; }
    flush(true);                       // leaving: send while the page can still talk
    since = 0;
  });
  window.addEventListener('pagehide', function () { flush(true); since = 0; });
  setInterval(tick, 2000);
})();
