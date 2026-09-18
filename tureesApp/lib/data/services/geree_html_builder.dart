import 'package:intl/intl.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/mon_num.dart';

/// Гэрээг өөрийнх нь загвартай нийлүүлж, вэб дээрх "Гэрээ харах" товч юу
/// үзүүлдэгтэй ижил HTML хуудас болгоно.
///
/// Загвар (`gereeniiZagvar`) дотор `&lt;talbainNegjUne&gt;` маягийн орлуулгууд
/// HTML-ээр escape хийгдсэн байдлаар хадгалагддаг. Вэб (turees
/// `pages/khyanalt/geree/gereeBurtgel` → `gereeKharya`) гэрээний талбар бүрээр
/// эдгээрийг сольж байж `components/pageComponents/geree/Kharakh.js`-д
/// дамжуулдаг. Апп дээр backend талын эндпойнт байхгүй тул яг тэр орлуулгыг
/// энд давтаж хийв.
class GereeHtmlBuilder {
  const GereeHtmlBuilder._();

  static final NumberFormat _tooFormat = NumberFormat('#,##0.00');

  /// [geree] — /geree/:id-аас ирсэн түүхий баримт.
  /// [zagvar] — /gereeniiZagvar/:id.
  /// [akt] — /aktiinZagvar/:id (гэрээнд холбогдсон бол).
  /// [barilga] — байгууллагын `barilguud`-аас олсон барилга (тамга, гарын үсэг,
  /// хаяг нь гэрээн дээр байхгүй үед эндээс нөхнө).
  static String bii({
    required Map<String, dynamic> geree,
    required Map<String, dynamic> zagvar,
    Map<String, dynamic>? akt,
    Map<String, dynamic>? barilga,
  }) {
    final beltgesen = _gereeBeltgeye(geree, barilga);

    final buff = StringBuffer();
    buff.write(_khuudas(zagvar, beltgesen));
    if (akt != null && akt.isNotEmpty) {
      buff.write(_khuudas(akt, beltgesen, garchig: 'Акт'));
    }
    return buff.toString();
  }

  // ── Нэг хуудас (гэрээ эсвэл акт) ──────────────────────────────────

  static String _khuudas(
    Map<String, dynamic> zagvar,
    Map<String, dynamic> geree, {
    String? garchig,
  }) {
    // Загварын бүх бичвэрийг нэг дор цуглуулж, орлуулгыг нэг удаа гүйлгэнэ.
    final zuunTolgoi = _mur(zagvar['zuunTolgoi']);
    final baruunTolgoi = _mur(zagvar['baruunTolgoi']);
    final zuunKhul = _mur(zagvar['zuunKhul']);
    final baruunKhul = _mur(zagvar['baruunKhul']);
    final zaaltuud = ((zagvar['dedKhesguud'] as List?) ?? [])
        .map((e) => _mur((e as Map?)?['zaalt']))
        .toList();

    final khesguud = <String>[
      zuunTolgoi,
      baruunTolgoi,
      zuunKhul,
      baruunKhul,
      ...zaaltuud,
    ];
    _orluulya(khesguud, geree);

    // Загварт нэр байхгүй бол вэб толгой/хөлийг нь огт үзүүлдэггүй.
    final nertei = _mur(zagvar['ner']).isNotEmpty;

    final buff = StringBuffer();
    if (garchig != null) {
      buff.write('<div class="khuudasniiGarchig">$garchig</div>');
    }
    buff.write('<div class="gereeniiKhuudas">');
    if (nertei) {
      buff.write(
        '<div class="khoyorBagana">'
        '<div>${khesguud[0]}</div>'
        '<div>${khesguud[1]}</div>'
        '</div>',
      );
    }
    for (var i = 4; i < khesguud.length; i++) {
      buff.write('<div class="zaalt">${khesguud[i]}</div>');
    }
    if (nertei) {
      buff.write(
        '<div class="khoyorBagana">'
        '<div>${khesguud[2]}</div>'
        '<div>${khesguud[3]}</div>'
        '</div>',
      );
    }
    buff.write('</div>');
    return buff.toString();
  }

