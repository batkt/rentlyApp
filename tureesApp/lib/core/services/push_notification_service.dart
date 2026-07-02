import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles background (locked-phone / terminated-app) push notifications.
///
/// Requires `android/app/google-services.json` and
/// `ios/Runner/GoogleService-Info.plist` from the Firebase console — without
/// those, [init] fails fast and the rest of the app keeps working using only
/// the existing in-app socket notifications.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Runs in a separate isolate while the app is backgrounded/terminated.
  // FCM shows the system notification on its own here — nothing to do.
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'turees_default_channel',
    'Мэдэгдэл',
    description: 'Түрээс апп-ын мэдэгдэл',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // Foreground messages don't show a system notification by default —
      // show one ourselves so the behaviour matches a locked/backgrounded phone.
      FirebaseMessaging.onMessage.listen((message) {
        final notif = message.notification;
        if (notif == null) return;
        _localNotifications.show(
          notif.hashCode,
          notif.title,
          notif.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      });

      _initialized = true;
    } catch (e) {
      // Firebase config files not present yet — push notifications stay
      // disabled but the rest of the app keeps working via the socket.
      debugPrint('PushNotificationService.init skipped: $e');
    }
  }

  /// Fetches the current device's FCM token and hands it to [onToken] so the
  /// caller can persist it (e.g. save it on the logged-in tenant's record).
  /// Also keeps it up to date if Firebase rotates the token later.
  Future<void> registerToken(Future<void> Function(String token) onToken) async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await onToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(onToken);
    } catch (e) {
      debugPrint('PushNotificationService.registerToken failed: $e');
    }
  }
}
