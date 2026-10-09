import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
import 'support/actual_screen_fixtures.dart';

// Runs AFTER the original 240 strict cases, both 12-case choosers and the three
// browser-return cycles. Actual production screen classes, fictional local
// backends, fixed-phase Android SurfaceView PixelCopy. Never a replacement for
// any matrix frame, native chooser assertion, hosted page or authenticated E2E.
class NativeActualScreensJourney extends StatefulWidget {
  final Future<void> Function(String,Object) write;
  final Future<void> Function() onComplete;
  const NativeActualScreensJourney({super.key,required this.write,required this.onComplete});
  @override State<NativeActualScreensJourney> createState()=>_ActualScreensState();
}
class _ActualScreensState extends State<NativeActualScreensJourney> {
  static const capture=MethodChannel('proxo/native-capture');
  final viewport=GlobalKey(),results=<String,Object>{},captures=<String,Object>{};
  Widget screen=const SizedBox.shrink();double width=393;
  Directory get files=>Directory('${Directory.systemTemp.parent.path}/files');
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>unawaited(_run()));}
  Element get root=>viewport.currentContext! as Element;
  Future<void> _mount(Widget child,int w)async {
    setState((){screen=child;width=w.toDouble();});
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds:900));
    await WidgetsBinding.instance.endOfFrame;
  }
  Future<void> _permission()async {
    await widget.write('proxolink-actual-screens-request.json',{'id':'actual-notification-permission','phase':'permission'});
    final ack=File('${files.path}/proxolink-actual-screens-ack');
    for(var i=0;i<180;i++){
      if(await ack.exists()&&(await ack.readAsString()).trim()=='actual-notification-permission'){await ack.delete();return;}
      await Future<void>.delayed(const Duration(milliseconds:250));
    }throw StateError('actual_screen_permission');
  }
  Future<void> _at(Stopwatch clock,int phase)async {
    final remaining=phase-clock.elapsedMilliseconds;
    if(remaining<0)throw StateError('actual_screen_phase_missed');
    await Future<void>.delayed(Duration(milliseconds:remaining));
  }
  Future<Map<String,Object>> _png(String id,String phase,{Stopwatch? clock})async {
    final requested=clock?.elapsedMilliseconds??0;
    final surface=await capture.invokeMapMethod<String,dynamic>('captureSurface');
    if(surface?['status']!=0)throw StateError('actual_screen_surface');
    final source=File('${files.path}/proxolink-diagnostic-surface.png'),name='$id-$phase.png';
    await source.copy('${files.path}/$name');
    final box=viewport.currentContext!.findRenderObject()! as RenderBox,point=box.localToGlobal(Offset.zero);
    final evidence=<String,Object>{'file':name,'phase':phase,'requested_elapsed_ms':requested,'completed_elapsed_ms':clock?.elapsedMilliseconds??0,
      'surface':{for(final k in ['screen_x','screen_y','width','height','requested_ms','completed_ms'])k:surface![k] as num},
      'viewport':{'x':point.dx,'y':point.dy,'width':box.size.width,'height':box.size.height},
      'capture':'Android Flutter SurfaceView PixelCopy'};
    captures[name]=evidence;await _save();return evidence;
  }
  Future<void> _save()async=>widget.write('proxolink-actual-screens-results.json',{
    'fictional_backends':true,'hosted_content_verified':false,'production_screen_classes':true,'cases':results,'captures':captures});
  Future<void> _run()async {
    ActualScreenBackend? backend;
    try {
      // Normal permission grant keeps actual Home's existing permission check
      // out of Firebase. It does not alter the earlier matrix/device settings.
      await _permission();backend=ActualScreenBackend();await backend.initialize();
      for(final w in [320,393,430,768]) {
        for(final kind in ['home','tools']) {
          final id='actual-$kind-refresh-$w',handle=ProxoRefreshController(),repo=ActualToolsRepository();
          Completer<void>? gate;
          try {
            await _mount(kind=='home'?HomeScreen(key:ValueKey(id),refreshController:handle)
              :ToolsScreen(key:ValueKey(id),repository:repo,refreshController:handle),w);
            final scroll=screenElements(root,(v)=>kind=='home'?v is SingleChildScrollView:v is ListView).first;
            Offset position()=>(scroll.findRenderObject()! as RenderBox).localToGlobal(Offset.zero);
            final initial=position(),shots=<Object>[await _png(id,'initial')],offsets=<double>[];
            gate=Completer<void>();if(kind=='home'){backend.refreshGate=gate;}else{repo.refreshGate=gate;}
            final reads=kind=='home'?backend.reads['pa_ads']!:repo.reads;
            final clock=Stopwatch()..start();final refreshing=handle.refresh();unawaited(handle.refresh());
            for(final phase in [100,300]) {
              await _at(clock,phase);offsets.add(position().dy-initial.dy);
              if(!handle.isRefreshing||offsets.last<=0)throw StateError('actual_screen_refresh');
              shots.add(await _png(id,'${phase}ms',clock:clock));
            }
            // The original concurrent fetch/drop remains pending through both captures.
            await Future<void>.delayed(const Duration(milliseconds:600));
            if((kind=='home'?backend.reads['pa_ads']!:repo.reads)!=reads+1)throw StateError('actual_screen_reads');
            gate.complete();await refreshing;
            await Future<void>.delayed(const Duration(milliseconds:600));await WidgetsBinding.instance.endOfFrame;
            if(handle.isRefreshing||position()!=initial)throw StateError('actual_screen_settle');
            shots.add(await _png(id,'settled',clock:clock));
            results[id]={'passed':true,'same_scroll_element':scroll.mounted,'spinner_closed':true,'settled_offset':0,
              'collection_reads_added':1,'offsets_100_300':offsets,'screenshots':shots,'trigger':'existing ProxoRefreshController.refresh'};
          }catch(e){results[id]={'passed':false,'failed_check':_error(e)};}
          finally{if(gate!=null&&!gate.isCompleted)gate.complete();backend.refreshGate=null;handle.dispose();}
          await _save();await _mount(const SizedBox.shrink(),w);
        }
        Map<String,Object>? appearance;
        for(final kind in ['ad','proxolink']) {
          final id='actual-$kind-error-$w';
          try {
            await _mount(kind=='ad'?AdCreateScreen(key:ValueKey(id),repository:ActualAdRepository(),proxoCard:actualInvalidAdDraft())
              :ProxoLinkCreatePageScreen(key:ValueKey(id),repository:ActualToolsRepository()),w);
            final button=screenElements(root,(v)=>v.key==ValueKey(kind=='ad'?'review-ad':'create-page-submit')).single;
            await Scrollable.ensureVisible(button,alignment:.5,duration:const Duration(milliseconds:260));
            await Future<void>.delayed(const Duration(milliseconds:400));
            if(screenNoticeCount(root)!=0)throw StateError('actual_screen_notices');
            final shots=<Object>[await _png(id,'initial')],counts=<String,int>{};
            final pressed=(button.widget as FilledButton).onPressed;
            if(pressed==null)throw StateError('actual_screen_validation');
            // Calls the ACTUAL form submit callback and its actual controller;
            // input provenance is explicit, not represented as an ADB tap.
            final clock=Stopwatch()..start();pressed();
            for(final phase in [400,4900,5500]) {
              await _at(clock,phase);counts['${phase}ms']=screenNoticeCount(root);
              if((phase<5000&&counts['${phase}ms']!=2)||(phase==5500&&counts['${phase}ms']!=0))throw StateError('actual_screen_lifecycle');
              if(phase==400){final a=screenNoticeAppearance(root);if(appearance!=null&&a.toString()!=appearance.toString())throw StateError('actual_screen_appearance');appearance=a;}
              shots.add(await _png(id,'${phase}ms',clock:clock));
            }
            results[id]={'passed':true,'notice_counts':counts,'appearance':appearance!,'automatic_exit':true,'real_form_validation':true,
              'trigger':'actual production FilledButton.onPressed callback','native_input':false,'screenshots':shots};
          }catch(e){results[id]={'passed':false,'failed_check':_error(e)};}
          await _save();await _mount(const SizedBox.shrink(),w);
        }
      }
    }catch(e){results['setup']={'passed':false,'failed_check':_error(e)};await _save();}
    finally{await backend?.dispose();}
    await widget.onComplete();
  }
  String _error(Object e)=>e is StateError&&{'actual_screen_permission','actual_screen_phase_missed','actual_screen_surface','actual_screen_refresh',
    'actual_screen_reads','actual_screen_settle','actual_screen_notices','actual_screen_validation','actual_screen_lifecycle','actual_screen_appearance'}.contains(e.message)
      ?e.message:'actual_screen_unclassified';
  @override Widget build(BuildContext context)=>Center(child:SizedBox(width:width,height:1200,
    child:MediaQuery(data:MediaQuery.of(context).copyWith(size:Size(width,1200)),child:RepaintBoundary(key:viewport,child:screen))));
}
