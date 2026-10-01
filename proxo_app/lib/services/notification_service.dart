// notification_service.dart  (نسخەی نوێ — توکێن پاشەکەوت دەکات)
// بیخەرە ناو:  lib/services/notification_service.dart
//
// ── گۆڕانی نوێ لەم نسخەدا ────────────────────────────────────────────────────
//   • توکێنی FCM ئۆتۆماتیکی دەخرێتە Supabase (pa_device_tokens)
//   • کاتی گۆڕینی توکێن، نوێیەکەی جێگرەوەی کۆیەکە دەکات
//   • saveTokenAfterLogin() بانگدەکرێت کاتی لۆگین کردنی بەکارهێنەر
//   • Edge Function ئەمە بەکاردەهێنێت بۆ نارینی push بۆ موبایل
//
// ── SQL — جەدوەلی pa_device_tokens ────────────────────────────────────────────
//   create table if not exists pa_device_tokens (
//     id         uuid primary key default gen_random_uuid(),
//     user_id    uuid not null references auth.users(id) on delete cascade,
//     token      text not null,
//     platform   text not null default 'android',  -- 'android' | 'ios'
//     updated_at timestamptz default now(),
//     unique(user_id, token)
//   );
//   alter table pa_device_tokens enable row level security;
//   create policy "user owns tokens"
//     on pa_device_tokens for all using (auth.uid() = user_id);
//
// ── pubspec.yaml ──────────────────────────────────────────────────────────────
//   dependencies:
//     firebase_core:               ^3.6.0
//     firebase_messaging:          ^15.1.3
//     flutter_local_notifications: ^17.2.2
//     supabase_flutter:            ^2.5.6
//
// ── main.dart ────────────────────────────────────────────────────────────────
//   final navigatorKey = GlobalKey<NavigatorState>();
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await Firebase.initializeApp();
//     await Supabase.initialize(url: '...', anonKey: '...');
//     FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
//     await NotificationService.instance.init(navigatorKey: navigatorKey);
//     runApp(MyApp(navigatorKey: navigatorKey));
//   }
//
// ── AndroidManifest.xml (ناو <application>) ───────────────────────────────────
//   <meta-data
//     android:name="com.google.firebase.messaging.default_notification_channel_id"
//     android:value="proxo_high_importance" />
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND HANDLER — top-level، دەرەوەی هەر کلاسێک
//
// FIX: _initLocalPlugin() now creates the AndroidNotificationChannel in this
//      isolate too. Without this, Android 8+ silently drops any notification
//      that targets a channel that does not yet exist in the terminated process.
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // FIX: کاتی لۆگ ئاوت، ئاگاداری نیشان مەدە
  // Supabase initialize کردن بۆ خوێندنەوەی سێشنی پاشەکەوتکراو
  try {
    await Supabase.initialize(
      url: 'https://cojchkwssmasiejcgvbk.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvamNoa3dzc21hc2llamNndmJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMTE1MTIsImV4cCI6MjA5Mjg4NzUxMn0'
          '.RCALy3wpKHGAkmXWcBqEb_QFEUmh6ErdRbfrBmagvtw',
    );
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return; // لۆگ ئاوتە — ئاگاداری نیشان مەدە
  } catch (_) {
    // ئەگەر Supabase نەگرایەوە، بەردەوام بە
  }

  // Creates plugin AND the channel inside this background isolate.
  await NotificationService._initLocalPlugin();

  // FIX DUPLICATE: Messages with a notification payload are displayed
  // automatically by the Android OS — manually showing them again here
  // creates a second (duplicate) notification.
  // Only handle data-only messages that Android cannot display by itself.
  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService._showFromData(message.data);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE MAP
// ─────────────────────────────────────────────────────────────────────────────

