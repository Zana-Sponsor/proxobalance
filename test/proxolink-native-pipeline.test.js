import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import sharp from 'sharp';
import {digest,inputHashes,inputDifferences,resourceIdentity,safeLayers,readNativePipeline,sourceIdentity,markupIdentity,markupDifferences} from '../scripts/proxolink-native-pipeline.mjs';
import {DIAGNOSTIC_POINTS,REPRODUCTION_IDS,diagnosePixelPair} from '../scripts/proxolink-native-diagnostics.mjs';
import {compareNativePixels,captureNativeFrames} from '../scripts/proxolink-pixel-comparison.mjs';
test('input and resource evidence hashes private content without treating a field difference as causal',()=>{
 const a=inputHashes({template:'pill',avatarUrl:'/order/secret/avatar?preview_token=secret',buttons:[{url:'secret'}]}),b=inputHashes({template:'pill',avatarUrl:null,buttons:[{url:'secret'}]});
 assert.deepEqual(inputDifferences(a,b),[{field:'avatarUrl',possible_effects:['resource_selection'],causal_effect_proven:false}]);
 const resource=resourceIdentity('https://private.invalid/order/secret/avatar?preview_token=secret');
 assert.equal(resource.kind,'avatar');assert.equal(resource.query_count,1);assert.match(resource.identity_sha256,/^[a-f0-9]{64}$/);
 assert.doesNotMatch(JSON.stringify({a,b,resource}),/secret|private|token/);
});
test('layer evidence retains subpixel geometry, hierarchy and matrix without URLs or arbitrary strings',()=>{
 const layers=safeLayers([{layerId:'private',width:768,height:1520,offsetX:.5,paintCount:3,drawsContent:true,url:'secret'},
 {layerId:'child',parentLayerId:'private',width:334,height:56,transform:[1,0,0,0,0,1,0,0,0,0,1,0,217,325.1875,0,1]}]);
 assert.equal(layers[0].offsetX,.5);assert.equal(layers[1].parent_index,0);assert.equal(layers[1].transform[13],325.1875);
 assert.doesNotMatch(JSON.stringify(layers),/secret|private|url/);assert.throws(()=>safeLayers([{transform:[1,2]}]),/invalid/);
});
test('live markup differences locate structural inputs while retaining only bounded hashes',()=>{
 const nodes=[{tag:'HTML',parent:-1,attributes:[],text:''},{tag:'P',parent:0,
  attributes:[{name:'id',value:'private'},{name:'href',value:'https://secret.invalid?token=secret'}],text:'private customer'}];
 const a=markupIdentity(nodes),reverse=structuredClone(nodes);reverse[1].attributes.reverse();
 assert.deepEqual(a,markupIdentity(reverse));
 const changed=structuredClone(nodes);changed[1].text+='!';
 const differences=markupDifferences(a,markupIdentity(changed));
 assert.deepEqual(differences,[{index:1,presence_changed:false,parent_changed:false,tag_changed:false,
  text_changed:true,attributes_changed:false,causal_effect_proven:false}]);
 assert.doesNotMatch(JSON.stringify({a,differences}),/private|customer|secret|https|token/);
 assert.throws(()=>markupIdentity([{tag:'HTML',parent:0,attributes:[],text:''}]),/native_pipeline_invalid/);
 assert.throws(()=>markupIdentity(Array(2049).fill(nodes[0])),/native_pipeline_invalid/);
});
test('live source identity hashes actual styles/font bytes and rejects empty cached evidence',()=>{
 const css='@font-face{font-family:private;src:url(data:font/woff2;base64,c2VjcmV0)}body{color:red}';
 const evidence=sourceIdentity('<html><style>'+css+'</style><p>secret customer name</p></html>');
 assert.equal(evidence.status,'captured');assert.equal(evidence.css_sha256,digest(css));
 assert.equal(evidence.style_count,1);assert.equal(evidence.embedded[0].kind,'font');
 assert.equal(evidence.embedded[0].body_sha256,digest(Buffer.from('secret')));assert.equal(evidence.embedded[0].body_bytes,6);
 assert.deepEqual(sourceIdentity(''),{status:'unavailable',reason:'empty_document'});
 assert.equal(sourceIdentity('<html></html>').css_sha256,null);
 assert.doesNotMatch(JSON.stringify(evidence),/secret|private|customer|font-family|base64/);
 assert.throws(()=>sourceIdentity(null),/native_pipeline_invalid/);
});
test('Dart scripts parse and host/probe target all eight failures plus two controls identically',()=>{
 const dart=fs.readFileSync(new URL('../proxo_app/integration_test/proxolink_native_diagnostics.dart',import.meta.url),'utf8');
 for(const [id,point] of Object.entries(DIAGNOSTIC_POINTS))assert.ok(dart.includes("'"+id+"':["+point.join(',')+']'));
 for(const match of dart.matchAll(/r'''([\s\S]*?)'''/g))new vm.Script(match[1].replaceAll('POINT_X','225').replaceAll('POINT_Y','386'));
 assert.equal(REPRODUCTION_IDS.length,8);assert.deepEqual(DIAGNOSTIC_POINTS['pill-contact-en-portrait-768'],[225,386]);
});
test('post-acceptance diagnostics cannot tolerate one channel or choose a later matching sample',async()=>{
 const raw=Buffer.alloc(8*8*3,200),image=()=>sharp(raw,{raw:{width:8,height:8,channels:3}}).png().toBuffer();
 const first=await image();raw[(3*8+4)*3+1]=199;const changed=await image();
 const crop={left:0,top:0,width:8,height:8,css_height:8};
 const compared=await compareNativePixels(changed,first,crop);assert.equal(compared.metrics.changed_pixels,1);assert.equal(compared.metrics.exact_pixels_equal,false);
 let count=0;const frames=await captureNativeFrames(()=>[changed,first,first][count++],crop);
 assert.equal(count,3);assert.deepEqual(frames.png,changed);assert.equal(frames.repeatability.exact_pixels_equal,false);
 const diagnostic=await diagnosePixelPair(changed,first,crop,[4,3],{coordinateLimit:0});
 assert.equal(diagnostic.changed_pixels,1);assert.equal(diagnostic.coordinates_truncated,true);
 // Only explanatory output can be bounded; the acceptance metric remains failed.
 assert.equal(compared.metrics.exact_pixels_equal,false);
});
test('native CDP readback uses one predetermined frame and hashes cached resources, never publishes endpoint data',async()=>{
 const png=await sharp({create:{width:8,height:8,channels:3,background:'#eeeeee'}}).png().toBuffer();
 const html='<html><style>body{color:red}</style><script id="proxo-config">{"name":"secret","template":"pill"}</script></html>';
 const capture='pill-order-ku-portrait-768-candidate',calls=[],commands=[];
 let cached=html;
 const originalFetch=globalThis.fetch,originalSocket=globalThis.WebSocket;
 class FakeSocket extends EventTarget{
  constructor(){super();queueMicrotask(()=>this.dispatchEvent(new Event('open')));}
  close(){}
  send(text){const {id,method,params}=JSON.parse(text);calls.push({method,params});let result={};
   if(method==='Runtime.evaluate')result={result:{value:params.expression==='window.__nativeCaptureIdentity'?capture:JSON.stringify({html,config:{name:'secret',template:'pill'},buttons:[{provider:'whatsapp',href:'secret'}]})}};
   if(method==='Page.getLayoutMetrics')result={cssLayoutViewport:{clientWidth:8,clientHeight:8},cssVisualViewport:{clientWidth:8,clientHeight:8,scale:1},cssContentSize:{width:8,height:8}};
   if(method==='Page.captureScreenshot')result={data:png.toString('base64')};
   if(method==='Page.getResourceTree')result={frameTree:{frame:{id:'frame',url:'https://private.invalid/contact-preview?token=secret'},resources:[]}};
   if(method==='Page.getResourceContent')result={content:cached,base64Encoded:false};
   queueMicrotask(()=>this.dispatchEvent(new MessageEvent('message',{data:JSON.stringify({id,result})})));
  }
 }
 globalThis.WebSocket=FakeSocket;
 globalThis.fetch=async()=>({ok:true,json:async()=>[{webSocketDebuggerUrl:'ws://localhost:123/devtools/page/private'}]});
 try{
  const result=await readNativePipeline(args=>{commands.push(args);return Buffer.from(args.includes('pidof')?'42':args.includes('tcp:0')?'123':'');},'com.proxo.proxoapp',capture);
  assert.equal(result.metadata.status,'captured');assert.deepEqual(result.png,png);assert.equal(result.metadata.source.html_sha256,digest(html));
  assert.equal(calls.filter(x=>x.method==='Page.captureScreenshot').length,1);
  assert.deepEqual(calls.find(x=>x.method==='Page.captureScreenshot').params,{format:'png',fromSurface:true,captureBeyondViewport:false});
  assert.equal(result.metadata.source.inputs.fields.find(x=>x.field==='name').sha256,digest(JSON.stringify('secret')));
  assert.doesNotMatch(JSON.stringify(result.metadata),/secret|private|token|contact-preview/);
  assert.ok(commands.some(args=>args.includes('--remove')));
  cached='';const empty=await readNativePipeline(args=>Buffer.from(args.includes('pidof')?'42':args.includes('tcp:0')?'123':''),'com.proxo.proxoapp',capture);
  assert.equal(empty.metadata.source.status,'unavailable');assert.equal(empty.metadata.source.css_sha256,undefined);
  assert.equal(empty.metadata.live_source.status,'captured');assert.equal(empty.metadata.live_source.css_sha256,digest('body{color:red}'));
  assert.equal(empty.metadata.resources[0].body_bytes,0);
  assert.doesNotMatch(JSON.stringify(empty.metadata),/secret|private|token|contact-preview/);
 }finally{globalThis.fetch=originalFetch;globalThis.WebSocket=originalSocket;}
});
