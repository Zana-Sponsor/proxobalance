'use strict';

/* Keep the customer UI in the supported light theme without inline JavaScript. */
document.documentElement.setAttribute('data-theme', 'light');
try {
  localStorage.setItem('zex_theme', 'light');
} catch (_) {}

/* If a request never returns, resolve loading placeholders to readable text. */
window.setTimeout(function () {
  ['historyPreview', 'txList', 'publicFeed'].forEach(function (id) {
    var el = document.getElementById(id);
    if (el && el.querySelector('.tx-skel, .feed-skel')) {
      el.innerHTML = '<div class="empty-state">نەتوانرا داتاکان باربکرێن — تکایە دووبارە هەوڵبدەوە</div>';
    }
  });

  document.querySelectorAll('.sk-num').forEach(function (item) {
    item.replaceWith('—');
  });
}, 12000);
