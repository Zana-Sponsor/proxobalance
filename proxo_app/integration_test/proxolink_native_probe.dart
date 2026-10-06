import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';

const _styles=['pill','pill-mint','pill-dark','pill-white'];
const _types=['contact','order','download'];
const _languages=['ku','en'];
const _widths=[320,375,393,430,768];
final _cases=[for(final style in _styles)for(final type in _types)for(final language in _languages)
  for(final width in _widths) {'style':style,'type':type,'language':language,'width':width}];
Directory get _files=>Directory('${Directory.systemTemp.parent.path}/files');
Future<Map<String,dynamic>> _configuration() async => Map<String,dynamic>.from(
  jsonDecode(await File('${_files.path}/proxolink-verification.json').readAsString()) as Map);
Future<Map<String,dynamic>> _read(WebViewController c,String js) async {
  final raw=await c.runJavaScriptReturningResult(js);
  dynamic value=raw is String?jsonDecode(raw):raw;
  if(value is String)value=jsonDecode(value);
  return Map<String,dynamic>.from(value as Map);
}
Future<Map<String,dynamic>> _state(WebViewController c)=>_read(c,r'''
JSON.stringify({ready:document.readyState==='complete',width:innerWidth,scroll:document.documentElement.scrollWidth,
 language:document.documentElement.lang,direction:document.documentElement.dir,
 fonts:Array.from(document.fonts).some(f=>/Bahij/.test(f.family)&&f.status==='loaded'),
 fontApplied:/Bahij/.test(getComputedStyle(document.body).fontFamily),
 images:Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0),
 icons:Array.from(document.querySelectorAll('.provider-glyph')).every(e=>/Proxo/.test(getComputedStyle(e).fontFamily))&&
   Array.from(document.querySelectorAll('.pl-ic')).every(e=>!!e.firstElementChild),
 providers:Array.from(document.querySelectorAll('[data-provider]')).map(e=>e.dataset.provider),
 pixel:typeof window.ttq!=='undefined',placeholders:document.body.textContent.includes('{{PROXO_CONFIG}}'),
 motion:Array.from(document.querySelectorAll('[data-provider]')).every(e=>getComputedStyle(e).transitionDuration.split(',').some(t=>parseFloat(t)>0)),
 animations:document.getAnimations().map(a=>Number(a.currentTime)||0),
 waVisible:!!document.querySelector('.wa-message-card:not([hidden])')})
''');
Future<void> main() async {WidgetsFlutterBinding.ensureInitialized();runApp(const _ProbeApp());}
class _ProbeApp extends StatelessWidget {
 const _ProbeApp();
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,theme:buildAppTheme(),home:const _Probe());
}
class _Probe extends StatefulWidget {
 const _Probe();
 @override State<_Probe> createState()=>_ProbeState();
}
class _ProbeState extends State<_Probe> {
 final _viewport=GlobalKey(),_results=<String,dynamic>{},_candidateChecks=<String,Map<String,dynamic>>{};
 int _index=0;bool _baseline=false,_complete=false;
 Map<String,String> _headers={};
 String get _id {final c=_cases[_index.clamp(0,_cases.length-1)];return '${c['style']}-${c['type']}-${c['language']}-${c['width']}';}
 @override void initState(){super.initState();_configure();}
 Future<void> _configure() async {final config=await _configuration();if(mounted)setState(()=>_headers=Map<String,String>.from(config['headers'] as Map));}
 Future<void> _write(String file,Object value) async {await File('${_files.path}/$file').writeAsString(jsonEncode(value));}
 Future<void> _verify(WebViewController controller) async {
  final id=_id,baseline=_baseline,c=_cases[_index];Map<String,dynamic>? state;
  try {
   for(var i=0;i<120;i++){
    await Future<void>.delayed(const Duration(milliseconds:100));
    try{state=await _state(controller);if(state['ready']==true&&state['fonts']==true&&state['images']==true)break;}catch(_){}
   }
   final expectedProviders=switch(c['type']) {
    'contact'=>['whatsapp','viber','instagram','telegram','korek','asiacell'],
    'order'=>['talabat','toters','lezzoo','wade'],_=>['app_store','google_play'],
   };
   if(state==null||state['ready']!=true||state['fonts']!=true||state['fontApplied']!=true||state['images']!=true||state['icons']!=true
    ||state['language']!=c['language']||state['direction']!=(c['language']=='en'?'ltr':'rtl')||state['pixel']!=false||state['placeholders']!=false
    ||(state['scroll'] as num)>(state['width'] as num)+1||((state['width'] as num)-(c['width'] as int)).abs()>1
    ||jsonEncode(state['providers'])!=jsonEncode(expectedProviders)||state['motion']!=true)throw StateError('rendered_page_checks');
   if(!baseline){
    final times=state['animations'] as List;
    if(times.isNotEmpty){
     await Future<void>.delayed(const Duration(milliseconds:150));
     final later=(await _state(controller))['animations'] as List;
     if(!List.generate(times.length,(i)=>i).any((i)=>i<later.length&&(later[i] as num)>(times[i] as num)))throw StateError('animation_motion');
    }
    final before=await controller.currentUrl();
    await controller.runJavaScript('window.__probeOpened=0;window.open=function(){window.__probeOpened++;};document.querySelectorAll("[data-provider]").forEach(e=>e.click());');
    await Future<void>.delayed(const Duration(milliseconds:200));
    final inert=await _read(controller,'JSON.stringify({inert:window.__probeOpened===0,dialog:!document.getElementById("intent-dialog").open})');
    if(inert['inert']!=true||inert['dialog']!=true||await controller.currentUrl()!=before)throw StateError('preview_actions');
    final publicActions=await _read(controller,r'''
(()=>{const config=window.ProxoLink.getConfig(),opened=[];
 window.__PROXO_INTERCEPT_NAVIGATION__=true;
 window.addEventListener('proxo:navigate',e=>{opened.push(e.detail);e.preventDefault();});
 window.ProxoLink.setConfig({...config,preview:false});
 document.querySelectorAll('[data-provider]').forEach(e=>e.click());
 const valid=opened.length===config.buttons.length&&opened.every((a,i)=>a.provider===config.buttons[i].type&&a.url===config.buttons[i].url);
 window.ProxoLink.setConfig(config);return JSON.stringify({valid});})()
''');
    if(publicActions['valid']!=true||await controller.currentUrl()!=before)throw StateError('public_actions');
    final configuration=await _configuration();
    for(final url in ['https://example.invalid/','${configuration['origin']}/api/contact-templates','${configuration['origin']}/page-preview?token=invalid','file:///etc/passwd']){
     await controller.runJavaScript('location.href=${jsonEncode(url)}');await Future<void>.delayed(const Duration(milliseconds:150));
     if(await controller.currentUrl()!=before)throw StateError('navigation_boundary');
    }
    if(c['type']=='contact'){
     await Future<void>.delayed(const Duration(milliseconds:2200));
     if((await _state(controller))['waVisible']!=true)throw StateError('whatsapp_hint');
    }
    _candidateChecks[id]={'width':state['width'],'font_loaded':state['fonts'],'font_applied':state['fontApplied'],
     'images_loaded':state['images'],'icons_loaded':state['icons'],'animation_checked':true,'animation_count':times.length,
     'provider_types':true,'preview_inert':true,'public_actions_checked':publicActions['valid'],'navigation_blocked':true};
   }
   // Same WebView/device/DPR and frozen original CSS on both documents.
   await controller.runJavaScript('window.scrollTo(0,0);document.getAnimations().forEach(a=>{a.pause();a.currentTime=0;});const toast=document.getElementById("toast");toast.hidden=true;document.querySelectorAll(".wa-message-card").forEach(e=>{e.hidden=true;new MutationObserver(()=>{if(!e.hidden)e.hidden=true;}).observe(e,{attributes:true,attributeFilter:["hidden"]});});');
   await Future<void>.delayed(const Duration(milliseconds:150));
   if(!mounted)return;
   final box=_viewport.currentContext!.findRenderObject()! as RenderBox,origin=box.localToGlobal(Offset.zero);
   if(MediaQuery.devicePixelRatioOf(context)!=1)throw StateError('pixel_density');
   final captureId='$id-${baseline?'baseline':'candidate'}';
   await _write('proxolink-verification-case.json',{'id':id,'capture_id':captureId,'style':c['style'],'type':c['type'],'language':c['language'],'width':c['width'],
    'variant':baseline?'baseline':'candidate','viewport':{'left':origin.dx.floor(),'top':origin.dy.floor(),'width':box.size.width.round(),'height':box.size.height.round(),'css_height':box.size.height.round()}});
   final ack=File('${_files.path}/proxolink-verification-ack');var seen=false;
   for(var i=0;i<240;i++){
    if(await ack.exists()&&(await ack.readAsString()).trim()==captureId){seen=true;await ack.delete();break;}
    await Future<void>.delayed(const Duration(milliseconds:250));
   }
   if(!seen)throw StateError('screenshot_ack');
   if(baseline)_results[id]={'passed':true,..._candidateChecks[id]!};
  }catch(error){
   _results[id]={'passed':false,'failed_check':error is StateError?error.message:'unclassified_native_check',
    'width':state?['width'],'font_loaded':state?['fonts'],'font_applied':state?['fontApplied'],'images_loaded':state?['images'],'icons_loaded':state?['icons']};
  }
  if(!mounted)return;
  if(!baseline&&!_results.containsKey(id)){setState(()=>_baseline=true);return;}
  if(_index+1==_cases.length){await _write('proxolink-verification-results.json',_results);setState(()=>_complete=true);}
  else setState((){_index++;_baseline=false;});
 }
 @override Widget build(BuildContext context){
  final c=_cases[_index];
  return Scaffold(backgroundColor:AppColors.page,appBar:AppBar(title:const Text('ProxoLink')),body:SafeArea(child:Center(
   child:SizedBox(width:(c['width'] as int).toDouble(),height:MediaQuery.sizeOf(context).height*.80,
    child:SizedBox(key:_viewport,child:_complete?Text('${_cases.length} native cases completed'):_headers.isEmpty?const CircularProgressIndicator():ProxoLinkPreview(
     key:ValueKey('$_id/$_baseline'),requestHeaders:_headers,
     loadUrl:()async {final r=await _configuration();return Uri.parse((r['previews'] as Map)['${c['style']}-${c['type']}-${c['language']}${_baseline?'-baseline':''}'] as String);},
     onControllerCreated:_verify,
    )),
   ),
  )));
 }
}
