import 'dart:convert';
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
    int? tuluv,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = {
      'register': register,
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
}
