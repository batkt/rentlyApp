import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Flipped when the server rejects our token — the account was deleted or
/// deactivated. HomeScreen watches it to warn the user and sign them out.
final erkhTsutslagdsanProvider = StateProvider<bool>((ref) => false);

final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.read(secureStorageProvider);
  final client = DioClient(storage);
  client.onErkhTsutslagdsan =
      () => ref.read(erkhTsutslagdsanProvider.notifier).state = true;
  return client;
});

class DioClient {
  late final Dio _dio;
  final SecureStorageService _storage;

  /// Called when the server rejects the stored token — the account was
  /// deleted or deactivated while the app was still holding a session.
  void Function()? onErkhTsutslagdsan;

  /// Endpoints where a 401 means "wrong credentials", not "account gone".
  static bool _nevtrekhZam(String path) {
    const zamuud = [
      ApiConstants.login,
      ApiConstants.loginWithOrg,
      ApiConstants.verifyPhone,
      ApiConstants.resetPasswordCheck,
      ApiConstants.sergeekhKodAvya,
      ApiConstants.nuutsUgSergeeye,
      ApiConstants.getUserByToken,
    ];
    return zamuud.any(path.contains);
  }

  DioClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.headers.containsKey('Authorization')) {
            final token = await _storage.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // A deleted/revoked account answers 401 on every token-backed call.
          // Logging in with a wrong password is a 401 too, so the auth
          // endpoints are excluded — those are handled by LoginScreen.
          if (error.response?.statusCode == 401 &&
              !_nevtrekhZam(error.requestOptions.path)) {
            onErkhTsutslagdsan?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.delete(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> postFormData(String path, FormData formData) async {
    return await _dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  String get imageBaseUrl => '${ApiConstants.baseUrl}/zurag/';
}