  // ── Гэрээний утгуудыг орлуулгад бэлдэх ────────────────────────────

  static Map<String, dynamic> _gereeBeltgeye(
    Map<String, dynamic> geree,
    Map<String, dynamic>? barilga,
  ) {
    final g = Map<String, dynamic>.from(geree);
    final orgId = _mur(g['baiguullagiinId']);

    if (_mur(g['barilgiinKhayag']).isEmpty) {
      g['barilgiinKhayag'] = _mur(barilga?['khayag']);
    }

    final ekhlekh = _ognoo(g['gereeniiOgnoo']);
    if (ekhlekh != null) {
      g['ekhlekhOn'] = DateFormat('yyyy').format(ekhlekh);
      // Вэб дээрх талбарын нэр яг ийм бичигдсэн (ekhelkhSar) — загварууд
      // түүгээр нь орлуулга хийдэг тул засаж болохгүй.
      g['ekhelkhSar'] = DateFormat('MM').format(ekhlekh);
      g['ekhlekhUdur'] = DateFormat('dd').format(ekhlekh);

      final khugatsaa = _toon(g['khugatsaa']);
      if (khugatsaa > 0) {
        final duusakh = _ognoo(g['duusakhOgnoo']);
        if (duusakh != null) {
          g['duusakhOn'] = DateFormat('yyyy').format(duusakh);
          g['duusakhSar'] = DateFormat('MM').format(duusakh);
          g['duusakhUdur'] = DateFormat('dd').format(duusakh);
        }
      }
    }

    g['talbainNegjUneUsgeer'] = monToWords(g['talbainNegjUne']);
    g['talbainNiitUneUsgeer'] = monToWords(g['talbainNiitUne']);
    final baritsaa = _toon(g['baritsaaAvakhDun']);
    g['baritsaaAvakhDunUsgeer'] = baritsaa > 0 ? monToWords(baritsaa) : '';

    // Тамга, гарын үсэг — вэб дээрх шиг үнэмлэхүй байрлалтай зураг.
    g['gariinUseg'] = _zuragBlok(
      turul: 'gariinUseg',
      orgId: orgId,
      id: _mur(barilga?['gariinUseg']),
      urgun: 100,
      undur: 50,
      shiljilt: 'translate(-50%, -30%)',
    );
    g['tamga'] = _zuragBlok(
      turul: 'tamga',
      orgId: orgId,
      id: _mur(barilga?['tamga']),
      urgun: 115,
      undur: 100,
      shiljilt: 'translate(-10%, -50%)',
    );
    g['gereeniiTamga'] = _zuragBlok(
      turul: 'gereeniiTamga',
      orgId: orgId,
      id: _mur(barilga?['gereeniiTamga']),
      urgun: 115,
      undur: 100,
      shiljilt: 'translate(-10%, -50%)',
    );

    if (ekhlekh != null) {
      g['gereeniiOgnoo'] = DateFormat('yyyy/MM/dd').format(ekhlekh);
    }

    return g;
  }

  static String _zuragBlok({
    required String turul,
    required String orgId,
    required String id,
    required int urgun,
    required int undur,
    required String shiljilt,
  }) {
    if (id.isEmpty || orgId.isEmpty) return '';
    final src = ApiConstants.zuragAvyaTuruleer(turul, orgId, id);
    return '<span style="position:absolute;z-index:1;">'
        '<img src="$src" style="width:${urgun}px;height:${undur}px;'
        'transform:$shiljilt;opacity:0.9;" />'
        '</span>';
  }

  // ── Орлуулга ──────────────────────────────────────────────────────

