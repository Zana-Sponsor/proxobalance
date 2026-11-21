import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// v93: the receipt is added two ways, the camera or the gallery, with no other words; once chosen it
// shows the picture and a way to take it off. A picture from the camera is moved into #fileInput.
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const html=read('index.html'), css=read('assets/css/exchange-form.css'), app=read('assets/js/app.js');
const P='html body #mainApp#mainApp#mainApp #pageHome #exchangeCard';
const proof=html.slice(html.indexOf('<section class="xc-step" id="grpProof">'), html.indexOf('</section>', html.indexOf('id="grpProof"')));
const fnSource=name=>{
  const a=app.indexOf('function '+name+'(');
  assert.ok(a>=0,name);
  let depth=0,i=app.indexOf('{',a);
  for(;i<app.length;i++){ if(app[i]==='{') depth++; else if(app[i]==='}'&&--depth===0) break; }
  return app.slice(a,i+1);
};

test('two options, camera then gallery, and nothing else to read', ()=>{
  assert.match(proof, /<input type="file" id="fileInput" class="file-input-native" accept="image\/jpeg,image\/png,image\/webp" onchange="onFileSelected\(this\)">/);
  assert.match(proof, /<input type="file" id="fileInputCamera" class="file-input-native" accept="image\/\*" capture="environment" onchange="onCameraSelected\(this\)">/);
  assert.match(proof, /<label class="xc-receipt-opt is-camera" for="fileInputCamera"><svg[^>]*>[\s\S]*?<\/svg><span>کامێرا<\/span><\/label>\s*<label class="xc-receipt-opt" for="fileInput"><svg[^>]*>[\s\S]*?<\/svg><span>گەلەری<\/span><\/label>/);
  assert.match(proof, /<div class="xc-receipt-picked" id="receiptPicked" hidden>\s*<img id="receiptThumb" alt="">\s*<b>پسووڵە زیاد کرا<\/b>\s*<button type="button" class="xc-receipt-clear" onclick="clearReceipt\(\)" aria-label="لابردنی پسووڵە">/);
  assert.match(proof, /<span class="field-error" id="fileInputError"><\/span>/);
  // the old words are gone
  assert.doesNotMatch(proof, /JPG|PNG|WEBP|هەڵبژێرە|بەبێ بەڵگەی ناردن|xc-hint|file-picker/);
  assert.doesNotMatch(app, /filePickerName|filePickerMeta|label\[for="fileInput"\]\.file-picker|Gallery یان Files/);
});

test('the camera\'s picture lands in #fileInput; a gallery pick clears the camera; × clears both', ()=>{
  const els={}, calls=[];
  const mk=id=>({id,value:'',files:[]});
  els.fileInput=mk('fileInput'); els.fileInputCamera=mk('fileInputCamera');
  const ctx=vm.createContext({document:{getElementById:id=>els[id]||null},calls,
    DataTransfer:function(){ const f=[]; this.items={add:x=>f.push(x)}; this.files=f; },
    onFileSelected:input=>calls.push(input.id)});
  vm.runInContext(fnSource('receiptFile')+fnSource('onCameraSelected')+fnSource('clearReceipt'),ctx);
  const photo={name:'camera.jpg'};
  els.fileInputCamera.files=[photo]; els.fileInputCamera.value='C:\\fakepath\\camera.jpg';
  ctx.onCameraSelected(els.fileInputCamera);
  assert.equal(els.fileInput.files[0],photo);
  assert.equal(els.fileInputCamera.value,'');
  assert.deepEqual(calls,['fileInput']);
  assert.equal(ctx.receiptFile(),photo);
  // a browser that will not move it: the camera input stays the source and receiptFile() reads it
  calls.length=0; els.fileInput.files=[]; els.fileInputCamera.files=[photo];
  ctx.DataTransfer=function(){ throw new Error('no'); };
  ctx.onCameraSelected(els.fileInputCamera);
  assert.deepEqual(calls,['fileInputCamera']);
  assert.equal(ctx.receiptFile(),photo);
  // × clears both and redraws from #fileInput
  calls.length=0; els.fileInput.value='x'; els.fileInputCamera.value='y';
  ctx.clearReceipt();
  assert.equal(els.fileInput.value,''); assert.equal(els.fileInputCamera.value,'');
  assert.deepEqual(calls,['fileInput']);
  // a gallery pick clears the camera
  assert.match(fnSource('onFileSelected'), /if\(file && input\.id==='fileInput'\)\{ const cam=document\.getElementById\('fileInputCamera'\); if\(cam\) cam\.value=''; \}/);
  // validation, submission and the form reset read and clear through these
  assert.match(fnSource('_validateOrderFields'), /const file=receiptFile\(\);/);
  assert.match(app, /const selectedFile=document\.getElementById\('from'\)\.value==='AccountBalance'\?null:receiptFile\(\);/);
  assert.match(fnSource('resetHomeForm'), /try\{ clearReceipt\(\); \}catch\(_\)\{\}/);
});

