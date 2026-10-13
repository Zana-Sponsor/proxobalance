import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {chromium} from 'playwright';

// Execute the exact Dart-embedded intervention, not a second implementation.
const dart=readFileSync('proxo_app/integration_test/proxolink_native_diagnostics.dart','utf8');
const script=dart.match(/const nativeRepaintScript = r'''([\s\S]*?)''';/)?.[1];
assert.ok(script);
const browser=await chromium.launch({headless:true});
try {
  const page=await browser.newPage({viewport:{width:393,height:800}});
  for(const original of [null,'','color: rgb(21, 32, 43); visibility: visible !important;']){
    await page.setContent('<html><body><div style="height:1400px;background:linear-gradient(#eff8f5,#fff)">Repaint contract</div></body></html>');
    await page.evaluate(value=>{if(value!==null)document.documentElement.setAttribute('style',value);window.scrollTo(0,80);},original);
    const before=await page.screenshot();
    const scroll=await page.evaluate(()=>scrollY);
    await page.evaluate(script);
    await page.waitForFunction(()=>window.__nativeRepaint?.done===true);
    assert.deepEqual(await page.evaluate(()=>window.__nativeRepaint),{done:true,restored:true}, JSON.stringify({original,actual:await page.evaluate(()=>document.documentElement.getAttribute('style'))}));
    assert.equal(await page.evaluate(()=>document.documentElement.getAttribute('style')),original);
    assert.equal(await page.evaluate(()=>scrollY),scroll);
    assert.deepEqual(await page.screenshot(),before);
  }
  console.log('VERIFIED: repaint restores absent, empty and important inline styles, scroll and exact fixture pixels. Native causality remains separate.');
} finally {await browser.close();}
