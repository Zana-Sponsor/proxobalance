import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// One Android appearance for foreground and background data notifications.
/// Automatic FCM notification messages use the same icon/color in the manifest.
abstract final class ProxoNotificationPresentation {
  static const channel = AndroidNotificationChannel(
    'proxo_high_importance',
    'Proxo Notifications',
    description: 'ئاگادارکردنەوەی پرۆکسۆ',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
  );
  static final details = NotificationDetails(
    android: AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon:
          const DrawableResourceAndroidBitmap('proxo_notification_large'),
      color: const Color(0xFF046CFA),
      autoCancel: true,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> showMessage(
    FlutterLocalNotificationsPlugin plugin,
    RemoteMessage message,
  ) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    // Silent data updates should remain silent; visible data-only pushes must
    // not disappear simply because FCM omitted its notification object.
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty))
      return;
    await plugin.show(
      (message.messageId ?? message.data['id']?.toString() ?? title ?? 'proxo')
              .hashCode &
          0x7FFFFFFF,
      title ?? 'Proxo',
      body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> showData(
    FlutterLocalNotificationsPlugin plugin,
    Map<String, dynamic> data,
  ) =>
      showMessage(plugin, RemoteMessage(data: data));

  static Map<String, dynamic>? launchPayload(
      NotificationAppLaunchDetails? launch) {
    if (launch?.didNotificationLaunchApp != true) return null;
    final payload = launch?.notificationResponse?.payload;
    if (payload == null) return null;
    try {
      final data = jsonDecode(payload);
      return data is Map<String, dynamic> && data.isNotEmpty ? data : null;
    } on FormatException {
      return null;
    }
  }
}
