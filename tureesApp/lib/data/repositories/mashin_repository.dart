import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/mashin_model.dart';

final mashinRepositoryProvider = Provider<MashinRepository>((ref) {
  return MashinRepository(ref.read(dioClientProvider));
});

class MashinRepository {
  final DioClient _client;

  MashinRepository(this._client);

  /// The tenant's own vehicles. Scoped by register the same way the web app
  /// does — a plate belongs to whoever registered it, not to a building.
  Future<List<MashinModel>> getMashinuud({
    required String baiguullagiinId,
    required String register,
  }) async {
    final res = await _client.get(ApiConstants.mashin, queryParameters: {
      'query': jsonEncode({
        'baiguullagiinId': baiguullagiinId,
        'ezemshigchiinRegister': register,
      }),
      'khuudasniiKhemjee': 999999,
    });

    final list = (res.data is Map ? res.data['jagsaalt'] as List? : null) ?? [];
    return list
        .map((e) => MashinModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((m) => m.dugaar.isNotEmpty)
        .toList();
  }

  /// Registers the plate in the parking module's Машин бүртгэл under
  /// `turul: "Түрээслэгч"`.
  ///
  /// `tuluv` (Үнэгүй / Хөнгөлөлттэй / Харилцагч) is deliberately left unset —
  /// it decides whether the car parks free, so the parking manager picks it.
  /// The contract fields mirror what the manager's own form writes
  /// (`components/pageComponents/zogsool/MashinBurtgel.js`), so the record
  /// lands in the Түрээслэгч list with its талбай, гэрээ and хугацаа filled.
  Future<void> addMashin({
    required String baiguullagiinId,
    required String barilgiinId,
    required String dugaar,
    required String ezemshigchiinId,
    required String ezemshigchiinNer,
    required String ezemshigchiinRegister,
    required String ezemshigchiinUtas,
    String? talbainDugaar,
    String? gereeniiId,
    String? gereeniiDugaar,
    String? ekhlekhOgnoo,
    String? duusakhOgnoo,
  }) async {
    await _client.post(ApiConstants.mashin, data: {
      'baiguullagiinId': baiguullagiinId,
      'barilgiinId': barilgiinId,
      'turul': 'Түрээслэгч',
      'dugaar': dugaar,
      'zogsooliinTurul': 'Гадна',
      'ezemshigchiinNer': ezemshigchiinNer,
      'ezemshigchiinRegister': ezemshigchiinRegister,
      'ezemshigchiinUtas': ezemshigchiinUtas,
      'ezemshigchiinId': ezemshigchiinId,
      if (talbainDugaar != null && talbainDugaar.isNotEmpty)
        'ezemshigchiinTalbainDugaar': talbainDugaar,
      if (gereeniiId != null && gereeniiId.isNotEmpty) 'gereeniiId': gereeniiId,
      if (gereeniiDugaar != null && gereeniiDugaar.isNotEmpty)
        'gereeniiDugaar': gereeniiDugaar,
      if (ekhlekhOgnoo != null) 'ekhlekhOgnoo': ekhlekhOgnoo,
      if (duusakhOgnoo != null) 'duusakhOgnoo': duusakhOgnoo,
    });
  }

  Future<void> deleteMashin(String id) async {
    await _client.delete(ApiConstants.mashinById(id));
  }
}
