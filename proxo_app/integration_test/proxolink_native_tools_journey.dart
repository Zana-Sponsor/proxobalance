import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';

// Fictional owner/list only; no create, upload, database mutation or capability.
// A real external browser is launched using Tools' production url_launcher call.
// Public content of this nonexistent fixture UUID is NOT certified by this test.
class _ToolsFixture extends ProxoLinkRepository {
  int reads = 0;
  static const owner = '00000000-0000-4000-8000-000000000099';
  static String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
  @override String get ownerScope => owner;
  @override Future<List<ProxoCard>> cards() async {
    reads++;
    return [for(var i=1;i<=15;i++) ProxoCard(id:id(i),userId:owner,name:'پەڕەی تاقیکردنەوە $i',
      templateKey:'pill',templateVersion:6,pageKind:'contact',moderationStatus:'pending',
      status:'active',publishStatus:'ready',cardNumber:i,
      createdAt:DateTime.utc(2026,10,9).subtract(Duration(minutes:i)),updatedAt:DateTime.utc(2026,10,9))];
  }
  @override Uri publicUrl(String id,{String pageType='contact'}) => Uri.parse(ProxoLinkService.publicBase).resolve('/$pageType/$id');
  @override Future<List<ProxoTemplate>> templates() => throw StateError('tools_fixture_write_boundary');
  @override Future<List<ProxoProvider>> providers() => throw StateError('tools_fixture_write_boundary');
  @override Future<Uri> formPreview(Map<String,dynamic> data,{ProxoCard? existing}) => throw StateError('tools_fixture_write_boundary');
  @override Future<ProxoCard> save(Map<String,dynamic> data,{ProxoCard? existing}) => throw StateError('tools_fixture_write_boundary');
  @override Future<void> action(String id,String action) => throw StateError('tools_fixture_write_boundary');
  @override Future<Uri> preview(String id) => throw StateError('tools_fixture_write_boundary');
  @override Future<Uri> templatePreview(String key,int version,{String theme='purple',String language='ku',String pageType='contact'}) => throw StateError('tools_fixture_write_boundary');
  @override Future<String> uploadAvatar(String id,Uint8List bytes) => throw StateError('tools_fixture_write_boundary');
}
class NativeToolsBrowserJourney extends StatefulWidget {
  final Future<void> Function(String,Object) write;
  final Future<void> Function() onComplete;
  const NativeToolsBrowserJourney({super.key,required this.write,required this.onComplete});
  @override State<NativeToolsBrowserJourney> createState()=>_BrowserJourneyState();
}
class _BrowserJourneyState extends State<NativeToolsBrowserJourney> with WidgetsBindingObserver {
  final _repository=_ToolsFixture();
  int _paused=0,_resumed=0;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_)=>unawaited(_run()));}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused)_paused++;
    if(state==AppLifecycleState.resumed)_resumed++;
  }
  List<Element> _find(bool Function(Widget) predicate,{Element? root}){
    final found=<Element>[];void visit(Element e){if(predicate(e.widget))found.add(e);e.visitChildren(visit);}
    (root??context as Element).visitChildren(visit);return found;
  }
  Future<Element> _wait(bool Function(Widget) predicate)async{
    for(var i=0;i<200;i++){final found=_find(predicate);if(found.length==1)return found.single;
      await Future<void>.delayed(const Duration(milliseconds:100));}
    throw StateError('browser_journey_element');
  }
  Future<void> _ack(String id)async{
    final file=File('${Directory.systemTemp.parent.path}/files/proxolink-tools-browser-ack');
    for(var i=0;i<180;i++){
      if(await file.exists()&&(await file.readAsString()).trim()==id){await file.delete();return;}
      await Future<void>.delayed(const Duration(milliseconds:250));
    }throw StateError('browser_journey_ack');
  }
  Future<void> _run()async{
    final results=<String,Object>{};
    try{
      final list=(await _wait((w)=>w is ListView)).widget as ListView;
      final scroll=list.controller!;
      // This waits for the initial collection, then establishes a nonzero scroll.
      await _wait((w)=>w.key==ValueKey('proxolink-page-${_ToolsFixture.id(1)}'));
      await scroll.animateTo(800,duration:const Duration(milliseconds:260),curve:Curves.easeOutCubic);
      for(var cycle=1;cycle<=3;cycle++){
        final id='tools-browser-$cycle',observed=<String,Object>{};
        try{
          final row=await _wait((w)=>w.key==ValueKey('proxolink-page-${_ToolsFixture.id(5)}'));
          final previews=_find((w)=>w is FilledButton,root:row);
          if(previews.length!=1)throw StateError('browser_journey_element');
          await Scrollable.ensureVisible(previews.single,alignment:.5);await WidgetsBinding.instance.endOfFrame;
          final box=previews.single.findRenderObject()! as RenderBox;
          final center=box.localToGlobal(box.size.center(Offset.zero));
          final offset=scroll.offset,position=(row.findRenderObject()! as RenderBox).localToGlobal(Offset.zero);
          final paused=_paused,resumed=_resumed;
          await widget.write('proxolink-tools-browser-request.json',{'id':id,'phase':'tap','x':center.dx.round(),'y':center.dy.round()});
          await _ack(id);
          // Host acknowledges only after observing an external browser and
          // bringing the existing activity back to the foreground.
          for(var i=0;i<100&&_resumed==resumed;i++)await Future<void>.delayed(const Duration(milliseconds:100));
          await WidgetsBinding.instance.endOfFrame;
          final after=await _wait((w)=>w.key==ValueKey('proxolink-page-${_ToolsFixture.id(5)}'));
          final afterPosition=(after.findRenderObject()! as RenderBox).localToGlobal(Offset.zero);
          observed.addAll({'pause_observed':_paused>paused,'resume_observed':_resumed>resumed,'same_row_element':identical(row,after),
            'same_scroll_offset':scroll.offset==offset,'same_row_position':afterPosition==position,
            'collection_reads':_repository.reads,'scroll_offset':offset,'scroll_offset_after':scroll.offset,
            'pause_count_before':paused,'pause_count_after':_paused,'resume_count_before':resumed,'resume_count_after':_resumed,
            'row_x_before':position.dx,'row_y_before':position.dy,'row_x_after':afterPosition.dx,'row_y_after':afterPosition.dy,
            'fictional_repository':true,'public_content_verified':false});
          // Retain the actual return screen and every predicate even on failure.
          await widget.write('proxolink-tools-browser-request.json',{'id':id,'phase':'capture'});await _ack(id);
          if(_paused<=paused||_resumed<=resumed||!identical(row,after)||scroll.offset!=offset||
              afterPosition!=position||_repository.reads!=1)throw StateError('browser_journey_state');
          results[id]={...observed,'passed':true,'pause_observed':true,'resume_observed':true,'same_row_element':true,
            'same_scroll_offset':true,'same_row_position':true,'collection_reads':_repository.reads,'scroll_offset':offset,
            'public_content_verified':false,'fictional_repository':true};
        }catch(error){
          results[id]={...observed,'passed':false,'failed_check':error is StateError&&
            {'browser_journey_ack','browser_journey_element','browser_journey_state'}.contains(error.message)?error.message:'browser_journey_unclassified'};
        }
        await widget.write('proxolink-tools-browser-results.json',results);
      }
    }catch(_){await widget.write('proxolink-tools-browser-results.json',{'setup_failed':true});}
    await widget.onComplete();
  }
  @override Widget build(BuildContext context)=>Center(child:SizedBox(width:430,child:ToolsScreen(repository:_repository)));
}
