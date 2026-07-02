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

  Future<List<({String id, String ner})>> getBarilguud(String orgId) async {
    try {
      final res = await _client.get('${ApiConstants.organization}/$orgId');
      final data = res.data as Map<String, dynamic>?;
      if (data == null) return [];
      final list = data['barilguud'] as List? ?? [];
      return list
          .map((b) => (id: (b['_id'] ?? '').toString(), ner: (b['ner'] ?? '').toString()))
          .where((b) => b.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> verifyPhone(String phone) async {
    final res = await _client.post(ApiConstants.verifyPhone, data: {'utas': phone});
    return res.data as Map<String, dynamic>;
  }

  Future<void> saveFcmToken(String khariltsagchId, String fcmToken) async {
    await _client.post(ApiConstants.khariltsagchidTokenOnooyo, data: {
      'id': khariltsagchId,
      'token': fcmToken,
    });
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

    final updated = Map<String, dynamic>.from(khariltsagch);
    updated['nuutsUg'] = newPassword;
    await _client.put(
      '${ApiConstants.khariltsagch}/$id',
      data: updated,
      options: Options(headers: {'Authorization': 'bearer $token'}),
    );
  }

  /// Step 1 of OTP password recovery: sends a 6-digit code to the phone via SMS.
  /// Returns the khariltsagch._id needed for step 2.
  Future<String> sendRecoveryCode(String phone) async {
    // ignore: avoid_print
    print('[OTP] Sending recovery code to phone: $phone');
    final res = await _client.post(
      ApiConstants.sergeekhKodAvya,
      data: {'utas': phone},
    );
    // ignore: avoid_print
    print('[OTP] sendRecoveryCode response: status=${res.statusCode} data=${res.data}');
    final id = res.data?.toString() ?? '';
    // ignore: avoid_print
    print('[OTP] Parsed khariltsagch id: "$id"');
    return id;
  }

  /// Step 2: verifies the code. Returns a one-time token.
  Future<String> verifyRecoveryCode(String id, String code) async {
    // ignore: avoid_print
    print('[OTP] Verifying code: id=$id code=$code');
    final res = await _client.post(
      ApiConstants.nuutsUgSergeeye,
      data: {'id': id, 'sergeekhKod': code},
    );
    // ignore: avoid_print
    print('[OTP] verifyRecoveryCode response: status=${res.statusCode} data=${res.data}');
    final data = res.data as Map<String, dynamic>;
    final token = data['token']?.toString() ?? '';
    // ignore: avoid_print
    print('[OTP] Parsed token: "${token.isEmpty ? "EMPTY" : "ok (${token.length} chars)"}');
    return token;
  }

  /// Step 3: updates the password using the one-time token from step 2.
  Future<void> updatePassword(String id, String newPassword, String token) async {
    await _client.put(
      '${ApiConstants.khariltsagch}/$id',
      data: {'nuutsUg': newPassword},
      options: Options(headers: {'Authorization': 'bearer $token'}),
    );
  }
}
