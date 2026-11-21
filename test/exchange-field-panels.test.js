import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// v89: the figures you type in the new-order form sit in panels that hold their own label:
// (v90: one size for every value, 16/600, the choosers' too and the placeholders'; the amount 26/700)
// the number to pay into, the amount (the big one, its currency a chip), the sender's name and
// phone, and the recipient's number (a green tick when it is right).
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const html=read('index.html'), css=read('assets/css/exchange-form.css'), app=read('assets/js/app.js');
const P='html body #mainApp#mainApp#mainApp #pageHome #exchangeCard';
const fnSource=name=>{
  const a=app.indexOf('function '+name+'(');
  assert.ok(a>=0,name);
  let depth=0,i=app.indexOf('{',a);
  for(;i<app.length;i++){ if(app[i]==='{') depth++; else if(app[i]==='}'&&--depth===0) break; }
  return app.slice(a,i+1);
};

test('the five panels are marked and each keeps its label first, then its field', ()=>{
  assert.match(html, /<div class="wallet-row ux-payment-destination xc-panel">\s*<div class="ux-wallet-head">/);
  assert.match(html, /<div class="field xc-panel xc-amount-field">\s*<label class="field-label" for="amt">چەند دەنێری؟<\/label>/); // v92: the amount asks
  assert.match(html, /<div class="field xc-panel xc-locked" id="senderNameField">\s*<label class="field-label" for="userSenderName">/);
  assert.match(html, /<div class="field xc-panel" id="senderPhoneField" style="display:none">\s*<label class="field-label" for="userSenderPhone">/);
  assert.match(html, /<div class="field xc-panel">\s*<label class="field-label" for="userPhone" id="phoneLabel">/);
  assert.equal((html.match(/xc-panel/g)||[]).length, 6); // five panels, and the comment that names the class
});

test('the amount: its currency is a chip in Kurdish (د.ع, or $ for USDT) that the field points to', ()=>{
  assert.match(html, /<input type="text" inputmode="decimal" id="amt" class="input" placeholder="0" dir="ltr"\s+aria-describedby="amtHint amtSuffix"/);
  assert.match(html, /<span class="xc-in-unit" id="amtSuffix">د\.ع<\/span>/);
  assert.doesNotMatch(html, /xc-in-suffix|>IQD</);
  const el={textContent:''};
  const ctx=vm.createContext({formatNum:String,MIN_AMOUNT:10000,recipientIsCard:()=>false,METHOD_META:{},
    document:{getElementById:id=>({from:{value:'FastPay'},receiveVia:{value:'FIB'},amtSuffix:el,userPhone:{}}[id]||null)}});
  vm.runInContext(fnSource('refreshFormHints')+';refreshFormHints();',ctx);
  assert.equal(el.textContent,'د.ع');
  ctx.document.getElementById=id=>({from:{value:'USDT'},receiveVia:{value:'FIB'},amtSuffix:el,userPhone:{}}[id]||null);
  vm.runInContext('refreshFormHints();',ctx);
  assert.equal(el.textContent,'$');
});

