import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxolink_preview.dart';
import 'proxolink_native_diagnostics.dart';
import 'proxolink_native_chooser.dart';

const _styles=['pill','pill-mint','pill-dark','pill-white'];
const _types=['contact','order','download'];
const _languages=['ku','en'];
const _widths=[320,375,393,430,768];
const _orientations=['portrait','landscape'];
const _nativeCapture=MethodChannel('proxo/native-capture');
final _cases=[for(final style in _styles)for(final type in _types)for(final language in _languages)
  for(final orientation in _orientations)for(final width in _widths) {'style':style,'type':type,'language':language,'orientation':orientation,'width':width}];
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
 int _index=0;bool _baseline=false,_behavior=true,_complete=false,_chooser=false;
 WebViewController? _behaviorController,_candidateCaptureController;
 Map<String,String> _headers={};
 String get _id {final c=_cases[_index.clamp(0,_cases.length-1)];return '${c['style']}-${c['type']}-${c['language']}-${c['orientation']}-${c['width']}';}
 @override void initState(){super.initState();_configure();}
 Future<void> _configure() async {final config=await _configuration();if(mounted)setState(()=>_headers=Map<String,String>.from(config['headers'] as Map));}
 Future<void> _write(String file,Object value) async {
  final temporary=File('${_files.path}/$file.next');
  await temporary.writeAsString(jsonEncode(value),flush:true);
  await temporary.rename('${_files.path}/$file');
 }
 Future<void> _verify(WebViewController controller) async {
  final id=_id,baseline=_baseline,behavior=_behavior,c=_cases[_index];Map<String,dynamic>? state;
  final instrument=!behavior&&nativeDiagnosticPoints.containsKey(id);
  final lifecycle=Stopwatch()..start();
  final lifecycleTimes=<String,dynamic>{};
  final actionDiagnostics=<String,dynamic>{};
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
   if(behavior){
    _behaviorController=controller;
    // Observe the original entrance animations from one fresh render. Keep
    // their references so an animation finishing during the sample is still
    // measured, rather than disappearing from document.getAnimations().
    await controller.runJavaScript('window.ProxoLink.setConfig(window.ProxoLink.getConfig());window.__probeAnimations=document.getAnimations();');
    final times=(await _read(controller,'JSON.stringify({times:window.__probeAnimations.map(a=>Number(a.currentTime)||0)})'))['times'] as List;
    if(c['type']!='download'&&times.isEmpty)throw StateError('animation_motion');
    if(times.isNotEmpty){
     await Future<void>.delayed(const Duration(milliseconds:150));
     final later=(await _read(controller,'JSON.stringify({times:window.__probeAnimations.map(a=>Number(a.currentTime)||0)})'))['times'] as List;
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
 const legacy_viber_url_parser=config.buttons.some(b=>b.type==='viber'&&new URL(b.url).hostname==='');
 const expected=new Map(config.buttons.filter(b=>b.enabled!==false).map(b=>[b.type,b.url]));
 const valid=opened.length===expected.size&&new Set(opened.map(a=>a.provider)).size===expected.size&&opened.every(a=>expected.get(a.provider)===a.url);
 const matches=Object.fromEntries([...expected].map(([provider,url])=>[provider+'_destination_match',opened.filter(a=>a.provider===provider).length===1&&opened.find(a=>a.provider===provider)?.url===url]));
 window.ProxoLink.setConfig(config);return JSON.stringify({valid,legacy_viber_url_parser,expected_count:expected.size,observed_count:opened.length,...matches});})()
''');
    actionDiagnostics.addAll(publicActions);
    actionDiagnostics['public_url_unchanged']=await controller.currentUrl()==before;
    if(publicActions['valid']!=true)throw StateError('public_actions');
    if(actionDiagnostics['public_url_unchanged']!=true)throw StateError('public_navigation');
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
     'provider_types':true,'preview_inert':true,'public_actions_checked':publicActions['valid'],'legacy_viber_url_parser':publicActions['legacy_viber_url_parser'],'navigation_blocked':true};
    // A document reload retains the native WebView/compositor that performed
    // the interactions. Retire that view before either parity capture. Both
    // capture roles now create the same production widget from a fresh view,
    // with identical initial-load/reload/settle history and no action tests.
    if(mounted)setState(()=>_behavior=false);
    return;
   }
   if(identical(controller,_behaviorController)
     ||(baseline&&identical(controller,_candidateCaptureController)))throw StateError('fresh_native_view');
   if(!baseline)_candidateCaptureController=controller;
   if(instrument)lifecycleTimes['initial_ready_ms']=lifecycle.elapsedMicroseconds/1000;
   // Both newly created views reload once and use the same settled state.
   final previousFrame=await _read(controller,'JSON.stringify({time:performance.timeOrigin})');
   final captureUrl=await controller.currentUrl();
   if(captureUrl==null)throw StateError('fresh_frame');
   await controller.loadRequest(Uri.parse(captureUrl),headers:_headers);
   var fresh=false;
   for(var i=0;i<120;i++){
    await Future<void>.delayed(const Duration(milliseconds:100));
    try{
     final frame=await _read(controller,'JSON.stringify({time:performance.timeOrigin})');
     final loaded=await _state(controller);
     if(frame['time']!=previousFrame['time']&&loaded['ready']==true&&loaded['fonts']==true
       &&loaded['images']==true&&loaded['icons']==true
       &&jsonEncode(loaded['providers'])==jsonEncode(expectedProviders)){fresh=true;break;}
    }catch(_){}
   }
   if(!fresh)throw StateError('fresh_frame');
   if(instrument)lifecycleTimes['reload_ready_ms']=lifecycle.elapsedMicroseconds/1000;
   // Capture the same fully entered state of the original CSS on both
   // documents. Freezing an in-flight entrance at zero hides its buttons,
   // while a completed backwards-fill entrance is already fully visible.
   await controller.runJavaScript('window.scrollTo(0,0);document.getAnimations().forEach(a=>{if(Number.isFinite(a.effect.getComputedTiming().endTime)){a.finish();}else{a.pause();a.currentTime=0;}});const toast=document.getElementById("toast");toast.hidden=true;document.querySelectorAll(".wa-message-card").forEach(e=>{e.hidden=true;new MutationObserver(()=>{if(!e.hidden)e.hidden=true;}).observe(e,{attributes:true,attributeFilter:["hidden"]});});');
   // Android briefly paints its native scrollbar after a new document loads.
   // Use the same settled interval for both captures, without masking pixels
   // or changing the original page CSS, assets, geometry or acceptance limit.
   await Future<void>.delayed(const Duration(seconds:2));
   final capture=await _read(controller,'JSON.stringify({visible:Array.from(document.querySelectorAll("[data-provider]")).every(e=>Number(getComputedStyle(e).opacity)===1&&e.getBoundingClientRect().width>0),hintHidden:Array.from(document.querySelectorAll(".wa-message-card")).every(e=>e.hidden),toastHidden:document.getElementById("toast").hidden})');
   if(capture['visible']!=true||capture['hintHidden']!=true||capture['toastHidden']!=true)throw StateError('capture_visibility');
   // DOM readiness and a delay do not acknowledge Android's asynchronous
   // raster/draw. Wait for the real native view before publishing capture-ready.
   final platform=controller.platform;
   if(platform is! AndroidWebViewController)throw StateError('native_paint_barrier');
   bool? drawn;
   try{drawn=await _nativeCapture.invokeMethod<bool>('awaitDraw',
     {'webViewIdentifier':platform.webViewIdentifier,'diagnostics':instrument});}
   catch(_){throw StateError('native_paint_barrier');}
   if(drawn!=true)throw StateError('native_paint_barrier');
   final diagnostic=<String,dynamic>{};
   if(instrument){
    lifecycleTimes['barrier_return_ms']=lifecycle.elapsedMicroseconds/1000;
    diagnostic['lifecycle']=lifecycleTimes;
    diagnostic['dom']=await _read(controller,nativeDiagnosticScript(nativeDiagnosticPoints[id]!));
    diagnostic['native']=await _nativeCapture.invokeMapMethod<String,dynamic>('diagnostics',{'webViewIdentifier':platform.webViewIdentifier});
   }
   if(!mounted)return;
   final box=_viewport.currentContext!.findRenderObject()! as RenderBox,origin=box.localToGlobal(Offset.zero);
   if(MediaQuery.devicePixelRatioOf(context)!=1)throw StateError('pixel_density');
   final captureId='$id-${baseline?'baseline':'candidate'}';
   await _write('proxolink-verification-case.json',{'id':id,'capture_id':captureId,'style':c['style'],'type':c['type'],'language':c['language'],'width':c['width'],
    'variant':baseline?'baseline':'candidate','orientation':c['orientation'],
    if(instrument)'diagnostics':{...diagnostic,'flutter_bounds':[origin.dx,origin.dy,box.size.width,box.size.height]},
    'viewport':{'left':origin.dx.floor(),'top':origin.dy.floor(),'width':box.size.width.round(),'height':box.size.height.round(),'css_height':box.size.height.round()}});
   final ack=File('${_files.path}/proxolink-verification-ack');var seen=false;
   var surfaceCaptured=false;
   for(var i=0;i<240;i++){
    if(instrument&&!surfaceCaptured){
     final request=File('${_files.path}/proxolink-diagnostic-request');
     if(await request.exists()&&(await request.readAsString()).trim()==captureId){
      surfaceCaptured=true;
      final surface=await _nativeCapture.invokeMapMethod<String,dynamic>('captureSurface');
      final after={'dom':await _read(controller,nativeDiagnosticScript(nativeDiagnosticPoints[id]!)),
       'native':await _nativeCapture.invokeMapMethod<String,dynamic>('diagnostics',{'webViewIdentifier':platform.webViewIdentifier}),
       'flutter_bounds':[origin.dx,origin.dy,box.size.width,box.size.height]};
      await _write('proxolink-diagnostic-surface.json',{'id':captureId,'surface':surface,'state_after':after});
     }
    }
    if(await ack.exists()&&(await ack.readAsString()).trim()==captureId){seen=true;await ack.delete();break;}
    await Future<void>.delayed(const Duration(milliseconds:250));
   }
   if(!seen)throw StateError('screenshot_ack');
   if(baseline)_results[id]={'passed':true,..._candidateChecks[id]!,'fresh_native_views':true,'native_paint_barriers':true};
  }catch(error){
   _results[id]={'passed':false,'failed_check':error is StateError?error.message:'unclassified_native_check',
    'width':state?['width'],'font_loaded':state?['fonts'],'font_applied':state?['fontApplied'],'images_loaded':state?['images'],'icons_loaded':state?['icons'],...actionDiagnostics};
  }
  if(!mounted)return;
  if(!baseline&&!_results.containsKey(id)){setState(()=>_baseline=true);return;}
  await _write('proxolink-verification-progress.json',_results);
  if(_index+1==_cases.length){setState(()=>_chooser=true);}
  else setState((){_index++;_baseline=false;_behavior=true;_behaviorController=null;_candidateCaptureController=null;});
 }
 @override Widget build(BuildContext context){
  if(_chooser)return NativeProxoLinkChooser(
   configuration:_configuration,write:_write,
   onComplete:()async {await _write('proxolink-verification-results.json',_results);if(mounted)setState((){_chooser=false;_complete=true;});},
  );
  final c=_cases[_index];
  return Scaffold(backgroundColor:AppColors.page,appBar:AppBar(title:const Text('ProxoLink')),body:SafeArea(child:Center(
   child:SizedBox(width:(c['width'] as int).toDouble(),height:c['orientation']=='landscape'?(c['width'] as int)*.6:MediaQuery.sizeOf(context).height*.80,
    child:SizedBox(key:_viewport,child:_complete?Text('${_cases.length} native cases completed'):_headers.isEmpty?const CircularProgressIndicator():ProxoLinkPreview(
     key:ValueKey('$_id/$_baseline/$_behavior'),requestHeaders:_headers,
     loadUrl:()async {final r=await _configuration();return Uri.parse((r['previews'] as Map)['${c['style']}-${c['type']}-${c['language']}${_baseline?'-baseline':''}'] as String);},
     onControllerCreated:_verify,
    )),
   ),
  )));
 }
}

