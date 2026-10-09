import {createHash} from 'node:crypto';
import sharp from 'sharp';
export const DIAGNOSTIC_POINTS=Object.freeze({
 'pill-contact-en-portrait-768':[225,386], 'pill-order-ku-portrait-768':[380,222],
 'pill-mint-contact-ku-portrait-768':[290,228], 'pill-mint-order-ku-portrait-320':[257,88],
 'pill-mint-order-ku-portrait-430':[282,184], 'pill-mint-order-ku-portrait-768':[583,90],
 'pill-mint-order-en-portrait-430':[282,184], 'pill-mint-order-en-portrait-768':[290,228],
 'pill-order-en-portrait-768':[380,222], 'pill-mint-contact-ku-portrait-430':[282,184],
});
export const REPRODUCTION_IDS=Object.keys(DIAGNOSTIC_POINTS).slice(0,8);
export const CHOOSER_IDS=['contact','order','download'].flatMap(type=>['pill','pill-mint','pill-dark','pill-white'].map(style=>`chooser-${type}-${style}`));
export const CREATE_CHOOSER_IDS=CHOOSER_IDS.map(id=>'create-'+id);
const numericKeys=new Set(('measured_width measured_height scaled_density orientation insets config_hash html_hash config_source_hash client_width client_height offset_width offset_height offset_left offset_top parent_bounds containing_bounds value_hash identity_hash duration_ms response_end_ms transfer_size encoded_size decoded_size response_status initiator_hash natural_width natural_height family_hash weight_hash dropped_frames vsync_ms intended_vsync_ms layout_ms draw_duration_ms sync_ms command_ms swap_ms total_ms callbacks first_ms second_ms start_ms response_ms dom_complete_ms load_end_ms type_hash content_height page_scale window_width window_height display_width display_height xdpi ydpi window_color_mode document_bounds body_bounds screen_width screen_height screen_color_depth screen_pixel_depth class_hash id_hash initial_ready_ms reload_ready_ms barrier_return_ms time_origin now_ms dpr inner_width inner_height scroll_x scroll_y scroll_width scroll_height visual_viewport bounds style_hash text_hash opacity hit_bounds hit_style_hash href_hash fonts_hash css_hash time play_state_hash end flutter_bounds observed_ms requested_ms visual_state_ms draw_ms frame_commit_ms post_animation_callbacks animation_1_ms animation_2_ms width height screen_x screen_y window_x window_y x y alpha scale_x scale_y translation_x translation_y matrix layer_type density density_dpi sdk').split(' '));
const booleanKeys=new Set(('layout_requested laid_out render_process_present fonts_ready images_ready complete loaded elements_truncated resources_truncated present visibility document_complete visual_state_seen draw_seen frame_commit_seen hardware_accelerated attached').split(' '));
const cssKeys=new Set(('width height minWidth minHeight maxWidth maxHeight position display margin padding border borderTopWidth borderRightWidth borderBottomWidth borderLeftWidth borderColor borderStyle boxSizing backgroundClip overflow overflowX overflowY clipPath zIndex perspective willChange contain fontFeatureSettings fontVariationSettings textAlign direction unicodeBidi fontFamily fontSize fontWeight lineHeight letterSpacing color backgroundColor backgroundImage opacity transform filter mixBlendMode isolation borderRadius boxShadow transformOrigin backgroundSize backgroundPosition fontStyle fontKerning textRendering transitionProperty transitionDuration transitionDelay animationName animationDuration animationDelay animationFillMode animationPlayState zoom').split(' '));
const containerKeys=new Set(['lifecycle','dom','native','barrier','elements','animations','ancestry','covering','navigation','animation_barrier','resources','images','fonts','inputs','buttons','parents','frames','text_rects']);
// No page text, URLs, capabilities, headers, credentials, arbitrary keys or native dumps.
export function safeRenderDiagnostics(value){
 const number=v=>typeof v==='number'&&Number.isFinite(v)&&Math.abs(v)<1e16;
 function clean(v,depth=0){
  if(depth>6||!v||typeof v!=='object'||Array.isArray(v))throw Error('native_diagnostics_invalid');
  const out={};
  for(const [k,item] of Object.entries(v)){
   if(numericKeys.has(k)){
    if(Array.isArray(item)){if(item.length>16||!item.every(number))throw Error('native_diagnostics_invalid');out[k]=item;}
    else {if(!number(item))throw Error('native_diagnostics_invalid');out[k]=item;}
   }else if(booleanKeys.has(k)){
    if(typeof item!=='boolean')throw Error('native_diagnostics_invalid');out[k]=item;
   }else if(containerKeys.has(k)){
    if(Array.isArray(item)){if(item.length>32)throw Error('native_diagnostics_invalid');out[k]=item.map(x=>clean(x,depth+1));}
    else out[k]=clean(item,depth+1);
   }else if(['computed','before','after'].includes(k)){
    const css={};for(const [property,text] of Object.entries(item||{})){
     if(cssKeys.has(property)&&typeof text==='string'&&text.length<2048&&/^[a-z0-9 ,.%#()+_\/\-"']*$/i.test(text)&&(!/url\(/i.test(text)||text==='url(redacted)'))css[property]=text;
    }out[k]=css;
   }else if(k==='tag'&&['HTML','BODY','DIV','H1','H2','P','SPAN','A','IMG','BUTTON','SECTION','SVG','SMALL','OTHER'].includes(item)){out[k]=item;
   }else if(k==='selector'){
    if(typeof item!=='string'||item.length>300||! /^(?:\.(?:wrap|aura|av-wrap|av|profile|uname|ubio|btns|list|store-list|footer)|\[data-provider="(?:whatsapp|viber|instagram|telegram|korek|asiacell|talabat|toters|lezzoo|wade|app_store|google_play)"\]|(?:(?:html|body|div|h1|h2|p|span|a|img|button|section|svg|small):nth-of-type\([0-9]+\)>?){0,6})$/.test(item))throw Error('native_diagnostics_invalid');out[k]=item;
   }else if(k==='field'&&['template','lang','direction','name','bio','avatarUrl','preview','videoUrl','buttons','intents'].includes(item)){out[k]=item;
   }else if(k==='provider'&&['whatsapp','viber','instagram','telegram','korek','asiacell','talabat','toters','lezzoo','wade','app_store','google_play','other'].includes(item)){out[k]=item;
   }else if(k==='webview_version'){
    if(typeof item!=='string'||!/^\d+(?:\.\d+){1,5}$/.test(item))throw Error('native_diagnostics_invalid');out[k]=item;
   }
  }
  return out;
 }
 const out=clean(value);
 if(out.dom?.dpr!==1||out.native?.sdk!==35||out.native?.density!==1||!out.native.webview_version
  ||out.native.barrier?.visual_state_seen!==true||out.native.barrier?.draw_seen!==true
  ||out.native.barrier?.post_animation_callbacks!==2||out.flutter_bounds?.length!==4)
  throw Error('native_diagnostics_incomplete');
 const {time_origin,now_ms,...layout}=out.dom;
 const geometry=Object.fromEntries(['dpr','document_bounds','body_bounds','client_width','client_height','inner_width','inner_height','scroll_x','scroll_y','visual_viewport','elements'].map(k=>[k,out.dom[k]]));
 return {...out,geometry_sha256:createHash('sha256').update(JSON.stringify(geometry)).digest('hex'),dom_state_sha256:createHash('sha256').update(JSON.stringify(layout)).digest('hex'),state_sha256:createHash('sha256').update(JSON.stringify(out)).digest('hex')};
}
const chooserFlags=['passed','builder_screen','thumbnail_decoded','selection_changed','selected_state','live_theme_match','provider_type_match','fresh_controller','native_draw'];
const chooserErrors=new Set(['chooser_builder_setup','chooser_element_missing','chooser_thumbnail_missing','chooser_thumbnail_image','chooser_tap_bounds','chooser_must_change_selection','chooser_selection_callback','chooser_live_preview_design','chooser_selected_state','chooser_native_draw','chooser_capture_ack','chooser_timeout','chooser_unclassified']);
export function safeChooserResults(data){
 return Object.fromEntries(CHOOSER_IDS.filter(id=>data?.[id]).map(id=>{
  const item=data[id],out=Object.fromEntries(chooserFlags.filter(k=>typeof item[k]==='boolean').map(k=>[k,item[k]]));
  if(chooserErrors.has(item.failed_check))out.failed_check=item.failed_check;
  if(Number.isInteger(item.width)&&item.width>=100&&item.width<=430)out.width=item.width;
  if(Array.isArray(item.tap_bounds)&&item.tap_bounds.length===4&&item.tap_bounds.every(v=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<1900))out.tap_bounds=item.tap_bounds;
  return[id,out];
 }));
}
export function validateChooserResults(data,taps,captures){
 if(Object.keys(data).length!==12||taps.size!==12||captures.size!==12||!CHOOSER_IDS.every(id=>
  taps.has(id)&&captures.has(id)&&chooserFlags.every(k=>data[id]?.[k]===true)&&Number.isInteger(data[id]?.width)&&data[id].width>=100&&data[id].width<=430))
  throw Error('native_chooser_failed');
 return data;
}
const createChooserFlags=['passed','form_screen','type_match','thumbnail_decoded','selection_changed','selected_state',
 'provider_type_match','no_webview','no_preview_request','native_input','captured'];
const createChooserErrors=new Set(['create_chooser_setup','create_chooser_element_missing','create_chooser_ack',
 'create_chooser_tap_bounds','create_chooser_selection','create_chooser_thumbnail','create_chooser_providers',
 'create_chooser_preview','create_chooser_unclassified']);
export function safeCreateChooserResults(data){
 return Object.fromEntries(CREATE_CHOOSER_IDS.filter(id=>data?.[id]).map(id=>{
  const item=data[id],out=Object.fromEntries(createChooserFlags.filter(k=>typeof item[k]==='boolean').map(k=>[k,item[k]]));
  if(createChooserErrors.has(item.failed_check))out.failed_check=item.failed_check;
  if(Number.isInteger(item.width)&&item.width>=48&&item.width<=430)out.width=item.width;
  if(Array.isArray(item.tap_bounds)&&item.tap_bounds.length===4&&item.tap_bounds.every(v=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<1900))out.tap_bounds=item.tap_bounds;
  return[id,out];
 }));
}
export function validateCreateChooserResults(data,taps,captures,setups){
 if(Object.keys(data).length!==12||taps.size!==12||captures.size!==12||setups.size!==3||
  !['contact','order','download'].every(type=>setups.has('create-chooser-setup-'+type))||
  !CREATE_CHOOSER_IDS.every(id=>taps.has(id)&&captures.has(id)&&createChooserFlags.every(k=>data[id]?.[k]===true)&&
   Number.isInteger(data[id]?.width)&&data[id].width>=48&&data[id].width<=430))throw Error('native_create_chooser_failed');
 return data;
}
async function rgb(png){return sharp(png).removeAlpha().raw().toBuffer({resolveWithObject:true});}
function point(data,info,x,y){return [...data.subarray((y*info.width+x)*3,(y*info.width+x)*3+3)];}
function region(data,info,x,y){
 const rows=[];
 for(let yy=Math.max(0,y-2);yy<=Math.min(info.height-1,y+2);yy++){
  const row=[];for(let xx=Math.max(0,x-2);xx<=Math.min(info.width-1,x+2);xx++)row.push({x:xx,y:yy,rgb:point(data,info,xx,yy)});
  rows.push(row);
 }
 return rows;
}
export async function diagnosticSample(png,coordinate){
 const {data,info}=await rgb(png),[x,y]=coordinate;
 if(info.channels!==3||x<0||y<0||x>=info.width||y>=info.height)throw Error('native_diagnostics_invalid');
 return {rgb:point(data,info,x,y),neighborhood:region(data,info,x,y),rgb_sha256:createHash('sha256').update(data).digest('hex')};
}
export async function diagnosePixelPair(candidate,baseline,viewport,knownPoint,{coordinateLimit=Infinity}={}){
 const a=await rgb(candidate),b=await rgb(baseline);
 if(a.info.width!==b.info.width||a.info.height!==b.info.height||a.info.channels!==3||b.info.channels!==3)throw Error('native_diagnostics_invalid');
 const changed=[];
 for(let i=0;i<a.data.length;i+=3)if(a.data[i]!==b.data[i]||a.data[i+1]!==b.data[i+1]||a.data[i+2]!==b.data[i+2])changed.push([i/3%a.info.width,Math.floor(i/3/a.info.width)]);
 const describe=([x,y])=>{
  const candidate=point(a.data,a.info,x,y),baseline=point(b.data,b.info,x,y);
  return {crop:[x,y],screen:[x+viewport.left,y+viewport.top],candidate,baseline,delta:candidate.map((v,i)=>v-baseline[i]),
   candidate_neighborhood:region(a.data,a.info,x,y),baseline_neighborhood:region(b.data,b.info,x,y)};
 };
 // Full difference coordinates are retained. Neighborhoods only around the six
 // diagnostic locations and actual differences, with no pixel acceptance change.
 return {viewport,changed_pixels:changed.length,changed_coordinates:changed.slice(0,coordinateLimit),coordinates_truncated:changed.length>coordinateLimit,
  differences:changed.slice(0,64).map(describe),neighborhoods_truncated:changed.length>64,
  historical_point:knownPoint?describe(knownPoint):null};
}
export function validateDiagnosticRoles(roles){
 const ids=Object.keys(DIAGNOSTIC_POINTS).flatMap(id=>[id+'-candidate',id+'-baseline']);
 if(Object.keys(roles).length!==ids.length||!ids.every(id=>roles[id]?.samples?.length===3&&roles[id]?.capture_timing?.length===3
  &&roles[id]?.state?.native?.webview_version&&roles[id]?.state_after?.native?.webview_version
  &&roles[id]?.surface?.status===0&&roles[id]?.surface_sample?.rgb?.length===3&&roles[id]?.pipeline?.status==='captured'&&roles[id]?.pipeline?.dimensions_match===true&&roles[id]?.state_after_webcontents?.native?.webview_version
  &&roles[id]?.post_webcontents_timing?.completed_ms>=roles[id]?.post_webcontents_timing?.started_ms))throw Error('native_diagnostics_incomplete');
 if(new Set(ids.map(id=>roles[id].state.native.webview_version)).size!==1)throw Error('native_diagnostics_environment_mismatch');
 if(!ids.every(id=>roles[id].state.native.webview_version===roles[id].state_after.native.webview_version
  &&roles[id].state.native.webview_version===roles[id].state_after_webcontents.native.webview_version))throw Error('native_diagnostics_environment_mismatch');
}

export function safeSurface(value){
 const keys=['status','requested_ms','completed_ms','screen_x','screen_y','width','height'];
 return Object.fromEntries(keys.filter(k=>typeof value?.[k]==='number'&&Number.isFinite(value[k])).map(k=>[k,value[k]]));
}

// Observations do not turn fresh-view reproductions into acceptance frames.
export function validateReproductions(roles){
 const ids=REPRODUCTION_IDS.flatMap(id=>['candidate','baseline'].map(role=>'repro-'+id+'-'+role));
 if(Object.keys(roles).length!==ids.length||!ids.every(id=>roles[id]?.repeatability?.samples===3
  &&roles[id]?.repeatability?.exact_pixels_equal===true&&roles[id]?.state?.dom?.animation_barrier?.callbacks===2
  &&roles[id]?.pipeline?.status==='captured'&&roles[id]?.pipeline?.dimensions_match===true))throw Error('native_diagnostics_incomplete');
}
