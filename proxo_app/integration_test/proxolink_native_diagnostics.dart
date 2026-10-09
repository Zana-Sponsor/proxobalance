// Debug-only read-only observations. No template, resource, CSS or GPU setting changes.
const nativeDiagnosticPoints = <String,List<int>>{
 'pill-contact-en-portrait-768':[225,386],
 'pill-order-ku-portrait-768':[380,222],
 'pill-mint-contact-ku-portrait-768':[290,228],
 'pill-mint-order-ku-portrait-320':[257,88],
 'pill-mint-order-ku-portrait-430':[282,184],
 'pill-mint-order-ku-portrait-768':[583,90],
 'pill-mint-order-en-portrait-430':[282,184],
 'pill-mint-order-en-portrait-768':[290,228],
 // Passing controls retained from the first instrumentation.
 'pill-order-en-portrait-768':[380,222],
 'pill-mint-contact-ku-portrait-430':[282,184],
};
const nativeReproductionIds = <String>[
 'pill-contact-en-portrait-768','pill-order-ku-portrait-768',
 'pill-mint-contact-ku-portrait-768','pill-mint-order-ku-portrait-320',
 'pill-mint-order-ku-portrait-430','pill-mint-order-ku-portrait-768',
 'pill-mint-order-en-portrait-430','pill-mint-order-en-portrait-768',
];
// Exactly two DOM animation callbacks, recorded on both roles before the existing
// native barrier. These callbacks alone do not prove display presentation.
const nativeAnimationBarrierScript = r'''
window.__nativeAnimationBarrier={requested_ms:performance.now(),callbacks:0};
requestAnimationFrame(t=>{window.__nativeAnimationBarrier.first_ms=t;window.__nativeAnimationBarrier.callbacks=1;
 requestAnimationFrame(t=>{window.__nativeAnimationBarrier.second_ms=t;window.__nativeAnimationBarrier.callbacks=2;});});
''';
String nativeDiagnosticScript(List<int> point) => r'''
(()=>{
 const hash=s=>{let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;};
 const rect=e=>{const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height];};
 const names=['.wrap','.aura','.av-wrap','.av','.profile','.uname','.ubio','.btns','.list','.store-list','.footer'];
 const providers=['whatsapp','viber','instagram','telegram','korek','asiacell','talabat','toters','lezzoo','wade','app_store','google_play'];
 const properties=['width','height','minWidth','minHeight','maxWidth','maxHeight','position','display','margin','padding','border','borderTopWidth','borderRightWidth','borderBottomWidth','borderLeftWidth','borderColor','borderStyle','borderRadius','boxSizing','boxShadow','backgroundColor','backgroundImage','backgroundSize','backgroundPosition','backgroundClip','overflow','overflowX','overflowY','clipPath','zIndex','opacity','transform','transformOrigin','perspective','filter','mixBlendMode','isolation','willChange','contain','fontFamily','fontSize','fontWeight','fontStyle','fontKerning','fontFeatureSettings','fontVariationSettings','lineHeight','letterSpacing','textRendering','textAlign','direction','unicodeBidi','color','transitionProperty','transitionDuration','transitionDelay','animationName','animationDuration','animationDelay','animationFillMode','animationPlayState','zoom'];
 const styles=(e,pseudo)=>{const c=getComputedStyle(e,pseudo);return Object.fromEntries(properties.map(k=>[k,/url\(/i.test(c[k])?'url(redacted)':c[k]]));};
 const selector=e=>{
  for(const s of names)if(e.matches(s))return s;
  if(providers.includes(e.dataset?.provider))return '[data-provider="'+e.dataset.provider+'"]';
  const parts=[];for(let n=e;n&&parts.length<6;n=n.parentElement){const tag=n.tagName.toLowerCase();
   if(!/^(html|body|div|h1|h2|p|span|a|img|button|section|svg|small)$/.test(tag))break;
   const siblings=n.parentElement?[...n.parentElement.children].filter(c=>c.tagName===n.tagName):[n];parts.unshift(tag+':nth-of-type('+(siblings.indexOf(n)+1)+')');}
  return parts.join('>');
 };
 const textBounds=e=>{const range=document.createRange();range.selectNodeContents(e);return [...range.getClientRects()].slice(0,32).map(r=>[r.x,r.y,r.width,r.height]);};
 const describe=e=>({tag:['HTML','BODY','DIV','H1','H2','P','SPAN','A','IMG','BUTTON','SECTION','SVG','SMALL'].includes(e.tagName)?e.tagName:'OTHER',selector:selector(e),bounds:rect(e),
  text_rects:textBounds(e).map(bounds=>({bounds})),client_width:e.clientWidth,client_height:e.clientHeight,offset_width:e.offsetWidth,offset_height:e.offsetHeight,
  offset_left:e.offsetLeft,offset_top:e.offsetTop,parent_bounds:e.parentElement?rect(e.parentElement):[],containing_bounds:e.offsetParent?rect(e.offsetParent):[],
  class_hash:hash(e.className?.toString()||''),id_hash:hash(e.id||''),text_hash:hash(e.textContent||''),computed:styles(e),before:styles(e,'::before'),after:styles(e,'::after')});
 const selected=[...names.map(s=>document.querySelector(s)),...document.querySelectorAll('[data-provider]')].filter(Boolean);
 const elements=selected.slice(0,32).map(describe),x=POINT_X,y=POINT_Y,hit=document.elementFromPoint(x,y);
 const ancestry=[];for(let e=hit;e&&ancestry.length<12;e=e.parentElement)ancestry.push(describe(e));
 const navigation=performance.getEntriesByType('navigation')[0];
 const covering=[...document.elementsFromPoint(x,y)].slice(0,12).map(describe);
 const config=window.ProxoLink?.getConfig()||{},fields=['template','lang','direction','name','bio','avatarUrl','preview','videoUrl','buttons','intents'];
 const inputs=fields.map(field=>({field,value_hash:hash(JSON.stringify(config[field])??'undefined')}));
 const buttons=[...document.querySelectorAll('[data-provider]')].map(e=>({provider:providers.includes(e.dataset.provider)?e.dataset.provider:'other',href_hash:hash(e.getAttribute('href')||''),bounds:rect(e)}));
 const resources=performance.getEntriesByType('resource').slice(0,32).map(r=>({identity_hash:hash(r.name),start_ms:r.startTime,duration_ms:r.duration,response_ms:r.responseStart,response_end_ms:r.responseEnd,transfer_size:r.transferSize,encoded_size:r.encodedBodySize,decoded_size:r.decodedBodySize,response_status:r.responseStatus||0,initiator_hash:hash(r.initiatorType)}));
 const images=[...document.images].slice(0,32).map(e=>({selector:selector(e),identity_hash:hash(e.currentSrc||e.src),complete:e.complete,natural_width:e.naturalWidth,natural_height:e.naturalHeight,client_width:e.clientWidth,client_height:e.clientHeight,bounds:rect(e)}));
 const fonts=[...document.fonts].slice(0,16).map(f=>({loaded:f.status==='loaded',family_hash:hash(f.family),style_hash:hash(f.style),weight_hash:hash(f.weight)}));
 return JSON.stringify({time_origin:performance.timeOrigin,now_ms:performance.now(),dpr:devicePixelRatio,
  navigation:navigation?{start_ms:navigation.startTime,response_ms:navigation.responseStart,dom_complete_ms:navigation.domComplete,load_end_ms:navigation.loadEventEnd,type_hash:hash(navigation.type)}:{},
  animation_barrier:window.__nativeAnimationBarrier||{},ancestry,covering,elements,
  elements_truncated:selected.length>32,resources_truncated:performance.getEntriesByType('resource').length>32,
  resources,images,fonts,inputs,buttons,config_hash:hash(JSON.stringify(config)),
  html_hash:hash(document.documentElement.outerHTML),config_source_hash:hash(document.getElementById('proxo-config')?.textContent||''),
  document_bounds:rect(document.documentElement),body_bounds:rect(document.body),
  client_width:document.documentElement.clientWidth,client_height:document.documentElement.clientHeight,
  screen_width:screen.width,screen_height:screen.height,screen_color_depth:screen.colorDepth,screen_pixel_depth:screen.pixelDepth,
  inner_width:innerWidth,inner_height:innerHeight,scroll_x:scrollX,scroll_y:scrollY,
  scroll_width:document.documentElement.scrollWidth,scroll_height:document.documentElement.scrollHeight,
  visual_viewport:visualViewport?[visualViewport.offsetLeft,visualViewport.offsetTop,visualViewport.width,visualViewport.height,visualViewport.scale]:[],
  hit_bounds:hit?rect(hit):[],hit_style_hash:hit?hash(JSON.stringify(properties.map(k=>getComputedStyle(hit)[k]))):0,
  fonts_ready:document.fonts.status==='loaded',images_ready:[...document.images].every(e=>e.complete&&e.naturalWidth>0),
  fonts_hash:hash(JSON.stringify([...document.fonts].map(f=>[f.family,f.style,f.weight,f.status]))),
  css_hash:hash([...document.querySelectorAll('style')].map(e=>e.textContent).join('\n')),
  animations:document.getAnimations().slice(0,16).map(a=>({time:Number(a.currentTime)||0,play_state_hash:hash(a.playState),end:Number.isFinite(a.effect.getComputedTiming().endTime)?a.effect.getComputedTiming().endTime:-1})),
  visibility:document.visibilityState==='visible',document_complete:document.readyState==='complete'});
})()
'''.replaceAll('POINT_X','${point[0]}').replaceAll('POINT_Y','${point[1]}');
