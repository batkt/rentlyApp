import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// zevtabs админ (Хувилбар → төсөл «Turees») дээр бүртгэсэн аппын хувилбар.
/// systemiinUdirdlaga: GET /app-version/Turees/:platform (нэвтрэлтгүй).
class KhuvilbarMedeelel {
  final String version;
  final String minVersion;
  final bool zaaval;
  final String updateUrl;
  final String message;

  const KhuvilbarMedeelel({
    required this.version,
    required this.minVersion,
    required this.zaaval,
    required this.updateUrl,
    required this.message,
  });
}

class KhuvilbarService {
  KhuvilbarService._();

  static const _url = 'https://admin.zevtabs.mn/api/app-version/Turees';
  static const _androidId = 'mn.zevtabs.turees_app';
  static const _iosBundleId = 'mn.zevtabs.rently';
  static const _algassanTulkhuur = 'khuvilbar_algassan';

  static const defaultMessage =
      'Аппликейшнд нэмэлт өөрчлөлт орсон тул дахин татаж суулгаарай. '
      'Хэрэв шинэчлэлт хийгээгүй тохиолдолд аппликейшнийг бүрэн ашиглах '
      'боломжгүй.';

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Шинэчлэх шаардлагатай бол мэдээллийг, үгүй бол null буцаана.
  /// Сүлжээний алдаа гарвал апп ашиглахад саад болохгүй — null.
  static Future<KhuvilbarMedeelel?> shalgakh() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final res = await _dio.get('$_url/$platform');
      final data = res.data;
      if (data is! Map) return null;

      final shine = (data['version'] ?? '').toString().trim();
      final min = (data['minVersion'] ?? '').toString().trim();
      final zaavalTug = data['isForceUpdate'] == true || data['zaavalEsekh'] == true;
      if (shine.isEmpty) return null;

      final odoo = (await PackageInfo.fromPlatform()).version;
      final shineniiKhuvilbar = _ikh(shine, odoo);
      final minoosDoosh = min.isNotEmpty && _ikh(min, odoo);
      if (!shineniiKhuvilbar && !minoosDoosh) return null;

      final zaaval = minoosDoosh || (zaavalTug && shineniiKhuvilbar);
      if (!zaaval) {
        // «Дараа нь» дарсан хувилбарыг дахин санал болгохгүй.
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(_algassanTulkhuur) == shine) return null;
      }

      final message = (data['message'] ?? '').toString().trim();
      return KhuvilbarMedeelel(
        version: shine,
        minVersion: min,
        zaaval: zaaval,
        updateUrl: (data['updateUrl'] ?? '').toString().trim(),
        message: message.isNotEmpty ? message : defaultMessage,
      );
    } catch (e) {
      debugPrint('[Khuvilbar] шалгаж чадсангүй: $e');
      return null;
    }
  }

  static Future<void> algasakh(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_algassanTulkhuur, version);
  }

  /// Админ дээр оруулсан холбоос, байхгүй бол store-ын холбоос.
  static Future<String> storeUrl(KhuvilbarMedeelel m) async {
    if (m.updateUrl.isNotEmpty) return m.updateUrl;
    if (Platform.isAndroid) {
      return 'https://play.google.com/store/apps/details?id=$_androidId';
    }
    try {
      final res = await _dio.get(
        'https://itunes.apple.com/lookup',
        queryParameters: {'bundleId': _iosBundleId, 'country': 'mn'},
      );
      // iTunes нь text/javascript төрлөөр буцаадаг тул String ирж болно.
      final data = res.data is String ? jsonDecode(res.data as String) : res.data;
      final url = (data?['results'] as List?)?.firstOrNull?['trackViewUrl'];
      if (url is String && url.isNotEmpty) return url;
    } catch (_) {}
    return 'https://apps.apple.com/mn/search?term=rently';
  }

  /// a > b эсэх («1.22.0» > «1.21.1»). Дутуу хэсэг 0.
  static bool _ikh(String a, String b) {
    List<int> zadal(String v) => v
        .split('+')
        .first
        .split('.')
        .map((x) => int.tryParse(x.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final x = zadal(a), y = zadal(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0;
      final yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi > yi;
    }
    return false;
  }
}