  static void _orluulya(List<String> khesguud, Map<String, dynamic> geree) {
    void sold(String tulkhuur, String utga) {
      if (tulkhuur.isEmpty) return;
      final khee = RegExp(
        RegExp.escape('&lt;$tulkhuur&gt;'),
        caseSensitive: false,
      );
      for (var i = 0; i < khesguud.length; i++) {
        if (!khesguud[i].contains('&lt;')) continue;
        khesguud[i] = khesguud[i].replaceAll(khee, utga);
      }
    }

    geree.forEach((tulkhuur, utga) {
      if (tulkhuur == 'zardluud' && utga is List) {
        _zardliinOrluulga(utga, sold);
        return;
      }
      if (tulkhuur == 'segmentuud' && utga is List) {
        for (final segment in utga) {
          if (segment is! Map) continue;
          sold(_mur(segment['ner']), _mur(segment['utga']));
        }
        return;
      }
      if (tulkhuur == 'utas') {
        final utas = utga is List && utga.isNotEmpty ? _mur(utga.first) : '';
        sold(tulkhuur, utas);
        return;
      }
      // Мөнгөн дүнгүүд гэрээн дээр таслалтай харагддаг.
      if (tulkhuur == 'talbainNegjUne' ||
          tulkhuur == 'talbainNiitUne' ||
          tulkhuur == 'baritsaaAvakhDun') {
        sold(tulkhuur, _too(utga));
        return;
      }
      // Массив/объект талбарууд (guilgeenuud, avlaga гэх мэт) загвар дээр
      // орлуулга болж хэрэглэгддэггүй — оруулбал зүгээр л хог бичвэр болно.
      if (utga is List || utga is Map) return;
      sold(tulkhuur, utga == null ? '' : utga.toString());
    });
  }

  static void _zardliinOrluulga(
    List zardluud,
    void Function(String tulkhuur, String utga) sold,
  ) {
    num niitDun = 0;
    num nuatguiDun = 0;
    num nuattaiDun = 0;
    for (final mur in zardluud) {
      if (mur is! Map) continue;
      final tulukhDun = _toon(mur['tulukhDun']);
      final dun = tulukhDun != 0 ? tulukhDun : _toon(mur['dun']);
      niitDun += dun;
      if (mur['nuatNemekhEsekh'] == true) {
        nuattaiDun += dun;
      } else {
        nuatguiDun += dun;
      }
    }
    sold('niitZardliinDun', _too(niitDun));
    sold('niitZardliinNuatguiDun', _too(nuatguiDun));
    sold('niitZardliinNuatiinDun', _too((nuattaiDun / 11).round()));

    for (final mur in zardluud) {
      if (mur is! Map) continue;
      final ner = _mur(mur['ner']);
      if (ner.isEmpty) continue;
      final tariff = _toon(mur['tariff']) != 0 ? mur['tariff'] : mur['dun'];
      final talbaruud = <String, String>{
        'tariff': _too(tariff),
        'tariffUsgeer': _mur(mur['tariffUsgeer']),
        'tulukhDun': _too(mur['tulukhDun']),
        'dun': _too(mur['dun']),
        'negj': _mur(mur['turul']),
        'khemjikhNegj': _mur(mur['turul']),
        'umnukhZaalt': _too(mur['umnukhZaalt'] ?? 0),
        'suuliinZaalt': _too(mur['suuliinZaalt'] ?? 0),
        'khungulult': _too(mur['khungulult'] ?? 0),
      };
      talbaruud.forEach((talbar, utga) => sold('$ner.$talbar', utga));
    }
  }

  // ── Жижиг туслахууд ───────────────────────────────────────────────

  static String _mur(dynamic utga) => utga?.toString() ?? '';

  static num _toon(dynamic utga) =>
      utga is num ? utga : (num.tryParse(_mur(utga)) ?? 0);

  static String _too(dynamic utga) => _tooFormat.format(_toon(utga));

  static DateTime? _ognoo(dynamic utga) {
    final parsed = DateTime.tryParse(_mur(utga));
    return parsed?.toLocal();
  }
}
