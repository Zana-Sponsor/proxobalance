import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_cache.dart';
import 'app_telemetry_service.dart';
import 'proxolink_service.dart' show newProxoRequestId;

class TopupFailure implements Exception {
  const TopupFailure(this.code); final String code;
}
/// Only a hash and random retry key are persisted, never receipt/form contents.
/// Re-entering the same details after termination recovers the committed result.
class TopupService {
  TopupService(this.client);
  final SupabaseClient client;
  static final Map<String,Future<Map<String,dynamic>>> _pending={};
  Future<Map<String,dynamic>> submit({required String method,required int grossIqd,required String sender,required String note,required String receipt}) {
    final owner=client.auth.currentUser?.id;
    if(owner==null)return Future.error(const TopupFailure('NOT_AUTHENTICATED'));
    final details={'method':method,'gross':grossIqd,'sender':sender,'note':note,'receipt':sha256.convert(utf8.encode(receipt)).toString()};
    final fingerprint=sha256.convert(utf8.encode(jsonEncode(details))).toString();
    final scope='$owner:$fingerprint';
    return _pending.putIfAbsent(scope,()=>Future<Map<String,dynamic>>.microtask(() async {
      try { return await _submit(owner,fingerprint,method,grossIqd,sender,note,receipt); }
      finally { _pending.remove(scope); }
    }));
  }
  Future<Map<String,dynamic>> _submit(String owner,String fingerprint,String method,int gross,String sender,String note,String receipt) async {
    final p=await SharedPreferences.getInstance();
    final storage='proxo.topup.retry.v1.$owner';
    final stored=p.getString(storage);
    Map<String,dynamic>? retry;
    try { if(stored!=null) retry=Map<String,dynamic>.from(jsonDecode(stored) as Map); } catch(_) {}
    // A changed payload is a genuinely new request. One bounded last-request
    // record per account is retained for seven days, including after success.
    final now=DateTime.now().millisecondsSinceEpoch;
    final same=retry?['fingerprint']==fingerprint && now-(retry?['at'] as int? ?? 0)<const Duration(days:7).inMilliseconds;
    final key=same?retry!['key'] as String:newProxoRequestId();
    if(!await p.setString(storage,jsonEncode({'fingerprint':fingerprint,'key':key,'at':now})))throw const TopupFailure('STORAGE_UNAVAILABLE');
    if(client.auth.currentUser?.id!=owner)throw const TopupFailure('SESSION_CHANGED');
    AppTelemetryService.active?.event('action','topup_submit',outcome:'incomplete');
    final watch=Stopwatch()..start();
    try {
      final raw=await client.rpc('pa_submit_topup',params:{'p_key':key,'p_method':method,'p_gross_iqd':gross,'p_sender':sender,'p_note':note,'p_receipt':receipt}).timeout(const Duration(seconds:30));
      if(client.auth.currentUser?.id!=owner)throw const TopupFailure('SESSION_CHANGED');
      final result=Map<String,dynamic>.from(raw as Map);
      if(result['ok']!=true)throw TopupFailure(result['code'] as String? ?? 'TOPUP_FAILED');
      AppDataCache.forClient(client).financialChanged();
      AppTelemetryService.active?.event('action','topup_submit',outcome:'success');
      return result;
    } catch(e) { AppTelemetryService.active?.error(e);rethrow; }
    finally { AppTelemetryService.active?.event('performance','topup_request',durationMs:watch.elapsedMilliseconds); }
  }
}
