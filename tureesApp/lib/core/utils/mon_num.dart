/// Тоог монгол үсгээр бичих — turees вэбийн хэрэглэдэг `mon_num` санны
/// `toWords`-ийн порт.
///
/// Гэрээний загвар дээр `<talbainNegjUneUsgeer>`, `<talbainNiitUneUsgeer>`,
/// `<baritsaaAvakhDunUsgeer>` гэсэн орлуулгууд байдаг бөгөөд вэб дээр эдгээрийг
/// `toWords`-оор бөглөдөг. Апп дээр яг ижил бичвэр гарах ёстой тул логикийг нь
/// мөрөөр нь дагаж буулгав (mon_num@1.0.3 src/index.ts).
library;

const List<String> _digit = [
  'нэг', 'хоёр', 'гурав', 'дөрөв', 'тав', 'зургаа', 'долоо', 'найм', 'ес', 'тэг',
];

const List<String> _digitPrefix = [
  'нэг', 'хоёр', 'гурван', 'дөрвөн', 'таван', 'зургаан', 'долоон', 'найман', 'есөн',
];

const String _oneVariant = 'нэгэн';

const List<String> _tents = [
  'арав', 'хорь', 'гуч', 'дөч', 'тавь', 'жар', 'дал', 'ная', 'ер',
];

const List<String> _tentPrefix = [
  'арван', 'хорин', 'гучин', 'дөчин', 'тавин', 'жаран', 'далан', 'наян', 'ерэн',
];

const List<String> _tenPowers = ['зуу', 'мянга', 'сая', 'тэр бум', 'их наяд'];
const List<String> _tenPowersPrefix = [
  'зуун', 'мянган', 'сая', 'тэр бум', 'их наяд',
];

/// Дараа нь нэр дагадаг хэлбэр ("гурван зуун" гэх мэт).
String _urdakhKhelber(int num) {
  if (num < 10) {
    if (num == 0) return _digit[9];
    return _digitPrefix[num - 1];
  }
  if (num < 100) {
    if (num % 10 == 0) return _tentPrefix[(num ~/ 10) - 1];
    final base = num ~/ 10;
    final uldegdel = num - base * 10 - 1;
    return '${_tentPrefix[base - 1]} '
        '${uldegdel == 0 ? _oneVariant : _digitPrefix[uldegdel]}';
  }
  if (num < 1000) {
    final uldegdel = num % 100;
    if (uldegdel == 0) {
      return '${_digitPrefix[(num ~/ 100) - 1]} ${_tenPowersPrefix[0]}';
    }
    final base = num ~/ 100;
    if (uldegdel < 10) {
      return '${_digitPrefix[base - 1]} ${_tenPowersPrefix[0]} '
          '${uldegdel == 1 ? _oneVariant : _digitPrefix[uldegdel - 1]}';
    }
    return '${_digitPrefix[base - 1]} ${_tenPowersPrefix[0]} '
        '${_urdakhKhelber(uldegdel)}';
  }
  return '';
}

String _bichvereer(int num) {
  if (num < 10) {
    if (num == 0) return _digit[9];
    return _digit[num - 1];
  }
  if (num < 100) {
    if (num % 10 == 0) return _tents[(num ~/ 10) - 1];
    final base = num ~/ 10;
    return '${_tentPrefix[base - 1]} ${_digit[num - base * 10 - 1]}';
  }
  if (num < 1000) {
    final uldegdel = num % 100;
    if (uldegdel == 0) {
      return '${_digitPrefix[(num ~/ 100) - 1]} ${_tenPowers[0]}';
    }
    final base = num ~/ 100;
    return '${_digitPrefix[base - 1]} ${_tenPowersPrefix[0]} '
        '${_bichvereer(uldegdel)}';
  }

  // Мянга, сая, тэр бум, их наяд — бүгд ижил хэв маягтай.
  const khuvaaguud = [1000, 1000000, 1000000000, 1000000000000];
  for (var i = 0; i < khuvaaguud.length; i++) {
    final khuvaagch = khuvaaguud[i];
    final daraakh = i + 1 < khuvaaguud.length ? khuvaaguud[i + 1] : null;
    if (daraakh != null && num >= daraakh) continue;
    final uldegdel = num % khuvaagch;
    final khuvaasan = num ~/ khuvaagch;
    if (uldegdel == 0) {
      return '${_urdakhKhelber(khuvaasan)} ${_tenPowers[i + 1]}';
    }
    return '${_urdakhKhelber(khuvaasan)} ${_tenPowers[i + 1]} '
        '${_bichvereer(uldegdel)}';
  }
  return '';
}

/// Тоог үсгээр. Хэмжээнээс хэтэрсэн/буруу утганд хоосон мөр буцаана.
String monToWords(dynamic utga) {
  final num? too = utga is num ? utga : num.tryParse(utga?.toString() ?? '');
  if (too == null) return '';
  final butarkhaigui = too.round();
  if (butarkhaigui < 0 || butarkhaigui >= 1000000000000000) return '';
  return _bichvereer(butarkhaigui);
}