const _kRouteMap = <String, String>{
  'ad_approved'       : '/my-ads',
  'ad_rejected'       : '/my-ads',
  'ad_active'         : '/my-ads',
  'ad_completed'      : '/my-ads',
  'ad_paused'         : '/my-ads',
  'new_ad'            : '/my-ads',
  'deposit_approved'  : '/wallet',
  'deposit_rejected'  : '/wallet',
  'balance_added'     : '/wallet',
  'refund'            : '/wallet',
  'refund_rejected_ad': '/wallet',
  'new_asset'         : '/assets',
  'profile_update'    : '/profile',
  'admin_msg'         : '/notifications',
  'system_update'     : '/notifications',
  'general'           : '/notifications',
  'warning'           : '/notifications',
  'error'             : '/notifications',
};

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — Singleton
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final _messaging   = FirebaseMessaging.instance;
  static final _localPlugin = FlutterLocalNotificationsPlugin();

  // FIX: Channel ID matches AndroidManifest.xml
  //   android:value="proxo_high_importance"
  // and is used consistently in every show() call and the background handler.
  static const _channel = AndroidNotificationChannel(
    'proxo_high_importance',
    'Proxo Notifications',
    description: 'ئاگادارکردنەوەی پرۆکسۆ',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
  );

  GlobalKey<NavigatorState>? _navigatorKey;
  Map<String, dynamic>? _pendingData; // FIX: ئاگاداری پاشەکەوتکراو کاتی داخستنی ئەپ

  // ── consumePendingData — MainShell دەیخوێنێتەوە دوای کردنەوە ────────────
  Map<String, dynamic>? consumePendingData() {
    final d = _pendingData;
    _pendingData = null;
    return d;
  }

  // ── navigateFromPending — MainShell دەیژێنێت ─────────────────────────────
  void navigateFromPending() {
    final d = consumePendingData();
    if (d != null) _navigate(d);
  }

  // ── init ──────────────────────────────────────────────────────────────────

  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    void Function(RemoteMessage)? onForegroundMessage,
  }) async {
    _navigatorKey = navigatorKey;

    // NOTE: onBackgroundMessage is already registered in main() before init()
    // is called. Do NOT re-register it here to avoid a redundant overwrite.

    // _initLocalPlugin creates the plugin + channel in the foreground process.
    await _initLocalPlugin(navigatorKey: navigatorKey);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground
    FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
      _showLocalNotification(message);
    });

    // Background tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigate(message.data);
    });

    // Terminated tap — FIX: پاشەکەوت بکە، MainShell دوای کردنەوەی تەواو navigate دەکات
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _pendingData = initial.data;
    }

    // ── توکێن پاشەکەوت بکە (ئەگەر ئێستا لۆگین کراوە) ─────────────────────
    // FIX: Also save token on any future auth state change (signedIn).
    // Previously the token was only saved here at startup. If currentUser is
    // null at this point (user not yet logged in), the save is a no-op and
    // the token was never saved, so pa_device_tokens stayed empty and the
    // Edge Function had no token to send FCM push to.
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('[FCM] Token: $token');
      await _saveTokenToSupabase(token);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refresh: $newToken');
      await _saveTokenToSupabase(newToken);
    });
  }

  // ── saveTokenAfterLogin — بانگدەکرێت کاتی لۆگین کردنی بەکارهێنەر ─────────
  //
  // FIX: This method must be called from the auth state listener in main.dart
  // when the user signs in. At app startup the user is not yet logged in, so
  // _saveTokenToSupabase() returns early (uid == null). Calling this method
  // after login ensures the token is always stored in pa_device_tokens, which
  // is required for background FCM push notifications to reach the device.
  Future<void> saveTokenAfterLogin() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Saving token after login...');
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('[FCM] saveTokenAfterLogin error: $e');
    }
  }

  // ── توکێن بخەرە Supabase ─────────────────────────────────────────────────
  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final platform = Platform.isIOS ? 'ios' : 'android';

      await Supabase.instance.client
          .from('pa_device_tokens')
          .upsert(
            {
              'user_id'   : uid,
              'token'     : token,
              'platform'  : platform,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id, token',
          );

      debugPrint('[FCM] Token saved ✓  ($platform)');
    } catch (e) {
      debugPrint('[FCM] Token save error: $e');
    }
  }

  // ── توکێن کاتی logout سڕینەوە ────────────────────────────────────────────
  Future<void> removeToken() async {
    try {
      final uid   = Supabase.instance.client.auth.currentUser?.id;
      final token = await _messaging.getToken();
      if (uid == null || token == null) return;

      await Supabase.instance.client
          .from('pa_device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('token',   token);

      debugPrint('[FCM] Token removed ✓');
    } catch (e) {
      debugPrint('[FCM] Token remove error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Stable notification ID: same string always → same int (no duplicates)
  static int _stableId(String key) => key.hashCode & 0x7FFFFFFF;

  Future<String?> getToken()                  => _messaging.getToken();
  Future<void> subscribeToTopic(String topic) => _messaging.subscribeToTopic(topic);
  Future<void> unsubscribeFromTopic(String t) => _messaging.unsubscribeFromTopic(t);

  // ── _navigate ─────────────────────────────────────────────────────────────

  void _navigate(Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final screen = data['screen'] as String?;
    if (screen != null && screen.isNotEmpty) {
      navigator.pushNamed('/$screen');
      return;
    }

    final type  = data['type'] as String? ?? 'general';
    final route = _kRouteMap[type] ?? '/notifications';
    final adId  = data['ad_id'] as String?;
    navigator.pushNamed(route, arguments: adId != null ? {'ad_id': adId} : null);
  }

  // ── INTERNAL static helpers ───────────────────────────────────────────────
  //
  // FIX: createNotificationChannel() is now called inside _initLocalPlugin so
  // it runs in BOTH the foreground process AND the background isolate that FCM
  // spins up for terminated-state messages.
  //
  // On Android 8+ (API 26+) a notification targeting a channel that does not
  // exist in the current process is silently dropped. Calling
  // createNotificationChannel() is idempotent — safe to call multiple times.

  static Future<void> _initLocalPlugin({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    await _localPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        try {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          instance._navigate(data);
        } catch (_) {}
      },
    );

    // Create the channel in whatever process (foreground or background isolate)
    // is currently running. Android ignores duplicate creates — this is safe.
    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _localPlugin.show(
      _stableId(message.messageId ?? (message.notification?.title ?? 'proxo')),
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority:   Priority.high,
          icon:       'ic_notification',
          largeIcon:  null,
          color:      const Color(0xFF0E78FF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _showFromData(Map<String, dynamic> data) async {
    await _localPlugin.show(
      _stableId(data['id'] as String? ?? data['title'] as String? ?? 'proxo'),
      data['title'] as String? ?? 'Proxo',
      data['body']  as String? ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance:   Importance.max,
          priority:     Priority.high,
          icon:         'ic_notification',
          largeIcon:    null,
          color:        const Color(0xFF0E78FF),
          autoCancel:   true,
          ongoing:      false,
          showProgress: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }
}
