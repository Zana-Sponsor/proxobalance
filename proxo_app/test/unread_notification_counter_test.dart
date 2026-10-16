import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/services/unread_notification_counter.dart';
import 'support/session_fixture.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('four mounted bells share one read/subscription and release all resources',()async{
  final client=SupabaseClient('https://counter.invalid','fixture',authOptions:const AuthClientOptions(autoRefreshToken:false));
  await restoreFixture(client);int reads=0,subscriptions=0,closed=0;
  final pending=Completer<int>();
  final service=UnreadNotificationCounter(client,load:(_) {reads++;return pending.future;},subscribe:(_,changed){subscriptions++;return (){closed++;};});
  for(int i=0;i<4;i++)service.acquire();
  final result=service.refresh();expect(reads,1);expect(subscriptions,1);
  pending.complete(3);await result;expect(service.count.value,3);
  for(int i=0;i<3;i++)service.release();expect(closed,0);
  service.release();expect(closed,1);expect(service.consumers,0);expect(service.count.value,0);
  await client.dispose();
 });
 test('account switch rejects old counts and keeps one new subscription',()async{
  final client=SupabaseClient('https://counter.invalid','fixture',authOptions:const AuthClientOptions(autoRefreshToken:false));await restoreFixture(client);
  final old=Completer<int>();int opened=0,closed=0;
  final service=UnreadNotificationCounter(client,load:(owner)=>owner==userA?old.future:Future.value(2),subscribe:(_,changed){opened++;return (){closed++;};});
  service.acquire();final wait=service.refresh();await restoreFixture(client,userB);await Future<void>.delayed(Duration.zero);
  old.complete(99);await wait;await service.refresh();expect(service.count.value,2);expect(opened,2);expect(closed,1);
  service.release();expect(closed,2);await client.dispose();
 });
}
