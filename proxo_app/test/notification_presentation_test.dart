import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:proxo_app/services/notification_presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final plugin = FlutterLocalNotificationsPlugin();
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
      calls.add(call);
      return true;
    });
    await plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification')));
    calls.clear();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final notification in [
    null,
    const RemoteNotification(title: 'Proxo', body: 'Fixture')
  ]) {
    test(
        'visible ${notification == null ? 'data' : 'mixed'} message posts once with Proxo branding',
        () async {
      await ProxoNotificationPresentation.showMessage(
          plugin,
          RemoteMessage(
              messageId: 'fixture-one',
              notification: notification,
              data: const {
                'title': 'Proxo',
                'body': 'Fixture',
                'screen': 'my-ads'
              }));
      final posted = calls.where((c) => c.method == 'show').toList();
      expect(posted, hasLength(1));
      final args = posted.single.arguments as Map;
      final android = args['platformSpecifics'] as Map;
      expect(android['icon'], 'ic_notification');
      expect(android['largeIcon'], 'proxo_notification_large');
      expect(android['channelId'], 'proxo_high_importance');
      expect(android['importance'], Importance.max.value);
      expect(args['title'], 'Proxo');
      expect(jsonDecode(args['payload'] as String)['screen'], 'my-ads');
    });
  }
  test('silent data update does not create an empty alert', () async {
    await ProxoNotificationPresentation.showMessage(
        plugin, const RemoteMessage(data: {'refresh': 'true'}));
    expect(calls.where((c) => c.method == 'show'), isEmpty);
  });
  test('background data and foreground messages use the same presentation',
      () async {
    await ProxoNotificationPresentation.showData(
        plugin, {'title': 'Proxo', 'body': 'Fixture'});
    final background = calls.single.arguments as Map;
    calls.clear();
    await ProxoNotificationPresentation.showMessage(
        plugin,
        const RemoteMessage(
            notification: RemoteNotification(title: 'Proxo', body: 'Fixture')));
    expect((calls.single.arguments as Map)['platformSpecifics'],
        background['platformSpecifics']);
  });
  test(
      'terminated local notification restores navigation and ignores malformed payloads',
      () {
    NotificationAppLaunchDetails launch(String payload, {bool opened = true}) =>
        NotificationAppLaunchDetails(opened,
            notificationResponse: NotificationResponse(
                notificationResponseType:
                    NotificationResponseType.selectedNotification,
                payload: payload));
    expect(
        ProxoNotificationPresentation.launchPayload(
            launch('{"screen":"my-ads"}')),
        {'screen': 'my-ads'});
    for (final invalid in ['[1]', '{}', 'bad-json']) {
      expect(
          ProxoNotificationPresentation.launchPayload(launch(invalid)), isNull);
    }
    expect(
        ProxoNotificationPresentation.launchPayload(
            launch('{"screen":"my-ads"}', opened: false)),
        isNull);
  });
}
