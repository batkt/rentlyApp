import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/socket/socket_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(secureStorageProvider),
    ref.read(socketServiceProvider),
    ref.read(biometricServiceProvider),
  );
});

/// Additional app users the tenant created in the web portal. Shown in
/// Профайл so they can see who else has access to their contracts.
final nemeltKhereglegchidProvider = FutureProvider<List<UserModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.id.isEmpty) return [];
  return ref.read(authRepositoryProvider).nemeltKhereglegchid(
        baiguullagiinId: user.baiguullagiinId,
        nemegchiiId: user.id,
      );
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authStateProvider).user;
});

final selectedBarilgiinIdProvider = Provider<String>((ref) {
  final s = ref.watch(authStateProvider);
  return s.selectedBarilgiinId ?? s.user?.barilgiinId ?? '';
});

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final bool isAuthenticated;
  final String? error;
  final List<OrgSelectionModel> orgOptions;
  final String? pendingPhone;
  final String? pendingPassword;
  final List<({String id, String ner})> barilguud;
  final String? selectedBarilgiinId;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.isAuthenticated = false,
    this.error,
    this.orgOptions = const [],
    this.pendingPhone,
    this.pendingPassword,
    this.barilguud = const [],
    this.selectedBarilgiinId,
  });

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    bool? isAuthenticated,
    String? error,
    List<OrgSelectionModel>? orgOptions,
    String? pendingPhone,
    String? pendingPassword,
    List<({String id, String ner})>? barilguud,
    String? selectedBarilgiinId,
    bool clearSelectedBarilgiinId = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      orgOptions: orgOptions ?? this.orgOptions,
      pendingPhone: pendingPhone ?? this.pendingPhone,
      pendingPassword: pendingPassword ?? this.pendingPassword,
      barilguud: barilguud ?? this.barilguud,
      selectedBarilgiinId: clearSelectedBarilgiinId ? null : (selectedBarilgiinId ?? this.selectedBarilgiinId),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final SecureStorageService _storage;
  final SocketService _socket;
  final BiometricService _biometric;

  AuthNotifier(this._repo, this._storage, this._socket, this._biometric)
      : super(const AuthState());

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final isLoggedIn = await _storage.isLoggedIn();
      if (isLoggedIn) {
        final user = await _repo.getUserByToken();
        if (user != null) {
          // Load from cache; if empty, fetch from server in background
          var barilguud = await _loadBarilguud();
          state = state.copyWith(isLoading: false, user: user, isAuthenticated: true, barilguud: barilguud);
          await _socket.connect();
          _socket.joinOrgRoom(user.baiguullagiinId);
          _socket.joinUserRoom(user.id);
          PushNotificationService.instance.registerToken((token) => _repo.saveFcmToken(user.id, token));
          _refreshBarilguud(user.baiguullagiinId);
          return;
        }
      }
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  void _refreshBarilguud(String orgId) async {
    try {
      final fetched = await _repo.getBarilguud(orgId);
      if (fetched.isNotEmpty) {
        await _storage.saveBuildings(jsonEncode(
          fetched.map((b) => {'id': b.id, 'ner': b.ner}).toList(),
        ));
        state = state.copyWith(barilguud: fetched);
      }
    } catch (_) {}
  }

  Future<LoginResult> login(String phone, String password, {String? baiguullagiinId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.login(
        phone: phone,
        password: password,
        baiguullagiinId: baiguullagiinId,
      );

      if (data['multipleOrgs'] == true) {
        final baiguullaguud = data['baiguullaguud'] as List?;
        final orgs = (baiguullaguud ?? []).map((e) => OrgSelectionModel.fromJson(e as Map<String, dynamic>)).toList();
        state = state.copyWith(
          isLoading: false,
          orgOptions: orgs,
          pendingPhone: phone,
          pendingPassword: password,
        );
        return LoginResult.needsOrgSelection;
      }

      return await _handleLoginSuccess(data, phone);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return LoginResult.error;
    }
  }

  Future<LoginResult> loginWithOrg(OrgSelectionModel org) async {
    if (state.pendingPhone == null || state.pendingPassword == null) {
      return LoginResult.error;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.login(
        phone: state.pendingPhone!,
        password: state.pendingPassword!,
        baiguullagiinId: org.id,
        barilgiinId: org.barilgiinId,
      );
      return await _handleLoginSuccess(data, state.pendingPhone!);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return LoginResult.error;
    }
  }

  Future<LoginResult> _handleLoginSuccess(Map<String, dynamic> data, String phone) async {
    final token = data['token']?.toString() ?? '';
    final khariltsagch = data['result'] as Map<String, dynamic>?;

    if (token.isEmpty || khariltsagch == null) {
      state = state.copyWith(isLoading: false, error: 'Нэвтрэх мэдээлэл буруу байна');
      return LoginResult.error;
    }

    await _storage.saveToken(token);
    final user = UserModel.fromJson({...khariltsagch, 'token': token});

    await _storage.saveUserData(
      role: user.zochinTurul,
      orgId: user.baiguullagiinId,
      buildingId: user.barilgiinId,
      userId: user.id,
      phone: phone,
      userName: user.ner,
      userRegister: user.register,
    );

    // Fetch org buildings fresh on every login so the dashboard selector is populated
    var barilguud = await _repo.getBarilguud(user.baiguullagiinId);
    if (barilguud.isNotEmpty) {
      await _storage.saveBuildings(jsonEncode(
        barilguud.map((b) => {'id': b.id, 'ner': b.ner}).toList(),
      ));
    } else {
      barilguud = await _loadBarilguud();
    }
    state = state.copyWith(isLoading: false, user: user, isAuthenticated: true, barilguud: barilguud);
    await _socket.connect();
    _socket.joinOrgRoom(user.baiguullagiinId);
    _socket.joinUserRoom(user.id);
    PushNotificationService.instance.registerToken((token) => _repo.saveFcmToken(user.id, token));
    return LoginResult.success;
  }

  /// Ask the server whether this account still exists. Returns true when it
  /// was deleted (or deactivated) — the caller shows the warning and signs out.
  Future<bool> erkhUstsanEsekhShalgaya() async {
    if (!state.isAuthenticated) return false;
    final tuluv = await _repo.khereglegchShalgaya();
    if (tuluv != KhereglegchiinTuluv.ustsan) return false;
    await logout();
    return true;
  }

  Future<void> logout() async {
    _socket.disconnect();
    await _storage.clearAll();
    state = const AuthState();
  }

  Future<void> reloadBarilguud() async {
    final barilguud = await _loadBarilguud();
    state = state.copyWith(barilguud: barilguud);
  }

  Future<void> switchBuilding(String barilgiinId) async {
    await _storage.write('selected_barilgiinId', barilgiinId);
    state = state.copyWith(selectedBarilgiinId: barilgiinId);
  }

  Future<List<({String id, String ner})>> _loadBarilguud() async {
    try {
      final json = await _storage.getBuildings();
      if (json == null || json.isEmpty) return [];
      final list = jsonDecode(json) as List;
      return list
          .map((e) => (id: (e['id'] ?? '').toString(), ner: (e['ner'] ?? '').toString()))
          .where((b) => b.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final serverMsg = data['aldaa'] ?? data['message'];
        if (serverMsg != null) return serverMsg.toString();
      }
      if (e.response?.statusCode == 401) return 'Нууц үг буруу байна';
      if (e.response?.statusCode == 404) return 'Хэрэглэгч олдсонгүй';
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return 'Холболтын хугацаа дууссан';
      }
      if (e.type == DioExceptionType.connectionError) return 'Интернет холболт байхгүй';
    }
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) return 'Нууц үг буруу байна';
    if (msg.contains('404')) return 'Хэрэглэгч олдсонгүй';
    if (msg.contains('SocketException')) return 'Интернет холболт байхгүй';
    return 'Алдаа гарлаа. Дахин оролдоно уу';
  }

  /// Every failure path used to return `false` silently, so a tap on
  /// "Face ID-ээр нэвтрэх" that could not work looked like a dead button.
  /// Each one now leaves a message in [AuthState.error], which LoginScreen
  /// already surfaces as a snackbar.
  Future<bool> loginWithBiometric() async {
    final hasToken = await _storage.isLoggedIn();
    if (!hasToken) {
      state = state.copyWith(
        error: 'Хадгалсан нэвтрэлт олдсонгүй. Утасны дугаар, нууц үгээрээ нэвтэрнэ үү',
      );
      return false;
    }

    if (!await _biometric.isEnrolled) {
      state = state.copyWith(
        error: 'Face ID / хурууны хээ тохируулаагүй байна. Утасныхаа тохиргооноос идэвхжүүлнэ үү',
      );
      return false;
    }

    final authenticated = await _biometric.authenticate();
    if (!authenticated) {
      final kod = _biometric.lastError;
      state = state.copyWith(
        error: kod == 'LockedOut' || kod == 'PermanentlyLockedOut'
            ? 'Олон удаа буруу оролдсон тул түр хаагдсан байна. Нууц үгээрээ нэвтэрнэ үү'
            : 'Баталгаажуулалт амжилтгүй боллоо',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.getUserByToken();
      if (user != null) {
        state = state.copyWith(isLoading: false, user: user, isAuthenticated: true);
        await _socket.connect();
        _socket.joinOrgRoom(user.baiguullagiinId);
        _socket.joinUserRoom(user.id);
        return true;
      }
      // The token is no longer good — drop it so the button stops promising
      // a login that cannot happen.
      await _storage.clearAll();
      state = state.copyWith(
        isLoading: false,
        error: 'Нэвтрэх хугацаа дууссан байна. Дахин нэвтэрнэ үү',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Сервертэй холбогдож чадсангүй. Интернэтээ шалгана уу',
      );
      return false;
    }
  }

  Future<void> enableBiometric() async {
    await _storage.saveBiometricEnabled(true);
  }

  Future<bool> isBiometricEnabled() async {
    return _storage.isBiometricEnabled();
  }

  void clearError() => state = state.copyWith(error: null);
}

enum LoginResult { success, needsOrgSelection, error }
