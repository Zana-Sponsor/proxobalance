import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {DIAGNOSTIC_POINTS,REPRODUCTION_IDS,CHOOSER_IDS,safeRenderDiagnostics,safeChooserResults,validateChooserResults,
 diagnosticSample,diagnosePixelPair,validateDiagnosticRoles,validateReproductions,safeSurface} from '../scripts/proxolink-native-diagnostics.mjs';
import {CREATE_CHOOSER_IDS,safeCreateChooserResults,validateCreateChooserResults} from '../scripts/proxolink-native-diagnostics.mjs';
function state(){return {dom:{dpr:1,scroll_x:0,scroll_y:0,elements:[{present:true,bounds:[0.5,20,393,800],style_hash:123}]},
 native:{sdk:35,density:1,webview_version:'133.0.6943.137',barrier:{visual_state_seen:true,draw_seen:true,frame_commit_seen:false,post_animation_callbacks:2}},flutter_bounds:[403.5,200,393,1520]};}
test('native diagnostic allowlist retains fractional geometry and strips capabilities and arbitrary text',()=>{
 const input=state();input.token='secret';input.dom.url='https://example.invalid/?token=secret';input.native.headers={Authorization:'secret'};
 const out=safeRenderDiagnostics(input);
 assert.deepEqual(out.flutter_bounds,[403.5,200,393,1520]);assert.equal(out.dom.elements[0].bounds[0],0.5);
 assert.equal(out.native.barrier.frame_commit_seen,false);assert.match(out.state_sha256,/^[a-f0-9]{64}$/);
 assert.doesNotMatch(JSON.stringify(out),/secret|Authorization|token|example/);
 const bad=state();bad.native.webview_version='https://example.invalid/token';assert.throws(()=>safeRenderDiagnostics(bad),/invalid/);
 const wrong=state();wrong.dom.dpr=2;assert.throws(()=>safeRenderDiagnostics(wrong),/incomplete/);
 const noDraw=state();noDraw.native.barrier.draw_seen=false;assert.throws(()=>safeRenderDiagnostics(noDraw),/incomplete/);
 assert.deepEqual(safeSurface({status:0,width:1200,private_url:'secret'}),{status:0,width:1200});
});
test('diagnostics report a one-channel difference, exact screen coordinates and unmodified neighborhoods',async()=>{
 const width=8,height=8,raw=Buffer.alloc(width*height*3,200);
 const baseline=await sharp(raw,{raw:{width,height,channels:3}}).png().toBuffer();
 raw[(3*width+4)*3+1]=199;
 const candidate=await sharp(raw,{raw:{width,height,channels:3}}).png().toBuffer();
 const viewport={left:100,top:200,width,height};
 const out=await diagnosePixelPair(candidate,baseline,viewport,[4,3]);
 assert.equal(out.changed_pixels,1);assert.deepEqual(out.changed_coordinates,[[4,3]]);
 assert.deepEqual(out.differences[0].screen,[104,203]);assert.deepEqual(out.differences[0].candidate,[200,199,200]);
 assert.deepEqual(out.differences[0].delta,[0,-1,0]);
 assert.equal(out.differences[0].candidate_neighborhood.length,5);
 assert.deepEqual(out.differences[0].candidate_neighborhood[2][2],{x:4,y:3,rgb:[200,199,200]});
 const sample=await diagnosticSample(candidate,[4,3]);assert.deepEqual(sample.rgb,[200,199,200]);
 const same=await diagnosePixelPair(candidate,candidate,viewport,[4,3]);assert.equal(same.changed_pixels,0);assert.deepEqual(same.historical_point.delta,[0,0,0]);
 await assert.rejects(diagnosticSample(candidate,[8,3]),/invalid/);
});
test('native chooser requires 12 real input taps, 12 captures and every positive design assertion',()=>{
 assert.equal(CHOOSER_IDS.length,12);
 const good=Object.fromEntries(CHOOSER_IDS.map(id=>[id,{passed:true,builder_screen:true,thumbnail_decoded:true,selection_changed:true,selected_state:true,
 live_theme_match:true,provider_type_match:true,fresh_controller:true,native_draw:true,width:393,private_token:'secret'}]));
 const safe=safeChooserResults(good),taps=new Set(CHOOSER_IDS),captures=new Set(CHOOSER_IDS);
 assert.doesNotMatch(JSON.stringify(safe),/secret|token/);validateChooserResults(safe,taps,captures);
 assert.throws(()=>validateChooserResults(safe,new Set(),captures),/native_chooser_failed/);
 assert.throws(()=>validateChooserResults(safe,taps,new Set()),/native_chooser_failed/);
 safe[CHOOSER_IDS[0]].live_theme_match=false;assert.throws(()=>validateChooserResults(safe,taps,captures),/native_chooser_failed/);
});
test('current native Create Page supplements legacy chooser, requires every type/style input and rejects any live preview',()=>{
 const flags=['passed','form_screen','type_match','thumbnail_decoded','selection_changed','selected_state',
  'provider_type_match','no_webview','no_preview_request','native_input','captured'];
 const good=Object.fromEntries(CREATE_CHOOSER_IDS.map(id=>[id,{...Object.fromEntries(flags.map(k=>[k,true])),width:190,token:'secret'}]));
 const safe=safeCreateChooserResults(good),taps=new Set(CREATE_CHOOSER_IDS),captures=new Set(CREATE_CHOOSER_IDS),
  setups=new Set(['contact','order','download'].map(type=>'create-chooser-setup-'+type));
 assert.equal(CHOOSER_IDS.length,12);assert.equal(CREATE_CHOOSER_IDS.length,12);
 assert.doesNotMatch(JSON.stringify(safe),/secret|token/);
 validateCreateChooserResults(safe,taps,captures,setups);
 assert.throws(()=>validateCreateChooserResults(safe,new Set(),captures,setups),/native_create_chooser_failed/);
 assert.throws(()=>validateCreateChooserResults(safe,taps,new Set(),setups),/native_create_chooser_failed/);
 assert.throws(()=>validateCreateChooserResults(safe,taps,captures,new Set()),/native_create_chooser_failed/);
 for(const flag of flags){
  safe[CREATE_CHOOSER_IDS[0]][flag]=false;
  assert.throws(()=>validateCreateChooserResults(safe,taps,captures,setups),/native_create_chooser_failed/);
  safe[CREATE_CHOOSER_IDS[0]][flag]=true;
 }
 delete safe[CREATE_CHOOSER_IDS[0]];
 assert.throws(()=>validateCreateChooserResults(safe,taps,captures,setups),/native_create_chooser_failed/);
});
test('original ten deep targets plus the new download failure require both roles, exactly three samples and the same WebView version',()=>{
 assert.equal(Object.keys(DIAGNOSTIC_POINTS).length,11);
 const roles=Object.fromEntries(Object.keys(DIAGNOSTIC_POINTS).flatMap(id=>['candidate','baseline'].map(role=>[id+'-'+role,{state:state(),state_after:state(),state_after_webcontents:state(),post_webcontents_timing:{started_ms:1,completed_ms:2},pipeline:{status:'captured',dimensions_match:true},surface:{status:0},surface_sample:{rgb:[1,2,3]},samples:[{},{},{}],capture_timing:[{},{},{}]}])));
 validateDiagnosticRoles(roles);
 const first=Object.keys(roles)[0];roles[first].samples.pop();assert.throws(()=>validateDiagnosticRoles(roles),/incomplete/);roles[first].samples.push({});
 roles[first].state.native.webview_version='134.0.0.0';assert.throws(()=>validateDiagnosticRoles(roles),/environment_mismatch/);
});

