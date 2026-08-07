import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Rently/core/theme/app_theme.dart';
import 'package:Rently/presentation/screens/auth/login_screen.dart';

/// The X in the phone field kept being reported as dead. Pin the behaviour
/// down: typing a number must show it, and tapping it must empty the field —
/// including after the number was verified, where the field used to be
/// `enabled: false` and TextField's IgnorePointer ate the tap.
void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();
  }

  String phoneText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller?.text ?? '';

  testWidgets('X товч бичсэн дугаарыг цэвэрлэнэ', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, '9421');
    await tester.pump();

    final clearButton = find.widgetWithIcon(IconButton, Icons.cancel_rounded);
    expect(clearButton, findsOneWidget, reason: 'дугаар бичсэн үед X гарч ирэх ёстой');

    await tester.tap(clearButton);
    await tester.pump();

    expect(phoneText(tester), isEmpty, reason: 'X дарсны дараа талбар хоосон байх ёстой');
    expect(find.widgetWithIcon(IconButton, Icons.cancel_rounded), findsNothing);
  });

  testWidgets('Талбар хоосон үед X харагдахгүй', (tester) async {
    await pumpLogin(tester);
    expect(find.widgetWithIcon(IconButton, Icons.cancel_rounded), findsNothing);
  });

  testWidgets('Дугаар оруулсан ямар ч төлөвт талбар дарагдахуйц хэвээр', (tester) async {
    await pumpLogin(tester);

    // 8 орон бөглөхөд шалгах хүсэлт эхэлнэ. Тэр үед ч, шалгагдсаны дараа ч
    // талбарыг `enabled: false` болгож болохгүй — тэгвэл X товч дарагдахаа
    // больдог (TextField бүхэлдээ IgnorePointer дотор ордог).
    await tester.enterText(find.byType(TextFormField).first, '99246123');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isNot(false),
      reason: 'enabled: false бол suffix дэх X товч таптыг хүлээж авахгүй',
    );
  });
}
