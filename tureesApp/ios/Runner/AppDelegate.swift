import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // UIScene + implicit engine дээр plugin-ууд launch дууссаны ДАРАА
    // бүртгэгддэг тул firebase_messaging нь didFinishLaunching мэдэгдлийг
    // алгасаж, APNs-д огт бүртгүүлдэггүй байв (iOS-д түгжигдсэн дэлгэц
    // дээр push ирэхгүй, Android-д ирдэг шалтгаан). Энд өөрсдөө хийнэ.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // APNs токеныг FCM-д шууд өгнө — үүнгүйгээр getToken
    // `apns-token-not-set` алдаа өгч, серверт токен хадгалагддаггүй.
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