test('fresh-view reproduction is bounded to eight cases, requires three stable frames and cannot omit a role',()=>{
 assert.equal(REPRODUCTION_IDS.length,8);
 const roles=Object.fromEntries(REPRODUCTION_IDS.flatMap(id=>['candidate','baseline'].map(role=>['repro-'+id+'-'+role,{
   state:{dom:{animation_barrier:{callbacks:2}}},repeatability:{samples:3,exact_pixels_equal:true},pipeline:{status:'captured',dimensions_match:true}}])));
 validateReproductions(roles);const first=Object.keys(roles)[0];roles[first].repeatability.exact_pixels_equal=false;assert.throws(()=>validateReproductions(roles),/incomplete/);
 roles[first].repeatability.exact_pixels_equal=true;delete roles[first];assert.throws(()=>validateReproductions(roles),/incomplete/);
});
test('shadow, containing-block, native density and two-frame measurements survive the safe allowlist',()=>{
 const value=state();value.dom.animation_barrier={requested_ms:1,first_ms:2,second_ms:3,callbacks:2};
 value.dom.elements=[{selector:'[data-provider="whatsapp"]',bounds:[217,325.1875,334,56],parent_bounds:[217,281.1875,334,464],containing_bounds:[0,0,768,1520],
   client_width:334,offset_top:44,computed:{boxShadow:'rgba(17, 130, 73, 0.36) 0px 6px 14px -8px',borderRadius:'50px',fontFamily:'"Bahij"',href:'secret'}}];
 value.dom.resources=[{identity_hash:123,response_status:200,decoded_size:100,url:'secret'}];
 value.native.scaled_density=1;value.native.frames=[{layout_ms:0.1,draw_duration_ms:1.2,vsync_ms:25}];
 const out=safeRenderDiagnostics(value);assert.equal(out.dom.elements[0].computed.borderRadius,'50px');
 assert.equal(out.dom.elements[0].computed.fontFamily,'"Bahij"');assert.equal(out.dom.resources[0].response_status,200);
 assert.equal(out.native.scaled_density,1);assert.equal(out.dom.animation_barrier.callbacks,2);assert.doesNotMatch(JSON.stringify(out),/secret|href/);
 value.dom.elements[0].selector='[data-provider="secret"]';assert.throws(()=>safeRenderDiagnostics(value),/invalid/);
});
