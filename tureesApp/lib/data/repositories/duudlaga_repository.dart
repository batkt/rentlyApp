import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/duudlaga_model.dart';

final duudlagaRepositoryProvider = Provider<DuudlagaRepository>((ref) {
  return DuudlagaRepository(ref.read(dioClientProvider));
});

class DuudlagaRepository {
  final DioClient _client;

  DuudlagaRepository(this._client);

  Future<List<DuudlagaModel>> getDuudlagaList({
    required String baiguullagiinId,
    required String khariltsagchiinId,
    required String barilgiinId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = {
      'baiguullagiinId': baiguullagiinId,
      'khariltsagchiinId': khariltsagchiinId,
      'barilgiinId': barilgiinId,
    };

    final res = await _client.get(ApiConstants.duudlaga, queryParameters: {
      'query': jsonEncode(query),
      'khuudasniiDugaar': page,
      'khuudasniiKhemjee': pageSize,
      'order': jsonEncode({'createdAt': -1}),
    });

    final data = res.data;
    final list = (data['jagsaalt'] as List?) ?? [];
    // Filter for duudlaga type only, exclude requests/complaints
    return list
        .map((e) => DuudlagaModel.fromJson(e as Map<String, dynamic>))
        .where((d) =>
            d.duudlagiinTurul == 'duudlaga' ||
            d.duudlagiinTurul.isEmpty ||
            !['shaardlaga', 'gomdol', 'sanal', 'sanalKhuselt'].contains(d.duudlagiinTurul))
        .toList();
  }

  Future<DuudlagaModel> createDuudlaga({
    required String baiguullagiinId,
    required String khariltsagchiinId,
    required String barilgiinId,
    required String khariltsagchiinNer,
    required String khariltsagchiinUtas,
    required String title,
    required String message,
    String? khariltsagchiinGereeniiDugaar,
    String? khariltsagchiinTalbainDugaar,
    String? khariltsagchiinRegister,
  }) async {
    final res = await _client.post(ApiConstants.duudlaga, data: {
      'baiguullagiinId': baiguullagiinId,
      'khariltsagchiinId': khariltsagchiinId,
      'barilgiinId': barilgiinId,
      'title': title,
      'message': message,
      'duudlagiinTurul': 'duudlaga',
      'turul': 'duudlaga',
      'khariltsagchiinNer': khariltsagchiinNer,
      'khariltsagchiinUtas': khariltsagchiinUtas,
      if (khariltsagchiinGereeniiDugaar != null)
        'khariltsagchiinGereeniiDugaar': khariltsagchiinGereeniiDugaar,
      if (khariltsagchiinTalbainDugaar != null)
        'khariltsagchiinTalbainDugaar': khariltsagchiinTalbainDugaar,
      if (khariltsagchiinRegister != null)
        'khariltsagchiinRegister': khariltsagchiinRegister,
      'tukhainBaaziinKholbolt': 'default',
    });
    return DuudlagaModel.fromJson(res.data['data'] ?? res.data);
  }

  Future<void> updateStatus(String id, int tuluv, {String? tailbar}) async {
    await _client.put(ApiConstants.duudlagaUpdate(id), data: {
      'tuluv': tuluv,
      if (tailbar != null) 'tailbar': tailbar,
    });
  }
}
