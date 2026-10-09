import test from 'node:test';
import assert from 'node:assert/strict';
import {SCREEN_IDS,SCREEN_FILES,screenPhases,safeActualScreens,validateActualScreens} from '../scripts/proxolink-native-actual-screens.mjs';
test('actual native screen gate requires all widths, fixed surface captures, real validation and automatic exit without claiming hosted content',()=>{
 const data={fictional_backends:true,production_screen_classes:true,hosted_content_verified:false,cases:{},captures:{},token:'private'};
 for(const id of SCREEN_IDS){
  data.cases[id]=id.includes('-refresh-')?{passed:true,same_scroll_element:true,spinner_closed:true,settled_offset:0,collection_reads_added:1,offsets_100_300:[30,60]}:
   {passed:true,real_form_validation:true,automatic_exit:true,native_input:false,appearance:{decoration:'BoxDecoration',text_style:'Rabar',icon_size:18,icon_color:0xffb74956},notice_counts:{'400ms':2,'4900ms':2,'5500ms':0},
    visual_state:{'400ms':{opacity:[1,1],size_factor:[1,1]},'4900ms':{opacity:[1,1],size_factor:[1,1]},'5500ms':{opacity:[],size_factor:[]}}};
  for(const phase of screenPhases(id)){const file=id+'-'+phase+'.png',ms=parseInt(phase)||0;data.captures[file]={file,phase,
   requested_elapsed_ms:ms,completed_elapsed_ms:ms+40,surface:{screen_x:0,screen_y:0,width:1200,height:1900,requested_ms:100,completed_ms:140},
   viewport:{x:0,y:0,width:Number(id.split('-').at(-1)),height:1200},url:'https://private.example/token'};}
 }
 const safe=safeActualScreens(data),copies=new Set(SCREEN_FILES);assert.doesNotMatch(JSON.stringify(safe),/private|https|token|BoxDecoration|Rabar/);
 validateActualScreens(safe,copies);
 assert.throws(()=>validateActualScreens(safe,new Set()),/native_actual_screens_failed/);
 const mutate=fn=>{const next=structuredClone(safe);fn(next);assert.throws(()=>validateActualScreens(next,copies),/native_actual_screens_failed/);};
 mutate(d=>d.hosted_content_verified=true);mutate(d=>delete d.cases[SCREEN_IDS[0]]);mutate(d=>d.cases[SCREEN_IDS[0]].settled_offset=1);
 mutate(d=>d.cases['actual-ad-error-393'].notice_counts['5500ms']=1);mutate(d=>d.cases['actual-ad-error-393'].appearance_sha256='wrong');
 mutate(d=>d.cases['actual-ad-error-393'].visual_state['400ms'].opacity[0]=0);
 mutate(d=>d.captures['actual-home-refresh-393-100ms.png'].requested_elapsed_ms=99);
 mutate(d=>d.captures[SCREEN_FILES[0]].viewport.x=1200);
});
