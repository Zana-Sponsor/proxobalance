/* ═════════════════════════════════════════════════════════════════
   Private payment receipts.
   Orders keep the receipt's storage address as before
   (…/storage/v1/object/public/receipts/<user_id>/<file>). The bucket is
   private, so whenever such an address appears in an <img src> or <a href>
   it is swapped for a short-lived signed link made with the signed-in
   session. Supabase then checks the storage policy: a customer only gets
   their own folder, staff need the 'view' permission.
   Used by the customer app (index.html) and the admin panel. Needs the
   global `sb` Supabase client that both pages create.
   ═════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';
  var MARK = '/storage/v1/object/public/receipts/';
  var TTL = 3600;                        // seconds a signed link stays valid
  var cache = new Map();                 // path -> { url, until }
  var pending = new Map();               // path -> Promise

  function pathOf(address) {
    if (typeof address !== 'string') return null;
    var at = address.indexOf(MARK);
    if (at < 0) return null;
    try { return decodeURIComponent(address.slice(at + MARK.length).split(/[?#]/)[0]) || null; }
    catch (_) { return null; }
  }
  function client() {
    try { return (typeof sb !== 'undefined' && sb && sb.storage) ? sb : null; } catch (_) { return null; }
  }
  function sign(path) {
    var hit = cache.get(path);
    if (hit && hit.until > Date.now() + 60000) return Promise.resolve(hit.url);
    if (pending.has(path)) return pending.get(path);
    var job = Promise.resolve().then(function () {
      var c = client();
      if (!c) return null;
      return c.storage.from('receipts').createSignedUrl(path, TTL).then(function (res) {
        var url = res && !res.error && res.data && res.data.signedUrl;
        if (!url) return null;
        cache.set(path, { url: url, until: Date.now() + TTL * 1000 });
        return url;
      });
    }).catch(function () { return null; }).then(function (url) { pending.delete(path); return url; });
    pending.set(path, job);
    return job;
  }
  function swap(el, attr) {
    var before = el.getAttribute(attr);
    var path = pathOf(before);
    if (!path) return;
    el.setAttribute('data-receipt-loading', '');
    sign(path).then(function (url) {
      if (url && el.getAttribute(attr) === before) el.setAttribute(attr, url);
      el.removeAttribute('data-receipt-loading');
    });
  }
  var SELECT_IMG = 'img[src*="' + MARK + '"]', SELECT_LINK = 'a[href*="' + MARK + '"]';
  function scan(root) {
    if (!root || root.nodeType !== 1) return;
    if (root.matches(SELECT_IMG)) swap(root, 'src');
    if (root.matches(SELECT_LINK)) swap(root, 'href');
    root.querySelectorAll(SELECT_IMG).forEach(function (el) { swap(el, 'src'); });
    root.querySelectorAll(SELECT_LINK).forEach(function (el) { swap(el, 'href'); });
  }
  function start() {
    // hide the unsigned image for the instant before its signed link arrives
    var style = document.createElement('style');
    style.textContent = 'img[src*="' + MARK + '"],img[data-receipt-loading]{visibility:hidden}';
    document.head.appendChild(style);
    scan(document.body);
    new MutationObserver(function (changes) {
      changes.forEach(function (c) {
        if (c.type === 'attributes') scan(c.target);
        else c.addedNodes.forEach(scan);
      });
    }).observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ['src', 'href'] });
  }

  // For code that needs the link itself (e.g. to open in a new tab).
  window.ProxoReceipts = {
    pathOf: pathOf,
    signedUrl: function (address) {
      var path = pathOf(address);
      return path ? sign(path).then(function (url) { return url || address; }) : Promise.resolve(address);
    }
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
