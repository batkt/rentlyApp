import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/push_notification_service.dart';
import 'presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PushNotificationService.instance.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final container = ProviderContainer();
  // Бүртгэл нь устсан байвал `checkAuth` сешнийг тасалдаг — анхааруулгыг нь
  // эхний фрэйм дээр ErkhKhamgaalagch үзүүлэхийн тулд тугийг нь асаана.
  await container.read(authStateProvider.notifier).checkAuth(
        erkhUstsan: () =>
            container.read(erkhUstsanMedegdekhProvider.notifier).state = true,
      );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TureesApp(),
    ),
  );
}
