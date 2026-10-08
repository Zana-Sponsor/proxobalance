import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_design.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/widgets/proxolink_design_selector.dart';

// Only the repository boundary is read-only. The real ToolsScreen builder,
// thumbnail onSelected binding and large production WebView are unchanged.
// Capabilities come from the authenticated host catalog, never an HTML asset.
class _ReadOnlyChooserRepository extends ProxoLinkRepository {
 final Future<Map<String,dynamic>> Function() configuration;
 int requests=0;
 String? lastStyle,lastType;
 _ReadOnlyChooserRepository(this.configuration);
 @override Future<List<ProxoCard>> cards()async=>[];
 @override Future<List<ProxoTemplate>> templates()async=>[for(final key in ProxoLinkDesign.labels.keys)
  ProxoTemplate(key:key,label:ProxoLinkDesign.label(key),previewPath:'',version:6,requiresAvatar:false)];
 @override Future<List<ProxoProvider>> providers()async=>[for(final type in ProxoPageType.values)
  for(final key in _providers(type))ProxoProvider(key:key,pageType:type.key,label:key,icon:key,inputKind:'url')];
 @override Future<Uri> formPreview(Map<String,dynamic> data,{ProxoCard? existing})async{
  requests++;lastStyle=data['template_key'] as String;lastType=data['page_kind'] as String;
  final config=await configuration();
  return Uri.parse((config['previews'] as Map)['$lastStyle-$lastType-ku'] as String);
 }
 @override Future<Uri> templatePreview(String key,int version,{String theme='purple',String language='ku',String pageType='contact'})=>throw StateError('chooser_write_boundary');
 @override Future<ProxoCard> save(Map<String,dynamic> data,{ProxoCard? existing})=>throw StateError('chooser_write_boundary');
 @override Future<void> action(String id,String action)=>throw StateError('chooser_write_boundary');
 @override Future<Uri> preview(String id)=>throw StateError('chooser_write_boundary');
 @override Future<String> uploadAvatar(String id,Uint8List bytes)=>throw StateError('chooser_write_boundary');
 @override Uri publicUrl(String id,{String pageType='contact'})=>throw StateError('chooser_write_boundary');
}
List<String> _providers(ProxoPageType type)=>switch(type){
 ProxoPageType.contact=>['whatsapp','viber','instagram','telegram','korek','asiacell'],
 ProxoPageType.order=>['talabat','toters','lezzoo','wade'],ProxoPageType.download=>['app_store','google_play']};
