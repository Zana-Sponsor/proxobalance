// ignore_for_file: prefer_single_quotes
/// 8 card style HTML templates — placeholders:
/// {{GRAD}} {{AVATAR}} {{NAME}} {{BIO}} {{BUTTONS}} {{TT_BADGE}} {{TT_INLINE}}
/// {{THEME_FROM}} {{THEME_TO}} {{HANDLERS}}
///
/// {{GRAD}}, {{THEME_FROM}}, {{THEME_TO}} mirror proxo-tools.js's per-style
/// `theme.grad` / `theme.from` / `theme.to` usage exactly (verified against
/// buildPageDark/Light/Classic/Pill/Card/Neon/Zoom/Banner in proxo-tools.js):
///   • dark, light        -> {{GRAD}} on .gradient-bg only
///   • classic             -> {{GRAD}} on .top-banner only
///   • pill, card          -> {{GRAD}} on .hdr, {{THEME_FROM}} on .av background
///   • neon                -> {{GRAD}} on .hdr, {{THEME_FROM}} on .av background,
///                            {{THEME_TO}}99 on .av's glow box-shadow (alpha ~60%)
///   • zoom                -> {{GRAD}} on .hdr, {{THEME_FROM}} on .av background,
///                            {{THEME_TO}}66 on .av's glow box-shadow (alpha ~40%)
///   • banner              -> {{GRAD}} on .hdr only
/// An earlier version of this file hardcoded the default purple gradient
/// (#5b1fa8/#c855e0) directly into every template's CSS instead of using
/// these placeholders at all — meaning changing the theme color in the
/// form had NO visible effect on the generated card, for any of the 8
/// styles. Fixed: every {{GRAD}}/{{THEME_FROM}}/{{THEME_TO}} spot above is
/// now a real placeholder, filled by buildCardHtml() in html_generator.dart.
///
/// {{HANDLERS}} is replaced with the real per-platform click-handler script,
/// generated from the actual selected platforms + the contact values the
/// user entered (see html_generator.dart -> _buildHandlersScript). Each
/// template used to ship with 4 hardcoded demo handlers (wa/vb/ig/tg only,
/// pointing at a placeholder phone number / the @proxo_iq demo accounts) —
/// that dead-weight/incorrect script has been removed in favor of this
/// placeholder so every generated card actually calls the numbers/usernames
/// the user typed in, for all 6 platforms (including phone/Korek + Asiacell,
/// which the old hardcoded script silently ignored).
class CardTemplates {
  CardTemplates._();

