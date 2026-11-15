// Admin: image banners for the customer app (table ex_banners, bucket "banners").
//   slide  dashboard, a fixed 12:5 place, several slide by themselves
//   popup  over the screen on the sections chosen here, once per account
// Pictures are cut to the exact size and made WebP in the browser (~60–150 KB),
// then sent straight to storage with a one-time address from /api/admin.
(function(){
  'use strict';
  const SIZE = { slide: [1200, 500], popup: [720, 900] };
  const SECTIONS = [
    ['home', 'سەرەکی'], ['exchange', 'ئاڵوگۆڕ'], ['transactions', 'مامەڵەکان'], ['profile', 'پڕۆفایل'],
    ['balance', 'مێژووی باڵانس'], ['support', 'پشتگیری'], ['verify', 'پشتڕاستکردنەوەی ناسنامە'],
    ['changes', 'گۆڕانکاری نرخ'], ['rules', 'یاساکان']
  ];
  const NAME = Object.fromEntries(SECTIONS);
  const MAX_BYTES = 250 * 1024;
  let list = [], busy = false;
  let draft = null;           // { id, kind, image_path, blob, preview, action_type, action_section, action_url, places, is_active }

  const e = (v) => (typeof esc === 'function' ? esc(v) : String(v == null ? '' : v));
  const toast = (m, k) => { if (typeof showToast === 'function') showToast(m, k); };
  const $ = (id) => document.getElementById(id);
  const imgUrl = (path) => SB_URL + '/storage/v1/object/public/banners/' + path;
  const kb = (n) => Math.max(1, Math.round(n / 1024)).toLocaleString('en-US') + ' KB';

  function actionText(b){
    if (b.action_type === 'section') return 'کلیک ← ' + (NAME[b.action_section] || b.action_section);
    if (b.action_type === 'url') { let host = b.action_url; try { host = new URL(b.action_url).host; } catch (_) {} return 'کلیک ← ' + host; }
    return 'بێ کلیک';
  }
  function itemHTML(b, i, arr){
    const placeText = b.kind === 'popup' ? (b.places || []).map(p => NAME[p] || p).join('، ') : '';
    return '<div class="bn-item' + (b.is_active ? '' : ' off') + '">'
      + '<img class="bn-thumb ' + b.kind + '" src="' + e(imgUrl(b.image_path)) + '" alt="" loading="lazy" decoding="async" width="' + b.image_w + '" height="' + b.image_h + '">'
      + '<div class="bn-info"><b>' + e(actionText(b)) + '</b>'
      + (placeText ? '<span>لە: ' + e(placeText) + '</span>' : '')
      + (b.kind === 'popup' ? '<span>' + Number(b.seen || 0).toLocaleString('en-US') + ' کەس بینیویەتی</span>' : '')
      + (b.is_active ? '' : '<span class="bn-hidden">پیشان نادرێت</span>')
      + '</div>'
      + '<div class="bn-ctl">'
      + '<label class="mswitch" title="' + (b.is_active ? 'پیشان دەدرێت' : 'پیشان نادرێت') + '"><input type="checkbox" aria-label="پیشاندان"' + (b.is_active ? ' checked' : '') + ' onchange="setBannerActive(\'' + b.id + '\', this.checked)"><span class="track"></span></label>'
      + '<div class="bn-btns">'
      + '<button type="button" class="act-btn dark" aria-label="بەرەو سەرەوە" title="بەرەو سەرەوە"' + (i === 0 ? ' disabled' : '') + ' onclick="moveBanner(\'' + b.id + '\', -1)"><i class="fas fa-arrow-up"></i></button>'
      + '<button type="button" class="act-btn dark" aria-label="بەرەو خوارەوە" title="بەرەو خوارەوە"' + (i === arr.length - 1 ? ' disabled' : '') + ' onclick="moveBanner(\'' + b.id + '\', 1)"><i class="fas fa-arrow-down"></i></button>'
      + '<button type="button" class="act-btn dark" aria-label="دەستکاری" title="دەستکاری" onclick="openBannerEditor(\'' + b.kind + '\', \'' + b.id + '\')"><i class="fas fa-pen"></i></button>'
      + '<button type="button" class="act-btn rd" aria-label="سڕینەوە" title="سڕینەوە" onclick="deleteBanner(\'' + b.id + '\')"><i class="fas fa-trash"></i></button>'
      + '</div></div></div>';
  }
  function render(){
    ['slide', 'popup'].forEach(kind => {
      const wrap = $(kind === 'slide' ? 'bnSlides' : 'bnPopups');
      if (!wrap) return;
      const rows = list.filter(b => b.kind === kind);
      wrap.innerHTML = rows.length ? rows.map(itemHTML).join('') : '<div class="bn-empty">هیچ بانەرێک نییە</div>';
    });
  }
  async function load(){
    try { list = await adminApiRequest('banners_list', {}); render(); }
    catch (err) {
      ['bnSlides', 'bnPopups'].forEach(id => { const w = $(id); if (w) w.innerHTML = '<div class="bn-empty">' + e(err && err.message) + '</div>'; });
    }
  }

  window.setBannerActive = async function(id, on){
    try { await adminApiRequest('banner_set_active', { id, is_active: on }); toast(on ? 'بانەرەکە پیشان دەدرێت' : 'بانەرەکە شاردرایەوە', 'gr'); }
    catch (err) { toast(err && err.message || 'نەگۆڕدرا', 'rd'); }
    await load();
  };
  window.moveBanner = async function(id, dir){
    const b = list.find(x => x.id === id); if (!b || busy) return;
    const ids = list.filter(x => x.kind === b.kind).map(x => x.id);
    const i = ids.indexOf(id), j = i + dir;
    if (j < 0 || j >= ids.length) return;
    [ids[i], ids[j]] = [ids[j], ids[i]];
    busy = true;
    try { await adminApiRequest('banner_reorder', { ids }); } catch (err) { toast(err && err.message || 'نەگۆڕدرا', 'rd'); }
    busy = false; await load();
  };
  window.deleteBanner = function(id){
    confirm2('سڕینەوەی بانەر', 'ئەم بانەرە و وێنەکەی دەسڕدرێنەوە', 'fas fa-trash', 'var(--rd)', async () => {
      try { await adminApiRequest('banner_delete', { id }); toast('بانەرەکە سڕایەوە', 'gr'); }
      catch (err) { toast(err && err.message || 'نەسڕایەوە', 'rd'); }
      await load();
    });
  };

  // ── editor ──────────────────────────────────────────────────────
  function drawEditor(){
    const d = draft, [w, h] = SIZE[d.kind];
    $('bnModalTitle').textContent = (d.id ? 'دەستکاری ' : 'زیادکردنی ') + (d.kind === 'slide' ? 'بانەری داشبۆرد' : 'بانەری سەر شاشە');
    const pic = d.preview || (d.image_path ? imgUrl(d.image_path) : '');
    $('bnPick').className = 'bn-pick ' + d.kind + (pic ? ' has' : '');
    $('bnPick').innerHTML = pic
      ? '<img src="' + e(pic) + '" alt="">'
      : '<span><b>هەڵبژاردنی وێنە</b><small dir="ltr">' + w + ' × ' + h + '</small></span>';
    $('bnPickMeta').textContent = d.blob ? (w + ' × ' + h + ' · WebP · ' + kb(d.blob.size)) : '';
    document.querySelectorAll('[data-bn-act]').forEach(x => {
      const on = x.dataset.bnAct === d.action_type;
      x.classList.toggle('on', on); x.setAttribute('aria-checked', String(on));
    });
    $('bnSectionWrap').hidden = d.action_type !== 'section';
    $('bnUrlWrap').hidden = d.action_type !== 'url';
    $('bnSection').value = d.action_section || 'exchange';
    $('bnUrl').value = d.action_url || '';
    $('bnPlacesWrap').hidden = d.kind !== 'popup';
    $('bnPlaces').innerHTML = SECTIONS.map(([k, label]) =>
      '<label class="bn-place"><input type="checkbox" value="' + k + '"' + ((d.places || []).includes(k) ? ' checked' : '') + '><span>' + e(label) + '</span></label>').join('');
    $('bnActive').checked = d.is_active !== false;
    $('bnErr').textContent = '';
  }
  window.openBannerEditor = function(kind, id){
    const b = id ? list.find(x => x.id === id) : null;
    if (draft && draft.preview) URL.revokeObjectURL(draft.preview);
    draft = b ? { id: b.id, kind: b.kind, image_path: b.image_path, action_type: b.action_type, action_section: b.action_section, action_url: b.action_url, places: (b.places || []).slice(), is_active: b.is_active }
              : { id: null, kind, image_path: null, action_type: 'none', action_section: 'exchange', action_url: '', places: kind === 'popup' ? ['home'] : [], is_active: true };
    $('bnSection').innerHTML = SECTIONS.map(([k, label]) => '<option value="' + k + '">' + e(label) + '</option>').join('');
    $('bnFile').value = '';
    drawEditor();
    openMo('moBanner');
  };
  window.setBannerAction = function(type){ if (!draft) return; draft.action_type = type; drawEditor(); };

  // cut to the exact frame from the middle, then the smallest WebP that still looks clean
  async function toWebp(file, W, H){
    let src;
    try { src = await createImageBitmap(file); }
    catch (_) {
      src = await new Promise((res, rej) => { const im = new Image(); im.onload = () => res(im); im.onerror = rej; im.src = URL.createObjectURL(file); });
    }
    const sw0 = src.width, sh0 = src.height;
    const scale = Math.max(W / sw0, H / sh0), sw = W / scale, sh = H / scale;
    const canvas = document.createElement('canvas'); canvas.width = W; canvas.height = H;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(src, (sw0 - sw) / 2, (sh0 - sh) / 2, sw, sh, 0, 0, W, H);
    let blob = null;
    for (const q of [0.82, 0.74, 0.66, 0.58, 0.5]) {
      blob = await new Promise(res => canvas.toBlob(res, 'image/webp', q));
      if (!blob || blob.type !== 'image/webp') throw new Error('ئەم وێنگەڕە ناتوانێت WebP دروست بکات؛ Chrome بەکاربهێنە');
      if (blob.size <= MAX_BYTES) break;
    }
    return blob;
  }
  window.pickBannerImage = async function(input){
    const file = input.files && input.files[0];
    if (!file || !draft) return;
    if (!/^image\//.test(file.type)) { $('bnErr').textContent = 'تەنها وێنە هەڵبژێرە'; return; }
    try {
      const [W, H] = SIZE[draft.kind];
      const blob = await toWebp(file, W, H);
      if (draft.preview) URL.revokeObjectURL(draft.preview);
      draft.blob = blob; draft.preview = URL.createObjectURL(blob);
      drawEditor();
    } catch (err) { $('bnErr').textContent = err && err.message || 'وێنەکە نەخوێندرایەوە'; }
  };
  window.saveBanner = async function(){
    if (!draft || busy) return;
    const d = draft, err = $('bnErr'), btn = $('bnSaveBtn');
    d.action_section = $('bnSection').value;
    d.action_url = $('bnUrl').value.trim();
    d.places = [...document.querySelectorAll('#bnPlaces input:checked')].map(x => x.value);
    d.is_active = $('bnActive').checked;
    if (!d.blob && !d.image_path) { err.textContent = 'وێنە هەڵبژێرە'; return; }
    if (d.action_type === 'url' && !/^https:\/\/\S+$/.test(d.action_url)) { err.textContent = 'لینکەکە دەبێت بە https:// دەست پێبکات'; return; }
    if (d.kind === 'popup' && !d.places.length) { err.textContent = 'لانیکەم یەک بەش هەڵبژێرە بۆ پیشاندان'; return; }
    busy = true; btn.disabled = true; btn.textContent = 'پاشەکەوت دەکرێت...';
    try {
      let path = d.image_path;
      if (d.blob) {
        const up = await adminApiRequest('banner_upload_url', { kind: d.kind });
        const { error } = await sb.storage.from('banners').uploadToSignedUrl(up.path, up.token, d.blob, { contentType: 'image/webp', cacheControl: '31536000' });
        if (error) throw error;
        path = up.path;
      }
      await adminApiRequest('banner_save', {
        id: d.id, kind: d.kind, image_path: path, is_active: d.is_active,
        action_type: d.action_type,
        action_section: d.action_type === 'section' ? d.action_section : null,
        action_url: d.action_type === 'url' ? d.action_url : null,
        places: d.kind === 'popup' ? d.places : []
      });
      closeMo('moBanner');
      toast('بانەرەکە پاشەکەوتکرا', 'gr');
      await load();
    } catch (x) {
      err.textContent = x && x.message ? x.message : 'پاشەکەوت نەکرا';
    } finally { busy = false; btn.disabled = false; btn.textContent = 'پاشەکەوتکردن'; }
  };

  if (typeof pageConfig === 'object' && pageConfig) {
    pageConfig.banners = { title: 'بانەرەکان', sub: 'بانەری داشبۆرد و بانەری سەر شاشە بۆ کڕیار', load: () => load() };
  }
  window.loadBannersAdmin = load;
})();
