// firebase_messaging_service.dart
  // بیخە ناو:  lib/services/firebase_messaging_service.dart
  //
  // NOTE: This file is kept for reference but is NOT imported by main.dart.
  // All active FCM logic lives in notification_service.dart.
  //
  // FIX: The duplicate firebaseMessagingBackgroundHandler that was previously
  // defined here has been removed. Having two top-level functions with the
  // same name across imports causes ambiguous-import errors and unpredictable
  // handler registration. The authoritative handler is in notification_service.dart.

  import 'dart:convert';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  import 'package:flutter_local_notifications/flutter_local_notifications.dart';

  // ─────────────────────────────────────────────────────────────────────────────
  // SERVICE CLASS  (optional / legacy — use NotificationService instead)
  // ─────────────────────────────────────────────────────────────────────────────
  class FirebaseMessagingService {
    FirebaseMessagingService._();
    static final FirebaseMessagingService instance = FirebaseMessagingService._();

    final _messaging = FirebaseMessaging.instance;
    final _localNotifications = FlutterLocalNotificationsPlugin();

    // Channel ID must match AndroidManifest.xml default_notification_channel_id
    // and the _channel constant in NotificationService.
    static const _channelId   = 'proxo_high_importance';
    static const _channelName = 'Proxo Notifications';

    // ── destdan بکە لە main()، دوای Firebase.initializeApp() ──────────────────
    Future<void> init() async {
      await _requestPermissions();
      await _setupLocalNotifications();
      _listenForeground();
      _listenBackgroundTap();
      await _checkInitialMessage();
      await _printToken();
    }

    // ── 1. مۆڵەت وەرگرتن ─────────────────────────────────────────────────────
    Future<void> _requestPermissions() async {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('[FCM] Auth status: ${settings.authorizationStatus}');
    }

    // ── 2. Local Notifications ────────────────────────────────────────────────
    Future<void> _setupLocalNotifications() async {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _localNotifications.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            final data =
                jsonDecode(response.payload!) as Map<String, dynamic>;
            _navigate(data);
          }
        },
      );

      // FIX: channel ID changed from 'proxo_channel' → 'proxo_high_importance'
      // to match AndroidManifest.xml default_notification_channel_id.
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Proxo push notifications',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // ── 3. ئەپ کراوەیە — Foreground ──────────────────────────────────────────
    void _listenForeground() {
      FirebaseMessaging.onMessage.listen((message) async {
        final n = message.notification;
        if (n == null) return;

        await _localNotifications.show(
          message.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,        // FIX: was 'proxo_channel'
              _channelName,
              channelDescription: 'Proxo push notifications',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: jsonEncode(message.data),
        );
      });
    }

    // ── 4. ئەپ پاشەکەوت کراوە — Background tap ───────────────────────────────
    void _listenBackgroundTap() {
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _navigate(message.data);
      });
    }

    // ── 5. ئەپ داخستوو بوو — Terminated tap ──────────────────────────────────
    Future<void> _checkInitialMessage() async {
      final message = await _messaging.getInitialMessage();
      if (message != null) {
        _navigate(message.data);
      }
    }

    // ── 6. Token ──────────────────────────────────────────────────────────────
    Future<void> _printToken() async {
      final token = await _messaging.getToken();
      print('[FCM] Token: $token');

      _messaging.onTokenRefresh.listen((t) {
        print('[FCM] Token refresh: $t');
      });
    }

    // ── Navigate ───────────────────────────────────────────────────────────────
    void _navigate(Map<String, dynamic> data) {
      print('[FCM] Payload: $data');
    }
  }
