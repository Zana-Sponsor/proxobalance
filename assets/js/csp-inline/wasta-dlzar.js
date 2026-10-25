const urlParams = new URLSearchParams(window.location.search);
let selectedApp = '';
let selectedUrl = '';

function hideEffects() {
    const hand     = document.getElementById('click-hand');
    const shineBtn = document.querySelector('.shine-active');
    if (hand)     hand.classList.add('hidden');
    if (shineBtn) shineBtn.classList.add('no-shine');
}

function askConfirm(name, url, kurdishName) {
    selectedApp = name;
    selectedUrl = url;
    const btn   = document.getElementById('main-confirm-btn');
    const title = document.getElementById('modal-title');
    title.innerText = kurdishName;
    btn.className   = 'btn-confirm confirm-' + name.toLowerCase().substring(0, 2);
    document.getElementById('confirm-modal').classList.add('active');
    if (navigator.vibrate) navigator.vibrate(25);
}

function closeModal() { document.getElementById('confirm-modal').classList.remove('active'); }

function goLink() {
    hideEffects();

    // لۆژیکی نوێ بۆ پشکنینی ٢٤ کاتژمێر
    const lastTrackTime   = localStorage.getItem('tt_contact_timestamp');
    const currentTime     = new Date().getTime();
    const twentyFourHours = 24 * 60 * 60 * 1000; // ٢٤ کاتژمێر بە میلی چرکە

    if (window.ttq) {
        if (!lastTrackTime || (currentTime - lastTrackTime > twentyFourHours)) {
            ttq.track('Contact', { content_id: 'contact_button', content_name: selectedApp });
            localStorage.setItem('tt_contact_timestamp', currentTime);
        }
    }

    closeModal();
    setTimeout(() => { window.location.href = selectedUrl; }, 700);
}

!function (w, d, t) {
  w.TiktokAnalyticsObject = t;
  var ttq = w[t] = w[t] || [];
  ttq.methods = ['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'];
  ttq.setAndDefer = function(t, e) { t[e] = function() { t.push([e].concat(Array.prototype.slice.call(arguments, 0))); }; };
  for (var i = 0; i < ttq.methods.length; i++) ttq.setAndDefer(ttq, ttq.methods[i]);
  ttq.instance = function(t) {
    for (var e = ttq._i[t] || [], n = 0; n < ttq.methods.length; n++) ttq.setAndDefer(e, ttq.methods[n]);
    return e;
  };
  ttq.load = function(e, n) {
    var r = 'https://analytics.tiktok.com/i18n/pixel/events.js';
    ttq._i = ttq._i || {}; ttq._i[e] = []; ttq._i[e]._u = r;
    ttq._t = ttq._t || {}; ttq._t[e] = +new Date;
    ttq._o = ttq._o || {}; ttq._o[e] = n || {};
    var s = document.createElement('script');
    s.type = 'text/javascript'; s.async = true;
    s.src = r + '?sdkid=' + e + '&lib=' + t;
    e = document.getElementsByTagName('script')[0];
    e.parentNode.insertBefore(s, e);
  };
  ttq.load('D6BIIA3C77U1CE9DCUMG'); // ← Pixel ID دەتوانی لێرەدا بیگۆڕی
  ttq.page();
}(window, document, 'ttq');

document.addEventListener('DOMContentLoaded', function() {
  document.getElementById('wa').onclick = function(){
    askConfirm('whatsapp', 'whatsapp://send?phone=9647507675237', 'واتسئاپ');
  };
  document.getElementById('vb').onclick = function(){
    askConfirm('viber', 'viber://chat?number=9647507675237', 'ڤایبەر');
  };
  document.getElementById('ph').onclick = function(){
    askConfirm('phone', 'tel:9647507675237', 'کۆرەک');
  };
  window.onclick = function(e) { if (e.target.id === 'confirm-modal') closeModal(); }
  setTimeout(hideEffects, 10000);
  (function(){var b=document.querySelectorAll('.btn');var n=b.length;var m=n<=2?100:n<=3?120:n<=4?140:n<=5?160:180;var f=document.querySelector('.footer');if(f)f.style.marginTop=m+'px';})();
});
