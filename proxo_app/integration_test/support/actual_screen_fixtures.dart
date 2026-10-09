// Test/debug-only transports for rendering the actual production screen classes.
// No real credential, outbound request, storage write or database mutation.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_design.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/widgets/ad_validation_notifications.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

const screenFixtureOwner='00000000-0000-4000-8000-000000000099';
class ActualScreenBackend {
 late final SupabaseClient client;
 final reads=<String,int>{};
 Completer<void>? refreshGate;
 ActualScreenBackend(){
  client=SupabaseClient('https://screen-fixtures.invalid','fictional-publishable-key',
   httpClient:MockClient((request)async{
    if(request.method!='GET'||request.url.host!='screen-fixtures.invalid')throw StateError('screen_fixture_network_boundary');
    final table=request.url.path.split('/').last;
    if(!{'profiles','pa_ads','pa_featured_ads_public','pa_popups'}.contains(table))throw StateError('screen_fixture_network_boundary');
    reads.update(table,(v)=>v+1,ifAbsent:()=>1);
    if(table=='pa_ads'||table=='pa_featured_ads_public')await refreshGate?.future;
    final Object data=table=='profiles'?{'full_name':'تاقیکردنەوە Proxo'}:table=='pa_ads'?[{
     'id':'00000000-0000-4000-8000-000000000001','title':'Fictional screen fixture','status':'active',
     'spend':12.5,'prev_spend':8,'clicks':1246,'impressions':84320,'prev_impressions':60000,
     'conversions':10,'budget':10,'total_budget':30,'created_at':DateTime.now().subtract(const Duration(hours:1)).toIso8601String(),
    }]:[];
    return http.Response(jsonEncode(data),200,headers:{'content-type':'application/json'});
   }),authOptions:const AuthClientOptions(autoRefreshToken:false),
   realtimeClientOptions:RealtimeClientOptions(transport:(url,headers)=>_ScreenSocket(),disconnectOnEmptyChannelsAfter:Duration.zero));
 }
 Future<void> initialize()async{
  String part(Object value)=>base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=','');
  final token='${part({'alg':'HS256','typ':'JWT'})}.${part({'sub':screenFixtureOwner,'exp':DateTime.now().millisecondsSinceEpoch~/1000+86400})}.fictional-signature';
  await client.auth.recoverSession(jsonEncode(Session(accessToken:token,tokenType:'bearer',
   user:const User(id:screenFixtureOwner,appMetadata:{},userMetadata:{},aud:'authenticated',createdAt:'2026-10-09T00:00:00Z')).toJson()));
  app.supabase=client;
 }
 Future<void> dispose()async{if(refreshGate!=null&&!refreshGate!.isCompleted)refreshGate!.complete();await client.dispose();}
}
class _ScreenSocket extends StreamChannelMixin<dynamic> implements WebSocketChannel {
 final incoming=StreamController<dynamic>();
 late final _ScreenSink output=_ScreenSink(this);
 @override Stream<dynamic> get stream=>incoming.stream;
 @override WebSocketSink get sink=>output;
 @override Future<void> get ready=>Future<void>.value();
 @override String? get protocol=>null;
 @override int? get closeCode=>null;
 @override String? get closeReason=>null;
}
class _ScreenSink implements WebSocketSink {
 final _ScreenSocket socket;
 final completed=Completer<void>();
 _ScreenSink(this.socket);
 @override Future<void> get done=>completed.future;
 @override void add(dynamic event){
  final frame=jsonDecode(event as String);
  final positional=frame is List;
  final topic=positional?frame[2]:frame['topic'],ref=positional?frame[1]:frame['ref'];
  final join=positional?frame[0]:frame['join_ref'],kind=positional?frame[3]:frame['event'];
  final payload=positional?frame[4]:frame['payload'];
  if(!{'phx_join','phx_leave','heartbeat'}.contains(kind))return;
  final bindings=(payload?['config']?['postgres_changes'] as List?)??[];
  final reply={'status':'ok','response':{'postgres_changes':[for(var i=0;i<bindings.length;i++){...Map<String,dynamic>.from(bindings[i] as Map),'id':i}]}};
  scheduleMicrotask((){if(!socket.incoming.isClosed)socket.incoming.add(jsonEncode(positional?[join,ref,topic,'phx_reply',reply]:
   {'join_ref':join,'ref':ref,'topic':topic,'event':'phx_reply','payload':reply}));});
 }
 @override void addError(Object error,[StackTrace? stackTrace])=>throw StateError('screen_fixture_socket_boundary');
 @override Future<void> addStream(Stream<dynamic> stream)async{await for(final e in stream){add(e);}}
 @override Future<void> close([int? closeCode,String? closeReason])async{
  if(!completed.isCompleted){completed.complete();await socket.incoming.close();}
 }
}
class ActualToolsRepository extends ProxoLinkRepository {
 int reads=0;
 Completer<void>? refreshGate;
 @override String get ownerScope=>screenFixtureOwner;
 @override Future<List<ProxoCard>> cards()async{
  reads++;await refreshGate?.future;
  return [for(var i=1;i<=3;i++)ProxoCard(id:'00000000-0000-4000-8000-${i.toString().padLeft(12,'0')}',
   userId:screenFixtureOwner,name:'پەڕەی تاقیکردنەوە $i',templateKey:'pill',templateVersion:6,pageKind:'contact',
   moderationStatus:['pending','approved','rejected'][i-1],status:'active',publishStatus:'ready',cardNumber:i,
   createdAt:DateTime.utc(2026,10,9),updatedAt:DateTime.utc(2026,10,9))];
 }
 @override Future<List<ProxoTemplate>> templates()async=>[for(final key in ProxoLinkDesign.labels.keys)
  ProxoTemplate(key:key,label:ProxoLinkDesign.label(key),previewPath:'',version:6,requiresAvatar:false)];
 @override Future<List<ProxoProvider>> providers()async=>[const ProxoProvider(key:'telegram',pageType:'contact',label:'telegram',icon:'telegram',inputKind:'url')];
 @override Future<ProxoCard> save(Map<String,dynamic> data,{ProxoCard? existing})=>throw StateError('screen_fixture_write_boundary');
 @override Future<void> action(String id,String action)=>throw StateError('screen_fixture_write_boundary');
 @override Future<Uri> preview(String id)=>throw StateError('screen_fixture_preview_boundary');
 @override Future<Uri> formPreview(Map<String,dynamic> data,{ProxoCard? existing})=>throw StateError('screen_fixture_preview_boundary');
 @override Future<Uri> templatePreview(String key,int version,{String theme='purple',String language='ku',String pageType='contact'})=>throw StateError('screen_fixture_preview_boundary');
 @override Future<String> uploadAvatar(String id,Uint8List bytes)=>throw StateError('screen_fixture_write_boundary');
 @override Uri publicUrl(String id,{String pageType='contact'})=>throw StateError('screen_fixture_preview_boundary');
}
class ActualAdRepository extends AdCreationRepository {
 @override Future<List<Map<String,dynamic>>> loadAssets()async=>[];
 @override Future<AdPendingSubmission?> pending()async=>null;
 @override Future<AdQuote> quote(AdDraft d)async=>AdQuote(grossUsd:10,costUsd:10,promoUsd:0,promoFixedIqd:0,rate:1800,balanceUsd:1000,days:1,historicalViewRate:.72);
 @override Future<String> submit(AdPendingSubmission r,ValueNotifier<AdPaymentProgress> progress)=>throw StateError('screen_fixture_write_boundary');
}
Map<String,dynamic> actualInvalidAdDraft()=>const AdDraft(title:'',link:'',code:'FICTIONAL-CODE',goal:'views',
 category:'cosmetics_beauty',paymentMethod:'app_balance',immediate:true).toJson();

