import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';

// v94: a «!» beside «پسووڵەی پارەدان» opens «پسووڵەی پارەدان چییە؟»: two example receipts (everything
// but the amount hidden) and one paragraph that says what to do.
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const bytes=path=>readFileSync(new URL('../'+path,import.meta.url));
const html=read('index.html'), css=read('assets/css/exchange-form.css'), app=read('assets/js/app.js');
const P='html body #mainApp#mainApp#mainApp #pageHome #exchangeCard';

test('the «!» sits beside the receipt title and opens the sheet', ()=>{
  assert.match(html, /<h3>پسووڵەی پارەدان<\/h3>\s*<!-- [^>]*-->\s*<button type="button" class="xc-help-btn" onclick="openReceiptHelp\(\)" aria-haspopup="dialog" aria-controls="receiptHelpSheet" aria-label="پسووڵەی پارەدان چییە؟"><svg class="pxi"[^>]*><circle cx="12" cy="12" r="9"\/><path d="M12 7\.5v5\.5"\/><path d="M12 16\.5h\.01"\/><\/svg><\/button>\s*<\/div>/);
  assert.match(app, /function openReceiptHelp\(\)\{\n  const sheet=document\.getElementById\('receiptHelpSheet'\);\n  if\(sheet\) openSheet\(sheet\);\n\}/);
  assert.match(app, /function closeReceiptHelp\(\)\{\n  const sheet=document\.getElementById\('receiptHelpSheet'\);\n  if\(sheet\) closeSheet\(sheet\);\n\}/);
  assert.match(app, /try\{ closeRoundingInfo\(\); \}catch\(_\)\{\}\n  try\{ closeReceiptHelp\(\); \}catch\(_\)\{\}/);
});

test('the sheet: title, close, two examples, one paragraph', ()=>{
  const a=html.indexOf('<div id="receiptHelpSheet"'), b=html.indexOf('<!-- ══', a);
  const sheet=html.slice(a,b);
  assert.match(sheet, /class="sheet-overlay" role="dialog" aria-modal="true" aria-labelledby="receiptHelpTitle" aria-describedby="receiptHelpText" aria-hidden="true" onclick="if\(event\.target===this\) closeReceiptHelp\(\)"/);
  assert.match(sheet, /<h3 id="receiptHelpTitle">پسووڵەی پارەدان چییە؟<\/h3>\s*<button type="button" class="sheet-close" onclick="closeReceiptHelp\(\)" aria-label="داخستن">/);
  assert.match(sheet, /<div class="rh-shots">\s*<img src="\/assets\/images\/receipt-example-1\.jpg" width="480" height="640" alt="نموونەی پسووڵەی پارەدان" loading="lazy" decoding="async">\s*<img src="\/assets\/images\/receipt-example-2\.jpg" width="480" height="640" alt="نموونەیەکی تری پسووڵەی پارەدان" loading="lazy" decoding="async">\s*<\/div>/);
  assert.match(sheet, /<p class="ri-text" id="receiptHelpText">کاتێک ڕێگای ناردن و وەرگرتن هەڵدەبژێریت، لە سەرەوە ژمارەیەکت بۆ دەردەکەوێت\. بڕی پارەکە بۆ ئەو ژمارەیە بنێرە، پاشان سکرین شۆتی پەڕەی ناردنەکە بگرە و لە بەشی پسووڵەی پارەدان دایبنێ\.<\/p>/);
  assert.equal((sheet.match(/<p /g)||[]).length, 1);
});

test('the examples are small 480×640 JPEGs that carry no camera data', ()=>{
  for(const f of ['assets/images/receipt-example-1.jpg','assets/images/receipt-example-2.jpg']){
    const b=bytes(f);
    assert.equal(b[0],0xFF); assert.equal(b[1],0xD8);              // JPEG
    assert.ok(b.length<40*1024, f+' '+b.length);
    assert.equal(b.indexOf(Buffer.from('Exif')), -1, f+' has EXIF');
    // the size, from the start-of-frame marker
    let i=2, size=null;
    while(i<b.length){ if(b[i]!==0xFF){ i++; continue; } const m=b[i+1]; const len=b.readUInt16BE(i+2);
      if(m>=0xC0&&m<=0xC2){ size=[b.readUInt16BE(i+7),b.readUInt16BE(i+5)]; break; } i+=2+len; }
    assert.deepEqual(size,[480,640],f);
  }
});

test('the look: the «!» blue by the title; the sheet as «بڕی گەڕێندراو», the examples 3:4 side by side', ()=>{
  assert.ok(css.includes(`${P} #grpProof .xc-step-head h3 { flex: 0 1 auto !important; }`));
  assert.match(css, /\.xc-help-btn \{\n  flex: 0 0 auto; display: inline-grid !important; place-items: center; width: 32px; height: 32px;[^}]*color: var\(--xf-accent\) !important;/);
  assert.ok(css.includes(`${P} .xc-help-btn:focus-visible { outline: 2px solid var(--xf-accent); outline-offset: 1px; }`));
  assert.match(css, /html body #receiptHelpSheet#receiptHelpSheet \.sheet-head h3 \{\n  color: var\(--ri-ink\) !important; font-size: 18px !important; font-weight: 500 !important;/);
  assert.match(css, /html body #receiptHelpSheet \.rh-shots \{ display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin: 0 0 14px; \}/);
  assert.match(css, /html body #receiptHelpSheet \.rh-shots img \{\n  display: block; width: 100%; height: auto; aspect-ratio: 3 \/ 4; object-fit: cover;/);
  assert.match(css, /html body #receiptHelpSheet \.ri-text \{[^}]*font-size: 15px !important; font-weight: 400 !important; line-height: 1\.9 !important;/);
  assert.match(css, /html\[data-theme="dark"\] body #receiptHelpSheet \{\n  --ri-sheet: #131c2e;/);
  assert.match(css, /@media \(prefers-reduced-motion: reduce\) \{\n  html body #receiptHelpSheet#receiptHelpSheet > \.sheet \{ transition: none; \}\n\}/);
});
