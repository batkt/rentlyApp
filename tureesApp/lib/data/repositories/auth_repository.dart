import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioClientProvider));
});

class AuthRepository {
  final DioClient _client;

  AuthRepository(this._client);

  Future<Map<String, dynamic>> verifyPhone(String phone) async {
    final res = await _client.post(ApiConstants.verifyPhone, data: {'utas': phone});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
    String? baiguullagiinId,
    String? barilgiinId,
  }) async {
    final hasOrg = baiguullagiinId != null && baiguullagiinId.isNotEmpty;
    final endpoint = hasOrg ? ApiConstants.loginWithOrg : ApiConstants.login;

    final data = {
      'utas': phone,
      'nuutsUg': password,
      'userAgent': 'TureesApp/1.0 (Mobile)',
      if (hasOrg) 'baiguullagiinId': baiguullagiinId,
      if (barilgiinId != null && barilgiinId.isNotEmpty) 'barilgiinId': barilgiinId,
    };

    final res = await _client.post(endpoint, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<UserModel?> getUserByToken() async {
    try {
      final res = await _client.post(ApiConstants.getUserByToken);
      final data = res.data;
      if (data != null) {
        return UserModel.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    // Step 1: verify phone and get user + one-time token
    final checkRes = await _client.post(
      ApiConstants.resetPasswordCheck,
      data: {'utas': phone},
    );
    final checkData = checkRes.data as Map<String, dynamic>;
    final token = checkData['token']?.toString();
    final khariltsagch = checkData['result'] as Map<String, dynamic>?;

    if (token == null || khariltsagch == null) {
      throw Exception('Хэрэглэгч олдсонгүй');
    }
    final id = khariltsagch['_id']?.toString();
    if (id == null || id.isEmpty) throw Exception('Хэрэглэгч олдсонгүй');

    // Step 2: update password using the returned token
    final updated = Map<String, dynamic>.from(khariltsagch);
    updated['nuutsUg'] = newPassword;
    await _client.put(
      '${ApiConstants.khariltsagch}/$id',
      data: updated,
      options: Options(headers: {'Authorization': 'bearer $token'}),
    );
  }
}
