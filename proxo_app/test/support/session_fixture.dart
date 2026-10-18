import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
const userA = '11111111-1111-4111-8111-111111111111';
const userB = '22222222-2222-4222-8222-222222222222';
Session sessionFor(String user) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final sid = user == userA ? 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' : 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  return Session(accessToken: '${part({'alg':'HS256'})}.${part({'sub':user,'session_id':sid,'exp':DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.fixture',
    refreshToken:'fixture-refresh',tokenType:'bearer', user:User(id:user,appMetadata:const {},userMetadata:const {},aud:'authenticated',createdAt:'2026-10-16T00:00:00Z'));
}
Future<void> restoreFixture(SupabaseClient c, [String user = userA]) async { await c.auth.recoverSession(jsonEncode(sessionFor(user).toJson())); }
