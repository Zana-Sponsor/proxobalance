// lib/services/admin_notifier.dart
//
// بیخەرە ناو:  lib/services/admin_notifier.dart
//
// بەکارهێنان لە Admin Panel:
//
//   // کاتی پەسەندکردنی ڕیکلام
//   await AdminNotifier.adApproved(userId: ad.userId, adId: ad.id);
//
//   // کاتی پەسەندکردنی پارە
//   await AdminNotifier.depositApproved(userId: tx.userId);
//
//   // کاتی ڕەتکردنەوەی پارە
//   await AdminNotifier.depositRejected(userId: tx.userId);
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotifier {
  AdminNotifier._();

  static final _sb = Supabase.instance.client;

  // ── ناردنی notification بە Edge Function ─────────────────────────────────

  static Future<void> _send({
    required String userId,
    required String type,
    String?  title,
    String?  body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _sb.functions.invoke(
        'send-notification',
        body: {
          'user_id': userId,
          'type'   : type,
          if (title != null) 'title': title,
          if (body  != null) 'body' : body,
          if (data  != null) 'data' : data,
        },
      );
    } catch (e) {
      // notification شکستی هێنا — بێدەنگ تێپەڕ بکە (ئەپ نامرێت)
      print('[AdminNotifier] Error sending $type: $e');
    }
  }

  // ── ڕیکلام ──────────────────────────────────────────────────────────────

  static Future<void> adApproved({
    required String userId,
    required String adId,
  }) => _send(
    userId: userId,
    type  : 'ad_approved',
    data  : {'ad_id': adId},
  );

  static Future<void> adRejected({
    required String userId,
    required String adId,
  }) => _send(
    userId: userId,
    type  : 'ad_rejected',
    data  : {'ad_id': adId},
  );

  static Future<void> adActive({
    required String userId,
    required String adId,
  }) => _send(
    userId: userId,
    type  : 'ad_active',
    data  : {'ad_id': adId},
  );

  static Future<void> adCompleted({
    required String userId,
    required String adId,
  }) => _send(
    userId: userId,
    type  : 'ad_completed',
    data  : {'ad_id': adId},
  );

  static Future<void> adPaused({
    required String userId,
    required String adId,
  }) => _send(
    userId: userId,
    type  : 'ad_paused',
    data  : {'ad_id': adId},
  );

  // ── پارە / باڵانس ────────────────────────────────────────────────────────

  static Future<void> depositApproved({required String userId}) =>
      _send(userId: userId, type: 'deposit_approved');

  static Future<void> depositRejected({required String userId}) =>
      _send(userId: userId, type: 'deposit_rejected');

  static Future<void> balanceAdded({
    required String userId,
    String? customBody,
  }) => _send(
    userId: userId,
    type  : 'balance_added',
    body  : customBody,
  );

  static Future<void> refund({
    required String userId,
    String? adId,
  }) => _send(
    userId: userId,
    type  : 'refund',
    data  : adId != null ? {'ad_id': adId} : null,
  );

  // ── پەیامی دیاریکراو (ئادمین دەنووسێت) ──────────────────────────────────

  static Future<void> custom({
    required String userId,
    required String title,
    required String body,
    String type = 'admin_msg',
    Map<String, dynamic>? data,
  }) => _send(
    userId: userId,
    type  : type,
    title : title,
    body  : body,
    data  : data,
  );
}
