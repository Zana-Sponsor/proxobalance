import {createHash} from 'node:crypto';
export const SCREEN_WIDTHS=[320,393,430,768];
export const SCREEN_IDS=SCREEN_WIDTHS.flatMap(w=>['home-refresh','tools-refresh','ad-error','proxolink-error'].map(s=>'actual-'+s+'-'+w));
export const screenPhases=id=>id.includes('-refresh-')?['initial','100ms','300ms','settled']:['initial','400ms','4900ms','5500ms'];
export const SCREEN_FILES=SCREEN_IDS.flatMap(id=>screenPhases(id).map(phase=>id+'-'+phase+'.png'));
const errors=['actual_screen_permission','actual_screen_phase_missed','actual_screen_surface','actual_screen_refresh','actual_screen_reads',
 'actual_screen_settle','actual_screen_notices','actual_screen_validation','actual_screen_lifecycle','actual_screen_appearance','actual_screen_unclassified'];
const number=v=>Number.isFinite(v)&&Math.abs(v)<=1e10;
const numeric=(item,keys)=>Object.fromEntries(keys.filter(k=>number(item?.[k])).map(k=>[k,item[k]]));
function safeCapture(item,file){
 if(item?.file!==file||!SCREEN_FILES.includes(file))return null;
 return {file,phase:screenPhases(SCREEN_IDS.find(id=>file.startsWith(id+'-'))).find(p=>file.endsWith('-'+p+'.png')),
  ...numeric(item,['requested_elapsed_ms','completed_elapsed_ms']),
  surface:numeric(item.surface,['screen_x','screen_y','width','height','requested_ms','copied_ms','completed_ms']),
  viewport:numeric(item.viewport,['x','y','width','height']),capture:'Android Flutter SurfaceView PixelCopy'};
}
export function safeActualScreens(data){
 const out={fictional_backends:data?.fictional_backends===true,production_screen_classes:data?.production_screen_classes===true,
  hosted_content_verified:data?.hosted_content_verified===true,cases:{},captures:{}};
 for(const id of [...SCREEN_IDS,'setup'])if(data?.cases?.[id]){
  const item=data.cases[id],safe={passed:item.passed===true};
  for(const key of ['same_scroll_element','spinner_closed','automatic_exit','real_form_validation','native_input'])if(typeof item[key]==='boolean')safe[key]=item[key];
  Object.assign(safe,numeric(item,['settled_offset','collection_reads_added']));
  if(item.phase_observations)safe.phase_observations=Object.fromEntries(screenPhases(id).filter(p=>item.phase_observations[p]).map(p=>{
   const state=item.phase_observations[p],out=numeric(state,['observed_elapsed_ms','notice_count','offset']);
   if(typeof state.is_refreshing==='boolean')out.is_refreshing=state.is_refreshing;
   for(const key of ['opacity','size_factor'])if(Array.isArray(state[key])&&state[key].length<=3&&state[key].every(v=>number(v)&&v>=0&&v<=1))out[key]=state[key];
   return[p,out];
  }));
  if(Array.isArray(item.offsets_100_300)&&item.offsets_100_300.length===2&&item.offsets_100_300.every(number))safe.offsets_100_300=item.offsets_100_300;
  if(item.notice_counts)safe.notice_counts=numeric(item.notice_counts,['400ms','4900ms','5500ms']);
  if(item.visual_state)safe.visual_state=Object.fromEntries(['400ms','4900ms','5500ms'].map(phase=>[phase,Object.fromEntries(
    ['opacity','size_factor'].filter(k=>Array.isArray(item.visual_state[phase]?.[k])&&item.visual_state[phase][k].length<=3&&
      item.visual_state[phase][k].every(v=>number(v)&&v>=0&&v<=1)).map(k=>[k,item.visual_state[phase][k]]))]));
  if(item.appearance&&Object.keys(item.appearance).sort().join(',')==='decoration,icon_color,icon_size,text_style')
   safe.appearance_sha256=createHash('sha256').update(JSON.stringify(Object.entries(item.appearance).sort())).digest('hex');
  if(errors.includes(item.failed_check))safe.failed_check=item.failed_check;
  out.cases[id]=safe;
 }
 for(const file of SCREEN_FILES){const item=safeCapture(data?.captures?.[file],file);if(item)out.captures[file]=item;}
 return out;
}
export function validateActualScreens(data,copied){
 const fail=()=>{throw Error('native_actual_screens_failed');};
 if(data.fictional_backends!==true||data.production_screen_classes!==true||data.hosted_content_verified!==false||data.cases.setup)fail();
 for(const id of SCREEN_IDS){
  const item=data.cases[id];if(!item?.passed)fail();
  if(id.includes('-refresh-')){
   if(item.same_scroll_element!==true||item.spinner_closed!==true||item.settled_offset!==0||item.collection_reads_added!==1||
      item.offsets_100_300?.length!==2||!item.offsets_100_300.every(v=>v>0&&v<100))fail();
  }else{
   if(item.real_form_validation!==true||item.automatic_exit!==true||item.native_input!==false||!item.appearance_sha256||
      item.notice_counts?.['400ms']!==2||item.notice_counts?.['4900ms']!==2||item.notice_counts?.['5500ms']!==0)fail();
   for(const phase of ['400ms','4900ms'])for(const key of ['opacity','size_factor'])
    if(item.visual_state?.[phase]?.[key]?.length!==2||!item.visual_state[phase][key].every(v=>v===1))fail();
   for(const key of ['opacity','size_factor'])if(item.visual_state?.['5500ms']?.[key]?.length!==0)fail();
  }
  for(const phase of screenPhases(id)){
   const file=id+'-'+phase+'.png',shot=data.captures[file],width=Number(id.split('-').at(-1));
   if(!copied.has(file)||!shot||!['requested_elapsed_ms','completed_elapsed_ms'].every(k=>number(shot[k]))||
      !['screen_x','screen_y','width','height','requested_ms','copied_ms','completed_ms'].every(k=>number(shot.surface[k]))||
      !['x','y','width','height'].every(k=>number(shot.viewport[k]))||shot.viewport.width!==width||shot.viewport.height!==1200||shot.requested_elapsed_ms<0||
      shot.completed_elapsed_ms<shot.requested_elapsed_ms||shot.surface.width<=0||shot.surface.height<=0||
      shot.surface.copied_ms<shot.surface.requested_ms||shot.surface.completed_ms<shot.surface.copied_ms||
      shot.viewport.x<shot.surface.screen_x||shot.viewport.y<shot.surface.screen_y||
      shot.viewport.x+width>shot.surface.screen_x+shot.surface.width||shot.viewport.y+1200>shot.surface.screen_y+shot.surface.height)fail();
   // Fixed timer phase, one surface request; no retry or later-frame selection.
   if(/^\d+ms$/.test(phase)&&shot.requested_elapsed_ms<parseInt(phase))fail();
  }
 }
 for(const width of SCREEN_WIDTHS)if(data.cases['actual-ad-error-'+width].appearance_sha256!==data.cases['actual-proxolink-error-'+width].appearance_sha256)fail();
 return data;
}
