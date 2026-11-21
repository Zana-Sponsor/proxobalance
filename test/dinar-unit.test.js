import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// v90: the customer site writes dinars as «د.ع», never «IQD», and a dinar figure reads right to left
// so «د.ع» sits to the left of the number (as in «پوختەی نرخ»). Dollars stay «N $», left to right.
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const app=read('assets/js/app.js'), html=read('index.html'), css=read('assets/css/transaction-summary.css');

test('no «IQD» is shown to the customer: only currency codes and names in code are left', ()=>{
  const shown=app.split('\n').map((l,i)=>[i+1,l]).filter(([,l])=>/IQD/.test(l)&&!/^\s*\/\//.test(l))
    .map(([n,l])=>[n,l.replace(/'IQD'|SAMPLE_IQD|_iqd\b/g,'')]).filter(([,l])=>/IQD/.test(l));
  assert.deepEqual(shown,[]);
  // the page: only the schema.org data keeps the code
  assert.deepEqual(html.match(/IQD/g),['IQD']);
  assert.match(html, /"currenciesAccepted": "IQD, USD"/);
  assert.match(html, /<span>قەبارەی ئاڵوگۆڕ \(د\.ع\)<\/span>/);
  assert.match(html, /<strong id="bxAmount" dir="rtl">/);
});

test('txAmount writes «د.ع»; amtDir turns dinars right to left and keeps dollars left to right', ()=>{
  const a=app.indexOf('function txAmount('), b=app.indexOf('// Date as «DD - MM - YYYY', a);
  const c=vm.createContext({formatNum:v=>Number(v).toLocaleString('en-US')});
  vm.runInContext(app.slice(a,b),c);
  assert.equal(c.txAmount(60000,'FIB'),'60,000 د.ع');
  assert.equal(c.txAmount(50,'USDT'),'50 $');
  assert.equal(c.txAmount('x','FIB'),'—');
  assert.equal(c.amtDir('60,000 د.ع'),'rtl');
  assert.equal(c.amtDir('50 $'),'ltr');
  assert.equal(c.amtDir('50$'),'ltr');
  assert.equal(c.amtDir('—'),'rtl');
});

test('every place a figure is written takes its direction from the figure', ()=>{
  for(const re of [
    /'<strong class="tf-hero-amount" dir="'\+amtDir\(opts\.amount\)\+'">'/,
    /'<strong class="tx-item-amount" dir="'\+amtDir\(amount\)\+'">'/,
    /<b class="fb-v" dir="'\+amtDir\(v\)\+'">/,
    /<b class="fbx-amt" dir="'\+amtDir\(txAmount\(order\.amount,order\.from_method\)\)\+'">/,
    /<b class="dbr-amt" dir="'\+amtDir\(amount\)\+'">/,
    /<span class="cf-amount" dir="'\+amtDir\(displayAmt\)\+'">/,
    /row\('وەرگر وەریدەگرێت',formatNum\(payout\.payout_iqd\)\+' د\.ع','is-result','rtl'\)/,
    /'<span class="rate-in" dir="'\+amtDir\(inTxt\)\+'">'/,
    /<strong class="bh-amt" dir="rtl"><bdi dir="ltr">\+'\+escHtml\(Number\(r\.delta_iqd\|\|0\)\.toLocaleString\('en-US'\)\)\+'<\/bdi> د\.ع<\/strong>/,
    /<small class="bx-cur">د\.ع<\/small>/,
  ]) assert.match(app, re);
  // the confirmation no longer turns the summary's «د.ع» back into «IQD»
  assert.doesNotMatch(app, /replace\(\/ د\\\.ع\$\/,' IQD'\)/);
  // two older sheets set direction: ltr by class; the attribute wins
  assert.match(css, /html body :is\(\.fb-v, \.bh-amt, \.tx-item-amount, \.tf-hero-amount, \.fbx-amt, \.dbr-amt, \.fa-val, \.rate-in, \.rate-out, \.cf-amount, \.confirm-row-value, #bxAmount\)\[dir="rtl"\] \{\n  direction: rtl !important; unicode-bidi: isolate !important;\n\}/);
});
