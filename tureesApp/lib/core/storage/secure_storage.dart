import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveToken(String token) async {
    await _storage.write(key: StorageKeys.token, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: StorageKeys.token);
  }

  Future<void> saveUserData({
    required String role,
    required String orgId,
    required String buildingId,
    required String userId,
    required String phone,
    String? userName,
    String? userRegister,
  }) async {
    await Future.wait([
      _storage.write(key: StorageKeys.userRole, value: role),
      _storage.write(key: StorageKeys.orgId, value: orgId),
      _storage.write(key: StorageKeys.buildingId, value: buildingId),
      _storage.write(key: StorageKeys.userId, value: userId),
      _storage.write(key: StorageKeys.phone, value: phone),
      if (userName != null) _storage.write(key: StorageKeys.userName, value: userName),
      if (userRegister != null) _storage.write(key: StorageKeys.userRegister, value: userRegister),
    ]);
  }

  Future<Map<String, String?>> getUserData() async {
    final results = await Future.wait([
      _storage.read(key: StorageKeys.token),
      _storage.read(key: StorageKeys.userRole),
      _storage.read(key: StorageKeys.orgId),
      _storage.read(key: StorageKeys.buildingId),
      _storage.read(key: StorageKeys.userId),
      _storage.read(key: StorageKeys.phone),
      _storage.read(key: StorageKeys.userName),
      _storage.read(key: StorageKeys.userRegister),
    ]);
    return {
      StorageKeys.token: results[0],
      StorageKeys.userRole: results[1],
      StorageKeys.orgId: results[2],
      StorageKeys.buildingId: results[3],
      StorageKeys.userId: results[4],
      StorageKeys.phone: results[5],
      StorageKeys.userName: results[6],
      StorageKeys.userRegister: results[7],
    };
  }

  Future<void> clearAll() async {
    final biometricEnabled = await isBiometricEnabled();
    await _storage.deleteAll();
    if (biometricEnabled) {
      await saveBiometricEnabled(true);
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled ? 'true' : 'false');
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: 'biometric_enabled');
    return val == 'true';
  }

  Future<void> saveBuildings(String json) async {
    await _storage.write(key: 'barilguud', value: json);
  }

  Future<String?> getBuildings() async {
    return await _storage.read(key: 'barilguud');
  }

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }
}
