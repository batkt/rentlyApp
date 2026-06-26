import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/agreement_model.dart';

final agreementRepositoryProvider = Provider<AgreementRepository>((ref) {
  return AgreementRepository(ref.read(dioClientProvider));
});

class AgreementRepository {
  final DioClient _client;

  AgreementRepository(this._client);

  Future<List<AgreementModel>> getAgreements({
    required String register,
    String? barilgiinId,
    int? tuluv,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = {
      'register': register,
      if (barilgiinId != null && barilgiinId.isNotEmpty) 'barilgiinId': barilgiinId,
      if (tuluv != null) 'tuluv': tuluv,
    };

    final res = await _client.get(ApiConstants.geree, queryParameters: {
      'query': jsonEncode(query),
      'khuudasniiDugaar': page,
      'khuudasniiKhemjee': pageSize,
    });

    final data = res.data;
    final list = data['jagsaalt'] as List? ?? [];
    return list.map((e) => AgreementModel.fromJson(e)).toList();
  }

  Future<AgreementModel?> getAgreementById(String id) async {
    try {
      final res = await _client.get('${ApiConstants.geree}/$id');
      return AgreementModel.fromJson(res.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getBalance(String gereeniiDugaar, String barilgiinId) async {
    final res = await _client.post(ApiConstants.gereeBalance, data: {
      'gereeniiDugaar': gereeniiDugaar,
      'barilgiinId': barilgiinId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUldegdel(String gereeniiDugaar, String barilgiinId) async {
    final res = await _client.post(ApiConstants.uldegdelBodyo, data: {
      'gereeniiDugaar': gereeniiDugaar,
      'barilgiinId': barilgiinId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getInvoiceHistory(String gereeniiId) async {
    final query = {'gereeniiId': gereeniiId};
    final res = await _client.get(ApiConstants.invoiceHistory, queryParameters: {
      'query': jsonEncode(query),
      'khuudasniiDugaar': 1,
      'khuudasniiKhemjee': 999999,
    });
    return ((res.data['jagsaalt'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  /// Bank account number (dansniiDugaar) from the latest invoice history.
  /// Used as the required `dansniiDugaar` field when generating a QPay invoice.
  Future<String?> getDansniiDugaar(String gereeniiId) async {
    try {
      final history = await getInvoiceHistory(gereeniiId);
      if (history.isEmpty) return null;
      history.sort((a, b) {
        final ad = (a['nekhemjlekhiinOgnoo'] ?? a['createdAt'] ?? '').toString();
        final bd = (b['nekhemjlekhiinOgnoo'] ?? b['createdAt'] ?? '').toString();
        return bd.compareTo(ad);
      });
      return history.first['nekhemjlekhiinDans']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<double> getNiitUldegdel(String gereeniiDugaar, String barilgiinId) async {
    final res = await getUldegdel(gereeniiDugaar, barilgiinId);
    return double.tryParse(res['uldegdel']?.toString() ?? '0') ?? 0.0;
  }

  /// Fetches outstanding balances for multiple agreements in one request.
  /// Returns map of { gereeniiId → {uldegdel, aldangiinUldegdel, ...} }.
  Future<Map<String, Map<String, dynamic>>> getBulkUldegdel(
    List<String> gereeniiIds, {
    String? barilgiinId,
    String? baiguullagiinId,
  }) async {
    if (gereeniiIds.isEmpty) return {};
    final res = await _client.post(ApiConstants.bulkUldegdelBodyo, data: {
      'gereeniiIds': gereeniiIds,
      if (barilgiinId != null && barilgiinId.isNotEmpty) 'barilgiinId': barilgiinId,
      if (baiguullagiinId != null && baiguullagiinId.isNotEmpty) 'baiguullagiinId': baiguullagiinId,
    });
    final data = res.data as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, (v as Map<String, dynamic>? ?? {})));
  }

  /// Fetches the payment breakdown for the month of [ognoo] for agreement [gereeniiId].
  /// Returns raw map with keys: umnukhSariinTulsun, umnukhSariinUrTulbur,
  /// niitUldegdel, eneSardTulukhDun, nekhemjlekhDeerGarakh, baritsaaAshiglasanDun.
  Future<Map<String, dynamic>> getTulburZadargaa(String gereeniiId, String ognoo) async {
    final date = DateTime.tryParse(ognoo) ?? DateTime.now();
    final year = date.year;
    final month = date.month;
    final start = '$year-${month.toString().padLeft(2, '0')}-01 00:00:00';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')} 23:59:59';
    final res = await _client.post(ApiConstants.tulburiinZadargaaAvya, data: {
      'id': gereeniiId,
      'ekhlekhOgnoo': start,
      'duusakhOgnoo': end,
      'nekhemjlekhAvakhOgnoo': end,
    });
    final list = res.data as List?;
    return (list != null && list.isNotEmpty) ? (list.first as Map<String, dynamic>) : {};
  }

  Future<String> uploadImage(File file, String baiguullagiinId) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: 'image.jpg'),
      'turul': 'jpg',
      'baiguullagiinId': baiguullagiinId,
    });
    final res = await _client.postFormData(ApiConstants.zuragKhadgalya, formData);
    return res.data['id']?.toString() ?? '';
  }

  Future<String> uploadFile(File file, String baiguullagiinId, String originalName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: originalName),
      'baiguullagiinId': baiguullagiinId,
    });
    final res = await _client.postFormData(ApiConstants.fileKhadgalya, formData);
    return res.data['id']?.toString() ?? '';
  }

  Future<void> saveZurguud(String gereeniiId, List<dynamic> zurguud) async {
    await _client.post(ApiConstants.gereeniiZurguudKhadgalakh, data: {
      'gereeniiId': gereeniiId,
      'zurguud': zurguud,
    });
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory(String gereeniiId) async {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final duusakhOgnoo =
        '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')} 23:59:59';
    final res = await _client.get(
      ApiConstants.gereeniiTulultAvya(gereeniiId),
      queryParameters: {'duusakhOgnoo': duusakhOgnoo},
    );
    final data = res.data;
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