test('the chosen picture shows with its thumbnail; the options come back when it is taken off', ()=>{
  const opts={hidden:false}, picked={hidden:true}, thumb={attrs:{},removeAttribute(k){ delete this.attrs[k]; delete this.src; }};
  const revoked=[];
  const ctx=vm.createContext({document:{getElementById:id=>({receiptOpts:opts,receiptPicked:picked,receiptThumb:thumb}[id]||null)},
    URL:{createObjectURL:()=>'blob:1',revokeObjectURL:u=>revoked.push(u)}});
  vm.runInContext('let _receiptThumbUrl="";'+fnSource('showReceiptPicked'),ctx);
  assert.equal(ctx.showReceiptPicked({name:'r.jpg'}),true);
  assert.equal(opts.hidden,true); assert.equal(picked.hidden,false); assert.equal(thumb.src,'blob:1');
  ctx.showReceiptPicked(null);
  assert.equal(opts.hidden,false); assert.equal(picked.hidden,true); assert.equal(thumb.src,undefined);
  assert.deepEqual(revoked,['blob:1']);
});

test('the look: two 64-high tiles like the panels; on a computer only the gallery, full width', ()=>{
  assert.ok(css.includes(`${P} .xc-receipt-opts:not([hidden]) { display: grid !important; grid-template-columns: 1fr 1fr; gap: 10px; margin: 0; }`));
  assert.match(css, /\.xc-receipt-opt \{\n  display: flex !important;[^}]*height: 64px; min-height: 64px;[^}]*border: 1px solid var\(--xf-field-line\) !important; border-radius: 14px !important; background: var\(--xf-field\) !important;[^}]*font-size: 16px !important; font-weight: 600 !important;/);
  assert.match(css, /@media \(hover: hover\) and \(pointer: fine\) \{\n  [^\n]+\.xc-receipt-opt\.is-camera \{ display: none !important; \}\n  [^\n]+\.xc-receipt-opts:not\(\[hidden\]\) \{ grid-template-columns: 1fr; \}\n\}/);
  assert.ok(css.includes(`${P} .xc-receipt:has(#fileInput.has-error) :is(.xc-receipt-opt, .xc-receipt-picked) { border-color: #c2414b !important; }`));
  assert.match(css, /\.xc-receipt-picked:not\(\[hidden\]\) \{\n  display: flex !important;[^}]*height: 64px;/);
  assert.ok(css.includes(`${P} .xc-receipt-picked img { flex: 0 0 44px; width: 44px; height: 44px; border-radius: 10px; object-fit: cover; background: var(--xf-chip); }`));
  // keyboard focus on a hidden input shows on its tile
  assert.match(css, /\.xc-receipt:has\(#fileInput:focus-visible\) \.xc-receipt-opt\[for="fileInput"\],\n[^\n]+\.xc-receipt:has\(#fileInputCamera:focus-visible\) \.xc-receipt-opt\[for="fileInputCamera"\] \{ border-color: var\(--xf-accent\) !important;/);
  assert.doesNotMatch(css, /#grpProof label\.file-picker/);
});
