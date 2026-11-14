/* ═════════════════════════════════════════════════════════════════
   Skeleton loading — one place for every "waiting for data" state.
   Each skeleton reuses the real card's classes (tx-item, tf-row, rate-card,
   chg-item, bh-item, notif-item, sc-case …) and only swaps the text for
   shimmering bars, so the card, its padding and its height are the same as
   the loaded card. Styling: assets/css/skeletons.css.
   ═════════════════════════════════════════════════════════════════ */
(function(){
  'use strict';
  // one bar; w = px number or any CSS width, h = px.
  // The wrapper carries a zero-width space, so it always takes the height of the
  // real text line it replaces — also inside flex rows, where a bare bar would shrink.
  function bar(w, h, round){
    const width = typeof w === 'number' ? w + 'px' : (w || '60px');
    return '<span class="skb-w" style="width:' + width + '" aria-hidden="true"><span class="skb' + (round ? ' skb-c' : '') + '" style="height:' + (h || 11) + 'px"></span>&#8203;</span>';
  }
  const pick = (arr, i) => arr[i % arr.length];
  const repeat = (n, fn) => Array.from({ length: n }, (_, i) => fn(i)).join('');

  // ── transaction card (home preview + /transactions) ──
  function txItems(n){
    return repeat(n || 4, i =>
      '<article class="tx-item is-skel" aria-hidden="true">'
      + '<span class="tx-item-ico"></span>'
      + '<span class="tx-item-main">'
        + '<span class="tx-item-route">' + bar(pick([96, 84, 104], i), 12) + '</span>'
        + '<span class="tx-item-when">' + bar(pick([112, 100, 118], i), 10) + '</span>'
      + '</span>'
      + '<span class="tx-item-end">'
        + '<strong class="tx-item-amount">' + bar(pick([66, 58, 72], i), 12) + '</strong>'
        + '<span class="tx-item-status">' + bar(pick([46, 54, 40], i), 10) + '</span>'
      + '</span>'
      + '</article>');
  }

  // ── dashboard: latest exchanges (one card, rows) ──
  function dbRows(n){
    return '<div class="dbr-list" aria-hidden="true">' + repeat(n || 4, i =>
      '<div class="dbr is-skel">'
      + '<span class="dbr-pair"><span class="method-icon is-skel-ico"></span><span class="method-icon is-skel-ico"></span></span>'
      + '<span class="dbr-main"><span class="dbr-title">' + bar(pick([92, 80, 100], i), 12) + '</span><span class="dbr-sub">' + bar(pick([70, 86, 62], i), 10) + '</span></span>'
      + '<span class="dbr-end"><b class="dbr-amt">' + bar(pick([70, 62, 76], i), 12) + '</b><span class="dbr-st">' + bar(pick([48, 40, 56], i), 10) + '</span></span>'
      + '</div>') + '</div>';
  }

  // ── transaction summary screen ──
  function summary(){
    const row = (k, v, cls) => '<div class="tf-row' + (cls ? ' ' + cls : '') + '"><span class="tf-k">' + bar(k, 11) + '</span><span class="tf-v">' + bar(v, 12) + '</span></div>';
    return '<div class="tf-flow is-skel" aria-hidden="true">'
      + '<section class="tf-hero">'
        + '<span class="tf-hero-ico"></span>'
        + '<small class="tf-hero-label">' + bar(104, 11) + '</small>'
        + '<strong class="tf-hero-amount">' + bar(136, 24) + '</strong>'
        + bar(78, 26, true)
      + '</section>'
      + '<section class="tf-sec"><h3 class="tf-sec-title">' + bar(88, 13) + '</h3><div class="tf-rows">'
        + row(56, 70) + row(88, 52) + row(66, 40) + row(104, 64, 'is-total')
      + '</div></section>'
      + '<section class="tf-sec"><h3 class="tf-sec-title">' + bar(96, 13) + '</h3><div class="tf-rows">'
        + row(92, 64) + row(120, 40)
      + '</div></section>'
      + '<section class="tf-sec"><h3 class="tf-sec-title">' + bar(84, 13) + '</h3><div class="tf-rows">'
        + row(64, 104) + row(80, 92) + row(60, 86) + row(56, 86) + row(62, 128) + row(58, 128)
      + '</div></section>'
      + '</div>';
  }

  // ── /changes: current rates + change log ──
  function rateCards(n){
    return repeat(n || 3, i =>
      '<div class="rate-card is-skel" aria-hidden="true">'
      + '<div class="rate-route">'
        + '<span class="rate-w">' + bar(18, 18, true) + bar(pick([52, 44, 58], i), 10) + '</span>'
        + '<span class="rate-arrow">' + bar(16, 8) + '</span>'
        + '<span class="rate-w">' + bar(18, 18, true) + bar(pick([36, 48, 40], i), 10) + '</span>'
      + '</div>'
      + '<div class="rate-eq">'
        + '<span class="rate-in">' + bar(70, 11) + '</span>'
        + '<span class="rate-eqico">' + bar(12, 8) + '</span>'
        + '<span class="rate-out">' + bar(78, 13) + '</span>'
      + '</div>'
      + '<div class="rate-fee">' + bar(56, 9) + '</div>'
      + '</div>');
  }
  function changeItems(n){
    return repeat(n || 3, i =>
      '<div class="chg-item is-skel" aria-hidden="true">'
      + '<span class="chg-ico"></span>'
      + '<div class="chg-body">'
        + '<div class="chg-head"><span class="chg-headline">' + bar(pick([150, 128, 164], i), 11) + '</span><span class="chg-time">' + bar(44, 9) + '</span></div>'
        + '<span class="chg-route">' + bar(pick([112, 96, 120], i), 10) + '</span>'
        + '<div class="chg-vals">' + bar(30, 11) + bar(14, 8) + bar(30, 11) + '</div>'
      + '</div>'
      + '</div>');
  }

  // ── /balance history ──
  function balHist(n){
    return repeat(n || 3, i =>
      '<article class="bh-item is-skel" aria-hidden="true">'
      + '<span class="bh-ico"></span>'
      + '<div class="bh-main"><b>' + bar(pick([112, 128, 104], i), 12) + '</b><small>' + bar(pick([150, 120, 140], i), 10) + '</small><time>' + bar(104, 10) + '</time></div>'
      + '<strong class="bh-amt">' + bar(pick([84, 72, 90], i), 13) + '</strong>'
      + '</article>');
  }

  // ── notifications panel ──
  function notifItems(n){
    return repeat(n || 4, i =>
      '<div class="notif-item is-skel" aria-hidden="true">'
      + '<span class="notif-item-ico"></span>'
      + '<span class="notif-item-text">'
        + '<span class="notif-item-title">' + bar(pick([150, 176, 132], i), 12) + '</span>'
        + '<span class="notif-item-msg">' + bar(pick(['92%', '78%', '86%'], i), 10) + '</span>'
        + '<span class="notif-item-time">' + bar(60, 9) + '</span>'
      + '</span>'
      + '</div>');
  }

  // ── support: my cases ──
  function supportCases(n){
    return repeat(n || 2, i =>
      '<article class="sc-case is-skel" aria-hidden="true">'
      + '<div class="sc-case-head">'
        + '<span class="sc-tile sc-case-ico"></span>'
        + '<div class="sc-case-id"><b>' + bar(112, 12) + '</b><small>' + bar(pick([156, 136], i), 10) + '</small></div>'
        + bar(70, 26, true)
      + '</div>'
      + '<p class="sc-case-desc">' + bar(pick(['86%', '64%'], i), 11) + '</p>'
      + '</article>');
  }

  // ── verify page banner ──
  function kycBanner(){
    return '<span class="kyc-ico is-skel-tile" aria-hidden="true"></span>'
      + '<div aria-hidden="true"><b>' + bar(168, 12) + '</b><p>' + bar('92%', 10) + '<br>' + bar('64%', 10) + '</p></div>';
  }

  window.PXS = { bar, txItems, dbRows, summary, rateCards, changeItems, balHist, notifItems, supportCases, kycBanner };
})();