class NativeProxoLinkChooser extends StatefulWidget {
 final Future<Map<String,dynamic>> Function() configuration;
 final Future<void> Function(String,Object) write;
 final Future<void> Function() onComplete;
 const NativeProxoLinkChooser({super.key,required this.configuration,required this.write,required this.onComplete});
 @override State<NativeProxoLinkChooser> createState()=>_NativeProxoLinkChooserState();
}
class _NativeProxoLinkChooserState extends State<NativeProxoLinkChooser> {
 final _results=<String,dynamic>{};
 late final _ReadOnlyChooserRepository _repository;
 ProxoPageType _type=ProxoPageType.contact;
 static const _capture=MethodChannel('proxo/native-capture');
 @override void initState(){super.initState();_repository=_ReadOnlyChooserRepository(widget.configuration);WidgetsBinding.instance.addPostFrameCallback((_){_run();});}
 List<Element> _elements(bool Function(Widget) predicate){
  final found=<Element>[];
  void visit(Element e){if(predicate(e.widget))found.add(e);e.visitChildren(visit);}
  (context as Element).visitChildren(visit);return found;
 }
 Future<Element> _waitElement(bool Function(Widget) predicate)async{
  for(var i=0;i<200;i++){final found=_elements(predicate);if(found.length==1)return found.single;await Future<void>.delayed(const Duration(milliseconds:100));}
  throw StateError('chooser_element_missing');
 }
 Future<List<double>> _tap(Element e,String id,{bool setup=false})async{
  await Scrollable.ensureVisible(e,alignment:0.5);
  await WidgetsBinding.instance.endOfFrame;
  final box=e.findRenderObject()! as RenderBox;
  final origin=box.localToGlobal(Offset.zero),center=box.localToGlobal(box.size.center(Offset.zero));
  if(!mounted)return [];
  if(MediaQuery.devicePixelRatioOf(context)!=1||box.size.isEmpty||center.dx<0||center.dy<0||center.dx>=1200||center.dy>=1900)throw StateError('chooser_tap_bounds');
  await widget.write('proxolink-chooser-request.json',{'id':id,'phase':setup?'setup':'tap','x':center.dx.round(),'y':center.dy.round()});
  return [origin.dx,origin.dy,box.size.width,box.size.height];
 }
 Future<Map<String,dynamic>> _read(WebViewController c,String script)async{
  dynamic value=await c.runJavaScriptReturningResult(script);if(value is String)value=jsonDecode(value);if(value is String)value=jsonDecode(value);
  return Map<String,dynamic>.from(value as Map);
 }
 Future<void> _ack(String id)async{
  final f=File('${Directory.systemTemp.parent.path}/files/proxolink-chooser-ack');
  for(var i=0;i<120;i++){if(await f.exists()&&(await f.readAsString()).trim()==id){await f.delete();return;}await Future<void>.delayed(const Duration(milliseconds:250));}
  throw StateError('chooser_capture_ack');
 }
 Future<void> _run()async{
  for(final type in ProxoPageType.values){
   if(!mounted)return;
   setState(()=>_type=type);await WidgetsBinding.instance.endOfFrame;
   var setupPassed=false;
   try{
    for(var i=0;i<200;i++){
     final choices=_elements((w)=>w is OutlinedButton);
     if(choices.length==3){await _tap(choices[type.index],'chooser-setup-${type.key}',setup:true);break;}
     await Future<void>.delayed(const Duration(milliseconds:100));
    }
    await _waitElement((w)=>w is ProxoLinkDesignSelector);setupPassed=true;
   }catch(_){}
   // Initial builder selection is pill. This fixed order changes it on every tap.
   for(final style in ['pill-mint','pill-dark','pill-white','pill']){
    final id='chooser-${type.key}-$style';
    try{
     if(!setupPassed)throw StateError('chooser_builder_setup');
     final selector=await _waitElement((w)=>w is ProxoLinkDesignSelector);
     if((selector.widget as ProxoLinkDesignSelector).selectedKey==style)throw StateError('chooser_must_change_selection');
     Object? imageError;
     if(!mounted)return;
     await precacheImage(AssetImage(ProxoLinkDesign.thumbnail(style,type)),context,onError:(Object error,StackTrace? stack){imageError=error;});
     if(imageError!=null)throw StateError('chooser_thumbnail_image');
     final oldViews=_elements((w)=>w is WebViewWidget);
     final oldPlatform=oldViews.isEmpty?null:(oldViews.single.widget as WebViewWidget).platform.params.controller;
     final requests=_repository.requests;
     final card=await _waitElement((w)=>w.key==ValueKey('proxolink-design-$style'));
     final tapBounds=await _tap(card,id);
     WebViewController? controller;
     for(var i=0;i<550;i++){
      await Future<void>.delayed(const Duration(milliseconds:100));
      final selected=_elements((w)=>w is ProxoLinkDesignSelector);
      final views=_elements((w)=>w is WebViewWidget);
      if(selected.length==1&&(selected.single.widget as ProxoLinkDesignSelector).selectedKey==style&&views.length==1){
       final platform=(views.single.widget as WebViewWidget).platform.params.controller;
       if(!identical(platform,oldPlatform)&&_repository.requests>requests){
        controller=WebViewController.fromPlatform(platform);
        await Scrollable.ensureVisible(views.single,alignment:0.5);await WidgetsBinding.instance.endOfFrame;break;
       }
      }
     }
     if(controller==null||_repository.lastStyle!=style||_repository.lastType!=type.key)throw StateError('chooser_selection_callback');
     final view=await _waitElement((w)=>w is WebViewWidget),box=view.findRenderObject()! as RenderBox;
     final width=box.size.width.round();
     Map<String,dynamic>? state;
     for(var i=0;i<450;i++){
      await Future<void>.delayed(const Duration(milliseconds:100));
      try{
       state=await _read(controller,r'''JSON.stringify({ready:document.readyState==='complete',theme:document.documentElement.dataset.theme,
        direction:document.documentElement.dir,language:document.documentElement.lang,width:innerWidth,scroll:document.documentElement.scrollWidth,
        font:[...document.fonts].some(f=>/Bahij/.test(f.family)&&f.status==='loaded'),images:[...document.images].every(i=>i.complete&&i.naturalWidth>0),
        providers:[...document.querySelectorAll('[data-provider]')].map(e=>e.dataset.provider)})''');
       if(state['ready']==true&&state['font']==true&&state['images']==true)break;
      }catch(_){}
     }
     if(state==null||state['ready']!=true||state['font']!=true||state['images']!=true||state['theme']!=style
      ||state['direction']!='rtl'||state['language']!='ku'||((state['width'] as num)-width).abs()>1||width<100
      ||(state['scroll'] as num)>(state['width'] as num)+1||jsonEncode(state['providers'])!=jsonEncode(_providers(type)))throw StateError('chooser_live_preview_design');
     final platform=controller.platform;
     if(platform is! AndroidWebViewController||await _capture.invokeMethod<bool>('awaitDraw',{'webViewIdentifier':platform.webViewIdentifier})!=true)throw StateError('chooser_native_draw');
     await widget.write('proxolink-chooser-request.json',{'id':id,'phase':'capture'});await _ack(id);
     _results[id]={'passed':true,'builder_screen':true,'thumbnail_decoded':true,'selection_changed':true,'selected_state':true,
      'live_theme_match':true,'provider_type_match':true,'fresh_controller':true,'native_draw':true,'width':width,'tap_bounds':tapBounds};
    }catch(error){
     const allowed={'chooser_builder_setup','chooser_element_missing','chooser_thumbnail_image','chooser_tap_bounds','chooser_must_change_selection',
      'chooser_selection_callback','chooser_live_preview_design','chooser_native_draw','chooser_capture_ack'};
     _results[id]={'passed':false,'failed_check':error is StateError&&allowed.contains(error.message)?error.message:'chooser_unclassified'};
    }
    await widget.write('proxolink-chooser-results.json',_results);
   }
  }
  await widget.onComplete();
 }
 @override Widget build(BuildContext context)=>Center(child:SizedBox(width:430,child:ToolsScreen(
  key:ValueKey('native-real-builder-${_type.key}'),initialCreate:true,repository:_repository)));
}
