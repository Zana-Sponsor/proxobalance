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
 late final http.Client transport;
 final reads=<String,int>{};
 final readGates=<String,Completer<void>>{};
 // Capture a response before its gate, so tests can deliver an older response
 // after a newer read or realtime event without any real network access.
 final readResponses=<String,Object>{};
 Completer<void>? refreshGate;
 Completer<void>? bannerGate;
 Completer<void>? unreadGate;
 int bannerJoins=0;
 bool includeNotifications = false;
 bool adsUnavailable = false;
 bool emptyAds = false;
 Map<String, dynamic>? banner;
 final _sockets=<_ScreenSocket>[];
 int logoutRequests=0;
 bool logoutFails=false;
 ActualScreenBackend({bool allowLogout=false}){
  transport=MockClient((request)async{
    if(allowLogout && request.method=='POST' && request.url.host=='screen-fixtures.invalid' && request.url.path=='/auth/v1/logout'){
      logoutRequests++;
      return http.Response(logoutFails?'{"message":"fixture logout unavailable"}':'',logoutFails?500:204,
        request:request,headers:{'content-type':'application/json'});
    }
    if(request.method!='GET'||request.url.host!='screen-fixtures.invalid')throw StateError('screen_fixture_network_boundary');
    final table=request.url.path.split('/').last;
    if(!{'profiles','pa_ads','pa_featured_ads_public','pa_popups','pa_notifications','pa_banners','pa_wallets','pa_user_points','pa_levels','pa_challenges','pa_tutorials','pa_challenge_progress','pa_vouchers','promo_codes'}.contains(table))throw StateError('screen_fixture_network_boundary');
    reads.update(table,(v)=>v+1,ifAbsent:()=>1);
    final response = readResponses[table];
    await readGates[table]?.future;
    if(table=='pa_banners')await bannerGate?.future;
    if(table=='pa_notifications')await unreadGate?.future;
    if(table=='pa_ads'||table=='pa_featured_ads_public')await refreshGate?.future;
    if(table=='pa_ads' && adsUnavailable) throw StateError('fixture_network_error');
    final Object data=table=='pa_banners' ? (banner ?? []) : table=='pa_notifications' && includeNotifications ? [
      {'id':'notice-1','user_id':screenFixtureOwner,'type':'ad_active','is_read':false,'created_at':DateTime.now().subtract(const Duration(minutes:3)).toUtc().toIso8601String()},
      {'id':'notice-2','user_id':screenFixtureOwner,'type':'deposit_approved','is_read':true,'created_at':DateTime.now().subtract(const Duration(days:1)).toUtc().toIso8601String()},
    ] : table=='pa_tutorials' ? [{'id':'tutorial-1','title':'Fixture tutorial','section':'دەستێک','youtube_url':''}] : table=='pa_levels' ? [
      {'id':'tier-1','level_number':1,'name_ku':'Tier 1','icon':'medal','min_points':0,'color':'#0365FF'},
      {'id':'tier-2','level_number':2,'name_ku':'Tier 2','icon':'crown','min_points':100,'color':'#7856A8'},
    ] : table=='pa_challenges' ? [
      {'id':'challenge-1','title':'Fixture challenge','description':'Read-only fixture','goal_type':'ads_count','goal_value':3,'reward_points':10,'reward_iqd':0},
    ] : table=='pa_vouchers' ? (request.url.queryParameters.containsKey('used_at') ? [] : [
      {'id':'voucher-1','code':'DEMO-ONLY','amount_iqd':1000,'reason':'دیاری بەخێرهاتن','is_signup_bonus':true,'created_at':'2026-10-14T10:00:00Z'},
    ]) : table=='promo_codes' ? [
      {'id':'promo-1','code':'DEMO-ONLY','discount_type':'percentage','discount_value':5,'is_active':true},
    ] : table=='profiles'?{'full_name':'تاقیکردنەوە Proxo','email':'fixture@example.invalid','phone':'+9647500000000'}:table=='pa_ads' && emptyAds ? [] :table=='pa_ads'?[{
     'id':'00000000-0000-4000-8000-000000000001','title':'Fictional screen fixture','status':'active',
     'spend':12.5,'prev_spend':8,'clicks':1246,'impressions':84320,'prev_impressions':60000,
     'conversions':10,'budget':10,'total_budget':30,'created_at':DateTime.now().subtract(const Duration(hours:1)).toIso8601String(),
    }]:table=='pa_wallets'?{'balance':10}:table=='pa_user_points'?{'points':0}:[];
    return http.Response(jsonEncode(response ?? data),200,request:request,headers:{'content-type':'application/json','content-range':'*/0'});
   });
 }
 Future<void> initialize()async{
  final instance=await Supabase.initialize(url:'https://screen-fixtures.invalid',anonKey:'fictional-publishable-key',debug:false,
   httpClient:transport,authOptions:const FlutterAuthClientOptions(autoRefreshToken:false,localStorage:EmptyLocalStorage(),detectSessionInUri:false),
   realtimeClientOptions:RealtimeClientOptions(transport:(url,headers){final socket=_ScreenSocket(onJoin:(topic){if(topic=='realtime:banner_rt')bannerJoins++;});_sockets.add(socket);return socket;},disconnectOnEmptyChannelsAfter:Duration.zero));
  client=instance.client;
  String part(Object value)=>base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=','');
  final token='${part({'alg':'HS256','typ':'JWT'})}.${part({'sub':screenFixtureOwner,'exp':DateTime.now().millisecondsSinceEpoch~/1000+86400})}.fictional-signature';
  await client.auth.recoverSession(jsonEncode(Session(accessToken:token,tokenType:'bearer',
   user:const User(id:screenFixtureOwner,appMetadata:{},userMetadata:{},aud:'authenticated',createdAt:'2026-10-09T00:00:00Z')).toJson()));
  app.supabase=client;
  // Prove the fixture meets the actual PostgREST response/request contract
  // before mounting any production screen.
  await client.from('pa_ads').select('id');
 }
 void emitBannerChange(){
  for(final socket in _sockets){
   socket.emit('realtime:banner_rt','postgres_changes',{'ids':[0],'data':{
    'schema':'public','table':'pa_banners','type':'UPDATE','commit_timestamp':'2026-10-13T00:00:00Z',
    'columns':[],'record':{'id':'fixture-banner'},'old_record':{}}});
  }
 }
 void emitProfileChange(Map<String,dynamic> record,{bool wallet=false}){
  final prefix=wallet?'realtime:profile_screen_wallet_':'realtime:profile_screen_profile_';
  for(final socket in _sockets){
   for(final topic in socket.joinedTopics.where((t)=>t.startsWith(prefix))){
    socket.emit(topic,'postgres_changes',{'ids':[0],'data':{
     'schema':'public','table':wallet?'pa_wallets':'profiles','type':'UPDATE',
     'commit_timestamp':'2026-10-15T20:00:00Z','columns':[],
     'record':record,'old_record':{}}});
   }
  }
 }
 Future<void> dispose()async{if(refreshGate!=null&&!refreshGate!.isCompleted)refreshGate!.complete();await Supabase.instance.dispose();}
}
class _ScreenSocket extends StreamChannelMixin<dynamic> implements WebSocketChannel {
 final incoming=StreamController<dynamic>();
 final joinedTopics=<String>{};
 final void Function(String)? onJoin;
 bool positional=false;
 _ScreenSocket({this.onJoin});
 void emit(String topic,String event,Map<String,dynamic> payload){
  if(!incoming.isClosed)incoming.add(jsonEncode(positional?[null,null,topic,event,payload]:
   {'join_ref':null,'ref':null,'topic':topic,'event':event,'payload':payload}));
 }
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
  socket.positional=positional;
  final topic=positional?frame[2]:frame['topic'],ref=positional?frame[1]:frame['ref'];
  final join=positional?frame[0]:frame['join_ref'],kind=positional?frame[3]:frame['event'];
  final payload=positional?frame[4]:frame['payload'];
  if(kind=='phx_join'){
   socket.joinedTopics.add(topic as String);
   socket.onJoin?.call(topic);
  }
  if(kind=='phx_leave')socket.joinedTopics.remove(topic);
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
Map<String,Object> screenNoticeVisualState(Element root){
 final notice=screenElements(root,(w)=>w is AdValidationNotifications).single;
 return {'opacity':[for(final e in screenElements(notice,(w)=>w is FadeTransition))(e.widget as FadeTransition).opacity.value],
  'size_factor':[for(final e in screenElements(notice,(w)=>w is SizeTransition))(e.widget as SizeTransition).sizeFactor.value]};
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