  // ─────────────────────────────────────────────────────────────
  // 1. DARK  — تاریک
  //    • bg: #0d1021  • header: 190px gradient  • avatar: 100px
  //    • buttons: 2×2 grid glass (no fill)  • TikTok: grid item badge
  // ─────────────────────────────────────────────────────────────
  static const String dark = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face { font-family: 'Rabar_021'; src: url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2'); }
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@600&display=swap');
* { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
body { font-family: 'Inter', 'Rabar_021', sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; background: #0d1021; min-height: 100vh; }
.page { width: 100%; max-width: 430px; min-height: 100vh; display: flex; flex-direction: column; align-items: center; background: #0d1021; }
.top-section { width: 100%; position: relative; }
.gradient-bg { width: 100%; height: 190px; background: {{GRAD}}; position: relative; }
.gradient-bg::after { content: ''; position: absolute; bottom: 0; left: 0; width: 100%; height: 55px; background: #0d1021; border-radius: 50% 50% 0 0 / 55px 55px 0 0; }
.avatar { position: absolute; top: 40px; left: 50%; transform: translateX(-50%); width: 100px; height: 100px; border-radius: 50%; border: 5px solid #fff; overflow: hidden; background: #fff; box-shadow: 0 4px 24px rgba(0,0,0,.4); z-index: 10; }
.avatar img { width: 100%; height: 100%; object-fit: cover; display: block; }
.content { width: 100%; display: flex; flex-direction: column; align-items: center; padding: 0 16px 50px; background: #0d1021; }
.name { font-size: 19px; font-weight: 600; color: #fff; text-align: center; position: relative; top: -25px; margin-bottom: -10px; font-family: 'Inter', 'Rabar_021', sans-serif; }
.desc { font-size: 14px; color: #EDEDED; line-height: 2; text-align: center; margin-top: 18px; padding: 0 6px; white-space: pre-line; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; width: 100%; margin-top: 40px; }
.btn { position: relative; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 8px; padding: 18px 8px 15px; border-radius: 18px;
  font-size: 14px; font-weight: bold; color: #fff; min-height: 88px; cursor: pointer;
  text-decoration: none; overflow: hidden; transition: transform .13s;
  background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.15); }
.btn:active { transform: scale(.96); background: rgba(255,255,255,.12); }
.btn i { font-size: 28px; }
#wa i { font-size: 25px; }
#vb i { font-size: 22px; }
#tg i { font-size: 22px; }
#ig i { font-size: 22px; }
#ph i { font-size: 20px; }
#as i { font-size: 20px; }
.three-bottom-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; width: 100%; margin-top: 10px; align-items: center; }
.tt-pill { display: inline-flex; flex-direction: row; align-items: center;
  justify-content: center; gap: 7px; padding: 9px 16px; border-radius: 90px;
  background: rgba(255,255,255,0.03); -webkit-backdrop-filter: blur(5px);backdrop-filter: blur(5px); color: #fff;
  text-decoration: none; font-family: 'Rabar_021', sans-serif; font-size: 13.5px;
  font-weight: 600; position: relative; border: 1px solid rgba(255,255,255,0.1);
  width: 100%; box-sizing: border-box; }
.tt-pill::before { content: ''; position: absolute; inset: -1px; border-radius: 90px; padding: 1.2px; background: linear-gradient(45deg, #69c9d0, #ee1d52); -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0); mask-composite: exclude; opacity: .7; }
.tt-pill i { font-size: 18px; position: relative; z-index: 1; }
.tt-pill span { position: relative; z-index: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; direction: ltr; }
.tt-pill:active { transform: scale(.95); }
.tt-wrap { display: flex; justify-content: center; width: 100%; }
.tt-badge { background: rgba(255,255,255,0.03); -webkit-backdrop-filter: blur(5px);backdrop-filter: blur(5px); color: #fff;
  text-decoration: none; display: flex; flex-direction: row; align-items: center;
  gap: 8px; padding: 7px 18px; border-radius: 90px;
  border: 1px solid rgba(255,255,255,0.1); position: relative; margin-top: 14px;
  font-family: 'Rabar_021', sans-serif; font-size: 14.5px; font-weight: 600; }
.tt-badge::before { content: ''; position: absolute; inset: -1px; border-radius: 50px; padding: 1.2px; background: linear-gradient(45deg, #69c9d0, #ee1d52); -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0); mask-composite: exclude; opacity: .6; }
.tt-badge i { font-size: 17px; position: relative; z-index: 1; }
.tt-badge span { position: relative; z-index: 1; direction: ltr; }
.tt-badge:active { transform: scale(.95); }
.footer { width: 100%; margin-top: 100px; padding-bottom: 28px; text-align: center; }
.footer small { display: block; font-size: 11px; color: #999; margin-bottom: 8px; }
.footer img { height: 13px; display: block; margin: 0 auto 10px; }
.legal { font-size: 10px; color: #999; }
.legal a { color: inherit; text-decoration: none; margin: 0 5px; }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.75); -webkit-backdrop-filter: blur(8px);backdrop-filter: blur(8px); display: none; justify-content: center; align-items: center; z-index: 10000; }
.modal-overlay.active { display: flex; animation: fadeIn 0.2s ease; }
.modal-content { width: 85%; max-width: 320px; padding: 35px 25px; border-radius: 24px; text-align: center; box-shadow: 0 20px 50px rgba(0,0,0,0.3); background: #16181d; color: #fff; border: 1px solid rgba(255,255,255,0.1); }
.modal-content h3 { margin: 0 0 16px; font-size: 20px; }
.modal-content p { font-size: 14px; opacity: 0.7; margin-bottom: 25px; line-height: 1.6; }
.btn-confirm { width: 100%; padding: 16px; border-radius: 16px; border: none; font-family: 'Rabar_021'; font-size: 16px; font-weight: bold; cursor: pointer; transition: 0.2s; margin-bottom: 12px; }
.btn-cancel { color: #888; font-size: 14px; cursor: pointer; display: inline-block; padding: 5px; }
.btn-confirm.confirm-wh { background: #28E16D; color: #000; }
.btn-confirm.confirm-vi { background: #7360f2; color: #fff; }
.btn-confirm.confirm-te { background: #26A5E4; color: #fff; }
.btn-confirm.confirm-ph { background: #fff;    color: #000; }
.btn-confirm.confirm-as { background: #e03030; color: #fff; }
.btn-confirm.confirm-in { background: #dc2743; color: #fff; }
@keyframes shine { 0% { left: -100%; } 100% { left: 150%; } }
.shine-active { overflow: hidden; position: relative; }
.shine-active::after { content:''; position:absolute; top:0; left:-100%; width:60%; height:100%; background:linear-gradient(to right,transparent,rgba(255,255,255,0.12),transparent); transform:skewX(-25deg); animation: shine 2.5s ease-in-out infinite; pointer-events:none; border-radius:inherit; }
.no-shine::after { animation: none !important; display:none; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
</style>
</head>
<body>
<div class="modal-overlay" id="confirm-modal"><div class="modal-content"><h3 id="modal-title" dir="auto">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="main-confirm-btn" class="btn-confirm" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="btn-cancel" onclick="closeModal()">پاشگەزبوونەوە</div></div></div>
<div class="page">
  <div class="top-section"><div class="gradient-bg"></div><div class="avatar">{{AVATAR}}</div></div>
  <div class="content">
    <h1 class="name" dir="auto">{{NAME}}</h1>
    <p class="desc" dir="auto">{{BIO}}</p>
    <div class="grid">{{BUTTONS}}</div>{{TT_BADGE}}
    <div class="footer"><small>سپۆنسەرکراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
  </div>
</div>
<script>
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
{{HANDLERS}}
  window.onclick = function(e) { if (e.target.id === 'confirm-modal') closeModal(); }
  setTimeout(hideEffects, 10000);
  // فووتەر خۆکار
  (function(){var b=document.querySelectorAll('.btn');var n=b.length;var m=n<=2?100:n<=3?120:n<=4?140:n<=5?160:180;var f=document.querySelector('.footer');if(f)f.style.marginTop=m+'px';})();
});
</script></body></html>
  ''';

  // ─────────────────────────────────────────────────────────────
  // 2. LIGHT  — ڕووناک
  //    • bg: #fff  • header: 190px gradient  • avatar: 100px
  //    • buttons: 2×2 grid COLORED gradient  • TikTok: small pill below grid
  // ─────────────────────────────────────────────────────────────
  static const String light = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face { font-family: 'Rabar_021'; src: url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2'); }
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@600&display=swap');
* { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
body { font-family: 'Inter', 'Rabar_021', sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; background: #f0f0f0; min-height: 100vh; }
.page { width: 100%; max-width: 430px; background: #fff; min-height: 100vh; display: flex; flex-direction: column; align-items: center; }
.top-section { width: 100%; position: relative; }
.gradient-bg { width: 100%; height: 190px; background: {{GRAD}}; position: relative; }
.gradient-bg::after { content: ''; position: absolute; bottom: 0; left: 0; width: 100%; height: 55px; background: #fff; border-radius: 50% 50% 0 0 / 55px 55px 0 0; }
.avatar { position: absolute; top: 40px; left: 50%; transform: translateX(-50%); width: 100px; height: 100px; border-radius: 50%; border: 5px solid #fff; overflow: hidden; background: #ddd; box-shadow: 0 4px 24px rgba(0,0,0,.25); z-index: 10; }
.avatar img { width: 100%; height: 100%; object-fit: cover; display: block; }
.content { width: 100%; display: flex; flex-direction: column; align-items: center; padding: 0 16px 50px; background: #fff; }
.name { font-size: 19px; font-weight: 600; color: #111; text-align: center; position: relative; top: -25px; margin-bottom: -10px; font-family: 'Inter', 'Rabar_021', sans-serif; }
.desc { font-size: 14px; color: #333; line-height: 2; text-align: center; margin-top: 18px; padding: 0 6px; white-space: pre-line; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; width: 100%; margin-top: 40px; }
.btn { position: relative; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 8px; padding: 18px 8px 15px; border-radius: 18px;
  font-size: 14px; font-weight: bold; color: #fff; min-height: 88px; cursor: pointer;
  text-decoration: none; overflow: hidden; transition: transform .13s; background: #888; box-shadow: 0 4px 14px rgba(0,0,0,.15); }
#vb { background: linear-gradient(135deg, #5b40e8, #7b65f2); }
#wa { background: linear-gradient(135deg, #1aad4e, #25d366); }
#ig { background: linear-gradient(to right, #8a2387, #e94057, #f27121); }
#tg { background: linear-gradient(135deg, #0c85c2, #29a8eb); }
#ph { background: #e03030; } #as { background: #e03030; }
.btn:active { transform: scale(.96); }
.btn i { font-size: 28px; }
#wa i { font-size: 25px; }
#vb i { font-size: 22px; }
#tg i { font-size: 22px; }
#ig i { font-size: 22px; }
#ph i { font-size: 20px; }
#as i { font-size: 20px; }
.three-bottom-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; width: 100%; margin-top: 10px; align-items: center; }
.tt-pill { display: inline-flex; flex-direction: row; align-items: center;
  justify-content: center; gap: 7px; padding: 9px 16px; border-radius: 90px;
  background: rgba(255,255,255,0.06); color: #111; text-decoration: none;
  font-family: 'Rabar_021', sans-serif; font-size: 13.5px; font-weight: 600;
  position: relative; border: 1px solid rgba(0,0,0,0.12); width: 100%; box-sizing: border-box; }
.tt-pill::before { content: ''; position: absolute; inset: -1px; border-radius: 90px; padding: 1.2px; background: linear-gradient(45deg, #69c9d0, #ee1d52); -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0); mask-composite: exclude; opacity: .65; }
.tt-pill i { font-size: 18px; position: relative; z-index: 1; }
.tt-pill span { position: relative; z-index: 1; direction: ltr; }
.tt-pill:active { transform: scale(.95); }
.tt-wrap { display: flex; justify-content: center; width: 100%; }
.tt-badge { background: rgba(0,0,0,0.04); color: #111; text-decoration: none;
  display: flex; flex-direction: row; align-items: center; gap: 8px;
  padding: 7px 18px; border-radius: 90px; border: 1px solid rgba(0,0,0,0.1);
  position: relative; margin-top: 14px; font-family: 'Rabar_021', sans-serif; font-size: 14.5px; font-weight: 600; }
.tt-badge::before { content: ''; position: absolute; inset: -1px; border-radius: 50px; padding: 1.2px; background: linear-gradient(45deg, #69c9d0, #ee1d52); -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0); mask-composite: exclude; opacity: .6; }
.tt-badge i { font-size: 17px; position: relative; z-index: 1; }
.tt-badge span { position: relative; z-index: 1; direction: ltr; }
.tt-badge:active { transform: scale(.95); }
.footer { width: 100%; margin-top: 100px; padding-bottom: 28px; text-align: center; }
.footer small { display: block; font-size: 11px; color: #999; margin-bottom: 8px; }
.footer img { height: 13px; display: block; margin: 0 auto 10px; }
.legal { font-size: 10px; color: #999; }
.legal a { color: inherit; text-decoration: none; margin: 0 5px; }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.75); -webkit-backdrop-filter: blur(8px);backdrop-filter: blur(8px); display: none; justify-content: center; align-items: center; z-index: 10000; }
.modal-overlay.active { display: flex; animation: fadeIn 0.2s ease; }
.modal-content { width: 85%; max-width: 320px; padding: 35px 25px; border-radius: 24px; text-align: center; box-shadow: 0 20px 50px rgba(0,0,0,0.3); background: #16181d; color: #fff; border: 1px solid rgba(255,255,255,0.1); }
.modal-content h3 { margin: 0 0 16px; font-size: 20px; }
.modal-content p { font-size: 14px; opacity: 0.7; margin-bottom: 25px; line-height: 1.6; }
.btn-confirm { width: 100%; padding: 16px; border-radius: 16px; border: none; font-family: 'Rabar_021'; font-size: 16px; font-weight: bold; cursor: pointer; transition: 0.2s; margin-bottom: 12px; }
.btn-cancel { color: #888; font-size: 14px; cursor: pointer; display: inline-block; padding: 5px; }
.btn-confirm.confirm-wh { background: #28E16D; color: #000; }
.btn-confirm.confirm-vi { background: #7360f2; color: #fff; }
.btn-confirm.confirm-te { background: #26A5E4; color: #fff; }
.btn-confirm.confirm-ph { background: #fff;    color: #000; }
.btn-confirm.confirm-as { background: #e03030; color: #fff; }
.btn-confirm.confirm-in { background: #dc2743; color: #fff; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
@keyframes shine { 0% { left: -100%; } 100% { left: 150%; } }
.shine-active { overflow: hidden; position: relative; }
.shine-active::after { content:''; position:absolute; top:0; left:-100%; width:60%; height:100%; background:linear-gradient(to right,transparent,rgba(255,255,255,0.12),transparent); transform:skewX(-25deg); animation: shine 2.5s ease-in-out infinite; pointer-events:none; border-radius:inherit; }
.no-shine::after { animation: none !important; display:none; }
</style>
</head>
<body>
<div class="modal-overlay" id="confirm-modal"><div class="modal-content"><h3 id="modal-title" dir="auto">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="main-confirm-btn" class="btn-confirm" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="btn-cancel" onclick="closeModal()">پاشگەزبوونەوە</div></div></div>
<div class="page">
  <div class="top-section"><div class="gradient-bg"></div><div class="avatar">{{AVATAR}}</div></div>
  <div class="content">
    <h1 class="name" dir="auto">{{NAME}}</h1>
    <p class="desc" dir="auto">{{BIO}}</p>
    <div class="grid">{{BUTTONS}}</div>{{TT_BADGE}}
    <div class="footer"><small>سپۆنسەرکراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
  </div>
</div>
<script>
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
{{HANDLERS}}
  window.onclick = function(e) { if (e.target.id === 'confirm-modal') closeModal(); }
  setTimeout(hideEffects, 10000);
  (function(){var b=document.querySelectorAll('.btn');var n=b.length;var m=n<=2?100:n<=3?120:n<=4?140:n<=5?160:180;var f=document.querySelector('.footer');if(f)f.style.marginTop=m+'px';})();
});
</script></body></html>
  ''';

  // ─────────────────────────────────────────────────────────────
  // 3. CLASSIC  — کلاسیک
  //    • bg: #f0f0f0  • header: wide banner (no avatar, name+bio inside)
  //    • buttons: full-width list, radius 50px, icon RIGHT side
  //    • TikTok: black pill at bottom of card
  // ─────────────────────────────────────────────────────────────
  static const String classic = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face { font-family: 'Rabar_021'; src: url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2'); }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Rabar_021', sans-serif; background: #f0f0f0; display: flex; justify-content: center; min-height: 100vh; }
.page { width: 100%; max-width: 430px; min-height: 100vh; display: flex; flex-direction: column; align-items: center; background: #f0f0f0; padding-bottom: 60px; }
.top-banner { width: 100%; background: {{GRAD}}; padding: 36px 20px 60px; text-align: center; }
.name { font-size: 22px; font-weight: 600; color: #fff; text-shadow: 0 1px 4px rgba(0,0,0,.3); font-family: 'Inter', 'Rabar_021', sans-serif; }
.desc { font-size: 14px; color: rgba(255,255,255,.9); line-height: 1.9; text-align: center; margin-top: 10px; padding: 0 10px; white-space: pre-line; }
.content { width: 100%; padding: 0 18px; margin-top: -30px; }
.card-inner { background: #fff; border-radius: 24px; padding: 24px 16px 20px; box-shadow: 0 4px 24px rgba(0,0,0,.1); display: flex; flex-direction: column; gap: 10px; align-items: center; }
.btn-classic { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; padding: 14px 16px; border-radius: 50px; font-size: 16px; font-weight: 700; color: #fff; text-decoration: none; cursor: pointer; transition: transform .12s, opacity .12s; width: 100%; }
.btn-classic:active { transform: scale(.97); opacity: .9; }
.btn-classic .ic-wrap { display: flex; align-items: center; justify-content: center; font-size: 22px; }
.btn-classic span { text-align: center; }
.btn-classic .ic-spacer { width: 44px; }
.tt-classic { display: flex; align-items: center; justify-content: center;
  gap: 7px; margin-top: 4px; padding: 8px 20px; border-radius: 50px;
  background: #111; color: #fff; text-decoration: none;
  font-family: 'Rabar_021', sans-serif; font-size: 13px; font-weight: 600; transition: transform .12s; }
.tt-classic i { font-size: 18px; }
#wa i { font-size: 25px; }
#vb i { font-size: 22px; }
#tg i { font-size: 22px; }
#ig i { font-size: 22px; }
#ph i { font-size: 20px; }
#as i { font-size: 20px; }
.tt-classic:active { transform: scale(.96); }
.footer { width: 100%; margin-top: 80px; padding: 0 18px 20px; text-align: center; }
.footer small { display: block; font-size: 11px; color: #bbb; margin-bottom: 8px; }
.footer img { height: 13px; display: block; margin: 0 auto 10px; }
.legal { font-size: 10px; color: #bbb; }
.legal a { color: inherit; text-decoration: none; margin: 0 5px; }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.75); -webkit-backdrop-filter: blur(8px);backdrop-filter: blur(8px); display: none; justify-content: center; align-items: center; z-index: 10000; }
.modal-overlay.active { display: flex; animation: fadeIn 0.2s ease; }
.modal-content { width: 85%; max-width: 320px; padding: 35px 25px; border-radius: 24px; text-align: center; box-shadow: 0 20px 50px rgba(0,0,0,0.3); background: #16181d; color: #fff; border: 1px solid rgba(255,255,255,0.1); }
.modal-content h3 { margin: 0 0 16px; font-size: 20px; }
.modal-content p { font-size: 14px; opacity: 0.7; margin-bottom: 25px; line-height: 1.6; }
.btn-confirm { width: 100%; padding: 16px; border-radius: 16px; border: none; font-family: 'Rabar_021'; font-size: 16px; font-weight: bold; cursor: pointer; transition: 0.2s; margin-bottom: 12px; }
.btn-cancel { color: #888; font-size: 14px; cursor: pointer; display: inline-block; padding: 5px; }
.btn-confirm.confirm-wh { background: #28E16D; color: #000; }
.btn-confirm.confirm-vi { background: #7360f2; color: #fff; }
.btn-confirm.confirm-te { background: #26A5E4; color: #fff; }
.btn-confirm.confirm-ph { background: #fff;    color: #000; }
.btn-confirm.confirm-as { background: #e03030; color: #fff; }
.btn-confirm.confirm-in { background: #dc2743; color: #fff; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
@keyframes shine { 0% { left: -100%; } 100% { left: 150%; } }
.shine-active { overflow: hidden; position: relative; }
.shine-active::after { content:''; position:absolute; top:0; left:-100%; width:60%; height:100%; background:linear-gradient(to right,transparent,rgba(255,255,255,0.12),transparent); transform:skewX(-25deg); animation: shine 2.5s ease-in-out infinite; pointer-events:none; border-radius:inherit; }
.no-shine::after { animation: none !important; display:none; }
</style>
</head>
<body>
<div class="modal-overlay" id="confirm-modal"><div class="modal-content"><h3 id="modal-title" dir="auto">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="main-confirm-btn" class="btn-confirm" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="btn-cancel" onclick="closeModal()">پاشگەزبوونەوە</div></div></div>
<div class="page">
  <div class="top-banner"><h1 class="name" dir="auto">{{NAME}}</h1><p class="desc" dir="auto">{{BIO}}</p></div>
  <div class="content"><div class="card-inner">{{BUTTONS}}{{TT_BADGE}}</div></div>
  <div class="footer"><small>سپۆنسەرکراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
</div>
<script>
const urlParams = new URLSearchParams(window.location.search);
let selectedApp = '';
let selectedUrl = '';

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
{{HANDLERS}}
  window.onclick = function(e) { if (e.target.id === 'confirm-modal') closeModal(); }
  setTimeout(function(){ var s=document.querySelector('.shine-active'); if(s) s.classList.add('no-shine'); }, 10000);
  (function(){var b=document.querySelectorAll('.btn-classic');var n=b.length;var m=n<=2?80:n<=3?100:n<=4?120:n<=5?140:160;var f=document.querySelector('.footer');if(f)f.style.marginTop=m+'px';})();
});
</script></body></html>
  ''';

  // ─────────────────────────────────────────────────────────────
  // 4. PILL  — پیل
  //    • bg: #fff  • header: 110px  • avatar: 90px overlapping
  //    • buttons: full-width PILL radius:50px  • TikTok: black pill below
  // ─────────────────────────────────────────────────────────────
  static const String pill = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face{font-family:'R';src:url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2');}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}
body{font-family:'R',sans-serif;background:#f0f2f8;min-height:100vh;display:flex;justify-content:center;}
.wrap{width:100%;max-width:430px;min-height:100vh;background:#fff;display:flex;flex-direction:column;}
.hdr{height:110px;background:{{GRAD}};}
.av-wrap{display:flex;justify-content:center;margin-top:-45px;margin-bottom:14px;}
.av{width:90px;height:90px;border-radius:50%;border:4px solid #fff;overflow:hidden;background:{{THEME_FROM}};display:flex;align-items:center;justify-content:center;font-size:36px;font-weight:800;color:#fff;box-shadow:0 4px 18px rgba(0,0,0,.2);}
.av img{width:100%;height:100%;object-fit:cover;display:block;}
.profile{padding:0 22px;text-align:center;margin-bottom:24px;}
.uname{font-size:19px;font-weight:700;color:#111;margin-bottom:5px;}
.ubio{font-size:14px;color:#777;line-height:1.9;white-space:pre-line;}
.btns{padding:0 22px;display:flex;flex-direction:column;gap:12px;}
.pl-btn{display:flex;align-items:center;width:100%;padding:15px 14px;border-radius:50px;color:#fff;text-decoration:none;cursor:pointer;transition:transform .13s,opacity .13s;position:relative;overflow:hidden;}
.pl-btn:active{transform:scale(.97);opacity:.92;}
.pl-lbl{flex:1;text-align:center;font-size:17px;font-weight:700;}
.tt-wrap{display:flex;justify-content:center;margin:14px 22px 0;}
.tt-sm{display:inline-flex;align-items:center;gap:7px;padding:10px 22px;border-radius:50px;background:#111;color:#fff;text-decoration:none;font-size:14px;font-weight:700;}
.tt-sm:active{transform:scale(.97);}
.footer{width:100%;margin-top:auto;padding:60px 20px 24px;text-align:center;}
.footer small{display:block;font-size:11px;color:#bbb;margin-bottom:6px;font-weight:600;}
.footer img{height:15px;display:block;margin:0 auto 10px;opacity:.75;}
.legal{font-size:10px;color:#bbb;}.legal a{color:inherit;text-decoration:none;margin:0 5px;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);display:none;justify-content:center;align-items:center;z-index:9999;-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);}
.modal-overlay.active{display:flex;animation:fi .2s ease;}
.modal-box{width:84%;max-width:310px;background:#fff;border-radius:22px;padding:30px 22px;text-align:center;}
.modal-box h3{font-size:19px;font-weight:800;color:#111;margin-bottom:10px;}
.modal-box p{font-size:13px;color:#777;margin-bottom:22px;line-height:1.7;}
.modal-ok{width:100%;padding:15px;border-radius:50px;border:none;font-family:'R';font-size:16px;font-weight:800;cursor:pointer;margin-bottom:10px;color:#fff;}
.modal-cancel{font-size:13px;color:#aaa;cursor:pointer;padding:4px;}
.modal-ok.ok-wh{background:linear-gradient(to left,#128c7e,#25d366);}.modal-ok.ok-vi{background:linear-gradient(to left,#5c4fd6,#7360f2);}.modal-ok.ok-te{background:linear-gradient(to left,#229ed9,#2aabee);}.modal-ok.ok-ig{background:linear-gradient(to left,#833ab4,#fd1d1d,#f09433);}.modal-ok.ok-ph{background:linear-gradient(to left,#1d4ed8,#2563eb);}.modal-ok.ok-as{background:linear-gradient(to left,#b91c1c,#dc2626);}
@keyframes fi{from{opacity:0}to{opacity:1}}@keyframes sh{0%{left:-100%}100%{left:160%}}
.shine-active::after{content:'';position:absolute;top:0;left:-100%;width:55%;height:100%;background:linear-gradient(to right,transparent,rgba(255,255,255,.18),transparent);transform:skewX(-20deg);animation:sh 2.4s ease-in-out infinite;pointer-events:none;}
.no-sh::after{animation:none!important;display:none;}
</style></head><body>
<div class="modal-overlay" id="mod"><div class="modal-box"><h3 id="mod-ttl">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="mod-ok" class="modal-ok" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="modal-cancel" onclick="closeMod()">پاشگەزبوونەوە</div></div></div>
<div class="wrap">
  <div class="hdr"></div>
  <div class="av-wrap"><div class="av">{{AVATAR}}</div></div>
  <div class="profile"><div class="uname" dir="auto">{{NAME}}</div><div class="ubio" dir="auto">{{BIO}}</div></div>
  <div class="btns">{{BUTTONS}}</div>
  <div class="tt-wrap">{{TT_BADGE}}</div>
  <div class="footer"><small>سپۆنسەر کراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
</div>
<script>
let _app='',_url='';
function askConfirm(n,u,k){_app=n;_url=u;document.getElementById('mod-ttl').innerText=k;var cls='ok-'+n.substring(0,2);if(n==='telegram')cls='ok-te';document.getElementById('mod-ok').className='modal-ok '+cls;document.getElementById('mod').classList.add('active');if(navigator.vibrate)navigator.vibrate(22);}
function closeMod(){document.getElementById('mod').classList.remove('active');}
function goLink(){const lt=localStorage.getItem('tt_ct');const ct=Date.now();if(window.ttq&&(!lt||ct-lt>86400000)){ttq.track('Contact',{content_id:'contact_button',content_name:_app});localStorage.setItem('tt_ct',ct);}closeMod();setTimeout(()=>{window.location.href=_url;},700);}
!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)));};};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e;};ttq.load=function(e,n){var r='https://analytics.tiktok.com/i18n/pixel/events.js';ttq._i=ttq._i||{};ttq._i[e]=[];ttq._i[e]._u=r;ttq._t=ttq._t||{};ttq._t[e]=+new Date;ttq._o=ttq._o||{};ttq._o[e]=n||{};var s=document.createElement('script');s.type='text/javascript';s.async=!0;s.src=r+'?sdkid='+e+'&lib='+t;var x=document.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};ttq.load('D6BIIA3C77U1CE9DCUMG');ttq.page();}(window,document,'ttq');
document.addEventListener('DOMContentLoaded',function(){
  {{HANDLERS}}
  window.onclick=function(e){if(e.target.id==='mod')closeMod();};
  setTimeout(function(){var s=document.querySelector('.shine-active');if(s)s.classList.add('no-sh');},10000);
});
</script></body></html>
  ''';

  // ─────────────────────────────────────────────────────────────
  // 5. CARD  — کارد
  //    • bg: #eef0f5/#fff  • header: 110px  • avatar: 90px overlapping
  //    • buttons: full-width CARD radius:20px  • TikTok: rect badge radius:20px
  // ─────────────────────────────────────────────────────────────
  static const String card = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face{font-family:'R';src:url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2');}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}
body{font-family:'R',sans-serif;background:#eef0f5;min-height:100vh;display:flex;justify-content:center;}
.wrap{width:100%;max-width:430px;min-height:100vh;background:#fff;display:flex;flex-direction:column;}
.hdr{height:110px;background:{{GRAD}};}
.av-wrap{display:flex;justify-content:center;margin-top:-45px;margin-bottom:14px;}
.av{width:90px;height:90px;border-radius:50%;border:4px solid #fff;overflow:hidden;background:{{THEME_FROM}};display:flex;align-items:center;justify-content:center;font-size:36px;font-weight:800;color:#fff;box-shadow:0 4px 18px rgba(0,0,0,.2);}
.av img{width:100%;height:100%;object-fit:cover;display:block;}
.profile{padding:0 22px;text-align:center;margin-bottom:24px;}
.uname{font-size:19px;font-weight:700;color:#111;margin-bottom:5px;}
.ubio{font-size:14px;color:#777;line-height:1.9;white-space:pre-line;}
.btns{padding:0 22px;display:flex;flex-direction:column;gap:12px;}
.pl-btn{display:flex;align-items:center;width:100%;padding:15px 14px;border-radius:20px;color:#fff;text-decoration:none;cursor:pointer;transition:transform .13s,opacity .13s;position:relative;overflow:hidden;}
.pl-btn:active{transform:scale(.97);opacity:.92;}
.pl-lbl{flex:1;text-align:center;font-size:17px;font-weight:700;}
.tt-wrap{display:flex;justify-content:center;margin:14px 22px 0;}
.tt-sm{display:inline-flex;align-items:center;gap:7px;padding:10px 22px;border-radius:20px;background:#111;color:#fff;text-decoration:none;font-size:14px;font-weight:700;box-shadow:0 5px 16px rgba(0,0,0,.3);}
.tt-sm:active{transform:scale(.97);}
.footer{width:100%;margin-top:auto;padding:60px 20px 24px;text-align:center;}
.footer small{display:block;font-size:11px;color:#bbb;margin-bottom:6px;font-weight:600;}
.footer img{height:15px;display:block;margin:0 auto 10px;opacity:.75;}
.legal{font-size:10px;color:#bbb;}.legal a{color:inherit;text-decoration:none;margin:0 5px;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);display:none;justify-content:center;align-items:center;z-index:9999;-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);}
.modal-overlay.active{display:flex;animation:fi .2s ease;}
.modal-box{width:84%;max-width:310px;background:#fff;border-radius:22px;padding:30px 22px;text-align:center;}
.modal-box h3{font-size:19px;font-weight:800;color:#111;margin-bottom:10px;}
.modal-box p{font-size:13px;color:#777;margin-bottom:22px;line-height:1.7;}
.modal-ok{width:100%;padding:15px;border-radius:20px;border:none;font-family:'R';font-size:16px;font-weight:800;cursor:pointer;margin-bottom:10px;color:#fff;}
.modal-cancel{font-size:13px;color:#aaa;cursor:pointer;padding:4px;}
.modal-ok.ok-wh{background:linear-gradient(to left,#128c7e,#25d366);}.modal-ok.ok-vi{background:linear-gradient(to left,#5c4fd6,#7360f2);}.modal-ok.ok-te{background:linear-gradient(to left,#229ed9,#2aabee);}.modal-ok.ok-ig{background:linear-gradient(to left,#833ab4,#fd1d1d,#f09433);}.modal-ok.ok-ph{background:linear-gradient(to left,#1d4ed8,#2563eb);}.modal-ok.ok-as{background:linear-gradient(to left,#b91c1c,#dc2626);}
@keyframes fi{from{opacity:0}to{opacity:1}}@keyframes sh{0%{left:-100%}100%{left:160%}}
.shine-active::after{content:'';position:absolute;top:0;left:-100%;width:55%;height:100%;background:linear-gradient(to right,transparent,rgba(255,255,255,.18),transparent);transform:skewX(-20deg);animation:sh 2.4s ease-in-out infinite;pointer-events:none;}
.no-sh::after{animation:none!important;display:none;}
</style></head><body>
<div class="modal-overlay" id="mod"><div class="modal-box"><h3 id="mod-ttl">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="mod-ok" class="modal-ok" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="modal-cancel" onclick="closeMod()">پاشگەزبوونەوە</div></div></div>
<div class="wrap">
  <div class="hdr"></div>
  <div class="av-wrap"><div class="av">{{AVATAR}}</div></div>
  <div class="profile"><div class="uname" dir="auto">{{NAME}}</div><div class="ubio" dir="auto">{{BIO}}</div></div>
  <div class="btns">{{BUTTONS}}</div>
  <div class="tt-wrap">{{TT_BADGE}}</div>
  <div class="footer"><small>سپۆنسەر کراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
</div>
<script>
let _app='',_url='';
function askConfirm(n,u,k){_app=n;_url=u;document.getElementById('mod-ttl').innerText=k;var cls='ok-'+n.substring(0,2);if(n==='telegram')cls='ok-te';document.getElementById('mod-ok').className='modal-ok '+cls;document.getElementById('mod').classList.add('active');if(navigator.vibrate)navigator.vibrate(22);}
function closeMod(){document.getElementById('mod').classList.remove('active');}
function goLink(){const lt=localStorage.getItem('tt_ct');const ct=Date.now();if(window.ttq&&(!lt||ct-lt>86400000)){ttq.track('Contact',{content_id:'contact_button',content_name:_app});localStorage.setItem('tt_ct',ct);}closeMod();setTimeout(()=>{window.location.href=_url;},700);}
!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)));};};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e;};ttq.load=function(e,n){var r='https://analytics.tiktok.com/i18n/pixel/events.js';ttq._i=ttq._i||{};ttq._i[e]=[];ttq._i[e]._u=r;ttq._t=ttq._t||{};ttq._t[e]=+new Date;ttq._o=ttq._o||{};ttq._o[e]=n||{};var s=document.createElement('script');s.type='text/javascript';s.async=!0;s.src=r+'?sdkid='+e+'&lib='+t;var x=document.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};ttq.load('D6BIIA3C77U1CE9DCUMG');ttq.page();}(window,document,'ttq');
document.addEventListener('DOMContentLoaded',function(){
  {{HANDLERS}}
  window.onclick=function(e){if(e.target.id==='mod')closeMod();};
  setTimeout(function(){var s=document.querySelector('.shine-active');if(s)s.classList.add('no-sh');},10000);
});
</script></body></html>
  ''';

  // ─────────────────────────────────────────────────────────────
  // 6. NEON  — نیۆن
  //    • bg: #0d0f1c (very dark)  • header: 110px gradient
  //    • avatar: 90px with NEON glow shadow
  //    • buttons: pill radius:50px + neon box-shadow glow
  //    • TikTok: transparent glass pill
  // ─────────────────────────────────────────────────────────────
  static const String neon = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face{font-family:'R';src:url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2');}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}
body{font-family:'R',sans-serif;background:#060810;min-height:100vh;display:flex;justify-content:center;}
.wrap{width:100%;max-width:430px;min-height:100vh;background:#0d0f1c;display:flex;flex-direction:column;}
.hdr{height:110px;background:{{GRAD}};}
.av-wrap{display:flex;justify-content:center;margin-top:-45px;margin-bottom:14px;}
.av{width:90px;height:90px;border-radius:50%;border:4px solid #0d0f1c;overflow:hidden;background:{{THEME_FROM}};display:flex;align-items:center;justify-content:center;font-size:36px;font-weight:800;color:#fff;box-shadow:0 0 32px {{THEME_TO}}99;}
.av img{width:100%;height:100%;object-fit:cover;display:block;}
.profile{padding:0 22px;text-align:center;margin-bottom:24px;}
.uname{font-size:19px;font-weight:700;color:#fff;margin-bottom:5px;}
.ubio{font-size:14px;color:rgba(255,255,255,.55);line-height:1.9;white-space:pre-line;}
.btns{padding:0 22px;display:flex;flex-direction:column;gap:14px;}
.pl-btn{display:flex;align-items:center;width:100%;padding:15px 14px;border-radius:50px;color:#fff;text-decoration:none;cursor:pointer;transition:transform .13s,opacity .13s;position:relative;overflow:hidden;}
.pl-btn:active{transform:scale(.97);opacity:.92;}
.pl-lbl{flex:1;text-align:center;font-size:17px;font-weight:700;}
.tt-wrap{display:flex;justify-content:center;margin:14px 22px 0;}
.tt-sm{display:inline-flex;align-items:center;gap:7px;padding:10px 22px;border-radius:50px;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.18);color:rgba(255,255,255,.85);text-decoration:none;font-size:14px;font-weight:700;}
.tt-sm:active{transform:scale(.97);}
.footer{width:100%;margin-top:auto;padding:60px 20px 24px;text-align:center;}
.footer small{display:block;font-size:11px;color:rgba(255,255,255,.28);margin-bottom:6px;font-weight:600;}
.footer img{height:14px;display:block;margin:0 auto 10px;opacity:.65;}
.legal{font-size:10px;color:rgba(255,255,255,.28);}.legal a{color:inherit;text-decoration:none;margin:0 5px;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.75);display:none;justify-content:center;align-items:center;z-index:9999;-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);}
.modal-overlay.active{display:flex;animation:fi .2s ease;}
.modal-box{width:84%;max-width:310px;background:#161924;border:1px solid rgba(255,255,255,.1);border-radius:22px;padding:30px 22px;text-align:center;}
.modal-box h3{font-size:19px;font-weight:800;color:#fff;margin-bottom:10px;}
.modal-box p{font-size:13px;color:rgba(255,255,255,.55);margin-bottom:22px;line-height:1.7;}
.modal-ok{width:100%;padding:15px;border-radius:50px;border:none;font-family:'R';font-size:16px;font-weight:800;cursor:pointer;margin-bottom:10px;color:#fff;}
.modal-cancel{font-size:13px;color:#555;cursor:pointer;padding:4px;}
.modal-ok.ok-wh{background:linear-gradient(to left,#128c7e,#25d366);box-shadow:0 0 20px rgba(37,211,102,.4);}.modal-ok.ok-vi{background:linear-gradient(to left,#5c4fd6,#7360f2);box-shadow:0 0 20px rgba(115,96,242,.4);}.modal-ok.ok-te{background:linear-gradient(to left,#229ed9,#2aabee);box-shadow:0 0 20px rgba(42,171,238,.4);}.modal-ok.ok-ig{background:linear-gradient(to left,#833ab4,#fd1d1d,#f09433);}.modal-ok.ok-ph{background:linear-gradient(to left,#1d4ed8,#2563eb);box-shadow:0 0 20px rgba(37,99,235,.4);}.modal-ok.ok-as{background:linear-gradient(to left,#b91c1c,#dc2626);box-shadow:0 0 20px rgba(220,38,38,.4);}
@keyframes fi{from{opacity:0}to{opacity:1}}@keyframes sh{0%{left:-100%}100%{left:160%}}
.shine-active::after{content:'';position:absolute;top:0;left:-100%;width:55%;height:100%;background:linear-gradient(to right,transparent,rgba(255,255,255,.15),transparent);transform:skewX(-20deg);animation:sh 2.4s ease-in-out infinite;pointer-events:none;}
.no-sh::after{animation:none!important;display:none;}
</style></head><body>
<div class="modal-overlay" id="mod"><div class="modal-box"><h3 id="mod-ttl">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="mod-ok" class="modal-ok" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="modal-cancel" onclick="closeMod()">پاشگەزبوونەوە</div></div></div>
<div class="wrap">
  <div class="hdr"></div>
  <div class="av-wrap"><div class="av">{{AVATAR}}</div></div>
  <div class="profile"><div class="uname" dir="auto">{{NAME}}</div><div class="ubio" dir="auto">{{BIO}}</div></div>
  <div class="btns">{{BUTTONS}}</div>
  <div class="tt-wrap">{{TT_BADGE}}</div>
  <div class="footer"><small>سپۆنسەر کراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
</div>
<script>
let _app='',_url='';
function askConfirm(n,u,k){_app=n;_url=u;document.getElementById('mod-ttl').innerText=k;var cls='ok-'+n.substring(0,2);if(n==='telegram')cls='ok-te';document.getElementById('mod-ok').className='modal-ok '+cls;document.getElementById('mod').classList.add('active');if(navigator.vibrate)navigator.vibrate(22);}
function closeMod(){document.getElementById('mod').classList.remove('active');}
function goLink(){const lt=localStorage.getItem('tt_ct');const ct=Date.now();if(window.ttq&&(!lt||ct-lt>86400000)){ttq.track('Contact',{content_id:'contact_button',content_name:_app});localStorage.setItem('tt_ct',ct);}closeMod();setTimeout(()=>{window.location.href=_url;},700);}
!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)));};};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e;};ttq.load=function(e,n){var r='https://analytics.tiktok.com/i18n/pixel/events.js';ttq._i=ttq._i||{};ttq._i[e]=[];ttq._i[e]._u=r;ttq._t=ttq._t||{};ttq._t[e]=+new Date;ttq._o=ttq._o||{};ttq._o[e]=n||{};var s=document.createElement('script');s.type='text/javascript';s.async=!0;s.src=r+'?sdkid='+e+'&lib='+t;var x=document.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};ttq.load('D6BIIA3C77U1CE9DCUMG');ttq.page();}(window,document,'ttq');
document.addEventListener('DOMContentLoaded',function(){
  {{HANDLERS}}
  window.onclick=function(e){if(e.target.id==='mod')closeMod();};
  setTimeout(function(){var s=document.querySelector('.shine-active');if(s)s.classList.add('no-sh');},10000);
});
</script></body></html>
  ''';

  // ─────────────────────────────────────────────────────────────
  // 7. ZOOM  — زووم
  //    • bg: #fff  • header: 110px  • avatar: 90px + COLORED shadow
  //    • name: 20px (bigger)  • buttons: pill radius:50px (same as pill)
  //    • TikTok: black pill (same as pill) — distinct by avatar glow + name size
  // ─────────────────────────────────────────────────────────────
  static const String zoom = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face{font-family:'R';src:url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2');}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}
body{font-family:'R',sans-serif;background:#f0f2f8;min-height:100vh;display:flex;justify-content:center;}
.wrap{width:100%;max-width:430px;min-height:100vh;background:#fff;display:flex;flex-direction:column;}
.hdr{height:110px;background:{{GRAD}};}
.av-wrap{display:flex;justify-content:center;margin-top:-45px;margin-bottom:14px;}
.av{width:90px;height:90px;border-radius:50%;border:4px solid #fff;overflow:hidden;background:{{THEME_FROM}};display:flex;align-items:center;justify-content:center;font-size:36px;font-weight:800;color:#fff;box-shadow:0 6px 22px {{THEME_TO}}66;}
.av img{width:100%;height:100%;object-fit:cover;display:block;}
.profile{padding:0 22px;text-align:center;margin-bottom:26px;}
.uname{font-size:20px;font-weight:700;color:#111;margin-bottom:6px;}
.ubio{font-size:14px;color:#777;line-height:1.9;white-space:pre-line;}
.btns{padding:0 22px;display:flex;flex-direction:column;gap:12px;}
.pl-btn{display:flex;align-items:center;width:100%;padding:15px 14px;border-radius:50px;color:#fff;text-decoration:none;cursor:pointer;transition:transform .13s,opacity .13s;position:relative;overflow:hidden;}
.pl-btn:active{transform:scale(.97);opacity:.92;}
.pl-lbl{flex:1;text-align:center;font-size:17px;font-weight:700;}
.tt-wrap{display:flex;justify-content:center;margin:14px 22px 0;}
.tt-sm{display:inline-flex;align-items:center;gap:7px;padding:10px 22px;border-radius:50px;background:#111;color:#fff;text-decoration:none;font-size:14px;font-weight:700;}
.tt-sm:active{transform:scale(.97);}
.footer{width:100%;margin-top:auto;padding:60px 20px 24px;text-align:center;}
.footer small{display:block;font-size:11px;color:#bbb;margin-bottom:6px;font-weight:600;}
.footer img{height:15px;display:block;margin:0 auto 10px;opacity:.75;}
.legal{font-size:10px;color:#bbb;}.legal a{color:inherit;text-decoration:none;margin:0 5px;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);display:none;justify-content:center;align-items:center;z-index:9999;-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);}
.modal-overlay.active{display:flex;animation:fi .2s ease;}
.modal-box{width:84%;max-width:310px;background:#fff;border-radius:22px;padding:30px 22px;text-align:center;}
.modal-box h3{font-size:19px;font-weight:800;color:#111;margin-bottom:10px;}
.modal-box p{font-size:13px;color:#777;margin-bottom:22px;line-height:1.7;}
.modal-ok{width:100%;padding:15px;border-radius:50px;border:none;font-family:'R';font-size:16px;font-weight:800;cursor:pointer;margin-bottom:10px;color:#fff;}
.modal-cancel{font-size:13px;color:#aaa;cursor:pointer;padding:4px;}
.modal-ok.ok-wh{background:linear-gradient(to left,#128c7e,#25d366);}.modal-ok.ok-vi{background:linear-gradient(to left,#5c4fd6,#7360f2);}.modal-ok.ok-te{background:linear-gradient(to left,#229ed9,#2aabee);}.modal-ok.ok-ig{background:linear-gradient(to left,#833ab4,#fd1d1d,#f09433);}.modal-ok.ok-ph{background:linear-gradient(to left,#1d4ed8,#2563eb);}.modal-ok.ok-as{background:linear-gradient(to left,#b91c1c,#dc2626);}
@keyframes fi{from{opacity:0}to{opacity:1}}@keyframes sh{0%{left:-100%}100%{left:160%}}
.shine-active::after{content:'';position:absolute;top:0;left:-100%;width:55%;height:100%;background:linear-gradient(to right,transparent,rgba(255,255,255,.18),transparent);transform:skewX(-20deg);animation:sh 2.4s ease-in-out infinite;pointer-events:none;}
.no-sh::after{animation:none!important;display:none;}
</style></head><body>
<div class="modal-overlay" id="mod"><div class="modal-box"><h3 id="mod-ttl">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="mod-ok" class="modal-ok" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="modal-cancel" onclick="closeMod()">پاشگەزبوونەوە</div></div></div>
<div class="wrap">
  <div class="hdr"></div>
  <div class="av-wrap"><div class="av">{{AVATAR}}</div></div>
  <div class="profile"><div class="uname" dir="auto">{{NAME}}</div><div class="ubio" dir="auto">{{BIO}}</div></div>
  <div class="btns">{{BUTTONS}}</div>
  <div class="tt-wrap">{{TT_BADGE}}</div>
  <div class="footer"><small>سپۆنسەر کراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
</div>
<script>
let _app='',_url='';
function askConfirm(n,u,k){_app=n;_url=u;document.getElementById('mod-ttl').innerText=k;var cls='ok-'+n.substring(0,2);if(n==='telegram')cls='ok-te';document.getElementById('mod-ok').className='modal-ok '+cls;document.getElementById('mod').classList.add('active');if(navigator.vibrate)navigator.vibrate(22);}
function closeMod(){document.getElementById('mod').classList.remove('active');}
function goLink(){const lt=localStorage.getItem('tt_ct');const ct=Date.now();if(window.ttq&&(!lt||ct-lt>86400000)){ttq.track('Contact',{content_id:'contact_button',content_name:_app});localStorage.setItem('tt_ct',ct);}closeMod();setTimeout(()=>{window.location.href=_url;},700);}
!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)));};};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e;};ttq.load=function(e,n){var r='https://analytics.tiktok.com/i18n/pixel/events.js';ttq._i=ttq._i||{};ttq._i[e]=[];ttq._i[e]._u=r;ttq._t=ttq._t||{};ttq._t[e]=+new Date;ttq._o=ttq._o||{};ttq._o[e]=n||{};var s=document.createElement('script');s.type='text/javascript';s.async=!0;s.src=r+'?sdkid='+e+'&lib='+t;var x=document.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};ttq.load('D6BIIA3C77U1CE9DCUMG');ttq.page();}(window,document,'ttq');
document.addEventListener('DOMContentLoaded',function(){
  {{HANDLERS}}
  window.onclick=function(e){if(e.target.id==='mod')closeMod();};
  setTimeout(function(){var s=document.querySelector('.shine-active');if(s)s.classList.add('no-sh');},10000);
});
</script></body></html>
  ''';

  // ─────────────────────────────────────────────────────────────
  // 8. BANNER  — بانەر
  //    • bg: #fff  • header: HORIZONTAL (avatar + name + bio side-by-side)
  //    • TikTok: INLINE inside header  • buttons: pill radius:50px below header
  // ─────────────────────────────────────────────────────────────
  static const String banner = r'''
<!DOCTYPE html><html dir="rtl" lang="ku"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Proxo</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
<style>
@font-face{font-family:'R';src:url('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2') format('woff2');}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}
body{font-family:'R',sans-serif;background:#eef0f5;min-height:100vh;display:flex;justify-content:center;}
.wrap{width:100%;max-width:430px;min-height:100vh;background:#fff;display:flex;flex-direction:column;}
.hdr{background:{{GRAD}};padding:26px 22px;display:flex;align-items:center;gap:16px;}
.hdr-av{width:82px;height:82px;min-width:82px;border-radius:50%;border:3px solid rgba(255,255,255,.35);overflow:hidden;background:rgba(255,255,255,.15);display:flex;align-items:center;justify-content:center;font-size:32px;font-weight:800;color:#fff;}
.hdr-av img{width:100%;height:100%;object-fit:cover;display:block;}
.hdr-info{flex:1;}
.hdr-name{font-size:20px;font-weight:800;color:#fff;}
.hdr-bio{font-size:13px;color:rgba(255,255,255,.85);margin-top:5px;line-height:1.75;white-space:pre-line;}
.btns{padding:24px 22px 0;display:flex;flex-direction:column;gap:12px;}
.pl-btn{display:flex;align-items:center;width:100%;padding:15px 14px;border-radius:50px;color:#fff;text-decoration:none;cursor:pointer;transition:transform .13s,opacity .13s;position:relative;overflow:hidden;}
.pl-btn:active{transform:scale(.97);opacity:.92;}
.pl-lbl{flex:1;text-align:center;font-size:17px;font-weight:700;}
.footer{width:100%;margin-top:auto;padding:60px 20px 24px;text-align:center;}
.footer small{display:block;font-size:11px;color:#bbb;margin-bottom:6px;font-weight:600;}
.footer img{height:15px;display:block;margin:0 auto 10px;opacity:.75;}
.legal{font-size:10px;color:#bbb;}.legal a{color:inherit;text-decoration:none;margin:0 5px;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);display:none;justify-content:center;align-items:center;z-index:9999;-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);}
.modal-overlay.active{display:flex;animation:fi .2s ease;}
.modal-box{width:84%;max-width:310px;background:#fff;border-radius:22px;padding:30px 22px;text-align:center;}
.modal-box h3{font-size:19px;font-weight:800;color:#111;margin-bottom:10px;}
.modal-box p{font-size:13px;color:#777;margin-bottom:22px;line-height:1.7;}
.modal-ok{width:100%;padding:15px;border-radius:50px;border:none;font-family:'R';font-size:16px;font-weight:800;cursor:pointer;margin-bottom:10px;color:#fff;}
.modal-cancel{font-size:13px;color:#aaa;cursor:pointer;padding:4px;}
.modal-ok.ok-wh{background:linear-gradient(to left,#128c7e,#25d366);}.modal-ok.ok-vi{background:linear-gradient(to left,#5c4fd6,#7360f2);}.modal-ok.ok-te{background:linear-gradient(to left,#229ed9,#2aabee);}.modal-ok.ok-ig{background:linear-gradient(to left,#833ab4,#fd1d1d,#f09433);}.modal-ok.ok-ph{background:linear-gradient(to left,#1d4ed8,#2563eb);}.modal-ok.ok-as{background:linear-gradient(to left,#b91c1c,#dc2626);}
@keyframes fi{from{opacity:0}to{opacity:1}}@keyframes sh{0%{left:-100%}100%{left:160%}}
.shine-active::after{content:'';position:absolute;top:0;left:-100%;width:55%;height:100%;background:linear-gradient(to right,transparent,rgba(255,255,255,.18),transparent);transform:skewX(-20deg);animation:sh 2.4s ease-in-out infinite;pointer-events:none;}
.no-sh::after{animation:none!important;display:none;}
</style></head><body>
<div class="modal-overlay" id="mod"><div class="modal-box"><h3 id="mod-ttl">...</h3><p>ئایا دەتەوێت پەیوەندیمان پێوە بکەی؟</p><button id="mod-ok" class="modal-ok" onclick="goLink()">بەڵێ، بەردەوام بە</button><div class="modal-cancel" onclick="closeMod()">پاشگەزبوونەوە</div></div></div>
<div class="wrap">
  <div class="hdr">
    <div class="hdr-av">{{AVATAR}}</div>
    <div class="hdr-info">
      <div class="hdr-name" dir="auto">{{NAME}}</div>
      <div class="hdr-bio" dir="auto">{{BIO}}</div>
      {{TT_INLINE}}
    </div>
  </div>
  <div class="btns">{{BUTTONS}}</div>
  <div class="footer"><small>سپۆنسەر کراوە لەئەپی</small><a href="https://www.tiktok.com/@proxo_iq" target="_blank"><img src="https://image2url.com/r2/default/images/1772757087694-7bee9862-8ba7-44c2-9056-a4543f25aa32.webp" alt="Proxo"></a><div class="legal"><a href="https://proxopages.com/policy" target="_blank">Privacy Policy</a> | <a href="https://proxopages.com/terms" target="_blank">Terms &amp; Conditions</a></div></div>
</div>
<script>
let _app='',_url='';
function askConfirm(n,u,k){_app=n;_url=u;document.getElementById('mod-ttl').innerText=k;var cls='ok-'+n.substring(0,2);if(n==='telegram')cls='ok-te';document.getElementById('mod-ok').className='modal-ok '+cls;document.getElementById('mod').classList.add('active');if(navigator.vibrate)navigator.vibrate(22);}
function closeMod(){document.getElementById('mod').classList.remove('active');}
function goLink(){const lt=localStorage.getItem('tt_ct');const ct=Date.now();if(window.ttq&&(!lt||ct-lt>86400000)){ttq.track('Contact',{content_id:'contact_button',content_name:_app});localStorage.setItem('tt_ct',ct);}closeMod();setTimeout(()=>{window.location.href=_url;},700);}
!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)));};};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e;};ttq.load=function(e,n){var r='https://analytics.tiktok.com/i18n/pixel/events.js';ttq._i=ttq._i||{};ttq._i[e]=[];ttq._i[e]._u=r;ttq._t=ttq._t||{};ttq._t[e]=+new Date;ttq._o=ttq._o||{};ttq._o[e]=n||{};var s=document.createElement('script');s.type='text/javascript';s.async=!0;s.src=r+'?sdkid='+e+'&lib='+t;var x=document.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};ttq.load('D6BIIA3C77U1CE9DCUMG');ttq.page();}(window,document,'ttq');
document.addEventListener('DOMContentLoaded',function(){
  {{HANDLERS}}
  window.onclick=function(e){if(e.target.id==='mod')closeMod();};
  setTimeout(function(){var s=document.querySelector('.shine-active');if(s)s.classList.add('no-sh');},10000);
});
</script></body></html>
  ''';

  static const List<String> all = [dark, light, classic, pill, card, neon, zoom, banner];

  static String forStyle(String name) {
    switch (name) {
      case 'dark':    return dark;
      case 'light':   return light;
      case 'classic': return classic;
      case 'pill':    return pill;
      case 'card':    return card;
      case 'neon':    return neon;
      case 'zoom':    return zoom;
      case 'banner':  return banner;
      default:        return dark;
    }
  }
}