List<Element> screenElements(Element root,bool Function(Widget) predicate){
 final out=<Element>[];void visit(Element e){if(predicate(e.widget))out.add(e);e.visitChildren(visit);}visit(root);return out;
}
int screenNoticeCount(Element root){
 final notices=screenElements(root,(w)=>w is AdValidationNotifications);
 if(notices.length!=1)throw StateError('screen_notice_component');
 return screenElements(notices.single,(w)=>w is Icon&&w.icon==Icons.error_outline).length;
}
// Compare actual shared-card properties, independent of different error words
// and each screen's legitimate outer placement. No fixed expected mock layout.
Map<String,Object> screenNoticeAppearance(Element root){
 final notice=screenElements(root,(w)=>w is AdValidationNotifications).single;
 final decoration=screenElements(notice,(w)=>w is DecoratedBox&&w.decoration is BoxDecoration).map((e)=>(e.widget as DecoratedBox).decoration as BoxDecoration).first;
 final text=screenElements(notice,(w)=>w is ProxoText).first.widget as ProxoText;
 final icon=screenElements(notice,(w)=>w is Icon&&w.icon==Icons.error_outline).first.widget as Icon;
 return {'decoration':decoration.toString(),'text_style':text.style.toString(),'icon_size':icon.size??0,'icon_color':icon.color?.toARGB32()??0};
}
