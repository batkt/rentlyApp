import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Rently/data/models/agreement_model.dart';
import 'package:Rently/presentation/widgets/cards/agreement_card.dart';

AgreementModel _geree({
  double baritsaaAvakhDun = 0,
  double baritsaaniiUldegdel = 0,
}) =>
    AgreementModel(
      id: 'g1',
      gereeniiDugaar: 'ГД26090303',
      ner: 'Мичидмаа',
      ovog: 'Б',
      utas: const ['80062365'],
      talbainIdnuud: const [],
      tuluv: 1,
      uldegdel: 131443.15,
      baiguullagiinId: 'org1',
      barilgiinId: 'b1',
      avlaga: const [],
      zardluud: const [],
      baritsaaAvakhDun: baritsaaAvakhDun,
      baritsaaniiUldegdel: baritsaaniiUldegdel,
    );

Future<void> _kartBairluulya(WidgetTester tester, AgreementModel geree) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: AgreementCard(agreement: geree)),
      ),
    ),
  );
}

void main() {
  group('Барьцааны үлдэгдэл', () {
    test('төлөх үлдэгдэл = авах дүн - авсан дүн', () {
      expect(
        _geree(baritsaaAvakhDun: 675000, baritsaaniiUldegdel: 337500)
            .baritsaaTulukhUldegdel,
        337500,
      );
    });

    test('илүү төлсөн эсвэл бүрэн төлсөн бол 0, төлөгдсөн төлөвт орно', () {
      final buren = _geree(baritsaaAvakhDun: 337500, baritsaaniiUldegdel: 337500);
      expect(buren.baritsaaTulukhUldegdel, 0);
      expect(buren.baritsaaTulsun, isTrue);

      final iluu = _geree(baritsaaAvakhDun: 337500, baritsaaniiUldegdel: 400000);
      expect(iluu.baritsaaTulukhUldegdel, 0);
      expect(iluu.baritsaaTulsun, isTrue);
    });

    test('барьцаагүй гэрээ аль ч төлөвт ороогүй', () {
      final geree = _geree();
      expect(geree.baritsaaTulukhUldegdel, 0);
      expect(geree.baritsaaTulsun, isFalse);
    });
  });

  group('AgreementCard', () {
    testWidgets('дутуу барьцааг "төлөөгүй" гэж анхааруулах өнгөөр',
        (tester) async {
      await _kartBairluulya(
        tester,
        _geree(baritsaaAvakhDun: 675000, baritsaaniiUldegdel: 337500),
      );

      final matn = find.textContaining('Барьцаа төлөөгүй');
      expect(matn, findsOneWidget);
      expect(find.textContaining('Барьцаа төлөгдсөн'), findsNothing);
      // Дутуу дүн нь ҮЛДСЭН 337,500 биш — авсан дүнг харуулж байсан алдаа.
      expect(
        (tester.widget<Text>(matn).data ?? '').contains('337,500'),
        isTrue,
      );
    });

    testWidgets('бүрэн төлөгдсөн барьцааг ногоон мэдээлэл болгон',
        (tester) async {
      await _kartBairluulya(
        tester,
        _geree(baritsaaAvakhDun: 337500, baritsaaniiUldegdel: 337500),
      );

      expect(find.textContaining('Барьцаа төлөгдсөн'), findsOneWidget);
      expect(find.textContaining('Барьцаа төлөөгүй'), findsNothing);
    });

    testWidgets('барьцаагүй гэрээнд барьцааны мөр огт гарахгүй', (tester) async {
      await _kartBairluulya(tester, _geree());
      expect(find.textContaining('Барьцаа'), findsNothing);
    });
  });
}