test('the quick amount equal to what is typed is marked and read as pressed; calc works without a full document', ()=>{
  const btn=t=>({textContent:t,cls:new Set(),attrs:{},classList:{toggle(c,on){on?this.o.cls.add(c):this.o.cls.delete(c);}},setAttribute(k,v){this.attrs[k]=v;}});
  const btns=['10,000','50,000','100,000'].map(btn); btns.forEach(b=>{b.classList.o=b;});
  const ctx=vm.createContext({document:{querySelectorAll:sel=>{assert.equal(sel,'#exchangeCard .quick-amount-btn'); return btns;}}});
  vm.runInContext(fnSource('syncQuickAmounts'),ctx);
  ctx.syncQuickAmounts(50000);
  assert.deepEqual(btns.map(b=>[b.cls.has('is-selected'),b.attrs['aria-pressed']]),[[false,'false'],[true,'true'],[false,'false']]);
  ctx.syncQuickAmounts(0);
  assert.ok(btns.every(b=>!b.cls.has('is-selected')&&b.attrs['aria-pressed']==='false'));
  // the vm harnesses give calc() a document with getElementById only
  const bare=vm.createContext({document:{getElementById:()=>null}});
  vm.runInContext(fnSource('syncQuickAmounts'),bare);
  assert.doesNotThrow(()=>bare.syncQuickAmounts(10000));
  assert.match(fnSource('calc'), /^function calc\(\)\{\n  const val=getAmtRaw\(\);\n  const amt=parseFloat\(val\)\|\|0;\n  syncQuickAmounts\(amt\);/);
  assert.match(html, /<div class="quick-amounts" role="group" aria-label="بڕە خێراکان">/);
  assert.equal((html.match(/class="quick-amount-btn" aria-pressed="false" onclick="setQuickAmount\(\d+\)"/g)||[]).length, 3);
});

test('the recipient number shows a tick when validatePhoneLive calls it right', ()=>{
  assert.match(html, /id="userPhone" class="input xc-num"[\s\S]{0,400}?<span class="xc-in-ok" aria-hidden="true"><svg[^>]*><path d="m7 12\.5 3\.2 3\.2L17 9"\/><\/svg><\/span>\s*<\/div>/);
  assert.match(html, /id="userSenderPhone" class="input xc-num"/);
  assert.match(fnSource('validatePhoneLive'), /el\.classList\.add\(good \? 'ok' : 'bad'\);/);
  assert.ok(css.includes(`${P} .xc-input-wrap .input.ok ~ .xc-in-ok { opacity: 1; transform: none; }`));
  assert.ok(css.includes(`${P} .xc-panel #userPhone { padding-left: 48px !important; }`));
});

test('the panel look: label inside at the top, value at the start under it, blue on focus, red on error', ()=>{
  assert.ok(css.includes(`${P} .xc-panel > :is(.field-label, .ux-wallet-head) {\n  position: absolute !important; top: 11px !important; inset-inline: 16px !important;`));
  assert.ok(css.includes(`${P} .xc-panel .xc-input-wrap .input[dir="ltr"] { text-align: right !important; }`));
  assert.ok(css.includes(`${P} .xc-panel:focus-within > .field-label { color: var(--xf-accent) !important; }`));
  assert.ok(css.includes(`${P} .xc-input-wrap .input:is([aria-invalid="true"], .has-error) { border-color: #c2414b !important; }`));
  assert.ok(css.includes(`${P} .xc-panel:has(.input:is([aria-invalid="true"], .has-error)) > .field-label { color: #c2414b !important; }`));
  // the amount: 80 high, 26/700, the chip (13/700) beside the figure, white until the field is
  assert.match(css, /\.xc-in-unit \{\n  position: absolute !important; top: 34px !important; left: 12px !important;[^}]*border-radius: 999px !important; background: var\(--xf-card\) !important;[^}]*font-size: 13px !important; font-weight: 700 !important;/);
  assert.ok(css.includes(`${P} .xc-amount-field:focus-within .xc-in-unit { border-color: transparent !important; background: var(--xf-chip) !important; }`));
  // the number to pay into: the same panel; with nothing to copy the button stays hidden
  assert.match(css, /\.wallet-row-line \.wallet-value \{[^}]*margin: 18px 0 0 !important;[^}]*font-size: 16px !important; font-weight: 600 !important;/);
  assert.ok(css.includes(`${P} .wallet-row-line .copy-btn[style*="none"] { display: none !important; }`));
  // an error: one red line with a small «!», no bubble and no pointer
  assert.ok(css.includes(`${P} .field-error.show::before, ${P} .field-error.show::after { content: none !important; display: none !important; }`));
  assert.match(css, /#exchangeCard \.field-error\.show \{\n  position: static !important; display: flex !important;[^}]*background: none !important;/);
  // motion only answers the person, and stops for reduced motion
  assert.match(css, /@media \(prefers-reduced-motion: reduce\) \{\n  [^\n]+:is\(\.xc-in-ok, \.xc-in-unit, \.quick-amount-btn, \.xc-panel > \.field-label\) \{ transition: none !important; \}/);
});

test('one size for the values (v90): 12 labels, 13 chips and pills, 16 every value and placeholder, 26 the amount', ()=>{
  assert.ok(css.includes(`${P} .picker-trigger-value { color: var(--xf-ink) !important; font-size: 16px !important; font-weight: 600 !important; line-height: 1.5 !important; }`));
  assert.match(css, /\.xc-panel \.xc-input-wrap \.input \{\n  height: 64px !important;[^}]*font-size: 16px !important; font-weight: 600 !important; letter-spacing: \.04em;/);
  assert.ok(css.includes(`${P} .xc-panel .xc-input-wrap .input::placeholder { font-size: 16px; font-weight: 400; letter-spacing: .04em; }`));
  assert.match(css, /\.xc-amount-field \.xc-input-wrap #amt \{\n  height: 80px !important;[^}]*font-size: 26px !important; font-weight: 700 !important; line-height: 38px !important;/);
  assert.ok(css.includes(`${P} .xc-amount-field .xc-input-wrap #amt::placeholder { font-size: 26px; font-weight: 700; letter-spacing: -.01em; }`));
  assert.match(css, /\.quick-amount-btn \{[^}]*font-size: 13px !important; font-weight: 600 !important;/);
  assert.match(css, /\.wallet-row-line \.copy-btn \{[^}]*font-size: 13px !important; font-weight: 600 !important;/);
  assert.match(css, /#exchangeCard \.field-error\.show \{[^}]*font-size: 12px !important; font-weight: 500 !important;/);
  // nothing in a field is under 16 that a phone would zoom into
  const panel = css.slice(css.indexOf('/* ── the figures you type (v89)'), css.indexOf("/* the sender's name comes from the profile"));
  for (const m of panel.matchAll(/\.input[^{]*\{[^}]*font-size: (\d+)px/g)) assert.ok(Number(m[1]) >= 16, m[0]);
});

test('the quick amounts carry «د.ع» (or $ with USDT) and still mark the typed one; the number to pay into says «بینێرە بۆ ئەم ژمارەیە:» (v91)', ()=>{
  for(const [v,t] of [[10000,'10,000'],[50000,'50,000'],[100000,'100,000']])
    assert.ok(html.includes(`<button type="button" class="quick-amount-btn" aria-pressed="false" onclick="setQuickAmount(${v})">${t} <span class="qa-unit">د.ع</span></button>`), t);
  assert.ok(css.includes(`${P} .quick-amount-btn .qa-unit { font-size: 12px !important; font-weight: 500 !important; opacity: .75; }`));
  // the currency follows the amount's
  const units=[{textContent:'د.ع'},{textContent:'د.ع'}];
  const ctx=vm.createContext({formatNum:String,MIN_AMOUNT:10000,recipientIsCard:()=>false,METHOD_META:{},
    document:{getElementById:id=>({from:{value:'USDT'},receiveVia:{value:'FIB'},userPhone:{}}[id]||null),
      querySelectorAll:sel=>{ assert.equal(sel,'#exchangeCard .quick-amount-btn .qa-unit'); return units; }}});
  vm.runInContext(fnSource('refreshFormHints')+';refreshFormHints();',ctx);
  assert.deepEqual(units.map(u=>u.textContent),['$','$']);
  // «10,000 د.ع» is still read as 10000
  const btns=['10,000 د.ع','50,000 د.ع'].map(t=>{ const b={textContent:t,on:false,attrs:{},setAttribute(k,v){this.attrs[k]=v;}}; b.classList={toggle:(c,on)=>{b.on=on;}}; return b; });
  const c2=vm.createContext({document:{querySelectorAll:()=>btns}});
  vm.runInContext(fnSource('syncQuickAmounts'),c2);
  c2.syncQuickAmounts(50000);
  assert.deepEqual(btns.map(b=>b.on),[false,true]);
  // the label of the number to pay into
  assert.match(html, /<div class="ux-wallet-head"><span class="wallet-label">بینێرە بۆ ئەم ژمارەیە:<\/span><\/div>|<span class="wallet-label">بینێرە بۆ ئەم ژمارەیە:<\/span>/);
  assert.match(fnSource('updateWallet'), /payLbl\.textContent=internal\?'باڵانسی هەژمار':'بینێرە بۆ ئەم ژمارەیە:';/);
  assert.doesNotMatch(html+app, /ژمارەی هەژماری ناردن/);
});
