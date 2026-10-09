// Debug-only observations after the FIRST three acceptance frames. CDP is used
// against the existing Android WebView, never Chromium or an alternative render.
import {createHash} from 'node:crypto';
export const digest=value=>createHash('sha256').update(value).digest('hex');
// Only hashes/lengths leave this function. Empty cached CDP bodies are not
// source-identity evidence; the live DOM is observed separately after captures.
export function sourceIdentity(html){
 if(typeof html!=='string'||Buffer.byteLength(html)>16*1024*1024)throw Error('native_pipeline_invalid');
 if(!html.length)return {status:'unavailable',reason:'empty_document'};
 const styles=[...html.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi)].map(x=>x[1]);
 if(styles.length>64)throw Error('native_pipeline_invalid');
 const css=styles.join('\n'),embedded=[...css.matchAll(/url\(["']?(data:[^)'"\s]+)["']?\)/gi)];
 if(embedded.length>64)throw Error('native_pipeline_invalid');
 return {status:'captured',html_sha256:digest(html),html_bytes:Buffer.byteLength(html),
  style_count:styles.length,css_sha256:styles.length?digest(css):null,css_bytes:Buffer.byteLength(css),
  embedded:embedded.map(([_,value])=>{
   const split=value.indexOf(','),header=value.slice(0,split),payload=value.slice(split+1);
   const bytes=/;base64$/i.test(header)?Buffer.from(payload,'base64'):Buffer.from(decodeURIComponent(payload));
   return {kind:/^data:(?:font\/|application\/(?:font|x-font|vnd.ms-fontobject))/i.test(header)?'font':'other',
    identity_sha256:digest(value),body_sha256:digest(bytes),body_bytes:bytes.length};
  })};
}
const providers=['whatsapp','viber','instagram','telegram','korek','asiacell','talabat','toters','lezzoo','wade','app_store','google_play'];
const fields=['template','lang','direction','name','bio','avatarUrl','preview','videoUrl','buttons','intents'];
export function inputHashes(config){
 return {sha256:digest(JSON.stringify(config)),fields:fields.map(field=>({field,sha256:digest(JSON.stringify(config?.[field])??'undefined')}))};
}
export function inputDifferences(a,b){
 const effects={template:['css_classes'],lang:['text','direction'],direction:['direction','geometry'],name:['text','geometry','avatar_fallback'],bio:['text','geometry'],avatarUrl:['resource_selection'],preview:['navigation','provider_count'],videoUrl:['text','navigation'],buttons:['text','navigation','provider_count','geometry'],intents:['dialog_text','navigation']};
 return fields.filter(field=>a?.fields.find(x=>x.field===field)?.sha256!==b?.fields.find(x=>x.field===field)?.sha256)
  .map(field=>({field,possible_effects:effects[field],causal_effect_proven:false}));
}
export function resourceIdentity(url){
 const parsed=new URL(url);
 const kind=parsed.protocol==='data:'?'embedded':parsed.pathname.endsWith('/avatar')?'avatar':/\.(woff2?|ttf|otf)$/.test(parsed.pathname)?'font':/\.(png|jpe?g|svg|webp)$/.test(parsed.pathname)?'image':parsed.pathname==='/contact-preview'?'document':'other';
 return {kind,identity_sha256:digest(url),path_sha256:digest(parsed.pathname),query_count:[...parsed.searchParams].length};
}
export function safeLayers(layers){
 if(!Array.isArray(layers)||layers.length>128)throw Error('native_pipeline_invalid');
 return layers.map((layer,index)=>{
  const out={index};
  for(const key of ['offsetX','offsetY','width','height','paintCount','backendNodeId'])if(Number.isFinite(layer[key]))out[key]=layer[key];
  for(const key of ['drawsContent','invisible','isRoot'])if(typeof layer[key]==='boolean')out[key]=layer[key];
  if(layer.transform){if(layer.transform.length!==16||!layer.transform.every(Number.isFinite))throw Error('native_pipeline_invalid');out.transform=layer.transform;}
  out.parent_index=layers.findIndex(x=>x.layerId===layer.parentLayerId);
  return out;
 });
}
const bounds=value=>Object.fromEntries(['x','y','width','height','pageX','pageY','clientWidth','clientHeight','offsetX','offsetY','scale','zoom'].filter(k=>Number.isFinite(value?.[k])).map(k=>[k,value[k]]));
class Session{
 constructor(socket,deadline){this.socket=socket;this.deadline=deadline;this.next=0;this.pending=new Map();this.layers=[];
  socket.addEventListener('message',event=>{let data;try{data=JSON.parse(event.data);}catch{return;}
   if(data.method==='LayerTree.layerTreeDidChange')this.layers=data.params?.layers||[];
   const waiting=this.pending.get(data.id);if(waiting){clearTimeout(waiting.timer);this.pending.delete(data.id);data.error?waiting.reject(Error('native_pipeline_protocol')):waiting.resolve(data.result);}
  });
 }
 send(method,params={},timeout=10000){
 if(Date.now()>=this.deadline)return Promise.reject(Error('native_pipeline_timeout'));
 timeout=Math.min(timeout,this.deadline-Date.now());return new Promise((resolve,reject)=>{const id=++this.next;
  const timer=setTimeout(()=>{this.pending.delete(id);reject(Error('native_pipeline_timeout'));},timeout);
  this.pending.set(id,{resolve,reject,timer});this.socket.send(JSON.stringify({id,method,params}));
 });}
 close(){for(const waiter of this.pending.values()){clearTimeout(waiter.timer);waiter.reject(Error('native_pipeline_closed'));}this.pending.clear();this.socket.close();}
}
async function connect(url,deadline){
 const parsed=new URL(url);if(parsed.protocol!=='ws:'||parsed.hostname!=='127.0.0.1')throw Error('native_pipeline_invalid');
 const socket=new WebSocket(url);
 await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{socket.close();reject(Error('native_pipeline_timeout'));},Math.min(3000,Math.max(1,deadline-Date.now())));
  socket.addEventListener('open',()=>{clearTimeout(timer);resolve();},{once:true});socket.addEventListener('error',()=>{clearTimeout(timer);reject(Error('native_pipeline_unavailable'));},{once:true});});
 return new Session(socket,deadline);
}
// The active page is identified by a debug-only nonvisual capture marker, never
// by printing or retaining a signed preview URL. No runtime/network settings change.
export async function readNativePipeline(adb,packageId,captureId){
 let port,session;
 const deadline=Date.now()+25000;
 const started_ms=Number(process.hrtime.bigint())/1e6;
 try{
  const pid=adb(['shell','pidof',packageId]).toString().trim();if(!/^\d+$/.test(pid))throw Error('native_pipeline_unavailable');
  port=adb(['forward','tcp:0','localabstract:webview_devtools_remote_'+pid]).toString().trim();if(!/^\d+$/.test(port))throw Error('native_pipeline_invalid');
  const endpoint='http://127.0.0.1:'+port;
  const response=await fetch(endpoint+'/json/list',{signal:AbortSignal.timeout(10000),redirect:'error'});
  if(!response.ok)throw Error('native_pipeline_unavailable');
  const targets=await response.json();
  for(const target of targets.slice(0,32)){
   if(Date.now()>=deadline)throw Error('native_pipeline_timeout');
   if(!target.webSocketDebuggerUrl)continue;
   const url=new URL(target.webSocketDebuggerUrl);url.hostname='127.0.0.1';url.port=port;
   const candidate=await connect(url.href,deadline);
   try{
    const identity=await candidate.send('Runtime.evaluate',{expression:'window.__nativeCaptureIdentity',returnByValue:true});
    if(identity.result?.value===captureId){session=candidate;break;}
   }finally{if(session!==candidate)candidate.close();}
  }
  if(!session)throw Error('native_pipeline_unavailable');
  await session.send('Page.enable');
  let layer_error=null;
  try{await session.send('LayerTree.enable');}catch{layer_error='unsupported';}
  const metrics=await session.send('Page.getLayoutMetrics');
  // One predetermined WebContents compositor readback, after all acceptance
  // captures. This is not a raw Skia tile and does not prove GPU causality.
  const screenshot=await session.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
  if(typeof screenshot.data!=='string'||screenshot.data.length>16*1024*1024)throw Error('native_pipeline_invalid');
  const png=Buffer.from(screenshot.data,'base64');
  const resources=[],tree=await session.send('Page.getResourceTree');
  const entries=[{url:tree.frameTree.frame.url,type:'Document'},...(tree.frameTree.resources||[])];
  let source=null;
  let resources_truncated=entries.length>40;
  const resourceDeadline=Date.now()+20000;
  for(const item of entries.slice(0,40)){
   if(Date.now()>resourceDeadline){resources_truncated=true;break;}
   const entry={...resourceIdentity(item.url),type:['Document','Image','Font','Stylesheet','Script'].includes(item.type)?item.type:'Other'};
   try{
    const result=await session.send('Page.getResourceContent',{frameId:tree.frameTree.frame.id,url:item.url},1500);
    const body=Buffer.from(result.content,result.base64Encoded?'base64':'utf8');
    entry.body_sha256=digest(body);entry.body_bytes=body.length;
    if(item.type==='Document'){
     const html=body.toString('utf8'),payload=html.match(/<script[^>]*id=["']proxo-config["'][^>]*>([\s\S]*?)<\/script>/i)?.[1];
     source={...sourceIdentity(html),inputs:payload?inputHashes(JSON.parse(payload)):null};
    }
   }catch{entry.body_unavailable=true;}
   resources.push(entry);
  }
  const dom=await session.send('Runtime.evaluate',{expression:'JSON.stringify({html:document.documentElement.outerHTML,config:window.ProxoLink.getConfig(),buttons:[...document.querySelectorAll("[data-provider]")].map(e=>({provider:e.dataset.provider,href:e.getAttribute("href")}))})',returnByValue:true});
  const state=JSON.parse(dom.result.value);
  const buttons=state.buttons.filter(x=>providers.includes(x.provider)).map(x=>({provider:x.provider,href_sha256:digest(x.href||'')}));
  const metadata={status:'captured',started_ms,completed_ms:Number(process.hrtime.bigint())/1e6,
   scope:'Android WebView WebContents compositor surface after acceptance; no raw GPU/Skia tile or presentation fence',
   layout:{css_layout_viewport:bounds(metrics.cssLayoutViewport),css_visual_viewport:bounds(metrics.cssVisualViewport),css_content_size:bounds(metrics.cssContentSize)},
   layers:safeLayers(session.layers),layers_received:session.layers.length>0,layer_error:layer_error||(!session.layers.length?'not_observed':null),resources,resources_truncated,source,
   live_source:{...sourceIdentity(state.html),scope:'Live DOM after acceptance frames; not a capture-time source or causal rendering proof'},
   dom_sha256:digest(state.html),inputs:inputHashes(state.config),buttons};
  return {png,metadata};
 }catch(error){
  return {metadata:{status:'unavailable',code:['native_pipeline_unavailable','native_pipeline_invalid','native_pipeline_timeout','native_pipeline_protocol'].includes(error.message)?error.message:'native_pipeline_unavailable',started_ms,completed_ms:Number(process.hrtime.bigint())/1e6}};
 }finally{session?.close();if(port)adb(['forward','--remove','tcp:'+port],null,true);}
}
