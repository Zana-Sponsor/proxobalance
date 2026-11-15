/* Fee by amount — «لێبڕین بەپێی بڕ».
   One card on the rates page sets the same amount steps on many routes at
   once, and the same rows sit inside the route editor (#moRate).
   Stored in ex_rates.fee_brackets as [{up_to, percent}, …, {up_to:null, percent}]:
   the whole amount takes the percent of the first step it fits in
   (100,000 with "up to 100,000 → 1%" pays 1%). Orders (api-handlers/orders.js),
   the database (ex_effective_rate_value_b + the ex_rates check) and the
   customer quote already read this column. Nothing here touches rate_value. */
(function () {
  'use strict';
  const MAX_ROWS = 10;
  const blank = () => [{ upTo: '', percent: '' }, { upTo: '', percent: '' }];
  const ctxs = {
    card: { rows: blank() },
    modal: { rows: blank(), on: false, allowed: false, initial: null }
  };
  const picked = new Set();
  let busy = false;

  const e = (v) => (typeof esc === 'function' ? esc(v) : String(v == null ? '' : v));
  const nf = (n) => Number(n).toLocaleString('en-US');
  const pct = (n) => String(Math.round(Number(n) * 10000) / 10000);
  const toLatin = (s) => String(s == null ? '' : s)
    .replace(/[٠-٩]/g, (d) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d)))
    .replace(/[۰-۹]/g, (d) => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d)));
  const amountRaw = (v) => toLatin(v).replace(/[^0-9]/g, '').replace(/^0+(?=\d)/, '');
  const pctRaw = (v) => toLatin(v).replace(/[٫,]/g, '.').replace(/[^0-9.]/g, '').replace(/(\..*)\./g, '$1');
  const label = (k) => (typeof walletLabelFor === 'function' ? walletLabelFor(k) : k) || '—';
  const $ = (id) => document.getElementById(id);

  function rowsClean(ctx) {
    return ctxs[ctx].rows.map((r) => ({ upTo: amountRaw(r.upTo), percent: pctRaw(r.percent) }));
  }
  // [{up_to, percent}] or throws the Kurdish reason (without a prefix)
  function brackets(ctx) {
    try { return pairBracketsFromRows(rowsClean(ctx), ''); }
    catch (err) { throw new Error(String(err && err.message || '').replace(/^\s*:\s*/, '')); }
  }
  function bracketsOrNull(ctx) { try { return brackets(ctx); } catch (_) { return null; } }
  // numbers are isolated so "1%" stays "1%" inside Kurdish text (also in title attributes and the confirm text)
  const iso = (s) => '\u2066' + s + '\u2069';
  function stepsText(b) {
    return b.map((x, i) => (i < b.length - 1
      ? 'تا ' + iso(nf(x.up_to)) + ': ' + iso(pct(x.percent) + '%')
      : 'زیاتر: ' + iso(pct(x.percent) + '%'))).join(' · ');
  }
  window.feeStepsText = stepsText;

  // a route can take steps only with a % fee or a multiplier up to 1, never from USDT / the balance, never to USDT
  function eligible(r) {
    return !!r && !!r.to_method && r.to_method !== 'AccountBalance' && typeof pairTierAllowed === 'function'
      && pairTierAllowed(r.from_method, r.to_method, { type: r.rate_type, value: String(r.rate_value) });
  }
  function walletRank(key) {
    const list = typeof allWallets !== 'undefined' && Array.isArray(allWallets) ? allWallets : [];
    const i = list.findIndex((w) => w.key === key);
    return i < 0 ? 1000 : i;
  }
  // routes grouped by the wallet they leave from, in the wallets' order
  window.groupRatesByWallet = function (rows) {
    const map = new Map();
    rows.forEach((r) => { if (!map.has(r.from_method)) map.set(r.from_method, []); map.get(r.from_method).push(r); });
    const byWallet = (a, b) => walletRank(a) - walletRank(b) || label(a).localeCompare(label(b));
    return [...map.entries()]
      .sort((a, b) => byWallet(a[0], b[0]))
      .map(([from, list]) => [from, list.sort((a, b) => byWallet(a.to_method, b.to_method))]);
  };
  // "2%", "15%" for a ×0.85 multiplier, "×1,450", "500 د.ع"
  function feeLabel(r) {
    const v = Number(r.rate_value);
    if (r.rate_type === 'fee_percent') return pct(v) + '%';
    if (r.rate_type === 'fee_fixed') return nf(v) + ' د.ع';
    return v < 1 ? pct(100 - v * 100) + '%' : '×' + nf(v);
  }
  window.rateFeeLabel = feeLabel;
  function currentFee(r) {
    const b = typeof pairBracketsOfRow === 'function' ? pairBracketsOfRow(r) : null;
    return b ? b.map((x) => pct(x.percent) + '%').join(' / ') : feeLabel(r);
  }

  // ── the rows: «تا [بڕ] د.ع  [ ] %» … «زیاتر لە … د.ع  [ ] %» ─────────
  function aboveText(ctx) {
    const rows = ctxs[ctx].rows, prev = rows.length > 1 ? amountRaw(rows[rows.length - 2].upTo) : '';
    return prev ? 'زیاتر لە ' + nf(prev) + ' د.ع' : 'زیاتر لەوە';
  }
  function examplesHTML(ctx) {
    const b = bracketsOrNull(ctx);
    if (!b) return '';
    const at = b.map((x, i) => (i < b.length - 1 ? x.up_to : b[b.length - 2].up_to * 2));
    return '<small>نموونە</small>' + at.map((amount, i) =>
      '<span><bdi>' + nf(amount) + ' د.ع</bdi>: لێبڕین <bdi>' + nf(Math.round(amount * b[i].percent / 100)) + ' د.ع</bdi></span>').join('');
  }
  function rowsHTML(ctx) {
    const rows = ctxs[ctx].rows, n = rows.length;
    const body = rows.map((r, i) => {
      const last = i === n - 1;
      const lead = last
        ? '<span class="ft-k ft-k-above" id="ftAbove-' + ctx + '">' + e(aboveText(ctx)) + '</span>'
        : '<span class="ft-k">تا</span><label class="ft-in ft-amt"><input type="text" inputmode="numeric" dir="ltr" autocomplete="off" aria-label="تا بڕی (دینار)" value="' + e(r.upTo ? nf(r.upTo) : '') + '" data-ft="' + ctx + '" data-i="' + i + '" data-f="upTo"><span>د.ع</span></label>';
      const percent = '<label class="ft-in ft-pct"><input type="text" inputmode="decimal" dir="ltr" autocomplete="off" aria-label="ڕێژەی لێبڕین" value="' + e(r.percent) + '" data-ft="' + ctx + '" data-i="' + i + '" data-f="percent"><span>%</span></label>';
      const del = n > 2
        ? '<button type="button" class="ft-del" aria-label="لابردنی ئەم بڕە" title="لابردن" data-ft-del="' + ctx + '" data-i="' + i + '"><i class="fas fa-xmark"></i></button>'
        : '<span class="ft-del-ph" aria-hidden="true"></span>';
      return '<div class="ft-row' + (last ? ' last' : '') + '">' + lead + percent + del + '</div>';
    }).join('');
    return '<div class="ft-rows">' + body + '</div>'
      + '<div class="ft-under"><button type="button" class="act-btn dark ft-add" data-ft-add="' + ctx + '"' + (n >= MAX_ROWS ? ' disabled' : '') + '><i class="fas fa-plus"></i> زیادکردنی بڕێک</button>'
      + '<div class="ft-ex" id="ftEx-' + ctx + '">' + examplesHTML(ctx) + '</div></div>'
      + '<div class="ft-err" id="ftErr-' + ctx + '" role="alert"></div>';
  }
  function drawRows(ctx) {
    const wrap = $('ftRows-' + ctx);
    if (wrap) wrap.innerHTML = rowsHTML(ctx);
  }
  // after typing: the "above" label, the examples, the error line — inputs stay as they are
  function touch(ctx) {
    const above = $('ftAbove-' + ctx); if (above) above.textContent = aboveText(ctx);
    const ex = $('ftEx-' + ctx); if (ex) ex.innerHTML = examplesHTML(ctx);
    const err = $('ftErr-' + ctx); if (err) err.textContent = '';
    if (ctx === 'modal' && typeof updateAdminRatePreview === 'function') updateAdminRatePreview();
  }

  // keeps the caret after the same digit while commas come and go
  function setFormatted(input, text) {
    if (input.value === text) return;
    const before = amountRaw(input.value.slice(0, input.selectionStart || 0)).length;
    input.value = text;
    let p = 0, seen = 0;
    while (p < text.length && seen < before) { if (/\d/.test(text[p])) seen++; p++; }
    try { input.setSelectionRange(p, p); } catch (_) {}
  }
  document.addEventListener('input', (ev) => {
    const t = ev.target;
    if (!t || !t.dataset || !t.dataset.ft) return;
    const c = ctxs[t.dataset.ft], row = c && c.rows[Number(t.dataset.i)];
    if (!row) return;
    if (t.dataset.f === 'upTo') {
      row.upTo = amountRaw(t.value);
      setFormatted(t, row.upTo ? nf(row.upTo) : '');
    } else {
      row.percent = pctRaw(t.value);
      if (t.value !== row.percent) t.value = row.percent;
    }
    touch(t.dataset.ft);
  });
  document.addEventListener('click', (ev) => {
    const add = ev.target.closest('[data-ft-add]');
    if (add) {
      const ctx = add.dataset.ftAdd, rows = ctxs[ctx].rows;
      if (rows.length >= MAX_ROWS) return;
      rows.splice(rows.length - 1, 0, { upTo: '', percent: '' });      // a new step goes before "above"
      drawRows(ctx); touch(ctx);
      const inputs = document.querySelectorAll('#ftRows-' + ctx + ' input[data-f="upTo"]');
      if (inputs.length) inputs[inputs.length - 1].focus();
      return;
    }
    const del = ev.target.closest('[data-ft-del]');
    if (del) {
      const ctx = del.dataset.ftDel, rows = ctxs[ctx].rows;
      if (rows.length <= 2) return;
      rows.splice(Number(del.dataset.i), 1);
      drawRows(ctx); touch(ctx);
    }
  });

  // ── the card on the rates page ─────────────────────────────────────
  function cardRoutes() { return (typeof allRates !== 'undefined' && Array.isArray(allRates) ? allRates : []).filter(eligible); }
  function chipHTML(r) {
    const steps = typeof pairBracketsOfRow === 'function' && pairBracketsOfRow(r);
    return '<label class="ft-chip' + (r.is_active ? '' : ' off') + (steps ? ' has' : '') + '"' + (steps ? ' title="' + e(stepsText(steps)) + '"' : '') + '>'
      + '<input type="checkbox" data-ft-route="' + e(r.id) + '"' + (picked.has(String(r.id)) ? ' checked' : '') + '>'
      + '<span>' + e(label(r.to_method)) + '</span><small dir="ltr">' + e(currentFee(r)) + '</small></label>';
  }
  window.renderFeeTierCard = function () {
    const box = $('ftGroups');
    if (!box) return;
    const rowsBox = $('ftRows-card');
    if (rowsBox && !rowsBox.innerHTML) drawRows('card');
    const routes = cardRoutes();
    const ids = new Set(routes.map((r) => String(r.id)));
    [...picked].forEach((id) => { if (!ids.has(id)) picked.delete(id); });
    if (!routes.length) { box.innerHTML = '<div class="ft-none">هیچ ڕێگایەکی گونجاو نییە</div>'; syncPicks(); return; }
    box.innerHTML = groupRatesByWallet(routes).map(([from, list]) =>
      '<div class="ft-grp" data-ft-from="' + e(from) + '">'
      + '<label class="ft-grp-h"><input type="checkbox" data-ft-grp="' + e(from) + '"><b>' + e(label(from)) + '</b><small data-ft-grp-count></small></label>'
      + '<div class="ft-chips">' + list.map(chipHTML).join('') + '</div></div>').join('');
    syncPicks();
  };
  function syncPicks() {
    const routes = cardRoutes();
    document.querySelectorAll('#ftGroups .ft-grp').forEach((g) => {
      const boxes = [...g.querySelectorAll('[data-ft-route]')];
      const on = boxes.filter((b) => b.checked).length;
      const head = g.querySelector('[data-ft-grp]');
      head.checked = on > 0 && on === boxes.length;
      head.indeterminate = on > 0 && on < boxes.length;
      g.querySelector('[data-ft-grp-count]').textContent = on ? on + '/' + boxes.length : String(boxes.length);
    });
    const all = $('ftAll');
    if (all) { all.checked = routes.length > 0 && picked.size === routes.length; all.indeterminate = picked.size > 0 && picked.size < routes.length; }
    const save = $('ftSave');
    if (save) { save.disabled = busy || picked.size === 0; save.textContent = picked.size ? 'پاشەکەوتکردن بۆ ' + picked.size + ' ڕێگا' : 'پاشەکەوتکردن'; }
    const withSteps = routes.filter((r) => picked.has(String(r.id)) && pairBracketsOfRow(r)).length;
    const clear = $('ftClear');
    if (clear) { clear.hidden = withSteps === 0; clear.disabled = busy; clear.textContent = 'لابردنی لێبڕینی بەپێی بڕ (' + withSteps + ')'; }
  }
  document.addEventListener('change', (ev) => {
    const t = ev.target;
    if (!t) return;
    if (t.matches('[data-ft-route]')) {
      t.checked ? picked.add(t.dataset.ftRoute) : picked.delete(t.dataset.ftRoute);
    } else if (t.matches('[data-ft-grp]')) {
      const g = t.closest('.ft-grp');
      g.querySelectorAll('[data-ft-route]').forEach((b) => { b.checked = t.checked; t.checked ? picked.add(b.dataset.ftRoute) : picked.delete(b.dataset.ftRoute); });
    } else if (t.id === 'ftAll') {
      cardRoutes().forEach((r) => (t.checked ? picked.add(String(r.id)) : picked.delete(String(r.id))));
      document.querySelectorAll('#ftGroups [data-ft-route]').forEach((b) => { b.checked = t.checked; });
    } else if (t.id === 'rateTierOn') {
      ctxs.modal.on = t.checked;
      drawModal();
      if (typeof updateAdminRatePreview === 'function') updateAdminRatePreview();
      return;
    } else return;
    const err = $('ftErr-card'); if (err) err.textContent = '';
    syncPicks();
  });

  async function write(ids, patch, done) {
    busy = true; syncPicks();
    try {
      const { data, error } = await sb.from('ex_rates').update(patch).in('id', ids).select('*');
      if (error) { await handleDbWriteError(error); return; }
      const rows = Array.isArray(data) ? data : data ? [data] : [];
      rows.forEach((r) => { const i = allRates.findIndex((x) => String(x.id) === String(r.id)); if (i >= 0) allRates[i] = r; });
      if (rows.length !== ids.length) {
        showToast('هەموو ڕێگاکان پاشەکەوت نەکران؛ لیستەکە نوێ کرایەوە', 'rd');
        await loadRates();
        return;
      }
      picked.clear();
      if (typeof filterAdminRates === 'function') filterAdminRates(); else renderRates();
      showToast(done, 'gr');
    } catch (err) {
      showToast(typeof adminDbMessage === 'function' ? adminDbMessage(err) : String(err && err.message), 'rd');
    } finally { busy = false; syncPicks(); }
  }
  window.saveFeeTiers = function () {
    const err = $('ftErr-card');
    let b;
    try { b = brackets('card'); } catch (x) { if (err) err.textContent = x.message; return; }
    const ids = cardRoutes().filter((r) => picked.has(String(r.id))).map((r) => r.id);
    if (!ids.length) { if (err) err.textContent = 'لانیکەم یەک ڕێگا هەڵبژێرە'; return; }
    confirm2('لێبڕین بەپێی بڕ', ids.length + ' ڕێگا: ' + stepsText(b), 'fas fa-percent', 'var(--bl)',
      () => write(ids, { fee_brackets: b, fee_tier_enabled: false }, 'لێبڕین بۆ ' + ids.length + ' ڕێگا پاشەکەوتکرا'));
  };
  window.clearFeeTiers = function () {
    const ids = cardRoutes().filter((r) => picked.has(String(r.id)) && pairBracketsOfRow(r)).map((r) => r.id);
    if (!ids.length) return;
    confirm2('لابردنی لێبڕینی بەپێی بڕ', ids.length + ' ڕێگا دەگەڕێنەوە سەر نرخی ئاسایی خۆیان', 'fas fa-rotate-left', 'var(--rd)',
      () => write(ids, { fee_brackets: null, fee_tier_enabled: false }, 'لێبڕینی بەپێی بڕ لە ' + ids.length + ' ڕێگا لابرا'));
  };

  // ── inside the route editor (#moRate) ──────────────────────────────
  const val = (id) => ($(id) ? $(id).value : '');
  function modalAllowed() {
    return typeof pairTierAllowed === 'function' && !!val('rateTo')
      && pairTierAllowed(val('rateFrom'), val('rateTo'), { type: val('rateType'), value: val('rateValue') });
  }
  function drawModal() {
    const wrap = $('rateTierWrap'), c = ctxs.modal;
    if (!wrap) return;
    c.allowed = modalAllowed();
    if (!c.allowed) { wrap.hidden = true; wrap.innerHTML = ''; return; }
    wrap.hidden = false;
    wrap.innerHTML = '<div class="mswitch-row ft-switch"><span>لێبڕین بەپێی بڕ</span><label class="mswitch"><input type="checkbox" id="rateTierOn"' + (c.on ? ' checked' : '') + '><span class="track"></span></label></div>'
      + (c.on ? '<div class="ft-box" id="ftRows-modal">' + rowsHTML('modal') + '</div>' : '');
  }
  window.ftModalOpen = function (rate) {
    const c = ctxs.modal, b = rate && typeof pairBracketsOfRow === 'function' ? pairBracketsOfRow(rate) : null;
    c.initial = b ? JSON.stringify(b) : null;
    c.on = !!b;
    c.rows = b ? b.map((x, i) => ({ upTo: i < b.length - 1 ? String(x.up_to) : '', percent: pct(x.percent) })) : blank();
    drawModal();
  };
  // route, type or value changed: show or hide the section only when that flips
  window.ftModalRefresh = function () { if (modalAllowed() !== ctxs.modal.allowed) drawModal(); };
  // the steps in force for the preview, or null
  window.ftModalBrackets = function () {
    const c = ctxs.modal;
    return c.allowed && c.on ? bracketsOrNull('modal') : null;
  };
  // columns for saveRate: {} keeps what is stored; throws the reason when the rows are not right
  window.ftModalPatch = function (prevRate) {
    const c = ctxs.modal, had = !!(prevRate && (prevRate.fee_brackets || prevRate.fee_tier_enabled));
    if (!modalAllowed() || !c.on) return had ? { fee_brackets: null, fee_tier_enabled: false } : {};
    let b;
    try { b = brackets('modal'); }
    catch (x) { const err = $('ftErr-modal'); if (err) err.textContent = x.message; throw new Error('لێبڕین بەپێی بڕ: ' + x.message); }
    if (c.initial && JSON.stringify(b) === c.initial) return {};
    return { fee_brackets: b, fee_tier_enabled: false };
  };
})();
