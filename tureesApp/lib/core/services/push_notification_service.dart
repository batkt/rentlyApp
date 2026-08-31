import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

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

  /// Mirrors the "Мэдэгдэл харах" switch in Settings. Only governs what this
  /// app raises for a foreground message — a backgrounded/terminated app's
  /// notifications are drawn by the OS from the FCM payload, so those are
  /// turned off in the phone's own notification settings.
  bool showForegroundNotifications = true;

  static const _channel = AndroidNotificationChannel(
    'turees_default_channel',
    'Мэдэгдэл',
    description: 'Түрээс апп-ын мэдэгдэл',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        if (notif == null || !showForegroundNotifications) return;
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

  /// Утасны тохиргоон дээр мэдэгдэл унтраасан эсэх.
  ///
  /// `init` нь зөвшөөрлийг НЭГ удаа асуудаг: хэрэглэгч татгалзсан, эсвэл
  /// дараа нь утасныхаа тохиргооноос унтраасан бол апп дахин асуухгүй, харин
  /// push чимээгүй ирэхээ болино. Түүнийг илрүүлж анхааруулахад ашиглана.
  Future<bool> medegdelUnturaasanEsekh() async {
    try {
      final tokhirgoo =
          await FirebaseMessaging.instance.getNotificationSettings();
      switch (tokhirgoo.authorizationStatus) {
        case AuthorizationStatus.denied:
          return true;
        case AuthorizationStatus.notDetermined:
          // Хараахан асуугаагүй — унтраасан гэж үзэхгүй.
          return false;
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return false;
      }
    } catch (_) {
      // Firebase тохируулаагүй/алдаа — худал анхааруулга өгөхгүй.
      return false;
    }
  }

  /// Зөвшөөрлийг дахин асууна. Android 13+ дээр системийн цонх гарна;
  /// бүрмөсөн татгалзсан эсвэл iOS дээр бол юу ч болохгүй тул дуудагч тал
  /// үүний дараа утасны тохиргоо руу чиглүүлэх ёстой.
  Future<void> zuvshuuruliigDakhinAsuuya() async {
    try {
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('PushNotificationService.zuvshuuruliigDakhinAsuuya: $e');
    }
  }

  /// Fetches the current device's FCM token and hands it to [onToken] so the
  /// caller can persist it (e.g. save it on the logged-in tenant's record).
  /// Also keeps it up to date if Firebase rotates the token later.
  Future<void> registerToken(Future<void> Function(String token) onToken) async {
    // Өмнө нь `if (!_initialized) return;` гэж ЧИМЭЭГҮЙ буцдаг байсан.
    // `init()` нэг ч удаа унавал (сүлжээ, Play Services) тэр сессийн турш
    // токен хэзээ ч бүртгэгдэхгүй, апп нь бүрэн ажиллаж байгаа мэт
    // харагддаг — «мэдэгдэл ирэхгүй байна» гэдгийн шалтгаан нь энэ байж
    // болно. Одоо дахин эхлүүлэхийг оролдоно.
    if (!_initialized) {
      debugPrint('[FCM] init хийгдээгүй тул дахин оролдож байна');
      await init();
    }
    if (!_initialized) {
      debugPrint('[FCM] init амжилтгүй — токен бүртгэгдэхгүй');
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        // Google Play Services байхгүй/хуучирсан төхөөрөмж дээр (жишээ нь
        // Huawei) getToken үргэлж null буцаана — FCM тэнд ажиллахгүй.
        debugPrint('[FCM] getToken null буцаалаа — push ажиллахгүй');
        return;
      }
      debugPrint('[FCM] токен авлаа: ${token.substring(0, 12)}…');
      await onToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(onToken);
    } catch (e) {
      debugPrint('[FCM] registerToken амжилтгүй: $e');
    }
  }
}
