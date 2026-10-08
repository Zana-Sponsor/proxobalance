// Read-only observations. No CSS, assets, animation state or rendering settings change.
const nativeDiagnosticPoints = <String,List<int>>{
 'pill-contact-en-portrait-768':[380,222],
 'pill-order-ku-portrait-768':[380,222],
 'pill-order-en-portrait-768':[380,222],
 'pill-mint-contact-ku-portrait-430':[282,184],
 'pill-mint-order-ku-portrait-430':[282,184],
 'pill-mint-order-en-portrait-768':[290,228],
};
String nativeDiagnosticScript(List<int> point) => r'''
(()=>{
 const hash=s=>{let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;};
 const rect=e=>{const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height];};
 const names=['.wrap','.aura','.av','.profile','.uname','.ubio','.btns'];
 const properties=['fontFamily','fontSize','fontWeight','lineHeight','letterSpacing','color','backgroundColor','backgroundImage','opacity','transform','filter','mixBlendMode','isolation','borderRadius','boxShadow','transformOrigin','backgroundSize','backgroundPosition','fontStyle','fontKerning','textRendering','transitionProperty','transitionDuration','transitionDelay','animationName','animationDuration','animationDelay','animationFillMode','animationPlayState','zoom'];
 const styles=(e,pseudo)=>{const c=getComputedStyle(e,pseudo);return Object.fromEntries(properties.map(k=>[k,/url\(/i.test(c[k])?'url(redacted)':c[k]]));};
 const describe=e=>({tag:['HTML','BODY','DIV','H1','P','SPAN','A','IMG','BUTTON','SVG'].includes(e.tagName)?e.tagName:'OTHER',bounds:rect(e),class_hash:hash(e.className?.toString()||''),id_hash:hash(e.id||''),computed:styles(e),before:styles(e,'::before'),after:styles(e,'::after')});
 const elements=names.map(selector=>{const e=document.querySelector(selector);if(!e)return {present:false};const c=getComputedStyle(e);return {present:true,bounds:rect(e),computed:styles(e),before:styles(e,'::before'),after:styles(e,'::after'),style_hash:hash(JSON.stringify(properties.map(k=>c[k]))),text_hash:hash(e.textContent),opacity:Number(c.opacity)};});
 const x=POINT_X,y=POINT_Y,hit=document.elementFromPoint(x,y);
 const ancestry=[];for(let e=hit;e&&ancestry.length<12;e=e.parentElement)ancestry.push(describe(e));
 const navigation=performance.getEntriesByType('navigation')[0];
 const covering=[...document.elementsFromPoint(x,y)].slice(0,12).map(describe);
 return JSON.stringify({time_origin:performance.timeOrigin,now_ms:performance.now(),dpr:devicePixelRatio,
  navigation:navigation?{start_ms:navigation.startTime,response_ms:navigation.responseStart,dom_complete_ms:navigation.domComplete,load_end_ms:navigation.loadEventEnd,type_hash:hash(navigation.type)}:{},
  ancestry,covering,document_bounds:rect(document.documentElement),body_bounds:rect(document.body),
  screen_width:screen.width,screen_height:screen.height,screen_color_depth:screen.colorDepth,screen_pixel_depth:screen.pixelDepth,
  inner_width:innerWidth,inner_height:innerHeight,scroll_x:scrollX,scroll_y:scrollY,
  scroll_width:document.documentElement.scrollWidth,scroll_height:document.documentElement.scrollHeight,
  visual_viewport:visualViewport?[visualViewport.offsetLeft,visualViewport.offsetTop,visualViewport.width,visualViewport.height,visualViewport.scale]:[],
  elements,hit_bounds:hit?rect(hit):[],hit_style_hash:hit?hash(JSON.stringify(properties.map(k=>getComputedStyle(hit)[k]))):0,
  fonts_hash:hash(JSON.stringify([...document.fonts].map(f=>[f.family,f.style,f.weight,f.status]))),
  css_hash:hash([...document.querySelectorAll('style')].map(e=>e.textContent).join('\n')),
  animations:document.getAnimations().map(a=>({time:Number(a.currentTime)||0,play_state_hash:hash(a.playState),end:Number.isFinite(a.effect.getComputedTiming().endTime)?a.effect.getComputedTiming().endTime:-1})),
  visibility:document.visibilityState==='visible',document_complete:document.readyState==='complete'});
})()
'''.replaceAll('POINT_X','${point[0]}').replaceAll('POINT_Y','${point[1]}');
