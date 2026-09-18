import 'package:flutter_test/flutter_test.dart';

import 'package:Rently/core/utils/mon_num.dart';
import 'package:Rently/data/services/geree_html_builder.dart';

/// Загварын заалт нь HTML-ээр escape хийгдсэн орлуулгатай ирдэг
/// (`&lt;talbainNegjUne&gt;`), яг серверт хадгалагдсан хэлбэрээр.
Map<String, dynamic> _zagvar(List<String> zaaltuud) => {
      'ner': 'Түрээсийн гэрээ',
      'zuunTolgoi': '<p>Гэрээ №: &lt;gereeniiDugaar&gt;</p>',
      'baruunTolgoi': '<p>Огноо: &lt;gereeniiOgnoo&gt;</p>',
      'zuunKhul': '<p>Түрээслүүлэгч &lt;tamga&gt;</p>',
      'baruunKhul': '<p>Түрээслэгч: &lt;ner&gt;</p>',
      'dedKhesguud': zaaltuud.map((z) => {'zaalt': z}).toList(),
    };

void main() {
  group('monToWords', () {
    test('мянга, сая зэргийг вэбийн mon_num шиг бичнэ', () {
      expect(monToWords(0), 'тэг');
      expect(monToWords(11), 'арван нэг');
      expect(monToWords(120), 'нэг зуун хорь');
      expect(monToWords(1500000), 'нэг сая таван зуун мянга');
      expect(monToWords(2345), 'хоёр мянга гурван зуун дөчин тав');
    });

    test('тоо биш утганд хоосон мөр', () {
      expect(monToWords(null), '');
      expect(monToWords('  '), '');
    });
  });

  group('GereeHtmlBuilder', () {
    test('гэрээний талбаруудыг загварын орлуулга руу тавина', () {
      final html = GereeHtmlBuilder.bii(
        geree: {
          '_id': 'g1',
          'gereeniiDugaar': 'TUR-001',
          'gereeniiOgnoo': '2025-03-04T00:00:00.000Z',
          'duusakhOgnoo': '2026-03-04T00:00:00.000Z',
          'khugatsaa': 12,
          'ner': 'Болд',
          'utas': ['99119911', '88118811'],
          'talbainNegjUne': 45000,
          'talbainNiitUne': 1500000,
          'baiguullagiinId': 'org1',
        },
        zagvar: _zagvar([
          '<p>Талбайн нэгж үнэ &lt;talbainNegjUne&gt;₮, нийт '
              '&lt;talbainNiitUne&gt;₮ (&lt;talbainNiitUneUsgeer&gt;)</p>',
          '<p>Хугацаа: &lt;ekhlekhOn&gt;.&lt;ekhelkhSar&gt;.&lt;ekhlekhUdur&gt;'
              ' — &lt;duusakhOn&gt;.&lt;duusakhSar&gt;.&lt;duusakhUdur&gt;</p>',
          '<p>Утас: &lt;utas&gt;</p>',
        ]),
      );

      expect(html.contains('TUR-001'), isTrue);
      expect(html.contains('2025/03/04'), isTrue);
      expect(html.contains('45,000.00'), isTrue);
      expect(html.contains('1,500,000.00'), isTrue);
      expect(html.contains('нэг сая таван зуун мянга'), isTrue);
      expect(html.contains('2025.03.04 — 2026.03.04'), isTrue);
      // Олон утастай гэрээнд эхний дугаар нь ордог.
      expect(html.contains('Утас: 99119911'), isTrue);
      expect(html.contains('88118811'), isFalse);
      // Орлуулга үлдэж хоцроогүй эсэх.
      expect(html.contains('&lt;'), isFalse);
    });

    test('зардлын мөр бүрийн утга, нийт дүн орлуулагдана', () {
      final html = GereeHtmlBuilder.bii(
        geree: {
          'gereeniiDugaar': 'TUR-002',
          'ner': 'Болд',
          'baiguullagiinId': 'org1',
          'zardluud': [
            {'ner': 'Цахилгаан', 'tariff': 250, 'tulukhDun': 55000,
              'turul': 'кВт', 'nuatNemekhEsekh': true},
            {'ner': 'Ус', 'dun': 22000, 'turul': 'м3'},
          ],
        },
        zagvar: _zagvar([
          '<p>Цахилгаан: &lt;Цахилгаан.tariff&gt; / '
              '&lt;Цахилгаан.khemjikhNegj&gt; — &lt;Цахилгаан.tulukhDun&gt;₮</p>',
          '<p>Ус: &lt;Ус.dun&gt;₮</p>',
          '<p>Нийт: &lt;niitZardliinDun&gt;₮, НӨАТ-гүй '
              '&lt;niitZardliinNuatguiDun&gt;₮, НӨАТ &lt;niitZardliinNuatiinDun&gt;₮</p>',
        ]),
      );

      expect(html.contains('250.00 / кВт — 55,000.00₮'), isTrue);
      expect(html.contains('Ус: 22,000.00₮'), isTrue);
      expect(html.contains('Нийт: 77,000.00₮'), isTrue);
      expect(html.contains('НӨАТ-гүй 22,000.00₮'), isTrue);
      expect(html.contains('НӨАТ 5,000.00₮'), isTrue);
    });

    test('segment болон барилгын тамга, хаяг', () {
      final html = GereeHtmlBuilder.bii(
        geree: {
          'gereeniiDugaar': 'TUR-003',
          'ner': 'Болд',
          'baiguullagiinId': 'org1',
          'barilgiinId': 'b1',
          'segmentuud': [
            {'ner': 'khariutsagch', 'utga': 'Д.Сараа'},
          ],
        },
        zagvar: _zagvar([
          '<p>Хаяг: &lt;barilgiinKhayag&gt;</p>',
          '<p>Хариуцагч: &lt;khariutsagch&gt;</p>',
        ]),
        barilga: {
          '_id': 'b1',
          'khayag': 'СБД 1-р хороо',
          'tamga': 'tamga1',
          'gariinUseg': 'useg1',
        },
      );

      expect(html.contains('СБД 1-р хороо'), isTrue);
      expect(html.contains('Хариуцагч: Д.Сараа'), isTrue);
      expect(html.contains('/zuragAvya/tamga/org1/tamga1'), isTrue);
    });

    test('массив/объект талбар загварт хог бичвэр үлдээхгүй', () {
      final html = GereeHtmlBuilder.bii(
        geree: {
          'gereeniiDugaar': 'TUR-004',
          'ner': 'Болд',
          'baiguullagiinId': 'org1',
          'guilgeenuud': [
            {'dun': 1000},
          ],
          'avlaga': {'uldegdel': 5000},
        },
        zagvar: _zagvar(['<p>&lt;gereeniiDugaar&gt;</p>']),
      );

      expect(html.contains('TUR-004'), isTrue);
      expect(html.contains('{'), isFalse);
      expect(html.contains('Instance of'), isFalse);
    });

    test('акт холбогдсон бол гэрээний араас нэмэгдэнэ', () {
      final html = GereeHtmlBuilder.bii(
        geree: {
          'gereeniiDugaar': 'TUR-005',
          'ner': 'Болд',
          'baiguullagiinId': 'org1',
        },
        zagvar: _zagvar(['<p>Гэрээний заалт</p>']),
        akt: _zagvar(['<p>Хүлээлгэн өгсөн: &lt;ner&gt;</p>']),
      );

      expect(html.contains('Гэрээний заалт'), isTrue);
      expect(html.contains('Хүлээлгэн өгсөн: Болд'), isTrue);
      expect(html.contains('Акт'), isTrue);
    });
  });
}
