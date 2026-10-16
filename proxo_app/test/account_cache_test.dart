import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/services/account_cache.dart';
import 'package:proxo_app/services/ad_snapshot_cache.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('first/repeat visit and simultaneous readers share data until TTL expires', () async {
    var now = DateTime.utc(2026); final cache = AccountCache(clock:()=>now)..bind('A'); int calls=0;
    Future<Map<String,int>> load() async { calls++; return {'value':calls}; }
    final all = await Future.wait(List.generate(8,(_)=>cache.get('catalog',load)));
    expect(calls,1); expect(all.every((x)=>x['value']==1),true);
    await cache.get('catalog',load); expect(calls,1);
    now=now.add(const Duration(minutes:6)); await cache.get('catalog',load); expect(calls,2);
  });
  test('invalidation forces a refresh and rejects stale outstanding responses', () async {
    final cache=AccountCache()..bind('A'); final pending=Completer<Map<String,int>>();
    final first=cache.get('wallet',()=>pending.future);
    final reject=expectLater(first,throwsA(isA<CacheScopeChanged>()));
    cache.invalidate('wallet'); await cache.get('wallet',()async=>{'balance':2});
    pending.complete({'balance':999}); await reject;
    expect((await cache.get('wallet',()async=>{'balance':0}))['balance'],2);
  });
  test('logout/account switching clears cached and in-flight private data', () async {
    final cache=AccountCache()..bind('A'); final pending=Completer<List<String>>();
    final old=cache.get('private',()=>pending.future);final reject=expectLater(old,throwsA(isA<CacheScopeChanged>()));
    cache.bind(null);cache.bind('B');pending.complete(['A-private']);await reject;
    expect(cache.length,0);expect(await cache.get('private',()async=>['B-private']),['B-private']);
    cache.clear();expect(cache.length,0);
  });
  test('cache evicts within byte and entry limits across repeated navigation', () async {
    final cache=AccountCache(maxEntries:4,maxBytes:200)..bind('A');
    for(int i=0;i<100;i++){await cache.get('route$i',()async=>{'value':'${'x'*30}$i'});expect(cache.length,lessThanOrEqualTo(4));expect(cache.bytes,lessThanOrEqualTo(200));}
    cache.clear();expect(cache.bytes,0);
  });
  test('offline snapshots are bounded, expire, omit authorization codes and never cross accounts', () async {
    SharedPreferences.setMockInitialValues({});String? owner='A';var now=DateTime.utc(2026);
    final cache=AdSnapshotCache('A',()=>owner,clock:()=>now);
    await cache.write('all',[{'id':'ad','video_code':'secret','post_code':'secret','customer_note':'private','title':'display'}]);
    final first=await cache.read('all');expect(first!.single['title'],'display');expect(first.single.containsKey('video_code'),false);
    final prefs=await SharedPreferences.getInstance();expect(jsonEncode(prefs.getKeys().map(prefs.getString).toList()),isNot(contains('secret')));
    owner='B';expect(await cache.read('all'),isNull);await cache.write('all',[{'id':'B'}]);
    owner='A';expect((await cache.read('all'))!.single['id'],'ad');
    for(int i=0;i<10;i++){await cache.write('filter$i',List.generate(100,(n)=>{'id':'$n'}));}
    expect(prefs.getKeys().where((k)=>k.startsWith('proxo.ads.v4.')).length,4);
    expect((await cache.read('filter9'))!.length,50);
    now=now.add(const Duration(hours:25));expect(await cache.read('filter9'),isNull);
    await cache.invalidate();expect(prefs.getKeys(),isEmpty);
  });
}
